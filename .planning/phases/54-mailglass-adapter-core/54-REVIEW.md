---
phase: 54-mailglass-adapter-core
name: mailglass-adapter-core
status: issues
reviewed_at: 2026-05-29
depth: standard
diff_base: 3e93b00^
files_reviewed: 16
files_reviewed_list:
  - lib/chimeway/adapters/mailglass.ex
  - test/chimeway/adapters/mailglass_adapter_test.exs
  - test/chimeway/dispatch/executor_mailglass_adapter_test.exs
  - test/support/chimeway/mailglass_fixtures.ex
  - test/support/mailglass/test_repo.ex
  - test/support/mailglass/data_case.ex
  - test/support/mailglass/migrations/00000000000001_mailglass_init.exs
  - test/support/mailglass/migrations/00000000000002_add_idempotency_key_to_deliveries.exs
  - test/support/mailglass/migrations/00000000000003_mailglass_webhook_events.exs
  - test/support/mailglass/migrations/00000000000004_mailglass_v03.exs
  - test/support/mailglass/migrations/00000000000005_mailglass_v04.exs
  - test/support/chimeway/adapter/contract_test.ex
  - config/test.exs
  - test/test_helper.exs
  - mix.exs
  - guides/recipes/custom-adapter.md
findings:
  critical: 0
  warning: 4
  info: 4
  total: 8
---

# Phase 54 Code Review

**Reviewed:** 2026-05-29  
**Depth:** standard  
**Diff base:** `3e93b00^` (first phase 54 commit)  
**Status:** issues

## Summary

Phase 54 delivers a solid Mailglass adapter core: optional dependency packaging with `Code.ensure_loaded?/1` gating, runtime `:mailables` resolution, tenancy stamping via `Mailglass.Tenancy.with_tenant/2`, compact error details, success-meta redaction, shared `Chimeway.Adapter.ContractTest` coverage, and executor per-channel routing proof. All 9 Mailglass-tagged tests pass locally.

No critical security or tenancy bypass issues found. Several **warnings** remain around production-safe test hooks, incomplete redaction assertions on the executor path, optional-dep compile parity in test config, and test/doc drift on the full D-15 classification table.

**Positive observations:**

- Adapter reads config at call time (`resolve_mailables/1`, `outbound_opts`) — no compile-time secrets (D-10).
- Missing or blank `tenant_id` returns `{:error, :permanent, %{reason: :missing_tenant_id}}` before outbound call (D-11).
- Success meta is built from a fixed allowlist (`adapter`, `mailglass_delivery_id`, `provider_message_id`, `status`) and passed through `redact_meta/1`.
- Error `detail` maps are compact (`type`, `module` only) — no Mailglass context blobs or provider bodies persisted.
- `Chimeway.Adapter.ContractTest` error-shape test passes `simulate_error: true` when `simulate_error?/0` is true (54-03 macro fix).
- Hex migration shim + TestRepo/DataCase shims enable integration tests against published mailglass artifact.

**Verification:** `mix test test/chimeway/adapters/mailglass_adapter_test.exs test/chimeway/dispatch/executor_mailglass_adapter_test.exs --warnings-as-errors` — 9 tests, 0 failures.

---

## Critical Issues

None.

---

## Warnings

### WR-01: `simulate_error` hooks active in all Mix environments

**File:** `lib/chimeway/adapters/mailglass.ex:40-50, 83-91`

**Issue:** `deliver/2` short-circuits to simulated failures when `config[:simulate_error]` is set, and `merge_simulate_error_config/1` merges `:simulate_mailglass_error` from `Application.get_env(:chimeway, ...)` at runtime in every environment. A host that accidentally leaves test config in production (or sets the Application env globally) would bypass real Mailglass delivery for all email attempts.

**Impact:** Operational misconfiguration could silently prevent outbound email while still recording attempts (via simulate path or mis-set Application env).

**Fix:** Gate simulate branches behind `Mix.env() == :test`, or strip `:simulate_error` / ignore `:simulate_mailglass_error` outside `:test`. Document in `custom-adapter.md` that simulate flags are test-only.

---

### WR-02: Executor test does not assert provider_response redaction

**File:** `test/chimeway/dispatch/executor_mailglass_adapter_test.exs:58-83`

**Issue:** ECOS-02 requires redacted provider metadata on success. The test asserts `provider_response` contains `adapter: "mailglass"` but does not assert absence of sensitive keys (`:password`, `:token`, `:secret`, `:api_key`, `:auth`) on the persisted attempt row — the path that actually writes to `chimeway_delivery_attempts.provider_response`.

