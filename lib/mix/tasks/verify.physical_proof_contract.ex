defmodule Mix.Tasks.Verify.PhysicalProofContract do
  @moduledoc false
  use Mix.Task

  alias Chimeway.MobileProof.PhysicalBundle

  @shortdoc "Verify the selected CrossWake physical-proof contract without credentials"
  @authority "priv/mobile_proof/crosswake-selected-sha"
  @remote "https://github.com/szTheory/crosswake.git"
  @ref "refs/heads/phase-103-chimeway-notification-proof"
  @module "lib/crosswake/proof_lane/chimeway_notification_physical_proof.ex"
  @fixture "test/fixtures/proof_lane/chimeway-notification-physical-proof.json"
  @focused_test "test/crosswake/proof_lane/chimeway_notification_physical_proof_test.exs"

  @impl Mix.Task
  def run([]) do
    with {:ok, sha} <- selected_sha(),
         :ok <- advertised?(sha),
         {:ok, checkout} <- fresh_checkout(sha),
         :ok <- verify_checkout(checkout, sha),
         :ok <- verify_chimeway_bundle(sha) do
      Mix.shell().info("release_ready_physical_pending")
    else
      _ -> exit({:shutdown, 70})
    end
  after
    cleanup_checkout()
  end

  def run(_), do: exit({:shutdown, 64})

  defp selected_sha do
    with {:ok, value} <- File.read(@authority),
         sha = String.trim(value),
         true <- Regex.match?(~r/\A[0-9a-f]{40}\z/, sha) do
      {:ok, sha}
    else
      _ -> :error
    end
  end

  defp advertised?(sha) do
    case System.cmd("git", ["ls-remote", @remote, @ref], stderr_to_stdout: true) do
      {output, 0} when is_binary(output) ->
        if String.starts_with?(output, sha <> "\t"), do: :ok, else: :error

      _ ->
        :error
    end
  end

  defp fresh_checkout(sha) do
    root =
      Path.join(System.tmp_dir!(), "chimeway-crosswake-#{System.unique_integer([:positive])}")

    Process.put({__MODULE__, :checkout}, root)

    with {_, 0} <-
           System.cmd("git", ["clone", "--quiet", "--no-checkout", @remote, root],
             stderr_to_stdout: true
           ),
         {_, 0} <-
           System.cmd("git", ["fetch", "--quiet", "origin", @ref],
             cd: root,
             stderr_to_stdout: true
           ),
         {_, 0} <-
           System.cmd("git", ["checkout", "--quiet", "--detach", sha],
             cd: root,
             stderr_to_stdout: true
           ) do
      {:ok, root}
    else
      _ -> :error
    end
  end

  defp verify_checkout(root, sha) do
    module = Path.join(root, @module)
    fixture = Path.join(root, @fixture)
    focused = Path.join(root, @focused_test)

    with {^sha <> "\n", 0} <-
           System.cmd("git", ["rev-parse", "HEAD"], cd: root, stderr_to_stdout: true),
         {"", 0} <- System.cmd("git", ["status", "--porcelain"], cd: root, stderr_to_stdout: true),
         true <- Enum.all?([module, fixture, focused], &File.regular?/1),
         true <-
           marker?(module, "defmodule Crosswake.ProofLane.ChimewayNotificationPhysicalProof"),
         true <- marker?(module, "def schema_version"),
         true <- marker?(module, "def assertions"),
         true <- marker?(module, "def validate_report"),
         true <- marker?(module, "def validate_source_bound"),
         true <- marker?(module, "Evidence.check"),
         true <- marker?(focused, "validate_source_bound"),
         {_, 0} <-
           System.cmd("mix", ["test", @focused_test, "--max-failures", "1"],
             cd: root,
             stderr_to_stdout: true,
             env: crosswake_test_env()
           ) do
      :ok
    else
      _ -> :error
    end
  end

  defp marker?(path, marker), do: path |> File.read!() |> String.contains?(marker)

  # The freshly detached source remains the test subject; this only reuses already
  # installed dependency artifacts so the credential-free verifier never mutates it.
  defp crosswake_test_env do
    dependency_root =
      System.get_env("CROSSWAKE_DEPENDENCY_ROOT") || Path.expand("../crosswake", File.cwd!())

    [
      {"MIX_ENV", "test"},
      {"MIX_DEPS_PATH", Path.join(dependency_root, "deps")},
      {"MIX_BUILD_PATH", Path.join(dependency_root, "_build/test")}
    ]
  end

  defp verify_chimeway_bundle(sha) do
    bundle = bundle(sha)

    destination =
      Path.join(
        System.tmp_dir!(),
        "chimeway-physical-bundle-#{System.unique_integer([:positive])}"
      )

    try do
      with {:ok, artifact} <- build_artifact!(),
           artifact_sha256 <- sha256!(artifact),
           {:ok, _} <- validate_built_artifact!(artifact, artifact_sha256),
           bundle <-
             put_in(bundle, ["chimeway_envelope", "chimeway_artifact_sha256"], artifact_sha256),
           bundle <- Map.put(bundle, "bundle_sha256", PhysicalBundle.bundle_digest(bundle)),
           {:ok, _} <- PhysicalBundle.validate(bundle, selected_sha: sha),
           :ok <- PhysicalBundle.publish(bundle, destination, selected_sha: sha),
           {:error, %{rule_id: "PP-PUBLICATION-COLLISION"}} <-
             PhysicalBundle.publish(bundle, destination, selected_sha: sha) do
        :ok
      else
        _ -> :error
      end
    after
      File.rm_rf(destination)
      cleanup_artifact()
    end
  end

  defp bundle(sha) do
    envelope = %{
      "schema_version" => 1,
      "owner" => "chimeway",
      "chimeway_artifact_sha256" => String.duplicate("a", 64),
      "crosswake_remote" => @remote,
      "crosswake_sha" => sha,
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
    }

    %{
      "bundle_version" => 1,
      "owner" => "chimeway",
      "proof_class" => "physical",
      "chimeway_envelope" => envelope,
      "crosswake_record" => %{
        "schema_version" => 1,
        "owner" => "crosswake",
        "crosswake_sha" => sha,
        "evidence_sha256" => envelope["crosswake_evidence_sha256"],
        "completion_marker_sha256" => envelope["crosswake_completion_marker_sha256"],
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
        "run_ref" => envelope["run_ref"],
        "machine_envelope_sha256" => String.duplicate("d", 64),
        "observed_at" => "2026-08-26T12:01:00Z",
        "attester_ref" => "attester-opaque",
        "state" => "observed"
      },
      "completion_marker" => %{
        "schema_version" => 1,
        "owner" => "chimeway",
        "run_ref" => envelope["run_ref"],
        "machine_envelope_sha256" => String.duplicate("d", 64),
        "state" => "validated"
      }
    }
  end

  defp build_artifact! do
    output =
      Path.join(
        System.tmp_dir!(),
        "chimeway-physical-proof-#{System.unique_integer([:positive])}"
      )

    archive = Path.join(output, "chimeway.tar")
    :ok = File.mkdir_p(output)
    Process.put({__MODULE__, :artifact}, archive)

    case System.cmd("mix", ["hex.build", "--output", archive],
           stderr_to_stdout: true,
           env: [{"MIX_ENV", "prod"}]
         ) do
      {_, 0} -> {:ok, archive}
      _ -> :error
    end
  end

  defp validate_built_artifact!(archive, digest) do
    Code.require_file(Path.expand("../../../priv/adoption_proof/artifact_archive.ex", __DIR__))

    apply(Chimeway.AdoptionProof.ArtifactArchive, :with_validated_archive, [
      archive,
      digest,
      fn _ -> :ok end
    ])
  end

  defp sha256!(path),
    do: path |> File.read!() |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)

  defp cleanup_artifact do
    case Process.delete({__MODULE__, :artifact}) do
      nil -> :ok
      archive -> File.rm_rf(Path.dirname(archive))
    end
  end

  defp cleanup_checkout do
    case Process.delete({__MODULE__, :checkout}) do
      nil -> :ok
      root -> File.rm_rf(root)
    end
  end
end
