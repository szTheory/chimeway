---
phase: 75-runtime-prefix-propagation
verified: 2026-07-01T20:08:55Z
status: gaps_found
score: "32/38 must-haves verified"
behavior_unverified: 4
overrides_applied: 0
gaps:
  - truth: "Prefixed integration tests prove trigger-to-trace, duplicate idempotency, inbox read/seen, workflow progression, digest, webhook, and recovery paths."
    status: failed
    reason: "The focused runtime-prefix gate passes, but test/chimeway/runtime_prefix_integration_test.exs does not call Chimeway.Admin read models, Deliveries.recover_event/2, Deliveries.recover_delivery/2, SignalRouterWorker.perform/1, WorkflowProgressionWorker.perform/1, or Workflows.Progression.progress_run/2 under prefix mode."
    artifacts:
      - path: "test/chimeway/runtime_prefix_integration_test.exs"
        issue: "Contains runtime_prefix_operator, runtime_prefix_workflow_signal, and other tags, but the operator test only covers inbox plus Traces.get_trace/1 and the workflow/signal test only persists a signal and asserts a job was enqueued."
      - path: "mix.exs"
        issue: "verify.runtime_prefix points only at repo_prefix_test.exs and runtime_prefix_integration_test.exs, so the focused gate inherits the missing admin/recovery/progression coverage."
    missing:
      - "Add prefixed runtime assertions that call Admin.command_center/1, Admin.recent_problem_deliveries/1, Admin.definitions/1, Admin.feed/1, Admin.recovery_candidates/1, and Admin.outcome_totals/1 against prefixed rows."
      - "Add prefixed runtime assertions that call recovery flows such as Deliveries.begin_recovery/2, Deliveries.recover_delivery/2, and/or Deliveries.recover_event/2 and prove they do not read/write public rows."
      - "Add prefixed runtime assertions that execute SignalRouterWorker.perform/1 and WorkflowProgressionWorker.perform/1 or the shared Progression.progress_run/2 seam, not only signal persistence/enqueue assertions."
  - truth: "Runtime prefix integration coverage exists for trigger-to-trace, duplicate idempotency, inbox read/seen, workflow progression, digest, webhook, recovery, admin, trace, and explicit dispatch worker reload paths per D-16."
    status: failed
    reason: "Coverage is present for trigger, duplicate idempotency, trace, inbox read/seen, Oban boundary, dispatch workers, digest, webhook, preferences, policy, and public legacy mode. It is absent for Admin read models, recovery execution, and actual workflow/signal progression worker execution."
    artifacts:
      - path: "test/chimeway/runtime_prefix_integration_test.exs"
        issue: "No Admin, recover_event/recover_delivery, SignalRouterWorker.perform, WorkflowProgressionWorker.perform, or progress_run invocation appears in the focused integration suite."
    missing:
      - "Expand runtime_prefix_operator or add new tags to cover admin and recovery."
      - "Expand runtime_prefix_workflow_signal or add new tags to cover progression worker execution and signal routing reloads."
behavior_unverified_items:
  - truth: "Admin and recovery reads use configured storage by default per RUN-04."
    test: "Create prefixed runtime rows, then call Admin read-model functions and recovery functions under Application prefix \"chimeway\"."
    expected: "Admin DTOs and recovery results come from chimeway.chimeway_* rows, public.chimeway_* remains empty, and tenant/redaction assertions still hold."
    why_human: "Source wiring uses Repo defaults/Storage.repo_opts, but the focused runtime-prefix test gate never executes these admin or recovery APIs under prefix mode."
  - truth: "Workflow progression and signal routing use the configured Chimeway prefix per RUN-03."
    test: "Drive a waiting workflow with a matching signal and execute SignalRouterWorker.perform/1, then execute WorkflowProgressionWorker.perform/1 or Progression.progress_run/2 under prefix mode."
    expected: "Workflow runs, transitions, signals, and next-step deliveries are read/written in the chimeway schema with no public fallback."
    why_human: "The current runtime_prefix_workflow_signal test persists a workflow run and signal and asserts an enqueued job, but it does not execute the routing/progression runtime path."
  - truth: "Focused mix verify.runtime_prefix covers all Phase 75 runtime-prefix success criteria."
    test: "Inspect verify.runtime_prefix coverage against the Phase 75 roadmap success criteria."
    expected: "The alias executes tests covering trigger, idempotency, trace, inbox, admin, recovery, workflow progression, signal routing, digest, webhook, preferences, policy, dispatch workers, and public legacy mode."
    why_human: "The alias is wired and green, but coverage completeness requires reviewing which runtime APIs the tests actually invoke."
  - truth: "RUN-04 is behaviorally proven for admin, inbox, trace, and recovery surfaces under prefix mode."
    test: "Run prefixed runtime tests that exercise all RUN-04 surfaces."
    expected: "Admin, inbox, trace, and recovery surfaces all use configured storage and preserve tenant/redaction behavior."
    why_human: "Inbox and trace are exercised under prefix mode; admin and recovery are source-wired but not behaviorally exercised by the focused gate."
