---
phase: 14-delivery-reliability-hardening
plan: 02
subsystem: database
tags: [ecto, migration, rel-02, attempt-history, error-classification]

# Dependency graph
requires:
  - phase: 14-delivery-reliability-hardening
    provides: Wave 0 test scaffolding (14-01) — placeholder tests in test/chimeway/reliability/attempt_history_test.exs anchor REL-02 imports
provides:
  - chimeway_delivery_attempts.attempt_number :integer column (nullable, backfilled)
  - chimeway_delivery_attempts.error_class :string column (nullable, indexed)
  - DeliveryAttempt schema fields :attempt_number and :error_class
  - DeliveryAttempt.error_classes/0 public helper exposing the canonical whitelist
  - Changeset whitelist validation rejecting any error_class outside ["temporary","permanent","bounced"]
  - Changeset positive-integer guard on attempt_number with explicit error message
affects: [14-04 record_attempt_wiring, 14-05 dispatch_executor_classify, 14-07 attempt_history_tests]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Additive migration with explicit up/down (execute backfill is irreversible — change/0 unsuitable)"
    - "ROW_NUMBER() OVER (PARTITION BY ...) Postgres window function for ordinal backfill"
    - "Module-attribute whitelist (~w/sigil) + public helper for cross-module sharing (mirrors @sensitive_keys idiom from deliveries.ex)"
    - "validate_inclusion + custom validate_attempt_number_positive composed in pipeline"

key-files:
  created:
    - priv/repo/migrations/20260426150000_add_attempt_history_columns.exs
    - test/chimeway/delivery_attempt_test.exs
  modified:
    - lib/chimeway/delivery_attempt.ex

key-decisions:
  - "Leave attempt_number in @optional_fields for now — Plan 14-04 Task 3 promotes to @required after record_attempt/2 wiring (avoids transient red between waves)"
  - "Persist error_class as plain string with whitelist validation (not Ecto.Enum) to match Phase 11 string-channel idiom"
  - "Use def up/def down instead of def change because execute backfill cannot be auto-reversed"
  - "Trim @optional_fields to schema-backed subset (provider_response, attempt_number, error_class) — drop forward-compat tokens (started_at/completed_at/metadata) since they are not yet schema fields"
  - "Backfill error_class to NULL on historical rows (cannot be derived); attempt_number backfilled via ROW_NUMBER ordering on inserted_at"

patterns-established:
  - "REL-02 attempt history shape: (delivery_id, attempt_number 1-indexed, error_class string whitelist)"
  - "Whitelist module attribute + public helper exposed for downstream consumer modules (Dispatch.Executor in 14-05)"

requirements-completed: [REL-02]

# Metrics
duration: 5 min
completed: 2026-04-26
---

# Phase 14 Plan 02: Delivery Attempt History Schema (REL-02) Summary

**Additive migration adds `attempt_number :integer` and `error_class :string` columns to `chimeway_delivery_attempts` with ROW_NUMBER backfill, and extends `DeliveryAttempt` schema with whitelist validation for `error_class` and positive-integer guard for `attempt_number`.**

## Performance

- **Duration:** ~5 min (200s, includes test DB recreation + full suite)
- **Started:** 2026-04-26T18:24:47Z
- **Completed:** 2026-04-26T18:29:47Z
- **Tasks:** 2 (Task 1 = migration; Task 2 = TDD schema/changeset)
- **Files created:** 2 (migration + test)
- **Files modified:** 1 (delivery_attempt.ex)

## Accomplishments

- Migration applied cleanly to dev and test databases with deterministic ROW_NUMBER backfill
- `DeliveryAttempt` schema exposes `attempt_number` and `error_class`; existing callers stay green (additive)
- `DeliveryAttempt.error_classes/0` published as canonical whitelist for `Chimeway.Dispatch.Executor` consumption in 14-05
- 15 new unit tests cover whitelist accept/reject, positive-integer guard, nil-handling, and helper output
- Full test suite: **218 tests, 0 failures, 27 skipped** (pre-existing skipped scaffold tests from 14-01)
- Threat T-14-02 (information disclosure via uncontrolled `error_class` value) directly mitigated by `validate_inclusion` whitelist

## Task Commits

1. **Task 1: Create additive migration with backfill SQL** — `957b92c` (feat)
2. **Task 2 RED: Failing tests for whitelist + positive-integer validation** — `bb9395d` (test)
3. **Task 2 GREEN: Schema + changeset implementation** — `c9ad3a1` (feat)
4. **Task 2 style: mix format on new test file** — `24807e1` (style)

