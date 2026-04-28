if Code.ensure_loaded?(Oban) do
  defmodule Chimeway.Dispatch.Oban do
    @moduledoc """
    Oban-backed dispatcher — satisfies `Chimeway.Dispatch` behaviour.

    Configure via:

        config :chimeway, :dispatcher, Chimeway.Dispatch.Oban

    Each notification produces one `Chimeway.Dispatch.ObanWorker` job per
    delivery row. The queue is `:chimeway_delivery`.

    ## Transactional enqueue

    Pass `multi: %Ecto.Multi{}` to `dispatch/2` to insert job rows inside the
    same database transaction as the delivery rows:

        dispatcher.dispatch(notifications, multi: existing_multi)

    When `:multi` is absent, jobs are inserted via direct `Oban.insert/2`.

    ## Runtime validation

    If `:dispatcher` is configured as `Chimeway.Dispatch.Oban` but Oban is not
    loaded, the dispatch call will fail at runtime with a clear error. Add Oban
    as a non-optional dependency in your host application to avoid this.
    """

    @behaviour Chimeway.Dispatch

    alias Chimeway.{DeliveryPlanning, Dispatch.DeferredResumeWorker, Dispatch.ObanWorker, Repo}
    alias Chimeway.Telemetry
    alias Ecto.Multi

    @impl Chimeway.Dispatch
    def dispatch(notifications, opts) when is_list(notifications) do
      base_multi =
        case Keyword.get(opts, :multi, Multi.new()) do
          %Multi{} = multi -> multi
          _ -> Multi.new()
        end

      multi =
        base_multi
        |> Multi.run(:plan_notifications, &do_plan(notifications, opts, &1, &2))
        |> Multi.run(:enqueue_jobs, &do_enqueue(&1, &2))

      handle_transaction_result(Repo.transaction(multi))
    end

    @impl Chimeway.Dispatch
    def dispatch_delivery(%{id: _id} = delivery, _opts) do
      enqueue_delivery(delivery)
      |> normalize_dispatch_delivery_result(delivery)
    end

    def dispatch_delivery(delivery_id, _opts) when is_binary(delivery_id) do
      delivery = Chimeway.Deliveries.get_delivery!(delivery_id)
      dispatch_delivery(delivery, [])
    end

    defp do_plan(notifications, opts, _repo, _changes) do
      DeliveryPlanning.plan_notifications(notifications, opts)
    end

    defp do_enqueue(_repo, %{plan_notifications: deliveries}) do
      deliveries
      |> Enum.reduce_while({:ok, []}, fn delivery, {:ok, jobs} ->
        case enqueue_delivery(delivery) do
          {:skip, _delivery} -> {:cont, {:ok, jobs}}
          {:ok, job} -> {:cont, {:ok, [job | jobs]}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
      |> case do
        {:ok, jobs} -> {:ok, Enum.reverse(jobs)}
        {:error, reason} -> {:error, reason}
      end
    end

    defp handle_transaction_result({:ok, %{plan_notifications: deliveries}}),
      do: {:ok, deliveries}

    defp handle_transaction_result({:error, :plan_notifications, reason, _changes}) do
      {:error, {:planning_failed, reason}}
    end

    defp handle_transaction_result({:error, _step, reason, _changes}), do: {:error, reason}

    defp enqueue_delivery(%{status: :pending, orchestration_state: :ready} = delivery) do
      enqueue_job(delivery, ObanWorker.new(%{delivery_id: delivery.id}))
    end

    defp enqueue_delivery(
           %{
             status: :pending,
             orchestration_state: :deferred,
             next_eligible_at: %DateTime{}
           } = delivery
         ) do
      job =
        DeferredResumeWorker.new(
          %{delivery_id: delivery.id},
          scheduled_at: delivery.next_eligible_at
        )

      enqueue_job(delivery, job)
    end

    defp enqueue_delivery(delivery), do: {:skip, delivery}

    defp normalize_dispatch_delivery_result({:ok, _job}, delivery), do: {:ok, delivery}
    defp normalize_dispatch_delivery_result({:skip, delivery}, _original), do: {:skip, delivery}
    defp normalize_dispatch_delivery_result({:error, reason}, _delivery), do: {:error, reason}

    defp enqueue_job(delivery, job) do
      Telemetry.span(
        [:dispatch, :enqueue],
        Telemetry.safe_meta(%{
          delivery_id: delivery.id,
          channel: delivery.channel,
          notification_key: Map.get(delivery.metadata || %{}, "notification_key")
        }),
        fn ->
          result = Oban.insert(job)
          {result, %{}}
        end
      )
    end
  end
end
