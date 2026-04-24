if Code.ensure_loaded?(Oban) do
  defmodule Chimeway.Dispatch.ObanWorker do
    @moduledoc """
    Oban worker that performs a single Chimeway delivery by delivery_id.

    Job args contain only `delivery_id` (UUID string). Full payload is never
    stored in Oban job args — the delivery row is the source of truth.

    ## Transactional enqueue

    Insert this worker's job inside the same `Ecto.Multi` as delivery row creation:

        alias Chimeway.Dispatch.ObanWorker

        Ecto.Multi.new()
        |> Ecto.Multi.insert(:delivery, delivery_changeset)
        |> Oban.insert(:job, ObanWorker.new(%{delivery_id: delivery.id}))
        |> Chimeway.Repo.transaction()

    Rolling back the `Ecto.Multi` also rolls back the job — no orphaned jobs.

    ## Idempotency

    The worker checks delivery terminal states on every execution. A delivery
    already in `:succeeded`, `:suppressed`, or `:cancelled` returns `:ok`
    immediately with no adapter call and no new attempt row.
    """

    use Oban.Worker,
      queue: :chimeway_delivery,
      max_attempts: 5,
      unique: [fields: [:args], keys: [:delivery_id], period: 60]

    alias Chimeway.{Deliveries, Delivery, Policy}
    alias Chimeway.Telemetry

    @terminal_states [:succeeded, :suppressed, :cancelled]

    @impl Oban.Worker
    def perform(%Oban.Job{args: %{"delivery_id" => delivery_id}}) do
      delivery = Deliveries.get_delivery!(delivery_id)

      if delivery.status in @terminal_states do
        :ok
      else
        Telemetry.span(
          [:dispatch, :perform],
          Telemetry.safe_meta(%{delivery_id: delivery.id, channel: delivery.channel}),
          fn ->
            result = dispatch_delivery(delivery)
            {result, %{}}
          end
        )
      end
    end

    defp dispatch_delivery(%Delivery{} = delivery) do
      case Policy.evaluate(delivery, check_read_state: delivery.delay_fallback) do
        {:suppress, reason} ->
          case Deliveries.suppress_delivery(delivery, reason) do
            {:ok, _} -> :ok
            {:error, _} = err -> err
          end

        {:ok, :proceed} ->
          do_dispatch(delivery)
      end
    end

    defp do_dispatch(%Delivery{} = delivery) do
      with {:ok, dispatched} <- Deliveries.transition_status(delivery, :dispatched) do
        adapter = Application.get_env(:chimeway, :adapter, Chimeway.Adapters.Logger)
        channel_key = String.to_atom("adapter_#{delivery.channel}")
        adapter_config = Application.get_env(:chimeway, channel_key, [])

        {attempt_outcome, provider_response} =
          case adapter.deliver(dispatched, adapter_config) do
            {:ok, meta} -> {:succeeded, meta}
            {:error, :temporary, detail} -> {:failed, detail}
            {:error, :permanent, detail} -> {:rejected, detail}
            {:error, :bounced, detail} -> {:bounced, detail}
          end

        case Deliveries.record_attempt(dispatched, %{
               outcome: attempt_outcome,
               provider_response: provider_response
             }) do
          {:ok, _} -> :ok
          {:error, step, reason, _changes} -> {:error, {step, reason}}
        end
      end
    end
  end
end
