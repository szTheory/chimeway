defmodule ChimewayAdmin.LiveAuth do
  @moduledoc """
  LiveView `on_mount` hook — fail-closed authorization via `ChimewayAdmin.Auth`.

  Host must set `current_actor` on the socket assign or in the session under
  `"current_actor"` before the admin LiveView mounts.
  """
  import Phoenix.LiveView

  alias ChimewayAdmin.Auth

  def on_mount(action, _params, session, socket) when action in [:search_traces, :view_trace] do
    auth_module = Auth.auth_module()
    actor = socket.assigns[:current_actor] || session["current_actor"]

    context = %{
      live_view: socket.view,
      session: session
    }

    case auth_module.authorize(actor, action, context) do
      :ok ->
        {:cont, socket}

      {:error, :unauthorized} ->
        {:halt, redirect(socket, to: "/")}
    end
  end
end
