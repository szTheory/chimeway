# Phase 57: Docs & Release Gates - Context

**Gathered:** 2026-05-29 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Mailglass integration is documented, contract-tested, and gated in the release checklist alongside existing verify entrypoints. This phase delivers DOCS-06 (golden-path integration guide), DOCS-07 (guide doc-contract tests), and GATE-04 (`mix verify.mailglass` CI gate + MAINTAINING.md pre-ship checklist).

**Requirements:** DOCS-06, DOCS-07, GATE-04

**Success criteria (from ROADMAP):**
1. Golden-path integration guide walks a fresh host from dependency → config → trigger → Mailglass delivery → optional inbound feedback
2. Doc-contract tests fail if guide text regresses to pre-Mailglass assumptions or omits required setup steps
3. `mix verify.mailglass` runs in CI and appears in MAINTAINING.md pre-ship checklist without breaking the existing journey/doc gate quintet

**Out of scope:** Accrue/Threadline/Sigra blueprints (v1.9+), INBX bell UI, broad channel matrix, wiring all TeamPulse notifiers through Mailglass, global demo host Mailglass config in default test path (journey isolation preserved).
</domain>

<decisions>
## Implementation Decisions

### Integration guide location and shape (DOCS-06)
- **D-01:** Publish the golden-path Mailglass integration guide at `guides/introduction/mailglass-integration.md` — parallel to `guides/introduction/golden-path.md`, not folded into the blueprint recipe or Chimeway-only golden path.
- **D-02:** Guide is the canonical end-to-end adoption path; `guides/recipes/mailglass-integration-blueprint.md` remains the focused notifier/adapter recipe. Guide links to blueprint for copy-paste sections; blueprint links back to guide for full golden path (update blueprint "Related guides" and out-of-scope paragraph).
- **D-03:** Guide sections in order: (1) dependencies (`chimeway` + `mailglass`), (2) database/migrations for Chimeway and Mailglass repos, (3) runtime config (`channel_adapters`, `channel_adapter_configs`, Mailglass app config), (4) host `Mailglass.Mailable` module, (5) trigger + delivery/trace verification, (6) optional inbound feedback wiring.
- **D-04:** Inbound feedback section documents `Chimeway.Webhooks.process/4` host-mount pattern — NOT `Mailglass.Webhook.Plug` (Phase 55 D-02). Cross-link `guides/recipes/feedback-escalation-workflow.md` for workflow progression context.
- **D-05:** Include demo host inbound webhook route example (`/webhooks/chimeway/mailglass`) as optional worked example in the guide, referencing Phase 55 Mailglass adapter webhook callbacks (`verify_webhook`, `resolve_delivery`, `normalize_feedback`).
- **D-06:** Guide uses stable string identifiers aligned with demo host: `teampulse.invite_sent`, `teampulse.invite_sent.email`, `DemoHost.Notifiers.InviteSent`, `DemoHost.Mailers.InviteEmail` — same convergence as Phase 56.
- **D-07:** Document product name vs module: `Chimeway.Adapter.Mailglass` (requirements/adoption docs) vs `Chimeway.Adapters.Mailglass` (implementation module) — per Phase 54 D-07.

### Doc-contract coverage (DOCS-07)
- **D-08:** Add `describe "mailglass integration guide doc contract (DOCS-06 / DOCS-07)"` in `test/chimeway/doc_contract_test.exs` — same pattern as golden-path (DOCS-01) and blueprint recipe (ECOS-05).
- **D-09:** Required phrases MUST include at minimum: `Chimeway.Adapters.Mailglass`, `Chimeway.Adapter.Mailglass`, `channel_adapters`, `channel_adapter_configs`, `render_key`, `Chimeway.Webhooks.process`, `Mailglass.Mailable`, `Chimeway.trigger`, `tenant_id`, `idempotency_key`, orchestration/templating responsibility language.
- **D-10:** Forbidden strings reuse `@recipe_forbidden_strings` plus guide-specific anti-patterns: pre-Mailglass-only email path (Logger adapter as sole documented option), `Chimeway.Workflow` (not `Workflows`), fictional module names.
- **D-11:** Doc-contract runs via existing `mix ci.verify_gates` — no separate alias needed beyond GATE-04 mailglass test gate.

### Release gate: `mix verify.mailglass` (GATE-04)
- **D-12:** Add `verify.mailglass` alias in root `mix.exs`:
  ```elixir
  "verify.mailglass": [
    "cmd env MIX_ENV=test mix test --only mailglass --warnings-as-errors",
    "cmd --shell cd examples/chimeway_demo_host && mix deps.get && mix test --only mailglass --warnings-as-errors"
  ]
  ```
