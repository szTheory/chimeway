# Phase 102: Alpha Digital Twin & Hermetic Gate - Context

**Gathered:** 2026-08-25 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver a credential-free, deterministic cross-repository proof of the complete sanitized Adopter Alpha host → Chimeway → CrossWake mobile notification path. The proof must run real Chimeway persistence, exercise the safety-critical scenario matrix, expose named `mix verify.*` entrypoints, become a required CI gate, and validate the shape of future physical-iPhone evidence. A real APNs/iPhone run and adopter/operator documentation remain Phase 103.

</domain>

<decisions>
## Implementation Decisions

### Clean-Room Alpha Host and Repository Boundaries

- **D-01:** Build one dedicated, committed, sanitized Adopter Alpha test host/fixture for this phase. Do not retrofit the general Chimeway demo host or the existing CrossWake example host into the Alpha twin.
- **D-02:** The host must consume Chimeway from one immutable built package artifact, apply the real copied Chimeway migrations to PostgreSQL, and exercise the public trigger, planning, dispatch, recovery, trace, and explanation paths. A unit-only harness or proof that substitutes direct Chimeway lifecycle-row inserts is insufficient.
- **D-03:** The host must consume the real `crosswake` and `crosswake_chimeway` public contracts from a sibling checkout pinned to a full immutable commit SHA. CrossWake remains authoritative for manifest normalization, notification-open resolution, RouteGate evaluation, and its existing physical-iPhone evidence contract.
- **D-04:** Keep token material, binding lifecycle authority, eligibility, and one-time open intents in explicit host-owned fixture components. Chimeway and CrossWake may receive only the already-locked opaque references, fingerprints, classifications, and closed safe facts.

### Deterministic Scenario Ledger and Evidence

- **D-05:** Define one closed, versioned scenario ledger as the source of truth for the twin. Host, Chimeway, scripted APNs transport, and CrossWake proof consumers must execute or validate the same ordered scenario identities rather than maintain disconnected happy-path fixtures.
- **D-06:** Add the narrowest injectable clock seam needed along the exercised Chimeway target/APNs/recovery and host/CrossWake open-resolution boundaries. Production defaults remain the system clock; the twin advances a fixed clock explicitly and must not use wall-clock sleeps for expiry, retry, lease, or replay assertions.
- **D-07:** Use a scripted fake APNs transport behind the shipped transport behaviour. It must observe the real bounded request and return ordered accepted, retryable, permanent, exact-invalidation, and ambiguous-handoff outcomes without Pigeon network I/O, Apple credentials, or a provider emulator.
- **D-08:** The mandatory matrix is exact and merge-blocking: two-installation fan-out; zero-target suppression; token rotation and revocation races; reason-classified retry; expiry; opt-in, installation-safe collapse; trigger-commit recovery; post-handoff crash ambiguity; recursive leak prevention; offline open queue/reauthorization; denial; and replay rejection.
- **D-09:** Each scenario must assert durable lifecycle truth through real repository and public explanation surfaces, not only returned function values. The proof must demonstrate convergence/uniqueness and preserve the distinction between local intent, provider acceptance, invalidation, protected open, inbox seen, and inbox read.
- **D-10:** Emit one closed, allowlisted, machine-readable proof summary only after scanning persisted safe facts, traces, telemetry captures, exception/error output, transport observations, and final proof bytes for recursive leak sentinels. Unknown fields and uncontrolled diagnostic maps fail closed; raw tokens, identity, URLs, payloads, credentials, and provider bodies never appear in proof output.

### Verification Gates and Physical-Proof Contract

- **D-11:** Chimeway owns two named entrypoints: `mix verify.alpha_twin` for the hermetic production-path scenario and `mix verify.physical_proof_contract` for malformed/valid future evidence fixtures. Both commands must be deterministic, credential-free, non-interactive, and independently rerunnable.
- **D-12:** Add a dedicated `verify_alpha_twin` CI job that checks out CrossWake at the locked full SHA, runs both entrypoints, and is required by both `pr-gate` and `ci-gate`. Extend `mix ci.verify_gates` contract tests so local aliases, checkout provenance, commands, job result aggregation, and required-gate membership cannot drift.
- **D-13:** Proof output must record or cryptographically bind the exact Chimeway artifact digest and CrossWake implementation SHA used by the run. A floating branch, mutable tag, unvalidated local tree, or evidence from mismatched revisions cannot satisfy the gate.
- **D-14:** Define a versioned Chimeway mobile-proof extension for Phase 103 that references the canonical CrossWake Phase 162 evidence rather than copying or reinterpreting it. The extension must separate executable facts (permission state, authenticated registration, APNs provider acceptance, one-time protected activation, replay denial) from the explicitly subjective visible-alert observation.
- **D-15:** Physical-proof contract validation must reject missing, duplicate, reordered, unknown, wrong-owner, wrong-proof-class, sensitive, malformed, or revision-mismatched evidence. CI validates schemas and negative fixtures only; it never requires Apple credentials or claims that a physical display was observed.

