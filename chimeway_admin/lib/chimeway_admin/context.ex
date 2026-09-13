defmodule ChimewayAdmin.Context do
  @moduledoc """
  Shared host-provided context for Chimeway admin LiveViews.

  The context normalizes actor and tenant scope for reads and authorization.
  It does not validate tenant membership or host policy; that remains owned by
  the configured `ChimewayAdmin.Auth` implementation.
  """

  @safe_candidate_keys [
    :id,
    :event_id,
    :delivery_id,
    :notification_id,
    :notification_key,
    :notification_version,
    :recipient_id,
    :tenant_id,
    :type,
    :status,
    :reason,
    :correlation_id
  ]

  @type t :: %{
          actor: term(),
          tenant_id: String.t() | nil,
          params: map(),
          session: map(),
          live_view: module() | nil
        }

  @spec from(map(), map(), Phoenix.LiveView.Socket.t()) :: t()
  def from(params, session, socket) do
    %{
      actor: socket.assigns[:current_actor] || session["current_actor"],
      tenant_id: tenant_id(params, session),
      params: params || %{},
      session: session || %{},
      live_view: Map.get(socket, :view)
    }
  end

  @doc """
  Builds a context only when the host supplied a concrete tenant identity.
  """
  @spec build(map(), map(), Phoenix.LiveView.Socket.t()) :: {:ok, t()} | {:error, :invalid_tenant}
  def build(params, session, socket) do
    context = from(params, session, socket)

    if valid_tenant?(context.tenant_id) do
      {:ok, context}
    else
      {:error, :invalid_tenant}
    end
  end

  @spec read_opts(t() | nil, keyword()) :: keyword() | {:error, :invalid_tenant}
  def read_opts(context, opts \\ [])

  def read_opts(%{tenant_id: tenant_id}, opts) when is_binary(tenant_id) and tenant_id != "" do
    Keyword.put(opts, :tenant_id, tenant_id)
  end

  def read_opts(_context, _opts), do: {:error, :invalid_tenant}

  @spec authorize_context(t() | nil, atom(), map()) :: map()
  def authorize_context(context, action, extra_context \\ %{})

  def authorize_context(context, action, extra_context) when is_map(context) do
    context
    |> Map.take([:actor, :tenant_id, :params, :session, :live_view])
    |> Map.put(:action, action)
    |> Map.merge(extra_context || %{})
  end

  def authorize_context(_context, action, extra_context) do
    Map.put(extra_context || %{}, :action, action)
  end

  @spec candidate_facts(map() | nil) :: map()
  def candidate_facts(nil), do: %{}

  def candidate_facts(candidate) when is_map(candidate) do
    candidate
    |> Map.take(@safe_candidate_keys)
    |> Enum.reject(fn {_key, value} -> blank?(value) end)
    |> Map.new()
  end

  @spec actor_ref(t() | map() | term()) :: String.t() | nil
  def actor_ref(%{actor: actor}), do: actor_ref(actor)
  def actor_ref(%{"id" => id}) when not is_nil(id), do: normalize_value(id)
  def actor_ref(%{id: id}) when not is_nil(id), do: normalize_value(id)
  def actor_ref(%{"email" => email}) when not is_nil(email), do: normalize_value(email)
  def actor_ref(%{email: email}) when not is_nil(email), do: normalize_value(email)

  def actor_ref(value) when is_binary(value) or is_atom(value) or is_integer(value),
    do: normalize_value(value)

  def actor_ref(_value), do: nil

  @spec recovery_opts(t() | nil, String.t() | nil, term()) ::
          keyword() | {:error, :invalid_tenant}
  def recovery_opts(%{tenant_id: tenant_id} = context, reason, confirmation_marker)
      when is_binary(tenant_id) and tenant_id != "" do
    [
      source: "chimeway_admin",
      reason: normalize_value(reason),
      tenant_id: tenant_id,
      actor_ref: actor_ref(context),
      confirmation_marker: normalize_value(confirmation_marker)
    ]
    |> Enum.reject(fn {_key, value} -> blank?(value) end)
  end

  def recovery_opts(_context, _reason, _confirmation_marker) do
    {:error, :invalid_tenant}
  end

  defp tenant_id(params, session) do
    tenant_value(session, "chimeway_admin_tenant_id") ||
      tenant_value(session, "tenant_id") ||
      tenant_value(params, "tenant_id")
  end

  defp tenant_value(map, key) when is_map(map), do: normalize_tenant(Map.get(map, key))
  defp tenant_value(_map, _key), do: nil

  defp normalize_value(nil), do: nil

  defp normalize_value(value) when is_binary(value) do
    value
    |> String.trim()
    |> case do
      "" -> nil
      value -> value
    end
  end

  defp normalize_value(value) when is_atom(value),
    do: value |> Atom.to_string() |> normalize_value()

  defp normalize_value(value) when is_integer(value), do: Integer.to_string(value)
  defp normalize_value(_value), do: nil

  defp normalize_tenant(value) when is_binary(value), do: normalize_value(value)
  defp normalize_tenant(_value), do: nil

  defp valid_tenant?(tenant_id) when is_binary(tenant_id), do: tenant_id != ""
  defp valid_tenant?(_tenant_id), do: false

  defp blank?(value), do: is_nil(value) or value == ""
end