- **D-13:** Root subprocess exercises `@moduletag :mailglass` tests: adapter contract, executor routing, webhook pipeline (`mailglass_adapter_test.exs`, `executor_mailglass_adapter_test.exs`, `mailglass_webhook_pipeline_test.exs`). Demo host subprocess exercises DEMO-06 proof (`mailglass_delivery_proof_test.exs`).
- **D-14:** Do NOT add `verify.mailglass` to default `mix ci` alias — preserve Phase 41 D-09 fast-feedback separation.
- **D-15:** Update root `ci.test` alias to `--exclude mailglass` so default CI matrix stays fast; mailglass proof owned by explicit `verify.mailglass` gate (closes Phase 54 review WR-03 deferral).
- **D-16:** Add dedicated `verify_mailglass` CI job in `.github/workflows/ci.yml` mirroring `verify_journeys` (Postgres service, ecto create/migrate, `mix verify.mailglass`).
- **D-17:** Journey CI isolation preserved: `mix verify.journeys` continues `--only journey`; mailglass proof remains `--only mailglass` only.

### MAINTAINING.md and HexDocs wiring
- **D-18:** Extend MAINTAINING.md pre-ship checklist from quintet → **sextet**, adding `mix verify.mailglass` as 6th command after `mix verify.journeys`. Document what it covers (root adapter + webhook pipeline + demo host DEMO-06 proof).
- **D-19:** Add `guides/introduction/mailglass-integration.md` to `mix.exs` docs `extras` under Introduction group.
- **D-20:** Add `guides/recipes/mailglass-integration-blueprint.md` to docs `extras` if not already present (currently missing from extras list despite existing on disk).
- **D-21:** Cross-link from `guides/recipes/custom-adapter.md`, blueprint recipe, and README to the new integration guide.

### Relationship to existing gates
- **D-22:** Existing pre-ship quintet (`mix ci`, `mix ci.docs`, `mix ci.verify_gates`, `mix verify.example`, `mix verify.journeys`) MUST remain unchanged in behavior — sextet is additive.
- **D-23:** `mix verify.example` continues running full demo host test suite (may include mailglass tests as side effect); `mix verify.mailglass` is the explicit, named Mailglass integration gate for maintainers and CI.

### Claude's Discretion
- Exact inbound webhook controller code in guide vs demo host implementation for D-05 route
- Whether demo host route is guide-only prose or shipped controller module in `examples/chimeway_demo_host`
- Additional required phrases beyond D-09 minimum (e.g., `Mailglass.Outbound`, `provider_message_id`, specific webhook provider config keys)
- Root `ci.test` exclude timing: implement D-15 in same plan wave as verify.mailglass alias or defer if compile issues arise
- Guide filename adjustment if `mailglass-integration.md` conflicts with blueprint naming in doc-contract paths
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope and requirements
- `.planning/ROADMAP.md` — Phase 57 goal, success criteria, dependency on Phase 56
- `.planning/REQUIREMENTS.md` — DOCS-06, DOCS-07, GATE-04 acceptance criteria
- `.planning/seeds/SEED-003-ecosystem-integrations.md` — Chimeway orchestration vs Mailglass templating split
- `.planning/phases/54-mailglass-adapter-core/54-CONTEXT.md` — Outbound adapter decisions
- `.planning/phases/55-inbound-feedback-bridge/55-CONTEXT.md` — Webhook callback decisions (D-02: Webhooks.process, not Mailglass Plug)
- `.planning/phases/56-blueprint-demo-proof/56-CONTEXT.md` — Blueprint/demo proof; Phase 57 boundary (D-17)

### Guide patterns and targets
- `guides/introduction/golden-path.md` — Introduction-level golden-path structure (DOCS-01)
- `guides/introduction/installation.md` — Install/migration depth reference
- `guides/recipes/mailglass-integration-blueprint.md` — ECOS-05 blueprint (cross-link, not duplicate)
- `guides/recipes/custom-adapter.md` — Adapter behaviour + Mailglass stub
- `guides/recipes/feedback-escalation-workflow.md` — Webhook ingress + workflow progression pattern
- `test/chimeway/doc_contract_test.exs` — Doc-contract describe blocks (golden-path, blueprint, recipes)

