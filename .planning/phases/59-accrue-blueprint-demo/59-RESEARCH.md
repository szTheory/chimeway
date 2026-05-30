# Phase 59: Accrue Blueprint & Demo — Research

**Researched:** 2026-05-30  
**Phase:** 59-accrue-blueprint-demo  
**Requirements:** ECOS-07, DEMO-07  
**Status:** Ready for planning

---

## 1. Executive Summary

Phase 59 layers **adopter-facing proof** on top of Phase 58’s library-level ECOS-06 spine: a **demo host** Accrue dunning proof (`@moduletag :accrue`, admin trace at `/admin/chimeway`) and a **published blueprint recipe** with ECOS-07 doc-contract guards. It does **not** re-prove lifecycle mechanics in Chimeway root tests [CITED: 59-CONTEXT.md D-02].

**Planner takeaway:** Mirror the **Mailglass Phase 56–57 pattern** end-to-end: `mailglass_delivery_proof_test.exs` + `mailglass-integration-blueprint.md` + `doc_contract_test.exs` ECOS-05 block → Accrue equivalents in Wave 59-01 (demo) then 59-02 (recipe + contract). Extend `mix verify.accrue` to include demo host the way `verify.mailglass` spans root + demo [VERIFIED: mix.exs lines 99–108].

**Delivery order (locked):** Demo proof first (59-01 / DEMO-07), blueprint + doc-contract second (59-02 / ECOS-07) [CITED: 59-CONTEXT.md D-01].

---

## 2. Standard Stack

| Layer | Choice | Notes |
|-------|--------|-------|
| Language | Elixir ~> 1.17 | Matches demo host + Chimeway [CITED: examples/chimeway_demo_host/mix.exs] |
| Demo host | Phoenix 1.7 + chimeway path dep | Already has Mailglass; **Accrue not yet wired** [VERIFIED: demo_host mix.exs deps] |
| Billing events | `Accrue.Test.trigger_event/2` | Same as `accrue_dunning_lifecycle_test.exs` — no host glue [CITED: 58-CONTEXT.md D-12] |
| Email in demo lane | `Chimeway.Adapters.Logger` | Logger adapter only for Accrue proof — not Mailglass [CITED: 59-CONTEXT.md D-06] |
| Operator UI | `chimeway_admin` at `/admin/chimeway` | LiveView trace search — parallel JOUR-04/08 + DEMO-06 [CITED: admin_trace_live_test.exs] |
| CI lane | `@moduletag :accrue` + `mix verify.accrue` | Extend alias to demo host; formal CI job deferred Phase 60 [CITED: 59-CONTEXT.md D-04] |

---

## 3. Architecture Patterns

### 3.1 Mailglass template (copy structure, not content)

| Mailglass (shipped) | Accrue (Phase 59 target) |
|---------------------|--------------------------|
| `DemoHostWeb.MailglassDeliveryProofTest` (`:mailglass`) | `DemoHostWeb.AccrueDunningProofTest` (`:accrue`) |
| `DemoHost.Seeds.seed_invite/0` | `DemoHost.Seeds.seed_accrue_dunning/0` |
| `guides/recipes/mailglass-integration-blueprint.md` | `guides/recipes/accrue-dunning-blueprint.md` |
| `doc_contract_test.exs` ECOS-05 describe | ECOS-07 describe block |
| `verify.mailglass` root + demo host | `verify.accrue` root + demo host |

[VERIFIED: grep mailglass_delivery_proof_test.exs, mailglass blueprint, doc_contract ECOS-05]

### 3.2 Demo host Accrue bootstrap

Mirror `examples/chimeway_demo_host/test/test_helper.exs` Mailglass block:

1. `Code.ensure_loaded?(Accrue)` gate
2. `Application.ensure_all_started(:accrue)`
3. `Accrue.TestRepo` storage_up + migrations from Chimeway’s `test/support/accrue` migrations path (or Accrue package migrations)
4. Sandbox `:manual` mode for shared conn case

[CITED: test_helper.exs Mailglass block L13–41] [CITED: chimeway test/test_helper.exs Accrue bootstrap from Phase 58]

**Demo host deps:** Add `accrue_dep/0` helper mirroring root `mix.exs` (`ACCRUE_PATH` env, optional: true) [VERIFIED: mix.exs accrue_dep/0].

### 3.3 Demo proof flow (DEMO-07)

