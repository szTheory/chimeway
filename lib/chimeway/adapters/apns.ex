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
      accepted(result)
    else
      true -> {:error, :pre_handoff, :expired}
      {:error, :ambiguous} -> {:error, :possible_handoff, :ambiguous_handoff}
      {:error, :pigeon_unavailable} -> {:error, :pre_handoff, :pigeon_unavailable}
      {:error, :rejected} -> {:error, :possible_handoff, :provider_rejected}
      {:error, :binding_not_found} -> {:error, :pre_handoff, :binding_not_found}
      {:error, :payload_too_large} -> {:error, :pre_handoff, :payload_too_large}
      {:error, _} -> {:error, :pre_handoff, :invalid_request}
      _ -> {:error, :pre_handoff, :invalid_request}
    end
  rescue
    _ -> {:error, :possible_handoff, :ambiguous_handoff}
  catch
    _, _ -> {:error, :possible_handoff, :ambiguous_handoff}
  end

  defp accepted(%Transport.Result{outcome: :accepted}), do: {:ok, %{provider_code: "accepted"}}
  defp accepted(_), do: {:error, :possible_handoff, :ambiguous_handoff}

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
