# Phase 36: Golden Path & Version Alignment - Context

**Gathered:** 2026-05-28 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

A fresh Phoenix host can follow one credible path from dependency to first explainable trace, with consistent version strings everywhere. Delivers DOCS-01 and DOCS-02: a golden-path integration guide (dependency → migrations → config → first `Chimeway.trigger/3` → trace query → optional webhook pointer) and semver alignment across README, installation guide, and `mix.exs` `@version`. Does not include journey-guide doc truth (Phase 37), reference recipes (Phase 38), doc-contract CI gates (Phase 41), or engine/API changes.

</domain>

<decisions>
## Implementation Decisions

### Golden path document
- **D-01:** Ship a single vertical-slice guide at `guides/introduction/golden-path.md` as the primary DOCS-01 deliverable. It walks: add dependency → `mix chimeway.gen.migrations` → `mix ecto.migrate` → `config :chimeway, repo:` → add `Chimeway.Application` to supervision tree → minimal `:in_app` notifier → `Chimeway.trigger/3` with required `idempotency_key` → trace query proving explainability.
- **D-02:** Keep `guides/introduction/installation.md` as the detailed install reference; golden-path links to it for setup steps rather than duplicating every config paragraph verbatim.
- **D-03:** Golden-path notifier examples use the real Notifier callback API: `recipients/1` returning maps with `recipient_identity` and `recipient_type` (per `lib/chimeway/notifier.ex` and `lib/chimeway/trigger.ex` normalization) — not `resolve_recipients/2` or `identity` keys.

### Trace query (prove explainability)
- **D-04:** The golden-path “validation” step uses `Chimeway.Traces.explain_delivery/1` on a `delivery_id` from `{:ok, result}` after trigger (sync `:in_app` dispatch populates `result.trace.delivery_ids`), with `Chimeway.Traces.get_trace/1` on `result.trace.event_id` as an alternate path. Inbox listing alone is not sufficient as the proof step.
- **D-05:** Golden-path IEx snippets show reading `explanation.suppression_reason`, `explanation.status`, and `explanation.timeline` — aligned with `lib/chimeway/traces/explanation.ex` moduledoc, not raw payload inspection.

### Version alignment (DOCS-02)
- **D-06:** Align all consumer-facing version strings to `mix.exs` `@version` (currently `0.1.0`): README dep constraint, `guides/introduction/installation.md`, and golden-path dependency snippet all use `{:chimeway, "~> 0.1"}` (or equivalent matching `0.1.0`). Fix installation guide’s incorrect `~> 1.0.0`.
- **D-07:** Do not bump Hex package version to `1.0.0` in this phase unless planning discovers a separate release milestone requirement — this phase fixes drift, not a major version launch.
- **D-08:** Fix README Quick Start notifier example to match real API (`recipients/1`, correct recipient map keys, `Chimeway.trigger/3` with `idempotency_key`). README becomes a thin pointer: value prop, correct dep line, link to golden-path as primary onboarding.

### Optional webhook appendix
- **D-09:** Add a short “Next: webhook feedback loop” section at the end of golden-path that cross-links `examples/chimeway_demo_host` and `examples/chimeway_demo_host/test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs` — not a full inline webhook setup tutorial.
- **D-10:** Webhook appendix describes the outcome (inbound feedback → workflow progression → trace timeline entries) without duplicating Phase 34 engine docs or demo host controller implementation.

### Documentation packaging
- **D-11:** Add `guides/introduction/golden-path.md` to `mix.exs` `docs/[:extras]` list under Introduction group so HexDocs publishes it alongside installation and getting-started.
- **D-12:** Update `guides/introduction/getting-started.md` and/or installation “Next Steps” to link golden-path as the recommended post-install path (getting-started remains useful for inbox/channel depth; golden-path is the adoption spine).

### Claude's Discretion
- Exact golden-path section headings and copy tone (tutorial vs checklist)
- Whether to deprecate or trim overlapping content in getting-started vs golden-path
- Minor README structure (badges, doc link ordering)
- Whether golden-path includes a one-line `correlation_id` opt example for `find_traces_by_correlation_id/1`
- CHANGELOG entry for doc-only changes (if any release notes are warranted)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements and scope
- `.planning/ROADMAP.md` — Phase 36 goal, success criteria, DOCS-01/DOCS-02 mapping
- `.planning/REQUIREMENTS.md` — DOCS-01, DOCS-02 acceptance criteria
- `.planning/PROJECT.md` — Adoption Surface milestone intent, explainability as core value
- `.planning/phases/35-installer-task/35-CONTEXT.md` — Installer boundaries (D-14 semver deferred here; task name locked)
- `.planning/threads/2026-05-28-v1.5-milestone-assessment.md` — Version drift evidence and golden-path gap analysis

