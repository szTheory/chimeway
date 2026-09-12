# Phase 101: CrossWake Registration & Protected Open - Research

**Researched:** 2026-08-22
**Domain:** iOS APNs registration evidence, host-owned binding authority, and fail-closed notification-route activation
**Confidence:** MEDIUM

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

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

### Deferred Ideas (OUT OF SCOPE)

- Sanitized CrossWake reference host, deterministic fake APNs transport, end-to-end scenario matrix, named `mix verify.*` entrypoints, and CI integration — Phase 102.
- Physical-iPhone sandbox evidence and final host/operator adoption guidance — Phase 103.
- Android/FCM support, generic offline/background sync, arbitrary notification actions, dashboards, analytics, and engagement tracking — future scope or explicit non-goals.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| OPEN-01 | Explicit permission → APNs registration → authenticated binding, including idempotency, rotation, revocation, and invalidation. | Host-only registry command, scoped exact-revision CAS, and token-redaction boundary. [VERIFIED: codebase grep] |
| OPEN-02 | Normalize notification action allowlists with manifests; deny malformed/absent/unknown policy. | Replace the three divergent policy forms with a closed normalized action-policy type. [VERIFIED: codebase grep] |
| OPEN-03 | Offline opaque tap queue; reconnect atomically consumes and reauthorizes all current authority. | Separate native capture/queue from host `IntentConsumer`; consume first, then current manifest and `RouteGate`. [VERIFIED: codebase grep] |
| OPEN-04 | Invalid or stale opens have no fallback and emit sanitized explainable denial. | Existing notification `RouteGate` transition is `:halt`; extend denial taxonomy and sanitization tests. [VERIFIED: codebase grep] |
</phase_requirements>

## Project Constraints (from AGENTS.md)

- Preserve local-first host ownership of data, policy, and delivery history.
- Persist stable notification identity/version rather than module names; keep the durable lifecycle explainable.
- Treat idempotency and suppression reasons as first-class behavior; use replaceable behaviours and contract tests for adapters.
- Preserve host ownership of auth, tenancy, URL generation, and correlation IDs; never expose sensitive payload fields in telemetry or operator surfaces.
- Maintain `mix verify.*`/`mix ci.*` parity where this phase owns a gate, and use executable evidence for objectively machine-testable behavior rather than human/UAT checkpoints.

## Summary

