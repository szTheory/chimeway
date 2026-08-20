defmodule Chimeway.Adapters.APNS do
  @moduledoc "Pigeon-neutral APNs target adapter with host-owned transient custody."
  @behaviour Chimeway.TargetAdapter

  alias Chimeway.APNS.{BindingLookup, Payload, RequestIntent, Transport}
  alias Chimeway.TargetAdapter.TargetEnvelope

  @impl true
  def deliver(%TargetEnvelope{delivery: delivery, target: target}, _opts) do
    with {:ok, intent} <- RequestIntent.from_storage(target.apns_request_intent),
         false <- RequestIntent.expired?(intent, DateTime.utc_now()),
         {:ok, transient} <- BindingLookup.resolve(binding_request(target, intent)),
         {:ok, payload} <- Payload.build(delivery.render_data || %{}, intent.open_ref),
       {:ok, result} <-
           Transport.push(transient.dispatcher_ref, request(transient, intent, payload)) do
      classify_result(result, target, intent)
    else
      true -> {:expired, %{provider_code: "expired"}}
      {:error, :ambiguous} -> {:error, :possible_handoff, :ambiguous_handoff}
      {:error, :pigeon_unavailable} -> {:pre_handoff_retryable, %{provider_code: "pigeon_unavailable"}}
      {:error, :rejected} -> {:permanent, %{provider_code: "provider_rejected"}}
      {:error, :binding_not_found} -> {:pre_handoff_retryable, %{provider_code: "binding_not_found"}}
      {:error, :payload_too_large} -> {:permanent, %{provider_code: "payload_too_large"}}
      {:error, _} -> {:permanent, %{provider_code: "invalid_request"}}
      _ -> {:permanent, %{provider_code: "invalid_request"}}
    end
  rescue
    _ -> {:error, :possible_handoff, :ambiguous_handoff}
  catch
    _, _ -> {:error, :possible_handoff, :ambiguous_handoff}
  end

  defp classify_result(%Transport.Result{outcome: :accepted}, _target, _intent),
    do: {:provider_accepted, %{provider_code: "accepted", accepted_at: DateTime.utc_now()}}

  defp classify_result(
         %Transport.Result{outcome: :rejected, status: 410, reason: reason, timestamp: timestamp} = result,
         target,
         intent
       )
       when reason in ["ExpiredToken", "Unregistered"] and is_integer(timestamp) and timestamp >= 0 do
    case BindingLookup.invalidate(invalidation_key(target, intent)) do
      {:ok, %{status: :invalidated}} -> {:invalidated, provider_facts(result)}
      _ -> {:permanent, provider_facts(result)}
    end
  end

  defp classify_result(%Transport.Result{outcome: :rejected} = result, _target, _intent) do
    facts = provider_facts(result)

    case Map.fetch!(facts, :provider_reason) do
      reason when reason in ["idle_timeout", "too_many_provider_token_updates"] ->
        {:provider_retryable,
         Map.merge(facts, %{provider_code: reason, retry_after_ms: 1_000})}

      reason when reason in ["too_many_requests", "internal_server_error", "service_unavailable", "shutdown"] ->
        {:provider_retryable,
         Map.merge(facts, %{provider_code: reason, retry_after_ms: 1_000})}

      _ ->
        {:permanent, Map.put_new(facts, :provider_code, "provider_rejected")}
    end
  end

  defp classify_result(_, _target, _intent),
    do: {:possible_handoff, %{provider_code: "possible_provider_handoff"}}

  defp invalidation_key(target, intent) do
    %BindingLookup.InvalidationKey{
      tenant_id: target.tenant_id,
      environment: intent.environment,
      topic: intent.topic,
      binding_revision_ref: target.binding_revision_ref
    }
  end

  defp provider_facts(%Transport.Result{} = result) do
    %{}
    |> maybe_put(:provider_status, result.status)
    |> maybe_put(:provider_reason, normalize_reason(result.reason || result.code))
    |> maybe_put(:provider_timestamp, result.timestamp)
  end

  defp maybe_put(facts, _key, nil), do: facts
  defp maybe_put(facts, key, value), do: Map.put(facts, key, value)

  defp normalize_reason(value) when is_atom(value), do: value |> Atom.to_string() |> normalize_reason()

  defp normalize_reason(value) when is_binary(value) do
    value
    |> String.replace(~r/([a-z])([A-Z])/, "\\1_\\2")
    |> String.downcase()
  end

  defp normalize_reason(_), do: "unknown_error"

  defp binding_request(target, intent) do
    %BindingLookup.Request{
      tenant_id: target.tenant_id,
      environment: intent.environment,
      topic: intent.topic,
      binding_revision_ref: target.binding_revision_ref
    }
  end

  defp request(transient, intent, payload) do
    %Transport.Request{
      device_token: transient.device_token,
      topic: intent.topic,
      environment: intent.environment,
      id: intent.apns_id,
      expiration: DateTime.to_unix(intent.expires_at),
      collapse_id: intent.collapse_id,
      priority: 10,
      push_type: :alert,
      payload: payload
    }
  end
end
