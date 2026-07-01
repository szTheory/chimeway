---
phase: 75-runtime-prefix-propagation
reviewed: 2026-07-01T20:16:44Z
depth: standard
files_reviewed: 8
files_reviewed_list:
  - lib/chimeway/admin.ex
  - lib/chimeway/dispatch/oban.ex
  - lib/chimeway/repo.ex
  - lib/chimeway/traces.ex
  - lib/chimeway/trigger.ex
  - test/chimeway/repo_prefix_test.exs
  - test/chimeway/runtime_prefix_integration_test.exs
  - test/support/prefixed_runtime_case.ex
findings:
  critical: 1
  warning: 2
  info: 0
  total: 3
status: issues_found
---

# Phase 75: Code Review Report

**Reviewed:** 2026-07-01T20:16:44Z
**Depth:** standard
**Files Reviewed:** 8
**Status:** issues_found

## Summary

Reviewed the scoped runtime prefix source and test files. The focused tests pass, formatting is clean, and compilation with warnings-as-errors succeeds, but the reviewed code still has one sensitive-data persistence bug and two test reliability gaps that can let required prefix behavior regress unnoticed.

Verification run during review:

- `mix test test/chimeway/repo_prefix_test.exs test/chimeway/runtime_prefix_integration_test.exs`
- `mix format --check-formatted lib/chimeway/admin.ex lib/chimeway/dispatch/oban.ex lib/chimeway/repo.ex lib/chimeway/traces.ex lib/chimeway/trigger.ex test/chimeway/repo_prefix_test.exs test/chimeway/runtime_prefix_integration_test.exs test/support/prefixed_runtime_case.ex`
- `mix compile --warnings-as-errors`

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: BLOCKER - Sensitive-Key Scrubbing Is Only Top-Level

**File:** `lib/chimeway/trigger.ex:376`

**Issue:** `sanitize_map/1` removes sensitive keys only from the current map. `event_changeset/4` persists `sanitize_payload(params)` at line 162, and `notifications_attrs/5` persists `sanitize_render_assigns(rendering.assigns)` into notification metadata/render assigns at lines 194 and 203-204. Any nested `%{"token" => ...}`, `%{"password" => ...}`, `%{"secret" => ...}`, or `%{"url" => ...}` survives and is stored durably. This violates the module's own payload sanitization contract and the project rule to avoid leaking sensitive payload fields into storage/operator surfaces.

**Fix:**

```elixir
defp sanitize_map(map) when is_map(map) do
  Enum.reduce(map, %{}, fn {key, value}, acc ->
    if sensitive_key?(key) do
      acc
    else
      Map.put(acc, key, sanitize_value(value))
    end
  end)
end

defp sanitize_map(_not_map), do: %{}

defp sanitize_value(value) when is_map(value), do: sanitize_map(value)
defp sanitize_value(value) when is_list(value), do: Enum.map(value, &sanitize_value/1)
defp sanitize_value(value), do: value
```

Add regression tests with nested sensitive values in trigger params and rendering assigns.

## Warnings

### WR-01: WARNING - Workflow Prefix Test Stops Before Signal Routing Or Progression Executes

**File:** `test/chimeway/runtime_prefix_integration_test.exs:249`

**Issue:** The `runtime_prefix_workflow_signal` test asserts that `Signal.track/4` writes a prefixed signal and enqueues a `SignalRouterWorker`, but it never performs `SignalRouterWorker.perform/1`, `WorkflowProgressionWorker.perform/1`, or `Workflows.Progression.progress_run/2`. A broken worker reload path could still pass the current Phase 75 runtime-prefix gate. This matches the existing verification gap in `75-VERIFICATION.md`.

**Fix:** Extend the test to drive the workflow into a waiting/due state, perform the router/progression worker path, and assert prefixed-only workflow transitions and next-step deliveries. For example:

```elixir
assert :ok = perform_job(Chimeway.Dispatch.SignalRouterWorker, %{"signal_id" => signal.id})
assert_prefixed_only("chimeway_workflow_transitions", :nonzero)

assert :ok =
         perform_job(Chimeway.Dispatch.WorkflowProgressionWorker, %{
           "workflow_run_id" => workflow_run.id
         })
```

### WR-02: WARNING - Prefixed Fixture Readiness Check Can Reuse A Stale Schema

**File:** `test/support/prefixed_runtime_case.ex:135`

**Issue:** `generated_prefixed_schema_ready?/0` treats the `chimeway` schema as ready when only four base tables exist. Phase 75 tests exercise later tables such as workflow runs, signals, digest buckets, memberships, webhook ingress, preferences, and policy settings. A developer or CI database with a stale `chimeway` schema containing the first four tables but missing later tables/columns will skip `drop_generated_prefixed_schema!/0` and fail later with misleading undefined-table/undefined-column errors.

**Fix:** Compare the prefixed schema against the public Chimeway table set, and ideally include column checks for copied tables:

```elixir
defp generated_prefixed_schema_ready? do
  schema_exists?(@runtime_prefix) and
    MapSet.new(chimeway_tables(@runtime_prefix)) == MapSet.new(chimeway_tables("public"))
end
```

---

_Reviewed: 2026-07-01T20:16:44Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
