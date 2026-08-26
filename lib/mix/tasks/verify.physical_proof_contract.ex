defmodule Mix.Tasks.Verify.PhysicalProofContract do
  @moduledoc false
  use Mix.Task
  alias Chimeway.MobileProof.Extension

  @shortdoc "Validate the closed Alpha physical-proof fixture corpus"
  @root "test/fixtures/alpha_twin_physical_proof"

  @impl Mix.Task
  def run([]) do
    load_crosswake!()
    corpus = read!("negative-corpus.json")
    validator = &apply(Crosswake.ProofLane.PhysicalIphoneContract, :validate_report, [&1])

    with {:ok, artifact} <- build_artifact!(),
         artifact_sha256 <- sha256!(artifact),
         {:ok, _} <- validate_built_artifact!(artifact, artifact_sha256),
         valid <- Map.put(read!("valid.json"), "chimeway_artifact_sha256", artifact_sha256),
         {:ok, _} <-
           Extension.validate(valid,
             artifact_sha256: artifact_sha256,
             canonical_validator: validator
           ),
         :ok <- verify_cases(corpus, validator) do
      Mix.shell().info("physical proof contract OK")
    else
      _ -> exit({:shutdown, 70})
    end
  after
    cleanup_artifact()
  end

  def run(_), do: exit({:shutdown, 64})

  defp verify_cases(%{"cases" => cases}, validator) when is_list(cases) and length(cases) == 9 do
    ids = Enum.map(cases, &Map.get(&1, "id"))

    if ids ==
         ~w(version owner proof_class artifact_digest crosswake_sha contract scenario_order assertion_order sensitive) do
      Enum.reduce_while(cases, :ok, fn %{"proof" => proof, "rule_id" => rule_id, "path" => path},
                                       :ok ->
        case Extension.validate(proof, canonical_validator: validator) do
          {:error, %{rule_id: ^rule_id, path: ^path}} -> {:cont, :ok}
          _ -> {:halt, :error}
        end
      end)
    else
      :error
    end
  end

  defp verify_cases(_, _), do: :error
  defp read!(file), do: @root |> Path.join(file) |> File.read!() |> Jason.decode!()

  defp build_artifact! do
    output =
      Path.join(
        System.tmp_dir!(),
        "chimeway_physical_proof_#{System.unique_integer([:positive])}"
      )

    archive = Path.join(output, "chimeway.tar")
    :ok = File.mkdir_p(output)
    Process.put({__MODULE__, :artifact}, archive)

    case System.cmd("mix", ["hex.build", "--output", archive],
           stderr_to_stdout: true,
           env: [{"MIX_ENV", "prod"}]
         ) do
      {_output, 0} -> {:ok, archive}
      _ -> {:error, :build_failed}
    end
  end

  defp validate_built_artifact!(archive, artifact_sha256) do
    Code.require_file(Path.expand("../../../priv/adoption_proof/artifact_archive.ex", __DIR__))

    apply(Chimeway.AdoptionProof.ArtifactArchive, :with_validated_archive, [
      archive,
      artifact_sha256,
      fn _package_root -> :ok end
    ])
  end

  defp sha256!(archive),
    do: :crypto.hash(:sha256, File.read!(archive)) |> Base.encode16(case: :lower)

  defp cleanup_artifact do
    case Process.delete({__MODULE__, :artifact}) do
      nil -> :ok
      archive -> File.rm_rf(Path.dirname(archive))
    end
  end

  defp load_crosswake! do
    root = System.get_env("CROSSWAKE_PATH") || Path.expand("../crosswake", File.cwd!())
    Code.require_file(Path.join(root, "lib/crosswake/proof_lane/physical_iphone_contract.ex"))
  end
end
