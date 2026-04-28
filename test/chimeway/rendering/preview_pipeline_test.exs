defmodule Chimeway.Rendering.PreviewPipelineTest do
  use ExUnit.Case, async: true

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
    def build(_params, recipient), do: {:ok, %{legacy_recipient: recipient.id}}

    @impl true
    def rendering(params, recipient) do
      {:ok,
       %{
         assigns: %{
           "headline" => "#{Map.fetch!(params, :actor_name)} commented on your post",
           "body" => Map.fetch!(params, :comment_body),
           "primary_action" => %{
             "label" => "Open comment",
             "url" => "mailto:#{recipient.email}"
           },
           "subject" => "#{Map.fetch!(params, :actor_name)} commented on your post",
           "html_body" => "<p>#{Map.fetch!(params, :comment_body)}</p>",
           "text_body" => Map.fetch!(params, :comment_body)
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

      assert {:error,
              {:rendering_failed, "sms",
               {:unsupported_render_channel, "sms"}}} =
               Chimeway.preview_rendering(
                 InvalidChannelNotifier,
                 %{},
                 recipient: recipient,
                 channel: :sms
               )

      assert {:error,
              {:rendering_failed, "email",
               {:invalid_channel_payload, "email", %Ecto.Changeset{}}}} =
               Chimeway.preview_rendering(
                 InvalidAssignsNotifier,
                 %{},
                 recipient: recipient,
                 channel: :email
               )
    end
  end
end
