defmodule Chimeway.MobileProof.PhysicalBundle do
  @moduledoc false

  @remote "https://github.com/szTheory/crosswake.git"
  @files [
    {"chimeway-envelope.json", "chimeway_envelope"},
    {"crosswake-record.json", "crosswake_record"},
    {"visible-alert-attestation.json", "visible_alert_attestation"}
  ]
  @completion_file ".complete"
  @bundle_keys ~w(bundle_version owner proof_class chimeway_envelope crosswake_record visible_alert_attestation completion_marker bundle_digest)
  @envelope_keys ~w(schema_version owner chimeway_artifact_sha256 crosswake_remote crosswake_sha crosswake_contract_version crosswake_evidence_sha256 crosswake_completion_marker_sha256 run_ref captured_at facts)
  @crosswake_keys ~w(schema_version owner crosswake_remote crosswake_sha crosswake_contract_version evidence_sha256 completion_marker_sha256 run_ref outcome assertions)
  @attestation_keys ~w(schema_version run_ref machine_envelope_sha256 observed_at attester_ref state)
  @completion_keys ~w(schema_version owner run_ref machine_envelope_sha256 state component_digests bundle_digest)
  @component_keys Enum.map(@files, &elem(&1, 0))
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
         :ok <- completion(bundle["completion_marker"], bundle),
         :ok <- equals(bundle, "bundle_digest", bundle_digest(bundle), "PP-BUNDLE-DIGEST") do
      {:ok, bundle}
    end
  end

  def validate(_, _), do: error("PP-SCHEMA", [])

  @spec publish(map(), Path.t(), keyword()) ::
          :ok | {:error, %{rule_id: String.t(), path: [String.t()]}}
  def publish(bundle, destination, opts \\ [])

  def publish(bundle, destination, opts) when is_binary(destination) do
    with {:ok, _} <- validate(bundle, opts),
         :ok <- promotable(bundle),
         :ok <- create_destination(destination) do
      case write_files(bundle, destination) do
        :ok -> :ok
        _ -> cleanup_failed_publication(destination)
      end
    end
  end

  def publish(_, _, _), do: error("PP-PUBLICATION", [])

  @doc false
  @spec verify_directory(Path.t(), keyword()) ::
          {:ok, map()} | {:error, %{rule_id: String.t(), path: [String.t()]}}
  def verify_directory(destination, opts \\ []) when is_binary(destination) do
    with :ok <- exact_publication_files(destination),
         {:ok, records} <- read_canonical_records(destination),
         bundle <- bundle_from_records(records),
         {:ok, _} <- validate(bundle, opts),
         :ok <- promotable(bundle) do
      {:ok, bundle}
    end
  end

  @spec bundle_digest(map()) :: String.t()
  def bundle_digest(bundle) when is_map(bundle) do
    bundle
    |> component_digests()
    |> Jason.encode!()
    |> sha256()
  end

  @doc false
  def seal(bundle) when is_map(bundle) do
    envelope_sha256 = canonical_digest(bundle["chimeway_envelope"])

    bundle =
      bundle
      |> put_in(["visible_alert_attestation", "machine_envelope_sha256"], envelope_sha256)
      |> put_in(["completion_marker", "machine_envelope_sha256"], envelope_sha256)

    components = component_digests(bundle)
    digest = sha256(Jason.encode!(components))

    bundle
    |> put_in(["completion_marker", "component_digests"], components)
    |> put_in(["completion_marker", "bundle_digest"], digest)
    |> Map.put("bundle_digest", digest)
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
           equals(value, "crosswake_remote", @remote, "PP-CROSSWAKE-REMOTE", ["crosswake_record"]),
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
             "crosswake_contract_version",
             envelope["crosswake_contract_version"],
             "PP-CROSSWAKE-CONTRACT",
             ["crosswake_record"]
           ),
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
           equals(value, "run_ref", envelope["run_ref"], "PP-CROSSWAKE-RUN-REF", [
             "crosswake_record"
           ]),
         :ok <- equals(value, "outcome", "passed", "PP-CROSSWAKE-OUTCOME", ["crosswake_record"]),
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
           equals(
             value,
             "machine_envelope_sha256",
             canonical_digest(envelope),
             "PP-ATTESTATION-ENVELOPE",
             ["visible_alert_attestation"]
           ),
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

  defp completion(value, bundle) do
    envelope = bundle["chimeway_envelope"]
    expected_components = component_digests(bundle)
    expected_bundle_digest = sha256(Jason.encode!(expected_components))

    with :ok <- exact_keys(value, @completion_keys, "PP-COMPLETION-SCHEMA", ["completion_marker"]),
         :ok <- equals(value, "schema_version", 1, "PP-COMPLETION-VERSION", ["completion_marker"]),
         :ok <- equals(value, "owner", "chimeway", "PP-COMPLETION-OWNER", ["completion_marker"]),
         :ok <-
           equals(value, "run_ref", envelope["run_ref"], "PP-COMPLETION-RUN-REF", [
             "completion_marker"
           ]),
         :ok <-
           equals(
             value,
             "machine_envelope_sha256",
             canonical_digest(envelope),
             "PP-COMPLETION-ENVELOPE",
             ["completion_marker"]
           ),
         :ok <-
           exact_keys(value["component_digests"], @component_keys, "PP-COMPONENT-SCHEMA", [
             "completion_marker",
             "component_digests"
           ]),
         :ok <- component_digest_shapes(value["component_digests"]),
         :ok <-
           equals(value, "component_digests", expected_components, "PP-COMPONENT-DIGEST", [
             "completion_marker"
           ]),
         :ok <-
           equals(value, "bundle_digest", expected_bundle_digest, "PP-COMPLETION-BUNDLE-DIGEST", [
             "completion_marker"
           ]),
         :ok <- equals(value, "state", "validated", "PP-COMPLETION-STATE", ["completion_marker"]) do
      :ok
    end
  end

  defp component_digest_shapes(digests) do
    case Enum.find(@component_keys, &(not digest_value?(digests[&1]))) do
      nil ->
        :ok

      filename ->
        error("PP-COMPONENT-DIGEST", ["completion_marker", "component_digests", filename])
    end
  end

  defp component_digests(bundle) do
    Map.new(@files, fn {filename, key} -> {filename, canonical_digest(bundle[key])} end)
  end

  defp canonical_digest(value), do: value |> Jason.encode!() |> sha256()
  defp sha256(bytes), do: bytes |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)

  defp write_files(bundle, destination) do
    Enum.reduce_while(@files, :ok, fn {filename, key}, :ok ->
      case write_exclusive(Path.join(destination, filename), Jason.encode!(bundle[key])) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
    |> case do
      :ok ->
        write_exclusive(
          Path.join(destination, @completion_file),
          Jason.encode!(bundle["completion_marker"])
        )

      error ->
        error
    end
  end

  defp write_exclusive(path, bytes) do
    case File.open(path, [:write, :binary, :exclusive], fn io -> IO.binwrite(io, bytes) end) do
      {:ok, :ok} -> :ok
      _ -> :error
    end
  end

  defp exact_publication_files(destination) do
    with {:ok, names} <- File.ls(destination),
         true <- Enum.sort(names) == Enum.sort([@completion_file | @component_keys]),
         true <- Enum.all?(names, &regular_leaf?(Path.join(destination, &1))) do
      :ok
    else
      _ -> error("PP-PUBLICATION-FILES", [])
    end
  end

  defp regular_leaf?(path), do: match?({:ok, %File.Stat{type: :regular}}, File.lstat(path))

  defp read_canonical_records(destination) do
    Enum.reduce_while(
      @files ++ [{@completion_file, "completion_marker"}],
      {:ok, %{}},
      fn {filename, key}, {:ok, acc} ->
        with {:ok, bytes} <- File.read(Path.join(destination, filename)),
             {:ok, value} when is_map(value) <- Jason.decode(bytes),
             true <- Jason.encode!(value) == bytes do
          {:cont, {:ok, Map.put(acc, key, value)}}
        else
          _ -> {:halt, error("PP-PUBLICATION-CANONICAL", [filename])}
        end
      end
    )
  end

  defp bundle_from_records(records) do
    %{
      "bundle_version" => 1,
      "owner" => "chimeway",
      "proof_class" => "physical",
      "chimeway_envelope" => records["chimeway_envelope"],
      "crosswake_record" => records["crosswake_record"],
      "visible_alert_attestation" => records["visible_alert_attestation"],
      "completion_marker" => records["completion_marker"],
      "bundle_digest" => records["completion_marker"]["bundle_digest"]
    }
  end

  defp exact_keys(value, keys, rule, path) when is_map(value) do
    if Map.keys(value) |> Enum.sort() == Enum.sort(keys), do: :ok, else: error(rule, path)
  end

  defp exact_keys(_, _, rule, path), do: error(rule, path)

  defp equals(value, key, expected, rule, prefix \\ []),
    do: if(Map.get(value, key) == expected, do: :ok, else: error(rule, prefix ++ [key]))

  defp digest(value, key, rule, prefix),
    do: if(digest_value?(value[key]), do: :ok, else: error(rule, prefix ++ [key]))

  defp digest_value?(value), do: is_binary(value) and Regex.match?(~r/\A[0-9a-f]{64}\z/, value)

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
    with :ok <- File.mkdir_p(Path.dirname(destination)) do
      case File.mkdir(destination) do
        :ok -> :ok
        {:error, :eexist} -> error("PP-PUBLICATION-COLLISION", [])
        _ -> error("PP-PUBLICATION", [])
      end
    else
      _ -> error("PP-PUBLICATION", [])
    end
  end

  defp cleanup_failed_publication(destination) do
    _ = File.rm_rf(destination)
    error("PP-PUBLICATION", [])
  end

  defp promotable(%{"visible_alert_attestation" => %{"state" => "observed"}}), do: :ok

  defp promotable(_),
    do: error("PP-ATTESTATION-NOT-PROMOTABLE", ["visible_alert_attestation", "state"])

  defp error(rule_id, path), do: {:error, %{rule_id: rule_id, path: path}}
end
