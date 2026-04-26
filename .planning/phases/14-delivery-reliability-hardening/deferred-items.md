# Phase 14 Deferred Items

Items discovered during execution that are out of scope for the current task and are
deferred for explicit handling later. Per executor scope-boundary rule: only auto-fix
issues directly caused by the current task's changes; pre-existing failures in
unrelated files are logged here.

## Pre-existing `mix format --check-formatted` violations

Discovered while running `mix ci` for Plan 14-01. These files are not touched by
Phase 14 Wave 0 (test scaffolding only) and the violations exist on `main` prior to
this plan. They block `mix ci.lint` for everyone, not just this plan.

| File                                | Discovered in | Notes                                                                     |
| ----------------------------------- | ------------- | ------------------------------------------------------------------------- |
| `lib/chimeway/policy.ex`            | 14-01, 14-02  | Pre-existing format violation, unrelated to Phase 14 scope                |
| `lib/chimeway/policy/settings.ex`   | 14-01, 14-02  | Pre-existing format violation, unrelated to Phase 14 scope                |
| `test/chimeway/policy_test.exs`     | 14-01, 14-02  | Long-line `assert ==` not wrapped; pre-existing                            |

**Recommended disposition:** Have a Phase 14 closeout plan (or a one-off chore commit)
run `mix format` on these three files. Touching them inside 14-01 or 14-02 would expand
scope beyond their documented boundaries (Wave 0 test scaffolding for 14-01; additive
schema/migration for 14-02). 14-02 confirms `mix ci` is still blocked by the same three
files.

## Phase 10-02 telemetry.span/3 enrichment dependency (discovered in 14-08)

Discovered while running per-file regression spot-checks for Plan 14-08 Task 2.

`test/chimeway/reliability/attempt_history_test.exs:148` — the test
`[:attempts, :record, :stop] event meta carries attempt_number and error_class`
asserts `Map.has_key?(meta, :delivery_id)` on the `[:chimeway, :attempts, :record, :stop]`
telemetry stop event metadata. The current `Chimeway.Telemetry.span/3` (lib/chimeway/telemetry.ex)
forwards to `:telemetry.span/3` which does NOT auto-merge the start metadata into the stop
event metadata — only the `extra` map returned from the function tuple ends up on `:stop`.

`Chimeway.Deliveries.record_attempt/2` passes `delivery_id` in the start metadata but only
`{attempt_id, outcome, attempt_number, error_class}` in the `extra`, so `:stop` meta lacks
`delivery_id`.

| File                                              | Discovered in | Notes                                                                 |
| ------------------------------------------------- | ------------- | --------------------------------------------------------------------- |
| `lib/chimeway/telemetry.ex`                       | 14-08         | span/3 must merge start meta into stop meta (Phase 10-02 enrichment)  |
| `test/chimeway/reliability/attempt_history_test.exs:148-181` | 14-08 | 1 failing test — depends on the telemetry.ex fix landing             |

**Recommended disposition:** The Phase 10-02 `span/3` enrichment fix is being held in the
main worktree per executor instructions ("Do NOT modify lib/chimeway/telemetry.ex. The
Phase 10-02 span/3 enrichment fix is sitting as in-progress local edits in the main
worktree — leave telemetry.ex alone."). When that fix lands, this regression spot-check
will go green automatically. The other 30 reliability tests pass; only this single
telemetry-meta assertion fails.

Phase 14 D-15 spot-check status with this caveat:

| Spot-check                                                                | Result |
| ------------------------------------------------------------------------- | ------ |
| `mix test test/chimeway/telemetry_correlation_test.exs`                   | PASS   |
| `mix test test/chimeway/dispatch/sync_test.exs`                           | PASS   |
| `mix test test/chimeway/dispatch/oban_transactional_test.exs --include oban` | PASS   |
| `mix test test/chimeway/dispatch/oban_worker_test.exs --include oban`     | PASS   |
| `mix test test/chimeway/reliability/ --include oban --include integration` | 30/31 PASS — single failure pinned to Phase 10-02 enrichment dep |
| `mix compile --warnings-as-errors --force`                                | PASS   |
