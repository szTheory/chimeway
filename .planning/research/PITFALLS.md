# Domain Pitfalls: Adopter Alpha Mobile Delivery Readiness

**Domain:** APNs-first, Crosswake-mediated mobile notification delivery for Adopter Alpha
**Researched:** 2026-08-11
**Confidence:** HIGH for APNs semantics and existing seams; MEDIUM for final host-specific credential wiring

## Critical Pitfalls

### Pitfall 1: Raw APNs tokens leak through diagnostic paths

**What goes wrong:** A raw token is copied from the host-owned endpoint store into a Chimeway event, delivery metadata, attempt response, telemetry, log, trace, or proof artifact. It becomes durable sensitive data and can be replayed or correlated outside the host boundary.

**Why it happens:** Existing `Chimeway.Trigger` redaction is shallow: it removes a small key list only at the top level ([trigger.ex](/Users/jon/projects/chimeway/lib/chimeway/trigger.ex:376)). Crosswake rejects top-level token keys, but public contract metadata remains a map ([contracts.ex](/Users/jon/projects/crosswake/packages/crosswake_chimeway/lib/crosswake/companions/chimeway/contracts.ex:607)).

**How to avoid:** Keep raw tokens in the Alpha host only. Chimeway accepts an opaque endpoint/binding reference and a non-reversible, host-derived fingerprint. Apply one recursive, key-normalizing, allowlist-oriented redactor before every persistence, telemetry, adapter-result, error, and evidence boundary. Store a compact response projection, never provider request/response bodies.

**Warning signs:** `token`, `device_token`, APNs path fragments, authorization values, or `inspect/1` output appear in JSONB, telemetry captures, test failure messages, or physical-proof output.

**Phase to address:** Phase 97 — Mobile Binding Spine & Privacy Boundary.

---

### Pitfall 2: Treating an APNs token as a permanent user or device identity

**What goes wrong:** Rotation, reinstall, restore, new device, or session change leaves stale targets active; one user’s multiple installations collapse into one send; a token is reused in an unintended scope.

