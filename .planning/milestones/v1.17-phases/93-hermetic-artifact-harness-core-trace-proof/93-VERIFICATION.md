---
phase: 93-hermetic-artifact-harness-core-trace-proof
verified: 2026-08-09T02:24:26Z
status: passed
score: 5/5 must-haves verified
behavior_unverified: 0
overrides_applied: 0
---

# Phase 93: Hermetic Artifact Harness & Core Trace Proof Verification Report

**Phase Goal:** Prospective adopters can independently install an unpacked Chimeway artifact into a clean host and prove a core notification lifecycle through public explainability evidence.
**Verified:** 2026-08-09T02:24:26Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | An adopter can run the Core proof from a temporary clean consumer whose Chimeway dependency resolves from an unpacked built package artifact, not the repository source tree. | ✓ VERIFIED | The release-gate setup builds with `MIX_ENV=prod mix hex.build --unpack` and locates the actual root. `prove_core!/1` renders one path dependency, validates its expanded path equals that root and rejects the repository root before `deps.get`; its named provenance tests and the real consumer test passed. |
| 2 | The clean consumer can boot, create and migrate its own supported PostgreSQL database, and execute the documented Core command reproducibly. | ✓ VERIFIED | The fixture generates a unique owned database with `url: nil`, runs `deps.get`, default `chimeway.gen.migrations`, `ecto.create`, a `SELECT current_database()` probe, `ecto.migrate`, and normal `mix run priv/prove_core.exs`. The real generated-consumer test passed. The named teardown test also passed, proving the injected early-failure cleanup path. |
| 3 | The Core proof shows a notifier definition, public trigger, and durable delivery outcome with stable notification identity inputs visible in sanitized evidence. | ✓ VERIFIED | Generated `ArtifactConsumer.Notifiers.CoreTrace` fixes `notification_key` to `artifact_consumer.core_trace` and version to `1`; generated proof source invokes public `Chimeway.trigger/3` with fixed tenant and idempotency values, destructures exactly one delivery ID, and asserts public `:succeeded` status plus succeeded last attempt. The named end-to-end test passed. |
| 4 | The proof obtains and asserts the lifecycle explanation through a public Chimeway explainability API rather than private test helpers or database-only inspection. | ✓ VERIFIED | Generated `priv/prove_core.exs` contains exactly one `Chimeway.Traces.explain_delivery/1` call and no Repo, Ecto query, or private-helper lifecycle lookup. It validates the public ordered timeline, then emits only the six-field `CHIMEWAY_CORE_PROOF` evidence allowlist. The release-gate source/output contract checks passed. |
| 5 | The temporary consumer database and tree are removed after success and after setup or proof failure. | ✓ VERIFIED | `prove_core!/2` uses rescue/catch cleanup plus successful-result cleanup; `cleanup!/2` validates fixture ownership, drops only the generated `url: nil` database, and removes only the generated root in an `after` block. The named failure-injection test passed. |

