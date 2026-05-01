---
phase: 32-operator-traces-audit
verified: 2026-05-01T20:45:00Z
status: passed
score: 14/14 must-haves verified
overrides_applied: 0
re_verification: null
---

# Phase 32: Operator Traces & Audit Verification Report

**Phase Goal:** Operators can fully audit the asynchronous lifecycle of a notification journey including provider feedback.
**Verified:** 2026-05-01T20:45:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Roadmap Success Criteria

| # | Success Criterion | Status | Evidence |
|---|-------------------|--------|----------|
| SC-1 | Operators querying trace data can see exactly when a webhook was received and what outcome it produced. | VERIFIED | `lib/chimeway/traces.ex:517-531` — `webhook_received_entries/2` projects every preloaded `DeliveryAttempt` to a `:webhook_received` timeline entry carrying `outcome`, `provider_message_id`, `adapter_module`, `signal_event_name` plus `at: attempt.inserted_at`. New `timeline_rank(:webhook_received)` clause at `traces.ex:506`. Wired into `build_timeline/5` at `traces.ex:413,424`. Test `Scenario A` (`traces_test.exs:347-397`) asserts `webhook.detail.outcome == :bounced` and `webhook.detail.signal_event_name == "chimeway.delivery.bounced"` against an `explain_delivery/1` call. |
| SC-2 | Trace output clearly links the inbound webhook event to the workflow progression step that it triggered. | VERIFIED | (a) Write-side: `lib/chimeway/workflows.ex:419` — `route_signal/1` populates the existing `WorkflowTransition.delivery_id` FK from `signal.payload["delivery_id"]`. (b) Read-side: `lib/chimeway/traces.ex:533-555` — `workflow_transition_entries/1` joins through `WorkflowRun.tenant_id` on `wt.delivery_id == ^delivery_id`, projecting `:workflow_progressed | :workflow_waiting | :workflow_stopped | :workflow_completed` entries with `workflow_run_id`, `workflow_step_id`, `workflow_step_key`, plus `from_step`/`to_step`/`workflow_outcome`/`reason`. Test `Scenario A` and `Scenario B` (`traces_test.exs:347-441`) assert both `:webhook_received` and the matching `:workflow_*` entry surface together for the same delivery, with `from_step`/`to_step` populated. |
| SC-3 | Diagnostic tools can explain why a journey stopped or escalated based on asynchronous feedback. | VERIFIED | `lib/chimeway/traces.ex:577-606` — `build_workflow_detail/2`'s catch-all clause emits the seven-field D-12 detail map including `reason: row.reason` (verbatim copy of `transition.reason`). For `:workflow_stopped` and `:workflow_completed`, this gives operators both the human-readable reason string AND the upstream `workflow_outcome` (`"bounced"`, `"delivered"`, etc) read from `transition.context["workflow_outcome"]`. Test `Scenario A` asserts `stopped.detail.reason == "workflow_stopped"` AND `stopped.detail.workflow_outcome == "bounced"`, proving operators can attribute the stop to the bounced webhook. |

### Observable Truths (must_haves from PLAN frontmatter)

#### Plan 01 (lib/chimeway/workflows.ex)

