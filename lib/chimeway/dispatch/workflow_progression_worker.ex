if Code.ensure_loaded?(Oban) do
  defmodule Chimeway.Dispatch.WorkflowProgressionWorker do
    @moduledoc """
    Oban worker that wakes a due waiting workflow run by stable id.

    Job args contain only `workflow_run_id` per Phase 25 D-10. All
    correctness — row locking, due/anchor evaluation, branch resolution,
    next-step emission, and noop semantics — lives behind the shared
    `Chimeway.Workflows.Progression.progress_run/2` seam, so non-Oban hosts
    that drive progression manually through `progress_due_runs/1` and
    Oban-backed hosts that wake runs through this worker share identical
    internal semantics.

    Threats covered:

      * **T-25-07 (spoofing):** the worker accepts only `workflow_run_id` and
        reloads all workflow/delivery truth from Chimeway-owned rows before
        acting. Job args never carry rule data, delivery facts, or tenancy
        hints that could be tampered with mid-flight.
      * **T-25-08 (DoS / duplicate emission):** the worker delegates to the
        same `FOR UPDATE`-locked engine path that `progress_due_runs/1`
        uses, so duplicate jobs and concurrent retries collapse to noop
        without emitting another next-step delivery.
      * **T-25-09 (repudiation):** the engine persists transition reasons,
        anchor facts, and curated workflow outcomes durably before any
        advancement, so retries leave an auditable trail in
        `chimeway_workflow_transitions` rather than queue archaeology.
    """

    use Oban.Worker,
      queue: :chimeway_delivery,
      max_attempts: 5,
      replace: [scheduled: [:scheduled_at]],
      unique: [
        fields: [:args],
        keys: [:workflow_run_id],
        period: 60,
        timestamp: :scheduled_at
      ]

    alias Chimeway.Workflows.Progression

    @impl Oban.Worker
    def perform(%Oban.Job{args: %{"workflow_run_id" => workflow_run_id}})
        when is_binary(workflow_run_id) do
      # Delegate everything to the shared engine seam. `progress_run/2` opens
      # its own `Repo.transaction/1` and takes `FOR UPDATE` row locks on the
      # workflow run and the active-step delivery, so the worker stays thin
      # and never wraps the engine in another transaction (nested
      # transactions would surface internal `Repo.rollback/1` calls — used
      # by the engine for `:workflow_run_not_found` and similar — as
      # `MULTIPLE_ROLLBACK` errors at the queue boundary). Following the
      # `Chimeway.Dispatch.DigestFlushWorker` shape keeps the worker as a
      # one-call delegate and preserves D-10's "thin scheduled worker"
      # contract.
      workflow_run_id
      |> Progression.progress_run([])
      |> normalize_progress_result()
    end

    # Normalize the engine's three-result contract — `{:advanced, _, _}`,
    # `{:waiting, _}`, `{:noop, _, _}` — into a uniform `:ok` so duplicate
    # workers, noop-safe runs, and successful advancements all signal queue
    # success without triggering retry storms. `:workflow_run_not_found` is
    # treated as a noop too: the row may have been deleted between the
    # scheduler insert and the perform call, and there is nothing to retry.
    @doc false
    def normalize_progress_result({:ok, {:advanced, _run, _deliveries}}), do: :ok
    def normalize_progress_result({:ok, {:waiting, _run}}), do: :ok
    def normalize_progress_result({:ok, {:noop, _run, _reason}}), do: :ok
    def normalize_progress_result({:ok, {:completed, _run}}), do: :ok
    def normalize_progress_result({:ok, {:stopped, _run}}), do: :ok
    def normalize_progress_result({:error, :workflow_run_not_found}), do: :ok
    def normalize_progress_result({:error, reason}), do: {:error, reason}
  end
end
