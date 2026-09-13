# Phase 99: Multi-Installation Delivery & Recovery - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-08-19
**Phase:** 99-multi-installation-delivery-recovery
**Mode:** assumptions
**Areas analyzed:** Opaque Target Model and Logical Outcome, Target-Scoped Handoff Truth, Tenant-Scoped Recovery and Idempotency

## Assumptions Presented

### Opaque Target Model and Logical Outcome

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Keep one canonical logical push delivery per notification/channel, with a durable child target for every resolver-selected opaque tenant-scoped binding revision; suppress no-target deliveries explicitly and aggregate terminal results from target truth. | Confident | `lib/chimeway/delivery.ex`; `priv/chimeway_migrations/003_create_chimeway_deliveries.exs`; `.planning/ROADMAP.md`; `.planning/REQUIREMENTS.md`; Phase 98 context; `lib/chimeway/safe_evidence.ex` |

### Target-Scoped Handoff Truth

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Make the target the independent state machine, persist claim and attempt-start before provider I/O, and represent a crash after possible handoff as durable indeterminate evidence rather than silently resending. | Confident | `lib/chimeway/dispatch/executor.ex`; `lib/chimeway/delivery_attempt.ex`; `lib/chimeway/deliveries.ex`; PUSH-02/03; RECOV-02; Apple APNs and HTTP/2 request-reliability documentation |

### Tenant-Scoped Recovery and Idempotency

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Extend recovery through an explicit tenant-scoped bounded worker whose atomic claims make duplicate planning, execution, and recovery converge on the same target revision. | Confident | `lib/chimeway/deliveries.ex`; `test/chimeway/orchestration/recovery_test.exs`; Phase 97 context; `lib/chimeway/dispatch/oban_worker.ex`; `lib/chimeway/dispatch/oban.ex` |

## Corrections Made

No corrections — all assumptions confirmed.

## External Research

- Apple documents a successful APNs response as provider acceptance, not device delivery, display, handling, or open. Sources: [Handling notification responses from APNs](https://developer.apple.com/documentation/usernotifications/handling-notification-responses-from-apns), [Viewing notification status using Metrics and APNs](https://developer.apple.com/documentation/usernotifications/viewing-the-status-of-push-notifications-using-metrics-and-apns), and [User Notifications](https://developer.apple.com/documentation/usernotifications).
- Apple documents `apns-id` for correlation rather than general request deduplication; collapse behavior is narrower notification coalescing, not an exactly-once replay guarantee. Sources: [Sending notification requests to APNs](https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns) and [Handling notification responses from APNs](https://developer.apple.com/documentation/usernotifications/handling-notification-responses-from-apns).
- HTTP/2 request reliability permits an indeterminate processing outcome after some interrupted requests; only specific signals prove non-processing. Sources: [RFC 9113 §6.8](https://www.rfc-editor.org/rfc/rfc9113.html#section-6.8), [RFC 9113 §8.7](https://www.rfc-editor.org/rfc/rfc9113.html#section-8.7), and [RFC 9110 §9.2.2](https://www.rfc-editor.org/rfc/rfc9110.html#section-9.2.2).

