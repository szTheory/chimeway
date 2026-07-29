---
phase: 87-ci-observability-cache-diagnostics
plan: 02
subsystem: infra
tags: [github-actions, ci, bash, elixir, exunit, observability]

requires:
  - phase: 87-ci-observability-cache-diagnostics
    provides: 87-01 obs-recompile.sh/obs-summary.sh machinery + lint lane wiring pattern
provides:
  - "All 14 build lanes in .github/workflows/ci.yml instrumented end-to-end: stable cache id:(s), an obs-recompile.sh probe replacing the compile hidden inside ecto.create, and a trailing if: always() obs-summary.sh step."
  - "@build_lanes parametrized contract test coverage in test/chimeway/ci_observability_contract_test.exs asserting the wiring shape across all 14 lanes."
affects: [87-03-plan (OBS-04 live baseline evidence run against the fully-instrumented fleet)]

tech-stack:
  added: []
  patterns:
    - "Special-lane handling: verify_accrue's pre-existing `mix deps.compile` step is replaced in place (not appended) by obs-recompile.sh so the ACCRUE_PATH deps-compile-order comment and behavior are preserved."
    - "verify_sigra's probe runs after `mix deps.get` and before the named 'Prepare root test database' step, since this lane has no bare `mix ecto.create --quiet` step to anchor on."
    - "Multi-cache lanes (verify_inbox: 3, verify_admin: 4 incl. pre-existing id: playwright-cache) pass one CACHE_<ID>_HIT/MATCHED/PRIMARY env triple per cache id — obs-summary.sh discovers them generically via compgen -e, so no script change was needed."
    - "install_golden_contract's trailing summary step is gated `if: always() && steps.detect.outputs.run == 'true'` (not bare always()) so it never renders a false summary when the PR-only detect gate skips the lane body."

key-files:
  created: []
  modified:
    - .github/workflows/ci.yml
    - test/chimeway/ci_observability_contract_test.exs

key-decisions:
  - "[87-02]: verify_accrue's obs-recompile.sh step replaces (not supplements) the prior `mix deps.compile` step — one compile probe per lane, same explanatory comment kept above it."
  - "[87-02]: @build_lanes mirrors release_gate_contract_test.exs's @ci_gate_lanes exactly (14 lanes incl. lint) rather than defining a new list, keeping the two contract tests' lane vocabularies in lockstep."
  - "[87-02]: The --warnings-as-errors absence assertion checks the full per-lane job block (not just the recompile step) for maximum coverage — simpler and stronger than trying to scope the check to only the obs-recompile.sh line."

requirements-completed: [OBS-01, OBS-02, OBS-03]

coverage:
  - id: D1
    description: "Every one of the 14 build lanes gives each of its actions/cache steps a stable id: and carries a trailing if: always() observability summary step"
    requirement: "OBS-01"
    verification:
      - kind: unit
        ref: "test/chimeway/ci_observability_contract_test.exs#all build lanes carry cache id + trailing obs-summary (OBS-01/02/03 fan-out)"
        status: pass
    human_judgment: false
  - id: D2
    description: "The recompile probe replaces the compile hidden inside mix ecto.create with an explicit mix deps.compile + mix compile, so ecto.create becomes a fast DB op, across all 14 lanes"
    requirement: "OBS-02"
    verification:
      - kind: unit
        ref: "test/chimeway/ci_observability_contract_test.exs (obs-recompile.sh presence per lane) + manual grep -c 'scripts/ci/obs-recompile.sh' == 14"
        status: pass
    human_judgment: false
  - id: D3
    description: "Instrumentation never gates or materially slows real verify work — trailing summary steps are always if: always(), never a needs:/gate dependency; plain mix compile only, no --warnings-as-errors introduced"
    requirement: "OBS-03"
    verification:
      - kind: unit
        ref: "test/chimeway/ci_observability_contract_test.exs#no build-lane observability step introduces --warnings-as-errors"
        status: pass
    human_judgment: false
  - id: D4
    description: "install_golden_contract's observability steps mirror the lane's if: steps.detect.outputs.run == 'true' guard so they never run when the lane body is skipped"
    verification:
      - kind: unit
        ref: "test/chimeway/ci_observability_contract_test.exs#install_golden_contract obs-summary step also gates on steps.detect.outputs.run"
        status: pass
    human_judgment: false
  - id: D5
    description: "The test lane's two OTP matrix legs (26, 27) each write their own job summary without clobbering each other"
    verification:
      - kind: backstop
        ref: "Single job definition instrumented once; each matrix leg is a separate runner/job invocation with its own $GITHUB_STEP_SUMMARY, per GitHub Actions matrix semantics — same mechanism already proven correct for the pre-existing test lane's per-leg log isolation."
        status: pass
    human_judgment: true
    rationale: "Not directly provable offline (no live GitHub Actions matrix runner in this contract-test harness); accepted as a structural backstop consistent with documented GitHub Actions job-summary-per-job-instance behavior. A live push-to-main run (deferred to 87-03 / OBS-04) will show two independent step summaries, one per OTP leg."

