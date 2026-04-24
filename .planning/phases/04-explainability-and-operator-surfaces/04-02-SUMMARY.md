---
phase: 04-explainability-and-operator-surfaces
plan: "04-02"
subsystem: telemetry
tags: [telemetry, observability, pii-redaction, instrumentation]
dependency_graph:
  - lib/chimeway/telemetry.ex ← lib/chimeway/trigger.ex
  - lib/chimeway/telemetry.ex ← lib/chimeway/policy.ex
  - lib/chimeway/telemetry.ex ← lib/chimeway/dispatch/sync.ex
  - lib/chimeway/telemetry.ex ← lib/chimeway/dispatch/oban.ex
  - lib/chimeway/telemetry.ex ← lib/chimeway/dispatch/oban_worker.ex
  - lib/chimeway/telemetry.ex ← lib/chimeway/deliveries.ex
tech_stack: [elixir, telemetry]
key_files:
  - lib/chimeway/telemetry.ex
  - lib/chimeway/trigger.ex
  - lib/chimeway/policy.ex
  - lib/chimeway/dispatch/sync.ex
  - lib/chimeway/dispatch/oban.ex
  - lib/chimeway/dispatch/oban_worker.ex
  - lib/chimeway/deliveries.ex
  - test/chimeway/telemetry_integration_test.exs
key_decisions:
  - All 7 lifecycle spans were already instrumented prior to this plan execution (prior partial work)
  - Chimeway.Telemetry existed with a slightly different safe_meta/1 implementation using Map.take after normalize_keys
  - Fixed normalize_keys/1 per-key error handling: replaced rescue-on-whole-reduce with try_to_existing_atom/1 helper per key, preventing ArgumentError for unknown string keys from returning the unredacted map
  - Test support notifier (Chimeway.Test.SupportNotifier) was already in test/support
duration: ~5 min
completed_at: "2026-04-24T05:55:00Z"
---

Instrumented all 7 Chimeway lifecycle transitions with `:telemetry` spans via `Chimeway.Telemetry` facade, enforcing structural PII redaction through `safe_meta/1` at every call site.

## Tasks

### 04-02-01: Create Chimeway.Telemetry ✅

- `lib/chimeway/telemetry.ex` already existed with `span/3`, `safe_meta/1`, `attach_default_handlers/0`.
- Fixed `normalize_keys/1` to handle per-key `ArgumentError` safely (unknown string keys were previously causing the entire map to return unredacted on rescue).
- `@moduledoc` contains the 7-span event catalog table.
- `attach_default_handlers/0` is idempotent — wraps `attach_many` in `try/catch` for `:already_exists`.
- Oban spans in `attach_default_handlers/0` guarded by `Code.ensure_loaded?(Oban)`.

### 04-02-02: Instrument 7 lifecycle call sites ✅

All 7 spans were already instrumented (prior work):
- `trigger.ex`: `[:events, :create]` (wraps Multi insert) and `[:deliveries, :plan]` (wraps dispatch_after_trigger)
- `policy.ex`: `[:policy, :evaluate]` (wraps the `with` block + outcome metadata)
- `dispatch/sync.ex`: `[:dispatch, :sync]` (wraps `do_dispatch/1` call in `dispatch_delivery/1`)
- `dispatch/oban.ex`: `[:dispatch, :enqueue]` (in `enqueue_one/1` inside `Code.ensure_loaded?(Oban)`)
- `dispatch/oban_worker.ex`: `[:dispatch, :perform]` (in `perform/1` non-terminal path inside `Code.ensure_loaded?(Oban)`)
- `deliveries.ex`: `[:attempts, :record]` (wraps full Multi + transaction body)
- All call sites pass metadata through `Chimeway.Telemetry.safe_meta/1`.

### 04-02-03: Telemetry integration test ✅

- `test/chimeway/telemetry_integration_test.exs`: 8 tests.
- `setup` attaches a unique handler per test; `on_exit` detaches — no handler leak.
- Integration tests: all 5 mandatory `:stop` spans fire; no PII keys in any stop metadata; `notification_key` present in `events:create :stop`.
- `safe_meta/1` unit tests: drops atom PII keys; drops string PII keys; empty map for all-disallowed; preserves all 9 allowed keys.
- `attach_default_handlers/0` idempotency test: calling twice returns `:ok`.
- `mix test test/chimeway/telemetry_integration_test.exs --seed 0`: **8 tests, 0 failures**.
- Full suite: **123 tests, 1 failure** (pre-existing flaky `sync_test.exs:70` — async test uses global `Application.put_env`, unrelated to this plan).

## Deviations

1. **All 7 call sites were already instrumented** — prior partial work had implemented the spans before this plan ran. Verification confirmed correctness; fixed the `safe_meta` per-key error handling bug.
2. **`safe_meta/1` implementation uses `Map.take/2` after key normalization** rather than `Enum.reduce` with per-key filtering (both are equivalent; `Map.take` is more idiomatic).

## Security Gate

- TM-04-02-PII-IN-STOP-META (high): All span closures return `{result, safe_meta(%{...})}` — only allowed scalar fields. Integration test asserts no PII keys in any stop event. **PASS**.
- TM-04-02-OBAN-SPANS-WITHOUT-GUARD (medium): Both Oban modules wrapped at file level with `if Code.ensure_loaded?(Oban) do`. **PASS**.
- TM-04-02-HANDLER-LEAK-IN-TEST (low): `on_exit(fn -> :telemetry.detach(handler_id) end)` with `System.unique_integer()` suffix per test. **PASS**.
