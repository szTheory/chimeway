---
phase: 100-optional-apns-adapter
plan: 04
subsystem: apns-delivery
tags: [elixir, apns, pigeon, oban, ecto, privacy]
requires:
  - phase: 100-optional-apns-adapter
    provides: Pigeon-neutral APNs request boundary and exact host binding callbacks
provides:
  - Closed typed provider outcomes for exact durable target attempts
  - Fail-closed APNs invalidation and retry authority
  - Bounded APNs provider evidence and final retry exhaustion
affects: [100-05, apns-delivery, operator-traces]
tech-stack:
  added: []
  patterns:
    - Provider adapters return typed outcome maps; Executor never parses provider strings.
    - Target outcome completion locks the delivery, claimed target, and started attempt before one mutation.
    - APNs facts are redacted and validated through a fixed allowlist before persistence or trace projection.
key-files:
  created:
    - test/chimeway/apns/result_test.exs
    - test/chimeway/safe_evidence_test.exs
  modified:
    - lib/chimeway/target_adapter.ex
    - lib/chimeway/adapters/apns.ex
    - lib/chimeway/delivery_targets.ex
    - lib/chimeway/dispatch/executor.ex
    - lib/chimeway/dispatch/oban_worker.ex
    - lib/chimeway/safe_evidence.ex
key-decisions:
  - "[100-04]: Typed adapter outcomes are the only retry authority; ambiguous handoff is durable and terminal."
  - "[100-04]: Provider invalidation requires the complete 410/recognized-reason/timestamp tuple and host exact-CAS confirmation."
  - "[100-04]: APNs provider evidence uses bounded response facts and excludes raw provider material."
requirements-completed: [APNS-03, APNS-04, APNS-06]
metrics:
  duration: 12 min
  completed: 2026-08-20
status: complete
---

# Phase 100 Plan 04: Honest APNs Outcome Lifecycle Summary

**APNs result handling now closes one exact target attempt with typed acceptance, retry, terminal failure, invalidation, expiry, or ambiguity evidence—without treating provider handoff as engagement.**

## Accomplishments

- Added the closed `TargetAdapter` outcome algebra and a single locked `record_target_outcome/5` transaction for target/attempt completion.
- Classified APNs 410 invalidation fail-closed: only an exact recognized 410 response with non-negative timestamp and confirmed host CAS can invalidate a binding.
- Limited Oban retry authority to typed pre-handoff and provider-retryable outcomes; final attempts record `retry_exhausted` and complete the job.
- Expanded SafeEvidence with bounded APNs status, reason, timestamp, corrective-action, retry-delay, and acceptance fields.

## Verification

- PASS: `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/safe_evidence_test.exs test/chimeway/traces_test.exs test/chimeway/dispatch/target_worker_test.exs --warnings-as-errors` (59 tests).
- PASS: `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/delivery_target_test.exs test/chimeway/orchestration/target_recovery_test.exs test/chimeway/dispatch/target_worker_test.exs test/chimeway/apns --warnings-as-errors` (38 tests).
- PASS: `MIX_ENV=prod mix compile --warnings-as-errors`.

## Task Commits

1. Task 1 — `6122cf9` typed APNs target outcomes and exact completion.
2. Task 2 — `4059743` bounded APNs evidence and provider retry exhaustion.
3. Directly related compatibility correction — `c2a4b9b` updated APNs tracer assertions for typed result tuples.

## Decisions Made

- Provider acceptance remains a handoff fact only; it creates no protected-open, inbox-seen, or inbox-read assertion.
- Unknown, incomplete, or post-emission provider outcomes fail closed to permanent or ambiguous behavior rather than retry or invalidation.
- Safe evidence validates duplicate atom/string aliases as ambiguous, preventing conflicting facts from entering traces.

## Deviations from Plan

### Auto-fixed Issues

1. [Rule 1 - Bug] Aligned the existing APNs tracer with the expanded typed result contract.
- **Found during:** Overall lifecycle verification.
- **Fix:** Updated accepted and expired assertions to their typed provider outcomes.
- **Files modified:** `test/chimeway/apns/tracer_test.exs`.
- **Commit:** `c2a4b9b`.

## Known Stubs

None.

## Self-Check: PASSED

- Confirmed task commits `6122cf9`, `4059743`, and `c2a4b9b` exist in git history.
- Confirmed the APNs result and safe-evidence contract test files exist.
