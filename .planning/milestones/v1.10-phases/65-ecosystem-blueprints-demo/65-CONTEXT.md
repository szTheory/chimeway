# Phase 65: Ecosystem Blueprints & Demo - Context

**Gathered:** 2026-05-30 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Adopters can copy published Threadline and Sigra reference recipes and see the same behaviour proven on the demo host.

**In scope:**
- `guides/recipes/sigra-auth-blueprint.md` — Sigra auth reference blueprint (ECOS-10)
- `test/chimeway/doc_contract_test.exs` ECOS-10 `describe` block — CI doc-contract for blueprint truth
- `guides/recipes/sigra-auth-blueprint.md` added to `mix.exs` HexDocs extras
- `examples/chimeway_demo_host/test/demo_host_web/threadline_telemetry_proof_test.exs` — DEMO-09 proof
- `examples/chimeway_demo_host/test/demo_host_web/sigra_auth_proof_test.exs` — DEMO-10 proof
- `DemoHost.Seeds.seed_threadline_*` and `DemoHost.Seeds.seed_sigra_*` seed helpers for demo proofs

**Out of scope (Phase 66):** Golden-path integration guides (DOCS-10), guide doc-contract tests (DOCS-11), `mix verify.threadline` / `mix verify.sigra` CI gates + MAINTAINING checklist (GATE-07).

**Depends on:** Phase 63 (Chimeway.Telemetry.ThreadlineReporter shipped), Phase 64 (Sigra.Integrations.Chimeway with magic_link + confirmation_code dispatch shipped)

**Requirements:** ECOS-10, DEMO-09, DEMO-10
</domain>

<decisions>
## Implementation Decisions

### Blueprint Document Shape
- **D-01:** The Sigra auth reference blueprint (`guides/recipes/sigra-auth-blueprint.md`) follows the exact structure of `guides/recipes/accrue-dunning-blueprint.md` — sections: "Who this is for," responsibility split (Chimeway orchestrates when/why; Sigra owns auth state), notifier authoring code example for `sigra.auth.magic_link` and `sigra.auth.confirmation_code`, adopter wiring config, `Chimeway.trigger/3` call with `idempotency_key` + `tenant_id`, runnable demo pointer (`DemoHost.Seeds.seed_sigra_*`), and a reciprocal cross-link to the forthcoming Phase 66 `sigra-auth-integration.md` guide.
- **D-02:** Responsibility split language mirrors Accrue blueprint: "Chimeway orchestrates the when and why; Sigra owns auth state, token generation, and rate limits." Explicit callout that Phase 65 is NOT a `Chimeway.Adapter` delivery seam — it is a trigger bridge only.

### Demo Host Proof Structure
- **D-03:** Both demo proofs are separate test files in `examples/chimeway_demo_host/test/demo_host_web/`:
  - `threadline_telemetry_proof_test.exs` — `@moduletag :threadline`, proves Chimeway notification lifecycle event → Threadline `audit_actions` row with `correlation_id`, operator trace inspectability at `/admin/chimeway`
  - `sigra_auth_proof_test.exs` — `@moduletag :sigra`, proves Sigra auth event → Chimeway trigger → durable delivery attempt, operator trace inspectability
- **D-04:** Both proof files are guarded with `Code.ensure_loaded?/1` wrapping the entire module (Accrue proof precedent). Both use `ConnCase, async: false` + `Oban.Testing` + `DemoHost.Seeds.*` as the trigger entry point — mirroring `accrue_dunning_proof_test.exs` exactly.
- **D-05:** `DemoHost.Seeds` gets dedicated seed helpers: `seed_threadline_notification/0` (triggers a notification while ThreadlineReporter is attached, proves audit row creation) and `seed_sigra_auth/0` (triggers magic link or confirmation code flow, proves Chimeway delivery attempt). These are the "runnable demo" pointers in both the blueprint doc and the doc-contract required strings.
- **D-06:** Demo proofs include a `/admin/chimeway` LiveView search assertion to prove operator trace inspectability (same as DEMO-07 Accrue proof lines 95–124).

### Doc-Contract Coverage (ECOS-10)
- **D-07:** ECOS-10 doc-contract is a new `describe "ECOS-10 sigra auth blueprint"` block appended to `test/chimeway/doc_contract_test.exs` (not a separate file) — mirrors ECOS-05 (Mailglass, line ~247) and ECOS-07 (Accrue, line ~297) patterns.
- **D-08:** Required strings in ECOS-10 doc-contract: `Sigra.Integrations.Chimeway`, `sigra.auth.magic_link`, `sigra.auth.confirmation_code`, `Chimeway.trigger`, `idempotency_key`, `tenant_id`, `orchestrates`, `DemoHost.Seeds.seed_sigra`, `/admin/chimeway`, `sigra-auth-integration.md` (reciprocal cross-link to Phase 66 guide).
- **D-09:** `guides/recipes/sigra-auth-blueprint.md` is added to `mix.exs` HexDocs extras in Phase 65 (alongside the existing blueprint entries) so the existing HexDocs extras contract test (lines ~851–901) catches omissions immediately.

