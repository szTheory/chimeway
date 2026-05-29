defmodule ChimewayAdmin.Live.TraceDetailLive do
  @moduledoc """
  Operator trace detail — unified timeline from `Chimeway.Traces.explain_delivery/1`.

  Full timeline UI ships in plan 40-02.
  """
  use Phoenix.LiveView

  @impl true
  def mount(%{"delivery_id" => delivery_id}, _session, socket) do
    {:ok, assign(socket, delivery_id: delivery_id)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="chimeway-admin">
      <h1>Trace detail</h1>
      <p>Delivery {@delivery_id}</p>
    </div>
    """
  end
end
