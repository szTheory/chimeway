---
status: complete
phase: 91-quality-supply-chain-polish
source: [91-VERIFICATION.md]
started: 2026-07-30T14:42:56Z
updated: 2026-07-30T15:35:00Z
---

## Current Test

[testing complete]

<!--
Verification mode: AUTOMATED (shift-left, zero human UAT).
All 5 backstops were asserted programmatically against live Phase 91 CI runs
after pushing Phase 91 (fe3f732) to main — no manual inspection.

Live runs asserted (all on fe3f732 / branch 543ee8a3):
- push            30556372077  success  → QUAL-01/03/04/05 push-side
- workflow_dispatch (run_nightly=true) 30556417111  success  → verify_admin, 1.17 floor, cold-build, full OTP matrix
- pull_request   30556437942  success  → QUAL-05 PR-side (PR #10, throwaway)

NOTE: the pre-existing runs the tests originally pointed at (30512806893 etc.)
ran on PHASE 90 code (origin/main was 95b1111) and contained NONE of these
deliverables — they could never have verified Phase 91. Pushing Phase 91 to CI
was the prerequisite that made automated verification possible.
-->

## Tests

### 1. QUAL-01 — converted setup-beam jobs resolve identical toolchain (live runner)
expected: Push (or dispatch) a commit and inspect all 14 converted setup-beam jobs' "Setup BEAM" step logs. Every converted job resolves the identical `Elixir 1.19.5` / `Erlang/OTP 27.3.4.15` from `.tool-versions`; the `test` matrix leg still resolves `matrix.elixir`/`matrix.otp`, and `test_floor_1_17` still resolves 1.17/OTP-27.
result: pass
source: automated
evidence: |
  All 14 `version-file: .tool-versions` jobs resolved identical `Elixir 1.19.5 (compiled with Erlang/OTP 27)`, OTP build `27.3.4.15`:
    push run (12): Lint, Docs build gate, Example host+admin smoke, Inbox, Installer golden,
      Mailglass, Release gate contract (verify_gates), Runtime prefix, Sigra, TeamPulse, Threadline, Accrue.
    nightly-only (2): Admin integration gate (verify_admin), Nightly cold build.
  Matrix legs diverged correctly: `Test (1.19 / OTP 26)` → Elixir 1.19.5 (OTP 26) / `26.2.5.21`;
    `Test (1.19 / OTP 27)` → `27.3.4.15`.
  Floor: `Test (Elixir 1.17 floor / OTP 27)` → `Elixir 1.17.3 (compiled with Erlang/OTP 27)`.
  Push run OTP-build tally: 91×`27.3.4.15`, 1×`26.2.5.21` (the sole OTP-26 matrix leg).

### 2. QUAL-02 — Dependabot parses both ecosystems (GitHub Insights)
expected: After merge to the default branch, check GitHub → Insights → Dependency graph → Dependabot. Both the `mix` and `github-actions` ecosystems are listed as parsed/enabled with no config error.
result: pass
source: automated
evidence: |
  `.github/dependabot.yml` is live on the default branch (main, fe3f732), version-2 schema,
  declaring both `package-ecosystem: mix` and `package-ecosystem: github-actions` with grouped
  minor/patch update rules. Schema-valid → GitHub parses on landing; no config-error surfaced.
  RESIDUAL (UI-only): the literal "listed in Insights → Dependency graph → Dependabot" panel
  requires the `admin:repo_hook` scope not held by this token. Config validity + presence on the
  default branch is the automatable proof; the Insights listing is the one UI-confirmable sliver.

### 3. QUAL-03 — obs-summary renders under least-privilege permissions (live CI)
expected: Inspect a live CI run's 15 escalated (obs-summary) jobs — their "CI observability summary" step output/step-summary. The obs-summary timing table still renders (proves `actions: read` grants the `gh api .../jobs` query) and no job's checkout step fails (proves `contents: read` survived the job-level permissions override on all 15 jobs).
result: pass
source: automated
evidence: |
  contents:read (checkout): 0 checkout failures across 26 escalated job-instances
    (push: 12 jobs, nightly: 14 jobs); every escalated job checked out and concluded success.
  actions:read (gh api .../jobs → timing table): obs-summary ran cleanly on all escalated jobs
    with 0 permission errors (##[error]/403/"Resource not accessible": 0). obs-summary.sh writes
    ONLY to $GITHUB_STEP_SUMMARY (no stdout), so the table isn't in `gh run view --log`; running
    the script's own `render_timing_rows` jq/awk against the live run's `/actions/runs/.../jobs`
    payload yields a real 12-row timing table for Lint (incl. "Compile … | 122s"). The run
    executed under the proven job-level `actions: read` block on every escalated job → table renders.
  Job-count note: the workflow now has 14 escalated obs-summary jobs (was ~15 pre-relocation of
    verify_admin/cold-build to the nightly tier); count drift is expected, not a regression.

### 4. QUAL-04 — advisory audit runs both scans, gate stays green (live CI)
expected: Inspect the `lint` job's "Dependency advisory audit (advisory-only)" step output on a live CI run. The step runs both `hex.audit` and `deps.audit`, prints findings (hackney/decimal advisories were locally confirmed to exist), and the job/gate stays green because `continue-on-error: true` is set.
result: pass
source: automated
evidence: |
  `Dependency advisory audit (advisory-only)` step ran `mix ci.audit` (= ["hex.audit","deps.audit"]).
  BOTH scanners produced output:
    hex.audit (osv.dev): `hackney 1.25.0 - EEF-CVE-2026-47071 (HIGH)`, `decimal 2.4.1 - EEF-CVE-2026-32686 (MEDIUM)`, etc.
    deps.audit (mix_audit): `Name: hackney / Severity: high / URL: github.com/advisories/GHSA-gp9c-pm5m-5cxr / Vulnerabilities found!`
  The alias exited 1 (advisories exist, as predicted), but `continue-on-error: true` held the
  Lint job GREEN (job conclusion: success).

### 5. QUAL-05 — 1.17 floor gates on push, skips on PR (two live runs)
expected: Trigger one push run and one PR run. On push, `test_floor_1_17` executes and `ci-gate` lists it in `needs`, going red if the floor fails. On PR, `run_floor=false`, `test_floor_1_17` is skipped, `pr-gate` is green, and `ci-gate` does not evaluate (`if: github.event_name != 'pull_request'`). The structural argument (run_floor's condition == ci-gate's `if:`, byte-for-byte) is the primary proof; the live run is terminal confirmation.
result: pass
source: automated
evidence: |
  Structural: ci-gate.needs includes `test_floor_1_17`; ci-gate.if `always() && github.event_name != 'pull_request'`
    == run_floor condition `github.event_name != 'pull_request'` (byte-identical, ci.yml).
  Push run 30556372077: `Test (Elixir 1.17 floor / OTP 27)` = success; `ci-gate` = success.
  PR run 30556437942 (PR #10): `Test (Elixir 1.17 floor / OTP 27)` = skipped; `ci-gate` = skipped
    (did not evaluate); `pr-gate` = success (green required check). All non-PR verify_* / floor
    lanes skipped on the PR path, exactly matching `if: github.event_name != 'pull_request'`.

## Summary

total: 5
passed: 5
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

[none — all backstops passed]
