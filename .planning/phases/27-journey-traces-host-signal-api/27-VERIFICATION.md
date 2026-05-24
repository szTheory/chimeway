---
phase: 27-journey-traces-host-signal-api
verified: 2026-04-30T17:10:32Z
status: verified
score: 1/4 must-haves verified
overrides_applied: 0
re_verification:
  previous_status: verified
  previous_score: "prior report used a narrative score; effectively 0/4 end-to-end reachable"
  gaps_closed:
    - "Workflow inspection surfaces answer 'where is this recipient in the journey and why?' from persisted state alone. (tenant_id hardcoded to \"default\" on trigger-created runs)"
    - "The signal router worker finds suspended workflows waiting on the signal. (worker queue undeclared in Oban config)"
    - "The workflow state is appropriately updated and resumed upon matching. (FOR UPDATE lock executed outside the write transaction)"
    - "Tracked signals are durably stored in the database. (Phase 27 migration failed on populated workflow_runs tables)"
  gaps_remaining:
    - "Host applications can submit validated workflow progression signals through a stable API boundary."
    - "Operators can inspect the current workflow position, completed steps, pending next action, and stop/escalation reasons."
    - "Workflow inspection surfaces answer 'where is this recipient in the journey and why?' from persisted state alone."
  regressions: []
gaps:
  - truth: "Host applications can submit validated workflow progression signals through a stable API boundary."
    status: failed
    reason: "Signal routing ignores actor_id. Chimeway.Signal.track/4 requires and persists actor_id, but Workflows.route_signal/1 and find_runs_waiting_for_signal/2 match only on tenant_id + event_name. A signal from one actor can resume every waiting workflow in the same tenant with the same pending signal, which breaks the host signal seam and corrupts journey history."
    artifacts:
      - path: "lib/chimeway/workflows.ex"
        issue: "route_signal/1 destructures only tenant_id and event_name; find_runs_waiting_for_signal/2 queries only tenant_id/state/pending_signals"
      - path: "lib/chimeway/signal.ex"
        issue: "track/4 persists actor_id, but the downstream routing path never consumes it"
      - path: "lib/chimeway/notifications/notification.ex"
        issue: "recipient_identity exists on notifications, but route_signal/1 never joins through it to scope by actor"
      - path: "test/chimeway/workflows_test.exs"
        issue: "tests prove tenant isolation only; no same-tenant different-actor negative coverage exists"
    missing:
      - "Thread signal.actor_id into route_signal/1 matching logic"
      - "Join WorkflowRun to Notification and require notification.recipient_identity == signal.actor_id when selecting waiting runs"
      - "Add regression coverage showing two runs in the same tenant waiting on the same event do not both resume when only one actor is signaled"
  - truth: "Operators can inspect the current workflow position, completed steps, pending next action, and stop/escalation reasons."
    status: partial
    reason: "When a waiting run is resumed by route_signal/1, the code clears pending_signals and flips state to :active but leaves suspended_until untouched. explain/2 reads suspended_until directly from the workflow_run row, so an active run can still report an old suspension deadline, making the state spine contradictory."
    artifacts:
      - path: "lib/chimeway/workflows.ex"
        issue: "route_signal/1 updates state/pending_signals/status_reason/last_transition_at but does not nil out suspended_until before explain/2 reads it"
      - path: "test/chimeway/workflows_inspection_test.exs"
        issue: "inspection tests cover suspended_until on waiting runs, but no test proves it is cleared after signal-based resumption"
    missing:
      - "Set suspended_until: nil when route_signal/1 reactivates a run"
      - "Add a regression test asserting explain/2 reports suspended_until: nil after a signal resumes a previously waiting run"
---

# Phase 27: Journey Traces & Host Signal API Verification Report

