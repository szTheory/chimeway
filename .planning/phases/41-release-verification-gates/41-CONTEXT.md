# Phase 41: Release Verification Gates - Context

**Gathered:** 2026-05-29 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Doc drift and example breakage are caught before release, not by adopters in production. Delivers **GATE-01**: automated doc-contract checks, `mix verify.example` wired into CI, and a maintainer release runbook that names these gates as mandatory pre-ship steps.

In scope: extend `test/chimeway/doc_contract_test.exs` to cover adoption-surface docs (golden-path, installation, README, oban-integration); add version-alignment and installer-task-name gates; add named `mix ci.verify_gates` entrypoint; add GitHub Actions job for `mix verify.example`; expand `verify.example` to include admin/reference-flow smoke; update `MAINTAINING.md` release runbook.

Out of scope: new engine/API changes, new guides or recipes, Hex version bump, read/unread workflow glue, bell inbox UI, full fresh-Phoenix-host UAT automation (manual UAT remains acceptable), changing `ci.install_golden` path-gating behavior.

</domain>

<decisions>
## Implementation Decisions

### Doc-contract matrix completion
- **D-01:** Extend `test/chimeway/doc_contract_test.exs` with describe blocks for adoption-surface docs not yet gated: `guides/introduction/golden-path.md`, `guides/introduction/installation.md`, `README.md`, and `guides/recipes/oban-integration.md` (closes IN-01 deferred from Phase 37).
- **D-02:** Follow the established static forbidden/required string pattern from Phases 37–38 — no new doc-contract framework or external tooling.
- **D-03:** Golden-path and installation gates require `mix chimeway.gen.migrations`, `Chimeway.trigger`, `idempotency_key`, and `Chimeway.Traces.explain_delivery` where applicable; forbid fictional APIs (`Chimeway.Workflow`, `stop_conditions`, `Workflows.Workers`, `Chimeway.Trigger.trigger`).
- **D-04:** Oban-integration gate requires `Chimeway.Dispatch.WorkflowProgressionWorker` and `Chimeway.Dispatch.SignalRouterWorker`; forbids `Workflows.Workers` namespace (Phase 37 IN-01).

### Version alignment gate
- **D-05:** Add automated ExUnit gate asserting `mix.exs` `@version "0.1.0"` aligns with consumer-facing `{:chimeway, "~> 0.1"}` in README, `guides/introduction/installation.md`, and `guides/introduction/golden-path.md`.
- **D-06:** Forbid `~> 1.0` / `1.0.0` version drift in those consumer-facing files — replaces Phase 36 manual grep gates with persistent CI enforcement (DOCS-02 regression protection).

### Installer task name gate
- **D-07:** Doc-contract tests require `mix chimeway.gen.migrations` in installation, golden-path, and README install blocks; forbid fictional installer task names — ties docs to Phase 35 D-01 locked task name.

### `mix verify.example` in CI
- **D-08:** Add a dedicated GitHub Actions job in `.github/workflows/ci.yml` running `mix verify.example` on every push/PR to `main` — separate job from core `mix ci.test` matrix (preserves Phase 33 fast-feedback pattern).
- **D-09:** Do **not** add `verify.example` to default `mix ci` alias — keep explicit opt-in via named entrypoint + CI job + MAINTAINING.md runbook.

### `verify.example` scope expansion
- **D-10:** Expand `mix verify.example` to include admin/reference-flow smoke beyond webhook E2E — run `chimeway_admin` test suite and/or add minimal demo-host admin route coverage at `/admin/chimeway` (Phase 40 deferred OPER smoke).
- **D-11:** Preserve existing demo-host webhook + feedback pipeline E2E coverage inside `verify.example`; expansion is additive, not a replacement.

### Named pre-ship entrypoint
- **D-12:** Add `mix ci.verify_gates` alias bundling doc-contract tests + version-alignment gates as the single citeable GATE-01 command for maintainers and CI documentation.
- **D-13:** `ci.verify_gates` runs scoped test path(s) only — not full `mix test` — for fast, explicit gate semantics parallel to `ci.install_golden`.

### MAINTAINING.md release runbook
- **D-14:** Update `MAINTAINING.md` step 3 ("Run the full local gate") to mandate `mix ci`, `mix ci.docs`, `mix ci.verify_gates`, and `mix verify.example` before tagging/publishing.
- **D-15:** Document `mix ci.install_golden` as required when installer templates or `lib/mix/tasks/chimeway.gen.migrations.ex` change (reference existing path-gated CI job; do not change gating behavior).
- **D-16:** Post-publish verify trio (`verify.clean`, `verify.parity`, `verify.published`) remains unchanged — GATE-01 gates are **pre-ship**, not post-publish.

### Claude's Discretion
- Exact forbidden/required string lists per new describe block
- Whether version-alignment lives in `doc_contract_test.exs` or a sibling `version_alignment_test.exs`
- Whether `verify.example` chains `chimeway_admin` tests via subprocess or adds demo-host admin LiveView smoke test
- CI job naming and matrix details (single OTP version vs full matrix for example host)
- Whether `ci.verify_gates` also invokes `mix ci.docs` or keeps docs separate (MAINTAINING.md already mandates both)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements and scope
- `.planning/ROADMAP.md` — Phase 41 goal, success criteria, GATE-01 mapping
- `.planning/REQUIREMENTS.md` — GATE-01 acceptance criteria
- `.planning/PROJECT.md` — Quality bar (`mix verify.*`, `mix ci.*`, release hygiene)
- `.planning/METHODOLOGY.md` — Least-Surprise DX Default, Research-First Decision Ownership

