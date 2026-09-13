# Project Research Summary

**Project:** Chimeway v1.18 Adopter Alpha Mobile Delivery Readiness
**Domain:** APNs-first, tenant-safe mobile push delivery for an embedded Elixir notification layer
**Researched:** 2026-08-11
**Confidence:** HIGH

## Executive Summary

Chimeway should become the durable, explainable orchestration ledger for an iPhone-first CrossWake adopter—not a mobile identity or endpoint store. The production shape is one logical notification `Delivery` for the reminder decision, with durable `DeliveryTarget` children for every eligible installation and independent target attempts underneath. The host owns raw APNs tokens, credentials, binding lifecycle, business eligibility, and one-time open intents; CrossWake owns native permission/token acquisition and protected route activation. Chimeway persists only tenant-scoped opaque references, compact provider facts, and explainable outcomes.

The recommended execution path is an optional Pigeon `~> 2.0` APNs adapter behind an explicit host resolver/token-provider boundary. First establish tenant identity, migration compatibility, recursive redaction, and a target-aware durable outbox; then add APNs response classification, expiry, fanout aggregation, and binding feedback. Finish by joining CrossWake registration and fail-closed offline opens to a deterministic digital twin, followed by a signed physical-iPhone sandbox proof. APNs acceptance must remain a provider fact only: it does not prove display, open, seen, read, or engagement.

The principal risks are privacy leakage, cross-tenant targeting, stale or rotated token misuse, duplicate sends around a post-handoff crash, and offline navigation that bypasses current authority. Mitigate them with opaque host-owned refs; tenant filters on every event, trace, recovery, and mutation; per-revision target identity; a persisted attempt-start before provider I/O plus explicit ambiguous-handoff evidence; expiry-bounded retries; and one-time, reconnect-time reauthorization through CrossWake RouteGate.

## Key Findings

### Recommended Stack

Extend Chimeway’s established lifecycle and optional Oban dispatch rather than create a push-only queue. Use Pigeon `~> 2.0` (2.0.1) only when the APNs integration is enabled; it supplies the HTTP/2, TLS, JWT provider-token, persistent-connection, and normalized-response machinery that Chimeway should not reimplement. The host configures the Pigeon dispatcher and resolves secrets; the adapter sees a raw token only at the final host-owned send boundary.

**Core technologies:**

- Chimeway event → notification → delivery → attempt spine: durable planning, retry, recovery, and trace foundation to extend with target children.
- PostgreSQL/Ecto: additive tenant and target migrations, unique target identity, append-only attempts, and scoped recovery.
- Oban `~> 2.x` (optional existing integration): durable execution and retry of temporary target outcomes, bounded by semantic expiry.
- Pigeon `~> 2.0`: optional APNs HTTP/2 client and response-normalization boundary.
- Host endpoint/open registry: raw token, installation, binding, identity, session, credential, and one-time-open authority.
- ExUnit scripted fake transport: deterministic digital-twin proof without Apple credentials; add Mox only if explicit fakes become repetitious.

### Expected Features

**Must have (table stakes):**

- Tenant-qualified idempotency, lifecycle records, traces, recovery, and administrative access, with an explicit legacy single-tenant compatibility mode.
- Recursive, normalized redaction across persistence, telemetry, logs, DTOs, adapter outcomes, and evidence artifacts.
- Active-installation fanout beneath one logical push delivery, independent target lifecycle/attempts, zero-target suppression, and partial-failure explanation.
- APNs payload bounds, host-supplied absolute expiry, reason-aware retry/invalid-binding feedback, and per-target crash ambiguity handling.
- Explicit CrossWake permission/registration/binding lifecycle plus an opaque, one-time protected-open path that reauthorizes after reconnect.
- Explainable tenant-safe operator traces, hermetic digital-twin coverage, and a redacted physical-iPhone sandbox proof.

**Should have (competitive):**

- Logical-delivery aggregation that reports a mixed fanout honestly: success when at least one target is APNs-accepted while retaining each failed target’s evidence.
- An explicit outcome taxonomy that separates dispatch, APNs acceptance/rejection, binding changes, protected open authorization, inbox seen, and inbox read.
- Opt-in semantic collapse keys only for replaceable current-state reminders, never as a global coalescing mechanism.

**Defer (v2+ / after validation):**

- FCM/Android transport and physical proof; retain provider-neutral target fields but do not expand the initial operational surface.
- Generic offline/background sync, campaign builders, device-management UI, rich actions/media, and engagement analytics.
- Inbox progression/UI polish until operators demonstrate a gap in trace projections.

### Architecture Approach

The authoritative architecture has three boundaries: the host governs identity, policy, tokens, credentials, bindings, and open intents; Chimeway governs durable notification planning and per-installation delivery truth; CrossWake governs native registration and policy-checked activation. Add immutable `tenant_id` to events and notifications, preserve a logical `Delivery`, and add a `DeliveryTarget` child keyed by opaque binding reference/revision plus provider, platform, environment, and topic posture. Attempts attach to targets, not merely a channel. A host `TargetResolver` returns only eligible opaque targets; a host APNs gateway dereferences them just in time.

