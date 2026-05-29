# Phase 42: Close gap DOCS-02/GATE-01 — Context

**Gathered:** 2026-05-29 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Close the v1.5 re-audit regressions for **DOCS-02** and **GATE-01**: restore semver truth across consumer-facing docs after `mix.exs` bumped to `@version "1.0.0"`, reconcile doc-contract drift logic so major-version bumps do not contradict alignment gates, and get the GATE-01 pre-ship quartet green.

In scope:
- Update `{:chimeway, "~> 1.0"}` in README, `guides/introduction/installation.md`, and `guides/introduction/golden-path.md`
- Reconcile `test/chimeway/doc_contract_test.exs` drift patterns for 1.x (dynamic `stale_drift_patterns/2` keyed off `mix.exs` major.minor)
- Fix `mix ci.docs` ex_doc relative-link warnings by converting out-of-package `../../examples/` and `../../chimeway_admin/` links to GitHub absolute URLs (Phase 36-03 precedent)
- Fix `examples/chimeway_demo_host/README.md` stale `ALLOW_DEMO_ADMIN` auth doc (OPER partial hygiene)
- Re-run and verify pre-ship quartet: `mix ci`, `mix ci.docs`, `mix ci.verify_gates`, `mix verify.example`

Out of scope: engine/API changes, new doc-contract describe blocks, Hex publish ceremony, Nyquist frontmatter fixes (phases 35/39 tech debt), read/unread workflow glue, new guides or recipes.

Depends on: Phase 41 (GATE-01 gates and quartet runbook already shipped; this phase closes the regression they correctly caught).

</domain>

<decisions>
## Implementation Decisions

### Phase boundary and success criteria
- **D-01:** Phase 42 succeeds when all four MAINTAINING.md pre-ship commands exit 0 — not merely `mix ci.verify_gates`. GATE-01 closure requires the full quartet green.
- **D-02:** Requirements satisfied: **DOCS-02** (consumer semver alignment) and **GATE-01** (doc-contract gates + pre-ship verification). Re-audit status update is a planning/execution deliverable, not a separate requirement.

### Version alignment (DOCS-02)
- **D-03:** Align the three gated consumer surfaces to `{:chimeway, "~> 1.0"}` matching `mix.exs` `@version "1.0.0"`: `README.md`, `guides/introduction/installation.md`, `guides/introduction/golden-path.md`.
- **D-04:** Use `~> MAJOR.MINOR` constraint form only — no patch-level `~> 1.0.0` in consumer docs (enforced by existing regex in doc-contract tests).

### Drift pattern reconciliation
- **D-05:** Replace static `@drift_patterns` that forbade `~> 1.0` at 0.x with dynamic `stale_drift_patterns(major, minor)` derived from `mix.exs` `@version` at test runtime.
- **D-06:** At `1.0.0`, forbid stale patterns: `{:chimeway, "~> 0.1"}`, literal `0.1.0`, and `{:chimeway, "~> 0.` prefix drift. At `0.x`, forbid premature `~> 1.0` / `1.0.0` drift (preserves Phase 41 D-06 intent across future minor bumps within a major).
- **D-07:** Keep alignment test dynamic: read `@version` from `mix.exs`, compute `{:chimeway, "~> #{major}.#{minor}"}`, assert presence in all three consumer files — do not hard-code `"1.0.0"` in assertions.

### ex_doc cross-package links (`mix ci.docs`)
- **D-08:** Convert remaining `../../examples/chimeway_demo_host/` and `../../chimeway_admin/` relative markdown links to GitHub absolute URLs using repo base `https://github.com/jonlunsford/chimeway` (same pattern as golden-path webhook appendix lines 174–175).
- **D-09:** Fix all four guides with `../../` cross-package links for consistency, not only the two currently failing `mix ci.docs`: `guides/introduction/golden-path.md`, `guides/recipes/password-reset-support-trace.md`, `guides/recipes/feedback-escalation-workflow.md`, `guides/flows/multi-step-journeys.md`.
- **D-10:** Do **not** add `examples/` or `chimeway_admin/` to `mix.exs` `:files` list — out-of-package paths are not Hex-publishable; GitHub URLs are the established fix.

### Demo host README auth doc
- **D-11:** Update `examples/chimeway_demo_host/README.md` Production auth section to remove stale `ALLOW_DEMO_ADMIN=true` escape hatch; document that `:prod` always returns `{:error, :unauthorized}` until host implements real `ChimewayAdmin.Auth` (Phase 40 behavior).

