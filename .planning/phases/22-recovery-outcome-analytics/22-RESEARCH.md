# Phase 22: Recovery & Outcome Analytics - Research

**Researched:** 2026-04-28 [VERIFIED: system date]
**Domain:** Durable reconciliation of undispatched delivery rows and aggregate outcome analytics over the canonical delivery lifecycle [VERIFIED: .planning/phases/22-recovery-outcome-analytics/22-CONTEXT.md, lib/chimeway/deliveries.ex, lib/chimeway/traces.ex]
**Confidence:** HIGH on repo fit and architectural direction [VERIFIED: codebase inspection]

<user_constraints>
## User Constraints (from CONTEXT.md)

Copied from `.planning/phases/22-recovery-outcome-analytics/22-CONTEXT.md` without scope expansion. [VERIFIED: .planning/phases/22-recovery-outcome-analytics/22-CONTEXT.md]

### Locked Decisions
- **D-01:** Reconciliation will recover "stuck" deliveries by re-enqueuing them to the dispatcher and mutating the canonical delivery rows in place, without deleting or replacing them. [VERIFIED]
- **D-02:** Detection of undispatched persisted deliveries will rely on querying Chimeway's schema state without interrogating the Oban queue. [VERIFIED]
- **D-03:** Aggregate query capabilities will be implemented as new functions within `Chimeway.Traces` rather than introducing a separate top-level analytics module. [VERIFIED]
- **D-04:** Outcome analytics will aggregate directly over `chimeway_deliveries.status`, `chimeway_deliveries.orchestration_state`, and `chimeway_deliveries.suppression_reason` rather than traversing attempt history. [VERIFIED]

### Deferred Ideas (OUT OF SCOPE)
- Workflow journeys and escalation trees.
- Broad channel expansion.
- Hosted dashboards or queue-native recovery tooling.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| OPS-01 | Operators can detect and reconcile persisted events or deliveries that were never fully dispatched after trigger-time failures. [VERIFIED: .planning/REQUIREMENTS.md] | Add durable delivery-state queries for recoverable rows plus a reconciliation service that reuses existing dispatch entrypoints and preserves explanation metadata on the same row. [VERIFIED: lib/chimeway/deliveries.ex, lib/chimeway/dispatch/oban.ex, lib/chimeway/dispatch/oban_worker.ex, lib/chimeway/trigger.ex] |
| OPS-02 | Operators can query aggregate outcomes by notification key, channel, and lifecycle result, including sent, suppressed, delayed, digested, failed, and exhausted flows. [VERIFIED: .planning/REQUIREMENTS.md] | Extend `Chimeway.Traces` with grouped aggregate queries over `events`, `notifications`, and `deliveries`, using durable status/orchestration/suppression facts rather than attempts or queue state. [VERIFIED: lib/chimeway/traces.ex, lib/chimeway/deliveries.ex] |
</phase_requirements>

## Recommendation

Phase 22 should stay on the delivery row as the single source of operational truth. Recovery should detect only Chimeway-owned stuck states, reconcile them by reusing the existing dispatcher, and stamp durable metadata describing the recovery source and time on the same `chimeway_deliveries` row. Analytics should live under `Chimeway.Traces` and aggregate directly from canonical delivery state rather than reverse-engineering intent from attempts or Oban jobs. [VERIFIED: AGENTS.md, .planning/phases/22-recovery-outcome-analytics/22-CONTEXT.md, lib/chimeway/deliveries.ex, lib/chimeway/dispatch/oban.ex, lib/chimeway/traces.ex]

The strongest repo fit is a three-slice plan:
1. Add delivery-level detection and reconciliation primitives.
2. Expose an operator-facing recovery API that safely re-drives stuck rows through normal dispatch.
3. Add aggregate outcome query APIs and tests to `Chimeway.Traces`.

This mirrors how prior phases split durable state contracts first, runtime behavior second, and explainability/operator surfaces last. [VERIFIED: .planning/phases/18-scheduled-resume-deferred-dispatch/18-CONTEXT.md, .planning/phases/20-digest-emission-explainability/20-RESEARCH.md, .planning/phases/21-template-versioning-rendering-contracts/21-01-PLAN.md]

