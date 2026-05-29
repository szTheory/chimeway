defmodule ChimewayAdmin.Live.TraceSearchLive do
  @moduledoc """
  Operator trace search (recipient ID or correlation ID).

  Full search logic ships in plan 40-02; this module compiles with the router macro.
  """
  use Phoenix.LiveView

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, results: [], query: "", mode: "recipient")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="chimeway-admin">
      <h1>Trace search</h1>
      <p>Search by recipient or correlation ID.</p>
    </div>
    """
  end
end
