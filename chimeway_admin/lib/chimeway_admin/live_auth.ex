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
  alias ChimewayAdmin.Context

  @actions [
    :search_traces,
    :view_trace,
    :view_feed,
    :view_definitions,
    :view_health,
    :list_recovery_candidates,
    :recover_delivery,
    :recover_event
  ]

  def on_mount(action, params, session, socket) when action in @actions do
    admin_context = Context.from(params, session, socket)

    with :ok <- authorize(action, admin_context, %{}),
         {:ok, admin_context} <- Context.build(params, session, socket) do
      {:cont,
       socket
       |> assign(:chimeway_admin_context, admin_context)
       |> assign(:chimeway_admin_session, session)}
    else
      {:error, _} -> {:halt, redirect(socket, to: unauthorized_redirect())}
    end
  end

  @doc """
  Re-checks authorization for event handlers after mount.

  Returns `{:ok, socket}` or `{:error, redirected_socket}`.
  """
  @spec ensure_authorized(Phoenix.LiveView.Socket.t(), atom(), map()) ::
          {:ok, Phoenix.LiveView.Socket.t()} | {:error, Phoenix.LiveView.Socket.t()}
  def ensure_authorized(socket, action, extra_context \\ %{}) when action in @actions do
    admin_context =
      Map.get(socket.assigns, :chimeway_admin_context) ||
        Context.from(%{}, Map.get(socket.assigns, :chimeway_admin_session, %{}), socket)

    with :ok <- valid_context(admin_context),
         :ok <- authorize(action, admin_context, extra_context) do
      {:ok, socket}
    else
      {:error, _} -> {:error, redirect(socket, to: unauthorized_redirect())}
    end
  end

  defp valid_context(%{tenant_id: tenant_id}) when is_binary(tenant_id) and tenant_id != "",
    do: :ok

  defp valid_context(_context), do: {:error, :invalid_tenant}

  defp authorize(action, admin_context, extra_context) do
    auth_module = Auth.auth_module()
    actor = admin_context.actor
    context = Context.authorize_context(admin_context, action, extra_context)

    case auth_module.authorize(actor, action, context) do
      :ok ->
        :ok

      {:error, :unauthorized} ->
        {:error, :unauthorized}

      other ->
        require Logger

        Logger.warning(
          "ChimewayAdmin.Auth.authorize/3 returned an unexpected value; treating as unauthorized",
          action: action,
          auth_module: inspect(auth_module),
          return_type: unexpected_return_type(other)
        )

        {:error, :unauthorized}
    end
  end

  defp unexpected_return_type(value) when is_tuple(value), do: :tuple
  defp unexpected_return_type(value) when is_map(value), do: :map
  defp unexpected_return_type(value) when is_list(value), do: :list
  defp unexpected_return_type(value) when is_atom(value), do: :atom
  defp unexpected_return_type(value) when is_binary(value), do: :binary
  defp unexpected_return_type(_value), do: :other

  defp unauthorized_redirect do
    Application.get_env(:chimeway_admin, :unauthorized_redirect, "/")
  end
end
