defmodule AlphaTwin.ProofSummary do
  @moduledoc false

  @remote "https://github.com/szTheory/crosswake.git"
  @scenario "accepted_handoff_protected_open"

  def render!(%{
        archive_digest: digest,
        crosswake_remote: @remote,
        crosswake_sha: sha,
        scenario_id: @scenario,
        activation: :authorized,
        explanation: :accepted
      })
      when is_binary(digest) and byte_size(digest) == 64 and is_binary(sha) and
             byte_size(sha) == 40 do
    unless String.match?(digest, ~r/\A[0-9a-f]{64}\z/) and
             String.match?(sha, ~r/\A[0-9a-f]{40}\z/),
           do: raise(ArgumentError, "invalid CrossWake provenance")

    "CHIMEWAY_ALPHA_TWIN_PROOF schema=1 scenario=#{@scenario} archive_sha256=#{digest} " <>
      "crosswake_sha=#{sha} delivery=provider_accepted activation=authorized"
  end

  def render!(_), do: raise(ArgumentError, "invalid CrossWake provenance")
end
