defmodule AlphaTwin.Runner do
  @moduledoc false

  alias AlphaTwin.{ProtectedOpen, Registry, ScriptedAPNSTransport}
  alias Chimeway.APNS.{BindingLookup, RequestIntent}
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

          failure ->
            IO.puts(
              :stderr,
              "[alpha-twin] scenario_failed id=#{id} class=#{failure_class(failure)}"
            )

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

  defp failure_class({:error, reason}) when is_atom(reason), do: reason
  defp failure_class(_), do: :unexpected_result

  defp configure(registry) do
    Application.put_env(:chimeway, :alpha_twin_registry, registry)
    Application.put_env(:chimeway, :apns_binding_lookup, Registry)
    Application.put_env(:crosswake, :companions, [Crosswake.Companions.Sigra])
  end

  # Every delivery ledger entry traverses the production trigger, planning,
  # dispatch, recovery, persistence, and explanation seams as applicable.
  defp execute_scenario("token_rotation", registry), do: execute_token_rotation(registry)

  defp execute_scenario("revocation_race", registry), do: execute_revocation_race(registry)

  defp execute_scenario("opt_in_installation_safe_collapse", registry),
    do:
      durable_delivery("opt_in_installation_safe_collapse", registry, :installation_safe_distinct)

  defp execute_scenario("accepted_handoff_protected_open", registry),
    do:
      durable_delivery(
        "accepted_handoff_protected_open",
        registry,
        :protected_open_once
      )

  defp execute_scenario("two_installation_fanout", registry),
    do: durable_delivery("two_installation_fanout", registry, :fanout_two_provider_acceptances)

  defp execute_scenario("zero_target_suppression", registry),
    do: durable_delivery("zero_target_suppression", registry, :suppressed_no_targets)

  defp execute_scenario("classified_retry", registry),
    do: durable_delivery("classified_retry", registry, :retryable_then_accepted)

  defp execute_scenario("expiry_before_io", registry),
    do: durable_delivery("expiry_before_io", registry, :expired_before_provider_io)

  defp execute_scenario("trigger_commit_recovery", registry),
    do: durable_delivery("trigger_commit_recovery", registry, :recovery_converged)

  defp execute_scenario("post_handoff_ambiguity", registry),
    do: durable_delivery("post_handoff_ambiguity", registry, :ambiguous_handoff_no_resend)

  defp execute_scenario(id, registry) do
    case execute_fixture_scenario(id, registry) do
      {:ok, outcome} -> {:ok, outcome, :converged, :explained}
      _ -> {:error, :scenario_failed}
    end
  end

  defp durable_delivery(id, registry, outcome) do
    with {:ok, delivery, expected_targets, expected_attempts} <- trigger_delivery(id, registry),
         {:ok, explanation} <-
           Chimeway.Traces.explain_delivery(delivery.id, tenant_id: "alpha-twin"),
         true <- explanation.delivery_id == delivery.id,
         true <- target_count_matches?(id, explanation, expected_targets),
         true <- target_attempt_count(delivery.id) == expected_attempts,
         true <- target_outcomes(delivery.id) == expected_target_outcomes(id),
         true <- target_attempt_outcomes(delivery.id) == expected_attempt_outcomes(id),
         true <- delivery.status == expected_delivery_status(id),
         true <- collapse_contract?(id, delivery.id),
         :ok <- delivery_contract(id, delivery, explanation, registry) do
      {:ok, outcome, :converged, :explained}
    else
      _ -> {:error, :durable_lifecycle_not_proven}
    end
  end

  defp execute_token_rotation(registry) do
    with {:ok, old} <- bind(registry, "rotation-durable"),
         {:ok, old_pair} <- intent_pair(registry, old),
         {:ok, delivery, transport} <-
           plan_only_delivery("token-rotation-old", registry, old_pair, [{:accepted}]),
         [old_target] <- targets_for(delivery.id),
         {:ok, replacement} <-
           Registry.rotate(registry, old.binding_revision_ref, "raw-token-rotation-new"),
         {:error, :pre_handoff_retryable} <-
           Chimeway.Dispatch.Executor.run_target(delivery,
             target_id: old_target.id,
             source: "alpha_twin_rotation"
           ),
         {:error, :script_remaining} <- ScriptedAPNSTransport.assert_drained(transport),
         [%{outcome: :failed, safe_facts: %{"provider_code" => "binding_not_found"}}] <-
           attempts_for(old_target.id),
         {:ok, _invalidated} <-
           Chimeway.DeliveryTargets.invalidate_target(
             Chimeway.Repo.get!(Chimeway.Delivery, delivery.id),
             old_target.id,
             tenant_id: "alpha-twin"
           ),
         {:ok, old_explanation} <-
           Chimeway.Traces.explain_delivery(delivery.id, tenant_id: "alpha-twin"),
         [:failed, :invalidated] <- explanation_attempt_outcomes(old_explanation),
         {:ok, replacement_delivery} <-
           accepted_replacement_delivery("token-rotation-new", registry, replacement),
         {:ok, replacement_explanation} <-
           Chimeway.Traces.explain_delivery(replacement_delivery.id, tenant_id: "alpha-twin"),
         true <- replacement_explanation.status == :succeeded,
         [replacement_target] <- targets_for(replacement_delivery.id),
         true <- replacement_target.binding_revision_ref == replacement.binding_revision_ref,
         true <- replacement_target.binding_revision_ref != old_target.binding_revision_ref do
      {:ok, :old_revision_rejected, :converged, :explained}
    else
      _ -> {:error, :rotation_lifecycle_not_proven}
    end
  end

  defp execute_revocation_race(registry) do
    with {:ok, old} <- bind(registry, "revocation-durable"),
         {:ok, old_pair} <- intent_pair(registry, old),
         {:ok, delivery, transport} <-
           plan_only_delivery(
             "revocation-race-old",
             registry,
             old_pair,
             [{:blocked, {:invalidating, 1}}]
           ),
         [old_target] <- targets_for(delivery.id) do
      task =
        Task.async(fn ->
          Chimeway.Dispatch.Executor.run_target(execution_delivery(delivery),
            target_id: old_target.id,
            source: "alpha_twin_revocation_race"
          )
        end)

      with {:ok, transport_pid} <- await_blocked_transport(),
           true <- transport_pid == transport,
           {:ok, replacement} <-
             Registry.rotate(registry, old.binding_revision_ref, "raw-token-revocation-new"),
           :ok <- release_transport(transport_pid),
           {:ok, _result} <- Task.await(task, 5_000),
           :ok <- ScriptedAPNSTransport.assert_drained(transport),
           [%{outcome: :failed, safe_facts: safe_facts}] <- attempts_for(old_target.id),
           410 <- safe_facts["provider_status"],
           "unregistered" <- safe_facts["provider_reason"],
           {:ok, _transient} <- Registry.resolve(registry, request(replacement)),
           {:ok, old_explanation} <-
             Chimeway.Traces.explain_delivery(delivery.id, tenant_id: "alpha-twin"),
           [:failed] <- explanation_attempt_outcomes(old_explanation),
           {:ok, replacement_delivery} <-
             accepted_replacement_delivery("revocation-race-new", registry, replacement),
           {:ok, replacement_explanation} <-
             Chimeway.Traces.explain_delivery(replacement_delivery.id, tenant_id: "alpha-twin"),
           true <- replacement_explanation.status == :succeeded do
        {:ok, :exact_revision_cas, :converged, :explained}
      else
        _ ->
          Task.shutdown(task, :brutal_kill)
          {:error, :revocation_lifecycle_not_proven}
      end
    else
      _ -> {:error, :revocation_lifecycle_not_proven}
    end
  end

  defp plan_only_delivery(id, registry, pair, script) do
    {:ok, transport} = ScriptedAPNSTransport.start_link(script: script, observer: self())
    configure_delivery_runtime(registry, [pair], transport, AlphaTwin.PlanOnlyDispatcher)

    with {:ok, %{event: event}} <- trigger(id),
         %Chimeway.Delivery{} = delivery <- delivery_for_event(event.id) do
      {:ok, delivery, transport}
    else
      _ -> {:error, :planning_failed}
    end
  end

  defp accepted_replacement_delivery(id, registry, binding) do
    with {:ok, pair} <- intent_pair(registry, binding) do
      {:ok, transport} = ScriptedAPNSTransport.start_link(script: [{:accepted}], observer: self())
      configure_delivery_runtime(registry, [pair], transport, Chimeway.Dispatch.Sync)

      with {:ok, %{event: event}} <- trigger(id),
           %Chimeway.Delivery{} = delivery <- delivery_for_event(event.id),
           :ok <- ScriptedAPNSTransport.assert_drained(transport),
           [%{status: :provider_accepted} = target] <- targets_for(delivery.id),
           [%{outcome: :provider_accepted}] <- attempts_for(target.id) do
        {:ok, delivery}
      else
        _ -> {:error, :replacement_not_accepted}
      end
    end
  end

  defp configure_delivery_runtime(registry, bindings, transport, dispatcher) do
    Application.put_env(:chimeway, :alpha_twin_registry, registry)
    Application.put_env(:chimeway, :alpha_twin_target_bindings, bindings)
    Application.put_env(:chimeway, :target_resolver, AlphaTwin.IntegrationTargetResolver)
    Application.put_env(:chimeway, :target_adapter, Chimeway.Adapters.APNS)
    Application.put_env(:chimeway, :apns_binding_lookup, AlphaTwin.Registry)
    Application.put_env(:chimeway, :apns_transport, AlphaTwin.ScriptedAPNSTransport)
    Application.put_env(:chimeway, :alpha_twin_apns_script, transport)
    Application.put_env(:chimeway, :dispatcher, dispatcher)
  end

  defp trigger(id) do
    Chimeway.Trigger.trigger(AlphaTwin.IntegrationNotifier, %{},
      tenant_id: "alpha-twin",
      idempotency_key: "alpha-ledger-#{id}-#{System.unique_integer([:positive])}"
    )
  end

  defp delivery_for_event(event_id) do
    Chimeway.Repo.one(
      from(d in Chimeway.Delivery,
        join: n in Chimeway.Notifications.Notification,
        on: d.notification_id == n.id,
        where: n.event_id == ^event_id and d.tenant_id == "alpha-twin"
      )
    )
  end

  defp execution_delivery(delivery) do
    %{delivery | render_data: %{"title" => "Alpha twin", "body" => "Hermetic lifecycle proof"}}
  end

  defp targets_for(delivery_id) do
    Chimeway.Repo.all(
      from(t in Chimeway.DeliveryTarget,
        where: t.delivery_id == ^delivery_id and t.tenant_id == "alpha-twin",
        order_by: [asc: t.binding_revision_ref]
      )
    )
  end

  defp attempts_for(target_id) do
    Chimeway.Repo.all(
      from(a in Chimeway.DeliveryTargetAttempt,
        where: a.delivery_target_id == ^target_id and a.tenant_id == "alpha-twin",
        order_by: [asc: a.attempt_number]
      )
    )
  end

  defp explanation_attempt_outcomes(explanation) do
    explanation.targets
    |> Enum.flat_map(& &1.attempts)
    |> Enum.map(& &1.outcome)
  end

  defp await_blocked_transport do
    receive do
      {:alpha_twin_apns_blocked, pid} when is_pid(pid) -> {:ok, pid}
    after
      5_000 -> {:error, :transport_not_blocked}
    end
  end

  defp release_transport(pid) when is_pid(pid) do
    send(pid, :alpha_twin_release)
    :ok
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

        with :ok <- transport_contract(id, transport) do
          finish_delivery_setup(id, delivery, expected_targets, expected_attempts)
        end

      _ ->
        {:error, :trigger_failed}
    end
  end

  defp transport_contract("expiry_before_io", transport) do
    case ScriptedAPNSTransport.assert_drained(transport) do
      {:error, :script_remaining} -> :ok
      _ -> {:error, :expiry_reached_provider_io}
    end
  end

  defp transport_contract(_id, transport), do: ScriptedAPNSTransport.assert_drained(transport)

  defp finish_delivery_setup("classified_retry", delivery, targets, _attempts) do
    {:ok, transport} = ScriptedAPNSTransport.start_link(script: [{:accepted}], observer: self())
    Application.put_env(:chimeway, :alpha_twin_apns_script, transport)
    {:ok, _} = Chimeway.Dispatch.Sync.dispatch_delivery(execution_delivery(delivery), [])
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

  defp delivery_setup("classified_retry", registry) do
    {:ok, pair} = binding_intent(registry, "durable-retry")
    {[pair], [{:retryable}], 1, 2}
  end

  defp delivery_setup("opt_in_installation_safe_collapse", registry) do
    {:ok, first} = collapse_binding_intent(registry, "durable-collapse-1", "occurrence-shared")
    {:ok, second} = collapse_binding_intent(registry, "durable-collapse-2", "occurrence-shared")
    {[first, second], [{:accepted}, {:accepted}], 2, 2}
  end

  defp delivery_setup(_id, registry) do
    {:ok, pair} = binding_intent(registry, "durable")
    {[pair], [{:accepted}], 1, 1}
  end

  defp binding_intent(registry, suffix, expires_at \\ ~U[2030-08-25 12:00:00Z]) do
    with {:ok, binding} <- bind(registry, suffix),
         {:ok, pair} <- intent_pair(registry, binding, expires_at) do
      {:ok, pair}
    end
  end

  defp intent_pair(registry, binding, expires_at \\ ~U[2030-08-25 12:00:00Z]) do
    with {:ok, %{intent_ref: open_ref}} <-
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

  defp target_count_matches?("zero_target_suppression", explanation, 0),
    do: explanation.targets == []

  defp target_count_matches?(_id, explanation, expected),
    do: explanation.target_aggregate.target_count == expected

  defp target_outcomes(delivery_id) do
    Chimeway.Repo.all(
      from(t in Chimeway.DeliveryTarget,
        where: t.delivery_id == ^delivery_id and t.tenant_id == "alpha-twin",
        order_by: [asc: t.binding_revision_ref],
        select: t.status
      )
    )
  end

  defp target_attempt_outcomes(delivery_id) do
    Chimeway.Repo.all(
      from(a in Chimeway.DeliveryTargetAttempt,
        join: t in Chimeway.DeliveryTarget,
        on: a.delivery_target_id == t.id,
        where: t.delivery_id == ^delivery_id and a.tenant_id == "alpha-twin",
        order_by: [asc: t.binding_revision_ref, asc: a.attempt_number],
        select: a.outcome
      )
    )
  end

  defp expected_target_outcomes("zero_target_suppression"), do: []
  defp expected_target_outcomes("expiry_before_io"), do: [:expired]
  defp expected_target_outcomes("post_handoff_ambiguity"), do: [:ambiguous_handoff]
  defp expected_target_outcomes("trigger_commit_recovery"), do: [:failed]

  defp expected_target_outcomes("two_installation_fanout"),
    do: [:provider_accepted, :provider_accepted]

  defp expected_target_outcomes("opt_in_installation_safe_collapse"),
    do: [:provider_accepted, :provider_accepted]

  defp expected_target_outcomes(_), do: [:provider_accepted]

  defp expected_attempt_outcomes("zero_target_suppression"), do: []
  defp expected_attempt_outcomes("classified_retry"), do: [:failed, :provider_accepted]
  defp expected_attempt_outcomes("expiry_before_io"), do: [:expired]
  defp expected_attempt_outcomes("post_handoff_ambiguity"), do: [:ambiguous_handoff]
  defp expected_attempt_outcomes("trigger_commit_recovery"), do: [:failed]

  defp expected_attempt_outcomes("two_installation_fanout"),
    do: [:provider_accepted, :provider_accepted]

  defp expected_attempt_outcomes("opt_in_installation_safe_collapse"),
    do: [:provider_accepted, :provider_accepted]

  defp expected_attempt_outcomes(_), do: [:provider_accepted]

  defp expected_delivery_status("zero_target_suppression"), do: :suppressed

  defp expected_delivery_status(id)
       when id in ["expiry_before_io", "post_handoff_ambiguity", "trigger_commit_recovery"],
       do: :failed

  defp expected_delivery_status(_), do: :succeeded

  defp delivery_contract("accepted_handoff_protected_open", delivery, _explanation, _registry) do
    with [target] <- targets_for(delivery.id),
         open_ref when is_binary(open_ref) <- target.apns_request_intent["open_ref"],
         {:allow, %{transition: :activate}} <- resolve(open_ref, target.binding_revision_ref),
         {:deny, %{code: "notification.open.replayed"}} <-
           resolve(open_ref, target.binding_revision_ref) do
      :ok
    else
      _ -> {:error, :protected_open_not_proven}
    end
  end

  defp delivery_contract("zero_target_suppression", delivery, explanation, _registry) do
    if delivery.suppression_reason == "no_eligible_targets" and
         explanation.status == :suppressed and explanation.targets == [],
       do: :ok,
       else: {:error, :suppression_not_proven}
  end

  defp delivery_contract("trigger_commit_recovery", delivery, explanation, _registry) do
    if delivery.metadata["recovery_source"] == "target_recovery" and
         delivery.metadata["recovery_reason"] == "resumed_planning" and
         explanation.status == :failed,
       do: :ok,
       else: {:error, :recovery_not_explained}
  end

  defp delivery_contract(_id, _delivery, _explanation, _registry), do: :ok

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

  defp execute_fixture_scenario("recursive_leak_prevention", _registry) do
    clean_sources = %{
      "storage" => %{"status" => "succeeded"},
      "traces" => [%{"outcome" => "provider_accepted"}],
      "telemetry" => %{"count" => 1},
      "exceptions" => [],
      "observations" => [%{"provider_status" => 200}],
      "final_bytes" => "CHIMEWAY_ALPHA_TWIN_PROOF schema=1"
    }

    sentinels = [
      {"storage", "raw-token-sentinel"},
      {"traces", "raw-identity-sentinel"},
      {"telemetry", "raw-url-sentinel"},
      {"exceptions", "raw-payload-sentinel"},
      {"observations", "raw-credential-sentinel"},
      {"final_bytes", "raw-provider-body-sentinel"}
    ]

    with :ok <- AlphaTwin.ProofSummary.scan_sources(clean_sources),
         true <-
           Enum.all?(sentinels, fn {source, sentinel} ->
             injected = Map.put(clean_sources, source, %{"nested" => [sentinel]})

             match?(
               {:error, %{rule: :sensitive_value, path: [^source, "nested", "0"]}},
               AlphaTwin.ProofSummary.scan_sources(injected)
             )
           end) do
      {:ok, :recursive_scan_rejected}
    else
      _ -> {:error, :leak_scan_failed}
    end
  end

  defp execute_fixture_scenario("offline_reauthorization", registry),
    do: open_once(registry, :protected_open_once)

  defp execute_fixture_scenario("stale_denied_open", registry) do
    with {:ok, binding} <- bind(registry, "stale"),
         {:ok, %{intent_ref: ref}} <-
           Registry.issue_intent(registry, binding.binding_revision_ref),
         {:deny, _} <-
           resolve_against(ref, "cw_binding_not_current", binding.binding_revision_ref) do
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

  defp resolve(ref, binding_ref), do: resolve_against(ref, binding_ref, binding_ref)

  defp resolve_against(ref, evidence_binding_ref, current_binding_ref) do
    Application.put_env(:chimeway, :alpha_twin_binding_ref, current_binding_ref)

    Crosswake.Companions.Chimeway.Resolver.resolve(
      ProtectedOpen.manifest(),
      ProtectedOpen.evidence(ref, evidence_binding_ref),
      AlphaTwin.IntentConsumer
    )
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
end
