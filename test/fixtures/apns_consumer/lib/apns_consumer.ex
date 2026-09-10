defmodule APNSConsumer do
  @moduledoc false

  @behaviour Chimeway.APNS.BindingLookup

  alias Chimeway.APNS.{BindingLookup, RequestIntent, Transport}
  alias Chimeway.APNS.Transport.{Request, Result}
  alias Chimeway.TargetAdapter.TargetEnvelope

  def core_smoke, do: Chimeway.SafeEvidence.delivery_metadata(%{"source" => "apns-consumer"})

  def accepted_result do
    {:ok, %Result{outcome: :accepted, code: :accepted}}
  end

  def expired_token_result do
    Transport.PigeonAdapter.extract_response(%{
      "status" => 410,
      "reason" => "ExpiredToken",
      "timestamp" => 1_725_000_000
    })
  end

  def request do
    %Request{
      device_token: "fixture-token-never-emitted",
      topic: "com.example.chimeway",
      environment: :sandbox,
      id: "9a2c7c14-9876-4bca-aabb-0123456789ab",
      expiration: 1_725_003_600,
      priority: 10,
      push_type: :alert,
      payload: %{json: %{"aps" => %{"alert" => %{"title" => "Fixture", "body" => "Accepted"}}}}
    }
  end

  def original_binding_key do
    %BindingLookup.InvalidationKey{
      tenant_id: "tenant-1",
      environment: :sandbox,
      topic: "com.example.app",
      binding_revision_ref: "cw_binding_revision_001"
    }
  end

  def start_binding_registry(test_pid, dispatcher) do
    Agent.start_link(fn ->
      %{
        original: :active,
        replacement: :active,
        successful_invalidations: 0,
        test_pid: test_pid,
        dispatcher: dispatcher
      }
    end)
  end

  def binding_state do
    registry = Application.fetch_env!(:apns_consumer, :binding_registry)
    Agent.get(registry, &Map.take(&1, [:original, :replacement, :successful_invalidations]))
  end

  def start_dispatcher do
    {:ok, _started} = Application.ensure_all_started(:pigeon)

    apns_config = Module.concat(["Pigeon", "APNS", "Config"])
    notification_queue = Module.concat(["Pigeon", "NotificationQueue"])
    dispatcher = Module.concat(["Pigeon", "Dispatcher"])
    adapter = Module.concat(["Chimeway", "APNS", "Transport", "PigeonAdapter"])

    state = %{
      config: struct(apns_config),
      queue: apply(notification_queue, :new, []),
      socket: :fixture_socket,
      stream_id: 1
    }

    apply(dispatcher, :start_link, [
      [adapter: adapter, chimeway_apns_state: state, name: nil, pool_size: 1]
    ])
  end

  def deliver(dispatcher) do
    Chimeway.Adapters.APNS.deliver(envelope(dispatcher), [])
  end

  def install_live_binding(device_token, dispatcher, topic)
      when is_binary(device_token) and is_pid(dispatcher) and is_binary(topic) do
    Application.put_env(:apns_consumer, :live_binding, %{
      device_token: device_token,
      dispatcher: dispatcher,
      topic: topic
    })
  end

  def clear_live_binding, do: Application.delete_env(:apns_consumer, :live_binding)

  def deliver_live(topic, open_ref) when is_binary(topic) and is_binary(open_ref) do
    {:ok, intent} =
      RequestIntent.new(
        %{
          environment: :sandbox,
          topic: topic,
          apns_id: Ecto.UUID.generate(),
          expires_at: DateTime.add(DateTime.utc_now(), 120, :second),
          open_ref: open_ref
        },
        []
      )

    envelope = %TargetEnvelope{
      delivery: %Chimeway.Delivery{
        render_data: %{
          "title" => "Chimeway physical proof",
          "body" => "Provider handoff reached this iPhone. Tap to verify the protected open."
        }
      },
      target: %Chimeway.DeliveryTarget{
        tenant_id: "physical-proof-tenant",
        binding_revision_ref: "physical-proof-binding-v1",
        apns_request_intent: RequestIntent.to_storage(intent)
      }
    }

    Chimeway.Adapters.APNS.deliver(envelope, [])
  end

  @impl true
  def resolve_binding(%BindingLookup.Request{} = request) do
    case Application.get_env(:apns_consumer, :live_binding) do
      %{device_token: token, dispatcher: dispatcher, topic: topic}
      when request.tenant_id == "physical-proof-tenant" and request.environment == :sandbox and
             request.topic == topic and
             request.binding_revision_ref == "physical-proof-binding-v1" ->
        {:ok,
         %BindingLookup.Transient{
           tenant_id: request.tenant_id,
           environment: request.environment,
           topic: request.topic,
           binding_revision_ref: request.binding_revision_ref,
           device_token: token,
           dispatcher_ref: dispatcher
         }}

      _ ->
        resolve_fixture_binding(request)
    end
  end

  @impl true
  def invalidate_binding(%BindingLookup.InvalidationKey{} = key) do
    registry = Application.fetch_env!(:apns_consumer, :binding_registry)

    Agent.get_and_update(registry, fn state ->
      send(state.test_pid, {:binding_invalidation, key})

      if key == original_binding_key() and state.original == :active do
        result = {:ok, %BindingLookup.InvalidationResult{status: :invalidated}}

        {result,
         %{
           state
           | original: :invalidated,
             successful_invalidations: state.successful_invalidations + 1
         }}
      else
        {{:ok, %BindingLookup.InvalidationResult{status: :unchanged}}, state}
      end
    end)
  end

  def evidence do
    ~s({"provider":"apns","outcome":"provider_accepted","environment":"sandbox","proof":"not_live_not_device_not_open"})
  end

  defp envelope(_dispatcher) do
    {:ok, intent} =
      RequestIntent.new(
        %{
          environment: :sandbox,
          topic: "com.example.app",
          apns_id: "9a2c7c14-9876-4bca-aabb-0123456789ab",
          expires_at: DateTime.add(DateTime.utc_now(), 60, :second),
          open_ref: "open-ref"
        },
        []
      )

    %TargetEnvelope{
      delivery: %Chimeway.Delivery{render_data: %{"title" => "Fixture", "body" => "Accepted"}},
      target: %Chimeway.DeliveryTarget{
        tenant_id: "tenant-1",
        binding_revision_ref: "cw_binding_revision_001",
        apns_request_intent: RequestIntent.to_storage(intent)
      }
    }
  end

  defp exact_original?(request) do
    request.tenant_id == "tenant-1" and request.environment == :sandbox and
      request.topic == "com.example.app" and
      request.binding_revision_ref == "cw_binding_revision_001"
  end

  defp resolve_fixture_binding(request) do
    registry = Application.fetch_env!(:apns_consumer, :binding_registry)

    Agent.get(registry, fn state ->
      if exact_original?(request) do
        {:ok,
         %BindingLookup.Transient{
           tenant_id: request.tenant_id,
           environment: request.environment,
           topic: request.topic,
           binding_revision_ref: request.binding_revision_ref,
           device_token: "fixture-token-never-emitted",
           dispatcher_ref: state.dispatcher
         }}
      else
        {:error, :binding_not_found}
      end
    end)
  end
end