**Score:** 5/5 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `test/support/artifact_consumer_fixture.ex` | Hermetic consumer lifecycle API and generated consumer sources | ✓ VERIFIED | 440 substantive lines; `prove_core!/2` orchestrates provenance validation, all consumer commands, safe proof parsing, and exact-target cleanup. It is called by the release-gate test. |
| `test/chimeway/release_gate_contract_test.exs` | Existing release-gate anchor exercises the Core artifact proof | ✓ VERIFIED | Module-wide `async: false`; the Core describe builds/unpacks once and its 120-second real-consumer test calls the fixture. The file is included in `ci.verify_gates`. |
| Generated `mix.exs` | Artifact-only Chimeway dependency and direct host dependencies | ✓ VERIFIED | Generated at runtime, then inspected before any subprocess: exactly one `:chimeway` path equal to the unpacked root; `ecto_sql`, `postgrex`, and `oban` are direct host dependencies. Real-consumer test executed it. |
| Generated `config/config.exs`, Repo, Application, notifier, and `priv/prove_core.exs` | Isolated PostgreSQL host and public Core proof | ✓ VERIFIED | Fixture renders all files, executes the complete host lifecycle, and returns parsed safe evidence after cleanup; end-to-end contract passed. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- |
| `build_unpacked_package!/0` / `unpacked_package_root!/1` | `ArtifactConsumerFixture.prove_core!/1` | Located unpacked root passed to fixture | ✓ WIRED | The Core test setup produces `%{root: unpacked_package_root!(output)}` and passes `root` directly to `prove_core!/1`. |
| Generated `mix.exs` | Unpacked artifact root | Validated sole `:chimeway` path dependency | ✓ WIRED | `validate_artifact_dependency!/3` runs before `run_mix!(root, ["deps.get"])`; exact-root, duplicate, and repository-root rejection tests pass. |
| Generated `config/config.exs` | `ArtifactConsumer.Repo` and unique PostgreSQL database | `url: nil`, generated database config, current-DB probe | ✓ WIRED | Generated Repo config is used by `ecto.create`, the explicit `SELECT current_database()` probe, and `ecto.migrate`; the real consumer path passed. |
| `Chimeway.trigger/3` result | `Chimeway.Traces.explain_delivery/1` | Sole public delivery-ID bridge | ✓ WIRED | Generated proof matches `[delivery_id] = result.trace.delivery_ids` and immediately calls the public explainability API; source contract rejects repository/database alternatives. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Generated `priv/prove_core.exs` | `delivery_id`, `explanation`, timeline and last attempt | Public `Chimeway.trigger/3` result followed by `Chimeway.Traces.explain_delivery/1` against the consumer-owned PostgreSQL lifecycle | Yes — the real unpacked-artifact consumer completed a delivery and parsed the returned public evidence | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Complete unpacked-artifact Core lifecycle | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs:988 --warnings-as-errors` | 1 test, 0 failures | ✓ PASS |
| Failure-path cleanup | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs:1211 --warnings-as-errors` | 1 test, 0 failures | ✓ PASS |
| Release-gate integration | `MIX_ENV=test mix ci.verify_gates` | 546 tests, 0 failures | ✓ PASS |

`mix ci.verify_gates` emitted pre-existing Threadline sandbox-ownership error logs during cleanup, but ExUnit completed successfully with 546 tests and 0 failures; they are outside the Phase 93 artifact fixture path.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- |
| PROOF-01 | 93-01 | Clean consumer installs Chimeway from an unpacked built artifact without root source-path dependency. | ✓ SATISFIED | Actual production artifact build/unpack, exact-path validation before consumer commands, and passing end-to-end test. |
| PROOF-02 | 93-01 | Fixture boots, migrates, and runs documented proof commands reproducibly with supported PostgreSQL. | ✓ SATISFIED | Unique generated DB, authoritative probe, default migration generator, migration, normal application boot, and passing real consumer test. |
| PROOF-03 | 93-01 | Adoption proof asserts lifecycle evidence through a public explainability API. | ✓ SATISFIED | One public `explain_delivery/1` call; source/output contracts reject database and private-helper evidence paths. |
| CORE-01 | 93-01 | Core path proves notifier definition through trigger, durable delivery outcome, and explainable trace in clean consumer fixture. | ✓ SATISFIED | Fixed notifier identity, public trigger inputs, Sync/Logger config, exactly one public delivery ID, succeeded attempt, and ordered public timeline. |

All requirements mapped to Phase 93 are declared by 93-01; no orphaned Phase 93 requirements were found.

### Prohibition Checks

| Prohibition | Status | Evidence |
| --- | --- | --- |
| Must not resolve `:chimeway` from repository source, DemoHost, or another source. | ✓ VERIFIED | Exact generated dependency validation precedes all commands; tests cover root and duplicate rejection. |
| Must not derive lifecycle assertions from direct DB inspection, private functions, or repository-only helpers. | ✓ VERIFIED | Generated proof source is contract-tested for exactly one public explanation call and forbidden Repo/query patterns. |
| Must not print sensitive payload, recipient, contact, provider, credential, URL, or full explanation data. | ✓ VERIFIED | Evidence is a fixed six-key sentinel allowlist; source/output contract rejects the listed sensitive strings. |
| Must not add Phase 96 selector, adoption alias, or dedicated CI lane. | ✓ VERIFIED | Phase implementation commits modify only the two test files; no production, Mix alias, workflow, or CI-lane change is present. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- |
| — | — | No `TBD`, `FIXME`, `XXX`, placeholder, empty implementation, or hardcoded-empty-data stub found in the Phase 93 implementation files. | — | None |

### Gaps Summary

No gaps found. The phase goal is achieved by executable, source-traced evidence rather than SUMMARY.md assertions.

---

_Verified: 2026-08-09T02:24:26Z_
_Verifier: the agent (gsd-verifier)_
