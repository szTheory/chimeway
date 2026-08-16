if Code.ensure_loaded?(Oban) do
  defmodule Chimeway.Dispatch.DeferredResumeWorker do
    @moduledoc """
    Oban worker that resumes a deferred delivery row and enqueues the canonical
    delivery performer in the same transaction.

    Job args contain the durable `delivery_id` and its owning `tenant_id`. Deferred
    scheduling facts stay on the delivery row, and actual send execution remains owned by
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
    def perform(%Oban.Job{args: %{"delivery_id" => delivery_id, "tenant_id" => tenant_id}}) do
      Multi.new()
      |> Multi.run(:resume_delivery, resume_delivery_step(delivery_id, tenant_id))
      |> Multi.run(:dispatch_job, &dispatch_job_step/2)
      |> Repo.transaction()
      |> normalize_transaction_result()
    end

    def perform(%Oban.Job{args: %{"delivery_id" => _delivery_id}}),
      do: {:error, :tenant_scope_required}

    defp resume_delivery_step(delivery_id, tenant_id) do
      fn _repo, _changes ->
        delivery_id
        |> Deliveries.resume_deferred_delivery(tenant_id: tenant_id, source: "oban_scheduler")
        |> normalize_resume_result()
      end
    end

    defp normalize_resume_result({:ok, delivery}), do: {:ok, {:resumed, delivery}}
    defp normalize_resume_result({:noop, delivery}), do: {:ok, {:noop, delivery}}

    defp dispatch_job_step(_repo, %{resume_delivery: {:resumed, delivery}}) do
      delivery.id
      |> build_dispatch_job()
      |> Oban.insert()
    end

    defp dispatch_job_step(_repo, %{resume_delivery: {:noop, _delivery}}), do: {:ok, nil}

    defp build_dispatch_job(delivery_id), do: ObanWorker.new(%{delivery_id: delivery_id})

    defp normalize_transaction_result({:ok, _changes}), do: :ok
    defp normalize_transaction_result({:error, _step, reason, _changes}), do: {:error, reason}
  end
end
