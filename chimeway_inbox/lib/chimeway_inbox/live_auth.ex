defmodule ChimewayInbox.LiveAuth do
  @moduledoc """
  LiveView `on_mount` hook — fail-closed recipient and tenant resolution via
  `ChimewayInbox.Auth`.

  Both host callbacks must return a nonblank binary identity/tenant or an error.
  Any unexpected result is logged and treated as unauthorized.
  """
  import Phoenix.Component
  import Phoenix.LiveView

  alias ChimewayInbox.Auth

  def on_mount(:inbox_bell, _params, session, socket) do
    case resolve_context(session, socket) do
      {:ok, recipient_identity, tenant_id} ->
        {:cont,
         assign(socket,
           recipient_identity: recipient_identity,
           tenant_id: tenant_id,
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

    case resolve_context(session, socket) do
      {:ok, recipient_identity, tenant_id}
      when recipient_identity == socket.assigns.recipient_identity and
             tenant_id == socket.assigns.tenant_id ->
        {:ok, socket}

      {:error, _} ->
        {:error, redirect(socket, to: unauthorized_redirect())}
    end
  end

  defp resolve_context(session, socket) do
    auth_module = Auth.auth_module()

    context = %{
      live_view: socket.view,
      session: session
    }

    with {:ok, recipient_identity} <-
           resolve_value(auth_module, :current_recipient, session, context),
         {:ok, tenant_id} <- resolve_value(auth_module, :current_tenant, session, context) do
      {:ok, recipient_identity, tenant_id}
    end
  end

  defp resolve_value(auth_module, callback, session, context) do
    case apply(auth_module, callback, [session, context]) do
      {:ok, value} when is_binary(value) ->
        case String.trim(value) do
          "" -> unexpected_callback(callback, {:ok, value})
          normalized -> {:ok, normalized}
        end

      {:error, _reason} ->
        {:error, :unauthorized}

      other ->
        unexpected_callback(callback, other)
    end
  rescue
    UndefinedFunctionError -> unexpected_callback(callback, :missing_callback)
  end

  defp unexpected_callback(callback, result) do
    require Logger

    Logger.warning(
      "ChimewayInbox.Auth.#{callback}/2 returned unexpected #{inspect(result)}; treating as unauthorized"
    )

    {:error, :unauthorized}
  end

  defp unauthorized_redirect do
    Application.get_env(:chimeway_inbox, :unauthorized_redirect, "/")
  end
end