### the agent's Discretion

- Exact module, fixture-directory, scenario-ledger, and proof-summary names beyond the two locked Mix task names.
- Exact internal clock behaviour/configuration shape, provided injection is narrow, production defaults are unchanged, and every time-sensitive twin assertion is sleep-free.
- Exact JSON or line-oriented encoding for the scenario ledger and proof summary, provided schemas are closed, versioned, bounded, deterministic, non-echoing, and atom-safe.
- Exact CI caching and job-internal decomposition, provided the immutable CrossWake provenance and required-gate parity are executable contracts.
- Exact stable rule IDs for malformed evidence, provided failures identify only a closed rule/path and never echo rejected sensitive values.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Active milestone contract

- `.planning/ROADMAP.md` — Phase 102 goal, fixed boundary, dependencies, and three success criteria.
- `.planning/REQUIREMENTS.md` — Binding TWIN-01, TWIN-02, and GATE-01 acceptance requirements; TWIN-03 and DOCS-01 Phase 103 boundary.
- `.planning/PROJECT.md` — v1.18 ownership split, local-first posture, durable explainability, privacy boundary, and twin-before-device proof rule.
- `.planning/METHODOLOGY.md` — cohesive, research-first, durable-explainability, least-surprise, and low-escalation decision lenses.

### Locked v1.18 decisions

- `.planning/phases/97-tenant-identity-compatible-upgrade/97-CONTEXT.md` — immutable tenant identity, explicit tenant predicates, non-disclosure, and static storage decisions.
- `.planning/phases/98-privacy-safe-delivery-evidence/98-CONTEXT.md` — recursive safe-evidence boundary and prohibition on raw tokens, credentials, identities, links, payloads, and provider bodies.
- `.planning/phases/99-multi-installation-delivery-recovery/99-CONTEXT.md` — one logical delivery, durable target fan-out, recovery convergence, attempt-start evidence, and ambiguous handoff semantics.
- `.planning/phases/100-optional-apns-adapter/100-CONTEXT.md` — optional adapter, host token custody, bounded APNs intent, reason classification, exact invalidation, expiry, collapse, and provider-acceptance vocabulary.
- `.planning/phases/101-crosswake-registration-protected-open/101-CONTEXT.md` — authenticated binding authority, normalized manifest policy, offline queue, one-time consumption, current RouteGate evaluation, and sanitized denial vocabulary.

### Existing Chimeway proof and runtime seams

- `lib/mix/tasks/verify.adoption_paths.ex` — named Mix verification task pattern and clean proof runner entrypoint.
- `scripts/prove-adoption-paths.exs` — immutable artifact build/digest validation, clean-consumer orchestration, and closed single-line evidence pattern.
- `priv/adoption_proof/artifact_archive.ex` — bounded immutable archive validation reusable for the Chimeway package input.
- `test/fixtures/apns_consumer/` — existing clean consumer fixture for optional APNs integration and exact host CAS behavior.
- `test/support/apns_fake_transport.ex` — existing scripted transport behaviour seam to evolve into the deterministic scenario transport.
- `lib/chimeway/delivery_targets.ex` — durable target planning, claim, attempt, retry, expiry, invalidation, and aggregation spine.
- `lib/chimeway/target_recovery.ex` — bounded tenant-scoped stranded-event, stale-attempt, and pending-target recovery.
- `lib/chimeway/safe_evidence.ex` — recursive privacy enforcement and closed safe-fact vocabulary.
- `test/chimeway/release_gate_contract_test.exs` — local alias, CI job, aggregate-gate, and release parity contract pattern.
- `.github/workflows/ci.yml` — current dedicated `verify.*` job and `pr-gate`/`ci-gate` topology.

### Governing CrossWake contracts

- `../crosswake/AGENTS.md` — CrossWake privacy, fail-closed, offline-scope, and automated-evidence rules.
- `../crosswake/.planning/ADR-FIRST-B2C-ADOPTER.md` — governing adopter boundary and iOS-only/non-generic scope.
- `../crosswake/.planning/ROADMAP.md` — Phase 162 physical-iPhone boundary and Phase 163 reference-host prerequisites.
- `../crosswake/.planning/STATE.md` — current external Apple-signing blocker and canonical physical-proof ownership.
- `../crosswake/packages/crosswake_chimeway/lib/crosswake/companions/chimeway/contracts.ex` — opaque token, binding, provider-feedback, notification-open, and resolution data contracts.
- `../crosswake/packages/crosswake_chimeway/lib/crosswake/companions/chimeway/resolver.ex` — current manifest/action and RouteGate reauthorization sequence.
- `../crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/registry.ex` — existing host-owned binding and one-time-intent authority patterns.
- `../crosswake/lib/crosswake/proof_lane/physical_iphone_contract.ex` — canonical closed physical assertion ownership and report-shape validator.
- `../crosswake/lib/crosswake/proof_lane/evidence.ex` — privacy-safe, allowlisted, versioned physical evidence and promotion boundary.
- `../crosswake/script/verify_physical_iphone_report_contract.sh` — current serialization-only credential-free physical report contract gate.

