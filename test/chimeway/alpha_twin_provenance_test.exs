defmodule Chimeway.AlphaTwinProvenanceTest do
  use ExUnit.Case, async: true

  Code.require_file("scripts/prove-alpha-twin.exs")

  test "proof line binds the exact artifact digest and CrossWake SHA" do
    digest = String.duplicate("a", 64)
    sha = "f2c502cdb1ce572a4a57257d9e3c051665704b90"

    assert Chimeway.AlphaTwinProofRunner.proof_line!(%{
             archive_digest: digest,
             crosswake_remote: "https://github.com/szTheory/crosswake.git",
             crosswake_sha: sha,
             scenario_id: "accepted_handoff_protected_open",
             activation: :authorized,
             explanation: :accepted
           }) =~ "archive_sha256=#{digest} crosswake_sha=#{sha}"
  end

  test "proof line rejects mutable provenance" do
    assert_raise ArgumentError, fn ->
      Chimeway.AlphaTwinProofRunner.proof_line!(%{
        archive_digest: String.duplicate("a", 64),
        crosswake_remote: "main",
        crosswake_sha: "f2c502cdb1ce572a4a57257d9e3c051665704b90",
        scenario_id: "accepted_handoff_protected_open",
        activation: :authorized,
        explanation: :accepted
      })
    end
  end
end
