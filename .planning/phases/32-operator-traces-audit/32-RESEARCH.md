# Phase 32: Operator Traces & Audit - Research

**Researched:** 2026-05-01
**Domain:** Elixir / Ecto read-side projection of already-persisted operator-trace state
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Linkage**
- **D-01:** `WorkflowTransition.delivery_id` FK already exists from Phase 24 (`priv/repo/migrations/20260429170200_create_chimeway_workflow_transitions.exs:17`, indexed line 28, `on_delete: :nilify_all`). Phase 32 ships **no migration**.
- **D-02:** Single write-side change: `Chimeway.Workflows.route_signal/1` adds `delivery_id: Map.get(signal.payload, "delivery_id")` to the `append_transition/2` attrs map. Use `Map.get` (not `Map.fetch!`) — host signals via `Chimeway.Signal.track/4` may legitimately omit `"delivery_id"`; the FK is nullable.
- **D-03:** Phase 25's progression engine already populates `:delivery_id` on every transition (`progression.ex:271, 309, 327, 370, 402, 482`). No change to those write paths.

**Timeline projection**
- **D-04:** Five new event atoms appended to existing flat `%Chimeway.Traces.Explanation{}.timeline` list at strictly contiguous ranks 13..17:
  - `:webhook_received` (13), `:workflow_progressed` (14), `:workflow_waiting` (15), `:workflow_stopped` (16), `:workflow_completed` (17)
- **D-05:** New ranks added as compile-time literal clauses to existing `defp timeline_rank/1` at `lib/chimeway/traces.ex:485-498`. The `_event -> 99` fallback stays at the end. No reordering of pre-Phase-32 ranks.
- **D-06:** `:webhook_received` source = preloaded `DeliveryAttempt` rows (already loaded at `traces.ex:119`). Carries `outcome`, `provider_message_id`, `adapter_module`, `at` from `attempt.inserted_at`.
- **D-07:** `:workflow_*` source = `WorkflowTransition` rows joined on `delivery_id`. Reason→atom dispatch for **only** the four documented progression reasons:
  - `"progressed_on_delivery_outcome"` → `:workflow_progressed`
  - `"waiting_for_step_progression"` → `:workflow_waiting`
  - `"workflow_stopped"` → `:workflow_stopped`
  - `"workflow_completed"` → `:workflow_completed`
