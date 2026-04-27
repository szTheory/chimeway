# Phase 7 Pattern Map: Delayed Fallback Runtime Wiring

**Phase**: 07  
**Generated**: 2026-04-24  
**Inputs**: `07-CONTEXT.md`, `07-RESEARCH.md`, listed runtime and test surfaces

---

## 1) Intended touch map -> closest analogs

| Intended phase file/function | Closest analog in current code | Pattern to reuse for Phase 07 |
|---|---|---|
| `lib/chimeway/notifier.ex` -> `@callback delayed_fallback_channels/2` (optional) | Existing optional `channels/2` callback contract | Additive behaviour extension only; keep notifier DX explicit and backwards-compatible. |
| `lib/chimeway/delivery_planning.ex` -> delayed-fallback resolver + validation | `resolve_channels/2` + `normalize_channels/1` | Resolve intent deterministically, normalize channel values, return typed errors on invalid shapes. |
| `lib/chimeway/delivery_planning.ex` -> persist per-channel delayed-fallback intent | `plan_notification/2` reduce loop + `evaluate_planning_policy/1` | Keep planner row-first and deterministic; enrich planning attrs without changing side-effect boundaries. |
| `lib/chimeway/deliveries.ex` -> additive `plan_delivery/3` | Existing idempotent `plan_delivery/2` | Preserve `(notification_id, channel)` idempotency and authoritative re-read after conflict. |
| `lib/chimeway/deliveries.ex` -> delayed-fallback provenance metadata write | `suppress_delivery/3` metadata checkpoint write | Use metadata map normalization and stable string values for explainability fields. |
| `lib/chimeway/dispatch/sync.ex` -> final perform-time fallback gate | `Policy.evaluate(delivery, check_read_state: delivery.delay_fallback)` | Keep read-state suppression as final pre-adapter gate. |
| `lib/chimeway/dispatch/oban_worker.ex` -> final perform-time fallback gate | Same policy call as sync | Preserve exact suppression semantics and adapter-skip behavior parity with sync. |
| `lib/chimeway/dispatch/oban.ex` -> enqueue parity with suppression | Pending-only enqueue filter | Never enqueue suppressed rows; planner output remains source of truth for Oban scheduling. |
| `lib/chimeway/trigger.ex` -> trigger-driven runtime wiring | Existing dispatch opts plumbing (`:notifier`, `:trigger_params`) | Keep wiring through trigger path so Phase 07 evidence is runtime, not fixture-only. |
| `test/chimeway/*` -> delayed fallback evidence | `delivery_signature/1` parity helper and current sync/oban suppression tests | Assert status/reason/checkpoint/attempt parity in both strategies with trigger-driven scenarios. |

---

## 2) Analog excerpts and relevance

### Planner-first deterministic fanout

```elixir
channels
|> Enum.reduce_while({:ok, []}, fn channel, {:ok, acc} ->
  with {:ok, delivery} <- Deliveries.plan_delivery(notification.id, channel),
       {:ok, planned_delivery} <- evaluate_planning_policy(delivery) do
    {:cont, {:ok, [planned_delivery | acc]}}
  else
    {:error, _reason} = error -> {:halt, error}
  end
end)
```

Why this matters: Phase 07 should keep delayed-fallback wiring inside this deterministic planner loop, not in dispatchers.

### Idempotent delivery row creation contract

```elixir
%Delivery{}
|> Delivery.changeset(%{
  notification_id: notification_id,
  channel: channel_str,
  status: :pending
})
|> Repo.insert(on_conflict: :nothing, conflict_target: [:notification_id, :channel])
```

Why this matters: `plan_delivery/3` must remain additive and preserve idempotency guarantees.

### Explainability metadata write pattern

```elixir
metadata =
  delivery.metadata
  |> ensure_metadata_map()
  |> Map.put("policy_checkpoint", checkpoint)
```

Why this matters: delayed-fallback provenance should follow the same stable metadata normalization pattern.

### Policy read-state suppression contract

```elixir
defp maybe_check_read_state(%Delivery{notification_id: notification_id} = delivery, true) do
  case Repo.get(Notification, notification_id) do
    %{read_at: _read_at} -> {:suppress, :already_read}
    _ -> {:ok, :proceed}
  end
end
```

