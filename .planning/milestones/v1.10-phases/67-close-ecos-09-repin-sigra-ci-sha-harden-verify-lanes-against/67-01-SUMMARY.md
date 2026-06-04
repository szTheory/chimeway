---
phase: 67
plan: 01
subsystem: ci
tags:
  - testing
  - github-actions
  - security
dependency_graph:
  requires: []
  provides:
    - strict integration check guards
  affects:
    - .github/workflows/ci.yml
    - test/test_helper.exs
    - test/chimeway/integrations/sigra_auth_harness_test.exs
    - test/chimeway/integrations/accrue_dunning_harness_test.exs
    - test/chimeway/integrations/threadline_telemetry_harness_test.exs
    - test/chimeway/release_gate_contract_test.exs
tech_stack:
  added: []
  patterns:
    - integration-tests-floor
key_files:
  created: []
  modified:
    - .github/workflows/ci.yml
    - test/test_helper.exs
    - test/chimeway/integrations/sigra_auth_harness_test.exs
    - test/chimeway/integrations/accrue_dunning_harness_test.exs
    - test/chimeway/integrations/threadline_telemetry_harness_test.exs
    - test/chimeway/release_gate_contract_test.exs
metrics:
  duration: 8min
  completed_date: "2026-06-03"
---

# Phase 67 Plan 01: Close ECOS-09 Summary

This plan closed the ECOS-09 defect by strictly validating external integrations.

## Work Completed

- Repinned Sigra CI SHA to `62ceb46a38c4e617f6c06d874ecb12e1ab19d97c` to ensure integration code is present in CI sibling checkout.
- Added strict `else-raise` paths to `test_helper.exs` conditional compilation blocks for Sigra and Accrue when the integration file is missing.
- Hardened integration harness tests to assert module loads and verify existence of required functions (`dispatch_magic_link_after_request/3` for Sigra, `start_campaign/3` for Accrue, `attach/0` for Threadline).
- Added a `verify-lane test-count floor` block to `test/chimeway/release_gate_contract_test.exs` ensuring tests don't fail silently by skipping tests.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed test_helper.exs SyntaxError**
- **Found during:** Task 3
- **Issue:** A `.mode(Sigra.TestRepo, :manual)` and an `end` leaked at EOF in `test_helper.exs` causing a syntax error.
- **Fix:** Removed the stray characters.
- **Files modified:** `test/test_helper.exs`
- **Commit:** [Included in 5b49d1c]

## Known Stubs
None.

## Threat Flags
None.

## Self-Check: PASSED
- `test/test_helper.exs` syntax fix confirmed working.
- `test/chimeway/release_gate_contract_test.exs` integration count assertions working successfully.