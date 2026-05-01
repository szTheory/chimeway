---
phase: 29-outbound-channel-contracts
verified: 2026-04-30T22:14:00Z
status: passed
score: 12/12 must-haves verified
overrides_applied: 0
re_verification: null
---

# Phase 29: Outbound Channel Contracts Verification Report

**Phase Goal:** Host apps can configure and render notifications for non-email channels (SMS, Push) using standard adapter boundaries.
**Verified:** 2026-04-30T22:14:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

The phase goal is achieved end-to-end. The codebase delivers a public `Chimeway.Rendering.Channel` behaviour, three new built-in channel render-contract validators (Sms, Push, Chat) plus refactored Email/InApp, a three-layer `channel_module/1` resolver with `:channel_render_modules` registry overlay and once-flag telemetry on misses, boot-time validation guarding against typo'd modules, per-channel adapter resolution via `:channel_adapters` with legacy `:adapter` fallback (D-18), `adapter_module` persistence on attempt rows, trace-surface exposure of `adapter_module`, and full executable test coverage (506 tests, 0 failures).

### Observable Truths (consolidated from ROADMAP success criteria + plan must_haves)

| #  | Truth                                                                                                                                              | Status     | Evidence                                                                                                                                                                                                            |
| -- | -------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1  | SC-1: Operator can define a channel adapter for SMS or Push that implements Chimeway's behavior                                                    | VERIFIED   | `Chimeway.Adapter` behaviour exists; `:channel_adapters` config map resolves per-channel adapter via `Executor.resolve_adapter/1`; `validate_channel_render_modules!/0` validates host-defined render modules at boot |
| 2  | SC-2: Notification templates can define distinct render contracts for different channels (e.g. `text_body` for SMS vs `html_body` for email)      | VERIFIED   | `Channels.Sms` @types `%{text_body: :string}`; `Channels.Email` @types `%{subject, html_body, text_body}`; `Channels.Push` @types `%{title, body, data}`; `Channels.Chat` @types `%{text, rich_payload}`            |
| 3  | SC-3: The delivery engine correctly routes payloads to the specified non-email adapter                                                             | VERIFIED   | `Executor.resolve_adapter/1` (executor.ex:77-97) resolves per-channel adapter via `:channel_adapters` map; `run_delivery/1` calls `resolve_adapter(dispatched.channel)`; integration tests assert per-attempt adapter persistence |
| 4  | A public module `Chimeway.Rendering.Channel` exists with a single `@callback validate/1` and `__using__/1` macro                                  | VERIFIED   | lib/chimeway/rendering/channel.ex:36 declares `@callback validate(attrs :: map())`; lines 38-42 define `__using__/1` injecting `@behaviour`                                                                          |
| 5  | All five built-in channel modules declare `use Chimeway.Rendering.Channel` and `@impl Chimeway.Rendering.Channel`                                   | VERIFIED   | grep confirms 5 matches across email.ex, in_app.ex, sms.ex, push.ex, chat.ex; each has 1 `@impl` annotation                                                                                                          |
| 6  | `channel_module/1` resolves email/in_app/sms/push/chat via compiled clauses + host-configured channels via `:channel_render_modules` registry      | VERIFIED   | rendering.ex:232-236 has 5 compiled clauses; rendering.ex:240 registry lookup via `Application.get_env(:chimeway, :channel_render_modules, %{}) \|> Map.get(channel)`                                                |
| 7  | Unknown channels emit `[:chimeway, :rendering, :channel_unregistered]` telemetry once per channel per BEAM lifetime via `:persistent_term`         | VERIFIED   | rendering.ex:245-258: `:persistent_term.get` once-flag check, `:telemetry.execute`, `Logger.warning`, `:persistent_term.put`; telemetry_integration_test.exs:163-198 asserts emit + refute on second call          |
| 8  | Boot-time validation rejects typo'd modules in `:channel_render_modules` (raises ArgumentError)                                                    | VERIFIED   | application.ex:41-65 `validate_channel_render_modules!/0` with cond chain checking `is_atom`, `Code.ensure_loaded?`, `function_exported?(:validate, 1)`; application_validation_test.exs has 3+ assert_raise tests |
| 9  | `chimeway_delivery_attempts.adapter_module` nullable string column exists; DeliveryAttempt schema casts the field                                 | VERIFIED   | Migration 20260430120000 adds `adapter_module :string null: true`; delivery_attempt.ex:44 declares `field(:adapter_module, :string)`; line 54 includes `:adapter_module` in `@optional_fields`                       |
| 10 | `Executor.run_delivery/1` persists `adapter_module: inspect(adapter)` on attempt; SMS routes to SMS-configured adapter; legacy `:adapter` fallback works | VERIFIED   | executor.ex:32 calls `resolve_adapter(dispatched.channel)`; line 45 passes `adapter_module: inspect(adapter)` to `record_attempt/2`; delivery_lifecycle_test.exs:437,463,480 assert per-adapter persistence; D-21 cross-attempt diff at line 483 |
| 11 | `[:chimeway, :dispatch, :adapter_fallback]` telemetry fires only when `:channel_adapters` is set AND lookup misses (D-19)                          | VERIFIED   | executor.ex:84-90 gates emit on `map_size(channel_adapters) > 0`; telemetry_integration_test.exs:201-260 has positive + negative cases; both assertions pass                                                          |
| 12 | `[:chimeway, :dispatch, :sync, :stop]` stop metadata includes `adapter_module`; trace `explain_delivery/1` surfaces `adapter_module` in last_attempt and timeline detail | VERIFIED   | sync.ex:94-107 threads `adapter_module` into stop_meta via safe_meta; traces.ex:281 in build_last_attempt_map; traces.ex:403 in attempt_entries detail; explanation.ex:63 typespec includes `adapter_module: String.t() \| nil` |

