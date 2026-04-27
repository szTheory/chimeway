---
phase: 11
phase_name: channel-adapter-safety-and-explainability-hardening
verified_at: 2026-04-24
status: gaps_found
score: 5/5
gaps:
  - id: GAP-11-01
    severity: blocker
    description: "`mix ci` fails — `mix format --check-formatted` reports 7 unformatted files. All failures are pre-existing (confirmed against commits before Phase 11). Phase 11 plan verification gate explicitly requires `mix ci` to pass."
    fix_plan: FIX-11-01
deferred:
  - item: "`lib/chimeway/dispatch/oban.ex` enqueue step-name `String.to_atom(\"enqueue_delivery_\")` atom creation"
    deferred_to: Phase 12
    evidence: "Plans 11-01 and 11-02 both document this as explicitly out of scope."
---

# Phase 11 Verification Report

## Goal
Remove unsafe channel atom conversion paths and preserve explainability for valid custom channels.

---

## Success Criteria Verification

### SC-1: Executor channel adapter resolution no longer creates atoms from runtime channel strings
**Status**: VERIFIED

**Evidence**:
- `lib/chimeway/dispatch/channel_adapter_config.ex` implements `resolve/2` using a string-keyed map lookup (`Application.get_env(:chimeway, :channel_adapter_configs, %{})`) as the preferred path and a legacy fallback that scans `Application.get_all_env(:chimeway)` using `Atom.to_string(key) == "adapter_#{channel}"` — no atom is ever created from the runtime channel string.
- `lib/chimeway/dispatch/executor.ex` line 16 calls `ChannelAdapterConfig.resolve(delivery.channel, [])` and contains no `String.to_atom/1` or interpolated atom creation from `delivery.channel`.
- Broader scan of `lib/` confirms the only `String.to_atom` call is `lib/chimeway/dispatch/oban.ex:68` for enqueue step-name, which is explicitly deferred to Phase 12.

**Artifacts**:
- `lib/chimeway/dispatch/channel_adapter_config.ex`
- `lib/chimeway/dispatch/executor.ex`

---

### SC-2: Operator explainability surfaces handle valid custom channels without raising conversion errors
**Status**: VERIFIED

**Evidence**:
- `lib/chimeway/traces.ex` line 135 assigns `channel: delivery.channel` directly — no `String.to_existing_atom/1` call anywhere in the file.
- `lib/chimeway/traces/explanation.ex` declares `channel: String.t()` in `@type t` and documents the field as a string with examples `"in_app"`, `"email"`, `"webhook_partner"`.
- The `build_timeline/4` helper in `traces.ex` also passes `delivery.channel` as a plain string in the `:delivery_planned` entry.

**Artifacts**:
- `lib/chimeway/traces.ex`
- `lib/chimeway/traces/explanation.ex`

---

### SC-3: Regression tests cover adapter lookup and explainability behavior for custom channel inputs
**Status**: VERIFIED

**Evidence**:
- `test/chimeway/dispatch/sync_test.exs`: two INTG-02-tagged tests in the `"custom channel adapter config resolution"` describe block. Preferred map path asserts `assert_receive {:adapter_config, [provider: "acme_sms", timeout_ms: 1500]}`. Legacy fallback path asserts `assert_receive {:adapter_config, [provider: "legacy_sms"]}`. Both exercise a test-local `Chimeway.Test.SyncCaptureConfigAdapter`.
- `test/chimeway/dispatch/oban_test.exs`: two INTG-02-tagged tests covering the Oban worker path for `"sms_custom"` channel. Preferred map and legacy fallback both covered; status transitions to `:succeeded` are asserted.
- `test/chimeway/dispatch/oban_worker_test.exs`: two INTG-02-tagged tests covering the Oban worker seam directly for `"sms_custom"`. Same preferred/legacy matrix; delivery status and config receipt both asserted.
- `test/chimeway/traces_test.exs`: two OPS-01-tagged tests in `"explain_delivery/1 — custom channel safety"` describe block. Both assert `{:ok, %Explanation{channel: "webhook_partner"}}` and the second also confirms `:delivery_planned` is present in the timeline.
- `test/chimeway/integration/delivery_lifecycle_test.exs`: Scenario F (OPS-01) triggers `ChimewayTest.Notifiers.LifecycleCustomChannel`, queries the persisted `webhook_partner` delivery row, asserts `delivery.status == :succeeded`, then calls `Traces.explain_delivery/1` and asserts `channel: "webhook_partner"` and `:delivery_planned` in timeline.

**Artifacts**:
- `test/chimeway/dispatch/sync_test.exs`
- `test/chimeway/dispatch/oban_test.exs`
- `test/chimeway/dispatch/oban_worker_test.exs`
- `test/chimeway/traces_test.exs`
- `test/chimeway/integration/delivery_lifecycle_test.exs`