**Major components:**

1. Tenant spine and compatibility migration — tenant-qualified event/notification identity, idempotency, queries, backfill report, and legacy shim.
2. `Chimeway.Push.TargetResolver` and `DeliveryTarget` context — active target resolution, idempotent fanout, target claims/statuses, aggregation, and recovery.
3. Recursive redactor and compact diagnostic projection — single safe boundary for every observable or durable value.
4. Optional APNs adapter — Pigeon-backed bounded request construction, `apns-id`, response classification, exact-revision feedback, retry/expiry handling.
5. CrossWake companion lifecycle — explicit native permission/registration/binding and one-time reconnect-time protected opens.
6. Digital twin and physical-proof gate — deterministic scripted coverage in CI plus redacted real-device evidence outside CI.

### Critical Pitfalls

1. **Raw endpoint or credential leakage** — keep raw values host-only and recursively redact/drop token, auth, secret, URL, and deep-link forms before every Chimeway boundary; test nested payloads and diagnostic rendering.
2. **Using a token as user/device identity** — target installations and binding revisions, retain provider/platform/environment/topic posture, and supersede rotation atomically without affecting other installations.
3. **Global idempotency or channel-only uniqueness** — qualify idempotency by tenant and model all devices as target children; every query, feedback path, recovery claim, and mutation must require tenant scope.
4. **Blind retry after a crash or permanent APNs response** — persist an attempt-start/claim before I/O, use a stable `apns-id`, retain ambiguous handoff evidence, and classify status plus APNs reason before retrying or invalidating exactly one binding.
5. **Offline opens granting stale authority** — queue opaque evidence only; atomically consume once after reconnect and recheck expiry, tenant, binding revision, session, manifest allowlist, and RouteGate. Unknown or malformed action policy is default-deny.

## Implications for Roadmap

### Phase 97: Tenant Identity & Compatible Upgrade
**Rationale:** Tenant safety and privacy are preconditions for storing or resolving any mobile target; adding them afterward would make legacy fanout and operator evidence unsafe.

**Delivers:** Immutable tenant fields, `{tenant_id, idempotency_key}` uniqueness, tenant-required inbox/trace/admin/recovery APIs, additive migrations with an ambiguity report, explicit legacy single-tenant compatibility, and centralized recursive redaction.

**Addresses:** Tenant-safe operator trace and privacy-safe bounded evidence.

**Avoids:** Cross-tenant collisions, unscoped recovery, shallow diagnostic redaction, and guessed legacy tenant backfills.

### Phase 98: Multi-Installation Delivery & Recovery
**Rationale:** The existing logical channel delivery cannot represent two devices independently; establish target aggregates before attaching APNs transport behavior.

**Delivers:** `DeliveryTarget` identity/state, target-aware attempts, resolver contract, idempotent active-installation fanout, no-target suppression, partial aggregate outcomes, per-target claims, and tenant-scoped recovery with durable post-trigger planning and ambiguous-handoff evidence.

**Addresses:** Active-installation fanout, durable provider-attempt truth, explainable fanout ledger, and host expiry propagation.

**Avoids:** One-device suppression of another, duplicate recovery sends, and falsely treating planned-with-no-targets as provider success.

### Phase 99: Optional APNs Adapter
**Rationale:** Transport becomes safe only after target identity, claims, and redaction can preserve reason-specific provider facts.

**Delivers:** Optional Pigeon `~> 2.0` adapter, host-owned dispatcher/token lookup, bounded alert payloads with opaque `open_ref`, topic/environment posture, stable `apns-id`, expiry, opt-in collapse, reason classification, and exact-binding invalidation.

**Addresses:** APNs-first delivery, expiry/retry/feedback lifecycle, and compact explainable APNs evidence.

**Avoids:** Hand-built HTTP/2/JWT behavior, permanent-error retries, configuration errors invalidating endpoints, environment/topic confusion, and universal collapse IDs.

### Phase 100: CrossWake Registration & Protected Open
**Rationale:** A real push is incomplete until installation registration, rotation, logout, and notification activation preserve host authority end to end.

**Delivers:** Explicit permission → APNs registration → authenticated binding flow; rotation/revocation feedback; compiled manifest allowlist fixes; offline evidence queue; and atomic reconnect-time one-time intent consumption plus RouteGate reauthorization.

**Addresses:** Protected notification open, token lifecycle feedback, and safe offline behavior.

**Avoids:** Offline bearer authority, replayed/expired opens, silent fallback navigation, and permissive malformed action configuration.

### Phase 101: Alpha Digital Twin & Hermetic Gate
**Rationale:** The regression gate must exercise the public host/Chimeway/CrossWake boundaries deterministically before external device credentials can be trusted as evidence.

