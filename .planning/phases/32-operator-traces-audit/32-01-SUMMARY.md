---
phase: 32-operator-traces-audit
plan: 01
subsystem: workflows
tags: [elixir, ecto, workflows, signals, traceability, foreign-keys]

# Dependency graph
requires:
  - phase: 24-workflow-deliveries-fk
    provides: WorkflowTransition.delivery_id nullable FK column already on schema
  - phase: 25-progression-traces
    provides: :delivery_id populated on every progression transition; pattern for FK linkage
  - phase: 31-feedback-driven-progression
    provides: signal.payload["delivery_id"] guaranteed for webhook-routed signals; payload-safety contract on WorkflowTransition.context
provides:
  - WorkflowTransition.delivery_id is now populated on signal_received rows when signal.payload carries "delivery_id"
  - Nil-safe behavior when payload omits "delivery_id" (Map.get returns nil; insert succeeds)
  - Two new write-path tests anchoring D-21 contract inside `describe "route_signal/1 — transition traces"`
affects:
  - 32-02 (read-side projection — consumes the populated FK to link :webhook_received events to workflow transitions)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "FK linkage on signal_received transition: `delivery_id: Map.get(signal.payload, \"delivery_id\")` inside append_transition/2 attrs map (mirrors the Phase 25 pattern for progression transitions)"
    - "Payload-safety preserved structurally: :delivery_id is a column, never a context-map key — runtime refute Map.has_key?(transition.context, \"delivery_id\") is the durable contract (no whole-file static gate)"

key-files:
  created: []
  modified:
    - "lib/chimeway/workflows.ex (route_signal/1: binding _signal → signal; new attrs-map key)"
    - "test/chimeway/workflows_test.exs (two D-21 tests inside existing describe block)"

key-decisions:
  - "Use Map.get(signal.payload, \"delivery_id\") rather than Map.fetch! — host-app callers via Chimeway.Signal.track/4 may legitimately omit \"delivery_id\" (D-02 nil-safe path)"
  - "FK is enforced at insert time even with on_delete: :nilify_all; tests must insert a real Delivery row rather than relying on plan parenthetical's any-UUID assertion"
  - "delivery_id remains a column, never a context-map key — runtime refute assertion (in Test A) is the durable contract (D-21)"

patterns-established:
  - "Signal-routed transitions populate the same delivery_id FK that progression transitions populate (Phase 25 parity)"
  - "Inline test fixture pattern: when a test needs a Delivery row, insert Event → Notification → Delivery directly using existing aliases plus fully-qualified Chimeway.Delivery (no new helpers, no new aliases)"

requirements-completed:
  - TRAC-02

# Metrics
duration: 4min
completed: 2026-05-01
---

# Phase 32 Plan 01: Populate WorkflowTransition.delivery_id on signal_received Summary

**One attrs-map key (`delivery_id: Map.get(signal.payload, "delivery_id")`) in `Chimeway.Workflows.route_signal/1` plus a `_signal → signal` binding restoration — closes the upstream-data gap for Plan 02's read-side projection so `:webhook_received` events can be linked back to the journey progression step they triggered.**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-05-01T20:12:45Z
- **Completed:** 2026-05-01T20:16:33Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- `route_signal/1` now populates the existing `WorkflowTransition.delivery_id` FK on the `signal_received` row from `signal.payload["delivery_id"]` (TRAC-02).
- Nil-payload regression covered: when `signal.payload` lacks `"delivery_id"`, `route_signal/1` returns `{:ok, _}` and inserts the transition with `transition.delivery_id == nil` (does not raise).
- Phase 31 payload-safety contract preserved: `WorkflowTransition.context` remains exactly `%{"event_name" => event_name}` — no payload, no `"delivery_id"` string key (delivery_id is a column, not a context entry).
- Two new tests added inside `describe "route_signal/1 — transition traces"` anchor the D-21 contract.

## Task Commits

Each task was committed atomically (worktree branch — orchestrator merges after wave completes):

