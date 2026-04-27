# Phase 08 Pattern Map: Trigger Dispatch Outcome Surfacing

**Phase**: 08  
**Generated**: 2026-04-24  
**Inputs**: `08-CONTEXT.md`, `08-RESEARCH.md`

---

## 1) Target touch map with file-role classification

| Likely target file/module | File role classification | Why Phase 08 should touch it | Closest analogs to reuse |
|---|---|---|---|
| `lib/chimeway/trigger.ex` | Public trigger orchestration and response normalization seam | Add caller-visible dispatch/enqueue outcome surfacing and durable trace pointers | Existing `normalize_trigger_result/3` additive map shaping; telemetry extra metadata in `do_trigger/6` |
| `lib/chimeway/dispatch/sync.ex` | Sync dispatch contract source | Keep tagged error/success contract stable for trigger outcome mapping | Existing `planning_failed/1` and `{:ok, deliveries}` returns |
| `lib/chimeway/dispatch/oban.ex` | Async enqueue contract source | Keep stage-aware enqueue/planning outcomes stable for trigger mapping | Existing `planning_failed/1` and pending-delivery semantics |
| `lib/chimeway/traces.ex` | Operator lookup surface | Ensure trigger pointers map to existing trace queries | `get_trace/1`, `find_traces_by_correlation_id/1`, `explain_delivery/1` |
| `test/chimeway/trigger_pipeline_test.exs` | Trigger contract regression suite | Assert enriched response fields and duplicate non-dispatch guarantees | Existing idempotency and fanout contract assertions |
| `test/chimeway/integration/delivery_lifecycle_test.exs` | End-to-end durable lifecycle evidence | Verify trigger outcome metadata resolves to real durable rows and trace APIs | Existing scenario-based trigger -> event -> delivery chain assertions |
| `test/chimeway/dispatch/sync_test.exs` + `test/chimeway/dispatch/oban_test.exs` | Dispatch contract parity suites | Lock assumptions Trigger uses when mapping dispatcher outcomes | Existing planning/perform suppression parity assertions |

---

## 2) Closest analog excerpts and concrete references

### A. Existing trigger result shaping pattern

Reference: `lib/chimeway/trigger.ex` (`normalize_trigger_result/3`)

```elixir
{:ok,
 %{
   event: event,
   notification_key: event.notification_key,
   notification_version: event.notification_version,
   idempotency_key: event.idempotency_key,
   recipients: recipients,
   notifications_inserted: notifications_inserted
 }}
```

Pattern relevance:
- Phase 08 should follow additive map extension (new keys only) to preserve compatibility.

---

### B. Current swallow point to replace

Reference: `lib/chimeway/trigger.ex` (`dispatch_after_trigger/4`)

```elixir
case dispatcher.dispatch(notifications, dispatch_opts) do
  {:ok, _deliveries} -> :ok
  {:error, reason} -> Logger.warning("Dispatch failed after trigger: #{inspect(reason)}")
end

result
```

Pattern relevance:
- This is the exact Phase 08 gap; warning-only behavior needs caller-visible outcome merge.

---

### C. Dispatcher return contract patterns

Reference 1: `lib/chimeway/dispatch/sync.ex`  
Reference 2: `lib/chimeway/dispatch/oban.ex`

```elixir
# sync
{:ok, grouped_results |> Enum.reverse() |> List.flatten()}
{:error, {:planning_failed, reason}}

# oban
{:ok, deliveries}
{:error, {:planning_failed, reason}}
```

Pattern relevance:
- Trigger can normalize these without changing dispatcher APIs.

---

### D. Durable trace lookup analogs

Reference: `lib/chimeway/traces.ex`

```elixir
@spec get_trace(String.t()) :: {:ok, Event.t()} | {:error, :not_found}
@spec find_traces_by_correlation_id(String.t()) :: [Event.t()]
```

Pattern relevance:
- Trigger output should include identifiers already accepted by these APIs.

---

### E. Duplicate idempotency short-circuit pattern

Reference: `lib/chimeway/trigger.ex`

```elixir
if idempotency_conflict?(changeset) do
  case Repo.get_by(Event, idempotency_key: idempotency_key) do
    nil -> {:error, :duplicate_event_not_found}
    existing_event -> {:duplicate, existing_event}
  end
end
```

Pattern relevance:
- Phase 08 must not route duplicate path through dispatch outcome enrichment.

---

## 3) Practical implementation notes by target area

### Area A: Trigger response enrichment

- Keep top-level tuple contract unchanged.
- Add only payload keys (`dispatch_outcome`, `dispatch_mode`, `trace`).
- Derive trace pointers from durable entities (`event.id`, `event.correlation_id`, `delivery.id`).

Pitfalls:
- Replacing `{:ok, map}` with new tuple tags.
- Using non-durable IDs or transient process-only data in `trace`.

---

### Area B: Stage-aware sync vs oban semantics

- Normalize mode explicitly (`:sync`, `:oban`, `:unknown`).
- Keep one outcome field with clear success/error semantics.
- Avoid forcing Oban worker-completion semantics into trigger response (enqueue is enough for this phase).

Pitfalls:
- Treating enqueue acceptance as perform success.
- Returning mode-specific incompatible payload shapes.

---

### Area C: Test strategy patterns

- Unit-level contract assertions in `trigger_pipeline_test.exs`.
- End-to-end durability checks in `delivery_lifecycle_test.exs`.
- Contract parity assertions in sync/Oban dispatch suites.

Pitfalls:
- Asserting only presence of keys, not pointer correctness.
- Missing duplicate non-dispatch regression coverage.

---

## 4) Scope guardrails for this phase

- In scope:
  - trigger caller-visible outcome surfacing
  - stage-aware dispatch mode metadata
  - durable trace pointer linkage from trigger response
  - tests proving these contracts
- Out of scope:
  - redesigning dispatcher APIs
  - blocking trigger on Oban worker completion
  - introducing new channel capabilities

---

## 5) Mapped targets summary

- `lib/chimeway/trigger.ex`
- `test/chimeway/trigger_pipeline_test.exs`
- `test/chimeway/integration/delivery_lifecycle_test.exs`
- `test/chimeway/dispatch/sync_test.exs`
- `test/chimeway/dispatch/oban_test.exs`
- `test/chimeway/traces_test.exs`
