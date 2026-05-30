---
phase: 61-inbox-headless-package
plan: 01
subsystem: inbox
tags: [inbox, pagination, dto, unread-count, exunit]

requires:
  - phase: 48-49
    provides: Inbox lifecycle spine (read/seen/archive columns)
provides:
  - Chimeway.unread_count/2 with exclude_archived default true
  - Paginated Chimeway.list_for_recipient/2 returning %{items, has_more} DTO maps
  - Chimeway.Inbox.Item.to_map/1 serializable inbox item maps
  - Backward-compatible struct list when pagination opts absent
affects: [61-02, 61-03, 62]

tech-stack:
  added: []
  patterns:
    - "Keyset pagination on (inserted_at desc, id desc) with limit+1 has_more"
    - "Dual return shape gated by pagination opt presence"
    - "Phoenix-free DTO mapper in lib/chimeway/inbox/item.ex"

key-files:
  created:
    - lib/chimeway/inbox/item.ex
    - test/chimeway/inbox_pagination_test.exs
  modified:
    - lib/chimeway/inbox.ex
    - lib/chimeway.ex

key-decisions:
  - "Pagination triggered by :limit, cursor opts, or :paginate true — legacy path unchanged"
  - "Invalid before_id UUID ignored — cursor treated as first page (T-61-04)"
  - "href omitted from DTO maps in v1.9 per UI-SPEC"

patterns-established:
  - "Pattern: Item.to_map/1 for UI-facing inbox rows with ISO8601 timestamps"
  - "Pattern: exclude_archived default true on list and unread_count queries"

requirements-completed: [INBX-01]

duration: 25min
completed: 2026-05-30
---

# Phase 61 Plan 01: Headless Inbox API Polish Summary

**UI-ready headless inbox queries on core Chimeway: unread_count, keyset-paginated list_for_recipient with stable DTO maps, and exclude_archived defaults — no Phoenix in lib/chimeway.**

## Performance

- **Duration:** ~25 min
- **Tasks:** 4
- **Files modified:** 4

## Accomplishments

- Added `Chimeway.Inbox.Item.to_map/1` mapping id, title, body_preview, inserted_at, read_at, seen_at per UI-SPEC.
- Added `Chimeway.unread_count/2` and `exclude_archived` filter (default true) on list and count queries.
- Extended `list_for_recipient/2` with paginated branch returning `%{items: [dto_map], has_more: boolean}`; legacy struct list preserved.
- Added 5 pagination/DTO/archived-filter tests in `inbox_pagination_test.exs`.

## Task Commits

Each task was committed atomically:

1. **Task 1: DTO mapper module (D-03)** - `c9c8102` (feat)
2. **Task 2: unread_count + exclude_archived query helpers (D-01)** - `d0b5e9f` (feat)
3. **Task 3: Paginated list branch + DTO return (D-02)** - `f2dee3a` (feat)
4. **Task 4: Pagination + DTO tests** - `9f889ac` (test)

**Plan metadata:** pending (docs commit follows this file)

## Files Created/Modified

- `lib/chimeway/inbox/item.ex` - Serializable inbox item DTO mapper
- `lib/chimeway/inbox.ex` - unread_count, exclude_archived, paginated list branch
- `lib/chimeway.ex` - Public unread_count delegate + list_for_recipient moduledoc
- `test/chimeway/inbox_pagination_test.exs` - unread_count, DTO keys, has_more/cursor, archived, title tests

## Decisions Made

- Pagination detection uses `:limit`, `:before_inserted_at`, `:before_id`, or `:paginate, true`.
- Cursor requires valid UUID via `Ecto.UUID.cast/1`; invalid cursor falls back to first page.
- body_preview truncated to 120 graphemes from body_preview/preview/body metadata keys.

## Deviations from Plan

### Minor test adjustment

**1. Separate events per notification in unread_count test**
- **Found during:** Task 2 (test insert)
- **Issue:** Unique constraint on `(event_id, recipient_identity)` prevented multiple notifications per event
- **Fix:** Use distinct events for each test notification (matches inbox_query_test pattern)
- **Files modified:** `test/chimeway/inbox_pagination_test.exs`
- **Committed in:** `d0b5e9f`, `9f889ac`

**2. unread_count test added in Task 2 commit (not Task 4)**
- **Reason:** Task 2 verify requires `--only unread_count` test; minimal test committed with Task 2, remaining tests in Task 4
- **Impact:** Task 4 commit extends same test file rather than creating it fresh

---

**Total deviations:** 2 minor (test ordering/structure only)
**Impact on plan:** No scope or API changes.

## Verification Results

| Check | Result |
|-------|--------|
| `mix compile --warnings-as-errors` | PASS |
| `mix test test/chimeway/inbox_query_test.exs test/chimeway/inbox_pagination_test.exs --warnings-as-errors` | PASS (6 tests, 0 failures) |
| `mix ci.test` | PASS (825 tests, 0 failures) |
| No Phoenix imports under `lib/chimeway/` | PASS |

## Self-Check: PASSED

## Next Phase Readiness

- Ready for 61-02: `chimeway_inbox` package can consume `Chimeway.unread_count/2` and paginated `list_for_recipient/2`.
- Package LiveView should pass cursor as `before_inserted_at` + `before_id` from last item on load_more.

---
*Phase: 61-inbox-headless-package*
*Completed: 2026-05-30*
