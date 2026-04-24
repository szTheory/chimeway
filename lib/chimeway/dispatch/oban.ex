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

    alias Chimeway.{DeliveryPlanning, Dispatch.ObanWorker, Repo}
    alias Chimeway.Telemetry

    @impl Chimeway.Dispatch
    def dispatch(notifications, opts) when is_list(notifications) do
      base_multi =
        case Keyword.get(opts, :multi, Ecto.Multi.new()) do
          %Ecto.Multi{} = multi -> multi
          _ -> Ecto.Multi.new()
        end

      multi =
        base_multi
        |> Ecto.Multi.run(:plan_notifications, fn _repo, _changes ->
          DeliveryPlanning.plan_notifications(notifications, opts)
        end)
        |> Ecto.Multi.run(:enqueue_jobs, fn _repo, %{plan_notifications: deliveries} ->
          deliveries
          |> Enum.filter(fn delivery -> delivery.status == :pending end)
          |> Enum.reduce_while({:ok, []}, fn delivery, {:ok, jobs} ->
            case enqueue_one(delivery) do
              {:ok, job} -> {:cont, {:ok, [job | jobs]}}
              {:error, reason} -> {:halt, {:error, reason}}
            end
          end)
          |> case do
            {:ok, jobs} -> {:ok, Enum.reverse(jobs)}
            {:error, reason} -> {:error, reason}
          end
        end)

      case Repo.transaction(multi) do
        {:ok, %{plan_notifications: deliveries}} ->
          {:ok, deliveries}

        {:error, :plan_notifications, reason, _changes} ->
          {:error, {:planning_failed, reason}}

        {:error, _step, reason, _changes} ->
          {:error, reason}
      end
    end

    defp enqueue_one(delivery) do
      Telemetry.span(
        [:dispatch, :enqueue],
        Telemetry.safe_meta(%{delivery_id: delivery.id}),
        fn ->
          result = Oban.insert(ObanWorker.new(%{delivery_id: delivery.id}))
          {result, %{}}
        end
      )
    end
  end
end
