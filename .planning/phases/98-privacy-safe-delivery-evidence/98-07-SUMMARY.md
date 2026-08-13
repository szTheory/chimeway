---
phase: 98-privacy-safe-delivery-evidence
plan: 07
subsystem: privacy-safe evidence
tags: [elixir, ecto, privacy, traces, digest]
requires:
  - phase: 98-privacy-safe-delivery-evidence
    provides: shared SafeEvidence projection boundaries
provides:
  - Field-specific closed grammars for durable facts and digest evidence
  - Fail-closed digest-resolution reason persistence
  - Safe digested-delivery trace explanations
affects: [trigger, deliveries, traces, digests]
tech-stack:
  added: []
  patterns:
    - Closed literal field dispatch with duplicate key omission
    - Digest evidence reconstructed from validated literal fields
key-files:
  created: [.planning/phases/98-privacy-safe-delivery-evidence/98-07-SUMMARY.md]
  modified:
    - lib/chimeway/safe_evidence.ex
    - lib/chimeway/deliveries.ex
    - lib/chimeway/delivery_planning.ex
    - lib/chimeway/trigger.ex
    - test/chimeway/trigger_sanitization_test.exs
    - test/chimeway/privacy_boundary_test.exs
    - test/chimeway/traces_test.exs
key-decisions:
  - "[98-07]: Approved evidence keys use field-specific grammars and ambiguous atom/string duplicates are omitted."
  - "[98-07]: Unsafe digest reasons are stored as nil; trace digest maps are rebuilt from closed fields."
requirements-completed: [PRIV-03, PRIV-04]
coverage:
  - id: D1
    description: Trigger and digest paths reject hostile values under approved keys while preserving safe lifecycle evidence.
    requirement: PRIV-03
    verification:
      - kind: integration
        ref: env MIX_ENV=test mix test test/chimeway/trigger_sanitization_test.exs test/chimeway/privacy_boundary_test.exs --warnings-as-errors
        status: pass
    human_judgment: false
  - id: D2
    description: Digested delivery explanations retain categorical digest facts and the real digested status without raw text.
    requirement: PRIV-04
    verification:
      - kind: integration
        ref: env MIX_ENV=test mix test test/chimeway/traces_test.exs test/chimeway/orchestration/digest_explainability_test.exs --warnings-as-errors
        status: pass
    human_judgment: false
duration: 14 min
completed: 2026-08-13
status: complete
---

# Phase 98 Plan 07: Privacy-Safe Delivery Evidence Summary

**Closed field grammars now prevent approved keys from laundering sensitive values through Trigger, digest persistence, and delivery explanations while preserving `:digested` lifecycle evidence.**

## Accomplishments

- Replaced generic scalar acceptance with field-specific code, enum, ID, timestamp, integer, boolean, and nested digest-entry validation.
- Normalized unsafe digest-resolution reasons to `nil` before durable updates and rebuilt trace digest maps from validated fields.
- Added TDD regressions for hostile approved-key Trigger inputs, unsafe digest reasons, and real `:digested` explanations.

## Verification

- PASS: focused Phase 98 suites (57 tests, 0 failures).
- PASS: `mix format --check-formatted` for plan-owned files.
- PASS: clean `mix ci` after restoring compatible typed operational projections.

## Post-Execution Regression Fix

- Restored validated opaque lifecycle IDs, correlation references, stable recipient references, `superseded` cancellation evidence, and fixed-format digest metadata.
- Kept rendering declarations public and intact; delivery planning drops only its non-rendering recipient helper before channel validation and can recover a persisted render identity without host render context.
- Existing Trigger, telemetry, deferred-lifecycle, digest-lifecycle, notifier-contract, and Phase 98 privacy tests now provide regression coverage.

## Follow-up Runtime Compatibility Fix

- Preserved trusted internal render-channel declarations through Trigger and `SafeEvidence.render_channels/1`, whose per-entry render key/version checks remain closed.
- Reused persisted render assigns when a dispatch-only custom-channel notifier intentionally has no rendering/build callback.
- Verified persisted digest orchestration and workflow linkage recovery without re-entering callback code.

## Final Runtime Regression Fix

- Restored canonical privacy-filtered notification channel snapshots while carrying the initial channel payloads only in the in-process dispatch options.
- Pre-rendered initial delivery payloads once at Trigger time, so dispatch does not invoke notifier rendering a second time; payloads remain on delivery records and are omitted from trace evidence.
- Restored stable opaque host recipient references and identity ordering, and accepted dotted render keys in the closed trace-identity grammar.
- PASS: render identity, Trigger pipeline, Scenario J lifecycle, and core/mailglass/accrue release-gate proof cases (12 tests, 0 failures).
- UNRUN: atom-count release-gate case could not start because the shared PostgreSQL test environment reported `too_many_connections`; this is an external concurrent-test capacity condition.

## Task Commits

1. **Task 1 RED:** `06c25fd` — failing privacy evidence regressions.
2. **Task 1 GREEN:** `2b9f36c` — closed approved-key evidence laundering.
3. **Follow-up:** `b13b360` — preserve runtime rendering semantics.

## Decisions Made

- Duplicate atom/string spellings for a fact are omitted instead of depending on input enumeration order.
- Unsafe unclassified digest text has no manual-review retention path; lifecycle state remains available with a `nil` reason.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Restored existing safe channel, time-zone, correlation, workflow-ID, and workflow-step projections.**
- **Found during:** Task 1 full CI verification.
- **Issue:** Initial field grammar tightening rejected valid typed operational values.
- **Fix:** Added explicit field-family validators without restoring a generic binary fallback.
- **Verification:** `mix ci` passed.
- **Committed in:** `2b9f36c`.

**2. [Rule 1 - Bug] Restored established typed delivery and rendering operations after clean CI exposed regressions.**
- **Found during:** Post-wave isolated `mix ci`.
- **Issue:** Overly narrow schemas rejected opaque operational IDs and fixed digest metadata, while recipient/render handling broke regular Trigger and recovery paths.
- **Fix:** Added typed opaque-reference and fixed digest-template validators, preserved stable recipient refs, and constrained delivery-boundary render cleanup.
- **Verification:** focused 80-test suite and clean `mix ci` passed.

**3. [Rule 1 - Bug] Restored internal channel declarations and persisted recovery paths.**
- **Found during:** post-wave orchestrator CI.
- **Issue:** Privacy redaction removed legitimate `email` channel keys before field-specific render-channel validation; dispatch-only custom notifiers were incorrectly asked to render.
- **Fix:** Kept internal declarations intact until literal render identity validation and used persisted assigns when no rendering callback exists.
- **Verification:** specified recovery/custom-channel cases plus Phase 98 privacy suites (61 tests, 0 failures).

**4. [Rule 1 - Bug] Separated initial runtime rendering from durable evidence snapshots.**
- **Found during:** authoritative clean CI follow-up.
- **Issue:** preserving internal rendering declarations in the durable snapshot bypassed canonical filtering, reordered host recipients, and caused an unnecessary second render callback.
- **Fix:** restored filtered snapshots; precomputed the initial delivery payloads transiently and retained only closed render identity in traces.
- **Verification:** targeted render identity, Trigger, lifecycle, and release-proof cases (12 tests, 0 failures).
- **Committed in:** `b13b360`.

## Known Stubs

None.

## Self-Check: PASSED

- Found task commits `06c25fd`, `2b9f36c`, and `b13b360`.
- Found all modified production and test files.
- No tracked file deletions or placeholder stubs introduced.
