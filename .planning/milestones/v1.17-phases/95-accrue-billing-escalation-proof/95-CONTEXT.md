# Phase 95: Accrue Billing-Escalation Proof - Context

**Gathered:** 2026-08-09 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Extend the Phase 93 unpacked-artifact clean consumer with an Accrue billing-escalation proof. The proof must begin escalation at Accrue's natural payment-failure boundary, progress or terminate through a payment outcome signal without directly invoking a Chimeway notifier, and expose sanitized public workflow evidence. It must accurately distinguish released-package adopter proof from immutable pinned-ref compatibility evidence. New Chimeway runtime behavior, live payment-provider integration, a new CI lane, and the Phase 96 adoption selector remain out of scope.
</domain>

<decisions>
## Implementation Decisions

### Natural Accrue Lifecycle Boundary
- **D-01:** Start the proof through Accrue's `invoice.payment_failed` event and end the waiting dunning workflow through its `invoice.paid` outcome event; do not call a bundled Chimeway notifier directly to simulate either boundary.
- **D-02:** Prove the actual Accrue-to-Chimeway integration workflow: payment failure starts the campaign and payment success routes the outcome signal that progresses or terminates it.

### Clean Consumer Topology
- **D-03:** Extend `ArtifactConsumerFixture` with a separately callable Accrue proof, preserving the Phase 93 artifact-only `:chimeway` dependency, isolated temporary host/database, provenance validation, and cleanup discipline.
- **D-04:** Do not use DemoHost, the source-tree checkout, or a repository-maintainer `verify.*` lane as the adopter proof; they may be regression analogs but cannot establish packaged-consumer provenance.

### Public Workflow Evidence
- **D-05:** Emit one strict, machine-parseable `CHIMEWAY_ACCRUE_PROOF` record derived exclusively from public workflow/trace APIs. It must prove both waiting progression and the `invoice.paid` / outcome-signal result.
- **D-06:** Allowlist only stable workflow/notification identity, non-sensitive lifecycle state/reason, and ordered timeline facts necessary to establish progression and outcome. Reject duplicate or unknown keys; exclude billing identifiers, recipient data, payloads, metadata blobs, credentials, raw structs, and direct database inspection from public proof output.

### Release Provenance and Guidance
- **D-07:** Treat the proof as an independent released-package adopter proof only when its resolved Accrue Hex release contains the Chimeway integration; identify the exact released Chimeway and Accrue package versions in that case.
- **D-08:** If released-package availability cannot be established, identify the immutable integration ref/SHA and label the result solely as compatibility evidence, never as released-package installation guidance.
- **D-09:** Prefer the current verified Accrue `1.3.0` released-package path when the generated proof validates that release contains the integration; otherwise fall back to the CI-pinned `236fa2f1649e771f3b515603495436badeed3c7b` compatibility label.

### the agent's Discretion
- Exact generated module names, safe output field spelling/order, fixture values, command wiring, and focused contract-test placement, provided the lifecycle, provenance, public-evidence, and truthful-labeling decisions above remain intact.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Scope and proof posture
- `.planning/ROADMAP.md` — Phase 95 goal, requirements, success criteria, and Phase 93 dependency.
- `.planning/REQUIREMENTS.md` — ACCR-01 and ACCR-02 acceptance requirements.
- `.planning/PROJECT.md` and `.planning/METHODOLOGY.md` — local-first explainability and decisive, least-surprise planning lenses.
- `.planning/phases/93-hermetic-artifact-harness-core-trace-proof/93-CONTEXT.md` — locked unpacked-artifact and public-evidence constraints.
- `.planning/phases/94-mailglass-transactional-email-proof/94-CONTEXT.md` — second-proof extension, evidence allowlist, and truthful-proof-language precedent.

### Accrue integration and lifecycle
- `guides/introduction/accrue-dunning-integration.md` — canonical Accrue event-boundary adoption flow.
- `deps/accrue/lib/accrue/integrations/chimeway.ex` — integration behavior for payment failure and payment outcome.
- `test/chimeway/integrations/accrue_dunning_lifecycle_test.exs` — established event-driven lifecycle proof.
- `test/test_helper.exs` — Accrue integration compilation and test-environment constraints.

### Consumer harness, evidence, and provenance
- `test/support/artifact_consumer_fixture.ex` — temporary packaged-consumer/provenance/cleanup seam to extend.
- `test/chimeway/release_gate_contract_test.exs` — strict public proof record and release-gate contract patterns.
- `lib/chimeway/traces.ex` and `lib/chimeway/traces/explanation.ex` — public sanitized trace evidence contract.
- `mix.lock`, `deps/accrue/hex_metadata.config`, `MAINTAINING.md`, and `.github/workflows/ci.yml` — resolved release and immutable compatibility provenance anchors.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `test/support/artifact_consumer_fixture.ex` owns package construction/unpacking, generated temporary consumer execution, database isolation, provenance validation, and cleanup; Accrue is a new callable capability of that harness.
- `Chimeway.Traces.explain_delivery/1` and its explanation shape are the sanitized public evidence seam.
- Accrue's existing lifecycle integration test demonstrates event entry through `Accrue.Test.trigger_event/2` rather than direct notifier calls.

### Established Patterns
- Packaged-consumer proofs are isolated, serialized where resources require it, and protected through ExUnit release/doc contracts rather than parallel shell truth checkers.
- Stable strings rather than module names are durable identities; public evidence is strict, allowlisted, ordered, and excludes sensitive data.
- Released-package claims require release-specific proof; pinned references are compatibility evidence and must not be presented as install guidance.

### Integration Points
- The generated consumer must compose the unpacked Chimeway artifact with the resolved Accrue integration and its normal event/outcome boundary.
- The proof record, canonical Accrue guide, and release/doc contract tests must agree on lifecycle claims and provenance terminology.
</code_context>

<specifics>
## Specific Ideas

- The proof should make one clear adopter story visible: billing failure begins escalation; payment success signals the workflow; Chimeway's public trace explains the resulting state.
- Favor the Phase 94 strict-record pattern, adapted for workflow progression rather than a delivery-only outcome.
- Package/release wording must be conditional and auditable rather than optimistic: released-package proof only with verified release content; otherwise exact-ref compatibility evidence.
</specifics>

<deferred>
## Deferred Ideas

- Live provider/webhook payment acceptance, credentials, retries, and production billing data — host/provider responsibility outside this deterministic proof.
- New Chimeway runtime lifecycle semantics, notifier APIs, or adapter behavior — outside the proof/documentation scope.
- `verify.adoption_paths`, a dedicated adoption CI lane, and cross-path drift enforcement — Phase 96.
</deferred>

---

*Phase: 95-accrue-billing-escalation-proof*
*Context gathered: 2026-08-09*
