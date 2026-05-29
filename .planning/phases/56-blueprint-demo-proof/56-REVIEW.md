---
phase: 56-blueprint-demo-proof
name: blueprint-demo-proof
status: issues
reviewed_at: 2026-05-29
depth: standard
files_reviewed: 10
files_reviewed_list:
  - examples/chimeway_demo_host/lib/demo_host/mailers/invite_email.ex
  - examples/chimeway_demo_host/test/demo_host_web/mailglass_delivery_proof_test.exs
  - examples/chimeway_demo_host/test/support/mailglass/test_repo.ex
  - examples/chimeway_demo_host/mix.exs
  - examples/chimeway_demo_host/config/test.exs
  - examples/chimeway_demo_host/test/test_helper.exs
  - chimeway_admin/lib/chimeway_admin/redaction.ex
  - guides/recipes/mailglass-integration-blueprint.md
  - guides/recipes/custom-adapter.md
  - test/chimeway/doc_contract_test.exs
findings:
  critical: 0
  warning: 3
  info: 3
  total: 6
---

# Phase 56 Code Review

**Reviewed:** 2026-05-29  
**Depth:** standard  
**Scope:** Plans 56-01 (DEMO-06 demo proof) and 56-02 (ECOS-05 blueprint + doc-contract)  
**Status:** issues

## Summary

Phase 56 delivers a coherent Mailglass adoption slice: demo host mailable + isolated `:mailglass` proof tests, admin timeline visibility for `adapter_module`, and an ECOS-05 blueprint with CI doc-contract locking. Journey isolation (D-10) is correctly preserved — `mix verify.journeys` uses `--only journey` while Mailglass proofs run under `--only mailglass`.

No critical bugs, security regressions, or tenancy/PII leaks found. Three **warnings** remain around doc-contract completeness, redaction test coverage for the new whitelist key, and a demo mailable fallback that could mislead copy-paste adopters.

**Positive observations:**

- Per-test `Application.put_env` for `:channel_adapters` / `:channel_adapter_configs` with `on_exit` restore — correct journey isolation pattern (D-10).
- `MailglassDeliveryProofTest` asserts delivery attempt `adapter_module` contains `Chimeway.Adapters.Mailglass` and admin detail excludes raw email + HTML body.
- `InviteEmail` reads string-keyed render_data consistent with `Chimeway.Rendering.Channels.Email` validation.
- Demo host `Mailglass.TestRepo` shim mirrors root pattern; distinct DB name prevents collision with root mailglass test DB.
- Blueprint clearly documents product name vs module split and defers Phase 57 scope (D-17).
- ECOS-05 doc-contract reuses `@recipe_forbidden_strings` and `Chimeway.Workflow` regex gate like sibling recipes.

**Verification:**

```bash
cd examples/chimeway_demo_host && mix test --only mailglass --warnings-as-errors
# 2 tests, 0 failures

MIX_ENV=test mix test test/chimeway/doc_contract_test.exs --warnings-as-errors
# 132 tests, 0 failures
```

---

## Critical Issues

None.

---

## Warnings

### WR-01: ECOS-05 doc-contract omits trigger/idempotency phrases

**Files:** `test/chimeway/doc_contract_test.exs:267-279`, `guides/recipes/mailglass-integration-blueprint.md:99-107`

**Issue:** The ECOS-05 `@required` list locks adapter config and responsibility-split language but does not require `Chimeway.trigger`, `idempotency_key`, or `tenant_id` — all present in the blueprint trigger section and required by the prose ("Both `:idempotency_key` and `:tenant_id` are required."). Sibling recipe contracts (RECP-01/02) lock `Chimeway.trigger`.

**Impact:** A future edit could remove the trigger example or idempotency requirements without failing CI, weakening the adoption blueprint.

**Fix:** Add `Chimeway.trigger`, `idempotency_key`, and `tenant_id` to the ECOS-05 `@required` list (or a dedicated `@required_phrases` block if substring matching is preferred for multi-word requirements).

---

### WR-02: `adapter_module` redaction whitelist lacks unit test

**Files:** `chimeway_admin/lib/chimeway_admin/redaction.ex:6-8`, `chimeway_admin/test/chimeway_admin/redaction_test.exs`

