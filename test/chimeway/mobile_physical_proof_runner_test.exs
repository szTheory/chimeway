defmodule Chimeway.MobilePhysicalProofRunnerTest do
  use ExUnit.Case, async: false

  alias Mix.Tasks.Chimeway.MobilePhysicalProof

  test "preflight emits stable ordered rule IDs without authority values or local paths" do
    result = MobilePhysicalProof.preflight_result()

    assert result.schema_version == 1
    assert result.threshold == "physical_support"
    assert result.outcome in ["blocked", "unavailable", "ready"]
    assert Enum.map(result.checks, & &1.rule_id) == MobilePhysicalProof.preflight_rule_ids()
    assert Enum.all?(result.checks, &(&1.outcome in ["passed", "blocked", "unavailable"]))

    encoded = Jason.encode!(result)
    refute encoded =~ "crosswake-selected-sha"
    refute encoded =~ File.cwd!()
    refute encoded =~ "65dd9f42e218261015823e28045c507db1884cf3"
  end

  test "visible alert input is explicit and limited to the D-13 choices" do
    assert MobilePhysicalProof.alert_question() ==
             "Did the expected Chimeway alert appear on the selected iPhone?"

    assert MobilePhysicalProof.alert_state("Observed") == {:ok, "observed"}
    assert MobilePhysicalProof.alert_state("Did not appear") == {:ok, "not_observed"}
    assert MobilePhysicalProof.alert_state("Cannot verify") == {:ok, "unavailable"}

    assert MobilePhysicalProof.alert_state(nil) == :error
    assert MobilePhysicalProof.alert_state("observed") == :error
    assert MobilePhysicalProof.alert_state("It appeared") == :error
  end

  test "preflight CLI produces bounded JSON without creating proof evidence" do
    output =
      ExUnit.CaptureIO.capture_io(fn ->
        MobilePhysicalProof.run(["--preflight", "--json"])
      end)

    assert %{"schema_version" => 1, "checks" => checks} = Jason.decode!(output)
    assert Enum.map(checks, & &1["rule_id"]) == MobilePhysicalProof.preflight_rule_ids()
  end
end
