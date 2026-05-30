defmodule DemoHost.Seeds do
  @moduledoc """
  Deterministic TeamPulse demo data for local exploration and journey tests.

  Adopter-copyable: uses `Chimeway.trigger/3` and public Chimeway contexts —
  not internal test fixture inserts.

  ## Scenarios

  - **Invite** (`:invite`) — successful multi-channel delivery for Alex
  - **Password reset** (`:password_reset`) — email suppressed by preference for Sam
  - **Payment escalation** (`:escalation_waiting`) — READ-driven `:waiting` after in-app delivery

  Run all scenarios with `DemoHost.Seeds.run/0` or `mix demo.seed`.
  """

  alias Chimeway.{Preferences, Repo, Traces}
  alias Chimeway.Delivery
  alias Chimeway.Notifications.Notification

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
  JOUR-03: payment reminder with READ-driven workflow waiting.

  Uses `Chimeway.trigger/3` only — after in-app delivery succeeds, the engine
  enters `:waiting` with `pending_signals` from `cancel_signals`. Pair with
  `Chimeway.mark_read/3` in journey tests for early exit.
  """
  @spec seed_escalation_waiting() :: {:ok, map()} | {:error, term()}
  def seed_escalation_waiting do
    trigger(
      DemoHost.Notifiers.PaymentReminder,
      %{email: @morgan_email, invoice_id: "INV-1001"},
      idempotency_key: @payment_idempotency,
      correlation_id: "teampulse-seed-payment-corr",
      tenant_id: @tenant_id
    )
  end

  @doc "Alias for `seed_escalation_waiting/0` — used by journey tests."
  def escalation_waiting!, do: seed_escalation_waiting()

  @doc """
  DEMO-07: Accrue billing-event dunning through Chimeway with Logger email delivery.

  Uses `Accrue.Test.trigger_event/2` for `invoice.payment_failed` — not
  `Chimeway.trigger/3` host glue. Standalone API; not invoked from `run/0`.
  """
  @spec seed_accrue_dunning() :: {:ok, map()} | {:error, term()}
  def seed_accrue_dunning do
    if Code.ensure_loaded?(DemoHost.AccrueSeeds) do
      DemoHost.AccrueSeeds.seed_accrue_dunning()
    else
      {:error, :accrue_not_available}
    end
  end

  @doc "Accrue demo customer email for admin trace search."
  def accrue_demo_email do
    if Code.ensure_loaded?(DemoHost.AccrueSeeds) do
      DemoHost.AccrueSeeds.demo_email()
    else
      "accrue.demo@teampulse.test"
    end
  end

  @doc "Accrue demo recipient identity for admin trace search."
  def accrue_demo_identity do
    if Code.ensure_loaded?(DemoHost.AccrueSeeds) do
      DemoHost.AccrueSeeds.demo_identity()
    else
      recipient_identity("accrue.demo@teampulse.test")
    end
  end

  @doc "Returns suppression explanation for Sam's password reset seed (JOUR-02)."
  @spec password_reset_explanation() :: {:ok, map()} | {:error, term()}
  def password_reset_explanation do
    with {:ok, %{trace: %{delivery_ids: [delivery_id | _]}}} <- seed_password_reset(),
         {:ok, explanation} <- Traces.explain_delivery(delivery_id) do
      {:ok, explanation}
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
