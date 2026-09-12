# Phase 104: CrossWake Provider-Feedback Recipe Truth - Context

**Gathered:** 2026-09-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Close the adopter-facing CrossWake provider-feedback documentation seam on a separately selected documentation revision. The phase makes the worker recipe source-valid and executable, proves exact authenticated authority and denial behavior, and adds a Chimeway-side fresh-checkout contract without changing the immutable v1.18 physical-proof branch or SHA.

</domain>

<decisions>
## Implementation Decisions

### Recipe contract
- D-01: Normalize provider attributes only through `Crosswake.Companions.Chimeway.Redaction.feedback_from_provider_attrs/1`; the contract struct is not a constructor API.
- D-02: The worker must use a host-owned resolver that returns a keyword list containing `:authenticated_context`, `:binding_ref`, `:installation_ref`, `:app_identity_ref`, and current `:session_ref` plus `:session_version` when the binding is session-scoped.
- D-03: Provider token references and fingerprints are corroborating evidence only and never authenticate or broaden invalidation authority.
- D-04: Preserve the registry result instead of unconditionally returning `:ok`, so durable job retry/discard policy can act on explicit outcomes.

### Executable evidence
- D-05: Exercise the README's real public conversion and registry boundaries from an example-host test rather than accepting a string-only or compile-only sample.
- D-06: Cover advisory acceptance, exact invalidation, stale or mismatched authority denial, and recursive evidence sanitization with behavior assertions.
- D-07: The documentation contract must reject the known nonexistent constructor and incomplete option scope, and must detect vacuous examples that never execute the registry path.
- D-08: Keep test data synthetic and assert that raw recipient identity, raw tokens, and provider payload content do not escape through evidence.

### Revision selection and immutability
- D-09: Select the CrossWake documentation revision independently from the existing physical-proof selection; never repurpose or overwrite the v1.18 selection file.
- D-10: Verify the documentation revision from a clean remote checkout at an exact SHA, while separately asserting that `resume/chimeway-notification-physical-proof` still resolves to `3165ab6938fa673f8a289c27699658bb78650ef3`.
- D-11: Build the documentation revision from CrossWake's proof-backed Phase 101/103 lineage where the authenticated provider-feedback runtime exists, not from the older physical-proof-only branch.
- D-12: Publish only a new documentation branch if the fresh-remote contract requires reachability; do not move, force-update, or merge into the physical-proof branch.

### the agent's Discretion
- Exact test-module naming, fixture layout, and whether the Chimeway verifier is a focused Mix task or a release-gate contract are implementation details, provided the named aggregate gate remains deterministic and Phoenix stays optional for Chimeway core.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- CrossWake's `CrosswakeExample.Chimeway.Registry.apply_provider_feedback/2` on `origin/phase-103-chimeway-notification-proof` already enforces exact authenticated binding, installation, application, and session authority.
- CrossWake's `Crosswake.Companions.Chimeway.Redaction.feedback_from_provider_attrs/1` and `CrosswakeExample.Chimeway.MetadataSanitizer` are the real conversion and recursive sanitization boundaries.
- `test/crosswake/proof/phase60_chimeway_registry_test.exs` already contains database-backed provider-feedback and sanitization proof patterns suitable for focused extension.
- Chimeway already has physical-proof verification tasks, selected-ref fixtures, release-gate contract tests, and a CI fresh-checkout lane that can be mirrored without sharing authority.

### Established Patterns
- External evidence is SHA-pinned, source-bound, and verified in a clean checkout before support claims are accepted.
- Exact-scope security failures fail closed as indistinguishable `:no_active_bindings` outcomes.
- Documentation/release-gate acceptance uses executable `mix verify.*` and `mix ci.*` entrypoints rather than conversational UAT.
- Sensitive content is validated by allowlists and negative assertions, not by logging or snapshotting live payloads.

### Integration Points
- CrossWake: `examples/phoenix_host/README.md`, registry proof tests, and the Phase 101/103 notification companion lineage.
- Chimeway: `mix.exs` aliases, `.github/workflows/ci.yml`, focused Mix verifier tasks, doc/release-gate contract tests, and immutable physical-proof selection under `priv/physical_proof`.

</code_context>

<specifics>
## Specific Ideas

Use a new CrossWake documentation branch rooted in the proof-backed notification branch and pin its exact commit separately in Chimeway. The Chimeway contract should fetch that branch into a temporary clean checkout, run the focused CrossWake proof, and compare the physical-proof remote head to its frozen SHA before declaring success.

</specifics>

<deferred>
## Deferred Ideas

- Inbox publishing and LiveView refresh belong to Phase 105.
- Seen-driven workflow progression belongs to Phase 106.
- Operator timeline and aggregate inbox documentation/gates belong to Phase 107.
- Android/FCM and generic offline synchronization remain outside v1.19.

</deferred>
