# Phase 105: Tenant-Safe Inbox Change Stream - Research

**Researched:** 2026-09-12
**Sources:** installed project dependencies and live codebase

## Recommendation

Use a core behaviour with a no-op default, then implement the opt-in adapter in `chimeway_inbox` with Phoenix PubSub. Treat broadcasts as lossy reload hints: durable PostgreSQL state remains authoritative, so reconnect or the next relevant hint simply reloads badge/items.

## Existing Runtime Facts

- Root Chimeway has no Phoenix dependency; keep it that way.
- Phoenix PubSub 2.2 `subscribe/3` permits duplicate subscriptions, so subscribe exactly once on connected mount.
- Phoenix LiveView 1.1 performs disconnected and connected mounts; `connected?/1` distinguishes the subscription-safe pass.
- `Chimeway.Inbox` already makes seen/read idempotent via `is_nil(field(...))`; archive needs the same first-transition predicate.
- Trigger notification rows commit inside `Ecto.Multi`, so publish from normalized success after `Repo.transaction/1`, never from `insert_notifications/6`.

## Implementation Guidance

1. Keep the behavior callback synchronous and fully guarded; this preserves deterministic tests and prevents supervised process requirements in core.
2. A hint should contain routing inputs only inside the publisher process. The wire topic is HMAC-SHA256 and the wire message contains only schema/version.
3. Require an explicit secret of at least 32 bytes. Do not fall back to tenant IDs, endpoint names, hashes without a secret, or global topics.
4. On LiveView receipt, reauthorize before reload. PubSub delivery is not authorization.
5. Test creation after commit by querying from the publisher callback; test failures and exceptions still return the original durable success.
6. Prove optionality by compiling/testing root without Phoenix declarations and by keeping all `Phoenix.PubSub` references under `chimeway_inbox`.

## Pitfalls

- Publishing inside the transaction allows observers to race uncommitted state and couples adapter failure to durability.
- Raw `tenant_id:recipient_ref` topics leak host identity structure to local process inspection and telemetry.
- Including notification IDs or event metadata encourages clients to treat hints as authoritative deltas.
- Subscribing during disconnected mount duplicates delivery after WebSocket connection.
- Reloading without reauthorization can preserve a stale subscriber after host session/tenant changes.
