# Phase 11 Research: Channel Adapter Safety and Explainability Hardening

**Phase**: 11 - Channel Adapter Safety and Explainability Hardening  
**Requirements**: INTG-02, OPS-01  
**Researched**: 2026-04-24  
**Status**: RESEARCH COMPLETE

---

## Executive Summary

Phase 11 should focus on two concrete breakpoints already identified by prior audits and still present in the code:

1. `Chimeway.Dispatch.Executor.run_delivery/1` creates runtime atoms from `delivery.channel` via `String.to_atom("adapter_#{delivery.channel}")` in `lib/chimeway/dispatch/executor.ex`.
2. `Chimeway.Traces.explain_delivery/1` can raise for valid custom channels by calling `String.to_existing_atom(delivery.channel)` in `lib/chimeway/traces.ex`.

Because `Chimeway.DeliveryPlanning` intentionally normalizes notifier channels to strings and `chimeway_deliveries.channel` is persisted as string (`lib/chimeway/delivery_planning.ex`, `lib/chimeway/delivery.ex`), both dynamic atom paths are incompatible with the current fanout contract. The safest implementation is to keep runtime channel handling string-native end-to-end and add a compatibility resolver for legacy channel adapter config keys that never creates atoms at runtime.

---

## Current-State Code Map (Phase 11 Scope)

### Primary in-scope modules

- `lib/chimeway/dispatch/executor.ex`
  - `run_delivery/1` resolves channel-specific adapter config with dynamic atom creation.
  - Shared execution seam for both sync and Oban worker paths.
- `lib/chimeway/traces.ex`
  - `explain_delivery/1` builds operator-facing explanation struct and currently atom-casts `delivery.channel`.
- `lib/chimeway/traces/explanation.ex`
  - Typespec and docs currently define `channel: atom()`, which conflicts with string-first channel persistence.

### Secondary modules impacted by behavior contracts

- `lib/chimeway/dispatch/sync.ex` and `lib/chimeway/dispatch/oban_worker.ex`
  - Both delegate to `Dispatch.Executor.run_delivery/1`; regression parity coverage must include both.
- `lib/chimeway/delivery_planning.ex`, `lib/chimeway/delivery.ex`, `lib/chimeway/deliveries.ex`
  - Already enforce string-safe planning/persistence behavior; these form the upstream contract that Phase 11 must honor.

### Adjacent but explicitly deferred (do not include in Phase 11 task scope)

- `lib/chimeway/dispatch/oban.ex`
  - `String.to_atom("enqueue_delivery_#{delivery.id}")` remains deferred to Phase 12 by decision D-05 in `11-CONTEXT.md`.

---

## Why This Matters for INTG-02 and OPS-01

### INTG-02 (adapter seam reliability)

- Current planner accepts custom channels (`Notifier.channels/2` supports `atom() | String.t()` in `lib/chimeway/notifier.ex`).
- Those channels persist as strings and flow into executor.
- Dynamic atom creation in executor can exhaust VM atom table under unbounded/novel channel values, violating safe adapter seam behavior.

### OPS-01 (operator explainability reliability)

- Operator trace call `Traces.explain_delivery/1` should not fail for valid persisted channel values.
- Existing `String.to_existing_atom/1` can raise on valid custom channels (e.g. `"sms"`, `"push"`, host-defined channels).
- A raising explainability surface directly violates the core value ("why was this sent/failed/suppressed?").

---

## Safe Alternatives to Runtime Atom Creation (Elixir, Repository-Applicable)

### Recommended target pattern (primary)

Use a static config key with string-keyed channel map, for example:

- `config :chimeway, :channel_adapter_configs, %{"in_app" => [...], "email" => [...], "my_custom" => [...]}`  

Runtime lookup then stays string-native:

- `channel = delivery.channel` (string)
- `adapter_config = get_in(config_map, [channel]) || []`

This avoids runtime atom creation entirely and matches existing string channel storage.

### Compatibility bridge (recommended for host-app stability)

Retain support for legacy per-channel env keys (e.g. `:adapter_email`) without creating atoms:

- Read all env once via `Application.get_all_env(:chimeway)`.
- Locate keys with `Atom.to_string(key) == "adapter_#{delivery.channel}"`.
- Use that value when new map config is absent.

This preserves existing host configuration if already declared in config files (atoms already exist) while blocking runtime atom creation from delivery data.

### Patterns to avoid

- `String.to_atom/1` on runtime channel strings.
- Interpolated atom creation (`:"adapter_#{channel}"`) from runtime values.
- `String.to_existing_atom/1` in operator APIs where channel values are not strictly atom-backed by design.

---

## Planner-Ready Task Decomposition Guidance

### Task A — Introduce atom-safe adapter config resolver

**Target files**:
- `lib/chimeway/dispatch/executor.ex` (or a new helper module under `lib/chimeway/dispatch/`)

**Deliverables**:
- Replace `String.to_atom("adapter_#{delivery.channel}")` path with a resolver that:
  1. Checks a string-keyed map config (new preferred contract).
  2. Falls back to scanning existing env keys for legacy `adapter_<channel>` names.
  3. Returns deterministic default `[]` when no config exists.

**Why this decomposition matters**:
- Keeps INTG-02 hardening localized to the shared seam used by sync and Oban worker.
- Minimizes risk of behavior drift across dispatch modes.

### Task B — Preserve explainability for custom channels

**Target files**:
- `lib/chimeway/traces.ex`
- `lib/chimeway/traces/explanation.ex`

