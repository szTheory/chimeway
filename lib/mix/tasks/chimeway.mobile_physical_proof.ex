defmodule Mix.Tasks.Chimeway.MobilePhysicalProof do
  @moduledoc false
  use Mix.Task

  @shortdoc "Run the bounded, fail-closed physical iPhone proof preflight"

  @alert_question "Did the expected Chimeway alert appear on the selected iPhone?"
  @alert_options %{
    "Observed" => "observed",
    "Did not appear" => "not_observed",
    "Cannot verify" => "unavailable"
  }

  @preflight_rule_ids [
    "PHYSICAL-AUTHORITY-SELECTED-REVISION",
    "PHYSICAL-CROSSWAKE-SOURCE-BOUND",
    "PHYSICAL-CROSSWAKE-PHASE-162",
    "PHYSICAL-CHIMEWAY-IMMUTABLE-ARTIFACT",
    "PHYSICAL-APPLE-SIGNING",
    "PHYSICAL-APNS-SANDBOX",
    "PHYSICAL-SELECTED-IPHONE",
    "PHYSICAL-HOST-ACTIVATION-AUTHORITY",
    "PHYSICAL-DESTINATION-FRESH"
  ]

  @impl Mix.Task
  def run(["--preflight", "--json"]), do: print(preflight_result())

  def run(["--verify-promoted", "--json"]), do: print(verify_promoted_result())

  def run(["--run", "--promote", "--json"]), do: promote()

  def run(_),
    do:
      Mix.raise(
        "expected --preflight --json, --run --promote --json, or --verify-promoted --json"
      )

  def preflight_rule_ids, do: @preflight_rule_ids

  def alert_question, do: @alert_question

  def preflight_result do
    checks = [
      check("PHYSICAL-AUTHORITY-SELECTED-REVISION", selected_revision?(), "blocked"),
      check("PHYSICAL-CROSSWAKE-SOURCE-BOUND", source_bound?(), "unavailable"),
      check(
        "PHYSICAL-CROSSWAKE-PHASE-162",
        env_ready?("CHIMEWAY_PHYSICAL_PROOF_CROSSWAKE_PHASE_162"),
        "unavailable"
      ),
      check(
        "PHYSICAL-CHIMEWAY-IMMUTABLE-ARTIFACT",
        env_ready?("CHIMEWAY_PHYSICAL_PROOF_ARTIFACT"),
        "unavailable"
      ),
      check(
        "PHYSICAL-APPLE-SIGNING",
        env_ready?("CHIMEWAY_PHYSICAL_PROOF_APPLE_SIGNING"),
        "unavailable"
      ),
      check(
        "PHYSICAL-APNS-SANDBOX",
        env_ready?("CHIMEWAY_PHYSICAL_PROOF_APNS_SANDBOX"),
        "unavailable"
      ),
      check(
        "PHYSICAL-SELECTED-IPHONE",
        env_ready?("CHIMEWAY_PHYSICAL_PROOF_SELECTED_IPHONE"),
        "unavailable"
      ),
      check(
        "PHYSICAL-HOST-ACTIVATION-AUTHORITY",
        env_ready?("CHIMEWAY_PHYSICAL_PROOF_HOST_ACTIVATION"),
        "unavailable"
      ),
      check(
        "PHYSICAL-DESTINATION-FRESH",
        env_ready?("CHIMEWAY_PHYSICAL_PROOF_DESTINATION"),
        "unavailable"
      )
    ]

    %{
      schema_version: 1,
      threshold: "physical_support",
      outcome: if(Enum.all?(checks, &(&1.outcome == "passed")), do: "ready", else: "blocked"),
      checks: checks
    }
  end

  def alert_state(value), do: Map.fetch(@alert_options, value) |> normalize_alert_state()

  defp promote do
    if System.get_env("CI") in ["true", "1"] do
      Mix.raise("physical proof promotion is unavailable in CI")
    end

    with "ready" <- preflight_result().outcome,
         {:ok, state} <- alert_state(System.get_env("CHIMEWAY_PHYSICAL_PROOF_ALERT_STATE")),
         "observed" <- state do
      Mix.raise("physical proof publication requires the CrossWake-owned signed-device command")
    else
      "not_observed" ->
        Mix.raise("visible alert was not observed; physical support remains pending")

      "unavailable" ->
        Mix.raise("visible alert cannot be inferred; physical support remains pending")

      _ ->
        Mix.raise("physical proof preflight is incomplete; physical support remains pending")
    end
  end

  defp verify_promoted_result do
    %{
      schema_version: 1,
      threshold: "physical_support",
      outcome: "unavailable",
      checks: [check("PHYSICAL-PROMOTED-BUNDLE", false, "unavailable")]
    }
  end

  defp check(rule_id, true, _blocked), do: %{rule_id: rule_id, outcome: "passed"}
  defp check(rule_id, false, outcome), do: %{rule_id: rule_id, outcome: outcome}

  defp selected_revision? do
    case File.read("priv/mobile_proof/crosswake-selected-sha") do
      {:ok, sha} -> Regex.match?(~r/\A[0-9a-f]{40}\s*\z/, sha)
      _ -> false
    end
  end

  defp source_bound?, do: env_ready?("CHIMEWAY_PHYSICAL_PROOF_SOURCE_BOUND")
  defp env_ready?(name), do: System.get_env(name) == "ready"
  defp normalize_alert_state({:ok, state}), do: {:ok, state}
  defp normalize_alert_state(:error), do: :error
  defp print(result), do: Mix.shell().info(Jason.encode!(result))
end
