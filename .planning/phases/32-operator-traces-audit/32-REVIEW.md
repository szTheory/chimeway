---
phase: 32-operator-traces-audit
review_type: code-review
depth: standard
diff_base: d77e0979268abdc6b52c109299bc9ddc4d3ba8bb^
files_reviewed: 4
status: issues_found
findings:
  critical: 1
  warning: 13
  info: 0
  total: 14
---

# Code Review: Phase 32 — Operator Traces Audit

**Reviewed at:** standard depth
**Files:** `lib/chimeway/traces.ex`, `lib/chimeway/workflows.ex`, `test/chimeway/traces_test.exs`, `test/chimeway/workflows_test.exs`
**Diff base:** `d77e0979268abdc6b52c109299bc9ddc4d3ba8bb^`

## Summary

The Phase 32 implementation adds two reasonable features: (1) `WorkflowTransition.delivery_id` population from incoming signals (Plan 32-01), and (2) read-side projection of `:webhook_received` and `:workflow_*` timeline entries in `Chimeway.Traces.explain_delivery/1` (Plan 32-02). The atom-safety discipline (literal-string→atom dispatch with nil fallback) is correct, the cross-tenant defensive join is in place, and the PII-boundary tests are well-constructed.

However, the review surfaced one BLOCKER (a parameter-order bug in a public function that would crash any caller; **pre-existing — not introduced by Phase 32**), plus several WARNING-class concerns about misleading semantics, dead code paths, and incomplete error handling.

---

## CR-01 (BLOCKER)

### B-01: `Workflows.fetch_definition/2` is broken — both code paths crash

**Pre-existing:** introduced at commit `3ca153d4` (2026-04-29) — Phase 32 did not modify this function, but the file is in review scope.

**File:** `lib/chimeway/workflows.ex:81-89`

```elixir
def fetch_definition(workflow_key, workflow_version)
    when is_binary(workflow_key) and is_integer(workflow_version) do
  {:ok,
   Repo.get_by(WorkflowDefinition,
     workflow_key: workflow_key,
     workflow_version: workflow_version
   )
   |> preload_steps(Repo)}              # <-- bug
end
```

`preload_steps/2` is defined with signature `(repo, definition)` (lines 453-461). The pipe operator passes the `WorkflowDefinition` (or `nil`) result of `Repo.get_by` as the **first** argument to `preload_steps`, with `Repo` as the **second** argument — i.e. it calls `preload_steps(definition_or_nil, Repo)`, which is the **wrong argument order**.

The other call sites use `then/2` to reorder explicitly (lines 61 and 101: `then(&preload_steps(repo, &1))`), which shows the author was aware of the parameter convention. This site missed the wrapper.

Trace through the consequences:
- `preload_steps(_repo, nil)` matches when **second** arg is nil. Here second arg is `Repo` (the module), so this clause does not match.
- Falls through to `preload_steps(repo, definition)` which calls `repo.preload(definition, ..., force: true)`. With the swapped args this becomes `definition_struct.preload(Repo, ..., force: true)` (or `nil.preload(...)` for the not-found case).
- Both forms raise `UndefinedFunctionError` at runtime.

The function currently has zero callers in the repo. But it is `@spec`'d and exported, so the moment someone wires it up it crashes.

**Fix:**
```elixir
def fetch_definition(workflow_key, workflow_version)
    when is_binary(workflow_key) and is_integer(workflow_version) do
  definition =
    Repo.get_by(WorkflowDefinition,
      workflow_key: workflow_key,
      workflow_version: workflow_version
    )

  {:ok, preload_steps(Repo, definition)}
end
```

There is no test exercising `fetch_definition/2` in `workflows_test.exs` — adding one would have caught this. Also note the `@spec` advertises `{:error, term()}` as a possible return, but the function never produces an error tuple — see WR-08.

---

## WARNINGS

### WR-01: `webhook_received_entries/2` produces a `:webhook_received` timeline entry for every attempt, even for non-webhook channels

**File:** `lib/chimeway/traces.ex:517-531`

The function unconditionally maps every attempt to a `:webhook_received` entry. For an `in_app` delivery (no webhook involved), the timeline now contains a `:webhook_received` event whose `provider_message_id` is `nil` and `signal_event_name` is `nil` — semantically misleading, since no webhook was actually received.

