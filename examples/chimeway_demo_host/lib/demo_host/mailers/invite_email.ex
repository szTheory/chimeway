defmodule DemoHost.Mailers.InviteEmail do
  @moduledoc """
  Mailglass mailable for the `teampulse.invite_sent.email` render key.

  Host-owned template module for DEMO-06. Chimeway's Mailglass adapter passes
  notifier `rendering/2` assigns merged with `"to"` from delivery render_data.

  ## Recipient resolution

  Production and dev builds require `"to"` (or `:to`) in assigns — typically
  injected by the Mailglass adapter from delivery render_data. The Alex seed
  email fallback exists **only in `:test`** so isolated mailable tests can run
  without wiring full delivery context; do not copy that fallback into real apps.
  """

  use Mailglass.Mailable, stream: :transactional

  @doc """
  Builds the invite email from notifier assigns.

  Expects `subject`, `html_body`, and `text_body` from
  `DemoHost.Notifiers.InviteSent.rendering/2`. Recipient `"to"` must come from
  delivery render_data in non-test environments.
  """
  def invite_email(assigns) when is_map(assigns) do
    to = recipient(assigns)
    subject = Map.get(assigns, "subject") || "You're invited"
    html_body = Map.get(assigns, "html_body") || ""
    text_body = Map.get(assigns, "text_body") || ""

    new()
    |> Mailglass.Message.update_swoosh(fn email ->
      email
      |> Swoosh.Email.to(to)
      |> Swoosh.Email.from({"TeamPulse", "invites@teampulse.test"})
      |> Swoosh.Email.subject(subject)
      |> Swoosh.Email.html_body(html_body)
      |> Swoosh.Email.text_body(text_body)
    end)
    |> Mailglass.Message.put_function(:invite_email)
  end

  defp recipient(assigns) do
    case Map.get(assigns, "to") || Map.get(assigns, :to) do
      nil ->
        if Mix.env() == :test do
          DemoHost.Seeds.alex_email()
        else
          raise ArgumentError, "missing recipient :to in invite_email assigns"
        end

      to ->
        to
    end
  end
end