duration: 9min
completed: 2026-07-29
status: complete
---

# Phase 87 Plan 02: Fan Observability to All 14 Build Lanes Summary

**All 14 CI build lanes (single-cache DB lanes, two-cache demo-host lanes, and five special/partner lanes) now render the cache/recompile/timing observability tables end-to-end, with the contract test asserting the wiring shape across the full fleet.**

## Performance

- **Duration:** 9 min
- **Started:** 2026-07-29T02:01:06Z
- **Completed:** 2026-07-29T02:07:56Z
- **Tasks:** 3
- **Files modified:** 2

## Accomplishments

- Instrumented the four single-cache DB lanes (`verify_gates`, `verify_docs`, `test`, `verify_runtime_prefix`) with `id: cache_main`, an `obs-recompile.sh` probe placed ahead of `mix ecto.create --quiet` (or `mix ci.docs` for the DB-less `verify_docs` lane), and a trailing `if: always()` `obs-summary.sh` step.
- Instrumented the four two-cache demo-host lanes (`verify_example`, `verify_journeys`, `verify_mailglass`, `verify_threadline`) with `id: cache_main` + `id: cache_demo` and a trailing summary step passing both cache-output triples, leaving the pre-existing JOUR-05 "Warm :dev build" steps untouched.
- Instrumented the five special lanes: `verify_accrue` (replaced its existing `mix deps.compile` step in place with the probe, `id: cache_main` + `id: cache_demo`), `verify_inbox` (three caches: `cache_main`, `cache_nested_inbox`, `cache_demo`), `verify_sigra` (probe placed between `mix deps.get` and the named "Prepare root test database" step, since this lane has no bare `ecto.create`), `verify_admin` (four caches incl. the pre-existing `id: playwright-cache`), and `install_golden_contract` (probe + summary both correctly guarded by the existing `steps.detect.outputs.run == 'true'` condition, summary as `if: always() && steps.detect.outputs.run == 'true'`).
- Extended `test/chimeway/ci_observability_contract_test.exs` with a `@build_lanes` module attribute (mirrors `release_gate_contract_test.exs`'s `@ci_gate_lanes`, 14 lanes) and three new test groups: a parametrized per-lane assertion (`id: cache_main`, `scripts/ci/obs-summary.sh`, `if: always()`), a focused `install_golden_contract` detect-guard assertion, and a fleet-wide `--warnings-as-errors` absence check. 27 tests total, 0 failures.

## Task Commits

Each task was committed atomically:

1. **Task 1: Instrument the single-cache DB lanes (verify_gates, verify_docs, test, verify_runtime_prefix)** - `226d07e` (feat)
2. **Task 2: Instrument the two-cache demo-host lanes (verify_example, verify_journeys, verify_mailglass, verify_threadline)** - `14d7662` (feat)
3. **Task 3: Instrument the special lanes (accrue, inbox, sigra, admin, install_golden_contract) and extend the contract test to all 14 build lanes** - `bf13e87` (feat)

## Files Created/Modified

- `.github/workflows/ci.yml` - All 14 build lanes now carry cache `id:`s, an `obs-recompile.sh` probe, and a trailing `if: always()` `obs-summary.sh` step (lint lane was already wired in Plan 01).
- `test/chimeway/ci_observability_contract_test.exs` - Added `@build_lanes` + 16 new tests (14 parametrized per-lane + 1 install_golden_contract guard + 1 fleet-wide `--warnings-as-errors` check); 27 tests total.

## Decisions Made

- Replaced (not supplemented) `verify_accrue`'s pre-existing `mix deps.compile` step with `obs-recompile.sh` — one compile probe per lane, keeping the original explanatory comment about compile ordering above it.
- `@build_lanes` mirrors `@ci_gate_lanes` from `release_gate_contract_test.exs` exactly (14 lanes including `lint`), keeping the two contract tests' lane vocabularies in lockstep rather than defining a divergent list.
- The `--warnings-as-errors` absence assertion checks each lane's entire job block, not just the `obs-recompile.sh` line — simpler to write correctly and strictly stronger coverage than a narrowly-scoped check.

## Verification

- PASS: `mix test test/chimeway/ci_observability_contract_test.exs` — 27 tests, 0 failures (includes all 14 `@build_lanes` parametrized assertions).
- PASS: `grep -c 'scripts/ci/obs-summary.sh' .github/workflows/ci.yml` → 14.
- PASS: `grep -c 'id: cache_main' .github/workflows/ci.yml` → 14.
- PASS: `grep -c 'warnings-as-errors' .github/workflows/ci.yml` → 0 (no `--warnings-as-errors` introduced anywhere).
- PASS: `mix ci.lint` — Credo clean, 197 source files, no issues.
- PASS: `mix format --check-formatted .github/workflows/ci.yml test/chimeway/ci_observability_contract_test.exs`.
- PASS: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))"` — valid YAML after every task's edits.

