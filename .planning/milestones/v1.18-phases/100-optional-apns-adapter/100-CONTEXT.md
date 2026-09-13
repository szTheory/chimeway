# Phase 100: Optional APNs Adapter - Context

**Gathered:** 2026-08-20 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Provide an explicitly opt-in, Pigeon-backed APNs target adapter for hosts that need iPhone push delivery. The phase owns safe request construction, host-controlled token and dispatcher resolution, stable APNs request identity, expiry and collapse handling, reason-aware provider classification, exact-binding invalidation, and honest operator evidence. It does not add Pigeon or APNs configuration to non-push hosts, take durable custody of raw tokens or credentials, implement CrossWake registration or protected-open authorization, build the hermetic adopter twin, or prove the physical-iPhone path; those remain owned by Phases 101-103.

</domain>

<decisions>
## Implementation Decisions

### Optional Adapter and Host Custody

- **D-01:** APNs is an explicit opt-in `Chimeway.TargetAdapter` implementation. A non-push consumer must be able to fetch, compile, boot, and use Chimeway without Pigeon in its dependency tree and without any APNs configuration; an opted-in host explicitly adds and starts Pigeon.
- **D-02:** The host supervises credential-bearing Pigeon dispatchers and retains custody of `.p8` keys, key identifiers, team identifiers, and connection configuration. Chimeway receives only an opaque dispatcher reference selected for the exact environment and credential posture.
- **D-03:** At the final send boundary, a host-owned lookup resolves the exact tenant-scoped `binding_revision_ref` to transient request material. The raw device token may exist only ephemerally for request construction and must never enter Chimeway-owned persistence, logs, telemetry, traces, DTOs, exceptions, or proof artifacts.
- **D-04:** Missing, stale, mismatched, or invalid host lookup results fail before provider handoff with stable, safe evidence. Lookup and invalidation contracts remain tenant-explicit and non-disclosing.

### Durable, Bounded Request Intent

- **D-05:** Persist and validate safe APNs request intent before target execution: exact environment and topic, stable UUID-shaped `apns-id`, host-supplied absolute expiry, opaque one-time open reference, and optional replaceability/collapse identity. Raw tokens, credentials, rendered provider payloads, and provider bodies are never part of that durable intent.
- **D-06:** Every retry or recovery attempt reuses the original stable request identity and safe intent, re-resolves only the exact binding revision's transient token/dispatcher material, and rechecks absolute expiry before provider I/O. Expired work terminates with explicit expiry evidence and no APNs request.
- **D-07:** Construct a closed, allowlisted APNs payload from validated push rendering plus the opaque open reference. Do not expose a general top-level custom-map merge; enforce Apple's ordinary 4,096-byte payload limit before provider I/O and preserve Phase 98 recursive privacy rejection.
- **D-08:** Omit `apns-collapse-id` by default. Emit it only for a host-opted replaceable occurrence, using a stable opaque value no longer than 64 bytes and scoped to the occurrence plus exact binding revision, environment, and topic so it cannot coalesce a distinct notification or installation.
- **D-09:** Treat stable `apns-id` as correlation only. It does not provide provider deduplication and does not make a re-drive after an ambiguous handoff safe.

### Honest Outcomes and Exact Invalidation

- **D-10:** Extend the target-adapter result contract so every conclusive result follows one of four durable paths: accepted provider handoff, retryable rejection with a defined corrective action/backoff, permanent payload or configuration rejection, or exact-binding invalidation. Preserve the original attempt and safe provider facts in all cases.
- **D-11:** A confirmed APNs 200/Pigeon success is `provider_accepted` handoff only. It never means device receipt, display, protected open, inbox seen/read, or engagement.
- **D-12:** Retry only confirmed pre-provider failures or conclusive APNs rejections whose documented remedy is retry/backoff or connection/provider-token refresh, and recheck expiry first. Treat ordinary request, topic, environment, credential, authorization, and payload errors as terminal for the unchanged request.
- **D-13:** Any Pigeon synchronous `:timeout`, process exit, connection loss, or missing durable response after request emission may have occurred is `ambiguous_handoff`, not retryable. Do not blindly resend it.
- **D-14:** Pin and contract-test the supported Pigeon result vocabulary. Pigeon 2.0.1's normalized response is not sufficient as the sole reason source because it discards HTTP status and 410 timestamp and maps current Apple reasons to `:unknown_error`; preserve status/reason through a narrow reason-aware seam where required. Any still-unknown conclusive provider rejection fails closed as permanent and must neither retry nor invalidate.
- **D-15:** Only APNs 410 `ExpiredToken` or `Unregistered` may trigger provider-driven binding invalidation. `BadDeviceToken`, `DeviceTokenNotForTopic`, and other routing/configuration failures do not authorize invalidation.
- **D-16:** Host invalidation is a conditional compare-and-update against the exact `{tenant_id, environment, topic, binding_revision_ref}` used by the request. It must never resolve and invalidate a later current revision, a different installation, another environment, or another tenant. Chimeway marks only the matching delivery target invalidated and retains the attempt evidence.

