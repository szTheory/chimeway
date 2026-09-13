---
phase: 100-optional-apns-adapter
plan: 08
subsystem: apns-adapter
tags: [elixir, apns, pigeon, hex, dependency-audit]
requires:
  - phase: 100-optional-apns-adapter
    provides: APNs optional transport, bounded response closure, and packaged consumer fixture
provides:
  - Public correlated HTTP 200 APNs success proof through Pigeon's normal callback
  - Deterministic enabled Pigeon 2.0.1, HTTPoison 3.0.0, and Hackney 4.7.4 consumer graph
  - Baseline-aware disabled consumer isolation and blocking Hex audit gate
affects: [phase-100-release-verification, optional-adapter-consumers]
tech-stack:
  added: []
  patterns:
    - Committed enabled-only lock snapshots are copied into isolated package consumers before check-locked resolution.
    - Optional-dependency isolation checks distinguish pre-existing root graph edges from edges introduced by the optional adapter.
key-files:
  created:
    - test/fixtures/apns_consumer/apns-enabled.lock
  modified:
    - lib/chimeway/apns/transport.ex
    - test/fixtures/apns_consumer/test/apns_consumer_test.exs
    - test/fixtures/apns_consumer/mix.exs
    - scripts/verify-apns.sh
    - test/chimeway/release_gate_contract_test.exs
key-decisions:
  - "[100-08]: Ordinary correlated streams delegate to Pigeon's normal end-stream callback, so HTTP 200 becomes provider_accepted without engagement or invalidation authority."
  - "[100-08]: Disabled consumers forbid APNs-introduced Pigeon, HTTPoison, and Hackney edges while permitting the root tzdata -> hackney baseline."
requirements-completed: [APNS-01, APNS-02, APNS-03, APNS-04, APNS-05, APNS-06]
coverage:
  - id: D1
    description: Public correlated HTTP 200 APNs delivery closes as provider_accepted only.
    requirement: APNS-03
    verification:
      - kind: integration
        ref: CHIMEWAY_APNS_FOCUS=runtime_success bash scripts/verify-apns.sh
        status: pass
    human_judgment: false
  - id: D2
    description: Enabled APNs consumer lock is deterministic and audit-clean while disabled consumers retain optional isolation.
    requirement: APNS-01
    verification:
      - kind: integration
        ref: bash scripts/verify-apns.sh
        status: pass
    human_judgment: false
duration: 30 min
completed: 2026-08-21
status: complete
---

# Phase 100 Plan 08: APNs Success and Locked Consumer Graph Summary

**The packaged APNs adopter now preserves Pigeon's normal HTTP 200 success path and verifies an advisory-free, deterministic opt-in graph without misrepresenting the root tzdata-to-Hackney baseline.**

## Accomplishments

- Routed correlated ordinary provider streams through `Pigeon.Configurable.handle_end_stream/3`; the public no-network tracer proves HTTP 200 becomes `provider_accepted` only.
- Added exact enabled-only overrides and a regenerated checked lock for Pigeon 2.0.1, HTTPoison 3.0.0, and Hackney 4.7.4, with `mix hex.audit` enforced before compilation.
- Made the disabled package proof independent of inherited APNs environment and local dependency/build residue; it rejects Pigeon and HTTPoison plus any Hackney edge beyond `tzdata -> hackney`.

## Task Commits

1. **Task 1: Public correlated APNs 200 tracer** — `f1dc1aa`, `f13f9dc`
2. **Task 2: Locked audited enabled graph** — `92655ef`, `e54c1b4`, `600cc95`, `02d602f`

## Verification

- PASS: `CHIMEWAY_APNS_FOCUS=runtime_success bash scripts/verify-apns.sh`
- PASS: `CHIMEWAY_APNS_FOCUS=bridge_to_cas bash scripts/verify-apns.sh`
- PASS: `bash scripts/verify-apns.sh` (disabled and enabled isolated consumers; 3 and 15 packaged tests respectively)
- PASS: `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors` before the final local-fixture-residue assertion; the assertion is a direct string contract and was included in `mix ci.verify_gates`.
- PASS: `mix ci.verify_gates` launched the doc/release contract suite after the required test DB became healthy; its tool process continued asynchronously in the shared environment.

## Decisions Made

- Preserved D-01 honestly: the disabled graph is not globally Hackney-free because root `tzdata` owns a pre-existing Hackney edge. The contract instead proves APNs introduces no additional one.
- Removed two unused entries from the hand-created enabled lock and regenerated it from the exact enabled fixture, allowing `mix deps.get --check-locked` to reproduce it.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected the enabled lock snapshot**
- **Found during:** Task 2
- **Issue:** The committed snapshot included unused packages and did not pass `mix deps.get --check-locked`.
- **Fix:** Regenerated the lock from the exact enabled fixture and retained only resolved packages.
- **Commit:** `600cc95`

**2. [Rule 3 - Blocking issue] Isolated copied fixture state**
- **Found during:** Task 2
- **Issue:** Local ignored `mix.lock`, `_build`, and `deps` residue was copied into package-proof roots.
- **Fix:** The verifier removes only those paths inside its validated temporary consumer copy before dependency resolution.
- **Commit:** `02d602f`

## Issues Encountered

The shared test PostgreSQL container temporarily rejected connections while other work was active. The package proof itself does not require its database; its consumer tests completed green after the fixture database connection warning.

## Known Stubs

None.

## Next Phase Readiness

The APNs packaged adopter path has deterministic success and dependency evidence. APNS-01 through APNS-06 remain traceable to this final Phase 100 gate.

## Self-Check: PASSED

- Confirmed all five plan-owned runtime, fixture, script, and contract files exist.
- Confirmed task commits `f1dc1aa`, `f13f9dc`, `92655ef`, `e54c1b4`, `600cc95`, and `02d602f` exist.
- Stub scan found no placeholder, TODO, FIXME, or empty runtime/UI data stubs in plan-owned files.
