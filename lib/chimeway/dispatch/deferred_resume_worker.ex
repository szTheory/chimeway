if Code.ensure_loaded?(Oban) do
  defmodule Chimeway.Dispatch.DeferredResumeWorker do
    @moduledoc """
    Oban worker that resumes a deferred delivery row and enqueues the canonical
    delivery performer in the same transaction.

    Job args contain only `delivery_id`. Deferred scheduling facts stay on the
    delivery row, and actual send execution remains owned by
    `Chimeway.Dispatch.ObanWorker`.
    """

    use Oban.Worker,
      queue: :chimeway_delivery,
      max_attempts: 5,
      replace: [scheduled: [:scheduled_at]],
      unique: [fields: [:args], keys: [:delivery_id], period: 60, timestamp: :scheduled_at]

    alias Chimeway.{Deliveries, Repo}
    alias Chimeway.Dispatch.ObanWorker
    alias Ecto.Multi

    @impl Oban.Worker
    def perform(%Oban.Job{args: %{"delivery_id" => delivery_id}}) do
      Multi.new()
      |> Multi.run(:resume_delivery, fn _repo, _changes ->
        case Deliveries.resume_deferred_delivery(delivery_id, source: "oban_scheduler") do
          {:ok, delivery} -> {:ok, {:resumed, delivery}}
          {:noop, delivery} -> {:ok, {:noop, delivery}}
        end
      end)
      |> Multi.run(:dispatch_job, fn _repo, %{resume_delivery: resume_delivery} ->
        case resume_delivery do
          {:resumed, delivery} -> Oban.insert(ObanWorker.new(%{delivery_id: delivery.id}))
          {:noop, _delivery} -> {:ok, nil}
        end
      end)
      |> Repo.transaction()
      |> case do
        {:ok, _changes} -> :ok
        {:error, _step, reason, _changes} -> {:error, reason}
      end
    end
  end
end