## Why This Fits The Repo

### Existing delivery helpers already encode the house style for lifecycle convergence

`list_due_deferred_deliveries/1`, `resume_deferred_delivery/2`, `cancel_deferred_delivery/3`, and `exhaust_delivery/1` all mutate canonical rows in place through named helpers rather than ad hoc caller updates. Recovery should follow that exact pattern. [VERIFIED: lib/chimeway/deliveries.ex]

### Dispatcher seams already accept `delivery_id` and treat queue state as disposable

`Chimeway.Dispatch.Oban.dispatch_delivery/2` and `Chimeway.Dispatch.ObanWorker.perform/1` operate from durable delivery IDs and ignore jobs for rows that are no longer actionable. That makes re-drive by delivery ID a natural fit and keeps Oban out of the business-truth layer. [VERIFIED: lib/chimeway/dispatch/oban.ex, lib/chimeway/dispatch/oban_worker.ex]

### Trace surfaces are already the operator entrypoint

`Chimeway.Traces` owns `get_trace/2`, recipient lookups, correlation lookups, and `explain_delivery/2`. Adding outcome aggregates there preserves one obvious operator API instead of splitting analytics into a second context. [VERIFIED: lib/chimeway/traces.ex]

## Recommended Architecture

### 1. Detect recoverable stuck rows from Chimeway state only

Recovery should query `chimeway_deliveries` for actionable rows such as:
- `status == :pending` and `orchestration_state == :ready` older than a safe threshold, meaning planning persisted the row but dispatch never completed. [VERIFIED: .planning/phases/22-recovery-outcome-analytics/22-CONTEXT.md, lib/chimeway/deliveries.ex]
- Optionally `status == :failed` rows that are not terminally exhausted and have no active retry path, if planning confirms the product model wants manual re-drive for these as well. [ASSUMED from phase goal]

The first slice should not consult `oban_jobs`; the queue is an execution artifact and the project has already locked that principle. [VERIFIED: .planning/phases/20-digest-emission-explainability/20-CONTEXT.md, .planning/phases/22-recovery-outcome-analytics/22-CONTEXT.md]

### 2. Reconcile by reusing dispatcher entrypoints and mutating the same row

Recovery should add one explicit helper or service that:
- reloads the delivery by ID,
- proves it is still actionable under the same durable query rules,
- stamps recovery metadata such as `recovery_source`, `recovered_at`, and optional operator reason,
- re-enqueues through the configured dispatcher with `dispatch_delivery(delivery_id, ...)`,
- returns tagged outcomes like `{:ok, delivery}`, `{:noop, delivery}`, or `{:error, reason}`.

This mirrors the deferred-resume posture: the row identity stays the same, history remains queryable, and duplicate recovery attempts collapse to no-op behavior instead of creating replacement rows. [VERIFIED: lib/chimeway/deliveries.ex, test/chimeway/orchestration/deferred_resume_test.exs]

### 3. Keep recovery explainable on the delivery row

Recovery must not silently "fix" a row. The durable row should expose enough fact to answer:
- why the row was considered stuck,
- when it was re-driven,
- what source initiated the recovery,
- whether the recovery actually changed state or was a no-op.

The simplest fit is delivery metadata, because prior lifecycle helpers already record durable machine-readable facts there for policy checkpoints, resume events, and correlation continuity. [VERIFIED: lib/chimeway/deliveries.ex, lib/chimeway/traces.ex]

### 4. Add grouped aggregate queries under `Chimeway.Traces`

Outcome analytics should group over durable delivery facts joined back to notification/event identity:
- group keys: `notification_key`, `channel`, optional time window.
- outcome buckets: `sent`, `suppressed`, `delayed`, `digested`, `failed`, `exhausted`.

Recommended mapping:
- `sent` -> `status == :succeeded`
- `suppressed` -> `status == :suppressed`
- `delayed` -> `status == :pending and orchestration_state == :deferred` or equivalent currently-deferred rows
- `digested` -> `status == :digested` or digest-linked source outcome
- `failed` -> `status == :failed`
- `exhausted` -> `status == :cancelled and suppression_reason == "retries_exhausted"`

