---
phase: 100
fixed_at: 2026-08-21T15:28:41Z
review_path: /Users/jon/projects/chimeway/.planning/phases/100-optional-apns-adapter/100-REVIEW.md
iteration: 1
findings_in_scope: 3
fixed: 3
skipped: 0
status: all_fixed
---

# Phase 100: Code Review Fix Report

**Fixed at:** 2026-08-21T15:28:41Z
**Source review:** /Users/jon/projects/chimeway/.planning/phases/100-optional-apns-adapter/100-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 3
- Fixed: 3
- Skipped: 0

## Fixed Issues

### CR-01: The 410 invalidation triple can never be reconstructed from a real APNs response

**Files modified:** `lib/chimeway/apns/transport.ex`
**Commit:** 6eacc4e
**Status:** fixed: requires human verification
**Applied fix:** Combines the HTTP/2 stream status with the decoded APNs body before validating the 410 invalidation triple.

### CR-02: Retryable APNs provider responses are classified as permanent failures

**Files modified:** `lib/chimeway/apns/transport.ex`, `test/chimeway/apns/result_test.exs`, `test/fixtures/apns_consumer/test/apns_consumer_test.exs`
**Commit:** ccf6ab3
**Status:** fixed: requires human verification
**Applied fix:** Preserves recognized retryable APNs 403, 429, 500, and 503 responses as closed transport results and verifies adapter retry classification.

### CR-03: A missing or stopped Pigeon dispatcher is recorded as a permanent provider rejection

**Files modified:** `lib/chimeway/apns/transport.ex`, `test/chimeway/adapters/apns_test.exs`, `test/fixtures/apns_consumer/test/apns_consumer_test.exs`
**Commit:** 465e55a
**Status:** fixed: requires human verification
**Applied fix:** Maps Pigeon's `:not_started` response to the local unavailable transport outcome and covers the pre-handoff adapter result.

---

_Fixed: 2026-08-21T15:28:41Z_
_Fixer: the agent (gsd-code-fixer)_
_Iteration: 1_