### the agent's Discretion

- Exact module, behaviour, callback, struct, and configuration names, provided the public contracts remain data-first, explicit, tenant-safe, and optional.
- Exact optional-dependency and conditional-compilation packaging, provided clean-consumer executable evidence proves Chimeway fetches, compiles, and boots with Pigeon absent and opted-in evidence proves the adapter path.
- Exact table/column placement for safe request intent and exact reason-preserving Pigeon integration mechanism, provided the locked durability, privacy, version-pinning, and response-classification contracts hold.
- Exact closed APS allowlist, validation error names, safe provider-fact keys, retry schedule, and backoff implementation, provided Apple limits and documented retry delays are honored and classifications remain stable and executable.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Active milestone contract

- `.planning/ROADMAP.md` — Phase 100 goal, dependency, fixed boundary, and five success criteria.
- `.planning/REQUIREMENTS.md` — Binding APNS-01 through APNS-06 acceptance requirements and explicit mobile-delivery non-goals.
- `.planning/PROJECT.md` — v1.18 host/Chimeway/CrossWake ownership split, local-first posture, privacy boundary, and APNs target features.
- `.planning/METHODOLOGY.md` — Cohesive recommendation, research-first ownership, durable explainability, least-surprise DX, and low-escalation lenses applied to this phase.
- `.planning/phases/97-tenant-identity-compatible-upgrade/97-CONTEXT.md` — Locked tenant identity, fail-closed scoping, host authority, and static storage decisions inherited by Phase 100.
- `.planning/phases/98-privacy-safe-delivery-evidence/98-CONTEXT.md` — Locked recursive safe-evidence boundary and prohibition on durable raw tokens, credentials, links, payloads, and provider bodies.
- `.planning/phases/99-multi-installation-delivery-recovery/99-CONTEXT.md` — Locked target lifecycle, pre-I/O attempt evidence, ambiguous handoff, recovery, aggregation, and exact binding-revision decisions.

### Existing adapter, target, and evidence contracts

- `mix.exs` — Dependency and application-start surface where Pigeon optionality must be proven.
- `lib/chimeway/target_adapter.ex` — Existing replaceable target-provider behaviour and envelope seam.
- `lib/chimeway/target_resolver.ex` — Opaque tenant-scoped binding-revision contract.
- `lib/chimeway/dispatch/executor.ex` — Current target adapter invocation and coarse result classification to replace with APNs-aware outcomes.
- `lib/chimeway/delivery_targets.ex` — Atomic target claim, attempt-start, retry, expiry, invalidation, aggregation, and result persistence spine.
- `lib/chimeway/delivery_target.ex` — Durable per-binding-revision target identity and lifecycle states.
- `lib/chimeway/delivery_target_attempt.ex` — Append-only target attempt outcome and safe-fact contract.
- `lib/chimeway/safe_evidence.ex` — Closed evidence vocabulary and recursive privacy enforcement boundary.
- `lib/chimeway/rendering/channels/push.ex` — Existing generic push content validation and provider-plumbing boundary.
- `test/chimeway/dispatch/target_worker_test.exs` — Executable target claim, pre-I/O evidence, ambiguity, retry exhaustion, and target-safe-fact patterns.

### Provider and library contracts

