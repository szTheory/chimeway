---
phase: 79-front-door-and-docs-ia
verified: 2026-07-03T00:00:00Z
status: passed
score: 5/5 must-haves verified
behavior_unverified: 0
overrides_applied: 0
human_verification: []
human_verification_resolved:
  - test: "README decision-page narrative coherence (Success Criterion 1)."
    resolution: automated
    covered_by:
      - "test/chimeway/doc_contract_test.exs#decision-page sections appear in narrative order — recurring deterministic section-ORDER gate (in mix ci.verify_gates), locking value prop -> When to use -> Non-goals -> Host-owned boundaries -> Optional surfaces -> Installation -> Trigger-to-explainable-trace."
      - "one-time LLM coherence sign-off 2026-07-03: VERDICT coherent, CONFIDENCE high, RECOMMENDATION pass as-is (subjective read shifted from human to LLM; deliberately NOT wired into CI — a rarely-changing structurally-locked doc does not justify a paid/non-deterministic gate)."
    note: "Minor non-blocking LLM observation: Quick Start repeats the trigger snippet with different literals than the walkthrough (cosmetic; logged as optional polish, not a gap)."
  - test: "End-to-end trigger-to-explainability smoke (documented snippet chain)."
    resolution: automated
    covered_by:
      - "test/chimeway/integration/readme_snippet_test.exs#the documented trigger -> explain_delivery snippet chain runs end-to-end — DB-backed runtime proof, runs in the CI test job (postgres:15)."
    note: "Supersedes `mix demo.up --check` (which only migrates+seeds+exits-0 and never asserts the trace). Host-boot intent remains covered by the existing verify.example CI job."
---

# Phase 79: Front Door and Docs IA Verification Report

**Phase Goal:** Rewrite README as the public decision page for local-first ownership, explainability, host boundaries, non-goals, optional surfaces, and install flow; add/update snippets showing stable notification keys, tenant_id, idempotency_key, storage prefix, and trace/explainability proof; complete/demote/delink stub guides; add a clean consumer or unpacked-Hex smoke path that follows the final public docs — then LOCK the story with executable ExUnit contract assertions including proof it survives Hex packaging.
**Verified:** 2026-07-03
**Status:** passed (both human items automated 2026-07-03 — see "Verification Automated" below)
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | ----- | ------ | -------- |
| 1 | README leads with local-first value prop + preserves explainability promise (DOCS-14) | VERIFIED | README.md:1-9 opens "local-first, explainable, durable notification library... there is no external notification SaaS... Every notification decision is traceable." doc_contract asserts `local-first` marker (test:1405-1420). |
| 2 | README states use cases, non-goals, host-owned boundaries, and optional/preview-surface status (DOCS-15) | VERIFIED | README.md has all four headings: `## When to use` (L11), `## Non-goals` (L23), `## Host-owned boundaries` (L33), `## Optional surfaces` (L46); sibling packages framed as `in-repo preview/path package` / `not published on Hex yet` (L47-54). All 7 markers asserted in doc_contract (test:1405-1420) and packaged-README (release_gate:520-528). |
| 3 | README snippets show notification_key/0, tenant_id, idempotency_key, storage prefix, and Chimeway.Traces.explain_delivery on the real public API (DOCS-16) | VERIFIED | README.md:108-146 shows notifier `notification_key/0`+`version/0`, `config :chimeway, prefix: "chimeway"`, `Chimeway.trigger(...)` with both opts, `Chimeway.Traces.explain_delivery(delivery_id)` from `result.trace.delivery_ids`. All symbols confirmed in lib source (trigger.ex:15, traces.ex:135, notifier.ex:47-48). No fictional `Chimeway.explain_delivery` delegate (confirmed absent in lib/chimeway.ex). Both trigger examples genuinely carry both opts (2/2/2). |
| 4 | Three Flows stubs delinked from README nav + mix.exs (files kept on disk, multi-step-journeys.md preserved); golden-path legacy URLs canonicalized + guarded (DOCS-17) | VERIFIED | `grep guides/flows/trigger-to-delivery.md README.md` = 0; three stub files still on disk; three stub entries absent from mix.exs; `multi-step-journeys.md` kept (grep = 1). golden-path.md: 0 jonlunsford URLs, 4 canonical szTheory URLs. Regression guard at doc_contract:1225-1228. |
| 5 | Packaged (unpacked-Hex) README carries the DOCS-14/15/16 public-story invariants (ADPT-01) | VERIFIED | release_gate:493-529 builds+unpacks the REAL prod Hex package (`build_unpacked_package!`) and asserts the packaged README carries `local-first`, `## Non-goals`, `## Host-owned boundaries`, `in-repo preview/path package`, `Chimeway.Traces.explain_delivery`. Test passes (part of 505/0). Markers byte-identical to source-tree contract (lockstep). |

