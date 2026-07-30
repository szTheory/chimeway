---
phase: 91
slug: quality-supply-chain-polish
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-30
---

# Phase 91 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> **Config/CI-only phase:** there is no library test suite to sample — the observable
> "test" surface is `actionlint`/`yamllint` on the workflow files, `mix` output, and a
> green CI run on `main`. See `91-RESEARCH.md` § "Validation Architecture" for the
> authoritative validation map the Nyquist auditor consumes.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | none — config-only phase; verification is CI-run + static-lint based (no unit tests) |
| **Config file** | `.github/workflows/ci.yml`, `.github/workflows/release.yml`, `mix.exs` |
| **Quick run command** | `actionlint .github/workflows/ci.yml && mix deps.audit` |
| **Full suite command** | green CI run on `main` (push tier: `{26,27}` matrix + 1.17 floor + gates) |
| **Estimated runtime** | ~lint seconds locally; full CI push tier ~6–7 min |

---

## Sampling Rate

- **After every task commit:** Run `actionlint <changed-workflow>` (YAML + expression validity)
- **After every plan wave:** Re-run `actionlint` on all touched workflows + `mix deps.get && mix deps.audit`
- **Before `/gsd-verify-work`:** A push-tier CI run must be green (floor leg exercised AND gating)
- **Max feedback latency:** ~lint seconds locally; CI confirmation is the terminal gate

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| _seeded — planner fills per-task rows against QUAL-01..05; see 91-RESEARCH.md § Validation Architecture_ | | | | | | | | | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

*Existing infrastructure covers all phase requirements — no test-framework install needed. Validation is CI-run + `actionlint`/`mix` based (config-only phase).*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `.tool-versions` resolves to today's exact Erlang/Elixir (no silent shift/hard-fail) | QUAL-01 | Requires a live `setup-beam` run to confirm `version-type: strict` resolves the full-patch pins | Trigger a CI run; confirm the `Setup BEAM` step logs `Elixir 1.19.5` / `Erlang/OTP 27.3.4` in a converted job |
| Dependabot opens PRs for `mix` + `github-actions` | QUAL-02 | GitHub-native; only observable after merge on the schedule | Confirm GitHub → Insights → Dependency graph → Dependabot lists both ecosystems as parsed/enabled |
| 1.17 floor leg runs AND blocks push CI on failure | QUAL-05 | Requires a push event (skipped on PR by design) | On a push, confirm `test_floor_1_17` runs and `ci-gate` `needs:` it; structural argument in RESEARCH.md is the primary proof |

---

## Validation Sign-Off

- [ ] All tasks have an automated `actionlint`/`mix`/CI-run verify or a documented manual verification
- [ ] Sampling continuity: no 3 consecutive tasks without an automated check
- [ ] Wave 0 covers all MISSING references (N/A — no framework install)
- [ ] No watch-mode flags
- [ ] Feedback latency acceptable (lint-local + CI terminal gate)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
