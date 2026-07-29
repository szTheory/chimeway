---
phase: 87
slug: ci-observability-cache-diagnostics
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-28
---

# Phase 87 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source: `87-RESEARCH.md` → **## Validation Architecture**. This phase's "behaviors" are
> shell parsing + workflow wiring, not library code — so validation extends the repo's
> established **ExUnit CI-script contract-test** pattern
> (`test/chimeway/release_gate_contract_test.exs`), NOT a new framework.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (already present) — contract tests over `scripts/ci/obs-*.sh` + `ci.yml` wiring |
| **Config file** | `test/test_helper.exs` (existing) |
| **Quick run command** | `mix test test/chimeway/ci_observability_contract_test.exs` |
| **Full suite command** | `mix ci.verify_gates` (contract lane) + one live push run for run-link evidence |
| **Estimated runtime** | ~5–15 seconds (unit/contract) + one live CI run (OBS-04 evidence) |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/chimeway/ci_observability_contract_test.exs`
- **After every plan wave:** Run `mix ci.verify_gates` (full contract lane)
- **Before `/gsd-verify-work`:** Full suite green **and** one live push run whose build-lane
  job summaries visibly render the cache, recompile, and timing tables.
- **Max feedback latency:** ~15 seconds for the unit/contract layer (live-run evidence is out-of-band, OBS-04 only)

---

## Per-Task Verification Map

> Task IDs are seeded representatively against requirements; `/gsd-plan-phase` (planner) and
> `/gsd-validate-phase` finalize exact IDs against the emitted PLAN.md task breakdown.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 87-00-01 | 00 | 0 | OBS-01..04 | T-87-01 | Summary prints only cache keys/counts/durations/run-URL; never `env`/secrets | unit/contract | `mix test test/chimeway/ci_observability_contract_test.exs` | ❌ W0 | ⬜ pending |
| 87-xx-01 | xx | 1 | OBS-01 | T-87-02 | Cache classifier → HIT/PARTIAL/MISS; every build-lane cache step has stable `id:` | unit + contract | `System.cmd` 3 synthetic triples → 3 states; grep asserts `id:` + obs-summary step per lane | ❌ W0 | ⬜ pending |
| 87-xx-02 | xx | 1 | OBS-02 | — | Recompile parser sums `Compiling N files`, splits deps/app, returns 0 when warm | unit | `System.cmd` pipes fixture compile logs → asserts `deps_n`/`app_n`; empty → `0 0` | ❌ W0 | ⬜ pending |
| 87-xx-03 | xx | 1 | OBS-03 | — | Timing renderer turns fixture `/jobs` JSON → `\| step \| Ns \|`; missing data → "unavailable" (non-fatal) | unit | `System.cmd` feeds fixture jobs-API JSON to the `jq` render path; assert rows + graceful fallback | ❌ W0 | ⬜ pending |
| 87-xx-04 | xx | 2 | OBS-04 | — | `.planning/CI-PERF-BASELINE.md` exists with `actions/runs/` permalink + 4 baseline facts | contract + human | ExUnit asserts file exists + run-URL pattern + the four numbers; human opens run, confirms tables render | ❌ W0 + live run | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/chimeway/ci_observability_contract_test.exs` — covers OBS-01..04 (classifier/parser/timing via `System.cmd` + fixtures; `ci.yml` wiring grep; baseline-doc existence + run-link assertion)
- [ ] `test/fixtures/ci/compile_cold.log`, `test/fixtures/ci/compile_warm.log`, `test/fixtures/ci/jobs_api_sample.json` — parser fixtures
- [ ] `.planning/CI-PERF-BASELINE.md` — created and populated from a real push run (OBS-04 evidence of record)
- [ ] Optional advisory: `shellcheck` on new `scripts/ci/obs-*.sh` (matches repo shell-hygiene posture)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Job-summary tables render correctly in the GitHub UI | OBS-01, OBS-02, OBS-03 | GitHub-side markdown rendering of `$GITHUB_STEP_SUMMARY` cannot be asserted from ExUnit | Open the linked baseline run; confirm each build lane's summary shows a cache table, a deps/app recompile line, and a per-step timing table |
| Baseline run link resolves to the measured run | OBS-04 | The permalink points at a live GitHub Actions run | Click the `actions/runs/...` link in `CI-PERF-BASELINE.md`; confirm it is the recorded baseline run |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s (unit/contract layer)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