**Score:** 12/12 truths verified

### Required Artifacts

| Artifact                                                                                                  | Expected                                                          | Status     | Details                                                              |
| --------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------- | ---------- | -------------------------------------------------------------------- |
| `lib/chimeway/rendering/channel.ex`                                                                       | Public behaviour + __using__ macro                                | VERIFIED   | 43 lines; single `@callback validate/1`; macro injects `@behaviour`  |
| `lib/chimeway/rendering/channels/sms.ex`                                                                  | SMS validator (text_body required, vendor strip)                  | VERIFIED   | 50 lines; `@types %{text_body: :string}`; `use` + `@impl` declared   |
| `lib/chimeway/rendering/channels/push.ex`                                                                 | Push validator (title+body required, optional data map)           | VERIFIED   | 49 lines; `@types %{title, body, data}`; `use` + `@impl`             |
| `lib/chimeway/rendering/channels/chat.ex`                                                                 | Chat validator (text required, optional rich_payload)             | VERIFIED   | 48 lines; `@types %{text, rich_payload}`; `use` + `@impl`            |
| `lib/chimeway/rendering/channels/email.ex` (refactored)                                                   | use macro + @impl annotation                                      | VERIFIED   | line 6 `use`, line 18 `@impl`                                        |
| `lib/chimeway/rendering/channels/in_app.ex` (refactored)                                                  | use macro + @impl annotation                                      | VERIFIED   | line 6 `use`, line 18 `@impl`; nested `validate_primary_action` intact |
| `priv/repo/migrations/20260430120000_add_adapter_module_to_chimeway_delivery_attempts.exs`               | Reversible migration adding nullable adapter_module column        | VERIFIED   | `def change` with `add :adapter_module, :string, null: true`         |
| `lib/chimeway/delivery_attempt.ex`                                                                        | Schema field + cast allowlist for adapter_module                  | VERIFIED   | line 44 schema field; line 54 in @optional_fields                    |
| `lib/chimeway/rendering.ex`                                                                               | Three-layer channel_module/1 with persistent_term once-flag       | VERIFIED   | 5 compiled clauses + registry layer + telemetry/persistent_term + Logger.warning |
| `lib/chimeway/application.ex`                                                                             | validate_channel_render_modules!/0 boot guard                     | VERIFIED   | lines 41-65; called from start/2 line 10                              |
| `lib/chimeway/telemetry.ex`                                                                               | adapter_module in @allowed_meta_keys                              | VERIFIED   | line 83 includes `adapter_module`; moduledoc line 33 also lists it   |
| `lib/chimeway/dispatch/executor.ex`                                                                       | resolve_adapter/1 + adapter_module persistence                    | VERIFIED   | resolve_adapter at line 77; adapter_module: inspect(adapter) at line 45 |
| `lib/chimeway/dispatch/sync.ex`                                                                           | adapter_module threaded into :sync,:stop metadata                 | VERIFIED   | do_dispatch returns {result, adapter_module}; do_dispatch_with_telemetry merges into safe_meta |
| `lib/chimeway/traces.ex`                                                                                  | adapter_module in build_last_attempt_map and attempt_entries detail | VERIFIED | 2 occurrences of `adapter_module: attempt.adapter_module` (lines 281, 403) |
| `lib/chimeway/traces/explanation.ex`                                                                      | adapter_module in @type t last_attempt + moduledoc                | VERIFIED   | line 63 `adapter_module: String.t() \| nil`; moduledoc line 32       |
| `lib/chimeway/adapters/test.ex`                                                                           | Channel-tagged mailbox send                                       | VERIFIED   | line 30 `send(self(), {:chimeway_delivery, delivery.channel, delivery})` |
| `test/chimeway/rendering/channel_contract_test.exs`                                                       | Sms/Push/Chat round-trip + registry-overlay tests                 | VERIFIED   | describe blocks for SMS, Push, Chat, registry-overlay; tests pass    |
| `test/chimeway/application_validation_test.exs`                                                           | D-13 boot validation tests                                        | VERIFIED   | 3 `assert_raise ArgumentError` (non-existent, missing-validate, non-atom); pass |
| `test/chimeway/integration/delivery_lifecycle_test.exs`                                                   | adapter_module assertion + D-21 per-attempt diff                  | VERIFIED   | lines 437, 463, 480, 483 — all assertions pass                       |
| `test/chimeway/telemetry_integration_test.exs`                                                            | channel_unregistered + adapter_fallback positive/negative          | VERIFIED   | describe blocks at lines 163, 201, 254 — all pass                     |

