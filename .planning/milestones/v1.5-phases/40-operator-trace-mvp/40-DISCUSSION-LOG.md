# Phase 40: Operator Trace MVP - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-05-28
**Phase:** 40-operator-trace-mvp
**Mode:** assumptions
**Areas analyzed:** Package shape, Auth seam, UI surface & mounting, Search & result flow, Timeline presentation, Redaction policy, Demo host proof, MVP scope boundary

## Assumptions Presented

### Package shape (INV-001)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Ship `chimeway_admin` as in-repo sibling Mix project at `chimeway_admin/`, not LiveViews in core | Confident | Core `mix.exs` has no Phoenix deps; ROADMAP names separate package; `prompts/chimeway-engineering-dna-from-prior-libs.md` §3; v1.5 assessment thread |

### Auth seam
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| New `ChimewayAdmin.Auth` behaviour with host-implemented `authorize/2`; fail closed; no hard-coded auth | Confident | `prompts/chimeway-admin-ui-and-operator-ia.md`; `prompts/chimeway-host-app-integration-seam.md`; no existing admin auth in `lib/` |

### UI surface & mounting
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Phoenix LiveView in `chimeway_admin`; mountable router under host authenticated scope | Confident | Admin IA prompt; demo host Phoenix 1.7; Phase 39 D-01 deferred operator UI here |

### Search & result flow
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Explicit search mode: Recipient ID → `find_traces_for_recipient/2`; Correlation ID → `find_traces_by_correlation_id/1`; detail via `explain_delivery/1` | Confident | `lib/chimeway/traces.ex`; Phase 38 D-05; Phase 39 Support Operator flow |

### Timeline presentation
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Render `Explanation.timeline` from `explain_delivery/1`; no new engine timeline APIs | Confident | `build_timeline/5` in `lib/chimeway/traces.ex`; Phase 32 TRAC-01/02; OPER-02 requirement |

### Redaction policy
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| View-layer redaction for MVP; Explanation fields only in detail; truncated recipient in lists | Likely | `Chimeway.Traces.Explanation` omits payloads; `Chimeway.Telemetry` PII redaction; no trace redaction module yet |

### Demo host proof
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Wire into `examples/chimeway_demo_host` with permissive dev auth stub; README + golden-path cross-link | Confident | Demo host as E2E proof surface; Phase 39 deferred HTTP trace route |

### MVP scope boundary
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Trace lookup only (search + detail); exclude inbox, campaigns, health, registry | Confident | ROADMAP success criterion 3; OPER-02; Phase 38/39 deferrals |

## Corrections Made

No corrections — all assumptions confirmed by user (selected "Yes, proceed").

## Methodology Lenses Applied

- **Cohesive Recommendation Default / One-Shot Recommendation Bias:** Single stack recommendation — sibling package + existing Traces API + LiveView mount.
- **Durable Explainability Bias:** UI reads `Explanation` from durable rows, not transient job state.
- **High-Impact Escalation Gate:** INV-001 resolved as Confident recommendation (sibling package), not left open for plan-phase.
- **Research-First Decision Ownership:** Codebase read before user interaction; ~2 interactions total.

## External Research

Not performed — codebase provided sufficient evidence for all assumption areas.
