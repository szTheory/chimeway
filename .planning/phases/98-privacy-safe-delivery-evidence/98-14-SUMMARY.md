---
phase: 98-privacy-safe-delivery-evidence
plan: 14
subsystem: privacy-safe-delivery-evidence
tags: [elixir, ecto, privacy, traces, adoption-proof]
requires:
  - phase: 98-privacy-safe-delivery-evidence
    provides: SafeEvidence closed diagnostic vocabulary
provides:
  - Closed public lifecycle trace maps
  - Opaque recipient adoption proof fixtures
affects: [admin-trace-search, sigra-lifecycle, adoption-path-gate]
tech-stack:
  added: []
  patterns: [SafeEvidence literal map projections, opaque recipient references]
key-files:
  created: [.planning/phases/98-privacy-safe-delivery-evidence/98-14-SUMMARY.md]
  modified: [lib/chimeway/safe_evidence.ex, lib/chimeway/traces.ex, chimeway_admin/lib/chimeway_admin/live/trace_search_live.ex, priv/adoption_proof/artifact_consumer_fixture.ex]
key-decisions:
  - "[98-14]: Public traces cross SafeEvidence projections and retain tenant identity only on the event root."
metrics:
  duration: 8 min
  completed: 2026-08-16
status: complete
---

# Phase 98 Plan 14: Privacy-Safe Delivery Evidence Summary

Public trace queries now return closed nested maps, while adoption proof notifiers use opaque recipient references.

## Completed Tasks

1. Added SafeEvidence event, notification, delivery, and attempt trace constructors and projected all public trace query results.
2. Updated Admin and Sigra direct consumers to use the closed map vocabulary and masked opaque recipient evidence.
3. Reworked Core and Mailglass generated proof recipients to use bounded `cw_` references; the Mailglass address is supplied only as a rendering `"to"` assign.

## Verification

- Passed: focused traces and privacy-boundary tests; `mix verify.admin`; Sigra and tenant-identity tests; focused Core adoption proof.
- Passed: `mix verify.adoption_paths --only core` emitted one `CHIMEWAY_CORE_PROOF` record.
- Unrun / blocked: `mix verify.runtime_prefix` fails in pre-existing DemoHost seed setup with `{:error, :unsafe_evidence}`.
- Unrun / blocked: `mix verify.adoption_paths --only mailglass` exits 70 at the artifact Mailglass stage; the gate provides no underlying child error.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Preserved Admin notification-key rendering after removal of raw event schemas**
- **Found during:** Task 2
- **Fix:** Included the event notification key in the recipient trace projection and consumed opaque `recipient_id` in the LiveView.
- **Commit:** 84d8730

## Known Stubs

None.

## Self-Check: PASSED

- Required implementation files and task commits exist.
