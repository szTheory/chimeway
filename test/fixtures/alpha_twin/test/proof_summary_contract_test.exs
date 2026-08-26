defmodule AlphaTwin.ProofSummaryContractTest do
  use ExUnit.Case, async: true

  @moduletag :alpha_twin_safety_matrix

  @results [
    {"accepted_handoff_protected_open", "protected_open_once"},
    {"two_installation_fanout", "fanout_two_provider_acceptances"},
    {"zero_target_suppression", "suppressed_no_targets"},
    {"token_rotation", "old_revision_rejected"},
    {"revocation_race", "exact_revision_cas"},
    {"classified_retry", "retryable_then_accepted"},
    {"expiry_before_io", "expired_before_provider_io"},
    {"opt_in_installation_safe_collapse", "installation_safe_distinct"},
    {"trigger_commit_recovery", "recovery_converged"},
    {"post_handoff_ambiguity", "ambiguous_handoff_no_resend"},
    {"recursive_leak_prevention", "recursive_scan_rejected"},
    {"offline_reauthorization", "protected_open_once"},
    {"stale_denied_open", "denied_no_fallback"},
    {"replay_rejection", "replay_rejected"}
  ]

  test "accepts only the complete ordered result ledger and separated taxonomy" do
    attrs = proof_attrs()
    assert {:ok, encoded} = AlphaTwin.ProofSummary.render(attrs)
    assert Jason.decode!(encoded) == attrs

    for invalid <- [
          put_in(attrs, ["scenario_results"], tl(attrs["scenario_results"])),
          put_in(attrs, ["scenario_results"], Enum.reverse(attrs["scenario_results"])),
          put_in(attrs, ["scenario_results", Access.at(0), "outcome"], "terminal"),
          update_in(attrs, ["scenario_results", Access.at(0)], &Map.put(&1, "debug", true)),
          put_in(attrs, ["claim_taxonomy", "protected_open"], "provider_accepted"),
          Map.put(attrs, "debug", true)
        ] do
      assert {:error, %{rule: :invalid_schema, path: []}} =
               AlphaTwin.ProofSummary.render(invalid)
    end
  end

  test "requires every evidence source and rejects nested sentinel classes without echoing them" do
    clean = %{
      "storage" => %{"status" => "succeeded"},
      "traces" => [%{"outcome" => "provider_accepted"}],
      "telemetry" => %{"count" => 1},
      "exceptions" => [],
      "observations" => [%{"provider_status" => 200}],
      "final_bytes" => "CHIMEWAY_ALPHA_TWIN_PROOF schema=1"
    }

    assert :ok = AlphaTwin.ProofSummary.scan_sources(clean)

    assert {:error, %{rule: :invalid_sources, path: []}} =
             clean |> Map.delete("telemetry") |> AlphaTwin.ProofSummary.scan_sources()

    for {source, sentinel} <- [
          {"storage", "raw-token-sentinel"},
          {"traces", "raw-identity-sentinel"},
          {"telemetry", "raw-url-sentinel"},
          {"exceptions", "raw-payload-sentinel"},
          {"observations", "raw-credential-sentinel"},
          {"final_bytes", "raw-provider-body-sentinel"}
        ] do
      injected = Map.put(clean, source, %{"nested" => [sentinel]})

      assert {:error, %{rule: :sensitive_value, path: [^source, "nested", "0"]}} =
               AlphaTwin.ProofSummary.scan_sources(injected)

      refute inspect(AlphaTwin.ProofSummary.scan_sources(injected)) =~ sentinel
    end
  end

  defp proof_attrs do
    %{
      "schema_version" => 1,
      "proof_class" => "alpha_twin",
      "chimeway_artifact_sha256" => String.duplicate("a", 64),
      "crosswake_sha" => String.duplicate("b", 40),
      "scenario_results" =>
        Enum.map(@results, fn {id, outcome} -> %{"id" => id, "outcome" => outcome} end),
      "claim_taxonomy" => %{
        "dispatch_intent" => "recorded",
        "provider_acceptance" => "provider_accepted",
        "invalidation" => "observed",
        "protected_open" => "authorized_once",
        "inbox_seen" => "not_attempted",
        "inbox_read" => "not_attempted"
      }
    }
  end
end
