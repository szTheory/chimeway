# Phase 11 Pattern Map: Channel Adapter Safety and Explainability Hardening

**Phase**: 11  
**Generated**: 2026-04-24  
**Inputs**: `11-CONTEXT.md`, `11-RESEARCH.md`

---

## 1) Target touch map with file-role classification

| Likely target file/module | File role classification | Why Phase 11 should touch it | Closest analogs to reuse |
|---|---|---|---|
| `lib/chimeway/dispatch/executor.ex` | Shared runtime execution seam (sync + Oban worker) | Remove runtime atom creation from adapter-config lookup and keep deterministic default behavior | `DeliveryPlanning.normalize_channels/1`, `Deliveries.plan_delivery/3`, `Trigger.dispatch_after_trigger/4` runtime config lookup pattern |
| `lib/chimeway/dispatch/channel_adapter_config.ex` (new helper, likely) | Pure resolver/helper module for channel adapter config | Isolate compatibility logic (new string-keyed map + legacy key fallback) so executor stays focused on execution | `DeliveryPlanning.resolve_*` helper decomposition and explicit fallback defaults |
| `lib/chimeway/traces.ex` | Operator explainability query surface | Keep `explain_delivery/1` string-safe for `delivery.channel`; prevent raises for valid custom channels | Existing timeline payload already uses `delivery.channel` string directly |
| `lib/chimeway/traces/explanation.ex` | Explainability contract/typespec module | Align public contract with persisted string channels | `Delivery`/`NotificationPreference` schemas model channels as strings |
| `test/chimeway/dispatch/sync_test.exs` | Sync execution regression coverage | Lock custom-channel adapter lookup behavior in sync path | Existing adapter outcome and planning suppression test style |
| `test/chimeway/dispatch/oban_worker_test.exs` | Oban perform-path regression coverage | Prove shared executor hardening parity in background path | Existing perform idempotency/suppression parity patterns |
| `test/chimeway/dispatch/oban_test.exs` | Oban enqueue/runtime integration coverage | Ensure planning + enqueue behavior remains stable with custom channels | Existing enqueue assertions and worker execution tests |
| `test/chimeway/traces_test.exs` | Explainability contract regression coverage | Assert custom channels explain without raising and remain readable | Existing `explain_delivery/1` timeline and status assertions |
| `test/support/chimeway/dispatch_helpers.ex` (optional touch) | Cross-dispatch fixture helper | Reuse channel-param fixture path for parity tests without bespoke setup | `create_pending_delivery/1` channel normalization to string |

---

## 2) Closest analog excerpts and concrete references

### A. String-first channel normalization (planner contract)

Reference: `lib/chimeway/delivery_planning.ex` (`normalize_channels/1`)

```elixir
defp normalize_channels(channels) when is_list(channels) do
  channels
  |> Enum.reduce_while({:ok, MapSet.new()}, fn
    channel, {:ok, acc} when is_atom(channel) ->
      {:cont, {:ok, MapSet.put(acc, Atom.to_string(channel))}}

    channel, {:ok, acc} when is_binary(channel) ->
      normalized_channel = String.trim(channel)
```

Pattern relevance:
- Runtime channel values are intentionally normalized to strings before persistence.
- Phase 11 resolver logic should consume this contract directly (string channel in, no atom conversion).

---

### B. Durable channel string persistence (delivery contract)

Reference: `lib/chimeway/deliveries.ex` (`plan_delivery/3`)

```elixir
channel_str = if is_atom(channel), do: Atom.to_string(channel), else: channel

%Delivery{}
|> Delivery.changeset(%{
  notification_id: notification_id,
  channel: channel_str,
  status: :pending
})
```

Pattern relevance:
- Confirms persisted `delivery.channel` is a string contract.
- Explainability and adapter lookup should remain string-native to avoid fanout/runtime mismatch.

---

### C. Shared execution seam used by both sync and Oban worker

Reference 1: `lib/chimeway/dispatch/sync.ex` (`do_dispatch/1`)  
Reference 2: `lib/chimeway/dispatch/oban_worker.ex` (`do_dispatch/1`)

```elixir
case Chimeway.Dispatch.Executor.run_delivery(delivery) do
  {:ok, %{delivery: updated_delivery}} -> {:ok, updated_delivery}
  {:error, step, reason, _changes} -> {:error, {step, reason}}
  {:error, _reason} = error -> error
end
```

Pattern relevance:
- Phase 11 should prioritize hardening inside `Executor.run_delivery/1`, since this one seam drives both execution modes.
- Regression tests should assert parity rather than duplicating resolver behavior per dispatcher.

---

### D. Current unsafe adapter-config lookup to replace

Reference: `lib/chimeway/dispatch/executor.ex` (`run_delivery/1`)

```elixir
adapter = Application.get_env(:chimeway, :adapter, Chimeway.Adapters.Logger)
channel_key = String.to_atom("adapter_#{delivery.channel}")
adapter_config = Application.get_env(:chimeway, channel_key, [])
```

