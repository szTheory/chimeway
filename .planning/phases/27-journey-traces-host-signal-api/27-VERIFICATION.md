---
phase: 27-journey-traces-host-signal-api
verified: 2026-04-30T00:00:00Z
status: gaps_found
score: 4/4 success criteria surface as VERIFIED, but 4 BLOCKER defects make 3 of them unreachable in any real deployment
overrides_applied: 0
gaps:
  - truth: "Workflow inspection surfaces answer 'where is this recipient in the journey and why?' from persisted state alone."
    status: failed
    reason: "create_initial_run/4 hardcodes tenant_id: 'default' for every trigger-created WorkflowRun. Calling explain(real_tenant, run.id) against any production run returns {:error, :not_found} because the row's tenant_id is 'default', not the host's tenant. The inspection API is structurally unreachable for all trigger-created runs in multi-tenant deployments. (CR-04)"
    artifacts:
      - path: "lib/chimeway/workflows.ex"
        issue: "Line 166: tenant_id: \"default\" hardcoded in create_initial_run/4; no test covers the Trigger.fire -> explain round-trip"
    missing:
      - "Thread tenant_id through create_initial_run/4 and its callers (Chimeway.Trigger) so trigger-created runs carry the host's real tenant identity"
      - "Add end-to-end test: Trigger.fire/1 -> Workflows.explain(tenant_id, run.id) -> {:ok, _}"

  - truth: "The signal router worker finds suspended workflows waiting on the signal."
    status: failed
    reason: "SignalRouterWorker declares queue: :signals but no Oban configuration file declares a :signals queue. Only :chimeway_delivery is configured. In any real Oban deployment, enqueued jobs accumulate in oban_jobs as :available forever and are never consumed. Workflows stay :waiting despite signals being tracked. Tests pass only because Oban.Testing :manual mode invokes perform/1 directly, bypassing the queue dispatcher. (CR-03)"
    artifacts:
      - path: "lib/chimeway/dispatch/signal_router_worker.ex"
        issue: "Line 16: use Oban.Worker, queue: :signals — queue :signals is never declared"
      - path: "config/test.exs"
        issue: "Line 25: queues: [chimeway_delivery: 10] — :signals queue absent"
    missing:
      - "Add :signals (or :chimeway_signals) to Oban queues in config/test.exs, config/dev.exs, and host-facing installation docs"
      - "Update worker to use the declared queue name"

  - truth: "The workflow state is appropriately updated and resumed upon matching."
    status: failed
    reason: "route_signal/1 issues a FOR UPDATE lock query outside any transaction (line 379 calls find_runs_waiting_for_signal before Repo.transaction at line 408). PostgreSQL releases row locks at transaction commit; since there is no enclosing transaction at lock time, the locks are released before the write transaction begins. Two concurrent SignalRouterWorker jobs for the same (tenant_id, event_name) can both read the same waiting run, open separate Multi transactions, and each succeed — producing duplicate signal_received transition rows for one logical resumption. (CR-02)"
    artifacts:
      - path: "lib/chimeway/workflows.ex"
        issue: "Lines 379 + 418-428: find_runs_waiting_for_signal (with FOR UPDATE) called outside Repo.transaction; lock is released before Multi at line 408 executes"
    missing:
      - "Move find_runs_waiting_for_signal/2 call inside the Repo.transaction/1 wrapping so FOR UPDATE locks are held through commit"

  - truth: "Tracked signals are durably stored in the database."
    status: failed
    reason: "The migration adds tenant_id NOT NULL to chimeway_workflow_runs without backfilling existing rows. Any host with pre-existing workflow_runs rows (from Phases 24/25/26) will fail this migration with: ERROR: column 'tenant_id' of relation 'chimeway_workflow_runs' contains null values. The migration cannot be applied in upgrade scenarios, leaving the database in a half-migrated state and blocking all Phase 27 functionality. (CR-01)"
    artifacts:
      - path: "priv/repo/migrations/20260430013208_create_chimeway_signals_and_spine.exs"
        issue: "Line 6: add :tenant_id, :string, null: false — no backfill for pre-existing rows, no column default"
    missing:
      - "Add column nullable, execute backfill UPDATE, then enforce NOT NULL constraint in sequence within the same migration"
      - "Also backfill pending_signals = '{}' for pre-existing rows (IN-04)"
---

# Phase 27: Journey Traces & Host Signal API — Verification Report

