# Phase 71: Redaction and Explainability Contracts - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md - this log preserves the analysis.

**Date:** 2026-06-04T18:19:42Z
**Phase:** 71-redaction-and-explainability-contracts
**Mode:** assumptions
**Areas analyzed:** Boundary Strategy, DTO Contract, Rendered HTML Leak Tests, Explanation Language, Definitions Copy

## Assumptions Presented

### Boundary Strategy

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Keep redaction as a two-layer contract: core `Chimeway.Admin` DTOs expose only stable explainability fields, while `chimeway_admin` LiveViews/components own display masking for recipient identities and timeline details. | Likely | `lib/chimeway/admin.ex`; `test/chimeway/admin_test.exs`; `chimeway_admin/lib/chimeway_admin/redaction.ex`; `chimeway_admin/lib/chimeway_admin/live/dashboard_live.ex`; `chimeway_admin/lib/chimeway_admin/live/feed_live.ex`; `chimeway_admin/lib/chimeway_admin/live/trace_detail_live.ex` |

### DTO Contract

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Tighten DTO tests around an allowlist of stable fields, but do not remove `recipient_id` from every DTO yet; instead require rendered HTML to mask full recipient PII and consider redacted recipient display fields as an implementation-local improvement. | Unclear | `lib/chimeway/admin.ex`; `test/chimeway/admin_test.exs`; `chimeway_admin/lib/chimeway_admin/redaction.ex`; `chimeway_admin/lib/chimeway_admin/live/feed_live.ex`; `chimeway_admin/lib/chimeway_admin/live/dashboard_live.ex`; `chimeway_admin/lib/chimeway_admin/live/recovery_live.ex` |

### Rendered HTML Leak Tests

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Add LiveView rendered-HTML leak tests across dashboard, trace detail, feed, recovery, and definitions; include payloads, render data, provider bodies/responses, metadata, tokens/secrets/auth codes, and full recipient PII. | Confident | `.planning/ROADMAP.md`; `chimeway_admin/test/chimeway_admin/live/recovery_live_test.exs`; `chimeway_admin/lib/chimeway_admin/components/timeline_event.ex`; `chimeway_admin/lib/chimeway_admin/live/feed_live.ex`; `chimeway_admin/lib/chimeway_admin/live/dashboard_live.ex` |

### Explanation Language

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Centralize operator labels for lifecycle states in `ChimewayAdmin.Components.Status` or a nearby presenter, mapping raw states/outcomes into distinct copy for sent, provider accepted, delivered, suppressed, retryable failure, and terminal failure without changing durable core status atoms. | Likely | `chimeway_admin/lib/chimeway_admin/components/status.ex`; `lib/chimeway/traces.ex`; `test/chimeway/traces_test.exs`; `.planning/REQUIREMENTS.md`; `.planning/ROADMAP.md` |

### Definitions Copy

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Keep Definitions as DB-inferred durable key/version history and add rendered-copy/tests that explicitly avoid code registry or skew detection claims. | Confident | `.planning/phases/68-admin-truth-alignment/68-CONTEXT.md`; `lib/chimeway/admin.ex`; `chimeway_admin/lib/chimeway_admin/live/definitions_live.ex`; `.planning/ROADMAP.md` |

## Corrections Made

No corrections - all assumptions confirmed.
