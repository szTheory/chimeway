# Phase 95: Accrue Billing-Escalation Proof - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-08-09T17:15:43Z
**Phase:** 95-Accrue Billing-Escalation Proof
**Mode:** assumptions
**Areas analyzed:** Natural Accrue Boundary, Clean-Consumer Topology, Public Workflow Evidence, Release Provenance

## Assumptions Presented

### Natural Accrue Boundary
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Initiate dunning through Accrue payment failure and terminate through payment success, not a direct Chimeway notifier call. | Confident | `guides/introduction/accrue-dunning-integration.md`, `deps/accrue/lib/accrue/integrations/chimeway.ex`, `test/chimeway/integrations/accrue_dunning_lifecycle_test.exs` |

### Clean-Consumer Topology
| Assumption | Confidence | Evidence |
| Extend the unpacked-artifact consumer fixture with a separate Accrue proof. | Confident | Phase 93 and 94 contexts; `test/support/artifact_consumer_fixture.ex` |

### Public Workflow Evidence
| Assumption | Confidence | Evidence |
| Emit a dedicated strict sanitized Accrue record proving waiting progression and payment-signal outcome. | Likely | `test/chimeway/integrations/accrue_dunning_lifecycle_test.exs`, `test/support/artifact_consumer_fixture.ex`, `test/chimeway/release_gate_contract_test.exs` |

### Release Provenance
| Assumption | Confidence | Evidence |
| Use released-package labeling only if the resolved Accrue release contains the integration; otherwise label exact-ref compatibility evidence only. | Likely | `mix.lock`, `deps/accrue/hex_metadata.config`, `MAINTAINING.md`, `.github/workflows/ci.yml` |

## Corrections Made

No corrections — user approved the recommended coherent approach.
