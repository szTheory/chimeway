defmodule DemoHost.Notifiers.PasswordReset do
  @moduledoc """
  TeamPulse password reset — Support Operator JTBD.

  Demonstrates explainability when a channel is suppressed by recipient preference.
  """
  use Chimeway.Notifier

  @impl true
  def notification_key, do: "teampulse.password_reset"

  @impl true
  def version, do: 1

  @impl true
  def recipients(%{email: email}) do
    {:ok, [%{recipient_identity: DemoHost.Seeds.recipient_identity(email), recipient_type: "user"}]}
  end

  @impl true
  def build(_params, _recipient) do
    {:ok,
     %{
       "headline" => "Reset your password",
       "body" => "Use the link below to choose a new password.",
       "primary_action" => %{"label" => "Reset password", "url" => "https://teampulse.test/reset"}
     }}
  end

  @impl true
  def channels(_params, _recipient), do: {:ok, [:email]}

  @impl true
  def rendering(_params, _recipient) do
    {:ok,
     %{
       assigns: %{
         "headline" => "Reset your password",
         "body" => "Use the link below to choose a new password.",
         "primary_action" => %{"label" => "Reset password", "url" => "https://teampulse.test/reset"},
         "subject" => "Reset your TeamPulse password",
         "html_body" => "<p>Use the link below to choose a new password.</p>",
         "text_body" => "Use the link below to choose a new password."
       },
       channels: %{
         email: %{render_key: "teampulse.password_reset.email", render_version: 1}
       }
     }}
  end
end
