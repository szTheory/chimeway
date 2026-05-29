defmodule DemoHost.Notifiers.PaymentReminder do
  @moduledoc """
  TeamPulse payment reminder — Product Manager JTBD.

  Workflow waits for inbound `chimeway.delivery.succeeded` before advancing.
  Pair with `DemoHost.Seeds.escalation_waiting!/0` and webhook E2E tests.
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
               %{"kind" => "stop", "outcome" => "bounced"}
             ]
           }
         },
         %{
           step_key: "paid_confirmation",
           step_order: 2,
           channel: :in_app,
           config: %{}
         }
       ]
     }}
  end
end
