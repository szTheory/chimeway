defmodule Chimeway.Signal do
  @moduledoc """
  Host-facing API boundary for submitting workflow progression signals.

  Host applications call `track/4` with a tenant id, actor id, event name, and
  optional payload. The function durably persists a `Chimeway.Signals.Signal`
  row and atomically enqueues a `Chimeway.Dispatch.SignalRouterWorker` job
  carrying the new signal's id. The worker (Phase 27-02) is responsible for
  routing the signal to whichever workflow runs are waiting on it.

  Both side effects share a single `Ecto.Multi` transaction — if the Oban
  insert fails, the Signal row is rolled back; no orphaned signals or jobs.
  """

  alias Chimeway.Dispatch.SignalRouterWorker
  alias Chimeway.Repo
  alias Chimeway.Signals.Signal
  alias Ecto.Multi

  @spec track(String.t(), String.t(), String.t(), map()) ::
          {:ok, Signal.t()} | {:error, Ecto.Changeset.t() | term()}
  def track(tenant_id, actor_id, event_name, payload \\ %{}) do
    attrs = %{
      tenant_id: tenant_id,
      actor_id: actor_id,
      event_name: event_name,
      payload: payload
    }

    Multi.new()
    |> Multi.insert(:signal, Signal.changeset(%Signal{}, attrs))
    |> Oban.insert(:job, fn %{signal: signal} ->
      SignalRouterWorker.new(%{"signal_id" => signal.id})
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{signal: signal}} -> {:ok, signal}
      {:error, _step, reason, _changes} -> {:error, reason}
    end
  end
end
