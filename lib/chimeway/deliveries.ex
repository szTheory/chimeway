defmodule Chimeway.Deliveries do
  @moduledoc """
  Context module for delivery planning, attempt recording, and status transitions.

  Delivery rows are idempotent per (notification_id, channel). Attempt rows are
  append-only — each adapter call produces a new attempt row.
  """

  import Ecto.Changeset, only: [change: 2]
  import Ecto.Query, only: [from: 2]

  alias Chimeway.{Delivery, DeliveryAttempt, Repo}
  alias Chimeway.Telemetry
  alias Ecto.Multi

  @terminal_states [:succeeded, :suppressed, :cancelled]

  @doc """
  Returns the list of terminal delivery states — used by the dispatcher (Plan 02-02)
  to short-circuit dispatch for already-terminal deliveries.
  """
  def terminal_states, do: @terminal_states

  # General-path transitions. Note: `failed -> :cancelled` is INTENTIONALLY OMITTED here
  # even though :cancelled is a valid status — that transition is reserved for
  # Deliveries.exhaust_delivery/1 (D-10), which performs an out-of-band update
  # bypassing this table. The general transition_status/2 path must NOT permit
  # arbitrary callers to drive failed -> cancelled.
  @allowed_transitions %{
    pending: [:dispatched, :suppressed, :cancelled],
    dispatched: [:succeeded, :failed, :suppressed],
    failed: [:dispatched]
  }

  @doc """
  Plans a delivery row for the given notification_id and channel.
  Idempotent: duplicate calls on the same (notification_id, channel) create exactly one row.
  """
  @spec plan_delivery(binary(), atom() | binary()) ::
          {:ok, Delivery.t()} | {:error, Ecto.Changeset.t() | term()}
  @spec plan_delivery(binary(), atom() | binary(), keyword()) ::
          {:ok, Delivery.t()} | {:error, Ecto.Changeset.t() | term()}
  def plan_delivery(notification_id, channel, opts \\ [])

  def plan_delivery(notification_id, channel, opts) when is_list(opts) do
    channel_str = if is_atom(channel), do: Atom.to_string(channel), else: channel

    with {:ok, delay_fallback} <-
           normalize_delay_fallback(Keyword.get(opts, :delay_fallback, false)),
         {:ok, delayed_fallback_source} <-
           normalize_delayed_fallback_source(
             Keyword.get(opts, :delayed_fallback_source, :default)
           ) do
      metadata =
        opts
        |> Keyword.get(:metadata, %{})
        |> ensure_metadata_map()
        |> Map.put("delayed_fallback_source", delayed_fallback_source)
        |> maybe_put("notification_key", opts[:notification_key])
        |> maybe_put("event_id", opts[:event_id])
        |> maybe_put("correlation_id", opts[:correlation_id])

      result =
        %Delivery{}
        |> Delivery.changeset(%{
          notification_id: notification_id,
          channel: channel_str,
          status: :pending,
          delay_fallback: delay_fallback,
          metadata: metadata
        })
        |> Repo.insert(on_conflict: :nothing, conflict_target: [:notification_id, :channel])

      case result do
        {:ok, _} ->
          # Reload from DB: on_conflict: :nothing returns a phantom struct on conflict.
          # Always return the authoritative row with current status.
          {:ok, Repo.get_by!(Delivery, notification_id: notification_id, channel: channel_str)}

        error ->
          error
      end
    end
  end

  def plan_delivery(_notification_id, _channel, opts) do
    {:error, {:invalid_plan_delivery_opts, opts}}
  end

  defp normalize_delay_fallback(value) when is_boolean(value), do: {:ok, value}
  defp normalize_delay_fallback(value), do: {:error, {:invalid_delay_fallback, value}}

  defp normalize_orchestration_state(state)
       when state in [:ready, :deferred, :digest_held],
       do: {:ok, state}

  defp normalize_orchestration_state(state), do: {:error, {:invalid_orchestration_state, state}}

  defp normalize_optional_string(nil), do: {:ok, nil}
  defp normalize_optional_string(value) when is_binary(value) and byte_size(value) > 0, do: {:ok, value}
  defp normalize_optional_string(value), do: {:error, {:invalid_planning_reason, value}}

  defp normalize_optional_map(nil), do: {:ok, nil}
  defp normalize_optional_map(value) when is_map(value), do: {:ok, value}
  defp normalize_optional_map(value), do: {:error, {:invalid_planning_context, value}}

  defp normalize_optional_datetime(nil), do: {:ok, nil}
  defp normalize_optional_datetime(%DateTime{} = value), do: {:ok, value}
  defp normalize_optional_datetime(value), do: {:error, {:invalid_next_eligible_at, value}}

  defp normalize_delayed_fallback_source(:default), do: {:ok, "default"}
  defp normalize_delayed_fallback_source(:notifier), do: {:ok, "notifier"}
  defp normalize_delayed_fallback_source(:policy), do: {:ok, "policy"}
  defp normalize_delayed_fallback_source("default"), do: {:ok, "default"}
  defp normalize_delayed_fallback_source("notifier"), do: {:ok, "notifier"}
  defp normalize_delayed_fallback_source("policy"), do: {:ok, "policy"}

  defp normalize_delayed_fallback_source(value),
    do: {:error, {:invalid_delayed_fallback_source, value}}

  @doc """
  Fetches a delivery by ID, raising if not found.
  """
  @spec get_delivery!(binary()) :: Delivery.t()
  def get_delivery!(id), do: Repo.get!(Delivery, id)

  @doc """
  Transitions a delivery to a new status, respecting the allowed transition table.
  Returns {:error, {:invalid_transition, from: current, to: new}} for disallowed transitions.
  """
  @spec transition_status(Delivery.t(), atom()) :: {:ok, Delivery.t()} | {:error, term()}
  def transition_status(%Delivery{} = delivery, new_status) do
    allowed = Map.get(@allowed_transitions, delivery.status, [])

    if new_status in allowed do
      delivery
      |> change(status: new_status)
      |> Repo.update()
    else
      {:error, {:invalid_transition, from: delivery.status, to: new_status}}
    end
  end

  @doc """
  Transitions a delivery to :suppressed and persists the suppression_reason.
  """
  @spec suppress_delivery(Delivery.t(), atom()) :: {:ok, Delivery.t()} | {:error, term()}
  def suppress_delivery(%Delivery{} = delivery, reason) when is_atom(reason) do
    suppress_delivery(delivery, reason, [])
  end

  @doc """
  Transitions a delivery to :suppressed, persists suppression_reason, and records
  policy checkpoint metadata (`planning` or `perform`).
  """
  @spec suppress_delivery(Delivery.t(), atom(), keyword()) ::
          {:ok, Delivery.t()} | {:error, term()}
  def suppress_delivery(%Delivery{} = delivery, reason, opts)
      when is_atom(reason) and is_list(opts) do
    checkpoint =
      opts
      |> Keyword.get(:checkpoint, :perform)
      |> normalize_checkpoint()

    metadata =
      delivery.metadata
      |> ensure_metadata_map()
      |> Map.put("policy_checkpoint", checkpoint)

    delivery
    |> change(
      status: :suppressed,
      suppression_reason: Atom.to_string(reason),
      metadata: metadata
    )
    |> Repo.update()
  end

  @doc """
  Persists planning-time orchestration facts on the canonical delivery row.
  """
  @spec apply_planning_decision(Delivery.t(), map()) :: {:ok, Delivery.t()} | {:error, term()}
  def apply_planning_decision(%Delivery{} = delivery, decision) when is_map(decision) do
    with {:ok, state} <- normalize_orchestration_state(Map.get(decision, :orchestration_state, :ready)),
         {:ok, planning_reason} <- normalize_optional_string(Map.get(decision, :planning_reason)),
         {:ok, planning_context} <- normalize_optional_map(Map.get(decision, :planning_context)),
         {:ok, next_eligible_at} <- normalize_optional_datetime(Map.get(decision, :next_eligible_at)) do
      delivery
      |> change(%{
        orchestration_state: state,
        planning_reason: planning_reason,
        planning_context: planning_context,
        next_eligible_at: next_eligible_at
      })
      |> Repo.update()
    end
  end

  def apply_planning_decision(%Delivery{} = _delivery, decision),
    do: {:error, {:invalid_planning_decision, decision}}

  @doc """
  Transitions a `:failed` delivery to `:cancelled` with `suppression_reason: "retries_exhausted"`.

  This is the ONLY entry point for the `failed -> :cancelled` transition. The general
  `transition_status/2` path intentionally rejects `failed -> :cancelled` (the
  `@allowed_transitions` table has `failed: [:dispatched]` only). `exhaust_delivery/1`
  performs a direct `change/2 |> Repo.update()` that bypasses the transition table —
  exactly mirroring how `suppress_delivery/3` writes the `:suppressed` terminal state
  from any non-terminal status.

  Called from `Chimeway.Dispatch.ObanWorker.perform/1` when
  `job.attempt == job.max_attempts` and the adapter classification was `:temporary`
  (REL-03 D-10/D-11). Records `policy_checkpoint: "perform"` in metadata so traces
  preserve the explanation that exhaustion happened at perform time.
  """
  @spec exhaust_delivery(Delivery.t()) :: {:ok, Delivery.t()} | {:error, term()}
  def exhaust_delivery(%Delivery{status: :failed} = delivery) do
    metadata =
      delivery.metadata
      |> ensure_metadata_map()
      |> Map.put("policy_checkpoint", "perform")

    delivery
    |> change(
      status: :cancelled,
      suppression_reason: "retries_exhausted",
      metadata: metadata
    )
    |> Repo.update()
  end

  def exhaust_delivery(%Delivery{status: status}),
    do: {:error, {:invalid_exhaust_from, status}}

  @doc """
  Atomically inserts an attempt row and transitions the delivery status.

  Returns `{:ok, %{delivery: updated_delivery, attempt: attempt}}` on success, or
  `{:error, step, reason, changes}` if any step fails (both operations roll back).

  ## Phase 14 contract additions

  - Acquires a `SELECT ... FOR UPDATE` row lock on the delivery via the
    `:lock_delivery` Multi step BEFORE computing `attempt_number` (W8 preemptive
    fix). This serializes concurrent `record_attempt/2` callers for the same
    delivery and makes `attempt_number` contiguity invariant under concurrent
    execution. The `pending -> dispatched` transition that
    `Executor.run_delivery/1` performs BEFORE calling this function is a secondary
    serialization layer.
  - Computes `attempt_number` inside the Multi via the `:next_attempt_number` step
    (RESEARCH Pattern 4).
  - Routes `error_class` permanent/bounced outcomes to `:cancelled` with the
    appropriate `suppression_reason` inside the same transaction (RESEARCH
    Pitfall 2). This makes sync and Oban paths converge on a terminal state
    without forking — sync gains REL-03 convergence automatically.
  - Telemetry stop metadata now includes `attempt_number` and `error_class`,
    preserving the Phase 10 correlation_id/notification_key keys.
  """
  @spec record_attempt(Delivery.t(), map()) ::
          {:ok, %{delivery: Delivery.t(), attempt: DeliveryAttempt.t()}}
          | {:error, atom(), term(), map()}
  def record_attempt(%Delivery{} = delivery, attrs) do
    Telemetry.span(
      [:attempts, :record],
      Telemetry.safe_meta(%{
        delivery_id: delivery.id,
        channel: delivery.channel,
        notification_key: Map.get(delivery.metadata || %{}, "notification_key")
      }),
      fn ->
        result = do_record_attempt(delivery, attrs)

        extra =
          case result do
            {:ok, %{attempt: attempt}} ->
              Telemetry.safe_meta(%{
                attempt_id: attempt.id,
                outcome: attempt.outcome,
                attempt_number: attempt.attempt_number,
                error_class: attempt.error_class
              })

            _ ->
              %{}
          end

        {result, extra}
      end
    )
  end

  defp do_record_attempt(%Delivery{} = delivery, attrs) do
    outcome = Map.get(attrs, :outcome) || Map.get(attrs, "outcome")
    error_class = Map.get(attrs, :error_class) || Map.get(attrs, "error_class")

    safe_attrs =
      attrs
      |> coerce_provider_response_to_atom_key()
      |> Map.update(:provider_response, nil, &sanitize_metadata/1)
      |> Map.put(:delivery_id, delivery.id)

    Multi.new()
    |> Multi.run(:lock_delivery, fn repo, _changes ->
      # W8 preemptive fix: SELECT FOR UPDATE serializes concurrent
      # record_attempt/2 callers for the same delivery_id. With this lock,
      # attempt_number contiguity is invariant under concurrent execution.
      case repo.one(from(d in Delivery, where: d.id == ^delivery.id, lock: "FOR UPDATE")) do
        nil -> {:error, :delivery_not_found}
        locked -> {:ok, locked}
      end
    end)
    |> Multi.run(:next_attempt_number, fn repo, %{lock_delivery: locked} ->
      next_n =
        from(a in DeliveryAttempt,
          where: a.delivery_id == ^locked.id,
          select: count(a.id)
        )
        |> repo.one()
        |> Kernel.+(1)

      {:ok, next_n}
    end)
    |> Multi.insert(:attempt, fn %{next_attempt_number: n, lock_delivery: locked} ->
      attempt_attrs =
        safe_attrs
        |> Map.put(:delivery_id, locked.id)
        |> Map.put(:attempt_number, n)

      DeliveryAttempt.changeset(%DeliveryAttempt{}, attempt_attrs)
    end)
    |> Multi.run(:delivery, fn _repo, %{lock_delivery: locked} ->
      terminal_or_failed_transition(locked, outcome, error_class)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{delivery: updated_delivery, attempt: attempt}} ->
        {:ok, %{delivery: updated_delivery, attempt: attempt}}

      {:error, step, reason, changes} ->
        {:error, step, reason, changes}
    end
  end

  defp coerce_provider_response_to_atom_key(attrs) do
    case Map.pop(attrs, "provider_response") do
      {nil, attrs} -> attrs
      {val, attrs} -> Map.put_new(attrs, :provider_response, val)
    end
  end

  # Maps outcome + error_class to the next delivery status. Permanent/bounced go
  # straight to :cancelled (sync and Oban both converge here). Temporary stays at
  # :failed so Oban can retry. Succeeded transitions normally.
  defp terminal_or_failed_transition(delivery, :succeeded, _error_class),
    do: transition_status(delivery, :succeeded)

  defp terminal_or_failed_transition(delivery, "succeeded", _error_class),
    do: transition_status(delivery, :succeeded)

  defp terminal_or_failed_transition(delivery, _outcome, "permanent"),
    do: cancel_with_reason(delivery, "permanent_failure")

  defp terminal_or_failed_transition(delivery, _outcome, "bounced"),
    do: cancel_with_reason(delivery, "bounced")

  defp terminal_or_failed_transition(delivery, _outcome, _error_class),
    do: transition_status(delivery, :failed)

  # Direct cancel write for permanent/bounced terminal convergence.
  # Bypasses @allowed_transitions because dispatched -> :cancelled is not in the
  # table; mirrors the suppress_delivery/3 + exhaust_delivery/1 named-helper idiom.
  # The explicit suppression_reason ("permanent_failure" or "bounced") is the
  # durable explanation operators see in traces.
  defp cancel_with_reason(%Delivery{} = delivery, reason) when is_binary(reason) do
    metadata =
      delivery.metadata
      |> ensure_metadata_map()
      |> Map.put("policy_checkpoint", "perform")

    delivery
    |> change(
      status: :cancelled,
      suppression_reason: reason,
      metadata: metadata
    )
    |> Repo.update()
  end

  @sensitive_keys ~w(password token secret)

  defp sanitize_metadata(map) when is_map(map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      if sensitive_key?(key), do: acc, else: Map.put(acc, key, value)
    end)
  end

  defp sanitize_metadata(_), do: %{}

  defp ensure_metadata_map(map) when is_map(map), do: map
  defp ensure_metadata_map(_), do: %{}

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp normalize_checkpoint(:planning), do: "planning"
  defp normalize_checkpoint(:perform), do: "perform"
  defp normalize_checkpoint("planning"), do: "planning"
  defp normalize_checkpoint("perform"), do: "perform"
  defp normalize_checkpoint(_), do: "perform"

  defp sensitive_key?(key) when is_atom(key), do: sensitive_key?(Atom.to_string(key))
  defp sensitive_key?(key) when is_binary(key), do: String.downcase(key) in @sensitive_keys
  defp sensitive_key?(_), do: false
end
