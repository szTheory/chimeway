---
phase: 58
slug: accrue-dunning-core
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-29
---

# Phase 58 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.17+) |
| **Config file** | `mix.exs` aliases (`ci.test`, `verify.accrue`) |
| **Quick run command** | `mix test test/chimeway/integrations/accrue_dunning_harness_test.exs --only accrue --warnings-as-errors` |
| **Full suite command** | `mix verify.accrue` |
| **Estimated runtime** | ~30–90 seconds (depends on Accrue bootstrap) |

---

## Sampling Rate

- **After every task commit:** Run targeted `mix test .../accrue_* --only accrue --warnings-as-errors`
- **After every plan wave:** Run `mix verify.accrue`
- **Before `/gsd-verify-work`:** Full `mix verify.accrue` + `mix ci.test` must be green
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 58-01-01 | 01 | 1 | ECOS-06 | T-58-01 | Optional dep compiles without Accrue | compile | `mix compile --warnings-as-errors` | ✅ | ✅ green |
| 58-01-02 | 01 | 1 | ECOS-06 | T-58-02 | Accrue tests skip when dep absent | unit | `mix test --exclude accrue --warnings-as-errors` | ✅ | ✅ green |
| 58-01-03 | 01 | 1 | ECOS-06 | T-58-03 | Harness bootstrap + config round-trip | integration | `mix test test/chimeway/integrations/accrue_dunning_harness_test.exs --only accrue` | ✅ | ✅ green |
| 58-02-01 | 02 | 2 | ECOS-06 | T-58-04 | `payment_failed` → WorkflowRun + explainable trace | integration | `mix verify.accrue` (start describe) | ✅ | ✅ green |
| 58-02-02 | 02 | 2 | ECOS-06 | T-58-05 | Idempotent duplicate trigger | integration | `mix verify.accrue` | ✅ | ✅ green |
| 58-02-03 | 02 | 2 | ECOS-06 | T-58-06 | wait_until leaves pending_signals == [] while waiting; invoice.paid termination via cancel_campaign/3 → Chimeway.Signal.track/4 | integration | `mix verify.accrue` | ✅ | ✅ green |
| 58-03-01 | 03 | 3 | ECOS-06 | T-58-07 | `cancel_campaign` emits correct signal shape | integration | `mix verify.accrue` (terminate describe) | ✅ | ✅ green |
| 58-03-02 | 03 | 3 | ECOS-06 | T-58-08 | `route_signal` resumes run; no escalation email | integration | `mix verify.accrue` | ✅ | ✅ green |
| 58-03-03 | 03 | 3 | ECOS-06 | T-58-09 | `signal_received` context event_name only | integration | `mix verify.accrue` | ✅ | ✅ green |
| — | — | — | — | T-27-03 | Cross-tenant isolation unchanged | regression | `mix test test/chimeway/workflows_test.exs --warnings-as-errors` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `mix.exs` — optional `{:accrue, "~> 1.2", optional: true}`, `ci.test` exclude `:accrue`, `verify.accrue` alias
- [x] `test/support/accrue/data_case.ex` — shared sandbox bootstrap (Mailglass precedent)
- [x] `test/support/accrue/fixtures.ex` — customer/subscription/invoice helpers
- [x] `test/test_helper.exs` — conditional Accrue.TestRepo bootstrap
- [x] `test/chimeway/integrations/accrue_dunning_harness_test.exs` — Wave 58-01 stub
- [x] `test/chimeway/integrations/accrue_dunning_lifecycle_test.exs` — Waves 58-02/03 E2E
- [x] Accrue repo: `DunningNotifier.workflow/2`, `rendering/2`, `cancel_campaign/3` fix

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Accrue hex version pin at release | ECOS-06 | Cross-repo release coordination | Verify Accrue hex release includes `workflow/2` before bumping Chimeway dep constraint |

*All engine behaviour paths have automated verification via `mix verify.accrue` once Wave 0 lands.*

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 120s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-05-30