Pattern relevance:
- This is the exact dynamic-atom hotspot.
- Replacement should preserve call-time config read and default `[]` semantics.

---

### E. Explainability mismatch: timeline is string-safe, headline field is not

Reference: `lib/chimeway/traces.ex` (`explain_delivery/1` + `build_timeline/4`)

```elixir
explanation = %Explanation{
  # ...
  channel: String.to_existing_atom(delivery.channel),
  # ...
}

%{at: delivery.inserted_at, event: :delivery_planned, detail: %{channel: delivery.channel}}
```

Pattern relevance:
- Timeline detail already carries channel as persisted string, but top-level explanation field atom-casts.
- Phase 11 should make both surfaces consistent and non-raising.

---

### F. Existing non-raising existing-atom conversion pattern (bounded domain)

Reference: `lib/chimeway/telemetry.ex` (`try_to_existing_atom/1`)

```elixir
defp try_to_existing_atom(str) do
  String.to_existing_atom(str)
rescue
  ArgumentError -> nil
end
```

Pattern relevance:
- Demonstrates repository preference for non-raising wrappers when conversion may fail.
- For Phase 11 channels, the stronger pattern is to avoid atom conversion entirely.

---

### G. Parity helper for dispatch-path assertions

Reference: `test/support/chimeway/dispatch_helpers.ex` (`create_pending_delivery/1`, `delivery_signature/1`)

```elixir
channel = Keyword.get(opts, :channel, :in_app)
...
channel: to_string(channel),
...
%{
  status: delivery.status,
  suppression_reason: delivery.suppression_reason,
  policy_checkpoint: get_in(delivery.metadata || %{}, ["policy_checkpoint"]),
  attempt_count: attempt_count
}
```

Pattern relevance:
- Supports adding custom-channel parity tests without new fixture infrastructure.
- Keeps sync/Oban checks aligned around normalized outcomes.

---

## 3) Practical implementation notes by target area

### Area A: Adapter config resolution hardening (`dispatch/executor`)

- Prefer a dedicated resolver function/module so `run_delivery/1` stays focused on transition -> deliver -> classify -> record.
- Keep deterministic lookup order:
  1) preferred string-keyed map config (for example `:channel_adapter_configs`),
  2) legacy compatibility lookup for pre-existing `:adapter_<channel>` env keys,
  3) default `[]`.
- Legacy compatibility should iterate existing env keys (`Application.get_all_env(:chimeway)`) and compare by string name; never create atoms from `delivery.channel`.
- Preserve call-time config reads (`Application.get_env/3` style) to keep test overrides and runtime config behavior unchanged.

Pitfalls:
- Reintroducing interpolation-based atoms (`:"adapter_#{channel}"`, `String.to_atom/1`) in helper code.
- Non-deterministic fallback behavior if both new and legacy configs exist.
- Returning `nil` instead of `[]` can break adapter implementations expecting keyword list defaults.

---

### Area B: Explainability channel safety (`traces` + `traces/explanation`)

- Keep `Explanation.channel` string-based to match `Delivery.channel` persistence and timeline detail payloads.
- `Traces.explain_delivery/1` should copy channel as-is from delivery row, not convert.
- Update docs/typespec together so trace consumers have one stable contract.

Pitfalls:
- Partial contract migration (runtime string but typespec still `atom()`), causing downstream confusion and brittle tests.
- Hidden atom conversion in helper/refactor code paths that still raises on custom channels.

---

### Area C: Regression parity coverage (sync + Oban + traces)

- Add one custom-channel fixture path and assert behavior through both dispatch strategies using existing helper style.
- Keep assertions behavior-centric:
  - no crash for valid custom channels,
  - attempt/status transitions still correct,
  - explainability returns `{:ok, %Explanation{channel: <string>}}`.
- Reuse existing setup/teardown env override patterns in dispatch tests.

Pitfalls:
- Testing only sync or only Oban worker; shared seam changes require both.
- Only testing built-in channels (`:in_app`/`email`) and missing custom-channel regressions.

---

## 4) Scope guardrails for this phase

- In scope:
  - adapter config lookup safety in shared executor seam,
  - explainability channel non-raising behavior and contract alignment,
  - regression coverage for custom-channel parity.
- Out of scope (explicitly deferred):
  - `lib/chimeway/dispatch/oban.ex` dynamic step-name atom creation (`enqueue_delivery_<id>`) remains Phase 12 work.

---

## 5) Mapped targets summary

- `lib/chimeway/dispatch/executor.ex`
- `lib/chimeway/dispatch/channel_adapter_config.ex` (likely new)
- `lib/chimeway/traces.ex`
- `lib/chimeway/traces/explanation.ex`
- `test/chimeway/dispatch/sync_test.exs`
- `test/chimeway/dispatch/oban_worker_test.exs`
- `test/chimeway/dispatch/oban_test.exs`
- `test/chimeway/traces_test.exs`
- `test/support/chimeway/dispatch_helpers.ex` (optional)