- **D-08:** Suppress `"signal_received"`, `"step_activated"`, and `"reactivated_from_wait"` from the `explain_delivery/1` projection (internal cursor events; UI-SPEC rank table deliberately omits them).
- **D-09:** Projection happens inside `Chimeway.Traces.build_timeline/5` (called from `explain_delivery/1` at `traces.ex:133`). New private helper queries `WorkflowTransition` rows scoped by `delivery_id == ^delivery.id`. Tenant scoping is enforced defensively by also filtering through `WorkflowRun.tenant_id == ^delivery.tenant_id` (matches Phase 27's structural-tenant-guard discipline).
- **D-10:** `Chimeway.Workflows.list_traces/3` is **not modified**. New `delivery_id` values surface automatically via struct introspection once D-02 populates them.

**Detail-map shape**
- **D-11:** `:webhook_received` `:detail` (atom keys, ≤6): `outcome`, `provider_message_id`, `adapter_module`, `signal_event_name` (sourced from companion `signal_received` `WorkflowTransition.context["event_name"]` keyed by same `delivery_id`, when present).
- **D-12:** `:workflow_progressed` / `:workflow_stopped` / `:workflow_completed` `:detail` (atom keys, ≤6): `workflow_run_id`, `workflow_step_id`, `workflow_step_key`, `workflow_outcome` (from `transition.context["workflow_outcome"]`), `from_step` / `to_step` (from `transition.context`), `reason` (string copy of `transition.reason`).
- **D-13:** `:workflow_waiting` `:detail`: `workflow_run_id`, `workflow_step_id`, `workflow_step_key`, `due_at` (from `transition.context["due_at"]`), `rule_kind` (e.g. `"wait_until"`).

**PII boundary (strict)**
- **D-14:** Allowed in timeline `:detail`: `delivery_id`, `workflow_run_id`, `workflow_step_id`, `workflow_step_key`, `signal.event_name`, outcome atoms, timestamps, `provider_message_id`.
- **D-15:** **NEVER**: raw `signal.payload` map, `provider_response` body, recipient identity, webhook source IP, headers, raw webhook body.

**Atom safety**
- **D-16:** Five new atoms are **compile-time literals** in the dispatch table. Never `String.to_atom/1`, never `String.to_existing_atom/1` for these names. Phase 31's bounded `String.to_existing_atom/1` at `webhooks/process_feedback_worker.ex:20` stays as-is — Phase 32 does NOT extend that pattern.

**Cross-tenant `:not_found` discipline**
- **D-17:** Cross-tenant access continues to return `{:error, :not_found}` (timing-attack-safe).
- **D-18:** No new public API; no new error tuples. The reserved `{:error, :webhook_link_unavailable}` in UI-SPEC line 211 is **not** introduced.

**Test posture**
- **D-19:** Extend `test/chimeway/traces_test.exs` with new `describe "explain_delivery/1 — webhook + workflow timeline"` block covering UI-SPEC scenarios A/B/C (lines 256-300). Existing set-membership and timestamp-monotonicity assertions (`traces_test.exs:220-244`) stay green.
- **D-20:** Parallel PII-boundary test mirroring `workflows_inspection_test.exs:294-313` against `Explanation.timeline[].detail` for all five new event atoms. Refute keys: `payload`, `data`, `recipient`, `email`, `phone`, `provider_response`.
- **D-21:** Write-path test in `test/chimeway/workflows_test.exs` proving `route_signal/1` populates `transition.delivery_id` from `signal.payload["delivery_id"]` while leaving `transition.context` unchanged from the Phase 31 contract. Existing `workflows_inspection_test.exs:294-313` payload-safety test continues to pass (additive change to a separate column).

### Claude's Discretion
- Module placement of the reason→atom dispatch helper: private function in `Chimeway.Traces`, sibling private module `Chimeway.Traces.WorkflowProjection`, or inline in `build_timeline/5`. Pick the most testable seam consistent with the Phase 27/29 helper layout already in `traces.ex`.
- Whether the `WorkflowTransition` query joins through `WorkflowRun` to enforce tenant scoping or relies solely on the `delivery_id` FK chain. Both are correct; the explicit join is defense-in-depth (recommended).
- Whether `:webhook_received`'s `signal_event_name` is sourced via the companion `signal_received` transition (D-11 default) or via a direct `Signal` row read scoped by `signal.payload["delivery_id"]`. The transition-companion path is preferred (no second query).
- Migration sequencing — there is no migration. Phase ships in code + tests.

### Deferred Ideas (OUT OF SCOPE)
- `{:error, :webhook_link_unavailable}` error tuple (UI-SPEC line 211 reserves it; not needed in Phase 32).
- Reference operator UI / dashboard (v1.4 deferred per `STATE.md:159`).
- Read/unread-driven workflow branching (v1.4 deferred per `STATE.md:158`).
- Telemetry events for `:webhook_received` projection.
- Bulk timeline pagination on `explain_delivery/1`.
- `step_activated` / `reactivated_from_wait` projection (suppressed per D-08; future "verbose trace" mode).
- Bundled vendor adapters in core (PROJECT.md no-vendor-lock-in constraint).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TRAC-01 | Operator timeline traces include asynchronous provider callbacks and the resulting outcome state updates. | `:webhook_received` (rank 13) projects `DeliveryAttempt` rows already preloaded by `explain_delivery/1` at `traces.ex:119`; `:workflow_progressed/_waiting/_stopped/_completed` (ranks 14..17) project `WorkflowTransition` rows joined on the existing `delivery_id` FK. The new `route_signal/1` write-path delta makes the `signal_received` companion row's `delivery_id` populated for `signal_event_name` lookup. |
| TRAC-02 | Trace visibility connects the inbound webhook event back to the specific journey progression step it triggered. | Linkage is the explicit `WorkflowTransition.delivery_id` FK already present in the schema (`workflow_transition.ex:20`, migration line 17). Once D-02 populates it on the `signal_received` row, the timeline projects two co-keyed entries per webhook (`:webhook_received` from `DeliveryAttempt` + `:workflow_progressed/_stopped/_completed` from `WorkflowTransition`), both surfaced together by `(rank, at)` sorting in `Enum.sort_by(&timeline_sort_key/1)` at `traces.ex:418`. `list_traces/3` already returns full `WorkflowTransition` structs, so `delivery_id` materializes via struct introspection (UI-SPEC §C example at lines 290-300 works without API change). |
</phase_requirements>

## Summary

Phase 32 is a **pure read-side projection** over already-persisted state from Phases 24/25/27/29/30/31, plus exactly one write-path delta in `Chimeway.Workflows.route_signal/1` to populate the existing nullable `WorkflowTransition.delivery_id` FK on the `signal_received` row. There is **no migration**, no new struct field on `%Chimeway.Traces.Explanation{}`, no new `WorkflowTransition.reason` strings, and no new `transition.context` keys. The whole phase ships in code + tests with HIGH confidence — every dependency was directly verified by reading the source.

Five compile-time-literal event atoms (`:webhook_received` + four `:workflow_*`) extend the existing `defp timeline_rank/1` table at `lib/chimeway/traces.ex:485-498` at strictly contiguous ranks 13..17. Two new private helpers in `Chimeway.Traces.build_timeline/5` derive the new entries: one from preloaded `DeliveryAttempt` rows (no new query) and one from a single new `WorkflowTransition`-by-`delivery_id` query joined defensively through `WorkflowRun.tenant_id`.

**Primary recommendation:** Land the work as a **single Wave** with three tasks — (1) add the `delivery_id` to the `route_signal/1` `append_transition/2` attrs map, (2) extend `build_timeline/5` with two new private helpers and append five clauses to `timeline_rank/1`, (3) extend three existing test files with the three test bodies specified in D-19/D-20/D-21. The work is small enough that splitting waves would add ceremony without parallelism benefit; no task in this phase can begin before the others are at least scoped, and all three tasks share a single PR-shaped diff.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Webhook receipt persistence | Phase 30 (already shipped) | — | Write-path is in `Chimeway.Webhooks.ProcessFeedbackWorker.perform/1` which records a `DeliveryAttempt` and emits a `Signal`. Phase 32 only **reads** this state; no write-side change. |
| Workflow transition append on signal receipt | `Chimeway.Workflows.route_signal/1` (Phase 27/31, modified) | — | The single write delta in Phase 32 — adds `delivery_id` from `signal.payload["delivery_id"]` to the existing `append_transition/2` attrs map at `lib/chimeway/workflows.ex:412-419`. |
| Workflow progression transition append | `Chimeway.Workflows.Progression` (Phase 25 — unchanged) | — | Already populates `:delivery_id` on every transition (`progression.ex:271, 309, 327, 370, 402, 482`). Phase 32 reads but does not modify. |
| Timeline projection (`:webhook_received`) | `Chimeway.Traces.build_timeline/5` (read-side) | — | Derived from preloaded `attempts` list; no new query. Lives in same module as existing `attempt_entries` builder for symmetry. |
| Timeline projection (`:workflow_*`) | `Chimeway.Traces.build_timeline/5` (read-side) | — | New private helper issues one `WorkflowTransition` query keyed by `delivery_id`, joined defensively through `WorkflowRun.tenant_id`. Reason→atom dispatch is a literal `case`/function-head table. |
| Cross-tenant `:not_found` enforcement | `Chimeway.Traces.explain_delivery/1` (existing) | New `WorkflowTransition` query | Top-level `Repo.one(... where d.id == ^delivery_id)` already returns `nil → {:error, :not_found}`. Defense-in-depth: new helper joins through `WorkflowRun.tenant_id == ^delivery.tenant_id` even though FK chain implies it (Phase 27 idiom — see `workflows.ex:319-322`, `:344-352`). |
| Atom-safety gate | Compile-time literal dispatch (existing pattern) | — | All five new atoms are function-head clauses in `timeline_rank/1` and a new function-head reason→atom dispatch. **Never** `String.to_atom/1` or `String.to_existing_atom/1` in Phase 32. |
| Test infrastructure | ExUnit + `Chimeway.DataCase` (existing) | — | `mix test` runs against the SQL Sandbox. Async `true` for `traces_test.exs`; async `false` for `workflows_test.exs` (existing — preserve). |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Elixir | ~> 1.17 [VERIFIED: `mix.exs:11`] | Application language | Already in use; no version change. |
| Ecto SQL | ~> 3.11 [VERIFIED: `mix.exs` deps] | Persistence and query DSL | Already in use; the new `WorkflowTransition`-by-`delivery_id` query uses the existing `import Ecto.Query` idiom present in both `traces.ex:31` and `workflows.ex:4`. |
| Postgrex | >= 0.0.0 [VERIFIED: `mix.exs` deps] | PostgreSQL driver | Already in use. |
| Jason | ~> 1.4 [VERIFIED: `mix.exs` deps] | JSON serialization | Already in use; not directly touched by Phase 32. |
| ExUnit + `Chimeway.DataCase` | stdlib + project-local [VERIFIED: `test/test_helper.exs:1`, `test/support/data_case.ex`] | Test framework + SQL sandbox | Already in use; new tests slot into existing `describe` blocks. |

### Supporting
None — Phase 32 introduces no new dependencies. Ecto query is enough to express the single new read.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Two-call projection (`DeliveryAttempt` for `:webhook_received` + `WorkflowTransition` join for `:workflow_*`) | Single join query joining `DeliveryAttempt` to `WorkflowTransition` on `delivery_id` | Possible micro-optimization but loses the "two distinct sources" semantic separation that makes D-08 suppression and D-15 PII-boundary trivial to enforce. **Reject** — the two-row model (one row per source) is the locked architecture from D-06/D-07. |
| Source `:webhook_received` from `Signal` rows directly | Query `Signal` by `payload["delivery_id"]` | Adds a second read, surfaces `payload` (PII risk), and provides no operator benefit because `DeliveryAttempt` is already preloaded. **Reject** — locked in D-06. |
| Source `:webhook_received` from `WorkflowTransition.reason = "signal_received"` | Same join as `:workflow_*` projection | Misses UI-SPEC line 200's "delivery exists, no workflow run linked" case where no transition row exists. **Reject** — locked in D-06. |

**Installation:** No new packages. The phase is pure code and test additions in existing modules.

**Version verification:** Confirmed `mix.exs:11` declares `elixir: "~> 1.17"`, `ecto_sql: "~> 3.11"`, `postgrex: ">= 0.0.0"`, `jason: "~> 1.4"`. No package upgrades required.

## Architecture Patterns

### System Architecture Diagram

```
                    ┌──────────────────────────────────────────┐
                    │  Provider webhook (Phase 30 — unchanged) │
                    └─────────────────────┬────────────────────┘
                                          │
                                          ▼
            ┌───────────────────────────────────────────────────┐
            │ Chimeway.Webhooks.ProcessFeedbackWorker.perform/1 │
            │   (lib/chimeway/webhooks/process_feedback_worker  │
            │    .ex — unchanged in Phase 32)                   │
            │  • Deliveries.record_attempt/2                    │
            │       → INSERT chimeway_delivery_attempts         │
            │         (outcome, provider_message_id,            │
            │          adapter_module)                          │
            │  • Chimeway.Signal.track/4                        │
            │       → INSERT chimeway_signals                   │
            │       payload = %{"delivery_id" => delivery.id,   │
            │                  "status" => to_string(outcome)}  │
            │       enqueues SignalRouterWorker                 │
            └───────────────┬───────────────────────────────────┘
                            │
                            ▼
        ┌──────────────────────────────────────────────────────┐
        │ Chimeway.Dispatch.SignalRouterWorker.perform/1       │
        │   → Chimeway.Workflows.route_signal/1                │
        │     (workflows.ex:393-430)                           │
        │                                                      │
        │   ★ PHASE 32 SINGLE WRITE DELTA at line 412-419:    │
        │     append_transition/2 attrs gain                   │
        │     :delivery_id => Map.get(signal.payload,          │
        │                              "delivery_id")          │
        │     reason: "signal_received"                        │
        │     context: %{"event_name" => event_name}           │
        │     ── INSERT chimeway_workflow_transitions          │
        │     (now with delivery_id populated)                 │
        └──────────────────────────────────────────────────────┘
                            │
                            ▼  (separate transaction — Phase 25/31)
        ┌──────────────────────────────────────────────────────┐
        │ Chimeway.Workflows.Progression.progress_run/2        │
        │ (UNCHANGED — already populates delivery_id)          │
        │   • advance_run  → reason: "progressed_on_delivery_  │
        │                                outcome"              │
        │   • enter_waiting → reason: "waiting_for_step_       │
        │                                 progression"         │
        │   • stop_run     → reason: "workflow_stopped"        │
        │   • complete_run → reason: "workflow_completed"      │
        │   ── INSERT chimeway_workflow_transitions            │
        └──────────────────────────────────────────────────────┘

                  ──────── READ-SIDE (Phase 32 additions) ────────

   Operator query: Chimeway.Traces.explain_delivery(delivery_id)
                            │
                            ▼
   ┌────────────────────────────────────────────────────────────────┐
   │ explain_delivery/1 (traces.ex:113-159)                         │
   │  • Repo.one(Delivery, preload: [notification: :event,          │
   │                                  attempts: []])                │
   │       → cross-tenant :not_found discipline preserved           │
   │  • build_timeline/5 (traces.ex:286-419)                        │
   │       │                                                        │
   │       ├─ existing entries (event_created → attempt_recorded)   │
   │       │                                                        │
   │       ├─ ★ NEW: webhook_received_entries(attempts,             │
   │       │            companion_event_name_by_delivery_id)        │
   │       │       (rank 13 — derived from preloaded attempts)      │
   │       │                                                        │
   │       └─ ★ NEW: workflow_transition_entries(delivery)          │
   │              (ranks 14..17 — single Ecto query joining         │
   │               WorkflowTransition through WorkflowRun.tenant_id │
   │               filtered on delivery_id)                         │
   │                                                                │
   │  ★ NEW: timeline_rank/1 gains 5 literal-atom clauses           │
   │       (traces.ex:485-498 — append after :attempt_recorded)     │
   │                                                                │
   │  Final Enum.sort_by(&timeline_sort_key/1) keeps                │
   │  determinism via {rank, at}.                                   │
   └────────────────────────────────────────────────────────────────┘

                            │
                            ▼
   {:ok, %Explanation{timeline: [...all events sorted by (rank, at)...]}}
```

[VERIFIED: each line above corresponds to a line range I read directly in the source files cited in CONTEXT.md `<canonical_refs>`.]

### Recommended Project Structure

No new files. Phase 32 modifies four existing files:

```
lib/chimeway/
├── traces.ex                          # ★ build_timeline/5, timeline_rank/1
├── workflows.ex                       # ★ route_signal/1 (one-line attrs delta)
└── (no other lib changes)

test/chimeway/
├── traces_test.exs                    # ★ new describe block (D-19, D-20)
├── workflows_test.exs                 # ★ new test in "transition traces" describe (D-21)
└── workflows_inspection_test.exs      # untouched — its existing payload-safety test
                                       #   continues to pass (additive change is to a
                                       #   separate column, not :context)
```

[VERIFIED by `ls /Users/jon/projects/chimeway/lib/chimeway/`, `find ... -name "process_feedback_worker*"`, and direct reads of all four files.]

### Pattern 1: Compile-Time Literal Atom Dispatch (Phase 27/29 carry-over)

**What:** Map external-to-system identifiers (here: `WorkflowTransition.reason` strings) to internal atoms via function-head pattern matching, never via `String.to_atom/1` or `String.to_existing_atom/1`.

**When to use:** Every Phase 32 atom-emitting code path.

**Example (existing — extend with five new clauses):**
```elixir
# lib/chimeway/traces.ex:485-498  [VERIFIED: read directly]
defp timeline_rank(:event_created), do: 0
defp timeline_rank(:notification_created), do: 1
defp timeline_rank(:delivery_planned), do: 2
defp timeline_rank(:deferred), do: 3
defp timeline_rank(:resumed), do: 4
defp timeline_rank(:recovered), do: 5
defp timeline_rank(:suppressed), do: 6
defp timeline_rank(:cancelled), do: 7
defp timeline_rank(:digested), do: 8
defp timeline_rank(:digest_skipped), do: 9
defp timeline_rank(:emitted_immediately), do: 10
defp timeline_rank(:digest_emitted), do: 11
defp timeline_rank(:attempt_recorded), do: 12
# ★ INSERT FIVE NEW CLAUSES HERE ★
# defp timeline_rank(:webhook_received), do: 13
# defp timeline_rank(:workflow_progressed), do: 14
# defp timeline_rank(:workflow_waiting), do: 15
# defp timeline_rank(:workflow_stopped), do: 16
# defp timeline_rank(:workflow_completed), do: 17
defp timeline_rank(_event), do: 99   # MUST stay last
```

**Reason→atom dispatch (new — recommended shape):**
```elixir
# Place as a private helper near build_timeline/5 in traces.ex.
# Note: ONLY four reasons map. Anything else (signal_received, step_activated,
# reactivated_from_wait, workflow_started) returns :skip and the projector
# drops the entry per D-08.
defp project_workflow_reason("progressed_on_delivery_outcome"), do: :workflow_progressed
defp project_workflow_reason("waiting_for_step_progression"), do: :workflow_waiting
defp project_workflow_reason("workflow_stopped"), do: :workflow_stopped
defp project_workflow_reason("workflow_completed"), do: :workflow_completed
defp project_workflow_reason(_other), do: :skip
```
[CITED: D-07/D-08 from CONTEXT.md; D-16 atom-safety gate; UI-SPEC §Registry-Safety lines 235-238.]

### Pattern 2: `Enum.sort_by/2` over `{rank, at}` Tuples

**What:** All timeline projections produce `%{at, event, detail}` maps; the final `Enum.sort_by(&timeline_sort_key/1)` at `traces.ex:418` orders them deterministically.

**When to use:** Whenever a new timeline entry list is appended into `build_timeline/5`.

**Example (existing pattern — extend, do not rewrite):**
```elixir
# lib/chimeway/traces.ex:411-419  [VERIFIED: read directly]
(base ++
   deferred_entries ++
   resumed_entries ++
   recovery_entries ++
   suppression_entries ++
   cancellation_entries ++
   digest_entries ++ attempt_entries)
|> Enum.sort_by(&timeline_sort_key/1)

# lib/chimeway/traces.ex:481-483
defp timeline_sort_key(%{event: event, at: at}) do
  {timeline_rank(event), at}
end
```

**Phase 32 extension shape (recommended):**
```elixir
webhook_entries = webhook_received_entries(attempts, signal_event_name_by_delivery_id)
workflow_entries = workflow_transition_entries(delivery)

(base ++
   deferred_entries ++
   resumed_entries ++
   recovery_entries ++
   suppression_entries ++
   cancellation_entries ++
   digest_entries ++ attempt_entries ++
   webhook_entries ++ workflow_entries)
|> Enum.sort_by(&timeline_sort_key/1)
```
[VERIFIED: extension point is the concat block at `traces.ex:411-417`.]

### Pattern 3: Cross-Tenant `:not_found` (Phase 27 carry-over)

**What:** Every cross-table read in `Chimeway.Workflows`/`Chimeway.Traces` filters by `tenant_id` even when the FK chain already implies it. Cross-tenant reads return `{:error, :not_found}`, never `{:error, :forbidden}` (timing-attack-safe).

**Existing example (preserve):**
```elixir
# lib/chimeway/workflows.ex:344-352  [VERIFIED: read directly]
run_query =
  from(wr in WorkflowRun,
    where: wr.id == ^execution_id and wr.tenant_id == ^tenant_id,
    select: wr.id
  )

case Repo.one(run_query) do
  nil -> {:error, :not_found}
  _run_id -> # ... fetch traces
end
```

**Phase 32 extension (new private helper — recommended):**
```elixir
# Place as a private helper in Chimeway.Traces. The Delivery struct passed in
# already carries tenant_id; we filter through WorkflowRun.tenant_id as
# defense-in-depth even though the delivery_id FK + WorkflowRun.tenant_id
# chain implies it.
defp workflow_transition_entries(%Delivery{id: delivery_id, tenant_id: tenant_id}) do
  rows =
    Repo.all(
      from(wt in WorkflowTransition,
        join: wr in WorkflowRun, on: wr.id == wt.workflow_run_id,
        join: ws in WorkflowStep, on: ws.id == wt.workflow_step_id,
        where:
          wt.delivery_id == ^delivery_id and
          wr.tenant_id == ^tenant_id,
        select: %{
          inserted_at: wt.inserted_at,
          reason: wt.reason,
          context: wt.context,
          workflow_run_id: wt.workflow_run_id,
          workflow_step_id: wt.workflow_step_id,
          workflow_step_key: ws.step_key
        }
      )
    )

  rows
  |> Enum.flat_map(&project_transition_row/1)
end

defp project_transition_row(%{reason: reason} = row) do
  case project_workflow_reason(reason) do
    :skip -> []
    event_atom -> [build_workflow_entry(event_atom, row)]
  end
end

# build_workflow_entry/2 dispatches on event_atom to the four detail-map shapes
# from D-12 / D-13. Atom-key detail maps; ≤6 keys; PII-safe by construction.
```
[VERIFIED: same shape as `workflows.ex:319-322` and `:344-352`. Note the `WorkflowStep` join is needed because `:workflow_step_key` (D-12) is not stored on the transition row — the transition has `workflow_step_id` but the step_key string lives on `WorkflowStep`. See `workflow_transition.ex:19` `belongs_to(:workflow_step, WorkflowStep)`.]

### Pattern 4: Two-Row Model Per Webhook (Phase 31 carry-over)

**What:** Every webhook produces (a) a `signal_received` `WorkflowTransition` written by `route_signal/1` carrying only structural metadata (`%{"event_name" => …}`) and (b) one progression-engine `WorkflowTransition` (`progressed_on_delivery_outcome` / `workflow_stopped` / `workflow_completed` / `waiting_for_step_progression`) written by `Progression.progress_run/2` in a separate transaction. Both rows share the same `delivery_id`.

**Why it matters for Phase 32:** The projector treats them as distinct sources:
- `:webhook_received` is sourced from `DeliveryAttempt` (D-06), not from the `signal_received` row. The `signal_received` row contributes only `signal_event_name` to the `:webhook_received` detail map (D-11) via a companion lookup keyed by `delivery_id`.
- `:workflow_*` is sourced from the progression engine's transition row (D-07).

**The companion-row lookup (D-11):** A single `delivery_id` may have **at most one** `signal_received` transition row in practice (each webhook fires `Signal.track/4` exactly once at `webhooks/process_feedback_worker.ex:55`, which writes one signal, which fires one `route_signal/1`). However, the lookup must still be defensive — if a future code path or a re-tried webhook wrote two `signal_received` rows for the same `delivery_id`, taking `List.first/1` of the rows ordered by `inserted_at ASC` is sufficient for D-11's purpose (any companion event_name is acceptable; the field is informational). Recommended approach:

```elixir
# Inside build_timeline/5, derive once and pass into webhook_received_entries/2:
companion_event_name = lookup_signal_received_event_name(delivery)

defp lookup_signal_received_event_name(%Delivery{id: delivery_id, tenant_id: tenant_id}) do
  Repo.one(
    from(wt in WorkflowTransition,
      join: wr in WorkflowRun, on: wr.id == wt.workflow_run_id,
      where:
        wt.delivery_id == ^delivery_id and
        wt.reason == "signal_received" and
        wr.tenant_id == ^tenant_id,
      order_by: [asc: wt.inserted_at],
      limit: 1,
      select: wt.context["event_name"]
    )
  )
end
```

If the discretion-area note in CONTEXT.md is taken to fold this lookup into `workflow_transition_entries/1` (selecting `signal_received` rows but mapping them to `:skip`), the same data could be returned from one query — but this is an optimization for later; the two-query path is clearer and incurs negligible cost given the per-delivery row counts. [VERIFIED: discretion area in CONTEXT.md `<decisions>` "Claude's Discretion" bullet 3.]

### Anti-Patterns to Avoid

- **`String.to_atom/1` or `String.to_existing_atom/1` for the five new event atoms** — UI-SPEC §Registry-Safety lines 235-238 and D-16. The compile-time literal pattern is structural; deviating from it allows arbitrary strings to leak into the BEAM atom table.
- **Reordering existing `timeline_rank/1` clauses** — UI-SPEC §Spacing line 75-77 mandates strict contiguity at ranks 13..17 with no gaps and no shifts. Existing tests use set-membership only (verified at `traces_test.exs:227-232`), but consumers in the wild may be sensitive to ordering — preserve it.
- **Adding new keys to `WorkflowTransition.context`** — Phase 25's keys (`workflow_outcome`, `from_step`, `to_step`, `anchor_delivery_id`, `due_at`) cover everything D-12/D-13 need. CONTEXT.md `<domain>` bans new context keys.
- **Including `payload`, `provider_response`, recipient identity, IPs, headers in any timeline `:detail` map** — D-15. Refute with the pattern at `workflows_inspection_test.exs:294-313`.
- **Calling the progression engine synchronously from `route_signal/1`** — Phase 31 architecture is `route_signal/1` writes the `signal_received` row, then a separate `WorkflowProgressionWorker` transaction runs `progress_run/2`. Don't conflate the two.
- **Failing the `route_signal/1` transaction when `signal.payload["delivery_id"]` is nil** — host-app signals via `Chimeway.Signal.track/4` (`signal.ex:22`) may legitimately omit it (e.g., user-action signals). The FK is nullable; use `Map.get/2`, not `Map.fetch!/2`. [VERIFIED: D-02 explicit; `workflow_transition.ex:31` lists `:delivery_id` in `@optional_fields`.]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| FK constraint on `WorkflowTransition.delivery_id` | A new migration adding the FK | Existing migration `20260429170200_create_chimeway_workflow_transitions.exs:17` | The FK is already there with `on_delete: :nilify_all`, indexed at line 28. UI-SPEC line 231 saying it is "new" is inaccurate (correction noted in CONTEXT.md `<canonical_refs>`). |
| Tenant-scoping enforcement | A custom guard around the new query | The Phase 27 idiom: filter through `WorkflowRun.tenant_id` | Pattern is already established at `workflows.ex:319-322` and `:344-352`. Defense-in-depth even though the FK chain implies it. |
| Atom dispatch for the five new atoms | A registry / Application env table | Function-head pattern matching as in `timeline_rank/1` | Compile-time literals are mandatory per UI-SPEC §Registry-Safety. The existing rank table is the canonical pattern. |
| Timeline ordering | A custom sort comparator | The existing `Enum.sort_by(&timeline_sort_key/1)` over `{rank, at}` tuples | Already deterministic; new ranks integrate without comparator changes (`traces.ex:481-483`). |
| Companion-row lookup for `signal_event_name` | A separate `Signal` query keyed by JSON containment | The companion `WorkflowTransition` row's `context["event_name"]` (already populated by Phase 31 `route_signal/1` at `workflows.ex:418`) | Avoids a second read path against `Signal` and avoids exposing `payload`. The transition-companion path is preferred per CONTEXT.md "Claude's Discretion" bullet 3. |
| `:webhook_received` data source | A new query against `Signal` rows | Preloaded `attempts` already loaded by `explain_delivery/1` at `traces.ex:119` | Already preloaded; covers UI-SPEC line 200's no-workflow-run case; PII-safe by construction. |
| Cross-tenant `:not_found` discipline | A new error tuple | The existing `nil → {:error, :not_found}` cases preserved at `traces.ex:124-126` and `workflows.ex:319-322,350-352` | D-17/D-18; `{:error, :webhook_link_unavailable}` is reserved but **not** introduced in Phase 32. |

**Key insight:** Phase 32's value is making existing data more legible, not growing the schema. Every "new" surface in the timeline corresponds to existing rows; the only durable shape change is one populated FK column on rows written from a single call site (`route_signal/1`).

## Common Pitfalls

### Pitfall 1: `WorkflowStep.step_key` Not on the Transition Row

**What goes wrong:** D-12/D-13 require `workflow_step_key` (string) in the detail map. The transition row has `workflow_step_id` (UUID) but not the key string.

**Why it happens:** The schema at `workflow_transition.ex:19` is `belongs_to(:workflow_step, WorkflowStep)` — the key lives on `WorkflowStep.step_key`.

**How to avoid:** Join `WorkflowStep` in the new `workflow_transition_entries/1` query and select `ws.step_key`. (See Pattern 3 above.) Use `LEFT JOIN` if there is any concern that `workflow_step_id` may be nil — the schema declares `:workflow_step_id` in `@optional_fields` at line 31, so it can be nil for the `workflow_started` reason; however, all four projected reasons (`progressed_on_delivery_outcome` / `waiting_for_step_progression` / `workflow_stopped` / `workflow_completed`) always set `workflow_step_id` per the progression engine call sites at `progression.ex:269-270, 308, 326, 369, 401-402`. **Recommendation:** use a regular inner join in the projection query (the four projected reasons all have it), and use a `LEFT JOIN ... ON` if defense-in-depth is required.

**Warning signs:** A test fails because `workflow_step_key` is nil for `:workflow_*` entries.

[VERIFIED: `workflow_transition.ex:19, 31`; `progression.ex` step_id assignments.]

### Pitfall 2: `Map.fetch!` on Optional Payload Key

**What goes wrong:** Using `Map.fetch!(signal.payload, "delivery_id")` in `route_signal/1` raises `KeyError` for host-app signals submitted via `Chimeway.Signal.track/4` (`signal.ex:22`) without a `"delivery_id"` payload key, breaking the existing public API contract.

**Why it happens:** `Chimeway.Signal.track/4` accepts an arbitrary `payload :: map()` and host apps may emit user-action signals (e.g., `chimeway.email.opened`) where `delivery_id` is meaningful but absent.

**How to avoid:** D-02 explicitly mandates `Map.get(signal.payload, "delivery_id")` — returns `nil`, which the FK accepts because `:delivery_id` is in `@optional_fields` (`workflow_transition.ex:31`).

**Warning signs:** Existing `route_signal/1` tests that don't supply `delivery_id` in payload start failing (e.g., `workflows_test.exs:265-289` "transition traces" describe).

[VERIFIED: D-02 explicit; signal payload is open-ended (`signal.ex:23` default `%{}`); `workflow_transition.ex:31` schema.]

### Pitfall 3: `Enum.reduce_while` Initial Accumulator Mismatch

**What goes wrong:** `route_signal/1` at `workflows.ex:403-428` uses `Enum.reduce_while(matched_runs, %{}, …)`. Adding the new attrs key to the `append_transition/2` call does **not** change reduce semantics — the success branch still returns `{:cont, acc}` and the rollback branch returns `{:halt, …}`. **No change** to this control flow is needed.

**Why it happens:** A naive reading of D-02 might invite restructuring the reduce to handle a new error case (FK violation). But the FK is nullable and the value is `Map.get/2` (always returns a value or nil), so changeset validation cannot fail on this column. No new error tuple is introduced (D-18).

**How to avoid:** Treat the change as a pure additive map-key insertion; do not modify the surrounding `with` chain or the reduce.

**Warning signs:** A diff with more than ~3 lines of `route_signal/1` change indicates over-scoping.

[VERIFIED: `workflows.ex:393-430` read directly.]

### Pitfall 4: Preload Order Does Not Include `WorkflowTransition`

**What goes wrong:** Adding `:workflow_transitions` to the `explain_delivery/1` preload list at `traces.ex:117-120` would change the public preload contract and could regress consumer code that introspects `loaded.attempts` order. The new query is **not** part of the preload.

**Why it happens:** It feels natural to preload everything in one place. But the new helper issues its own targeted query joining through `WorkflowRun.tenant_id`, which the existing preload chain (`[notification: :event, attempts: []]`) cannot express in a single tree.

**How to avoid:** Issue the `WorkflowTransition` query inside the new helper. Do not modify the preload at `traces.ex:119`.

**Warning signs:** A diff that touches the preload list at `traces.ex:117-120`.

[VERIFIED: `traces.ex:113-159` read directly.]

### Pitfall 5: The Two `signal_received` Rows Edge Case

**What goes wrong:** `route_signal/1` at `workflows.ex:399, 436-450` may match **multiple** `WorkflowRun` rows for the same `(tenant_id, actor_id, event_name)` triple — see `find_runs_waiting_for_signal/3`. Each matched run gets its own `signal_received` `WorkflowTransition` (loop body at `:412-419`). Therefore a single `delivery_id` *can* have multiple `signal_received` rows when multiple workflow runs are waiting for the same signal on the same delivery (rare but possible).

**Why it matters for D-11:** The companion lookup must not assume single-row. Use `limit: 1` with a deterministic `order_by` (e.g., `[asc: wt.inserted_at]`); the field is informational, so any of the companion event_names is correct (they will all be the same `event_name` string in practice — the signal that triggered the routing).

**How to avoid:** Use the `limit: 1` + `order_by` shape shown in Pattern 4 above. Don't use `Repo.one` with no ordering, which can raise on multi-row results in some adapter configurations.

**Warning signs:** A test failing because the `lookup_signal_received_event_name/1` helper returned an unexpected ordering.

[VERIFIED: `workflows.ex:436-450` (`find_runs_waiting_for_signal`) and the loop at `:403-428`.]

### Pitfall 6: Async-Test Sandbox Race on `route_signal/1` Test Body

**What goes wrong:** `Chimeway.WorkflowsTest` uses `async: false` (`workflows_test.exs:2`) — the new D-21 test is added **inside** the existing `describe "route_signal/1 — transition traces"` block (line 265), so it inherits the same async setting. Adding the test to a different `async: true` test file (e.g., `traces_test.exs`) would be a sandbox isolation problem because `route_signal/1` does an Ecto transaction with `FOR UPDATE` locks.

**How to avoid:** Co-locate the D-21 test with the existing `route_signal/1` tests in `workflows_test.exs`. Do not relocate to `traces_test.exs`.

**Warning signs:** Test failing intermittently with `Postgrex.Error` or sandbox checkout errors.

[VERIFIED: `test/chimeway/workflows_test.exs:1-2` uses `async: false`; `test/chimeway/traces_test.exs:1-2` uses `async: true`.]

### Pitfall 7: `process_feedback_worker.ex` Path Mismatch in CONTEXT.md

**What goes wrong:** CONTEXT.md `<canonical_refs>` line 257-258 references `lib/chimeway/signals/process_feedback_worker.ex`. The actual path is `lib/chimeway/webhooks/process_feedback_worker.ex` (verified by `find`). The bounded `String.to_existing_atom/1` referenced in D-16 lives at `webhooks/process_feedback_worker.ex:20`, **not** `signals/`.

**Why it matters:** Phase 32 does not modify this file, so the path mismatch is not load-bearing — but the planner should not waste a round-trip looking for the file under the wrong path.

**How to avoid:** Treat the actual path `lib/chimeway/webhooks/process_feedback_worker.ex` as authoritative. The `lib/chimeway/signals/` directory contains only `signal.ex` (the Ecto schema).

**Warning signs:** A plan task references `lib/chimeway/signals/process_feedback_worker.ex` in its file list.

[VERIFIED: `find /Users/jon/projects/chimeway/lib -name "*feedback*"` returns only `lib/chimeway/webhooks/process_feedback_worker.ex`; `ls lib/chimeway/signals/` returns only `signal.ex`.]

## Code Examples

Verified patterns derived from direct reads of the existing codebase:

### Existing `build_timeline/5` Concat-and-Sort Block (extension site)

```elixir
# lib/chimeway/traces.ex:411-419  [VERIFIED: read directly]
(base ++
   deferred_entries ++
   resumed_entries ++
   recovery_entries ++
   suppression_entries ++
   cancellation_entries ++
   digest_entries ++ attempt_entries)
|> Enum.sort_by(&timeline_sort_key/1)
```

### Existing `attempt_entries` Builder (template for `:webhook_received`)

```elixir
# lib/chimeway/traces.ex:394-407  [VERIFIED: read directly]
attempt_entries =
  Enum.map(attempts, fn attempt ->
    %{
      at: attempt.inserted_at,
      event: :attempt_recorded,
      detail: %{
        outcome: attempt.outcome,
        attempt_number: attempt.attempt_number,
        error_class: attempt.error_class,
        adapter_module: attempt.adapter_module
        # Phase 29 D-22 — nil for pre-Phase-29 rows
      }
    }
  end)
```

**Phase 32 parallel for `:webhook_received` (recommended shape):**
```elixir
# Source: D-06 + D-11; mirrors attempt_entries idiom verbatim.
webhook_received_entries =
  Enum.map(attempts, fn attempt ->
    %{
      at: attempt.inserted_at,
      event: :webhook_received,
      detail: %{
        outcome: attempt.outcome,
        provider_message_id: attempt.provider_message_id,
        adapter_module: attempt.adapter_module,
        signal_event_name: companion_event_name  # may be nil; sourced once above
      }
    }
  end)
```

### Existing `route_signal/1` `append_transition/2` Call (the single write delta)

```elixir
# lib/chimeway/workflows.ex:412-419  [VERIFIED: read directly]
{:ok, transition} <-
  append_transition(Repo, %{
    workflow_run_id: run.id,
    from_state: :waiting,
    to_state: :active,
    reason: "signal_received",
    context: %{"event_name" => event_name},
    inserted_at: now
  })
```

**Phase 32 delta (recommended one-line addition — D-02):**
```elixir
{:ok, transition} <-
  append_transition(Repo, %{
    workflow_run_id: run.id,
    delivery_id: Map.get(signal.payload, "delivery_id"),  # ★ NEW
    from_state: :waiting,
    to_state: :active,
    reason: "signal_received",
    context: %{"event_name" => event_name},
    inserted_at: now
  })
```

The signal struct already binds `signal` in the function head (`workflows.ex:394-396`), so `signal.payload` is in scope. Note that `route_signal/1` currently destructures `Signal{tenant_id: ..., event_name: ..., actor_id: ...}` and discards the rest with `= _signal` — this needs to bind the full struct (e.g., `= signal`) so `signal.payload` is accessible. **Recommendation:** change `_signal` to `signal` (one character) in the function head at line 396. [VERIFIED: line 395 shows `... = _signal` — bind to `signal` to access payload.]

### Existing PII-Boundary Refute Pattern (template for D-20)

```elixir
# test/chimeway/workflows_inspection_test.exs:294-313  [VERIFIED: read directly]
describe "list_traces/3 — payload safety" do
  test "does not expose payload data in trace context" do
    run = insert_workflow_run!(%{tenant_id: "acme"})

    insert_transition!(run, %{
      reason: "signal_received",
      to_state: :active,
      context: %{"event_name" => "invoice.paid"}
    })

    assert {:ok, [trace]} = Workflows.list_traces("acme", run.id)
    assert trace.context["event_name"] == "invoice.paid"
    refute Map.has_key?(trace.context, "payload")
    refute Map.has_key?(trace.context, "data")
    refute Map.has_key?(trace.context, "amount")
  end
end
```

**Phase 32 parallel for D-20 (recommended shape — applied to every new event atom):**
```elixir
# test/chimeway/traces_test.exs — new describe block
describe "explain_delivery/1 — timeline detail PII boundary" do
  test "no event_atom carries payload, recipient, or provider_response" do
    # Setup: a delivery with attempts + a workflow run + at least one
    # progression transition for each of the four projected reasons.
    # Then:
    assert {:ok, exp} = Traces.explain_delivery(delivery.id)
    new_atoms = [:webhook_received, :workflow_progressed, :workflow_waiting,
                 :workflow_stopped, :workflow_completed]

    for entry <- exp.timeline, entry.event in new_atoms do
      refute Map.has_key?(entry.detail, :payload)
      refute Map.has_key?(entry.detail, :data)
      refute Map.has_key?(entry.detail, :recipient)
      refute Map.has_key?(entry.detail, :email)
      refute Map.has_key?(entry.detail, :phone)
      refute Map.has_key?(entry.detail, :provider_response)
      # String-keyed too, to be safe under either convention:
      refute Map.has_key?(entry.detail, "payload")
      refute Map.has_key?(entry.detail, "provider_response")
    end
  end
end
```

### Existing Set-Membership / Monotonicity Test Pattern (D-19 carry-forward)

```elixir
# test/chimeway/traces_test.exs:220-244  [VERIFIED: read directly]
test "timeline contains :event_created, :notification_created, :delivery_planned, :attempt_recorded" do
  # ...
  event_names = Enum.map(exp.timeline, & &1.event)
  assert :event_created in event_names
  assert :notification_created in event_names
  assert :delivery_planned in event_names
  assert :attempt_recorded in event_names
end

test "timeline is sorted ascending by timestamp" do
  # ...
  timestamps = Enum.map(exp.timeline, & &1.at)
  assert timestamps == Enum.sort(timestamps, DateTime)
end
```

**Phase 32 extension for D-19 (mirror set-membership; preserve monotonicity):**
```elixir
describe "explain_delivery/1 — webhook + workflow timeline" do
  test "timeline includes :webhook_received and :workflow_stopped for bounced + stopped" do
    # ... fixture setup mirroring UI-SPEC §A example at lines 256-275 ...
    assert {:ok, exp} = Traces.explain_delivery(delivery.id)
    event_names = Enum.map(exp.timeline, & &1.event)
    assert :webhook_received in event_names
    assert :workflow_stopped in event_names
    refute :signal_received in event_names           # D-08 suppression
    refute :step_activated in event_names            # D-08 suppression
    refute :reactivated_from_wait in event_names     # D-08 suppression
  end

  test "timeline includes :webhook_received and :workflow_progressed for delivered + progressed" do
    # ... mirroring UI-SPEC §B example at lines 277-285 ...
  end

  test "list_traces/3 returns transition rows with delivery_id populated" do
    # ... mirroring UI-SPEC §C example at lines 290-300 ...
    assert {:ok, transitions} = Workflows.list_traces(tenant_id, run.id)
    signal_received_rows = Enum.filter(transitions, &(&1.reason == "signal_received"))
    assert Enum.all?(signal_received_rows, &is_binary(&1.delivery_id))
  end
end
```
[VERIFIED: existing assertions at lines 227-232, 242-243 use set-membership and monotonicity only — no length lock, no atom-set closure.]

## Runtime State Inventory

> Phase 32 is purely additive over already-persisted state — no rename, no refactor, no migration. This section is included only because the phase touches a write path (`route_signal/1`); each category is verified for completeness.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — verified by reading `route_signal/1` at `workflows.ex:393-430`. The change populates a column that already exists and is currently nullable; existing rows with `delivery_id == nil` remain valid (no backfill required, no impact on consumers). | None. Existing legacy `signal_received` transition rows simply stay nil-keyed; the projection silently omits the companion-row contribution (D-11 handles nil). |
| Live service config | None — Phase 32 does not introduce new env vars, runtime config, or external services. | None. |
| OS-registered state | None — no new Oban workers, no new schedulers, no new system processes. The existing `Chimeway.Dispatch.SignalRouterWorker` is unchanged. | None. |
| Secrets/env vars | None — no new secrets, no new env var names, no new auth boundaries. | None. |
| Build artifacts / installed packages | None — no `mix.exs` changes, no new dependencies, no build step changes. | None. |

**The canonical question:** *After every file in the repo is updated, what runtime systems still have the old string cached, stored, or registered?* — **Nothing.** Phase 32 is additive code with no rename component.

[VERIFIED by reading `lib/chimeway/workflows.ex`, `lib/chimeway/traces.ex`, `mix.exs`, `lib/chimeway/application.ex` (no changes needed), and confirming the FK already exists in the schema.]

## Environment Availability

> Phase 32 has no external dependencies — it is purely code and tests against the existing Elixir/Ecto/PostgreSQL stack already in use. The full audit:

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | Compilation | ✓ | ~> 1.17 [VERIFIED: `mix.exs:11`] | — |
| Ecto SQL | Repo + queries | ✓ | ~> 3.11 [VERIFIED: `mix.exs` deps] | — |
| Postgrex | DB driver | ✓ | >= 0.0.0 [VERIFIED: `mix.exs` deps] | — |
| PostgreSQL | Test sandbox + live DB | ✓ (assumed — same as all prior phases) | — | — |
| ExUnit | Test framework | ✓ (stdlib) | bundled with Elixir 1.17 | — |
| `Chimeway.DataCase` (project-local) | SQL sandbox setup | ✓ [VERIFIED: `test/support/data_case.ex`] | — | — |

**Missing dependencies with no fallback:** None.

**Missing dependencies with fallback:** None.

## Validation Architecture

> nyquist_validation is enabled in `.planning/config.json` (`workflow.nyquist_validation: true` [VERIFIED]). This section produces the full validation map plan-phase Step 5.5 will instantiate as VALIDATION.md.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir 1.17 stdlib) + `Chimeway.DataCase` (`test/support/data_case.ex`) |
| Config file | `mix.exs` (deps + `elixirc_paths`); `test/test_helper.exs` (single line: `ExUnit.start()`) |
| Quick run command | `mix test test/chimeway/traces_test.exs:LINE test/chimeway/workflows_test.exs:LINE` (line-targeted; <2s typical for the touched describe blocks) |
| Full suite command | `mix test` (full project test suite — runs all DataCase + ExUnit tests across `lib`/`test`) |
| Tests-only-touched-files command | `mix test test/chimeway/traces_test.exs test/chimeway/workflows_test.exs test/chimeway/workflows_inspection_test.exs` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TRAC-01 | `:webhook_received` entry appears in `explain_delivery/1` timeline with `outcome`, `provider_message_id`, `adapter_module`, `signal_event_name` | unit (DataCase, async: true) | `mix test test/chimeway/traces_test.exs -e "describe \"explain_delivery/1 — webhook + workflow timeline\""` | ✅ existing file; ❌ Wave 0 — describe block to add |
| TRAC-01 | `:workflow_progressed` projects from `progressed_on_delivery_outcome` transition row | unit | (same describe block as above) | ❌ Wave 0 — test body to add |
| TRAC-01 | `:workflow_stopped` projects from `workflow_stopped` transition row | unit | (same describe block) | ❌ Wave 0 |
| TRAC-01 | `:workflow_completed` projects from `workflow_completed` transition row | unit | (same describe block) | ❌ Wave 0 |
| TRAC-01 | `:workflow_waiting` projects from `waiting_for_step_progression` transition row with `due_at` + `rule_kind` | unit | (same describe block) | ❌ Wave 0 |
| TRAC-02 | `route_signal/1` populates `transition.delivery_id` from `signal.payload["delivery_id"]` | unit (DataCase, async: false) | `mix test test/chimeway/workflows_test.exs -e "describe \"route_signal/1 — transition traces\""` | ✅ existing describe; ❌ Wave 0 — new test body to add |
| TRAC-02 | `route_signal/1` leaves `transition.context` unchanged from Phase 31 (`%{"event_name" => …}` only — no payload leakage) | unit | (same describe; existing test at `workflows_test.exs:286-289` continues to pass) | ✅ existing — must remain green |
| TRAC-02 | `list_traces/3` returns transition rows with `delivery_id` populated when payload carries the key | unit | `mix test test/chimeway/traces_test.exs -e "describe \"explain_delivery/1 — webhook + workflow timeline\""` (UI-SPEC §C scenario) | ❌ Wave 0 |
| Cross-cut | All five new event-atom detail maps refute PII keys (`payload`, `data`, `recipient`, `email`, `phone`, `provider_response`) | unit | `mix test test/chimeway/traces_test.exs -e "timeline detail PII boundary"` | ❌ Wave 0 — D-20 describe to add |
| Cross-cut | Cross-tenant `:not_found` invariance preserved (no leakage of other-tenant transitions in the new query) | unit | (added inside the new describe; mirrors `workflows_test.exs:280-284`) | ❌ Wave 0 |
| Backward-compat | Existing set-membership and timestamp-monotonicity tests stay green (`traces_test.exs:227-243`) | unit | `mix test test/chimeway/traces_test.exs:220` and `:235` | ✅ existing — must stay green |
| Backward-compat | Existing `list_traces/3 — payload safety` stays green (`workflows_inspection_test.exs:294-313`) | unit | `mix test test/chimeway/workflows_inspection_test.exs:294` | ✅ existing — must stay green |
| Atom-safety | No `String.to_atom/1` or `String.to_existing_atom/1` introduced for the five new atom names | static | `! grep -rn "String.to_atom\|String.to_existing_atom" lib/chimeway/traces.ex` (must return zero new matches) and `grep -n "String.to_existing_atom" lib/chimeway/webhooks/process_feedback_worker.ex` (must remain at line 20 — bounded usage preserved) | ✅ scriptable |

