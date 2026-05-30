defmodule DemoHost.Seeds do
  @compile {:no_warn_undefined,
            [
              DemoHost.AccrueSeeds,
              Sigra.Integrations.Chimeway,
              Sigra.Integrations.Chimeway.MagicLinkNotifier,
              Sigra.Integrations.Chimeway.PendingDelivery
            ]}
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
  @inbox_idempotency_a "teampulse-seed-inbox-v1-a"
  @inbox_idempotency_b "teampulse-seed-inbox-v1-b"

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

  @doc """
  DEMO-08: Adopter-copyable inbox seed with two unread in_app notifications for Alex.

  Triggers `Chimeway.trigger/3` via `DemoHost.Notifiers.InviteSent` so the bell list
  has metadata `subject` for assertions. Standalone API; not invoked from `run/0`.
  """
  @spec seed_inbox() :: {:ok, map()} | {:error, term()}
  def seed_inbox do
    recipient = alex_identity()

    with {:ok, first} <-
           trigger(
             DemoHost.Notifiers.InviteSent,
             %{email: @alex_email, team_name: "Design"},
             idempotency_key: @inbox_idempotency_a,
             correlation_id: "teampulse-seed-inbox-a-corr",
             tenant_id: @tenant_id
           ),
         {:ok, second} <-
           trigger(
             DemoHost.Notifiers.InviteSent,
             %{email: @alex_email, team_name: "Product"},
             idempotency_key: @inbox_idempotency_b,
             correlation_id: "teampulse-seed-inbox-b-corr",
             tenant_id: @tenant_id
           ) do
      notification_ids =
        [first, second]
        |> Enum.flat_map(&notification_ids_for_seed/1)
        |> Enum.uniq()

      if length(notification_ids) >= 2 do
        {:ok,
         %{
           notification_ids: notification_ids,
           recipient_identity: recipient,
           trace: %{
             first_event_id: first.trace.event_id,
             second_event_id: second.trace.event_id
           }
         }}
      else
        {:error, :insufficient_notifications}
      end
    end
  end

  @doc """
  DEMO-09: Threadline audit correlation for notification lifecycle with reporter attached.

  Triggers `Chimeway.trigger/3` via `DemoHost.Notifiers.InviteSent` while a
  `Chimeway.Telemetry.ThreadlineReporter` is attached by the caller's test setup.
  Standalone API; not invoked from `run/0`. Caller must attach ThreadlineReporter in setup.

  Returns `{:ok, %{recipient_identity: ..., trace: %{delivery_ids: [...], correlation_id: ...}}}`.
  """
  @spec seed_threadline_notification() :: {:ok, map()} | {:error, term()}
  def seed_threadline_notification do
    if Code.ensure_loaded?(Chimeway.Telemetry.ThreadlineReporter) do
      recipient = alex_identity()
      correlation_id = "teampulse-seed-threadline-corr-#{System.unique_integer([:positive])}"

      case Chimeway.trigger(
             DemoHost.Notifiers.InviteSent,
             %{email: @alex_email, team_name: "Threadline Demo"},
             idempotency_key: "teampulse-seed-threadline-v1-#{System.unique_integer([:positive])}",
             correlation_id: correlation_id,
             tenant_id: @tenant_id
           ) do
        {:ok, result} ->
          event_id = result.trace.event_id
          delivery_ids = delivery_ids_for_event(event_id)

          {:ok,
           %{
             recipient_identity: recipient,
             trace: %{delivery_ids: delivery_ids, correlation_id: correlation_id}
           }}

        {:duplicate, _event} ->
          {:error, :duplicate_seed}

        {:error, _} = err ->
          err
      end
    else
      {:error, :threadline_not_available}
    end
  end

  @doc """
  DEMO-10: Sigra auth → Chimeway durable delivery with operator trace inspectability.

  Triggers `sigra.auth.magic_link` via Chimeway using the Sigra integration module's
  notifier directly. Standalone API; not invoked from `run/0`. Caller must configure
  Sigra integration (enabled: true) and Chimeway adapter in setup.

  Returns `{:ok, %{recipient_identity: ..., trace: %{delivery_ids: [...], correlation_id: ...}}}`.
  Never exposes `raw_token` or `url` in the returned map.
  """
  @spec seed_sigra_auth() :: {:ok, map()} | {:error, term()}
  def seed_sigra_auth do
    if Code.ensure_loaded?(Sigra.Integrations.Chimeway) do
      idempotency_key = "teampulse-seed-sigra-magic-link-#{System.unique_integer([:positive])}"
      correlation_id = "teampulse-seed-sigra-corr-#{System.unique_integer([:positive])}"

      # Pre-populate PendingDelivery so MagicLinkNotifier.rendering/2 can pop the URL at render time.
      # The URL itself is discarded — only identifier fields reach the Chimeway trace.
      :ok =
        Sigra.Integrations.Chimeway.PendingDelivery.put(idempotency_key, %{
          url: "https://example.test/demo-auth/#{idempotency_key}"
        })

      trigger_params = %{
        "idempotency_key" => idempotency_key,
        "user_id" => @alex_email,
        "email" => @alex_email,
        "kind" => "magic_link"
      }

      trigger_opts = [
        idempotency_key: idempotency_key,
        tenant_id: @tenant_id,
        correlation_id: correlation_id
      ]

      case Chimeway.trigger(Sigra.Integrations.Chimeway.MagicLinkNotifier, trigger_params, trigger_opts) do
        {:ok, result} ->
          event_id = result.trace.event_id
          delivery_ids = delivery_ids_for_event(event_id)

          {:ok,
           %{
             recipient_identity: @alex_email,
             trace: %{delivery_ids: delivery_ids, correlation_id: correlation_id}
           }}

        {:duplicate, _event} ->
          {:error, :duplicate_seed}

        {:error, _} = err ->
          err
      end
    else
      {:error, :sigra_not_available}
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
  def accrue_demo_identity, do: accrue_demo_email()

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

  defp notification_ids_for_seed(%{trace: %{event_id: event_id}}) do
    from(n in Notification,
      where: n.event_id == ^event_id and n.recipient_identity == ^alex_identity(),
      select: n.id
    )
    |> Repo.all()
  end

  defp delivery_ids_for_event(event_id) do
    from(d in Delivery,
      join: n in Notification,
      on: d.notification_id == n.id,
      where: n.event_id == ^event_id,
      select: d.id
    )
    |> Repo.all()
  end
end