**Phase Goal:** Expose journey inspection and a stable host signal seam.
**Verified:** 2026-04-30
**Status:** gaps_found
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths (Roadmap Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| SC-1 | Host applications can submit validated workflow progression signals through a stable API boundary. | VERIFIED (in isolation) | `Chimeway.Signal.track/4` exists, uses Ecto.Multi for atomic insert + enqueue, tests 5/5 pass. Blocked in production by CR-01 (migration) and CR-03 (queue). |
| SC-2 | Operators can inspect the current workflow position, completed steps, pending next action, and stop/escalation reasons. | VERIFIED (in isolation) | `explain/2` and `list_traces/3` exist in workflows.ex with tenant_id enforced. 14 inspection tests pass. Blocked in production by CR-04 (tenant_id hardcoded "default" on all trigger-created runs). |
| SC-3 | Journey trace surfaces remain payload-safe and tenancy-aware while spanning multiple deliveries and channels. | VERIFIED | WorkflowTransition.context never receives signal payload by construction; route_signal/1 writes only event_name; list_traces/3 enforces tenant_id. Blocked in production by CR-02 (lock race) and CR-03 (queue). |
| SC-4 | Workflow inspection surfaces answer "where is this recipient in the journey and why?" from persisted state alone. | FAILED | explain/2 queries by (execution_id AND tenant_id). All trigger-created runs carry tenant_id: "default" (CR-04). In any real deployment, explain("real_tenant", run.id) returns {:error, :not_found} for all runs created via the trigger pipeline. The inspection API cannot answer the question it was built to answer. |

**Score:** 3/4 truths verified in isolation. 0/4 truths reachable end-to-end in a real deployment due to compounding blockers.

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/chimeway/signals/signal.ex` | Signal schema for durable event storage | VERIFIED | Binary UUID PK, tenant_id/actor_id/event_name/payload fields, validate_required + validate_length on all three required string fields |
| `lib/chimeway/workflows/workflow_run.ex` | State spine columns in schema | VERIFIED | tenant_id (required), suspended_until, pending_signals (default []), terminal_reason all present in schema and @required_fields/@optional_fields |
| `lib/chimeway/signal.ex` | Chimeway.Signal.track/4 API boundary | VERIFIED | Ecto.Multi wrapping insert + Oban.insert in one Repo.transaction; returns {:ok, signal} or {:error, reason} |
| `lib/chimeway/dispatch/signal_router_worker.ex` | Oban worker for fanning out signals | STUB in production | Module exists and is substantive; perform/1 correctly delegates to route_signal/1. BUT queue: :signals is not declared in any Oban config — jobs are enqueued but never executed outside test mode (CR-03). |
| `lib/chimeway/workflows.ex` | explain/2 and list_traces/3 inspection endpoints | VERIFIED (structurally) | Both functions exist, enforce tenant_id, return {:error, :not_found} on cross-tenant. Unreachable for trigger-created runs due to CR-04. |
| `priv/repo/migrations/20260430013208_create_chimeway_signals_and_spine.exs` | Migration for spine columns and signals table | STUB/BROKEN | Adds tenant_id NOT NULL without backfill — fails on any non-empty chimeway_workflow_runs table (CR-01). |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `lib/chimeway/signal.ex` | `lib/chimeway/signals/signal.ex` | `Multi.insert(:signal, Signal.changeset(...))` | VERIFIED | Line 31: Multi.insert calls Signal.changeset; confirmed in code |
| `lib/chimeway/dispatch/signal_router_worker.ex` | `lib/chimeway/workflows.ex` | `Workflows.route_signal/1` | VERIFIED (structurally) | Line 29-30: case Workflows.route_signal(signal); function exists at workflows.ex:377 |
| `lib/chimeway/workflows.ex` | `chimeway_workflow_runs` | Ecto queries enforcing tenant_id | PARTIAL | explain/2 (line 295) and list_traces/3 (line 335) correctly include `wr.tenant_id == ^tenant_id`. However create_initial_run/4 (line 166) bypasses this by hardcoding "default", making the downstream enforcement hollow for real runs (CR-04). |
| `lib/chimeway/workflows.ex` | `chimeway_workflow_runs` | FOR UPDATE lock in route_signal/1 | BROKEN | Lock issued outside transaction (line 379 before Repo.transaction at line 408); PostgreSQL releases the lock before writes execute (CR-02). |

---

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `explain/2` | WorkflowRun row | Ecto query with LEFT JOIN to WorkflowStep | Yes — live DB query | FLOWING (but hollow for trigger-created runs: all have tenant_id "default") |
| `list_traces/3` | WorkflowTransition rows | Two-query pattern: ownership check then transitions | Yes — live DB queries | FLOWING (but hollow for trigger-created runs: tenant ownership check fails) |
| `route_signal/1` | matched WorkflowRun rows | `find_runs_waiting_for_signal/2` Repo.all | Yes — live DB query | PARTIAL — query finds real rows, but FOR UPDATE lock released before write transaction starts (CR-02) |

---

### Behavioral Spot-Checks

| Behavior | Method | Result | Status |
|----------|--------|--------|--------|
| Signal track inserts durably | Code read: Multi.insert + Repo.transaction | Implementation confirmed | PASS (unit) |
| Oban job actually processed | Config check: queues in all config files | Only chimeway_delivery: 10 — :signals absent | FAIL (CR-03) |
| Migration applies to non-empty DB | Migration code read | NOT NULL without backfill | FAIL (CR-01) |
| explain() for trigger-created run | Code trace: create_initial_run tenant_id | Hardcoded "default" — returns :not_found for real tenant | FAIL (CR-04) |
| FOR UPDATE held through write | workflows.ex lines 379+408 | Lock query outside transaction | FAIL (CR-02) |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| API-01 | 27-01 | Host applications can submit explicit workflow progression signals through a stable public API without mutating durable history directly. | PARTIAL | Signal.track/4 API boundary exists and is substantive. Migration (CR-01) must apply first; Oban queue must be declared (CR-03) before signals actually route in production. |
| OPS-03 | 27-02, 27-03 | Operators can inspect current workflow position, completed steps, pending next action, and the reason a workflow advanced, waited, escalated, or stopped. | PARTIAL | explain/2 and list_traces/3 exist and are correct for hand-constructed fixtures. Unusable for trigger-created runs until CR-04 is resolved. |
| OPS-04 | 27-03 | Journey traces preserve payload-safe explanation across multiple deliveries and channels under one workflow run. | PARTIAL | Structural-traces-only invariant is enforced at write time in route_signal/1. Usable payload safety is blocked until CR-01 (migration), CR-03 (queue), and CR-04 (tenant threading) are fixed. |

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `priv/repo/migrations/20260430013208_create_chimeway_signals_and_spine.exs` | 6 | `add :tenant_id, :string, null: false` with no backfill | BLOCKER | Migration fails on any non-empty table — entire phase cannot be deployed (CR-01) |
| `lib/chimeway/workflows.ex` | 379 vs 408 | `FOR UPDATE` lock issued outside `Repo.transaction` | BLOCKER | Lock semantics are void; concurrent workers can double-resume the same run (CR-02) |
| `lib/chimeway/dispatch/signal_router_worker.ex` | 16 | `queue: :signals` undeclared in Oban config | BLOCKER | All signal routing jobs permanently stuck in :available state in production (CR-03) |
| `lib/chimeway/workflows.ex` | 166 | `tenant_id: "default"` hardcoded in `create_initial_run/4` | BLOCKER | All trigger-created runs share tenant "default"; explain/route_signal unusable for real tenants (CR-04) |
| `lib/chimeway/workflows/workflow_run.ex` | 54-63 | No `validate_length(:tenant_id, min: 1)` | WARNING | Empty string tenant_id passes changeset validation; asymmetry with Signal schema which does validate this (WR-03) |
| `lib/chimeway/workflows.ex` | 330 | `_opts \\ []` ignores `:limit` option documented in @doc | WARNING | Documented :limit opt silently ignored; unbounded query for long-running workflows (WR-06) |

---

### Human Verification Required

None. All gaps are deterministically verifiable from code analysis.

---

## Gaps Summary

Phase 27 delivers a structurally complete Signal API and inspection surface — the code compiles, the schemas are correct, the tenant-isolation logic is properly implemented in queries, and 26 tests pass. However, four compounding BLOCKER defects make the entire phase non-functional in any real deployment:

**CR-01 (Migration):** The migration cannot be applied to any database that already has workflow_runs rows (created by Phases 24/25/26). The `NOT NULL` constraint with no backfill will abort the migration, leaving the database in a half-applied state. No Phase 27 functionality can deploy until this is fixed.

**CR-02 (Lock semantics):** `route_signal/1` acquires `FOR UPDATE` row locks outside any transaction. The locks are released immediately upon query return, before the write transaction begins. Two concurrent SignalRouterWorker jobs for the same signal event can both read the same waiting run and produce duplicate `signal_received` transition records — violating the audit-truth and idempotency guarantees the module docstring claims.

**CR-03 (Oban queue):** `SignalRouterWorker` uses queue `:signals`, which is not declared in any Oban configuration file. In any environment where Oban actually processes queues (dev, staging, production), every `Signal.track/4` call inserts a job that is never consumed. Workflows remain `:waiting` permanently. Tests pass only because `Oban.Testing :manual` mode invokes `perform_job/2` directly.

**CR-04 (Tenant threading):** `create_initial_run/4` hardcodes `tenant_id: "default"`. Every WorkflowRun created via `Chimeway.Trigger` carries this literal. Calling `Workflows.explain("acme", run.id)` against any trigger-created run returns `{:error, :not_found}` because the row's tenant is `"default"`, not `"acme"`. The inspection API cannot serve its primary purpose — answering "where is this recipient?" — for any run created through the normal trigger flow. Signal routing via `route_signal/1` also fails to match trigger-created runs unless the host signals using tenant `"default"`, which collapses the entire tenant-isolation story.

**Root cause pattern:** CR-01 and CR-04 stem from the same underlying gap — the phase correctly built tenant-awareness into the new API surfaces but did not thread tenant identity through the existing trigger pipeline. CR-02 and CR-03 are independent implementation defects where the test isolation mode masked production failures.

---

_Verified: 2026-04-30_
_Verifier: Claude (gsd-verifier)_
