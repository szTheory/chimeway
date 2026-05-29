if Code.ensure_loaded?(Mailglass) do
  defmodule Chimeway.TestSupport.MailglassFixtures do
    @moduledoc false

    defmodule TestMailer do
      @moduledoc false
      use Mailglass.Mailable, stream: :transactional

      def test_email(assigns) when is_map(assigns) do
        to = Map.get(assigns, "to") || Map.get(assigns, :to)

        new()
        |> Mailglass.Message.update_swoosh(fn email ->
          email
          |> Swoosh.Email.to(to)
          |> Swoosh.Email.from({"Chimeway Test", "test@example.com"})
          |> Swoosh.Email.subject("Chimeway test email")
          |> Swoosh.Email.text_body("Test")
        end)
        |> Mailglass.Message.put_function(:test_email)
      end
    end

    @doc false
    def mailables do
      %{"chimeway.test.email" => {TestMailer, :test_email}}
    end

    @doc false
    def sample_delivery do
      %Chimeway.Delivery{
        id: Ecto.UUID.generate(),
        channel: "email",
        notification_id: Ecto.UUID.generate(),
        tenant_id: "test-tenant",
        actor_id: "user:test@example.com",
        status: :pending,
        render_key: "chimeway.test.email",
        render_data: %{"to" => "test@example.com"},
        metadata: %{}
      }
    end

    @doc false
    def postmark_webhook_config do
      %{basic_auth: {"user", "pass"}}
    end

    @doc false
    def postmark_delivery_payload(opts \\ []) do
      message_id = Keyword.get(opts, :message_id, "postmark-msg-123")
      delivered_at = Keyword.get(opts, :delivered_at, "2026-05-29T12:00:00Z")

      %{
        "RecordType" => "Delivery",
        "MessageID" => message_id,
        "DeliveredAt" => delivered_at,
        "Recipient" => "test@example.com",
        "Tag" => "chimeway-test"
      }
    end

    @doc false
    def postmark_delivery_payload_for_message_id(message_id) when is_binary(message_id) do
      postmark_delivery_payload(message_id: message_id)
    end

    @doc false
    def postmark_bounce_payload(opts \\ []) do
      message_id = Keyword.get(opts, :message_id, "postmark-msg-bounce")

      %{
        "RecordType" => "Bounce",
        "TypeCode" => 1,
        "ID" => 42,
        "MessageID" => message_id,
        "BouncedAt" => "2026-05-29T12:01:00Z",
        "Email" => "bounce@example.com"
      }
    end

    @doc false
    def postmark_open_payload do
      %{
        "RecordType" => "Open",
        "MessageID" => "postmark-msg-open",
        "ReceivedAt" => "2026-05-29T12:02:00Z",
        "Recipient" => "test@example.com"
      }
    end

    @doc false
    def postmark_delivery_headers do
      auth = Base.encode64("user:pass")
      [{"authorization", "Basic #{auth}"}]
    end

    @doc false
    def postmark_webhook_config_keyword do
      [
        webhook_provider: :postmark,
        webhook_provider_config: postmark_webhook_config()
      ]
    end

    @doc false
    def encode_postmark_payload(payload) when is_map(payload) do
      Jason.encode!(payload)
    end
  end
end
