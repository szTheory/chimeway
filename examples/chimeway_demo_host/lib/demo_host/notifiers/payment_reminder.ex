defmodule DemoHost.Notifiers.PaymentReminder do
  @moduledoc """
  TeamPulse payment reminder — Product Manager JTBD.

  If Morgan does not open the in-app notice within 2 hours, escalate to email.
  Inbox read (`Chimeway.mark_read/3`) cancels the wait early via
  `chimeway.notification.read`.

  Pair with `DemoHost.Seeds.escalation_waiting!/0` and JOUR-03 in
  `journey_test.exs` for the READ-driven path. Webhook / delivery-feedback
  proof lives in `feedback_pipeline_e2e_test.exs`.
  """
  use Chimeway.Notifier

  @impl true
  def notification_key, do: "teampulse.payment_reminder"

  @impl true
  def version, do: 1

  @impl true
  def recipients(%{email: email}) do
    {:ok, [%{recipient_identity: DemoHost.Seeds.recipient_identity(email), recipient_type: "user"}]}
  end

  @impl true
  def build(%{invoice_id: invoice_id}, _recipient) do
    {:ok,
     %{
       "headline" => "Payment reminder",
       "body" => "Invoice #{invoice_id} is due.",
       "primary_action" => %{"label" => "Pay now", "url" => "https://teampulse.test/billing"}
     }}
  end

  @impl true
  def channels(_params, _recipient), do: {:ok, [:in_app, :email]}

  @impl true
  def rendering(%{invoice_id: invoice_id}, _recipient) do
    {:ok,
     %{
       assigns: %{
         "headline" => "Payment reminder",
         "body" => "Invoice #{invoice_id} is due.",
         "primary_action" => %{"label" => "Pay now", "url" => "https://teampulse.test/billing"},
         "subject" => "Payment reminder",
         "html_body" => "<p>Invoice #{invoice_id} is due.</p>",
         "text_body" => "Invoice #{invoice_id} is due."
       },
       channels: %{
         in_app: %{render_key: "teampulse.payment_reminder.in_app", render_version: 1},
         email: %{render_key: "teampulse.payment_reminder.email", render_version: 1}
       }
     }}
  end

  @impl true
  def workflow(_params, _recipient) do
    {:ok,
     %{
       workflow_key: "teampulse.payment_reminder",
       workflow_version: 1,
       steps: [
         %{
           step_key: "initial_notice",
           step_order: 1,
           channel: :in_app,
           config: %{
             "progress" => [
               %{
                 "kind" => "wait_until",
                 "anchor" => "prior_delivery_terminal_at",
                 "delay_seconds" => 7200,
                 "to_step" => "email_escalation",
                 "cancel_signals" => ["chimeway.notification.read"]
               }
             ]
           }
         },
         %{
           step_key: "email_escalation",
           step_order: 2,
           channel: :email,
           config: %{}
         }
       ]
     }}
  end
end
