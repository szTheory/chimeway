defmodule Chimeway.APNS.ResultTest do
  use ExUnit.Case, async: false

  alias Chimeway.APNS.{BindingLookup, RequestIntent, Transport}
  alias Chimeway.Adapters.APNS
  alias Chimeway.TargetAdapter.TargetEnvelope

  defmodule Lookup do
    @behaviour BindingLookup

    def resolve_binding(request), do: Application.fetch_env!(:chimeway, :apns_result_lookup).(request)
    def invalidate_binding(key), do: Application.fetch_env!(:chimeway, :apns_result_invalidate).(key)
  end

  setup do
    previous =
      for key <- [:apns_binding_lookup, :apns_transport, :apns_result_lookup, :apns_result_invalidate],
          do: {key, Application.get_env(:chimeway, key)}

    Application.put_env(:chimeway, :apns_binding_lookup, Lookup)
    Application.put_env(:chimeway, :apns_transport, Chimeway.Test.APNSFakeTransport)
    Application.put_env(:chimeway, :apns_fake_transport_pid, self())

    Application.put_env(:chimeway, :apns_result_lookup, fn request ->
      {:ok,
       %BindingLookup.Transient{
         tenant_id: request.tenant_id,
         environment: request.environment,
         topic: request.topic,
         binding_revision_ref: request.binding_revision_ref,
         device_token: "raw-token-sentinel",
         dispatcher_ref: "dispatcher-sandbox"
       }}
    end)

    on_exit(fn ->
      Enum.each(previous, fn
        {key, nil} -> Application.delete_env(:chimeway, key)
        {key, value} -> Application.put_env(:chimeway, key, value)
      end)

      Application.delete_env(:chimeway, :apns_fake_transport_pid)
      Application.delete_env(:chimeway, :apns_fake_transport_result)
    end)
  end

  test "only an exact 410 invalidation triple and exact host CAS can invalidate" do
    Application.put_env(:chimeway, :apns_fake_transport_result, {
      :ok,
      %Transport.Result{
        outcome: :rejected,
        code: :unregistered,
        status: 410,
        reason: "Unregistered",
        timestamp: 1
      }
    })

    Application.put_env(:chimeway, :apns_result_invalidate, fn key ->
      send(self(), {:invalidate, key})
      {:ok, %BindingLookup.InvalidationResult{status: :invalidated}}
    end)

    assert {:invalidated, %{provider_status: 410, provider_reason: "unregistered", provider_timestamp: 1}} =
             APNS.deliver(envelope(), [])

    assert_receive {:invalidate,
                    %BindingLookup.InvalidationKey{
                      tenant_id: "tenant-1",
                      environment: :sandbox,
                      topic: "com.example.app",
                      binding_revision_ref: "cw_binding_revision_001"
                    }}

    for result <- [
          %Transport.Result{outcome: :rejected, code: :unregistered, status: 410, reason: "Unregistered"},
          %Transport.Result{outcome: :rejected, code: :bad_device_token, status: 410, reason: "BadDeviceToken", timestamp: 1},
          %Transport.Result{outcome: :rejected, code: :unregistered, status: 400, reason: "Unregistered", timestamp: 1}
        ] do
      Application.put_env(:chimeway, :apns_fake_transport_result, {:ok, result})
      assert {:permanent, _facts} = APNS.deliver(envelope(), [])
      refute_receive {:invalidate, _}
    end
  end

  defp envelope do
    {:ok, intent} =
      RequestIntent.new(
        %{
          environment: :sandbox,
          topic: "com.example.app",
          apns_id: "8d9c95fe-a6fd-4e82-b451-cbd59f02d948",
          expires_at: DateTime.add(DateTime.utc_now(), 60, :second),
          open_ref: "open-ref"
        },
        []
      )

    %TargetEnvelope{
      delivery: %Chimeway.Delivery{render_data: %{"title" => "Hello", "body" => "World"}},
      target: %Chimeway.DeliveryTarget{
        tenant_id: "tenant-1",
        binding_revision_ref: "cw_binding_revision_001",
        apns_request_intent: RequestIntent.to_storage(intent)
      }
    }
  end
end