Phase 101 is a cross-repository contract-hardening phase: CrossWake owns native permission/token observation, a bounded opaque tap queue, compiled-manifest policy, and final native activation; the adopter host owns APNs token custody, tenant/session identity, binding mutation, intent persistence, and one-time consumption; Chimeway remains outside both authorities and only carries opaque delivery binding/open references. This matches the existing companion seam and prevents provider/client evidence from becoming an authorization grant. [VERIFIED: codebase grep] [CITED: https://developer.apple.com/documentation/usernotifications/registering-your-app-with-apns]

The implementation should harden existing code rather than introduce a generic push framework. The current `Resolver` allows every action for `notification_open: true` and checks manifest policy before consuming the host intent; the current schema/builder/serialization preserve `true` and `%{actions: ...}` separately. Replace that with one closed normalized representation where `true` means exactly the canonical default-tap action, and make the host return a fully reauthorized consumed resolution before CrossWake evaluates the current manifest and `RouteGate`. [VERIFIED: codebase grep]

**Primary recommendation:** Implement host-authoritative CAS contracts and a normalized `notification_open` policy first, then wire iOS observation/queue delegates to those contracts; cover every race, authority change, and denial via hermetic ExUnit/Swift tests. [VERIFIED: codebase grep]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| Permission request and APNs token callback | Browser / Client (iOS native host) | API / Backend | iOS initiates registration and receives an opaque token; only the authenticated host submits it to the registry. [CITED: https://developer.apple.com/documentation/uikit/uiapplication/registerforremotenotifications%28%29] |
| Token redaction and scoped binding lifecycle | API / Backend | Database / Storage | Host registry alone can authenticate tenant/session scope and atomically refresh, supersede, or revoke exact revisions. [VERIFIED: codebase grep] |
| Notification-open policy normalization | Frontend Server (compiled manifest producer) | Browser / Client | The same closed representation must be authored, compiled, serialized, validated, and evaluated by the CrossWake resolver. [VERIFIED: codebase grep] |
| Offline tap capture and bounded persistence | Browser / Client (iOS native host) | Database / Storage | Native code may retain opaque local evidence while offline, but cannot resolve authority or activate. [ASSUMED] |
| One-time intent consumption and current authority recheck | API / Backend | Database / Storage | The host owns the intent record, exact binding revision, tenant/session checks, and atomic one-winner update. [VERIFIED: codebase grep] |
| Final route authorization and activation | Frontend Server (CrossWake policy/RouteGate) | Browser / Client | CrossWake evaluates the current compiled manifest and RouteGate, then invokes the existing native activation seam only on allow. [VERIFIED: codebase grep] |

## Standard Stack

### Core

| Library / platform | Version | Purpose | Why Standard |
|--------------------|---------|---------|--------------|
| CrossWake core | `0.2.0` workspace source | Policy schema, manifest builder/types/validator, and `RouteGate`. [VERIFIED: codebase grep] | Reuse the active route-policy boundary instead of a parallel notification router. [VERIFIED: codebase grep] |
| `crosswake_chimeway` | `0.1.0` workspace source | Provider-neutral evidence contracts, redaction, intent-consumer behaviour, resolver, denial/telemetry boundary. [VERIFIED: codebase grep] | It already isolates CrossWake from host persistence/auth authority. [VERIFIED: codebase grep] |
| Swift `UserNotifications` / UIKit | iOS deployment target `15+` | Permission status, APNs registration, and notification-response delegate entrypoints. [VERIFIED: codebase grep] [CITED: https://developer.apple.com/documentation/usernotifications/handling-notifications-and-notification-related-actions] | Apple supplies the callback boundary; CrossWake should expose thin host delegates rather than wrap APNs itself. [CITED: https://developer.apple.com/documentation/uikit/uiapplication/registerforremotenotifications%28%29] |
| Host Ecto/PostgreSQL registry | Host selected | Binding revision and one-time intent CAS. [ASSUMED] | PostgreSQL predicate updates/transactions can provide a one-winner consume result without client-side locks. [CITED: https://hexdocs.pm/Ecto.Repo.html#c:update_all/3] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| ExUnit | Elixir built-in | Contract, property/table, privacy, and concurrency race tests. [VERIFIED: codebase grep] | All host/companion semantics that can be proven without a physical phone. [VERIFIED: codebase grep] |
| XCTest / Swift Package Manager | Swift tools `5.9` package declaration | iOS delegate/queue/activation state tests. [VERIFIED: codebase grep] | Test thin shell-core seams and ensure no local activation occurs when offline/denied. [ASSUMED] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Host-owned binding and intent registry | CrossWake-owned persistence | Rejected: it would violate the locked host ownership of tokens, identity, tenancy, sessions, and CAS operations. [VERIFIED: codebase grep] |
| Closed manifest action policy | Arbitrary payload deep link/action | Rejected: APNs/client data is evidence and cannot receive route or action authority. [VERIFIED: codebase grep] |

**Installation:** No new external dependency should be installed in this phase. [VERIFIED: codebase grep]

## Package Legitimacy Audit

Not applicable — Phase 101 should add no external package. [VERIFIED: codebase grep]

## Architecture Patterns

### System Architecture Diagram

```text
User grants permission
  -> iOS host requests APNs registration
  -> APNs callback supplies transient token
  -> host redacts/submits scoped observation
  -> authenticated host registry CAS
       -> same token: refresh current exact revision
       -> changed token: create replacement + supersede old exact revision
       -> logout/revocation/provider invalidation: conditional disable exact revision

APNs payload/tap
  -> iOS delegate extracts only opaque open/binding/action correlation evidence
  -> offline? queue bounded opaque item; do not activate
  -> reconnect
  -> host IntentConsumer atomic consume + reauthorize tenant/binding/session/expiry/server route+action
       -> denied/replay: sanitized outcome, no route
       -> valid: CrossWake resolver checks CURRENT normalized manifest action policy
                -> RouteGate(current auth, activation_source: :notification)
                    -> deny: halt, no fallback
                    -> allow: ActivationCoordinator activates trusted resolved route
```

### Recommended Project Structure

```text
../crosswake/
├── lib/crosswake/policy/                 # one normalization function and authoring validation
├── lib/crosswake/manifest/               # consume only normalized policy in build/type/validator/serialization
├── lib/crosswake/compatibility/          # final RouteGate notification halt behavior
├── packages/crosswake_chimeway/lib/      # contracts, resolver, redaction, denial, telemetry seams
├── packages/crosswake_chimeway/test/     # resolver + closed denial/contract race fixtures
└── packages/crosswake-shell-core-ios/    # host delegates, opaque queue, activation integration + XCTest
```

### Pattern 1: Data-first host authority behaviour

**What:** Define narrow host callbacks for binding observation/revocation and intent consumption; input/output contain opaque refs and a closed state/result vocabulary only. [VERIFIED: codebase grep]

**When to use:** Every transition that requires tenant, subject, session, token custody, expiry, or mutation authority. [VERIFIED: codebase grep]

**Implementation direction:** Extend `IntentConsumer.consume_intent/1` (or an adjacent behaviour) so success means the host atomically consumed exactly one intent after rechecking all current authority, returning a route/action result bound by the server. CrossWake must reject unexpected shape/state. [VERIFIED: codebase grep]

### Pattern 2: Normalize once, consume everywhere

**What:** Introduce a dedicated normalized `NotificationOpenPolicy` value, for example `%{default_action: "tap", actions: MapSet.new(["tap", ...])}`, that the schema creates and the route, builder, types, validator, serializer, inspection, and resolver consume. Exact struct names are discretionary. [ASSUMED]

**When to use:** At policy parsing/compilation time; runtime code must never reinterpret raw `true`, `false`, list, atom, or map authoring values. [VERIFIED: codebase grep]

**Required mapping:** `true` becomes only the canonical default action; explicit non-empty allowlists must include only recognized action identifiers; absent/false/malformed/empty/unknown action denies. [VERIFIED: codebase grep]

### Pattern 3: Predicate-CAS one-time consume

**What:** Execute one host database mutation whose predicate includes `open_ref`, unconsumed state, expiry, tenant, exact binding revision, session/version, and active/revocation state; mark consumed and return server-bound route/action only when one row changes. [CITED: https://hexdocs.pm/Ecto.Repo.html#c:update_all/3]

**When to use:** Reconnect processing and every duplicate/concurrent attempt. A zero-row result maps to a generic safe denial after the host classifies the authoritative state. [ASSUMED]

### Anti-Patterns to Avoid

- **Client-side authorization:** Do not derive URL, tenant, route, action, session, or binding authority from APNs payload/queue data. [VERIFIED: codebase grep]
- **Read-then-write consumption:** Do not query intent state then mark it consumed in a separate write; concurrent consumers can both activate. Use one atomic predicate update/transaction. [ASSUMED]
- **Policy drift:** Do not leave parsing, compiled serialization, and resolver with independent `true`/allowlist meanings. [VERIFIED: codebase grep]
- **Fallback after protected denial:** Do not call `on_unavailable` or `ActivationCoordinator.openURL` after a notification denial. [VERIFIED: codebase grep]
- **Raw diagnostic capture:** Do not store token, payload, URL, identity, or provider body in queue, contract metadata, denial details, telemetry, logs, or tests. [VERIFIED: codebase grep]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| APNs registration transport/callback plumbing | Custom token protocol or fixed-size token format | UIKit registration and app delegate callbacks. [CITED: https://developer.apple.com/documentation/uikit/uiapplication/registerforremotenotifications%28%29] | Apple delivers an opaque, variable-length token asynchronously and documents a failure callback. [CITED: https://developer.apple.com/documentation/usernotifications/registering-your-app-with-apns] |
| Notification action dispatch | Generic deep-link/action framework | `UNUserNotificationCenterDelegate` response action identifier plus the normalized host policy. [CITED: https://developer.apple.com/documentation/usernotifications/handling-notifications-and-notification-related-actions] | The system supplies the selected action, but it is not authorization. [ASSUMED] |
| One-time exclusion | In-memory mutex or client “seen” flag | Host database CAS transaction/predicate update. [CITED: https://hexdocs.pm/Ecto.Repo.html#c:update_all/3] | It survives process restarts and gives one concurrent winner. [ASSUMED] |
| Privacy filtering | Per-call key blacklists | Existing CrossWake redaction plus a closed allowlist at every public evidence boundary. [VERIFIED: codebase grep] | Existing contracts reject token-shaped public fields; unbounded metadata remains a regression risk. [VERIFIED: codebase grep] |

**Key insight:** This phase composes existing iOS, host, CrossWake, and Chimeway boundaries; it must not invent an alternate authority plane. [VERIFIED: codebase grep]

## Common Pitfalls

### Pitfall 1: Treating a token callback as registration authority

**What goes wrong:** A token snapshot activates a delivery route before authenticated tenant/session binding. [VERIFIED: codebase grep]

**How to avoid:** Model permission, APNs observation, and host binding as separate states; re-register at app launch and treat token changes as normal. [CITED: https://developer.apple.com/documentation/usernotifications/registering-your-app-with-apns]

**Warning signs:** Fixed token-length validation, client token caching, or a token-only binding key. [CITED: https://developer.apple.com/documentation/watchkit/wkextensiondelegate/didregisterforremotenotifications%28withdevicetoken%3A%29]

### Pitfall 2: Current `true` policy silently grants all actions

**What goes wrong:** Current resolver fallback allows any `action_ref` when `notification_open` is not `[actions: ...]`, and schema/build/serialization retain `true` as a distinct value. [VERIFIED: codebase grep]

**How to avoid:** Normalize before manifest construction and make resolver acceptance an exact membership check, including canonical default only. [VERIFIED: codebase grep]

**Warning signs:** Tests asserting an unrecognized action succeeds on a legacy-`true` route, or an empty explicit action list compiles. [ASSUMED]

### Pitfall 3: Offline queue becomes a bearer grant

**What goes wrong:** Native code opens from queued route/deep-link data while no current session, tenant, manifest, or binding check exists. [VERIFIED: codebase grep]

**How to avoid:** Queue opaque evidence only; reconnect to atomic host consumption, then evaluate fresh manifest and `RouteGate`. [VERIFIED: codebase grep]

**Warning signs:** Queue schema includes URL, payload, token, identity, or an “authorized” boolean. [ASSUMED]

### Pitfall 4: Revocation disables the wrong binding

**What goes wrong:** A logout/provider invalidation broad update disables a rotated replacement or another tenant/environment/topic/session. [VERIFIED: codebase grep]

**How to avoid:** Include exact opaque revision plus full authority scope in every update predicate and prove stale invalidation returns no change. [ASSUMED]

**Warning signs:** `UPDATE ... WHERE installation_ref = ...` without revision/state/session/tenant predicates. [ASSUMED]

## Code Examples

### iOS registration boundary

```swift
// Source: Apple UIKit registration docs; host retains token custody.
func application(_ application: UIApplication,
  didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
  // Send token only through the authenticated host registry client.
  // Do not log, persist in CrossWake, or derive route authority here.
  hostBindingClient.observeAPNsToken(deviceToken)
}
```

[CITED: https://developer.apple.com/documentation/uikit/uiapplicationdelegate/application%28_%3Adidregisterforremotenotificationswithdevicetoken%3A%29]

### Atomic intent consumption shape

```elixir
# Host-owned pseudocode: exact schema/column names are discretionary.
from(i in OpenIntent,
  where: i.open_ref == ^evidence.open_ref and is_nil(i.consumed_at),
  where: i.expires_at > ^now and i.tenant_id == ^current_tenant_id,
  where: i.binding_ref == ^evidence.binding_ref and i.session_version == ^session_version,
  where: i.binding_state == :active
)
|> Repo.update_all(set: [consumed_at: now])
```

[CITED: https://hexdocs.pm/Ecto.Repo.html#c:update_all/3] [ASSUMED: host schema illustration]

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| Token treated as durable identity / cached client value | APNs token is opaque, variable-length transport data; re-register and bind it to current host authority. [CITED: https://developer.apple.com/documentation/usernotifications/registering-your-app-with-apns] | Rotation must create/supersede host revisions rather than mutate identity assumptions. [VERIFIED: codebase grep] |
| Notification response performs deep-link routing | Response action becomes opaque evidence reauthorized by a server-bound intent, current compiled manifest, and RouteGate. [ASSUMED] | Offline tap cannot activate directly. [VERIFIED: codebase grep] |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The host will use Ecto/PostgreSQL for binding and one-time intent persistence. | Standard Stack / Pattern 3 | Planner must adapt the CAS test/transaction design to the adopter’s actual durable store. |
| A2 | A Swift local queue implementation can be kept bounded/durable without adding a package. | Responsibility Map | Exact storage and recovery semantics need a CrossWake implementation decision. |
| A3 | A predicate `update_all` with the listed scope is the selected host implementation. | Code Examples | The authoritative host may choose another transactional primitive, but must preserve one-winner semantics. |

## Open Questions (RESOLVED)

1. **What is the canonical default tap action identifier and normalized serialized shape?**
   - What we know: legacy `true` must mean exactly one default action and all non-default actions require explicit allowlisting. [VERIFIED: codebase grep]
   - What's unclear: the existing authoring type only accepts atoms for explicit actions while runtime evidence currently uses strings. [VERIFIED: codebase grep]
   - Resolution: use `tap` as the canonical default action identifier and `%{actions: [String.t()]}` as the sole normalized compiled/serialized shape. Schema normalization converts accepted atom authoring values to bounded strings; route structs, manifest building/serialization, validation, and resolver membership consume that representation without reinterpretation. This is implemented by Plan 101-02 and enforced at runtime by Plan 101-03. [RESOLVED: 2026-08-22]

2. **How does the host communicate distinct safe intent-denial states without leaking authority data?**
   - What we know: current denial codes cover expiry, replay, binding, route, action, and generic policy; the phase additionally needs explicit session/auth-safe outcomes. [VERIFIED: codebase grep]
   - What's unclear: whether a new stable public subcode is needed or existing `policy_denied` intentionally coalesces session/logout/tenant switch. [VERIFIED: codebase grep]
   - Resolution: coalesce logout, session/version, tenant-switch, and current-auth failures to the single stable public code `notification.open.authorization_denied`; keep binding-revoked, binding-mismatched, route/action mismatch, replay, expiry, and default-policy categories distinct. All public detail and telemetry pass through recursively closed bounded-scalar projections. This mapping is implemented and leak-tested by Plan 101-08. [RESOLVED: 2026-08-22]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Elixir / Mix | CrossWake companion/core tests | ✓ | Elixir/Mix 1.19.5, OTP 28 | — [VERIFIED: local command] |
| Swift Package Manager | shell-core delegate/queue tests | ✓ | Swift 6.3.3 | — [VERIFIED: local command] |
| Xcode | iOS-target compilation and XCTest | ✓ | Xcode 26.6 | — [VERIFIED: local command] |
| `crosswake_chimeway` Hex dependencies | Companion ExUnit tests | ✗ | `ex_doc` is not locked in the sibling checkout | Run `cd ../crosswake/packages/crosswake_chimeway && mix deps.get` before test execution. [VERIFIED: local command] |
| Physical iPhone / signing credentials | Phase 103 proof only | not required | — | Deferred; no Phase 101 completion dependency. [VERIFIED: codebase grep] |

**Missing dependencies with no fallback:** None for Phase 101’s implementation plan. The sibling checkout requires its normal `mix deps.get` preparation before the existing companion test command can run. [VERIFIED: local command]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit plus Swift XCTest/SPM. [VERIFIED: codebase grep] |
| Config file | `../crosswake/mix.exs`, `../crosswake/packages/crosswake_chimeway/mix.exs`, and `../crosswake/packages/crosswake-shell-core-ios/Package.swift`. [VERIFIED: codebase grep] |
| Quick run command | `cd ../crosswake/packages/crosswake_chimeway && mix test test/crosswake/companions/chimeway/resolver_test.exs` [VERIFIED: codebase grep] |
| Full suite command | `cd ../crosswake && mix verify && cd packages/crosswake-shell-core-ios && swift test` [VERIFIED: codebase grep] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| OPEN-01 | Idempotent observation, rotation, exact-revision logout/session/permission/provider invalidation including races. | Host contract/integration | Host fixture command to be added; focused companion contract test. | ❌ Wave 0 |
| OPEN-02 | `true` default action, explicit action membership, malformed/empty/unknown/absent policy deny through schema → manifest → resolver. | Unit/contract | `mix test` focused policy/manifest/resolver files. | Partial — resolver test exists; normalization coverage is ❌ Wave 0. [VERIFIED: codebase grep] |
| OPEN-03 | Offline queue records opaque-only evidence; concurrent reconnect has one consume winner; valid consume rechecks current authority then manifest + RouteGate. | XCTest + ExUnit race/contract | `swift test` and focused companion/host tests. | ❌ Wave 0 |
| OPEN-04 | Replay/expiry/revocation/mismatch/logout/tenant switch/removed route/action deny, halt, and emit only sanctioned details. | Unit/table + privacy regression | focused resolver/denial/RouteGate tests. | Partial — resolver/denial tests exist; full matrix is ❌ Wave 0. [VERIFIED: codebase grep] |

### Sampling Rate

- **Per task commit:** focused affected ExUnit or Swift test command. [VERIFIED: codebase grep]
- **Per wave merge:** `cd ../crosswake && mix verify` plus `swift test` for shell changes. [VERIFIED: codebase grep]
- **Phase gate:** all deterministic contracts/races/privacy checks green; do not request conversational UAT. [VERIFIED: codebase grep]

### Wave 0 Gaps

- [ ] Host registry contract fixture with deterministic clock and concurrency tests for observation, supersession, exact-revision invalidation, and intent consume.
- [ ] CrossWake schema/builder/types/validator/resolver round-trip tests for the closed normalized action policy.
- [ ] Swift queue/delegate tests proving opaque-only storage, limits/cleanup, offline no-activation, and reconnect handoff.
- [ ] Cross-product denial matrix tests asserting no fallback activation and recursive output sanitization.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | yes | Host authenticates every bind and intent consume; native evidence does not authenticate. [VERIFIED: codebase grep] |
| V3 Session Management | yes | Include current session/version in exact binding and consume predicates; logout/revocation conditionally disables only the matching revision. [VERIFIED: codebase grep] |
| V4 Access Control | yes | Current tenant, route/action policy, and `RouteGate` run before any activation. [VERIFIED: codebase grep] |
| V5 Input Validation | yes | Closed contract constructors, normalized policy validator, opaque-ref grammar, and denial sanitization. [VERIFIED: codebase grep] |
| V6 Cryptography | yes | Use existing host secret/HMAC custody for token fingerprinting; do not hand-roll cryptography. [VERIFIED: codebase grep] |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Replayed/open-ref race | Elevation of Privilege | Atomic host one-time consume with exactly one winner, current-state reauthorization, and replay denial. [ASSUMED] |
| Stale token invalidates rotated binding | Tampering / Denial of Service | Conditional update predicates include exact revision and authority scope. [VERIFIED: codebase grep] |
| APNs payload grants deep link or tenant | Spoofing / Elevation of Privilege | Treat payload as opaque evidence; server binds route/action and CrossWake rechecks policy/gate. [VERIFIED: codebase grep] |
| Sensitive diagnostics from callback/queue | Information Disclosure | Token redaction, closed metadata/details allowlists, and output-scan tests. [VERIFIED: codebase grep] |
| Notification denial navigates fallback route | Elevation of Privilege | `activation_source: :notification` must retain `RouteGate` `:halt` transition. [VERIFIED: codebase grep] |

## Sources

### Primary (HIGH confidence)

- CrossWake source contracts and resolver — implementation gaps and existing reusable seams. [VERIFIED: codebase grep]
- CrossWake policy/manifest/RouteGate source — authoring-to-runtime policy path and notification halt behavior. [VERIFIED: codebase grep]
- Chimeway Phase 101 context and requirements — locked scope and acceptance criteria. [VERIFIED: codebase grep]

### Secondary (MEDIUM confidence)

- [Apple: registering an app with APNs](https://developer.apple.com/documentation/usernotifications/registering-your-app-with-apns) — APNs registration/token lifecycle.
- [Apple: handling notification actions](https://developer.apple.com/documentation/usernotifications/handling-notifications-and-notification-related-actions) — notification-response delegate/action identifier.
- [Ecto.Repo `update_all/3`](https://hexdocs.pm/Ecto.Repo.html#c:update_all/3) — predicate update result semantics.

### Tertiary (LOW confidence)

- None beyond explicitly logged implementation assumptions.

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — existing CrossWake/CrossWake Chimeway/Shell core packages are direct codebase evidence; no new package recommendation. [VERIFIED: codebase grep]
- Architecture: HIGH — locked phase context and current seams agree on ownership and fail-closed flow. [VERIFIED: codebase grep]
- Pitfalls: MEDIUM — code shows the actual permissive resolver and Apple/Ecto docs support lifecycle/atomic-update mechanics; host schema remains adopter-specific. [VERIFIED: codebase grep] [CITED: https://developer.apple.com/documentation/usernotifications/registering-your-app-with-apns]

**Research date:** 2026-08-22
**Valid until:** 2026-09-21 for repository findings; recheck Apple/Ecto documentation before implementation if delayed.