---

## Artifact Table

| File | Exists | Substantive | Wired | Status |
|------|--------|-------------|-------|--------|
| `lib/chimeway/dispatch/channel_adapter_config.ex` | Yes | Yes | Yes | VERIFIED |
| `lib/chimeway/dispatch/executor.ex` | Yes | Yes | Yes | VERIFIED |
| `lib/chimeway/traces.ex` | Yes | Yes | Yes | VERIFIED |
| `lib/chimeway/traces/explanation.ex` | Yes | Yes | Yes | VERIFIED |
| `test/chimeway/dispatch/sync_test.exs` | Yes | Yes | Yes | VERIFIED |
| `test/chimeway/dispatch/oban_test.exs` | Yes | Yes | Yes | VERIFIED |
| `test/chimeway/dispatch/oban_worker_test.exs` | Yes | Yes | Yes | VERIFIED |
| `test/chimeway/traces_test.exs` | Yes | Yes | Yes | VERIFIED |
| `test/chimeway/integration/delivery_lifecycle_test.exs` | Yes | Yes | Yes | VERIFIED |

---

## Requirements Coverage

| Requirement | Status | Evidence |
|-------------|--------|----------|
| INTG-02 | SATISFIED | `ChannelAdapterConfig.resolve/2` eliminates all atom creation from runtime channel strings. Preferred string-keyed map and legacy `adapter_<channel>` fallback both tested in sync, oban, and oban_worker suites. INTG-02 markers are grep-visible in all three dispatch test files. |
| OPS-01 | SATISFIED | `explain_delivery/1` assigns `channel: delivery.channel` directly and returns `%Explanation{channel: "webhook_partner"}` for custom string channels without raising. OPS-01 markers present in `traces_test.exs` and `delivery_lifecycle_test.exs`. Integration test confirms trigger-to-trace path. |

---

## Anti-patterns

None found. Scanned all four modified production files:
- No `String.to_atom/1` in `executor.ex` or `channel_adapter_config.ex`
- No `String.to_existing_atom/1` in `traces.ex` or `explanation.ex`
- No TODO/FIXME/XXX/HACK markers in any Phase 11 production files
- `lib/chimeway/dispatch/oban.ex` retains `String.to_atom("enqueue_delivery_#{delivery.id}")` — intentionally deferred to Phase 12, not a Phase 11 gap

---

## Gaps

### GAP-11-01 — `mix ci` format gate failure (blocker)

`mix ci` exits 1 because `mix format --check-formatted` reports 7 unformatted files.

**All 7 failures are pre-existing**, confirmed by running `mix format --check-formatted` against the pre-Phase-11 state of each file:

| File | Pre-existing? | Issue |
|------|--------------|-------|
| `test/chimeway/dispatch/sync_test.exs` | Yes (Phase 7) | Missing blank lines around assert blocks |
| `test/chimeway/trigger_pipeline_test.exs` | Yes | Long `Repo.aggregate` call needs wrapping |
| `lib/chimeway/traces.ex` | Yes (Phase 6) | Long `policy_checkpoint:` map key line |
| `lib/chimeway/deliveries.ex` | Yes | Long `@spec` and `with` lines |
| `lib/chimeway/delivery_planning.ex` | Yes | Multiple long lines |
| `test/chimeway/policy/delayed_fallback_test.exs` | Yes | `recipients/1` line length |
| `lib/chimeway/trigger.ex` | Yes | Missing blank line before `dispatch_opts` |

Phase 11 plan `11-02-PLAN.md` verification gate includes `mix ci`. The gate cannot pass until these are resolved.

**Phase 11 logic is correct.** This is a CI hygiene gap, not a behavioral regression.

### Fix Plan: FIX-11-01

**Objective:** Satisfy the `mix ci` formatting gate.

**Tasks:**
1. Run `mix format` (formats all files to pass `--check-formatted`).
2. Verify no logic changes: `git diff lib/ test/` — all changes should be whitespace/wrapping only.
3. Run full verification:
   ```
   mix test test/chimeway/dispatch/sync_test.exs test/chimeway/dispatch/oban_test.exs test/chimeway/dispatch/oban_worker_test.exs test/chimeway/traces_test.exs test/chimeway/integration/delivery_lifecycle_test.exs
   mix ci
   ```
4. Commit: `style: run mix format to satisfy ci gate`.

After applying FIX-11-01, re-verify: status becomes `passed`, score remains `5/5`.

---

## Deferred Items (out of scope, not gaps)

- `lib/chimeway/dispatch/oban.ex` enqueue step-name atom creation (`String.to_atom("enqueue_delivery_")`) is explicitly in-scope for Phase 12, not Phase 11. Its continued presence is expected and correct per plans 11-01 and 11-02.
