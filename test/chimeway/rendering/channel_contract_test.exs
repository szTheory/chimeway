defmodule Chimeway.Rendering.ChannelContractTest do
  use ExUnit.Case, async: true

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
      assert {:error, {:rendering_failed, "email", {:invalid_channel_payload, "email", changeset}}} =
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

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
