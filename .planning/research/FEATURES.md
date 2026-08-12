# Feature Research: Chimeway v1.18 Adopter Alpha Mobile Delivery Readiness

**Domain:** Production APNs-first mobile notification delivery for an embedded Elixir/Phoenix library
**Researched:** 2026-08-11
**Confidence:** HIGH for existing boundaries and APNs constraints; MEDIUM for production-operational recommendations.

## Feature Landscape

### Table Stakes (Users Expect These)

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| APNs-first provider adapter | A mobile adopter needs an actual server-to-APNs delivery path, not only contracts. | HIGH | Build from an explicit transport behaviour; persist a safe request correlation and APNs response outcome for every request. APNs acceptance is not device, user, or open confirmation. |
| Active-installation fanout | A person may use more than one active installation. | HIGH | Select every active, eligible APNs binding within the host's tenant/subject scope; model each installation target independently from the one logical `push` delivery. |
| Durable provider-attempt truth | Retries and uncertain network outcomes must remain explainable. | HIGH | Stable Chimeway attempt identity, idempotent Oban execution, redacted APNs request ID/reason, bounded retry classification, and a terminal outcome for every target. |
| Token lifecycle feedback | Invalid/unregistered tokens must stop future sends without erasing history. | MEDIUM | Apply APNs feedback to backend-owned Crosswake bindings: invalidating feedback changes binding state; transient/provider failures remain audit-only. |
| Host-controlled expiry | Time-sensitive notifications must not be delivered after their business value expires. | MEDIUM | Host supplies absolute expiry; Chimeway suppresses before dispatch and derives `apns-expiration` from it. Never invent expiry from user/device state. |
| Privacy-safe bounded payload | Push payloads travel through a third-party provider and are size limited. | HIGH | Strict size/field validation; opaque notification/open references only; no raw tokens, credentials, recipient identity, sensitive content, or trusted deep links. APNs rejects ordinary payloads over 4 KB. [Apple: Generating a remote notification](https://developer.apple.com/documentation/usernotifications/generating-a-remote-notification?changes=_3) |
| Protected notification-open path | A push tap must not bypass current authorization or route policy. | HIGH | Pass evidence through Crosswake's one-time open intent, manifest route/action allowlist, and current auth/step-up check. No fallback route on expiry, revocation, or denial. |
| Tenant-safe operator trace | Operators need to answer why a given installation did not receive a notification without data leakage. | MEDIUM | Show selection, suppression/expiry, each target attempt, response, binding mutation, and open decision; enforce tenant scope and redact sensitive data. |

### Differentiators (Competitive Advantage)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Explainable fanout ledger | Separates partial delivery from total failure, with an answer for each installation. | MEDIUM | Logical delivery can succeed when at least one eligible target is accepted while retaining failures/retries for other targets. Never collapse a mixed result into a misleading whole-delivery status. |
| Hermetic APNs digital twin | Makes transport headers, payload shape, expiry, retries, feedback, and protected opens merge-blocking without Apple credentials. | HIGH | Deterministic scripted adapter replaces live APNs in CI; include token rotation and crash/retry recovery scenarios. |
| Physical-iPhone sandbox proof | Confirms entitlement, sandbox environment, token acquisition, visible notification, and protected activation on a real generated shell. | MEDIUM | Separate non-hermetic acceptance evidence from the CI twin; record redacted evidence only and do not expand claims to delivery/read analytics. |
| Explicit delivery-claim taxonomy | Prevents overclaiming while preserving useful operations data. | LOW | Distinguish Chimeway dispatch, APNs accepted/rejected, binding revoked, app-open authorized/denied, inbox seen, and inbox read. |
| Opt-in semantic coalescing | Lets an adopter replace stale reminders without incorrectly merging distinct learning events. | MEDIUM | Host may supply a semantic collapse key; persist it and why it was used. APNs can retain only one pending notification per bundle ID, so universal collapse IDs are unsafe. [Apple: Sending notification requests to APNs](https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns?changes=_3) |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| FCM transport in this milestone | “Cross-platform” can suggest two provider implementations at once. | Divides validation and production hardening before the APNs path is proven. | Keep provider-neutral contracts; defer FCM transport and Android physical proof. |
| Generic offline/background-sync promise | Push seems like a way to keep all local data fresh. | Crosswake expressly supports one route-scoped replay seam, not app-wide background sync; background pushes are throttled and not guaranteed. [Crosswake offline guide](../../../crosswake/guides/offline.md) [Apple: Pushing background updates](https://developer.apple.com/documentation/usernotifications/pushing-background-updates-to-your-app) | Use a visible push to direct the user to canonical server data; retain Crosswake's explicit offline-island boundaries. |
| “Delivered/read/opened” provider analytics | Product teams want engagement measurement. | APNs acceptance does not prove presentation, receipt, read, or safe route activation. | Persist request outcomes; treat authorized app-submitted open and explicit inbox transitions as separate facts. |
| Raw-token storage or payload logging | Simplifies debugging. | Violates the safe token/evidence boundary and risks credential or user-data exposure. | Store opaque `token_ref`/fingerprint and redacted correlation evidence only. |
| Chimeway-owned identity, eligibility, timezone, deep links, or expiry policy | A library can appear easier when it owns application decisions. | Violates local-first host ownership and creates wrong authority boundaries. | Host supplies domain eligibility/time/route intent; Crosswake activates a permitted route; Chimeway owns delivery truth. |
| Generic campaign builder/device-management UI | A broad UI looks like a complete mobile offering. | Adds a SaaS control plane and distracts from durable embedded delivery. | Deliver queryable trace projections and host-controlled operator surfaces. |
| Silent fallback navigation after invalid open | Helps avoid a dead-end tap. | Can bypass intended route policy or conceal revocation/step-up. | Return an explicit safe denial and let the host show the appropriate recovery UI. |

## User, Host, and Operator Behaviors

| Actor | Required behavior | Boundary |
|-------|-------------------|----------|
| Host | Supplies tenant, recipient eligibility, identity/session lifecycle, timezone, absolute expiry, semantic event data, and intended route/action. Handles raw tokens at its boundary. | The host remains authority for business decisions and raw credentials. |
| Crosswake | Acquires permission/token evidence, identifies installation, binds safe token references, and activates only a route/action still permitted by current policy and auth. | Evidence never grants delivery, identity, or route authority. |
| Chimeway | Selects eligible active bindings, renders a bounded APNs payload, schedules/retries sends, persists per-target provider truth, and explains outcomes. | It does not assert device presentation or engagement. |
| Operator | Traces a notification from selection through APNs outcome and binding state without seeing secrets or cross-tenant data. | A partial fanout remains visible as per-target facts. |
| End user | Receives a minimal alert and, on tap, reaches the intended route only if the binding and authorization remain valid. | Open is not automatically `seen` or `read`. |

## Feature Dependencies

```text
Tenant/privacy invariants + Crosswake binding authority
  └──> APNs transport contract + per-installation target/attempt persistence
         └──> active binding selection + host expiry + idempotent Oban dispatch
                └──> APNs feedback -> binding lifecycle update
                       └──> protected open correlation + operator trace
                              ├──> hermetic APNs digital twin
                              └──> physical-iPhone APNs sandbox proof
```

### Dependency Notes

- **Per-installation target/attempt persistence requires the current delivery spine to be extended:** `chimeway_deliveries` is currently unique by notification and channel, so it cannot itself represent independent all-installation results ([delivery.ex](../../lib/chimeway/delivery.ex)). Keep it as the logical channel plan and add a target/attempt layer beneath it.
- **Dispatch requires active binding authority:** Crosswake bindings already carry installation, provider/platform/environment, scoped backend identity, lifecycle state, and safe token references ([contracts.ex](../../../crosswake/packages/crosswake_chimeway/lib/crosswake/companions/chimeway/contracts.ex); [token_binding.ex](../../../crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/token_binding.ex)).
- **Protected open requires delivery correlation, not a trusted deep link:** Crosswake's companion guide specifies backend-bound token/open records, route allowlists, and current RouteGate/Sigra evaluation ([companions.md](../../../crosswake/guides/companions.md)).
- **The physical proof is downstream of the hermetic twin:** native entitlement and APNs sandbox credentials are external acceptance evidence; they must not be the only regression gate.

## MVP Definition

### Launch With (v1.18)

- [ ] APNs-first adapter plus logical-delivery / per-installation target-attempt model — essential for all-active-installation production use without false aggregate truth.
- [ ] Binding selection, tenant/privacy enforcement, host expiry suppression, durable idempotent dispatch, and feedback-to-binding lifecycle — essential safety and recovery foundation.
- [ ] Opaque bounded payload and protected Crosswake notification-open correlation — essential to preserve authority and privacy boundaries.
- [ ] Operator-explainable trace and hermetic digital twin — essential CI proof of production behavior.
- [ ] Physical-iPhone APNs sandbox proof — essential to validate the real entitlement/token/provider path after hermetic coverage exists.

### Add After Validation (v1.x)

- [ ] Opt-in host-semantic APNs collapse keys — add after the adopter has verified which reminder classes are safely replaceable.
- [ ] Operator UI projections or inbox progression integration — add only when trace queries expose a demonstrated usability gap; do not infer `seen`/`read` from a push tap.
- [ ] FCM delivery adapter and Android physical proof — add after the APNs data model and retry/feedback semantics are stable.

### Future Consideration (v2+)

- [ ] Rich notification extensions, media, categories, and quick actions — defer until there is a concrete, privacy-reviewed adopter workflow.
- [ ] Aggregated engagement analytics — defer unless a consented, independently authoritative event model is specified.

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Per-installation durable APNs attempts | HIGH | HIGH | P1 |
| Expiry, retry, and feedback lifecycle | HIGH | HIGH | P1 |
| Protected open and privacy boundary | HIGH | HIGH | P1 |
| Hermetic digital twin | HIGH | HIGH | P1 |
| Physical-iPhone sandbox proof | HIGH | MEDIUM | P1 |
| Semantic collapse keys | MEDIUM | MEDIUM | P2 |
| FCM transport and Android proof | HIGH | HIGH | P3 |

## Sources

### Repository evidence (HIGH confidence)

- [Chimeway project context](../PROJECT.md) — local-first, explainability-first product contract.
- [Delivery schema](../../lib/chimeway/delivery.ex) — durable logical per-channel delivery and current uniqueness boundary.
- [Inbox lifecycle](../../lib/chimeway/inbox.ex) — recipient-scoped, idempotent `seen`/`read` facts.
- [Crosswake Chimeway contracts](../../../crosswake/packages/crosswake_chimeway/lib/crosswake/companions/chimeway/contracts.ex) — safe token evidence/binding vocabulary and one-time open evidence.
- [Crosswake Chimeway companion guide](../../../crosswake/guides/companions.md) — host authority, backend binding, protected resolver, and current non-claims.
- [Crosswake offline guide](../../../crosswake/guides/offline.md) — narrow route-scoped offline boundary and no background-sync claim.

### Primary external sources (HIGH confidence)

- [Apple: Sending notification requests to APNs](https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns?changes=_3) — best-effort delivery, retention/expiry, ordering, and pending-notification behavior.
- [Apple: Generating a remote notification](https://developer.apple.com/documentation/usernotifications/generating-a-remote-notification?changes=_3) — payload structure and 4 KB non-VoIP limit.
- [Apple: Pushing background updates to your app](https://developer.apple.com/documentation/usernotifications/pushing-background-updates-to-your-app) — low-priority, throttled, non-guaranteed background notifications.

---
*Feature research for: Chimeway v1.18 Adopter Alpha mobile delivery readiness*
*Researched: 2026-08-11*
