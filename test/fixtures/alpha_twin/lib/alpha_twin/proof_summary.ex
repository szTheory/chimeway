defmodule AlphaTwin.ProofSummary do
  @moduledoc false

  @remote "https://github.com/szTheory/crosswake.git"
  @scenario "accepted_handoff_protected_open"
  @proof_keys ~w(schema_version proof_class chimeway_artifact_sha256 crosswake_sha scenario_results claim_taxonomy)
  @taxonomy_keys ~w(provider_acceptance protected_open inbox_seen inbox_read)

  @doc "Returns a canonical, closed proof or a non-echoing safe failure."
  @spec render(map()) :: {:ok, binary()} | {:error, %{rule: atom(), path: [String.t()]}}
  def render(attrs) when is_map(attrs) do
    case sensitive_path(attrs) do
      nil -> validate_and_encode(attrs)
      path -> {:error, %{rule: :sensitive_value, path: path}}
    end
  end

  def render(_), do: {:error, %{rule: :invalid_schema, path: []}}

  def render!(%{
        archive_digest: digest,
        crosswake_remote: @remote,
        crosswake_sha: sha,
        scenario_id: @scenario,
        activation: :authorized,
        explanation: :accepted,
        fixture_result: :passed
      })
      when is_binary(digest) and byte_size(digest) == 64 and is_binary(sha) and
             byte_size(sha) == 40 do
    unless String.match?(digest, ~r/\A[0-9a-f]{64}\z/) and
             String.match?(sha, ~r/\A[0-9a-f]{40}\z/),
           do: raise(ArgumentError, "invalid CrossWake provenance")

    "CHIMEWAY_ALPHA_TWIN_PROOF schema=1 scenario=#{@scenario} archive_sha256=#{digest} " <>
      "crosswake_sha=#{sha} fixture=passed delivery=provider_accepted activation=authorized"
  end

  def render!(_), do: raise(ArgumentError, "invalid CrossWake provenance")

  defp validate_and_encode(attrs) do
    with true <- Map.keys(attrs) |> Enum.sort() == Enum.sort(@proof_keys),
         1 <- attrs["schema_version"],
         "alpha_twin" <- attrs["proof_class"],
         true <- digest?(attrs["chimeway_artifact_sha256"], 64),
         true <- digest?(attrs["crosswake_sha"], 40),
         true <- valid_results?(attrs["scenario_results"]),
         true <- valid_taxonomy?(attrs["claim_taxonomy"]) do
      {:ok, Jason.encode!(attrs)}
    else
      _ -> {:error, %{rule: :invalid_schema, path: []}}
    end
  end

  defp valid_results?(results) when is_list(results) do
    Enum.all?(results, fn
      %{"id" => id, "outcome" => outcome} = result
      when map_size(result) == 2 and is_binary(id) and is_binary(outcome) ->
        true

      _ ->
        false
    end)
  end

  defp valid_results?(_), do: false

  defp valid_taxonomy?(taxonomy) when is_map(taxonomy) do
    Map.keys(taxonomy) |> Enum.sort() == Enum.sort(@taxonomy_keys) and
      Enum.all?(taxonomy, fn {key, value} -> key in @taxonomy_keys and is_binary(value) end)
  end

  defp valid_taxonomy?(_), do: false

  defp digest?(value, length) when is_binary(value) and byte_size(value) == length,
    do: String.match?(value, ~r/\A[0-9a-f]+\z/)

  defp digest?(_, _), do: false

  defp sensitive_path(value), do: sensitive_path(value, [])

  defp sensitive_path(value, path) when is_map(value) do
    Enum.find_value(value, fn {key, nested} ->
      sensitive_path(nested, path ++ [to_string(key)])
    end)
  end

  defp sensitive_path(value, path) when is_list(value) do
    Enum.with_index(value)
    |> Enum.find_value(fn {nested, index} ->
      sensitive_path(nested, path ++ [Integer.to_string(index)])
    end)
  end

  defp sensitive_path(value, path) when is_binary(value) do
    if String.contains?(value, [
         "raw-token",
         "credential",
         "provider-body",
         "https://",
         "payload",
         "actor:"
       ]), do: path
  end

  defp sensitive_path(_, _), do: nil
end