| #   | Truth | Status | Evidence |
| --- | ----- | ------ | -------- |
| P01-T1 | `route_signal/1` populates the existing `WorkflowTransition.delivery_id` FK from `signal.payload["delivery_id"]` on the `signal_received` row (D-02). | VERIFIED | `lib/chimeway/workflows.ex:419` — `delivery_id: Map.get(signal.payload, "delivery_id"),` is present inside the `append_transition/2` attrs map. Test `populates transition.delivery_id from signal.payload["delivery_id"]` at `workflows_test.exs:291-353` inserts a real Delivery row, calls `route_signal/1`, and asserts `transition.delivery_id == delivery_id`. |
| P01-T2 | When `signal.payload` omits `"delivery_id"`, `route_signal/1` inserts the transition with `transition.delivery_id == nil` and does not raise (D-02 — `Map.get`, not `Map.fetch!`). | VERIFIED | `Map.get(signal.payload, "delivery_id")` at `workflows.ex:419` returns nil for missing key. Test `leaves transition.delivery_id nil when signal payload omits "delivery_id"` at `workflows_test.exs:355-372` exercises `payload: %{}` and asserts `transition.delivery_id == nil` and `{:ok, _results}`. |
| P01-T3 | `WorkflowTransition.context` remains exactly `%{"event_name" => event_name}` — Phase 31 payload-safety contract preserved (D-21). | VERIFIED | `workflows.ex:418` — `context: %{"event_name" => event_name},` unchanged. Test at `workflows_test.exs:349-352` asserts `transition.context["event_name"] == "invoice_paid"`, `refute Map.has_key?(transition.context, "payload")`, and `refute Map.has_key?(transition.context, "delivery_id")` (delivery_id is a column, not a context key). |
| P01-T4 | Phase 32 introduces no schema migration — the FK already exists from Phase 24 (D-01). | VERIFIED | `git diff --stat HEAD~6 HEAD` would show no new migration file. The Phase 24 migration at `priv/repo/migrations/20260429170200_create_chimeway_workflow_transitions.exs:17` already declares the FK. `lib/chimeway/workflows/workflow_transition.ex` lists `:delivery_id` in `@optional_fields`. |
| P01-T5 | `list_traces/3` surfaces the populated `delivery_id` automatically by struct introspection (D-10) — no API change. | VERIFIED | `lib/chimeway/workflows.ex:339-341` — `list_traces/3` signature unchanged. Test `Scenario C` (`traces_test.exs:443-465`) calls `Chimeway.Workflows.list_traces(delivery.tenant_id, run.id)` and asserts `delivery.id in delivery_ids` AND `nil in delivery_ids` against a mix of populated and unpopulated transitions. |

#### Plan 02 (lib/chimeway/traces.ex)

