#!/usr/bin/env elixir

Code.require_file(Path.expand("../priv/adoption_proof/artifact_archive.ex", __DIR__))

defmodule Chimeway.AccrueProofCLI do
  @usage 64
  @provenance 65
  @proof 66
  @fixture "priv/adoption_proof/artifact_consumer_fixture.ex"

  def run(argv) do
    argv = if List.first(argv) == "--", do: tl(argv), else: argv

    with {:ok, archive, digest} <- arguments(argv),
         {:ok, status} <-
           Chimeway.AdoptionProof.ArtifactArchive.with_validated_archive(
             archive,
             digest,
             fn root ->
               try do
                 Code.require_file(Path.join(root, @fixture))
                 opts = test_failure_opts()
                 proof = Chimeway.Test.ArtifactConsumerFixture.prove_accrue!(root, opts)
                 IO.puts(proof.output)
                 0
               rescue
                 _ -> diagnostic("proof failed", @proof)
               end
             end
           ) do
      status
    else
      {:usage, message} -> diagnostic(message, @usage)
      {:provenance, message} -> diagnostic(message, @provenance)
    end
  end

  defp arguments(["--artifact-archive", archive, "--sha256", digest]),
    do: validate_arguments(archive, digest)

  defp arguments(_),
    do: {:usage, "usage: --artifact-archive /absolute/chimeway.tar --sha256 lowercase-64-hex"}

  defp validate_arguments(archive, digest) do
    cond do
      Path.type(archive) != :absolute ->
        {:usage, "artifact archive must be an absolute regular file"}

      not File.regular?(archive) ->
        {:usage, "artifact archive must be an absolute regular file"}

      not Regex.match?(~r/\A[0-9a-f]{64}\z/, digest) ->
        {:usage, "sha256 must be lowercase hexadecimal"}

      true ->
        {:ok, Path.expand(archive), digest}
    end
  end

  defp test_failure_opts do
    case System.get_env("CHIMEWAY_ACCRUE_PROOF_TEST_FAILURE") do
      "before_commands" -> [fail_before_commands: true]
      "after_database" -> [fail_after_database: true]
      _ -> []
    end
  end

  defp diagnostic(message, status) do
    IO.binwrite(:stderr, "Accrue package proof: #{message}\n")
    status
  end
end

System.halt(Chimeway.AccrueProofCLI.run(System.argv()))
