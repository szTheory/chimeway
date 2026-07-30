# 89-03 Summary — Fan-out: 7 async flips (orchestration/integration/trigger)

**Status:** COMPLETE (commit `42ee53a`) · **Requirements:** CONC-01

Flipped to `async: true` (research-audited D-02 flip-safe):
`orchestration/digest_explainability`, `orchestration/delivery_planning`,
`integration/trigger_explain`, `integration/readme_snippet` (its `use` is at line 15),
`idempotency_constraint`, `trigger_sanitization`, `persistence_transaction`.

These fire `Trigger.trigger` telemetry but only ASSERT on it — unlike `telemetry_correlation_test.exs`, which ATTACHes global `:telemetry` handlers and therefore stays `async: false` (RESEARCH §4). Verified in the combined suite run (see 89-06).