This keeps aggregate semantics derivable from durable row state and explicit reasons instead of attempt-history heuristics. [VERIFIED: .planning/phases/22-recovery-outcome-analytics/22-CONTEXT.md, lib/chimeway/deliveries.ex, lib/chimeway/traces.ex]

## Recommended Project Structure

```text
lib/chimeway/
├── deliveries.ex                  # recoverable-row query + reconciliation helper
├── traces.ex                      # aggregate outcome queries
├── traces/outcome_summary.ex      # optional typed result struct if planner chooses one
└── dispatch/                      # no new queue-truth logic; reuse existing dispatcher seams

test/chimeway/
├── deliveries_test.exs            # recovery query/helper behavior
├── traces_test.exs                # aggregate outcome queries
├── orchestration/recovery_test.exs# focused recovery flows, if the planner wants a new file
└── integration/delivery_lifecycle_test.exs
```

## Implementation Patterns To Use

### Pattern 1: Named lifecycle helpers on `Chimeway.Deliveries`

Do not let callers hand-roll `Repo.update_all` against delivery state. Add explicit helpers the same way the repo already does for deferred resume, cancellation, and exhaustion. [VERIFIED: lib/chimeway/deliveries.ex]

### Pattern 2: Durable identifiers only in recovery execution

If recovery can be triggered asynchronously later, any job or API should carry only `delivery_id` and operator-supplied reason/source values. Raw event payload or queue snapshots do not belong in the execution contract. [VERIFIED: lib/chimeway/dispatch/oban_worker.ex]

### Pattern 3: Analytics from joins, not preload-heavy N+1 loops

`Traces.find_traces_for_recipient/2` already uses explicit joins to avoid N+1 reads. Outcome aggregation should do the same with grouped Ecto queries across `events`, `notifications`, and `deliveries`. [VERIFIED: lib/chimeway/traces.ex]

### Pattern 4: Tagged noop semantics for duplicate recovery

Deferred resume already returns `{:noop, delivery}` when the row is no longer actionable. Recovery should preserve this posture so repeated operator actions or retries remain idempotent and explainable. [VERIFIED: lib/chimeway/deliveries.ex]

## Anti-Patterns To Avoid

- **Oban-driven detection:** `oban_jobs` state is not durable business truth here. [VERIFIED: .planning/phases/22-recovery-outcome-analytics/22-CONTEXT.md]
- **Replacement-row recovery:** creating a second delivery would break trace continuity and operator trust. [VERIFIED: AGENTS.md, .planning/phases/22-recovery-outcome-analytics/22-CONTEXT.md]
- **Attempt-history analytics:** attempts answer "what happened during provider execution", not the canonical product outcome buckets requested in OPS-02. [VERIFIED: .planning/phases/22-recovery-outcome-analytics/22-CONTEXT.md]
- **Opaque recovery mutations:** every recovery path needs durable metadata or trace surface support so operators can explain the intervention later. [VERIFIED: AGENTS.md, lib/chimeway/traces.ex]

## Suggested Plan Split

### Plan 22-01
Lock the durable recovery contract:
- add recoverable-row query helpers and tagged reconciliation outcomes,
- define recovery metadata fields and idempotent no-op behavior,
- add focused unit tests around stuck-row detection and row mutation guards.

### Plan 22-02
Wire operator recovery into the existing dispatch path:
- implement a public recovery API or service around `dispatch_delivery/2`,
- preserve row identity, metadata continuity, and duplicate recovery safety,
- prove trigger/dispatch/recovery interactions through integration coverage.

