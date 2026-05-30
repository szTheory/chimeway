# Phase 60: Accrue Docs & Release Gate — Research

**Researched:** 2026-05-30  
**Phase:** 60-accrue-docs-release-gate  
**Requirements:** DOCS-08 (Accrue), DOCS-09 (Accrue), GATE-05 (Accrue)  
**Status:** Ready for planning

---

## 1. Executive Summary

Phase 60 closes the **adopter documentation and CI gate** loop for Accrue dunning — the mirror of Mailglass Phase 57 (`mailglass-integration.md` + DOCS-06/07 doc-contract + `verify_mailglass` CI job). Phases 58–59 shipped ECOS-06/DEMO-07/ECOS-07; Phase 60 publishes the **golden-path introduction guide**, **guide doc-contract**, and **formal `verify_accrue` CI job** without changing dunning behavior.

**Planner takeaway:** Three plans in two waves — **60-01** (guide) and **60-03** (CI + MAINTAINING) parallel in Wave 1; **60-02** (doc-contract) blocked on 60-01. Reuse Mailglass introduction + doc-contract patterns verbatim; Accrue-specific twist is **billing-event trigger path** (not `Chimeway.trigger/3` primary story) and **sibling Accrue repo checkout** in CI.

---

## 2. Standard Stack

| Layer | Choice | Notes |
|-------|--------|-------|
| Guide artifact | `guides/introduction/accrue-dunning-integration.md` | Parallel to `mailglass-integration.md` [CITED: 60-CONTEXT D-03] |
| Doc-contract | `test/chimeway/doc_contract_test.exs` | New describe after mailglass guide block [CITED: D-09] |
| Verify alias | `mix verify.accrue` (existing) | Root 11 + demo 3 `:accrue` tests [VERIFIED: mix.exs L111–115] |
| CI job | `verify_accrue` in `.github/workflows/ci.yml` | Mirror `verify_mailglass` L163–201 [VERIFIED] |
| Accrue source | `szTheory/accrue` path dep via `ACCRUE_PATH` | Integration module not in hex-only artifact [VERIFIED: accrue_dep/0] |
| Maintainer docs | `MAINTAINING.md` pre-ship septet | six → seven gates [CITED: D-16] |

---

## 3. Architecture Patterns

### 3.1 Mailglass Phase 57 template (direct map)

| Mailglass (shipped) | Accrue (Phase 60 target) |
|---------------------|--------------------------|
| `guides/introduction/mailglass-integration.md` | `guides/introduction/accrue-dunning-integration.md` |
| `doc_contract` DOCS-06/07 describe | DOCS-08/09 describe |
| `verify_mailglass` CI job | `verify_accrue` CI job |
| README adoption link | README Accrue guide link |
| Blueprint ↔ guide reciprocal links | Update `accrue-dunning-blueprint.md` placeholder |

### 3.2 Guide structure (D-04)

Eight sections mirroring Mailglass introduction:

1. **Responsibility split (SEED-003)** — Chimeway orchestrates when/why; Accrue owns billing state; **not** `Chimeway.Adapter` seam
2. **Dependencies** — `{:chimeway, "~> 1.0"}`, `{:accrue, ...}` with `ACCRUE_PATH` sibling note
3. **Database / migrations** — Chimeway spine + Accrue repo migrations (link Accrue docs)
4. **Runtime config** — `config :accrue, dunning: [engine: Accrue.Integrations.Chimeway]`
5. **DunningNotifier reference** — `Accrue.Integrations.Chimeway.DunningNotifier` in Accrue repo; `workflow/2`, `cancel_signals: ["invoice.paid"]`
6. **Billing-event triggers** — `invoice.payment_failed` start, `invoice.paid` Outcome Signal terminate; forbid `payment_recovered`
7. **Verification** — `mix verify.accrue`, `DemoHost.Seeds.seed_accrue_dunning/0`, `/admin/chimeway`; Logger adapter minimal path; optional Mailglass cross-link
8. **Related guides** — blueprint, golden path, mailglass blueprint optional

Primary adoption path: **Accrue events → engine → Chimeway workflow**, not host `Chimeway.trigger(DunningNotifier, ...)`.

### 3.3 Doc-contract (D-09..D-12)

Extend `doc_contract_test.exs` after mailglass guide describe (~L347):