```
DemoHost.Seeds.seed_accrue_dunning/0
  → Accrue fixtures: customer + past_due subscription + failed invoice
  → Accrue.Test.trigger_event("invoice.payment_failed", ...)
  → Accrue.Integrations.Chimeway.start_campaign → Chimeway workflow
  → drain initial Logger email delivery
  → progress to :waiting, pending_signals: ["invoice.paid"]
  → (test) trigger invoice.paid → signal_received, no escalation email
  → (test) admin LiveView search by customer email recipient_identity
```

Reuse helpers from `Chimeway.TestSupport.AccrueFixtures` **or** extract shared module under `examples/chimeway_demo_host/test/support/accrue/` — demo host cannot import Chimeway `test/support` at compile time without `elixirc_paths` [ASSUMED: duplicate thin wrapper in demo test/support is simplest].

### 3.4 Blueprint recipe (ECOS-07)

Structure parallel to `mailglass-integration-blueprint.md`:

1. **Who this is for** — Feature Developer (DunningNotifier) + Adopter (Accrue engine config)
2. **Responsibility split** — Chimeway orchestrates when/why; Accrue owns billing state (SEED-003)
3. **Feature Developer** — `Accrue.Integrations.Chimeway.DunningNotifier.workflow/2`, `cancel_signals: ["invoice.paid"]`, 48h escalation shape
4. **Adopter** — `config :accrue, dunning: [engine: Accrue.Integrations.Chimeway]`, event subscription (`invoice.payment_failed` / `invoice.paid`)
5. **Trigger example** — Accrue event path, not raw `Chimeway.trigger/3` from host
6. **Runnable references** — `DemoHost.Seeds.seed_accrue_dunning/0`, `/admin/chimeway`
7. **Out of scope** — golden-path guide → Phase 60 DOCS-08; `mix verify.accrue` CI job → Phase 60 GATE-05
8. **Related guides** — Mailglass blueprint cross-link (optional email), Phase 60 guide placeholder

[CITED: mailglass-integration-blueprint.md sections] [CITED: 59-CONTEXT.md D-11..D-14]

### 3.5 Doc-contract (ECOS-07)

Mirror ECOS-05 pattern in `test/chimeway/doc_contract_test.exs`:

- `@accrue_blueprint_recipe` path expand
- `@recipe_forbidden_strings` reuse (fictional modules)
- `@required` strings from D-16: `Accrue.Integrations.Chimeway`, `invoice.payment_failed`, `invoice.paid`, `cancel_signals`, `workflow/2`, `config :accrue`, `dunning`, `idempotency_key`, `tenant_id`, orchestration/billing split language, `DemoHost.Seeds.seed_accrue_dunning`, `/admin/chimeway`
- Regex guard: no `Chimeway.Workflow` (use `Workflows`)

[CITED: doc_contract_test.exs ECOS-05 block L245–290]

### 3.6 verify.accrue extension

Current alias (root only):

```elixir
"verify.accrue": [
  "deps.compile accrue --force",
  "cmd env MIX_ENV=test mix test --only accrue --warnings-as-errors"
]
```

Target (Mailglass parity):

```elixir
"verify.accrue": [
  "deps.compile accrue --force",
  "cmd env MIX_ENV=test mix test --only accrue --warnings-as-errors",
  "cmd --shell cd examples/chimeway_demo_host && mix deps.get && mix test --only accrue --warnings-as-errors"
]
```

[CITED: verify.mailglass alias L99–102] [CITED: 59-CONTEXT.md D-04]

---

## 4. Pitfalls

| Pitfall | Mitigation |
|---------|------------|
| Accrue proof pollutes `:journey` suite | `@moduletag :accrue` only; demo host `mix test` default excludes `:accrue` if needed [CITED: D-03] |
| `seed_accrue_dunning/0` in `run/0` breaks idempotency | Keep **standalone** seed API; do not add to `Seeds.run/0` until proven safe [CITED: D-10 discretion] |
| Re-proving ECOS-06 in root tests | Demo tests assert **host-visible** outcomes only; defer engine edge cases to Phase 58 suite [CITED: D-02] |
| Blueprint duplicates Phase 60 guide | Explicit out-of-scope section + cross-link [CITED: D-12] |
| Fictional module names in docs | doc-contract `@required` + regex forbidden guards [CITED: D-15] |
| Demo host without ACCRUE_PATH | Tests conditional on `Code.ensure_loaded?(Accrue)` — skip or tag exclude [CITED: Phase 58 pattern] |

---

## 5. Codebase Anchors

