if Code.ensure_loaded?(Oban) do
  defmodule Chimeway.Dispatch.RecoveryWorker do
    @moduledoc false

    use Oban.Worker, queue: :chimeway_recovery, max_attempts: 1

    alias Chimeway.TargetRecovery

    @impl Oban.Worker
    def perform(%Oban.Job{args: %{"tenant_id" => tenant_id} = args}) when is_binary(tenant_id) do
      opts =
        []
        |> maybe_put(:batch_size, Map.get(args, "batch_size"))
        |> maybe_put(:cursor, Map.get(args, "cursor"))

      _result = TargetRecovery.recover_tenant(tenant_id, opts)
      :ok
    end

    def perform(%Oban.Job{}), do: :ok

    defp maybe_put(opts, _key, nil), do: opts
    defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
  end
end
