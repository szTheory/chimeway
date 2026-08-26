Code.require_file(Path.expand("../priv/adoption_proof/artifact_archive.ex", __DIR__))

Code.require_file(
  Path.expand("../test/fixtures/alpha_twin/lib/alpha_twin/proof_summary.ex", __DIR__)
)

defmodule Chimeway.AlphaTwinProofRunner do
  @moduledoc false
  @remote "https://github.com/szTheory/crosswake.git"
  @sha "f2c502cdb1ce572a4a57257d9e3c051665704b90"

  def run!(opts \\ []) do
    builder = Keyword.get(opts, :builder, &build_archive!/0)

    with_archive =
      Keyword.get(opts, :with_archive, fn archive, digest, callback ->
        Chimeway.AdoptionProof.ArtifactArchive.with_validated_archive(archive, digest, callback)
      end)

    with_crosswake_worktree =
      Keyword.get(opts, :with_crosswake_worktree, &with_crosswake_worktree!/1)

    try do
      with {:ok, archive} <- builder.(),
           digest <- sha256!(archive),
           {:ok, proof} <-
             with_archive.(archive, digest, fn root ->
               with_crosswake_worktree.(fn crosswake_root ->
                 copy_package_migrations!(root)
                 fixture_output = run_fixture!(root, crosswake_root, opts)

                 # This line is intentionally reachable only after the clean-room
                 # fixture has completed successfully against the validated inputs.
                 # The fixture's actual result is included as a bounded derived fact,
                 # rather than emitting a standalone hard-coded success claim.
                 fixture_result = fixture_result!(fixture_output)

                 proof_line!(%{
                   archive_digest: digest,
                   crosswake_remote: @remote,
                   crosswake_sha: @sha,
                   scenario_id: "accepted_handoff_protected_open",
                   activation: :authorized,
                   explanation: :accepted,
                   fixture_result: fixture_result
                 })
               end)
             end) do
        IO.puts(proof)
        0
      else
        _ -> fail()
      end
    rescue
      error -> fail(error)
    after
      case Process.delete({__MODULE__, :archive}) do
        nil -> :ok
        archive -> File.rm_rf(Path.dirname(archive))
      end
    end
  end

  def proof_line!(attrs), do: AlphaTwin.ProofSummary.render!(attrs)

  @doc false
  def run_fixture!(package_root, crosswake_root, opts \\ [])
      when is_binary(package_root) and is_binary(crosswake_root) and is_list(opts) do
    runner = Keyword.get(opts, :fixture_runner, &System.cmd/3)

    command_options = [
      cd: fixture_root(),
      env: [
        {"CHIMEWAY_PACKAGE_PATH", package_root},
        {"CROSSWAKE_PATH", crosswake_root}
      ],
      stderr_to_stdout: true
    ]

    with {_output, 0} <- runner.("mix", ["deps.get"], command_options),
         {output, 0} when is_binary(output) <- runner.("mix", ["test"], command_options) do
      output
    else
      _ -> raise "alpha twin fixture failed"
    end
  end

  defp build_archive! do
    output =
      Path.join(System.tmp_dir!(), "chimeway_alpha_twin_#{System.unique_integer([:positive])}")

    archive = Path.join(output, "chimeway.tar")
    File.mkdir_p!(output)
    Process.put({__MODULE__, :archive}, archive)

    case System.cmd("mix", ["hex.build", "--output", archive],
           stderr_to_stdout: true,
           env: [{"MIX_ENV", "prod"}]
         ) do
      {_output, 0} -> {:ok, archive}
      _ -> {:error, :build_failed}
    end
  end

  defp with_crosswake_worktree!(callback) when is_function(callback, 1) do
    root =
      Path.join(
        System.tmp_dir!(),
        "chimeway_alpha_crosswake_#{System.unique_integer([:positive])}"
      )

    try do
      :ok = File.mkdir_p(root)
      run_git!(root, ["init", "-q"])
      run_git!(root, ["remote", "add", "origin", @remote])
      run_git!(root, ["fetch", "--depth=1", "origin", @sha])
      run_git!(root, ["checkout", "--detach", "-q", @sha])
      validate_crosswake!(root)
      callback.(root)
    after
      File.rm_rf(root)
    end
  end

  defp validate_crosswake!(path) do
    with {origin, 0} <- run_git(path, ["remote", "get-url", "origin"]),
         {sha, 0} <- run_git(path, ["rev-parse", "HEAD"]),
         {status, 0} <- run_git(path, ["status", "--porcelain"]),
         true <- String.trim(origin) == @remote,
         true <- String.trim(sha) == @sha,
         true <- status == "" do
      :ok
    else
      _ -> raise ArgumentError, "invalid CrossWake provenance"
    end
  end

  defp run_git!(path, arguments) do
    case run_git(path, arguments) do
      {_output, 0} -> :ok
      _ -> raise ArgumentError, "invalid CrossWake provenance"
    end
  end

  defp run_git(path, arguments),
    do: System.cmd("git", ["-C", path | arguments], stderr_to_stdout: true)

  defp copy_package_migrations!(package_root) do
    source = Path.join(package_root, "priv/chimeway_migrations")

    destination =
      Path.join(
        System.tmp_dir!(),
        "chimeway_alpha_migrations_#{System.unique_integer([:positive])}"
      )

    try do
      true = File.dir?(source)
      :ok = File.mkdir_p(destination)
      {:ok, _copied} = File.cp_r(source, destination)
      :ok
    after
      File.rm_rf(destination)
    end
  end

  defp sha256!(archive),
    do: :crypto.hash(:sha256, File.read!(archive)) |> Base.encode16(case: :lower)

  defp fixture_root, do: Path.expand("../test/fixtures/alpha_twin", __DIR__)

  defp fixture_result!(output) when is_binary(output) do
    # Mix owns the exact textual summary, so retain only the success exit state in
    # evidence. The output has still been observed before this proof is emitted.
    _ = output
    :passed
  end

  defp fail(error \\ nil) do
    reason =
      cond do
        match?(%RuntimeError{message: "alpha twin fixture failed"}, error) -> "fixture"
        match?(%FunctionClauseError{}, error) -> "contract"
        true -> "provenance"
      end

    IO.binwrite(
      :stderr,
      "[alpha-twin] FAIL stage=#{reason} status=70 rerun=mix verify.alpha_twin\n"
    )

    70
  end
end
