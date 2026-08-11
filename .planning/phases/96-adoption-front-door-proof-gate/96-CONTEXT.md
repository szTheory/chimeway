# Phase 96: Adoption Front Door & Proof Gate - Context

**Gathered:** 2026-08-10 (assumptions mode, expanded research)
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver a concise, documentation-first adoption selector for the existing Core, Mailglass, and Accrue clean-room proofs, plus one focused, PostgreSQL-backed CI proof lane and contracts that keep the selector, commands, fixture behavior, and CI entrypoint truthful together. This phase composes the Phase 93–95 proofs; it does not add runtime integration behavior, live-provider validation, browser UI, source-checkout partner suites, or a new public product surface beyond the documented verification command.
</domain>

<decisions>
## Implementation Decisions

### Adoption Selector and Information Architecture
- **D-01:** Create one canonical static Markdown adoption selector in `guides/introduction/`, listed first in the ExDoc Introduction extras and linked prominently from the README documentation/quick-start surface. Do not build cards, a browser experience, or a second tutorial.
- **D-02:** Make the selector outcome-first with exactly Core, Mailglass, and Accrue rows. Every row must consistently provide: “Choose this when”, a Host / Chimeway / partner responsibility split, a copyable focused proof command, one representative sanitized `CHIMEWAY_*_PROOF` record shape, an explicit “Does not cover” boundary, and a link to its canonical detailed guide.
- **D-03:** Preserve progressive disclosure: the selector helps an adopter choose and evaluate; the existing Golden Path, Mailglass, and Accrue guides remain the sole owners of detailed setup and lifecycle explanation. README stays concise and links through rather than copying the selector content.
- **D-04:** Use literal, calm developer-to-developer microcopy: what happened → why it matters → next step. Use “proof”, “trace”, “attempt”, “host-owned”, and “compatibility evidence”; never overclaim delivery or expose fixture/CI internals.

### Verification Command and Evidence UX
- **D-05:** Implement `mix verify.adoption_paths` as one documented, purpose-built Mix task with a bounded `--only core|mailglass|accrue` option; without `--only`, it runs all three paths. The all-path form is the canonical CI/release gate, and the scoped form is the local recovery loop.
- **D-06:** Have the Mix task delegate orchestration to one local runner rather than a long inline alias command. It must serially compose the existing artifact-consumer proof capabilities and keep proof construction, unpacked-artifact provenance, lifecycle validation, evidence parsing, and cleanup in the package-owned fixture.
- **D-07:** Preserve the existing strict, one-record `CHIMEWAY_CORE_PROOF`, `CHIMEWAY_MAILGLASS_PROOF`, and `CHIMEWAY_ACCRUE_PROOF` formats as the automation interface. Add fixed, redacted path `START`, `PASS`, and `FAIL` framing with only path, safe stage, exit status, safe token/provenance facts, and rerun command.
- **D-08:** Never present `verify.mailglass` or `verify.accrue` as adopter proof commands: they remain broader repository-maintainer regression suites. Do not dump generated-host output, database URLs/names, archive or temporary paths, payloads, recipients, credentials, provider responses, raw structs, SQL, or full exceptions.
- **D-09:** Preserve the prior proof truth boundaries verbatim in selector-facing language: Core proves a durable lifecycle/public trace, not external delivery; Mailglass Fake proves local host composition and Chimeway adapter orchestration, not provider acceptance/sender verification/inbox placement/live feedback; Accrue preserves its event-to-signal and non-terminal `active / signal_received` semantics plus released-package versus SHA-qualified compatibility terminology.

### Focused CI and Operational Posture
- **D-10:** Add exactly one dedicated PostgreSQL 15-backed `verify_adoption_paths` CI job that invokes the aggregate `mix verify.adoption_paths` command, uses the established root setup/cache/service-container patterns, retains bounded per-path diagnostics, and runs serially.
- **D-11:** Add the job to the full push/dispatch `ci-gate` release-confidence topology while leaving the fast PR gate focused on cheap structural contracts. This respects the existing CI-tiering decision that expensive ecosystem-style proofs stay out of the PR fast path while behavior is continuously verified on main/release paths.
- **D-12:** Do not run detailed partner suites, check out sibling partner repositories, add a local registry/Compose stack/source-path fallback, cache generated temporary hosts/databases, or split into three jobs/matrix legs. One lane is the lower-risk baseline; split later only if measured timing and failure isolation justify it.