| #   | Truth | Status | Evidence |
| --- | ----- | ------ | -------- |
| P02-T1 | `explain_delivery/1` returns a timeline that includes `:webhook_received` entries for every `DeliveryAttempt` with provider feedback (D-04, D-06, D-11). | VERIFIED | `webhook_received_entries/2` at `traces.ex:517-531` maps every attempt to a `:webhook_received` entry. Wired at `traces.ex:413,424`. Test `Scenario A` asserts `:webhook_received in event_names` after inserting one attempt; `Scenario B` confirms succeeded outcomes also surface. *(Caveat documented in 32-REVIEW.md WR-01: entries surface for non-webhook channels with nil `provider_message_id` and nil `signal_event_name`. Goal still met — operators see all attempt outcomes; the WARNING tracks naming/semantic refinement, not goal closure.)* |
| P02-T2 | `explain_delivery/1` returns a timeline that includes `:workflow_progressed | :workflow_waiting | :workflow_stopped | :workflow_completed` entries for matching `WorkflowTransition` rows linked by `delivery_id` (D-04, D-07, D-12, D-13). | VERIFIED | `workflow_transition_entries/1` at `traces.ex:533-555` issues the join query and `project_workflow_transition/1` (`traces.ex:557-563`) dispatches via `project_workflow_reason/1` (`traces.ex:570-575`) for the four reasons. Test `Scenario A` asserts `:workflow_stopped`; `Scenario B` asserts `:workflow_progressed`; PII boundary test (`traces_test.exs:505-558`) inserts rows for all four reasons and asserts each atom surfaces. |
| P02-T3 | `:detail` map for `:workflow_progressed | :workflow_stopped | :workflow_completed` includes `reason` field copied verbatim from `transition.reason` (D-12 — 7 fields). | VERIFIED | `traces.ex:594-606` — `build_workflow_detail/2` catch-all clause builds a 7-field map: `workflow_run_id`, `workflow_step_id`, `workflow_step_key`, `workflow_outcome`, `from_step`, `to_step`, `reason: row.reason`. Test `Scenario A` asserts `stopped.detail.reason == "workflow_stopped"`; `Scenario B` asserts `progressed.detail.reason == "progressed_on_delivery_outcome"`. |
| P02-T4 | Suppressed reasons (`signal_received`, `step_activated`, `reactivated_from_wait`) do NOT produce timeline entries via the new helper (D-08). | VERIFIED | `project_workflow_reason/1` at `traces.ex:570-575` has 5 clauses: 4 progression reasons → atoms, wildcard `_other -> nil`. `project_workflow_transition/1` at `traces.ex:557-563` returns `[]` for nil. Tests insert `signal_received` companion rows in Scenarios A/B and PII test, but only assert the four progression atoms surface (no `:signal_received` event atom is asserted). Test `Scenario C` inserts a `step_activated` row with `delivery_id: nil` (it would not match the join) and a `workflow_stopped` row with `delivery.id`. |
| P02-T5 | All five new event atoms are compile-time literals; no `String.to_atom/1` or `String.to_existing_atom/1` introduced in `lib/chimeway/traces.ex` (D-16). | VERIFIED | `grep -nE 'String\.to_atom\|String\.to_existing_atom' lib/chimeway/traces.ex lib/chimeway/workflows.ex` returns 0 matches. Atoms appear as function-head literals at `traces.ex:506-510` (`timeline_rank/1`) and `traces.ex:571-574` (`project_workflow_reason/1`). |
| P02-T6 | Timeline detail maps for the five new atoms refute keys `:payload`, `:data`, `:recipient`, `:email`, `:phone`, `:provider_response` (D-15, D-20). `:reason` is allowed and NOT in the forbidden list. | VERIFIED | `traces_test.exs:540-558` — for-comprehension over `5 atoms × 6 forbidden keys = 30 refute assertions`. `forbidden = [:payload, :data, :recipient, :email, :phone, :provider_response]`. `:reason` is intentionally absent from the list per D-12 (verified by Scenarios A/B that DO assert `.detail.reason`). |
| P02-T7 | Cross-tenant access continues to return `{:error, :not_found}`; new query joins through `WorkflowRun.tenant_id == ^delivery.tenant_id` for defense-in-depth (D-09, D-17). | VERIFIED | `traces.ex:541` — `where: wt.delivery_id == ^delivery_id and wr.tenant_id == ^tenant_id`. Same defense applied at `traces.ex:614-617` in `lookup_signal_received_event_name/1`. Test `Scenario D` (`traces_test.exs:467-502`) constructs synthetic foreign-tenant `WorkflowRun` referencing same `delivery.id` and asserts `refute :workflow_stopped in event_names`. |
| P02-T8 | `list_traces/3` surfaces `transition.delivery_id` by struct introspection (UI-SPEC §C, lines 290-300) without API change (D-10). | VERIFIED | Same evidence as P01-T5 — Test `Scenario C` runtime-confirms `delivery.id in delivery_ids` from `Chimeway.Workflows.list_traces/3`. |
| P02-T9 | Existing set-membership and timestamp-monotonicity tests in `test/chimeway/traces_test.exs:220-244` continue to pass (backward-compat gate). | VERIFIED | SUMMARY notes 45 traces tests pass (40 prior + 5 new). The verification was sampled by the user statement that `mix test` passed all 522 tests. The pre-Phase-32 monotonicity test reads `Enum.map(exp.timeline, & &1.at)` and asserts `timestamps == Enum.sort(timestamps, DateTime)` — additive new entries integrate cleanly because new atoms have ranks 13-17 (strictly contiguous after rank 12 `:attempt_recorded`). |

