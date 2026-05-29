defmodule DemoHost.Mailers.InviteEmail do
  @moduledoc """
  Mailglass mailable for the `teampulse.invite_sent.email` render key.

  Host-owned template module for DEMO-06. Chimeway's Mailglass adapter passes
  notifier `rendering/2` assigns merged with `"to"` from delivery render_data.
  """

  use Mailglass.Mailable, stream: :transactional

  @doc """
  Builds the invite email from notifier assigns.

  Expects `subject`, `html_body`, and `text_body` from
  `DemoHost.Notifiers.InviteSent.rendering/2`. Recipient `"to"` comes from
  delivery render_data when present; falls back to the demo Alex seed email.
  """
  def invite_email(assigns) when is_map(assigns) do
    to = Map.get(assigns, "to") || Map.get(assigns, :to) || DemoHost.Seeds.alex_email()
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
end
