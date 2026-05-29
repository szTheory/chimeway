defmodule DemoHost.Notifiers.InviteSent do
  @moduledoc """
  TeamPulse invite notification — Feature Developer JTBD.

  Copy-paste reference for a simple multi-channel transactional notifier.
  """
  use Chimeway.Notifier

  @impl true
  def notification_key, do: "teampulse.invite_sent"

  @impl true
  def version, do: 1

  @impl true
  def recipients(%{email: email}) do
    {:ok, [%{recipient_identity: DemoHost.Seeds.recipient_identity(email), recipient_type: "user"}]}
  end

  @impl true
  def build(%{team_name: team_name}, _recipient) do
    {:ok,
     %{
       "headline" => "You're invited to #{team_name}",
       "body" => "Join your team on TeamPulse.",
       "primary_action" => %{"label" => "Accept invite", "url" => "https://teampulse.test/invite"}
     }}
  end

  @impl true
  def channels(_params, _recipient), do: {:ok, [:email, :in_app]}

  @impl true
  def rendering(%{team_name: team_name}, _recipient) do
    {:ok,
     %{
       assigns: %{
         "headline" => "You're invited to #{team_name}",
         "body" => "Join your team on TeamPulse.",
         "primary_action" => %{"label" => "Accept invite", "url" => "https://teampulse.test/invite"},
         "subject" => "You're invited to #{team_name}",
         "html_body" => "<p>Join your team on TeamPulse.</p>",
         "text_body" => "Join your team on TeamPulse."
       },
       channels: %{
         in_app: %{render_key: "teampulse.invite_sent.in_app", render_version: 1},
         email: %{render_key: "teampulse.invite_sent.email", render_version: 1}
       }
     }}
  end
end
