# Phase 32: Operator Traces & Audit - Context

**Gathered:** 2026-05-01 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Expand the operator-facing trace surfaces (`Chimeway.Traces.explain_delivery/1` and
`Chimeway.Workflows.list_traces/3`) so operators can fully audit the **asynchronous**
lifecycle of a notification journey: when a webhook was received, what outcome it
produced, and which workflow progression step it triggered. Phase 32 is a **read-only,
additive** projection over already-persisted state from Phases 24/25/27/29/30/31 — plus
one tiny write-side fix in `Chimeway.Workflows.route_signal/1` to populate the existing
`WorkflowTransition.delivery_id` FK that the signal-received write path currently omits.

Out of scope: any new struct fields on `%Chimeway.Traces.Explanation{}`; any new
`WorkflowTransition.reason` strings; any new `WorkflowTransition.context` keys; any
schema migration for the FK (it already exists from Phase 24); any synchronous
progression triggering inside `route_signal/1` (the progression engine continues to
own that). Bundled vendor adapter expansion, broader operator UI productization, and
read/unread-driven branching remain deferred per `.planning/STATE.md` v1.4 deferred
items.

</domain>

<decisions>
## Implementation Decisions

### Linkage (carries forward from `32-00-ASSUMPTIONS.md` §1)
- **D-01:** Workflow transitions are linked to deliveries via the **existing**
  `WorkflowTransition.delivery_id` FK. This column was added in Phase 24's migration
  (`priv/repo/migrations/20260429170200_create_chimeway_workflow_transitions.exs:17`)
  with `references(:chimeway_deliveries, type: :uuid, on_delete: :nilify_all)` and an
  index (line 28). UI-SPEC §Registry-Safety line 231 describes this FK as "new" — it
  is not. **Phase 32 ships no migration.**
- **D-02:** The single write-side change is in `Chimeway.Workflows.route_signal/1`
  (`lib/chimeway/workflows.ex:393-430`): read `Map.get(signal.payload, "delivery_id")`
  and pass it through the `append_transition/2` attrs map alongside the existing
  `:context => %{"event_name" => event_name}`. Use `Map.get` (not `Map.fetch!`) — host-
  app signals from `Chimeway.Signal.track/4` (`signal.ex:22`) may legitimately omit
  `"delivery_id"`; the FK is nullable.
- **D-03:** Phase 25's progression engine (`lib/chimeway/workflows/progression.ex`)
  already populates `:delivery_id` on every transition it appends (lines 271, 309,
  327, 370, 402, 482) — Phase 32 makes no change to those write paths.

### Timeline projection (carries forward from `32-00-ASSUMPTIONS.md` §2 + UI-SPEC §Spacing)
- **D-04:** Five new event atoms appended to the existing flat
  `%Chimeway.Traces.Explanation{}.timeline` list, ranks **strictly contiguous** with
  existing ranks (UI-SPEC table lines 53-72):
  - `:webhook_received` (rank 13)
  - `:workflow_progressed` (rank 14)
  - `:workflow_waiting` (rank 15)
  - `:workflow_stopped` (rank 16)
  - `:workflow_completed` (rank 17)
- **D-05:** New atom ranks added as compile-time literal clauses to the existing
  `defp timeline_rank/1` table at `lib/chimeway/traces.ex:485-498`. The `_event -> 99`
  fallback stays at the end. No reordering of pre-Phase-32 ranks.
- **D-06:** **Source for `:webhook_received` entries is `DeliveryAttempt` rows**
  (already preloaded by `explain_delivery/1` at `traces.ex:119`). Each entry carries
  `provider_message_id`, `adapter_module`, `outcome :: :delivered | :bounced | :failed`,
  and `at` from `attempt.inserted_at`. Rationale: PII-safe by construction (these
  fields are already operator-allowed per Phase 29 D-22), single read path, and
  covers UI-SPEC line 200's "delivery exists, no workflow run linked" case where
  no transition row exists. Querying `Signal` rows directly via JSON containment was
  considered and rejected (extra read, PII surface, no operator benefit).
- **D-07:** **Source for `:workflow_*` entries is the `WorkflowTransition` rows
  joined on `delivery_id`** (now reliably populated per D-02). Reason→atom dispatch
  uses a fixed compile-time mapping for **only the four documented progression
  reasons**:
  - `"progressed_on_delivery_outcome"` → `:workflow_progressed`
  - `"waiting_for_step_progression"` → `:workflow_waiting`
  - `"workflow_stopped"` → `:workflow_stopped`
  - `"workflow_completed"` → `:workflow_completed`
