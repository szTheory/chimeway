---
phase: 63
slug: threadline-telemetry-bridge
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-30
---

# Phase 63 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.17+) |
| **Config file** | `mix.exs` aliases (`ci.test`, future `verify.threadline`) |
| **Quick run command** | `mix test test/chimeway/integrations/threadline_telemetry_harness_test.exs --only threadline --warnings-as-errors` |
| **Full suite command** | `mix test --only threadline --warnings-as-errors` |
| **Estimated runtime** | ~20–60 seconds (depends on Threadline bootstrap) |

---

## Sampling Rate

- **After every task commit:** Run targeted `mix test .../threadline_* --only threadline --warnings-as-errors`
- **After every plan wave:** Run `mix test --only threadline --warnings-as-errors`
- **Before `/gsd-verify-work`:** Full `mix test --only threadline` + `mix ci.test` must be green
- **Max feedback latency:** 90 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 63-01-01 | 01 | 1 | ECOS-08 | T-63-01 | Optional dep compiles without Threadline | compile | `mix compile --warnings-as-errors` | ✅ | ⬜ pending |
| 63-01-02 | 01 | 1 | ECOS-08 | T-63-02 | Threadline tests skip when dep absent | unit | `mix test --exclude threadline --warnings-as-errors` | ✅ | ⬜ pending |
| 63-01-03 | 01 | 1 | ECOS-08 | T-63-03 | Harness bootstrap + config round-trip | integration | `mix test test/chimeway/integrations/threadline_telemetry_harness_test.exs --only threadline` | ❌ W0 | ⬜ pending |
| 63-01-04 | 01 | 1 | ECOS-08 | T-63-04 | `planning_reason` in safe_meta; deferred span enriched | unit | `mix test test/chimeway/telemetry_integration_test.exs --warnings-as-errors` | ✅ | ⬜ pending |
| 63-01-05 | 01 | 1 | ECOS-08 | T-63-05 | `correlation_id` on outcome spans | unit | `mix test test/chimeway/telemetry_correlation_test.exs --warnings-as-errors` | ✅ | ⬜ pending |
| 63-02-01 | 02 | 2 | ECOS-08 | T-63-06 | Reporter attach + record_action on lifecycle event | integration | `mix test test/chimeway/integrations/threadline_telemetry_lifecycle_test.exs --only threadline` | ❌ W0 | ⬜ pending |
| 63-02-02 | 02 | 2 | ECOS-08 | T-63-07 | Audit row correlation_id matches trigger | integration | same | ❌ W0 | ⬜ pending |
| 63-02-03 | 02 | 2 | ECOS-08 | T-63-08 | No PII in Threadline comment/reason | integration | same + telemetry PII tests | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `mix.exs` — optional `{:threadline, "~> 0.7", optional: true}`, `ci.test` exclude `:threadline`
- [ ] `config/test.exs` — Threadline.Test.Repo database config
- [ ] `test/test_helper.exs` — conditional Threadline bootstrap
- [ ] `test/support/threadline/data_case.ex` — audit_actions cleanup + Chimeway sandbox
- [ ] `test/support/threadline/fixtures.ex` — reporter config + attach helpers
- [ ] `test/chimeway/integrations/threadline_telemetry_harness_test.exs` — Wave 63-01 stub
- [ ] `test/chimeway/integrations/threadline_telemetry_lifecycle_test.exs` — Wave 63-02 E2E
- [ ] `lib/chimeway/telemetry/threadline_reporter.ex` — reporter module
- [ ] Telemetry enrichment — `planning_reason` allowed key + `correlation_id` on outcome spans

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Threadline hex version pin at release | ECOS-08 | Cross-repo release coordination | Verify Threadline hex `~> 0.7` includes `record_action/2` correlation_id before release bump |
| `mix verify.threadline` CI job | GATE-07 | Deferred to Phase 66 | N/A for Phase 63 |

*All Phase 63 engine behaviour paths have automated verification via `--only threadline` once Wave 0 lands.*

---

## Validation Sign-Off

- [ ] All tasks have automated verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 90s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