### Key Link Verification

| From                                          | To                                              | Via                                                          | Status   | Details                                                                              |
| --------------------------------------------- | ----------------------------------------------- | ------------------------------------------------------------ | -------- | ------------------------------------------------------------------------------------ |
| Channel validators (5 files)                  | `Chimeway.Rendering.Channel` behaviour          | `use Chimeway.Rendering.Channel`                             | WIRED    | grep confirms 5 matches; all compile cleanly with @impl annotations                   |
| `Chimeway.Rendering.channel_module/1`         | `Application.get_env(:channel_render_modules)`  | `Map.get(registry, channel)` in fallback clause              | WIRED    | rendering.ex:240 — registry lookup before telemetry emit                              |
| `Chimeway.Application.start/2`                | `validate_channel_render_modules!/0`            | direct call at top of start/2                                | WIRED    | application.ex:10 invokes guard before children boot                                 |
| `Chimeway.Dispatch.Executor.run_delivery/1`   | `Application.get_env(:channel_adapters)`        | `Map.get(channel_adapters, channel)` in resolve_adapter/1    | WIRED    | executor.ex:78,80 — per-channel resolution                                            |
| `Chimeway.Dispatch.Executor`                  | `Deliveries.record_attempt/2`                   | attrs map containing `adapter_module: inspect(adapter)`      | WIRED    | executor.ex:45 — string persisted (no Elixir. prefix)                                 |
| `Chimeway.Dispatch.Sync.do_dispatch_with_telemetry` | `:sync, :stop` telemetry stop metadata    | `Telemetry.safe_meta(%{outcome:, adapter_module:})`          | WIRED    | sync.ex:99-105 — adapter_module merged via safe_meta filter                          |
| `Chimeway.Traces.build_last_attempt_map`      | preloaded `attempt.adapter_module`              | `adapter_module: attempt.adapter_module` map key             | WIRED    | traces.ex:281 — direct field access from preloaded struct                            |
| `Chimeway.Traces` attempt_entries Enum.map    | preloaded `attempt.adapter_module`              | per-attempt detail map key                                   | WIRED    | traces.ex:403 — same field surfaced in timeline entries                              |

