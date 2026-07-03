---
phase: 79
slug: front-door-and-docs-ia
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-03
---

# Phase 79 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Docs/release truth is treated as executable ExUnit contracts in this project — every
> requirement below is proven by a string assertion inside an existing `describe` block.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir) |
| **Config file** | `test/test_helper.exs` (existing) |
| **Quick run command** | `mix test test/chimeway/doc_contract_test.exs test/chimeway/release_gate_contract_test.exs` |
| **Full suite command** | `mix ci.verify_gates` (release-blocking lane running the doc/release contracts) |
| **Estimated runtime** | ~30–90 seconds (quick); `ci.verify_gates` longer (builds/unpacks the Hex artifact) |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/chimeway/doc_contract_test.exs test/chimeway/release_gate_contract_test.exs`
- **After every plan wave:** Run `mix ci.verify_gates`
- **Before `/gsd-verify-work`:** `mix ci.verify_gates` must be green
- **Max feedback latency:** ~90 seconds (quick lane)

---

## Per-Task Verification Map

Requirement-level map (task IDs finalized by the planner). Every requirement is proven by a
contract assertion in an existing describe block; the "File Exists" column reflects that the
block exists today but the new marker/assertion is a Wave 0 addition.

| Requirement | Behavior | Test File / Describe Block | Test Type | Automated Command | Block Exists | New Assertion |
|-------------|----------|----------------------------|-----------|-------------------|--------------|---------------|
| DOCS-14 | README leads with local-first value prop + explainability promise | `doc_contract_test.exs` — "README install doc contract" (~L1330-1391) | contract | `mix test test/chimeway/doc_contract_test.exs` | ✅ | ❌ W0 (value-prop marker in `@required`) |
| DOCS-15 | README states non-goals, host-owned boundary, optional/preview-surface status | `doc_contract_test.exs` — same describe | contract | `mix test test/chimeway/doc_contract_test.exs` | ✅ | ❌ W0 (non-goals / host-boundary / optional-surface markers) |
| DOCS-16 | Snippets show notification key, `tenant_id`, `idempotency_key`, prefix, `Chimeway.Traces.explain_delivery` | `doc_contract_test.exs` — same describe + per-trigger invariant (mirror ~L1247-1261) | contract | `mix test test/chimeway/doc_contract_test.exs` | ✅ | ❌ W0 (`Chimeway.Traces.explain_delivery` in `@required` + per-trigger idem/tenant invariant) |
| DOCS-17 | Flows stubs delinked (README + mix.exs extras); stale `jonlunsford` URLs fixed | `doc_contract_test.exs` — hexdocs-extras contract (~L1442-1587); new golden-path legacy-URL guard | contract | `mix test test/chimeway/doc_contract_test.exs` | ✅ (extras) | ❌ W0 (recommended golden-path URL guard) |
| ADPT-01 | Packaged (unpacked-Hex) README carries the new public-story invariants | `release_gate_contract_test.exs` — "unpacked Hex package artifact truth" (~L466-531, extend ~L493-530) | contract | `mix test test/chimeway/release_gate_contract_test.exs` | ✅ | ❌ W0 (packaged-README assertions for DOCS-14/15/16 invariants) |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

New assertions inside **existing** blocks (no new test files — D-09 forbids a new test file):

- [ ] `test/chimeway/doc_contract_test.exs` — add value-prop, `## Non-goals` heading, host-boundary, and optional/preview-surface markers to the README `@required` set
- [ ] `test/chimeway/doc_contract_test.exs` — add `Chimeway.Traces.explain_delivery` to README `@required`
- [ ] `test/chimeway/doc_contract_test.exs` — add README per-trigger `idempotency_key` / `tenant_id` invariant (mirror golden-path ~L1247-1261)
- [ ] `test/chimeway/release_gate_contract_test.exs` — extend "unpacked Hex package artifact truth" (~L493-530) with packaged-README DOCS-14/15/16 invariants
- [ ] (Recommended) `test/chimeway/doc_contract_test.exs` — golden-path legacy-URL guard so the D-06 `jonlunsford → szTheory` fix cannot silently regress (no guard covers golden-path.md today)
- [ ] (Recommended, D-03) `test/chimeway/doc_contract_test.exs` — README guard forbidding `{:chimeway_admin, "~> 1.0"}` / `{:chimeway_inbox, "~> 1.0"}` install claims and requiring preview-status language

*Test infrastructure exists; gaps are new assertions inside existing blocks, not new files.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| A new adopter can read first-hop docs and understand when to use / avoid Chimeway (subjective narrative quality) | DOCS-14/15 (Success Criterion 1) | Readability/comprehension is a human judgment; contracts pin the presence of required sections/strings but not prose quality | Read the rewritten `README.md` top-to-bottom as a first-time adopter; confirm value prop → when-to-use → non-goals → host boundary → optional surfaces → install → trigger→explain flow reads coherently |
| `mix demo.up --check` runtime companion still works (D-08) | ADPT-01 (companion) | Runs a live demo host; kept as companion, not the primary ADPT-01 anchor | `cd examples/chimeway_demo_host && mix demo.up --check` |

*Packaged-doc truth (the primary ADPT-01 anchor) IS automated via the unpacked-Hex artifact test.*

---

## Validation Sign-Off

- [ ] All requirements have `<automated>` contract verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (new markers/assertions in existing blocks)
- [ ] No watch-mode flags
- [ ] Feedback latency < 90s (quick lane)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
