Code.require_file(Path.expand("../priv/adoption_proof/artifact_archive.ex", __DIR__))

defmodule Chimeway.AdoptionProofRunner do
  @moduledoc false

  @fixture "priv/adoption_proof/artifact_consumer_fixture.ex"
  @paths [:core, :mailglass, :accrue]

  @spec run!([:core | :mailglass | :accrue], keyword()) :: non_neg_integer()
  def run!(paths, opts \\ []) when is_list(paths) do
    builder = Keyword.get(opts, :builder, &build_archive!/0)

    with_archive =
      Keyword.get(opts, :with_archive, fn archive, digest, callback ->
        apply(Chimeway.AdoptionProof.ArtifactArchive, :with_validated_archive, [
          archive,
          digest,
          callback
        ])
      end)

    try do
      with {:ok, archive} <- builder.(),
           {:ok, result} <-
             with_archive.(archive, sha256!(archive), fn root -> run_paths!(paths, root, opts) end) do
        result
      else
        {:error, _} -> fail(:core, :unpack)
      end
    rescue
      _ -> fail(:core, :build)
    after
      case Process.delete({__MODULE__, :archive}) do
        nil -> :ok
        archive -> File.rm_rf(Path.dirname(archive))
      end
    end
  end

  defp run_paths!(paths, root, opts) do
    Enum.reduce_while(paths, 0, fn path, _status ->
      case run_path(path, root, opts) do
        0 -> {:cont, 0}
        status -> {:halt, status}
      end
    end)
  end

  defp run_path(path, root, opts) when path in @paths do
    IO.puts("[adoption:#{path}] START")

    try do
      proof = proof_function(path, opts).(root)
      validate_output!(path, proof.output)
      IO.puts(proof.output)
      IO.puts("[adoption:#{path}] PASS")
      0
    rescue
      _ -> fail(path, path)
    end
  end

  defp proof_function(path, opts) do
    case Keyword.get(opts, :proofs) do
      proofs when is_map(proofs) -> Map.fetch!(proofs, path)
      _ -> production_proof_function(path)
    end
  end

  defp production_proof_function(path) do
    fn root ->
      require_fixture!(root)

      case path do
        :core -> apply(Chimeway.Test.ArtifactConsumerFixture, :prove_core!, [root, []])
        :mailglass -> apply(Chimeway.Test.ArtifactConsumerFixture, :prove_mailglass!, [root, []])
        :accrue -> apply(Chimeway.Test.ArtifactConsumerFixture, :prove_accrue!, [root, []])
      end
    end
  end

  defp require_fixture!(root) do
    compiler_options = Code.compiler_options()
    Code.compiler_options(ignore_module_conflict: true)

    try do
      Code.require_file(Path.join(root, @fixture))
    after
      Code.compiler_options(compiler_options)
    end
  end

  defp validate_output!(path, output) when is_binary(output) do
    prefix = "CHIMEWAY_#{path |> Atom.to_string() |> String.upcase()}_PROOF "

    unless String.starts_with?(output, prefix) and output == String.trim(output) and
             length(String.split(output, "\n", trim: true)) == 1 do
      raise "invalid proof output"
    end

    case path do
      :core -> Chimeway.Test.ArtifactConsumerFixture.parse_evidence!(output)
      :mailglass -> Chimeway.Test.ArtifactConsumerFixture.parse_mailglass_evidence!(output)
      :accrue -> Chimeway.Test.ArtifactConsumerFixture.parse_accrue_evidence!(output)
    end
  end

  defp validate_output!(_, _), do: raise("invalid proof output")

  defp build_archive! do
    output =
      Path.join(System.tmp_dir!(), "chimeway_adoption_#{System.unique_integer([:positive])}")

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

  defp sha256!(archive),
    do: :crypto.hash(:sha256, File.read!(archive)) |> Base.encode16(case: :lower)

  defp fail(path, stage) do
    IO.binwrite(
      :stderr,
      "[adoption:#{path}] FAIL stage=#{stage} status=70 rerun=mix verify.adoption_paths --only #{path}\n"
    )

    70
  end
end