### Release gate infrastructure
- `mix.exs` — Existing aliases: `ci.test`, `ci.verify_gates`, `verify.journeys`, `verify.example`
- `MAINTAINING.md` — Pre-ship quintet (extend to sextet)
- `.github/workflows/ci.yml` — `verify_journeys` job pattern for new `verify_mailglass` job

### Mailglass test surfaces (verify.mailglass scope)
- `test/chimeway/adapters/mailglass_adapter_test.exs` — Root adapter contract (`@moduletag :mailglass`)
- `test/chimeway/adapters/mailglass_webhook_pipeline_test.exs` — ECOS-04 webhook pipeline proof
- `test/chimeway/dispatch/executor_mailglass_adapter_test.exs` — Per-channel adapter routing
- `config/test.exs` — Root Mailglass test harness (Fake adapter, TestRepo, tenancy)
- `examples/chimeway_demo_host/test/demo_host_web/mailglass_delivery_proof_test.exs` — DEMO-06 proof
- `examples/chimeway_demo_host/lib/demo_host/mailers/invite_email.ex` — Host mailable reference
- `lib/chimeway/adapters/mailglass.ex` — Adapter implementation referenced in guide
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Complete Mailglass adapter stack (Phases 54–55): outbound `deliver/2`, webhook callbacks, contract tests, webhook pipeline integration test
- ECOS-05 blueprint recipe with doc-contract coverage — copy-paste notifier/adapter sections for guide
- DEMO-06 demo host proof: `mailglass_delivery_proof_test.exs`, `DemoHost.Mailers.InviteEmail`, admin trace inspectability
- Golden-path guide + doc-contract infrastructure — structural template for new introduction guide
- `verify.journeys` alias + CI job — direct pattern for `verify.mailglass`
- `feedback-escalation-workflow.md` — webhook ingress documentation pattern for inbound feedback section

### Established Patterns
- Introduction guides: numbered steps, copy-paste config blocks, runnable demo host pointers, "Related guides" footer
- Doc-contract: `@required` phrase list + `@recipe_forbidden_strings` + `Chimeway.Workflow` regex gate per describe block
- Named verify entrypoints separate from `mix ci` (Phase 41 D-09); CI jobs mirror aliases (`verify_example`, `verify_journeys`)
- Mailglass tests: `@moduletag :mailglass`, selective `--only mailglass` / `--exclude mailglass`
- Journey isolation: demo host default test path uses Logger adapter; Mailglass only in tagged modules (D-10 from Phase 56)
- MAINTAINING.md pre-ship commands documented with one-line descriptions per gate

### Integration Points
| Seam | Role in Phase 57 |
|------|------------------|
| `guides/introduction/mailglass-integration.md` | DOCS-06 primary deliverable |
| `test/chimeway/doc_contract_test.exs` | DOCS-07 CI truth lock |
| `mix.exs` `verify.mailglass` alias | GATE-04 named entrypoint |
| `mix.exs` `ci.test` `--exclude mailglass` | Fast default CI (WR-03) |
| `.github/workflows/ci.yml` `verify_mailglass` job | GATE-04 shift-left CI |
| `MAINTAINING.md` step 3 | Pre-ship sextet documentation |
| `mix.exs` docs extras | HexDocs discoverability |
| Blueprint + custom-adapter cross-links | Guide discoverability from existing docs |
</code_context>

<specifics>
## Specific Ideas

- SEED-003 vision: Chimeway orchestrates when/why; Mailglass handles templating/MJML/Swoosh. Phase 57 makes the full composition adoptable via golden-path guide + explicit verify gate.
- Guide and blueprint share stable identifiers with demo host — no module-name durable identity.
- Pre-ship checklist grows from quintet to sextet; existing gates must not regress.
- Phase 54 review WR-03 (`--exclude mailglass` in default CI) closes in this phase alongside GATE-04.

</specifics>

<deferred>
## Deferred Ideas

- Accrue dunning, Threadline telemetry, Sigra auth blueprints — v1.9+ (SEED-003 remainder)
- INBX bell / notification center UI — v1.9
- Wiring all three TeamPulse notifiers through Mailglass — only invite email required (DEMO-06); guide may reference others but not require proof
- Global demo host Mailglass config in default test path — rejected; breaks journey CI (D-10)
- Bundling `verify.mailglass` into default `mix ci` — rejected per Phase 41 pattern
- Playwright admin smoke — deferred per INV-004

### Reviewed Todos (not folded)
None — no pending todos matched Phase 57.

</deferred>

---

*Phase: 57-docs-release-gates*
*Context gathered: 2026-05-29 (assumptions mode)*
