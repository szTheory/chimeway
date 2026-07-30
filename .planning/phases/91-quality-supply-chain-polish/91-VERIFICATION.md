---
phase: 91-quality-supply-chain-polish
verified: 2026-07-30T14:42:56Z
status: human_needed
score: 13/13 must-haves verified
behavior_unverified: 0
overrides_applied: 0
human_verification:
  - test: "Push (or dispatch) a commit and inspect all 14 converted setup-beam jobs' 'Setup BEAM' step logs in ci.yml"
    expected: "Every converted job resolves the identical `Elixir 1.19.5` / `Erlang/OTP 27.3.4.15` from `.tool-versions`; the `test` matrix leg still resolves `matrix.elixir`/`matrix.otp`, and `test_floor_1_17` still resolves 1.17/OTP-27"
    why_human: "QUAL-01 backstop — version resolution is only observable in a live GitHub Actions runner, not statically. Declared as `verification: backstop` in 91-01-PLAN.md must_haves."
  - test: "After merge to the default branch, check GitHub → Insights → Dependency graph → Dependabot"
    expected: "Both the `mix` and `github-actions` ecosystems are listed as parsed/enabled with no config error"
    why_human: "QUAL-02 backstop — Dependabot config parsing is only observable in GitHub's UI post-push. Declared as `verification: backstop` in 91-02-PLAN.md must_haves."
  - test: "Inspect the `lint` job's 'Dependency advisory audit (advisory-only)' step output on a live CI run"
    expected: "The step runs both `hex.audit` and `deps.audit`, prints findings (hackney/decimal advisories were locally confirmed to exist), and the job/gate stays green because `continue-on-error: true` is set"
    why_human: "QUAL-04 backstop — advisory-step behavior under `continue-on-error` in a live runner. Declared as `verification: backstop` in 91-02-PLAN.md must_haves."
  - test: "Inspect a live CI run's 15 escalated (obs-summary) jobs — their 'CI observability summary' step output/step-summary"
    expected: "The obs-summary timing table still renders (proves `actions: read` grants the `gh api .../jobs` query) and no job's checkout step fails (proves `contents: read` survived the job-level permissions override on all 15 jobs)"
    why_human: "QUAL-03 backstop — GITHUB_TOKEN scope behavior is only observable in a live runner, not via static grep. Declared as `verification: backstop` in 91-03-PLAN.md must_haves."
  - test: "Trigger one push run and one PR run"
    expected: "On push: `test_floor_1_17` executes and `ci-gate` lists it in `needs`, going red if the floor fails. On PR: `run_floor=false`, `test_floor_1_17` is skipped, `pr-gate` is green, and `ci-gate` does not evaluate (`if: github.event_name != 'pull_request'`)"
    why_human: "QUAL-05 backstop — the push-vs-PR gating behavior is only observable across two real workflow runs. Declared as `verification: backstop` in 91-03-PLAN.md must_haves. The structural argument (run_floor's condition == ci-gate's `if:` condition, byte-for-byte) is statically verified below and is the primary proof; the live run is the terminal confirmation."
---

# Phase 91: Quality & Supply-Chain Polish Verification Report

**Phase Goal:** Close the remaining small-but-compounding toolchain-truth and supply-chain gaps — one source of truth for toolchain versions (`.tool-versions` feeding setup-beam `version-file:`), automated dependency-update PRs (Dependabot mix + github-actions), least-privilege workflow permissions (top-level `contents: read`, jobs escalate only what they need), an advisory `mix_audit` vulnerability scan (non-blocking, matching `hex.audit`), and a reconciled CI-vs-release Elixir version (release pinned to the 1.17 floor; CI exercises AND gates that floor on push/nightly).

