---
phase: 90-pipeline-tiering-pr-main-nightly
plan: 01
subsystem: ci
tags: [github-actions, ci, tiering, fromjson, concurrency, elixir]
requires: []
provides:
  - resolve_tiers setup job (bare, no checkout) emitting run_nightly + otp_matrix outputs
  - schedule cron "0 7 * * *" trigger on ci.yml
  - workflow_dispatch.inputs.run_nightly boolean (default false)
  - event-conditional test OTP matrix via fromJSON(needs.resolve_tiers.outputs.otp_matrix)
  - concurrency group keyed on github.event_name; PR-only cancel-in-progress
  - ExUnit contract backstop locking the new tiering shape
affects:
  - phase-90-02-verify-admin-nightly-gating
  - phase-90-03-nightly-cold-build-and-floor-jobs
  - phase-91-1-17-ci-leg (leans on nightly tier)
tech-stack:
  added: []
  patterns:
    - "Setup-job-driven conditional matrix: JSON-string job output consumed downstream via fromJSON()"
    - "Concurrency group keyed on github.event_name to isolate push vs schedule cancellation groups"
key-files:
  created:
    - .planning/phases/90-pipeline-tiering-pr-main-nightly/90-01-SUMMARY.md
  modified:
    - .github/workflows/ci.yml
    - test/chimeway/release_gate_contract_test.exs
decisions:
  - "[90-01]: resolve_tiers is a bare setup job (no checkout) emitting run_nightly + otp_matrix JSON outputs; test's OTP matrix consumes it via fromJSON — PR runs OTP 27 only, push/schedule/dispatch run 26+27."
  - "[90-01]: concurrency group keyed on github.event_name with cancel-in-progress scoped to pull_request only, so a push can never cancel an in-flight nightly run (Pitfall 2 / T-90-04)."
metrics:
  duration: 18 min
  completed: 2026-07-29
requirements-completed: [TIER-03]
status: complete
---

# Phase 90 Plan 01: resolve_tiers Setup Job + Event-Conditional OTP Matrix Summary

**Introduced the phase's tracer — a bare `resolve_tiers` setup job whose JSON `otp_matrix` output drives the `test` job's OTP matrix via `fromJSON()` (PR: OTP 27 only; push/schedule/dispatch: OTP 26+27) — plus the `schedule:` cron, `workflow_dispatch.inputs.run_nightly` boolean, and an event-name-keyed `concurrency` group so a push can never cancel an in-flight nightly run; proven live on a real GitHub-hosted `workflow_dispatch` run.**

## Performance

- **Duration:** ~18 min
- **Completed:** 2026-07-29
- **Tasks:** 2
- **Files modified:** 2 (plus this summary)

## Accomplishments

- Added `schedule: - cron: "0 7 * * *"` and a `workflow_dispatch.inputs.run_nightly` boolean input (default `false`) to `ci.yml`, with a runbook comment documenting `gh workflow run ci.yml --ref <branch> -f run_nightly=true` for on-demand nightly runs. The existing `push`/`pull_request` entries and `release.yml`'s bare-dispatch comment are unchanged.
- Fixed the `concurrency` block: `group:` now interpolates `github.event_name` (`${{ github.workflow }}-${{ github.event_name }}-${{ github.ref }}`) and `cancel-in-progress:` is scoped to `${{ github.event_name == 'pull_request' }}` — push and schedule runs on `main` no longer share a cancellation group (T-90-04 mitigation).
- Added the bare `resolve_tiers` job as the first job in `jobs:`, no `actions/checkout`, one `id: flags` bash step emitting `otp_matrix` (`["27"]` on `pull_request`, `["26","27"]` otherwise) and `run_nightly` (`"true"` on schedule or a `workflow_dispatch` with `run_nightly=true`).
- Wired the `test` job with `needs: [resolve_tiers]` and replaced the hardcoded `otp: ["26", "27"]` with `otp: ${{ fromJSON(needs.resolve_tiers.outputs.otp_matrix) }}`. All other `test` content (services, env, cache key, steps, `elixir: ["1.19"]`) untouched.
- Added a `describe "pipeline tiering contract (TIER-01..04, Phase 90)"` block to `release_gate_contract_test.exs` with four tests locking the schedule/dispatch-input shape, the concurrency fix, the bare `resolve_tiers` job + outputs, and the `fromJSON`-driven `test` matrix.

