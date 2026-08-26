defmodule Chimeway.MobileProof.ExtensionTest do
  use ExUnit.Case, async: true

  alias Chimeway.MobileProof.Extension

  @fixture "test/fixtures/alpha_twin_physical_proof/valid.json"
  @fixture_sha256 "5b42dfd21f9159e94a678f8d021a61fb2e18f0cb9e7c521d529b1e101176f757"
  @corpus_sha256 "4831d203853c3c6ae5df796acfa2b06e98263c2b77f2de2e5cace20cd2552787"

  test "keeps the committed hermetic fixture and corpus byte-stable" do
    assert @fixture_sha256 == sha256(@fixture)

    assert @corpus_sha256 ==
             sha256("test/fixtures/alpha_twin_physical_proof/negative-corpus.json")
  end

  test "accepts the closed hermetic extension and preserves subjective alert honesty" do
    fixture = @fixture |> File.read!() |> Jason.decode!()

    assert {:ok, proof} = Extension.validate(fixture, canonical_validator: &valid_report/1)
    assert proof["subjective_observation"] == %{"visible_alert" => "not_asserted"}
  end

  test "rejects a mismatched artifact digest without echoing the rejected value" do
    fixture = @fixture |> File.read!() |> Jason.decode!()
    rejected = String.duplicate("a", 64)

    assert {:error, %{rule_id: "MP-ARTIFACT-DIGEST", path: ["chimeway_artifact_sha256"]}} =
             Extension.validate(Map.put(fixture, "chimeway_artifact_sha256", rejected),
               artifact_sha256: String.duplicate("b", 64),
               canonical_validator: &valid_report/1
             )
  end

  test "does not accept the placeholder fixture digest as a real artifact binding" do
    fixture = @fixture |> File.read!() |> Jason.decode!()

    assert {:error, %{rule_id: "MP-ARTIFACT-DIGEST", path: ["chimeway_artifact_sha256"]}} =
             Extension.validate(fixture,
               artifact_sha256: String.duplicate("b", 64),
               canonical_validator: &valid_report/1
             )
  end

  test "rejects reordered canonical assertions through the delegated validator" do
    fixture = @fixture |> File.read!() |> Jason.decode!()
    [first, second | rest] = fixture["crosswake_report"]
    reordered = %{fixture | "crosswake_report" => [second, first | rest]}

    assert {:error, %{rule_id: "MP-CROSSWAKE-ASSERTIONS-ORDER", path: ["crosswake_report"]}} =
             Extension.validate(reordered,
               canonical_validator: fn _ -> {:error, "PI-ASSERTIONS-ORDER"} end
             )
  end

  defp valid_report(_report), do: :ok

  defp sha256(path),
    do: path |> File.read!() |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)
end
