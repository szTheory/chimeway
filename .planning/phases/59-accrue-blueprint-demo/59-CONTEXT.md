# Phase 59: Accrue Blueprint & Demo - Context

**Gathered:** 2026-05-30 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Adopters can copy a published Accrue + Chimeway dunning reference recipe and see the same behaviour proven on the demo host with operator trace inspectability at `/admin/chimeway`.

**In scope:** Demo host Accrue dunning end-to-end proof (DEMO-07), Accrue dunning blueprint recipe with ECOS-07 doc-contract, selective `:accrue` CI extension to demo host, adopter-copyable demo seeds entry point.

**Out of scope (later phases):** Golden-path Accrue integration guide (Phase 60 DOCS-08), doc-contract for guide (Phase 60 DOCS-09), `mix verify.accrue` CI job + MAINTAINING formalization (Phase 60 GATE-05), Threadline/Sigra ecosystem slices.

**Depends on:** Phase 58 (ECOS-06 dunning core — workflow start + `invoice.paid` termination).

**Requirements:** ECOS-07, DEMO-07
</domain>

<decisions>
## Implementation Decisions

### Delivery order (ROADMAP waves)
- **D-01:** Follow ROADMAP wave order — **demo host proof first** (59-01 / DEMO-07), then **blueprint recipe + ECOS-07 doc-contract** (59-02). Demo must exist before blueprint references runnable proof.
- **D-02:** Phase 58 library integration tests remain the ECOS-06 spine; Phase 59 adds demo-host + recipe layers only — no duplicate lifecycle proof in Chimeway root tests.

### Demo proof architecture (DEMO-07)
- **D-03:** Demo host Accrue proof mirrors Mailglass selective-CI pattern: `@moduletag :accrue` isolated from `:journey` suite (journey keeps default Logger adapter; Accrue lane does not regress JOUR-01..08).
- **D-04:** Extend `mix verify.accrue` to run **both** root `:accrue` tests and demo host `:accrue` tests — parallel to `mix verify.mailglass` (root + demo host). Formal CI job + MAINTAINING checklist entry deferred to Phase 60 GATE-05.
- **D-05:** Demo triggers dunning via **Accrue billing events** (`Accrue.Test.trigger_event/2` or equivalent public Accrue API) — not direct `Chimeway.trigger/3` or host webhook callback glue. Preserves ECOS-06 "no host glue" adoption story.
- **D-06:** Demo dunning email steps use **Logger adapter** (`configure_chimeway_logger_adapter!/0` pattern from Phase 58 fixtures) — not Mailglass. Keeps Accrue proof self-contained without dual Mailglass+Accrue sandbox complexity.
- **D-07:** Demo proof asserts **escalation path**: failed payment → initial email delivery → `:waiting` with `pending_signals: ["invoice.paid"]` → paid invoice terminates via Outcome Signal before escalation email fires.
- **D-08:** Operator trace proof at `/admin/chimeway` shows `accrue.dunning` workflow progression and explainable transitions (including `signal_received` on `invoice.paid`) — parallel to JOUR-08 Morgan escalation + Mailglass DEMO-06 admin trace tests.

### Demo host wiring
- **D-09:** Demo host gains Accrue dependency (path dep via `ACCRUE_PATH` env or sibling path — mirror root `mix.exs` `accrue_dep/0`) plus Accrue TestRepo bootstrap in demo host `test/test_helper.exs` (parallel to existing Mailglass TestRepo bootstrap).
- **D-10:** Add **`DemoHost.Seeds.seed_accrue_dunning/0`** as adopter-copyable public API — uses Accrue event triggers, not internal fixture inserts. Follows existing `seed_invite/0` / `seed_escalation_waiting/0` pattern.