**Fix:** After `run_delivery/1`, assert `provider_response` has no sensitive keys (reuse the same key list as `Chimeway.Adapter.ContractTest` or call a shared helper).

---

### WR-03: Test config breaks optional-dep compile parity (D-06)

**Files:** `config/test.exs:29-50`, `test/test_helper.exs:4-33`

**Issue:** Core lib correctly gates the adapter module with `Code.ensure_loaded?(Mailglass)`, but `config/test.exs` unconditionally references `Mailglass.Adapters.Fake`, `Mailglass.TestRepo`, etc. `MIX_ENV=test mix compile` fails when the optional mailglass dep is not fetched — contradicting D-06 “Chimeway MUST compile cleanly when Mailglass is not installed.” Tests define `@moduletag :mailglass` for selective CI, but no `--exclude mailglass` wiring exists yet (deferred to Phase 57 `mix verify.mailglass`).

**Fix:** Wrap Mailglass config in `if Code.ensure_loaded?(Mailglass)` (accepting the 54-01 config-load caveat) or document that mailglass is a required dev/test dep for Chimeway maintainers until GATE-04 lands.

---

### WR-04: D-15 classification table documented but not fully tested

**Files:** `test/chimeway/adapters/mailglass_adapter_test.exs:6-17, 69-106`, `lib/chimeway/adapters/mailglass.ex:172-206`

**Issue:** Moduledoc table lists seven Mailglass error types plus simulate_error. Tests cover three paths (simulate → `:temporary`, SuppressedError → `:bounced`, TemplateError → `:permanent`). Untested classifiers: `RateLimitError`, retryable/non-retryable `SendError`, `ConfigError`, `TenancyError`, and the catch-all unknown struct branch. Plan 54-03 required one example per Chimeway class (met), but the documented matrix overstates coverage.

**Fix:** Add `classify_error_for_test/1` assertions for remaining error structs, or narrow the moduledoc table to “representative examples” until full matrix tests land.

---

## Info

### IN-01: Input validation permanent errors lack dedicated tests

**File:** `lib/chimeway/adapters/mailglass.ex:93-98, 100-112, 133-136`

**Issue:** `missing_tenant_id`, `missing_recipient`, and `unknown_render_key` permanent paths are implemented but not covered by focused tests.

**Fix:** Add three small unit tests (no DB required for validation-only paths).

---

### IN-02: Contract test checks sensitive keys on success meta only

**File:** `test/support/chimeway/adapter/contract_test.ex:92-101`

**Issue:** Error-shape contract test asserts `is_map(detail)` but does not run `__contract_check_no_sensitive_keys!/1` on error detail. Mailglass classification tests manually refute `:token`/`:api_key` on some paths; macro does not enforce this for all adapters.

**Fix:** Optional enhancement — extend macro to redact-check error detail maps.

---

### IN-03: `redact_meta/1` strips sensitive keys one nesting level

**File:** `lib/chimeway/adapters/mailglass.ex:217-224`

**Issue:** Nested maps deeper than one level could retain sensitive keys. Matches 54-02 plan (“recursively one level”) and current meta shape is flat — low risk today.

---

### IN-04: Generic custom-adapter recipe shows invalid ContractTest usage

**File:** `guides/recipes/custom-adapter.md:68-72`

**Issue:** Pre-existing generic example uses `use Chimeway.Adapter.ContractTest, adapter: MyApp.MyCustomAdapter` — the macro requires `adapter_module/0` and `sample_delivery/0` callbacks, not an `:adapter` option. Mailglass section added in 54-03 is correct.

**Fix:** Correct generic example in a follow-up doc pass (Phase 57 doc-truth scope).

---

## Adapter Contract & Tenancy Assessment

| Area | Verdict |
|------|---------|
| Return shapes (`{:ok, meta}` / `{:error, class, detail}`) | Pass |
| Error classes (`:temporary`, `:permanent`, `:bounced`) | Pass |
| Runtime config (no compile-time secrets) | Pass |
| Tenancy stamp before Outbound | Pass |
| Success meta redaction | Pass (adapter); executor test gap (WR-02) |
| Error detail compactness | Pass |
| Optional dep gating (lib) | Pass |
| Optional dep gating (test config) | Partial (WR-03) |

---

## Recommended Follow-ups

1. Gate or document simulate_error paths (WR-01) before Phase 55 webhook work ships to hosts.
2. Add provider_response redaction assertion to executor test (WR-02).
3. Align D-15 docs vs tests (WR-04) — either expand tests or narrow moduledoc.
4. Wire `@moduletag :mailglass` exclude path in Phase 57 GATE-04 CI entrypoint (WR-03).