**Score:** 5/5 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `README.md` | Additive-superset decision page, four sections | VERIFIED | 163 lines; four decision headings + DOCS-16 snippet chain + preserved install/prefix/quick-start/docs/license. |
| `mix.exs` docs.extras | Three Flows stubs removed, multi-step-journeys kept | VERIFIED | Three stub entries gone; multi-step-journeys.md retained (grep=1). |
| `guides/introduction/golden-path.md` | Canonical szTheory URLs | VERIFIED | 0 legacy jonlunsford URLs; 4 szTheory URLs. |
| `test/chimeway/doc_contract_test.exs` | Extended README describe | VERIFIED | `@readme_decision_markers` list (1405-1413), `Chimeway.Traces.explain_delivery` in `@required` (1381), per-trigger invariant (1424-1438), sibling-install forbid (1443-1448), golden-path legacy-URL guard (1225-1228). |
| `test/chimeway/release_gate_contract_test.exs` | Packaged-README invariants | VERIFIED | Marker loop at 520-528 inside unpacked-artifact test. |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | -- | --- | ------ | ------- |
| README markers | doc_contract assertions | Byte-identical marker strings | WIRED | 7 decision markers + explain_delivery required marker all present in README and asserted. |
| README markers | release_gate packaged-README assertions | Marker-string lockstep | WIRED | `local-first`, `## Non-goals`, `## Host-owned boundaries`, `in-repo preview/path package`, `Chimeway.Traces.explain_delivery` identical across both contracts. |
| mix.exs extras | multi-step-journeys.md | doc_contract content enforcement | WIRED | Kept in mix.exs; stub cross-links preserved (files on disk). |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| doc + release_gate contracts pass | `mix test doc_contract_test.exs release_gate_contract_test.exs` | 505 tests, 0 failures | PASS |
| Real Hex package builds + packaged README carries markers | (release_gate `build_unpacked_package!` in suite above) | included in 505/0 | PASS |
| Public API symbols exist | grep lib/chimeway.ex, traces.ex, notifier.ex | trigger/3, explain_delivery/1, notification_key/0, version/0 all present; no explain_delivery delegate | PASS |
| golden-path URL canonicalization | grep jonlunsford / szTheory | 0 / 4 | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ----------- | ----------- | ------ | -------- |
| DOCS-14 | 79-01 | README local-first value prop + explainability promise | SATISFIED | Truth 1 |
| DOCS-15 | 79-01 | Use cases, non-goals, host boundaries, optional surface status | SATISFIED | Truth 2 |
| DOCS-16 | 79-01 | Public snippets: stable key, tenant_id, idempotency_key, prefix, trace lookup | SATISFIED | Truth 3 |
| DOCS-17 | 79-01 | Stub/stale guides removed from primary learning paths | SATISFIED | Truth 4 |
| ADPT-01 | 79-01 | Unpacked-Hex smoke path proves public docs/package story | SATISFIED | Truth 5 |

All 5 requirement IDs from PLAN frontmatter are present in REQUIREMENTS.md mapped to Phase 79 (lines 19-21, 34, 75-79), status Complete. No orphaned requirements.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| test/chimeway/doc_contract_test.exs | 1424-1438 (+ golden-path mirror 1255-1269) | Per-trigger "every trigger includes idempotency_key + tenant_id" enforced as three document-wide occurrence counts, not per-call association | Warning | Enforcement-strength, not a current goal miss. README is genuinely 2/2/2 with both opts on both trigger calls, so the public story is accurate today. The check could vacuously pass on a FUTURE edit (a trigger missing both opts while another block supplies the tokens) or false-fail a legitimate negative example. Matches REVIEW WR-01. Does not block phase goal; recommend the per-call span fix from WR-01 to keep the lock durable. |
| test/chimeway/doc_contract_test.exs | 1304, 1365 | README/installation `identity:` forbid uses plain substring (would also forbid canonical `recipient_identity:`) | Info | REVIEW WR-03. Not triggered today (README carries no recipients example); asymmetric with golden-path lookbehind. No goal impact. |
| test/chimeway/release_gate_contract_test.exs | 625-630 | `extract_ci_job_block` over-captures across hyphen-named jobs | Info | REVIEW WR-02. Concerns CI-gate job assertions, not the DOCS/ADPT markers verified this phase. Out of scope for phase-79 goal; tracked in REVIEW. |