## Deviations from Plan

None - plan executed exactly as written. All five special-lane nuances (accrue replacement, inbox/admin multi-cache triples, sigra pre-ecto.create ordering, install_golden_contract detect-guard propagation) matched the plan's `<action>` instructions without requiring adjustment.

**Total deviations:** 0 auto-fixed.
**Impact on plan:** No scope change.

## Issues Encountered

- `mix test` produces known non-fatal `Threadline.Export.CleanupTask` `DBConnection.OwnershipError` log noise during the async test run (same class of noise documented in prior phase summaries, e.g. Phase 74 P03 and the STATE.md "verification-noise" deferred item) — does not affect the 27/27 pass count.

## Known Stubs

None. All 14 build lanes are real, production-quality CI wiring — no placeholder or stubbed observability steps.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for 87-03. All 14 build lanes are statically wired and offline-contract-proven; 87-03 can capture the OBS-04 live baseline evidence (a real push-to-main CI run showing all three tables rendered per lane, real `gh api` reachability, real cache hit/miss states, and the two `test` lane OTP matrix legs writing independent summaries) to close out Phase 87.

## Self-Check: PASSED

- `grep -c 'scripts/ci/obs-summary.sh' .github/workflows/ci.yml` → 14 (confirmed present).
- `grep -c 'id: cache_main' .github/workflows/ci.yml` → 14 (confirmed present).
- Found `test/chimeway/ci_observability_contract_test.exs` with `@build_lanes` (14 entries) and 27 total tests, 0 failures on `mix test test/chimeway/ci_observability_contract_test.exs`.
- Found task commits `226d07e`, `14d7662`, `bf13e87` in `git log --oneline`.
- No unexpected tracked-file deletions in any of the three task commits (`git diff --diff-filter=D` empty for all three).

---
*Phase: 87-ci-observability-cache-diagnostics*
*Completed: 2026-07-29*
