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

    alias Chimeway.{Deliveries, Dispatch.ObanWorker, Repo}
    alias Chimeway.Telemetry

    @impl Chimeway.Dispatch
    def dispatch(notifications, opts) when is_list(notifications) do
      multi_opt = Keyword.get(opts, :multi)

      deliveries =
        Enum.flat_map(notifications, fn notification ->
          case Deliveries.plan_delivery(notification.id, :in_app) do
            {:ok, delivery} -> [delivery]
            {:error, _} -> []
          end
        end)

      case enqueue_deliveries(deliveries, multi_opt) do
        :ok -> {:ok, deliveries}
        {:error, reason} -> {:error, reason}
      end
    end

    defp enqueue_deliveries(deliveries, nil) do
      Enum.reduce_while(deliveries, :ok, fn delivery, :ok ->
        case enqueue_one(delivery) do
          {:ok, _job} -> {:cont, :ok}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
    end

    defp enqueue_deliveries(deliveries, multi) when is_struct(multi, Ecto.Multi) do
      multi_with_jobs =
        Enum.reduce(deliveries, multi, fn delivery, acc ->
          job_name = String.to_atom("enqueue_delivery_#{delivery.id}")
          Oban.insert(acc, job_name, ObanWorker.new(%{delivery_id: delivery.id}))
        end)

      case Repo.transaction(multi_with_jobs) do
        {:ok, _changes} -> :ok
        {:error, _step, reason, _changes} -> {:error, reason}
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