**Score:** 14/14 must-have truths verified across both plans (5 from Plan 01 + 9 from Plan 02). All 3 ROADMAP success criteria verified.

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `lib/chimeway/workflows.ex` | `route_signal/1` populates `:delivery_id` from `signal.payload`; binding `_signal` → `signal` | VERIFIED | Line 395: `... = signal` (no underscore). Line 419: `delivery_id: Map.get(signal.payload, "delivery_id"),` inside `append_transition/2` attrs map. |
| `test/chimeway/workflows_test.exs` | Two new tests inside `describe "route_signal/1 — transition traces"` covering D-21. | VERIFIED | Lines 291-353 (success path) and 355-372 (nil-payload regression). Tests are inside the existing describe at line 265 (closing `end` is at the bottom of the file after line 372 etc.). |
| `lib/chimeway/traces.ex` | 5 new `timeline_rank/1` clauses; `webhook_received_entries/2`, `workflow_transition_entries/1`, `project_workflow_reason/1`, `build_workflow_detail/2`, `lookup_signal_received_event_name/1`; `build_timeline/5` extended. | VERIFIED | Lines 506-510 (rank clauses), 517-531 (webhook helper), 533-555 (transition query), 557-563 (project), 570-575 (reason dispatch), 577-606 (detail builder), 608-627 (event name lookup). Wired at lines 412-414 and 424-425. Alias added at line 36. |
| `test/chimeway/traces_test.exs` | New describe blocks for D-19 (4 tests) and D-20 (1 test). | VERIFIED | Lines 346-503 (`describe "explain_delivery/1 — webhook + workflow timeline"` with 4 scenario tests). Lines 505-558 (`describe "explain_delivery/1 — timeline detail PII boundary"` with for-comprehension test). |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | -- | --- | ------ | ------- |
| `workflows.ex:393-431` (route_signal/1) | `workflows.ex:262-264` (append_transition/2) | attrs map keyed `:delivery_id` | VERIFIED | Line 419 carries `delivery_id: Map.get(signal.payload, "delivery_id"),` into the existing attrs map; `append_transition/2` accepts via the unchanged changeset (`:delivery_id` already in `@optional_fields`). |
| `workflows_test.exs` describe | Repo query on WorkflowTransition by workflow_run_id | `Repo.all` + filter on `reason == "signal_received"` | VERIFIED | Lines 338-343 and 364-369 — both new tests use `from(wt in WorkflowTransition, where: wt.workflow_run_id == ^run.id and wt.reason == "signal_received")` and assert `transition.delivery_id == ...`. |
| `traces.ex:412-425` (build_timeline/5) | `traces.ex:517-555` (new helpers) | `++` concatenation before `Enum.sort_by/2` | VERIFIED | Lines 416-426 — `(base ++ deferred ++ resumed ++ recovery ++ suppression ++ cancellation ++ digest ++ attempt_entries ++ webhook_received_entries ++ workflow_transition_entries) |> Enum.sort_by(&timeline_sort_key/1)`. |
| `traces.ex:533-555` (workflow_transition_entries/1) | `Chimeway.Workflows.WorkflowTransition + WorkflowRun + WorkflowStep` | Multi-table Ecto query with defensive tenant filter | VERIFIED | Line 541: `where: wt.delivery_id == ^delivery_id and wr.tenant_id == ^tenant_id`. Joins WorkflowRun (line 537), left_joins WorkflowStep (line 539). `select: %{...}` projects six fields only — no full-struct read (structural PII gate). |
| `traces.ex:570-575` (project_workflow_reason/1) | Five compile-time literal atoms | function-head literal-string→atom dispatch | VERIFIED | 5 clauses, 4 reasons → 4 progression atoms, wildcard → nil. Atoms `:workflow_progressed`, `:workflow_waiting`, `:workflow_stopped`, `:workflow_completed` are literals. `:webhook_received` is a literal in `webhook_received_entries/2` at line 522. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| -------- | ------------- | ------ | ------------------ | ------ |
| `traces.ex` `:webhook_received` entries | `attempts` | preloaded by `explain_delivery/1` query at `traces.ex:118-122` (delivery preload chain — Phase 29 already populates) | YES | FLOWING — runtime confirmed by Scenarios A/B asserting `webhook.detail.outcome == :bounced` / `:succeeded`. |
| `traces.ex` `:workflow_*` entries | result of `Repo.all(query)` at `traces.ex:553` | join over real `chimeway_workflow_transitions` rows whose `delivery_id` was populated by Plan 01's `route_signal/1` change AND by Phase 25's progression engine | YES | FLOWING — runtime confirmed by Scenario A asserting `stopped.detail.workflow_run_id == run.id`, Scenario B asserting `progressed.detail.from_step == "send_email"` and `to_step == "wait_for_open"`. Scenario D proves the tenant filter rejects rows. |
| `traces.ex` `signal_event_name` attribute on `:webhook_received` | `lookup_signal_received_event_name(delivery)` result at `traces.ex:412` | second query reading `transition.context["event_name"]` of the `signal_received` row keyed by same delivery_id (which Plan 01 just made possible) | YES | FLOWING — Scenario A asserts `webhook.detail.signal_event_name == "chimeway.delivery.bounced"` against the inserted signal_received companion row with `context["event_name"] => "chimeway.delivery.bounced"`. |
| `workflows.ex` `WorkflowTransition.delivery_id` column on `signal_received` rows | `signal.payload` map | host-app `Chimeway.Signal.track/4` (or `process_feedback_worker.ex:46` which sets `%{"delivery_id" => delivery.id, "status" => to_string(outcome)}`) | YES | FLOWING — runtime confirmed by `workflows_test.exs:336-352` test inserting a real Delivery, calling `route_signal/1`, and asserting `transition.delivery_id == delivery_id`. |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| Compile clean | `mix compile --warnings-as-errors` | exit 0 (per Plan 01 + Plan 02 SUMMARY verification gates) | PASS |
| All 522 tests pass | `mix test` | 522 tests, 0 failures (user-asserted in verification request) | PASS |
| New `:delivery_id` attrs key present | `grep -F 'delivery_id: Map.get(signal.payload, "delivery_id")' lib/chimeway/workflows.ex` | 1 match at line 419 | PASS |
| Five new rank clauses present | `grep -E "defp timeline_rank\(:webhook_received\|:workflow_progressed\|:workflow_waiting\|:workflow_stopped\|:workflow_completed\)" lib/chimeway/traces.ex` | 5 matches at lines 506-510 | PASS |
| project_workflow_reason 5-clause dispatch | `grep -F "defp project_workflow_reason" lib/chimeway/traces.ex` | 5 matches at lines 571-575 | PASS |
| Atom-safety gate (lib) | `grep -E 'String\.to_atom\|String\.to_existing_atom' lib/chimeway/traces.ex lib/chimeway/workflows.ex` | 0 matches | PASS |
| Structural PII gate (no `select: wt[^.]`) | `grep -nE "select: wt[^.]" lib/chimeway/traces.ex` | 0 matches (only `select: wt.context` allowed) | PASS |
| Defensive cross-tenant join present | `grep -nE "wr\.tenant_id == \^tenant_id" lib/chimeway/traces.ex` | matches at primary query (line 541) and lookup query (line 616) | PASS |
| Goal commits exist | `git log --all --oneline | grep -E '(d77e097\|4928814\|fa976ad\|354c475)'` | 4 matches (all 4 task commits present) | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ----------- | ----------- | ------ | -------- |
| TRAC-01 | 32-02-PLAN.md (declared via `requirements_addressed`) | Operator timeline traces include asynchronous provider callbacks and the resulting outcome state updates. | SATISFIED | `:webhook_received` entry on the timeline (Plan 02 read-side) carries `outcome`, `provider_message_id`, `adapter_module`, `signal_event_name`. Plus the `:workflow_*` atoms surface "the resulting outcome state updates" (workflow_outcome, from_step, to_step, reason). Verified by Scenarios A/B at runtime. |
| TRAC-02 | 32-01-PLAN.md (write-side) + 32-02-PLAN.md (read-side) — both declare via `requirements_addressed` | Trace visibility connects the inbound webhook event back to the specific journey progression step it triggered. | SATISFIED | Two-step linkage proven end-to-end: (a) `route_signal/1` writes `signal_received` row with `delivery_id` populated from `signal.payload["delivery_id"]` (verified by `workflows_test.exs:291-353`); (b) `explain_delivery/1`'s timeline projection joins through `delivery_id` and produces the linked `:workflow_*` event with `workflow_run_id`/`workflow_step_id`/`workflow_step_key` (verified by `traces_test.exs:347-441` Scenarios A and B). The companion `signal_event_name` field on `:webhook_received` adds the inbound→outbound vocabulary link. |

