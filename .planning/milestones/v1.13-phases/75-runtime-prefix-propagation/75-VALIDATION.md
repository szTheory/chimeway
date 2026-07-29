---
phase: 75
slug: runtime-prefix-propagation
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-07-01
revised: 2026-07-01
---

# Phase 75 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit with Ecto SQL Sandbox and PostgreSQL |
| **Config file** | `config/test.exs`, `test/support/conn_case.ex`, `test/support/data_case.ex` |
| **Wave 0 quick run command** | `MIX_ENV=test mix test test/chimeway/repo_prefix_test.exs test/chimeway/runtime_prefix_integration_test.exs --warnings-as-errors` |
| **Final suite command** | `mix verify.runtime_prefix && mix ci.test && mix verify.install_golden` |
| **Estimated runtime** | ~180 seconds for focused prefix checks; broader CI can exceed that at the final gate |

---

## Sampling Rate

- **After every task commit:** Run the task-owned automated command listed below; no task-level command should require a future task's file or future tag behavior.
- **After Wave 0:** Run `MIX_ENV=test mix test test/chimeway/repo_prefix_test.exs test/chimeway/runtime_prefix_integration_test.exs --warnings-as-errors` and confirm any RED failures are implementation-contract failures, not harness setup or compile failures.
- **After implementation waves:** Run the newly green tag for the completed plan plus its existing public-mode focused tests.
- **Final Phase 75 gate:** Plan 75-07 owns `mix verify.runtime_prefix`, then `mix ci.test`, then `mix verify.install_golden`.
- **Max feedback latency:** 180 seconds for focused prefix checks; broader CI can run as the final phase gate.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 75-01-01 | 01 | 0 | RUN-01, RUN-02, RUN-03, RUN-04 | T-75-01 / T-75-02 | Prefix test harness creates and tears down isolated `chimeway` schema without leaking app env into public-mode tests | support compile smoke | `MIX_ENV=test mix test test/chimeway/storage_test.exs --warnings-as-errors` | no - created by task | green |
| 75-01-02 | 01 | 0 | RUN-01, RUN-02, RUN-03 | T-75-02 | `Repo.default_options/1` guardrails delegate to `Chimeway.Storage.repo_opts/1`, preserve explicit `prefix:` probes, and reject broad wrapper/API prefix shapes | unit | `MIX_ENV=test mix test test/chimeway/repo_prefix_test.exs --warnings-as-errors` | no - created by task | green |
| 75-01-03 | 01 | 0 | RUN-01, RUN-02, RUN-03, RUN-04 | T-75-01 / T-75-03 | Runtime integration suite defines narrow tags for trigger, operator, Oban boundary, workflow/signal, dispatch-worker delivery reload, digest, webhook, preferences, policy evaluation, and public mode. The dispatch-worker tag names `Chimeway.Dispatch.ObanWorker.perform/1` delivery reload by durable `delivery_id` and `Chimeway.Dispatch.DeferredResumeWorker.perform/1` deferred resume reload by durable `delivery_id`. | integration scaffold | `MIX_ENV=test mix test test/chimeway/runtime_prefix_integration_test.exs --warnings-as-errors` | no - created by task | green |
| 75-02-01 | 02 | 1 | RUN-01, RUN-02, RUN-03 | T-75-04 | Repo defaults apply configured storage prefix to normal operations while transaction options remain unprefixed | unit | `MIX_ENV=test mix test test/chimeway/repo_prefix_test.exs --warnings-as-errors` | yes - 75-01 | green |
| 75-02-02 | 02 | 1 | RUN-01, RUN-02 | T-75-05 / T-75-06 | Trigger fanout, string-source `insert_all`, and duplicate idempotency use configured storage without public API prefix options | integration + regression | `MIX_ENV=test mix test test/chimeway/runtime_prefix_integration_test.exs --only runtime_prefix_trigger --warnings-as-errors`<br>`MIX_ENV=test mix test test/chimeway/trigger_pipeline_test.exs --warnings-as-errors` | yes - 75-01 | green |
| 75-03-01 | 03 | 2 | RUN-02, RUN-04 | T-75-07 | Admin and trace option filtering preserves tenant/redaction behavior and explicit prefix probes while delegating prefix mapping to Storage | focused public tests | `MIX_ENV=test mix test test/chimeway/admin_test.exs test/chimeway/traces_test.exs --warnings-as-errors` | yes - existing | green |
| 75-03-02 | 03 | 2 | RUN-04 | T-75-08 / T-75-09 | Inbox, admin, trace, and recovery surfaces route through configured storage while preserving tenant predicates and redaction | integration + focused public tests | `MIX_ENV=test mix test test/chimeway/runtime_prefix_integration_test.exs --only runtime_prefix_operator --warnings-as-errors`<br>`MIX_ENV=test mix test test/chimeway/inbox_integration_test.exs test/chimeway/inbox_state_transition_test.exs test/chimeway/orchestration/recovery_test.exs --warnings-as-errors` | yes - 75-01 | green |
| 75-04-01 | 04 | 2 | RUN-03 | T-75-10 | Direct `Oban.Job` reads/deletes use Oban's job-table prefix domain while Chimeway-owned rows use configured storage | integration + focused public tests | `MIX_ENV=test mix test test/chimeway/dispatch/oban_test.exs --warnings-as-errors`<br>`MIX_ENV=test mix test test/chimeway/runtime_prefix_integration_test.exs --only runtime_prefix_oban_boundary --warnings-as-errors` | yes - 75-01 | green |
| 75-04-02 | 04 | 2 | RUN-03 | T-75-11 | Workflow progression, signal routing, `Chimeway.Dispatch.ObanWorker.perform/1` delivery reloads, and `Chimeway.Dispatch.DeferredResumeWorker.perform/1` deferred resume reloads use durable IDs and configured Chimeway storage | integration + focused public tests | `MIX_ENV=test mix test test/chimeway/runtime_prefix_integration_test.exs --only runtime_prefix_workflow_signal --warnings-as-errors`<br>`MIX_ENV=test mix test test/chimeway/runtime_prefix_integration_test.exs --only runtime_prefix_dispatch_worker --warnings-as-errors`<br>`MIX_ENV=test mix test test/chimeway/orchestration/workflow_progression_test.exs test/chimeway/signal_test.exs test/chimeway/dispatch/signal_router_worker_test.exs test/chimeway/dispatch/workflow_progression_worker_test.exs test/chimeway/dispatch/oban_worker_test.exs test/chimeway/orchestration/deferred_resume_test.exs --warnings-as-errors` | yes - 75-01 | green |
| 75-06-01 | 06 | 2 | RUN-03 | T-75-19 | Preferences and policy settings read/write configured storage without exposing prefix arguments on domain APIs | integration + focused public tests | `MIX_ENV=test mix test test/chimeway/runtime_prefix_integration_test.exs --only runtime_prefix_preferences --warnings-as-errors`<br>`MIX_ENV=test mix test test/chimeway/preferences_test.exs test/chimeway/policy_settings_test.exs --warnings-as-errors` | yes - 75-01 | green |
| 75-06-02 | 06 | 2 | RUN-03 | T-75-20 / T-75-21 | Policy evaluation reloads configured storage and preserves suppression explainability with payload-safe telemetry | integration + focused public tests | `MIX_ENV=test mix test test/chimeway/runtime_prefix_integration_test.exs --only runtime_prefix_policy_eval --warnings-as-errors`<br>`MIX_ENV=test mix test test/chimeway/policy_test.exs test/chimeway/policy/delayed_fallback_test.exs --warnings-as-errors` | yes - 75-01 | green |
| 75-05-01 | 05 | 3 | RUN-03 | T-75-16 / T-75-18 | Digest rules, buckets, memberships, emission, and bulk operations use configured storage while job args remain durable-ID based | integration + focused public tests | `MIX_ENV=test mix test test/chimeway/runtime_prefix_integration_test.exs --only runtime_prefix_digest --warnings-as-errors`<br>`MIX_ENV=test mix test test/chimeway/digests/accumulation_test.exs test/chimeway/digests/emission_test.exs test/chimeway/digests/flush_scheduling_test.exs --warnings-as-errors` | yes - 75-01 | green |
| 75-05-02 | 05 | 3 | RUN-03 | T-75-17 | Webhook ingress and feedback worker reload durable ingress IDs from configured storage without payload-bearing diagnostics | integration + focused public tests | `MIX_ENV=test mix test test/chimeway/runtime_prefix_integration_test.exs --only runtime_prefix_webhook --warnings-as-errors`<br>`MIX_ENV=test mix test test/chimeway/webhooks/ingress_test.exs test/chimeway/webhooks/process_feedback_worker_test.exs --warnings-as-errors` | yes - 75-01 | green |
| 75-07-01 | 07 | 4 | RUN-01, RUN-02, RUN-03, RUN-04 | T-75-13 / T-75-15 | Focused `mix verify.runtime_prefix` alias covers only Phase 75 runtime-prefix proof files and preserves existing verify aliases | CI alias | `mix verify.runtime_prefix` | no - created by task | green |
| 75-07-02 | 07 | 4 | RUN-01, RUN-02, RUN-03, RUN-04 | T-75-13 / T-75-14 / T-75-15 | Final phase gate proves runtime prefix behavior, public legacy compatibility, and generated migration proof | final gate | `mix verify.runtime_prefix`<br>`mix ci.test`<br>`mix verify.install_golden` | yes - 75-07-01 | green |
| 75-08-01 | 08 | gap-closure | RUN-02, RUN-04 | T-75-22 / T-75-23 / T-75-24 / T-75-26 | Admin read models and recovery execution use ordinary API args, preserve redaction/tenant predicates, stamp recovery evidence durably, and avoid public-schema fallback | integration + regression | `MIX_ENV=test mix test test/chimeway/runtime_prefix_integration_test.exs --only runtime_prefix_operator --warnings-as-errors`<br>`MIX_ENV=test mix test test/chimeway/admin_test.exs test/chimeway/orchestration/recovery_test.exs --warnings-as-errors` | yes - 75-01 | green |
| 75-08-02 | 08 | gap-closure | RUN-03 | T-75-25 / T-75-26 | Signal routing and workflow progression execute from exact durable-ID-only queued args and reload canonical rows from configured Chimeway storage | integration + final gate | `MIX_ENV=test mix test test/chimeway/runtime_prefix_integration_test.exs --only runtime_prefix_workflow_signal --warnings-as-errors`<br>`mix verify.runtime_prefix`<br>`mix ci.test`<br>`mix verify.install_golden` | yes - 75-01 | green |

