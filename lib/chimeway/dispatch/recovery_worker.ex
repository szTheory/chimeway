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
        |> maybe_put(:event_cursor, Map.get(args, "event_cursor"))
        |> maybe_put(:target_cursor, Map.get(args, "target_cursor"))
        |> maybe_put(:stale_attempt_cursor, Map.get(args, "stale_attempt_cursor"))

      summary = TargetRecovery.recover_tenant(tenant_id, opts)

      :telemetry.execute(
        [:chimeway, :recovery, :completed],
        summary.counts,
        %{reason: summary.reason, reasons: summary.reasons, continuations: summary.continuations}
      )

      {:ok, summary}
    end

    def perform(%Oban.Job{}), do: :ok

    defp maybe_put(opts, _key, nil), do: opts
    defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
  end
end
