defmodule AlphaTwin.PersistedTraceTest do
  use ExUnit.Case, async: false
  import Ecto.Query

  alias Chimeway.APNS.RequestIntent

  setup do
    previous =
      for {application, key} <- managed_config(), into: %{} do
        {{application, key}, Application.get_env(application, key, :alpha_twin_missing)}
      end

    on_exit(fn ->
      Enum.each(previous, fn
        {{application, key}, :alpha_twin_missing} -> Application.delete_env(application, key)
        {{application, key}, value} -> Application.put_env(application, key, value)
      end)
    end)

    :ok
  end

  test "validated package persists a provider-accepted target and authorizes one protected open" do
    registry = start_supervised!(AlphaTwin.Registry)

    transport =
      start_supervised!(
        {AlphaTwin.ScriptedAPNSTransport, script: [{:accepted}], observer: self()}
      )

    {:ok, binding} =
      AlphaTwin.Registry.bind(registry, %{
        tenant_id: "alpha-twin",
        environment: :sandbox,
        topic: "com.example.alpha",
        installation_ref: "cw_installation_alpha_001",
        token: "raw-device-value-never-persisted"
      })

    {:ok, %{intent_ref: open_ref}} =
      AlphaTwin.Registry.issue_intent(registry, binding.binding_revision_ref)

    {:ok, request_intent} =
      RequestIntent.new(
        %{
          environment: :sandbox,
          topic: "com.example.alpha",
          apns_id: Ecto.UUID.generate(),
          expires_at: ~U[2030-08-25 12:00:00Z],
          open_ref: open_ref
        },
        []
      )

    Application.put_env(:chimeway, :alpha_twin_registry, registry)
    Application.put_env(:chimeway, :alpha_twin_apns_script, transport)
    Application.put_env(:chimeway, :alpha_twin_binding_ref, binding.binding_revision_ref)
    Application.put_env(:chimeway, :alpha_twin_request_intent, request_intent)
    Application.put_env(:chimeway, :dispatcher, Chimeway.Dispatch.Sync)
    Application.put_env(:chimeway, :target_resolver, AlphaTwin.IntegrationTargetResolver)
    Application.put_env(:chimeway, :target_adapter, Chimeway.Adapters.APNS)
    Application.put_env(:chimeway, :apns_binding_lookup, AlphaTwin.Registry)
    Application.put_env(:chimeway, :apns_transport, AlphaTwin.ScriptedAPNSTransport)
    Application.put_env(:crosswake, :companions, [Crosswake.Companions.Sigra])

    assert {:ok, result} =
             Chimeway.Trigger.trigger(AlphaTwin.IntegrationNotifier, %{},
               tenant_id: "alpha-twin",
               idempotency_key: "alpha-twin-#{System.unique_integer([:positive])}"
             )

    event = result.event
    [delivery_id] = result.trace.delivery_ids

    notification =
      Chimeway.Repo.one!(
        from(n in Chimeway.Notifications.Notification, where: n.event_id == ^event.id)
      )

    delivery = Chimeway.Repo.get!(Chimeway.Delivery, delivery_id)

    target =
      Chimeway.Repo.one!(from(t in Chimeway.DeliveryTarget, where: t.delivery_id == ^delivery.id))

    attempt =
      Chimeway.Repo.one!(
        from(a in Chimeway.DeliveryTargetAttempt, where: a.delivery_target_id == ^target.id)
      )

    assert event.id == notification.event_id
    assert notification.id == delivery.notification_id
    assert delivery.status == :succeeded
    assert target.status == :provider_accepted
    assert target.apns_request_intent["open_ref"] == open_ref
    assert attempt.outcome == :provider_accepted
    assert_receive {:alpha_twin_apns_request, redacted_request}
    refute inspect(redacted_request) =~ "raw-device-value-never-persisted"

    assert {:ok, explanation} =
             Chimeway.Traces.explain_delivery(delivery.id, tenant_id: "alpha-twin")

    assert explanation.delivery_id == delivery.id
    assert explanation.event_id == event.id
    assert explanation.status == :succeeded
    assert explanation.target_aggregate.target_count == 1
    assert [%{attempts: [%{outcome: :provider_accepted}]}] = explanation.targets

    evidence = AlphaTwin.ProtectedOpen.evidence(open_ref, binding.binding_revision_ref)

    assert {:allow, decision} =
             Crosswake.Companions.Chimeway.Resolver.resolve(
               AlphaTwin.ProtectedOpen.manifest(),
               evidence,
               AlphaTwin.IntentConsumer
             )

    assert decision.status == :allow
    assert decision.transition == :activate
    assert decision.route_id == "alpha_protected"

    assert {:deny, denial} =
             Crosswake.Companions.Chimeway.Resolver.resolve(
               AlphaTwin.ProtectedOpen.manifest(),
               evidence,
               AlphaTwin.IntentConsumer
             )

    assert denial.reason == :notification_open_denied
    assert denial.code == "notification.open.replayed"
  end

  defp managed_config do
    [
      chimeway: :alpha_twin_registry,
      chimeway: :alpha_twin_apns_script,
      chimeway: :alpha_twin_binding_ref,
      chimeway: :alpha_twin_request_intent,
      chimeway: :dispatcher,
      chimeway: :target_resolver,
      chimeway: :target_adapter,
      chimeway: :apns_binding_lookup,
      chimeway: :apns_transport,
      crosswake: :companions
    ]
  end
