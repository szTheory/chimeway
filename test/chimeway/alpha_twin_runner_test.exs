defmodule Chimeway.AlphaTwinRunnerTest do
  use ExUnit.Case, async: true

  @moduletag :alpha_twin_tracer

  @proof_path Path.expand("../../scripts/prove-alpha-twin.exs", __DIR__)
  @fixture_path Path.expand("../fixtures/alpha_twin/lib/alpha_twin/proof_summary.ex", __DIR__)

  test "renders one bounded proof bound to immutable package and CrossWake provenance" do
    Code.require_file(@fixture_path)
    Code.require_file(@proof_path)

    proof =
      apply(Chimeway.AlphaTwinProofRunner, :proof_line!, [
        %{
          archive_digest: String.duplicate("a", 64),
          crosswake_remote: "https://github.com/szTheory/crosswake.git",
          crosswake_sha: "f2c502cdb1ce572a4a57257d9e3c051665704b90",
          scenario_id: "accepted_handoff_protected_open",
          activation: :authorized,
          explanation: :accepted
        }
      ])

    assert proof ==
             "CHIMEWAY_ALPHA_TWIN_PROOF schema=1 scenario=accepted_handoff_protected_open " <>
               "archive_sha256=#{String.duplicate("a", 64)} " <>
               "crosswake_sha=f2c502cdb1ce572a4a57257d9e3c051665704b90 " <>
               "delivery=provider_accepted activation=authorized"
  end

  test "rejects a mutable CrossWake provenance value without echoing it" do
    Code.require_file(@fixture_path)
    Code.require_file(@proof_path)

    assert_raise ArgumentError, "invalid CrossWake provenance", fn ->
      apply(Chimeway.AlphaTwinProofRunner, :proof_line!, [
        %{
          archive_digest: String.duplicate("a", 64),
          crosswake_remote: "https://example.invalid/private-token",
          crosswake_sha: "main",
          scenario_id: "accepted_handoff_protected_open",
          activation: :authorized,
          explanation: :accepted
        }
      ])
    end
  end
end