### Plan 22-03
Add aggregate outcome analytics:
- grouped `Chimeway.Traces` queries by key/channel/outcome,
- explicit bucket mapping for exhausted versus generic cancelled,
- tests proving payload-safe aggregate responses and correct counts.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit with Ecto SQL sandbox. [VERIFIED: test/test_helper.exs, test/support/data_case.ex] |
| Config file | `test/test_helper.exs`. [VERIFIED: test/test_helper.exs] |
| Quick run command | `mix test test/chimeway/deliveries_test.exs test/chimeway/traces_test.exs test/chimeway/integration/delivery_lifecycle_test.exs -x`. [VERIFIED: files exist] |
| Full suite command | `mix test`. [VERIFIED: mix.exs aliases and standard project posture] |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| OPS-01 | Recoverable rows are detected from durable schema state and re-driven safely without replacing delivery identity. [VERIFIED: .planning/REQUIREMENTS.md] | unit + integration | `mix test test/chimeway/deliveries_test.exs test/chimeway/integration/delivery_lifecycle_test.exs -x` | ✅ [VERIFIED: files exist] |
| OPS-02 | Aggregate outcome queries report grouped counts by notification key, channel, and durable lifecycle bucket. [VERIFIED: .planning/REQUIREMENTS.md] | unit | `mix test test/chimeway/traces_test.exs -x` | ✅ [VERIFIED: file exists] |

### Sampling Rate

- **Per task commit:** `mix test test/chimeway/deliveries_test.exs test/chimeway/traces_test.exs -x`
- **Per wave merge:** `mix test`
- **Phase gate:** Full suite green before verification.

### Wave 0 Gaps

- [ ] Add targeted tests covering recoverable ready/pending rows that age past the threshold while terminal, deferred, and already-dispatched rows remain excluded. [VERIFIED: lib/chimeway/deliveries.ex, test/chimeway/deliveries_test.exs]
- [ ] Add recovery integration coverage proving duplicate re-drive attempts no-op once the row is no longer recoverable. [ASSUMED from required idempotency posture]
- [ ] Add aggregate query assertions for `exhausted` versus other `:cancelled` reasons and for currently deferred rows counted as `delayed`. [VERIFIED: lib/chimeway/traces.ex, test/chimeway/traces_test.exs]

## Security Domain

### Applicable Concerns

| Concern | Why It Applies | Standard Mitigation |
|---------|----------------|---------------------|
| Tampering | Recovery mutates existing canonical rows and could hide history if done opaquely. [VERIFIED: phase goal, AGENTS.md] | Use named helpers, durable metadata, and trace-visible recovery facts. [VERIFIED: lib/chimeway/deliveries.ex, lib/chimeway/traces.ex] |
| Repudiation | Operators need to explain that a row was manually or automatically re-driven. [VERIFIED: AGENTS.md] | Stamp `recovery_source` / `recovered_at` style metadata and expose it through traces or recovery results. [ASSUMED from repo patterns] |
| Information Disclosure | Analytics and traces must not widen payload exposure. [VERIFIED: AGENTS.md] | Aggregate only over durable status/key/channel fields and keep payload/provider data out of summary surfaces. [VERIFIED: lib/chimeway/traces.ex] |

## Sources

### Primary

- `.planning/phases/22-recovery-outcome-analytics/22-CONTEXT.md` - locked decisions and scope. [VERIFIED: local file]
- `.planning/REQUIREMENTS.md` - `OPS-01` and `OPS-02`. [VERIFIED: local file]
- `lib/chimeway/deliveries.ex` - lifecycle helpers, durable row mutations, and existing idempotent no-op patterns. [VERIFIED: local file]
- `lib/chimeway/traces.ex` - operator query surface and explanation posture. [VERIFIED: local file]
- `lib/chimeway/dispatch/oban.ex` - dispatcher reuse by delivery ID. [VERIFIED: local file]
- `lib/chimeway/dispatch/oban_worker.ex` - delivery-id-only execution and terminal short-circuit posture. [VERIFIED: local file]
- `test/chimeway/traces_test.exs` - current trace contract and existing OPS-01 assertions. [VERIFIED: local file]
- `test/chimeway/orchestration/deferred_resume_test.exs` - canonical no-op and row-identity recovery analog. [VERIFIED: local file]

### Secondary

- `.planning/phases/20-digest-emission-explainability/20-CONTEXT.md` - queue-state-is-not-truth precedent for operator-facing behavior. [VERIFIED: local file]
- `.planning/phases/20-digest-emission-explainability/20-RESEARCH.md` - prior slice ordering pattern of contract -> runtime -> explainability. [VERIFIED: local file]
- `.planning/phases/21.1-rendering-durability-and-preview-hardening/21.1-RESEARCH.md` - current research/validation artifact structure used in this repo. [VERIFIED: local file]

## RESEARCH COMPLETE