### Installation and onboarding (existing guides)
- `guides/introduction/installation.md` — Current install steps; must align version string and reference real `mix chimeway.gen.migrations`
- `guides/introduction/getting-started.md` — Notifier/trigger/inbox patterns; cross-link target for golden-path
- `guides/recipes/tracing-a-notification.md` — Trace API reference (`explain_delivery`, correlation, telemetry safety)
- `guides/recipes/oban-integration.md` — Oban boundary (separate from Chimeway migrations; optional async path)

### Public API (source of truth for doc examples)
- `lib/chimeway.ex` — `Chimeway.trigger/3` public entrypoint
- `lib/chimeway/notifier.ex` — Notifier callbacks (`recipients/1`, `notification_key`, `version`)
- `lib/chimeway/trigger.ex` — Trigger result shape (`trace.event_id`, `trace.delivery_ids`)
- `lib/chimeway/traces.ex` — `get_trace/1`, `explain_delivery/1`, `find_traces_by_correlation_id/1`
- `lib/chimeway/traces/explanation.ex` — Explanation struct fields and suppression_reason vocabulary

### Demo host (webhook appendix only)
- `examples/chimeway_demo_host/` — Reference Phoenix host for webhook feedback E2E
- `examples/chimeway_demo_host/test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs` — Runnable proof of feedback → progression → trace

### Methodology
- `.planning/METHODOLOGY.md` — Least-Surprise DX Default, One-Shot Recommendation Bias, Research-First Decision Ownership

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `mix.exs` `@version "0.1.0"` — Single source of truth for DOCS-02 alignment
- `lib/mix/tasks/chimeway.gen.migrations.ex` — Documented installer (Phase 35); golden-path step 2
- `lib/chimeway/traces.ex` moduledoc — Copy-ready IEx examples for golden-path trace section
- `guides/introduction/installation.md` — Four-step install flow (deps, migrations, config, supervisor)
- `guides/recipes/tracing-a-notification.md` — Telemetry + trace diagnosis depth (link, don’t duplicate)
- `examples/chimeway_demo_host` — Webhook feedback loop proof for optional appendix

### Established Patterns
- Guides live under `guides/introduction/`, `guides/flows/`, `guides/recipes/` with `mix.exs` docs extras registration
- Package ships `guides/` in Hex files list — new guide is publishable without code changes
- Idempotency required on every `Chimeway.trigger/3` — golden-path must show `:idempotency_key` (not optional in examples)
- Explainability product surface is `Chimeway.Traces.explain_delivery/1`, not inbox listing
- Doc examples must match `@callback recipients/1` — README currently violates this (pre-existing drift)

### Integration Points
- `README.md` — First-touch adopter surface; must link golden-path and fix API examples
- `mix.exs` `docs/[:extras]` — Add golden-path for HexDocs
- `guides/introduction/installation.md` “Next Steps” — Route to golden-path instead of/in addition to getting-started
- Future Phase 41 (GATE-01) — Doc-contract checks will validate version strings and golden-path steps against repo

</code_context>

<specifics>
## Specific Ideas

- User confirmed all assumptions without corrections (assumptions mode, 2026-05-28)
- Align to `0.1.0` / `~> 0.1` everywhere rather than premature `1.0.0` Hex bump — fixes three-way drift without conflating internal milestone numbering (v1.4) with package semver
- Golden path proves explainability via `explain_delivery/1`, not just “notification appeared in inbox”

</specifics>

<deferred>
## Deferred Ideas

- **Hex 1.0.0 release** — Coordinated version bump + CHANGELOG + publish checklist — out of scope unless explicitly added; align docs to current `@version` instead
- **Doc-contract CI (GATE-01)** — Phase 41; Phase 36 ships docs alignment, GATE-01 wires automated drift detection
- **Journey guide doc truth (`stop_conditions`, `pending_signals`)** — Phase 37 (DOCS-03 / INV-002)
- **Reference recipes (password-reset, feedback escalation)** — Phase 38 (RECP-01, RECP-02)
- **Demo host non-webhook trace path** — Phase 39 (DEMO-01)
- **`mix chimeway.install` full scaffold** — Deferred from Phase 35
- **README as full tutorial** — README stays thin; golden-path owns the vertical slice

</deferred>

---

*Phase: 36-golden-path-version-alignment*
*Context gathered: 2026-05-28*
