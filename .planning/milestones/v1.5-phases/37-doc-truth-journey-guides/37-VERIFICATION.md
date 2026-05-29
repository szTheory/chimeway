---
phase: 37
name: doc-truth-journey-guides
status: passed
score: 16/16
requirements:
  DOCS-03: passed
verified_at: 2026-05-28
---

# Phase 37 Verification: Doc Truth & Journey Guides

**Goal:** Journey/workflow guides match engine capabilities; resolve `stop_conditions` / `pending_signals` drift via doc-truth or explicit deferral (DOCS-03).

**Status:** `passed` — DOCS-03 criteria #1–#3 satisfied; all plan must-haves green after gap-closure plan 37-04.

## Requirements Traceability

| Requirement | Criterion | Description | Status | Evidence |
|-------------|-----------|-------------|--------|----------|
| **DOCS-03** | #1 | Journey guide documents engine-accurate `wait_until`, `on_outcome`, `stop`, trigger, signals, Dispatch workers | **passed** | `guides/flows/multi-step-journeys.md` rewritten; grep gates green; cross-links to demo E2E + golden-path appendix resolve |
| **DOCS-03** | #2 | INV-002 resolved via doc-truth — explicit READ deferral for `pending_signals` / read-to-cancel | **passed** | §7 engine gap cites `enter_waiting/6` does not set `pending_signals`; §Deferred lists READ-01/READ-02; no `stop_conditions` in guides |
| **DOCS-03** | #3 | Lightweight doc-contract test catches journey guide API drift | **passed** | `test/chimeway/doc_contract_test.exs` — 18 tests, 0 failures; forbidden/required string gates |

## Automated Gates (37-VALIDATION.md)

| Task | Gate | Result |
|------|------|--------|
| 37-01-01 | `wait_until` / `on_outcome` / `stop` in journey guide | ✅ PASS |
| 37-01-02 | No aspirational APIs (`Chimeway.Workflow`, `stop_conditions`, `:wait`) | ✅ PASS |
| 37-01-03 | Deferred / READ / `pending_signals` callout | ✅ PASS |
| 37-01-04 | `Chimeway.trigger/3`; no `Chimeway.Trigger.trigger` in flows | ✅ PASS |
| 37-02-01 | Dispatch worker modules; no `Workflows.Workers` in guides | ✅ PASS |
| 37-03-01 | `mix test test/chimeway/doc_contract_test.exs` | ✅ 18 tests, 0 failures |
| 37-03-02 | `mix ci.docs && mix ci` | ✅ exit 0; 578 tests, 0 failures |

## Plan Must-Haves

### Plan 37-01 — Journey guide rewrite

| Check | Result |
|-------|--------|
| `workflow/2` with `wait_until`, `on_outcome`, `stop` progress rules | ✅ |
| Primary story: time-based in_app → email via `wait_until` (not read-to-cancel) | ✅ |
| `Chimeway.trigger/3` with `idempotency_key` and `tenant_id` | ✅ |
| `Chimeway.Signal.track/4` tenant-first argument order | ✅ |
| `:waiting` state, `explain/2`, `list_traces/2` inspection documented | ✅ |
| Delivery-feedback path with demo E2E + golden-path cross-links | ✅ |
| `pending_signals` gap + READ milestone deferral section | ✅ |
| Dispatch worker names in journey guide | ✅ |

### Plan 37-02 — Oban recipe fix

| Check | Result |
|-------|--------|
| `Chimeway.Dispatch.WorkflowProgressionWorker` and `SignalRouterWorker` | ✅ |
| Queues `:chimeway_delivery` / `:chimeway_signals` match `lib/chimeway/dispatch/` | ✅ |
| Per-run `due_at` scheduling documented as primary model | ✅ |
| `:chimeway_workflows` queue removed / marked unused | ✅ |
| `pending_signals` semantics (not stop-conditions fiction) | ✅ |
| Transactional Multi example matches engine API | ✅ — Pattern A (host Multi → trigger) and Pattern B (`Oban.dispatch/2` with `multi:`) per plan 37-04 |

### Plan 37-03 — Doc-contract test + validation sign-off

| Check | Result |
|-------|--------|
| Journey guide forbidden/required string gates in `doc_contract_test.exs` | ✅ |
| `37-VALIDATION.md` wave_0_complete + nyquist_compliant | ✅ |
| `mix test` + `mix ci` green | ✅ |

## Engine Cross-Check

| Guide claim | Code evidence | Match |
|-------------|---------------|-------|
| `enter_waiting/6` does not populate `pending_signals` | `progression.ex` `enter_waiting/6` updates state/context only — no `pending_signals` assignment | ✅ |
| `WorkflowProgressionWorker` on `:chimeway_delivery` | `workflow_progression_worker.ex` `queue: :chimeway_delivery` | ✅ |
| `SignalRouterWorker` on `:chimeway_signals` | `signal_router_worker.ex` `queue: :chimeway_signals` | ✅ |
| `temporary_failure` early-fire warning (WR-02 prose) | Documented in journey guide §2; aligns with Notifier moduledoc | ✅ |

## Test Execution Evidence

```
mix test test/chimeway/doc_contract_test.exs  → 18 tests, 0 failures
mix ci.docs                                      → exit 0
mix ci                                           → 578 tests, 0 failures
rg 'Workflows\.Workers' guides/                  → 0 matches
```

## Score

**16/16 must-have checks passed (100%)**

- Plan 37-01: 8/8
- Plan 37-02: 6/6
- Plan 37-03: 3/3
- Plan 37-04: gap closure (WR-01, WR-02, WR-03, IN-02)

DOCS-03 requirement: **passed** (all three acceptance criteria met).

## Gaps Found

| ID | Severity | File | Issue | Status |
|----|----------|------|-------|--------|
| WR-01 | Warning | `guides/recipes/oban-integration.md` | Transactional example passed `multi:` to `Chimeway.trigger/3` | **closed** — plan 37-04 Pattern A/B rewrite |
| WR-02 | Warning | `guides/recipes/oban-integration.md` | Commented cron lacked `progress_due_runs/1` guidance | **closed** — plan 37-04 cron comment |
| WR-03 | Info | `guides/flows/multi-step-journeys.md` | Stale Phase 38 Oban deferral | **closed** — plan 37-04 Next Steps update |
| IN-01 | Info | `doc_contract_test.exs` | No automated gates for `oban-integration.md` | **deferred** — Phase 41 GATE-01 |
| IN-02 | Info | `multi-step-journeys.md` | Unqualified `ProcessFeedbackWorker` | **closed** — plan 37-04 full module name |

**Recommendation:** Phase complete. IN-01 remains Phase 41 scope.

## Human Verification (optional UAT)

Not blocking automated sign-off. From `37-VALIDATION.md` manual checklist:

| Behavior | Instructions |
|----------|--------------|
| Fresh-host escalation timing | Trigger notifier with `wait_until` fixture; converge in_app → `:waiting`; past-due `progress_run/2` → email; `Workflows.explain/2` shows `waiting_for_step_progression` |
| Delivery-feedback signal path | Walk demo host feedback E2E or golden-path webhook appendix end-to-end |
| Semantic prose accuracy | Confirm WR-02 `temporary_failure` warning and §7 `enter_waiting` gap read correctly to a fresh adopter |
