# Phase 32: Operator Traces & Audit - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-05-01
**Phase:** 32-operator-traces-audit
**Mode:** assumptions
**Areas analyzed:** Schema & FK Linkage, Timeline Projection, Atom Safety & Backward Compatibility, route_signal/1 write path, Test Posture

## Pre-existing artifacts loaded

- `32-00-ASSUMPTIONS.md` — three architectural decisions already locked: Explicit DB Link, Flat Timeline, Strict PII Boundary.
- `32-UI-SPEC.md` — operator output contract approved 2026-05-01: 5 new timeline event atoms, ranks 13-17, atom safety gate, allowed/forbidden detail field tables, reason-string vocabulary.

## Methodology lenses applied

- **Cohesive Recommendation Default** — present one coherent decision set rather than option menus.
- **High-Impact Escalation Gate** — implementation-local choices not surfaced for approval; only the FK-already-exists correction was flagged.
- **Research-First Decision Ownership** — codebase analyzer ran before any user prompt.
- **Durable Explainability Bias** — all decisions favor durable, queryable records over transient state.

## Assumptions Presented

### Schema & FK Linkage

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `WorkflowTransition.delivery_id` already exists from Phase 24 — no migration needed | Confident | `priv/repo/migrations/20260429170200_create_chimeway_workflow_transitions.exs:17,28`; `lib/chimeway/workflows/workflow_transition.ex:20,31`; `progression.ex:271,309,327,370,402,482` |
| FK on-delete behavior matches UI-SPEC §Registry-Safety (`:nilify_all`) — no migration tweak | Confident | Migration line 17 vs UI-SPEC line 231 |
| No new fields on `Chimeway.Traces.Explanation` — additive timeline only | Confident | UI-SPEC §Registry-Safety line 228; `traces/explanation.ex:69-89` |

### Timeline Projection (read-side)

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Projection happens inside `Chimeway.Traces.build_timeline/5` via new private helper joining `WorkflowTransition` on `delivery_id` | Confident | `traces.ex:32-35,117-121,133,286-419` |
| New ranks 13-17 added as compile-time literal clauses to existing `defp timeline_rank/1` | Confident | `traces.ex:485-498`; UI-SPEC line 76 |
| `:webhook_received` sources from `DeliveryAttempt` (already preloaded; PII-safe; covers no-workflow case) | Likely | `traces.ex:119`; UI-SPEC line 200; `delivery_attempt.ex:45`; alternatives: query `Signal` rows (rejected — extra read, PII surface), join through transition `signal_received` rows (rejected — misses no-workflow case) |
| `Chimeway.Workflows.list_traces/3` needs no API change — `delivery_id` materializes by struct introspection once `route_signal/1` populates it | Confident | `workflows.ex:354-369`; `workflows_inspection_test.exs:177-262` |

### Atom Safety & Backward Compatibility

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Five new atoms must be compile-time literals; never derived from strings | Confident | UI-SPEC §Registry-Safety lines 235-238; `traces.ex:485-498` |
| Reason→atom dispatch is a fixed mapping for 4 reasons; suppress `signal_received`, `step_activated`, `reactivated_from_wait` from timeline | Likely | UI-SPEC rank table lines 53-72 deliberately omits these; `progression.ex:50-52,329,485,199`; `workflows.ex:418`; alternative: project all reasons to rank 99 (rejected — clutters timeline with non-narrative events) |
| Existing tests don't lock timeline length/atom set — Phase 32 can add entries safely | Likely | `traces_test.exs:227-232,242-243` use set-membership and timestamp-monotonicity only |

### `route_signal/1` write path

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| One-line write fix: `Map.get(signal.payload, "delivery_id")` into `append_transition` attrs | Confident | `workflows.ex:412-419`; `process_feedback_worker.ex:46`; `signal.ex:22`; `workflow_transition.ex:31` |
| `WorkflowTransition.context` map needs no new keys (Phase 25 keys cover D-12/D-13) | Confident | UI-SPEC line 232; `progression.ex:296-302,351-357,384-390` |
| Two-row model per webhook: `route_signal/1` writes `signal_received` row; progression engine writes `progressed/stopped/completed` row separately | Likely | `workflows.ex:402-429`; `progression.ex:600`; absence of `progress_run` call in route_signal chain; alternative: synchronous progression in `route_signal` (rejected — no such call site exists) |

### Test Posture

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `test/chimeway/traces_test.exs` extended with new `describe` block; existing assertions preserved | Likely | `traces_test.exs:220-244,967` line span; spot-check confirms set-membership and filter patterns |
| `workflows_test.exs:265-289` payload-safety contract preserved (Phase 32 changes column not context) | Confident | Lines 287-288 assert `context["event_name"]` / refute `"payload"` |
| Add parallel PII-boundary test on `Explanation.timeline[].detail` mirroring `workflows_inspection_test.exs:294-313` | Confident | UI-SPEC §Color lines 139-156 enumerate the gates |

## User Interaction

User confirmed assumptions with "Yes, proceed" — no corrections requested. The
FK-already-exists correction (UI-SPEC §Registry-Safety line 231 inaccurate; no
migration needed in Phase 32) was the only notable surface from codebase analysis;
user approved that this becomes a locked decision (D-01 in CONTEXT.md).

## Auto-Resolved

None — all assumptions confirmed by user.

## Corrections Made

None — all assumptions stood.

## Landmines Surfaced (preserved for executor reference)

- Cross-tenant scoping on the new `WorkflowTransition` join — defense-in-depth filter
  through `WorkflowRun.tenant_id` even though the FK chain implies it.
- Do NOT extend `process_feedback_worker.ex:20`'s `String.to_existing_atom/1` pattern
  to the new event atoms (UI-SPEC atom-safety gate).
- Two-row model per webhook means projection must avoid double-counting webhooks
  when multiple workflow runs match the same actor (`workflows.ex:436-450`'s
  `find_runs_waiting_for_signal`). Mitigation in CONTEXT.md D-06: source
  `:webhook_received` from `DeliveryAttempt`, not from
  `WorkflowTransition.reason = "signal_received"`.

## External Research

None — Phase 32 is an internal projection over already-persisted state. ASSUMPTIONS.md,
UI-SPEC.md, and the Phase 24/25/27/29/30/31 source code together provide complete
evidence. No library compatibility or ecosystem-best-practices research required.
