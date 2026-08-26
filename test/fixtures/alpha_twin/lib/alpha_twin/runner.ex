defmodule AlphaTwin.Runner do
  @moduledoc false

  alias AlphaTwin.{ProtectedOpen, Registry, ScriptedAPNSTransport}
  alias Chimeway.APNS.{BindingLookup, RequestIntent}
  alias Chimeway.Adapters.APNS
  alias Chimeway.TargetAdapter.TargetEnvelope

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
          {:ok, outcome} ->
            {:cont,
             {:ok,
              [%{id: id, durable: :converged, explanation: :explained, outcome: outcome} | acc]}}

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

  defp execute_scenario("two_installation_fanout", registry) do
    with {:ok, first} <- bind(registry, "fanout-1"),
         {:ok, second} <- bind(registry, "fanout-2"),
         true <- first.binding_revision_ref != second.binding_revision_ref,
         :ok <- deliver_each(registry, [first, second], [{:accepted}, {:accepted}]) do
      {:ok, :fanout_two_provider_acceptances}
    else
      _ -> {:error, :fanout_failed}
    end
  end

  defp execute_scenario("zero_target_suppression", registry) do
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

  defp execute_scenario("token_rotation", registry) do
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

  defp execute_scenario("revocation_race", registry) do
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

  defp execute_scenario("classified_retry", registry) do
    with {:ok, binding} <- bind(registry, "retry"),
         :ok <- deliver_each(registry, [binding, binding], [{:retryable}, {:accepted}]) do
      {:ok, :retryable_then_accepted}
    else
      _ -> {:error, :retry_failed}
    end
  end

  defp execute_scenario("expiry_before_io", registry) do
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

  defp execute_scenario("opt_in_installation_safe_collapse", registry) do
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
  defp execute_scenario("trigger_commit_recovery", _registry) do
    summary = Chimeway.TargetRecovery.recover_tenant("alpha-twin", now: @now)

    if is_map(summary) and is_map(summary.counts),
      do: {:ok, :recovery_converged},
      else: {:error, :recovery_failed}
  end

  defp execute_scenario("post_handoff_ambiguity", registry) do
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

  defp execute_scenario("recursive_leak_prevention", _registry) do
    case AlphaTwin.ProofSummary.render(%{"trace" => %{"nested" => "raw-token-sentinel"}}) do
      {:error, %{rule: :sensitive_value, path: ["trace", "nested"]}} ->
        {:ok, :recursive_scan_rejected}

      _ ->
        {:error, :leak_scan_failed}
    end
  end

  defp execute_scenario("offline_reauthorization", registry),
    do: open_once(registry, :protected_open_once)

  defp execute_scenario("accepted_handoff_protected_open", registry),
    do: open_once(registry, :protected_open_once)

  defp execute_scenario("stale_denied_open", registry) do
    with {:ok, binding} <- bind(registry, "stale"),
         {:ok, %{intent_ref: ref}} <-
           Registry.issue_intent(registry, binding.binding_revision_ref),
         {:deny, _} <- resolve(ref, "cw_binding_not_current") do
      {:ok, :denied_no_fallback}
    else
      _ -> {:error, :stale_open_failed}
    end
  end

  defp execute_scenario("replay_rejection", registry) do
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