_TDD task 2 follows the test → feat sequence; refactor not needed (validator function is small and focused)._

## Migration Details

**File:** `priv/repo/migrations/20260426150000_add_attempt_history_columns.exs`

**`up/0` (full SQL via Ecto.Migration DSL):**

```elixir
alter table(:chimeway_delivery_attempts) do
  add :attempt_number, :integer, null: true
  add :error_class, :string, null: true
end

execute(
  """
  UPDATE chimeway_delivery_attempts AS a
  SET attempt_number = sub.rn
  FROM (
    SELECT id, ROW_NUMBER() OVER (PARTITION BY delivery_id ORDER BY inserted_at) AS rn
    FROM chimeway_delivery_attempts
  ) AS sub
  WHERE a.id = sub.id;
  """,
  "UPDATE chimeway_delivery_attempts SET attempt_number = NULL;"
)

create index(:chimeway_delivery_attempts, [:error_class])
```

**`down/0`:** drops the index, then removes both columns.

Verified columns post-migration via `information_schema.columns`:
`["id", "delivery_id", "outcome", "provider_response", "inserted_at", "attempt_number", "error_class"]`.

## Schema Field Additions

```elixir
field(:attempt_number, :integer)
field(:error_class, :string)
```

Validation pipeline:

```elixir
|> cast(attrs, @required_fields ++ @optional_fields)
|> validate_required(@required_fields)
|> validate_inclusion(:error_class, @error_classes)  # @error_classes ~w(temporary permanent bounced)
|> validate_attempt_number_positive()
|> put_inserted_at()
```

## @required_fields decision (two-step landing)

Plan 14-02 keeps `@required_fields ~w(delivery_id outcome)a` — `attempt_number` lives in `@optional_fields`. **Plan 14-04 Task 3** will promote `attempt_number` to `@required_fields` AFTER 14-04 Task 2 wires `Deliveries.record_attempt/2` to inject the value via the new `:next_attempt_number` Multi step. This split prevents a transient red `mix test` between Wave 2 and Wave 4 — existing callers that omit `attempt_number` (most of `deliveries_test.exs`) keep working at this plan boundary.

## `mix test` Summary

```
Finished in 0.9 seconds (0.4s async, 0.4s sync)
218 tests, 0 failures, 27 skipped
```

The 27 skipped tests are the pre-existing Wave 0 scaffolds in `test/chimeway/reliability/attempt_history_test.exs` and related files (left for Plan 14-07).

Specifically called-out regression suites all green:
- `mix test test/chimeway/deliveries_test.exs test/chimeway/dispatch/oban_worker_test.exs test/chimeway/dispatch/sync_test.exs` — 40 tests, 0 failures
- `mix test test/chimeway/telemetry_correlation_test.exs test/chimeway/telemetry_integration_test.exs` — 10 tests, 0 failures (Phase 10 protection)

Phase 11 (channel safety) and Phase 12 (transactional dispatch) tests included in the full-suite run.

## Files Created/Modified

- `priv/repo/migrations/20260426150000_add_attempt_history_columns.exs` — Adds attempt_number + error_class columns; backfills attempt_number via ROW_NUMBER; creates error_class index.
- `lib/chimeway/delivery_attempt.ex` — Adds two schema fields, `@error_classes` whitelist, public `error_classes/0` helper, `validate_inclusion`, and `validate_attempt_number_positive/1`.
- `test/chimeway/delivery_attempt_test.exs` — 15 unit tests (created).

## Decisions Made

See frontmatter `key-decisions`. Most consequential:

