---
phase: 60-accrue-docs-release-gate
reviewed: 2026-05-30T13:00:00Z
depth: standard
files_reviewed: 7
findings:
  critical: 0
  warning: 1
  info: 4
  total: 5
status: issues
---

# Phase 60: Code Review Report

**Reviewed:** 2026-05-30  
**Depth:** standard  
**Plans:** 60-01 (DOCS-08 integration guide), 60-02 (DOCS-09 doc-contract), 60-03 (GATE-05 CI + MAINTAINING)  
**Status:** issues

## Summary

Phase 60 delivers the Accrue dunning documentation and release-gate slice cleanly: a Mailglass-parity introduction guide, reciprocal blueprint cross-links, README/HexDocs discoverability, a doc-contract describe locking D-11 required strings and `payment_recovered` drift, and a `verify_accrue` CI job mirroring `verify_mailglass` with pinned sibling checkout.

No critical security or CI correctness issues found. Doc-contract tests pass (200 tests, 0 failures). One documentation terminology warning in the integration guide's workflow description; four informational maintainability notes.

## Critical Issues

None.

## Warnings

### WR-01: Integration guide conflates `cancel_signals` (rule config) with `:waiting` runtime state

**File:** `guides/introduction/accrue-dunning-integration.md` (Section 4, bullet 2)  
**Issue:** Prose reads "workflow enters `:waiting` with `cancel_signals: ["invoice.paid"]`" — at runtime, waiting runs expose `pending_signals`, populated from the rule's `cancel_signals` at `:waiting` entry (see `guides/flows/multi-step-journeys.md`). The blueprint correctly uses `pending_signals` in its escalation description; the integration guide does not.

**Impact:** Adopters inspecting `WorkflowRun` records or traces may look for a nonexistent `cancel_signals` field on the run and misdiagnose signal routing.

**Suggestion:** Reword bullet 2 to match the blueprint and journey guide — e.g. "workflow enters `:waiting` with `pending_signals: ["invoice.paid"]` (auto-populated from the rule's `cancel_signals`)". Optionally add a doc-contract `requires pending_signals` for the guide to prevent recurrence.

## Info

- **IN-01:** Guide `accrue_dep/0` snippet omits `optional: true` on the path dep branch; `mix.exs` includes it. Harmless for copy-paste but slightly divergent from repo convention.
- **IN-02:** `accrue-dunning-integration.md` is not in `@consumer_files` for the GATE-01 version-alignment describe (`README.md`, `installation.md`, `golden-path.md` only). Guide contains `{:chimeway, "~> 1.0"}` today but drift won't fail CI until manually caught.
- **IN-03:** ECOS-07 blueprint doc-contract lacks a `payment_recovered` forbid test (guide describe has one per D-12). Blueprint is clean now; guide-only guard leaves blueprint open to deprecated signal naming drift.
- **IN-04:** `verify_accrue` cache key hashes `mix.lock` only, not the pinned Accrue SHA. Ref bumps in `ci.yml` without lockfile changes may restore stale `_build` artifacts; mitigated by `deps.compile accrue --force` in the `verify.accrue` alias but worth including Accrue ref in cache key when bumping integration pins.

## Positive Observations

- Guide vs blueprint separation mirrors Phase 57 Mailglass pattern; reciprocal links are correct.
- Billing-event primary path and explicit forbid of host `Chimeway.trigger(DunningNotifier, ...)` adoption are clear and threat-model aligned.
- `verify_accrue` job structure matches `verify_mailglass` (Postgres, pinned checkout SHA, dedicated cache key, ecto create/migrate, `mix verify.accrue`).
- MAINTAINING pre-ship septet accurately documents all seven gates including `ACCRUE_PATH` sibling checkout expectations.
- Doc-contract describe reuses shared forbidden-string guards and adds guide-specific coverage (14 required strings, billing-state split, dependencies section, `payment_recovered` forbid).

## Recommended Actions

1. Fix Section 4 bullet 2 terminology in `accrue-dunning-integration.md` (WR-01)
2. Optional: extend doc-contract with `pending_signals` require and/or blueprint `payment_recovered` forbid (IN-03)
3. Optional: add `accrue-dunning-integration.md` to `@consumer_files` in version-alignment describe (IN-02)
