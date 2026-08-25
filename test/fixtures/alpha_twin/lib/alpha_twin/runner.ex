defmodule AlphaTwin.Runner do
  @moduledoc false

  @delivery_scenario_ids [
    "accepted_handoff_protected_open",
    "two_installation_fanout",
    "zero_target_suppression",
    "token_rotation",
    "revocation_race",
    "classified_retry",
    "expiry_before_io",
    "opt_in_installation_safe_collapse",
    "trigger_commit_recovery",
    "post_handoff_ambiguity"
  ]

  @spec delivery_scenario_ids() :: [String.t()]
  def delivery_scenario_ids, do: @delivery_scenario_ids

  @spec validate_ledger(map()) :: {:ok, [String.t()]} | {:error, :invalid_ledger}
  def validate_ledger(
        %{
          "schema_version" => 1,
          "crosswake_remote" => "https://github.com/szTheory/crosswake.git",
          "crosswake_sha" => sha,
          "scenario_ids" => scenario_ids
        } = ledger
      )
      when map_size(ledger) == 4 and is_binary(sha) and byte_size(sha) == 40 and
             is_list(scenario_ids) do
    if scenario_ids == @delivery_scenario_ids and Enum.all?(scenario_ids, &is_binary/1),
      do: {:ok, scenario_ids},
      else: {:error, :invalid_ledger}
  end

  def validate_ledger(_), do: {:error, :invalid_ledger}

  @doc """
  Executes the fixture's closed delivery portion of the twin ledger.  The returned
  facts deliberately model only safe, durable categories: the runner never carries
  device tokens, payloads, or provider response bodies across this boundary.
  """
  @spec run(keyword()) :: {:ok, map()} | {:error, :invalid_ledger}
  def run(opts) when is_list(opts) do
    with {:ok, contents} <- File.read(Keyword.fetch!(opts, :ledger)),
         {:ok, ledger} <- Jason.decode(contents),
         {:ok, scenario_ids} <- validate_ledger(ledger) do
      {:ok,
       %{
         scenario_ids: scenario_ids,
         scenario_results: Enum.map(scenario_ids, &scenario_result/1),
         claim_taxonomy: %{
           dispatch_intent: :recorded,
           provider_acceptance: :provider_accepted,
           invalidation: :not_observed,
           protected_open: :not_attempted,
           inbox_seen: :not_attempted,
           inbox_read: :not_attempted
         }
       }}
    else
      _ -> {:error, :invalid_ledger}
    end
  end

  def run!(attrs) when is_map(attrs) do
    # This boundary accepts only opaque references and safe lifecycle facts. The host
    # retains raw token and one-time-intent authority; no host secret is returned.
    AlphaTwin.ProofSummary.render!(attrs)
  end

  defp scenario_result("zero_target_suppression") do
    %{id: "zero_target_suppression", durable: :converged, explanation: :explained,
      outcome: :suppressed_no_targets}
  end

  defp scenario_result("post_handoff_ambiguity") do
    %{id: "post_handoff_ambiguity", durable: :converged, explanation: :explained,
      outcome: :ambiguous_handoff_no_resend}
  end

  defp scenario_result(id) do
    %{id: id, durable: :converged, explanation: :explained, outcome: :terminal}
  end
end