1. **Two-step `attempt_number` required-ness landing** (per CONTEXT.md D-07/D-08 + plan front-matter Note). Avoids transient test breakage between waves.
2. **String whitelist instead of `Ecto.Enum`** for `error_class`. Mirrors Phase 11's deliberate move toward string-safe channel/adapter resolution, and matches the project's `@sensitive_keys ~w(...)` idiom in `lib/chimeway/deliveries.ex:215`.
3. **`up/down` instead of `change/0`**. Required because `execute/2` for the backfill `UPDATE` cannot be auto-reversed by Ecto.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Trimmed `@optional_fields` to schema-backed subset**
- **Found during:** Task 2 (GREEN compile)
- **Issue:** Plan listed `~w(attempt_number error_class provider_response started_at completed_at metadata)a` as optional fields, citing forward-compatibility. The schema does not define `started_at`, `completed_at`, or `metadata` fields. Modern Ecto raises `ArgumentError` for unknown fields passed to `cast/3` allowed-list. The plan's NOTE explicitly authorized this fallback: "If the executor finds `cast/3` rejects unknown fields in this Ecto version, trim to only `~w(provider_response attempt_number error_class)a`".
- **Fix:** Used trimmed list `~w(attempt_number error_class provider_response)a` per plan's documented fallback.
- **Files modified:** lib/chimeway/delivery_attempt.ex
- **Verification:** `mix compile --warnings-as-errors --force` passes; all 218 tests green.
- **Committed in:** `c9ad3a1` (Task 2 GREEN commit)

**2. [Rule 1 - Bug] Applied `mix format` to new test file**
- **Found during:** End-of-plan `mix ci` gate
- **Issue:** Initial `assert ... ,` long-line in `test/chimeway/delivery_attempt_test.exs` exceeded line-length and `mix format --check-formatted` flagged it.
- **Fix:** `mix format test/chimeway/delivery_attempt_test.exs` — auto-wrapping applied; tests still pass.
- **Files modified:** test/chimeway/delivery_attempt_test.exs
- **Verification:** `mix test test/chimeway/delivery_attempt_test.exs` — 15/15 pass; `mix format --check-formatted` no longer flags the file.
- **Committed in:** `24807e1` (style commit)

---

**Total deviations:** 2 auto-fixed (both Rule 1 — small bugs caught during verification gates).
**Impact on plan:** No scope creep. Both fixes are confined to files this plan owns. The `@optional_fields` adjustment was explicitly authorized by the plan's fallback note.

## Deferred Issues (out of scope)

`mix ci` (full lint+test gate) still fails because of three **pre-existing** unformatted files unrelated to this plan:

| File                              | Last touched in |
| --------------------------------- | --------------- |
| `lib/chimeway/policy.ex`          | 13-03           |
| `lib/chimeway/policy/settings.ex` | 13-02           |
| `test/chimeway/policy_test.exs`   | 13-02           |

Per executor scope-boundary rule, pre-existing failures in unrelated files are logged to `.planning/phases/14-delivery-reliability-hardening/deferred-items.md` (already documented from Plan 14-01; this plan added a 14-02 confirmation row). All targeted regression suites called out by this plan's `<verify>` and `<success_criteria>` blocks pass.

## Issues Encountered

- Worktree did not have `mix deps.get` run yet on first `mix ecto.migrate`. Resolved by running `mix deps.get` once, after which all migrations and tests proceeded normally.

## Threat Flags

None. The plan's `<threat_model>` already enumerates T-14-02, T-14-04, T-14-05 — no new surface introduced. T-14-02 (the only `mitigate` disposition) is fully addressed by the `validate_inclusion(:error_class, @error_classes)` line in the changeset.

## Next Phase Readiness

- **Plan 14-04 (record_attempt wiring)** can rely on:
  - `attempt_number` and `error_class` columns existing in the DB (both nullable).
  - `DeliveryAttempt.error_classes/0` for the canonical whitelist.
  - Schema accepts both fields via `cast/3`.
  - `attempt_number` still in `@optional_fields` — 14-04 Task 3 promotes it to `@required_fields`.
- **Plan 14-05 (dispatch executor classify)** can `import Chimeway.DeliveryAttempt, only: [error_classes: 0]` and `validate against the same source of truth.
- **Plan 14-07 (attempt history tests)** has the schema fixtures it needs to fill in the currently-skipped `test/chimeway/reliability/attempt_history_test.exs` describes.

No blockers for downstream waves.

## Self-Check: PASSED

Files verified to exist:
- FOUND: priv/repo/migrations/20260426150000_add_attempt_history_columns.exs
- FOUND: lib/chimeway/delivery_attempt.ex
- FOUND: test/chimeway/delivery_attempt_test.exs

Commits verified to exist:
- FOUND: 957b92c (Task 1 migration)
- FOUND: bb9395d (Task 2 RED tests)
- FOUND: c9ad3a1 (Task 2 GREEN implementation)
- FOUND: 24807e1 (Task 2 format style fix)

---
*Phase: 14-delivery-reliability-hardening*
*Plan: 14-02*
*Completed: 2026-04-26*
