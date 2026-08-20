defmodule Chimeway.APNS.TracerTest do
  use Chimeway.DataCase, async: false

  alias Chimeway.APNS.RequestIntent

  defmodule Lookup do
    def resolve(tenant_id, environment, topic, binding_revision_ref) do
      send(Application.fetch_env!(:chimeway, :apns_tracer_pid), {:lookup, tenant_id, environment, topic, binding_revision_ref})
      {:ok, %{tenant_id: tenant_id, environment: environment, topic: topic, binding_revision_ref: binding_revision_ref, token: "raw-token-sentinel", dispatcher_ref: "dispatcher-opaque"}}
    end
  end

  defmodule Transport do
    def deliver(dispatcher_ref, request) do
      send(Application.fetch_env!(:chimeway, :apns_tracer_pid), {:transport, dispatcher_ref, request})
      {:ok, :accepted}
    end
  end

  setup do
    previous_lookup = Application.get_env(:chimeway, :apns_binding_lookup)
    previous_transport = Application.get_env(:chimeway, :apns_transport)
    Application.put_env(:chimeway, :apns_binding_lookup, Lookup)
    Application.put_env(:chimeway, :apns_transport, Transport)
    Application.put_env(:chimeway, :apns_tracer_pid, self())

    on_exit(fn ->
      restore(:apns_binding_lookup, previous_lookup)
      restore(:apns_transport, previous_transport)
      Application.delete_env(:chimeway, :apns_tracer_pid)
    end)
  end

  test "request intents retain only durable APNs routing facts" do
    expires_at = DateTime.add(DateTime.utc_now(), 60, :second) |> DateTime.truncate(:second)

    assert {:ok, intent} =
             RequestIntent.new(
               %{
                 environment: :sandbox,
                 topic: "com.example.chimeway",
                 apns_id: "8d9c95fe-a6fd-4e82-b451-cbd59f02d948",
                 expires_at: expires_at,
                 open_ref: "open_opaque_ref"
               },
               binding_revision_ref: "cw_apns_tracer_001"
             )

    assert intent.environment == :sandbox
    assert intent.collapse_id == nil
    assert %{"environment" => "sandbox", "topic" => "com.example.chimeway"} =
             RequestIntent.to_storage(intent)
  end

  test "accepted adapter handoff resolves scoped material only after durable intent validation" do
    expires_at = DateTime.add(DateTime.utc_now(), 60, :second) |> DateTime.truncate(:second)
    {:ok, intent} = RequestIntent.new(%{environment: :sandbox, topic: "com.example.chimeway", apns_id: "8d9c95fe-a6fd-4e82-b451-cbd59f02d948", expires_at: expires_at, open_ref: "open_opaque_ref"}, [])
    target = %Chimeway.DeliveryTarget{tenant_id: "tenant-1", binding_revision_ref: "cw_apns_tracer_001", apns_request_intent: RequestIntent.to_storage(intent)}
    delivery = %Chimeway.Delivery{render_data: %{"title" => "Hello", "body" => "World"}}

    assert {:ok, %{provider_code: "accepted"}} =
             Chimeway.Adapters.APNS.deliver(%Chimeway.TargetAdapter.TargetEnvelope{delivery: delivery, target: target}, [])

    assert_receive {:lookup, "tenant-1", :sandbox, "com.example.chimeway", "cw_apns_tracer_001"}
    assert_receive {:transport, "dispatcher-opaque", %{"aps" => %{"alert" => %{"title" => "Hello", "body" => "World"}}, "chimeway_open_ref" => "open_opaque_ref"}}
  end

  test "expired intent never reaches host lookup or transport" do
    expires_at = DateTime.add(DateTime.utc_now(), -1, :second) |> DateTime.truncate(:second)
    {:ok, intent} = RequestIntent.new(%{environment: :sandbox, topic: "com.example.chimeway", apns_id: "8d9c95fe-a6fd-4e82-b451-cbd59f02d948", expires_at: expires_at, open_ref: "open_opaque_ref"}, [])
    target = %Chimeway.DeliveryTarget{tenant_id: "tenant-1", binding_revision_ref: "cw_apns_tracer_001", apns_request_intent: RequestIntent.to_storage(intent)}

    assert {:error, :pre_handoff, :expired} =
             Chimeway.Adapters.APNS.deliver(%Chimeway.TargetAdapter.TargetEnvelope{delivery: %Chimeway.Delivery{}, target: target}, [])

    refute_receive {:lookup, _, _, _, _}
    refute_receive {:transport, _, _}
  end

  defp restore(key, nil), do: Application.delete_env(:chimeway, key)
  defp restore(key, value), do: Application.put_env(:chimeway, key, value)
end