The 32-CONTEXT.md design notes say D-06 sources webhook entries from `DeliveryAttempt` rows for "single read path" reasons, but the implementation does not gate on whether a real webhook was received. Concretely, a successful `in_app` delivery in `traces_test.exs:299-344` will now have BOTH `:attempt_recorded` AND `:webhook_received` entries — the test does not refute the latter, so the regression is silent.

**Fix:** Either gate on `attempt.provider_message_id != nil` (or some other "this attempt actually involved an external provider" signal), or rename the atom to `:attempt_outcome_recorded` to reflect that this carries vendor outcome metadata regardless of transport.

### WR-02: `emitted_digest_context/1` produces malformed `rule_identity` when `rule_version` is missing

**File:** `lib/chimeway/traces.ex:806-808` (pre-Phase-32 code in review scope)

If `rule_key` is set but `rule_version` is missing or `nil`, the interpolation produces strings like `"daily_digest:v"` — a malformed identity that downstream consumers will silently accept and display.

**Fix:** Return `nil` when version is missing, or fail loudly via a `case` on `{rule_key, rule_version}`.

### WR-03: `route_signal/1` `{:halt, Repo.rollback(reason)}` builds a tuple that is never observed

**File:** `lib/chimeway/workflows.ex:426-428`

`Repo.rollback/1` performs a non-local return out of the entire `Repo.transaction(fn -> ... end)`. The `{:halt, ...}` tuple is constructed only to be discarded — `Repo.rollback` never returns control to `Enum.reduce_while`. Misleading control flow.

**Fix:** `else {:error, reason} -> Repo.rollback(reason) end`

### WR-04: `route_signal/1` partial-success accumulator is silently discarded on per-run failure

**File:** `lib/chimeway/workflows.ex:403-429`

The reduce_while accumulates per-run results into `acc`. On any single-run failure, `Repo.rollback(reason)` aborts the **entire** transaction. This is the correct atomic semantics, but the function's `@doc` and `@spec` advertise the success shape `{:ok, results_map}` without describing the all-or-nothing failure mode. There is no test for the partial-failure path.

**Fix:** Add a `## Errors` doc section describing all-or-nothing semantics, and add a test that injects a changeset error on the second run and asserts both runs remain in `:waiting`.

### WR-05: `lookup_signal_received_event_name/1` only returns the first signal_received row, but its result is applied to every attempt

**File:** `lib/chimeway/traces.ex:608-627`, used at `412-413`

`lookup_signal_received_event_name` orders by `inserted_at asc` and limits to 1. The single returned `event_name` is then woven into every entry produced by `webhook_received_entries/2`. If a delivery has two attempts and two distinct signal_received transitions (e.g. `delivered` then `bounced`), every webhook entry will report the **first** event name, which is wrong for the second attempt.

**Fix:** Either correlate signals to attempts by timestamp, or accept that webhook entries should not carry `signal_event_name` at all and emit a separate `:signal_received` entry per signal-row.

### WR-06: `route_signal/1` does not validate the type of `signal.payload["delivery_id"]`

**File:** `lib/chimeway/workflows.ex:419` (introduced by Phase 32-01)

```elixir
delivery_id: Map.get(signal.payload, "delivery_id"),
```

If the host app sends `payload: %{"delivery_id" => 123}` (integer) or `%{"delivery_id" => "not-a-uuid"}`, this value is fed straight into `WorkflowTransition.changeset` and the FK insert. The result is either an Ecto cast error or a Postgrex foreign-key error.

`workflows_test.exs:355-372` covers the missing-key case (nil) but no malformed-value case.

**Fix:** Whitelist:
```elixir
delivery_id =
  case Map.get(signal.payload, "delivery_id") do
    id when is_binary(id) -> id
    _ -> nil
  end
```

### WR-07: `metadata_datetime/2` silently drops valid ISO-8601 strings with non-zero UTC offset

**File:** `lib/chimeway/traces.ex:482-487` (pre-existing)

Rejecting non-UTC offsets is defensible policy, but the silent drop means resume timestamps with a non-zero offset appear in the timeline as `nil`.

**Fix:** Either accept the offset and convert to UTC, or document the policy in moduledoc and consider logging at debug level when a parse fails.

### WR-08: `Workflows.fetch_definition/2` `@spec` advertises an `{:error, term()}` return that the function never produces

**File:** `lib/chimeway/workflows.ex:79-89` (pre-existing — pairs with B-01)

