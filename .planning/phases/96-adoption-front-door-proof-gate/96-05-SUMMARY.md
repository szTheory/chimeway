---
phase: 96-adoption-front-door-proof-gate
plan: "05"
subsystem: adoption-proof
tags: [elixir, release-gate, accrue, mailglass]
requires:
  - phase: 96-adoption-front-door-proof-gate
    provides: bounded immutable archive validation
provides:
  - redacted Accrue validator failures
  - current-source release contracts
affects: [GATE-01, DOCS-01]
tech-stack:
  added: []
  patterns: [fixed-redacted-cli-diagnostic, external-compiler-resource]
key-files:
  created: [96-05-SUMMARY.md]
  modified: [scripts/prove-accrue-consumer.exs, test/support/artifact_consumer_fixture.ex, test/chimeway/release_gate_contract_test.exs]
requirements-completed: [GATE-01, DOCS-01]
completed: 2026-08-10
status: complete
---

# Phase 96 Plan 05: Adoption Proof Gate Closure Summary

**Accrue archive failures now emit one redacted provenance line, while release contracts compile current fixture source and the full gate is green.**

## Accomplishments

- Mapped every archive-validator `{:error, _}` to `Accrue package proof: archive validation failed` with exit 65.
- Added wrong-digest and malformed-archive CLI regressions, fixture compiler dependency tracking, and precise proof-record source checks.
- Repaired discovered fixture-contract parity cases and ran `mix ci.verify_gates` successfully: 611 tests, 0 failures, 486.8s.

## Task Commits

1. Task 1 RED — e556ce6
2. Task 1 GREEN — 9bf99ef
3. Task 2 RED — 741c53f
4. Task 2 GREEN — 4932588
5. Gate-parity repairs — 75bd050, f5cdcd5, 2dc793b

## Verification

- PASS — focused Accrue CLI redaction regression.
- PASS — focused Mailglass/source-contract checks.
- PASS — `mix ci.verify_gates` (611 tests, 0 failures, 486.8s).

## Deviations from Plan

### Auto-fixed Issues

- **[Rule 1 - Contract parity]** Narrowed contradictory Core repository source checks and made the packaged CLI avoid booting an unconfigured root app.

## Known Stubs

None.

## Self-Check: PASSED

- Confirmed all Plan 05 task commits exist and the canonical release gate passed.
