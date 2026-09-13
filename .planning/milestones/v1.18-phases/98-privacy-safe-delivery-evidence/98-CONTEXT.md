# Phase 98: Privacy-Safe Delivery Evidence - Context

**Gathered:** 2026-08-12 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Make Chimeway-owned delivery evidence safe to persist and emit while remaining operationally explainable. This phase covers recursive redaction and a shared safe-evidence vocabulary across persistence, attempt results, telemetry, logs, traces, DTOs, and proof output. Mobile target fan-out, APNs dispatch behavior, recovery, protected opens, and new provider capabilities remain owned by later phases.

</domain>

<decisions>
## Implementation Decisions

### One Recursive Privacy Boundary

- **D-01:** Establish one core, atom-safe recursive privacy boundary for maps, lists, and keyword-shaped values. It must normalize atom and string keys case-insensitively without creating atoms from caller-controlled input.
- **D-02:** Apply the shared boundary before every Chimeway persistence write and diagnostic projection. Surface-specific shallow filters may remain only as defense-in-depth; they are not the privacy contract.
- **D-03:** Forbidden keys and their values are removed recursively rather than masked inside otherwise retained sensitive blobs. Nested and mixed-case forms must behave identically.

### Opaque Durable Evidence, Not Sanitized Sensitive Blobs

- **D-04:** Raw device tokens, endpoints, credentials, recipient or adopter data, trusted deep links, rendered content, and provider bodies are prohibited at Chimeway-owned write boundaries.
- **D-05:** Durable evidence is explicit and allowlisted: opaque references or fingerprints, stable outcomes and error classifications, lifecycle identifiers and timestamps, render identity, and narrowly allowlisted provider facts.
- **D-06:** Do not retain redacted provider bodies or generic diagnostic maps as a fallback. Explainability must come from structured safe facts, not sanitized copies of sensitive source material.

### Explainability Through Safe Projections

- **D-07:** Delivery traces, attempt results, telemetry, logs, admin DTOs, and proof artifacts share one safe evidence vocabulary and never expose raw lifecycle schemas or uncontrolled diagnostic values.
- **D-08:** Preserve the facts operators need to explain behavior—status, reason, classification, timeline, timestamps, render identity, and opaque identifiers—while excluding raw identity, content, endpoint, credential, link, and provider-controlled values.
- **D-09:** Core API and projection boundaries must be safe independently of `chimeway_admin`. View-layer recipient masking and timeline allowlisting remain defense-in-depth, not the primary privacy control.

### the agent's Discretion

- Exact module and function names for the shared recursive privacy boundary.
- Exact forbidden-key taxonomy and safe provider-fact allowlist, provided they cover PRIV-03/PRIV-04 fixtures, are case-normalized, and default closed for diagnostic blobs.
- Exact opaque-reference and fingerprint representation, provided it is stable enough for correlation, cannot recover the source value, and does not transfer host-owned identity or credential custody into Chimeway.
- Exact internal migration or compatibility mechanics for existing generic JSON fields, provided new writes cannot retain prohibited data and existing lifecycle explainability remains intact.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Active milestone contract

- `.planning/ROADMAP.md` — Phase 98 goal, fixed boundary, dependency, and three success criteria.
- `.planning/REQUIREMENTS.md` — Binding PRIV-03 and PRIV-04 acceptance requirements and explicit mobile-delivery non-goals.
- `.planning/PROJECT.md` — v1.18 local-first ownership boundaries, durable explainability posture, and privacy target features.
- `.planning/METHODOLOGY.md` — cohesive recommendation, durable explainability, least-surprise DX, and low-escalation lenses applied to this phase.
- `.planning/phases/97-tenant-identity-compatible-upgrade/97-CONTEXT.md` — locked tenant identity, host ownership, fail-closed access, and static storage decisions inherited by Phase 98.

### Existing privacy and operator contracts

- `.planning/milestones/v1.11-phases/71-redaction-and-explainability-contracts/71-CONTEXT.md` — prior redaction, DTO, and operator explainability decisions that Phase 98 must strengthen rather than bypass.
- `lib/chimeway/trigger.ex` — current event and notification persistence sanitization seams.
- `lib/chimeway/deliveries.ex` — current delivery-attempt persistence and provider-response sanitization seams.
- `lib/chimeway/telemetry.ex` — central telemetry metadata allowlist and default diagnostic projection.
- `lib/chimeway/traces.ex` — trace timeline, attempt summary, and explanation projection surfaces.
- `lib/chimeway/admin.ex` — core admin DTO projection surface.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `Chimeway.Telemetry.safe_meta/1` in `lib/chimeway/telemetry.ex` is the established telemetry allowlist seam.
- `ChimewayAdmin.Redaction` in `chimeway_admin/lib/chimeway_admin/redaction.ex` provides recipient masking and timeline-detail allowlisting as downstream defense-in-depth.
- Trace timeline construction and last-attempt summaries in `lib/chimeway/traces.ex` already retain durable outcomes and classifications without needing provider bodies.
- Adversarial fixtures in `test/chimeway/trigger_sanitization_test.exs`, `test/chimeway/admin_test.exs`, `test/chimeway/traces_test.exs`, and `chimeway_admin/test/chimeway_admin/live/privacy_leak_live_test.exs` can be expanded into cross-surface leak regression evidence.
- Proof allowlist and sensitive-output rejection patterns in `test/chimeway/release_gate_contract_test.exs` provide an executable evidence-contract precedent.

### Established Patterns

- Operator surfaces use small DTOs instead of returning raw Ecto schemas.
- Telemetry projects an explicit allowlist rather than forwarding general payload data.
- Explainability derives from durable lifecycle rows, stable reasons, and classifications.
- Existing persistence sanitizers normalize atom/string keys case-insensitively but inspect only one level; Phase 98 closes the recursive gap.
- Objectively machine-testable privacy acceptance must be `type="auto"` with executable evidence; no conversational UAT or human verification checkpoint is appropriate.

### Integration Points

- Event and notification writes in `lib/chimeway/trigger.ex`.
- Delivery planning and attempt writes in `lib/chimeway/delivery.ex`, `lib/chimeway/deliveries.ex`, and `lib/chimeway/delivery_attempt.ex`.
- Telemetry spans, direct events, and default logs in `lib/chimeway/telemetry.ex`, `lib/chimeway/dispatch/executor.ex`, and `lib/chimeway/rendering.ex`.
- Trace, explanation, admin DTO, and LiveView paths in `lib/chimeway/traces.ex`, `lib/chimeway/traces/explanation.ex`, `lib/chimeway/admin.ex`, and `chimeway_admin/lib/chimeway_admin/redaction.ex`.
- Proof and release evidence contracts in `test/chimeway/release_gate_contract_test.exs` and existing privacy fixtures.

</code_context>

<specifics>
## Specific Ideas

- One shared safe-evidence vocabulary should be recognizable across trace, attempt, telemetry, DTO, and proof output rather than translated through unrelated per-surface filters.
- Safe behavior should be automatic at shared write/projection boundaries so adopters cannot accidentally select an unsafe path.
- Fingerprints and opaque references are correlation evidence, not a substitute channel for retaining identity or endpoint data.

</specifics>

<deferred>
## Deferred Ideas

None — analysis stayed within Phase 98 scope.

</deferred>

---

*Phase: 98-privacy-safe-delivery-evidence*
*Context gathered: 2026-08-12*
