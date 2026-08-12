---
phase: 97-tenant-identity-compatible-upgrade
plan: 14
subsystem: inbox-auth-and-ci
tags: [elixir, phoenix-liveview, tenant-isolation, ci]
requires:
  - phase: 97-tenant-identity-compatible-upgrade
    provides: explicit tenant scope
provides:
  - Total fail-closed mounted Inbox authorization under identity drift
  - Required unfiltered Inbox verification in the PR aggregate
affects: [tenant-safety, pull-request-gates]
tech-stack:
  added: []
  patterns: [exact mounted identity equality, executable acceptance evidence]
key-files:
  created: [.planning/phases/97-tenant-identity-compatible-upgrade/97-14-SUMMARY.md]
  modified: [chimeway_inbox/lib/chimeway_inbox/live_auth.ex, chimeway_inbox/test/chimeway_inbox/live/bell_dropdown_live_test.exs, .github/workflows/ci.yml, test/chimeway/release_gate_contract_test.exs, AGENTS.md]
key-decisions:
  - "[97-14]: Successful host identity mismatches redirect without rebinding mounted authority."
  - "[97-14]: Machine-testable Inbox acceptance is a required PR lane, not conversational UAT."
metrics:
  duration: 16 min
  tasks_completed: 2
status: complete
---

# Phase 97 Plan 14: Inbox Identity Drift Summary

**Mounted Inbox events now fail closed for every changed recipient/tenant pair, with the Inbox verification lane required on pull requests.**

## Accomplishments

- Added a total successful-mismatch clause to `LiveAuth.ensure_authorized/2` that redirects before any handler reads or mutates Inbox state.
- Added mounted LiveView proofs for tenant-only, recipient-only, and combined drift, plus a non-mutating toggle event and persisted no-mutation assertions.
- Reclassified the machine-testable tracer as `type="auto"`; AGENTS.md now forbids conversational UAT for executable acceptance evidence.
- Added `verify_inbox` to `pr-gate` needs, environment, and aggregate command; its PR exclusion is removed and contract-tested.

## Task Commits

1. `25cca4e` — RED tenant-drift regression test.
2. `a5c1104` — fail-closed successful-mismatch implementation.
3. `b225ff0` — recipient and combined-drift coverage.
4. `3d5ed1d` — required unfiltered Inbox PR lane and automation policy.

## Verification

- PASS: `mix format --check-formatted` for changed Inbox and release-gate test files.
- PASS: focused Inbox LiveView suite — 10 tests, 0 failures.
- PASS: isolated `mix verify.inbox` — package suite 11 tests, demo-host Inbox suite 2 tests, 0 failures.
- PASS: `mix ci.verify_gates` — doc and release-gate contracts passed.
- PASS: final `mix ci.test` — 1,373 tests, 0 failures (35 excluded); the alias now skips partner repo setup owned by separately required `verify.*` lanes.
- PASS: Phase verifier — 4/4 must-haves and TENANT-01..03 satisfied with no human UAT.

## Deviations from Plan

### Authorized automation expansion

- Updated the plan task type and repository policy so objectively machine-testable acceptance work is automated, and made `verify_inbox` a required unfiltered PR gate with executable contract proof.

## Known Stubs

None.

## Self-Check: PASSED

- Found all changed Inbox, CI, policy, and contract-test files.
- Found task commits `25cca4e`, `a5c1104`, `b225ff0`, and `3d5ed1d`.
