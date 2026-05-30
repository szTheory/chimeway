if Code.ensure_loaded?(Oban) do
  defmodule Chimeway.Dispatch.UnhandledOutcomeError do
    @moduledoc """
    Raised by `Chimeway.Dispatch.ObanWorker` when `map_outcome_to_oban_return/4`
    encounters a (outcome, error_class, status) shape that none of the documented
    clauses match AND the in-band convergence guard cannot legally fire (delivery
    is not in :failed status, or this is not the final attempt). This is the
    loud-failure branch of the BL-02 fix — see Plan 14-10.

    The exception carries enough metadata for an operator to reproduce the
    scenario and extend either `Executor.classify/1` or the documented worker
    clauses.
    """
    defexception [
      :message,
      :delivery_id,
      :outcome,
      :error_class,
      :status,
      :attempt,
      :max_attempts
    ]

    @impl true
    def exception(opts) do
      delivery_id = Keyword.fetch!(opts, :delivery_id)
      outcome = Keyword.fetch!(opts, :outcome)
      error_class = Keyword.fetch!(opts, :error_class)
      status = Keyword.fetch!(opts, :status)
      attempt = Keyword.fetch!(opts, :attempt)
      max_attempts = Keyword.fetch!(opts, :max_attempts)

      message =
        "unhandled delivery outcome shape (BL-02): " <>
          "delivery_id=#{inspect(delivery_id)} outcome=#{inspect(outcome)} " <>
          "error_class=#{inspect(error_class)} status=#{inspect(status)} " <>
          "attempt=#{attempt}/#{max_attempts}"

      %__MODULE__{
        message: message,
        delivery_id: delivery_id,
        outcome: outcome,
        error_class: error_class,
        status: status,
        attempt: attempt,
        max_attempts: max_attempts
      }
    end
  end

  defmodule Chimeway.Dispatch.ObanWorker do
    @moduledoc """
    Oban worker that performs a single Chimeway delivery by delivery_id.

    Job args contain only `delivery_id` (UUID string). Full payload is never
    stored in Oban job args — the delivery row is the source of truth.

    ## Transactional enqueue

    Insert this worker's job inside the same `Ecto.Multi` as delivery row creation:

        alias Chimeway.Dispatch.ObanWorker

        Ecto.Multi.new()
        |> Ecto.Multi.insert(:delivery, delivery_changeset)
        |> Oban.insert(:job, ObanWorker.new(%{delivery_id: delivery.id}))
        |> Chimeway.Repo.transaction()

    Rolling back the `Ecto.Multi` also rolls back the job — no orphaned jobs.

    ## Idempotency and terminal-state short-circuit

    The worker checks delivery terminal states (via `Chimeway.Deliveries.terminal_states/0`)
    on every execution. A delivery already in `:succeeded`, `:suppressed`, or `:cancelled`
    returns `:ok` immediately with no adapter call and no new attempt row.

    ## Phase 14 retry contract (REL-02 / REL-03)

    OSS Oban 2.21.1 has no exhausted callback. This worker uses an in-band
    `attempt == max_attempts` guard inside `perform/1` to know when it has reached
    the final retry — that is the moment the durable `:cancelled retries_exhausted`
    state is written via `Deliveries.exhaust_delivery/1`.

    Return-value contract:

    - Successful delivery -> `:ok`.
    - Permanent / bounced failure -> `:ok` (record_attempt already converged the
      delivery to `:cancelled` with the appropriate suppression_reason; Oban does
      not retry).
    - Transient failure with retries remaining (`attempt < max_attempts`) ->
      `{:error, reason}`; Oban schedules a retry under its default exponential-
      with-jitter `c:Oban.Worker.backoff/1`.
    - Transient failure on the final attempt (`attempt == max_attempts`) ->
      `Deliveries.exhaust_delivery/1` writes the `:cancelled retries_exhausted`
      terminal state, then this function returns `:ok` so the Oban job is marked
      `:completed` instead of `:discarded` (RESEARCH Pitfall 1: keeps operator
      telemetry dashboards clean — the durable explanation lives on the delivery
      row, not on the Oban job).
    """

    use Oban.Worker,
      queue: :chimeway_delivery,
      max_attempts: 5,
      unique: [fields: [:args], keys: [:delivery_id], period: 60]

    alias Chimeway.{Deliveries, Delivery, DeliveryAttempt, Policy}
    alias Chimeway.Dispatch.Executor
    alias Chimeway.Telemetry

    require Logger

    @impl Oban.Worker
    def perform(%Oban.Job{
          args: %{"delivery_id" => delivery_id},
          attempt: attempt,
          max_attempts: max_attempts
        }) do
      delivery = Deliveries.get_delivery!(delivery_id)

      if delivery.status in Deliveries.terminal_states() or delivery.orchestration_state != :ready do
        :ok
      else
        Telemetry.span(
          [:dispatch, :perform],
          Telemetry.safe_meta(%{
            delivery_id: delivery.id,
            channel: delivery.channel,
            notification_key: Map.get(delivery.metadata || %{}, "notification_key"),
            correlation_id: Map.get(delivery.metadata || %{}, "correlation_id"),
            attempt: attempt,
            max_attempts: max_attempts
          }),
          fn ->
            result = handle_delivery(delivery, attempt, max_attempts)
            {result, %{}}
          end
        )
      end
    end

    defp handle_delivery(%Delivery{} = delivery, attempt, max_attempts) do
      case Policy.evaluate(delivery, check_read_state: delivery.delay_fallback) do
        {:suppress, reason} ->
          case Deliveries.suppress_delivery(delivery, reason, checkpoint: :perform) do
            {:ok, _} -> :ok
            {:error, _} = err -> err
          end

        {:defer, decision} ->
          handle_deferred_delivery(delivery, decision, attempt, max_attempts)

        {:ok, :proceed} ->
          do_dispatch(delivery, attempt, max_attempts)
      end
    end

    defp handle_deferred_delivery(%Delivery{} = delivery, decision, attempt, max_attempts) do
      with {:ok, updated_delivery} <- Deliveries.apply_planning_decision(delivery, decision) do
        case updated_delivery do
          %Delivery{orchestration_state: :ready} ->
            do_dispatch(updated_delivery, attempt, max_attempts)

          %Delivery{} ->
            if updated_delivery.status in Deliveries.terminal_states() do
              :ok
            else
              case configured_dispatcher().dispatch_delivery(
                     updated_delivery,
                     pre_planned: true,
                     post_commit: true
                   ) do
                {:ok, _delivery} -> :ok
                {:skip, _delivery} -> :ok
                {:error, reason} -> {:error, {:deferred_handoff_failed, reason}}
              end
            end
        end
      end
    end

    defp do_dispatch(%Delivery{id: id}, attempt, max_attempts) do
      fresh = Deliveries.get_delivery!(id)

      if fresh.status in Deliveries.terminal_states() do
        :ok
      else
        case Executor.run_delivery(fresh) do
          {:ok, %{attempt: %DeliveryAttempt{} = recorded, delivery: %Delivery{} = updated}} ->
            map_outcome_to_oban_return(recorded, updated, attempt, max_attempts)

          {:error, step, reason, _changes} ->
            {:error, {step, reason}}

          {:error, _reason} = error ->
            error
        end
      end
    end

    # Maps the recorded attempt outcome+error_class to an Oban perform/1 return value.
    #
    # - succeeded                                       -> :ok
    # - permanent/bounced (delivery already :cancelled) -> :ok (record_attempt converged)
    # - temporary AND attempt == max_attempts           -> exhaust_delivery + :ok
    # - temporary AND attempt < max_attempts            -> {:error, reason}
    defp map_outcome_to_oban_return(
           %DeliveryAttempt{outcome: :succeeded},
           _delivery,
           _attempt,
           _max
         ),
         do: :ok

    defp map_outcome_to_oban_return(
           %DeliveryAttempt{error_class: error_class},
           %Delivery{status: :cancelled},
           _attempt,
           _max
         )
         when error_class in ["permanent", "bounced"] do
      # record_attempt already wrote :cancelled with suppression_reason
      # "permanent_failure" or "bounced". No retry. Return :ok so Oban completes.
      :ok
    end

    defp map_outcome_to_oban_return(
           %DeliveryAttempt{error_class: "temporary"} = recorded,
           %Delivery{status: :failed} = delivery,
           attempt,
           max_attempts
         ) do
      reason = error_reason_from_attempt(recorded)

      if attempt >= max_attempts do
        # In-band exhaustion guard (RESEARCH Pattern 2 / Pitfall 1).
        # Write the durable terminal state, then return :ok so the Oban job is
        # marked :completed rather than :discarded.
        case Deliveries.exhaust_delivery(delivery) do
          {:ok, _exhausted} -> :ok
          {:error, exhaust_reason} -> {:error, {:exhaust_failed, exhaust_reason, reason}}
        end
      else
        # Retry under the documented Oban budget. Default backoff curve applies.
        {:error, reason}
      end
    end

    # Catch-all defensive clause (BL-02 fix). Two branches:
    #   Branch A (convergence): if this is the final attempt AND the delivery is in
    #     :failed, call exhaust_delivery/1 to land the durable :cancelled
    #     retries_exhausted state. Returns :ok so Oban marks the job :completed.
    #   Branch B (loud failure): otherwise, log + raise. The unexpected shape is
    #     a real bug (either Executor.classify/1 grew a new return shape that the
    #     documented map_outcome_to_oban_return clauses do not cover, or some
    #     adapter return path bypassed classification). Surface it loudly so the
    #     operator notices instead of silently leaking a non-terminal delivery row.
    defp map_outcome_to_oban_return(
           %DeliveryAttempt{} = recorded,
           %Delivery{} = delivery,
           attempt_n,
           max
         ) do
      if attempt_n >= max and delivery.status == :failed do
        # Branch A: convergence — mirror the temporary/exhaustion path.
        case Deliveries.exhaust_delivery(delivery) do
          {:ok, _exhausted} ->
            :ok

          {:error, exhaust_reason} ->
            {:error,
             {:exhaust_failed, exhaust_reason,
              {:unhandled_outcome, recorded.outcome, recorded.error_class, delivery.status}}}
        end
      else
        # Branch B: loud failure — the convergence helper cannot legally write
        # from this state, OR we still have retries to burn but the shape is wrong.
        # Either way the catch-all itself is the bug; raise so the contract violation
        # is impossible to miss.
        Logger.error(
          "unhandled delivery outcome (BL-02): delivery_id=#{inspect(delivery.id)} " <>
            "outcome=#{inspect(recorded.outcome)} error_class=#{inspect(recorded.error_class)} " <>
            "status=#{inspect(delivery.status)} attempt=#{attempt_n}/#{max}"
        )

        raise Chimeway.Dispatch.UnhandledOutcomeError,
          delivery_id: delivery.id,
          outcome: recorded.outcome,
          error_class: recorded.error_class,
          status: delivery.status,
          attempt: attempt_n,
          max_attempts: max
      end
    end

    defp error_reason_from_attempt(%DeliveryAttempt{provider_response: provider_response}) do
      case provider_response do
        %{} = pr when map_size(pr) > 0 -> {:adapter_temporary, pr}
        _ -> :adapter_temporary
      end
    end

    defp configured_dispatcher do
      Application.get_env(:chimeway, :dispatcher, Chimeway.Dispatch.Sync)
    end
  end
end
