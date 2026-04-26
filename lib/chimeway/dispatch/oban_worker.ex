if Code.ensure_loaded?(Oban) do
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

    OSS Oban 2.21.1 has no `c:exhausted/1` callback. This worker uses an in-band
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

    @impl Oban.Worker
    def perform(%Oban.Job{
          args: %{"delivery_id" => delivery_id},
          attempt: attempt,
          max_attempts: max_attempts
        }) do
      delivery = Deliveries.get_delivery!(delivery_id)

      if delivery.status in Deliveries.terminal_states() do
        :ok
      else
        Telemetry.span(
          [:dispatch, :perform],
          Telemetry.safe_meta(%{
            delivery_id: delivery.id,
            channel: delivery.channel,
            notification_key: Map.get(delivery.metadata || %{}, "notification_key"),
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

        {:ok, :proceed} ->
          do_dispatch(delivery, attempt, max_attempts)
      end
    end

    defp do_dispatch(%Delivery{} = delivery, attempt, max_attempts) do
      case Executor.run_delivery(delivery) do
        {:ok, %{attempt: %DeliveryAttempt{} = recorded, delivery: %Delivery{} = updated}} ->
          map_outcome_to_oban_return(recorded, updated, attempt, max_attempts)

        {:error, step, reason, _changes} ->
          {:error, {step, reason}}

        {:error, _reason} = error ->
          error
      end
    end

    # Maps the recorded attempt outcome+error_class to an Oban perform/1 return value.
    #
    # - succeeded                                       -> :ok
    # - permanent/bounced (delivery already :cancelled) -> :ok (record_attempt converged)
    # - temporary AND attempt == max_attempts           -> exhaust_delivery + :ok
    # - temporary AND attempt < max_attempts            -> {:error, reason}
    defp map_outcome_to_oban_return(%DeliveryAttempt{outcome: :succeeded}, _delivery, _attempt, _max),
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

    # Catch-all defensive clause: an outcome shape we did not anticipate. Surface
    # the data to the caller so it shows up in Oban error telemetry.
    defp map_outcome_to_oban_return(%DeliveryAttempt{} = attempt, %Delivery{} = delivery, _attempt_n, _max) do
      {:error, {:unhandled_outcome, attempt.outcome, attempt.error_class, delivery.status}}
    end

    defp error_reason_from_attempt(%DeliveryAttempt{provider_response: provider_response}) do
      case provider_response do
        %{} = pr when map_size(pr) > 0 -> {:adapter_temporary, pr}
        _ -> :adapter_temporary
      end
    end
  end
end