### Blueprint recipe (ECOS-07)
- **D-11:** New focused recipe at **`guides/recipes/accrue-dunning-blueprint.md`** — parallel structure to `mailglass-integration-blueprint.md`. Documents: Feature Developer notifier authoring (`DunningNotifier.workflow/2`, `cancel_signals: ["invoice.paid"]`), Adopter Accrue engine config (`config :accrue, dunning: [engine: Accrue.Integrations.Chimeway]`), event subscription (`invoice.payment_failed` start / `invoice.paid` terminate), and **Chimeway orchestrates when/why vs Accrue owns billing state** responsibility split (SEED-003).
- **D-12:** Blueprint **does not** duplicate the full golden-path integration guide — out-of-scope section points to Phase 60 DOCS-08 guide (mirror Mailglass blueprint → integration guide separation from Phase 57 D-02).
- **D-13:** Blueprint includes reciprocal cross-links to Mailglass blueprint where email delivery is optional (Phase 58 D-07) and to Phase 60 golden-path guide placeholder.
- **D-14:** Runnable references cite **`Accrue.Integrations.Chimeway.DunningNotifier`** (sibling Accrue repo) and demo host seeds — not fictional modules.

### Doc-contract (ECOS-07)
- **D-15:** Add **`accrue dunning blueprint recipe doc contract (ECOS-07)`** describe block to `test/chimeway/doc_contract_test.exs` — mirror ECOS-05 mailglass blueprint pattern: `@required` strings + `@forbidden` drift guards + fictional-module regex checks.
- **D-16:** Required doc-contract strings (minimum): `Accrue.Integrations.Chimeway`, `invoice.payment_failed`, `invoice.paid`, `cancel_signals`, `workflow/2`, `config :accrue`, `dunning`, `idempotency_key`, `tenant_id`, orchestration/billing-state split language, `DemoHost.Seeds.seed_accrue_dunning` (or chosen seed function name), `/admin/chimeway`.

### Claude's Discretion
- Exact blueprint filename slug if `accrue-dunning-blueprint.md` vs `accrue-dunning-integration-blueprint.md` — prefer shorter parallel to mailglass.
- Demo host Accrue customer/subscription fixture shape (reuse Phase 58 fixtures vs demo-specific tenant).
- Admin trace assertion depth (workflow run search vs delivery-only search) — must satisfy ROADMAP SC #3 operator inspectability.
- Whether `seed_accrue_dunning/0` joins `DemoHost.Seeds.run/0` or stays standalone (avoid breaking existing journey idempotency).
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

| Ref | Path | Why |
|-----|------|-----|
| Phase goal | `.planning/ROADMAP.md` (Phase 59) | Success criteria, waves 59-01..02 |
| Requirements | `.planning/REQUIREMENTS.md` (ECOS-07, DEMO-07) | Locked acceptance for recipe + demo proof |
| Phase 58 context | `.planning/phases/58-accrue-dunning-core/58-CONTEXT.md` | Dunning core decisions, deferred demo/recipe scope |
| Phase 58 verification | `.planning/phases/58-accrue-dunning-core/58-VERIFICATION.md` | ECOS-06 evidence baseline demo must not re-prove |
| SEED-003 Accrue slice | `.planning/seeds/SEED-003-ecosystem-integrations.md` | Dunning blueprint intent (48h escalation, billing-state split) |
| Accrue ↔ Chimeway engine | `../accrue/accrue/lib/accrue/integrations/chimeway.ex` | `DunningNotifier.workflow/2`, `start_campaign/3`, `cancel_campaign/3` |
| Accrue lifecycle tests | `test/chimeway/integrations/accrue_dunning_lifecycle_test.exs` | Event trigger + termination proof pattern to mirror in demo |
| Accrue test fixtures | `test/support/accrue/fixtures.ex` | Engine config, Logger adapter, event trigger helpers |
| Mailglass blueprint template | `guides/recipes/mailglass-integration-blueprint.md` | ECOS-05 recipe structure, out-of-scope guide separation |
| Mailglass demo proof | `examples/chimeway_demo_host/test/demo_host_web/mailglass_delivery_proof_test.exs` | DEMO-06 `@moduletag :mailglass` + admin trace pattern |
| Mailglass doc-contract | `test/chimeway/doc_contract_test.exs` (ECOS-05 describe) | ECOS-07 doc-contract template |
| Demo seeds API | `examples/chimeway_demo_host/lib/demo_host/seeds.ex` | Adopter-copyable seed pattern |
| Demo host test bootstrap | `examples/chimeway_demo_host/test/test_helper.exs` | Mailglass TestRepo pattern to replicate for Accrue |
| Admin trace tests | `examples/chimeway_demo_host/test/demo_host_web/admin_trace_live_test.exs` | JOUR-07/08 operator trace assertion patterns |
| Verify aliases | `mix.exs` (`verify.accrue`, `verify.mailglass`) | Selective CI lane extension pattern |
| Guide vs blueprint separation | `.planning/STATE.md` (Phase 57 D-02) | Blueprint focused; golden-path guide is Phase 60 |
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`Accrue.Integrations.Chimeway.DunningNotifier`** — shipped workflow/2 with 48h wait + `cancel_signals: ["invoice.paid"]` (Phase 58).
- **`Chimeway.TestSupport.AccrueFixtures`** — customer/subscription/invoice helpers, `trigger_invoice_payment_failed_event!/4`, `trigger_invoice_paid_event!/4`, progression helpers.
- **`DemoHost.Seeds`** — deterministic idempotent trigger API for journey/demo proof.
- **`DemoHostWeb.MailglassDeliveryProofTest`** — selective tag + admin LiveView trace search template.
- **`doc_contract_test.exs` ECOS-05 block** — required/forbidden string guards for blueprint recipes.

