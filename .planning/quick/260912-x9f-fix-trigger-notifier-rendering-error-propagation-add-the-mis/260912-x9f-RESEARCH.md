# Quick 260912-x9f: Trigger Rendering Error and Mounted Bell Proof - Research

**Researched:** 2026-09-13
**Domain:** Elixir/Ecto transaction error propagation and Phoenix LiveView integration proof
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Core change contract
- **D-01:** Publish only a closed versioned reload hint with `tenant_id`, opaque `recipient_ref`, and event class `created | seen | read | archived`; never publish notification payload, metadata, addresses, tokens, or caller context.
- **D-02:** Core defines the publisher behaviour and a no-op default. Phoenix, Phoenix PubSub, and `chimeway_inbox` remain absent from root dependencies and compile paths.
- **D-03:** Creation hints run only after the event/notification transaction commits. Lifecycle hints run only after the first exact tenant/recipient conditional update succeeds.
- **D-04:** Repeated seen/read/archive calls are idempotent and publish no duplicate hint. Duplicate triggers publish no creation hint.
- **D-05:** Publisher `{:error, _}`, unexpected returns, exits, throws, and exceptions never change the durable API result. Emit only stable success/failure telemetry classification.

#### Optional Phoenix adapter
- **D-06:** `chimeway_inbox` supplies the Phoenix PubSub publisher; hosts opt in by configuring it as Chimeway's publisher plus a PubSub server and a high-entropy topic secret.
- **D-07:** Topics are HMAC-derived from a length-delimited tenant/recipient tuple and expose neither input. Messages are the closed tuple `{:chimeway_inbox, :reload, 1}` with no identity or record data.
- **D-08:** Subscribe only during connected mount, after `on_mount` has authorized a nonblank tenant and opaque recipient. Missing/unsafe config fails closed without crashing the disconnected render.
- **D-09:** On a reload message, re-check current host authorization before querying. Authorization drift redirects; a relevant message reloads first-page items and badge from Chimeway's tenant-scoped APIs; unrelated messages are ignored.

#### Scope continuity
- **D-10:** Preserve existing visual markup, copy, pagination, and explicit row-read behavior. Real-time reload resets the visible collection to the authoritative first page.
- **D-11:** Archive publishing becomes first-transition-only without implicitly marking read or seen.
- **D-12:** All fixtures use synthetic opaque references and prove cross-tenant/cross-recipient non-delivery without logging topic inputs.

### the agent's Discretion

- Exact module names, telemetry suffix, and test fixture helpers may follow existing project conventions if these boundaries remain explicit and executable.

### Deferred Ideas (OUT OF SCOPE)

- Bell-panel `mark_seen` and once-only workflow progression: Phase 106.
- Operator seen/read timeline, integration guide, and final named release contract: Phase 107.
- WebSockets outside Phoenix PubSub, durable client cursors, mobile background sync, and per-item delta payloads: future work.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| INBX-03 | A host can opt into a replaceable inbox-change publisher that emits a closed event only after durable notification creation or a first seen, read, or archive transition, without adding Phoenix or PubSub as a core dependency. | The reducer fix restores the documented error tuple while retaining transaction rollback and post-commit-only publication. [VERIFIED: `.planning/REQUIREMENTS.md:14-17`; `lib/chimeway/trigger.ex:94-128,234-308,356-418`] |
| INBX-04 | A connected `chimeway_inbox` bell subscribes only to its currently authorized tenant and opaque recipient stream and refreshes its badge and visible items on relevant arrival and lifecycle events without polling or cross-tenant disclosure. | The mounted demo test can exercise the already-wired public Trigger → configured publisher → HMAC topic → LiveView reload chain. [VERIFIED: `.planning/REQUIREMENTS.md:14-17`; `examples/chimeway_demo_host/config/config.exs:17-23`; `chimeway_inbox/lib/chimeway_inbox/live/bell_dropdown_live.ex:14-50`] |
</phase_requirements>

## Summary

`Trigger.notifications_attrs/6` uses `Enum.reduce_while/3`, but the callback's `with` expression returns a bare `{:error, reason}` when rendering, orchestration, or workflow resolution fails. `Enum.reduce_while/3` accepts only `{:cont, accumulator}` or `{:halt, accumulator}`, so the next reducer dispatch raises `FunctionClauseError` before the existing final error clause can run. [VERIFIED: `lib/chimeway/trigger.ex:256-308`] A direct test-environment probe reproduced `FunctionClauseError: no function clause matching in Enumerable.List.reduce/3` for a notifier returning `{:error, :forced_rendering_failure}`; a follow-up query found `EVENT_COUNT=0`, confirming rollback despite the wrong public behavior. [VERIFIED: local `MIX_ENV=test mix run` probe on 2026-09-13]

