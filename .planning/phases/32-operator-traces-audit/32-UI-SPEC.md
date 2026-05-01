---
phase: 32
slug: operator-traces-audit
status: approved
shadcn_initialized: false
preset: none
created: 2026-05-01
reviewed_at: 2026-05-01
surface_kind: structured-data-operator-output
---

# Phase 32 — Operator Trace Output Contract

> Phase 32 ships an **operator-facing diagnostic surface**, not a visual web UI. This is an
> Elixir host-app library, so the "UI" is the shape, naming, and ordering of trace data
> returned by `Chimeway.Traces.explain_delivery/1` and `Chimeway.Workflows.list_traces/3`.
>
> The standard visual UI-SPEC dimensions (spacing, typography, color, registry) are
> structurally inapplicable. Each section below reframes its dimension for a structured
> operator-output surface, preserving the six-dimension Checker Sign-Off contract so
> downstream agents still validate against a consistent rubric.

---

## Design System

| Property | Value |
|----------|-------|
| Tool | none — this is an Elixir library, no visual framework |
| Preset | not applicable |
| Component library | not applicable |
| Icon library | not applicable |
| Font | not applicable |
| Output container | `%Chimeway.Traces.Explanation{}` struct (existing) and `[%Chimeway.Workflows.WorkflowTransition{}]` rows (existing) |
| Output medium | IEx terminal, host-app trace dashboards (consumers iterate the timeline list) |

**Why no visual UI:** Phase 32 ships operator query APIs, not pages. Per the v1.4 deferred-items
list (STATE.md line 159): "Reference operator UI and broader adoption-surface work after
workflow semantics stabilize." Phase 32's surface is the structured data those future UIs
will consume.

---

## Spacing Scale

> Reframed as: **Timeline event ordering and structural rank.**

The flat timeline projects heterogeneous lifecycle events into one chronological list.
Ordering is deterministic via `(timeline_rank, at)` pairs — same as Phase 27 / 29. Phase 32
appends new ranks after `:attempt_recorded` (rank 12) so existing consumer ordering does
not shift.

| Event Atom | Rank | Phase Origin | Inserted Sort Position |
|------------|------|--------------|------------------------|
| `:event_created` | 0 | existing | first |
| `:notification_created` | 1 | existing | — |
| `:delivery_planned` | 2 | existing | — |
| `:deferred` | 3 | existing | — |
| `:resumed` | 4 | existing | — |
| `:recovered` | 5 | existing | — |
| `:suppressed` | 6 | existing | — |
| `:cancelled` | 7 | existing | — |
| `:digested` | 8 | existing | — |
| `:digest_skipped` | 9 | existing | — |
| `:emitted_immediately` | 10 | existing | — |
| `:digest_emitted` | 11 | existing | — |
| `:attempt_recorded` | 12 | existing | — |
| `:webhook_received` | **13** | **Phase 32 (new)** | after attempt |
| `:workflow_progressed` | **14** | **Phase 32 (new)** | after webhook (if delivery linked to a transition) |
| `:workflow_waiting` | **15** | **Phase 32 (new)** | for `wait_until` enter-waiting transitions |
| `:workflow_stopped` | **16** | **Phase 32 (new)** | for stop-rule terminal transitions |
| `:workflow_completed` | **17** | **Phase 32 (new)** | for implicit-completion terminal transitions |
| unknown | 99 | existing fallback | last |

Exceptions: none. New rank values are strictly contiguous with existing ones — no gaps,
no reordering of pre-Phase-32 ranks. This preserves test fixtures and host-app rendering
written against the v1.3 timeline shape.

**Timeline entry struct** (must remain identical for all new atoms):

```elixir
%{at: DateTime.t(), event: atom(), detail: map()}
```

Detail map keys are string-or-atom-keyed per existing convention (atom keys for new entries,
mirroring `:attempt_recorded`).

---

## Typography

> Reframed as: **Naming conventions and readability of operator-facing identifiers.**

