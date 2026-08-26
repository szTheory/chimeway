defmodule AlphaTwin.Registry do
  @moduledoc false
  use GenServer
  @behaviour Chimeway.APNS.BindingLookup

  alias Chimeway.APNS.BindingLookup

  def start_link(_opts \\ []),
    do: GenServer.start_link(__MODULE__, %{bindings: %{}, intents: %{}, sequence: 0})

  def bind(pid, attrs), do: GenServer.call(pid, {:bind, attrs})
  def rotate(pid, ref, token), do: GenServer.call(pid, {:rotate, ref, token})
  def issue_intent(pid, ref), do: GenServer.call(pid, {:issue_intent, ref})
  def consume_intent(pid, ref), do: GenServer.call(pid, {:consume_intent, ref})
  def resolve(pid, request), do: GenServer.call(pid, {:resolve, request})
  def invalidate(pid, key), do: GenServer.call(pid, {:invalidate, key})

  @impl true
  def resolve_binding(request),
    do: resolve(Application.fetch_env!(:chimeway, :alpha_twin_registry), request)

  @impl true
  def invalidate_binding(key),
    do: invalidate(Application.fetch_env!(:chimeway, :alpha_twin_registry), key)

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:bind, attrs}, _from, state),
    do: {:reply, create_binding(state, attrs), state_after_binding(state, attrs)}

  def handle_call({:rotate, ref, token}, _from, state), do: rotate_binding(ref, token, state)

  def handle_call({:resolve, request}, _from, state),
    do: {:reply, resolve_binding_for(request, state), state}

  def handle_call({:invalidate, key}, _from, state), do: invalidate_binding_for(key, state)
  def handle_call({:issue_intent, ref}, _from, state), do: issue_intent_for(ref, state)
  def handle_call({:consume_intent, ref}, _from, state), do: consume_intent_for(ref, state)

  defp state_after_binding(state, attrs) do
    binding = binding_for(state.sequence + 1, attrs)

    %{
      state
      | bindings: Map.put(state.bindings, binding.binding_revision_ref, binding),
        sequence: state.sequence + 1
    }
  end

  defp create_binding(state, attrs),
    do: {:ok, observation(binding_for(state.sequence + 1, attrs))}

  defp rotate_binding(ref, token, state) do
    case Map.get(state.bindings, ref) do
      %{active: true} = old ->
        attrs =
          Map.take(old, [:tenant_id, :environment, :topic, :installation_ref])
          |> Map.put(:token, token)

        new = binding_for(state.sequence + 1, attrs)

        bindings =
          state.bindings
          |> Map.put(ref, %{old | active: false})
          |> Map.put(new.binding_revision_ref, new)

        {:reply, {:ok, observation(new)},
         %{state | bindings: bindings, sequence: state.sequence + 1}}

      _ ->
        {:reply, {:error, :binding_not_found}, state}
    end
  end

  defp resolve_binding_for(%BindingLookup.Request{} = request, state) do
    case Map.get(state.bindings, request.binding_revision_ref) do
      %{active: true, tenant_id: tenant_id, environment: environment, topic: topic, token: token} =
          binding
      when tenant_id == request.tenant_id and environment == request.environment and
             topic == request.topic ->
        {:ok,
         %BindingLookup.Transient{
           tenant_id: tenant_id,
           environment: environment,
           topic: topic,
           binding_revision_ref: binding.binding_revision_ref,
           device_token: token,
           dispatcher_ref: :alpha_twin
         }}

      _ ->
        {:error, :binding_not_found}
    end
  end

  defp invalidate_binding_for(%BindingLookup.InvalidationKey{} = key, state) do
    case Map.get(state.bindings, key.binding_revision_ref) do
      %{active: true, tenant_id: tenant_id, environment: environment, topic: topic} = binding
      when tenant_id == key.tenant_id and environment == key.environment and topic == key.topic ->
        {:reply, {:ok, %BindingLookup.InvalidationResult{status: :invalidated}},
         %{
           state
           | bindings:
               Map.put(state.bindings, key.binding_revision_ref, %{binding | active: false})
         }}

      _ ->
        {:reply, {:ok, %BindingLookup.InvalidationResult{status: :unchanged}}, state}
    end
  end

  defp issue_intent_for(ref, state) do
    case Map.get(state.bindings, ref) do
      %{active: true} ->
        intent_ref =
          "cw_open_" <> Integer.to_string(state.sequence + map_size(state.intents) + 1)

        {:reply, {:ok, %{intent_ref: intent_ref, classification: :issued}},
         %{state | intents: Map.put(state.intents, intent_ref, false)}}

      _ ->
        {:reply, {:error, :binding_not_found}, state}
    end
  end

  defp consume_intent_for(ref, state) do
    case Map.fetch(state.intents, ref) do
      {:ok, false} ->
        {:reply, {:ok, %{classification: :accepted}},
         %{state | intents: Map.put(state.intents, ref, true)}}

      {:ok, true} ->
        {:reply, {:error, :replayed}, state}

      :error ->
        {:reply, {:error, :not_found}, state}
    end
  end

  defp binding_for(sequence, attrs) do
    %{
      tenant_id: tenant_id,
      environment: environment,
      topic: topic,
      installation_ref: installation_ref,
      token: token
    } = attrs

    %{
      tenant_id: tenant_id,
      environment: environment,
      topic: topic,
      installation_ref: installation_ref,
      token: token,
      token_fingerprint: :crypto.hash(:sha256, token) |> Base.url_encode64(padding: false),
      binding_revision_ref: "cw_binding_" <> Integer.to_string(sequence),
      active: true
    }
  end

  defp observation(binding),
    do:
      Map.take(binding, [
        :tenant_id,
        :environment,
        :topic,
        :installation_ref,
        :token_fingerprint,
        :binding_revision_ref
      ])
end
