defmodule Chimeway.MobileProof.Extension do
  @moduledoc false

  @version 1
  @remote "https://github.com/szTheory/crosswake.git"
  @sha "f2c502cdb1ce572a4a57257d9e3c051665704b90"
  @scenarios ~w(accepted_handoff_protected_open two_installation_fanout zero_target_suppression token_rotation revocation_race classified_retry expiry_before_io opt_in_installation_safe_collapse trigger_commit_recovery post_handoff_ambiguity recursive_leak_prevention offline_reauthorization stale_denied_open replay_rejection)
  @keys ~w(extension_version owner proof_class chimeway_artifact_sha256 crosswake_sha crosswake_contract crosswake_report scenario_ids executable_facts subjective_observation)

  @spec validate(term(), keyword()) :: {:ok, map()} | {:error, %{rule_id: String.t(), path: [String.t()]}}
  def validate(proof, opts \\ [])
  def validate(proof, opts) when is_map(proof) do
    with :ok <- exact_keys(proof),
         :ok <- equals(proof, "extension_version", @version, "MP-VERSION"),
         :ok <- equals(proof, "owner", "chimeway", "MP-OWNER"),
         :ok <- equals(proof, "proof_class", "hermetic", "MP-PROOF-CLASS"),
         :ok <- digest(proof, "chimeway_artifact_sha256", "MP-ARTIFACT-DIGEST"),
         :ok <- artifact_match(proof, opts),
         :ok <- equals(proof, "crosswake_sha", @sha, "MP-CROSSWAKE-SHA"),
         :ok <- contract(proof),
         :ok <- scenarios(proof),
         :ok <- no_sensitive(proof),
         :ok <- facts(proof),
         :ok <- observation(proof),
         :ok <- canonical_report(proof, opts) do
      {:ok, proof}
    else
      {:error, _} = error -> error
    end
  end

  def validate(_, _), do: error("MP-SCHEMA", [])

  defp exact_keys(proof) do
    if Map.keys(proof) |> Enum.sort() == Enum.sort(@keys), do: :ok, else: error("MP-SCHEMA", [])
  end

  defp equals(proof, key, value, rule), do: if(Map.get(proof, key) == value, do: :ok, else: error(rule, [key]))

  defp digest(proof, key, rule) do
    if is_binary(proof[key]) and Regex.match?(~r/\A[0-9a-f]{64}\z/, proof[key]), do: :ok, else: error(rule, [key])
  end

  defp artifact_match(proof, opts) do
    case Keyword.get(opts, :artifact_sha256) do
      nil -> :ok
      digest -> if(digest == proof["chimeway_artifact_sha256"], do: :ok, else: error("MP-ARTIFACT-DIGEST", ["chimeway_artifact_sha256"]))
    end
  end

  defp contract(proof) do
    expected = %{"schema_version" => 1, "remote" => @remote, "sha" => @sha, "contract" => "physical_iphone_contract"}
    if proof["crosswake_contract"] == expected, do: :ok, else: error("MP-CROSSWAKE-CONTRACT", ["crosswake_contract"])
  end

  defp scenarios(proof) do
    if proof["scenario_ids"] == @scenarios, do: :ok, else: error("MP-SCENARIOS-ORDER", ["scenario_ids"])
  end

  defp facts(proof) do
    if proof["executable_facts"] == %{"alpha_twin" => "validated"}, do: :ok, else: error("MP-EXECUTABLE-FACTS", ["executable_facts"])
  end

  defp observation(proof) do
    if proof["subjective_observation"] == %{"visible_alert" => "not_asserted"}, do: :ok, else: error("MP-SUBJECTIVE-OBSERVATION", ["subjective_observation"])
  end

  defp canonical_report(proof, opts) do
    validator = Keyword.get(opts, :canonical_validator, &default_validator/1)

    case validator.(string_report_to_atoms(proof["crosswake_report"])) do
      :ok -> :ok
      {:error, "PI-ASSERTIONS-ORDER"} -> error("MP-CROSSWAKE-ASSERTIONS-ORDER", ["crosswake_report"])
      {:error, _} -> error("MP-CROSSWAKE-ASSERTIONS", ["crosswake_report"])
      _ -> error("MP-CROSSWAKE-ASSERTIONS", ["crosswake_report"])
    end
  rescue
    _ -> error("MP-CROSSWAKE-ASSERTIONS", ["crosswake_report"])
  end

  defp string_report_to_atoms(report) when is_list(report) do
    Enum.map(report, fn
      %{"id" => id, "owner" => owner, "outcome" => outcome} = value when map_size(value) == 3 ->
        %{id: id, owner: safe_owner(owner), outcome: safe_outcome(outcome)}
      _ -> %{}
    end)
  end
  defp string_report_to_atoms(_), do: []
  defp safe_owner("device_local"), do: :device_local
  defp safe_owner("backend_authority"), do: :backend_authority
  defp safe_owner("evidence_promotion"), do: :evidence_promotion
  defp safe_owner(_), do: :invalid
  defp safe_outcome("passed"), do: :passed
  defp safe_outcome("blocked"), do: :blocked
  defp safe_outcome("unavailable"), do: :unavailable
  defp safe_outcome(_), do: :invalid

  defp default_validator(report) do
    if Code.ensure_loaded?(Crosswake.ProofLane.PhysicalIphoneContract),
      do: apply(Crosswake.ProofLane.PhysicalIphoneContract, :validate_report, [report]),
      else: {:error, "PI-ASSERTIONS-COMPLETE"}
  end

  defp no_sensitive(proof), do: if(sensitive?([proof["executable_facts"], proof["subjective_observation"]]), do: error("MP-SENSITIVE", []), else: :ok)
  defp sensitive?(value) when is_map(value), do: Enum.any?(value, fn {key, nested} -> sensitive?(to_string(key)) or sensitive?(nested) end)
  defp sensitive?(value) when is_list(value), do: Enum.any?(value, &sensitive?/1)
  defp sensitive?(value) when is_binary(value), do: String.contains?(String.downcase(value), ["token", "credential", "password", "secret", "payload"])
  defp sensitive?(_), do: false
  defp error(rule_id, path), do: {:error, %{rule_id: rule_id, path: path}}
end