**Verified:** 2026-07-30T14:42:56Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `.tool-versions` is the single toolchain source; `setup-beam`'s `version-file:` reads it; cache keys derive from resolved versions, not hard-coded strings (ROADMAP SC1 / QUAL-01) | ✓ VERIFIED | `.tool-versions` at repo root: `erlang 27.3.4.15` + `elixir 1.19.5-otp-27`. `grep -c 'version-file: .tool-versions' ci.yml` = 14; `grep -c 'version-type: strict'` = 14. Cache-key lines still read `steps.beam.outputs.elixir-version`/`otp-version` (unchanged, e.g. ci.yml:104,168,213...). |
| 2 | The `test` matrix leg and `test_floor_1_17` floor leg retain explicit pins, not converted to version-file (D-03) | ✓ VERIFIED | `ci.yml:267` `elixir-version: ${{ matrix.elixir }}`; `ci.yml:1207` `elixir-version: "1.17"` (test_floor_1_17 block) — both intact, no `version-file` in either block. |
| 3 | `.github/dependabot.yml` exists and opens update PRs for both `mix` and `github-actions` ecosystems (ROADMAP SC2 / QUAL-02) | ✓ VERIFIED | File contains `version: 2`, `package-ecosystem: "mix"` + `package-ecosystem: "github-actions"`, both `directory: "/"`, weekly schedule, grouped `minor`/`patch`. Valid YAML confirmed via `python3 -c "import yaml; yaml.safe_load(...)"`. 65 SHA-pinned `uses:` refs exist in ci.yml for the github-actions ecosystem to act on. |
| 4 | `ci.yml` declares top-level `permissions: contents: read`; individual jobs escalate only what they need (ROADMAP SC3 / QUAL-03) | ✓ VERIFIED | Top-level `permissions:\n  contents: read` block present before `jobs:` (ci.yml:42-43). Exactly 15 job-level `permissions:` blocks (on `lint`, `verify_gates`, `verify_docs`, `test`, `verify_example`, `verify_runtime_prefix`, `verify_journeys`, `verify_mailglass`, `verify_accrue`, `verify_inbox`, `verify_threadline`, `verify_sigra`, `verify_admin`, `install_golden_contract`, `nightly_cold_build`), each declaring both `contents: read` and `actions: read`. `resolve_tiers`, `test_floor_1_17`, `pr-gate`, `ci-gate`, `nightly-gate` confirmed to have no job-level block (inherit read-only). |
| 5 | Exactly 15 `actions: read` and 16 `contents: read` (1 top-level + 15 job-level); zero `write` scopes anywhere (D-09) | ✓ VERIFIED | `grep -c 'actions: read'` = 15; `grep -c 'contents: read'` = 16; `grep -E '(contents\|actions\|...):\s*write'` matched nothing. |
| 6 | `mix_audit` runs in CI as a real advisory-DB vulnerability scan, non-blocking, findings visible in job output (ROADMAP SC4 / QUAL-04) | ✓ VERIFIED | `mix.exs:43` `{:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false}`; `mix.exs:84` `"ci.audit": ["hex.audit", "deps.audit"]`; `mix.lock:52` resolves `mix_audit` 2.1.5; `ci.yml:120-122` "Dependency advisory audit (advisory-only)" step runs `mix ci.audit` with `continue-on-error: true` intact. |
| 7 | Release workflow's Elixir version and CI's 1.17-floor leg are reconciled — release stays pinned to 1.17, CI exercises that floor on push/nightly (ROADMAP SC5 / QUAL-05) | ✓ VERIFIED | `release.yml:259-260` still pins `elixir-version: "1.17"` / `otp-version: "27"` (unchanged). `resolve_tiers` emits `run_floor` = `true` iff `github.event_name != 'pull_request'` (ci.yml, `flags` step). `test_floor_1_17`'s `if:` reads `needs.resolve_tiers.outputs.run_floor == 'true'` (broadened from `run_nightly`). |
| 8 | `ci-gate`'s `needs`/`env`/aggregate include `test_floor_1_17`/`TEST_FLOOR_1_17` — the floor genuinely gates on push (D-15, anti-vacuous-pass) | ✓ VERIFIED | `ci-gate` block: `needs: [..., test_floor_1_17]` (14 lanes), `env: TEST_FLOOR_1_17: ${{ needs.test_floor_1_17.result }}`, `aggregate-gate.sh` arg list includes `TEST_FLOOR_1_17`. `run_floor`'s emission condition (`github.event_name != 'pull_request'`) is byte-for-byte identical to `ci-gate`'s own `if: always() && github.event_name != 'pull_request'` — the floor's result is never `skipped` when ci-gate evaluates it (structural, not softened aggregate). |
| 9 | `pr-gate` does NOT reference the floor (D-14); it stays off for PRs | ✓ VERIFIED | `pr-gate` `needs: [lint, test, verify_gates, verify_docs]` — 4 lanes, no `test_floor_1_17`. |
| 10 | `aggregate-gate.sh` is unchanged — skipped-as-fail contract intact (structural anti-vacuous-pass guarantee) | ✓ VERIFIED | `git log --oneline -- scripts/ci/aggregate-gate.sh` shows no commit in this phase's range touching the file; last modifying commit predates phase 91. |
| 11 | `nightly-gate` is unchanged — already lists the floor | ✓ VERIFIED | `nightly-gate` `needs: [resolve_tiers, nightly_cold_build, test, test_floor_1_17, verify_admin]` — matches pre-existing Phase 90 shape (no diff in this phase). |

