defmodule ChimewayAdmin.LiveAuth do
  @moduledoc """
  LiveView `on_mount` hook — fail-closed authorization via `ChimewayAdmin.Auth`.

  Host must set `current_actor` on the socket assign or in the session under
  `"current_actor"` before the admin LiveView mounts.

  Allowed `authorize/3` return values: `:ok` or `{:error, :unauthorized}`.
  Any other return is logged and treated as unauthorized.
  """
  import Phoenix.Component
  import Phoenix.LiveView

  alias ChimewayAdmin.Auth

  def on_mount(action, _params, session, socket) when action in [:search_traces, :view_trace] do
    case authorize(action, session, socket) do
      :ok ->
        {:cont, assign(socket, :chimeway_admin_session, session)}

      {:error, _} ->
        {:halt, redirect(socket, to: unauthorized_redirect())}
    end
  end

  @doc """
  Re-checks authorization for event handlers after mount.

  Returns `{:ok, socket}` or `{:error, redirected_socket}`.
  """
  @spec ensure_authorized(Phoenix.LiveView.Socket.t(), atom()) ::
          {:ok, Phoenix.LiveView.Socket.t()} | {:error, Phoenix.LiveView.Socket.t()}
  def ensure_authorized(socket, action) when action in [:search_traces, :view_trace] do
    session = Map.get(socket.assigns, :chimeway_admin_session, %{})

    case authorize(action, session, socket) do
      :ok ->
        {:ok, socket}

      {:error, _} ->
        {:error, redirect(socket, to: unauthorized_redirect())}
    end
  end

  defp authorize(action, session, socket) do
    auth_module = Auth.auth_module()
    actor = socket.assigns[:current_actor] || session["current_actor"]

    context = %{
      live_view: socket.view,
      session: session
    }

    case auth_module.authorize(actor, action, context) do
      :ok ->
        :ok

      {:error, :unauthorized} ->
        {:error, :unauthorized}

      other ->
        require Logger

        Logger.warning(
          "ChimewayAdmin.Auth.authorize/3 returned unexpected #{inspect(other)}; treating as unauthorized"
        )

        {:error, :unauthorized}
    end
  end

  defp unauthorized_redirect do
    Application.get_env(:chimeway_admin, :unauthorized_redirect, "/")
  end
end
