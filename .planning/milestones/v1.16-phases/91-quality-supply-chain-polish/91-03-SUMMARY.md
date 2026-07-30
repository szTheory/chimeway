---
phase: 91-quality-supply-chain-polish
plan: 03
subsystem: ci
tags: [github-actions, permissions, least-privilege, ci-release-skew, vacuous-pass-guard]

requires:
  - phase: 91-quality-supply-chain-polish
    provides: 91-01 .tool-versions version-file conversion (this plan layers permissions/run_floor on top)
  - phase: 90-pipeline-tiering
    provides: resolve_tiers tier-flag architecture + nightly-gate aggregate (run_floor mirrors run_nightly)

provides:
  - Top-level GITHUB_TOKEN least-privilege default (contents: read) in ci.yml
  - 15 obs-summary jobs escalated to { contents: read, actions: read }
  - resolve_tiers run_floor output driving test_floor_1_17 on push + nightly (off for PRs)
  - ci-gate genuinely gates on the Elixir 1.17 floor (test_floor_1_17 in needs/env/aggregate)

affects:
  - future-CI-permission-audits
  - future-supply-chain-hardening-phases (release.yml/publish-hex.yml least-privilege, explicitly deferred)

tech-stack:
  added: []
  patterns:
    - "Top-level permissions: contents: read + job-level escalation (job-level permissions REPLACES top-level, so contents: read is re-declared in every escalating job)"
    - "Structural PR-skip-as-pass: run_floor's condition is byte-for-byte identical to ci-gate's own run condition (github.event_name != 'pull_request'), so the floor is never 'skipped' when ci-gate evaluates TEST_FLOOR_1_17 — no softening of aggregate-gate.sh's skipped-as-fail contract"

key-files:
  created: []
  modified:
    - .github/workflows/ci.yml
    - test/chimeway/release_gate_contract_test.exs

key-decisions:
  - "[91-03]: Job-level permissions blocks always re-declare contents: read alongside actions: read (job-level permissions REPLACES, not merges with, the top-level default — Pitfall 3)"
  - "[91-03]: run_floor is true iff github.event_name != 'pull_request' — deliberately identical to ci-gate's `if: always() && github.event_name != 'pull_request'` so the floor's result is never `skipped` when ci-gate aggregates it (D-15, structural not softened)"
  - "[91-03]: ci-gate needs/env/aggregate-gate.sh arg list extended with test_floor_1_17/TEST_FLOOR_1_17 (13 -> 14 lanes); pr-gate, nightly-gate, aggregate-gate.sh, and release.yml left untouched (D-13/D-14)"
  - "[91-03]: Deviation (Rule 1) — updated release_gate_contract_test.exs's stale Phase-90 assertions (@ci_gate_lanes 13->14, test_floor_1_17's if: run_nightly->run_floor, 'ci-gate needs stays 13 lanes' -> 14) that would otherwise fail against the now-intentional new contract; added a resolve_tiers run_floor emission/output contract test"

patterns-established:
  - "Job-level permissions escalation pattern for any future job that needs `gh api` / actions-metadata access: always co-declare contents: read"
  - "Tier-flag-mirrors-gate-condition pattern for any future push-gated nightly-tier leg (reuse run_floor's structural PR-skip-as-pass shape rather than inline event checks)"

requirements-completed: [QUAL-03, QUAL-05]

duration: ~10 min
completed: 2026-07-30
status: complete
---

# Phase 91 Plan 03: Least-Privilege Permissions + 1.17 Floor Gating Summary

**Top-level `permissions: contents: read` in `ci.yml` with 15 obs-summary jobs escalating to `actions: read`, plus a new `run_floor` tier flag that makes the Elixir 1.17 floor leg run AND genuinely gate `ci-gate` on push (not just run silently on nightly).**

## Accomplishments

- Added a top-level `permissions: contents: read` block to `ci.yml` (after the shared `env:` block, before `jobs:`), giving every job a read-only `GITHUB_TOKEN` default.
- Escalated exactly the 15 jobs that invoke `scripts/ci/obs-summary.sh` (the `gh api .../jobs` CI-run timing query) to job-level `permissions: { contents: read, actions: read }`: `lint`, `verify_gates`, `verify_docs`, `test`, `verify_example`, `verify_runtime_prefix`, `verify_journeys`, `verify_mailglass`, `verify_accrue`, `verify_inbox`, `verify_threadline`, `verify_sigra`, `verify_admin`, `install_golden_contract`, `nightly_cold_build`. Every escalating job co-declares `contents: read` (job-level `permissions:` replaces, not merges with, the top-level default — Pitfall 3).
- Left the 5 non-obs jobs (`resolve_tiers`, `test_floor_1_17`, `pr-gate`, `ci-gate`, `nightly-gate`) with no job-level `permissions:` block — they inherit the read-only top-level default. Zero `write` scopes exist anywhere in the file (D-09).
- Added a `run_floor` output to `resolve_tiers`, emitted `true` iff `github.event_name != 'pull_request'` — identical to `ci-gate`'s own run condition (`always() && github.event_name != 'pull_request'`), so the floor's result is never `skipped` when `ci-gate` evaluates it.
- Broadened `test_floor_1_17`'s `if:` from `needs.resolve_tiers.outputs.run_nightly == 'true'` to `needs.resolve_tiers.outputs.run_floor == 'true'` — the floor now runs on push + nightly, off for PRs (D-14). Its pinned Elixir 1.17 / OTP 27 block and `test-floor-` cache namespace are untouched (D-03).
- Extended `ci-gate`: added `test_floor_1_17` to `needs:` (13 -> 14 lanes), `TEST_FLOOR_1_17: ${{ needs.test_floor_1_17.result }}` to `env:`, and `TEST_FLOOR_1_17` to the `scripts/ci/aggregate-gate.sh` arg list — a floor failure now blocks push CI (D-15).
- Left `pr-gate` (4 lanes, no floor reference), `nightly-gate` (already listed the floor), `scripts/ci/aggregate-gate.sh` (skipped-as-fail contract unmodified), and `release.yml` (Elixir 1.17 / OTP 27 pin unchanged) exactly as they were.