---

# Phase 75: Runtime Prefix Propagation Verification Report

**Phase Goal:** Thread the storage-prefix contract through Chimeway runtime behavior so real notification flows read and write in the configured schema.
**Verified:** 2026-07-01T20:08:55Z
**Status:** gaps_found
**Re-verification:** No - initial verification

## Goal Achievement

Phase 75 is close but not complete. The core prefix mechanism is real: `Chimeway.Repo.default_options/1` delegates normal operations to `Chimeway.Storage.repo_opts/1`, the focused `mix verify.runtime_prefix` alias exists, and the verifier re-ran the final gates successfully. The blocker is coverage, not command health: the focused gate does not actually exercise several required runtime paths named by the roadmap and plan must-haves.

### Observable Truths

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | Trigger fanout persists events, notifications, deliveries, and attempts into the configured prefix. | VERIFIED | `runtime_prefix_trigger` calls `Chimeway.trigger/3`, asserts prefixed-only events/notifications/deliveries/attempts, and duplicate idempotency returns the configured-schema event. |
| 2 | Idempotency, duplicate detection, traces, explainability, and inbox reads avoid public fallback when prefix mode is enabled. | VERIFIED | Runtime tests cover duplicate trigger, `Traces.get_trace/1`, `Chimeway.list_for_recipient/2`, `mark_seen/3`, `mark_read/3`, and `unread_count/1`; trace explicit prefix probes remain in `test/chimeway/traces_test.exs`. |
| 3 | Admin and recovery paths are covered by prefixed integration tests. | FAILED | `rg` found no `Chimeway.Admin`, `recover_event`, or `recover_delivery` call in `test/chimeway/runtime_prefix_integration_test.exs`. |
| 4 | Workflow progression and signal routing execute under configured prefix. | PRESENT_BEHAVIOR_UNVERIFIED | Source has `SignalRouterWorker.perform/1` and `WorkflowProgressionWorker.perform/1`; runtime test only asserts signal row placement and job enqueue, not worker/progression execution. |
| 5 | Digests, webhook ingress, preferences, policy settings, policy evaluation, dispatch workers, and string-source/bulk operations propagate prefix options. | VERIFIED | Runtime tags cover digest accumulation/flush, webhook process/feedback worker, preference/settings/policy rows, Oban/deferred workers, and `insert_all`/`update_all` paths. |
| 6 | Legacy public mode remains green. | VERIFIED | `runtime_prefix_public` asserts public rows are created and prefixed rows remain zero with `prefix: false`; `mix ci.test` also passed. |
| 7 | `mix verify.runtime_prefix` is focused and green. | VERIFIED | `mix.exs` alias runs only `repo_prefix_test.exs` and `runtime_prefix_integration_test.exs`; verifier run passed 16 tests, 0 failures. |

