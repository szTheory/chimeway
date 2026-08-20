# External API Coverage — Phase 100 Optional APNs Adapter

**Pinned surface:** Pigeon 2.0.1 APNs notification/dispatcher API and Apple ordinary remote-notification request/response semantics.  
**Rule:** Chimeway integrates only the target-specific APNs request and result surface. Dispatcher credentials, connection supervision, registration, protected-open authorization, other Pigeon providers, and rich APS presentation options remain outside this phase for the reasons recorded below.

| External capability | Disposition | Phase 100 contract / reason |
|---|---|---|
| Host adds and starts Pigeon 2.0.1 | INTEGRATE | Opted-in hosts add the dependency and supervise the dispatcher; the Chimeway package remains Pigeon-free (D-01, D-02). |
| `Pigeon.push/3` synchronous single-notification send | INTEGRATE | The pinned host-selected transport sends one target request and returns a target-specific result; timeout is treated as possible handoff (D-09, D-13, D-14). |
| `Pigeon.push/3` list/batch send | OPT-OUT | Phase 99 already claims and records each installation independently; batching would blur per-target attempts and handoff ambiguity. |
| `Pigeon.push/3` `:timeout` option | INTEGRATE | The transport accepts a bounded timeout, but expiration of the local wait is an ambiguous handoff rather than proof of no APNs request. |
| `Pigeon.push/3` `:on_response` async callback | OPT-OUT | The durable Phase 99 executor is synchronous per claimed attempt; a callback after claim finalization would create a second completion authority. |
| Pigeon dispatcher process/pid/registered-name selection | INTEGRATE | Host lookup returns only an opaque dispatcher reference selected for the exact environment and credential posture (D-02, D-03). |
| Pigeon dispatcher supervision and pool lifecycle | OPT-OUT | The host owns dispatcher children and operational sizing; Chimeway neither starts nor restarts credential-bearing processes (D-02). |
| APNs certificate configuration (`:cert`, `:key`) | OPT-OUT | Credential material is exclusively host-owned and never crosses the Chimeway boundary (D-02). |
| APNs token configuration (`:key`, `:key_identifier`, `:team_id`) | OPT-OUT | Credential material and JWT/provider-token refresh remain inside the host-supervised Pigeon dispatcher (D-02, D-12). |
| APNs connection configuration (`:mode`, `:uri`, `:port`, `:ping_period`) | OPT-OUT | Environment/connection configuration is host-owned; Chimeway persists the safe environment identity only and verifies lookup agreement (D-02, D-04). |
| `Pigeon.APNS.Notification.device_token` | INTEGRATE | Resolved transiently for the exact tenant/binding revision immediately before send and excluded from persistence/evidence (D-03, D-04). |
| `Pigeon.APNS.Notification.topic` | INTEGRATE | Persisted in closed safe intent, checked against host lookup, and sent unchanged (D-05). |
| `Pigeon.APNS.Notification.id` / `apns-id` | INTEGRATE | Persisted UUID-shaped correlation identity and reused by retries/recovery without deduplication claims (D-05, D-06, D-09). |
| `Pigeon.APNS.Notification.expiration` / `apns-expiration` | INTEGRATE | Host absolute expiry is checked before lookup/I/O on every attempt and encoded as epoch seconds (D-04, D-06). |
| `Pigeon.APNS.Notification.collapse_id` / `apns-collapse-id` | INTEGRATE | Omitted unless host opts a replaceable occurrence in; then derived as an opaque value of at most 64 bytes scoped to occurrence, binding revision, environment, and topic (D-08). |
| `Pigeon.APNS.Notification.push_type` | INTEGRATE | Fixed to `"alert"` for this visible-notification phase; the closed payload contains an alert (D-07). |
| `Pigeon.APNS.Notification.priority` | INTEGRATE | Fixed to ordinary alert priority `10`; callers cannot widen it into an arbitrary APNs header surface. |
| `Pigeon.APNS.Notification.payload` | INTEGRATE | Built from the closed `aps.alert` title/body plus one named opaque open-reference key and rejected above 4,096 encoded bytes before I/O (D-07). |
| `Pigeon.APNS.Notification.new/3` and `new/4` | OPT-OUT | The optional boundary constructs the pinned struct dynamically from already validated fields so the core package has no static Pigeon reference (D-01). |
| `put_alert/2` | OPT-OUT | The closed payload builder creates the one approved alert shape before the dynamic Pigeon seam; no second mutable construction path is needed. |
| `put_custom/2` | OPT-OUT | Its general top-level merge conflicts with the closed allowlist and recursive privacy contract (D-07). |
| `put_badge/2`, `put_category/2`, `put_sound/2` | OPT-OUT | No adopter requirement in this phase authorizes these presentation keys; adding them would widen the payload contract. |
| `put_content_available/1` | OPT-OUT | Silent/background notifications are not the Phase 100 visible-alert contract. |
| `put_interruption_level/2` | OPT-OUT | Time-sensitive/critical presentation policy is not specified for the adopter-alpha request surface. |
| `put_mutable_content/1` | OPT-OUT | Notification service-extension/media mutation is outside the closed payload contract. |
| `put_target_content_id/2`, `put_thread_id/2` | OPT-OUT | Window targeting and APNs thread grouping are not required; replaceable occurrences use the separately bounded collapse identity. |
| Notification `response: :success` / APNs HTTP 200 | INTEGRATE | Classified only as `provider_accepted`; it is not device receipt, display, open, seen, or read (D-10, D-11). |
| Notification `response: :timeout` | INTEGRATE | Classified as `ambiguous_handoff` and excluded from automatic retry (D-13). |
| Known retryable provider reasons (`idle_timeout`, `too_many_provider_token_updates`, `too_many_requests`, `internal_server_error`, `service_unavailable`, `shutdown`) | INTEGRATE | Mapped through the pinned reason seam to bounded retry/backoff or credential-refresh corrective action, with expiry rechecked first (D-12, D-14). |
| APNs 410 `ExpiredToken` / `Unregistered` plus response timestamp | INTEGRATE | The reason-aware seam preserves status/reason/timestamp; only these exact results can request host compare-and-update invalidation (D-14, D-15, D-16). |
| `BadDeviceToken`, `DeviceTokenNotForTopic`, request/topic/auth/payload errors | INTEGRATE | Classified as permanent for the unchanged request and never authorize binding invalidation (D-12, D-15). |
| Pigeon `:unknown_error` or future conclusive reason | INTEGRATE | Fails closed as permanent with a stable safe code; it never retries or invalidates (D-14). |
| Raw APNs response body and arbitrary error/exception terms | OPT-OUT | Only bounded status/reason/410 timestamp/retry delay facts cross the seam; bodies and exception terms are excluded from Chimeway persistence and evidence (D-03, D-14). |
| Pigeon FCM and ADM providers | OPT-OUT | Android and the broad channel matrix are explicitly deferred beyond this milestone. |
| Apple device registration/token rotation APIs | OPT-OUT | CrossWake registration, rotation, and revocation are Phase 101 responsibilities. |
| Apple protected-open/deep-link authorization | OPT-OUT | Phase 101 owns one-time open consumption and current-authority checks; Phase 100 transports only an opaque reference. |

## Executable coverage contract

`test/chimeway/apns/api_coverage_test.exs` must parse this table and prove every external row has exactly one `INTEGRATE` or `OPT-OUT` disposition, every `OPT-OUT` row has a non-empty reason, and the pinned request fields/result classes named above are exercised by the focused APNs contract suites. `mix verify.apns` is the phase-level executable entrypoint.