- [Pigeon 2.0.1 APNs notification documentation](https://pigeon.hexdocs.pm/Pigeon.APNS.Notification.html) — Notification fields, synchronous result vocabulary, and public request API.
- [Pigeon 2.0.1 APNs shared transport source](https://github.com/codedge-llc/pigeon/blob/v2.0.1/lib/pigeon/apns/shared.ex) — Header construction and response normalization behavior that must be pinned by contract tests.
- [Pigeon 2.0.1 synchronous push source](https://github.com/codedge-llc/pigeon/blob/v2.0.1/lib/pigeon.ex) — Local receive-timeout behavior requiring ambiguous-handoff treatment.
- [Apple: Sending notification requests to APNs](https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns) — Canonical APNs request headers, payload limits, expiration, and collapse semantics.
- [Apple: Handling notification responses from APNs](https://developer.apple.com/documentation/usernotifications/handling-notification-responses-from-apns) — Canonical status/reason meanings, retry guidance, and exact-token invalidation semantics.
- [Apple: Establishing a token-based connection to APNs](https://developer.apple.com/documentation/usernotifications/establishing-a-token-based-connection-to-apns) — Credential, team, connection, and provider-token constraints owned by host dispatchers.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `Chimeway.TargetAdapter` and `Chimeway.TargetAdapter.TargetEnvelope`: existing provider handoff seam for an optional APNs implementation.
- `Chimeway.DeliveryTargets`: atomic target claiming, attempt-start persistence, retry exhaustion, expiry, invalidation, exact target mutation, and parent aggregation.
- `Chimeway.SafeEvidence.target_attempt_facts/1`: closed provider-evidence boundary to extend with bounded APNs classifications rather than raw responses.
- `Chimeway.Rendering.Channels.Push`: validated content seam that keeps APNs headers and transport mechanics out of generic rendering.
- Target worker and delivery target tests: established executable patterns for pre-I/O truth, ambiguity, no duplicate provider call, retry exhaustion, tenant safety, and privacy assertions.

### Established Patterns

- Tenant-qualified binding revisions are opaque values, and durable target identity converges on `{delivery_id, binding_revision_ref}`.
- Attempt-start is persisted before provider I/O; unknown post-I/O outcomes are ambiguous and are not blindly retried.
- Provider acceptance means provider handoff only, with engagement states projected separately.
- Optional integrations use explicit dependency/configuration boundaries rather than mandatory runtime services.
- Operator surfaces project small closed facts and stable lifecycle reasons rather than raw provider bodies, payloads, credentials, or tokens.
- Objectively machine-testable optionality, payload bounds, expiry, classification, invalidation, and privacy acceptance must use executable evidence, not conversational UAT.

### Integration Points

- `lib/chimeway/target_adapter.ex` and `lib/chimeway/dispatch/executor.ex` for the richer APNs request/result and host-lookup boundary.
- `lib/chimeway/delivery_target.ex`, `lib/chimeway/delivery_target_attempt.ex`, and `lib/chimeway/delivery_targets.ex` for safe durable request intent, expiry suppression, classifications, and exact invalidation.
- `lib/chimeway/safe_evidence.ex`, trace/explanation projections, telemetry, and operator DTOs for bounded APNs facts and distinct outcome vocabulary.
- `lib/chimeway/rendering/channels/push.ex` for the closed boundary between approved visible content and APNs-specific headers/custom data.
- `mix.exs`, clean-consumer fixtures, and release-gate contracts for Pigeon-absent and Pigeon-enabled compilation/boot evidence.

</code_context>

<specifics>
## Specific Ideas

- Treat Pigeon `:timeout` as possible handoff ambiguity even though Pigeon's public typespec describes it as a timeout-style error.
- Use host-supervised dispatcher references so Chimeway never owns Apple credentials and environment selection is explicit at the connection boundary.
- Preserve one operator narrative: local dispatch intent, provider acceptance/rejection, retry exhaustion, exact-binding invalidation, protected open, and inbox seen/read are separate facts.
- Fail closed on future or unknown provider reasons: no automatic retry and no invalidation without a positively recognized safe classification.
- Stable `apns-id` is correlation evidence, never an exactly-once or deduplication promise.

</specifics>

<deferred>
## Deferred Ideas

- CrossWake token registration, rotation/revocation, offline tap queueing, one-time protected-open consumption, and authorization — Phase 101.
- Hermetic fake-APNs adopter twin, cross-repository verification entrypoints, and provider-reason scenario matrix — Phase 102.
- Physical-iPhone sandbox evidence and final integration/operator guidance — Phase 103.
- FCM/Android transport and a broad channel matrix — future milestone scope.

</deferred>

---

*Phase: 100-optional-apns-adapter*
*Context gathered: 2026-08-20*
