---
phase: 39
name: demo-host-trace-path
status: passed
score: 15/15
requirements:
  DEMO-01: passed
verified_at: 2026-05-28
---

# Phase 39 Verification: Demo Host Trace Path

**Goal:** Demo host proves explainability without requiring provider webhook setup.

**Status:** `passed` — all plan must-haves verified; post-merge test gate green.

## Requirements Traceability

| Requirement | Description | Status | Evidence |
|-------------|-------------|--------|----------|
| **DEMO-01** | Runnable demo host trace path separate from webhook E2E | **passed** | README IEx walkthrough + `mix demo.trace`; golden-path cross-link |

## ROADMAP Success Criteria

| # | Criterion | Status | Evidence |
|---|-----------|--------|----------|
| 1 | Trace inspection path separate from webhook E2E | **passed** | README § "Not this path: webhook progression"; contrasts golden-path appendix |
| 2 | Adopter can follow doc and query delivery/trace outcomes | **passed** | `mix demo.trace` returns `:succeeded` status and non-empty timeline |
| 3 | Referenced from golden-path as lowest-friction validation | **passed** | `### Validate in the demo host (no webhooks)` in golden-path §6 |

## Automated Gates

| Gate | Result |
|------|--------|
| `cd examples/chimeway_demo_host && mix compile --warnings-as-errors` | ✅ |
| `mix test --warnings-as-errors` (root suite) | ✅ 597 tests, 0 failures |
| `mix demo.trace` | ✅ status :succeeded, timeline populated |
| README grep (no `Repo.insert!`, no `Oban.drain_queue`) | ✅ |
| Golden-path demo host subsection | ✅ |

## Plan Must-Haves

### Plan 39-01 — Runtime foundation

| Check | Result |
|-------|--------|
| dev.exs: Sync dispatcher + chimeway_dev pool | ✅ |
| dev.exs: no SQL Sandbox | ✅ |
| TraceDemo notifier compiles | ✅ |
| .iex.exs starts :chimeway | ✅ |

### Plan 39-02 — README walkthrough

| Check | Result |
|-------|--------|
| Prerequisites + IEx bootstrap documented | ✅ |
| Chimeway.trigger/3 with idempotency_key + tenant_id | ✅ |
| explain_delivery/1 fields (status, suppression_reason, planning_reason, timeline) | ✅ |
| Webhook path contrast + golden-path link | ✅ |
| Optional D-08 script | ✅ implemented |

### Plan 39-03 — Adoption doc integration

| Check | Result |
|-------|--------|
| Golden-path "Validate in the demo host" subsection | ✅ |
| Password-reset recipe runnable proof cross-link | ✅ |
| No CI/doc-contract expansion (D-09) | ✅ |

## Score

**15/15 must-have checks passed (100%)**

## Human Verification (optional)

| Behavior | Instructions |
|----------|--------------|
| Full IEx walkthrough | `cd examples/chimeway_demo_host && iex -S mix`, run README snippets |
| Golden-path navigation | Open golden-path §6, follow link to demo host README |

Not blocking automated sign-off — `mix demo.trace` validates the same delivery APIs.

## Gaps Found

None.