### Established Patterns
- **Selective CI tags:** `@moduletag :accrue` / `:mailglass` excluded from default `ci.test`; dedicated `mix verify.*` aliases.
- **Not an adapter:** Accrue integration is workflow + Signal bridge only — no `Chimeway.Adapter` seam (Phase 58 D-01).
- **Guide vs blueprint separation:** Introduction guide owns end-to-end path; blueprint is focused recipe with cross-links (Phase 57 D-02).
- **Demo host path deps:** chimeway + chimeway_admin + mailglass; Accrue not yet wired.
- **Adopter-copyable seeds:** Public API uses triggers/events, not test fixture inserts (v1.6 decision).

### Integration Points
- **Accrue → Chimeway start:** `invoice.payment_failed` → `Accrue.Integrations.Chimeway.start_campaign/3` → `Chimeway.trigger/3`.
- **Accrue → Chimeway stop:** `invoice.paid` → `cancel_campaign/3` → `Chimeway.Signal.track/4` with `event_name: "invoice.paid"`.
- **Demo host → admin:** `/admin/chimeway` LiveView trace search by recipient identity / workflow run.
- **Blueprint → demo:** Runnable `DemoHost.Seeds.seed_accrue_dunning/0` pointer for local proof.
- **verify.accrue → demo host:** Extend alias to `cd examples/chimeway_demo_host && mix test --only accrue`.
</code_context>

<specifics>
## Specific Ideas

- Product language "Outcome Signal" = durable **`invoice.paid`** signal satisfying `cancel_signals` on active dunning waits (Phase 58 D-08/D-09).
- SEED-003 escalation shape: Email 1 → wait 48h → Email 2 — already implemented in `DunningNotifier.workflow/2`; demo and blueprint document this shape.
- Operator must see explainable suppression/delivery decisions — not just workflow state (ROADMAP SC #3).
- Mailglass remains optional for email delivery in production hosts; demo uses Logger adapter for Accrue lane isolation.
</specifics>

<deferred>
## Deferred Ideas

- **Golden-path Accrue integration guide** — Phase 60 (DOCS-08).
- **Guide doc-contract + forbidden phrase guards** — Phase 60 (DOCS-09).
- **`mix verify.accrue` CI job + MAINTAINING pre-ship checklist** — Phase 60 (GATE-05 formalization); Phase 59 extends alias only.
- **Accrue admin UI displaying active Chimeway dunning state** — SEED-003 bidirectional win; out of Chimeway repo scope.
- **Mailglass + Accrue combined demo** — would couple two ecosystem lanes; defer unless explicitly requested.

None — analysis stayed within phase scope.
</deferred>
