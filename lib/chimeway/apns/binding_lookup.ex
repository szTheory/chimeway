defmodule Chimeway.APNS.BindingLookup do
  @moduledoc "Tenant-explicit host custody boundary for transient APNs bindings."

  defmodule Request do
    @enforce_keys [:tenant_id, :environment, :topic, :binding_revision_ref]
    defstruct [:tenant_id, :environment, :topic, :binding_revision_ref]
  end

  defmodule Transient do
    @enforce_keys [
      :tenant_id,
      :environment,
      :topic,
      :binding_revision_ref,
      :device_token,
      :dispatcher_ref
    ]
    defstruct [
      :tenant_id,
      :environment,
      :topic,
      :binding_revision_ref,
      :device_token,
      :dispatcher_ref
    ]
  end

  defmodule InvalidationKey do
    @enforce_keys [:tenant_id, :environment, :topic, :binding_revision_ref]
    defstruct [:tenant_id, :environment, :topic, :binding_revision_ref]
  end

  defmodule InvalidationResult do
    @enforce_keys [:status]
    defstruct [:status]
  end

  @callback resolve_binding(Request.t()) :: {:ok, Transient.t()} | {:error, atom()}
  @callback invalidate_binding(InvalidationKey.t()) ::
              {:ok, InvalidationResult.t()} | {:error, atom()}

  @spec resolve(Request.t(), keyword()) :: {:ok, Transient.t()} | {:error, :binding_not_found}
  def resolve(%Request{} = request, opts \\ []) do
    module =
      Keyword.get(opts, :binding_lookup, Application.get_env(:chimeway, :apns_binding_lookup))

    with module when is_atom(module) <- module,
         {:ok, %Transient{} = transient} <- module.resolve_binding(request),
         true <- echoes?(transient, request) and valid_transient?(transient) do
      {:ok, transient}
    else
      _ -> {:error, :binding_not_found}
    end
  end

  @spec invalidate(InvalidationKey.t(), keyword()) ::
          {:ok, InvalidationResult.t()} | {:error, :binding_not_found}
  def invalidate(%InvalidationKey{} = key, opts \\ []) do
    module =
      Keyword.get(opts, :binding_lookup, Application.get_env(:chimeway, :apns_binding_lookup))

    with module when is_atom(module) <- module,
         {:ok, %InvalidationResult{status: status} = result} <- module.invalidate_binding(key),
         true <- status in [:invalidated, :unchanged] do
      {:ok, result}
    else
      _ -> {:error, :binding_not_found}
    end
  end

  defp echoes?(transient, request) do
    Map.take(transient, [:tenant_id, :environment, :topic, :binding_revision_ref]) ==
      Map.take(request, [:tenant_id, :environment, :topic, :binding_revision_ref])
  end

  defp valid_transient?(%Transient{device_token: token, dispatcher_ref: dispatcher}) do
    is_binary(token) and byte_size(token) > 0 and is_binary(dispatcher) and
      byte_size(dispatcher) > 0
  end
end