### Prior phase handoffs (deferred GATE-01 work)
- `.planning/phases/35-installer-task/35-CONTEXT.md` — Installer task name locked; `ci.install_golden` pattern
- `.planning/phases/36-golden-path-version-alignment/36-CONTEXT.md` — DOCS-01/02; manual version grep gates to automate
- `.planning/phases/37-doc-truth-journey-guides/37-CONTEXT.md` — Journey doc-contract pattern; IN-01 oban-integration deferred here
- `.planning/phases/37-doc-truth-journey-guides/37-VERIFICATION.md` — IN-01 oban-integration gap evidence
- `.planning/phases/38-reference-recipes/38-CONTEXT.md` — Recipe doc-contract pattern
- `.planning/phases/39-demo-host-trace-path/39-CONTEXT.md` — D-09: do not expand verify.example (now Phase 41 scope)
- `.planning/phases/40-operator-trace-mvp/40-CONTEXT.md` — Admin smoke deferred to Phase 41

### Doc-contract target files
- `test/chimeway/doc_contract_test.exs` — Existing gate pattern (moduledoc + journey + recipes)
- `guides/introduction/golden-path.md` — Golden-path steps to validate
- `guides/introduction/installation.md` — Installer + version alignment target
- `README.md` — First-touch version + installer alignment
- `guides/recipes/oban-integration.md` — Worker namespace truth (IN-01)

### Verify entrypoints and CI
- `mix.exs` — `@version`, `verify.example`, `ci.install_golden` aliases
- `MAINTAINING.md` — Release runbook to update
- `.github/workflows/ci.yml` — CI job insertion point
- `.github/workflows/docs.yml` — Existing `mix ci.docs` job (unchanged)

### Example host and admin proof
- `examples/chimeway_demo_host/` — `verify.example` target; webhook E2E proof
- `examples/chimeway_demo_host/mix.exs` — `chimeway_admin` path dep
- `examples/chimeway_demo_host/lib/demo_host_web/router.ex` — Admin mount at `/admin/chimeway`
- `chimeway_admin/test/` — Admin LiveView route tests for verify expansion

### Engineering DNA
- `AGENTS.md` — Named `mix verify.*` / `mix ci.*` entrypoints mandatory
- `prompts/chimeway-testing-and-e2e-strategy.md` — Named entrypoints, CI parity
- `prompts/chimeway-release-engineering-and-ci.md` — Release verify patterns

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `test/chimeway/doc_contract_test.exs` — 37 tests across moduledoc, journey guide, password-reset recipe, feedback-escalation recipe; extend with golden-path, installation, README, oban-integration describe blocks
- `mix.exs` `verify.example` alias — Already runs `examples/chimeway_demo_host` test suite; expand scope for admin smoke
- `mix.exs` `ci.install_golden` — Path-gated installer contract pattern to mirror for verify.example CI job design
- `.github/workflows/ci.yml` `install_golden_contract` job — Template for dedicated proof-lane CI job with optional path-gating
- Phase 36 `36-03-PLAN.md` grep gates — Version alignment patterns to codify as ExUnit assertions

### Established Patterns
- Doc-contract: static `@forbidden_strings` / `@required` lists per guide file in ExUnit describe blocks (Phase 37 D-15)
- `verify.*` aliases separate from default `mix ci` for fast core feedback (Phase 33 D-10, Phase 35 patterns)
- `ci.install_golden` path-gated on PRs, always runs on main push — precedent for verify.example job design
- MAINTAINING.md documents maintainer-facing release steps; post-publish verify trio already established

### Integration Points
- `test/chimeway/doc_contract_test.exs` — Primary GATE-01 test expansion target
- `mix.exs` aliases — Add `ci.verify_gates`; expand `verify.example`
- `.github/workflows/ci.yml` — New `verify_example` job
- `MAINTAINING.md` — Pre-ship gate documentation (step 3 expansion)
- `examples/chimeway_demo_host/test/` — Potential admin route smoke test addition
- `chimeway_admin/test/chimeway_admin/` — Admin test suite for verify.example chaining

</code_context>

<specifics>
## Specific Ideas

- User confirmed all assumptions without corrections (assumptions mode, 2026-05-29)
- GATE-01 closes the v1.5 adoption-surface quality loop — docs truth (Phases 36–38) and reference proof (Phases 39–40) become release-blocking gates
- Oban-integration doc-contract (IN-01) is explicitly in scope — the last major guide gap from Phase 37 review

</specifics>

<deferred>
## Deferred Ideas

- **Full fresh-Phoenix-host UAT automation** — Create app → migrate → trigger → explain in IEx; manual UAT acceptable; not CI-automated in this phase
- **Hex 1.0.0 coordinated release** — Version bump + publish checklist expansion — out of scope; gates enforce current `0.1.0` alignment
- **Doc-contract gates for every guide under `guides/`** — Only adoption-surface docs with known drift history; cheatsheet and flow guides not in GATE-01 matrix unless planning discovers gaps
- **Adding `verify.example` to default `mix ci`** — Explicitly rejected; keep fast local gate + named CI job
- **Engine/API changes** — Out of scope for v1.5 adoption surface

</deferred>

---

*Phase: 41-release-verification-gates*
*Context gathered: 2026-05-29*