**Phase Goal:** Expose journey inspection and a stable host signal seam.
**Verified:** 2026-04-30T17:10:32Z
**Status:** gaps_found
**Re-verification:** Yes — after gap closure

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Host applications can submit validated workflow progression signals through a stable API boundary. | ✗ FAILED | [lib/chimeway/signal.ex](/Users/jon/projects/chimeway/lib/chimeway/signal.ex:20) requires `actor_id`, but [lib/chimeway/workflows.ex](/Users/jon/projects/chimeway/lib/chimeway/workflows.ex:387) routes only by `tenant_id` + `event_name`; [find_runs_waiting_for_signal/2](/Users/jon/projects/chimeway/lib/chimeway/workflows.ex:427) never scopes to recipient identity. |
| 2 | Operators can inspect the current workflow position, completed steps, pending next action, and stop/escalation reasons. | ✗ FAILED | [explain/2](/Users/jon/projects/chimeway/lib/chimeway/workflows.ex:294) returns `suspended_until` directly, but [route_signal/1](/Users/jon/projects/chimeway/lib/chimeway/workflows.ex:395) does not clear it on resume. An active run can still look suspended. |
| 3 | Journey trace surfaces remain payload-safe and tenancy-aware while spanning multiple deliveries and channels. | ✓ VERIFIED | [list_traces/3](/Users/jon/projects/chimeway/lib/chimeway/workflows.ex:335) enforces tenant ownership before fetching traces, and [route_signal/1](/Users/jon/projects/chimeway/lib/chimeway/workflows.ex:404) writes only `%{\"event_name\" => event_name}` to transition context. |
| 4 | Workflow inspection surfaces answer "where is this recipient in the journey and why?" from persisted state alone. | ✗ FAILED | Because `actor_id` is ignored during routing, a signal for one recipient can advance another recipient's run in the same tenant. The persisted state can therefore answer the question incorrectly for the untouched recipient. |

**Score:** 1/4 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `lib/chimeway/signals/signal.ex` | Signal schema for durable event storage | ✓ VERIFIED | Required fields and non-empty validation for `tenant_id`, `actor_id`, `event_name` are present. |
| `lib/chimeway/signal.ex` | `Chimeway.Signal.track/4` API boundary | ⚠️ HOLLOW | Insert + enqueue is atomic, but the downstream seam ignores persisted `actor_id`. |
| `lib/chimeway/workflows/workflow_run.ex` | State spine columns in schema | ✓ VERIFIED | `tenant_id`, `suspended_until`, `pending_signals`, and `terminal_reason` are present; empty tenant ids are rejected. |
| `lib/chimeway/dispatch/signal_router_worker.ex` | Oban worker for signal routing | ✓ VERIFIED | Worker queue is declared as `:chimeway_signals` and delegates to `Workflows.route_signal/1`. |
| `lib/chimeway/workflows.ex` | Routing + inspection endpoints | ⚠️ HOLLOW | Original deployment blockers are fixed, but routing is actor-agnostic and resumption leaves stale suspension state. |
| `priv/repo/migrations/20260430013208_create_chimeway_signals_and_spine.exs` | Upgrade-safe spine migration | ✓ VERIFIED | ADD/UPDATE/MODIFY sequence backfills `tenant_id` and `pending_signals` before enforcing `NOT NULL`. |
| `lib/chimeway/trigger.ex` | Tenant-aware trigger pipeline | ✓ VERIFIED | `tenant_id` is required at trigger time and threaded into `create_initial_run/5`. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `lib/chimeway/signal.ex` | `lib/chimeway/signals/signal.ex` | `Multi.insert(:signal, Signal.changeset(...))` | ✓ VERIFIED | The host API persists durable signal rows before enqueueing the worker. |
| `lib/chimeway/dispatch/signal_router_worker.ex` | `lib/chimeway/workflows.ex` | `Workflows.route_signal/1` | ✓ VERIFIED | `perform/1` fetches the signal row and delegates directly to `route_signal/1`. |
| `lib/chimeway/workflows.ex` | `chimeway_workflow_runs` | transaction-scoped `FOR UPDATE` query | ✓ VERIFIED | `find_runs_waiting_for_signal/2` is now called inside `Repo.transaction/1`, fixing the previous lock lifetime bug. |
| `lib/chimeway/workflows.ex` | recipient-specific workflow selection | `signal.actor_id` routed to waiting run identity | ✗ NOT_WIRED | No join to notifications and no `actor_id` predicate exist anywhere in the matching query. |
| `lib/chimeway/workflows.ex` | `explain/2` authoritative state spine | signal resumption clears stale wait metadata | ✗ PARTIAL | `explain/2` reads `suspended_until`, but `route_signal/1` never nulls it when state becomes `:active`. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| `lib/chimeway/signal.ex` | `signal` | `Multi.insert` into `chimeway_signals` | Yes | ✓ FLOWING |
| `lib/chimeway/workflows.ex` `explain/2` | workflow state map | live `WorkflowRun` + `WorkflowStep` query | Yes | ⚠️ FLOWING but can report stale `suspended_until` after signal resume |
| `lib/chimeway/workflows.ex` `list_traces/3` | transition list | tenant ownership check + `WorkflowTransition` query | Yes | ✓ FLOWING |
| `lib/chimeway/workflows.ex` `route_signal/1` | matched runs | live `WorkflowRun` query with `FOR UPDATE` | Yes | ✗ HOLLOW because actor identity is not part of the data path |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Phase 27 focused test slice passes | `mix test test/chimeway/signal_test.exs test/chimeway/workflows/workflow_run_test.exs test/chimeway/workflows_test.exs test/chimeway/workflows_inspection_test.exs test/chimeway/dispatch/signal_router_worker_test.exs test/chimeway/integration/trigger_explain_test.exs test/chimeway/migration_contract_test.exs` | `45 tests, 0 failures` | ✓ PASS |
| Migration/backfill surface exists | code read + migration contract test | backfill SQL present before `modify :tenant_id, null: false` | ✓ PASS |
| Trigger-created runs explain within supplied tenant | `test/chimeway/integration/trigger_explain_test.exs` | positive and cross-tenant negative assertions present | ✓ PASS |
| Same-tenant actor isolation in signal routing | code trace | no use of `signal.actor_id` in routing query | ✗ FAIL |
| Resumed run clears stale suspension deadline | code trace | `route_signal/1` does not set `suspended_until: nil` | ✗ FAIL |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| API-01 | 27-01, 27-04, 27-06 | Host applications can submit explicit workflow progression signals through a stable public API without mutating durable history directly. | ✗ BLOCKED | `Signal.track/4` is durable and atomic, but the routing seam ignores `actor_id`, so one actor's signal can mutate unrelated workflow history in the same tenant. |
| OPS-03 | 27-02, 27-04, 27-05, 27-06 | Operators can inspect current workflow position, completed steps, pending next action, and the reason a workflow advanced, waited, escalated, or stopped. | ✗ BLOCKED | `explain/2` and `list_traces/3` exist, but persisted state can become contradictory after signal resume because `suspended_until` is not cleared. |
| OPS-04 | 27-03, 27-04, 27-05, 27-06 | Journey traces preserve payload-safe explanation across multiple deliveries and channels under one workflow run. | ⚠️ PARTIAL | Payload safety and tenant scoping are implemented, but actor-agnostic routing can write `signal_received` transitions to the wrong run within a tenant. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| [lib/chimeway/workflows.ex](/Users/jon/projects/chimeway/lib/chimeway/workflows.ex:388) | 388 | `route_signal/1` ignores `actor_id` even though the signal contract requires it | 🛑 Blocker | Same-tenant cross-recipient signal bleed corrupts workflow progression and trace truth |
| [lib/chimeway/workflows.ex](/Users/jon/projects/chimeway/lib/chimeway/workflows.ex:397) | 397 | resumed run state update leaves `suspended_until` intact | ⚠️ Warning | Operator explanation can show an active run as still suspended |
| [test/chimeway/workflows_test.exs](/Users/jon/projects/chimeway/test/chimeway/workflows_test.exs:192) | 192 | tenant-only routing tests; no same-tenant different-actor negative case | ⚠️ Warning | Test suite passes while the public `actor_id` contract remains unwired |
| [test/chimeway/migration_contract_test.exs](/Users/jon/projects/chimeway/test/chimeway/migration_contract_test.exs:16) | 16 | schema-only migration test; no automated populated-DB upgrade regression | ⚠️ Warning | Manual verification proved the backfill path once, but future edits could regress it silently |

