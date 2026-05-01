defmodule Chimeway.Webhooks do
  @moduledoc """
  Pure function boundary for synchronously ingesting and verifying inbound webhooks.
  """
  alias Chimeway.Webhooks.ProcessFeedbackWorker

  def process(adapter_module, raw_body, headers, config) do
    with :ok <- adapter_module.verify_webhook(raw_body, headers, config),
         {:ok, parsed} <- Jason.decode(raw_body),
         {:ok, delivery_info} <- adapter_module.resolve_delivery(parsed),
         {:ok, feedback_info} <- adapter_module.normalize_feedback(parsed) do
      
      args =
        %{
          "status" => to_string(feedback_info.status),
          "provider_response" => parsed,
          "adapter_module" => to_string(adapter_module)
        }
        |> Map.merge(stringify_keys(delivery_info))

      ProcessFeedbackWorker.enqueue(args)
    else
      {:error, :unauthorized} -> {:error, :unauthorized}
      _ -> :error
    end
  end

  defp stringify_keys(map) do
    Map.new(map, fn {k, v} -> {to_string(k), v} end)
  end
end