- `@accrue_integration_guide` path constant
- Reuse `@recipe_forbidden_strings` + `Chimeway.Workflow` regex
- **Forbid** `payment_recovered` (guide-specific, D-12)
- `@required` = ECOS-07 blueprint minimum + guide-specific: `mix verify.accrue`, `ACCRUE_PATH`, section coverage strings (`mix chimeway.gen.migrations` or deps/migrations language)
- Billing-state split assertion (same as blueprint describe)

### 3.4 CI `verify_accrue` job (D-13..D-14)

Mirror `verify_mailglass` job structure:

```yaml
verify_accrue:
  name: Accrue dunning integration gate
  # postgres service, beam setup, cache, deps.get, ecto create/migrate
  # EXTRA: checkout szTheory/accrue at pinned SHA into ./accrue/accrue
  env:
    ACCRUE_PATH: ${{ github.workspace }}/accrue/accrue
  run: mix verify.accrue
```

**Pinned ref:** `de7a3fef53247619d96a26eea60197d74fd14634` (local sibling HEAD 2026-05-30; planner may use tag when Accrue releases integration module to hex).

**Checkout pattern:**

```yaml
- uses: actions/checkout@v4
  with:
    repository: szTheory/accrue
    ref: de7a3fef53247619d96a26eea60197d74fd14634
    path: accrue/accrue
```

Set `ACCRUE_PATH` for root `mix verify.accrue` so `accrue_dep/0` resolves path dep. Demo host step inside alias still uses hardcoded `../../../accrue/accrue` — CI layout must place Accrue at `accrue/accrue` relative to repo root (matches local `../accrue/accrue` convention when chimeway is sibling).

**Risk:** Demo alias hardcodes `../../../accrue/accrue` from `examples/chimeway_demo_host` — from repo root that resolves to `{workspace}/accrue/accrue` ✓ when checkout path is `accrue/accrue`.

### 3.5 MAINTAINING.md (D-16)

Add after `mix verify.mailglass`:

```bash
mix verify.accrue
```

Description: Accrue dunning integration gate (GATE-05 Accrue): ECOS-06 lifecycle + DEMO-07 demo proof via sibling Accrue checkout.

Update "All six must pass" → "All seven must pass".

Document `ACCRUE_PATH` / CI sibling checkout expectation for maintainers (59-REVIEW IN-03).

### 3.6 HexDocs extras

Add `guides/introduction/accrue-dunning-integration.md` to `mix.exs` `docs/0` extras list (after mailglass-integration.md).

---

## 4. Validation Architecture

| Property | Value |
|----------|-------|
| Framework | ExUnit |
| Quick run | `mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` |
| Full gate | `ACCRUE_PATH=../accrue/accrue mix verify.accrue --warnings-as-errors` |
| CI gate | `verify_accrue` job with sibling checkout |
| Estimated runtime | ~30–60s doc-contract; ~2–3 min verify.accrue with Accrue compile |

**Per-plan verification:**

| Plan | Primary command |
|------|-----------------|
| 60-01 | Manual: guide file exists + required strings grep |
| 60-02 | `mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` |
| 60-03 | `ACCRUE_PATH=... mix verify.accrue`; CI workflow syntax valid |

**Nyquist:** Doc-contract provides automated truth lock (DOCS-09); verify.accrue provides integration proof (GATE-05). No new application code paths — documentation + CI only.

---

## 5. Pitfalls

| ID | Pitfall | Mitigation |
|----|---------|------------|
| P-01 | Guide presents `Chimeway.trigger/3` as primary Accrue adoption | Doc-contract + CONTEXT D-04 forbid; required strings emphasize Accrue events |
| P-02 | `payment_recovered` deprecated signal in guide | Explicit forbid in doc-contract (D-12) |
| P-03 | CI runs hex-only accrue without integration module | Mandatory sibling checkout + `ACCRUE_PATH` (D-14) |
| P-04 | Breaking existing verify_mailglass/journeys jobs | Accrue job additive only (ROADMAP SC #3) |
| P-05 | Guide duplicates blueprint content | Guide owns path; blueprint keeps recipe sections; reciprocal links (D-05) |

---

## 6. File Checklist

| File | Action |
|------|--------|
| `guides/introduction/accrue-dunning-integration.md` | Create (60-01) |
| `guides/recipes/accrue-dunning-blueprint.md` | Update cross-links (60-01) |
| `README.md` | Add adoption link (60-01) |
| `mix.exs` | docs extras entry (60-01) |
| `test/chimeway/doc_contract_test.exs` | New describe (60-02) |
| `.github/workflows/ci.yml` | `verify_accrue` job (60-03) |
| `MAINTAINING.md` | Septet checklist (60-03) |

---

## RESEARCH COMPLETE
