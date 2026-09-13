# Phase 101: CrossWake Registration & Protected Open - Context

**Gathered:** 2026-08-22 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Enable a CrossWake iOS host to move from explicit notification permission through APNs token observation into an authenticated, host-owned binding lifecycle, then activate a notification route only through a one-time, fail-closed authorization path. This phase owns idempotent observation, exact binding rotation/revocation/invalidation, normalized compiled-manifest action policy, opaque offline tap queueing, reconnect-time intent consumption, and current RouteGate authorization. The Phase 102 digital twin and CI gate, Phase 103 physical-iPhone proof and adoption guidance, Android/FCM, generic offline or background sync, and a general notification-action framework remain outside this phase.

</domain>

<decisions>
## Implementation Decisions

### Registration Lifecycle Authority

- **D-01:** Keep native permission, APNs token observation, and authenticated host binding as explicit sequential states. Token observation alone is advisory provider evidence and never grants identity, session, tenant, delivery, or route authority.
- **D-02:** Make the authenticated host registry the sole binding authority. Every observation is submitted within explicit tenant, installation, environment, topic/app-identity, subject, and current-session scope; observing the current token refreshes the same revision idempotently, while a changed token atomically creates the replacement revision and supersedes the prior one.
- **D-03:** Only the exact current active revision is eligible. Logout, session revocation, permission loss, host revocation, and recognized provider invalidation must conditionally disable the exact matching revision without affecting a replacement, another installation, environment, topic, session, or tenant.
- **D-04:** Raw APNs tokens remain transient between the iOS host and the authenticated host registry. CrossWake and Chimeway durable state, telemetry, logs, denials, DTOs, and proof-facing contracts carry only validated opaque refs, bounded fingerprints/classifications, and closed safe facts.

### Manifest-Consistent Notification Policy

- **D-05:** Normalize every `notification_open` declaration into one closed compiled-manifest representation shared by policy validation, manifest building/serialization, and runtime resolution. Absent, `false`, malformed, unrecognized, unknown-route, empty-action, and unknown-action forms deny by default.
- **D-06:** Preserve the legacy `notification_open: true` authoring form only as shorthand for one canonical default tap action. It must never mean that arbitrary present or future action references are allowed; any non-default action requires an explicit per-route allowlist entry.
- **D-07:** Bind route and action intent on the trusted host side. Client/APNs evidence may carry opaque correlation values but is never authority for a deep link, route, action, identity, tenant, binding, or session.
- **D-08:** After a one-time intent is accepted, evaluate the current compiled manifest and `RouteGate` with `activation_source: :notification` and current auth context. Every denial halts activation; notification opens never use `on_unavailable` fallback navigation.

### Offline One-Time Protected Open

- **D-09:** An offline notification tap enters a bounded queue containing only validated opaque evidence and display-safe local state. It must not resolve or activate a route locally, and queued evidence is not a bearer credential or authorization grant.
- **D-10:** On reconnect, resolve through the host-owned `IntentConsumer` seam. Atomic one-time consumption must have one winner and must recheck the current tenant, exact binding revision, expiry, session/version, and server-bound route/action intent; concurrent or subsequent consumers receive replay denial.
- **D-11:** CrossWake must then recheck the normalized current manifest route/action policy and immediately run RouteGate before native activation. Expired, replayed, revoked, mismatched, logged-out, tenant-switched, route-removed, action-removed, malformed, or authorization-denied opens activate nothing.
- **D-12:** Record stable sanitized outcomes for queued, consumed/authorized, replayed, expired, binding-revoked, binding-mismatched, route/action mismatch, session/auth denial, and default policy denial without exposing raw intent state, token, identity, payload, URL, or provider-controlled data.
- **D-13:** Extend only the iOS host seams needed for explicit permission/registration observation and opaque notification-open queueing/activation. Preserve host ownership of persistence, authentication, session authority, binding CAS operations, and one-time intents.

### the agent's Discretion

- Exact module, callback, struct, and host-delegate names, provided the registration and protected-open contracts remain data-first, explicit, replaceable, and fail closed.
- Exact canonical default-tap identifier and normalized manifest encoding, provided authoring, compiled output, validation, and runtime resolution share one representation and never widen `true` into an arbitrary-action grant.
- Exact queue storage mechanism, item/count/age bounds, retry scheduling, and terminal cleanup behavior, provided it stores opaque evidence only, survives the required offline/reconnect path, and cannot activate locally.
- Exact host transaction/schema design for binding observations and one-time intents, provided idempotency, supersession, compare-and-update invalidation, replay exclusion, and current-authority checks are enforced atomically with executable race evidence.
- Exact safe denial codes and telemetry event names, provided public outcomes remain stable, generic, non-disclosing, recursively sanitized, and distinguish protected open from APNs acceptance and inbox seen/read.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Active Chimeway milestone contract