The smallest safe correction is an `else` clause inside the reducer callback that converts any existing tagged error into `{:halt, error}`. The already-present terminal case then returns the error unchanged, `Ecto.Multi.run/3` rolls back, and `normalize_trigger_result/3` produces the public wrapper. The exact existing public path is quoted as `{:error, {:notifications_insert_failed, reason}}`. [VERIFIED: `lib/chimeway/trigger.ex:256-308,412-418`]

Add exactly two behavior tests: one core test proving a rendering error returns the expected tuple, persists neither event nor notification, and publishes no hint; one demo-host LiveView test that mounts first, invokes public `Chimeway.trigger/3`, and observes the bell refresh without direct inserts, manual publisher calls, or polling. [VERIFIED: existing partial seams in `test/chimeway/trigger_inbox_change_test.exs:81-129`, `chimeway_inbox/test/chimeway_inbox/live/bell_dropdown_live_test.exs`, and `examples/chimeway_demo_host/test/demo_host_web/inbox_bell_proof_test.exs:34-62`]

**Primary recommendation:** modify only `lib/chimeway/trigger.ex` plus the two existing focused test files; do not redesign rendering, transactions, PubSub, or LiveView state.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Rendering error normalization | API / Backend | Database / Storage | Trigger owns public orchestration; Ecto.Multi owns rollback. [VERIFIED: `lib/chimeway/trigger.ex:45-129,234-308,397-418`] |
| Post-commit creation hint | API / Backend | Frontend Server | Trigger publishes only after transaction normalization; the optional adapter transports the closed hint. [VERIFIED: `lib/chimeway/trigger.ex:356-394`; `chimeway_inbox/lib/chimeway_inbox/pub_sub_publisher.ex:14-21`] |
| Mounted bell refresh proof | Frontend Server (LiveView) | API / Backend | The bell subscribes on connected mount and reloads through public tenant-scoped APIs after a message. [VERIFIED: `chimeway_inbox/lib/chimeway_inbox/live/bell_dropdown_live.ex:14-50,210-248`] |

## Project Constraints (from AGENTS.md)

- Use Elixir 1.17+ / OTP 26+, Ecto 3.x + PostgreSQL 15+, with Phoenix limited to optional integration surfaces. [VERIFIED: `AGENTS.md:9-15`; verbatim values: `Elixir 1.17+ / OTP 26+`, `Ecto 3.x + PostgreSQL 15+`, `Phoenix 1.7/1.8 (optional integration surfaces)`]
- Preserve stable notification identity, the event → notification → delivery → attempt lifecycle, first-class idempotency/suppression behavior, replaceable adapters with contract tests, and host-owned auth/tenancy/URL/correlation boundaries. [VERIFIED: `AGENTS.md:17-23`]
- Maintain `mix verify.*` and `mix ci.*` entrypoints in local/CI parity and never leak sensitive payload fields through telemetry or operator surfaces. [VERIFIED: `AGENTS.md:25-32`]
- Use executable evidence for objective acceptance; do not add conversational UAT or a human checkpoint. [VERIFIED: `AGENTS.md:30-32`]

## Standard Stack

No new package or framework is needed. Use the repository's existing `Enum.reduce_while/3`, `Ecto.Multi`, ExUnit, Phoenix PubSub adapter, and `Phoenix.LiveViewTest`. [VERIFIED: `lib/chimeway/trigger.ex:42,94-109,259-308`; `examples/chimeway_demo_host/test/demo_host_web/inbox_bell_proof_test.exs:7-18`]

## Root Cause and Smallest Safe Code Shape

The reducer currently emits the success control tuple but has no error control tuple. Preserve its current success branch and add only:

```elixir
      else
        {:error, _reason} = error -> {:halt, error}
      end
```

[VERIFIED pattern source: `lib/chimeway/trigger.ex:259-308`; the existing downstream error form is quoted verbatim: `{:error, _reason} = error -> error` at lines 305-308]

This shape is preferable to rescuing around `Notifier.resolve_rendering/3`: returned contract errors are expected values, while notifier exceptions remain a separate API-policy question outside this stabilization item. [VERIFIED: `lib/chimeway/rendering.ex:28-54,88-111`; `[ASSUMED]` scope recommendation based on the quick-task boundary]

Expected propagation after the patch:

