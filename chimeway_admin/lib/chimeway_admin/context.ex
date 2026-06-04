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

  @spec read_opts(t() | nil, keyword()) :: keyword()
  def read_opts(context, opts \\ [])

  def read_opts(%{tenant_id: tenant_id}, opts) when is_binary(tenant_id) do
    Keyword.put(opts, :tenant_id, tenant_id)
  end

  def read_opts(_context, opts), do: opts

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

  @spec recovery_opts(t() | nil, String.t() | nil, term()) :: keyword()
  def recovery_opts(context, reason, confirmation_marker) do
    [
      source: "chimeway_admin",
      reason: normalize_value(reason),
      actor_ref: actor_ref(context),
      confirmation_marker: normalize_value(confirmation_marker)
    ]
    |> Enum.reject(fn {_key, value} -> blank?(value) end)
  end

  defp tenant_id(params, session) do
    session_value(session, "chimeway_admin_tenant_id") ||
      session_value(session, "tenant_id") ||
      session_value(params, "tenant_id")
  end

  defp session_value(map, key) when is_map(map), do: normalize_value(Map.get(map, key))
  defp session_value(_map, _key), do: nil

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

  defp blank?(value), do: is_nil(value) or value == ""
end
