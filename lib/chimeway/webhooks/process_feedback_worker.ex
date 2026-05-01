defmodule Chimeway.Webhooks.ProcessFeedbackWorker do
  use Oban.Worker, queue: :default

  alias Chimeway.Deliveries

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    delivery_lookup = 
      case args do
        %{"delivery_id" => id} -> {:ok, Deliveries.get_delivery!(id)}
        %{"provider_message_id" => pid} -> Deliveries.get_delivery_by_provider_message_id(pid)
      end
    
    with {:ok, delivery} <- delivery_lookup do
      outcome = 
        case args["status"] do
          "delivered" -> :succeeded
          "bounced" -> :bounced
          "failed" -> :failed
          other -> String.to_existing_atom(other)
        end
      
      attempt_params = %{
        outcome: outcome,
        provider_response: args["provider_response"],
        adapter_module: args["adapter_module"]
      }

      attempt_params = 
        if outcome in [:bounced, :failed] do
          Map.put(attempt_params, :error_class, to_string(outcome))
        else
          attempt_params
        end
      
      attempt_params =
        if args["provider_message_id"] do
          Map.put(attempt_params, :provider_message_id, args["provider_message_id"])
        else
          attempt_params
        end

      case Deliveries.record_attempt(delivery, attempt_params) do
        {:ok, _} -> :ok
        error -> error
      end
    end
  end

  def enqueue(args) do
    args
    |> new()
    |> Oban.insert()

    {:ok, :enqueued}
  end
end