```text
Rendering.resolve_declaration/3
  -> {:error, {:rendering_resolution_failed, reason}}
notifications_attrs/6
  -> {:halt, same_error}
Ecto.Multi.run(:notifications, ...)
  -> transaction rollback
normalize_trigger_result/3
  -> {:error, {:notifications_insert_failed, same_reason}}
```

[VERIFIED: `lib/chimeway/rendering.ex:28-54,88-111`; `lib/chimeway/trigger.ex:94-128,234-308,397-418`]

## Exact Test Changes

### 1. Core rollback/no-publish contract

**File:** `test/chimeway/trigger_inbox_change_test.exs`

- Add a synthetic `RenderingFailureNotifier` implementing the existing notifier behaviour and returning `{:error, :forced_rendering_failure}` from `rendering/2`. Keep its recipient an opaque synthetic `cw_...` reference. [VERIFIED precedent: `test/chimeway/trigger_inbox_change_test.exs:11-40`; opaque-fixture constraint: `.planning/phases/105-tenant-safe-inbox-change-stream/105-CONTEXT.md:30-36`]
- Under the existing `RecordingPublisher` setup, invoke `Trigger.trigger/3` with a unique idempotency key and assert exactly:

```elixir
{:error,
 {:notifications_insert_failed,
  {:rendering_resolution_failed, :forced_rendering_failure}}}
```

[VERIFIED error construction: `lib/chimeway/rendering.ex:107-111`; `lib/chimeway/trigger.ex:412-418`]

- Assert the event with that idempotency key does not exist, no notification exists for the test tenant, and `refute_receive {:change, _, _}`. This simultaneously locks rollback and no post-commit publication. [VERIFIED transaction and publication boundaries: `lib/chimeway/trigger.ex:94-109,356-394`; existing test idiom: `test/chimeway/trigger_inbox_change_test.exs:104-117`]

### 2. Mounted Trigger-to-bell refresh contract

**File:** `examples/chimeway_demo_host/test/demo_host_web/inbox_bell_proof_test.exs`

- Mount `/inbox` for Alex first and assert the unique notification is absent. [VERIFIED mount pattern: `examples/chimeway_demo_host/test/demo_host_web/inbox_bell_proof_test.exs:34-49`]
- Call public `Chimeway.trigger/3` directly with `DemoHost.Notifiers.InviteSent`, Alex's email, a unique synthetic team name/idempotency key, and `tenant_id: DemoHost.Seeds.tenant_id()`. The notifier maps that email to the same opaque recipient identity authorized by the bell. [VERIFIED: `examples/chimeway_demo_host/lib/demo_host/notifiers/invite_sent.ex:9-49`; `examples/chimeway_demo_host/lib/demo_host/seeds.ex:42-67`]
- Call `render(view)` after Trigger returns and assert the badge changes to `Notifications, 1 unread`; then open the panel and assert the unique rendered subject/item is present. Do not call `ChimewayInbox.PubSubPublisher`, `ChangeStream.broadcast_topic/1`, or a direct insert helper in this test. [VERIFIED existing UI hooks/copy: `chimeway_inbox/lib/chimeway_inbox/live/bell_dropdown_live.ex:130-205,268-276`; existing refresh idiom: `chimeway_inbox/test/chimeway_inbox/live/bell_dropdown_live_test.exs`]

The demo host already configures the exact production bridge: `inbox_change_publisher: ChimewayInbox.PubSubPublisher`, `pubsub_server: DemoHost.PubSub`, and a topic secret. [VERIFIED: `examples/chimeway_demo_host/config/config.exs:17-23`; quoted values verbatim]

## Integration Points and Verification

| File | Change | Why |
|------|--------|-----|
| `lib/chimeway/trigger.ex` | Add tagged-error `{:halt, error}` to the notification attribute reducer. | Restores normal Ecto.Multi error propagation. |
| `test/chimeway/trigger_inbox_change_test.exs` | Add returned-error rollback/no-publish contract. | Prevents regression to an exception or accidental publication. |
| `examples/chimeway_demo_host/test/demo_host_web/inbox_bell_proof_test.exs` | Add mounted public Trigger arrival proof. | Closes the only missing end-to-end seam. |

All three paths are already in the named inbox gate: root trigger tests and the demo-host `:inbox` suite appear in the five ordered `verify.inbox` commands. [VERIFIED: `mix.exs:160-167`; quoted gate name: `verify.inbox`]

Run in order:

```bash
scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/trigger_inbox_change_test.exs --warnings-as-errors
cd examples/chimeway_demo_host && mix test test/demo_host_web/inbox_bell_proof_test.exs --only inbox --warnings-as-errors
mix verify.inbox
```

