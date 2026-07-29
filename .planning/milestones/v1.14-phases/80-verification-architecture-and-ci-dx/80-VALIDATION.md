---
phase: 80
slug: verification-architecture-and-ci-dx
status: approved
nyquist_compliant: true
wave_0_complete: false
created: 2026-07-03
---

# Phase 80 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.17 in CI) |
| **Config file** | none — standard `mix test` |
| **Quick run command** | `mix test test/chimeway/release_gate_contract_test.exs` |
| **Full suite command** | `mix ci` (lint + test) |
| **Estimated runtime** | ~10 seconds (contract test) / ~minutes (`mix ci`) |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/chimeway/release_gate_contract_test.exs`
- **After every plan wave:** Run `mix ci` (lint + test)
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** ~10 seconds (contract test)

---

## Per-Task Verification Map

Requirement → validation mapping (Nyquist Dimension 8). Structural cores are ExUnit-verifiable via an extended `test/chimeway/release_gate_contract_test.exs`; behavioral/operator tails are recorded as CI-observed or operator-attested.

| Req | Behavior | Validation type | Automated Command / Method | Code-verifiable |
|-----|----------|-----------------|----------------------------|-----------------|
| CI-01 | `pr-gate` exists, `needs` only fast subset `{lint,test,verify_gates,verify_docs}`, no path filter | ExUnit static | new assertions in `release_gate_contract_test.exs` | ✅ structure |
| CI-01 | `pr-gate` is the *required* PR check | Operator-attested | MAINTAINING.md step + GitHub branch-protection settings | ❌ D-08 |
| CI-02 | 3 workflows still poll `ci-gate` by name | ExUnit static | existing tests (release_gate_contract ~243-269) kept green | ✅ |
| CI-02 | `ci-gate` strictness ↑ — `install_golden_contract` folded into `needs` | ExUnit static | invert line-222 `refute→assert` + 14-lane count | ✅ |
| CI-02 | `ci-gate` actually gates release on push/dispatch | CI-run behavioral | observe a `workflow_dispatch` CI run + release replay | ⚠️ CI-observable |
| CI-03 | no job-level `paths:` on required-feeding lanes; detect-step pattern used | ExUnit static | grep-style assertion over `ci.yml` | ✅ |
| CI-03 | required check never strands pending | Operator-attested | depends on D-08 swap + a real skipped-path PR | ❌ branch-protection |
| CI-04 | `scripts/ci/*.sh` exist and `ci.yml` calls them | ExUnit static | `File.exists?` + `ci.yml` contains path | ✅ |
| CI-04 | scripts run locally | Behavioral smoke | run e.g. `scripts/ci/detect-installer-changes.sh main` locally | ⚠️ manual/CI smoke |
| CI-05 | cache steps for admin/inbox/demo `mix.lock`, npm, Playwright present + correctly keyed | ExUnit static | assert `ci.yml` contains cache paths/keys | ✅ |
| D-08 | branch-protection required check = `pr-gate` for PRs into `main` | Operator-attested | manual GitHub settings change | ❌ non-code-verifiable |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `test/chimeway/release_gate_contract_test.exs` — extension folded into **Wave 1 (80-01 Task 3)**, not a separate Wave 0: invert `install_golden_contract` needs assertion, update lane count 13→14, add `pr-gate` fast-subset + no-path-filter assertions; cache-presence assertions added in 80-02, script-redirect assertions in 80-03.

*No separate Wave 0 needed — existing ExUnit infrastructure covers all code-verifiable phase requirements; the contract-test lock evolves alongside each topology change wave. `wave_0_complete` stays false until execution runs.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `pr-gate` set as the required PR check; `ci-gate` removed as required for PRs | CI-01 / CI-03 / D-08 | Branch protection lives in GitHub repo settings, not the repo tree — code cannot set or assert it | Operator swaps required check `ci-gate`→`pr-gate` for PRs into `main` per MAINTAINING.md; verify a path-skipped PR no longer strands pending |
| `ci-gate` gates release/publish/automerge/recovery on push + `workflow_dispatch` | CI-02 | Requires a live CI run + release replay; not unit-observable | Observe a `workflow_dispatch` `ci-gate` run and a release-path poll succeed against it |
| Extracted `scripts/ci/*.sh` reproduce CI behavior locally | CI-04 | End-to-end reproducibility is a runtime smoke, not a static assertion | Run each extracted script locally and confirm parity with the CI step it replaced |

---

## Validation Sign-Off

- [x] All code-verifiable tasks have an ExUnit contract assertion or Wave 0 dependency
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 1 (80-01 Task 3) covers the release-gate contract extension (Wave 0 folded in)
- [x] Operator-attested items (D-08 branch-protection swap) documented in MAINTAINING.md (80-04 blocking checkpoint)
- [x] Behavioral/CI-run tails recorded as CI-observed, not silently dropped
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-07-03 (planning-time strategy sign-off; `wave_0_complete` flips at execution)
