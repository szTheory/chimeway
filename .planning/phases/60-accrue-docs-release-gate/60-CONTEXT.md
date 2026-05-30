# Phase 60: Accrue Docs & Release Gate - Context

**Gathered:** 2026-05-30 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Accrue dunning integration is documented end-to-end, contract-tested against doc drift, and gated in the release checklist and CI alongside existing journey/mailglass verify entrypoints.

**In scope:** Golden-path Accrue dunning integration guide (DOCS-08), guide doc-contract tests (DOCS-09), formal `mix verify.accrue` CI job + MAINTAINING.md pre-ship update (GATE-05 Accrue half only).

**Out of scope (later phases):** Inbox golden-path guide, inbox doc-contract, `mix verify.inbox` CI (Phase 62 DOCS-08/09 + GATE-05 inbox half), Threadline/Sigra ecosystem slices, changes to Accrue/Chimeway dunning core behavior (Phases 58–59).

**Depends on:** Phase 59 (blueprint + demo proof shipped; `mix verify.accrue` alias already spans root + demo host).

**Requirements:** DOCS-08 (Accrue), DOCS-09 (Accrue), GATE-05 (Accrue)
</domain>

<decisions>
## Implementation Decisions

### Delivery order (ROADMAP waves)
- **D-01:** Follow ROADMAP wave order — **60-01 guide (DOCS-08)** and **60-03 GATE-05** may run in parallel in Wave 1; **60-02 doc-contract (DOCS-09)** is blocked on 60-01 (guide file must exist before contract tests).
- **D-02:** Phase 60 is documentation + release-gate only — no new ECOS-06/DEMO-07 proof tests; reuse Phase 58–59 artifacts as runnable references in the guide.

### Golden-path guide (DOCS-08)
- **D-03:** New canonical guide at **`guides/introduction/accrue-dunning-integration.md`** — parallel naming/location to `guides/introduction/mailglass-integration.md`.
- **D-04:** Guide skeleton mirrors Mailglass introduction structure: (1) dependencies (Chimeway + Accrue), (2) database/migrations (Chimeway spine + Accrue repo per Accrue docs), (3) runtime config (`config :accrue, dunning: [engine: Accrue.Integrations.Chimeway]`), (4) DunningNotifier / `workflow/2` reference (Accrue repo module, not host glue), (5) billing-event trigger path (`invoice.payment_failed` start / `invoice.paid` terminate via Accrue events — **not** direct host `Chimeway.trigger/3` as primary story), (6) verification (`mix verify.accrue`, `/admin/chimeway` operator trace, `DemoHost.Seeds.seed_accrue_dunning/0`), (7) optional Mailglass email cross-link, (8) related guides.
- **D-05:** Guide owns the **end-to-end adoption path**; blueprint stays focused recipe — update reciprocal cross-links: replace Phase 60 placeholder in `guides/recipes/accrue-dunning-blueprint.md` with link to the new guide (mirror Phase 57 D-02 / Mailglass blueprint ↔ guide separation).
- **D-06:** Minimal email path in guide uses **Logger adapter** for self-contained proof (Phase 59 D-06); optional section points to [Mailglass integration blueprint](../recipes/mailglass-integration-blueprint.md) when hosts want Mailglass delivery for dunning email steps (Phase 58 D-07).
- **D-07:** Guide documents **Outcome Signal** product language: canonical `invoice.paid` + `cancel_signals: ["invoice.paid"]` termination — forbid deprecated `payment_recovered` phrasing in guide text.
- **D-08:** Add README adoption-docs link for the new guide (mirror existing Mailglass integration guide entry in `README.md`).

