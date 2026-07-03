# Phase 79: Front Door and Docs IA - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-07-03
**Phase:** 79-front-door-and-docs-ia
**Mode:** assumptions
**Areas analyzed:** README rewrite, DOCS-16 canonical snippets, stub/stale guide disposition, ADPT-01 smoke path, contract enforcement

## Assumptions Presented

### README Structure / Content Rewrite (DOCS-14 / DOCS-15)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Rewrite README as additive superset: lead with local-first value prop + explainability, add Use cases / Non-goals / Host boundaries / Optional surfaces, preserve all contract-required strings | Confident | README.md (70 lines, missing all four sections); doc_contract_test.exs README contract L1330-1391; release_gate_contract_test.exs L344-374 |

### DOCS-16 Canonical Snippet Set
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Snippet chains notifier `notification_key/0` (stable key) → `Chimeway.trigger(Notifier, params, idempotency_key:, tenant_id:)` → `prefix: "chimeway"` → `Chimeway.Traces.explain_delivery(delivery_id)` (no `Chimeway.explain_delivery` delegate) | Confident | lib/chimeway.ex; lib/chimeway/traces.ex L135/69/104; golden-path.md L86-95/130; doc_contract_test.exs L1222-1261 |

### Stub / Stale Guide Disposition (DOCS-17)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Three 9-line Flows stubs (async-dispatch, policy-and-preferences, trigger-to-delivery); delink from README + docs.extras, backlog completion; fix stale jonlunsford URLs in first-hop guides | Confident (which are stubs) / Likely (delink vs complete) | wc -l flow guides = 9 vs multi-step-journeys = 232; README L65; stubs not contract-enforced; golden-path.md L167/171/191/192 legacy URLs |

### ADPT-01 Smoke Path
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Extend existing unpacked-Hex artifact test to assert packaged README carries DOCS-14/15/16 invariants; keep demo-host as runtime companion (not primary anchor) | Likely | release_gate_contract_test.exs L466-531; mix.exs verify.parity L91-93; examples/chimeway_demo_host README |

### Contract Enforcement
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Extend existing "README install doc contract" block with new DOCS-14/15/16 markers + trace-snippet requirement + per-trigger invariant; no new test file | Confident | doc_contract_test.exs L1247-1261 (invariant pattern), L1367-1390 (@required list pattern) |

## Corrections Made

No corrections — both escalated (Likely) items were confirmed to the recommended option:

### ADPT-01 scope
- **Recommended & chosen:** Packaged-doc truth — extend the unpacked-Hex artifact test, no new
  runnable fresh-host harness.

### Stub guides
- **Recommended & chosen:** Delink all three flow stubs from README + docs.extras and backlog
  completion (over completing `trigger-to-delivery` or all three).

## External Research

None performed — codebase provided sufficient evidence for a docs/packaging phase.
