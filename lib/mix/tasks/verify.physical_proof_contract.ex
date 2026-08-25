defmodule Mix.Tasks.Verify.PhysicalProofContract do
  @moduledoc false
  use Mix.Task
  alias Chimeway.MobileProof.Extension

  @shortdoc "Validate the closed Alpha physical-proof fixture corpus"
  @root "test/fixtures/alpha_twin_physical_proof"

  @impl Mix.Task
  def run([]) do
    load_crosswake!()
    valid = read!("valid.json")
    corpus = read!("negative-corpus.json")
    validator = &apply(Crosswake.ProofLane.PhysicalIphoneContract, :validate_report, [&1])

    with {:ok, _} <- Extension.validate(valid, canonical_validator: validator),
         :ok <- verify_cases(corpus, validator) do
      Mix.shell().info("physical proof contract OK")
    else
      _ -> exit({:shutdown, 70})
    end
  end
  def run(_), do: exit({:shutdown, 64})

  defp verify_cases(%{"cases" => cases}, validator) when is_list(cases) and length(cases) == 9 do
    ids = Enum.map(cases, &Map.get(&1, "id"))
    if ids == ~w(version owner proof_class artifact_digest crosswake_sha contract scenario_order assertion_order sensitive) do
      Enum.reduce_while(cases, :ok, fn %{"proof" => proof, "rule_id" => rule_id, "path" => path}, :ok ->
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
  defp load_crosswake! do
    root = System.get_env("CROSSWAKE_PATH") || Path.expand("../crosswake", File.cwd!())
    Code.require_file(Path.join(root, "lib/crosswake/proof_lane/physical_iphone_contract.ex"))
  end
end
