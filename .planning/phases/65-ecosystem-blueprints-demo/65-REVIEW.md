---
phase: 65-ecosystem-blueprints-demo
reviewed: 2026-05-30T00:00:00Z
depth: standard
files_reviewed: 10
files_reviewed_list:
  - guides/recipes/sigra-auth-blueprint.md
  - test/chimeway/doc_contract_test.exs
  - examples/chimeway_demo_host/test/test_helper.exs
  - examples/chimeway_demo_host/lib/demo_host/seeds.ex
  - examples/chimeway_demo_host/test/demo_host_web/threadline_telemetry_proof_test.exs
  - examples/chimeway_demo_host/test/demo_host_web/sigra_auth_proof_test.exs
  - examples/chimeway_demo_host/test/support/threadline/test_repo.ex
  - examples/chimeway_demo_host/test/support/sigra/test_repo.ex
  - examples/chimeway_demo_host/mix.exs
  - examples/chimeway_demo_host/config/test.exs
findings:
  critical: 2
  warning: 4
  info: 3
  total: 9
status: issues_found
---

# Phase 65: Code Review Report

**Reviewed:** 2026-05-30
**Depth:** standard
**Files Reviewed:** 10
**Status:** issues_found

## Summary

Phase 65 delivers three artifacts: the `sigra-auth-blueprint.md` guide, a new ECOS-10 doc contract test block added to `doc_contract_test.exs`, and the Sigra-specific demo scaffolding (seeds, proof test, test support). The blueprint itself passes all its own doc contract checks cleanly — required strings are present and forbidden strings are absent. The bugs found are concentrated in test reliability (inconsistent `recipient_identity` format in the Sigra seed, env leak in both proof tests) and a latent logic inversion in `stale_drift_patterns` that would misfire if the package ever regresses below 1.0. There are also two documentation-layer issues: a dangling link to a guide that does not yet exist, and a duplicate describe-block label in `doc_contract_test.exs`.

---

## Critical Issues

### CR-01: `seed_sigra_auth/0` returns bare email as `recipient_identity` — inconsistent with stored format

**File:** `examples/chimeway_demo_host/lib/demo_host/seeds.ex:287`

