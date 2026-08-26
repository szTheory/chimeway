defmodule Chimeway.MobileProof.PhysicalBundle do
  @moduledoc false

  @remote "https://github.com/szTheory/crosswake.git"
  @bundle_keys ~w(bundle_version owner proof_class chimeway_envelope crosswake_record visible_alert_attestation completion_marker bundle_sha256)
  @envelope_keys ~w(schema_version owner chimeway_artifact_sha256 crosswake_remote crosswake_sha crosswake_contract_version crosswake_evidence_sha256 crosswake_completion_marker_sha256 run_ref captured_at facts)
  @crosswake_keys ~w(schema_version owner crosswake_sha evidence_sha256 completion_marker_sha256 assertions)
  @attestation_keys ~w(schema_version run_ref machine_envelope_sha256 observed_at attester_ref state)
  @completion_keys ~w(schema_version owner run_ref machine_envelope_sha256 state)
  @facts %{
    "delivery_succeeded" => "passed",
    "apns_provider_accepted" => "passed",
    "trace_explainable" => "passed"
  }
  @assertions [
    %{"id" => "permission_observed", "owner" => "device_local", "outcome" => "passed"},
    %{
      "id" => "authenticated_registration",
      "owner" => "backend_authority",
      "outcome" => "passed"
    },
    %{"id" => "protected_activation_once", "owner" => "backend_authority", "outcome" => "passed"}
  ]
  @sensitive ~w(token credential password secret payload identity account endpoint media screenshot video log path device_id canonical_bytes)

  @spec validate(term(), keyword()) ::
          {:ok, map()} | {:error, %{rule_id: String.t(), path: [String.t()]}}
  def validate(bundle, opts \\ [])

  def validate(bundle, opts) when is_map(bundle) and is_list(opts) do
    selected_sha = Keyword.get(opts, :selected_sha)

    with :ok <- exact_keys(bundle, @bundle_keys, "PP-SCHEMA", []),
         :ok <- equals(bundle, "bundle_version", 1, "PP-VERSION"),
         :ok <- equals(bundle, "owner", "chimeway", "PP-OWNER"),
         :ok <- equals(bundle, "proof_class", "physical", "PP-PROOF-CLASS"),
         :ok <- no_sensitive(bundle),
         :ok <- envelope(bundle["chimeway_envelope"], selected_sha),
         :ok <- crosswake(bundle["crosswake_record"], selected_sha, bundle["chimeway_envelope"]),
         :ok <- attestation(bundle["visible_alert_attestation"], bundle["chimeway_envelope"]),
         :ok <- completion(bundle["completion_marker"], bundle["chimeway_envelope"]),
         :ok <- bundle_digest_matches(bundle) do
      {:ok, bundle}
    end
  end

  def validate(_, _), do: error("PP-SCHEMA", [])

  @spec publish(map(), Path.t(), keyword()) ::
          :ok | {:error, %{rule_id: String.t(), path: [String.t()]}}
  def publish(bundle, destination, opts \\ [])

  def publish(bundle, destination, opts) when is_binary(destination) do
    with {:ok, _} <- validate(bundle, opts),
         :ok <- create_destination(destination),
         :ok <- File.write(Path.join(destination, "physical-bundle.json"), Jason.encode!(bundle)) do
      :ok
    else
      {:error, _} = error -> error
      _ -> error("PP-PUBLICATION", [])
    end
  end

  def publish(_, _, _), do: error("PP-PUBLICATION", [])

  @spec bundle_digest(map()) :: String.t()
  def bundle_digest(bundle) when is_map(bundle) do
    bundle
    |> Map.delete("bundle_sha256")
    |> Jason.encode!()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp envelope(value, selected_sha) do
    with :ok <- exact_keys(value, @envelope_keys, "PP-ENVELOPE-SCHEMA", ["chimeway_envelope"]),
         :ok <- equals(value, "schema_version", 1, "PP-ENVELOPE-VERSION", ["chimeway_envelope"]),
         :ok <- equals(value, "owner", "chimeway", "PP-ENVELOPE-OWNER", ["chimeway_envelope"]),
         :ok <-
           digest(value, "chimeway_artifact_sha256", "PP-ARTIFACT-DIGEST", ["chimeway_envelope"]),
         :ok <-
           equals(value, "crosswake_remote", @remote, "PP-CROSSWAKE-REMOTE", ["chimeway_envelope"]),
         :ok <-
           selected_sha(value["crosswake_sha"], selected_sha, [
             "chimeway_envelope",
             "crosswake_sha"
           ]),
         :ok <-
           equals(value, "crosswake_contract_version", 1, "PP-CROSSWAKE-CONTRACT", [
             "chimeway_envelope"
           ]),
         :ok <-
           digest(value, "crosswake_evidence_sha256", "PP-EVIDENCE-DIGEST", ["chimeway_envelope"]),
         :ok <-
           digest(value, "crosswake_completion_marker_sha256", "PP-MARKER-DIGEST", [
             "chimeway_envelope"
           ]),
         :ok <- opaque(value["run_ref"], "PP-RUN-REF", ["chimeway_envelope", "run_ref"]),
         :ok <- utc(value["captured_at"], "PP-CAPTURED-AT", ["chimeway_envelope", "captured_at"]),
         :ok <- equals(value, "facts", @facts, "PP-FACTS", ["chimeway_envelope"]) do
      :ok
    end
  end

  defp crosswake(value, selected_sha, envelope) do
    with :ok <- exact_keys(value, @crosswake_keys, "PP-CROSSWAKE-SCHEMA", ["crosswake_record"]),
         :ok <- equals(value, "schema_version", 1, "PP-CROSSWAKE-VERSION", ["crosswake_record"]),
         :ok <- equals(value, "owner", "crosswake", "PP-CROSSWAKE-OWNER", ["crosswake_record"]),
         :ok <-
           selected_sha(value["crosswake_sha"], selected_sha, [
             "crosswake_record",
             "crosswake_sha"
           ]),
         :ok <-
           equals(value, "crosswake_sha", envelope["crosswake_sha"], "PP-CROSSWAKE-REVISION", [
             "crosswake_record"
           ]),
         :ok <-
           equals(
             value,
             "evidence_sha256",
             envelope["crosswake_evidence_sha256"],
             "PP-EVIDENCE-DIGEST",
             ["crosswake_record"]
           ),
         :ok <-
           equals(
             value,
             "completion_marker_sha256",
             envelope["crosswake_completion_marker_sha256"],
             "PP-MARKER-DIGEST",
             ["crosswake_record"]
           ),
         :ok <-
           equals(value, "assertions", @assertions, "PP-CROSSWAKE-ASSERTIONS", [
             "crosswake_record"
           ]) do
      :ok
    end
  end

  defp attestation(value, envelope) do
    with :ok <-
           exact_keys(value, @attestation_keys, "PP-ATTESTATION-SCHEMA", [
             "visible_alert_attestation"
           ]),
         :ok <-
           equals(value, "schema_version", 1, "PP-ATTESTATION-VERSION", [
             "visible_alert_attestation"
           ]),
         :ok <-
           equals(value, "run_ref", envelope["run_ref"], "PP-ATTESTATION-RUN-REF", [
             "visible_alert_attestation"
           ]),
         :ok <-
           digest(value, "machine_envelope_sha256", "PP-ATTESTATION-ENVELOPE", [
             "visible_alert_attestation"
           ]),
         :ok <-
           utc(value["observed_at"], "PP-OBSERVED-AT", [
             "visible_alert_attestation",
             "observed_at"
           ]),
         :ok <-
           opaque(value["attester_ref"], "PP-ATTESTER-REF", [
             "visible_alert_attestation",
             "attester_ref"
           ]),
         :ok <- state(value["state"], ["visible_alert_attestation", "state"]) do
      :ok
    end
  end

  defp completion(value, envelope) do
    with :ok <- exact_keys(value, @completion_keys, "PP-COMPLETION-SCHEMA", ["completion_marker"]),
         :ok <- equals(value, "schema_version", 1, "PP-COMPLETION-VERSION", ["completion_marker"]),
         :ok <- equals(value, "owner", "chimeway", "PP-COMPLETION-OWNER", ["completion_marker"]),
         :ok <-
           equals(value, "run_ref", envelope["run_ref"], "PP-COMPLETION-RUN-REF", [
             "completion_marker"
           ]),
         :ok <-
           digest(value, "machine_envelope_sha256", "PP-COMPLETION-ENVELOPE", [
             "completion_marker"
           ]),
         :ok <- equals(value, "state", "validated", "PP-COMPLETION-STATE", ["completion_marker"]) do
      :ok
    end
  end

  defp exact_keys(value, keys, rule, path) when is_map(value) do
    if Map.keys(value) |> Enum.sort() == Enum.sort(keys), do: :ok, else: error(rule, path)
  end

  defp exact_keys(_, _, rule, path), do: error(rule, path)

  defp equals(value, key, expected, rule, prefix \\ []),
    do: if(Map.get(value, key) == expected, do: :ok, else: error(rule, prefix ++ [key]))

  defp digest(value, key, rule, prefix),
    do:
      if(is_binary(value[key]) and Regex.match?(~r/\A[0-9a-f]{64}\z/, value[key]),
        do: :ok,
        else: error(rule, prefix ++ [key])
      )

  defp bundle_digest_matches(bundle),
    do:
      if(bundle["bundle_sha256"] == bundle_digest(bundle),
        do: :ok,
        else: error("PP-BUNDLE-DIGEST", ["bundle_sha256"])
      )

  defp selected_sha(sha, expected, path)
       when is_binary(sha) and is_binary(expected) and sha == expected do
    if Regex.match?(~r/\A[0-9a-f]{40}\z/, sha), do: :ok, else: error("PP-CROSSWAKE-SHA", path)
  end

  defp selected_sha(_, _, path), do: error("PP-CROSSWAKE-SHA", path)

  defp opaque(value, rule, path),
    do:
      if(is_binary(value) and Regex.match?(~r/\A[a-z0-9][a-z0-9-]{7,127}\z/, value),
        do: :ok,
        else: error(rule, path)
      )

  defp utc(value, rule, path),
    do:
      if(is_binary(value) and Regex.match?(~r/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/, value),
        do: :ok,
        else: error(rule, path)
      )

  defp state(value, _path) when value in ~w(observed not_observed unavailable), do: :ok
  defp state(_, path), do: error("PP-ATTESTATION-STATE", path)

  defp no_sensitive(value) do
    case sensitive_path(value, []) do
      nil -> :ok
      path -> error("PP-SENSITIVE", path)
    end
  end

  defp sensitive_path(value, path) when is_map(value),
    do:
      Enum.find_value(value, fn {key, nested} ->
        if sensitive?(to_string(key)),
          do: path ++ [to_string(key)],
          else: sensitive_path(nested, path ++ [to_string(key)])
      end)

  defp sensitive_path(value, path) when is_list(value),
    do: Enum.find_value(value, fn nested -> sensitive_path(nested, path) end)

  defp sensitive_path(value, path), do: if(sensitive?(value), do: path, else: nil)

  defp sensitive?(value) when is_binary(value),
    do: String.contains?(String.downcase(value), @sensitive)

  defp sensitive?(_), do: false

  defp create_destination(destination) do
    case File.mkdir(destination) do
      :ok -> :ok
      {:error, :eexist} -> error("PP-PUBLICATION-COLLISION", [])
      _ -> error("PP-PUBLICATION", [])
    end
  end

  defp error(rule_id, path), do: {:error, %{rule_id: rule_id, path: path}}
end