### Claude's Discretion
- Exact GitHub URL formatting (tree vs blob, anchor fragments for `#operator-trace-ui-browser`)
- Whether to add a brief CHANGELOG entry under `[Unreleased]` for doc-only alignment (no version bump in this phase)
- Order of plan waves (version/drift first vs link fixes first — both must land before final quartet verification)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Gap analysis and scope
- `.planning/milestones/v1.5-MILESTONE-AUDIT.md` — Root cause, verification commands, recommended closure (items 1–5)
- `.planning/ROADMAP.md` — Phase 42 insertion rationale (v1.5 gap closure)
- `.planning/STATE.md` — Current focus and deferred tech-debt table
- `.planning/milestones/v1.5-ROADMAP.md` — DOCS-02 and GATE-01 original acceptance criteria
- `.planning/milestones/v1.5-REQUIREMENTS.md` — Requirement definitions (archived with milestone)

### Prior phase handoffs
- `.planning/phases/41-release-verification-gates/41-CONTEXT.md` — GATE-01 gates, D-05/D-06 drift intent, quartet runbook
- `.planning/phases/41-release-verification-gates/41-VALIDATION.md` — Pre-existing `mix ci.docs` failure evidence
- `.planning/phases/36-golden-path-version-alignment/36-CONTEXT.md` — DOCS-02 original alignment; D-06/D-07 version SSOT
- `.planning/phases/36-golden-path-version-alignment/36-03-SUMMARY.md` — GitHub URL pattern for out-of-package ex_doc links
- `.planning/phases/40-operator-trace-mvp/40-CONTEXT.md` — Admin auth behavior; ALLOW_DEMO_ADMIN removal

### Doc-contract and version targets
- `test/chimeway/doc_contract_test.exs` — `consumer version alignment` describe; `stale_drift_patterns/2` helper
- `mix.exs` — `@version "1.0.0"`; `ci.verify_gates`, `ci.docs` aliases
- `README.md` — Consumer dep constraint
- `guides/introduction/installation.md` — Consumer dep constraint
- `guides/introduction/golden-path.md` — Consumer dep + cross-package links (§6 + webhook appendix)
- `guides/recipes/password-reset-support-trace.md` — Cross-package demo host links
- `guides/recipes/feedback-escalation-workflow.md` — Cross-package E2E test link
- `guides/flows/multi-step-journeys.md` — Cross-package E2E test link

### Release runbook and example surfaces
- `MAINTAINING.md` — Pre-ship quartet (step 3)
- `examples/chimeway_demo_host/README.md` — Stale ALLOW_DEMO_ADMIN doc; operator trace UI anchor target

### Methodology
- `.planning/METHODOLOGY.md` — Least-Surprise DX Default, Research-First Decision Ownership

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `test/chimeway/doc_contract_test.exs` — Dynamic alignment test + `stale_drift_patterns/2` already drafted in working tree; `mix ci.verify_gates` green (86 tests)
- `guides/introduction/golden-path.md` lines 174–175 — Working GitHub URL pattern for `examples/chimeway_demo_host/` and E2E test
- `mix.exs` `source_url` / `links` — Canonical GitHub repo base for absolute URLs

### Established Patterns
- Doc-contract: static forbidden/required strings per guide + dynamic version alignment describe (Phase 41)
- ex_doc `--warnings-as-errors`: files outside Hex `:files` list must use GitHub URLs, not `../../` relative paths (Phase 36-03)
- `mix.exs` `@version` is SSOT for consumer `~> MAJOR.MINOR` constraint — drift patterns invert by major version
- GATE-01 quartet is four separate commands; `ci.verify_gates` is scoped to `doc_contract_test.exs` only (Phase 41 D-14)

### Integration Points
- Three consumer docs → doc-contract alignment + drift tests
- Four guides with `../../` links → `mix ci.docs` warnings-as-errors
- `examples/chimeway_demo_host/README.md` → OPER partial audit item; no gate test but audit closure hygiene
- Re-audit artifact `.planning/milestones/v1.5-MILESTONE-AUDIT.md` → update status after quartet green

</code_context>

<specifics>
## Specific Ideas

- User confirmed all assumptions without corrections (assumptions mode, 2026-05-29)
- Uncommitted working-tree changes already implement D-03 through D-07 and D-11 partially — planning should treat these as the intended direction, not re-invent
- Remaining blocker for quartet: `mix ci.docs` (10 ex_doc relative-link warnings in golden-path + password-reset recipe)

</specifics>

<deferred>
## Deferred Ideas

- **Nyquist frontmatter fixes** (phases 35/39 `nyquist_compliant: false`) — tech debt; separate validate-phase work
- **Hex 1.0.0 publish ceremony** — version is already 1.0.0 in mix.exs; coordinated publish/CHANGELOG is out of scope unless explicitly added
- **Doc-contract gates for every guide under `guides/`** — only adoption-surface + cross-link fixes needed for closure
- **Full fresh-Phoenix-host UAT automation** — deferred from Phase 41
- **Engine/API changes** — out of scope

None — analysis stayed within phase scope beyond noted audit hygiene (demo README).

</deferred>

---

*Phase: 42-close-gap-docs-02-gate-01-align-consumer-docs-to-1-0-0-and-f*
*Context gathered: 2026-05-29*
