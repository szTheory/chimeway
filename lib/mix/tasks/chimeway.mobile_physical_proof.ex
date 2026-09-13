defmodule Mix.Tasks.Chimeway.MobilePhysicalProof do
  @moduledoc false
  use Mix.Task

  alias Chimeway.MobileProof.PhysicalBundle

  @shortdoc "Run or verify the bounded physical iPhone proof"
  @remote "https://github.com/szTheory/crosswake.git"
  @ref "refs/heads/resume/chimeway-notification-physical-proof"
  @destination "evidence/mobile_physical/promoted"
  @focused_test "test/crosswake/proof_lane/chimeway_notification_physical_proof_test.exs"
  @phase_162 ".planning/workstreams/first-b2c-adopter-readiness/phases/162-physical-iphone-adoption-proof/162-VERIFICATION.md"
  @phase_162_tests [
    "test/crosswake/proof_lane/physical_iphone_evidence_transaction_test.exs",
    "test/crosswake/proof_lane/physical_iphone_preflight_test.exs",
    "test/crosswake/proof_lane/physical_iphone_report_contract_script_test.exs",
    "test/mix/tasks/crosswake.proof_lane.physical_iphone_test.exs",
    "test/crosswake/support_matrix/renderer_test.exs",
    "test/crosswake/support_matrix/support_matrix_test.exs"
  ]
  @alert_question "Did the expected Chimeway alert appear on the selected iPhone?"
  @alert_options %{
    "Observed" => "observed",
    "Did not appear" => "not_observed",
    "Cannot verify" => "unavailable"
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
  @facts %{
    "delivery_succeeded" => "passed",
    "apns_provider_accepted" => "passed",
    "trace_explainable" => "passed"
  }
  @preflight_rule_ids [
    "PHYSICAL-AUTHORITY-SELECTED-REVISION",
    "PHYSICAL-CROSSWAKE-SOURCE-BOUND",
    "PHYSICAL-CROSSWAKE-PHASE-162",
    "PHYSICAL-CHIMEWAY-IMMUTABLE-ARTIFACT",
    "PHYSICAL-APPLE-SIGNING",
    "PHYSICAL-APNS-SANDBOX",
    "PHYSICAL-SELECTED-IPHONE",
    "PHYSICAL-HOST-ACTIVATION-AUTHORITY",
    "PHYSICAL-DESTINATION-FRESH"
  ]

  @impl Mix.Task
  def run(["--preflight", "--json"]), do: print(preflight_result())

  def run(["--verify-promoted", "--json"]) do
    result = verify_promoted_result()
    print(result)
    if result.outcome != "physical_support_promoted", do: exit({:shutdown, 70})
  end

  def run(["--run", "--promote", "--json"]), do: promote()

  def run(_),
    do:
      Mix.raise(
        "expected --preflight --json, --run --promote --json, or --verify-promoted --json"
      )

  def preflight_rule_ids, do: @preflight_rule_ids
  def alert_question, do: @alert_question

  def preflight_result do
    selected = selected_revision()
    machine = machine_result()
    source = source_bound(selected)

    checks = [
      check("PHYSICAL-AUTHORITY-SELECTED-REVISION", ok?(selected), "blocked"),
      check("PHYSICAL-CROSSWAKE-SOURCE-BOUND", ok?(source), "unavailable"),
      check("PHYSICAL-CROSSWAKE-PHASE-162", phase_162_passed?(selected), "unavailable"),
      check("PHYSICAL-CHIMEWAY-IMMUTABLE-ARTIFACT", artifact_ready?(), "unavailable"),
      check("PHYSICAL-APPLE-SIGNING", physical_result_passed?(machine), "unavailable"),
      check(
        "PHYSICAL-APNS-SANDBOX",
        machine_fact?(machine, "apns_provider_accepted"),
        "unavailable"
      ),
      check("PHYSICAL-SELECTED-IPHONE", selected_iphone_passed?(machine), "unavailable"),
      check("PHYSICAL-HOST-ACTIVATION-AUTHORITY", host_authority_passed?(machine), "unavailable"),
      check("PHYSICAL-DESTINATION-FRESH", not File.exists?(@destination), "blocked")
    ]

    %{
      schema_version: 1,
      threshold: "physical_support",
      outcome: if(Enum.all?(checks, &(&1.outcome == "passed")), do: "ready", else: "blocked"),
      checks: checks
    }
  end

  def alert_state(value), do: Map.fetch(@alert_options, value) |> normalize_alert_state()

  defp promote do
    if System.get_env("CI") in ["true", "1"] do
      Mix.raise("physical proof promotion is unavailable in CI")
    end

    with "ready" <- preflight_result().outcome,
         {:ok, state} <- alert_state(System.get_env("CHIMEWAY_PHYSICAL_PROOF_ALERT_STATE")),
         "observed" <- state,
         {:ok, bundle} <- build_bundle(state),
         :ok <- PhysicalBundle.publish(bundle, @destination, selected_sha: selected_sha!()),
         {:ok, verified} <-
           PhysicalBundle.verify_directory(@destination, selected_sha: selected_sha!()) do
      print(%{
        schema_version: 1,
        threshold: "physical_support",
        outcome: "physical_support_promoted",
        run_ref: verified["chimeway_envelope"]["run_ref"],
        bundle_digest: verified["bundle_digest"]
      })
    else
      "not_observed" ->
        Mix.raise("visible alert was not observed; physical support remains pending")

      "unavailable" ->
        Mix.raise("visible alert cannot be inferred; physical support remains pending")

      {:error, %{rule_id: rule_id}} ->
        Mix.raise(rule_id)

      _ ->
        Mix.raise("physical proof preflight is incomplete; physical support remains pending")
    end
  end

  defp verify_promoted_result do
    check =
      with {:ok, sha} <- selected_revision(),
           {:ok, bundle} <- PhysicalBundle.verify_directory(@destination, selected_sha: sha) do
        {:ok, bundle}
      end

    case check do
      {:ok, bundle} ->
        %{
          schema_version: 1,
          threshold: "physical_support",
          outcome: "physical_support_promoted",
          checks: [check("PHYSICAL-PROMOTED-BUNDLE", true, "blocked")],
          run_ref: bundle["chimeway_envelope"]["run_ref"],
          bundle_digest: bundle["bundle_digest"]
        }

      _ ->
        %{
          schema_version: 1,
          threshold: "physical_support",
          outcome: "blocked",
          checks: [check("PHYSICAL-PROMOTED-BUNDLE", false, "blocked")]
        }
    end
  end

  defp build_bundle("observed") do
    with {:ok, sha} <- selected_revision(),
         {:ok, machine} <- machine_result(),
         {:ok, crosswake} <- crosswake_evidence(sha),
         {:ok, artifact_sha256} <- artifact_digest() do
      run_ref = machine["run_ref"]

      {:ok,
       PhysicalBundle.seal(%{
         "bundle_version" => 1,
         "owner" => "chimeway",
         "proof_class" => "physical",
         "chimeway_envelope" => %{
           "schema_version" => 1,
           "owner" => "chimeway",
           "chimeway_artifact_sha256" => artifact_sha256,
           "crosswake_remote" => @remote,
           "crosswake_sha" => sha,
           "crosswake_contract_version" => 1,
           "crosswake_evidence_sha256" => crosswake.evidence_sha256,
           "crosswake_completion_marker_sha256" => crosswake.marker_sha256,
           "run_ref" => run_ref,
           "captured_at" => crosswake.captured_at,
           "facts" => @facts
         },
         "crosswake_record" => %{
           "schema_version" => 1,
           "owner" => "crosswake",
           "crosswake_remote" => @remote,
           "crosswake_sha" => sha,
           "crosswake_contract_version" => 1,
           "evidence_sha256" => crosswake.evidence_sha256,
           "completion_marker_sha256" => crosswake.marker_sha256,
           "run_ref" => run_ref,
           "outcome" => "passed",
           "assertions" => @assertions
         },
         "visible_alert_attestation" => %{
           "schema_version" => 1,
           "run_ref" => run_ref,
           "machine_envelope_sha256" => String.duplicate("0", 64),
           "observed_at" => utc_now(),
           "attester_ref" => opaque_attester_ref(),
           "state" => "observed"
         },
         "completion_marker" => %{
           "schema_version" => 1,
           "owner" => "chimeway",
           "run_ref" => run_ref,
           "machine_envelope_sha256" => String.duplicate("0", 64),
           "state" => "validated",
           "component_digests" => %{},
           "bundle_digest" => String.duplicate("0", 64)
         },
         "bundle_digest" => String.duplicate("0", 64)
       })}
    end
  end

  defp build_bundle(_), do: :error

  defp selected_revision do
    with {:ok, value} <- File.read("priv/mobile_proof/crosswake-selected-sha"),
         sha = String.trim(value),
         true <- Regex.match?(~r/\A[0-9a-f]{40}\z/, sha) do
      {:ok, sha}
    else
      _ -> :error
    end
  end

  defp selected_sha! do
    {:ok, sha} = selected_revision()
    sha
  end

  defp source_bound({:ok, sha}) do
    with {advertised, 0} <-
           System.cmd("git", ["ls-remote", @remote, @ref], stderr_to_stdout: true),
         true <- String.starts_with?(advertised, sha <> "\t"),
         root when is_binary(root) <- System.get_env("CHIMEWAY_PHYSICAL_PROOF_CROSSWAKE_ROOT"),
         true <- Path.type(root) == :absolute,
         {head, 0} <- System.cmd("git", ["rev-parse", "HEAD"], cd: root, stderr_to_stdout: true),
         true <- String.trim(head) == sha,
         {"", 0} <- System.cmd("git", ["status", "--porcelain"], cd: root, stderr_to_stdout: true),
         true <- File.regular?(Path.join(root, @focused_test)),
         {_, 0} <-
           System.cmd("mix", ["test", @focused_test, "--max-failures", "1"],
             cd: root,
             stderr_to_stdout: true,
             env: crosswake_env()
           ),
         {:ok, _} <- crosswake_evidence(sha),
         {_, 0} <- validate_crosswake_source(root) do
      {:ok, sha}
    else
      _ -> :error
    end
  end

  defp source_bound(_), do: :error

  defp validate_crosswake_source(root) do
    code = """
    alias Crosswake.ProofLane.ChimewayNotificationPhysicalProof, as: Contract
    report = [
      %{id: "permission_observed", owner: :device_local, outcome: :passed},
      %{id: "authenticated_registration", owner: :backend_authority, outcome: :passed},
      %{id: "protected_activation_once", owner: :backend_authority, outcome: :passed}
    ]
    :ok = Contract.validate_source_bound(report, System.fetch_env!("CHIMEWAY_EVIDENCE_DIRECTORY"))
    """

    System.cmd("mix", ["run", "--no-start", "-e", code],
      cd: root,
      stderr_to_stdout: true,
      env:
        crosswake_env() ++
          [
            {"CHIMEWAY_EVIDENCE_DIRECTORY",
             System.get_env("CHIMEWAY_PHYSICAL_PROOF_CROSSWAKE_EVIDENCE") || ""}
          ]
    )
  end

  defp crosswake_env do
    [
      {"MIX_ENV", "test"},
      {"ASDF_ERLANG_VERSION", "27.3.4.15"},
      {"ASDF_ELIXIR_VERSION", "1.19.5-otp-27"}
    ]
  end

  defp phase_162_passed?({:ok, sha}) do
    case System.get_env("CHIMEWAY_PHYSICAL_PROOF_CROSSWAKE_ROOT") do
      root when is_binary(root) ->
        with {:ok, report} <- File.read(Path.join(root, @phase_162)),
             true <- report =~ "status: passed",
             {head, 0} <-
               System.cmd("git", ["rev-parse", "HEAD"], cd: root, stderr_to_stdout: true),
             true <- String.trim(head) == sha,
             {_, 0} <-
               System.cmd("mix", ["test" | @phase_162_tests] ++ ["--max-failures", "1"],
                 cd: root,
                 stderr_to_stdout: true,
                 env: crosswake_env()
               ) do
          true
        else
          _ -> false
        end

      _ ->
        false
    end
  end

  defp phase_162_passed?(_), do: false

  defp artifact_ready?, do: match?({:ok, _}, artifact_digest())

  defp artifact_digest do
    with path when is_binary(path) <- System.get_env("CHIMEWAY_PHYSICAL_PROOF_ARTIFACT"),
         true <- Path.type(path) == :absolute,
         {:ok, stat} <- File.lstat(path),
         true <- stat.type == :regular,
         {:ok, bytes} <- File.read(path) do
      digest = sha256(bytes)

      Code.require_file(Path.expand("../../../priv/adoption_proof/artifact_archive.ex", __DIR__))

      case apply(Chimeway.AdoptionProof.ArtifactArchive, :with_validated_archive, [
             path,
             digest,
             fn _ -> :ok end
           ]) do
        {:ok, :ok} -> {:ok, digest}
        _ -> :error
      end
    else
      _ -> :error
    end
  end

  defp machine_result do
    with path when is_binary(path) <- System.get_env("CHIMEWAY_PHYSICAL_PROOF_MACHINE_RESULT"),
         true <- Path.type(path) == :absolute,
         {:ok, bytes} <- File.read(path),
         {:ok, result} when is_map(result) <- Jason.decode(bytes),
         true <-
           Map.keys(result) |> Enum.sort() ==
             ~w(assertions chimeway_facts device_class outcome run_ref schema_version),
         true <- result["schema_version"] == 1,
         true <- result["outcome"] == "passed",
         true <- result["device_class"] == "physical_iphone",
         true <- result["assertions"] == @assertions,
         true <- result["chimeway_facts"] == @facts,
         true <- opaque?(result["run_ref"]) do
      {:ok, result}
    else
      _ -> :error
    end
  end

  defp crosswake_evidence(sha) do
    with directory when is_binary(directory) <-
           System.get_env("CHIMEWAY_PHYSICAL_PROOF_CROSSWAKE_EVIDENCE"),
         true <- Path.type(directory) == :absolute,
         {:ok, names} <- File.ls(directory),
         true <- Enum.sort(names) == [".complete", "proof-lane-evidence.json"],
         {:ok, evidence} <- File.read(Path.join(directory, "proof-lane-evidence.json")),
         {:ok, marker} <- File.read(Path.join(directory, ".complete")),
         evidence_sha256 = sha256(evidence),
         true <- marker == evidence_sha256,
         {:ok, record} when is_map(record) <- Jason.decode(evidence),
         true <- record["commit_ref"] == "git-" <> sha,
         true <- record["device_class"] == "physical_iphone",
         true <- record["outcome"] == "passed",
         true <- record["status"] == "passed",
         captured_at when is_binary(captured_at) <- record["captured_at"],
         true <- Regex.match?(~r/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/, captured_at) do
      {:ok,
       %{
         evidence_sha256: evidence_sha256,
         marker_sha256: sha256(marker),
         captured_at: captured_at
       }}
    else
      _ -> :error
    end
  end

  defp physical_result_passed?(
         {:ok, %{"outcome" => "passed", "device_class" => "physical_iphone"}}
       ),
       do: true

  defp physical_result_passed?(_), do: false

  defp machine_fact?({:ok, machine}, fact), do: machine["chimeway_facts"][fact] == "passed"
  defp machine_fact?(_, _), do: false

  defp selected_iphone_passed?({:ok, machine}) do
    machine["device_class"] == "physical_iphone" and
      assertion_passed?(machine, "permission_observed")
  end

  defp selected_iphone_passed?(_), do: false

  defp host_authority_passed?({:ok, machine}) do
    assertion_passed?(machine, "authenticated_registration") and
      assertion_passed?(machine, "protected_activation_once")
  end

  defp host_authority_passed?(_), do: false

  defp assertion_passed?(machine, id),
    do: Enum.any?(machine["assertions"], &(&1["id"] == id and &1["outcome"] == "passed"))

  defp check(rule_id, true, _blocked), do: %{rule_id: rule_id, outcome: "passed"}
  defp check(rule_id, false, outcome), do: %{rule_id: rule_id, outcome: outcome}
  defp ok?({:ok, _}), do: true
  defp ok?(_), do: false

  defp opaque?(value),
    do: is_binary(value) and Regex.match?(~r/\A[a-z0-9][a-z0-9-]{7,127}\z/, value)

  defp normalize_alert_state({:ok, state}), do: {:ok, state}
  defp normalize_alert_state(:error), do: :error

  defp utc_now,
    do:
      DateTime.utc_now() |> DateTime.truncate(:second) |> Calendar.strftime("%Y-%m-%dT%H:%M:%SZ")

  defp opaque_attester_ref,
    do: "attester-" <> (:crypto.strong_rand_bytes(12) |> Base.encode16(case: :lower))

  defp sha256(bytes), do: bytes |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)
  defp print(result), do: Mix.shell().info(Jason.encode!(result))
end