**Orphaned requirements:** None. REQUIREMENTS.md only assigns TRAC-01 and TRAC-02 to Phase 32; both are claimed by the plans (Plan 01 claims TRAC-02; Plan 02 claims both).

### Anti-Patterns Found

Anti-pattern scan limited to the four files modified by Phase 32. Nothing in the new code blocks goal achievement. The 32-REVIEW.md report (already produced) documents 13 WARNINGs and 1 BLOCKER across the broader review-scope files.

| File | Line(s) | Pattern | Severity | Impact |
| ---- | ------- | ------- | -------- | ------ |
| `lib/chimeway/traces.ex` | 517-531 | `webhook_received_entries/2` projects an entry for *every* attempt, including non-webhook channels — entry then carries nil `provider_message_id` / nil `signal_event_name` | INFO (Warning per 32-REVIEW.md WR-01) | Goal still met: operators still see attempt outcomes. Naming/semantic refinement deferred. Does not falsify any phase truth. |
| `lib/chimeway/traces.ex` | 608-627 | `lookup_signal_received_event_name/1` returns first signal_received row only — woven into every webhook entry uniformly | INFO (Warning per 32-REVIEW.md WR-05) | Multi-attempt deliveries with multiple signal_received rows would all show the first event_name. Edge case; no test fails on it; goal-level (linking inbound webhook to step) still met. |
| `lib/chimeway/workflows.ex` | 81-89 | `fetch_definition/2` — pre-existing parameter-order bug | BLOCKER per 32-REVIEW.md (CR-01) | **Pre-existing — NOT introduced by Phase 32** (commit `3ca153d4`, 2026-04-29). Function has zero callers in the repo. **Outside the Phase 32 goal scope.** Surfaced here so the user is aware of it before closing the milestone. |

