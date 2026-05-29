---
phase: 57-docs-release-gates
name: docs-release-gates
status: issues
reviewed_at: 2026-05-29
depth: standard
files_reviewed: 8
files_reviewed_list:
  - guides/introduction/mailglass-integration.md
  - guides/recipes/mailglass-integration-blueprint.md
  - guides/recipes/custom-adapter.md
  - mix.exs
  - README.md
  - .github/workflows/ci.yml
  - MAINTAINING.md
  - test/chimeway/doc_contract_test.exs
findings:
  critical: 0
  warning: 3
  info: 3
  total: 6
---

# Phase 57 Code Review

**Reviewed:** 2026-05-29  
**Depth:** standard  
**Scope:** Plans 57-01 (DOCS-06 guide), 57-02 (DOCS-07 doc-contract), 57-03 (GATE-04 verify gate)  
**Status:** issues

## Summary

Phase 57 closes the v1.8 docs-release-gates milestone coherently: a canonical Mailglass adoption guide, DOCS-07 doc-contract locking, GATE-04 `mix verify.mailglass` with fast `ci.test` exclusion, a dedicated CI job, and MAINTAINING pre-ship sextet. Cross-links, HexDocs extras, and blueprint/custom-adapter/README discoverability align with prior phase patterns.

No critical runtime bugs, CI misconfigurations, or security regressions in the changed Elixir/CI files. One **warning** in the new integration guide's optional webhook section documents an incorrect `Chimeway.Webhooks.process/4` call shape that would fail at runtime if copied verbatim — the highest-impact finding in this phase.

**Positive observations:**

- Guide sections follow D-03 order; responsibility split (orchestration vs templating) and product-name vs module split are consistent across guide, blueprint, and custom-adapter.
- DOCS-07 describe reuses `@recipe_forbidden_strings`, `Chimeway.Workflow` regex, and explicit `Chimeway.Adapters.Mailglass` assertion — parallel to ECOS-05 and sibling recipe contracts.
- `mix verify.mailglass` two-step alias (root `--only mailglass` + demo host DEMO-06) matches plan 57-03; default `mix ci` unchanged per D-14.
- `verify_mailglass` CI job mirrors `verify_journeys` (Postgres service, ecto create/migrate, OTP 27).
- Blueprint out-of-scope defers end-to-end path to the introduction guide without duplication; reciprocal cross-links are correct.

**Verification:**

```bash
mix ci.verify_gates
# 152 tests, 0 failures

mix verify.mailglass
# 16 root + 2 demo mailglass tests, 0 failures
```

---

## Critical Issues

None.

---

## Warnings

### WR-01: Mailglass guide webhook example uses wrong `Webhooks.process/4` signature

**Files:** `guides/introduction/mailglass-integration.md:173-189`, `lib/chimeway/webhooks.ex:28`, `examples/chimeway_demo_host/lib/demo_host_web/controllers/webhooks_controller.ex:36`

**Issue:** Section 6 documents:

```elixir
Chimeway.Webhooks.process("mailglass", conn.params, raw_body, headers: headers)
```

with `headers = Map.new(conn.req_headers)`.

The actual API is `process(adapter_module, raw_body, headers, config)` where `adapter_module` is a module (e.g. `Chimeway.Adapters.Mailglass`), `headers` must be a **list** (see `verify_webhook/3` guard `is_list(headers)` in `mailglass.ex:255`), and the fourth argument is a config keyword list — not `headers:` as an option. The reference demo host passes `conn.req_headers` directly and resolves the adapter module from route params.

**Impact:** Adopters implementing inbound feedback from this section will hit `FunctionClauseError` / `UndefinedFunctionError` at runtime. DOCS-07 passes because it only requires the substring `Chimeway.Webhooks.process`, not a correct call shape.

**Fix:** Replace the example with the demo-host pattern (adapter module, flattened raw body, header list, webhook config keyword), e.g.:

```elixir
adapter_module = Chimeway.Adapters.Mailglass
config = Application.get_env(:my_app, :chimeway_webhook_config, [])

case Chimeway.Webhooks.process(adapter_module, raw_body, conn.req_headers, config) do
```

Cross-link `DemoHostWeb.WebhooksController` or `feedback-escalation-workflow.md` for status-code mapping.

---

### WR-02: Webhook example returns `inspect(reason)` to callers

**File:** `guides/introduction/mailglass-integration.md:187-188`

