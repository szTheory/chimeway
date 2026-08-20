defmodule Chimeway.Adapters.APNS do
  @moduledoc "Runtime-configured, Pigeon-neutral APNs target adapter."
  @behaviour Chimeway.TargetAdapter

  alias Chimeway.APNS.RequestIntent
  alias Chimeway.TargetAdapter.TargetEnvelope

  @impl true
  def deliver(%TargetEnvelope{delivery: delivery, target: target}, _opts) do
    with {:ok, intent} <- RequestIntent.from_storage(target.apns_request_intent),
         false <- RequestIntent.expired?(intent, DateTime.utc_now()),
         lookup when is_atom(lookup) <- Application.get_env(:chimeway, :apns_binding_lookup),
         transport when is_atom(transport) <- Application.get_env(:chimeway, :apns_transport),
         {:ok, material} <- apply(lookup, :resolve, [target.tenant_id, intent.environment, intent.topic, target.binding_revision_ref]),
         :ok <- validate_material(material, target, intent),
         {:ok, request} <- request(delivery, intent),
         {:ok, _result} <- apply(transport, :deliver, [Map.fetch!(material, :dispatcher_ref), request]) do
      {:ok, %{provider_code: "accepted"}}
    else
      true -> {:error, :pre_handoff, :expired}
      nil -> {:error, :pre_handoff, :not_configured}
      {:error, _} -> {:error, :pre_handoff, :invalid_request}
      _ -> {:error, :pre_handoff, :invalid_request}
    end
  end

  defp validate_material(material, target, intent) when is_map(material) do
    if Map.get(material, :tenant_id) == target.tenant_id and
         Map.get(material, :environment) == intent.environment and
         Map.get(material, :topic) == intent.topic and
         Map.get(material, :binding_revision_ref) == target.binding_revision_ref and
         is_binary(Map.get(material, :token)) and is_binary(Map.get(material, :dispatcher_ref)) do
      :ok
    else
      {:error, :invalid_material}
    end
  end
  defp validate_material(_, _, _), do: {:error, :invalid_material}

  defp request(delivery, intent) do
    data = delivery.render_data || %{}
    title = Map.get(data, :title) || Map.get(data, "title")
    body = Map.get(data, :body) || Map.get(data, "body")
    request = %{"aps" => %{"alert" => %{"title" => title, "body" => body}}, "chimeway_open_ref" => intent.open_ref}
    request = if intent.collapse_id, do: Map.put(request, "collapse_id", intent.collapse_id), else: request
    if is_binary(title) and is_binary(body) and byte_size(Jason.encode!(request)) <= 4096, do: {:ok, request}, else: {:error, :payload_too_large}
  end
end