### Drift Contracts and Release Truth
- **D-13:** Extend the existing documentation and release-gate ExUnit contracts rather than creating a parallel shell truth checker. Contract coverage must bind all-and-only the three path keys, selector wording, guide locations, responsibility/limitation anchors, exact command forms, safe evidence tokens, fixture capabilities, Mix task option validation, CI job/service/command, and `ci-gate` aggregation.
- **D-14:** Include negative drift cases: unknown/duplicate `--only` values fail without a proof record; an aggregate run invokes each path once; focused runs invoke only their selected path; commands cannot regress to partner suites; unsafe/duplicate proof records, missing selector links, missing PostgreSQL CI service, removed aggregator membership, or renamed job/task fail the contract.
- **D-15:** Keep behavioral execution and structural contracts separate: contracts protect low-cost textual/config parity on PRs; the adoption CI lane proves the actual three clean-room behaviors from a built/unpacked artifact. Neither is a substitute for the other.

### the agent's Discretion
- Exact guide filename/title, table markup, ordered headings, task/runner module and script names, safe diagnostic stage vocabulary, focused test-module placement, CI timeout, and cache-key spelling, provided the locked command semantics, redaction boundary, one-lane topology, and contracts remain intact.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Scope, requirements, and project posture
- `.planning/ROADMAP.md` — Phase 96 goal, five success criteria, and dependent Phase 93–95 scope.
- `.planning/REQUIREMENTS.md` — ADPT-01, ADPT-02, GATE-01, GATE-02, and DOCS-01 acceptance requirements; explicit exclusion of local registry/Compose/source-path fallback.
- `.planning/PROJECT.md` — v1.17 adopter-proof intent and explicit non-UI scope.
- `.planning/METHODOLOGY.md` — cohesive recommendation, least-surprise DX, durable explainability, and low-escalation lenses.
- `.planning/STATE.md` — current phase and accumulated CI/adoption decisions.

### Prior clean-room proof contracts
- `.planning/phases/93-hermetic-artifact-harness-core-trace-proof/93-CONTEXT.md` — artifact-only Core proof, temporary PostgreSQL host, and public trace evidence constraints.
- `.planning/phases/94-mailglass-transactional-email-proof/94-CONTEXT.md` — Fake transport, one host repo, public evidence, and Mailglass limitation wording.
- `.planning/phases/95-accrue-billing-escalation-proof/95-CONTEXT.md` — Accrue natural event/outcome, public workflow evidence, and provenance terminology.
- `priv/adoption_proof/artifact_consumer_fixture.ex` — reusable Core, Mailglass, and Accrue artifact-consumer proof implementation and strict evidence parsers.
- `scripts/prove-accrue-consumer.exs` — packaged Accrue runner/provenance CLI precedent.

### Documentation, brand, and host ownership
- `README.md` — current local-first positioning, host boundary, and documentation entry surface.
- `guides/introduction/golden-path.md` — canonical Core guide and public lifecycle proof.
- `guides/introduction/mailglass-integration.md` — Mailglass proof, Fake boundary, and maintainer-suite distinction.
- `guides/introduction/accrue-dunning-integration.md` — Accrue proof, provenance, and non-terminal outcome wording.
- `guides/recipes/mailglass-integration-blueprint.md` and `guides/recipes/accrue-dunning-blueprint.md` — detailed recipe destinations; not alternative front doors.
- `brandbook/index.html` — current authoritative brand voice, literal operational claims, and accessibility/state guidance.
- `prompts/chimeway-host-app-integration-seam.md` — host/Chimeway/partner ownership vocabulary.
- `prompts/chimeway-release-engineering-and-ci.md` and `prompts/chimeway-testing-and-e2e-strategy.md` — clean-checkout CI scripts, PostgreSQL service, and test topology guidance.
- `prompts/chimeway-admin-ui-and-operator-ia.md` — confirms operators are downstream and no admin/browser proof belongs here.