- **D-08:** **Suppress** the following reasons from the `explain_delivery/1` timeline
  projection (they are internal cursor events, not in the operator narrative; UI-SPEC's
  rank table at lines 53-72 deliberately omits them):
  - `"signal_received"` (Phase 31, `workflows.ex:418`) — the corresponding
    `:webhook_received` entry already exists from D-06; this reason carries no
    additional information.
  - `"step_activated"` (Phase 25, `progression.ex:329, 485`) — internal cursor
    advance.
  - `"reactivated_from_wait"` (Phase 25, `progression.ex:199`) — internal lifecycle
    flip from `:waiting` to `:active`; the subsequent `:workflow_progressed` entry
    captures the operator-relevant fact.
- **D-09:** Timeline projection happens inside `Chimeway.Traces.build_timeline/5`
  (called from `explain_delivery/1` at `traces.ex:133`). A new private helper queries
  `WorkflowTransition` rows scoped by `delivery_id == ^delivery.id`. **Tenant scoping
  is enforced defensively** by also filtering through
  `WorkflowRun.tenant_id == ^delivery.tenant_id` even though the FK chain already
  guarantees this — this matches Phase 27's "structural tenant guard" discipline
  (`workflows.ex:319-322`).
- **D-10:** `Chimeway.Workflows.list_traces/3` is **not modified**. It already returns
  full `%WorkflowTransition{}` structs (`workflows.ex:354-369`); the new `delivery_id`
  values surface automatically by struct introspection now that D-02 populates them.
  The UI-SPEC §C example at lines 290-300 works without API change.

### Detail-map shape (carries forward from UI-SPEC §Color + §Copywriting)
- **D-11:** `:webhook_received` `:detail` map carries (atom keys, ≤6 entries):
  - `outcome` — `:delivered | :bounced | :failed` (from `attempt.outcome`)
  - `provider_message_id` — string (from `attempt.provider_message_id`)
  - `adapter_module` — string (from `attempt.adapter_module`, Phase 29 D-22)
  - `signal_event_name` — string (e.g. `"chimeway.delivery.bounced"`) — sourced from
    the *companion* `WorkflowTransition.context["event_name"]` of the `signal_received`
    row keyed by the same `delivery_id`, when present; nil otherwise.
- **D-12:** `:workflow_progressed` / `:workflow_stopped` / `:workflow_completed`
  `:detail` map carries (atom keys, ≤6 entries):
  - `workflow_run_id` — UUID
  - `workflow_step_id` — UUID (current step at the time of transition)
  - `workflow_step_key` — string from `WorkflowStep.step_key`
  - `workflow_outcome` — string from `transition.context["workflow_outcome"]`
    (Phase 25 already persists this on every progression branch)
  - `from_step` / `to_step` — strings from `transition.context["from_step"]` /
    `["to_step"]` (Phase 25 keys; reuse without invention)
  - `reason` — string copy of `transition.reason` for operator readability
- **D-13:** `:workflow_waiting` `:detail` map carries:
  - `workflow_run_id`, `workflow_step_id`, `workflow_step_key` (as above)
  - `due_at` — DateTime from the wait rule (`transition.context["due_at"]` per
    Phase 25)
  - `rule_kind` — string (e.g. `"wait_until"`)

### PII boundary (carries forward from `32-00-ASSUMPTIONS.md` §3 + UI-SPEC §Color)
- **D-14:** Allowed in timeline `:detail`: `delivery_id`, `workflow_run_id`,
  `workflow_step_id`, `workflow_step_key`, `signal.event_name`, `outcome` atom,
  `received_at` / `at` timestamps, `provider_message_id` (opaque vendor token).
- **D-15:** **NEVER** in timeline `:detail`: raw `signal.payload` map,
  `provider_response` body, recipient email/phone/display name, webhook source IP,
  webhook headers, raw webhook body. The raw payload lives only on `DeliveryAttempt`
  (via existing redacted accessors); `WorkflowTransition.context` continues to carry
  only structural metadata (event_name, step_key, source) per Phase 31.