## Task Commits

Each task was committed atomically:

1. **Task 1: resolve_tiers setup job + event-conditional OTP matrix** — `76f4459` (feat)
2. **Task 2: Wave-0 contract-test backstop** — `e1bf7f8` (test)

## Verification

- PASS: `actionlint .github/workflows/ci.yml` — exit 0.
- PASS: `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs` — 82 tests, 0 failures (includes the unchanged pre-existing `"ci-gate aggregates 14 required lanes"` test — `verify_admin`'s trigger is untouched in this plan).
- PASS: `mix format --check-formatted` on the test file.
- PASS (LIVE): `gh workflow run ci.yml --ref main` dispatched run `30510307057` (event `workflow_dispatch`, headSha `76f4459`, no `-f` so `run_nightly` defaulted false). Overall conclusion `success`. Job "Resolve tier flags" = `success`. Exactly two `Test (` matrix legs — `Test (Elixir 1.19 / OTP 26)` and `Test (Elixir 1.19 / OTP 27)` — both `success`, proving `resolve_tiers.outputs.otp_matrix` correctly drives the `test` matrix on a non-`pull_request` event. Commit `76f4459` was pushed to `origin/main` (`b06d882..76f4459`) before the dispatch, so the run exercised the tracer as it exists on the pushed ref.

## Decisions Made

- resolve_tiers is a bare setup job (no checkout) emitting `run_nightly` + `otp_matrix` JSON outputs; `test`'s OTP matrix consumes it via `fromJSON` — PR runs OTP 27 only, push/schedule/dispatch run 26+27.
- concurrency group keyed on `github.event_name` with `cancel-in-progress` scoped to `pull_request` only, so a push can never cancel an in-flight nightly run (Pitfall 2 / T-90-04).

## Deviations from Plan

None — the plan executed exactly as written. The `resolve_tiers` step logic and output names were taken verbatim from RESEARCH.md "Pattern 1" (locked design).

**Total deviations:** 0 auto-fixed.

## Threat Mitigations Applied

- **T-90-04 (DoS, concurrency push-vs-schedule collision):** mitigated — `concurrency.group` now keyed on `github.event_name`; `cancel-in-progress` scoped to `pull_request`.
- **T-90-01 / T-90-02 (accept):** unchanged — `run_nightly` is a boolean-typed input compared only via `==`/shell string equality, never interpolated as free text into a `run:` command; repo remains on `pull_request` (not `pull_request_target`).

## Known Stubs

None. Stub-pattern scan of the two modified files found no placeholder/TODO/FIXME or empty-value stubs.

## User Setup Required

None.

## Next Phase Readiness

Ready for 90-02. The `resolve_tiers.outputs.run_nightly` flag is now live and proven; Plan 90-02 can gate `verify_admin` on it and drop `verify_admin` from `ci-gate`'s `needs:` (updating `@ci_gate_lanes` 14→13 in the same plan to avoid the `skipped`-dependency trap). The `test` job is a stable multi-gate `needs:` target.

## Self-Check: PASSED

- FOUND: `.github/workflows/ci.yml`
- FOUND: `test/chimeway/release_gate_contract_test.exs`
- FOUND commit: `76f4459`
- FOUND commit: `e1bf7f8`
- TIER-03 marked complete in REQUIREMENTS.md.
- No tracked file deletions introduced by the task commits.

---
*Phase: 90-pipeline-tiering-pr-main-nightly*
*Completed: 2026-07-29*