### Claude's Discretion
- Exact seed helper names (`seed_sigra_auth/0` vs `seed_sigra_magic_link/0` etc.) — any stable name that the blueprint and doc-contract can agree on.
- Whether the Threadline demo proof uses an existing notifier (e.g. `teampulse.invite_sent`) or a new minimal notifier — either works as long as a Threadline `audit_actions` row with `correlation_id` is proven.
- Whether `sigra-auth-blueprint.md` is `guides/recipes/sigra-auth-blueprint.md` or uses a slightly different slug.
- Exact forbidden phrases in ECOS-10 doc-contract (Phase 64 D-07 redaction language to forbid: raw token, confirmation code verbatim).
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

| Ref | Path | Why |
|-----|------|-----|
| Phase goal | `.planning/ROADMAP.md` (Phase 65) | Success criteria, scope boundary vs Phase 66 |
| Requirements | `.planning/REQUIREMENTS.md` (ECOS-10, DEMO-09, DEMO-10) | Locked acceptance criteria |
| Phase 64 context | `.planning/phases/64-sigra-auth-flows-core/64-CONTEXT.md` | Sigra integration seam decisions (D-01..D-12) — what Phase 65 builds on top of |
| Phase 63 context | `.planning/phases/63-threadline-telemetry-bridge/63-CONTEXT.md` | ThreadlineReporter attach pattern, deferred verify gate |
| Accrue blueprint template | `guides/recipes/accrue-dunning-blueprint.md` | Document structure template for Sigra blueprint |
| Mailglass blueprint template | `guides/recipes/mailglass-integration-blueprint.md` | Second blueprint reference for doc structure |
| Accrue demo proof template | `examples/chimeway_demo_host/test/demo_host_web/accrue_dunning_proof_test.exs` | Demo proof test structure (DEMO-07 → DEMO-09/10) |
| Doc-contract test | `test/chimeway/doc_contract_test.exs` | ECOS-05/07 describe blocks as ECOS-10 template |
| Demo seeds | `examples/chimeway_demo_host/lib/demo_host/seeds.ex` | Seed helper pattern for demo proof entry points |
| mix.exs | `mix.exs` | HexDocs extras list, ci.test excludes, verify.* alias shapes |
| Demo host router | `examples/chimeway_demo_host/lib/demo_host_web/router.ex` | Existing routes + admin mount for trace inspectability |
| Threadline integration test | `test/chimeway/integrations/threadline_telemetry_lifecycle_test.exs` | Core lifecycle already proven — demo proof layers UI on top |
| Sigra integration test | `test/chimeway/integrations/sigra_auth_lifecycle_test.exs` | Core lifecycle already proven — demo proof layers UI on top |
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`guides/recipes/accrue-dunning-blueprint.md`** — copy/adapt for Sigra auth blueprint structure; responsibility-split language, notifier code block, trigger example, demo pointer, guide cross-link all reusable.
- **`examples/chimeway_demo_host/test/demo_host_web/accrue_dunning_proof_test.exs`** — copy/adapt for both DEMO-09 and DEMO-10; every structural choice (module guard, tag, ConnCase, Oban.Testing, Seeds trigger, admin LiveView assertion) is directly reusable.
- **`test/chimeway/doc_contract_test.exs`** lines ~247 (ECOS-05) and ~297 (ECOS-07) — describe block format is the ECOS-10 template.
- **`examples/chimeway_demo_host/lib/demo_host/seeds.ex`** — `seed_accrue_dunning/0` pattern for new `seed_threadline_notification/0` and `seed_sigra_auth/0` helpers.

### Established Patterns
- Blueprint structure: "Who this is for," responsibility split, notifier authoring code, adopter config wiring, trigger example, runnable demo pointer, cross-link to integration guide.
- Demo proof: `Code.ensure_loaded?` guard → `@moduletag :ecosystem` → ConnCase + Oban.Testing → `DemoHost.Seeds.*` trigger → `/admin/chimeway` LiveView assertion.
- Doc-contract: `describe "ECOS-XX"` block with `@blueprint_path`, `@required_strings`, `@forbidden_phrases` — appended to existing `doc_contract_test.exs`.
- HexDocs extras: blueprint file added to `mix.exs` extras list alongside existing blueprint entries.

### Integration Points
- `Chimeway.Telemetry.ThreadlineReporter` — needs to be attached in demo host `Application.start/2` for Threadline demo proof (mirrors how demo host configures Oban and adapters).
- `Sigra.Integrations.Chimeway` — called by seed helpers for Sigra demo proof; `SIGRA_PATH` env override for local dev (Phase 64 selective CI pattern).
- `/admin/chimeway` LiveView search — existing Chimeway admin already mounted in demo host router; no new route needed for trace inspectability assertions.
</code_context>

<specifics>
## Specific Ideas

No user corrections — all assumptions confirmed as presented.

**Blueprint scope confirmed:** Sigra blueprint covers both `sigra.auth.magic_link` and `sigra.auth.confirmation_code` flows (both Phase 64 flows), with the responsibility split callout that Chimeway orchestrates orchestration timing and Sigra owns token/auth state.
</specifics>

<deferred>
## Deferred Ideas

- **Golden-path Sigra auth integration guide** — Phase 66 DOCS-10.
- **Sigra guide doc-contract tests** — Phase 66 DOCS-11.
- **`mix verify.sigra` + `mix verify.threadline` CI gates** — Phase 66 GATE-07.
- **MAINTAINING.md pre-ship checklist entries for Threadline/Sigra** — Phase 66.

### Reviewed Todos (not folded)

No pending todos matched Phase 65 scope.
</deferred>