**Issue:** Plan 56-01 added `adapter_module` to `@allowed_detail_keys` so operator traces show the Mailglass adapter. `redaction_test.exs` covers `safe_timeline_detail/1` for sensitive key dropping but has no test asserting `adapter_module` passes through while e.g. `password` is still dropped.

**Impact:** A future refactor could remove `adapter_module` from the whitelist and break DEMO-06 admin inspectability; only the demo host integration test would catch it.

**Fix:** Add a focused unit test:

```elixir
detail = %{"adapter_module" => "Elixir.Chimeway.Adapters.Mailglass", "password" => "secret"}
assert Redaction.safe_timeline_detail(detail) == %{"adapter_module" => "Elixir.Chimeway.Adapters.Mailglass"}
```

---

### WR-03: InviteEmail silently falls back to demo seed recipient

**File:** `examples/chimeway_demo_host/lib/demo_host/mailers/invite_email.ex:18-19`

**Issue:** When `"to"` / `:to` is absent from assigns, `invite_email/1` falls back to `DemoHost.Seeds.alex_email()` instead of failing. The Mailglass adapter normally merges `"to"` from delivery render_data, so this path should be unreachable in the happy path — but copy-paste adopters may reuse the module and miss misconfigured recipient resolution.

**Impact:** Misconfigured hosts could send to a hardcoded demo address without an obvious error.

**Fix:** Document the fallback as demo-only in moduledoc (partially done) and consider `raise` or `{:error, :missing_recipient}` when `Mix.env() != :test` / outside demo host, or remove the fallback and rely on adapter-injected `"to"`.

---

## Info

### IN-01: Admin trace assertion allows loose "Mailglass" substring match

**File:** `examples/chimeway_demo_host/test/demo_host_web/mailglass_delivery_proof_test.exs:117`

**Issue:** `assert detail =~ "Chimeway.Adapters.Mailglass" or detail =~ "Mailglass"` could pass on incidental page copy. The delivery test already asserts `adapter_module` on the attempt row.

**Fix:** Tighten to `assert detail =~ "Chimeway.Adapters.Mailglass"` or assert rendered timeline contains `adapter_module` dt/dd pair.

---

### IN-02: Demo host test_helper always boots Mailglass infrastructure

**File:** `examples/chimeway_demo_host/test/test_helper.exs:13-42`

**Issue:** Mailglass DB create/migrate/start runs for every demo host test invocation (including `--only journey`), adding startup cost even when no Mailglass test runs. Acceptable given mailglass is now a required demo host dep; Phase 57 `mix verify.mailglass` may formalize selective runs.

---

### IN-03: Duplicate `Mailglass.TestRepo` shim in demo host

**Files:** `examples/chimeway_demo_host/test/support/mailglass/test_repo.ex`, `test/support/mailglass/test_repo.ex`

**Issue:** Identical conditional shim duplicated per D-09/D-11. Low maintenance risk today; any TestRepo otp_app change needs dual updates.

---

## Security & PII Assessment

| Area | Verdict |
|------|---------|
| Admin trace PII redaction (email, html_body) | Pass — proof test refutes raw values in detail |
| `adapter_module` in timeline detail | Pass — module string, whitelisted, not sensitive |
| Per-test adapter env isolation | Pass — `on_exit` restores previous config |
| Journey suite Logger adapter default | Pass — `mix verify.journeys` uses `--only journey` |
| Blueprint trigger example | Pass — demo email only, no secrets |
| Doc-contract forbidden strings | Pass — shared `@recipe_forbidden_strings` applied |

---

## Recommended Follow-ups

1. Extend ECOS-05 doc-contract required phrases (WR-01).
2. Add `adapter_module` unit test to `redaction_test.exs` (WR-02).
3. Harden or document InviteEmail recipient fallback for adopters (WR-03).
4. Phase 57: wire `mix verify.mailglass` and optional `--exclude mailglass` for root CI (deferred per D-17).

---

## Verdict

No blocking issues. Phase 56 is merge-ready with minor doc-contract and test-coverage gaps to address in Phase 57 or a quick follow-up pass.
