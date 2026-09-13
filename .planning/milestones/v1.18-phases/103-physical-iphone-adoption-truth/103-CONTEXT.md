# Phase 103: Physical iPhone & Adoption Truth - Context

**Gathered:** 2026-08-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Produce bounded, dated, redacted evidence that the Adopter Alpha production path reached one real iPhone through APNs sandbox and completed one protected activation, then give host integrators and operators one accurate adoption guide for setup, ownership, compatible upgrade, outcome interpretation, offline-open behavior, proof commands, troubleshooting, and non-goals. This phase may build and release deterministic schemas, validators, preflight, fixtures, and guidance before Apple credentials are available, but it may not promote physical support or complete TWIN-03 until the real signed-device evidence and narrow subjective alert observation exist.

</domain>

<decisions>
## Implementation Decisions

### Versioned Cross-Repository Physical Proof

- **D-01:** Keep `Chimeway.MobileProof.Extension` v1 as the immutable hermetic contract. Add a distinct versioned physical proof class/envelope for Phase 103; do not reinterpret or mutate the existing `proof_class: "hermetic"` fixture into physical evidence. — **Reversibility:** one-way — retained evidence and downstream validators must continue to understand the exact schema version and proof class that produced it.
- **D-02:** Model the promoted result as one dated proof bundle with independently typed records: a Chimeway machine-evidence envelope, a CrossWake-owned physical notification record, a separate visible-alert human attestation, and a digest-bound completion marker. The bundle is one proof record for TWIN-03, but its component claims remain visibly separate.
- **D-03:** The Chimeway envelope binds the exact immutable Chimeway package artifact digest, the CrossWake remote and compatible full commit SHA, the CrossWake contract version, the canonical CrossWake evidence digest, the CrossWake completion-marker digest, a fresh opaque run reference, and only closed Chimeway-owned delivery/attempt/trace facts.
- **D-04:** Chimeway must not copy or reinterpret the canonical CrossWake report. Verification must check out or otherwise resolve the declared immutable CrossWake revision, hash the canonical evidence bytes, and delegate semantic validation to a CrossWake-owned source-bound verifier. A CI URL, workflow result, Git tag, Hex release, or generic artifact attestation may supplement provenance but cannot replace behavioral evidence.
- **D-05:** Add an explicit CrossWake-owned notification physical-proof extension with fixed, ordered, owner-qualified facts for native permission observation, authenticated registration authority, and one-time protected activation. Chimeway may assert its own durable APNs provider-acceptance and explanation facts but may never manufacture device-local or protected-open authority. — **Reversibility:** costly — both repositories, retained proof fixtures, validators, and support truth consume this cross-repository ownership split.
- **D-06:** Resolve the known CrossWake revision mismatch explicitly during research/planning. The Alpha fixture's existing pin must not be silently reused if it does not match the canonical Phase 162 evidence and source-bound verifier revision selected for the physical run.
- **D-07:** Validation is fail-closed and non-echoing: exact keys, closed enums, stable ordering, full digests/SHAs, expected owners, artifact/evidence revision agreement, no replacement, and a recursive privacy scan. Failures expose only stable rule IDs and bounded paths; unknown, partial, duplicate, reordered, mismatched, or sensitive evidence cannot promote.
- **D-08:** Retained Chimeway evidence must not contain raw tokens, payloads, provider bodies, credentials, adopter/account identity, device identifiers, endpoint values, deep links, screenshots, video, raw logs, local filesystem paths, or uncontrolled diagnostic maps.

### Subjective Visible-Alert Attestation

- **D-09:** Record visible presentation in a separate closed `visible_alert_attestation` record linked by digest and opaque run reference to the machine-evidence envelope. Do not place the observation in the executable-facts map and do not retain screenshot/video evidence.
- **D-10:** Retain only the attestation schema/version, opaque run reference, machine-envelope digest, UTC observation time, an opaque host-resolvable attester reference, and one state: `observed`, `not_observed`, or `unavailable`.
- **D-11:** Only `observed` satisfies the subjective portion of TWIN-03. `not_observed` is a failed physical run; `unavailable` is an honest blocked/non-promotable run. Automation validates structure, binding, privacy, and state semantics but can never create or infer `observed`.
- **D-12:** Every retry creates new append-only run and attestation evidence. Never overwrite or upgrade a prior failed, unavailable, or successful record in place.
- **D-13:** Human-facing copy asks: "Did the expected Chimeway alert appear on the selected iPhone?" Options are "Observed", "Did not appear", and "Cannot verify". The adjacent explanation states that the observation confirms visible presentation only and does not establish APNs acceptance, protected activation, inbox state, or engagement.

