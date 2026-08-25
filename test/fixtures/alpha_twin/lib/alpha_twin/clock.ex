defmodule AlphaTwin.Clock do
  @moduledoc false
  use GenServer

  def start_link(opts), do: GenServer.start_link(__MODULE__, Keyword.fetch!(opts, :now))
  def now(pid) when is_pid(pid), do: GenServer.call(pid, :now)
  def now(opts) when is_list(opts), do: now(Keyword.fetch!(opts, :clock_pid))
  def advance(pid, seconds) when is_integer(seconds), do: GenServer.call(pid, {:advance, seconds})

  @impl true
  def init(now), do: {:ok, now}
  @impl true
  def handle_call(:now, _from, now), do: {:reply, now, now}

  def handle_call({:advance, seconds}, _from, now),
    do: {:reply, :ok, DateTime.add(now, seconds, :second)}
end
