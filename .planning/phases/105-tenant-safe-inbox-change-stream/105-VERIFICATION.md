---
phase: 105-tenant-safe-inbox-change-stream
verified: 2026-09-12T16:40:00Z
status: passed
score: 8/8 must-haves verified
behavior_unverified: 0
overrides_applied: 0
behavior_unverified_items: []
human_verification: []
---

# Phase 105 Verification Report

**Phase Goal:** Connected inbox clients can refresh from durable state when their exact authorized stream changes, without making Phoenix a core dependency.

## Goal Achievement

| # | Observable truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Core emits one closed, versioned hint after durable creation and each first lifecycle transition. | VERIFIED | Post-commit trigger and first seen/read/archive tests pass; duplicate trigger and repeated transitions emit no second hint. |
| 2 | Publisher failure cannot alter durable lifecycle truth and exposes only stable outcome telemetry. | VERIFIED | Error-return, invalid-return, raise, exit, and durable-write containment tests pass with closed telemetry metadata. |
| 3 | Core remains independent of Phoenix and the optional inbox package. | VERIFIED | Root compile/test passes; source and dependency scans find zero `Phoenix.PubSub`, `ChimewayInbox`, or Phoenix dependency references. |
| 4 | Publisher and subscriber share one opaque tenant-and-recipient stream. | VERIFIED | HMAC-SHA256 topic tests prove same-scope delivery, scope separation, domain/length separation, and absence of raw inputs. |
| 5 | PubSub traffic contains only the closed reload tuple and unsafe configuration fails closed. | VERIFIED | Exact-message and invalid-ref/weak-secret/invalid-server tests pass without scope or secret logging. |
| 6 | Connected bells reload authoritative badge/items without polling and preserve interaction state. | VERIFIED | LiveView tests prove immediate refresh, open-panel preservation, and reset from loaded page two to authoritative page one. |
| 7 | Other tenants, recipients, and unrelated messages cannot reveal or refresh inbox state. | VERIFIED | Wrong-tenant, wrong-recipient, direct-unrelated-message, and durable cross-tenant tests pass. |
| 8 | Every reload reauthorizes, and the reference host exercises opaque identity plus the opt-in adapter. | VERIFIED | Auth-drift redirect test and demo-host inbox proof pass against configured `DemoHost.PubSub`. |

**Score:** 8/8 truths verified. No conversational UAT is required or used.

## Required Artifacts

| Artifact | Status | Evidence |
| --- | --- | --- |
| Core change/publisher boundary | VERIFIED | Closed vocabulary, no-op default, post-commit trigger integration, and failure containment tests pass. |
| `ChimewayInbox.ChangeStream` | VERIFIED | Secret/config validation plus shared HMAC derivation and isolated subscription tests pass. |
| `ChimewayInbox.PubSubPublisher` | VERIFIED | Implements the core behaviour and broadcasts only the exact reload tuple. |
| `BellDropdownLive` stream handling | VERIFIED | Connected-only subscription, exact-message reauthorization/reload, and catch-all isolation tests pass. |
| Demo-host adoption | VERIFIED | Stable opaque recipient derivation and configured PubSub publisher pass the executable inbox proof. |

## Behavioral Evidence

- Core focused suite — passed: 22 tests, 0 failures, warnings as errors.
- Optional package focused suite — passed: 20 tests, 0 failures, warnings as errors.
- `mix verify.inbox` — passed: 21 optional-package tests plus 2 demo-host tests, 0 failures.
- Root Phoenix-optional source/dependency scans — passed with zero forbidden references.
- Phase-close review — no open correctness, privacy, or authorization findings.

## Verdict

**PASSED.** INBX-03 and INBX-04 are fully backed by machine-executable evidence. Phase 106 may proceed.