| Role | Convention | Example | Constraint |
|------|------------|---------|------------|
| Event atoms | `snake_case` past-tense verb | `:webhook_received`, `:workflow_progressed` | Must read as a thing-that-happened, not a noun. |
| Reason strings (transition.reason) | `snake_case` past-tense | `"progressed_on_delivery_outcome"`, `"workflow_stopped"` | Existing Phase 25 convention — Phase 32 reuses without invention. |
| Detail map keys | `snake_case` atom keys (new entries) or string keys (existing entries) | `:webhook_outcome`, `:workflow_run_id` | Match the surrounding entry's existing key style — do not mix. |
| Workflow outcome strings | lowercase atom-as-string | `"delivered"`, `"bounced"`, `"failed"` | Must match `Chimeway.Workflows.ProgressionOutcome` curated values. |
| Provider/source labels | lowercase, namespaced when external | `"chimeway.delivery.bounced"`, `"webhook"` | Already established by Phase 31 signal emission. |

**Forbidden in operator output (T-25-05 / T-27-04):**

- camelCase or PascalCase keys
- raw provider payload bodies (PII boundary)
- module names in user-facing output unless they are `last_attempt.adapter_module` (which is
  already an operator-relevant fact)
- error stack traces or arbitrary inspected terms

**Verbosity contract:**

- Each new timeline entry's `:detail` map MUST contain enough facts for an operator to answer
  one of the three success-criteria questions WITHOUT issuing a follow-up query.
- `:detail` MUST NOT exceed ~6 keys; if more facts are needed, persist them on the linked
  `WorkflowTransition.context` and surface only the IDs in the timeline detail.

---

## Color

> Reframed as: **Outcome-state semantics and the strict PII boundary.**

Color in a visual UI conveys severity and category. In structured operator output, the
analog is **outcome categorization** — every timeline event must declare its outcome class
unambiguously so a downstream renderer (or an operator scanning IEx output) can route
attention correctly without re-deriving it.

| Outcome Class | Purpose | New Phase 32 Entries |
|---------------|---------|----------------------|
| Informational (60%) | Default lifecycle events | `:webhook_received` with `outcome: :delivered` |
| Progression (30%) | Workflow advanced or completed normally | `:workflow_progressed`, `:workflow_completed` |
| Attention (10%) | Workflow halted on negative feedback or terminal failure | `:workflow_stopped`, `:webhook_received` with `outcome: :bounced \| :failed` |
| Destructive | (reserved for cancellation events; existing — Phase 32 does not extend) | — |

The 10% attention class is reserved for: bounced/failed webhook receipts, workflow stop
transitions, and stop-rule terminations driven by negative feedback. It is NOT used for
expected lifecycle waits or successful progressions.

**PII boundary (Strict — per ASSUMPTIONS.md §3):**

