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
  end
end
