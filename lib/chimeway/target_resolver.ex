defmodule Chimeway.TargetResolver do
  @moduledoc "Tenant-explicit resolver for opaque installation binding revisions."

  @callback resolve_targets(String.t(), keyword()) ::
              {:ok, [BindingRevision.t()]} | {:error, term()}

  defmodule BindingRevision do
    @moduledoc false
    @enforce_keys [:tenant_id, :binding_revision_ref]
    defstruct [:tenant_id, :binding_revision_ref, :request_intent]

    @type t :: %__MODULE__{
            tenant_id: String.t(),
            binding_revision_ref: String.t(),
            request_intent: Chimeway.APNS.RequestIntent.t() | nil
          }

    @spec new(String.t(), String.t()) :: {:ok, t()} | {:error, :invalid_binding_revision}
    def new(tenant_id, binding_revision_ref)
        when is_binary(tenant_id) and byte_size(tenant_id) > 0 and is_binary(binding_revision_ref) and
               byte_size(binding_revision_ref) in 4..128 do
      if String.match?(binding_revision_ref, ~r/^cw_[a-z0-9][a-z0-9_-]*$/) do
        {:ok, %__MODULE__{tenant_id: tenant_id, binding_revision_ref: binding_revision_ref}}
      else
        {:error, :invalid_binding_revision}
      end
    end

    def new(_, _), do: {:error, :invalid_binding_revision}

    @spec new_with_request_intent(String.t(), String.t(), Chimeway.APNS.RequestIntent.t()) ::
            {:ok, t()} | {:error, :invalid_binding_revision}
    def new_with_request_intent(
          tenant_id,
          binding_revision_ref,
          %Chimeway.APNS.RequestIntent{} = intent
        ) do
      case new(tenant_id, binding_revision_ref) do
        {:ok, binding} -> {:ok, %{binding | request_intent: intent}}
        error -> error
      end
    end
  end

  @spec resolve_targets(String.t(), keyword()) :: {:ok, [BindingRevision.t()]} | {:error, term()}
  def resolve_targets(tenant_id, opts) when is_binary(tenant_id) and is_list(opts) do
    resolver =
      Keyword.get(opts, :target_resolver, Application.get_env(:chimeway, :target_resolver))

    with resolver when is_atom(resolver) <- resolver,
         {:ok, results} <- resolver.resolve_targets(tenant_id, opts),
         {:ok, normalized} <- normalize(tenant_id, results) do
      {:ok, normalized}
    else
      nil -> {:error, :target_resolver_not_configured}
      {:error, _} = error -> error
      _ -> {:error, :invalid_target_resolution}
    end
  end

  def resolve_targets(_, _), do: {:error, :invalid_target_resolution}

  @spec normalize(String.t(), term()) ::
          {:ok, [BindingRevision.t()]} | {:error, :invalid_target_resolution}
  def normalize(tenant_id, results) when is_list(results) do
    results
    |> Enum.reduce_while({:ok, []}, fn
      %BindingRevision{tenant_id: ^tenant_id, binding_revision_ref: ref, request_intent: intent} =
          binding,
      {:ok, acc} ->
        case {BindingRevision.new(tenant_id, ref), valid_request_intent?(intent)} do
          {{:ok, _}, true} -> {:cont, {:ok, [binding | acc]}}
          _ -> {:halt, {:error, :invalid_target_resolution}}
        end

      _, _ ->
        {:halt, {:error, :invalid_target_resolution}}
    end)
    |> case do
      {:ok, bindings} ->
        {:ok,
         bindings
         |> Enum.reverse()
         |> Enum.sort_by(& &1.binding_revision_ref)
         |> Enum.uniq_by(& &1.binding_revision_ref)}

      error ->
        error
    end
  end

  def normalize(_, _), do: {:error, :invalid_target_resolution}

  defp valid_request_intent?(nil), do: true

  defp valid_request_intent?(%Chimeway.APNS.RequestIntent{} = intent) do
    match?(
      {:ok, _},
      Chimeway.APNS.RequestIntent.from_storage(Chimeway.APNS.RequestIntent.to_storage(intent))
    )
  end

  defp valid_request_intent?(_), do: false
end
