# Phase 94: Mailglass Transactional-Email Proof - Context

**Gathered:** 2026-08-08 (assumptions mode, expanded research)
**Status:** Ready for planning

<domain>
## Phase Boundary

Extend the Phase 93 unpacked-artifact clean consumer with one deterministic Mailglass transactional-email proof. An adopter must see configured host mailable and stable render-key orchestration reach a successful Fake-transport outcome, with sanitized public Chimeway evidence and an exact explanation of what the proof does and does not establish. Live provider acceptance, sender/domain verification, deliverability, inbound feedback, browser/admin proof, a new CI lane, and production runtime changes remain outside this phase.
</domain>

<decisions>
## Implementation Decisions

### Clean Consumer and Ownership Boundary
- **D-01:** Extend the Phase 93 ArtifactConsumerFixture with a separately callable Mailglass proof path; preserve the unpacked Chimeway artifact as the consumer's only :chimeway dependency, unique temporary PostgreSQL database, provenance validation, failure-safe cleanup, and serialized release-gate execution. Do not use DemoHost, a source-tree path dependency, or mix verify.mailglass as the adopter proof.
- **D-02:** Use one host-owned ArtifactConsumer.Repo for Mailglass persisted state and migrate both libraries through the generated host's normal Ecto migration path. The existing Mailglass.TestRepo arrangement is test-harness isolation, not the intended adopter architecture.
- **D-03:** Keep Phase 93's direct :oban consumer opt-in and add a direct Mailglass dependency compatible with the repository's resolved Mailglass 1.3 line. Run the proof only in the established Mailglass-compatible environment; do not change Chimeway's core Elixir support floor.

### Transactional Email Orchestration
- **D-04:** Generate an adopter-owned, email-only notifier with a fixed stable notification_key and version plus fixed explicit tenant_id and idempotency_key inputs. Its rendering/2 must persist an email render_key and render_version.
- **D-05:** Generate an adopter-owned Mailglass.Mailable and configure the email channel to use Chimeway.Adapters.Mailglass, mapping the exact stable render key to the host mailable function. Prove notifier -> persisted render identity -> configured map -> host mailable -> Mailglass adapter, not merely generic adapter success.
- **D-06:** Configure Mailglass.Adapters.Fake with the host repo and explicit Fake ownership setup before the synchronous trigger. Use Mailglass's public migration wrapper, not hand-written Mailglass DDL or a Phoenix-oriented installer.

### Evidence, Safety, and Truthful Language
- **D-07:** Use Chimeway.Traces.explain_delivery/1 as the sole adopter-facing lifecycle evidence source. Require its email channel, notification/render identity, successful delivery and attempt outcome, Mailglass adapter identity, and ordered lifecycle evidence. A separate Fake assertion may verify exactly one generated host mailable was recorded, but it is test validation rather than public trace evidence.
- **D-08:** Emit one strict, machine-parseable CHIMEWAY_MAILGLASS_PROOF line with transport=fake and only allowlisted stable identity, channel/render identity, status/attempt, adapter, and timeline fields. Reject duplicate or unknown keys and forbid recipient addresses, subject/body/assigns, credentials, raw Mailglass structs, provider IDs/responses, full metadata, and direct database inspection from proof output.
- **D-09:** Follow the brandbook's literal, calm what happened -> why it matters -> next step voice. Say Fake recorded the host-composed message and Chimeway recorded a successful Mailglass adapter attempt; never use unqualified email delivered language.

### Documentation and Developer Experience
- **D-10:** Update the canonical Mailglass integration guide with a concise clean-consumer proof section: what it proves (local configured composition, mailable selection, Chimeway routing/attempt persistence) and what it does not prove (real provider acceptance, sender/domain verification, inbox placement, production credentials, provider callbacks, or live webhook feedback). Cross-reference the blueprint rather than duplicating a second end-to-end guide.
- **D-11:** Correct the guide's implication that Mailglass needs a separate Ecto repo: Mailglass uses a host-configured repo, while this proof intentionally uses one consumer-owned repo. Label mix verify.mailglass accurately as a repository maintainer regression suite, not a command supplied to a Hex consumer.

### the agent's Discretion
- Exact helper/module names, fixture-local non-sensitive message values, safe output field spelling/order, migration filename, and focused contract-test placement, provided all provenance, ownership, evidence, redaction, and documentation decisions above remain intact.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Scope, prior proof, and project posture
- .planning/ROADMAP.md — Phase 94 goal, requirements, and success criteria.
- .planning/REQUIREMENTS.md — MAIL-01 and MAIL-02 acceptance requirements.
- .planning/PROJECT.md and .planning/METHODOLOGY.md — v1.17 adoption-proof intent and decisive, least-surprise, durable-explainability lenses.
- .planning/phases/93-hermetic-artifact-harness-core-trace-proof/93-CONTEXT.md — locked unpacked-artifact, public-evidence, and temporary-consumer decisions.
- .planning/phases/93-hermetic-artifact-harness-core-trace-proof/93-01-SUMMARY.md — implemented harness constraints, direct Oban opt-in, and reusable public-proof allowlist.

