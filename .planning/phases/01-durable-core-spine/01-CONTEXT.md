# Phase 1: Durable Core Spine - Context

**Gathered:** 2026-04-23  
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver the foundational event/notification data model with stable key identity and in-app lifecycle semantics. This phase covers notifier contract, trigger pipeline, durable event and per-recipient in-app records, idempotency foundations, and inbox read-state APIs. Outbound delivery execution breadth remains outside this phase boundary.

</domain>

<decisions>
## Implementation Decisions

### Package topology
- **D-01:** Start v0.1 as a single `chimeway` package to maximize early iteration speed and reduce packaging overhead.
- **D-02:** Document and preserve an extraction seam for `chimeway_admin` (and other optional packages) so package split can happen before 1.0 without breaking contracts.

### API contract style
- **D-03:** Use explicit behaviour callbacks as the primary contract for notifier definition and execution.
- **D-04:** Provide a thin optional DSL for ergonomics, but keep a plain `trigger/3` path available and first-class.

### Persistence boundary
- **D-05:** In phase 1, implement durable `events` and `notifications` tables with idempotency protections and inbox lifecycle fields.
- **D-06:** Defer `deliveries` and `attempts` persistence to phase 2 while keeping schema and key design compatible with that expansion.

### Identifier strategy
- **D-07:** Use stable persisted `notification_key` (+ version) as identity for notification types; do not persist module names as durable type identity.
- **D-08:** Use UUID primary keys and enforce unique idempotency constraints at the event layer from phase 1.

### Inbox lifecycle semantics
- **D-09:** Keep `seen_at`, `read_at`, and `archived_at` as separate explicit lifecycle timestamps.
- **D-10:** Expose explicit state-transition APIs; do not auto-mark notifications as read on fetch.

### Claude's Discretion
- Exact migration/index definitions for phase 1 tables, as long as they preserve decision D-05 through D-10.
- Concrete module naming for notifier and persistence internals, as long as stable key identity remains enforced.
- Whether to ship DSL helpers in phase 1 initial plan or as a follow-up plan in the same phase, provided the plain behaviour + `trigger/3` path exists.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase contract
- `.planning/ROADMAP.md` - Phase 1 goal, requirement mapping, and success criteria.
- `.planning/REQUIREMENTS.md` - Locked v1 requirements `CORE-01..04` and `INBX-01..03` for phase scope.
- `.planning/PROJECT.md` - Core value, constraints, non-goals, and key architectural commitments.

### Technical direction
- `.planning/research/ARCHITECTURE.md` - Recommended layered architecture and boundary patterns.
- `.planning/research/STACK.md` - Baseline stack choices and compatibility guidance.
- `.planning/research/PITFALLS.md` - Critical failure modes (identity, idempotency, hidden sends) to prevent early.
- `.planning/research/SUMMARY.md` - Phase ordering rationale and risk mitigation context.

### Source vision and prior-art synthesis
- `prompts/CHIMEWAY-GSD-IDEA.md` - Authoritative vision, principles, and v0.1 milestone intent.
- `prompts/elixir_notifykit_research_brief.md` - Deep domain model and cross-framework design lessons.
- `prompts/chimeway-engineering-dna-from-prior-libs.md` - OSS delivery discipline and release engineering expectations.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- No runtime source modules exist yet in this repository; reusable assets for this phase are planning artifacts and research docs.
- Existing planning docs already define baseline data model terms (`event`, `notification`, `delivery`, `attempt`) and should be treated as reusable vocabulary contracts.

### Established Patterns
- Documentation-first workflow: roadmap and requirements are explicit and phase-mapped before implementation.
- Explicitness over magic: behaviour-driven contracts are preferred to opaque framework-style abstractions.
- Local-first ownership and explainability are non-negotiable constraints carried from project initialization.

### Integration Points
- Phase 1 implementation should establish core module seams that phase 2 can connect to for outbound delivery/attempt persistence.
- Schema and API choices in this phase must be compatible with optional Oban and adapter integrations in later phases.
- CI/verification hooks (`mix verify.*`) are expected to land progressively and should be anticipated in file/layout decisions.

</code_context>

<specifics>
## Specific Ideas

- Keep the developer experience "idiomatic Elixir": explicit behaviour contracts plus optional ergonomics, not hidden framework magic.
- Preserve the "one event, many recipients" conceptual model in naming and schema shape from day one.
- Ensure every foundational decision in phase 1 supports later explainability goals, even if operator UI lands in later phases.

</specifics>

<deferred>
## Deferred Ideas

None - discussion stayed within phase scope.

</deferred>

---

*Phase: 01-durable-core-spine*  
*Context gathered: 2026-04-23*
