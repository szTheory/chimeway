---
phase: 33-webhook-ingress-durability
plan: "01"
subsystem: database
tags: [elixir, ecto, schema, migration, webhook, ingress, postgres, partial-index]

requires:
  - phase: 32-operator-traces-audit
    provides: WorkflowTransition.delivery_id linkage and explain_delivery/1 timeline
  - phase: 27-signal-routing
    provides: chimeway_signals + chimeway_workflow_runs migration shape (analog for ingress schema)

provides:
  - Chimeway.Webhooks.Ingress Ecto schema with changeset/2, 8-field explainability-first structure
  - chimeway_webhook_ingress DB table with partial composite unique index for provider-retry dedup
  - 10 passing tests covering validation rules + partial index DB behavior
  - Foundation for Phase 33 Plans 02 and 03 (Wave 2)

affects: [33-02-ingress-worker, 33-03-ingress-api, 33-04-ingress-example, 33-05-ingress-tests]

tech-stack:
  added: []
  patterns:
    - "Ecto.Enum for bounded atom vocabularies (ingress_state, ignored_reason) — atom-safe, compile-time bounded"
    - "Partial composite unique index via unique_index/3 where: clause for nullable FK dedup"
    - "validate_correlation_present/1 private function for multi-field conditional validation"
    - "Split test module pattern: ExUnit.Case for changeset-only tests, DataCase for DB integration tests"

key-files:
  created:
    - lib/chimeway/webhooks/ingress.ex
    - priv/repo/migrations/20260502120000_create_chimeway_webhook_ingress.exs
    - test/chimeway/webhooks/ingress_test.exs
  modified: []

key-decisions:
  - "Use :binary_id (not Ecto.UUID) for primary_key and foreign_key_type to match Phase 33 standardization"
  - "FK delivery_id uses on_delete: :nilify_all so hard-delete of delivery preserves audit ingress row"
  - "ingress_state and ignored_reason are Ecto.Enum (compile-time atom lists) per T-33-AUTH-LEAK discipline"
  - "DB test module (IngressDBTest) uses provider_message_id as correlation key to avoid real chimeway_deliveries FK row"
  - "constraint_name in Ecto unique_constraint errors is a string, not an atom — test asserts either form"

patterns-established:
  - "Ingress schema: explainability-first fields only, no raw payload/headers/source_ip (D-04)"
  - "Partial unique index: WHERE provider_event_id IS NOT NULL collapses provider retries with stable event ids"
  - "validate_correlation_present/1: delivery_id OR provider_message_id OR (:ignored AND reason) must be set"

requirements-completed: [FEED-01, FEED-02]

threats-mitigated: [T-33-PII, T-33-DEDUP-schema, T-33-AUTH-LEAK]

duration: 5min
completed: "2026-05-02"
---

# Phase 33 Plan 01: Ingress Schema Summary

**Ecto schema `Chimeway.Webhooks.Ingress` with 8 explainability-first fields, migration with partial composite unique index `(adapter_module, provider_event_id) WHERE provider_event_id IS NOT NULL`, and 10 passing tests covering validation + DB dedup behavior**

## Performance

- **Duration:** 5 min
- **Started:** 2026-05-02T01:54:25Z
- **Completed:** 2026-05-02T01:59:20Z
- **Tasks:** 3
- **Files modified:** 3 (all created)

## Accomplishments

- Created `Chimeway.Webhooks.Ingress` with 8-field schema, `Ecto.Enum` for bounded vocabularies, `validate_correlation_present/1` private guard, and `unique_constraint` declaration matching the partial index name
- Created migration creating `chimeway_webhook_ingress` table with binary_id PK, FK to chimeway_deliveries with nilify cascade, 3 lookup indexes, and partial composite unique index
- All 10 tests pass: 7 changeset validation unit tests + 3 DB integration tests proving partial index dedup, NULL non-collision, and cross-adapter isolation
- `MIX_ENV=test mix ecto.migrate` and `mix test test/chimeway/webhooks/ingress_test.exs` both exit 0

## Task Commits

Each task was committed atomically:

1. **Task 1: Wave 0 ingress schema test file (RED)** - `f277130` (test)
2. **Task 2: Chimeway.Webhooks.Ingress Ecto schema (GREEN)** - `2e904dc` (feat)
3. **Task 3: chimeway_webhook_ingress migration + GREEN tests** - `6041acb` (feat)

**Plan metadata:** (docs commit follows)

_Note: TDD tasks — test file created first (RED), schema second (GREEN), migration third (GREEN completing DB tests)_

## Files Created/Modified