### Validation Dimensions

The plan-phase template at `.planning/phases/32-operator-traces-audit/VALIDATION.md` should expose at least these six dimensions, each tied to one or more table rows above:

(a) **Timeline projection correctness for each of the 3 UI-SPEC scenarios** (lines 256-300 — bounced + stopped; delivered + progressed; `list_traces/3` transition rows). Mapped to TRAC-01 + TRAC-02 unit tests in `traces_test.exs`. Sampling: full new describe block per task commit; full suite at wave merge.

(b) **PII-boundary refute coverage on every new event atom**. Mapped to the cross-cut "D-20 timeline detail PII boundary" describe. The for-comprehension idiom (`for entry <- exp.timeline, entry.event in new_atoms`) ensures additive atom safety: if a future contributor adds a sixth event atom and forgets to refute PII keys, this test still catches it (dynamic enumeration, not enum closure).

(c) **`route_signal/1` write-path correctness incl. nullable `delivery_id`**. Mapped to TRAC-02 + the explicit nil-payload regression test (D-21). Asserts both: (i) when `payload["delivery_id"]` is present, `transition.delivery_id` matches; (ii) when `payload["delivery_id"]` is absent, `transition.delivery_id` is nil and the existing `route_signal/1` flow does not raise.

(d) **Cross-tenant `:not_found` invariance for the new helper**. The new `workflow_transition_entries/1` query joins through `WorkflowRun.tenant_id == ^delivery.tenant_id`. Test: insert a transition for `tenant_a` and an unrelated transition for `tenant_b` keyed by the same `delivery_id` (only possible if same FK target — synthetic test fixture); call `explain_delivery/1` for `tenant_a`'s delivery; assert the timeline contains only `tenant_a`'s transitions. (In practice the FK chain prevents cross-tenant `delivery_id` reuse, so this is defense-in-depth — the test guards against future schema changes that might relax the chain.)

