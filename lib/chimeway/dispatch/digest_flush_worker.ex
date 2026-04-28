if Code.ensure_loaded?(Oban) do
  defmodule Chimeway.Dispatch.DigestFlushWorker do
    @moduledoc "Thin Oban worker that delegates due digest bucket execution to the emission service."

    use Oban.Worker,
      queue: :chimeway_delivery,
      max_attempts: 5,
      unique: [fields: [:args], keys: [:bucket_id], period: 60]

    alias Chimeway.Digests

    @impl Oban.Worker
    def perform(%Oban.Job{args: %{"bucket_id" => bucket_id}}) do
      case Digests.emit_bucket(bucket_id) do
        {:ok, _result} -> :ok
        {:error, {:bucket_not_due, _bucket_id}} -> :ok
        {:error, reason} -> {:error, reason}
      end
    end
  end
end
