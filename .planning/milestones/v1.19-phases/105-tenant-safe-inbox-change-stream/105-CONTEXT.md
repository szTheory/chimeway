# Phase 105: Tenant-Safe Inbox Change Stream - Context

**Gathered:** 2026-09-12
**Status:** Ready for planning
**Mode:** autonomous assumptions analysis

<domain>
## Phase Boundary

Add a replaceable, Phoenix-free core reload-hint publisher and connect the optional `chimeway_inbox` LiveView to a host PubSub stream. This phase covers notification arrival plus first seen/read/archive transitions, tenant/recipient isolation, authoritative reload, publisher-failure containment, and non-Phoenix optionality. Panel-open `mark_seen`, workflow proof, operator timeline projection, and final documentation/release gates remain Phases 106–107.

</domain>

<decisions>
## Implementation Decisions

### Core change contract
- **D-01:** Publish only a closed versioned reload hint with `tenant_id`, opaque `recipient_ref`, and event class `created | seen | read | archived`; never publish notification payload, metadata, addresses, tokens, or caller context.
- **D-02:** Core defines the publisher behaviour and a no-op default. Phoenix, Phoenix PubSub, and `chimeway_inbox` remain absent from root dependencies and compile paths.
- **D-03:** Creation hints run only after the event/notification transaction commits. Lifecycle hints run only after the first exact tenant/recipient conditional update succeeds.
- **D-04:** Repeated seen/read/archive calls are idempotent and publish no duplicate hint. Duplicate triggers publish no creation hint.
- **D-05:** Publisher `{:error, _}`, unexpected returns, exits, throws, and exceptions never change the durable API result. Emit only stable success/failure telemetry classification.

### Optional Phoenix adapter
- **D-06:** `chimeway_inbox` supplies the Phoenix PubSub publisher; hosts opt in by configuring it as Chimeway's publisher plus a PubSub server and a high-entropy topic secret.
- **D-07:** Topics are HMAC-derived from a length-delimited tenant/recipient tuple and expose neither input. Messages are the closed tuple `{:chimeway_inbox, :reload, 1}` with no identity or record data.
- **D-08:** Subscribe only during connected mount, after `on_mount` has authorized a nonblank tenant and opaque recipient. Missing/unsafe config fails closed without crashing the disconnected render.
- **D-09:** On a reload message, re-check current host authorization before querying. Authorization drift redirects; a relevant message reloads first-page items and badge from Chimeway's tenant-scoped APIs; unrelated messages are ignored.

### Scope continuity
- **D-10:** Preserve existing visual markup, copy, pagination, and explicit row-read behavior. Real-time reload resets the visible collection to the authoritative first page.
- **D-11:** Archive publishing becomes first-transition-only without implicitly marking read or seen.
- **D-12:** All fixtures use synthetic opaque references and prove cross-tenant/cross-recipient non-delivery without logging topic inputs.

### Agent discretion
- Exact module names, telemetry suffix, and test fixture helpers may follow existing project conventions if these boundaries remain explicit and executable.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Chimeway.Inbox` already uses exact tenant + opaque recipient predicates and conditional first-transition updates for seen/read.
- `Chimeway.Trigger` inserts all notification rows inside one `Ecto.Multi`; successful normalization is the first safe post-commit hook.
- `ChimewayInbox.LiveAuth.ensure_authorized/2` already detects tenant or recipient drift before events.
- `BellDropdownLive.load_inbox/3` already reloads badge and first-page state authoritatively.
- Installed Phoenix PubSub 2.2 exposes `subscribe/3` and `broadcast/4`; LiveView 1.1 exposes `connected?/1` for the connected-mount boundary.

### Integration Points
- Core: `lib/chimeway/inbox.ex`, `lib/chimeway/trigger.ex`, new inbox change modules, telemetry contracts.
- Optional package: `chimeway_inbox` publisher/topic module, `BellDropdownLive`, test endpoint/config.
- Gates: existing `mix verify.inbox` package + demo-host lane; final aggregate expansion is Phase 107.

</code_context>

<deferred>
## Deferred Ideas

- Bell-panel `mark_seen` and once-only workflow progression: Phase 106.
- Operator seen/read timeline, integration guide, and final named release contract: Phase 107.
- WebSockets outside Phoenix PubSub, durable client cursors, mobile background sync, and per-item delta payloads: future work.

</deferred>