### Data-Flow Trace (Level 4)

| Artifact                                  | Data Variable          | Source                                                          | Produces Real Data | Status   |
| ----------------------------------------- | ---------------------- | --------------------------------------------------------------- | ------------------ | -------- |
| `Channels.Sms.validate/1`                 | `attrs` map            | Caller-supplied (host app `rendering/2` or `Rendering.render_delivery`) | Yes               | FLOWING  |
| `Channels.Push.validate/1`                | `attrs` map            | Same                                                            | Yes                | FLOWING  |
| `Channels.Chat.validate/1`                | `attrs` map            | Same                                                            | Yes                | FLOWING  |
| `Executor.resolve_adapter/1`              | `:channel_adapters` map | `Application.get_env(:chimeway, :channel_adapters, %{})`        | Yes (driven by host `config :chimeway, :channel_adapters, %{}` at runtime) | FLOWING |
| `Executor.run_delivery/1` adapter_module persist | `inspect(adapter)`     | resolved compile-time atom from `:channel_adapters` map         | Yes                | FLOWING  |
| `Traces.explain_delivery/1` last_attempt  | `attempt.adapter_module` | preloaded from `chimeway_delivery_attempts.adapter_module` column | Yes (post-migration; nil for pre-Phase-29 rows by design) | FLOWING |

### Behavioral Spot-Checks

| Behavior                                                                 | Command                                                                            | Result                | Status |
| ------------------------------------------------------------------------ | ---------------------------------------------------------------------------------- | --------------------- | ------ |
| Full test suite passes                                                   | `mix test`                                                                         | 506 tests, 0 failures | PASS   |
| Codebase compiles cleanly                                                | `mix compile`                                                                      | exits 0, app generated | PASS   |
| Channel-related tests pass (rendering + adapter resolution + boot validation) | `mix test test/chimeway/rendering/channel_contract_test.exs ...`                  | 46 tests, 0 failures  | PASS   |
| Five `use Chimeway.Rendering.Channel` declarations across channels       | `grep -rn "use Chimeway.Rendering.Channel" lib/chimeway/rendering/channels/`        | 5 matches             | PASS   |
| All channels have `@impl Chimeway.Rendering.Channel` annotation          | `grep -c "@impl Chimeway.Rendering.Channel" lib/chimeway/rendering/channels/*.ex`  | 1 each (5 files)      | PASS   |

### Requirements Coverage