### Atom safety (carries forward from UI-SPEC §Registry-Safety)
- **D-16:** All five new atoms are **compile-time literals** in the dispatch table.
  Never derive them from `Signal.event_name` strings, `WorkflowTransition.reason`
  strings, or any other untrusted input. The reason→atom dispatch (D-07) uses a
  literal `case` / function-head pattern; **never** `String.to_atom/1` and **never**
  `String.to_existing_atom/1` on these names. (Phase 31's
  `process_feedback_worker.ex:20` `String.to_existing_atom/1` on `args["status"]` is
  bounded by adapter `normalize_feedback/1` returns and stays as-is — Phase 32 does
  NOT extend that pattern.)

### Cross-tenant `:not_found` discipline (carries forward from Phase 27)
- **D-17:** Cross-tenant access to `explain_delivery/1` continues to return
  `{:error, :not_found}` (timing-attack-safe). Same for `list_traces/3` (no change
  required; existing two-query pattern at `workflows.ex:344-352` is preserved).
- **D-18:** Phase 32 introduces no new public API; therefore no new error tuples.
  The reserved `{:error, :webhook_link_unavailable}` mentioned in UI-SPEC line 211 is
  **not introduced** — leave it reserved unless a future phase actually needs it.

### Test posture
- **D-19:** Extend `test/chimeway/traces_test.exs` with a new `describe
  "explain_delivery/1 — webhook + workflow timeline"` block covering the three
  UI-SPEC scenarios at lines 256-300 (bounced + stopped, delivered + progressed,
  list_traces transition rows). No existing assertion locks `length(timeline)` or the
  absence of new event atoms (set-membership and timestamp-monotonicity preserved).
- **D-20:** Add a parallel PII-boundary test mirroring
  `workflows_inspection_test.exs:294-313` against `Explanation.timeline[].detail` for
  `:webhook_received`, `:workflow_progressed`, `:workflow_stopped`,
  `:workflow_completed`, `:workflow_waiting`. Refute keys: `payload`, `data`,
  `recipient`, `email`, `phone`, `provider_response`.
- **D-21:** Add a write-path test in `test/chimeway/workflows_test.exs` proving that
  `route_signal/1` populates `transition.delivery_id` from `signal.payload["delivery_id"]`
  while leaving `transition.context` unchanged from the Phase 31 contract
  (`%{"event_name" => …}` only). The existing payload-safety test at
  `workflows_inspection_test.exs:294-313` continues to pass (additive change to a
  separate column, not to `:context`).

### Claude's Discretion
- The exact module location of the reason→atom dispatch helper (private function in
  `Chimeway.Traces`, sibling private module `Chimeway.Traces.WorkflowProjection`, or
  inline in `build_timeline/5`) — pick the most testable seam consistent with the
  existing Phase 27/29 helper layout in `traces.ex`.
- Whether the `WorkflowTransition` query joins through `WorkflowRun` to enforce
  tenant scoping or relies solely on the `delivery_id` FK chain — both are correct;
  the explicit join is defense-in-depth and recommended.
- Whether `:webhook_received`'s `signal_event_name` is sourced via the companion
  `signal_received` transition (D-11 default) or via a direct `Signal` row read
  scoped by `signal.payload["delivery_id"]` — equivalent for correctness; the
  transition-companion path is preferred (no second query).
- Migration sequencing — there is no migration. The whole phase ships in code +
  tests.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 32 already-locked artifacts (read these FIRST)
- `.planning/phases/32-operator-traces-audit/32-00-ASSUMPTIONS.md` — Three
  architectural decisions: Explicit DB Link (§1), Flat Timeline (§2), Strict PII
  Boundary (§3). Locked; do not relitigate.
- `.planning/phases/32-operator-traces-audit/32-UI-SPEC.md` — Operator output
  contract: timeline rank table (lines 53-72), event atom naming (Typography
  §lines 92-117), allowed/forbidden detail fields (Color §lines 139-156),
  reason-string vocabulary (Copywriting §lines 168-176), atom-safety gate
  (Registry-Safety §lines 235-238), backward-compat gate (lines 240-247),
  operator examples (lines 256-300). **Approved 2026-05-01.**
- ⚠ Note on UI-SPEC §Registry-Safety line 231: it describes the
  `WorkflowTransition.delivery_id` FK as "new". The FK already exists from Phase 24
  (see D-01). Phase 32 ships **no migration** — only the one-line write-path fix
  in `route_signal/1` per D-02.

