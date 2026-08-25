Code.require_file("../lib/alpha_twin/clock.ex", __DIR__)
Code.require_file("../lib/alpha_twin/registry.ex", __DIR__)
Code.require_file("../lib/alpha_twin/scripted_apns_transport.ex", __DIR__)

defmodule AlphaTwin.SeamsTest do
  use ExUnit.Case, async: false

  @moduletag :alpha_twin_seams

  alias AlphaTwin.{Clock, Registry, ScriptedAPNSTransport}
  alias Chimeway.APNS.{BindingLookup, RequestIntent}
  alias Chimeway.Adapters.APNS
  alias Chimeway.TargetAdapter.TargetEnvelope

  setup do
    now = ~U[2026-08-25 12:00:00.000000Z]
    {:ok, clock} = Clock.start_link(now: now)
    {:ok, registry} = Registry.start_link()

    on_exit(fn ->
      Process.exit(clock, :normal)
      Process.exit(registry, :normal)
    end)

    %{clock: clock, registry: registry, now: now}
  end

  test "production clock defaults to system UTC while fixture time advances without sleeps", %{
    clock: clock,
    now: now
  } do
    assert %DateTime{} = Chimeway.Clock.now()
    assert ^now = Chimeway.Clock.now(clock: Clock, clock_pid: clock)
    assert :ok = Clock.advance(clock, 61)
    assert Clock.now(clock) == DateTime.add(now, 61, :second)
    refute File.read!(Path.join(__DIR__, "../lib/alpha_twin/clock.ex")) =~ "Process" <> ".sleep"
  end

  test "registry keeps tokens private, invalidates only exact old revision, and consumes an intent once",
       %{registry: registry} do
    {:ok, first} = Registry.bind(registry, binding_attrs("raw-token-one"))

    {:ok, second} =
      Registry.bind(registry, binding_attrs("raw-token-two", installation_ref: "install-2"))

    refute inspect(first) =~ "raw-token-one"
    assert first.installation_ref != second.installation_ref

    {:ok, replacement} =
      Registry.rotate(registry, first.binding_revision_ref, "raw-token-one-rotated")

    assert {:ok, %BindingLookup.InvalidationResult{status: :unchanged}} =
             Registry.invalidate(registry, invalidation(first))

    assert {:ok, %BindingLookup.Transient{device_token: "raw-token-one-rotated"}} =
             Registry.resolve(registry, request(replacement))

    assert {:error, :binding_not_found} = Registry.resolve(registry, request(first))

    assert {:ok, %{intent_ref: intent_ref}} =
             Registry.issue_intent(registry, replacement.binding_revision_ref)

    assert {:ok, %{classification: :accepted}} = Registry.consume_intent(registry, intent_ref)
    assert {:error, :replayed} = Registry.consume_intent(registry, intent_ref)
  end

  test "scripted transport redacts observations and drives all shipped adapter outcomes", %{
    registry: registry,
    now: now
  } do
    {:ok, binding} = Registry.bind(registry, binding_attrs("raw-token-never-observed"))
    Application.put_env(:chimeway, :apns_binding_lookup, Registry)
    Application.put_env(:chimeway, :alpha_twin_registry, registry)

    on_exit(fn ->
      Application.delete_env(:chimeway, :apns_binding_lookup)
      Application.delete_env(:chimeway, :alpha_twin_registry)
    end)

    for {script, expected} <- [
          {{:accepted}, :provider_accepted},
          {{:retryable}, :provider_retryable},
          {{:permanent}, :permanent},
          {{:ambiguous}, :ambiguous_handoff},
          {{:invalidating, 1}, :invalidated}
        ] do
      {:ok, transport} = ScriptedAPNSTransport.start_link(script: [script], observer: self())

      assert_result(
        expected,
        APNS.deliver(envelope(binding, now),
          transport: ScriptedAPNSTransport,
          script_pid: transport,
          now: now
        )
      )

      assert_receive {:alpha_twin_apns_request, observation}
      refute inspect(observation) =~ "raw-token-never-observed"
      refute inspect(observation) =~ "Hello"
      assert :ok = ScriptedAPNSTransport.assert_drained(transport)
      Process.exit(transport, :normal)
    end
  end

  defp binding_attrs(token, overrides \\ []) do
    Map.merge(
      %{
        tenant_id: "alpha-tenant",
        environment: :sandbox,
        topic: "com.example.alpha",
        installation_ref: "install-1",
        token: token
      },
      Map.new(overrides)
    )
  end

  defp request(binding),
    do: %BindingLookup.Request{
      tenant_id: binding.tenant_id,
      environment: binding.environment,
      topic: binding.topic,
      binding_revision_ref: binding.binding_revision_ref
    }

  defp invalidation(binding),
    do: %BindingLookup.InvalidationKey{
      tenant_id: binding.tenant_id,
      environment: binding.environment,
      topic: binding.topic,
      binding_revision_ref: binding.binding_revision_ref
    }

  defp envelope(binding, now) do
    {:ok, intent} =
      RequestIntent.new(
        %{
          environment: binding.environment,
          topic: binding.topic,
          apns_id: "8d9c95fe-a6fd-4e82-b451-cbd59f02d948",
          expires_at: DateTime.add(now, 60, :second),
          open_ref: "cw_open_alpha_001"
        },
        []
      )

    %TargetEnvelope{
      delivery: %Chimeway.Delivery{render_data: %{"title" => "Hello", "body" => "World"}},
      target: %Chimeway.DeliveryTarget{
        tenant_id: binding.tenant_id,
        binding_revision_ref: binding.binding_revision_ref,
        apns_request_intent: RequestIntent.to_storage(intent)
      }
    }
  end

  defp assert_result(:ambiguous_handoff, {:error, :possible_handoff, :ambiguous_handoff}), do: :ok
  defp assert_result(expected, {expected, _facts}), do: :ok
end