**Deliverables**:
- Stop atom-casting `delivery.channel` in `explain_delivery/1`.
- Keep `Explanation.channel` string-safe (typespec + docs aligned to runtime behavior).
- Keep timeline/event semantics unchanged.

**Why this decomposition matters**:
- Directly addresses OPS-01 trace reliability without broad trace API redesign.

### Task C — Add regression coverage for shared executor + trace explainability

**Target files**:
- `test/chimeway/dispatch/sync_test.exs`
- `test/chimeway/dispatch/oban_worker_test.exs`
- `test/chimeway/dispatch/oban_test.exs` (enqueue-level behavior assertions)
- `test/chimeway/traces_test.exs`
- optionally `test/chimeway/integration/delivery_lifecycle_test.exs` for trigger-driven confidence

**Deliverables**:
- Custom-channel execution does not raise and records attempts through shared executor.
- Explainability returns `{:ok, %Explanation{}}` for custom channel rows.
- Built-in channels still behave as before.

---

## Regression Risks and Mitigations

| Risk | Severity | Where | Mitigation |
|---|---|---|---|
| Legacy channel config behavior changes silently | High | `dispatch/executor` | Compatibility resolver: new string map first, legacy env key scan fallback, default `[]` |
| Trace consumer expects atom channel | Medium | `traces/explanation` + tests/docs | Explicitly migrate `channel` contract to string; update tests (`traces_test.exs`) and docs comments |
| Sync/Oban drift after executor hardening | Medium | `sync.ex`, `oban_worker.ex` | Shared seam remains in executor; parity tests for both paths with custom channel delivery |
| Scope creep into Phase 12 atom debt | Medium | `dispatch/oban.ex` | Keep `enqueue_delivery_#{id}` atom issue documented but out of this phase implementation |
| False confidence from only happy-path tests | Medium | test suite | Include custom-channel negative/edge assertions (unknown config, non-raising explainability) |

---

## Dependency and Ordering Constraints

1. **Apply resolver hardening at shared seam first** (`dispatch/executor.ex`) so both sync and Oban worker inherit the fix immediately.
2. **Then harden explainability contract** (`traces.ex`, `traces/explanation.ex`) so OPS-01-facing APIs no longer atom-cast channel values.
3. **Then add/adjust tests** across sync, Oban worker, and traces to lock parity and prevent reintroduction.
4. **Keep deferred debt untouched in this phase**:
   - Oban multi step-name atom creation in `dispatch/oban.ex` remains Phase 12 scope.
5. **Roadmap sequencing note**:
   - Phase 11 depends on Phase 7 contracts and should avoid introducing changes that pre-empt Phase 12 transactional/Oban consistency scope.

---

## Validation Architecture

Validation should be requirement-mapped and run in two loops: focused phase loop and full project gate.

### 1) Fast focused loop (during task execution)

- `mix test test/chimeway/dispatch/sync_test.exs test/chimeway/dispatch/oban_worker_test.exs test/chimeway/dispatch/oban_test.exs test/chimeway/traces_test.exs`

Purpose:
- Verifies shared executor behavior is safe for custom channels (INTG-02).
- Verifies explainability path is non-raising for valid custom channels (OPS-01).

### 2) Integration confidence loop (before phase sign-off)

- `mix test test/chimeway/integration/delivery_lifecycle_test.exs test/chimeway/trigger_pipeline_test.exs`

Purpose:
- Confirms channel string contracts still hold in trigger -> planning -> dispatch lifecycle.

### 3) Full quality gate (pre-complete)

- `mix ci`

Purpose:
- Ensures lint/compile/tests remain green under project release conventions from `CONTRIBUTING.md` and `mix.exs`.

### 4) Static safety assertions (quick grep guardrails)

- `rg "String\\.to_atom\\(\"adapter_" lib/chimeway/dispatch`
- `rg "String\\.to_existing_atom\\(delivery\\.channel\\)" lib/chimeway`

Expected:
- No matches in production paths after Phase 11 changes.

### 5) Success criteria mapping

- **SC1 (Roadmap)**: executor no longer creates atoms from runtime channel strings  
  - Evidence: code diff in `dispatch/executor.ex` + focused dispatch tests
- **SC2 (Roadmap)**: explainability handles valid custom channels without conversion errors  
  - Evidence: `traces.ex` contract change + custom-channel trace tests
- **SC3 (Roadmap)**: regression tests cover adapter lookup + explainability for custom channels  
  - Evidence: updated tests in dispatch + traces suites

---

## Recommended Test Cases to Add (Concrete)

1. **Executor config lookup with custom channel string**
   - Seed delivery with channel `"sms_custom"`.
   - Assert dispatch path does not raise and adapter is called with deterministic config (or `[]` default).
2. **Legacy config fallback path**
   - Set `Application.put_env(:chimeway, :adapter_email, [...])`.
   - Assert email channel resolves legacy config without any runtime atom creation path.
3. **Trace explainability for custom channel**
   - Plan delivery with channel `"webhook_partner"`.
   - Assert `Traces.explain_delivery/1` returns `{:ok, exp}` and `exp.channel == "webhook_partner"`.
4. **Parity assertion across sync and Oban worker**
   - Reuse shared fixture style from `test/support/chimeway/dispatch_helpers.ex`.
   - Assert both paths handle custom-channel delivery via shared executor without crash.

---

## Open Questions

None blocking for planning. The phase can proceed with the compatibility-safe resolver approach documented above.

---

*Research completed: 2026-04-24*  
*Overall confidence: HIGH*
