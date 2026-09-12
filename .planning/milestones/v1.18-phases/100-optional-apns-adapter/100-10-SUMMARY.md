---
phase: 100-optional-apns-adapter
plan: 10
subsystem: apns
tags: [elixir, apns, validation, privacy, pigeon]
requires:
  - phase: 100-optional-apns-adapter
    provides: durable APNs intent, payload, adapter, and consumer-gate seams
provides:
  - Closed opaque open-reference validation shared by durable and direct payload paths
  - Header-safe explicit APNs collapse validation before transport construction
  - Stored-intent rejection before lookup or provider handoff
affects: [apns-delivery, provider-boundary, privacy]
tech-stack:
  added: []
  patterns:
    - Internal shared closed-format validator for provider-bound opaque references
    - Anchored ASCII allowlist for caller-provided APNs header values
key-files:
  created:
    - lib/chimeway/apns/opaque_reference.ex
  modified:
    - lib/chimeway/apns/request_intent.ex
    - lib/chimeway/apns/payload.ex
    - test/chimeway/apns/request_test.exs
    - test/chimeway/adapters/apns_test.exs
key-decisions:
  - "[100-10] Open references accept only open-/open_ namespaces, optionally cw_-prefixed, with an ASCII alphanumeric/underscore/hyphen body."
  - "[100-10] Explicit collapse IDs use a separate anchored ASCII header allowlist while derived collapse values retain the existing exact-scope derivation."
metrics:
  duration: 7 min
  completed: 2026-08-22
status: complete
---

# Phase 100 Plan 10: APNs Input Boundary Closure Summary

**APNs durable intent and direct payload construction now share a closed opaque-reference grammar, while caller collapse IDs are validated as safe APNs headers before transport construction.**

## Accomplishments

- Added internal `Chimeway.APNS.OpaqueReference.valid?/1` with an anchored ASCII grammar and 256-byte cap.
- Applied that validator independently in `RequestIntent.new/2`/`from_storage/1` and `Payload.build/2`.
- Replaced explicit-collapse blacklist behavior with a 1..64-byte ASCII `[A-Za-z0-9_-]` allowlist; nil omission and derived exact-scope collapse behavior remain unchanged.
- Added tagged table-driven smoke coverage for accepted, malformed, non-binary, and byte-bound inputs plus no-I/O adapter behavior for malformed persisted values.

## Task Commits

1. **Task 1 RED: APNs input boundary regressions** — `23a38c8` (`test`)
2. **Task 1 GREEN: close APNs request input boundaries** — `cde335c` (`feat`)

## Verification

- PASS: `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/apns/request_test.exs --only apns_input_smoke --warnings-as-errors` — 2 tests, 0 failures.
- PASS: `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/apns/request_test.exs test/chimeway/adapters/apns_test.exs test/chimeway/apns/tracer_test.exs test/chimeway/apns/result_test.exs test/chimeway/dispatch/target_worker_test.exs test/chimeway/apns/api_coverage_test.exs --warnings-as-errors` — 29 tests, 0 failures.
- PASS: `mix format --check-formatted lib/chimeway/apns/opaque_reference.ex lib/chimeway/apns/request_intent.ex lib/chimeway/apns/payload.ex test/chimeway/apns/request_test.exs test/chimeway/adapters/apns_test.exs`.
- UNRUN: `bash scripts/verify-apns.sh` could not finish in the executor’s 30-second subprocess limit while compiling a fresh temporary consumer dependency tree. Its initial package build succeeds; rerun the exact command in CI or a non-time-limited shell for the final consumer proof.

Verifier outcome: `gaps_found` (the consumer-gate command is unrun; focused behavior evidence is green).

## TDD Gate Compliance

- RED commit `23a38c8` added failing opaque-reference and collapse-header boundary cases.
- GREEN commit `cde335c` introduced the shared validator and passed the focused smoke and regression gates.

## Deviations from Plan

### Auto-fixed Issues

None - implementation matched the planned files and validation architecture.

## Known Stubs

None. The plan-owned files contain no runtime placeholders, TODOs, FIXMEs, or empty data wiring.

## Threat Flags

None. This plan narrows existing provider-bound inputs and introduces no endpoint, credential, file-access, or schema surface.

## Self-Check: PASSED

- Found `lib/chimeway/apns/opaque_reference.ex` and all four modified plan-owned files.
- Found task commits `23a38c8` and `cde335c` in git history.
- Confirmed both durable/direct call sites invoke `OpaqueReference.valid?/1`.
- Confirmed the implementation commit introduced no tracked-file deletions.