### Milestone and phase scope
- `.planning/ROADMAP.md` — Phase 32 goal, dependency on Phase 31, success criteria
  (TRAC-01, TRAC-02), milestone v1.4 context.
- `.planning/REQUIREMENTS.md` — TRAC-01 ("Operator timeline traces include
  asynchronous provider callbacks and the resulting outcome state updates"),
  TRAC-02 ("Trace visibility connects the inbound webhook event back to the
  specific journey progression step it triggered").
- `.planning/PROJECT.md` — Local-first ownership, durable identity, explainability
  as core value.
- `.planning/METHODOLOGY.md` — Cohesive Recommendation Default, One-Shot
  Recommendation Bias, Research-First Decision Ownership, Durable Explainability
  Bias, Least-Surprise DX Default. The PII boundary and atom-safety gates are direct
  applications of these lenses.
- `.planning/STATE.md` — v1.4 deferred items (operator UI productization deferred
  beyond v1.4 — Phase 32 ships the structured surface those future UIs will
  consume).

### Prior phase carry-forward (read for locked design constraints)
- `.planning/phases/24-workflow-contracts-state-spine/24-CONTEXT.md` — Workflow
  schema decisions (`WorkflowRun`, `WorkflowStep`, `WorkflowTransition`),
  `delivery_id` FK already present.
- `.planning/phases/25-progression-engine-wait-gates/25-CONTEXT.md` — Reason-string
  vocabulary (`progressed_on_delivery_outcome`, `workflow_stopped`,
  `workflow_completed`, `waiting_for_step_progression`); `transition.context` keys
  (`workflow_outcome`, `from_step`, `to_step`, `anchor_delivery_id`, `due_at`).
- `.planning/phases/27-workflow-runs-inspection/` — `Chimeway.Workflows.explain/2`,
  `list_traces/3`, cross-tenant `:not_found` discipline, "no payload in context"
  PII contract (codified in `workflows_inspection_test.exs:294-313`).
- `.planning/phases/29-outbound-channel-contracts/29-CONTEXT.md` — D-22 (per-attempt
  `adapter_module` exposed via `Chimeway.Traces.explain/2`), Phase 11 atom-safety
  posture preserved.
- `.planning/phases/31-feedback-driven-progression/` — `route_signal/1` write path,
  `Chimeway.Signal.track/4` payload contract (`%{"delivery_id" => ..., "status" => ...}`),
  `process_feedback_worker.ex` adapter→signal pipeline.

### Existing source files (read these — they ARE the code surface Phase 32 modifies)
- `lib/chimeway/traces.ex` — `explain_delivery/1` at line 110, `build_timeline/5` at
  line 286, `timeline_rank/1` at lines 485-498, `timeline_sort_key/1` at lines
  481-483, `Explanation` struct at `lib/chimeway/traces/explanation.ex:69-89`.
  **Primary file for D-04..D-13.**
- `lib/chimeway/workflows.ex` — `route_signal/1` at lines 393-430,
  `append_transition/2` at lines 262-264, `list_traces/3` at lines 344-369,
  `explain/2`. **Primary file for D-02 (route_signal change).**
- `lib/chimeway/workflows/workflow_transition.ex` — schema at line 18-29; confirms
  `belongs_to(:delivery, Delivery)` at line 20 and `:delivery_id` in
  `@optional_fields` at line 31. **No schema change required.**
- `lib/chimeway/workflows/progression.ex` — Phase 25 reason-string + context-key
  source of truth. Lines 271, 309, 327, 370, 402, 482 already populate
  `:delivery_id`. Lines 296-302, 351-357, 384-390 already persist `workflow_outcome`,
  `from_step`, `to_step`. Read-only reference — Phase 32 does not modify.
- `lib/chimeway/signals/signal.ex` — `payload :map` field at lines 19-25, no
  schema change. Field already carries `"delivery_id"` per Phase 31's
  `process_feedback_worker.ex:46`.
- `lib/chimeway/signals/process_feedback_worker.ex` — `payload = %{"delivery_id" =>
  delivery.id, "status" => to_string(outcome)}` at line 46; bounded
  `String.to_existing_atom/1` at line 20 (read-only reference; do NOT extend the
  pattern to Phase 32 atoms).
- `lib/chimeway/delivery_attempt.ex` (or wherever the schema lives) — fields
  `outcome`, `provider_message_id`, `adapter_module`, `inserted_at`. Already
  preloaded by `explain_delivery/1` at `traces.ex:119`. **Source data for
  `:webhook_received` per D-06.**
- `priv/repo/migrations/20260429170200_create_chimeway_workflow_transitions.exs` —
  line 17 confirms the existing FK with `on_delete: :nilify_all`; line 28 confirms
  the index. **Reference only — do NOT add a new migration.**

### Existing tests (read for the test posture to extend)
- `test/chimeway/traces_test.exs` — set-membership + timestamp-monotonicity
  patterns at lines 220-244; the canonical posture Phase 32 extends with new
  `describe "explain_delivery/1 — webhook + workflow timeline"` blocks (D-19).
- `test/chimeway/workflows_test.exs` — `describe "route_signal/1 — transition
  traces"` at lines 265-289. The Phase 32 write-path test (D-21) is added here.
- `test/chimeway/workflows_inspection_test.exs:294-313` — canonical PII-boundary
  test pattern (`refute Map.has_key?(... "payload")`) cloned for D-20 against
  timeline detail maps.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`Chimeway.Traces.timeline_rank/1`** (`traces.ex:485-498`): canonical literal-atom
  rank table; Phase 32 extends with five new clauses (ranks 13-17) using the same
  idiom. The `_event -> 99` fallback stays unchanged.
- **`Chimeway.Traces.timeline_sort_key/1`** (`traces.ex:481-483`): the `{rank, at}`
  tuple already used by `Enum.sort_by/2`; new ranks integrate without sort changes.
- **`Chimeway.Traces.build_timeline/5`** (`traces.ex:286-419`): existing assembly
  function that concatenates per-source entry lists then sorts. New helper
  appends a `workflow_transition_entries(delivery)` list before the final sort.
- **`Chimeway.Workflows.append_transition/2`** (`workflows.ex:262-264`): already
  accepts `:delivery_id`; Phase 32's `route_signal/1` change just adds the key to
  the attrs map already passed in.
- **`%Chimeway.Traces.Explanation{}` struct** (`explanation.ex:69-89`): timeline
  field is `[%{at, event, detail}]` with no length cap. Adding new event types is
  zero-risk for host-app pattern matching that uses `Enum.filter`/`Enum.find`.
- **`DeliveryAttempt` preload chain in `explain_delivery/1`** (`traces.ex:119`):
  attempts are already loaded with `outcome`, `provider_message_id`,
  `adapter_module`. No new preload needed for D-06.
- **Cross-tenant `:not_found` query pattern** (`workflows.ex:319-322` and
  `:344-352`): the established Phase 27 "verify tenant ownership first, then
  fetch data" idiom. Phase 32's new `WorkflowTransition` query reuses the same
  shape (filter through `WorkflowRun.tenant_id`).
- **Phase 25 `transition.context` key vocabulary** (`progression.ex:296-302,
  351-357, 384-390`): already persists `workflow_outcome`, `from_step`, `to_step`,
  `anchor_delivery_id`, `due_at`. Phase 32 reads these keys verbatim per D-12/D-13;
  introduces no new keys.
- **PII-boundary test template** (`workflows_inspection_test.exs:294-313`): the
  `refute Map.has_key?(transition.context, "payload")` pattern, cloned for D-20
  against timeline detail maps.

### Established Patterns
- **Compile-time atom dispatch** (Phase 27/29 carry-over): `timeline_rank/1` and
  similar tables enumerate atoms as function-head clauses, never derived from
  strings. Phase 32 reason→atom dispatch (D-07) follows the same pattern.
- **Additive-only timeline projection**: existing event ranks never shift; new
  ranks are strictly contiguous (rank 12 → 13 → 14 …). Existing tests using
  set-membership remain green; new ranks just produce more entries.
- **Tenant scoping is structural** (Phase 27 D from STATE.md): every cross-table
  read filters by `tenant_id` even when an FK chain already implies it. Phase 32's
  `WorkflowTransition`-by-`delivery_id` query joins through `WorkflowRun` to
  preserve this defense-in-depth.
- **Operator-allowed fact list is the PII gate**: Phase 29 D-22 added
  `adapter_module` to traces; Phase 32 D-11 adds `provider_message_id` and
  `outcome`. Both are operator-allowed (already surfaced via `last_attempt`); the
  raw vendor body (`provider_response`) remains restricted.
- **Two-row model per webhook**: `route_signal/1` writes the `signal_received`
  transition; the progression engine writes the actual progression transition in a
  separate transaction. Both rows share `delivery_id`. The timeline projection
  treats them as distinct sources: `:webhook_received` from `DeliveryAttempt` (per
  D-06), `:workflow_*` from the progression's `WorkflowTransition` row (per D-07).
  Suppression list (D-08) prevents the `signal_received` row from generating its
  own timeline entry.

### Integration Points
- `lib/chimeway/workflows.ex:412-419` (`route_signal/1` `append_transition` call) —
  the single write-side change site for Phase 32. Add `:delivery_id =>
  Map.get(signal.payload, "delivery_id")` to the attrs map.
- `lib/chimeway/traces.ex:286-419` (`build_timeline/5`) — the single read-side
  extension site. Add a new private helper that queries `WorkflowTransition` rows
  by `delivery_id` (tenant-scoped through `WorkflowRun`) and projects them to
  `:workflow_*` timeline entries; merge with a new helper that derives
  `:webhook_received` entries from preloaded `DeliveryAttempt` rows.
- `lib/chimeway/traces.ex:485-498` (`timeline_rank/1`) — append five literal-atom
  clauses for ranks 13-17 immediately after the `:attempt_recorded` clause; keep
  `_event -> 99` last.
- `test/chimeway/traces_test.exs` — new `describe` block per D-19 + D-20 (PII
  boundary).
- `test/chimeway/workflows_test.exs` — new test per D-21 (route_signal populates
  `delivery_id`).

</code_context>

<specifics>
## Specific Ideas

- The two-row model is intentional: `:webhook_received` carries vendor/transport
  facts (provider_message_id, adapter_module, outcome — sourced from
  `DeliveryAttempt`), while `:workflow_progressed` carries policy/business facts
  (workflow_run_id, step keys, workflow_outcome — sourced from the progression
  engine's transition row). Mirrors Stripe's separation between event delivery and
  event processing in their dashboard.
- The `signal_received` reason is intentionally suppressed from the user-facing
  timeline (D-08) but remains queryable via `Chimeway.Workflows.list_traces/3` for
  raw audit purposes — operators who need the gory detail follow the
  `delivery_id` link, exactly as the cross-system pattern works in GitHub Actions
  (high-level run summary vs raw step output).
- Reuse of Phase 25 `transition.context` keys without invention is deliberate —
  every new context key is a maintenance cost across migrations and host-app
  upgrades. The Phase 32 read surface is pure projection; its job is to make
  existing data more legible, not to grow the schema.

</specifics>

<deferred>
## Deferred Ideas

- **`{:error, :webhook_link_unavailable}` error tuple** (UI-SPEC line 211 reserves
  it) — not needed in Phase 32 because the FK is nullable and the projection
  silently omits `:workflow_*` entries when no matching transition exists. Revisit
  if a future phase needs to distinguish "delivery has no workflow" from "delivery's
  workflow link is broken."
- **Reference operator UI / dashboard** — explicit v1.4 deferred item per
  `STATE.md:159` ("Reference operator UI and broader adoption-surface work after
  workflow semantics stabilize"). Phase 32's structured surface is the input those
  future UIs consume.
- **Read/unread-driven workflow branching** — explicit v1.4 deferred item per
  `STATE.md:158`. Trace projection for unread-state events is not in Phase 32.
- **Telemetry events for `:webhook_received` projection** — Phase 32 ships no new
  telemetry. Existing per-attempt telemetry (Phase 29 D-22) and per-signal/
  transition events (Phase 30/31) cover the underlying data sources.
- **Bulk timeline pagination on `explain_delivery/1`** — out of scope; the
  per-delivery timeline is bounded by the number of attempts + transitions
  attached to a single delivery and is not expected to grow unboundedly.
- **`step_activated` / `reactivated_from_wait` projection** — suppressed per D-08;
  surface them in a future "verbose trace" mode if operator demand emerges.
- **Bundled vendor adapters in core** — out of scope forever per PROJECT.md
  no-vendor-lock-in constraint.

</deferred>

---

*Phase: 32-operator-traces-audit*
*Context gathered: 2026-05-01*