### Canonical Mobile Adoption and Operations Guide

- **D-14:** Create one canonical ExDoc extra, `guides/introduction/mobile-adoption-operations.md`, and link it from README documentation/navigation and `guides/introduction/adoption-paths.md`. Keep one authority for Phase 103 guidance rather than expanding Golden Path into a mobile runbook or maintaining separate duplicative host/operator guides.
- **D-15:** Organize the guide for four jobs: host integrator, operator/on-call, security reviewer, and maintainer. Use a short readiness/role entry, then stable sections for ownership, install and compatible upgrade, tenant/APNs/host wiring, outcome vocabulary, offline protected opens, proof ladder, troubleshooting/operator actions, and explicit non-goals.
- **D-16:** Cross-link existing Golden Path, installation, storage-prefix upgrade, Oban, tracing, adapter, and adoption-proof material instead of copying detailed procedures. Examples and commands remain executable or contract-checked where objectively machine-testable.
- **D-17:** Use the current `brandbook/index.html` as the voice authority, superseding older prompt brand material: calm, precise, developer-to-developer, literal about limits, and structured as what happened -> why it matters -> how to fix. Prefer stable domain nouns such as installation, binding revision, target, attempt, provider acceptance, protected open, and trace.
- **D-18:** Documentation must state throughout that APNs acceptance is provider handoff only. It does not prove device receipt or display, protected activation, inbox seen/read, or engagement. The visible-alert attestation and protected-open evidence are separate facts.

### Two-Threshold Promotion

- **D-19:** Threshold A is `release_ready_physical_pending`: credential-free schemas, validators, fixtures, preflight, negative corpus, release-gate parity, and the adoption guide may merge and ship when `mix ci.verify_gates`, `mix verify.alpha_twin`, and `mix verify.physical_proof_contract` are green. Public surfaces must still say physical evidence is pending; TWIN-03 and Phase 103 remain incomplete.
- **D-20:** Git/Hex/package publication at Threshold A establishes package provenance only. It must not change physical-device support truth or be cited as APNs receipt, display, or protected-open evidence.
- **D-21:** Threshold B is `physical_support_promoted`: first resolve CrossWake Phase 162's canonical source-bound verification/final-reconciliation gap; then run the signed sandbox proof against the immutable Chimeway artifact and pinned CrossWake revision; validate all machine facts; capture `observed`; and atomically publish a dated no-replace proof bundle.
- **D-22:** Update the retained evidence, support wording, requirements, roadmap, and release/adoption truth together only after Threshold B passes. A partial or blocked run changes none of those claims.
- **D-23:** Apple account access, signing/provisioning, the selected physical phone, and the visible-alert observation are legitimate external/subjective gates. Every other tracer and acceptance claim remains type `auto` with executable evidence; neither credentials nor subjective observation belongs in CI.

### the agent's Discretion

- Exact Elixir module, struct, task, rule-ID, bundle-directory, and fixture names, provided the proof classes, ownership, privacy, append-only behavior, and two promotion thresholds remain explicit and stable.
- Exact internal JSON field names and completion-marker encoding, provided the schemas are closed, versioned, deterministic, atom-safe, digest-linked, and independently validate machine evidence and human observation.
- Exact CrossWake integration mechanism, provided CrossWake remains semantic authority for its evidence and validation is source-bound to the declared immutable revision.
- Exact prose layout, tables, admonitions, and cross-links inside the canonical guide, provided every DOCS-01 topic and the four persona/JTBD entry points remain easy to find and doc contracts prevent command/vocabulary drift.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Active Chimeway milestone contract

- `.planning/ROADMAP.md` — Phase 103 goal, dependency, three success criteria, external signing blocker, ownership split, and proof rule.
- `.planning/REQUIREMENTS.md` — Binding TWIN-03 and DOCS-01 requirements plus explicit mobile-delivery non-goals.
- `.planning/PROJECT.md` — v1.18 local-first goal, current state, package/milestone distinction, durable explainability, and proof-before-promotion posture.
- `.planning/STATE.md` — Current Phase 103 position, accumulated v1.18 ownership decisions, physical-proof blocker, and Phase 102 evidence constraints.
- `.planning/METHODOLOGY.md` — Research-first, durable-explainability, least-surprise, low-escalation, and cohesive-decision lenses.