*Status values: pending, green, red, flaky*

---

## Wave 0 Requirements

- [x] `test/support/prefixed_runtime_case.ex` - serialized prefix env and DB/schema/migration setup for prefixed runtime integration tests.
- [x] `test/chimeway/repo_prefix_test.exs` - unit guardrails for `Repo.default_options/1`, `Storage.repo_opts/1`, explicit prefix override preservation, and string-source `insert_all` routing proof.
- [x] `test/chimeway/runtime_prefix_integration_test.exs` - prefixed runtime integration proof for RUN-01 through RUN-04 with narrow task-owned tags, including `:runtime_prefix_dispatch_worker` proof for `test/chimeway/dispatch/oban_worker_test.exs` and `test/chimeway/orchestration/deferred_resume_test.exs` analog paths.

## Final Gate Ownership

- [x] Plan 75-07 creates `mix verify.runtime_prefix`.
- [x] Plan 75-07 runs `mix verify.runtime_prefix`, `mix ci.test`, and `mix verify.install_golden`.
- [x] `mix verify.runtime_prefix` remains focused on `test/chimeway/repo_prefix_test.exs` and `test/chimeway/runtime_prefix_integration_test.exs`; Phase 76 owns broader docs/demo/release-gate parity.
- [x] Plan 75-08 closes verifier gaps for admin, recovery, signal routing, and workflow progression execution.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| PostgreSQL 15 compatibility | RUN-01, RUN-02, RUN-03, RUN-04 | Local development may run PostgreSQL 14 while the project target is PostgreSQL 15+ | Treat green CI or a local PostgreSQL 15 service run of `mix verify.runtime_prefix` as final proof |

---

## Validation Sign-Off

- [x] All 17 tasks have automated verify commands.
- [x] Task-level verifies do not reference files before the owning or prior task creates them.
- [x] Async/runtime tags are narrow enough that Plans 75-04 and 75-05 verify only behavior owned by the current task or prior completed tasks.
- [x] Plan 75-07 owns `mix verify.runtime_prefix`; Wave 0 does not.
- [x] Sampling continuity: no 3 consecutive tasks without automated verify.
- [x] Wave 0 covers all missing references.
- [x] No watch-mode flags.
- [x] Feedback latency target documented.
- [x] `nyquist_compliant: true` set in frontmatter.

**Approval:** approved 2026-07-01

## Validation Audit 2026-07-01

| Metric | Count |
|--------|-------|
| Gaps found | 2 |
| Resolved | 2 |
| Escalated | 0 |

- Added 75-08 gap-closure validation rows for admin/recovery execution and worker progression execution.
- Final evidence: `mix verify.runtime_prefix` (16 tests, 0 failures), `mix ci.test` (1085 tests, 0 failures, 41 excluded), and `mix verify.install_golden` (14 tests, 0 failures).