## Task Commits

Each task was committed atomically:

1. **Task 1: Least-privilege permissions (top-level + 15 obs jobs)** - `ec90ccc` (feat)
2. **Task 2: Wire the 1.17 floor to run AND gate on push (run_floor + ci-gate)** - `309203a` (feat) — includes the necessary `release_gate_contract_test.exs` fix (see Deviations)

## Files Created/Modified

- `.github/workflows/ci.yml` - top-level `permissions:`, 15 job-level escalations, `resolve_tiers` `run_floor` output, `test_floor_1_17` broadened `if:`, `ci-gate` needs/env/aggregate extension.
- `test/chimeway/release_gate_contract_test.exs` - updated stale Phase-90 contract assertions to match the now-intentional 14-lane `ci-gate` + `run_floor`-gated floor (see Deviations).

## Decisions Made

- Job-level `permissions:` blocks always co-declare `contents: read` — never rely on the top-level default surviving a job-level override (Pitfall 3, D-08).
- `run_floor`'s condition is byte-for-byte identical to `ci-gate`'s run condition rather than a looser or inline check — this is what makes the PR-skip-as-pass guarantee structural instead of relying on `aggregate-gate.sh` treating `skipped` as a pass (D-15, Pitfall 2 avoided).
- `ci-gate`'s needs/env/aggregate list grew to 14 lanes; `pr-gate`/`nightly-gate`/`aggregate-gate.sh`/`release.yml` were deliberately left untouched per D-13/D-14.

## Verification

- PASS (automated, Task 1): `awk` top-level-permissions-before-jobs check + `grep -c 'actions: read'` == 15 + `grep -c 'contents: read'` == 16.
- PASS (automated, Task 2): `run_floor:` present; `run_floor == 'true'` present; `ci-gate` block contains `test_floor_1_17` and `TEST_FLOOR_1_17`; `release.yml` still pins `elixir-version: "1.17"`.
- PASS: `pr-gate` job block contains zero references to `test_floor_1_17`/`TEST_FLOOR_1_17` (grep count 0).
- PASS: `git diff --stat` confirms `release.yml` and `scripts/ci/aggregate-gate.sh` are untouched by this plan.
- PASS: `actionlint .github/workflows/ci.yml` — exit code 0, no static YAML/expression errors.
- PASS: `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs test/chimeway/ci_observability_contract_test.exs --warnings-as-errors` — 143 tests, 0 failures.
- PASS: `MIX_ENV=test mix test --warnings-as-errors` (full local suite, real Postgres, no `CHIMEWAY_SKIP_OBAN`) — 1280 tests, 1 pre-existing failure (`sigra_auth_harness_test.exs` — requires the `SIGRA_PATH` sibling-repo checkout that only exists in CI; unrelated to this plan's files).
- PASS: `mix format --check-formatted test/chimeway/release_gate_contract_test.exs` after reformatting the new assertion.
- PENDING (backstop, CI-only — cannot be executed by the executor): a **push run** where `test_floor_1_17` executes and `ci-gate` lists it in `needs` and goes red if the floor fails. The structural argument (floor `if:` == ci-gate `if:`) guarantees this; a live run is the terminal proof (RESEARCH Open Question 2).
- PENDING (backstop, CI-only): a **PR run** where the floor is skipped (`run_floor=false`) and `pr-gate` is green with `ci-gate` not evaluated, plus every escalated job's obs-summary timing table still rendering under `actions: read` with no checkout failures (proving `contents: read` survived the job-level override on all 15 jobs).

## TDD Gate Compliance

Not applicable — both tasks are `tdd="false"` (CI-config-only, no library behavior).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Updated stale Phase-90 contract-test assertions that this plan intentionally supersedes**
- **Found during:** Task 2, running the local test suite before committing.
- **Issue:** `test/chimeway/release_gate_contract_test.exs` (written in Phase 90) hard-locked the *old* contract: `@ci_gate_lanes` had 13 entries and a test asserted `length(needs) == length(@ci_gate_lanes)`; a second test explicitly asserted `test_floor_1_17` was *excluded* from `ci-gate`'s needs (`"ci-gate needs stays 13 lanes and excludes the nightly jobs"`); a third asserted `test_floor_1_17`'s `if:` still read `run_nightly`. Task 2's plan-mandated change (extend `ci-gate` to 14 lanes including `test_floor_1_17`; broaden the floor's `if:` to `run_floor`) directly contradicts all three assertions, so `mix test` would go red for correctly implementing D-15 — the exact failure mode the plan's whole purpose is to prevent (a real CI signal, not a stale-test false negative).
- **Fix:** Updated `@ci_gate_lanes` to include `test_floor_1_17` (14 entries); renamed/updated the "ci-gate aggregates N required lanes" test to 14; renamed/updated "ci-gate needs stays 13 lanes..." to assert 14 lanes, that `test_floor_1_17` **is** included, and that `nightly-gate`/`nightly_cold_build`/`verify_admin` remain excluded; updated the floor's `if:` assertion from `run_nightly` to `run_floor`; added a new test asserting `resolve_tiers` emits `run_floor:` and that its bash step's `!= "pull_request"` branch structure is present (locking the D-15 vacuous-pass guard as an executable contract, not just a code comment).
- **Files modified:** `test/chimeway/release_gate_contract_test.exs`.
- **Commit:** `309203a` (bundled with the Task 2 `ci.yml` change — both are one logical, atomic unit: the behavior change and the contract that proves it).

