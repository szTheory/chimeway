# Phase 93: Hermetic Artifact Harness & Core Trace Proof - Context

**Gathered:** 2026-08-08 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver a reproducible Core proof that installs an unpacked Chimeway package artifact into a temporary clean host, boots and migrates that host's supported PostgreSQL database, triggers a durable notification lifecycle, and asserts sanitized public trace evidence. Mailglass, Accrue, the adoption selector, and the focused adoption CI lane remain later phases.
</domain>

<decisions>
## Implementation Decisions

### Artifact Provenance Harness
- **D-01:** Implement the Core proof as an executable ExUnit contract that builds and unpacks the root Hex artifact, then runs a separately scaffolded temporary consumer whose `:chimeway` dependency points only at that unpacked directory.
- **D-02:** Do not reuse an in-repository path dependency, the repository source tree, or the DemoHost as the provenance proof; those remain useful examples but cannot establish artifact isolation.
- **D-03:** Extend the project's existing ExUnit package/release truth anchors rather than adding a parallel shell truth checker.

### Clean Host Lifecycle
- **D-04:** Give the temporary consumer its own real supported PostgreSQL database and exercise the documented default-prefixed installer/migration and application-boot path.
- **D-05:** Configure synchronous dispatch in the consumer proof so the documented Core command deterministically reaches a terminal durable delivery outcome.

### Public Evidence Contract
- **D-06:** Define an adopter-owned minimal notifier with a fixed stable `notification_key` and version, then trigger it with explicit stable `tenant_id` and `idempotency_key` inputs.
- **D-07:** Obtain and assert lifecycle evidence exclusively through `Chimeway.Traces.explain_delivery/1`; the evidence must include only sanitized public explanation fields, never private test helpers or database-only inspection.

### the agent's Discretion
- Exact temporary-consumer scaffolding, database-name isolation strategy, command wiring, notifier name, and assertion formatting, provided the artifact-only provenance, real supported PostgreSQL lifecycle, and public explainability boundaries above remain intact.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope and requirements
- `.planning/ROADMAP.md` — Phase 93 goal and four success criteria.
- `.planning/REQUIREMENTS.md` — PROOF-01, PROOF-02, PROOF-03, and CORE-01 acceptance requirements.
- `.planning/PROJECT.md` — v1.17 adoption-proof intent and local-first explainability principles.
- `.planning/METHODOLOGY.md` — decisive, least-surprise, durable-explainability decision lenses.

### Existing adopter and artifact contracts
- `.planning/milestones/v1.5-phases/35-installer-task/35-CONTEXT.md` — generated migration and idempotency contract decisions.
- `.planning/milestones/v1.5-phases/36-golden-path-version-alignment/36-CONTEXT.md` — canonical public trigger and `explain_delivery/1` proof flow.
- `.planning/milestones/v1.14-phases/78-release-and-package-truth/78-CONTEXT.md` — use existing ExUnit package/release anchors and unpacked-artifact proof shape.
- `.planning/milestones/v1.14-phases/79-front-door-and-docs-ia/79-CONTEXT.md` — canonical public API snippet and package-proof constraints.
- `test/chimeway/release_gate_contract_test.exs` — established `mix hex.build --unpack` package-artifact contract.
- `test/chimeway/install/golden_diff_test.exs` — installer fixture and golden-diff conventions.

### Public lifecycle and explainability APIs
- `guides/introduction/installation.md` — supported host setup, prefix, migration, and boot guidance.
- `guides/introduction/golden-path.md` — public notifier, trigger, identity, and trace-proof walkthrough.
- `lib/chimeway/traces.ex` — public `Chimeway.Traces.explain_delivery/1` API.
- `lib/chimeway/traces/explanation.ex` — sanitized public explanation shape.
- `test/chimeway/integration/readme_snippet_test.exs` — real public trigger-to-explain lifecycle precedent.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `test/chimeway/release_gate_contract_test.exs`: builds and unpacks the root package under `MIX_ENV=prod`; the natural artifact-provenance contract base.
- `test/support/installer_fixture.ex`: scaffolding conventions for generated migrations, useful without relying on its in-repo dependency model.
- `examples/chimeway_demo_host/lib/demo_host/notifiers/trace_demo.ex`: minimal notifier and trace-proof example to adapt into an adopter-owned consumer form.
- `lib/mix/tasks/verify_published.ex`: existing packaged-artifact verification seam to inspect for compatible command wiring.

### Established Patterns
- Package/release and documentation truth are protected by ExUnit contracts, not standalone shell checkers.
- New hosts use explicit `prefix: "chimeway"`; legacy public-schema behavior is explicit `prefix: false`, never a silent default.
- Public adoption snippets use a stable notifier key/version, `Chimeway.trigger/3` with `tenant_id` plus `idempotency_key`, then `Chimeway.Traces.explain_delivery/1` from the returned delivery ID.

### Integration Points
- The proof must connect the unpacked artifact to a temporary Mix/Ecto consumer, its PostgreSQL lifecycle, generated Chimeway migrations, and public trace API.
- Phase 96 will later compose this Core path with Mailglass and Accrue proof commands into the adoption selector and dedicated CI lane.
</code_context>

<specifics>
## Specific Ideas

- The proof is a clean consumer from an unpacked built artifact, not an elaboration of the in-repository DemoHost or an artifact README-only check.
- The visible outcome must make stable notification identity inputs and a sanitized durable delivery explanation legible to a prospective adopter.
</specifics>

<deferred>
## Deferred Ideas

- Mailglass transactional-email proof and its fake-transport boundary — Phase 94.
- Accrue billing-escalation proof and provenance labeling — Phase 95.
- Adoption path selector, `mix verify.adoption_paths`, dedicated CI lane, and drift contracts across all paths — Phase 96.
</deferred>

---

*Phase: 93-hermetic-artifact-harness-core-trace-proof*
*Context gathered: 2026-08-08*