**Delivers:** Sanitized CrossWake reference host, real Chimeway persistence, deterministic time/token registry/scripted APNs transport, named `mix verify.*` gates, CI integration, and machine-validated physical-proof schema.

**Addresses:** Hermetic APNs twin and operator-explainable production behavior.

**Avoids:** flaky credential-dependent CI, shallow happy-path mocks, untested rotation/revocation/retry/replay paths, and sensitive proof output.

### Phase 102: Physical iPhone & Adoption Truth
**Rationale:** The digital twin verifies policy; a signed physical device is the separate production acceptance proof for entitlement, sandbox routing, and native host wiring.

**Delivers:** Extended CrossWake physical-proof path covering permission, token registration, APNs acceptance, visible alert confirmation, and protected one-time activation; dated redacted evidence; and operator/adopter documentation.

**Addresses:** Physical-iPhone sandbox proof and clear limits on delivery/open claims.

**Avoids:** treating simulator evidence as real-device proof or conflating subjective display confirmation with machine-verifiable provider/open facts.

### Phase Ordering Rationale

- Establish tenant, migration, and privacy invariants before creating endpoint data or public evidence; they constrain every downstream schema and API.
- Separate logical planning from per-installation execution so policy/schedule/expiry are evaluated once while devices remain independently recoverable and explainable.
- Make APNs a thin optional adapter behind host authority, then connect native registration/open behavior once the backend vocabulary is stable.
- Require deterministic CI evidence before physical proof. The phone validates real entitlement and sandbox wiring but cannot serve as a repeatable release gate.

### Research Flags

Phases likely needing deeper research during planning:

- **Phase 97:** Existing migration/backfill, uniqueness, trace, and compatibility surfaces need exact codebase analysis to avoid a breaking upgrade.
- **Phase 99:** Confirm Pigeon’s installed API/configuration against the Elixir floor and exhaustively map its normalized response/GOAWAY semantics into Chimeway classifications.
- **Phase 100:** CrossWake’s native compiled manifest and resolver behavior require joint code-level analysis, especially the default-deny action policy and offline queue lifecycle.
- **Phase 102:** Apple signing/provisioning and the current CrossWake physical handoff require environment-specific validation; this is intentionally external acceptance work.

Phases with standard patterns (skip research-phase unless local implementation surprises arise):

- **Phase 98:** Ecto child aggregate, idempotent target fanout, append-only attempt records, leases, and tenant indexes are established patterns; focus planning on integration details.
- **Phase 101:** Deterministic clocks, fake transports, contract fixtures, and `mix verify.*` CI wiring are well-established locally.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Pigeon/APNs choice is supported by official Apple protocol requirements and existing Chimeway adapter/Oban seams. |
| Features | HIGH | Table stakes derive from Adopter Alpha’s explicit delivery/open requirements, repository boundaries, and Apple payload constraints. |
| Architecture | HIGH | The logical-delivery/target-child model follows verified local schemas and CrossWake companion contracts; physical operations remain environment-dependent. |
| Pitfalls | HIGH | Top risks are grounded in Apple documentation plus concrete current Chimeway/CrossWake seams. |

**Overall confidence:** HIGH

### Gaps to Address

- **Pigeon operational behavior:** Verify exact current APIs, response reasons, provider-token refresh, and test URI support when the optional dependency is introduced; preserve a fake facade regardless.
- **Legacy tenant migration:** Identify all unambiguous tenant evidence and publish an operator reconciliation path for legacy-unscoped rows; never infer a tenant.
- **APNs payload contract:** Choose the final display-safe copy, payload-size enforcement, and per-occurrence collapse policy with the adopter without placing business content in planning artifacts.
- **Physical proof environment:** The host must supply Apple team/key/bundle/sandbox configuration and a signed trusted iPhone; CI must validate evidence structure but cannot validate that external state.
- **Android scope:** Contracts should retain provider/platform extensibility, but FCM, Android lifecycle, and generic offline sync require a separate adopter-driven milestone.

## Sources

### Primary (HIGH confidence)

- [Chimeway stack research](STACK.md) — Pigeon/APNs boundary, optional dependency posture, retry mapping, and test seam.
- [Chimeway feature research](FEATURES.md) — launch scope, dependencies, anti-features, and prioritization.
- [Chimeway architecture research](ARCHITECTURE.md) — host/Chimeway/CrossWake boundaries, target aggregate, migration path, and proof order.
- [Chimeway pitfalls research](PITFALLS.md) — tenant, privacy, lifecycle, APNs, offline-open, and proof risks.
- [Apple APNs registration, request, response, and connection documentation](https://developer.apple.com/documentation/usernotifications) — provider protocol, payload, expiry, and reason-handling constraints.
- CrossWake Chimeway contracts/resolver and physical-iPhone handoff — opaque binding/open vocabulary and route-safe activation behavior.

---
*Research completed: 2026-08-11*
*Ready for roadmap: yes*
