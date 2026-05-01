defmodule Chimeway.Rendering.ChannelContractTest do
  # async: false — these tests mutate :persistent_term and Application env
  # for :channel_render_modules registry behavior.
  use ExUnit.Case, async: false

  alias Chimeway.Rendering

  describe "render_delivery/4" do
    test "renders validated in-app payloads with semantic inbox fields" do
      assert {:ok,
              %{
                channel: "in_app",
                render_data: %{
                  "body" => "Ada left a new comment",
                  "headline" => "New comment",
                  "primary_action" => %{"label" => "View comment", "url" => "/comments/42"}
                },
                render_key: "comment.created.in_app",
                render_version: 2
              }} =
               Rendering.render_delivery(
                 :in_app,
                 "comment.created.in_app",
                 2,
                 %{
                   "body" => "Ada left a new comment",
                   "headline" => "New comment",
                   "primary_action" => %{"label" => "View comment", "url" => "/comments/42"}
                 }
               )
    end

    test "renders validated email payloads with subject, html_body, and text_body" do
      assert {:ok,
              %{
                channel: "email",
                render_data: %{
                  "html_body" => "<p>Ada left a new comment</p>",
                  "subject" => "New comment",
                  "text_body" => "Ada left a new comment"
                },
                render_key: "comment.created.email",
                render_version: 4
              }} =
               Rendering.render_delivery(
                 :email,
                 "comment.created.email",
                 4,
                 %{
                   "html_body" => "<p>Ada left a new comment</p>",
                   "subject" => "New comment",
                   "text_body" => "Ada left a new comment"
                 }
               )
    end

    test "returns tagged runtime validation failures for malformed channel payloads" do
      assert {:error,
              {:rendering_failed, "email", {:invalid_channel_payload, "email", changeset}}} =
               Rendering.render_delivery(
                 :email,
                 "comment.created.email",
                 4,
                 %{"subject" => "Missing bodies"}
               )

      assert %Ecto.Changeset{} = changeset

      assert %{
               html_body: ["can't be blank"],
               text_body: ["can't be blank"]
             } = errors_on(changeset)
    end
  end

  describe "channel_module/1 three-layer resolution" do
    test "renders validated SMS payloads via compiled clause" do
      assert {:ok,
              %{
                channel: "sms",
                render_data: %{"text_body" => "Your code is 123456"},
                render_key: "auth.code.sms",
                render_version: 1
              }} =
               Rendering.render_delivery(
                 :sms,
                 "auth.code.sms",
                 1,
                 %{"text_body" => "Your code is 123456"}
               )
    end

    test "renders validated push payloads via compiled clause" do
      assert {:ok,
              %{
                channel: "push",
                render_data: %{"title" => "New comment", "body" => "Ada left a new comment"},
                render_key: "comment.created.push",
                render_version: 1
              }} =
               Rendering.render_delivery(
                 :push,
                 "comment.created.push",
                 1,
                 %{"title" => "New comment", "body" => "Ada left a new comment"}
               )
    end

    test "renders validated chat payloads via compiled clause" do
      assert {:ok,
              %{
                channel: "chat",
                render_data: %{"text" => "Build complete"},
                render_key: "ci.build.chat",
                render_version: 1
              }} =
               Rendering.render_delivery(
                 :chat,
                 "ci.build.chat",
                 1,
                 %{"text" => "Build complete"}
               )
    end

    test "resolves host-configured channel via :channel_render_modules registry" do
      previous = Application.get_env(:chimeway, :channel_render_modules, %{})

      Application.put_env(
        :chimeway,
        :channel_render_modules,
        Map.put(previous, "slack", Chimeway.Rendering.Channels.Chat)
      )

      try do
        assert {:ok, %{channel: "slack", render_data: %{"text" => "registry hit"}}} =
                 Rendering.render_delivery(
                   "slack",
                   "ops.alert.slack",
                   1,
                   %{"text" => "registry hit"}
                 )
      after
        Application.put_env(:chimeway, :channel_render_modules, previous)
      end
    end

    test "unknown channel emits telemetry once per BEAM lifetime + returns error" do
      channel = "unknown_xyz_#{System.unique_integer([:positive])}"
      handler_id = {:test_channel_unregistered, channel}
      test_pid = self()

      :telemetry.attach(
        handler_id,
        [:chimeway, :rendering, :channel_unregistered],
        fn event, measurements, meta, _config ->
          send(test_pid, {:telemetry_event, event, measurements, meta})
        end,
        nil
      )

      try do
        # First call: telemetry MUST fire + error returned
        assert {:error,
                {:rendering_failed, ^channel,
                 {:unsupported_render_channel, ^channel}}} =
                 Rendering.render_delivery(channel, "x.x.#{channel}", 1, %{})

        assert_receive {:telemetry_event, [:chimeway, :rendering, :channel_unregistered],
                        %{count: 1}, %{channel: ^channel}},
                       500

        # Second call: same error, but NO new telemetry (once-per-BEAM-lifetime)
        assert {:error,
                {:rendering_failed, ^channel,
                 {:unsupported_render_channel, ^channel}}} =
                 Rendering.render_delivery(channel, "x.x.#{channel}", 1, %{})

        refute_receive {:telemetry_event, [:chimeway, :rendering, :channel_unregistered], _, _},
                       100
      after
        :telemetry.detach(handler_id)
      end
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