| Asset | Path | Role in Phase 59 |
|-------|------|------------------|
| Lifecycle proof (reference) | `test/chimeway/integrations/accrue_dunning_lifecycle_test.exs` | Copy event trigger + waiting + terminate assertions |
| Fixtures | `test/support/accrue/fixtures.ex` | Engine config, Logger adapter, `trigger_invoice_*` helpers |
| Mailglass demo proof | `examples/.../mailglass_delivery_proof_test.exs` | ConnCase setup, admin LiveView search template |
| Mailglass blueprint | `guides/recipes/mailglass-integration-blueprint.md` | Recipe section structure |
| ECOS-05 doc-contract | `test/chimeway/doc_contract_test.exs` | ECOS-07 describe template |
| DunningNotifier | `../accrue/.../dunning_notifier.ex` | Blueprint workflow/2 citation |
| Demo seeds | `examples/.../lib/demo_host/seeds.ex` | Add `seed_accrue_dunning/0` |
| Demo test_helper | `examples/.../test/test_helper.exs` | Accrue TestRepo bootstrap |

---

## 6. Don't Hand-Roll

| Problem | Don't build | Use instead |
|---------|-------------|-------------|
| Host webhook glue for dunning | Custom HTTP callback in demo | `Accrue.Test.trigger_event/2` |
| Second ECOS-06 lifecycle suite in root | Duplicate 11 lifecycle tests | Demo host `:accrue` proof only |
| Mailglass in Accrue demo lane | Combined adapter proof | Logger adapter [D-06] |
| Full golden-path guide in blueprint | 60-page integration doc | Focused recipe + Phase 60 pointer |

---

## 7. Phase Dependencies

- **Requires Phase 58 complete:** `Accrue.Integrations.Chimeway`, lifecycle tests green, `verify.accrue` root lane [CITED: 58-VERIFICATION.md status passed]
- **Blocks Phase 60:** blueprint must exist before golden-path guide and GATE-05 formalization [CITED: ROADMAP Phase 60 Depends on 59]

---

## 8. Open Questions (Claude's Discretion — planner may decide)

| Item | Recommendation | Confidence |
|------|----------------|------------|
| Blueprint filename | `accrue-dunning-blueprint.md` (shorter, mailglass parallel) | HIGH |
| Demo fixture tenant | Dedicated `accrue-demo@teampulse.test` customer email for admin search | MEDIUM |
| Admin trace depth | Search by `recipient_identity` + assert workflow_key `accrue.dunning` in detail/trace list | HIGH |
| Shared fixtures | `demo_host/test/support/accrue_fixtures.ex` copying minimal helpers from Chimeway test support | HIGH |
| `mix.exs` extras | Add new blueprint to `docs/0` extras list when recipe lands | MEDIUM |

---

## 9. Validation Architecture (Nyquist Dimension 8)

### 9.1 Test framework

| Property | Value |
|----------|-------|
| Framework | ExUnit |
| Config | Root `mix.exs` + demo host `mix.exs` |
| Quick run (demo) | `cd examples/chimeway_demo_host && mix test --only accrue --warnings-as-errors` |
| Phase gate | `mix verify.accrue` (root + demo after 59-01) |
| Doc-contract | `mix test test/chimeway/doc_contract_test.exs` (ECOS-07 describe) |

### 9.2 ROADMAP success criteria → verification map

| # | Success criterion | Requirement | Automated command | Plan |
|---|-------------------|-------------|-------------------|------|
| 1 | Recipe documents notifier, events, orchestration split + doc-contract | ECOS-07 | `mix test test/chimeway/doc_contract_test.exs --only line <ecos07>` | 59-02 |
| 2 | Demo proves failed payment → email → waiting → paid terminates | DEMO-07 | `mix verify.accrue` (demo `:accrue` tests) | 59-01 |
| 3 | `/admin/chimeway` shows dunning progression + explainable decisions | DEMO-07 | Demo host LiveView test in accrue proof file | 59-01 |

### 9.3 Sampling rate

- **After 59-01 tasks:** `cd examples/chimeway_demo_host && mix test --only accrue`
- **After 59-02:** `mix test test/chimeway/doc_contract_test.exs` + full `mix verify.accrue`
- **Before phase sign-off:** `mix verify.accrue` + `mix ci.test` green (journey/mailglass unaffected)

---

## RESEARCH COMPLETE

Phase 59 is a **documentation + demo host extension** phase with a clear Mailglass precedent. No new Chimeway engine modules required — wiring, seeds, tests, recipe markdown, and doc-contract only.