### Verification Automated (was Human Verification Required)

Both items the initial verification flagged as human judgment were shifted left into automation on
2026-07-03 (zero manual UAT remaining). Full lane green afterward: `mix ci.verify_gates` 506 tests,
0 failures; default `mix test` lane 1153 tests, 0 failures.

#### 1. README decision-page narrative coherence — AUTOMATED

**Was:** subjective human read of README.md top-to-bottom.
**Now, recurring:** `test/chimeway/doc_contract_test.exs#decision-page sections appear in narrative order`
— a deterministic section-ORDER gate (line-anchored heading offsets asserted monotonic) that runs in
the release-blocking `mix ci.verify_gates` lane. Presence markers already existed; this locks the
*order* value prop -> When to use -> Non-goals -> Host-owned boundaries -> Optional surfaces ->
Installation -> Trigger-to-explainable-trace, so a narrative-breaking reorder now fails CI.
**Now, one-time subjective read:** an LLM coherence judge read the full README (2026-07-03) →
**VERDICT coherent, CONFIDENCE high, RECOMMENDATION pass as-is**. This replaces the *human* read with
an *LLM* read. Deliberately NOT wired into CI — a rarely-changing, structurally-locked doc does not
justify a paid/non-deterministic/secret-requiring gate (poor recurring value). Minor non-blocking LLM
note: Quick Start repeats the trigger snippet with different literals than the walkthrough (cosmetic;
optional future polish, not a gap).

#### 2. End-to-end trigger-to-explainability smoke — AUTOMATED

**Was:** `cd examples/chimeway_demo_host && mix demo.up --check` (human-run).
**Now:** `test/chimeway/integration/readme_snippet_test.exs#the documented trigger -> explain_delivery
snippet chain runs end-to-end` — a DB-backed ExUnit test that runs the exact README §"Trigger to
explainable trace" snippet (notifier with `notification_key/0` + `version/0`, `Chimeway.trigger/3`
with `tenant_id` + `idempotency_key`, then `result.trace.delivery_ids` → `Chimeway.Traces.explain_delivery/1`)
and asserts the returned `%Explanation{}` (delivery_id, notification_key "welcome_user", valid status,
non-empty timeline with `:delivery_planned`). Runs in the existing CI `test` job (postgres:15) — no new
job. This is a *stronger* proof than `demo.up --check`, which only migrates+seeds+exits-0 and never
asserts the trace; demo.up's host-boot intent remains covered by the existing `verify.example` CI job.

### Gaps Summary

No blocking gaps. All 5 must-have truths are verified by direct codebase inspection and a green contract suite (505 tests, 0 failures), including the release_gate test that builds and unpacks the real Hex package to prove the packaged README carries the public-story markers. All 5 requirement IDs are accounted for in REQUIREMENTS.md. The DOCS-16 snippets were confirmed against actual lib source (public API accurate; no fictional delegate).

The one enforcement-strength weakness the code review flagged (WR-01, document-wide count vs per-trigger association) is a WARNING, not a BLOCKER: the README is genuinely 2/2/2 with both required opts present on both trigger calls, so the public story is accurate as shipped — the concern is future-regression durability, which the WR-01 per-call-span fix would close.

Status is now `passed`: as of 2026-07-03 both formerly-human items are automated (see "Verification
Automated" above) — a deterministic section-order gate in the release lane plus a one-time LLM
coherence sign-off for the subjective read, and a DB-backed runtime test of the documented
trigger → explain_delivery snippet chain in the CI `test` job. Zero human verification remains.

---

_Verified: 2026-07-03_
_Verifier: Claude (gsd-verifier)_