1. **Task 1.1: Populate WorkflowTransition.delivery_id from signal.payload in route_signal/1** — `d77e097` (feat)
2. **Task 1.2: Add D-21 write-path tests inside `describe "route_signal/1 — transition traces"`** — `4928814` (test)

(No metadata commit in worktree mode — the orchestrator commits SUMMARY.md alongside STATE.md/ROADMAP.md after merge.)

## Files Created/Modified

- `lib/chimeway/workflows.ex` — Two-line change in `route_signal/1`:
  - Line 395: `= _signal` → `= signal` (binding made reachable inside the `Enum.reduce_while/3` closure).
  - Line 419: new attrs-map key `delivery_id: Map.get(signal.payload, "delivery_id")` inside the `append_transition/2` call.
- `test/chimeway/workflows_test.exs` — Two new tests appended inside the existing `describe "route_signal/1 — transition traces"` block (lines 291 and 320):
  - `"populates transition.delivery_id from signal.payload[\"delivery_id\"]"` — success path.
  - `"leaves transition.delivery_id nil when signal payload omits \"delivery_id\""` — nil-payload regression.

## Decisions Made

- **D-02 (Map.get over Map.fetch!):** confirmed during execution — the FK is nullable (`@optional_fields` lists `:delivery_id`) and host callers via `Chimeway.Signal.track/4` may legitimately omit the key. `Map.get/2` is the only correct access pattern.
- **D-21 invariant enforced at runtime, not via static gate:** Test A includes `refute Map.has_key?(transition.context, "delivery_id")` as the durable contract. The previously-proposed whole-file grep gate was correctly excluded from the plan because its file-wide scope would retroactively break on unrelated future additions.
- **Inline Delivery fixture for Test A:** the plan's parenthetical "any well-formed UUID" guidance was inaccurate (FK is enforced at insert time even with `on_delete: :nilify_all`). Resolved by inserting a real `Chimeway.Delivery` row inline using existing Event/Notification aliases plus the fully-qualified `Chimeway.Delivery` module name — no new helpers, no new aliases, no new describe blocks.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Test A required a real Delivery row, not just any UUID**
- **Found during:** Task 1.2 (initial test run after both tests added)
- **Issue:** Plan-supplied Test A code generated a random UUID (`Ecto.UUID.generate()`) and used it as `delivery_id`, relying on the plan's parenthetical claim that "the FK is `:nilify_all`" implied insert-time tolerance. Actually, `on_delete: :nilify_all` only governs delete behavior — the FK is still enforced at insert time, raising `Ecto.ConstraintError` (`chimeway_workflow_transitions_delivery_id_fkey`) when no matching `chimeway_deliveries.id` exists. Initial run failed: `13 tests, 1 failure`.
- **Fix:** Inserted a real Delivery row inline before invoking `route_signal/1` using `Chimeway.Delivery.changeset/2` with minimal required fields (notification_id, channel, status, tenant_id, actor_id) plus a fresh Event + Notification (matching the existing `insert_workflow_run!/1` fixture pattern). No new helpers, no new aliases — used fully-qualified `Chimeway.Delivery` to honor the no-new-aliases constraint.
- **Files modified:** `test/chimeway/workflows_test.exs` (Test A only — Test B unchanged because empty payload exercises the nil path which is FK-tolerant)
- **Verification:** Re-run `mix test test/chimeway/workflows_test.exs` → `13 tests, 0 failures`. Combined run with `workflows_inspection_test.exs` → `29 tests, 0 failures`.
- **Committed in:** `4928814` (Task 1.2 commit — full Test A is in this commit; the bug was caught and fixed before commit, not after)

---

**Total deviations:** 1 auto-fixed (1 bug — incorrect FK semantics in plan-supplied test text)
**Impact on plan:** Auto-fix was localized to Test A's setup code; behavior, assertions, and verification gates all unchanged. No scope creep.

## Issues Encountered

