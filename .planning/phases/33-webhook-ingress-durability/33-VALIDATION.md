---
phase: 33
slug: webhook-ingress-durability
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-01
---

# Phase 33 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Populated from `33-RESEARCH.md` § Validation Architecture during planning.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.18, OTP 27) |
| **Config file** | `config/test.exs`, `test/test_helper.exs` |
| **Quick run command** | `mix test test/chimeway/webhooks_test.exs test/chimeway/webhooks/` |
| **Full suite command** | `mix ci.test` |
| **Estimated runtime** | quick: ~3 s · full: ~25 s · `mix verify.example`: ~8 s |

---

## Sampling Rate

- **After every task commit:** Run quick run command above
- **After every plan wave:** Run full suite command above
- **Before `/gsd-verify-work`:** Full suite must be green AND `mix verify.example` (Plan 04) must be green
- **Max feedback latency:** quick ~3 s, full ~25 s

---

## Per-Task Verification Map

> The planner is the source of truth — this section is filled in during planning from `33-RESEARCH.md` § Validation Architecture and updated as plans land.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 33-01-* | 01 | 1 | FEED-01 | T-33-PII | Ingress row stores normalized fields only — no raw payload, no secret headers | unit | `mix test test/chimeway/webhooks/ingress_test.exs` | ❌ W0 | ⬜ pending |
| 33-02-* | 02 | 2 | FEED-01 | T-33-ATOMIC | `process/4` returns success only after Multi commits both ingress row + Oban job | unit | `mix test test/chimeway/webhooks_test.exs` | ✅ | ⬜ pending |
| 33-03-* | 03 | 2 | FEED-02 | T-33-RETRY | Unknown/stale `delivery_id` ⇒ ingress row marked ignored, worker returns `:ok` (no retry storm) | unit | `mix test test/chimeway/webhooks/process_feedback_worker_test.exs` | ✅ | ⬜ pending |
| 33-04-* | 04 | 3 | FEED-01, FEED-02 | T-33-RAWBODY | Host controller reads exact raw bytes via `:body_reader` BEFORE JSON parse | integration | `mix verify.example` | ❌ W0 | ⬜ pending |
| 33-05-* | 05 | 4 | FEED-01, FEED-02 | T-33-DEDUP | Duplicate provider_event_id collapses on `(adapter_module, provider_event_id)` partial unique index | unit | `mix test test/chimeway/webhooks_test.exs` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/chimeway/webhooks/ingress_test.exs` — stubs for FEED-01 ingress schema (Plan 01)
- [ ] `examples/chimeway_demo_host/` Mix project skeleton with `config/`, `lib/`, `test/` (Plan 04)
- [ ] `examples/chimeway_demo_host/test/chimeway_demo_host_web/controllers/webhooks_controller_test.exs` — E2E raw-body fixture test (Plan 04)
- [ ] `mix verify.example` alias added to `mix.exs` (Plan 04)

*Existing test infrastructure (`test/chimeway/webhooks_test.exs`, `test/chimeway/webhooks/process_feedback_worker_test.exs`) covers Plans 02, 03, 05 without Wave 0 work.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| In-flight Oban job backwards-compat shim path during deploy | FEED-01 | Mid-deploy queue draining is a release-engineering concern; the shim's correctness is unit-testable but the deploy runbook itself is operator-driven | Review release runbook in Plan 03; confirm shim covers pre-Phase-33 job shape `%{"delivery_id"\|"provider_message_id" => …}` |

*All other phase behaviors have automated verification.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (Plans 01 + 04)
- [ ] No watch-mode flags
- [ ] Feedback latency < 30 s
- [ ] `nyquist_compliant: true` set in frontmatter (after planner finalizes per-task rows)

**Approval:** granted