**Why it happens:** APNs tokens are app-device addresses, may change, have variable length, and Apple directs apps to register at launch rather than cache locally. A user may own several devices. [Apple: registering with APNs](https://developer.apple.com/documentation/usernotifications/registering-your-app-with-apns)

**How to avoid:** Make installation—not account or raw token—the fan-out unit. Bind `(installation_ref, provider, platform, environment, topic identity)` to host-owned raw token storage, tenant/subject/session version, and lifecycle state. Rebinding a rotated token atomically supersedes the prior binding; logout, permission denial, revocation, and provider invalidation change eligibility.

**Warning signs:** A fixed token length is validated; a device token is cached on the client; the endpoint key lacks installation/environment/topic; two active devices yield one target.

**Phase to address:** Phase 97 — Mobile Binding Spine & Privacy Boundary.

---

### Pitfall 3: Global idempotency and channel uniqueness break tenant-safe fanout

**What goes wrong:** An Alpha request key collides across tenants, or the current one-delivery-per-channel model collapses every installation into one `apns` delivery.

**Why it happens:** Events have a global unique `idempotency_key` ([event migration](/Users/jon/projects/chimeway/priv/repo/migrations/20260424023200_create_chimeway_events.exs:15)), while deliveries are unique by `(notification_id, channel)` ([delivery.ex](/Users/jon/projects/chimeway/lib/chimeway/delivery.ex:84)). Neither represents target installation identity.

**How to avoid:** For host semantics that are tenant-scoped, migrate idempotency to tenant scope and ensure every binding, feedback, recovery, and explain query has an explicit tenant filter. Keep notification intent separate from per-installation target/child delivery records, uniquely keyed by notification, provider, environment, and opaque binding/endpoint reference. Retain Chimeway’s static storage prefix; do not introduce request-selected prefixes.

**Warning signs:** Tenant A and B cannot submit the same request ID; an APNs channel has only one attempt for a user with several devices; recovery accepts an unscoped target ID.

**Phase to address:** Phase 97 — Mobile Binding Spine & Privacy Boundary.

---

### Pitfall 4: Crash recovery creates duplicates or stranded provider calls

**What goes wrong:** A process crashes between durable planning and sending, or after APNs accepts a request but before local success is written. Retrying blindly can duplicate a notification; declining recovery strands it.

**Why it happens:** Chimeway has recovery claims for old pending records ([deliveries.ex](/Users/jon/projects/chimeway/lib/chimeway/deliveries.ex:53)), but provider handoff and local attempt persistence remain separate effects. APNs acceptance is not device delivery.

**How to avoid:** Use a durable outbox/claim lease per target, persist an attempt-start/claim before I/O, give each request a stable `apns-id`, then append a sanitized result. Recover expired claims under the same tenant/target identity. Surface an explicit ambiguous-handoff state rather than quietly claiming device delivery or retrying without policy.

**Warning signs:** Provider calls occur with no preceding durable claim; worker restarts resend every pending row; traces label a 200 response as “delivered”; recovery records are not tenant-scoped.

**Phase to address:** Phase 97 — durable target/outbox model; Phase 98 — APNs attempt semantics.

---

### Pitfall 5: Status-only APNs handling retries permanent errors

**What goes wrong:** The adapter retries invalid/unregistered endpoints, retries malformed payloads, invalidates good tokens due to a credential/configuration failure, or omits the APNs correlation needed to explain a failure.

**Why it happens:** APNs gives a response for every POST, including `apns-id`, HTTP status, a JSON `reason`, and a 410 invalidation timestamp. Apple explicitly says not to retry `BadDeviceToken`, `DeviceTokenNotForTopic`, `Forbidden`, `ExpiredToken`, `Unregistered`, or `PayloadTooLarge`; 5xx can retry after 15 minutes with backoff, and `TooManyRequests` can retry with delay. [Apple: handling responses](https://developer.apple.com/documentation/usernotifications/handling-notification-responses-from-apns)

**How to avoid:** Classify by status *and* reason into accepted, retryable, permanent configuration, invalid-binding, and payload-invalid. Persist only allowlisted status/reason/timestamp/APNs ID. Invalidate just the matching binding for token-specific terminal responses; treat topic/environment/credential errors as configuration posture failures. Bound all retries by notification expiry.

**Warning signs:** A single generic `:temporary` APNs failure; missing APNs ID; retries for 400/410 reasons; token invalidation after a 403 credential error.

**Phase to address:** Phase 98 — APNs Transport, Attempt Classification & Retry.

---

### Pitfall 6: Sandbox/production or app-topic identity is mixed

**What goes wrong:** Test endpoints are used for production, production credentials target a sandbox token, or a token for another bundle/topic is sent. Failures get misdiagnosed as user churn.

**Why it happens:** APNs uses distinct development and production endpoints; token/topic/environment validity is coupled. Crosswake already includes environment and app identity posture in its binding contract ([contracts.ex](/Users/jon/projects/crosswake/packages/crosswake_chimeway/lib/crosswake/companions/chimeway/contracts.ex:11)). [Apple: APNs connections](https://developer.apple.com/documentation/usernotifications/establishing-a-connection-to-apns)

**How to avoid:** Include environment and topic/bundle identity in target eligibility and uniqueness. Resolve endpoint, topic, and credentials only from a closed host config, never payload metadata. Suppress unknown/mismatched identity with a safe trace reason; treat it separately from token invalidation.

**Warning signs:** Environment exists only in config, not binding/attempt identity; a sandbox proof uses production credentials; `BadDeviceToken` causes account-level revocation.

**Phase to address:** Phase 98 — APNs Transport, Attempt Classification & Retry; Phase 100 — physical-device proof.

---

### Pitfall 7: Collapse, offline storage, and retries change learning intent

**What goes wrong:** Meaningful prompts disappear because they share a collapse ID, stale prompts arrive after they matter, or the product assumes APNs is an ordered durable offline queue.

**Why it happens:** APNs can reorder notifications; offline delivery is best-effort; storage is bounded by expiration. `apns-collapse-id` merges notifications and is limited to 64 bytes. [Apple: sending requests](https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns)

**How to avoid:** Use a collapse ID only for explicitly replaceable, current-state reminders. Namespace it by tenant/subject/installation with opaque IDs; never use content or raw identity. Give every Alpha notification an explicit semantic expiry and prevent Chimeway retries after that instant. Distinct pedagogical events do not share a collapse ID.

**Warning signs:** One global reminder collapse key; `apns-expiration` omitted; delivery order assumed in UI/open logic; retries scheduled beyond the relevance window.

**Phase to address:** Phase 98 — APNs Transport, Attempt Classification & Retry.

---

### Pitfall 8: Offline notification opens bypass fresh authorization

**What goes wrong:** A locally queued tap navigates or invokes an action using stale tenant/session/route state, or duplicate taps replay a privileged intent.

**Why it happens:** Notification payloads are available while offline, but Crosswake’s resolver intentionally consumes intent before RouteGate evaluation ([resolver.ex](/Users/jon/projects/crosswake/packages/crosswake_chimeway/lib/crosswake/companions/chimeway/resolver.ex:20)). The client cannot establish current authorization offline.

**How to avoid:** Queue only opaque `open_ref`, binding reference, route/action refs, and display-safe state. On reconnect, atomically consume once and re-evaluate intent expiry, binding/session/tenant state, current manifest route/action allowlist, and RouteGate authorization. The queued item has no bearer authority. Denials stay generic.

**Warning signs:** Offline tap opens a route immediately; payload contains a URL/session credential; replay is not recorded; the app uses payload authorization without backend resolution.

**Phase to address:** Phase 99 — Secure Offline Open & Reauthorization.

---

### Pitfall 9: Manifest policy accidentally grants all notification actions

**What goes wrong:** A permissive or malformed `notification_open` value permits arbitrary action references.

**Why it happens:** Current resolver behavior denies `false`/`nil`, but any non-list configuration permits all actions; only `[actions: actions]` enforces an allowlist ([resolver.ex](/Users/jon/projects/crosswake/packages/crosswake_chimeway/lib/crosswake/companions/chimeway/resolver.ex:64)).

**How to avoid:** Alpha uses explicit per-route action allowlists only. Validate malformed manifest entries as default-deny before release; bind the action reference to the one-time intent server-side and retain generic denial messages.

**Warning signs:** `notification_open: true` appears in Alpha manifest; unrecognized action ref routes successfully; tests cover only allowed actions.

**Phase to address:** Phase 99 — Secure Offline Open & Reauthorization.

---

### Pitfall 10: Simulator/twin evidence is promoted as real device proof

**What goes wrong:** A happy-path mock proves local serialization but never validates signed-device entitlement, registration, host callback wiring, APNs environment, or privacy-safe evidence output.

**Why it happens:** The Crosswake iOS rehearsal is intentionally advisory. The physical handoff says a simulator cannot satisfy the promotion gate and requires host-owned callbacks plus a signed trusted iPhone ([physical iPhone handoff](/Users/jon/projects/crosswake/guides/physical_iphone_handoff.md:1)).

**How to avoid:** Use a deterministic APNs HTTP/2 twin in CI for status/reason/GOAWAY, crash, retry, binding, and offline-open matrices; reserve physical proof for a signed device and real backend evidence. The readiness report must expose only stable rule IDs.

**Warning signs:** CI claims a device received a notification; proof artifacts include account/device/route/token values; a simulator result marks a release ready; host proof callbacks remain skeletons.

**Phase to address:** Phase 100 — Hermetic Twin & Physical-iPhone Proof Gate.

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Store the raw token in `provider_response` for debugging | Easy correlation | Durable secret leakage across traces, backups, and support exports | Never |
| Add one `apns` channel record per notification | Fits current delivery uniqueness | Prevents per-installation fanout and independent lifecycle | Never for Alpha |
| Retry all non-200 responses | Simple worker code | APNs throttling, stale bindings, duplicate sends | Never |
| Treat APNs 200 as device delivery | Simple product metric | False delivery claims and misleading operator traces | Never |
| Use a global collapse ID | Simple coalescing | Cross-user/tenant replacement and lost learning prompts | Never |
| Simulator-only proof | Fast feedback | Misses signed-device and actual host wiring | Only as advisory preflight |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| APNs registration | Cache a fixed-size token locally | Register on launch, forward it securely, and treat it as variable-length opaque data. [Apple](https://developer.apple.com/documentation/usernotifications/registering-your-app-with-apns) |
| APNs HTTP/2 | Ignore stream responses/GOAWAY and use one generic failure | Parse each response, `apns-id`, JSON reason, 410 timestamp, and GOAWAY reason; honor APNs concurrency/backoff guidance. [Apple](https://developer.apple.com/documentation/usernotifications/handling-notification-responses-from-apns) |
| Crosswake contracts | Pass raw token as “metadata” to avoid forbidden keys | Pass only opaque references and validated evidence; recursive-redact every nested map. |
| Crosswake resolver | Treat a local open as authorization | Queue offline evidence then consume and reauthorize after reconnect through resolver + RouteGate. |
| Physical iPhone proof | Let safe readiness output stand in for proof | Fail closed until host callbacks and physical signed-device evidence exist. |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Per-target reconnect/JWT generation | Latency spikes, `TooManyProviderTokenUpdates`, socket churn | Long-lived HTTP/2 pool, bounded streams, shared provider token lifecycle | First burst or several concurrent target sends |
| Unbounded retry fanout | Queue growth and repeated user prompts | Lease claims, reason-specific backoff, expiry cutoff, target-level dedupe | Any provider outage |
| Full provider body persistence | Database growth and slow explain queries | Allowlisted compact diagnostics, external opaque evidence refs | Normal production usage |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Raw tokens/endpoint paths in diagnostics | Endpoint compromise and privacy breach | Host-only raw storage, opaque refs, recursive redaction, output scans |
| Binding mutation without tenant/session filter | Cross-tenant notification or revocation | Tenant/subject/session version in every eligibility and mutation query |
| Offline payload grants route/action authority | Replay or access after logout/revocation | One-time server intent plus reconnect-time RouteGate authorization |
| Configuration failure invalidates user binding | Loss of valid endpoints and denial of service | Separate configuration/app-identity posture from token invalidation |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Stale reminder arrives after relevance window | Notification feels incorrect or intrusive | Explicit semantic expiry; no retry after expiry |
| Different reminders collapse together | Missed meaningful practice cue | Collapse only replaceable current state |
| Offline tap appears to work then silently fails | Confusion and trust loss | Show queued state, reconnect, then resolve with safe generic denial/recovery behavior |
| One device’s invalid token disables all devices | User loses reminders everywhere | Independent binding lifecycle per installation |

## "Looks Done But Isn't" Checklist

- [ ] **Token binding:** Registration at launch, rotation, multi-installation fanout, logout/session revoke, provider invalidation, and stale pruning all have durable tests.
- [ ] **APNs transport:** Every response reason, 410 timestamp, `apns-id`, GOAWAY reason, and expiry-bounded retry path is testable through the twin.
- [ ] **Tenant safety:** Same idempotency key in two tenants, guessed target/binding IDs, recovery, feedback, and explain calls prove isolation.
- [ ] **Privacy:** Recursive injected secrets are absent from database, logs, telemetry, trace APIs, test errors, and proof artifacts.
- [ ] **Offline open:** Expired, replayed, revoked, tenant-switched, route-changed, and reauthorized reconnect scenarios are covered.
- [ ] **Physical proof:** A signed trusted iPhone and implemented host callbacks produce sanitized evidence; simulator proof remains advisory.

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Raw diagnostic leakage | HIGH | Stop affected exports/log access, rotate where warranted, redact/migrate retained data, add regression fixtures and output scans. |
| Stale/invalid endpoint fanout | MEDIUM | Classify stored provider feedback, invalidate only matching bindings, reacquire on next app launch, replay eligible unsent targets only. |
| Environment/topic mismatch | MEDIUM | Disable affected config posture, correct host credential/topic routing, leave user bindings intact, run sandbox/production contract proof. |
| Ambiguous post-handoff crash | MEDIUM | Preserve claim and APNs correlation, mark ambiguous, follow explicit retry policy within expiry, avoid falsely declaring delivery. |
| Offline open replay | MEDIUM | Invalidate/consume open ref, deny safely, audit opaque correlation refs, require current auth on next intent. |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Raw token leakage / shallow redaction | 97 | Nested-secret injections are absent from all durable and observable surfaces. |
| Token lifecycle, tenant scope, per-installation fanout | 97 | Rotation/multi-device/cross-tenant/migration and crash-claim tests. |
| APNs response, identity, collapse, expiry, retries | 98 | Scripted HTTP/2 twin covers statuses/reasons/GOAWAY/expiry and sanitized trace projection. |
| Offline open replay and route/action authorization | 99 | Offline/reconnect/session-revoke/route-change/replay matrix is deterministic. |
| Hermetic twin and signed physical proof | 100 | CI twin plus fail-closed physical-iPhone host proof with safe output scan. |

## Sources

- [Apple — Registering your app with APNs](https://developer.apple.com/documentation/usernotifications/registering-your-app-with-apns) — HIGH
- [Apple — Sending notification requests to APNs](https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns) — HIGH
- [Apple — Handling notification responses from APNs](https://developer.apple.com/documentation/usernotifications/handling-notification-responses-from-apns) — HIGH
- [Apple — Establishing a connection to APNs](https://developer.apple.com/documentation/usernotifications/establishing-a-connection-to-apns) — HIGH
- [Crosswake Chimeway contracts](/Users/jon/projects/crosswake/packages/crosswake_chimeway/lib/crosswake/companions/chimeway/contracts.ex) — HIGH
- [Crosswake Chimeway notification resolver](/Users/jon/projects/crosswake/packages/crosswake_chimeway/lib/crosswake/companions/chimeway/resolver.ex) — HIGH
- [Crosswake physical iPhone handoff](/Users/jon/projects/crosswake/guides/physical_iphone_handoff.md) — HIGH
- [Chimeway trigger redaction](/Users/jon/projects/chimeway/lib/chimeway/trigger.ex) and [delivery recovery](/Users/jon/projects/chimeway/lib/chimeway/deliveries.ex) — HIGH

---
*Pitfalls research for: Adopter Alpha mobile delivery readiness*
*Researched: 2026-08-11*