**Score:** 11/11 statically-verifiable truths verified (13/13 counting must_haves.truths lines across all 3 plans, which restate a subset of the above). 5 backstop items (declared `verification: backstop` in PLAN frontmatter) are correctly not counted toward this score — they route to human verification below, per phase-plan design.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `.tool-versions` | Repo-root file, strict full-patch pins | ✓ VERIFIED | 2 lines: `erlang 27.3.4.15`, `elixir 1.19.5-otp-27`, plus explanatory comments. |
| `.github/workflows/ci.yml` (14 converted setup-beam blocks) | `version-file:`/`version-type: strict` on 14 jobs | ✓ VERIFIED | 14/14 pairs present; matrix + floor legs unconverted. |
| `.github/dependabot.yml` | Valid YAML, `version: 2`, mix + github-actions, weekly, grouped | ✓ VERIFIED | Confirmed via direct read + `yaml.safe_load`. |
| `mix.exs` (mix_audit dep + extended ci.audit alias) | `{:mix_audit, "~> 2.1", only: [:dev,:test], runtime: false}` + `ci.audit == ["hex.audit","deps.audit"]` | ✓ VERIFIED | Both present at mix.exs:43 and :84. |
| `mix.lock` (mix_audit resolved) | mix_audit entry present | ✓ VERIFIED | `mix_audit` 2.1.5 resolved at mix.lock:52, with transitive `yaml_elixir`/`yamerl`. |
| `.github/workflows/ci.yml` (permissions + run_floor wiring) | Top-level `permissions:`, 15 job escalations, `run_floor` output, ci-gate extension | ✓ VERIFIED | All present and wired (see truths 4-8 above). |
| `.github/workflows/release.yml` | Unchanged, still pins 1.17/OTP-27 | ✓ VERIFIED | Lines 259-260 unchanged. |
| `scripts/ci/aggregate-gate.sh` | Unchanged | ✓ VERIFIED | No commit in this phase's range modifies it. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `.tool-versions` | `erlef/setup-beam` (14 jobs) | `version-file: .tool-versions` + `version-type: strict` | ✓ WIRED | 14/14 occurrences confirmed by grep; content matches captured green-run values. |
| `mix_audit` dep | `mix ci.audit` alias | `deps.audit` task provided by mix_audit, invoked via extended alias | ✓ WIRED | `mix.exs` alias includes `deps.audit`; `mix.lock` resolves the providing dep; SUMMARY confirms `mix help deps.audit` exits 0 locally. |
| `.github/dependabot.yml` `github-actions` ecosystem | SHA-pinned `uses:` refs in `ci.yml` | Dependabot native scan of `.github/workflows` | ✓ WIRED (structural) | 65 SHA-pinned `uses:@<40-hex>` refs exist for Dependabot to target; ecosystem config present with `directory: "/"`. Live PR-opening behavior is the QUAL-02 backstop (human verification). |
| `resolve_tiers.outputs.run_floor` | `test_floor_1_17` `if:` | `needs.resolve_tiers.outputs.run_floor == 'true'` | ✓ WIRED | Confirmed at test_floor_1_17 block, replacing prior `run_nightly` reference. |
| `test_floor_1_17` | `ci-gate` | `needs:` + `env: TEST_FLOOR_1_17` + `aggregate-gate.sh` arg | ✓ WIRED | All three wiring points confirmed present in the `ci-gate` block. |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| QUAL-01 | 91-01 | `.tool-versions` single toolchain source feeding setup-beam `version-file:` + cache keys | ✓ SATISFIED (structural) | 14/14 conversions, matrix/floor legs intact, cache keys unchanged. Live-resolution backstop pending (human verification). |
| QUAL-02 | 91-02 | `.github/dependabot.yml` covers `mix` + `github-actions` | ✓ SATISFIED (structural) | Valid config present, both ecosystems declared. GitHub Insights parse-confirmation backstop pending. |
| QUAL-03 | 91-03 | Top-level least-privilege `permissions: contents: read`; jobs escalate only where needed | ✓ SATISFIED (structural) | Top-level + 15/15 job-level blocks confirmed, zero write scopes. Live obs-summary-still-renders backstop pending. |
| QUAL-04 | 91-02 | `mix_audit` runs as real advisory-DB scan, non-blocking | ✓ SATISFIED (structural) | Dep + alias + lockfile confirmed; `continue-on-error: true` intact. Live CI-step-output backstop pending. |
| QUAL-05 | 91-03 | CI↔release Elixir skew reconciled; release stays 1.17, CI exercises AND gates that floor on push/nightly | ✓ SATISFIED (structural) | `release.yml` unchanged; `run_floor`/`ci-gate` wiring confirmed structurally identical to ci-gate's own run condition (anti-vacuous-pass). Live push+PR run backstop pending. |

