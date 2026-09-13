defmodule Chimeway.PhysicalProofContractRunnerTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Verify.PhysicalProofContract

  setup do
    root =
      Path.join(
        System.tmp_dir!(),
        "chimeway-physical-contract-runner-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(Path.join(root, "lib/crosswake/proof_lane"))
    File.mkdir_p!(Path.join(root, "test/fixtures/proof_lane"))
    File.mkdir_p!(Path.join(root, "test/crosswake/proof_lane"))

    File.write!(
      Path.join(root, "lib/crosswake/proof_lane/chimeway_notification_physical_proof.ex"),
      """
      defmodule Crosswake.ProofLane.ChimewayNotificationPhysicalProof do
        def schema_version, do: 1
        def assertions, do: []
        def validate_report(report), do: report
        def validate_source_bound(source), do: Evidence.check(source)
      end
      """
    )

    File.write!(
      Path.join(root, "test/fixtures/proof_lane/chimeway-notification-physical-proof.json"),
      "{}"
    )

    File.write!(
      Path.join(root, "test/crosswake/proof_lane/chimeway_notification_physical_proof_test.exs"),
      "validate_source_bound"
    )

    git!(root, ["init", "-q"])
    git!(root, ["add", "."])

    git!(root, [
      "-c",
      "user.name=Chimeway Test",
      "-c",
      "user.email=chimeway-test@example.invalid",
      "commit",
      "-q",
      "-m",
      "fixture"
    ])

    sha = git!(root, ["rev-parse", "HEAD"])

    on_exit(fn -> File.rm_rf(root) end)

    {:ok, root: root, sha: sha}
  end

  test "fetches the locked graph before running the detached contract test", %{
    root: root,
    sha: sha
  } do
    owner = self()

    runner = fn "mix", arguments, options ->
      send(owner, {:mix_command, arguments, options})
      {"", 0}
    end

    assert :ok = PhysicalProofContract.verify_checkout(root, sha, runner: runner)

    assert_receive {:mix_command, ["deps.get", "--check-locked"], dependency_options}

    assert_receive {:mix_command,
                    [
                      "test",
                      "test/crosswake/proof_lane/chimeway_notification_physical_proof_test.exs",
                      "--max-failures",
                      "1"
                    ], test_options}

    assert dependency_options == test_options
    assert dependency_options[:cd] == root
    assert dependency_options[:stderr_to_stdout]
    assert {"MIX_ENV", "test"} in dependency_options[:env]

    assert {"MIX_DEPS_PATH", deps_path} =
             List.keyfind(dependency_options[:env], "MIX_DEPS_PATH", 0)

    assert {"MIX_BUILD_PATH", build_path} =
             List.keyfind(dependency_options[:env], "MIX_BUILD_PATH", 0)

    refute inside?(deps_path, root)
    refute inside?(build_path, root)
  end

  test "fails closed on lock resolution failure without running the contract test", %{
    root: root,
    sha: sha
  } do
    runner = fn
      "mix", ["deps.get", "--check-locked"], _options -> {"lock drift", 1}
      "mix", ["test" | _arguments], _options -> flunk("test must not run after lock failure")
    end

    assert :error = PhysicalProofContract.verify_checkout(root, sha, runner: runner)
  end

  defp git!(root, arguments) do
    case System.cmd("git", arguments, cd: root, stderr_to_stdout: true) do
      {output, 0} -> String.trim(output)
      {output, status} -> flunk("git exited #{status}: #{output}")
    end
  end

  defp inside?(path, root) do
    expanded_path = Path.expand(path)
    expanded_root = Path.expand(root)
    expanded_path == expanded_root or String.starts_with?(expanded_path, expanded_root <> "/")
  end
end
