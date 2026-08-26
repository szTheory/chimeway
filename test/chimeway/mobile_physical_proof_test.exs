defmodule Chimeway.MobileProof.PhysicalBundleTest do
  use ExUnit.Case, async: true

  alias Chimeway.MobileProof.PhysicalBundle

  test "validates a closed physical bundle and publishes it exactly once" do
    bundle = physical_bundle()

    destination =
      Path.join(System.tmp_dir!(), "physical-bundle-#{System.unique_integer([:positive])}")

    try do
      assert {:ok, ^bundle} = PhysicalBundle.validate(bundle, selected_sha: selected_sha())
      assert :ok = PhysicalBundle.publish(bundle, destination, selected_sha: selected_sha())

      assert {:error, %{rule_id: "PP-PUBLICATION-COLLISION", path: []}} =
               PhysicalBundle.publish(bundle, destination, selected_sha: selected_sha())
    after
      File.rm_rf(destination)
    end
  end

  test "rejects a sensitive nested value without echoing it" do
    canary = "CANARY-DEVICE-TOKEN"

    bundle =
      put_in(physical_bundle(), ["chimeway_envelope", "facts", "delivery_succeeded"], canary)

    assert {:error,
            %{rule_id: "PP-SENSITIVE", path: ["chimeway_envelope", "facts", "delivery_succeeded"]}} =
             PhysicalBundle.validate(bundle, selected_sha: selected_sha())
  end

  defp physical_bundle do
    bundle = %{
      "bundle_version" => 1,
      "owner" => "chimeway",
      "proof_class" => "physical",
      "chimeway_envelope" => %{
        "schema_version" => 1,
        "owner" => "chimeway",
        "chimeway_artifact_sha256" => String.duplicate("a", 64),
        "crosswake_remote" => "https://github.com/szTheory/crosswake.git",
        "crosswake_sha" => selected_sha(),
        "crosswake_contract_version" => 1,
        "crosswake_evidence_sha256" => String.duplicate("b", 64),
        "crosswake_completion_marker_sha256" => String.duplicate("c", 64),
        "run_ref" => "run-20260826-opaque",
        "captured_at" => "2026-08-26T12:00:00Z",
        "facts" => %{
          "delivery_succeeded" => "passed",
          "apns_provider_accepted" => "passed",
          "trace_explainable" => "passed"
        }
      },
      "crosswake_record" => %{
        "schema_version" => 1,
        "owner" => "crosswake",
        "crosswake_sha" => selected_sha(),
        "evidence_sha256" => String.duplicate("b", 64),
        "completion_marker_sha256" => String.duplicate("c", 64),
        "assertions" => [
          %{"id" => "permission_observed", "owner" => "device_local", "outcome" => "passed"},
          %{
            "id" => "authenticated_registration",
            "owner" => "backend_authority",
            "outcome" => "passed"
          },
          %{
            "id" => "protected_activation_once",
            "owner" => "backend_authority",
            "outcome" => "passed"
          }
        ]
      },
      "visible_alert_attestation" => %{
        "schema_version" => 1,
        "run_ref" => "run-20260826-opaque",
        "machine_envelope_sha256" => String.duplicate("d", 64),
        "observed_at" => "2026-08-26T12:01:00Z",
        "attester_ref" => "attester-opaque",
        "state" => "observed"
      },
      "completion_marker" => %{
        "schema_version" => 1,
        "owner" => "chimeway",
        "run_ref" => "run-20260826-opaque",
        "machine_envelope_sha256" => String.duplicate("d", 64),
        "state" => "validated"
      }
    }

    Map.put(bundle, "bundle_sha256", PhysicalBundle.bundle_digest(bundle))
  end

  defp selected_sha, do: File.read!("priv/mobile_proof/crosswake-selected-sha") |> String.trim()
end