None of the 46 failures seen in one earlier local run (`CHIMEWAY_SKIP_OBAN=1 mix test` over the *full* suite) were caused by this plan — `CHIMEWAY_SKIP_OBAN=1` is meant for narrowly-scoped test files and breaks unrelated Oban-dependent tests when applied to the whole suite; the real full-suite run (no `CHIMEWAY_SKIP_OBAN`, real Postgres) showed only the pre-existing, environment-gated Sigra sibling-checkout failure noted above.

**Total deviations:** 1 auto-fixed (Rule 1 — necessary test-contract update, bundled into the causing commit).
**Impact on plan:** No scope change to `ci.yml`'s edits (exactly as specified); the test-file update was outside the plan's declared `files_modified` but was required to keep the test suite truthfully green against the plan's own intended new contract.

## Issues Encountered

- `mix format --check-formatted` flagged the new multi-clause assertion added to `release_gate_contract_test.exs`; reformatted with `mix format` and re-verified.
- One earlier local test run using `CHIMEWAY_SKIP_OBAN=1 mix test` (no file scoping) produced 46 unrelated failures — this was an environment/invocation artifact (that flag is meant for specific test files), not a regression; the real full-suite run confirmed only the single pre-existing Sigra-sibling-checkout failure.

## Known Stubs

None. Stub-pattern scan of `.github/workflows/ci.yml` and the modified test file found no placeholder/TODO/FIXME content.

## User Setup Required

None — no external service configuration required. The two backstops below require a live push and a live PR run on GitHub-hosted runners, which the executor cannot trigger itself.

## Next Phase Readiness

QUAL-03 and QUAL-05 are both structurally complete and locally verified (automated grep checks, `actionlint`, and the full contract-test suite). The two backstops are pending live-CI verification:
1. A **push** to `main` (or a dispatch) where `ci-gate` shows `test_floor_1_17` in its job graph and goes green with `TEST_FLOOR_1_17: success`, or red if the floor fails.
2. A **PR** run where `test_floor_1_17` is skipped, `pr-gate` is green, `ci-gate` does not run, and the obs-summary timing table still renders in all 15 escalated jobs' step summaries (proving `actions: read` works and `contents: read` was preserved on every job-level override).

This closes Phase 91 (all three plans — 91-01 toolchain source of truth, 91-02 dependabot + mix_audit, 91-03 permissions + floor gating — are now committed). Recorded per the phase's `<critical_notes>` instruction: the backstops are pending live verification, not blocking plan completion.

## Self-Check: PASSED

- Found `.github/workflows/ci.yml` with top-level `permissions:`, 16 total `permissions:` blocks (1 top-level + 15 job-level), 15 `actions: read`, 16 `contents: read`, `run_floor:` output, `run_floor == 'true'` in `test_floor_1_17`'s `if:`, `test_floor_1_17`/`TEST_FLOOR_1_17` in `ci-gate`'s needs/env/aggregate call.
- Found commit `ec90ccc` (Task 1) and `309203a` (Task 2) in `git log --oneline`.
- `release.yml` still declares `elixir-version: "1.17"`; `scripts/ci/aggregate-gate.sh` and `pr-gate`'s job block are byte-unchanged/floor-reference-free.
- `actionlint .github/workflows/ci.yml` exits 0.
- `mix test test/chimeway/release_gate_contract_test.exs test/chimeway/ci_observability_contract_test.exs --warnings-as-errors` — 143 tests, 0 failures.
- No tracked file deletions were introduced by either task commit.

---
*Phase: 91-quality-supply-chain-polish*
*Completed: 2026-07-30*
