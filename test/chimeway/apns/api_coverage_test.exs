defmodule Chimeway.APNS.APICoverageTest do
  use ExUnit.Case, async: true

  @coverage ".planning/phases/100-optional-apns-adapter/COVERAGE.md"

  test "every external capability has one supported disposition and opt-outs explain why" do
    rows = coverage_rows(File.read!(@coverage))
    assert rows != []

    for {capability, disposition, reason} <- rows do
      assert disposition in ["INTEGRATE", "OPT-OUT"], "#{capability} has an invalid disposition"

      if disposition == "OPT-OUT",
        do: assert(String.trim(reason) != "", "#{capability} needs a reason")
    end
  end

  test "the APNs verification alias includes all focused contracts and consumer proof" do
    mix_exs = File.read!("mix.exs")
    assert mix_exs =~ ~s("verify.apns")

    for required <- [
          "api_coverage_test.exs",
          "request_test.exs",
          "result_test.exs",
          "safe_evidence_test.exs",
          "migration_contract_test.exs",
          "bash scripts/verify-apns.sh"
        ] do
      assert mix_exs =~ required
    end
  end

  defp coverage_rows(markdown) do
    markdown
    |> String.split("\n")
    |> Enum.filter(&String.starts_with?(&1, "| "))
    |> Enum.map(&String.split(&1, "|", trim: true))
    |> Enum.filter(&(length(&1) == 3))
    |> Enum.map(fn [capability, disposition, reason] ->
      {String.trim(capability), String.trim(disposition), String.trim(reason)}
    end)
    |> Enum.reject(fn {_capability, disposition, _reason} ->
      String.downcase(disposition) in ["disposition", "---"]
    end)
  end
end