### Doc-contract (DOCS-09)
- **D-09:** Add **`accrue dunning integration guide doc contract (DOCS-08 / DOCS-09)`** describe block in `test/chimeway/doc_contract_test.exs` — parallel to `mailglass integration guide doc contract (DOCS-06 / DOCS-07)`.
- **D-10:** Reuse shared **`@recipe_forbidden_strings`** and fictional-module guard (`Chimeway.Workflow` regex) from existing doc-contract describes.
- **D-11:** Required strings (minimum): `Accrue.Integrations.Chimeway`, `invoice.payment_failed`, `invoice.paid`, `cancel_signals`, `workflow/2`, `config :accrue`, `dunning`, `idempotency_key`, `tenant_id`, orchestration/billing-state split language, `mix verify.accrue`, `DemoHost.Seeds.seed_accrue_dunning`, `/admin/chimeway`, `ACCRUE_PATH` (or equivalent sibling-checkout note). Guide-specific additions over blueprint contract: end-to-end section coverage (deps/migrations/config/trigger/verify).
- **D-12:** Forbid `payment_recovered` in guide (align ECOS-06 canonical signal naming); no requirement to document `Chimeway.Adapter` seam (integration is engine + workflow + Signal only).

### Release gate (GATE-05 Accrue half)
- **D-13:** Add **`verify_accrue`** job to `.github/workflows/ci.yml` mirroring `verify_mailglass` (Postgres service, deps.get, ecto create/migrate, `mix verify.accrue`).
- **D-14:** CI must **checkout sibling Accrue repo** before `mix verify.accrue` — hex `{:accrue, "~> 1.2"}` alone does not ship `Accrue.Integrations.Chimeway` integration module. Set `ACCRUE_PATH` to checked-out path; pin ref (tag/SHA) in workflow — document maintainer expectation in MAINTAINING.md (addresses 59-REVIEW IN-03 hardcoded path concern for CI, not local alias).
- **D-15:** **`mix verify.accrue` alias unchanged** in scope unless CI discovery requires env normalization — Phase 59 already wires root + demo host with `CHIMEWAY_SKIP_ACCRUE_DEP` cycle-break; formalization is CI + docs, not alias redesign.
- **D-16:** Update **`MAINTAINING.md`** pre-ship block: add `mix verify.accrue` command + one-line description (GATE-05 Accrue); update checklist count **six → seven** gates; Accrue half of GATE-05 only (`mix verify.inbox` deferred Phase 62).

### Claude's Discretion
- Exact Accrue GitHub checkout coordinates and pinned SHA in CI workflow (planner resolves org/repo from maintainer input or existing `ACCRUE_PATH` convention `../accrue/accrue`).
- Guide section numbering/titles and copy-paste snippet depth (must satisfy doc-contract required strings).
- Whether doc-contract adds Mailglass-optional cross-link as required vs recommended-only string.
- README / `guides/recipes/accrue-dunning-blueprint.md` cross-link wording updates beyond minimum reciprocal link.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

