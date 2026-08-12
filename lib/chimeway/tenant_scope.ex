defmodule Chimeway.TenantScope do
  @moduledoc """
  Resolves the one concrete tenant that authorizes a lifecycle operation.

  Tenant scope is durable row identity, not a storage prefix. Calls fail closed
  unless an explicit tenant is supplied or the host has opted into a concrete
  single-tenant compatibility value.
  """

  @spec resolve(keyword()) ::
          {:ok, String.t()} | {:error, :tenant_scope_required | :invalid_compatibility_tenant}
  def resolve(opts) when is_list(opts) do
    case Keyword.fetch(opts, :tenant_id) do
      {:ok, tenant_id} -> normalize_explicit(tenant_id)
      :error -> compatibility_tenant()
    end
  end

  defp normalize_explicit(tenant_id) when is_binary(tenant_id) do
    case String.trim(tenant_id) do
      "" -> {:error, :tenant_scope_required}
      normalized -> {:ok, normalized}
    end
  end

  defp normalize_explicit(_tenant_id), do: {:error, :tenant_scope_required}

  defp compatibility_tenant do
    case Application.get_env(:chimeway, :single_tenant_compatibility) do
      tenant_id when is_binary(tenant_id) -> normalize_compatibility(tenant_id)
      opts when is_list(opts) -> normalize_compatibility(Keyword.get(opts, :tenant_id))
      _ -> {:error, :tenant_scope_required}
    end
  end

  defp normalize_compatibility(tenant_id) when is_binary(tenant_id) do
    case String.trim(tenant_id) do
      "" -> {:error, :invalid_compatibility_tenant}
      normalized -> {:ok, normalized}
    end
  end

  defp normalize_compatibility(_tenant_id), do: {:error, :invalid_compatibility_tenant}
end
