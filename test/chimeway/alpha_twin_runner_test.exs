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
          explanation: :accepted,
          fixture_result: :passed
        }
      ])

    assert proof ==
             "CHIMEWAY_ALPHA_TWIN_PROOF schema=1 scenario=accepted_handoff_protected_open " <>
               "archive_sha256=#{String.duplicate("a", 64)} " <>
               "crosswake_sha=f2c502cdb1ce572a4a57257d9e3c051665704b90 " <>
               "fixture=passed delivery=provider_accepted activation=authorized"
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
          explanation: :accepted,
          fixture_result: :passed
        }
      ])
    end
  end

  test "a failed clean-room fixture command aborts the Alpha twin proof" do
    Code.require_file(@fixture_path)
    Code.require_file(@proof_path)

    assert_raise RuntimeError, "alpha twin fixture failed", fn ->
      apply(Chimeway.AlphaTwinProofRunner, :run_fixture!, [
        "/validated/package",
        "/detached/crosswake",
        [
          fixture_runner: fn "mix", command, options ->
            assert Path.basename(options[:cd]) == "fixture"
            assert File.regular?(Path.join(options[:cd], "mix.exs"))

            assert {"CHIMEWAY_PACKAGE_PATH", "/validated/package"} in options[:env]
            assert {"CROSSWAKE_PATH", "/detached/crosswake"} in options[:env]

            assert {"CHIMEWAY_ALPHA_TWIN_LEDGER",
                    "/validated/package/priv/alpha_twin/scenario-ledger.json"} in options[:env]

            assert {"DATABASE_URL", database_url} = List.keyfind(options[:env], "DATABASE_URL", 0)
            assert database_url =~ "/chimeway_alpha_twin_"

            case command do
              ["deps.get"] ->
                {"dependencies fetched", 0}

              ["chimeway.gen.migrations", "--prefix", "public"] ->
                {"migrations generated", 0}

              ["ecto.create", "-r", "Chimeway.Repo", "--quiet"] ->
                {"database created", 0}

              ["ecto.migrate", "-r", "Chimeway.Repo", "--quiet", "--migrations-path", _path] ->
                {"migrated", 0}

              ["test"] ->
                {"1 failure", 1}

              ["ecto.drop", "-r", "Chimeway.Repo", "--quiet"] ->
                {"database dropped", 0}
            end
          end
        ]
      ])
    end
  end
end