No orphaned requirement IDs found — REQUIREMENTS.md's "QUAL — Quality & Supply-Chain Polish (Phase 91)" section lists exactly QUAL-01..05, all of which are declared across the three plans' `requirements:` frontmatter (91-01: QUAL-01; 91-02: QUAL-02, QUAL-04; 91-03: QUAL-03, QUAL-05). REQUIREMENTS.md's per-item checkboxes (lines 41-45) are all `[x]`. Note: REQUIREMENTS.md's separate "Traceability" summary table (line 83) still shows `QUAL-01..05 | Phase 91 | Pending` — this is stale bookkeeping in a secondary summary table (the same staleness pattern appears on the `CACHE-01..05` row for the already-shipped Phase 88), not a gap in the actual requirement checkboxes or codebase; flagged as an info-level anti-pattern below, not a blocker.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `.planning/REQUIREMENTS.md` | 83 | Traceability summary row `QUAL-01..05 \| Phase 91 \| Pending` not updated to `Complete` despite per-item `[x]` checkboxes above it | ℹ️ Info | Cosmetic doc staleness only; does not affect requirement satisfaction (same pre-existing pattern on the Phase 88/CACHE row) — does not block phase goal. |

No TBD/FIXME/XXX/TODO/HACK/PLACEHOLDER markers found in any file modified by this phase (`.tool-versions`, `ci.yml`, `dependabot.yml`, `mix.exs`, `mix.lock`, `release_gate_contract_test.exs`). `actionlint .github/workflows/ci.yml` exits 0.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| `release_gate_contract_test.exs` (the new 14-lane / `run_floor` contract, added/updated in this phase's Rule-1 deviation) passes | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors` | "87 tests, 0 failures" | ✓ PASS |
| `.tool-versions` + ci.yml conversion is syntactically valid GitHub Actions YAML/expressions | `actionlint .github/workflows/ci.yml` | exit 0, no output | ✓ PASS |
| `.github/dependabot.yml` is valid YAML | `python3 -c "import yaml; yaml.safe_load(open('.github/dependabot.yml'))"` | exit 0 | ✓ PASS |

### Probe Execution

Not applicable — no `scripts/*/tests/probe-*.sh` files exist in this repository and none are declared in the PLAN/SUMMARY files for this phase. Step 7c: SKIPPED (no probes declared or discovered).

### Human Verification Required

This is a CI/config-only phase. Five must-haves are explicitly declared `verification: backstop` in the PLAN frontmatter — they assert runtime behavior only observable in a live GitHub Actions run (resolved BEAM versions, Dependabot's own config parser, `continue-on-error` step behavior, `GITHUB_TOKEN` scope enforcement, and push-vs-PR gate evaluation). All are structurally proven correct by the static checks above; none are FAILED. They route here per the phase's own design (see each plan's `<verify><human-check>` blocks), not because of any codebase gap:

### 1. QUAL-01 — Setup BEAM version resolution

**Test:** Push/dispatch a commit; inspect all 14 converted jobs' "Setup BEAM" step logs.
**Expected:** All resolve `Elixir 1.19.5` / `Erlang/OTP 27.3.4.15` identically; `test` matrix and `test_floor_1_17` still resolve their non-canonical pins.
**Why human:** Version resolution is a live-runner-only observable (backstop, 91-01-PLAN.md).

### 2. QUAL-02 — Dependabot config parse

**Test:** GitHub → Insights → Dependency graph → Dependabot, post-push.
**Expected:** Both `mix` and `github-actions` ecosystems listed as parsed, no config error.
**Why human:** Only observable in GitHub's own UI (backstop, 91-02-PLAN.md).

### 3. QUAL-04 — Advisory audit step behavior

**Test:** Inspect the `lint` job's "Dependency advisory audit (advisory-only)" step on a live run.
**Expected:** Both `hex.audit` and `deps.audit` run, findings print, gate stays green (`continue-on-error: true`).
**Why human:** Step-level runtime behavior under `continue-on-error`, only observable in CI (backstop, 91-02-PLAN.md).

### 4. QUAL-03 — Least-privilege token still functional

**Test:** Inspect the 15 escalated jobs' obs-summary output/step-summary on a live run.
**Expected:** Timing table renders (`actions: read` works); no checkout failures (`contents: read` survived job-level override).
**Why human:** GITHUB_TOKEN scope enforcement only observable in a live runner (backstop, 91-03-PLAN.md).

### 5. QUAL-05 — Push-vs-PR floor gating

**Test:** One push run + one PR run.
**Expected:** Push: floor runs, `ci-gate` gates on it (red if it fails). PR: floor skipped, `pr-gate` green, `ci-gate` not evaluated.
**Why human:** Cross-run gating behavior only observable across two real workflow triggers (backstop, 91-03-PLAN.md). Static/structural proof (run_floor's condition is byte-for-byte identical to ci-gate's own `if:`) is already confirmed above and is the primary evidence; the live run is the terminal confirmation, not a source of doubt.

### Gaps Summary

No gaps found. Every statically-verifiable must-have (artifacts, key links, requirement wiring, anti-vacuous-pass structural guarantees) is present, substantive, and wired correctly across all three plans. All 5 remaining open items are pre-declared backstops requiring a live GitHub Actions run to observe — this is expected and by design for a CI/config-only phase, not a defect. `.planning/WINDOWS.md` already tracks 3 of these 5 as open `unrun-verify` ledger entries (QUAL-01, QUAL-02, QUAL-04); the QUAL-03 and QUAL-05 backstops from 91-03-SUMMARY.md's "Next Phase Readiness" section were not separately logged to WINDOWS.md but are captured here.

---

_Verified: 2026-07-30T14:42:56Z_
_Verifier: Claude (gsd-verifier)_