| Ref | Path | Why |
|-----|------|-----|
| Phase goal | `.planning/ROADMAP.md` (Phase 60) | Success criteria, waves 60-01..03 |
| Requirements | `.planning/REQUIREMENTS.md` (DOCS-08, DOCS-09, GATE-05 Accrue) | Locked acceptance |
| Phase 59 context | `.planning/phases/59-accrue-blueprint-demo/59-CONTEXT.md` | Deferred guide/gate scope; demo patterns |
| Phase 58 context | `.planning/phases/58-accrue-dunning-core/58-CONTEXT.md` | ECOS-06 signal naming, engine config |
| Mailglass guide template | `guides/introduction/mailglass-integration.md` | DOCS-08 structure + section depth template |
| Mailglass doc-contract | `test/chimeway/doc_contract_test.exs` (DOCS-06/07 describe) | DOCS-09 describe template |
| Accrue blueprint | `guides/recipes/accrue-dunning-blueprint.md` | ECOS-07 recipe; cross-link target |
| Accrue blueprint doc-contract | `test/chimeway/doc_contract_test.exs` (ECOS-07 describe) | Required/forbidden baseline for guide contract |
| Demo proof | `examples/chimeway_demo_host/test/demo_host_web/accrue_dunning_proof_test.exs` | Runnable verification references |
| Demo seeds | `examples/chimeway_demo_host/lib/demo_host/seeds.ex` | `seed_accrue_dunning/0` pointer |
| Verify aliases | `mix.exs` (`verify.accrue`, `verify.mailglass`, `ci.test` excludes) | GATE-05 alias baseline |
| CI mailglass job | `.github/workflows/ci.yml` (`verify_mailglass`) | GATE-05 CI job template |
| MAINTAINING pre-ship | `MAINTAINING.md` | Checklist sextet → septet update |
| Guide vs blueprint separation | `.planning/STATE.md` (Phase 57 D-02) | Prevents introduction/recipe drift |
| README adoption links | `README.md` | DOCS-08 discoverability |
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`guides/introduction/mailglass-integration.md`** — canonical golden-path template (deps → config → trigger → verify → optional inbound → related).
- **`guides/recipes/accrue-dunning-blueprint.md`** — ECOS-07 focused recipe; out-of-scope section already points to Phase 60 guide.
- **`test/chimeway/doc_contract_test.exs`** — ECOS-07 blueprint describe + DOCS-06/07 mailglass guide describe patterns.
- **`mix verify.accrue`** — 11 root + 3 demo `:accrue` tests (Phase 59); alias includes `deps.compile accrue --force` and demo-host env cycle-break.
- **`MAINTAINING.md`** — six-gate pre-ship checklist; mailglass/journeys entries are copy templates for accrue entry.

### Established Patterns
- **Guide vs blueprint separation:** Introduction guide owns end-to-end path; recipe owns copy-paste notifier/config sections (Phase 57 D-02, 59 D-12).
- **Doc-contract truth lock:** `@required` string list + `@recipe_forbidden_strings` + fictional-module regex per markdown artifact.
- **Selective CI:** `verify.*` jobs are separate workflow jobs with Postgres; not bundled in default `ci` job.
- **Accrue sibling dep:** Local/CI proof requires `ACCRUE_PATH` path dep — integration module lives in Accrue repo, not hex-only artifact.

### Integration Points
- **Guide → blueprint:** Prerequisites + "for copy-paste sections see blueprint" reciprocal links.
- **Guide → demo:** `DemoHost.Seeds.seed_accrue_dunning/0`, `mix verify.accrue`, `/admin/chimeway` trace search.
- **Doc-contract → guide file:** `@accrue_integration_guide Path.expand(...)` pattern matching mailglass guide constant.
- **CI → verify.accrue:** New job runs existing alias after Accrue repo checkout.
- **MAINTAINING → CI:** Pre-ship command list must match CI jobs adopters/maintainers run locally.
</code_context>

<specifics>
## Specific Ideas

- ROADMAP success criterion #3: new gate must not break existing journey/mailglass verify jobs — accrue job is additive.
- Phase 59 verification: `ACCRUE_PATH=../accrue/accrue mix verify.accrue` is the local maintainer command; CI must make that reproducible without manual sibling checkout.
- Product language "Outcome Signal" = durable `invoice.paid` satisfying `cancel_signals` on dunning waits (carry forward from Phases 58–59).
</specifics>

<deferred>
## Deferred Ideas

- **`mix verify.inbox` CI job + inbox golden-path guide** — Phase 62 (GATE-05 inbox half, DOCS-08/09 inbox).
- **Accrue admin UI showing Chimeway dunning state** — SEED-003 bidirectional win; out of Chimeway repo scope.
- **Normalize `verify.accrue` hardcoded `../../../accrue/accrue` paths** — optional polish if CI checkout strategy supersedes (59-REVIEW IN-03); not required for Phase 60 acceptance.
- **Combined Mailglass + Accrue single demo narrative** — couples two ecosystem lanes; defer.

None — analysis stayed within phase scope.
</deferred>