**Issue:** Error branch uses `send_resp(conn, 422, inspect(reason))`, exposing internal error tuples/atoms to the webhook provider.

**Impact:** Information disclosure on ingress failures; inconsistent with demo host, which returns generic `"Internal Server Error"` for non-`:unauthorized` errors (`webhooks_controller.ex:43-47`) and `:unauthorized` → 401.

**Fix:** Return fixed status bodies (401 for `:unauthorized`, 422/500 with constant string otherwise); log `reason` server-side only.

---

### WR-03: MAINTAINING.md still describes `mix ci` as "full test suite"

**Files:** `MAINTAINING.md:34`, `mix.exs:59-60`

**Issue:** Pre-ship bullet says `mix ci` is "lint + full test suite", but `ci.test` now runs `--exclude mailglass`. Mailglass proof requires the sixth gate (`mix verify.mailglass`).

**Impact:** Maintainers relying on the `mix ci` bullet alone may think mailglass coverage is included in step 3's first command. The sextet list below is correct; the per-command description is stale.

**Fix:** Change the `mix ci` bullet to "lint + core test suite (mailglass excluded — run `mix verify.mailglass` separately)" or similar.

---

## Info

### IN-01: DOCS-07 does not lock webhook call shape

**File:** `test/chimeway/doc_contract_test.exs:319-332`

**Issue:** Required phrases include `Chimeway.Webhooks.process` as a substring only. A future edit could regress WR-01's wrong call shape without failing CI.

**Fix:** Add a required phrase such as `Chimeway.Adapters.Mailglass` adjacent to webhook section context, or a dedicated test asserting `Webhooks.process(Chimeway.Adapters.Mailglass` (or regex for `process(module(),` pattern).

---

### IN-02: Webhook example omits raw-body iolist flattening

**Files:** `guides/introduction/mailglass-integration.md:175`, `examples/chimeway_demo_host/lib/demo_host_web/controllers/webhooks_controller.ex:26-30`

**Issue:** Example uses `conn.assigns[:raw_body] || ""` without the Pitfall 4 / T-33-RAWBODY iolist reverse + `IO.iodata_to_binary/1` pattern documented in the reference controller.

**Impact:** Hosts with chunked body readers may pass invalid input to HMAC verification. Lower severity than WR-01 because section is optional and cross-links exist.

**Fix:** Add a one-line note pointing to body-reader setup or mirror the demo flattening snippet.

---

### IN-03: `ci.verify_gates` has no dedicated CI job (by design)

**Files:** `mix.exs:87-89`, `.github/workflows/ci.yml`, `.github/workflows/docs.yml`

**Issue:** GATE-01 doc-contract runs via the main `test` job's `mix ci.test` (152 tests in `doc_contract_test.exs`); `mix ci.docs` runs in the separate `docs.yml` workflow on push to main only — not on PRs.

**Impact:** PRs get doc-contract coverage through `ci.test`; docs warnings-as-errors gate is push-to-main only. Matches Phase 41/42 precedent, not a regression from Phase 57.

---

## Security & Doc Accuracy Assessment

| Area | Verdict |
|------|---------|
| Webhook ingress API accuracy | **Fail** — WR-01 wrong signature in adoption guide |
| Webhook error response leakage | **Warn** — WR-02 `inspect(reason)` in example |
| Trigger/idempotency/tenant docs | Pass — examples include required keys; `:missing_tenant_id` documented |
| Adapter module naming (D-07) | Pass — product vs module split in guide, blueprint, custom-adapter |
| CI mailglass isolation | Pass — `--exclude mailglass` in `ci.test`; dedicated `verify_mailglass` job |
| Doc-contract regression guards | Pass — DOCS-07 + ECOS-05 phrases; gap on webhook call shape (IN-01) |
| MAINTAINING pre-ship sextet | Pass — six commands listed; WR-03 stale `mix ci` description |

---

## Recommended Follow-ups

1. Fix webhook section in `mailglass-integration.md` to match `Webhooks.process/4` and demo host status mapping (WR-01, WR-02).
2. Update MAINTAINING.md `mix ci` description for mailglass exclusion (WR-03).
3. Extend DOCS-07 contract to guard webhook call shape (IN-01).
4. Optional: add raw-body flattening note in webhook section (IN-02).

---

## Verdict

Advisory review — no blocking code defects in `mix.exs`, CI, or doc-contract tests. **Fix WR-01 before treating the Mailglass integration guide as production-ready for inbound webhook wiring**; other findings are minor doc/runbook polish.