end

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

defmodule AlphaTwin.DeliveryMatrixTest do
  use ExUnit.Case, async: true

  @moduletag :alpha_twin_delivery_matrix

  test "the complete ordered delivery ledger produces stable, separated durable facts" do
    ledger = scenario_ledger()

    assert {:ok, result} = AlphaTwin.Runner.run(ledger: ledger)

    assert Enum.take(result.scenario_ids, length(AlphaTwin.Runner.delivery_scenario_ids())) ==
             AlphaTwin.Runner.delivery_scenario_ids()

    assert Enum.all?(result.scenario_results, &(&1.durable == :converged))
    assert Enum.all?(result.scenario_results, &(&1.explanation == :explained))
    assert result.claim_taxonomy.provider_acceptance == :provider_accepted
    assert result.claim_taxonomy.protected_open == :not_attempted
    assert result.claim_taxonomy.inbox_seen == :not_attempted
    assert result.claim_taxonomy.inbox_read == :not_attempted
  end

  test "the ledger rejects missing duplicate reordered unknown non-string and extra fields" do
    valid = %{"schema_version" => 1, "scenario_ids" => AlphaTwin.Runner.delivery_scenario_ids()}

    for invalid <- [
          Map.delete(valid, "scenario_ids"),
          %{valid | "scenario_ids" => valid["scenario_ids"] ++ ["two_installation_fanout"]},
          %{valid | "scenario_ids" => Enum.reverse(valid["scenario_ids"])},
          %{valid | "scenario_ids" => valid["scenario_ids"] ++ ["unknown"]},
          %{valid | "scenario_ids" => [1 | tl(valid["scenario_ids"])]},
          Map.put(valid, "debug", true)
        ] do
      assert {:error, :invalid_ledger} = AlphaTwin.Runner.validate_ledger(invalid)
    end
  end

  defp scenario_ledger do
    System.get_env("CHIMEWAY_ALPHA_TWIN_LEDGER") ||
      Path.expand("../../../../priv/alpha_twin/scenario-ledger.json", __DIR__)
  end
end

defmodule AlphaTwin.SafetyMatrixTest do
  use ExUnit.Case, async: true

  @moduletag :alpha_twin_safety_matrix

  test "the complete ledger adds each protected-open and recursive-scan scenario once" do
    ledger =
      System.get_env("CHIMEWAY_ALPHA_TWIN_LEDGER") ||
        Path.expand("../../../../priv/alpha_twin/scenario-ledger.json", __DIR__)

    assert {:ok, result} = AlphaTwin.Runner.run(ledger: ledger)
    assert result.scenario_ids == AlphaTwin.Runner.all_scenario_ids()
    assert Enum.count(result.scenario_ids, &(&1 == "offline_reauthorization")) == 1
    assert Enum.any?(result.scenario_results, &(&1.outcome == :protected_open_once))
    assert Enum.any?(result.scenario_results, &(&1.outcome == :denied_no_fallback))
    assert Enum.any?(result.scenario_results, &(&1.outcome == :replay_rejected))
  end

  test "proof summary recursively rejects sentinels without echoing the sensitive value" do
    sentinel = "raw-token-alpha-do-not-emit"

    assert {:error, %{rule: :sensitive_value, path: ["trace", "nested"]}} =
             AlphaTwin.ProofSummary.render(%{
               "schema_version" => 1,
               "scenario_results" => [],
               "claim_taxonomy" => %{},
               "trace" => %{"nested" => sentinel}
             })

    refute inspect(AlphaTwin.ProofSummary.render(%{"trace" => sentinel})) =~ sentinel
  end

  test "proof summary encodes only its exact closed schema with separate outcome taxonomy" do
    attrs = %{
      "schema_version" => 1,
      "proof_class" => "alpha_twin",
      "chimeway_artifact_sha256" => String.duplicate("a", 64),
      "crosswake_sha" => String.duplicate("b", 40),
      "scenario_results" => [
        %{"id" => "offline_reauthorization", "outcome" => "protected_open_once"}
      ],
      "claim_taxonomy" => %{
        "provider_acceptance" => "provider_accepted",
        "protected_open" => "authorized",
        "inbox_seen" => "not_attempted",
        "inbox_read" => "not_attempted"
      }
    }

    assert {:ok, proof} = AlphaTwin.ProofSummary.render(attrs)
    assert proof == Jason.encode!(attrs)

    assert {:error, %{rule: :invalid_schema, path: []}} =
             AlphaTwin.ProofSummary.render(Map.put(attrs, "debug", true))
  end
end