### Chimeway and Mailglass seams
- test/support/artifact_consumer_fixture.ex — Phase 93 temporary consumer scaffold, provenance, database, and cleanup pattern to extend.
- test/chimeway/release_gate_contract_test.exs — package artifact proof and release-gate contract anchor.
- lib/chimeway/adapters/mailglass.ex — render-key-to-mailable resolution and adapter outcomes.
- lib/chimeway/traces.ex and lib/chimeway/traces/explanation.ex — public, sanitized explanation contract.
- test/support/mailglass/migrations/00000000000001_mailglass_init.exs — public Mailglass migration-wrapper precedent.
- test/chimeway/dispatch/executor_mailglass_adapter_test.exs — Fake transport and adapter-contract precedent.
- examples/chimeway_demo_host/test/demo_host_web/mailglass_delivery_proof_test.exs — configured Mailglass analog, not artifact provenance.
- examples/chimeway_demo_host/lib/demo_host/notifiers/invite_sent.ex and examples/chimeway_demo_host/lib/demo_host/mailers/invite_email.ex — notifier/mailable analogs.

### Adopter guidance and official contracts
- guides/introduction/mailglass-integration.md — canonical guide to update and correct.
- guides/recipes/mailglass-integration-blueprint.md — focused wiring recipe and cross-reference boundary.
- test/chimeway/doc_contract_test.exs — documentation truth contract anchor.
- brandbook/index.html — current brand voice; supersedes older brand prompt prose where they differ.
- https://mailglass.hexdocs.pm/Mailglass.Repo.html — host-configured repository contract.
- https://mailglass.hexdocs.pm/testing.html — Fake transport testing and ownership contract.
- https://hexdocs.pm/mailglass/Mailglass.Adapters.Fake.html — Fake in-memory transport boundary.
- https://ecto-sql.hexdocs.pm/Mix.Tasks.Ecto.Migrate.html — standard Ecto migration execution contract.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- ArtifactConsumerFixture owns packaged-artifact construction, temporary consumer generation, a unique database, command execution, provenance checks, and cleanup; Mailglass must be a second proof capability, not a new harness.
- Chimeway.Traces.explain_delivery/1 is the public sanitized evidence seam.
- Existing demo notifier/mailable, adapter tests, and migration wrappers supply idiomatic host-owned module/function, render-key, Fake ownership, and migration patterns.

### Established Patterns
- Stable strings, not module names, are durable notification and render identities.
- ExUnit release/doc contracts, not an extra shell checker, protect package and documentation truth.
- Package consumer proofs are async: false, own unique resources, and clean failure paths explicitly.
- Public evidence is allowlisted and excludes PII, rendered content, credentials, and provider metadata.

### Integration Points
- Generated consumer dependencies/config compose the unpacked Chimeway artifact with Mailglass, Ecto/Postgrex, and direct Oban opt-in.
- The generated host binds the email channel to Chimeway.Adapters.Mailglass and the persisted email render key to the generated mailable function.
- The canonical guide and doc contracts explain the proof boundary without including admin, webhooks, or external-provider behavior.
</code_context>

<specifics>
## Specific Ideas

- Safe proof narrative: Mailglass Fake recorded the host-composed message and Chimeway recorded a successful Mailglass adapter attempt.
- Required limitation: Not covered: real provider acceptance, sender/domain verification, inbox placement or display, and live webhook feedback.
- The user requested one cohesive, research-backed recommendation set emphasizing expert Elixir/Ecto/Phoenix practice, least surprise, developer ergonomics, safety, explainability, and the adopter JTBD rather than backend implementation exposure.
</specifics>

<deferred>
## Deferred Ideas

- Real-provider acceptance, credentials, sender/domain verification, deliverability/inbox placement, and production feedback tests — host/provider responsibility, outside deterministic CI proof.
- Webhook simulation and feedback progression — explicitly outside MAIL-01/MAIL-02 proof scope.
- Browser/admin proof — optional unpublished sibling surface; adds no artifact-consumer confidence.
- verify.adoption_paths and dedicated adoption CI lane — Phase 96.
- Chimeway core runtime dependency, migration, adapter, or Elixir-floor changes — out of scope.
</deferred>

---

*Phase: 94-mailglass-transactional-email-proof*
*Context gathered: 2026-08-08*