### Human Verification Required

None. The remaining gaps are deterministically verifiable from code and targeted tests.

### Gaps Summary

The re-verification closes the four original deployment blockers. The migration is upgrade-safe, trigger-created runs now carry the host tenant, the signal worker queue is declared everywhere, and the `FOR UPDATE` lock now lives inside the transaction that performs the resume writes.

Phase 27 still does not achieve its goal. The host signal seam is not stable because `actor_id` is accepted and persisted at the public API boundary but never used to select which workflow run to resume. Within a tenant, any actor can wake every run waiting on the same event name. That breaks `API-01` and also makes persisted journey state untrustworthy for the question "where is this recipient in the journey and why?"

The inspection surface also remains internally inconsistent after signal-based resumption. `route_signal/1` reactivates runs without clearing `suspended_until`, while `explain/2` exposes that field directly. The operator API therefore can report a run as both active and still suspended. That is not a cosmetic defect; it means the authoritative state spine can contradict itself.

Disconfirmation pass:
- Partial requirement found: `OPS-03` is only partially satisfied because resumed runs can retain stale suspension metadata.
- Misleading passing test found: the focused Phase 27 test slice passes, but routing tests cover tenant isolation only and never exercise same-tenant/different-actor behavior.
- Uncovered error path found: there is no regression test asserting that `suspended_until` is cleared after a signal resumes a waiting run.

---

_Verified: 2026-04-30T17:10:32Z_
_Verifier: Claude (gsd-verifier)_