The body always returns `{:ok, ...}` (or crashes per CR-01). The error arm is unreachable.

**Fix:** Remove `{:error, term()}` from spec or actually surface errors (e.g. `:not_found` tuple).

### WR-09: `upsert_definition/2` wraps a single Multi step, then computes `DateTime.utc_now()` outside the transaction

**File:** `lib/chimeway/workflows.ex:24-35, 49-55` (pre-existing)

Wrapping a single `Multi.run` adds no value, and the `on_conflict: [set: [updated_at: DateTime.utc_now()]]` keyword list is built at function-call time, not commit time.

### WR-10: `:webhook_received` timeline entries pin `at` to `attempt.inserted_at` but `signal_event_name` comes from a row with a different `inserted_at`

**File:** `lib/chimeway/traces.ex:517-531`

The two timestamps may be seconds or minutes apart depending on signal arrival latency. Operators reading the timeline will assume `signal_event_name` describes what arrived at `at`, which it does not.

**Fix:** Drop `signal_event_name` from the webhook detail (move it to a dedicated `:signal_received` entry), or rename it (e.g. `:correlated_signal_event_name`).

### WR-11: Scenario D test synthesizes an FK state that is impossible in production, limiting its assurance value

**File:** `test/chimeway/traces_test.exs:467-503`

Cross-tenant `delivery_id` reuse is impossible through normal application code paths, so the test is verifying a defense-in-depth filter against a state the rest of the system would never produce.

**Note:** Defense-in-depth is the explicit design goal (D-09, D-17) — the test is correctly framed as a regression guard against future refactors that loosen the filter. Documented in the test's own comment. Acceptable as-is.

### WR-12: Public functions in `Chimeway.Traces` silently pass-through unknown opts to `Repo`

**File:** `lib/chimeway/traces.ex:67-90, 99-104, 115-160, 177-244` (pre-existing)

`Keyword.drop(opts, [:limit, :notification_key])` lets any unknown opt key fall through to `Repo.all(query, repo_opts)`. Typos like `lmit: 5` will silently get forwarded.

**Fix:** Use `Keyword.take(opts, @repo_opt_whitelist)` to whitelist known Repo opts.

### WR-13: WR-05 regression test depends on undocumented changeset internals

**File:** `test/chimeway/traces_test.exs:816-873` (pre-existing)

The test wedges in a shared `inserted_at` via `Ecto.Changeset.put_change` and depends on `DeliveryAttempt.changeset`'s `put_inserted_at/1` helper preserving an explicitly-set value. If `put_inserted_at` is later refactored, this test silently passes for the wrong reason.

**Fix:** Add a sanity assertion that `first.inserted_at == shared_at` (not just `first.inserted_at == second.inserted_at`).

---

## Notes / Out of Scope

- The `lookup_signal_received_event_name/1` query and `workflow_transition_entries/1` query each issue a separate `Repo.one`/`Repo.all` call inside `explain_delivery/1`, on top of the existing `Repo.one` for the delivery preload. That's three round-trips for a single explanation. Performance is out of v1 review scope.
- The five new compile-time atoms in `project_workflow_reason/1` (lines 571-575) are correctly literal-only with no `String.to_atom/1` or `String.to_existing_atom/1`. Atom safety gate (T-32-T2 / D-16) is met.
- The PII-boundary test (lines 506-568) is well-constructed and the for-comprehension defense ("every new atom appears in this fixture") guards against the for-comprehension being vacuously true. Good test discipline.

---

## Phase-32-introduced findings

Of the 14 findings above, only the following are NEW in Phase 32:

- **WR-01** — `webhook_received_entries/2` over-emits for non-webhook channels (Plan 32-02)
- **WR-04** — `route_signal/1` partial-failure semantics undocumented and untested (Plan 32-01 added the `delivery_id` attrs key but did not change the reduce_while)
- **WR-05** — `signal_event_name` smearing across attempts (Plan 32-02)
- **WR-06** — `route_signal/1` does not type-validate `delivery_id` (Plan 32-01)
- **WR-10** — `signal_event_name` timestamp mismatch with `at` (Plan 32-02)

The remainder (CR-01 / B-01, WR-02, WR-03, WR-07, WR-08, WR-09, WR-12, WR-13) are pre-existing and were surfaced because the files are in review scope. The user can choose whether to address them under Phase 32 gap closure or defer to a separate fix-up phase.
