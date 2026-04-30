defmodule Chimeway.Dispatch.SignalRouterWorker do
  @moduledoc """
  Worker for routing signals to the correct workflow run.
  """
  use Oban.Worker, queue: :signals

  @impl Oban.Worker
  def perform(_job) do
    {:ok, :noop}
  end
end
