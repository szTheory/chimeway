---
status: testing
phase: 91-quality-supply-chain-polish
source: [91-VERIFICATION.md]
started: 2026-07-30T14:42:56Z
updated: 2026-07-30T14:42:56Z
---

## Current Test

number: 1
name: All 14 converted setup-beam jobs resolve the identical toolchain on a live runner (QUAL-01)
expected: |
  Push (or dispatch) a commit and inspect all 14 converted setup-beam jobs' "Setup BEAM" step
  logs in ci.yml. Every converted job resolves the identical `Elixir 1.19.5` / `Erlang/OTP
  27.3.4.15` from `.tool-versions`; the `test` matrix leg still resolves `matrix.elixir`/`matrix.otp`,
  and `test_floor_1_17` still resolves 1.17/OTP-27.
awaiting: user response

## Tests

### 1. QUAL-01 — converted setup-beam jobs resolve identical toolchain (live runner)
expected: Push (or dispatch) a commit and inspect all 14 converted setup-beam jobs' "Setup BEAM" step logs. Every converted job resolves the identical `Elixir 1.19.5` / `Erlang/OTP 27.3.4.15` from `.tool-versions`; the `test` matrix leg still resolves `matrix.elixir`/`matrix.otp`, and `test_floor_1_17` still resolves 1.17/OTP-27.
result: [pending]

### 2. QUAL-02 — Dependabot parses both ecosystems (GitHub Insights)
expected: After merge to the default branch, check GitHub → Insights → Dependency graph → Dependabot. Both the `mix` and `github-actions` ecosystems are listed as parsed/enabled with no config error.
result: [pending]

### 3. QUAL-04 — advisory audit runs both scans, gate stays green (live CI)
expected: Inspect the `lint` job's "Dependency advisory audit (advisory-only)" step output on a live CI run. The step runs both `hex.audit` and `deps.audit`, prints findings (hackney/decimal advisories were locally confirmed to exist), and the job/gate stays green because `continue-on-error: true` is set.
result: [pending]

### 4. QUAL-03 — obs-summary renders under least-privilege permissions (live CI)
expected: Inspect a live CI run's 15 escalated (obs-summary) jobs — their "CI observability summary" step output/step-summary. The obs-summary timing table still renders (proves `actions: read` grants the `gh api .../jobs` query) and no job's checkout step fails (proves `contents: read` survived the job-level permissions override on all 15 jobs).
result: [pending]

### 5. QUAL-05 — 1.17 floor gates on push, skips on PR (two live runs)
expected: Trigger one push run and one PR run. On push, `test_floor_1_17` executes and `ci-gate` lists it in `needs`, going red if the floor fails. On PR, `run_floor=false`, `test_floor_1_17` is skipped, `pr-gate` is green, and `ci-gate` does not evaluate (`if: github.event_name != 'pull_request'`). The structural argument (run_floor's condition == ci-gate's `if:`, byte-for-byte) is the primary proof; the live run is terminal confirmation.
result: [pending]

## Summary

total: 5
passed: 0
issues: 0
pending: 5
skipped: 0
blocked: 0

## Gaps