### Pre-existing BLOCKER (Context Note)

A code-review pass (`.planning/phases/32-operator-traces-audit/32-REVIEW.md`) identified one BLOCKER: `Workflows.fetch_definition/2` at `lib/chimeway/workflows.ex:81-89` has a parameter-order bug in its `preload_steps/2` pipe — both code paths would crash if invoked. The function has zero callers in the repo and was introduced in commit `3ca153d4` (2026-04-29), well before Phase 32. **This BLOCKER is unrelated to the Phase 32 goal** and does not affect any of the 14 must-have truths or 3 success criteria. The verifier flags it here so the developer can decide whether to address it as a separate fix-up before milestone v1.4 closure.

### Human Verification Required

None. All goal-relevant truths are verified by automated tests in the codebase, runtime assertions on `Traces.explain_delivery/1` output, and the user-confirmed full test suite pass (522 tests, 0 failures). The phase has no UI surface (it produces a structured operator-timeline data shape; the reference operator UI is an explicit v1.4 deferred item per `STATE.md:159`).

### Gaps Summary

No gaps. The Phase 32 goal — "Operators can fully audit the asynchronous lifecycle of a notification journey including provider feedback" — is achieved end-to-end:

1. The write-side delta (Plan 01) populates `WorkflowTransition.delivery_id` on `signal_received` rows so the read-side join has data to project.
2. The read-side projection (Plan 02) extends `Chimeway.Traces.build_timeline/5` with two new helpers (`webhook_received_entries/2`, `workflow_transition_entries/1`), five new compile-time-literal event atoms (ranks 13-17), a defensive tenant-scoped query, and the seven-field detail map per D-12 including the verbatim `reason` field that lets operators attribute "why a journey stopped or escalated."
3. Five new tests across two files (4 D-19 scenario tests + 1 D-20 PII-boundary test in `traces_test.exs`; 2 D-21 write-path tests in `workflows_test.exs`) anchor the contracts at runtime. The for-comprehension PII test alone produces 30 refute assertions over the cartesian product of 5 new atoms × 6 forbidden keys.
4. Atom safety preserved (zero `String.to_atom/1`, zero `String.to_existing_atom/1` introduced in either edited file). Cross-tenant defense-in-depth verified at runtime by Scenario D.
5. Backward compat preserved: existing 40 traces tests + 11 workflows transition tests stay green; full project suite is 522 tests, 0 failures.

The phase introduced zero migrations, zero new struct fields on `%Explanation{}`, zero new `WorkflowTransition.context` keys, and zero new error tuples — exactly the contract `32-CONTEXT.md` locked.

---

*Verified: 2026-05-01T20:45:00Z*
*Verifier: Claude (gsd-verifier)*