**Issue:** `seed_sigra_auth/0` returns `recipient_identity: @alex_email` (the bare string `"alex@teampulse.test"`). Every other seed in the same file uses `alex_identity()` which produces `"user:alex@teampulse.test"`. The `sigra_auth_proof_test.exs` admin-trace test (`DEMO-10`) uses `result.recipient_identity` both as the trace search query (line 64) and in the HTML assertion (line 69). If the Chimeway delivery row is stored with the `"user:email"` format (which is what `Chimeway.trigger/3` would derive via the notifier's recipient resolution), the search finds nothing and the assertion `assert html =~ result.recipient_identity` trivially passes by matching the raw email string in irrelevant page content — masking a broken trace search.

Even if `MagicLinkNotifier` stores the raw email as the identity, the inconsistency with all other seed helpers makes the intent ambiguous and the test fragile.

**Fix:** Use a consistent format. If the Sigra notifier stores recipient identity as the bare email, document it explicitly. If it stores as `"user:email"`, use `alex_identity()`:

```elixir
# In seed_sigra_auth, replace:
recipient_identity: @alex_email,

# With:
recipient_identity: alex_identity(),
```

If Sigra's notifier intentionally uses a different identity format, introduce a dedicated helper (e.g., `sigra_recipient_identity/1`) and document the difference from TeamPulse app identity.

---

### CR-02: `stale_drift_patterns("0", _minor)` flags future versions as stale — logic inversion

**File:** `test/chimeway/doc_contract_test.exs:1011-1012`

**Issue:** The `stale_drift_patterns/2` clause for major version `"0"` returns `["{:chimeway, \"~> 1.0\"}", "1.0.0", ~s({:chimeway, "~> 1.)]` — patterns that identify version `1.0` as a stale drift. For a package at version `0.x.y`, `"~> 1.0"` is a future version, not a stale one. This is a logic inversion: the test would incorrectly fail consumer docs that reference `"~> 1.0"` when the package is at `0.x`, e.g., in forward-looking migration guides. Currently the project is at `1.0.0` so the `"1", "0"` specialized clause fires and this clause is dormant — but any regression or pre-release below `1.0` would activate the inverted check.

**Fix:**

```elixir
# Replace the "0", _minor clause (line 1011-1012) with:
defp stale_drift_patterns("0", minor) do
  prev_minor = minor |> String.to_integer() |> Kernel.-(1)
  if prev_minor >= 0 do
    ["{:chimeway, \"~> 0.#{prev_minor}\"}", ~s({:chimeway, "~> 0.#{prev_minor})]
  else
    []
  end
end
```

This correctly flags the previous minor version as stale when the package is at `0.x`.

---

## Warnings

### WR-01: `channel_adapter_configs` Application env leaked in both proof tests — no teardown

**File:** `examples/chimeway_demo_host/test/demo_host_web/sigra_auth_proof_test.exs:31-34`
**File:** `examples/chimeway_demo_host/test/demo_host_web/threadline_telemetry_proof_test.exs:40-43`

**Issue:** Both proof tests call `Application.put_env(:chimeway, :channel_adapter_configs, ...)` in `setup` but neither includes cleanup in `on_exit`. Since both tests use `async: false`, each leaves `:chimeway` `:channel_adapter_configs` set to the Logger adapter after the test completes. Any subsequent test in the same run that expects a different adapter configuration (e.g., the `:mailglass` adapter set by the main journey suite) will silently use the Logger adapter instead. This degrades test isolation without a compile or runtime error.

**Fix:** In both test setup blocks, capture and restore the previous value:

```elixir
setup do
  previous_adapter_configs = Application.get_env(:chimeway, :channel_adapter_configs)

  Application.put_env(:chimeway, :channel_adapter_configs, %{
    "email" => {Chimeway.Adapters.Logger, []}
    # ...
  })

  on_exit(fn ->
    if previous_adapter_configs do
      Application.put_env(:chimeway, :channel_adapter_configs, previous_adapter_configs)
    else
      Application.delete_env(:chimeway, :channel_adapter_configs)
    end
    # existing on_exit cleanup...
  end)
end
```

---

### WR-02: `on_exit` in `sigra_auth_proof_test` deletes `:sigra` `:chimeway` env instead of restoring it

**File:** `examples/chimeway_demo_host/test/demo_host_web/sigra_auth_proof_test.exs:37`

**Issue:** `test_helper.exs` sets `Application.put_env(:sigra, :chimeway, enabled: false)` once before all tests run (line 218). The `sigra_auth_proof_test.exs` setup overrides this to `enabled: true`, then `on_exit` calls `Application.delete_env(:sigra, :chimeway)` (line 37) instead of restoring `[enabled: false]`. After this test runs, the `:sigra :chimeway` key is absent from the application env rather than `[enabled: false]`. If any subsequent test or code path reads `Application.get_env(:sigra, :chimeway)` and guards on non-nil presence (rather than `Keyword.get(opts, :enabled, false)`), it will behave differently than if `test_helper.exs` had been the last writer.

**Fix:**

```elixir
# In setup, capture the previous value:
previous_chimeway_env = Application.get_env(:sigra, :chimeway)

# In on_exit, restore rather than delete:
on_exit(fn ->
  Application.put_env(:chimeway, :dispatcher, previous_dispatcher)
  if previous_chimeway_env do
    Application.put_env(:sigra, :chimeway, previous_chimeway_env)
  else
    Application.delete_env(:sigra, :chimeway)
  end
  Application.delete_env(:sigra, :repo)
end)
```

---

### WR-03: `sigra-auth-integration.md` is linked from the blueprint but does not exist

**File:** `guides/recipes/sigra-auth-blueprint.md:107,111`

**Issue:** The blueprint links to `../introduction/sigra-auth-integration.md` in two places (the "Out of scope" note and the "Related guides" section). This file does not exist — the `guides/introduction/` directory contains no `sigra-auth-integration.md`. The ECOS-10 doc contract test only checks that the *string* `"sigra-auth-integration.md"` appears in the blueprint; it does not attempt to open the file. So the contract test passes, but the link is broken for published HexDocs (404) and for any local developer following the blueprint.

The blueprint acknowledges this as Phase 66 DOCS-10 scope, but the link is live in the published recipe now.

**Fix:** Either gate the link behind a Phase 66 note (e.g., `(coming in Phase 66)`), or use a placeholder anchor that cannot resolve to a broken path:

```markdown
- [Sigra auth integration](../introduction/sigra-auth-integration.md) — canonical end-to-end adoption path (Phase 66 DOCS-10 — guide not yet published)
```

Alternatively, add a doc contract test that verifies the file exists when the link is present in the blueprint, so CI catches it on publication.

---

### WR-04: Duplicate `describe` block label `"DOCS-08 / DOCS-09"` in `doc_contract_test.exs`

**File:** `test/chimeway/doc_contract_test.exs:504` and `603`

**Issue:** Two distinct describe blocks use the identical label string `"accrue dunning integration guide doc contract (DOCS-08 / DOCS-09)"` and `"inbox integration guide doc contract (DOCS-08 / DOCS-09)"` — both tagged `DOCS-08 / DOCS-09`. ExUnit uses describe block labels for test output filtering and `--only` flags. While ExUnit will not error or skip tests due to duplicate labels, the duplicate causes ambiguity in `mix test --only "DOCS-08"` selection (both groups run) and makes CI test output harder to triage.

**Fix:** Give the inbox guide block a distinct identifier. Based on context, the inbox contract was likely authored as part of a different phase:

```elixir
# Line 603 — change:
describe "inbox integration guide doc contract (DOCS-08 / DOCS-09)" do

# To:
describe "inbox integration guide doc contract (ECOS-06)" do
```

Use whatever the canonical ticket ID is for the inbox guide contract.

---

## Info

### IN-01: `normalize_trigger_result/1` fallback clause contains redundant `Map.get` call

**File:** `examples/chimeway_demo_host/lib/demo_host/seeds.ex:338-340`

**Issue:** The fallback clause of `normalize_trigger_result/1` is only reached when the result does not have a `:trace` key (the first clause matches `%{trace: _}`). Inside the fallback, `Map.get(result, :trace, %{})` always evaluates to the default `%{}` because `:trace` is known to be absent. The `Map.get` call is dead computation.

**Fix:**

```elixir
defp normalize_trigger_result(result) when is_map(result) do
  Map.put_new(result, :trace, %{})
end
```

---

### IN-02: Inconsistent path resolution strategy in `doc_contract_test.exs`

**File:** `test/chimeway/doc_contract_test.exs:29,100-102,699,769`

**Issue:** Some guide path attributes use bare relative strings (e.g., `"guides/flows/multi-step-journeys.md"`, `"guides/introduction/golden-path.md"`) while others added in later phases use `Path.expand("../../...", __DIR__)`. Bare relative strings are resolved against the process working directory at test runtime, which is typically the project root — so they work, but they are brittle if tests are ever run from a different cwd (e.g., in a nested Mix task or IDE integration). The `Path.expand/2` approach is robust against cwd changes.

**Fix:** Standardize all guide path attributes to use `Path.expand`:

```elixir
# Replace (e.g., line 29):
@journey_guide "guides/flows/multi-step-journeys.md"

# With:
@journey_guide Path.expand("../../guides/flows/multi-step-journeys.md", __DIR__)
```

---

### IN-03: `accrue_test_paths/0` in `mix.exs` has no equivalent for Threadline or Sigra test support

**File:** `examples/chimeway_demo_host/mix.exs:27-33`

**Issue:** The `elixirc_paths(:test)` function appends `accrue_test_paths()` but not equivalent conditionals for Threadline or Sigra test support paths. The comment in `sigra_auth_proof_test.exs` explicitly notes "root test/support not available in demo host elixirc_paths — Pitfall 6" and that support fixtures are inlined as a workaround. This is functional but documents an asymmetry: Accrue has a dedicated support path mechanism while Threadline and Sigra use inline workarounds. If Threadline or Sigra fixture complexity grows, the inline approach becomes hard to maintain.

**Fix:** For now, document the design choice explicitly in `mix.exs`:

```elixir
defp elixirc_paths(:test) do
  # Sigra and Threadline test support is inlined in proof tests (Pitfall 6 — root test/support
  # not on elixirc_paths for demo_host). Accrue support is compiled separately due to migration
  # files; Sigra/Threadline have no such requirement.
  ["lib", "test/support"] ++ accrue_test_paths()
end
```

Alternatively, add `sigra_test_paths/0` and `threadline_test_paths/0` in line with the Accrue pattern when the proof tests grow more complex.

---

_Reviewed: 2026-05-30_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