### Milestone research

- `.planning/research/ARCHITECTURE.md` — host/Chimeway/CrossWake boundaries and required twin scenario set.
- `.planning/research/STACK.md` — explicit fake transport, ExUnit proof posture, and physical-proof separation.
- `.planning/research/FEATURES.md` — hermetic APNs twin differentiator and delivery-claim taxonomy.
- `.planning/research/SUMMARY.md` — recommended twin-before-device sequence and principal safety risks.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `Chimeway.AdoptionProofRunner` and `Chimeway.AdoptionProof.ArtifactArchive`: build one immutable Chimeway artifact, validate its digest, materialize it safely, and run clean consumers against exactly those bytes.
- `test/fixtures/apns_consumer`: provides the established isolated Mix-project pattern for optional APNs dependencies, host binding lookup/CAS, and real public adapter calls.
- `Chimeway.Test.APNSFakeTransport`: already sits behind the public transport behaviour and can become an ordered scripted transport without provider I/O.
- `Chimeway.DeliveryTargets`, `Chimeway.TargetRecovery`, and `Chimeway.Traces`: expose the real durable lifecycle and explanation surfaces the twin must assert.
- CrossWake companion contracts/resolver and example-host registry: provide the public protected-open and host-authority seams; the twin should consume them, not clone their policy logic.
- CrossWake `PhysicalIphoneContract` and `Evidence`: provide canonical closed report ownership and privacy validation that the Chimeway extension must reference.

### Established Patterns

- Verification paths use named `mix verify.*` commands, dedicated credential-free CI jobs, and release-gate contract tests that assert local/CI parity.
- Cross-repository consumers use explicit sibling paths in development/CI and immutable checkout provenance in required lanes.
- Provider acceptance is only handoff evidence; protected open and inbox lifecycle facts remain separate.
- Safe proof artifacts are closed allowlists with bounded values and negative fixtures, never generic serialized diagnostics.
- Host-owned registries retain raw-token and authorization authority; Chimeway persists only opaque selected revisions and CrossWake treats client evidence as non-authoritative.

### Integration Points

- Add the Alpha fixture beside existing clean consumers and invoke it through new Mix verification tasks.
- Route fake transport outcomes through `Chimeway.APNS.Transport` and public `Chimeway.Adapters.APNS` execution.
- Assert durable scenario results through Chimeway Repo schemas and trace/explanation projections after each ordered step.
- Feed opaque open evidence into the real CrossWake `IntentConsumer`/`Resolver`/RouteGate path using current compiled manifest policy.
- Extend `mix.exs`, `.github/workflows/ci.yml`, and `test/chimeway/release_gate_contract_test.exs` together so task, job, and aggregate-gate truth cannot diverge.

</code_context>

<specifics>
## Specific Ideas

- Treat the twin as one reproducible production-path narrative rather than a bundle of unrelated unit tests: host selects two bindings, Chimeway records independent target truth, scripted APNs outcomes mutate only exact revisions, and CrossWake authorizes one opaque open at most once.
- Make scenario time explicit in evidence so expiry, retry, lease, and replay boundaries are understandable without exposing host identity or wall-clock nondeterminism.
- Preserve one honest claim taxonomy throughout the final summary: local dispatch intent, APNs provider acceptance/rejection, exact binding invalidation, protected open, inbox seen, and inbox read are distinct facts.
- The physical-proof validator should be executable now with fixtures even though the real Apple-signing/device run remains externally blocked.

</specifics>

<deferred>
## Deferred Ideas

- Real APNs sandbox dispatch, physical-iPhone visible-alert confirmation, and retained dated device evidence — Phase 103 after the CrossWake Phase 162 Apple signing/provisioning gate is satisfied.
- Integration and operator documentation covering setup, migrations, outcome vocabulary, offline behavior, proof commands, and non-goals — Phase 103 (DOCS-01).
- FCM/Android transport, generic background/offline sync, engagement analytics, rich actions, and broad device management remain outside v1.18 scope.

</deferred>

---

*Phase: 102-alpha-digital-twin-hermetic-gate*
*Context gathered: 2026-08-25*