### Existing verification and CI seams
- `mix.exs` — current `verify.*` / `ci.*` convention and ExDoc extras ordering.
- `.github/workflows/ci.yml` — PostgreSQL service, cache, PR/main tiering, and gate-aggregation conventions.
- `test/chimeway/doc_contract_test.exs` — guide truth/topology contract seams, including Phase 95’s temporary `verify.adoption_paths` exclusion to replace.
- `test/chimeway/release_gate_contract_test.exs` — package proof, CI membership, alias/task, evidence, and release-truth contract seams.
- `.github/workflows/release.yml` — release automation depends on literal `ci-gate` success.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ArtifactConsumerFixture`: separately callable `prove_core!/2`, `prove_mailglass!/2`, and `prove_accrue!/2` paths already own packaged-artifact construction, generated clean consumer, unique database, public evidence checks, and cleanup.
- Existing `CHIMEWAY_*_PROOF` parsers and release contracts provide strict allowlisting, no atom creation, duplicate/unknown-key rejection, and safe lineage for path diagnostics.
- `scripts/prove-accrue-consumer.exs` demonstrates package-shipped runner validation, archive/digest handling, nonzero failure without an authoritative record, and safe CLI boundary.
- Existing `verify.*` aliases, CI scripts, Postgres service jobs, `ci-gate`, `pr-gate`, doc contracts, and release-gate contracts provide established naming/topology patterns.

### Established Patterns
- Adoption proofs are artifact-consumer evidence, not in-repository DemoHost or partner regression tests.
- ExUnit contract suites protect package, documentation, CI, and evidence truth; behavioral proof remains a real integration execution.
- CI tiering keeps expensive integration/ecosystem work on push/main while PR feedback favors cheaper gates.
- Safe operator/developer output is explicit and allowlisted, not an accidental dump of otherwise available backend state.
- New docs use semantic Markdown, normal code blocks, named links, and progressive disclosure; no visual frontend is needed for documentation selection.

### Integration Points
- The selector must compose README, ExDoc extras, three existing canonical guides, and a new documented Mix task without creating competing guidance.
- The task/runner must map bounded path names to existing fixture proof functions and preserve their proof evidence/cleanup contracts.
- The CI job must use the repository’s PostgreSQL/cache/aggregate patterns and be included in `ci-gate` without importing partner checkout/suite behavior.
- Doc/release contracts must be updated atomically with command, fixture mapping, guide, and CI changes so future edits cannot silently create a false adopter promise.
</code_context>

<specifics>
## Specific Ideas

- Selector table columns: Intended outcome, Choose, Chimeway owns, Host/partner owns, and proof boundary; each row expands into the same short command/evidence/limit/deep-guide structure.
- Example safe diagnostic register: `[adoption:mailglass] START`; `[adoption:mailglass] PASS`; `CHIMEWAY_MAILGLASS_PROOF transport=fake ...`; `[adoption:mailglass] FAILED stage=migrate`; “Why it matters …”; “Next step: mix verify.adoption_paths --only mailglass”.
- Keep visual/UI scope intentionally static: conventional headings, semantic table/caption where appropriate, descriptive links, visible focus/non-color-only rendering if docs are styled, no motion or diagrams required to understand proofs.
- User requested a research-backed, one-shot recommendation set optimizing expert Elixir/Ecto/Phoenix practice, trustworthy local-first explainability, cohesive architecture, low cognitive load, accessibility, and great developer ergonomics.
</specifics>

<deferred>
## Deferred Ideas

- A visual/browser adoption chooser, cards, responsive UI, or admin/operator proof — outside this documentation and CI phase.
- Three parallel/matrix adoption CI jobs, per-path required checks, or running the full adoption lane on PRs — defer unless measured runtime/failure-isolation needs outweigh the existing fast-PR tiering decision.
- A broadly supported Hex-consumer CLI, arbitrary path selectors, JSON reporting, or user-facing task APIs beyond bounded repository proof invocation — reconsider only if a later milestone establishes that support contract.
- Live provider/payment acceptance, credentials, sender/domain verification, inbox placement, webhooks, and production partner feedback — remain host/provider responsibility outside deterministic proofs.
- Sigra, Threadline, Inbox, and other future adoption paths — future ADPT-03 work after the three primary paths establish the reusable model.
</deferred>

---

*Phase: 96-adoption-front-door-proof-gate*
*Context gathered: 2026-08-10*