- `.planning/ROADMAP.md` — Phase 101 goal, fixed boundary, dependency, four success criteria, and host/Chimeway/CrossWake ownership split.
- `.planning/REQUIREMENTS.md` — OPEN-01 through OPEN-04 acceptance requirements and explicit mobile/offline/action non-goals.
- `.planning/PROJECT.md` — v1.18 production goal, local-first posture, explainability requirement, and protected-open target feature.
- `.planning/METHODOLOGY.md` — cohesive, research-first, one-shot, durable-explainability, least-surprise, and low-escalation decision lenses.
- `.planning/phases/97-tenant-identity-compatible-upgrade/97-CONTEXT.md` — locked explicit tenant authority, fail-closed/non-disclosing access, and static-storage decisions inherited by Phase 101.
- `.planning/phases/98-privacy-safe-delivery-evidence/98-CONTEXT.md` — locked recursive privacy boundary and prohibition on durable raw tokens, identity, deep links, credentials, provider bodies, and uncontrolled metadata.
- `.planning/phases/99-multi-installation-delivery-recovery/99-CONTEXT.md` — locked opaque binding-revision identity, target lifecycle, provider-handoff vocabulary, and exact-revision semantics.
- `.planning/phases/100-optional-apns-adapter/100-CONTEXT.md` — locked host token custody, bounded opaque open reference, exact provider invalidation CAS, and separation of APNs acceptance from protected open.

### Governing CrossWake product and adopter constraints

- `../crosswake/AGENTS.md` — CrossWake ownership, privacy, fail-closed, offline-scope, Android-freeze, and automated-evidence working rules.
- `../crosswake/.planning/ADR-FIRST-B2C-ADOPTER.md` — governing infrastructure decision, privacy boundary, reversal conditions, stop list, and non-goals.
- `../crosswake/.planning/FIRST-B2C-ADOPTER-ADOPTION-BRIEF.md` — adopter path, ownership boundaries, surface audit, and proof sequence.
- `../crosswake/.planning/FIRST-B2C-ADOPTER-ROUTE-POLICY-MAP.md` — route owners and route-policy constraints for the first-adopter path.
- `../crosswake/.planning/PROJECT.md` — CrossWake thesis, constraints, history, and locked product decisions.
- `../crosswake/.planning/REQUIREMENTS.md` — current CrossWake milestone requirements and traceability that Phase 101 must not contradict.
- `../crosswake/.planning/ROADMAP.md` — active CrossWake phase ordering and fixed later physical-proof boundary.
- `../crosswake/.planning/STATE.md` — current CrossWake position, blockers, and deferred work.

### Existing CrossWake companion and authorization contracts

- `../crosswake/packages/crosswake_chimeway/lib/crosswake/companions/chimeway/contracts.ex` — token evidence, binding lifecycle, provider feedback, notification-open evidence, and safe validation vocabulary.
- `../crosswake/packages/crosswake_chimeway/lib/crosswake/companions/chimeway/intent_consumer.ex` — replaceable host-owned one-time intent consumption seam.
- `../crosswake/packages/crosswake_chimeway/lib/crosswake/companions/chimeway/resolver.ex` — existing manifest check, intent resolution, denial mapping, and RouteGate sequence to harden.
- `../crosswake/packages/crosswake_chimeway/lib/crosswake/companions/chimeway/denial_codes.ex` — stable sanitized notification-open denial vocabulary.
- `../crosswake/packages/crosswake_chimeway/lib/crosswake/companions/chimeway/redaction.ex` — companion token/evidence redaction and fingerprint boundary.
- `../crosswake/packages/crosswake_chimeway/lib/crosswake/companions/chimeway/telemetry.ex` — closed safe telemetry metadata boundary.
- `../crosswake/lib/crosswake/compatibility/route_gate.ex` — fail-closed current compatibility/auth evaluation and notification-source no-fallback behavior.

### Manifest and native integration seams

- `../crosswake/lib/crosswake/policy/schema.ex` — current `notification_open` authoring schema and normalization entry point.
- `../crosswake/lib/crosswake/policy/route.ex` — route policy data structure carrying notification-open declarations.
- `../crosswake/lib/crosswake/manifest/builder.ex` — compiled route-entry construction that must share the normalized policy form.
- `../crosswake/lib/crosswake/manifest/types.ex` — compiled manifest type and serialization contract for notification-open policy.
- `../crosswake/lib/crosswake/manifest/validator.ex` — fail-closed compiled-manifest validation seam.
- `../crosswake/packages/crosswake-shell-core-ios/Sources/CrosswakeShellCore/CrosswakeShellConfig.swift` — existing optional host-owned notification-token delegate seam.
- `../crosswake/packages/crosswake-shell-core-ios/Sources/CrosswakeShellCore/ActivationCoordinator.swift` — existing native activation classification and route-activation seam.

