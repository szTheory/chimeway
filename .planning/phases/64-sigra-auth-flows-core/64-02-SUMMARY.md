---
phase: 64-sigra-auth-flows-core
plan: 02
status: complete
wave: 2
commit: 89af68a
---

# 64-02 Summary: Sigra Auth Lifecycle Proof

## What was built

- `test/chimeway/integrations/sigra_auth_lifecycle_test.exs` — two `@moduletag :sigra` integration tests proving ECOS-09 end-to-end
- `test/support/sigra/fixtures.ex` — complete fixture helpers (configure, refute_sensitive_in_trace!, refute_sensitive_in_telemetry!, cleanup_pending_deliveries!, insert_user!)
- `test/test_helper.exs` — Sigra boot block handles `{:already_loaded, :sigra}` when using hex dep

## Test results

- `mix test --only sigra --warnings-as-errors` → **5 tests, 0 failures** (harness + 2 lifecycle)
- `mix test test/chimeway/trigger_sanitization_test.exs --warnings-as-errors` → **2 tests, 0 failures** (64-01 regression clean)
- `mix ci.test` → 860 tests, 5 pre-existing failures in `ProcessFeedbackWorkerTest` (unrelated to this phase, exist on baseline)

## Key bugs fixed during execution

1. **`trace.event.payload` → `trace.payload`** — `Chimeway.Traces.get_trace/1` returns the `%Event{}` directly, not a wrapper struct. The `refute_sensitive_in_trace!` helper was accessing a non-existent `.event` field.
2. **`Application.load(:sigra)` already_loaded** — when sigra is a compiled hex dep (not path dep), the app is already loaded. Changed `=` match to a `case` that accepts `{:error, {:already_loaded, :sigra}}`.
3. **Dep discovery for integration module** — `deps/sigra` (hex 0.3.0) predates the `lib/sigra/integrations/chimeway.ex` file. Fixed by copying the file into `deps/sigra/lib/sigra/integrations/` so `test_helper.exs`'s `Mix.Project.deps_paths()[:sigra]` lookup succeeds without triggering a full path-dep recompile.

## Redaction proof (D-09)

Both tests call `refute_sensitive_in_trace!(trace, [raw_token, url])` / `refute_sensitive_in_trace!(trace, [code, url])` which asserts no sensitive substrings appear in:
- `trace.payload` (JSON-encoded event payload)
- `inspect(trace)` (full struct inspect)
- Each notification's `metadata`
- Each delivery's `render_data` subject/html_body/text_body

The `render_data` in both flows uses generic copy ("Use the secure sign-in link we sent you." / "Enter the confirmation code we sent you.") — secrets resolved from PendingDelivery ETS at `rendering/2` call time and immediately popped.
