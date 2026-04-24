---
status: issues
phase: 06-delivery-planning-and-policy-checkpoint-repair
updated: 2026-04-24T13:51:30Z
---

## Summary

- Advisory review completed for Phase 06 plans `06-01`, `06-02`, and `06-03`.
- Scope included runtime changes in delivery planning/dispatch plus added parity regression tests.
- Verification run: `mix test test/chimeway/trigger_pipeline_test.exs test/chimeway/dispatch/sync_test.exs test/chimeway/dispatch/oban_test.exs test/chimeway/policy_test.exs test/chimeway/integration/delivery_lifecycle_test.exs` (`33 tests, 0 failures`).
- Result: **3 findings** (1 high, 2 medium). No code was reverted (advisory gate only).

## Findings

### 1) High - Dynamic channel fanout enables unbounded atom creation in dispatch execution

**Where:** `lib/chimeway/delivery_planning.ex`, `lib/chimeway/dispatch/executor.ex`  
**What:** Planner now accepts arbitrary binary channels from `Notifier.channels/2`, persists them as `delivery.channel`, and executor derives adapter config keys via `String.to_atom("adapter_#{delivery.channel}")`.  
**Impact:** Repeated novel channel values can continuously allocate atoms (non-garbage-collected), creating a memory exhaustion / VM crash vector under malformed notifier output or hostile integration input.  
**Actionable remediation:** Remove runtime `String.to_atom/1` on delivery data. Use an allowlist-based channel map (string keys) or guarded `String.to_existing_atom/1` with explicit validation and a deterministic `{:error, :unsupported_channel}` path.

### 2) Medium - Trace explanation can crash on string-only channels introduced by fanout contract

**Where:** `lib/chimeway/traces.ex`  
**What:** `explain_delivery/1` still does `String.to_existing_atom(delivery.channel)`, but Phase 06 channel normalization allows plain strings from notifier callbacks.  
**Impact:** Deliveries planned with channel strings that are not already loaded atoms can raise `ArgumentError`, causing trace/explanation failures exactly where operators need diagnostics.  
**Actionable remediation:** Keep `channel` as a string in `Chimeway.Traces.Explanation` (or safely convert with fallback) and add regression coverage for fanout channels provided as strings.

### 3) Medium - Empty channel list is treated as success, producing silent no-delivery outcomes

**Where:** `lib/chimeway/delivery_planning.ex`  
**What:** `Notifier.channels/2` returning `{:ok, []}` passes normalization and returns `{:ok, []}` planning output with no suppression record and no error.  
**Impact:** Trigger/dispatch can report success while creating no delivery rows, losing auditable suppression provenance and making outcome interpretation ambiguous.  
**Actionable remediation:** Treat empty channel lists as invalid (`{:error, {:channels_resolution_failed, :empty_channels}}`) or persist an explicit suppressed delivery reason to preserve lifecycle traceability.

## Test/Risk Caveats

- Existing Phase 06 tests strongly cover planning/perform suppression parity and sync-vs-Oban behavior, but they do not currently assert behavior for arbitrary string channel names, atom-allocation safety, or empty-channel responses.
- Because those edges remain untested, operational risk persists even with the current green suite.
