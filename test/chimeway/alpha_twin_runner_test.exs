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

  test "refuses proof emission when any actual evidence source or final bytes are unsafe" do
    Code.require_file(@fixture_path)
    Code.require_file(@proof_path)

    attrs = %{
      archive_digest: String.duplicate("a", 64),
      crosswake_remote: "https://github.com/szTheory/crosswake.git",
      crosswake_sha: "f2c502cdb1ce572a4a57257d9e3c051665704b90",
      scenario_id: "accepted_handoff_protected_open",
      activation: :authorized,
      explanation: :accepted,
      fixture_result: :passed
    }

    safe_sources = %{
      "storage" => [%{"status" => "succeeded"}],
      "traces" => [%{"outcome" => "provider_accepted"}],
      "telemetry" => [%{"event" => "dispatch.stop"}],
      "exceptions" => [],
      "observations" => [%{"provider_status" => 200}],
      "final_bytes" => "pending_outer_proof"
    }

    assert apply(Chimeway.AlphaTwinProofRunner, :proof_line!, [attrs, safe_sources]) =~
             "CHIMEWAY_ALPHA_TWIN_PROOF"

    for {source, unsafe} <- [
          {"storage", %{"device_token" => "ordinary-device-value"}},
          {"traces", %{"identity" => "ordinary-user-value"}},
          {"telemetry", %{"redirect_url" => "custom://private"}},
          {"exceptions", %{"payload" => "private content"}},
          {"observations", %{"credential" => "signing material"}}
        ] do
      assert_raise ArgumentError, "unsafe Alpha twin evidence", fn ->
        sources = Map.put(safe_sources, source, unsafe)
        apply(Chimeway.AlphaTwinProofRunner, :proof_line!, [attrs, sources])
      end
    end

    assert_raise ArgumentError, "unsafe Alpha twin evidence", fn ->
      apply(Chimeway.AlphaTwinProofRunner, :scan_proof!, [
        "CHIMEWAY_ALPHA_TWIN_PROOF raw-provider-body-private",
        safe_sources
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
          database_url:
            "postgres://ci_user:ci-secret@localhost:5432/chimeway_test?sslmode=disable",
          fixture_runner: fn "mix", command, options ->
            assert Path.basename(options[:cd]) == "fixture"
            assert File.regular?(Path.join(options[:cd], "mix.exs"))

            assert {"CHIMEWAY_PACKAGE_PATH", "/validated/package"} in options[:env]
            assert {"CROSSWAKE_PATH", "/detached/crosswake"} in options[:env]

            assert {"CHIMEWAY_ALPHA_TWIN_LEDGER",
                    "/validated/package/priv/alpha_twin/scenario-ledger.json"} in options[:env]

            assert {"DATABASE_URL", database_url} = List.keyfind(options[:env], "DATABASE_URL", 0)

            assert %URI{
                     scheme: "postgres",
                     userinfo: "ci_user:ci-secret",
                     host: "localhost",
                     port: 5432,
                     path: "/chimeway_alpha_twin_" <> unique,
                     query: "sslmode=disable"
                   } = URI.parse(database_url)

            assert unique != ""

            case command do
              ["deps.get", "--check-locked"] ->
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

  test "derives the fixture database from the configured connection without changing options" do
    Code.require_file(@fixture_path)
    Code.require_file(@proof_path)

    database_url =
      apply(Chimeway.AlphaTwinProofRunner, :fixture_database_url!, [
        "postgresql://ci_user:ci-secret@[::1]:5433/chimeway_test?sslmode=require&pool_size=5",
        42
      ])

    assert %URI{
             scheme: "postgresql",
             userinfo: "ci_user:ci-secret",
             host: "::1",
             port: 5433,
             path: "/chimeway_alpha_twin_42",
             query: "sslmode=require&pool_size=5"
           } = URI.parse(database_url)
  end

  test "uses the local test database fallback only when no database URL is configured" do
    Code.require_file(@fixture_path)
    Code.require_file(@proof_path)

    database_url =
      apply(Chimeway.AlphaTwinProofRunner, :fixture_database_url!, [nil, 42])

    assert database_url ==
             "postgres://postgres:postgres@127.0.0.1:55432/chimeway_alpha_twin_42"
  end

  test "rejects malformed database URLs without exposing their contents" do
    Code.require_file(@fixture_path)
    Code.require_file(@proof_path)

    for database_url <- [
          "not-a-database-url",
          "postgres://ci_user:do-not-leak@/chimeway_test",
          "postgres://ci_user:do-not-leak@localhost:not-a-port/chimeway_test",
          "https://ci_user:do-not-leak@localhost/chimeway_test"
        ] do
      error =
        assert_raise ArgumentError, fn ->
          apply(Chimeway.AlphaTwinProofRunner, :fixture_database_url!, [database_url, 42])
        end

      assert Exception.message(error) == "invalid Alpha twin database URL"
      refute Exception.message(error) =~ "ci_user"
      refute Exception.message(error) =~ "do-not-leak"
    end
  end

  test "a malformed configured database URL aborts before running fixture commands" do
    Code.require_file(@fixture_path)
    Code.require_file(@proof_path)

    error =
      assert_raise ArgumentError, fn ->
        apply(Chimeway.AlphaTwinProofRunner, :run_fixture!, [
          "/validated/package",
          "/detached/crosswake",
          [
            database_url: "postgres://ci_user:do-not-leak@/chimeway_test",
            fixture_runner: fn _command, _arguments, _options ->
              flunk("an invalid database URL must fail before fixture execution")
            end
          ]
        ])
      end

    assert Exception.message(error) == "invalid Alpha twin database URL"
    refute Exception.message(error) =~ "ci_user"
    refute Exception.message(error) =~ "do-not-leak"
  end

  test "an unlocked dependency graph aborts before migrations or fixture execution" do
    Code.require_file(@fixture_path)
    Code.require_file(@proof_path)

    assert_raise RuntimeError, "alpha twin fixture failed", fn ->
      apply(Chimeway.AlphaTwinProofRunner, :run_fixture!, [
        "/validated/package",
        "/detached/crosswake",
        [
          fixture_runner: fn "mix", command, _options ->
            case command do
              ["deps.get", "--check-locked"] -> {"lockfile changed", 1}
              ["ecto.drop", "-r", "Chimeway.Repo", "--quiet"] -> {"not created", 1}
              later -> flunk("dependency failure must stop before #{inspect(later)}")
            end
          end
        ]
      ])
    end
  end
end
