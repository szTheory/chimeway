---
phase: 59
slug: accrue-blueprint-demo
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-05-30
---

# Phase 59 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.17+) |
| **Config file** | Root `mix.exs` aliases; `examples/chimeway_demo_host/mix.exs` |
| **Quick run command** | `cd examples/chimeway_demo_host && mix test --only accrue --warnings-as-errors` |
| **Full suite command** | `ACCRUE_PATH=../accrue/accrue mix verify.accrue --warnings-as-errors` |
| **Estimated runtime** | ~45–90 seconds (root + demo, Accrue compile) |

---

## Sampling Rate

- **After every task commit:** Run quick run command when demo files touched; run targeted doc-contract when recipe touched
- **After every plan wave:** Run `mix verify.accrue --warnings-as-errors`
- **Before `/gsd-verify-work`:** Full `mix verify.accrue` + `mix ci.test` green
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 59-01-01 | 01 | 1 | DEMO-07 | T-59-01 | Demo host Accrue dep optional; journey suite unchanged | config | `mix test --only journey` (demo host) | ✅ | ⬜ pending |
| 59-01-02 | 01 | 1 | DEMO-07 | T-59-02 | TestRepo bootstrap isolated to `:accrue` tests | integration | `cd examples/chimeway_demo_host && mix test --only accrue` | ❌ W0 | ⬜ pending |
| 59-01-03 | 01 | 1 | DEMO-07 | T-59-03 | Escalation path via Accrue events only | integration | same | ❌ W0 | ⬜ pending |
| 59-01-04 | 01 | 1 | DEMO-07 | T-59-04 | Admin trace shows workflow progression | integration | same | ❌ W0 | ⬜ pending |
| 59-01-05 | 01 | 1 | DEMO-07 | — | `verify.accrue` includes demo host | config | `mix verify.accrue` | ❌ W0 | ⬜ pending |
| 59-02-01 | 02 | 2 | ECOS-07 | — | Blueprint recipe published with required strings | doc | `mix test test/chimeway/doc_contract_test.exs` | ❌ W0 | ⬜ pending |
| 59-02-02 | 02 | 2 | ECOS-07 | T-59-05 | No fictional modules in recipe | unit | doc-contract describe | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing Phase 58 infrastructure covers Accrue engine proof. Phase 59 Wave 0 = demo host wiring artifacts:

- [ ] `examples/chimeway_demo_host/mix.exs` — optional accrue dep
- [ ] `examples/chimeway_demo_host/test/test_helper.exs` — Accrue TestRepo bootstrap
- [ ] `examples/chimeway_demo_host/test/support/accrue_fixtures.ex` — demo-local fixture helpers
- [ ] `examples/chimeway_demo_host/test/demo_host_web/accrue_dunning_proof_test.exs` — `@moduletag :accrue`
- [ ] `examples/chimeway_demo_host/lib/demo_host/seeds.ex` — `seed_accrue_dunning/0`
- [ ] `guides/recipes/accrue-dunning-blueprint.md` — ECOS-07 recipe
- [ ] `test/chimeway/doc_contract_test.exs` — ECOS-07 describe block

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Local ACCRUE_PATH sibling repo | DEMO-07 | Path dep env-specific | Document in blueprint prerequisites; CI uses fetched hex/path |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
