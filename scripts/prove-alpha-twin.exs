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

    try do
      with {:ok, archive} <- builder.(),
           digest <- sha256!(archive),
           {:ok, proof} <-
             Chimeway.AdoptionProof.ArtifactArchive.with_validated_archive(
               archive,
               digest,
               fn root ->
                 with_crosswake_worktree!(fn _crosswake_root ->
                   copy_package_migrations!(root)

                   proof_line!(%{
                     archive_digest: digest,
                     crosswake_remote: @remote,
                     crosswake_sha: @sha,
                     scenario_id: "accepted_handoff_protected_open",
                     activation: :authorized,
                     explanation: :accepted
                   })
                 end)
               end
             ) do
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

  defp fail(error \\ nil) do
    reason = if match?(%FunctionClauseError{}, error), do: "contract", else: "provenance"

    IO.binwrite(
      :stderr,
      "[alpha-twin] FAIL stage=#{reason} status=70 rerun=mix verify.alpha_twin\n"
    )

    70
  end
end