| Field | Allowed in timeline `:detail`? | Reason |
|-------|--------------------------------|--------|
| `delivery_id` | yes | UUID pointer; no PII |
| `workflow_run_id`, `workflow_step_id`, `workflow_step_key` | yes | structural identifiers |
| `signal.event_name` (e.g. `"chimeway.delivery.bounced"`) | yes | abstract signal name; no payload |
| `outcome` atom (`:delivered`, `:bounced`, `:failed`) | yes | curated enumeration |
| `received_at`, `at` timestamps | yes | not PII |
| `provider_message_id` | yes (it's an opaque vendor token, not user PII) | already surfaced via attempts |
| Raw `signal.payload` map | **NO** | may contain auth codes / personal text |
| `provider_response` body | **NO** | lives only on `DeliveryAttempt`, not in timeline detail |
| Recipient email / phone / display name | **NO** | already excluded by existing redaction |
| Webhook source IP, headers, raw body | **NO** | not modeled and never to be modeled here |

Linkage is by `delivery_id` and `workflow_run_id` only. Operators who need the raw provider
response follow the pointer to `Chimeway.Traces.explain_delivery/1`'s `last_attempt` field
(which is already redacted) or query `DeliveryAttempt` directly with proper authorization.

---

## Copywriting Contract

> Reframed as: **Reason strings, empty/error semantics, and operator-readability of struct
> output.** Each entry below is the canonical phrasing or value an operator will read in
> IEx or a future trace dashboard.

### Reason strings (persisted on `WorkflowTransition.reason`)

Existing reasons (Phase 25/27 — DO NOT change):

| Reason | When |
|--------|------|
| `"progressed_on_delivery_outcome"` | `on_outcome` rule matched |
| `"waiting_for_step_progression"` | `wait_until` rule entered waiting |
| `"workflow_stopped"` | `stop` rule terminated the run |
| `"workflow_completed"` | implicit completion (no more rules, branchable outcome) |
| `"reactivated_from_wait"` | due wait elapsed |
| `"step_activated"` | cursor advanced to a new step |

**No new reason strings are introduced by Phase 32.** Phase 31 already emits the upstream
signal; Phase 25 already records the transition reason. Phase 32 is a **read surface** —
its job is to project these existing reasons through `Chimeway.Traces.explain_delivery/1`.

### Timeline event labels (operator-facing — appear in IEx output and dashboards)

| Atom | Rendered Heading (when host UI exists) | Rendered Subline |
|------|---------------------------------------|------------------|
| `:webhook_received` | "Webhook received" | "{outcome} at {at}" — e.g. "delivered at 2026-05-01T12:34:56Z" |
| `:workflow_progressed` | "Workflow progressed" | "{from_step} → {to_step} on {workflow_outcome}" |
| `:workflow_waiting` | "Workflow waiting" | "until {due_at} ({rule_kind})" |
| `:workflow_stopped` | "Workflow stopped" | "on {workflow_outcome}" |
| `:workflow_completed` | "Workflow completed" | "on {workflow_outcome}" |

These are recommended renderings for downstream UI consumers; the library does not enforce
them. The library's contract is the atom + detail map; the rendering is host-determined.

### Empty / not-found semantics

| Case | Library Return Value | Operator Reading |
|------|----------------------|------------------|
| Delivery exists, no webhook yet | `timeline` lacks `:webhook_received` (and `:workflow_progressed`) entries | "No async outcome yet — workflow is still active or waiting." |
| Delivery exists, no workflow run linked | `timeline` lacks all `:workflow_*` entries | "Delivery is not part of a workflow journey." |
| `delivery_id` not found | `{:error, :not_found}` | "Delivery does not exist or belongs to a different tenant." |
| `execution_id` not found in `list_traces/3` | `{:error, :not_found}` | "Workflow run does not exist or belongs to a different tenant." |
| Cross-tenant access attempted | `{:error, :not_found}` (NOT `:forbidden`) | Timing-attack-safe; matches Phase 27 contract. |

### Error / diagnostic copywriting (when explanation cannot be produced)

| Error tuple | Stable string token | When |
|-------------|---------------------|------|
| `{:error, :not_found}` | (atom — host translates) | delivery or run missing/cross-tenant |
| Future: `{:error, :webhook_link_unavailable}` | only if a webhook exists but its delivery_id link is broken (not expected in Phase 32) | reserved — do NOT introduce unless required |

### "Destructive" actions

Phase 32 is **read-only**. No destructive operator actions in this phase. The trace API
neither mutates state nor exposes mutation seams. All mutation already happened upstream
(Phase 25 progression, Phase 27 routing, Phase 31 signal emission).

---

## Registry Safety

> Reframed as: **Schema and atom contract safety.** The dependency surface here is not
> registries of UI blocks — it's the public Elixir contract surface that host apps import.

| Surface | Phase 32 Change | Safety Gate |
|---------|-----------------|-------------|
| `%Chimeway.Traces.Explanation{}` struct fields | **No new fields.** Phase 32 only enriches the `:timeline` list with new event atoms; the struct shape is unchanged. | not required — additive timeline only |
| Timeline event atoms | 5 new atoms (`:webhook_received`, `:workflow_progressed`, `:workflow_waiting`, `:workflow_stopped`, `:workflow_completed`) | Atoms must be defined at module load time (compile-time atoms only — never `String.to_atom/1` from user/webhook input). |
| `Chimeway.Workflows.WorkflowTransition.reason` values | **No new reason strings.** Phase 32 reuses Phase 25's existing reasons. | not required |
| `WorkflowTransition.delivery_id` foreign key | **New explicit FK** per ASSUMPTIONS.md §1 | Migration must add the column with `null: true` (legacy transitions have no delivery link), index it for query performance, and reference `chimeway_deliveries(id)` with `on_delete: :nilify_all` to avoid blocking delivery cleanup. |
| Transition `context` map | **No new keys** required for the timeline projection — Phase 32 reads `context["workflow_outcome"]`, `context["from_step"]`, `context["to_step"]`, `context["anchor_delivery_id"]` (all existing Phase 25 keys). | not required |
| Third-party registries | none | not applicable |

**Atom-safety gate (T-29 carry-over):** New event atoms MUST be statically declared in
`Chimeway.Traces.Explanation` (or a sibling module) and used as literal atoms only. They
must NEVER be derived from webhook payloads, signal event names, or other untrusted strings.
This mirrors the existing rank-table pattern in `Chimeway.Traces.timeline_rank/1`.

**Backward-compatibility gate:** Host apps written against the Phase 31 timeline shape MUST
continue to render correctly without code changes. Specifically:

- The struct shape is unchanged.
- Existing event atoms keep their rank.
- Existing detail keys are not removed or renamed.
- New atoms appear only when the underlying data exists (e.g. `:webhook_received` appears
  only for deliveries that received a webhook signal).

---

## Operator Surface Examples (executor reference)

These illustrate the contract the executor implements. Not normative for the spec — they
are the spec made concrete.

### A. Delivery that bounced and stopped its workflow

```elixir
{:ok, %Chimeway.Traces.Explanation{} = explanation} =
  Chimeway.Traces.explain_delivery("delivery-uuid")

explanation.timeline
#=> [
#=>   %{at: ~U[2026-05-01 12:00:00Z], event: :event_created,        detail: %{...}},
#=>   %{at: ~U[2026-05-01 12:00:00Z], event: :notification_created, detail: %{...}},
#=>   %{at: ~U[2026-05-01 12:00:01Z], event: :delivery_planned,     detail: %{channel: "email"}},
#=>   %{at: ~U[2026-05-01 12:00:02Z], event: :attempt_recorded,     detail: %{outcome: :sent, ...}},
#=>   %{at: ~U[2026-05-01 12:05:00Z], event: :webhook_received,
#=>     detail: %{outcome: :bounced, signal_event_name: "chimeway.delivery.bounced",
#=>               provider_message_id: "msg_abc123"}},
#=>   %{at: ~U[2026-05-01 12:05:00Z], event: :workflow_stopped,
#=>     detail: %{workflow_run_id: "run-uuid", workflow_step_key: "send_email",
#=>               workflow_outcome: "bounced", reason: "workflow_stopped"}}
#=> ]
```

### B. Delivery that succeeded and progressed the workflow

```elixir
explanation.timeline
#=> [..., %{event: :attempt_recorded, detail: %{outcome: :sent}},
#=>      %{event: :webhook_received,  detail: %{outcome: :delivered, ...}},
#=>      %{event: :workflow_progressed,
#=>        detail: %{workflow_run_id: "run-uuid", from_step: "send_email",
#=>                  to_step: "wait_for_open", workflow_outcome: "delivered"}}]
```

### C. Workflow run inspection (transition list)

```elixir
{:ok, transitions} = Chimeway.Workflows.list_traces(tenant_id, run_id)

# Each transition row gains a usable delivery_id link per ASSUMPTIONS.md §1:
Enum.map(transitions, & {&1.reason, &1.delivery_id})
#=> [{"workflow_started",                 nil},
#=>  {"step_activated",                   nil},
#=>  {"progressed_on_delivery_outcome",   "delivery-uuid"},
#=>  {"step_activated",                   nil},
#=>  {"workflow_stopped",                 "delivery-uuid-2"}]
```

---

## Checker Sign-Off

> Each dimension has been reframed for a structured-data operator surface. Pass criteria are
> in the corresponding section above.

- [ ] Dimension 1 Copywriting: PASS — reason strings reuse Phase 25 vocabulary; empty/error semantics defined; no destructive actions.
- [ ] Dimension 2 Visuals (Timeline ordering): PASS — 5 new ranks (13–17) appended; no existing rank shifts.
- [ ] Dimension 3 Color (Outcome class + PII boundary): PASS — strict boundary enforced per ASSUMPTIONS.md §3; allowed/forbidden field tables explicit.
- [ ] Dimension 4 Typography (Naming conventions): PASS — snake_case atoms, past-tense verbs, ≤6 detail keys, no module names.
- [ ] Dimension 5 Spacing (Timeline shape): PASS — entry struct `%{at, event, detail}` unchanged; flat timeline per ASSUMPTIONS.md §2.
- [ ] Dimension 6 Registry Safety (Schema/atom contract): PASS — additive only; atoms declared at compile time; explicit `delivery_id` FK on `WorkflowTransition` per ASSUMPTIONS.md §1; backward-compatible with Phase 31 consumers.

**Approval:** pending