Why this matters: delayed fallback remains a perform-time read-state gate, not a new policy branch type.

### Sync/Oban perform-time parity seam

```elixir
case Policy.evaluate(delivery, check_read_state: delivery.delay_fallback) do
  {:suppress, reason} -> Deliveries.suppress_delivery(delivery, reason)
  {:ok, :proceed} -> do_dispatch_with_telemetry(delivery)
end
```

Why this matters: this call shape exists in both sync and Oban worker and is the parity anchor for Phase 07.

### Oban enqueue suppression parity

```elixir
pending_deliveries = Enum.filter(deliveries, fn delivery -> delivery.status == :pending end)
enqueue_deliveries(pending_deliveries, multi_opt)
```

Why this matters: if planning suppresses, Oban must not enqueue; delayed-fallback wiring must not break this.

### Trigger-path wiring (runtime evidence seam)

```elixir
dispatch_opts =
  opts
  |> Keyword.put_new(:notifier, notifier)
  |> Keyword.put_new(:trigger_params, params)
```

Why this matters: trigger already carries notifier + params into planning, so delayed-fallback intent should be resolved from real trigger inputs.

---

## 3) Invariants and guardrails to preserve

- **Suppression semantics**
  - Keep dual checkpoint model: planning for preference suppression, perform for read-state suppression.
  - For Phase 07 taxonomy, suppression reasons remain `channel_disabled` and `already_read` only.
  - Suppressed deliveries must never call adapters.

- **Attempt-count behavior**
  - Suppression before executor implies `attempt_count == 0`.
  - Attempts are created only through `Deliveries.record_attempt/2` after executor path begins.
  - Terminal deliveries (`:succeeded`, `:suppressed`, `:cancelled`) remain no-op for re-dispatch/perform.

- **Sync/Oban parity**
  - Both strategies must consume shared planner output.
  - Both perform paths must call `Policy.evaluate(delivery, check_read_state: delivery.delay_fallback)` before adapter execution.
  - Oban enqueue path must keep pending-only filter to mirror sync suppression outcomes.

- **Explainability metadata**
  - Preserve authoritative suppression contract: `status`, `suppression_reason`, `metadata["policy_checkpoint"]`.
  - Add delayed-fallback provenance with stable key/value shape (for example `metadata["delayed_fallback_source"]` in `default|notifier|policy` domain).
  - Keep metadata writes normalized to map/string values to avoid trace/query drift.

---

## 4) Test pattern recommendations (trigger-driven delayed fallback evidence)

1. **Add trigger-driven notifier fixture modules in integration tests**
   - Define notifier with `channels/2` (e.g., `[:in_app, :email]`) and delayed-fallback intent callback.
   - Drive through `Chimeway.trigger/3`; do not seed `delay_fallback` directly on delivery fixtures for acceptance evidence.

2. **Assert planner persistence directly after trigger**
   - Query deliveries for triggered notification and assert:
   - outbound channel(s) expected for delayed fallback -> `delay_fallback: true`
   - `in_app` -> `delay_fallback: false`
   - provenance metadata present on planned rows.

3. **Prove perform-time suppression after read-state drift**
   - Mark notification read after planning and before perform.
   - Sync path: dispatch result suppressed.
   - Oban path: `perform_job/2` suppressed.
   - Shared expected signature: `status: :suppressed`, `suppression_reason: "already_read"`, `policy_checkpoint: "perform"`, `attempt_count: 0`.

4. **Parity matrix assertions**
   - Reuse `delivery_signature/1`-style assertions across `sync_test.exs` and `oban_test.exs`.
   - Include both positive path (unread proceeds, attempts recorded) and suppressed path (read skips adapter, zero attempts).

5. **Validation/guardrail tests**
   - Invalid delayed-fallback channel subset -> typed planning error.
   - `in_app` cannot be marked delayed fallback.
   - Existing notifiers without delayed-fallback callback remain backward-compatible (`delay_fallback` defaults false).

6. **Fixture-helper role discipline**
   - Keep `create_pending_delivery(delay_fallback: true)` tests as branch-level unit guards.
   - Do not count fixture-only delayed-fallback tests as Phase 07 closure evidence.