- `lib/chimeway/webhooks/ingress.ex` — Ecto schema with 8 fields, changeset/2, validate_correlation_present/1, Ecto.Enum vocabularies
- `priv/repo/migrations/20260502120000_create_chimeway_webhook_ingress.exs` — Table DDL + 3 lookup indexes + partial composite unique index
- `test/chimeway/webhooks/ingress_test.exs` — 10 tests in two modules (IngressTest: ExUnit.Case async; IngressDBTest: DataCase async)

## Decisions Made

- Used `:binary_id` for primary key type (Phase 33 standardization, matches migration `:binary_id` type)
- `delivery_id` FK uses `on_delete: :nilify_all` so a hard delivery delete leaves the ingress audit row intact with `delivery_id = nil`
- DB test module uses `provider_message_id` as the correlation key to avoid needing real `chimeway_deliveries` rows — the FK constraint would otherwise fire on insert
- Ecto's `unique_constraint` error opts use string for `constraint_name` key (not atom); tests assert both forms for forward compatibility

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed `use ExUnit.Case` placement inside describe block**
- **Found during:** Task 1 (test execution in GREEN phase)
- **Issue:** Plan's test spec had `use ExUnit.Case` inside the `describe` block, which is invalid Elixir — `use` must appear at the module level
- **Fix:** Split into two top-level modules: `IngressTest` (`use ExUnit.Case, async: true`) and `IngressDBTest` (`use Chimeway.DataCase, async: true`)
- **Files modified:** test/chimeway/webhooks/ingress_test.exs
- **Verification:** 10 tests compile and pass
- **Committed in:** 6041acb (Task 3 commit)

**2. [Rule 1 - Bug] Fixed FK violation in DB tests using delivery_id from valid_attrs**
- **Found during:** Task 3 (DB integration tests)
- **Issue:** Default `valid_attrs` included `delivery_id: Ecto.UUID.generate()` — a non-existent UUID that triggers the `chimeway_webhook_ingress_delivery_id_fkey` FK constraint on Repo.insert
- **Fix:** Changed DB test module's `valid_attrs` to use `provider_message_id` as the correlation key (no FK constraint) instead of `delivery_id`
- **Files modified:** test/chimeway/webhooks/ingress_test.exs
- **Verification:** DB tests pass without FK constraint errors
- **Committed in:** 6041acb (Task 3 commit)

**3. [Rule 1 - Bug] Fixed constraint_name type mismatch in unique constraint assertion**
- **Found during:** Task 3 (DB test for dedup collision)
- **Issue:** Plan's test spec used `:chimeway_webhook_ingress_adapter_provider_event_uniq` (atom) but Ecto returns `"chimeway_webhook_ingress_adapter_provider_event_uniq"` (string) in error opts
- **Fix:** Test asserts string OR atom form for forward compatibility
- **Files modified:** test/chimeway/webhooks/ingress_test.exs
- **Verification:** Dedup constraint test passes; actual error opts confirmed via ExUnit output
- **Committed in:** 6041acb (Task 3 commit)

**4. [Rule 1 - Bug] Fixed empty-string adapter_module test assertion**
- **Found during:** Task 3 (Test 5 validation failure)
- **Issue:** Plan spec said empty-string `:adapter_module` should produce a `:length` validation error, but `validate_required` fires first for empty strings on `:string` fields in Ecto — the error is `:required`
- **Fix:** Updated Test 5 to assert `{"can't be blank", _}` and added a comment explaining the Ecto behavior
- **Files modified:** test/chimeway/webhooks/ingress_test.exs
- **Verification:** Test 5 passes with corrected assertion
- **Committed in:** 6041acb (Task 3 commit)

---

**Total deviations:** 4 auto-fixed (all Rule 1 - Bug)
**Impact on plan:** All fixes corrected test authoring issues — the schema and migration are exactly as specified. No scope creep.

## Issues Encountered

- Worktree did not have `deps/` or `_build/` symlinks — created symlinks to main project directories before first compile; this is standard worktree setup

## User Setup Required

None - no external service configuration required. Migration runs automatically via `MIX_ENV=test mix ecto.migrate`.

## Next Phase Readiness

- `Chimeway.Webhooks.Ingress` schema and `chimeway_webhook_ingress` table are ready
- Plans 02 (ingress worker) and 03 (webhooks API boundary) may now begin (Wave 2)
- The `:ingress` step in `Ecto.Multi` for Plan 02 can reference `Ingress.changeset/2` directly
- No blockers

---
*Phase: 33-webhook-ingress-durability*
*Completed: 2026-05-02*
