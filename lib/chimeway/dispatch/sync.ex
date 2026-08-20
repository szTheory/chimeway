defmodule Chimeway.Dispatch.Sync do
  @moduledoc """
  Synchronous dispatcher — runs the full delivery pipeline in the calling process.

  Pipeline per delivery:
  1. Terminal state guard — skip if already succeeded/suppressed/cancelled.
  2. Transition delivery to :dispatched (must succeed before adapter is called).
  3. Resolve adapter module from config.
  4. Call adapter.deliver/2.
  5. Classify outcome (dispatcher responsibility, not adapter's).
  6. Record attempt + transition to final status atomically.

  Swap to `Chimeway.Dispatch.Oban` in Phase 3 via config:

      config :chimeway, :dispatcher, Chimeway.Dispatch.Oban
  """

  @behaviour Chimeway.Dispatch

  alias Chimeway.{Deliveries, DeliveryPlanning, DeliveryTargets}
  alias Chimeway.Dispatch.Executor
  alias Chimeway.Policy
  alias Chimeway.Telemetry

  @impl Chimeway.Dispatch
  def dispatch(notifications, opts) when is_list(notifications) do
    notifications
    |> Enum.reduce_while({:ok, []}, fn notification, {:ok, acc} ->
      case dispatch_notification(notification, opts) do
        {:ok, results} -> {:cont, {:ok, [results | acc]}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, grouped_results} -> {:ok, grouped_results |> Enum.reverse() |> List.flatten()}
      {:error, _reason} = error -> error
    end
  end

  @impl Chimeway.Dispatch
  def dispatch_delivery(%{id: _id} = delivery, _opts) do
    dispatch_planned_delivery(delivery)
  end

  def dispatch_delivery(delivery_id, _opts) when is_binary(delivery_id) do
    delivery_id
    |> Deliveries.get_delivery!()
    |> dispatch_planned_delivery()
  end

  defp dispatch_notification(notification, opts) do
    case DeliveryPlanning.plan_notification(notification, opts) do
      {:ok, deliveries} ->
        {:ok, Enum.map(deliveries, &dispatch_planned_delivery/1)}

      {:error, reason} ->
        planning_failed(reason)
    end
  end

  # --- Private ---

  defp dispatch_planned_delivery(%{status: :suppressed} = delivery), do: {:ok, delivery}
  defp dispatch_planned_delivery(%{status: :digested} = delivery), do: {:skip, delivery}

  defp dispatch_planned_delivery(%{orchestration_state: state} = delivery) when state != :ready,
    do: {:skip, delivery}

  defp dispatch_planned_delivery(delivery), do: dispatch_delivery(delivery)

  defp dispatch_delivery(%{status: status} = delivery) do
    if status in Deliveries.terminal_states() do
      {:ok, delivery}
    else
      case Policy.evaluate(delivery, check_read_state: delivery.delay_fallback) do
        {:suppress, reason} ->
          Deliveries.suppress_delivery(delivery, reason, checkpoint: :perform)

        {:ok, :proceed} ->
          do_dispatch_with_telemetry(delivery)
      end
    end
  end

  defp do_dispatch_with_telemetry(delivery) do
    Telemetry.span(
      [:dispatch, :sync],
      Telemetry.safe_meta(%{
        delivery_id: delivery.id,
        channel: delivery.channel,
        notification_key: Map.get(delivery.metadata || %{}, "notification_key"),
        correlation_id: Map.get(delivery.metadata || %{}, "correlation_id")
      }),
      fn ->
        # D-22: do_dispatch/1 now returns {result, adapter_module} so the stop-meta
        # closure can include adapter_module without a second DB round-trip.
        {result, adapter_module} = do_dispatch(delivery)
        outcome = if match?({:ok, _}, result), do: :succeeded, else: :failed

        stop_meta =
          Telemetry.safe_meta(%{
            outcome: outcome,
            # D-22: nil for failed transitions or pre-Phase-29 attempts; safe_meta/1
            # uses Map.take/2 which preserves nil values for allowed keys.
            adapter_module: adapter_module
          })

        {result, stop_meta}
      end
    )
  end

  defp do_dispatch(delivery) do
    result =
      if delivery.channel == "push",
        do: run_push_targets(delivery),
        else: Executor.run_delivery(delivery)

    case result do
      {:ok, %{delivery: updated_delivery, attempt: attempt}} ->
        # D-22: thread adapter_module up to the sync,:stop telemetry metadata.
        {{:ok, updated_delivery}, Map.get(attempt, :adapter_module)}

      {:ok, %{delivery: updated_delivery}} ->
        # Defensive: attempt key missing from the executor return shape.
        {{:ok, updated_delivery}, nil}

      {:error, step, reason, _changes} ->
        {{:error, {step, reason}}, nil}

      {:error, _reason} = error ->
        {error, nil}

      {:noop, _reason} ->
        {{:ok, delivery}, nil}
    end
  end

  defp run_push_targets(delivery) do
    delivery
    |> DeliveryTargets.actionable_targets()
    |> Enum.reduce(nil, fn target, first_error ->
      case Executor.run_target(delivery, target_id: target.id, source: "sync") do
        {:error, reason} when is_nil(first_error) -> reason
        _result -> first_error
      end
    end)
    |> reload_push_parent(delivery)
  end

  defp reload_push_parent(first_error, delivery) do
    case DeliveryTargets.recompute_delivery(delivery, delivery.tenant_id) do
      {:ok, %{status: :succeeded} = updated_delivery} -> {:ok, %{delivery: updated_delivery}}
      {:ok, %{status: :suppressed} = updated_delivery} -> {:ok, %{delivery: updated_delivery}}
      {:ok, updated_delivery} when is_nil(first_error) -> {:ok, %{delivery: updated_delivery}}
      {:ok, _updated_delivery} -> {:error, first_error}
      {:error, reason} -> {:error, reason}
    end
  end

  defp planning_failed(reason), do: {:error, {:planning_failed, reason}}
end
