defmodule Chimeway.Rendering.PreviewPipelineTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Chimeway.Rendering

  defmodule PreviewNotifier do
    use Chimeway.Notifier

    @impl true
    def notification_key, do: "comment.created"

    @impl true
    def version, do: 7

    @impl true
    def recipients(_params), do: {:ok, [%{id: "recipient-1", email: "ada@example.com"}]}

    @impl true
    def build(_params, recipient),
      do: {:ok, %{legacy_recipient: recipient[:id] || recipient["id"]}}

    @impl true
    def rendering(params, recipient) do
      actor_name = params[:actor_name] || params["actor_name"]
      comment_body = params[:comment_body] || params["comment_body"]
      email = recipient[:email] || recipient["email"]

      {:ok,
       %{
         assigns: %{
           "headline" => "#{actor_name} commented on your post",
           "body" => comment_body,
           "primary_action" => %{
             "label" => "Open comment",
             "url" => "mailto:#{email}"
           },
           "subject" => "#{actor_name} commented on your post",
           "html_body" => "<p>#{comment_body}</p>",
           "text_body" => comment_body
         },
         channels: %{
           in_app: %{render_key: "comment.created.in_app", render_version: 2},
           email: %{render_key: "comment.created.email", render_version: 4}
         }
       }}
    end
  end

  defmodule InvalidChannelNotifier do
    use Chimeway.Notifier

    @impl true
    def notification_key, do: "invalid.channel"

    @impl true
    def version, do: 1

    @impl true
    def recipients(_params), do: {:ok, [%{id: "recipient-1"}]}

    @impl true
    def build(_params, _recipient), do: {:ok, %{}}

    @impl true
    def rendering(_params, _recipient) do
      {:ok,
       %{
         assigns: %{},
         channels: %{
           sms: %{render_key: "invalid.channel.sms", render_version: 1}
         }
       }}
    end
  end

  defmodule InvalidAssignsNotifier do
    use Chimeway.Notifier

    @impl true
    def notification_key, do: "invalid.assigns"

    @impl true
    def version, do: 1

    @impl true
    def recipients(_params), do: {:ok, [%{id: "recipient-1"}]}

    @impl true
    def build(_params, _recipient), do: {:ok, %{}}

    @impl true
    def rendering(_params, _recipient) do
      {:ok,
       %{
         assigns: %{"subject" => "Only subject"},
         channels: %{
           email: %{render_key: "invalid.assigns.email", render_version: 1}
         }
       }}
    end
  end

  defmodule BuggyNotifier do
    use Chimeway.Notifier

    @impl true
    def notification_key, do: "buggy.notifier"

    @impl true
    def version, do: 1

    @impl true
    def recipients(_params), do: {:ok, [%{id: "recipient-1"}]}

    @impl true
    def build(_params, _recipient), do: {:ok, %{}}

    @impl true
    def rendering(_params, _recipient) do
      raise "bug in rendering"
    end
  end

  describe "preview_rendering/3" do
    test "returns stable preview identity and validated render data" do
      recipient = %{id: "recipient-1", email: "ada@example.com"}

      assert {:ok, preview} =
               Chimeway.preview_rendering(
                 PreviewNotifier,
                 %{actor_name: "Ada", comment_body: "New comment"},
                 recipient: recipient,
                 channel: :email
               )

      assert preview.channel == "email"
      assert preview.render_key == "comment.created.email"
      assert preview.render_version == 4

      assert preview.render_data == %{
               "html_body" => "<p>New comment</p>",
               "subject" => "Ada commented on your post",
               "text_body" => "New comment"
             }
    end

    test "reuses the normalized declaration and channel renderer path used in production rendering" do
      recipient = %{id: "recipient-1", email: "ada@example.com"}

      assert {:ok, declaration} =
               Rendering.resolve_declaration(
                 PreviewNotifier,
                 %{actor_name: "Ada", comment_body: "New comment"},
                 recipient
               )

      email_rendering = declaration.channels["email"]

      assert {:ok, production_render} =
               Rendering.render_delivery(
                 "email",
                 email_rendering.render_key,
                 email_rendering.render_version,
                 declaration.assigns
               )

      assert {:ok, preview} =
               Chimeway.preview_rendering(
                 PreviewNotifier,
                 %{actor_name: "Ada", comment_body: "New comment"},
                 recipient: recipient,
                 channel: "email"
               )

      assert Map.from_struct(preview) == production_render
    end

    test "returns tagged production-style errors for invalid channels and malformed assigns" do
      recipient = %{id: "recipient-1"}

      assert {:error, {:rendering_failed, "sms", {:unsupported_render_channel, "sms"}}} =
               Chimeway.preview_rendering(
                 InvalidChannelNotifier,
                 %{},
                 recipient: recipient,
                 channel: :sms
               )

      assert {:error,
              {:rendering_failed, "email", {:invalid_channel_payload, "email", %Ecto.Changeset{}}}} =
               Chimeway.preview_rendering(
                 InvalidAssignsNotifier,
                 %{},
                 recipient: recipient,
                 channel: :email
               )
    end

    test "returns notifier_not_loaded for unloaded notifier modules" do
      recipient = %{id: "recipient-1", email: "ada@example.com"}

      assert {:error, :notifier_not_loaded} =
               Chimeway.preview_rendering(
                 SomeUnloadedNotifier,
                 %{},
                 recipient: recipient,
                 channel: :email
               )
    end

    test "preview still surfaces renderer errors without blanket rescue" do
      recipient = %{id: "recipient-1", email: "ada@example.com"}

      assert_raise RuntimeError, "bug in rendering", fn ->
        Chimeway.preview_rendering(
          BuggyNotifier,
          %{},
          recipient: recipient,
          channel: :email
        )
      end
    end
  end

  describe "mix preview.rendering" do
    setup do
      Mix.Task.clear()
      :ok
    end

    test "mix preview.rendering parses inline JSON inputs" do
      assert {:ok, preview} =
               Chimeway.preview_rendering(
                 PreviewNotifier,
                 %{"actor_name" => "Ada", "comment_body" => "New comment"},
                 recipient: %{"id" => "recipient-1", "email" => "ada@example.com"},
                 channel: :email
               )

      output =
        capture_io(fn ->
          Mix.Tasks.Preview.Rendering.run([
            "--notifier",
            "Elixir.Chimeway.Rendering.PreviewPipelineTest.PreviewNotifier",
            "--params-json",
            "{\"actor_name\": \"Ada\", \"comment_body\": \"New comment\"}",
            "--recipient-json",
            "{\"id\": \"recipient-1\", \"email\": \"ada@example.com\"}",
            "--channel",
            "email"
          ])
        end)

      assert output =~ "render_key: #{preview.render_key}"
      assert output =~ "render_version: #{preview.render_version}"
      assert output =~ "channel: #{preview.channel}"
      assert output =~ "\"subject\" => \"Ada commented on your post\""
      assert output =~ "\"html_body\" => \"<p>New comment</p>\""
    end

    test "mix preview.rendering parses JSON files" do
      params_path = Path.join(System.tmp_dir!(), "preview_params_#{System.unique_integer()}.json")

      recipient_path =
        Path.join(System.tmp_dir!(), "preview_recipient_#{System.unique_integer()}.json")

      File.write!(params_path, "{\"actor_name\": \"Ada\", \"comment_body\": \"New comment\"}")
      File.write!(recipient_path, "{\"id\": \"recipient-1\", \"email\": \"ada@example.com\"}")

      on_exit(fn ->
        File.rm(params_path)
        File.rm(recipient_path)
      end)

      output =
        capture_io(fn ->
          Mix.Tasks.Preview.Rendering.run([
            "--notifier",
            "Elixir.Chimeway.Rendering.PreviewPipelineTest.PreviewNotifier",
            "--params-file",
            params_path,
            "--recipient-file",
            recipient_path,
            "--channel",
            "email"
          ])
        end)

      assert output =~ "\"subject\" => \"Ada commented on your post\""
    end

    test "mix preview.rendering rejects executable input paths" do
      error =
        capture_io(:stderr, fn ->
          assert catch_exit(
                   Mix.Tasks.Preview.Rendering.run([
                     "--notifier",
                     "Elixir.Chimeway.Rendering.PreviewPipelineTest.PreviewNotifier",
                     "--params-json",
                     "File.read!(\"secrets.txt\")",
                     "--recipient-json",
                     "{}",
                     "--channel",
                     "email"
                   ])
                 ) == {:shutdown, 1}
        end)

      assert error =~ "Preview rendering failed: Invalid JSON syntax"
    end

    test "exits non-zero with usage guidance when required flags are missing" do
      error =
        capture_io(:stderr, fn ->
          assert catch_exit(Mix.Tasks.Preview.Rendering.run(["--channel", "email"])) ==
                   {:shutdown, 1}
        end)

      assert error =~ "Usage: mix preview.rendering"
      assert error =~ "--notifier"
      assert error =~ "--channel"
    end
  end
end
