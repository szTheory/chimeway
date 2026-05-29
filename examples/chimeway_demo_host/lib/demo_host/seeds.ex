defmodule DemoHost.Seeds do
  @moduledoc """
  Deterministic TeamPulse demo data for local exploration and journey tests.

  Adopter-copyable: uses `Chimeway.trigger/3` and public Chimeway contexts —
  not internal test fixture inserts.

  ## Scenarios

  - **Invite** (`:invite`) — successful multi-channel delivery for Alex
  - **Password reset** (`:password_reset`) — email suppressed by preference for Sam
  - **Payment escalation** (`:escalation_waiting`) — workflow waiting for webhook signal

  Run all scenarios with `DemoHost.Seeds.run/0` or `mix demo.seed`.
  """

  alias Chimeway.{Deliveries, Preferences, Repo, Traces}
  alias Chimeway.Delivery
  alias Chimeway.Notifications.Notification
  alias Chimeway.Workflows
  alias Chimeway.Workflows.WorkflowRun

  import Ecto.Query

  @tenant_id "teampulse"

  @alex_email "alex@teampulse.test"
  @sam_email "sam@teampulse.test"
  @morgan_email "morgan@teampulse.test"

  @invite_idempotency "teampulse-seed-invite-v1"
  @reset_idempotency "teampulse-seed-reset-v1"
  @payment_idempotency "teampulse-seed-payment-v1"

  @doc "Demo tenant id for TeamPulse scenarios."
  def tenant_id, do: @tenant_id

  @doc "Primary demo user email (successful invite + admin search)."
  def alex_email, do: @alex_email

  @doc "Recipient identity string for a TeamPulse user email."
  def recipient_identity(email) when is_binary(email), do: "user:#{email}"

  @doc "Alex's recipient identity — use in admin search."
  def alex_identity, do: recipient_identity(@alex_email)

  @doc "Sam's recipient identity — suppressed password reset scenario."
  def sam_identity, do: recipient_identity(@sam_email)

  @doc "Morgan's recipient identity — payment escalation scenario."
  def morgan_identity, do: recipient_identity(@morgan_email)

  @doc "Admin UI path on the demo host."
  def admin_path, do: "/admin/chimeway"

  @doc "Default local admin URL (demo host port 4001)."
  def admin_url, do: "http://localhost:4001#{admin_path()}"

  @type scenario_result :: %{
          invite: map(),
          password_reset: map(),
          escalation: map()
        }

  @doc """
  Seeds all TeamPulse scenarios idempotently. Safe to call repeatedly.
  """
  @spec run() :: {:ok, scenario_result()} | {:error, term()}
  def run do
    with {:ok, invite} <- seed_invite(),
         {:ok, password_reset} <- seed_password_reset(),
         {:ok, escalation} <- seed_escalation_waiting() do
      {:ok, %{invite: invite, password_reset: password_reset, escalation: escalation}}
    end
  end

  @doc "JOUR-01: successful team invite for Alex."
  @spec seed_invite() :: {:ok, map()} | {:error, term()}
  def seed_invite do
    trigger(
      DemoHost.Notifiers.InviteSent,
      %{email: @alex_email, team_name: "Engineering"},
      idempotency_key: @invite_idempotency,
      correlation_id: "teampulse-seed-invite-corr",
      tenant_id: @tenant_id
    )
  end

  @doc "JOUR-02: password reset suppressed for Sam (email channel disabled)."
  @spec seed_password_reset() :: {:ok, map()} | {:error, term()}
  def seed_password_reset do
    identity = recipient_identity(@sam_email)

    {:ok, _pref} =
      Preferences.upsert_preference(%{
        recipient_id: identity,
        notification_key: DemoHost.Notifiers.PasswordReset.notification_key(),
        channel: "email",
        enabled: false
      })

    trigger(
      DemoHost.Notifiers.PasswordReset,
      %{email: @sam_email},
      idempotency_key: @reset_idempotency,
      correlation_id: "teampulse-seed-reset-corr",
      tenant_id: @tenant_id
    )
  end

  @doc """
  JOUR-03: payment reminder with a delivery awaiting webhook feedback.

  Uses `Chimeway.trigger/3` for the notification + workflow, then public
  `Deliveries` / `Workflows` helpers to stage a dispatched delivery and a
  `:waiting` run keyed on `chimeway.delivery.succeeded`.
  """
  @spec seed_escalation_waiting() :: {:ok, map()} | {:error, term()}
  def seed_escalation_waiting do
    previous_adapters = Application.get_env(:chimeway, :channel_adapters, %{})

    Application.put_env(:chimeway, :channel_adapters, %{
      "email" => DemoHost.Adapters.PendingWebhookAdapter
    })

    result =
      with {:ok, trigger_result} <-
             trigger(
               DemoHost.Notifiers.PaymentReminder,
               %{email: @morgan_email, invoice_id: "INV-1001"},
               idempotency_key: @payment_idempotency,
               correlation_id: "teampulse-seed-payment-corr",
               tenant_id: @tenant_id
             ),
           {:ok, staged} <- stage_escalation_webhook(trigger_result) do
        {:ok, Map.merge(trigger_result, staged)}
      end

    Application.put_env(:chimeway, :channel_adapters, previous_adapters)
    result
  end

  @doc "Alias for `seed_escalation_waiting/0` — used by journey tests."
  def escalation_waiting!, do: seed_escalation_waiting()

  @doc "Returns suppression explanation for Sam's password reset seed (JOUR-02)."
  @spec password_reset_explanation() :: {:ok, map()} | {:error, term()}
  def password_reset_explanation do
    with {:ok, %{trace: %{delivery_ids: [delivery_id | _]}}} <- seed_password_reset(),
         {:ok, explanation} <- Traces.explain_delivery(delivery_id) do
      {:ok, explanation}
    end
  end

  defp stage_escalation_webhook(%{trace: %{delivery_ids: delivery_ids}}) do
    deliveries = Enum.map(delivery_ids, &Repo.get!(Delivery, &1))

    delivery =
      Enum.find(deliveries, fn d -> d.channel == "email" end) ||
        raise "expected email delivery from payment reminder trigger"

    run_id =
      delivery.workflow_run_id ||
        deliveries
        |> Enum.find_value(& &1.workflow_run_id) ||
        raise "expected workflow_run_id on payment reminder deliveries"

    run = Repo.get!(WorkflowRun, run_id)

    with {:ok, dispatched} <-
           (case delivery.status do
              :failed -> Deliveries.transition_status(delivery, :dispatched)
              :dispatched -> {:ok, delivery}
              other -> {:error, {:unexpected_delivery_status, other}}
            end),
         {:ok, waiting_run} <-
           Workflows.update_run(Repo, run, %{
             state: :waiting,
             status_reason: "waiting_for_signal",
             pending_signals: ["chimeway.delivery.succeeded"]
           }) do
      {:ok,
       %{
         delivery: dispatched,
         run: waiting_run,
         workflow_run_id: waiting_run.id
       }}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp trigger(notifier, params, opts) do
    case Chimeway.trigger(notifier, params, opts) do
      {:ok, result} ->
        {:ok, normalize_trigger_result(result)}

      {:duplicate, event} ->
        {:ok, normalize_duplicate(event)}

      {:error, _} = error ->
        error
    end
  end

  defp normalize_trigger_result(%{trace: _} = result), do: result

  defp normalize_trigger_result(result) when is_map(result) do
    Map.put_new(result, :trace, Map.get(result, :trace, %{}))
  end

  defp normalize_duplicate(event) do
    delivery_ids =
      from(d in Delivery,
        join: n in Notification,
        on: d.notification_id == n.id,
        where: n.event_id == ^event.id,
        select: d.id
      )
      |> Repo.all()

    %{
      trace: %{
        event_id: event.id,
        delivery_ids: delivery_ids,
        correlation_id: event.correlation_id
      },
      duplicate?: true
    }
  end
end
