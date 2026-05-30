defmodule ChimewayInbox.Live.BellDropdownLive do
  @moduledoc false
  use ChimewayInbox.Live, :live_view

  @impl true
  def mount(_params, _session, socket), do: {:ok, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="chimeway-inbox"></div>
    """
  end
end
