---
status: complete
phase: 80-verification-architecture-and-ci-dx
source: [80-VERIFICATION.md]
started: 2026-07-03T17:00:00Z
updated: 2026-07-03T17:12:00Z
---

## Current Test

number: 1
name: Open a real pull request to `main` that touches only non-installer files and watch the checks tab.
expected: |
  `pr-gate` runs and reports a success/failure conclusion; the PR is NOT stuck in
  "Expected — Waiting for status to be reported"; `ci-gate` and the nine heavy lanes
  plus `install_golden_contract` are skipped (not pending) on the PR event.
  Ruleset 18486746 gates merge on `pr-gate` only.
awaiting: none — passed

## Tests

### 1. Live PR reports `pr-gate` without stranding (CI-03 anti-pending)
expected: `pr-gate` runs on the `pull_request` event and reports a success/failure conclusion; the PR is NOT stuck in "Expected — Waiting for status to be reported"; `ci-gate` and the nine heavy lanes plus `install_golden_contract` are skipped (not pending) on the PR event; ruleset 18486746 gates merge on `pr-gate` only.
result: passed
evidence: |
  Live throwaway PR #3 (branch test/pr-gate-smoke, single non-installer markdown file) opened against main.
  Observed via `gh pr view 3 --json statusCheckRollup`:
  - `pr-gate` reached a terminal conclusion: COMPLETED/FAILURE (not pending).
  - 11 heavy lanes reported conclusion SKIPPED (ci-gate, install_golden_contract, and the nine
    integration lanes) — skipped, never pending.
  - Final `pending: []` — every check reached a terminal state; nothing stranded in
    "Expected — Waiting for status to be reported".
  - `mergeStateStatus: BLOCKED` — ruleset 18486746 correctly gates merge on `pr-gate` only.
  pr-gate's FAILURE conclusion is caused by pre-existing formatting drift on main making the
  `Lint` lane red (see Gaps) — the gate correctly blocking a red state, NOT a topology defect.
  The anti-pending property (CI-03) is fully demonstrated. PR closed (throwaway), branch deleted.

## Summary

total: 1
passed: 1
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

- **Out-of-scope pre-existing finding (not a Phase 80 defect):** `main` fails `mix ci.lint`.
  `mix format --check-formatted` reports ~18 unformatted committed files (e.g.
  `lib/chimeway/adapters/mailglass.ex`, `lib/chimeway/inbox.ex`,
  `lib/chimeway/telemetry/threadline_reporter.ex`, and many `test/**` + `test/support/**`),
  and `mix ci.audit` flags vulnerable deps (decimal, hackney, mint, plug, req).
  None of these files were touched by Phase 80. Consequence: now that `pr-gate` (which
  includes `Lint`) is the required PR check, this drift blocks ALL PR merges until fixed.
  Recommended fast-follow: `mix format` commit + dependency bump. Tracked outside Phase 80 scope.