### Existing architecture and risk analysis

- `.planning/research/ARCHITECTURE.md` — recommended host/Chimeway/CrossWake boundaries and one-time protected-open sequence.
- `.planning/research/PITFALLS.md` — offline authorization bypass and permissive manifest-action failure modes plus required prevention matrix.
- `.planning/research/STACK.md` — host registry, CrossWake companion, opaque evidence, and reconnect-time authorization integration direction.
- `.planning/research/SUMMARY.md` — milestone-wide architecture, sequencing, risks, and explicit proof boundary.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `Crosswake.Companions.Chimeway.Contracts`: already defines provider-neutral token observation, binding states/reasons, provider feedback, notification-open evidence, and open-resolution vocabulary.
- `Crosswake.Companions.Chimeway.IntentConsumer`: existing behaviour seam for a host-owned atomic one-time intent registry.
- `Crosswake.Companions.Chimeway.Resolver`: existing route lookup, intent-consumer call, denial projection, and RouteGate delegation path; it should be hardened rather than replaced.
- `Crosswake.Companions.Chimeway.Redaction` and `.Telemetry`: established safe evidence/fingerprint and closed telemetry boundaries.
- `Crosswake.Compatibility.RouteGate`: already distinguishes notification activation and returns `:halt` instead of applying route fallback after denial.
- CrossWake policy schema, manifest builder/types/validator, and their tests: existing authoring-to-compiled-output contract where one normalized action policy can be enforced.
- iOS `CrosswakeShellConfig` and `ActivationCoordinator`: existing host delegate and activation seams for bounded registration/open integration without moving host authority into CrossWake.

### Established Patterns

- Companion contracts describe evidence and delegation; they do not become authentication, persistence, session, or delivery authorities.
- Binding identity is installation-, provider-, environment-, topic/app-identity-, tenant-, subject-, and session-sensitive; raw token equality is not durable public identity.
- CrossWake route activation is manifest-driven and fail closed, and notification-source denials halt rather than redirect.
- Chimeway and CrossWake operator/proof surfaces retain stable opaque refs and closed classifications, never raw tokens, session material, identity, URLs, provider bodies, or arbitrary metadata.
- Offline claims remain narrow and honest: a queued notification tap is pending evidence, not generic sync and not offline route authority.
- Objectively machine-testable idempotency, rotation, race, replay, expiry, manifest, authorization, fallback, privacy, and queue behavior requires executable evidence rather than conversational UAT.

### Integration Points

- CrossWake iOS permission and token callbacks into an authenticated host registry operation that produces/refreshes exact opaque binding revisions.
- Host logout/session-revocation and Chimeway APNs invalidation callbacks into the same exact-revision conditional lifecycle boundary.
- CrossWake policy authoring, manifest compilation/serialization/validation, and companion resolver action checks into one normalized default-deny contract.
- Native notification-tap capture into a bounded opaque queue, reconnect processing into `IntentConsumer`, and authorized results into `RouteGate` plus the iOS activation coordinator.
- Companion denial codes, redaction, telemetry, and host audit records for sanitized queued/consumed/authorized/denied lifecycle evidence.
- Existing companion contract/resolver tests, manifest schema/builder/validator tests, RouteGate notification tests, and Swift shell-core tests for the machine-executable acceptance matrix.

</code_context>

<specifics>
## Specific Ideas

- Treat `notification_open: true` as exactly “the ordinary notification tap action,” never “all actions.”
- Preserve one authorization narrative: opaque tap queued, one host intent consumed, current manifest/action checked, current RouteGate evaluated, then and only then native activation.
- Make wrong-tenant, logged-out, revoked, expired, replayed, malformed, removed-route, and unauthorized cases produce no fallback route and only generic sanitized public evidence.
- Keep protected-open truth distinct from local dispatch intent, APNs provider acceptance/rejection, exact-binding invalidation, inbox seen, and inbox read.

</specifics>

<deferred>
## Deferred Ideas

- Sanitized CrossWake reference host, deterministic fake APNs transport, end-to-end scenario matrix, named `mix verify.*` entrypoints, and CI integration — Phase 102.
- Physical-iPhone sandbox evidence and final host/operator adoption guidance — Phase 103.
- Android/FCM support, generic offline/background sync, arbitrary notification actions, dashboards, analytics, and engagement tracking — future scope or explicit non-goals.

</deferred>

---

*Phase: 101-crosswake-registration-protected-open*
*Context gathered: 2026-08-22*
