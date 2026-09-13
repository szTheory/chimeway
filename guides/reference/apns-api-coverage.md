# APNs API Coverage

Chimeway's optional APNs adapter targets the Pigeon 2.0.1 notification and
dispatcher API together with Apple's ordinary remote-notification request and
response semantics.

The adapter intentionally integrates only the APNs request and result surface
needed for explainable, per-installation delivery. Host applications continue
to own credentials, connection supervision, device registration, and
protected-open authorization. `INTEGRATE` identifies behavior Chimeway owns;
`OPT-OUT` identifies adjacent behavior that deliberately stays outside the
library boundary.

| capability | disposition | reason |
|---|---|---|
| Host adds and starts Pigeon 2.0.1 | INTEGRATE | Opted-in hosts add the dependency and supervise the dispatcher, keeping the core Chimeway package Pigeon-free. |
| `Pigeon.push/3` synchronous single-notification send | INTEGRATE | The host-selected transport sends one installation request and returns an installation-specific result; a timeout is treated as a possible handoff. |
| `Pigeon.push/3` list/batch send | OPT-OUT | Chimeway claims and records each installation independently, while batching would blur per-installation attempts and handoff ambiguity. |
| `Pigeon.push/3` `:timeout` option | INTEGRATE | The transport accepts a bounded timeout, but expiration of the local wait is an ambiguous handoff rather than proof that APNs received no request. |
| `Pigeon.push/3` `:on_response` async callback | OPT-OUT | The durable executor is synchronous for each claimed attempt; a callback after claim finalization would create a second completion authority. |
| Pigeon dispatcher process/pid/registered-name selection | INTEGRATE | Host lookup returns only an opaque dispatcher reference selected for the exact environment and credential posture. |
| Pigeon dispatcher supervision and pool lifecycle | OPT-OUT | The host owns dispatcher children and operational sizing; Chimeway neither starts nor restarts credential-bearing processes. |
| APNs certificate configuration (`:cert`, `:key`) | OPT-OUT | Credential material is exclusively host-owned and never crosses the Chimeway boundary. |
| APNs token configuration (`:key`, `:key_identifier`, `:team_id`) | OPT-OUT | Credential material and provider-token refresh remain inside the host-supervised Pigeon dispatcher. |
| APNs connection configuration (`:mode`, `:uri`, `:port`, `:ping_period`) | OPT-OUT | Environment and connection configuration are host-owned; Chimeway persists only the safe environment identity and verifies lookup agreement. |
| `Pigeon.APNS.Notification.device_token` | INTEGRATE | The token is resolved transiently for the exact tenant and binding revision immediately before send, then excluded from persistence and evidence. |
| `Pigeon.APNS.Notification.topic` | INTEGRATE | The topic is persisted in closed safe intent, checked against host lookup, and sent unchanged. |
| `Pigeon.APNS.Notification.id` / `apns-id` | INTEGRATE | A UUID-shaped correlation identity is persisted and reused by retries and recovery without making deduplication claims. |
| `Pigeon.APNS.Notification.expiration` / `apns-expiration` | INTEGRATE | Host-supplied absolute expiry is checked before lookup or I/O on every attempt and encoded as epoch seconds. |
| `Pigeon.APNS.Notification.collapse_id` / `apns-collapse-id` | INTEGRATE | It is omitted unless the host marks an occurrence replaceable; when present, it is an opaque value of at most 64 bytes scoped to occurrence, binding revision, environment, and topic. |
| `Pigeon.APNS.Notification.push_type` | INTEGRATE | It is fixed to `"alert"` because the closed payload contains a visible alert. |
| `Pigeon.APNS.Notification.priority` | INTEGRATE | It is fixed to ordinary alert priority `10`; callers cannot widen it into an arbitrary APNs header surface. |
| `Pigeon.APNS.Notification.payload` | INTEGRATE | It is built from the closed `aps.alert` title/body plus one named opaque open-reference key and rejected above 4,096 encoded bytes before I/O. |
| `Pigeon.APNS.Notification.new/3` and `new/4` | OPT-OUT | The optional boundary constructs the pinned struct dynamically from already validated fields, so the core package has no static Pigeon reference. |
| `put_alert/2` | OPT-OUT | The closed payload builder creates the one approved alert shape before the dynamic Pigeon seam; no second mutable construction path is needed. |
| `put_custom/2` | OPT-OUT | Its general top-level merge conflicts with the closed allowlist and recursive privacy contract. |
| `put_badge/2`, `put_category/2`, `put_sound/2` | OPT-OUT | No current adopter requirement authorizes these presentation keys; adding them would widen the payload contract. |
| `put_content_available/1` | OPT-OUT | Silent and background notifications are outside the visible-alert contract. |
| `put_interruption_level/2` | OPT-OUT | Time-sensitive and critical presentation policy is not part of the supported request surface. |
| `put_mutable_content/1` | OPT-OUT | Notification service-extension and media mutation are outside the closed payload contract. |
| `put_target_content_id/2`, `put_thread_id/2` | OPT-OUT | Window targeting and APNs thread grouping are not required; replaceable occurrences use the separately bounded collapse identity. |
| Notification `response: :success` / APNs HTTP 200 | INTEGRATE | It is classified only as `provider_accepted`; it is not device receipt, display, open, seen, or read. |
| Notification `response: :timeout` | INTEGRATE | It is classified as `ambiguous_handoff` and excluded from automatic retry. |
| Known retryable provider reasons | INTEGRATE | Pinned timeout, rate-limit, server, unavailable, and shutdown reasons map to bounded retry/backoff or credential refresh after an expiry recheck. |
| APNs 410 `ExpiredToken` / `Unregistered` plus response timestamp | INTEGRATE | The reason-aware seam preserves status, reason, and timestamp; only these exact results can request host compare-and-update invalidation. |
| `BadDeviceToken`, `DeviceTokenNotForTopic`, request/topic/auth/payload errors | INTEGRATE | They are classified as permanent for the unchanged request and never authorize binding invalidation. |
| Pigeon `:unknown_error` or future conclusive reason | INTEGRATE | It fails closed as permanent with a stable safe code; it never retries or invalidates. |
| Raw APNs response body and arbitrary error/exception terms | OPT-OUT | Only bounded status, reason, 410 timestamp, and retry-delay facts cross the seam; bodies and exception terms are excluded from Chimeway persistence and evidence. |
| Pigeon FCM and ADM providers | OPT-OUT | Android and other provider integrations are outside the optional APNs adapter. |
| Apple device registration/token rotation APIs | OPT-OUT | CrossWake owns registration, rotation, and revocation; the adapter consumes only a current host-resolved binding. |
| Apple protected-open/deep-link authorization | OPT-OUT | CrossWake owns one-time open consumption and current-authority checks; the adapter transports only an opaque reference. |

## Executable matrix contract

`test/chimeway/apns/api_coverage_test.exs` parses this table and verifies that
all 36 capabilities have exactly one `INTEGRATE` or `OPT-OUT` disposition and
that every `OPT-OUT` has a rationale. The focused APNs request, result,
safe-evidence, migration, and clean-consumer suites exercise the integrated
surface through `mix verify.apns`.
