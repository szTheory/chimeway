---
phase: 19-digest-data-model-accumulation
plan: 01
subsystem: database
tags: [ecto, postgres, digests, schemas, migrations, tdd]
requires:
  - phase: 17-delivery-windows-deferral-semantics
    provides: digest-held planning state on canonical delivery rows
  - phase: 18-scheduled-resume-deferred-dispatch
    provides: durable orchestration timing patterns without overloading delivery windows
provides:
  - durable digest rule storage keyed by rule_key and rule_version
  - durable digest bucket storage keyed by rule, recipient, channel, grouping value, and window boundaries
  - public digest rule API for upsert, list, fetch, and lookup
affects: [phase-19-plan-02, phase-19-plan-03, digest-accumulation, explainability]
tech-stack:
  added: []
  patterns: [ecto schema validation, postgres unique indexes, upsert-based rule persistence]
key-files:
  created:
    - lib/chimeway/digests.ex
    - lib/chimeway/digests/digest_rule.ex
    - lib/chimeway/digests/digest_bucket.ex
    - priv/repo/migrations/20260428102000_create_chimeway_digest_rules.exs
    - priv/repo/migrations/20260428102100_create_chimeway_digest_buckets.exs
  modified:
    - test/chimeway/digests/digest_rule_test.exs
    - test/chimeway/digests/digest_bucket_test.exs
key-decisions:
  - "Digest rules persist stable identity with rule_key plus rule_version and never use notifier module names as durable storage keys."
  - "Digest buckets snapshot rule identity, grouping facts, and explicit window boundaries instead of reusing deliveries.next_eligible_at."
patterns-established:
  - "Use Ecto.Enum-backed changesets to constrain digest grouping and window modes before persistence."
  - "Use Postgres unique indexes plus Repo.insert on_conflict for durable digest rule identity."
requirements-completed: [DIGEST-01]
duration: 5min
completed: 2026-04-28
---

# Phase 19 Plan 01: Digest Data Model & Accumulation Summary

**Digest rule and bucket persistence with stable rule identity, explicit grouping modes, explicit window metadata, and a public upsert-and-lookup API**

## Performance

- **Duration:** 5 min
- **Started:** 2026-04-28T14:18:38Z
- **Completed:** 2026-04-28T14:23:38Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments
- Added RED tests that lock the digest rule and bucket storage contract, including grouping/window validation and composite bucket uniqueness.
- Implemented `Chimeway.Digests` with `upsert_rule/1`, `list_rules/1`, `get_rule!/1`, and `find_matching_rule/1`.
- Added digest rule and bucket schemas plus migrations with named unique indexes for durable identity boundaries.

## Task Commits

Each task was committed atomically:

1. **Task 1: Lock digest rule and bucket storage contracts with RED tests** - `7d78c7b` (`test`)
2. **Task 2: Implement digest rule and bucket schemas, API, and migrations** - `eeec217` (`feat`)

## Files Created/Modified
- `lib/chimeway/digests.ex` - Public digest rule persistence and lookup API.
- `lib/chimeway/digests/digest_rule.ex` - Rule schema with durable identity, grouping-mode validation, and window validation.
- `lib/chimeway/digests/digest_bucket.ex` - Bucket schema with snapshot identity fields and composite uniqueness enforcement.
- `priv/repo/migrations/20260428102000_create_chimeway_digest_rules.exs` - Digest rule table and durable identity indexes.
- `priv/repo/migrations/20260428102100_create_chimeway_digest_buckets.exs` - Digest bucket table and composite uniqueness index.
- `test/chimeway/digests/digest_rule_test.exs` - RED/GREEN contract tests for rule validation and API lookup behavior.
- `test/chimeway/digests/digest_bucket_test.exs` - RED/GREEN contract tests for bucket validation, counters, and uniqueness.

## Decisions Made
- Stored digest rule identity as `rule_key` plus `rule_version` with a named unique index so later accumulation and explanation work can survive notifier refactors.
- Stored bucket window boundaries as first-class columns on digest buckets so digest accumulation remains distinct from deferred delivery scheduling.
- Limited persisted digest data to rule identity, grouping facts, recipient scope, channel, and window metadata to preserve explainability without payload leakage.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- Targeted tests initially failed because the new digest tables did not exist in the test database yet; running `MIX_ENV=test mix ecto.migrate` brought the new migrations into the sandboxed test environment and the suite then passed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 19 now has durable digest rule and bucket contracts that Phase 19 accumulation work can write against safely.
- `find_matching_rule/1` and the bucket uniqueness boundary are in place for downstream accumulation and explanation slices.

## Known Stubs

None.

## Self-Check: PASSED

- Verified all created files exist on disk.
- Verified task commits `7d78c7b` and `eeec217` exist in git history.
- Re-ran `mix test test/chimeway/digests/digest_rule_test.exs test/chimeway/digests/digest_bucket_test.exs --trace` successfully.

---
*Phase: 19-digest-data-model-accumulation*
*Completed: 2026-04-28*
