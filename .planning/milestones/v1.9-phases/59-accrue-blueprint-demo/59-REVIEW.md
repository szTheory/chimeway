---
phase: 59-accrue-blueprint-demo
reviewed: 2026-05-30T12:30:00Z
depth: standard
files_reviewed: 7
findings:
  critical: 0
  warning: 1
  info: 3
  total: 4
status: issues
---

# Phase 59: Code Review Report

**Reviewed:** 2026-05-30  
**Depth:** standard  
**Plans:** 59-01 (DEMO-07 demo proof), 59-02 (ECOS-07 blueprint + doc-contract)  
**Status:** issues

## Summary

Phase 59 delivers a coherent Accrue dunning demo lane: billing-event triggers via `Accrue.Test.trigger_event/2`, Logger email isolation, `invoice.paid` termination with Oban signal drain, admin LiveView trace proof, published blueprint recipe, and ECOS-07 doc-contract guards. Functional behavior matches phase 58 ECOS-06 contracts.

No critical security or correctness bugs found in scope. One maintainability warning around Application env teardown parity with the Mailglass proof test; three informational notes on duplication, seed side-effects, and verify path assumptions.

## Critical Issues

None.

## Warnings

### WR-01: Accrue proof test setup does not restore adapter/dunning Application env

**File:** `examples/chimeway_demo_host/test/demo_host_web/accrue_dunning_proof_test.exs`  
**Issue:** Setup mutates `:accrue :dunning` and `:chimeway :channel_adapter_configs` but `on_exit/1` restores only `:accrue :env` and `:chimeway :dispatcher`. Mailglass proof restores adapter configs on exit.

**Suggestion:** Mirror the Mailglass pattern — snapshot and restore `:accrue :dunning` and `:chimeway :channel_adapter_configs` in `on_exit/1`.

## Info

- **IN-01:** Duplicated harness logic between `accrue_support/fixtures.ex` and `accrue_support/seeds.ex`
- **IN-02:** `seed_accrue_dunning/0` mutates Application env without restoration (fine in tests, surprising in IEx)
- **IN-03:** `verify.accrue` hardcodes sibling Accrue checkout path

## Recommended Actions

1. Restore adapter/dunning env in accrue proof test `on_exit/1` (WR-01)
2. Consider consolidating duplicated stub/drain helpers when touching harness again
3. Optional: note Application env side-effects in blueprint "Runnable demo" section
