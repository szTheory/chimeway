# Phase 100: Optional APNs Adapter - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-08-20
**Phase:** 100-optional-apns-adapter
**Mode:** assumptions
**Areas analyzed:** Optional Adapter and Host Custody, Durable Bounded Request Intent, Honest Outcomes and Exact Invalidation

## Assumptions Presented

### Optional Adapter and Host Custody

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| APNs remains an explicit opt-in `Chimeway.TargetAdapter`; Pigeon is absent from non-push hosts. | Confident | `lib/chimeway/target_adapter.ex`, `lib/chimeway/dispatch/executor.ex`, `mix.exs`; Pigeon 2.0.1 application/dependency source |
| A host-owned exact-binding lookup provides only transient token material and an opaque host-supervised dispatcher reference. | Confident | `lib/chimeway/target_resolver.ex`, `lib/chimeway/delivery_target.ex`, Phase 98/99 context; Pigeon dispatcher and notification APIs |

### Durable, Bounded Request Intent

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Environment/topic, stable `apns-id`, absolute expiry, opaque open reference, and optional collapse intent are durable validated facts; token and provider payload remain transient. | Likely | `lib/chimeway/delivery_targets.ex`, `lib/chimeway/delivery_target_attempt.ex`, `lib/chimeway/safe_evidence.ex`, `lib/chimeway/dispatch/oban_worker.ex` |
| The adapter builds a closed allowlisted payload and emits installation-safe collapse only for explicitly replaceable occurrences. | Likely | `lib/chimeway/rendering/channels/push.ex`, `lib/chimeway/safe_evidence.ex`; Apple payload/collapse limits; Pigeon custom-map behavior |

### Honest Outcomes and Exact Invalidation

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Target results distinguish accepted handoff, retryable rejection, permanent payload/configuration rejection, exact-binding invalidation, and ambiguous handoff. | Confident | `lib/chimeway/dispatch/executor.ex`, `lib/chimeway/delivery_target.ex`, `lib/chimeway/delivery_targets.ex`; Apple response catalog |
| Pigeon timeout is ambiguity, and Pigeon 2.0.1's normalized response requires version-pinned contracts plus a reason-preserving seam or fail-closed unknown handling. | Likely | Pigeon 2.0.1 `lib/pigeon.ex`, `lib/pigeon/apns/shared.ex`, and `lib/pigeon/apns/error.ex` |
| Only recognized APNs 410 `ExpiredToken`/`Unregistered` conditionally invalidates the exact tenant/environment/topic/binding revision. | Confident | Phase 97/99 context, `lib/chimeway/delivery_targets.ex`; Apple APNs response semantics |
| Provider acceptance remains handoff-only; protected open and inbox seen/read are separate facts. | Confident | Phase 99 context, `lib/chimeway/delivery_targets.ex`, `lib/chimeway/inbox.ex` |

## Corrections Made

No corrections — all assumptions confirmed.

## External Research

- **Pigeon optionality and dispatch:** Pigeon 2.0.1 is a general OTP application whose APNs processes start when the application starts; Chimeway must enforce dependency and boot optionality. Hosts can supervise credential-bearing dynamic dispatchers, while notifications carry token, topic, ID, expiration, and collapse fields.
- **Request mapping and bounds:** Pigeon maps `id`, `topic`, `expiration`, and `collapse_id` to the corresponding APNs headers but does not enforce Apple's UUID, 4,096-byte payload, or 64-byte collapse-ID limits. Chimeway must validate them before provider I/O.
- **Response fidelity:** Pigeon 2.0.1 discards HTTP status and APNs 410 timestamp, normalizes only the reason, maps some current Apple reasons to `:unknown_error`, and implements synchronous `:timeout` as a local receive timeout after dispatch.
- **Reason classification:** Apple permits bounded retry for documented throttling, server, provider-token, or connection remedies; most other 4xx results are terminal for the unchanged request. Only 410 `ExpiredToken` and `Unregistered` are safe exact-binding invalidation signals.

Primary sources:

- [Pigeon 2.0.1 APNs notification documentation](https://pigeon.hexdocs.pm/Pigeon.APNS.Notification.html)
- [Pigeon 2.0.1 APNs transport source](https://github.com/codedge-llc/pigeon/blob/v2.0.1/lib/pigeon/apns/shared.ex)
- [Pigeon 2.0.1 synchronous push source](https://github.com/codedge-llc/pigeon/blob/v2.0.1/lib/pigeon.ex)
- [Apple APNs request documentation](https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns)
- [Apple APNs response documentation](https://developer.apple.com/documentation/usernotifications/handling-notification-responses-from-apns)
- [Apple token-based connection documentation](https://developer.apple.com/documentation/usernotifications/establishing-a-token-based-connection-to-apns)

## Methodology Applied

- Cohesive Recommendation Default and One-Shot Recommendation Bias produced one adapter-plus-host-lookup design instead of an option menu.
- Research-First Decision Ownership required primary-source Pigeon and Apple validation before locking response semantics.
- Durable Explainability Bias kept request identity and provider outcomes on the target lifecycle spine while excluding raw transport data.
- Least-Surprise DX and Low-Escalation Recommendation Default kept Pigeon absent by default, collapse opt-in, unknown reasons fail-closed, and user escalation limited to confirmation of the cohesive set.