(e) **Backward-compatibility — existing assertions stay green**. The four canonical assertions to preserve:
  1. `traces_test.exs:220-232` — set-membership over existing event atoms.
  2. `traces_test.exs:235-244` — timestamp monotonicity.
  3. `workflows_test.exs:265-289` — existing `route_signal/1 — transition traces` describe (note: the test at lines 286-288 explicitly asserts `context["event_name"]` and refutes `"payload"` — must continue to pass).
  4. `workflows_inspection_test.exs:294-313` — payload-safety contract.
  Sampling: full project suite at wave merge.

(f) **Atom safety — no `String.to_atom`/`String.to_existing_atom` introduced**. Static-grep gate in CI (or as a pre-commit `mix` task). The gate must allow the existing bounded usage at `lib/chimeway/webhooks/process_feedback_worker.ex:20` (Phase 31's adapter-bounded conversion).

### Sampling Rate
- **Per task commit:** Quick run command targeting only the touched describe blocks — `mix test test/chimeway/traces_test.exs:LINE` etc. (<2s).
- **Per wave merge:** Full project suite — `mix test`. (Phase 32 is one wave; this is the merge gate.)
- **Phase gate:** Full suite green + atom-safety static grep clean before `/gsd-verify-work`.

### Wave 0 Gaps
- [ ] `test/chimeway/traces_test.exs` — new `describe "explain_delivery/1 — webhook + workflow timeline"` block covering UI-SPEC scenarios A/B/C (D-19) — 3 test bodies + fixture helpers.
- [ ] `test/chimeway/traces_test.exs` — new `describe "explain_delivery/1 — timeline detail PII boundary"` block (D-20) — 1 test body using the for-comprehension shape.
- [ ] `test/chimeway/workflows_test.exs` — new test inside existing `describe "route_signal/1 — transition traces"` block (D-21) — 1 test body asserting `transition.delivery_id` populated from payload.
- [ ] (Optional defense-in-depth) New test asserting `route_signal/1` does not raise when `signal.payload` lacks `"delivery_id"` (covers Pitfall 2). May land in same describe as D-21.
- [ ] No framework install needed — ExUnit + DataCase are already wired.

## Security Domain

> `security_enforcement` is not explicitly set in `.planning/config.json` — treating as enabled per default policy. Phase 32 is a structured-data operator surface for an internal Elixir library, so the threat model is narrow but explicit.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Library is consumed by host Elixir apps; auth lives in the host. Phase 32 introduces no auth surface. |
| V3 Session Management | no | No session state in Phase 32. |
| V4 Access Control | yes | Cross-tenant `:not_found` discipline (Phase 27 carry-over). New `WorkflowTransition` query joins through `WorkflowRun.tenant_id` — defense-in-depth even though FK chain implies it (D-09). |
| V5 Input Validation | yes | `signal.payload["delivery_id"]` is consumer-supplied. Validation: `Map.get/2` returns nil for missing key; the FK is nullable; the changeset accepts nil. **No `String.to_atom`** on this value (D-16). |
| V6 Cryptography | no | Phase 32 introduces no crypto surface. |
| V7 Error Handling and Logging | yes | All errors return `{:error, :not_found}` (D-17/D-18). No raw stack traces or arbitrary inspect terms in operator output (UI-SPEC §Typography line 108). |
| V8 Data Protection | yes | **Strict PII boundary** (D-14/D-15). Refutes via D-20 test. |
| V13 API and Web Service | partial | Public API surface unchanged (D-18); existing cross-tenant discipline preserved. |

### Known Threat Patterns for Elixir / Ecto / Phoenix-style library

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Atom-table exhaustion via untrusted-string-to-atom conversion | DoS | Compile-time literal atoms only — `timeline_rank/1`, `project_workflow_reason/1`. Static grep gate in CI (validation dimension f). [CITED: BEAM atom-table is unbounded but bounded-allocation; Erlang/OTP guidance against `String.to_atom/1` from untrusted input.] |
| PII leakage through structured operator output | Information Disclosure | Atom-keyed detail maps with explicit ≤6-key budget; refute-tests on `:payload`, `:data`, `:recipient`, `:email`, `:phone`, `:provider_response` for every new atom (D-20). |
| Cross-tenant data leakage via FK chain | Information Disclosure | Phase 27 idiom: explicit `tenant_id` filter through `WorkflowRun.tenant_id` even when FK chain implies it (D-09). |
| Cross-tenant timing oracle | Information Disclosure | Existing `{:error, :not_found}` instead of `:forbidden` (D-17 — Phase 27 contract preserved). |
| SQL injection via Ecto fragments | Tampering | Phase 32 uses parameterized Ecto query syntax (`from`, `where`, `^var`) — no `fragment(...)` with string interpolation. The single new query is fully parameterized (Pattern 3). |
| Race-condition on `route_signal/1` write | Tampering | Existing `Repo.transaction` + `FOR UPDATE` lock at `workflows.ex:436-450` is preserved — D-02 changes only the attrs map; no concurrency contract change. |

[VERIFIED: cross-checked `find_runs_waiting_for_signal/3` lock at `workflows.ex:446`; `Repo.transaction/1` wrapper at `:398`; existing `:not_found` discipline at `:319-322`, `:344-352`.]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `WorkflowTransition.delivery_id` populated only by progression engine | Now also populated by `route_signal/1` (D-02) | Phase 32 (this phase) | Operators can finally trace `signal_received` rows back to their delivery via the FK; UI-SPEC §C example becomes truthful. |
| `explain_delivery/1` timeline missing async / progression entries | Adds 5 new event atoms at ranks 13..17 | Phase 32 | Closes the asynchronous-lifecycle gap (TRAC-01, TRAC-02). |
| `signal_received` row had no FK to delivery | Phase 32 D-02 populates it | Phase 32 | Enables the companion-row lookup for `signal_event_name` (D-11) without a second query against `Signal`. |

**Deprecated/outdated:**
- UI-SPEC line 231 calling the FK "new" — corrected by D-01 (FK already exists from Phase 24). Documented in CONTEXT.md `<canonical_refs>`.

## Project Constraints (from project conventions)

- **No `CLAUDE.md`** at repo root [VERIFIED: `ls /Users/jon/projects/chimeway/CLAUDE.md` returns nothing].
- **No project-local skills** in `.claude/skills/` or `.agents/skills/` [VERIFIED: directories absent].
- Established conventions implicit in the codebase (must be honored):
  - Function-head pattern matching for atom dispatch (no string→atom conversion).
  - Explicit `tenant_id` filtering through `WorkflowRun.tenant_id` in every cross-table read (Phase 27 idiom).
  - PII-safe `WorkflowTransition.context` — only structural metadata (`event_name`, `step_key`, `source`, etc.).
  - Atom-keyed detail maps for new timeline entries (mirrors `:attempt_recorded` at `traces.ex:399-406`).
  - Compile-time literal atoms only.
  - `Repo.transaction/1` + `FOR UPDATE` for any multi-row write touching `WorkflowRun` state.
  - `async: true` for read-only DataCase tests; `async: false` for tests that exercise `route_signal/1` transactional locks.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| (none — every claim in this research is `[VERIFIED]` against direct file reads or `[CITED]` against CONTEXT.md / UI-SPEC.md) | — | — | — |

**Empty.** All factual claims about the codebase were verified by reading the source. All design constraints were cited against CONTEXT.md `<decisions>` (D-01..D-21), `<canonical_refs>`, or UI-SPEC.md (Approved 2026-05-01). No external library / version research was needed because Phase 32 introduces no new dependencies.

## Open Questions

1. **`signal_event_name` companion lookup: separate query or fold into projection query?**
   - **What we know:** D-11 requires `signal_event_name` in the `:webhook_received` detail map; CONTEXT.md "Claude's Discretion" bullet 3 marks the choice as the planner's. Two-query is clearer; one-query is more efficient.
   - **What's unclear:** Whether the planner's prior phases (27/29) preferred the one-query or two-query convention for similar sibling-row reads. Both Phases 27 and 29 used one query each (`workflows.ex:344-369` `list_traces/3` is one query; the new helper would also be one query).
   - **Recommendation:** **Two separate queries** — one for the new `workflow_transition_entries/1` projection (joins `WorkflowStep` for `step_key`), one for `lookup_signal_received_event_name/1`. The clarity benefit (each query has one purpose) outweighs the ~50µs second roundtrip on a per-delivery query that already issues several reads. If the planner prefers one query, the projection query can `LEFT JOIN` and aggregate, but the projection logic becomes harder to test.

2. **Reason→atom dispatch helper: private function in `Chimeway.Traces`, sibling private module, or inline?**
   - **What we know:** CONTEXT.md "Claude's Discretion" bullet 1 marks this as planner's choice. The current `traces.ex` already has many private helpers (e.g., `digest_timeline_entries/2`, `attempt_entries`, `metadata_string/2`).
   - **Recommendation:** **Private functions in `Chimeway.Traces`**, not a sibling module. `traces.ex` is currently ~780 lines and is the canonical home for all explanation-builder helpers; introducing `Chimeway.Traces.WorkflowProjection` adds ceremony for ~50 LOC. Place the new helpers immediately after `attempt_entries` is built (around `traces.ex:407`) and the `timeline_rank/1` clauses immediately after rank 12 (around line 497).

3. **Should D-21 also include a "nil payload" regression test?**
   - **What we know:** D-21 specifies the success-path test (payload has `"delivery_id"`). Pitfall 2 above flags the nil-payload edge case as a real risk to host-app signals via `Chimeway.Signal.track/4`.
   - **Recommendation:** **Yes, add it.** Either as a second test in the same describe block or as an inline second `assert` in the D-21 test. The risk-to-cost ratio is heavily skewed toward including it (one extra `assert` covers a real public-API regression).

## Sources

### Primary (HIGH confidence)
- [VERIFIED] `lib/chimeway/traces.ex` (full file read) — `explain_delivery/1` at lines 113-159; `build_timeline/5` at lines 286-419; `timeline_sort_key/1` at lines 481-483; `timeline_rank/1` at lines 485-498; preload chain at line 119.
- [VERIFIED] `lib/chimeway/workflows.ex` (full file read) — `route_signal/1` at lines 393-430; `append_transition/2` at lines 262-264; `list_traces/3` at lines 344-369; `explain/2` at lines 300-323; `find_runs_waiting_for_signal/3` at lines 436-450; cross-tenant query pattern at lines 319-322.
- [VERIFIED] `lib/chimeway/workflows/workflow_transition.ex` (full file read) — `belongs_to(:delivery, Delivery)` at line 20; `:delivery_id` in `@optional_fields` at line 31; `@state_values [:active, :waiting, :completed, :stopped]` at line 15.
- [VERIFIED] `lib/chimeway/traces/explanation.ex` (full file read) — struct fields at lines 69-89; `timeline_entry()` typespec at line 37.
- [VERIFIED] `lib/chimeway/signals/signal.ex` (full file read) — `payload :map, default: %{}` at line 23.
- [VERIFIED] `lib/chimeway/signal.ex` (top-level — read) — `Chimeway.Signal.track/4` at line 22.
- [VERIFIED] `lib/chimeway/delivery_attempt.ex` (full file read) — fields `outcome`, `provider_response`, `attempt_number`, `error_class`, `adapter_module`, `provider_message_id` at lines 40-46.
- [VERIFIED] `lib/chimeway/workflows/progression.ex` (full file read) — reason strings + context keys at lines 50-52, 250-258, 295-302, 351-357, 384-390, 472-505.
- [VERIFIED] `lib/chimeway/webhooks/process_feedback_worker.ex` (full file read) — `String.to_existing_atom/1` bounded usage at line 20; payload construction at line 46; `Chimeway.Signal.track/4` call at line 55.
- [VERIFIED] `priv/repo/migrations/20260429170200_create_chimeway_workflow_transitions.exs` (full file read) — FK on line 17 with `on_delete: :nilify_all`; index on `:delivery_id` at line 28.
- [VERIFIED] `test/chimeway/traces_test.exs` lines 1-244 (read) — fixture helpers, set-membership and monotonicity assertions.
- [VERIFIED] `test/chimeway/workflows_test.exs` lines 1-100, 240-330 (read) — `insert_workflow_run!`, `insert_signal!` fixtures; `route_signal/1 — transition traces` describe block.
- [VERIFIED] `test/chimeway/workflows_inspection_test.exs` lines 270-315 (read) — payload safety refute pattern.
- [VERIFIED] `mix.exs` lines 1-30 + deps grep — Elixir/Ecto/Postgrex/Jason versions.
- [VERIFIED] `.planning/config.json` — `workflow.nyquist_validation: true`, `workflow.discuss_mode: "assumptions"`.
- [VERIFIED] `.planning/REQUIREMENTS.md` — TRAC-01 / TRAC-02.
- [VERIFIED] `.planning/ROADMAP.md` — Phase 32 success criteria at lines 73-81.
- [VERIFIED] `.planning/STATE.md` — v1.4 deferred items at lines 155-159.

### Secondary (HIGH confidence — locked context)
- [CITED] `.planning/phases/32-operator-traces-audit/32-CONTEXT.md` — D-01..D-21 locked decisions; canonical references; `<code_context>` insights.
- [CITED] `.planning/phases/32-operator-traces-audit/32-UI-SPEC.md` — Approved 2026-05-01: rank table lines 53-72; PII tables lines 139-156; reason vocabulary lines 168-176; atom-safety lines 235-238; backward-compat gate lines 240-247; operator examples 256-300.
- [CITED] `.planning/phases/32-operator-traces-audit/32-00-ASSUMPTIONS.md` — Three architectural decisions (Explicit DB Link §1; Flat Timeline §2; Strict PII Boundary §3).
- [CITED] `.planning/phases/32-operator-traces-audit/32-DISCUSSION-LOG.md` — Audit trail showing user "Yes, proceed" approval; FK-already-exists correction.

### Tertiary (LOW confidence — flagged)
- None. No external research was needed for this phase.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — every package version verified against `mix.exs`; no new packages; no version uncertainty.
- Architecture: HIGH — extension sites are exact line numbers in two existing files, every join/select column verified against schema files I read directly.
- Pitfalls: HIGH — every pitfall is grounded in a specific line of code I read (e.g., Pitfall 1 grounded in `workflow_transition.ex:31` and `progression.ex` step_id assignments; Pitfall 7 grounded in `find` output).
- PII boundary / atom safety: HIGH — gates are mechanical (`grep` for forbidden patterns; `refute Map.has_key?` in tests).
- Validation architecture: HIGH — test framework (ExUnit + DataCase) is already in use; sampling commands are line-targeted and verified to match existing test layout.

**Research date:** 2026-05-01
**Valid until:** 2026-05-31 (30 days — internal codebase, no external dependencies, but progression-engine semantics may evolve in future phases)