**Score:** 32/38 must-haves verified, 4 present-but-behavior-unverified, 2 failed.

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `test/support/prefixed_runtime_case.ex` | Serialized prefixed runtime case and row-placement helpers | VERIFIED | Exists, substantive, uses `Chimeway.Repo`, `Application.put_env(:chimeway, :prefix, "chimeway")`, fixture-root check, schema-qualified row counts, and env restoration. |
| `test/chimeway/repo_prefix_test.exs` | Repo default-options guardrails | VERIFIED | Tests transaction defaults, normal operation prefix defaults, public legacy mode, explicit prefix probes, and forbidden schema-prefix/wrapper repo shapes. |
| `test/chimeway/runtime_prefix_integration_test.exs` | End-to-end runtime prefix proof | PARTIAL | Substantive and wired to the gate, but missing required admin, recovery, and actual signal/progression worker coverage. |
| `lib/chimeway/repo.ex` / `lib/chimeway/storage.ex` | Runtime storage-prefix seam | VERIFIED | `default_options(:transaction) == []`; other operations delegate to `Chimeway.Storage.repo_opts/1`; explicit probes win through `Keyword.put_new/3`. |
| Runtime implementation files | Prefix propagation across trigger, traces, admin, inbox, deliveries, workflows, dispatch, digests, webhooks, preferences, policy | VERIFIED_WITH_GAPS | Source is substantive and uses Repo defaults or explicit `Storage.repo_opts/1`/Oban opts where appropriate; behavior gap is focused gate coverage. |
| `mix.exs` | Focused `verify.runtime_prefix` alias | VERIFIED | Alias exists and references only the two focused runtime-prefix test files. |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `lib/chimeway/repo.ex` | `lib/chimeway/storage.ex` | `default_options/1` delegates to `Storage.repo_opts/1` | VERIFIED | Manual `rg` found `def default_options(_operation), do: Chimeway.Storage.repo_opts()`. |
| `test/chimeway/runtime_prefix_integration_test.exs` | Runtime APIs | Ordinary API calls, no prefix options | VERIFIED_WITH_GAPS | Calls `Chimeway.trigger/3`, inbox, trace, dispatch, digest, webhook, preferences, and policy APIs; missing Admin/recovery/progression-worker calls. |
| `lib/chimeway/dispatch/oban.ex` | Oban config | Oban job-table opts separate from Chimeway storage prefix | VERIFIED | Direct `Oban.Job` queries use `oban_job_repo_opts()` from Oban config. |
| `mix.exs` | Runtime prefix tests | `verify.runtime_prefix` command | VERIFIED | Alias invokes `test/chimeway/repo_prefix_test.exs` and `test/chimeway/runtime_prefix_integration_test.exs`. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|---|---|---|---|---|
| `test/chimeway/runtime_prefix_integration_test.exs` | Prefixed row counts | Real `Chimeway.trigger/3`, Repo operations, workers, and schema-qualified SQL counts | Yes | FLOWING for covered paths |
| `lib/chimeway/repo.ex` | Repo operation opts | `Application.get_env(:chimeway, :prefix)` through `Storage.validate_prefix!/0` and `repo_opts/1` | Yes | FLOWING |
| `lib/chimeway/admin.ex` | Admin read DTOs | Ecto queries with `Repo.all(repo_opts(opts))` | Source-wired | PRESENT_BEHAVIOR_UNVERIFIED under prefix tests |
| `lib/chimeway/dispatch/signal_router_worker.ex` / `workflow_progression_worker.ex` | Worker reload IDs | `Repo.get(Signal, signal_id)` and `Progression.progress_run(workflow_run_id, [])` | Source-wired | PRESENT_BEHAVIOR_UNVERIFIED under prefix tests |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Focused runtime prefix proof | `mix verify.runtime_prefix` | 16 tests, 0 failures; non-fatal Threadline cleanup logs | PASS |
| Migration-generation regression proof | `mix verify.install_golden` | 14 tests, 0 failures; non-fatal Threadline cleanup logs | PASS |
| Public legacy broad regression | `mix ci.test` | 1085 tests, 0 failures, 41 excluded | PASS |

### Probe Execution

No `scripts/**/tests/probe-*.sh` probes were found. Phase 75 declares Mix verification gates instead; those were executed above.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|---|---|---|---|---|
| RUN-01 | 75-01, 75-02, 75-07 | Trigger fanout persists events, notifications, deliveries, attempts into configured prefix. | SATISFIED | `runtime_prefix_trigger` and `mix verify.runtime_prefix` passed. |
| RUN-02 | 75-01, 75-02, 75-03, 75-07 | Idempotency, duplicate detection, lifecycle reads, traces, explainability use configured prefix. | SATISFIED | Duplicate trigger, trace, inbox lifecycle, and explicit probe tests passed. |
| RUN-03 | 75-01, 75-02, 75-04, 75-05, 75-06, 75-07 | Workflow progression, signal routing, digests, policy/preferences, webhooks, dispatch workers, insert_all propagate prefix. | PARTIAL | Digest/webhook/preferences/policy/dispatch/bulk paths are tested; signal routing and workflow progression worker execution are not exercised under prefix mode. |
| RUN-04 | 75-01, 75-03, 75-07 | Admin, inbox, trace, recovery surfaces use configured prefix and remain tenant/redaction-safe. | PARTIAL | Inbox/trace prefixed behavior and public admin redaction tests pass; Admin and recovery are not exercised by prefixed runtime tests. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---|---|---|---|
| None | - | - | - | `rg` found no TODO/TBD/FIXME/XXX/HACK/PLACEHOLDER/stub markers in phase-owned runtime files. Forbidden source scan found no `@schema_prefix`, `schema_prefix`, or `search_path` usage under phase-owned runtime files. |

### Human Verification Required

None. The blocking issue is deterministically observable missing automated/runtime gate coverage, not a visual or external-service behavior.

### Gaps Summary

`mix verify.runtime_prefix` is real and green, but it is not yet the full focused Phase 75 gate promised by the roadmap and plan. Add prefixed runtime tests for Admin read models, recovery execution, and workflow/signal progression worker execution, then re-run `mix verify.runtime_prefix`, `mix ci.test`, and `mix verify.install_golden`.

---

_Verified: 2026-07-01T20:08:55Z_
_Verifier: the agent (gsd-verifier)_
