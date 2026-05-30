---
phase: 60-accrue-docs-release-gate
fixed_at: 2026-05-30T14:00:00Z
review_path: 60-REVIEW.md
fix_scope: critical_warning
findings_in_scope: 1
fixed: 1
skipped: 0
iteration: 1
status: all_fixed
---

# Phase 60: Code Review Fix Report

**Fixed:** 2026-05-30  
**Scope:** critical_warning (Critical + Warning only)  
**Iteration:** 1

## Summary

Applied WR-01 from the phase 60 code review: corrected integration guide terminology to use runtime `pending_signals` instead of conflating rule-config `cancel_signals` with `:waiting` state. Added doc-contract guard to prevent recurrence.

## Fixed

### WR-01: Integration guide conflates `cancel_signals` with `:waiting` runtime state

**File:** `guides/introduction/accrue-dunning-integration.md`  
**Change:** Reworded Section 4 bullet 2 to match blueprint and journey guide — `pending_signals: ["invoice.paid"]` with parenthetical explaining auto-population from rule `cancel_signals`.

**File:** `test/chimeway/doc_contract_test.exs`  
**Change:** Added `pending_signals` to accrue integration guide `@required` list.

## Skipped

None in scope. Four Info findings (IN-01 through IN-04) were out of scope for `critical_warning` fix pass.

## Verification

- Doc-contract tests for accrue integration guide pass with new `pending_signals` require.