| Requirement | Source Plan(s) | Description                                                                                              | Status     | Evidence                                                                                                                                  |
| ----------- | -------------- | -------------------------------------------------------------------------------------------------------- | ---------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| CHAN-01     | 29-01, 29-02, 29-03, 29-04, 29-05, 29-06, 29-07 | System supports generic outbound channel adapters (SMS, Push, Chat) without hard-coupling to specific vendor SDKs | SATISFIED  | `Chimeway.Rendering.Channel` behaviour formalises render contract; `:channel_adapters` registry supports per-channel adapter modules; `:channel_render_modules` registry supports host-defined render validators; `Adapter` behaviour is vendor-agnostic; vendor fields stripped by Ecto cast/3 |
| CHAN-02     | 29-01, 29-03, 29-04, 29-07                       | Channel-specific rendering contracts exist to format payloads appropriately for different channels       | SATISFIED  | Email (`html_body`+`text_body`+`subject`), Sms (`text_body` only), Push (`title`+`body`+`data`), Chat (`text`+`rich_payload`), InApp (`headline`+`body`+`primary_action`) — each with distinct `@types` and `@required_fields`; `channel_contract_test.exs` proves round-trip for all five with vendor-field stripping |

No orphaned requirements — REQUIREMENTS.md maps Phase 29 to exactly CHAN-01 and CHAN-02; both appear in plan frontmatter and are satisfied.

### Anti-Patterns Found

| File                                       | Line     | Pattern                                                              | Severity | Impact                                                                                                                                                                  |
| ------------------------------------------ | -------- | -------------------------------------------------------------------- | -------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `lib/chimeway/dispatch/executor.ex`        | 74-76    | Misleading comment: "Map.get/2 against pre-existing atom keys" — implementation uses string keys (function head guards `is_binary(channel)`); contradicts production behavior | Warning  | CR-01 from code review. Documentation defect — risk that future readers register `:channel_adapters` with atom keys based on the comment, silently breaking per-channel routing in host configs. Does NOT block goal achievement: the implementation is correct, all tests use string keys correctly (e.g., `%{"sms" => MyAdapter}`), and the production behavior is verified. Recommend follow-up commit to correct comment to "string keys". |
| (none other)                               | —        | Stub patterns / TODO / FIXME / hardcoded empties / orphaned exports  | —        | grep across modified Phase-29 files surfaced no stub returns, no TODO/FIXME, no hardcoded empty data going to render. All exports verified WIRED.                          |

### Human Verification Required

None — all 12 must-haves were verifiable programmatically through code inspection, key-link tracing, and full test-suite execution (506 tests, 0 failures). The phase is library/back-end work with no UI surface, no real-time behavior, no external service integration in scope, and no visual rendering. Future phases involving actual SMS/Push provider integrations will require human-in-the-loop verification, but Phase 29's scope is the contract layer only.

### Gaps Summary

No gaps. The phase delivers exactly what the goal requires:

1. **Standard adapter boundaries** — `Chimeway.Adapter` behaviour (pre-existing) plus `:channel_adapters` config registry resolved per-delivery in `Executor.resolve_adapter/1`.
2. **Channel-specific render contracts** — five built-in channel validators (Email, InApp, Sms, Push, Chat) all declaring `@behaviour Chimeway.Rendering.Channel` with distinct `@types` field shapes; host-defined channels register through `:channel_render_modules`, validated at boot.
3. **Routing to non-email adapter** — executor calls `resolve_adapter(dispatched.channel)`; adapter_module persisted on attempt row as `inspect(adapter)`; integration test (delivery_lifecycle_test.exs:483) explicitly proves `attempt1.adapter_module != attempt2.adapter_module` when adapters differ.

The CR-01 BLOCKER from the code review is a comment-vs-implementation drift (documentation defect), not a functional gap. The implementation is string-keyed, tests assert string keys, and the production routing is verified correct. Recommend addressing as a follow-up doc-only commit; does not block phase closure.

The 6 WARNING-level review findings (unbounded `:persistent_term` growth from many distinct unknown channels, dispatcher metric outcome conflation, semantic ambiguity of empty-map config, code duplication across the five validators, etc.) are quality observations addressed by accepted design decisions in the threat register (T-29-14b accept) or are non-goal-blocking refactor opportunities for follow-up phases.

---

_Verified: 2026-04-30T22:14:00Z_
_Verifier: Claude (gsd-verifier)_
