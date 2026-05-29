---
phase: 38
name: reference-recipes
status: passed
score: 12/12
requirements:
  RECP-01: passed
  RECP-02: passed
verified_at: 2026-05-28
---

# Phase 38 Verification: Reference Recipes

**Goal:** Ship persona-driven RECP-01 and RECP-02 reference recipes under `guides/recipes/` with HexDocs registration and doc-contract gates.

**Status:** `passed` — all plan must-haves verified; automated gates green.

## Requirements Traceability

| Requirement | Description | Status | Evidence |
|-------------|-------------|--------|----------|
| **RECP-01** | Password-reset support trace walkthrough (Feature Developer + Support Operator) | **passed** | `guides/recipes/password-reset-support-trace.md`; doc-contract describe block |
| **RECP-02** | Feedback escalation walkthrough (send → webhook → workflow in trace) | **passed** | `guides/recipes/feedback-escalation-workflow.md`; E2E cross-link; doc-contract describe block |

## Automated Gates

| Gate | Result |
|------|--------|
| `mix test test/chimeway/doc_contract_test.exs` | ✅ 37 tests, 0 failures |
| `mix ci.docs` | ✅ exit 0 |
| Recipe files in `mix.exs` extras | ✅ both paths registered |
| Golden-path + journey cross-links | ✅ grep confirmed |

## Plan Must-Haves

### Plan 38-01 — Password reset recipe

| Check | Result |
|-------|--------|
| Persona framing (Support Operator JTBD quote) | ✅ |
| `Chimeway.trigger/3` with `idempotency_key` and `tenant_id` | ✅ |
| `find_traces_for_recipient/2` + `explain_delivery/1` | ✅ |
| Three diagnostic branches (policy, failure, succeeded) | ✅ |
| No forbidden APIs (`Chimeway.Workflow`, `stop_conditions`, etc.) | ✅ |

### Plan 38-02 — Feedback escalation recipe

| Check | Result |
|-------|--------|
| Progress and stop path subsections | ✅ |
| `ProcessFeedbackWorker`, `SignalRouterWorker`, `Signal.track/4` | ✅ |
| `chimeway.delivery.succeeded`, `webhook_received`, `workflow_stopped` | ✅ |
| Demo E2E + golden-path links | ✅ |

### Plan 38-03 — Integration

| Check | Result |
|-------|--------|
| HexDocs extras registration | ✅ |
| Adoption doc cross-links | ✅ |
| Recipe doc-contract tests | ✅ |

## Score

**12/12 must-have checks passed (100%)**

## Human Verification (optional)

| Behavior | Instructions |
|----------|--------------|
| Support Operator IEx walkthrough | Follow RECP-01 snippets after triggering password reset in a host |
| Product Manager narrative | Read RECP-02; open demo feedback E2E describe blocks |

Not blocking automated sign-off.

## Gaps Found

None.
