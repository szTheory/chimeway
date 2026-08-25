defmodule Chimeway.Adapters.APNS do
  @moduledoc "Pigeon-neutral APNs target adapter with host-owned transient custody."
  @behaviour Chimeway.TargetAdapter

  alias Chimeway.APNS.{BindingLookup, RequestIntent, Transport}
  alias Chimeway.TargetAdapter.TargetEnvelope

  @impl true
  def deliver(%TargetEnvelope{delivery: delivery, target: target}, opts) do
    with {:ok, intent} <- safe_intent(target.apns_request_intent),
         false <- safe_expired?(intent, now(opts)),
         {:ok, transient} <- safe_lookup(binding_request(target, intent)),
         {:ok, payload} <- safe_payload(delivery.render_data || %{}, intent.open_ref),
         {:ok, result} <-
           safe_transport(transient.dispatcher_ref, request(transient, intent, payload), opts) do
      classify_result(result, target, intent, now(opts))
    else
      true ->
        {:expired, %{provider_code: "expired"}}

      {:error, :lookup_failed} ->
        {:pre_handoff_retryable, %{provider_code: "binding_lookup_failed"}}

      {:error, :ambiguous} ->
        {:error, :possible_handoff, :ambiguous_handoff}

      {:error, :pigeon_unavailable} ->
        {:pre_handoff_retryable, %{provider_code: "pigeon_unavailable"}}

      {:error, :rejected} ->
        {:permanent, %{provider_code: "provider_rejected"}}

      {:error, :binding_not_found} ->
        {:pre_handoff_retryable, %{provider_code: "binding_not_found"}}

      {:error, :payload_too_large} ->
        {:permanent, %{provider_code: "payload_too_large"}}

      {:error, _} ->
        {:permanent, %{provider_code: "invalid_request"}}

      _ ->
        {:permanent, %{provider_code: "invalid_request"}}
    end
  end

  defp safe_intent(storage) do
    RequestIntent.from_storage(storage)
  rescue
    _ -> {:error, :invalid_request}
  catch
    _, _ -> {:error, :invalid_request}
  end

  defp safe_expired?(intent, now) do
    RequestIntent.expired?(intent, now)
  rescue
    _ -> false
  catch
    _, _ -> false
  end

  defp safe_lookup(request) do
    BindingLookup.resolve(request)
  rescue
    _ -> {:error, :lookup_failed}
  catch
    _, _ -> {:error, :lookup_failed}
  end

  defp safe_payload(render_data, open_ref) do
    builder = Application.get_env(:chimeway, :apns_payload_builder, Chimeway.APNS.Payload)
    builder.build(render_data, open_ref)
  rescue
    _ -> {:error, :invalid_payload}
  catch
    _, _ -> {:error, :invalid_payload}
  end

  defp safe_transport(dispatcher_ref, request, opts) do
    Transport.push(dispatcher_ref, request, opts)
  rescue
    _ -> {:error, :ambiguous}
  catch
    _, _ -> {:error, :ambiguous}
  end

  defp classify_result(%Transport.Result{outcome: :accepted}, _target, _intent, now),
    do: {:provider_accepted, %{provider_code: "accepted", accepted_at: now}}

  defp classify_result(
         %Transport.Result{outcome: :rejected, status: 410, reason: reason, timestamp: timestamp} =
           result,
         target,
         intent,
         _now
       )
       when reason in ["ExpiredToken", "Unregistered"] and is_integer(timestamp) and
              timestamp >= 0 do
    case BindingLookup.invalidate(invalidation_key(target, intent)) do
      {:ok, %{status: :invalidated}} -> {:invalidated, provider_facts(result)}
      _ -> {:permanent, provider_facts(result)}
    end
  end

  defp classify_result(%Transport.Result{outcome: :rejected} = result, _target, _intent, _now) do
    facts = provider_facts(result)

    case Map.fetch!(facts, :provider_reason) do
      reason when reason in ["idle_timeout", "too_many_provider_token_updates"] ->
        {:provider_retryable,
         Map.merge(facts, %{
           provider_code: reason,
           retry_after_ms: 1_000,
           corrective_action: "refresh_provider_token"
         })}

      reason
      when reason in [
             "too_many_requests",
             "internal_server_error",
             "service_unavailable",
             "shutdown"
           ] ->
        {:provider_retryable,
         Map.merge(facts, %{
           provider_code: reason,
           retry_after_ms: 1_000,
           corrective_action: "retry_later"
         })}

      _ ->
        {:permanent, Map.put_new(facts, :provider_code, "provider_rejected")}
    end
  end

  defp classify_result(_, _target, _intent, _now),
    do: {:possible_handoff, %{provider_code: "possible_provider_handoff"}}

  defp now(opts) do
    case Keyword.get(opts, :now) do
      %DateTime{} = resolved -> resolved
      _ -> Chimeway.Clock.now(opts)
    end
  end

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

  defp normalize_reason(value) when is_atom(value),
    do: value |> Atom.to_string() |> normalize_reason()

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
