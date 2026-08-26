---
phase: 102-alpha-digital-twin-hermetic-gate
verified: 2026-08-26T16:28:00Z
status: passed
score: 3/3 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 2/3
  gaps_closed:
    - "Scenario outcomes are now produced from actual Chimeway durable lifecycle, recovery, transport, registry, and CrossWake resolver seams."
    - "Actual persisted, trace, telemetry, exception, and redacted-observation evidence is collected, scanned, serialized, parsed, re-scanned with the exact candidate proof bytes, and required before proof emission."
  gaps_remaining: []
  regressions: []
---

# Phase 102: Alpha Digital Twin & Hermetic Gate Verification Report

**Phase Goal:** The full host, Chimeway, and CrossWake mobile path is reproducible in CI without Apple credentials and rejects regressions in safety-critical behavior.
**Verified:** 2026-08-26T16:28:00Z
**Status:** passed
**Re-verification:** Yes — prior gaps closed

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | A sanitized Alpha host runs real Chimeway persistence with deterministic time, a host token registry, and a scripted fake APNs transport. | ✓ VERIFIED | The clean-room runner builds/validates a package archive, copies fixture source plus its lockfile, applies package migrations to a unique disposable PostgreSQL database, and runs public Chimeway trigger/trace APIs. The fixture registry retains raw token values, while `ScriptedAPNSTransport` implements the shipped APNs behaviour with redacted observations. |
| 2 | The hermetic proof demonstrates two-installation fan-out, suppression, rotation/revocation races, classified retry, expiry, collapse, crash recovery, recursive leak prevention, and denied/replayed offline opens. | ✓ VERIFIED | `AlphaTwin.Runner.execute_scenario/2` dispatches each ledger ID to real lifecycle operations. It verifies persisted target/attempt outcomes/counts and `Traces.explain_delivery/2`; special paths use registry CAS, blocked scripted transport, target recovery with explicit clock, and real pinned CrossWake resolver calls. The runner collects actual evidence from those operations and fails closed on its recursive scan. |
| 3 | Named `mix verify.*` entrypoints run the cross-repository proof in CI without Apple credentials and reject malformed physical-proof evidence. | ✓ VERIFIED | `mix verify.alpha_twin` passed and emitted a proof bound to a freshly built archive digest and exact CrossWake SHA. `mix verify.physical_proof_contract` passed. CI `verify_alpha_twin` uses PostgreSQL 15 and an exact detached, clean canonical CrossWake checkout; both aggregate gates require and propagate its result. |

**Score:** 3/3 roadmap must-haves verified

## Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `scripts/prove-alpha-twin.exs` | Immutable package/provenance/fixture/proof orchestration | ✓ VERIFIED | The runner requires fixture test success, reads the fixture-produced JSON evidence artifact, scans it, constructs the candidate proof, replaces `final_bytes` with that exact candidate, scans again, and only then calls `IO.puts/1`. |
| `test/fixtures/alpha_twin/lib/alpha_twin/runner.ex` | Ordered real scenario ledger and actual runtime evidence collection | ✓ VERIFIED | Each outcome is checked against public trigger/dispatch/recovery/trace/registry/CrossWake behavior; `collect_evidence_sources/0` reads persisted rows and trace projections, captures Chimeway telemetry, caught crash facts, and real redacted APNs observations. |
| `test/fixtures/alpha_twin/lib/alpha_twin/proof_summary.ex` | Closed recursive scanner | ✓ VERIFIED | Exact six-source schema is required. Recursive scanning rejects sensitive key names/suffixes and values without echoing them. |
| `test/chimeway/alpha_twin_runner_test.exs` | Emission-seam negative tests | ✓ VERIFIED | Tests fail proof emission for unsafe storage, traces, telemetry, exceptions, observations, and final candidate bytes. |
| `lib/mix/tasks/verify.physical_proof_contract.ex` | Credential-free malformed physical-proof gate | ✓ VERIFIED | Builds/validates a fresh archive, binds its SHA to the positive fixture, and rejects the ordered negative corpus. |
| `.github/workflows/ci.yml` | Required locked Alpha lane and aggregate links | ✓ VERIFIED | The lane validates canonical remote/exact SHA/detached clean checkout, runs both named gates without Apple credentials, and is propagated to `pr-gate` and `ci-gate`. |

## Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| Scenario ledger | Chimeway durable lifecycle/explanation | `execute_scenario/2` and `durable_delivery/3` | ✓ WIRED | Results require actual deliveries, targets, attempts, statuses, and `Traces.explain_delivery/2` projections. |
| Crash recovery | `TargetRecovery.recover_tenant/2` | post-commit crash then explicit `now:` recovery | ✓ WIRED | Fixture checks resumed planning and no duplicate recovery; production recovery-clock forwarding has its focused regression test. |
| Open safety scenarios | CrossWake resolver | host registry → `Resolver.resolve/3` | ✓ WIRED | Tests require one activation, stale denial without fallback, and replay denial. |
| Actual evidence sources | outer proof emission | fixture JSON artifact → parse/scan → candidate-byte scan | ✓ WIRED | `run_fixture!/3` rejects missing/unsafe artifact data; `proof_line!/2` calls `scan_proof!/2`, which injects the exact candidate into `final_bytes` before output. |
| `verify_alpha_twin` lane | `pr-gate` and `ci-gate` | `needs`, `VERIFY_ALPHA_TWIN`, aggregate script | ✓ WIRED | Both aggregate job blocks include the lane, result environment key, and `aggregate-gate.sh` input. |

## Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Lifecycle scenarios | delivery/target/attempt outcomes | Chimeway public APIs and PostgreSQL | Yes | ✓ FLOWING |
| Trace evidence | delivery explanations | `Chimeway.Traces.explain_delivery/2` for actual persisted delivery IDs | Yes | ✓ FLOWING |
| Telemetry/errors/observations | captured event/caught-crash/redacted request facts | attached Chimeway telemetry, crash handler, scripted transport messages | Yes | ✓ FLOWING |
| Final proof bytes | candidate proof string | `ProofSummary.render!/1` then `scan_proof!/2` | Yes; exact candidate re-scanned | ✓ FLOWING |

## Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Exact CrossWake commit is publicly reachable | isolated `git fetch --depth=1 https://github.com/szTheory/crosswake.git f2c502cdb1ce572a4a57257d9e3c051665704b90` | `FETCH_HEAD` exactly matched `f2c502cdb1ce572a4a57257d9e3c051665704b90` | ✓ PASS |
| Clean-room Alpha proof | `mix verify.alpha_twin` | Passed; emitted one provenance-bound Alpha proof line with a fresh archive SHA and locked CrossWake SHA | ✓ PASS |
| Physical-proof contract | `mix verify.physical_proof_contract` | Exit 0; `physical proof contract OK` | ✓ PASS |
| Evidence/emission mutation coverage | `test/chimeway/alpha_twin_runner_test.exs` source inspection | Tests unsafe values in each actual source category and unsafe final proof bytes; each must raise before emission | ✓ PASS |

## Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| TWIN-01 | 102-01, 102-02, 102-04 | Sanitized real host with persistence, deterministic seams, registry, scripted APNs | ✓ SATISFIED | Immutable clean-room package host, copied migrations/real persistence, host-private registry, and real APNs transport behaviour. |
| TWIN-02 | 102-01, 102-02, 102-03, 102-04 | Complete hermetic delivery/recovery/privacy/open matrix | ✓ SATISFIED | Real scenario execution with durable and resolver assertions; runtime evidence scan is complete and bound to emission. |
| GATE-01 | 102-04 | Named credential-free CI entrypoints and physical-proof evidence contract | ✓ SATISFIED | Independently passing named gates, exact SHA/provenance checks, malformed corpus validation, and required CI aggregation. |

## Anti-Patterns Found

None in Phase 102 implementation files. No unresolved `TBD`, `FIXME`, or `XXX` markers were found.

---

_Verified: 2026-08-26T16:28:00Z_
_Verifier: the agent (gsd-verifier)_
