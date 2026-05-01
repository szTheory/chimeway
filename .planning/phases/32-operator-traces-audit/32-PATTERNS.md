# Phase 32: Operator Traces & Audit — Pattern Map

**Mapped:** 2026-05-01
**Files analyzed:** 4 (all modified — no new files)
**Analogs found:** 4 / 4 (every modification has a same-file or sibling-file analog already in the codebase)

## File Classification

| Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---------------|------|-----------|----------------|---------------|
| `lib/chimeway/traces.ex` | service (query context) | request-response (read-only projection) | self (`build_timeline/5` + `attempt_entries`/`digest_timeline_entries` helpers + `timeline_rank/1`) | exact (extending an in-file pattern) |
| `lib/chimeway/workflows.ex` | service (write path inside `Repo.transaction`) | event-driven (signal → transition row) | self (`route_signal/1` lines 393-430 — the call site of the change) | exact (one-line delta inside the function being modified) |
| `test/chimeway/traces_test.exs` | test | request-response | self (`describe "explain_delivery/1 — succeeded delivery"` lines 200-244) and `workflows_inspection_test.exs:294-313` (PII refute) | exact for fixture/posture; cross-file for PII refute pattern |
| `test/chimeway/workflows_test.exs` | test | event-driven | self (`describe "route_signal/1 — transition traces"` lines 265-289) | exact (extending the same describe block's idiom) |

All four files are existing — Phase 32 introduces zero new files.

---

## Pattern Assignments

### `lib/chimeway/traces.ex` (service, request-response)

**Analog:** Same file — extend the existing `build_timeline/5` (lines 286-419) and `timeline_rank/1` table (lines 485-498). Reference also `Chimeway.Workflows.list_traces/3` (`workflows.ex:344-371`) for the cross-tenant defensive query idiom.

#### A. Imports/aliases pattern (lines 31-35)

The module already has the imports a Phase 32 query needs. The planner must add **one new alias** (`Chimeway.Workflows.{WorkflowTransition, WorkflowRun, WorkflowStep}` — `WorkflowStep` is needed for the `step_key` join per RESEARCH.md Open Question 1). `import Ecto.Query` is already present.

```elixir
import Ecto.Query

alias Chimeway.{Delivery, Events.Event, Notifications.Notification, Repo}
alias Chimeway.Digests.DigestMembership
alias Chimeway.Traces.Explanation
```

**Notes:** Add `alias Chimeway.Workflows.{WorkflowRun, WorkflowStep, WorkflowTransition}` underneath the existing aliases. Do not introduce a sibling module — RESEARCH.md Open Question 2 recommends private helpers in `Chimeway.Traces`.

#### B. Per-source helper pattern — `attempt_entries` shape (lines 394-407)

This is the closest analog for the new `workflow_transition_entries/1` and `webhook_received_entries/1` helpers. Note the pattern: take a preloaded list, `Enum.map` it, return `%{at:, event:, detail:}` maps with **atom keys** in `:detail`, ≤6 fields.

```elixir
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

**Notes:**
- `:detail` uses atom keys (matches D-11/D-12/D-13 spec).
- The `at:` field is `attempt.inserted_at` — for `:webhook_received`, D-06 says use the **same** `attempt.inserted_at`.
- For `:webhook_received`, the `:detail` must include `outcome`, `provider_message_id`, `adapter_module`, and `signal_event_name` (per D-11) — exactly four keys, well under the ≤6 cap.
- The `:webhook_received` projection is built from the same `attempts` list already passed into `build_timeline/5` (no new preload needed — see CONTEXT.md `<code_context>` "DeliveryAttempt preload chain in `explain_delivery/1`").

#### C. Conditional/guarded entry pattern — `digest_timeline_entries/2` shape (lines 700-762)

This is the closest analog for `workflow_transition_entries/1`'s reason→atom dispatch (D-07). The function-head `case` clauses pattern-match on the source row's discriminator and produce different atom-tagged entries.

```elixir
defp digest_timeline_entries(%Delivery{} = delivery, digest_context)
     when is_map(digest_context) do
  case delivery.digest_flush_outcome do
    :digested ->
      [
        %{
          at: delivery.digest_flush_resolved_at || delivery.updated_at,
          event: :digested,
          detail: %{
            digest_delivery_id: delivery.digest_delivery_id,
            resolution_reason: delivery.digest_flush_reason,
            rule_identity: digest_context["rule_identity"]
          }
        }
      ]

    :skipped_by_policy ->
      [
        %{
          at: delivery.digest_flush_resolved_at || delivery.updated_at,
          event: :digest_skipped,
          detail: %{...}
        }
      ]
    # ...more clauses...
    _ ->
      []
  end
end

defp digest_timeline_entries(_delivery, _digest_context), do: []
```

**Notes for `workflow_transition_entries/1`:**
- Use the same shape: `case transition.reason do ... end` with **literal string** clauses for the four documented progression reasons (D-07).
- The fall-through `_ -> []` clause silently suppresses unknown reasons AND the documented suppression list (D-08: `"signal_received"`, `"step_activated"`, `"reactivated_from_wait"`). **Never** call `String.to_atom/1` or `String.to_existing_atom/1` (D-16).
- Each clause builds the `:detail` map per D-12/D-13 by reading `transition.context["workflow_outcome"]`, `["from_step"]`, `["to_step"]`, `["due_at"]` — Phase 25 keys; reuse without invention (per `<code_context>` line 308).

#### D. Cross-tenant query pattern — `Chimeway.Workflows.list_traces/3` (`workflows.ex:344-371`)

This is the canonical Phase 27 "verify tenant ownership first, then fetch the data" idiom. The new `WorkflowTransition`-by-`delivery_id` query in `Chimeway.Traces` mirrors this: even though `explain_delivery/1` already loaded the delivery (which scopes to the caller's tenant context implicitly via the `Delivery.id` lookup), the new query joins through `WorkflowRun.tenant_id` for defense-in-depth (D-09).

```elixir
# First confirm the run exists and belongs to this tenant (T-27-04 / T-27-05)
run_query =
  from(wr in WorkflowRun,
    where: wr.id == ^execution_id and wr.tenant_id == ^tenant_id,
    select: wr.id
  )

case Repo.one(run_query) do
  nil ->
    {:error, :not_found}

  _run_id ->
    traces_query =
      from(wt in WorkflowTransition,
        where: wt.workflow_run_id == ^execution_id,
        order_by: [asc: wt.inserted_at]
      )

    traces = Repo.all(traces_query)
    {:ok, traces}
end
```

**Notes for the new `Chimeway.Traces` query:**
- The Phase 32 query is **inside** `build_timeline/5`, so it does not return `{:error, :not_found}` — that decision is already made by `explain_delivery/1`'s `Repo.one(... where: d.id == ^delivery_id)` at lines 116-122. The new helper just returns `[]` when no rows match.
- The query filters by `wt.delivery_id == ^delivery.id` AND structurally joins `WorkflowRun` to enforce `wr.tenant_id == ^delivery.tenant_id` (D-09 defense-in-depth).
- Because D-12 requires `workflow_step_key` (a string from `WorkflowStep.step_key`), the query also `left_join`s `WorkflowStep` — see Pattern E below.

#### E. Multi-table join with `step_key` projection — `Chimeway.Workflows.explain/2` (`workflows.ex:300-323`)

This is the canonical analog for joining `WorkflowStep` to pick a `step_key` string. Uses `left_join` (so a transition with no `workflow_step_id` still surfaces — important because D-12 lists `workflow_step_key` but the schema marks `:workflow_step_id` as optional per `workflow_transition.ex:31`).

```elixir
query =
  from(wr in WorkflowRun,
    left_join: ws in WorkflowStep,
    on: wr.current_step_id == ws.id,
    where: wr.id == ^execution_id and wr.tenant_id == ^tenant_id,
    select: %{
      id: wr.id,
      tenant_id: wr.tenant_id,
      state: wr.state,
      status_reason: wr.status_reason,
      current_step_name: ws.step_key,
      suspended_until: wr.suspended_until,
      pending_signals: wr.pending_signals,
      terminal_reason: wr.terminal_reason
    }
  )
```

**Notes for the new query:**
- The new query needs **three** joins/relations: `WorkflowTransition wt` as the base, `join: wr in WorkflowRun, on: wt.workflow_run_id == wr.id` (for tenant scoping per D-09), and `left_join: ws in WorkflowStep, on: wt.workflow_step_id == ws.id` (for `step_key`).
- Use `select: %{...}` projecting the exact fields the helper needs: `at: wt.inserted_at, reason: wt.reason, context: wt.context, workflow_run_id: wt.workflow_run_id, workflow_step_id: wt.workflow_step_id, workflow_step_key: ws.step_key`. Do **not** select the full `%WorkflowTransition{}` struct — the selection is what guards against accidental PII leakage downstream.
- `Repo.all/1` for the result combinator (matches `list_traces/3`).

#### F. `timeline_rank/1` literal-atom dispatch table (lines 485-498) — exact insertion site

This is the canonical analog AND the exact site where Phase 32 appends five clauses (D-04, D-05). Copy the form verbatim; insert immediately after the `:attempt_recorded` line; keep `_event -> 99` last.

```elixir
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
defp timeline_rank(_event), do: 99
```

**Insertion (Phase 32 — D-04):** Add five clauses between `:attempt_recorded` (rank 12) and the `_event -> 99` fallback:

```elixir
defp timeline_rank(:attempt_recorded), do: 12
defp timeline_rank(:webhook_received), do: 13
defp timeline_rank(:workflow_progressed), do: 14
defp timeline_rank(:workflow_waiting), do: 15
defp timeline_rank(:workflow_stopped), do: 16
defp timeline_rank(:workflow_completed), do: 17
defp timeline_rank(_event), do: 99
```

**Notes:**
- All five new atoms are **compile-time literals** in the function-head pattern. This is the atom-safety gate (D-16, UI-SPEC §Registry-Safety). They MUST be referenced as `:webhook_received` etc. in the helper code that produces timeline entries — never derived from `transition.reason` strings.
- The `_event -> 99` fallback **must remain last** (T-29 carry-over, UI-SPEC line 73).
- No reordering of pre-Phase-32 ranks (UI-SPEC backward-compat gate, line 240).

#### G. `build_timeline/5` final concatenation site (lines 411-418) — exact insertion site

```elixir
(base ++
   deferred_entries ++
   resumed_entries ++
   recovery_entries ++
   suppression_entries ++
   cancellation_entries ++
   digest_entries ++ attempt_entries)
|> Enum.sort_by(&timeline_sort_key/1)
```

**Insertion (Phase 32):** Add `webhook_received_entries` and `workflow_transition_entries` to the concatenation. The exact order in the `++` chain does not matter (entries sort by `timeline_sort_key/1` afterward), but keep them adjacent to `attempt_entries` for readability:

```elixir
(base ++
   deferred_entries ++
   resumed_entries ++
   recovery_entries ++
   suppression_entries ++
   cancellation_entries ++
   digest_entries ++
   attempt_entries ++
   webhook_received_entries ++
   workflow_transition_entries)
|> Enum.sort_by(&timeline_sort_key/1)
```

**Notes:** No change to `Enum.sort_by(&timeline_sort_key/1)` — new ranks integrate automatically because `timeline_sort_key/1` already calls `timeline_rank(event)` for any atom (lines 481-483, see Pattern F).

---

### `lib/chimeway/workflows.ex` (service, event-driven write path)

**Analog:** Same file — `route_signal/1` at lines 393-430 (the function being modified).

#### A. The exact function head and `with` chain (lines 393-430)

This is the verbatim current shape; D-02 specifies a one-line bind change at line 395 plus one new key in the attrs map at lines 412-419.

```elixir
@spec route_signal(Signal.t()) :: {:ok, map()} | {:error, term()}
def route_signal(
      %Signal{tenant_id: tenant_id, event_name: event_name, actor_id: actor_id} = _signal
    )
    when is_binary(tenant_id) and is_binary(event_name) and is_binary(actor_id) do
  Repo.transaction(fn ->
    matched_runs = find_runs_waiting_for_signal(tenant_id, actor_id, event_name)

    now = DateTime.utc_now()

    Enum.reduce_while(matched_runs, %{}, fn run, acc ->
      with {:ok, updated_run} <-
             update_run(Repo, run, %{
               state: :active,
               pending_signals: [],
               status_reason: "signal_received",
               last_transition_at: now,
               suspended_until: nil
             }),
           {:ok, transition} <-
             append_transition(Repo, %{
               workflow_run_id: run.id,
               from_state: :waiting,
               to_state: :active,
               reason: "signal_received",
               context: %{"event_name" => event_name},
               inserted_at: now
             }) do
        {:cont,
         acc
         |> Map.put({:run_updated, run.id}, updated_run)
         |> Map.put({:transition_inserted, run.id}, transition)}
      else
        {:error, reason} -> {:halt, Repo.rollback(reason)}
      end
    end)
  end)
end
```

**Phase 32 deltas (D-02):**

1. **Line 395 binding fix:** Change `= _signal` to `= signal` so the payload is reachable inside `Enum.reduce_while/3`. The pattern destructure `%Signal{tenant_id: tenant_id, event_name: event_name, actor_id: actor_id}` continues to extract the existing fields; the `signal` binding is now also available.

2. **Lines 412-419 attrs-map insertion:** Add one key to the `append_transition/2` attrs map:

```elixir
{:ok, transition} <-
  append_transition(Repo, %{
    workflow_run_id: run.id,
    from_state: :waiting,
    to_state: :active,
    reason: "signal_received",
    context: %{"event_name" => event_name},
    delivery_id: Map.get(signal.payload, "delivery_id"),
    inserted_at: now
  }) do
```

**Notes:**
- Use `Map.get/2` (not `Map.fetch!/2`) per D-02 — host-app signals via `Chimeway.Signal.track/4` may legitimately omit `"delivery_id"`; the FK is nullable (`workflow_transition.ex:31` lists `:delivery_id` in `@optional_fields`; `priv/repo/migrations/20260429170200_create_chimeway_workflow_transitions.exs:17` declares `on_delete: :nilify_all`).
- The key is read from the **string-keyed** `signal.payload` map (Phase 31 contract: `process_feedback_worker.ex:46` writes `payload = %{"delivery_id" => delivery.id, "status" => to_string(outcome)}`).
- **The `:context` map is NOT changed.** It continues to be `%{"event_name" => event_name}` only — preserving the Phase 31 payload-safety contract codified in `workflows_inspection_test.exs:294-313`. The `:delivery_id` is a separate column on the schema; the existing payload-safety test continues to pass without modification (D-21).
- The `append_transition/2` helper at `workflows.ex:262-264` already passes the attrs map verbatim through `insert_transition/2` and the changeset accepts `:delivery_id` (per `workflow_transition.ex:31`'s `@optional_fields`) — no helper change required.

---

### `test/chimeway/traces_test.exs` (test, request-response)

**Analog A (fixture + posture):** Same file — `describe "explain_delivery/1 — succeeded delivery"` at lines 200-244.
**Analog B (PII refute pattern):** `test/chimeway/workflows_inspection_test.exs:294-313`.

#### A. File-level `async:` posture and existing aliases (lines 1-8)

```elixir
defmodule Chimeway.TracesTest do
  use Chimeway.DataCase, async: true

  alias Chimeway.{Deliveries, Delivery, Repo, Traces}
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification
  alias Chimeway.Traces.Explanation
```

**Notes:** `async: true` is preserved — the new `describe` blocks are read-only assertions over isolated sandbox fixtures and parallel-safe. New test must add aliases for `Chimeway.Workflows.{WorkflowRun, WorkflowStep, WorkflowTransition, WorkflowDefinition}` to construct workflow/transition fixtures inline. (No new helpers — keep fixtures inline like the existing `insert_event` / `insert_notification` / `plan_delivery` helpers at lines 11-39.)

#### B. Set-membership + monotonicity assertion idiom (lines 220-244)

This is the canonical posture for D-19 — assert presence of new event atoms in the timeline (set membership), assert ascending sort by `at` (monotonicity), and never assert exact `length(timeline)` (so additive entries do not break the tests).

```elixir
test "timeline contains :event_created, :notification_created, :delivery_planned, :attempt_recorded" do
  event = insert_event()
  notification = insert_notification(event)
  delivery = plan_delivery(notification)
  _succeeded = succeed_delivery(delivery)

  assert {:ok, exp} = Traces.explain_delivery(delivery.id)
  event_names = Enum.map(exp.timeline, & &1.event)

  assert :event_created in event_names
  assert :notification_created in event_names
  assert :delivery_planned in event_names
  assert :attempt_recorded in event_names
end

test "timeline is sorted ascending by timestamp" do
  event = insert_event()
  notification = insert_notification(event)
  delivery = plan_delivery(notification)
  _succeeded = succeed_delivery(delivery)

  assert {:ok, exp} = Traces.explain_delivery(delivery.id)
  timestamps = Enum.map(exp.timeline, & &1.at)
  assert timestamps == Enum.sort(timestamps, DateTime)
end
```

**Notes for D-19 tests (`describe "explain_delivery/1 — webhook + workflow timeline"`):**
- Three scenarios per UI-SPEC §A/§B/§C (lines 256-300):
  - **§A:** delivery + bounced attempt + a `WorkflowTransition` row with `delivery_id == delivery.id` and `reason == "workflow_stopped"` → assert `:webhook_received` in `event_names`, assert `:workflow_stopped` in `event_names`, assert one entry's `:detail.outcome == :bounced`, one entry's `:detail.workflow_outcome == "bounced"`.
  - **§B:** delivery + delivered attempt + a `WorkflowTransition` row with `reason == "progressed_on_delivery_outcome"` → assert `:webhook_received` and `:workflow_progressed` present; assert detail keys per D-12 (`workflow_run_id`, `from_step`, `to_step`, `workflow_outcome`).
  - **§C:** call `Workflows.list_traces/3` → assert returned `transition.delivery_id` is non-nil for the rows linked via D-02's write-path fix.
- Use `Enum.find(exp.timeline, & &1.event == :webhook_received)` to pick the entry, then assert on `:detail` map keys (atom keys per D-11).
- Assert NO existing rank shifts: `assert :attempt_recorded in event_names` and the existing monotonicity test continues to pass (D-04: ranks 13-17 are strictly contiguous).

#### C. PII-boundary refute pattern — `workflows_inspection_test.exs:294-313`

This is the canonical PII-refute idiom for D-20. Apply it to each of the five new event atoms' `:detail` maps.

```elixir
describe "list_traces/3 — payload safety" do
  test "does not expose payload data in trace context" do
    run = insert_workflow_run!(%{tenant_id: "acme"})

    insert_transition!(run, %{
      reason: "signal_received",
      to_state: :active,
      context: %{"event_name" => "invoice.paid"}
    })

    assert {:ok, [trace]} = Workflows.list_traces("acme", run.id)

    # Structural data is allowed (event_name identifies what happened)
    assert trace.context["event_name"] == "invoice.paid"

    # Payload data must not be in the context — structural traces only
    refute Map.has_key?(trace.context, "payload")
    refute Map.has_key?(trace.context, "data")
    refute Map.has_key?(trace.context, "amount")
  end
end
```

**Notes for D-20 tests (`describe "explain_delivery/1 — timeline detail PII boundary"`):**
- Iterate the timeline filtering by each new event atom and `refute Map.has_key?` on each forbidden key.
- Forbidden keys (D-20 explicit list): `:payload`, `:data`, `:recipient`, `:email`, `:phone`, `:provider_response`. Note that timeline `:detail` maps use **atom** keys (D-11/D-12/D-13 — atom keys for new entries per UI-SPEC line 86 and `attempt_entries` analog), so `refute Map.has_key?(detail, :payload)` not `"payload"`. (Cross-check: PII refute in `workflows_inspection_test.exs` uses string keys because `WorkflowTransition.context` is a string-keyed map; the timeline `:detail` map is the new atom-keyed surface.)
- A clean idiom is a for-comprehension over the five new atoms:

```elixir
new_atoms = [:webhook_received, :workflow_progressed, :workflow_waiting,
             :workflow_stopped, :workflow_completed]
forbidden = [:payload, :data, :recipient, :email, :phone, :provider_response]

for atom <- new_atoms,
    %{detail: detail} <- Enum.filter(exp.timeline, & &1.event == atom),
    key <- forbidden do
  refute Map.has_key?(detail, key),
    "expected #{atom} detail to not contain #{inspect(key)}; got: #{inspect(detail)}"
end
```

---

### `test/chimeway/workflows_test.exs` (test, event-driven)

**Analog:** Same file — `describe "route_signal/1 — transition traces"` at lines 265-289.

#### A. File-level `async:` posture and aliases (lines 1-12)

```elixir
defmodule Chimeway.WorkflowsTest do
  use Chimeway.DataCase, async: false

  import Ecto.Query

  alias Chimeway.Repo
  alias Chimeway.Signals.Signal
  alias Chimeway.Workflows
  alias Chimeway.Workflows.{WorkflowRun, WorkflowTransition}
```

**Notes:** `async: false` is preserved (existing posture for this file — write-path tests use FOR UPDATE locks and run sequentially). No new aliases needed. Signal fixture `insert_signal!` lives at `workflows_test.exs:90-93` and already supports the `payload:` attr.

#### B. The exact `describe "route_signal/1 — transition traces"` block (lines 265-289)

This is the verbatim template for the D-21 test — clone the fixture setup (`insert_workflow_run!`, `insert_signal!` with payload), then add the new asserts.

```elixir
describe "route_signal/1 — transition traces" do
  test "inserts a WorkflowTransition for the matched run on signal receipt" do
    run = insert_workflow_run!(%{pending_signals: ["invoice_paid"]})
    signal = insert_signal!(%{event_name: "invoice_paid", payload: %{"amount" => 100}})

    assert {:ok, _results} = Workflows.route_signal(signal)

    transitions =
      Repo.all(
        from(wt in WorkflowTransition,
          where: wt.workflow_run_id == ^run.id,
          order_by: [asc: wt.inserted_at]
        )
      )

    signal_transitions = Enum.filter(transitions, &(&1.reason == "signal_received"))
    assert length(signal_transitions) == 1

    [transition] = signal_transitions
    assert transition.from_state == :waiting
    assert transition.to_state == :active
    # Transition context records the event name but NOT the payload (safety)
    assert transition.context["event_name"] == "invoice_paid"
    refute Map.has_key?(transition.context, "payload")
  end
  ...
end
```

**Notes for the D-21 test (added inside this same `describe` block):**
- Construct a signal with payload `%{"delivery_id" => some_delivery.id}` (or a string UUID — the FK is `:nilify_all` so an unmatched UUID still inserts, but it's cleaner to construct a real `Chimeway.Delivery` row from a notification fixture).
- Add the new assertions:
  - `assert transition.delivery_id == some_delivery.id`
  - `assert transition.context["event_name"] == ...` (preserving the existing assert)
  - `refute Map.has_key?(transition.context, "payload")` (preserving the existing payload-safety contract)
  - `refute Map.has_key?(transition.context, "delivery_id")` (delivery_id is a column, not a context key — guards against accidental double-write)
- **Add a second test for the nil-payload regression** (per RESEARCH.md Open Question 3):

```elixir
test "leaves transition.delivery_id nil when signal payload omits delivery_id" do
  run = insert_workflow_run!(%{pending_signals: ["invoice_paid"]})
  signal = insert_signal!(%{event_name: "invoice_paid", payload: %{}})

  assert {:ok, _} = Workflows.route_signal(signal)

  [transition] =
    Repo.all(from(wt in WorkflowTransition,
      where: wt.workflow_run_id == ^run.id and wt.reason == "signal_received"))

  assert transition.delivery_id == nil
end
```

This second test guards against `Map.fetch!/2` being introduced later (which would crash on host-app `Chimeway.Signal.track/4` calls that legitimately omit `"delivery_id"` per `signal.ex:23` `payload :map, default: %{}`).

---

## Shared Patterns

### Compile-time atom dispatch (no `String.to_*atom/1`)

**Source:** `lib/chimeway/traces.ex:485-498` (`timeline_rank/1`).
**Apply to:** All five new atoms (`:webhook_received`, `:workflow_progressed`, `:workflow_waiting`, `:workflow_stopped`, `:workflow_completed`) AND the reason→atom dispatch helper in `Chimeway.Traces`.

The pattern: enumerate atoms as **literal** function-head clauses (Pattern F). The reason→atom dispatch (D-07) follows the same shape:

```elixir
# Recommended shape (private helper in Chimeway.Traces) — literal-string match:
defp progression_event_atom("progressed_on_delivery_outcome"), do: :workflow_progressed
defp progression_event_atom("waiting_for_step_progression"), do: :workflow_waiting
defp progression_event_atom("workflow_stopped"), do: :workflow_stopped
defp progression_event_atom("workflow_completed"), do: :workflow_completed
defp progression_event_atom(_other), do: nil  # suppression list (D-08) + safety
```

The `nil`-returning fallback is then filtered in the projection:

```elixir
workflow_transition_entries =
  rows
  |> Enum.flat_map(fn row ->
    case progression_event_atom(row.reason) do
      nil -> []
      atom -> [%{at: row.at, event: atom, detail: build_workflow_detail(atom, row)}]
    end
  end)
```

**Forbidden:** `String.to_atom(reason)`, `String.to_existing_atom(reason)`. The five atoms are guaranteed loaded because `timeline_rank/1` declares them at compile time (Pattern F).

### Atom-keyed `:detail` map (≤6 keys)

**Source:** `lib/chimeway/traces.ex:394-407` (`attempt_entries`) and `:700-762` (`digest_timeline_entries`).
**Apply to:** Every new timeline entry produced by Phase 32.

- New entries' `:detail` maps use **atom keys** (matches `attempt_entries`).
- `:detail` MUST NOT exceed ~6 keys (UI-SPEC line 115).
- Allowed keys (D-14): `delivery_id`, `workflow_run_id`, `workflow_step_id`, `workflow_step_key`, `signal.event_name` (as `:signal_event_name`), `outcome` atom, `received_at` / `at` timestamps, `provider_message_id`. Plus per-atom contract keys per D-11/D-12/D-13.
- Forbidden keys (D-15): raw payload, provider_response body, recipient PII, IPs, headers, raw bodies. The PII refute test (D-20) is the mechanical enforcement.

### Cross-tenant defense-in-depth via join

**Source:** `lib/chimeway/workflows.ex:344-352` (`list_traces/3` two-query) and `:300-323` (`explain/2` single-query with tenant filter).
**Apply to:** The new `WorkflowTransition`-by-`delivery_id` query in `Chimeway.Traces`.

Even though the `delivery_id` FK chain implies tenant scoping (a delivery's `tenant_id` matches the run that links to it), every cross-table read **also** filters by `tenant_id`. For the new query: `join: wr in WorkflowRun, on: wt.workflow_run_id == wr.id, where: wt.delivery_id == ^delivery.id and wr.tenant_id == ^delivery.tenant_id` (D-09).

### Additive-only timeline projection (UI-SPEC backward-compat gate)

**Source:** UI-SPEC lines 240-247.
**Apply to:** `lib/chimeway/traces.ex` modifications and all new tests.

- Existing event atoms keep their rank (no reordering of pre-Phase-32 ranks 0-12).
- The struct shape `%Chimeway.Traces.Explanation{}` is unchanged (no new fields).
- Existing detail keys are not removed or renamed.
- New atoms appear only when underlying data exists (the projection helper returns `[]` when no `WorkflowTransition` matches `delivery_id`, and `webhook_received_entries` returns `[]` when `attempts == []`).
- **No test asserts `length(timeline) == N` or `event_names == [...exact list...]`** — the existing `traces_test.exs:220-243` set-membership + monotonicity asserts continue to pass with new entries appended.

---

## No Analog Found

None — every Phase 32 change has a same-file or sibling-file analog.

| File | Reason |
|------|--------|
| (none) | Phase 32 is purely additive over established patterns. The reason→atom dispatch helper, the per-source projection helper, the multi-table query, the timeline rank table, the test fixtures, and the PII refute pattern all have direct in-codebase analogs. No external research-based patterns are needed (RESEARCH.md confirms: "Empty. All factual claims about the codebase were verified by reading the source"). |

---

## Metadata

**Analog search scope:**
- `lib/chimeway/traces.ex` (full file, 781 lines)
- `lib/chimeway/workflows.ex` (lines 1-460 read; relevant sections 260-450)
- `lib/chimeway/workflows/workflow_transition.ex` (full schema)
- `test/chimeway/traces_test.exs` (lines 1-50 + 200-244)
- `test/chimeway/workflows_test.exs` (lines 1-100 + 240-330)
- `test/chimeway/workflows_inspection_test.exs` (lines 285-315)

**Files scanned:** 6
**Pattern extraction date:** 2026-05-01
