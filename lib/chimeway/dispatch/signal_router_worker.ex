defmodule Chimeway.Dispatch.SignalRouterWorker do
  @moduledoc """
  Oban worker that routes an incoming signal to all waiting workflow runs that are
  suspended on the signal's `event_name` within the same tenant.

  Job args contain only `signal_id`. The worker:

    1. Fetches the `Chimeway.Signals.Signal` row by ID.
    2. Delegates to `Chimeway.Workflows.route_signal/1`, which atomically resumes
       every matching `WorkflowRun` and appends a `WorkflowTransition` trace.

  Returns `:ok` on success (including when zero workflows match) so Oban marks the
  job `:completed`. Returns `{:error, :signal_not_found}` when the signal row no
  longer exists; Oban will schedule a retry.
  """
  use Oban.Worker, queue: :chimeway_signals

  alias Chimeway.Repo
  alias Chimeway.Signals.Signal
  alias Chimeway.Workflows

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"signal_id" => signal_id}}) do
    case Repo.get(Signal, signal_id) do
      nil ->
        {:error, :signal_not_found}

      %Signal{} = signal ->
        case Workflows.route_signal(signal) do
          {:ok, _results} -> :ok
          {:error, reason} -> {:error, reason}
        end
    end
  end
end