### Locked Chimeway mobile decisions

- `.planning/phases/97-tenant-identity-compatible-upgrade/97-CONTEXT.md` — Explicit tenant authority, compatible upgrade, non-guessing reconciliation, and static storage decisions.
- `.planning/phases/98-privacy-safe-delivery-evidence/98-CONTEXT.md` — Recursive privacy boundary and closed safe-evidence vocabulary.
- `.planning/phases/99-multi-installation-delivery-recovery/99-CONTEXT.md` — Target fan-out, provider-handoff vocabulary, recovery convergence, and ambiguous-handoff semantics.
- `.planning/phases/100-optional-apns-adapter/100-CONTEXT.md` — APNs request/result, retry, invalidation, expiry, collapse, and host token-custody contracts.
- `.planning/phases/101-crosswake-registration-protected-open/101-CONTEXT.md` — Permission/registration ownership, offline queue, one-time consumption, and fail-closed protected activation.
- `.planning/phases/102-alpha-digital-twin-hermetic-gate/102-CONTEXT.md` — Immutable twin provenance, physical-proof extension contract, required verification entrypoints, and machine-versus-subjective evidence split.

### Existing Chimeway proof, gate, and documentation surfaces

- `lib/chimeway/mobile_proof/extension.ex` — Existing closed hermetic v1 extension, fixed CrossWake pin, copied report input, exact-key validation, and `visible_alert: not_asserted` baseline that Phase 103 must version rather than mutate.
- `lib/mix/tasks/verify.physical_proof_contract.ex` — Credential-free package-digest and fixture-corpus validator entrypoint.
- `test/chimeway/mobile_proof_extension_test.exs` — Existing non-echoing digest, subjective-honesty, and delegated-order tests.
- `test/fixtures/alpha_twin_physical_proof/valid.json` — Current hermetic fixture and exact CrossWake contract/report shape.
- `test/fixtures/alpha_twin_physical_proof/negative-corpus.json` — Current malformed-proof corpus pattern.
- `mix.exs` — `ci.alpha_twin`, `ci.verify_gates`, ExDoc extras, and documentation-group integration points.
- `test/chimeway/release_gate_contract_test.exs` — Local/CI alias and aggregate-gate parity contract.
- `.github/workflows/ci.yml` — Credential-free Alpha verification job and required aggregate-gate wiring.
- `guides/introduction/adoption-paths.md` — Existing role/choice-oriented proof selector and explicit "does not cover" pattern.
- `guides/introduction/golden-path.md` — General installation-to-trace journey that mobile guidance should cross-link rather than overload.
- `guides/introduction/storage-prefix-upgrade.md` — Existing compatible storage migration detail.
- `MAINTAINING.md` — Maintainer verification and release-truth entrypoint.

### Canonical CrossWake physical proof

- `../crosswake/AGENTS.md` — CrossWake privacy, fail-closed, physical-promotion, and machine-evidence working rules.
- `../crosswake/.planning/ROADMAP.md` — Phase 162 execution/promotion sequence and remaining final support/reconciliation work.
- `../crosswake/.planning/REQUIREMENTS.md` — DEVICE acceptance requirements and physical-only support boundary.
- `../crosswake/.planning/STATE.md` — Current external signing status, canonical proof authority, and remaining promotion truth.
- `../crosswake/.planning/phases/162-physical-iphone-adoption-proof/162-CONTEXT.md` — Sequential host-owned physical proof, preflight, privacy, evidence, recovery, and support-promotion decisions.
- `../crosswake/.planning/phases/162-physical-iphone-adoption-proof/162-VERIFICATION.md` — Verified implementation seams and unresolved absence of a dated physical artifact.
- `../crosswake/lib/crosswake/proof_lane/physical_iphone_contract.ex` — Closed ordered physical assertion vocabulary and owner validation.
- `../crosswake/lib/crosswake/proof_lane/physical_iphone_preflight.ex` — Ordered fail-closed readiness checks for real device execution.
- `../crosswake/lib/crosswake/proof_lane/evidence.ex` — Canonical source-bound evidence validation, privacy scan, atomic promotion, and completion-marker rules.
- `../crosswake/guides/support_matrix.md` — Current verification-required versus physically promoted support vocabulary.

### Project research and voice