- Initial `mix compile --warnings-as-errors` invocation failed with "Unchecked dependencies" — the worktree did not have `_build`/`deps` populated. Resolved with `mix deps.get` (one-time setup, no plan impact).

## Verification Results

| Gate | Command | Result |
|------|---------|--------|
| Compile clean | `mix compile --warnings-as-errors` | exit 0, no warnings |
| Workflows tests | `mix test test/chimeway/workflows_test.exs` | 13 tests, 0 failures |
| Inspection tests (payload-safety canonical) | `mix test test/chimeway/workflows_inspection_test.exs` | 16 tests, 0 failures |
| Combined sanity | `mix test test/chimeway/workflows_test.exs test/chimeway/workflows_inspection_test.exs` | 29 tests, 0 failures |
| Edit 1 grep (binding fix) | `grep -E '%Signal\{...\} = signal' lib/chimeway/workflows.ex` | 1 match |
| Edit 2 grep (attrs key) | `grep -F 'delivery_id: Map.get(signal.payload, "delivery_id")' lib/chimeway/workflows.ex` | 1 match |
| `_signal` removed | `grep -F '= _signal' lib/chimeway/workflows.ex` | 0 matches |
| Atom-safety gate (lib) | `! grep -E 'String\.to_atom\|String\.to_existing_atom' lib/chimeway/workflows.ex` | 0 matches |
| Atom-safety gate (test) | `! grep -E 'String\.to_atom\|String\.to_existing_atom' test/chimeway/workflows_test.exs` | 0 matches |
| Test A title present | `grep -c 'test "populates transition.delivery_id from signal.payload' test/chimeway/workflows_test.exs` | 1 |
| Test B title present | `grep -c 'test "leaves transition.delivery_id nil when signal payload omits' test/chimeway/workflows_test.exs` | 1 |
| Files-modified scope | `git diff --stat HEAD~2 HEAD` | exactly `lib/chimeway/workflows.ex` + `test/chimeway/workflows_test.exs` |

## TDD Gate Compliance

The plan declared Tasks 1.1 (`tdd="true"`) and 1.2 (`tdd="true"`) with the implementation in 1.1 preceding the new tests in 1.2 — a deliberate inversion of strict RED→GREEN ordering, justified by the plan because:
- The existing test in `describe "route_signal/1 — transition traces"` (lines 266-289) and the canonical payload-safety test in `workflows_inspection_test.exs:294-313` together act as a regression-only gate for Task 1.1 (the additive change must not break them).
- Task 1.2 then adds the D-21 success-path and nil-payload tests as durable contract assertions.

The two-commit sequence in git log (`feat(32-01): ...` → `test(32-01): ...`) reflects this plan-level structure. No RED→GREEN sequencing violation: Task 1.1's pre-existing tests passed both before and after the implementation change (regression intent); Task 1.2's new tests are written in two passes (the buggy plan-supplied Test A would have run RED on its initial pass, the fix moved it to GREEN — both within Task 1.2's commit boundary).

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- **Plan 02 unblocked:** the read-side projection's `lookup_signal_received_event_name/1` helper now has populated `signal_received.delivery_id` rows to project from. Without this plan, the helper would return `nil` for all webhook-routed transitions.
- **Zero migrations shipped** — the FK has existed on the schema since Phase 24; this plan only populates a column already declared optional.
- **Zero schema changes** — `WorkflowTransition.context` shape is byte-identical to Phase 31's contract.
- **Zero new error tuples** — `route_signal/1`'s success/failure shape is unchanged.

## Self-Check: PASSED

- File `lib/chimeway/workflows.ex` exists and contains both edits (verified by grep gates above).
- File `test/chimeway/workflows_test.exs` exists and contains both new tests (verified by grep gates above).
- Commit `d77e097` exists in git log: `feat(32-01): populate WorkflowTransition.delivery_id from signal.payload in route_signal/1`.
- Commit `4928814` exists in git log: `test(32-01): add D-21 write-path tests for transition.delivery_id population`.

---
*Phase: 32-operator-traces-audit*
*Completed: 2026-05-01*