[VERIFIED command precedents: `.planning/phases/105-tenant-safe-inbox-change-stream/105-VALIDATION.md`; aggregate definition: `mix.exs:160-167`]

## Risks and Guardrails

- **Double-wrapping the error:** `{:halt, {:error, error}}` would corrupt the existing shape. Halt with the already-tagged error unchanged. [VERIFIED: `lib/chimeway/trigger.ex:305-308,412-418`]
- **Publishing on failure:** do not move `ChangePublisher.publish/3`; it must remain reachable only from successful post-transaction normalization. [VERIFIED: `lib/chimeway/trigger.ex:356-394`]
- **Over-broad exception semantics:** do not add a rescue around notifier rendering in this quick item; that changes behavior beyond the reproduced returned-error bug. [ASSUMED: bounded-scope recommendation]
- **False E2E proof:** a test that inserts a notification directly or broadcasts manually repeats existing partial tests and does not close the audit finding. [VERIFIED: gap statement in `.planning/v1.19-MILESTONE-AUDIT.md:88-95`; existing partial tests in Phase 105 suites]
- **Global config interference:** keep the demo proof `async: false` as it already is; the demo uses configured application publisher/auth state and shared SQL sandbox mode. [VERIFIED: `examples/chimeway_demo_host/test/demo_host_web/inbox_bell_proof_test.exs:7-18`; `examples/chimeway_demo_host/test/support/conn_case.ex:14-22`]
- **Privacy drift:** use only synthetic team/idempotency values and the existing opaque recipient derivation; make no assertions involving raw topic values. [VERIFIED: `examples/chimeway_demo_host/lib/demo_host/seeds.ex:42-67`; `.planning/phases/105-tenant-safe-inbox-change-stream/105-CONTEXT.md:18-33`]

## Validation Architecture

| Requirement | Behavior | Test Type | Automated Command | File Exists? |
|-------------|----------|-----------|-------------------|-------------|
| INBX-03 | Returned rendering error rolls back event/notification and emits no creation hint | DB integration | focused root command above | ✅ extend existing file |
| INBX-04 | Trigger after connected mount refreshes the authorized bell without polling | mounted LiveView integration | focused demo command above | ✅ extend existing file |

**Sampling:** run the focused root test after the reducer change, the focused demo test after adding the mounted proof, then `mix verify.inbox` as the batch gate. [VERIFIED: `.planning/phases/105-tenant-safe-inbox-change-stream/105-VALIDATION.md`; `mix.exs:160-167`]

## Security Domain

Relevant controls are access control, input/error validation, and data protection. The patch must preserve exact tenant/opaque-recipient scoping, closed PubSub messages, authorization-before-reload, and no payload/topic logging. Authentication/session and cryptography implementations do not change. [VERIFIED: `chimeway_inbox/lib/chimeway_inbox/change_stream.ex:12-90`; `chimeway_inbox/lib/chimeway_inbox/live/bell_dropdown_live.ex:31-50`; Phase 105 D-01/D-07/D-09]

## Assumptions Log

| # | Claim | Risk if Wrong |
|---|-------|---------------|
| A1 | Returned notifier errors, not thrown notifier exceptions, are the intended boundary of this quick fix. | Expanding exception containment could require a separate public API decision and more adversarial tests. |

## Open Questions

None blocking. The implementation and both regression seams are fully identifiable in the current tree. [VERIFIED: local source/test inspection and reproduced failure on 2026-09-13]

## Sources

- `lib/chimeway/trigger.ex` — reducer, transaction, normalization, and post-commit publisher boundary.
- `lib/chimeway/rendering.ex` — rendering resolution error shapes.
- `test/chimeway/trigger_inbox_change_test.exs` — existing core integration fixtures and assertions.
- `chimeway_inbox/lib/chimeway_inbox/live/bell_dropdown_live.ex` — connected subscription and authoritative reload.
- `examples/chimeway_demo_host/config/config.exs` and `examples/chimeway_demo_host/test/demo_host_web/inbox_bell_proof_test.exs` — mounted host bridge and proof surface.
- `.planning/v1.19-MILESTONE-AUDIT.md` — precise stabilization gap.

## Metadata

**Confidence breakdown:** root cause HIGH (reproduced); implementation shape HIGH (direct control-flow inspection); test placement HIGH (existing focused gates and fixtures); exception-scope recommendation MEDIUM (bounded stabilization judgment).

**Valid until:** code changes in `Trigger.notifications_attrs/6`, the inbox publisher wiring, or the demo bell proof invalidate this research.
