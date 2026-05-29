---
phase: 49-inbox-read-signal
reviewed: 2026-05-29T00:00:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - lib/chimeway/inbox.ex
  - test/chimeway/inbox_state_transition_test.exs
  - test/chimeway/orchestration/workflow_progression_test.exs
  - guides/flows/multi-step-journeys.md
  - test/chimeway/doc_contract_test.exs
findings:
  critical: 0
  warning: 1
  info: 2
  total: 3
status: issues
---

# Phase 49: Code Review Report

**Reviewed:** 2026-05-29  
**Depth:** standard  
**Files Reviewed:** 5  
**Status:** issues

## Summary

Phase 49 implements READ-02/READ-03 cleanly: inbox lifecycle updates are recipient-scoped, first-transition signal emission is atomic via `is_nil(field)` in `update_all`, tenant resolution is server-side (WorkflowRun → Delivery fallback, skip when nil), and tests plus doc contracts align with shipped behavior. All 120 targeted tests pass.

No critical security defects found. Recipient identity is enforced on every mutation path; wrong-recipient calls return `{:error, :not_found}` without emitting signals. Tenant ID is never caller-supplied.

One operational warning remains around the intentional D-07 decoupling: a failed `Signal.track/4` after a successful lifecycle write cannot be recovered via re-mark.

## Critical Issues

None.

## Warnings

### WR-01: Failed signal emission is not recoverable after lifecycle commit

**File:** `lib/chimeway/inbox.ex:71-84, 113-121`  
**Issue:** On first `mark_read`/`mark_seen`, `Repo.update_all/3` commits `read_at`/`seen_at` before `Signal.track/4` runs in a separate transaction. `emit_inbox_signal/4` always returns `:ok` regardless of `Signal.track/4` outcome. If signal insert/enqueue fails, a subsequent re-mark hits the `{0, _}` branch, sees the timestamp already set, and returns `:ok` without retrying emission. Waiting workflows would not resume despite the inbox showing read/seen.

This matches D-07 (lifecycle success independent of signal track) but creates a durable inconsistency under transient DB/Oban failures.

**Fix:** Consider one of:
- Emit signal inside the same `Repo.transaction` as the lifecycle update (conflicts with current D-07 — would need decision change), or
- On `{0, _}` when field is set but no matching signal exists for this notification/event, enqueue a compensating signal (outbox/reconciliation), or
- At minimum, log/telemetry on `{:error, reason}` from `Signal.track/4` so operators can reconcile manually.

```elixir
case Signal.track(tenant_id, recipient_identity, event_name, %{"notification_id" => notification_id}) do
  {:ok, _} -> :ok
  {:error, reason} ->
    # :telemetry.execute([:chimeway, :inbox, :signal_failed], %{}, %{reason: reason, ...})
    :ok
end
```

## Info

### IN-01: No E2E integration test for `mark_seen` → workflow resume

**File:** `test/chimeway/orchestration/workflow_progression_test.exs:401-446`  
**Issue:** Integration coverage proves `Chimeway.mark_read/3` → `SignalRouterWorker` → `:waiting` → `:active` resume. The journey guide documents both `chimeway.notification.read` and `chimeway.notification.seen` as canonical `cancel_signals`, and unit tests cover seen emission, but there is no progression sibling test for `mark_seen` early exit.

**Fix:** Add a parallel describe test using a workflow fixture with `cancel_signals: ["chimeway.notification.seen"]` and assert `Chimeway.mark_seen/3` resumes the run (low priority — routing logic is event-name-agnostic).

### IN-02: `resolve_tenant_id/1` WorkflowRun query is unordered

**File:** `lib/chimeway/inbox.ex:94-101`  
**Issue:** `WorkflowRun` lookup uses `limit: 1` without `order_by`. If multiple runs ever exist for one `notification_id`, tenant resolution is non-deterministic. Normal Chimeway invariants likely enforce one run per notification, so this is defensive polish only.

**Fix:** Add `order_by: [asc: wr.inserted_at]` (or `desc` if latest preferred) to match the Delivery fallback pattern.

---

## Security Assessment

| Concern | Result |
|---------|--------|
| Cross-recipient access | **Pass** — all `update_all` queries filter `recipient_identity`; wrong recipient tested |
| Cross-tenant signal routing | **Pass** — `tenant_id` resolved from notification's WorkflowRun/Delivery, not caller input; `route_signal/1` enforces tenant + actor match |
| Duplicate signal emission | **Pass** — `is_nil(field)` guard + re-mark disambiguation prevents duplicate rows |
| Trace payload leakage (READ-03) | **Pass** — integration test asserts `signal_received` context is event name only |
| IDOR on notification_id | **Mitigated at API layer** — host must authenticate before calling `mark_read`; engine correctly scopes by recipient |

## Test & Doc Verification

- `mix test test/chimeway/inbox_state_transition_test.exs test/chimeway/orchestration/workflow_progression_test.exs test/chimeway/doc_contract_test.exs` — **120 tests, 0 failures**
- Doc contract flipped from Phase 48 deferral to shipped READ-02 assertions
- Journey guide §7 inbox lifecycle section matches implementation

---

_Reviewed: 2026-05-29_  
_Reviewer: Claude (gsd-code-reviewer)_  
_Depth: standard_
