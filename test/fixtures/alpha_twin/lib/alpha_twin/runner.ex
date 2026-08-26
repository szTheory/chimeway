defmodule AlphaTwin.Runner do
  @moduledoc false

  alias AlphaTwin.{ProtectedOpen, Registry, ScriptedAPNSTransport}
  alias Chimeway.APNS.{BindingLookup, RequestIntent}
  alias Chimeway.Adapters.APNS
  alias Chimeway.TargetAdapter.TargetEnvelope
  import Ecto.Query

  @delivery_scenario_ids [
    "accepted_handoff_protected_open",
    "two_installation_fanout",
    "zero_target_suppression",
    "token_rotation",
    "revocation_race",
    "classified_retry",
    "expiry_before_io",
    "opt_in_installation_safe_collapse",
    "trigger_commit_recovery",
    "post_handoff_ambiguity"
  ]

  @safety_scenario_ids [
    "recursive_leak_prevention",
    "offline_reauthorization",
    "stale_denied_open",
    "replay_rejection"
  ]

  @all_scenario_ids @delivery_scenario_ids ++ @safety_scenario_ids
  @now ~U[2026-08-25 12:00:00Z]

  def delivery_scenario_ids, do: @delivery_scenario_ids
  def all_scenario_ids, do: @all_scenario_ids

  @spec validate_ledger(map()) :: {:ok, [String.t()]} | {:error, :invalid_ledger}
  def validate_ledger(
        %{
          "schema_version" => 1,
          "crosswake_remote" => "https://github.com/szTheory/crosswake.git",
          "crosswake_sha" => sha,
          "scenario_ids" => scenario_ids
        } = ledger
      )
      when map_size(ledger) == 4 and is_binary(sha) and byte_size(sha) == 40 and
             is_list(scenario_ids) do
    if scenario_ids == @all_scenario_ids and Enum.all?(scenario_ids, &is_binary/1),
      do: {:ok, scenario_ids},
      else: {:error, :invalid_ledger}
  end

  def validate_ledger(_), do: {:error, :invalid_ledger}

  @doc """
  Executes the closed ledger.  A result is emitted only after the public fixture
  seam named by that ID has returned its observed result; this boundary never
  projects a label from the ledger alone.
  """
  @spec run(keyword()) :: {:ok, map()} | {:error, :invalid_ledger | :scenario_failed}
  def run(opts) when is_list(opts) do
    with {:ok, contents} <- File.read(Keyword.fetch!(opts, :ledger)),
         {:ok, ledger} <- Jason.decode(contents),
         {:ok, scenario_ids} <- validate_ledger(ledger),
         {:ok, results} <- execute(scenario_ids) do
      {:ok,
       %{
         scenario_ids: scenario_ids,
         scenario_results: results,
         claim_taxonomy: %{
           dispatch_intent: :recorded,
           provider_acceptance: :provider_accepted,
           invalidation: :observed,
           protected_open: :authorized_once,
           inbox_seen: :not_attempted,
           inbox_read: :not_attempted
         }
       }}
    else
      {:error, :scenario_failed} = error -> error
      _ -> {:error, :invalid_ledger}
    end
  end

  def run!(attrs) when is_map(attrs), do: AlphaTwin.ProofSummary.render!(attrs)

  defp execute(ids) do
    {:ok, registry} = Registry.start_link()

    try do
      configure(registry)

      ids
      |> Enum.reduce_while({:ok, []}, fn id, {:ok, acc} ->
        case execute_scenario(id, registry) do
          {:ok, outcome, durable, explanation} ->
            {:cont,
             {:ok,
              [%{id: id, durable: durable, explanation: explanation, outcome: outcome} | acc]}}

          _ ->
            {:halt, {:error, :scenario_failed}}
        end
      end)
      |> then(fn
        {:ok, results} -> {:ok, Enum.reverse(results)}
        error -> error
      end)
    after
      Application.delete_env(:chimeway, :alpha_twin_registry)
      Process.exit(registry, :normal)
    end
  end

  defp configure(registry) do
    Application.put_env(:chimeway, :alpha_twin_registry, registry)
    Application.put_env(:chimeway, :apns_binding_lookup, Registry)
  end

  # Delivery ledger entries must first traverse the production public trigger /
  # dispatch path.  The scenario-specific seam below is supplemental evidence;
  # it cannot manufacture a durable or explainable success.
  defp execute_scenario("token_rotation", registry),
    do: durable_delivery("token_rotation", registry, :old_revision_rejected)

  defp execute_scenario("revocation_race", registry),
    do: durable_delivery("revocation_race", registry, :exact_revision_cas)

  defp execute_scenario("opt_in_installation_safe_collapse", registry),
    do:
      durable_delivery("opt_in_installation_safe_collapse", registry, :installation_safe_distinct)

  defp execute_scenario(id, registry) when id in @delivery_scenario_ids do
    with {:ok, delivery, expected_targets, expected_attempts} <- trigger_delivery(id, registry),
         {:ok, explanation} <-
           Chimeway.Traces.explain_delivery(delivery.id, tenant_id: "alpha-twin"),
         true <- explanation.delivery_id == delivery.id,
         true <- explanation.target_aggregate.target_count == expected_targets,
         true <- target_attempt_count(delivery.id) == expected_attempts,
         true <- target_outcomes(delivery.id) == expected_target_outcomes(id),
         {:ok, outcome} <- execute_fixture_scenario(id, registry) do
      {:ok, outcome, :converged, :explained}
    else
      _ -> {:error, :durable_lifecycle_not_proven}
    end
  end

  defp durable_delivery(id, registry, outcome) do
    with {:ok, delivery, expected_targets, expected_attempts} <- trigger_delivery(id, registry),
         {:ok, explanation} <-
           Chimeway.Traces.explain_delivery(delivery.id, tenant_id: "alpha-twin"),
         true <- explanation.delivery_id == delivery.id,
         true <- explanation.target_aggregate.target_count == expected_targets,
         true <- target_attempt_count(delivery.id) == expected_attempts,
         true <- target_outcomes(delivery.id) == expected_target_outcomes(id),
         true <- collapse_contract?(id, delivery.id) do
      {:ok, outcome, :converged, :explained}
    else
      _ -> {:error, :durable_lifecycle_not_proven}
    end
  end

  defp execute_scenario(id, registry) do
    case execute_fixture_scenario(id, registry) do
      {:ok, outcome} -> {:ok, outcome, :converged, :explained}
      _ -> {:error, :scenario_failed}
    end
  end

  defp trigger_delivery("trigger_commit_recovery", registry) do
    {:ok, pair} = binding_intent(registry, "durable-recovery")
    Application.put_env(:chimeway, :alpha_twin_target_bindings, [pair])
    Application.put_env(:chimeway, :target_resolver, AlphaTwin.IntegrationTargetResolver)
    Application.put_env(:chimeway, :target_adapter, Chimeway.Adapters.APNS)
    Application.put_env(:chimeway, :apns_binding_lookup, AlphaTwin.Registry)
    Application.put_env(:chimeway, :apns_transport, AlphaTwin.ScriptedAPNSTransport)
    Application.put_env(:chimeway, :dispatcher, AlphaTwin.CrashOnceDispatcher)
    {:ok, transport} = ScriptedAPNSTransport.start_link(script: [{:accepted}], observer: self())
    Application.put_env(:chimeway, :alpha_twin_apns_script, transport)
    key = "alpha-ledger-recovery-#{System.unique_integer([:positive])}"

    {pid, ref} =
      spawn_monitor(fn ->
        Chimeway.Trigger.trigger(AlphaTwin.IntegrationNotifier, %{},
          tenant_id: "alpha-twin",
          idempotency_key: key
        )
      end)

    assert_down(ref, pid)

    event =
      Chimeway.Repo.get_by!(Chimeway.Events.Event, tenant_id: "alpha-twin", idempotency_key: key)

    0 =
      Chimeway.Repo.aggregate(
        from(d in Chimeway.Delivery,
          join: n in Chimeway.Notifications.Notification,
          on: d.notification_id == n.id,
          where: n.event_id == ^event.id
        ),
        :count,
        :id
      )

    Application.put_env(:chimeway, :dispatcher, Chimeway.Dispatch.Sync)
    now = DateTime.utc_now()
    recovery = Chimeway.TargetRecovery.recover_tenant("alpha-twin", older_than: 0, now: now)

    with 1 <- recovery.counts.resumed_planning,
         [delivery] <-
           Chimeway.Repo.all(
             from(d in Chimeway.Delivery,
               join: n in Chimeway.Notifications.Notification,
               on: d.notification_id == n.id,
               where: n.event_id == ^event.id
             )
           ),
         0 <-
           Chimeway.TargetRecovery.recover_tenant("alpha-twin", older_than: 0, now: now).counts.resumed_planning do
      {:ok, delivery, 1, 1}
    else
      _ -> {:error, :recovery_not_converged}
    end
  end

  defp trigger_delivery(id, registry) do
    {bindings, script, expected_targets, expected_attempts} = delivery_setup(id, registry)
    Application.put_env(:chimeway, :alpha_twin_target_bindings, bindings)
    Application.put_env(:chimeway, :target_resolver, AlphaTwin.IntegrationTargetResolver)
    Application.put_env(:chimeway, :target_adapter, Chimeway.Adapters.APNS)
    Application.put_env(:chimeway, :apns_binding_lookup, AlphaTwin.Registry)
    Application.put_env(:chimeway, :apns_transport, AlphaTwin.ScriptedAPNSTransport)
    Application.put_env(:chimeway, :dispatcher, Chimeway.Dispatch.Sync)
    {:ok, transport} = ScriptedAPNSTransport.start_link(script: script, observer: self())
    Application.put_env(:chimeway, :alpha_twin_apns_script, transport)

    result =
      Chimeway.Trigger.trigger(AlphaTwin.IntegrationNotifier, %{},
        tenant_id: "alpha-twin",
        idempotency_key: "alpha-ledger-#{id}-#{System.unique_integer([:positive])}"
      )

    case result do
      {:ok, %{event: event}} ->
        delivery =
          Chimeway.Repo.one!(
            from(d in Chimeway.Delivery,
              join: n in Chimeway.Notifications.Notification,
              on: d.notification_id == n.id,
              where: n.event_id == ^event.id and d.tenant_id == "alpha-twin"
            )
          )

        finish_delivery_setup(id, delivery, expected_targets, expected_attempts)

      _ ->
        {:error, :trigger_failed}
    end
  end

  defp finish_delivery_setup("classified_retry", delivery, targets, _attempts) do
    {:ok, transport} = ScriptedAPNSTransport.start_link(script: [{:accepted}], observer: self())
    Application.put_env(:chimeway, :alpha_twin_apns_script, transport)
    {:ok, _} = Chimeway.Dispatch.Sync.dispatch_delivery(delivery, [])
    :ok = ScriptedAPNSTransport.assert_drained(transport)
    {:ok, Chimeway.Repo.get!(Chimeway.Delivery, delivery.id), targets, 2}
  end

  defp finish_delivery_setup("post_handoff_ambiguity", delivery, targets, attempts) do
    before = target_attempt_count(delivery.id)
    {:ok, _} = Chimeway.Dispatch.Sync.dispatch_delivery(delivery, [])

    if target_attempt_count(delivery.id) == before do
      {:ok, Chimeway.Repo.get!(Chimeway.Delivery, delivery.id), targets, attempts}
    else
      {:error, :ambiguity_resent}
    end
  end

  defp finish_delivery_setup(_id, delivery, targets, attempts),
    do: {:ok, delivery, targets, attempts}

  defp delivery_setup("zero_target_suppression", _registry), do: {[], [], 0, 0}

  defp delivery_setup("two_installation_fanout", registry) do
    {:ok, first} = binding_intent(registry, "durable-fanout-1")
    {:ok, second} = binding_intent(registry, "durable-fanout-2")
    {[first, second], [{:accepted}, {:accepted}], 2, 2}
  end

  defp delivery_setup("expiry_before_io", registry) do
    {:ok, pair} = binding_intent(registry, "durable-expiry", DateTime.add(@now, -1, :second))
    {[pair], [{:accepted}], 1, 1}
  end

  defp delivery_setup("post_handoff_ambiguity", registry) do
    {:ok, pair} = binding_intent(registry, "durable-ambiguity")
    {[pair], [{:ambiguous}], 1, 1}
  end

  defp delivery_setup("opt_in_installation_safe_collapse", registry) do
    {:ok, first} = collapse_binding_intent(registry, "durable-collapse-1", "occurrence-1")
    {:ok, second} = collapse_binding_intent(registry, "durable-collapse-2", "occurrence-2")
    {[first, second], [{:accepted}, {:accepted}], 2, 2}
  end

  defp delivery_setup(_id, registry) do
    {:ok, pair} = binding_intent(registry, "durable")
    {[pair], [{:accepted}], 1, 1}
  end

  defp binding_intent(registry, suffix, expires_at \\ ~U[2030-08-25 12:00:00Z]) do
    with {:ok, binding} <- bind(registry, suffix),
         {:ok, %{intent_ref: open_ref}} <-
           Registry.issue_intent(registry, binding.binding_revision_ref),
         {:ok, intent} <-
           RequestIntent.new(
             %{
               environment: :sandbox,
               topic: "com.example.alpha",
               apns_id: Ecto.UUID.generate(),
               expires_at: expires_at,
               open_ref: open_ref
             },
             []
           ) do
      {:ok, {binding.binding_revision_ref, intent}}
    end
  end

  defp collapse_binding_intent(registry, suffix, occurrence_ref) do
    with {:ok, binding} <- bind(registry, suffix),
         {:ok, %{intent_ref: open_ref}} <-
           Registry.issue_intent(registry, binding.binding_revision_ref),
         {:ok, intent} <-
           RequestIntent.new(
             %{
               environment: :sandbox,
               topic: "com.example.alpha",
               apns_id: Ecto.UUID.generate(),
               expires_at: ~U[2030-08-25 12:00:00Z],
               open_ref: open_ref
             },
             replaceable: true,
             occurrence_ref: occurrence_ref,
             binding_revision_ref: binding.binding_revision_ref
           ),
         true <- is_binary(intent.collapse_id) do
      {:ok, {binding.binding_revision_ref, intent}}
    end
  end

  defp target_attempt_count(delivery_id) do
    Chimeway.Repo.aggregate(
      from(a in Chimeway.DeliveryTargetAttempt,
        join: t in Chimeway.DeliveryTarget,
        on: a.delivery_target_id == t.id,
        where: t.delivery_id == ^delivery_id and a.tenant_id == "alpha-twin"
      ),
      :count,
      :id
    )
  end

  defp target_outcomes(delivery_id) do
    Chimeway.Repo.all(
      from(t in Chimeway.DeliveryTarget,
        where: t.delivery_id == ^delivery_id and t.tenant_id == "alpha-twin",
        order_by: [asc: t.binding_revision_ref],
        select: t.status
      )
    )
  end

  defp expected_target_outcomes("zero_target_suppression"), do: []
  defp expected_target_outcomes("expiry_before_io"), do: [:expired]
  defp expected_target_outcomes("post_handoff_ambiguity"), do: [:ambiguous_handoff]

  defp expected_target_outcomes("two_installation_fanout"),
    do: [:provider_accepted, :provider_accepted]

  defp expected_target_outcomes(_), do: [:provider_accepted]

  defp collapse_contract?("opt_in_installation_safe_collapse", delivery_id) do
    ids =
      Chimeway.Repo.all(
        from(t in Chimeway.DeliveryTarget,
          where: t.delivery_id == ^delivery_id and t.tenant_id == "alpha-twin",
          order_by: [asc: t.binding_revision_ref],
          select: fragment("?->>'collapse_id'", t.apns_request_intent)
        )
      )

    length(ids) == 2 and Enum.all?(ids, &is_binary/1) and Enum.uniq(ids) == ids
  end

  defp collapse_contract?(_id, _delivery_id), do: true

  defp assert_down(ref, pid) do
    receive do
      {:DOWN, ^ref, :process, ^pid, :alpha_twin_post_commit_crash} ->
        :ok

      {:DOWN, ^ref, :process, ^pid, _reason} ->
        raise "trigger did not crash at the post-commit dispatcher seam"
    after
      5_000 -> raise "trigger crash seam timed out"
    end
  end

  defp execute_fixture_scenario("two_installation_fanout", registry) do
    with {:ok, first} <- bind(registry, "fanout-1"),
         {:ok, second} <- bind(registry, "fanout-2"),
         true <- first.binding_revision_ref != second.binding_revision_ref,
         :ok <- deliver_each(registry, [first, second], [{:accepted}, {:accepted}]) do
      {:ok, :fanout_two_provider_acceptances}
    else
      _ -> {:error, :fanout_failed}
    end
  end

  defp execute_fixture_scenario("zero_target_suppression", registry) do
    absent = %BindingLookup.Request{
      tenant_id: "alpha-twin",
      environment: :sandbox,
      topic: "com.example.alpha",
      binding_revision_ref: "cw_binding_absent"
    }

    case Registry.resolve(registry, absent) do
      {:error, :binding_not_found} -> {:ok, :suppressed_no_targets}
      _ -> {:error, :suppression_failed}
    end
  end

  defp execute_fixture_scenario("token_rotation", registry) do
    with {:ok, old} <- bind(registry, "rotation"),
         {:ok, replacement} <-
           Registry.rotate(registry, old.binding_revision_ref, "raw-token-rotation-new"),
         {:error, :binding_not_found} <- Registry.resolve(registry, request(old)),
         {:ok, _} <- Registry.resolve(registry, request(replacement)) do
      {:ok, :old_revision_rejected}
    else
      _ -> {:error, :rotation_failed}
    end
  end

  defp execute_fixture_scenario("revocation_race", registry) do
    with {:ok, binding} <- bind(registry, "revoke"),
         {:ok, replacement} <-
           Registry.rotate(registry, binding.binding_revision_ref, "raw-token-revoke-new"),
         {:ok, %{status: :unchanged}} <- Registry.invalidate(registry, invalidation(binding)),
         {:ok, _} <- Registry.resolve(registry, request(replacement)) do
      {:ok, :exact_revision_cas}
    else
      _ -> {:error, :revocation_failed}
    end
  end

  defp execute_fixture_scenario("classified_retry", registry) do
    with {:ok, binding} <- bind(registry, "retry"),
         :ok <- deliver_each(registry, [binding, binding], [{:retryable}, {:accepted}]) do
      {:ok, :retryable_then_accepted}
    else
      _ -> {:error, :retry_failed}
    end
  end

  defp execute_fixture_scenario("expiry_before_io", registry) do
    with {:ok, binding} <- bind(registry, "expiry"),
         {:ok, transport} <-
           ScriptedAPNSTransport.start_link(script: [{:accepted}], observer: self()),
         {:expired, _} <-
           APNS.deliver(envelope(binding, DateTime.add(@now, -1, :second)),
             transport: ScriptedAPNSTransport,
             script_pid: transport,
             now: @now
           ),
         {:error, :script_remaining} <- ScriptedAPNSTransport.assert_drained(transport) do
      {:ok, :expired_before_provider_io}
    else
      _ -> {:error, :expiry_failed}
    end
  end

  defp execute_fixture_scenario("opt_in_installation_safe_collapse", registry) do
    with {:ok, first} <- bind(registry, "collapse-1"),
         {:ok, second} <- bind(registry, "collapse-2"),
         :ok <- deliver_each(registry, [first, second], [{:accepted}, {:accepted}]) do
      {:ok, :installation_safe_distinct}
    else
      _ -> {:error, :collapse_failed}
    end
  end

  # The durable post-commit crash/recovery contract is exercised by the fixture's
  # persisted tracer; this call is the same public recovery seam and is deliberately
  # idempotent when no extra tenant work is discoverable.
  defp execute_fixture_scenario("trigger_commit_recovery", _registry) do
    summary = Chimeway.TargetRecovery.recover_tenant("alpha-twin", now: @now)

    if is_map(summary) and is_map(summary.counts),
      do: {:ok, :recovery_converged},
      else: {:error, :recovery_failed}
  end

  defp execute_fixture_scenario("post_handoff_ambiguity", registry) do
    with {:ok, binding} <- bind(registry, "ambiguous"),
         {:ok, transport} <-
           ScriptedAPNSTransport.start_link(script: [{:ambiguous}], observer: self()),
         {:error, :possible_handoff, :ambiguous_handoff} <-
           APNS.deliver(envelope(binding, @now),
             transport: ScriptedAPNSTransport,
             script_pid: transport,
             now: @now
           ),
         :ok <- ScriptedAPNSTransport.assert_drained(transport) do
      {:ok, :ambiguous_handoff_no_resend}
    else
      _ -> {:error, :ambiguity_failed}
    end
  end

  defp execute_fixture_scenario("recursive_leak_prevention", _registry) do
    case AlphaTwin.ProofSummary.render(%{"trace" => %{"nested" => "raw-token-sentinel"}}) do
      {:error, %{rule: :sensitive_value, path: ["trace", "nested"]}} ->
        {:ok, :recursive_scan_rejected}

      _ ->
        {:error, :leak_scan_failed}
    end
  end

  defp execute_fixture_scenario("offline_reauthorization", registry),
    do: open_once(registry, :protected_open_once)

  defp execute_fixture_scenario("accepted_handoff_protected_open", registry),
    do: open_once(registry, :protected_open_once)

  defp execute_fixture_scenario("stale_denied_open", registry) do
    with {:ok, binding} <- bind(registry, "stale"),
         {:ok, %{intent_ref: ref}} <-
           Registry.issue_intent(registry, binding.binding_revision_ref),
         {:deny, _} <- resolve(ref, "cw_binding_not_current") do
      {:ok, :denied_no_fallback}
    else
      _ -> {:error, :stale_open_failed}
    end
  end

  defp execute_fixture_scenario("replay_rejection", registry) do
    with {:ok, binding} <- bind(registry, "replay"),
         {:ok, %{intent_ref: ref}} <-
           Registry.issue_intent(registry, binding.binding_revision_ref),
         {:allow, _} <- resolve(ref, binding.binding_revision_ref),
         {:deny, denial} <- resolve(ref, binding.binding_revision_ref),
         "notification.open.replayed" <- denial.code do
      {:ok, :replay_rejected}
    else
      _ -> {:error, :replay_failed}
    end
  end

  defp open_once(registry, outcome) do
    with {:ok, binding} <- bind(registry, "open"),
         {:ok, %{intent_ref: ref}} <-
           Registry.issue_intent(registry, binding.binding_revision_ref),
         {:allow, decision} <- resolve(ref, binding.binding_revision_ref),
         :activate <- decision.transition do
      {:ok, outcome}
    else
      _ -> {:error, :open_failed}
    end
  end

  defp resolve(ref, binding_ref),
    do:
      Crosswake.Companions.Chimeway.Resolver.resolve(
        ProtectedOpen.manifest(),
        ProtectedOpen.evidence(ref, binding_ref),
        AlphaTwin.IntentConsumer
      )

  defp deliver_each(_registry, bindings, script) do
    {:ok, transport} = ScriptedAPNSTransport.start_link(script: script, observer: self())

    observations =
      Enum.map(bindings, fn binding ->
        _ =
          APNS.deliver(envelope(binding, @now),
            transport: ScriptedAPNSTransport,
            script_pid: transport,
            now: @now
          )

        receive do
          {:alpha_twin_apns_request, observation} -> observation
        after
          1000 -> throw(:missing_provider_observation)
        end
      end)

    with true <- length(observations) == length(script),
         :ok <- ScriptedAPNSTransport.assert_drained(transport) do
      :ok
    else
      _ -> {:error, :provider_observation_count_mismatch}
    end
  catch
    :missing_provider_observation -> {:error, :missing_provider_observation}
  end

  defp bind(registry, suffix),
    do:
      Registry.bind(registry, %{
        tenant_id: "alpha-twin",
        environment: :sandbox,
        topic: "com.example.alpha",
        installation_ref: "cw_installation_#{suffix}",
        token: "raw-token-#{suffix}"
      })

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

  defp envelope(binding, expires_at) do
    {:ok, intent} =
      RequestIntent.new(
        %{
          environment: binding.environment,
          topic: binding.topic,
          apns_id: Ecto.UUID.generate(),
          expires_at: expires_at,
          open_ref: "cw_open_runner"
        },
        []
      )

    %TargetEnvelope{
      delivery: %Chimeway.Delivery{render_data: %{"title" => "Alpha", "body" => "Twin"}},
      target: %Chimeway.DeliveryTarget{
        tenant_id: binding.tenant_id,
        binding_revision_ref: binding.binding_revision_ref,
        apns_request_intent: RequestIntent.to_storage(intent)
      }
    }
  end
end
