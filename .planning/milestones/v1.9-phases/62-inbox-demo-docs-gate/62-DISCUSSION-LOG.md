# Phase 62: Inbox Demo, Docs & Gate - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-05-30
**Phase:** 62-inbox-demo-docs-gate
**Mode:** assumptions
**Areas analyzed:** Demo Host Mount, Golden-Path Guide & Doc-Contract, verify.inbox & CI, Wave Ordering & MAINTAINING Octet

## Assumptions Presented

### Demo Host Mount Pattern (DEMO-08)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Clone chimeway_admin pattern: path dep, DemoHost.InboxAuth, chimeway_inbox_routes/0 in demo router | Confident | `examples/chimeway_demo_host/lib/demo_host_web/router.ex`, 61-CONTEXT |
| Dedicated `@moduletag :inbox` proof test module, not journey_test.exs extension | Likely | `mailglass_delivery_proof_test.exs`, `accrue_dunning_proof_test.exs`, verify alias patterns |
| Proof: list → mark_read via LiveView → badge; mark_seen via Chimeway.mark_seen/3 API | Likely | `bell_dropdown_live_test.exs` lines 97–99; ROADMAP SC #1 |
| DemoHost.Seeds.seed_inbox/0 + InboxAuth session → recipient identity | Likely | `seeds.ex`, `seed_accrue_dunning/0` pattern |

### Golden-Path Guide & Doc-Contract (DOCS-08/09 Inbox)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| New guide at `guides/introduction/inbox-integration.md` | Confident | Phase 60 D-03/D-04; no inbox guide in guides/ |
| Doc-contract describe mirroring Accrue block in doc_contract_test.exs | Confident | Accrue describe line 441+; hexdocs extras contract |
| Wave 62-02 blocked on 62-01 for runnable verification references | Confident | ROADMAP wave order; Accrue guide cites Phase 59 proof |

### verify.inbox Alias & CI Job (GATE-05 Inbox)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| verify.inbox = chimeway_inbox tests + demo --only inbox; no sibling checkout | Likely | mix.exs verify.example prep; in-repo path deps |
| CI verify_inbox job + release_gate_contract octet parity | Confident | ci.yml verify_mailglass template; release_gate_contract_test.exs |
| No root --only inbox unless new tagged root tests | Likely | inbox_* tests untagged in root test/ |

### Wave Ordering & MAINTAINING Octet
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| MAINTAINING seven → eight gates; release_gate_contract seven → eight | Confident | MAINTAINING.md lines 48–68; 60-03 septet pattern |
| Wave 1 parallel 62-01 + 62-03; 62-02 blocked on 62-01 | Confident | ROADMAP; Phase 60 Accrue wave pattern |

## Corrections Made

No corrections — all assumptions confirmed by user ("Yes, proceed").

## External Research

None required — Phase 62 patterns anchored in Phase 60 Accrue vertical slice, Phase 61 inbox package artifacts, and existing demo-host selective-proof conventions.