- `prompts/chimeway-engineering-dna-from-prior-libs.md` — OSS packaging, durable identity, explicit contracts, release gates, and prior-library lessons.
- `prompts/chimeway-host-app-integration-seam.md` — Host/Chimeway ownership, tenant/auth/URL boundaries, upgrade behavior, and executable seam proof.
- `prompts/chimeway-release-engineering-and-ci.md` — Local/CI parity and release-proof conventions.
- `prompts/chimeway-testing-and-e2e-strategy.md` — Shift-left machine evidence, named entrypoints, fake-provider gates, and doc-contract patterns.
- `prompts/chimeway-admin-ui-and-operator-ia.md` — Operator JTBD and explainability-first information architecture.
- `prompts/elixir_notifykit_research_brief.md` — Ecosystem precedents, adopter/operator personas, domain language, provider footguns, docs strategy, and DX goals.
- `brandbook/index.html` — Current brand, voice, operational microcopy, vocabulary, theme, and accessibility authority; supersedes older prompt brand-book material.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `Chimeway.MobileProof.Extension`: closed exact-key validation, non-echoing rule/path errors, bounded atom conversion, recursive sensitive-value rejection, and delegated CrossWake validation patterns.
- `Mix.Tasks.Verify.PhysicalProofContract`: immutable package build/digest binding, safe archive validation, fixture-corpus execution, and a named credential-free verifier.
- Alpha physical-proof fixtures/tests: version, owner, digest, revision, contract, ordering, and sensitive-value negative cases ready to extend for a new physical proof class.
- CrossWake `PhysicalIphoneContract`, `PhysicalIphonePreflight`, and `Evidence`: owner-qualified assertions, ordered readiness checks, source-bound canonical validation, atomic no-replace promotion, and completion markers.
- Existing Adoption Paths guide and ExDoc groups: established choose/run/does-not-cover/next-step content pattern and Introduction navigation.

### Established Patterns

- Verification commands are named `mix verify.*`/`mix ci.*`; CI calls the same entrypoints and release-gate contracts prevent topology drift.
- Chimeway builds and binds one immutable package artifact before clean-consumer proof; a mutable source tree is not release evidence.
- Provider acceptance, device display, protected open, inbox seen/read, and engagement are distinct facts throughout lifecycle and operator surfaces.
- Safe proof records are closed allowlists with stable outcomes and negative fixtures; uncontrolled diagnostic blobs and sensitive source material are forbidden.
- Cross-repository truth is pinned to full immutable revisions and each repository remains authority for its own assertions.
- Public docs use progressive disclosure and literal "does not cover" boundaries rather than exposing backend mechanics or overstating guarantees.

### Integration Points

- Add a new physical proof module/envelope beside, not inside, the hermetic v1 extension contract.
- Add credential-free physical schema/negative-corpus verification alongside `verify.physical_proof_contract`; keep the real signed-device tracer separate and non-CI.
- Extend `mix.exs`, release-gate contract tests, and `.github/workflows/ci.yml` together for Threshold A parity.
- Add or expose a CrossWake-owned Chimeway notification physical-proof contract and source-bound public validation seam at the pinned compatible revision.
- Join Chimeway and CrossWake evidence only through immutable digests, owner-qualified facts, and the completion marker; never through copied authority or floating paths.
- Add the canonical guide to ExDoc Introduction extras and link it from README and Adoption Paths; contract-check commands, headings, vocabulary, and support-status statements.

</code_context>

<specifics>
## Specific Ideas

- Treat the retained artifact as a small proof bundle rather than one flattened JSON document. The bundle is atomic for promotion while each record remains independently typed and attributable.
- Borrow the digest-linked subject/reference idea from successful software-attestation systems, but do not add a general signing/attestation framework or claim that artifact provenance proves physical behavior.
- Use one honest proof ladder in docs: deterministic adoption paths -> hermetic Alpha twin -> physical-proof contract validation -> credentialed signed-iPhone run -> dated promoted evidence.
- The guide's opening should let readers jump by job: "Integrate mobile push", "Explain an outcome", "Review the security boundary", or "Run/promote proof".
- Operational copy follows the current brandbook and always separates observable fact from inference: "Provider accepted the push notification. Device display is not guaranteed by the provider response."
- Threshold A should be useful and shippable, but every support surface must retain explicit `physical evidence pending` wording until Threshold B updates truth atomically.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within Phase 103 scope. FCM/Android, generic background sync, engagement analytics, screenshots/video retention, a general attestation platform, and a broader device/support matrix remain explicitly outside v1.18.

</deferred>

---

*Phase: 103-physical-iphone-adoption-truth*
*Context gathered: 2026-08-26*
