defmodule ChimewayInbox.LiveAuth do
  @moduledoc """
  LiveView `on_mount` hook — fail-closed recipient resolution via `ChimewayInbox.Auth`.

  Allowed `current_recipient/2` return values: `{:ok, recipient_identity}` or
  `{:error, :unauthorized}`. Any other return is logged and treated as unauthorized.
  """
  import Phoenix.Component
  import Phoenix.LiveView

  alias ChimewayInbox.Auth

  def on_mount(:inbox_bell, _params, session, socket) do
    case resolve_recipient(session, socket) do
      {:ok, recipient_identity} ->
        {:cont,
         assign(socket,
           recipient_identity: recipient_identity,
           chimeway_inbox_session: session
         )}

      {:error, _} ->
        {:halt, redirect(socket, to: unauthorized_redirect())}
    end
  end

  @doc """
  Re-checks recipient authorization for event handlers after mount.

  Returns `{:ok, socket}` or `{:error, redirected_socket}`.
  """
  @spec ensure_authorized(Phoenix.LiveView.Socket.t(), atom()) ::
          {:ok, Phoenix.LiveView.Socket.t()} | {:error, Phoenix.LiveView.Socket.t()}
  def ensure_authorized(socket, :inbox_bell) do
    session = Map.get(socket.assigns, :chimeway_inbox_session, %{})

    case resolve_recipient(session, socket) do
      {:ok, _recipient_identity} ->
        {:ok, socket}

      {:error, _} ->
        {:error, redirect(socket, to: unauthorized_redirect())}
    end
  end

  defp resolve_recipient(session, socket) do
    auth_module = Auth.auth_module()

    context = %{
      live_view: socket.view,
      session: session
    }

    case auth_module.current_recipient(session, context) do
      {:ok, recipient_identity} when is_binary(recipient_identity) ->
        {:ok, recipient_identity}

      {:error, :unauthorized} ->
        {:error, :unauthorized}

      other ->
        require Logger

        Logger.warning(
          "ChimewayInbox.Auth.current_recipient/2 returned unexpected #{inspect(other)}; treating as unauthorized"
        )

        {:error, :unauthorized}
    end
  end

  defp unauthorized_redirect do
    Application.get_env(:chimeway_inbox, :unauthorized_redirect, "/")
  end
end
