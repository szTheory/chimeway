defmodule Chimeway.Adapters.APNSTest do
  use ExUnit.Case, async: false

  alias Chimeway.APNS.{BindingLookup, RequestIntent, Transport}
  alias Chimeway.Adapters.APNS
  alias Chimeway.TargetAdapter.TargetEnvelope

  defmodule Lookup do
    @behaviour BindingLookup
    def resolve_binding(request),
      do: Application.fetch_env!(:chimeway, :apns_lookup_reply).(request)

    def invalidate_binding(_key), do: {:ok, %BindingLookup.InvalidationResult{status: :unchanged}}
  end

  defmodule RaisingPayloadBuilder do
    def build(_, _), do: raise("payload-sentinel-never-emitted")
  end

  setup do
    previous =
      for key <- [
            :apns_binding_lookup,
            :apns_transport,
            :apns_lookup_reply,
            :apns_payload_builder,
            :apns_fake_transport_pid,
            :apns_fake_transport_result
          ],
          do: {key, Application.get_env(:chimeway, key)}

    Application.put_env(:chimeway, :apns_binding_lookup, Lookup)
    Application.put_env(:chimeway, :apns_transport, Chimeway.Test.APNSFakeTransport)
    Application.put_env(:chimeway, :apns_fake_transport_pid, self())

    Application.put_env(:chimeway, :apns_lookup_reply, fn request ->
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
    end)
  end

  test "adapter resolves exact transient material and sends one closed request" do
    assert {:provider_accepted, %{provider_code: "accepted", accepted_at: %DateTime{}}} =
             APNS.deliver(envelope(), [])

    assert_receive {:apns_push, "dispatcher-sandbox", request}
    assert request.device_token == "[REDACTED]"
    assert request.topic == "com.example.app"
    assert request.environment == :sandbox
    assert request.id == "8d9c95fe-a6fd-4e82-b451-cbd59f02d948"
    assert request.priority == 10
    assert request.push_type == :alert
    assert request.collapse_id == nil

    assert request.payload.json == %{
             "aps" => %{"alert" => %{"title" => "Hello", "body" => "World"}},
             "chimeway_open_ref" => "open-ref"
           }

    refute inspect(request) =~ "raw-token-sentinel"
  end

  test "mismatched lookup and post-emission uncertainty become stable safe outcomes" do
    Application.put_env(:chimeway, :apns_lookup_reply, fn request ->
      {:ok,
       %BindingLookup.Transient{
         tenant_id: request.tenant_id,
         environment: request.environment,
         topic: "other.topic",
         binding_revision_ref: request.binding_revision_ref,
         device_token: "raw-token-sentinel",
         dispatcher_ref: "dispatcher"
       }}
    end)

    assert {:pre_handoff_retryable, %{provider_code: "binding_not_found"}} =
             APNS.deliver(envelope(), [])

    refute_receive {:apns_push, _, _}

    Application.put_env(:chimeway, :apns_lookup_reply, fn request ->
      {:ok,
       %BindingLookup.Transient{
         tenant_id: request.tenant_id,
         environment: request.environment,
         topic: request.topic,
         binding_revision_ref: request.binding_revision_ref,
         device_token: "raw-token-sentinel",
         dispatcher_ref: "dispatcher"
       }}
    end)

    Application.put_env(:chimeway, :apns_fake_transport_result, {:error, :ambiguous})

    assert {:error, :possible_handoff, :ambiguous_handoff} = APNS.deliver(envelope(), [])
    assert_receive {:apns_push, _, _}
  end

  test "an unavailable Pigeon dispatcher remains retryable before provider handoff" do
    Application.put_env(:chimeway, :apns_fake_transport_result, {:error, :pigeon_unavailable})

    assert {:pre_handoff_retryable, %{provider_code: "pigeon_unavailable"}} =
             APNS.deliver(envelope(), [])
  end

  test "lookup and payload-builder exceptions are bounded before transport handoff" do
    Application.put_env(:chimeway, :apns_lookup_reply, fn _ ->
      raise "lookup-token-sentinel-never-emitted"
    end)

    result = APNS.deliver(envelope(), [])
    assert {:pre_handoff_retryable, %{provider_code: "binding_lookup_failed"}} = result
    refute_receive {:apns_push, _, _}
    refute inspect(result) =~ "lookup-token-sentinel-never-emitted"
    refute inspect(result) =~ "possible_provider_handoff"

    Application.put_env(:chimeway, :apns_lookup_reply, fn request ->
      {:ok,
       %BindingLookup.Transient{
         tenant_id: request.tenant_id,
         environment: request.environment,
         topic: request.topic,
         binding_revision_ref: request.binding_revision_ref,
         device_token: "raw-token-sentinel",
         dispatcher_ref: "dispatcher"
       }}
    end)

    Application.put_env(:chimeway, :apns_payload_builder, RaisingPayloadBuilder)
    result = APNS.deliver(envelope(), [])
    assert {:permanent, %{provider_code: "invalid_request"}} = result
    refute_receive {:apns_push, _, _}
    refute inspect(result) =~ "payload-sentinel-never-emitted"
    refute inspect(result) =~ "possible_provider_handoff"
  end

  test "malformed stored intent is rejected before lookup or transport" do
    for {field, unsafe_value} <- [
          {"open_ref", "https://unsafe.example/open"},
          {"collapse_id", "unsafe\rheader"}
        ] do
      target = envelope().target
      storage = Map.put(target.apns_request_intent, field, unsafe_value)

      result =
        APNS.deliver(
          %TargetEnvelope{envelope() | target: %{target | apns_request_intent: storage}},
          []
        )

      assert {:permanent, %{provider_code: "invalid_request"}} = result
      refute_receive {:apns_push, _, _}
      refute inspect(result) =~ unsafe_value
    end
  end

  test "Pigeon is optional and raw extraction fails closed unless the invalidation triple is complete" do
    assert {:error, :pigeon_unavailable} = Transport.pigeon_push("dispatcher", request())

    assert {:ok, %{status: 410, reason: :unregistered, timestamp: 1}} =
             Transport.PigeonAdapter.extract_response(%{
               "status" => 410,
               "reason" => "Unregistered",
               "timestamp" => 1
             })

    for response <- [
          %{},
          %{"status" => 410, "reason" => "Unregistered"},
          %{"status" => 400, "reason" => "Unregistered", "timestamp" => 1},
          %{"status" => 410, "reason" => "BadDeviceToken", "timestamp" => 1}
        ] do
      assert {:error, :incomplete_provider_response} =
               Transport.PigeonAdapter.extract_response(response)
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

  defp request do
    {:ok, payload} =
      Chimeway.APNS.Payload.build(%{"title" => "Hello", "body" => "World"}, "open-ref")

    %Transport.Request{
      device_token: "raw-token-sentinel",
      topic: "com.example.app",
      environment: :sandbox,
      id: "8d9c95fe-a6fd-4e82-b451-cbd59f02d948",
      expiration: 0,
      collapse_id: nil,
      priority: 10,
      push_type: :alert,
      payload: payload
    }
  end
end
