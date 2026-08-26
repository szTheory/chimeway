defmodule Chimeway.MobileProof.ExtensionTest do
  use ExUnit.Case, async: true

  alias Chimeway.MobileProof.Extension

  @fixture "test/fixtures/alpha_twin_physical_proof/valid.json"

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
end
