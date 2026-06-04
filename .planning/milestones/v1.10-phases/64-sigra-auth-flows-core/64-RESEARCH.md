# Phase 64: Sigra Auth Flows Core — Research

**Researched:** 2026-05-30  
**Phase:** 64-sigra-auth-flows-core  
**Requirement:** ECOS-09  
**Status:** Ready for planning

---

## 1. Executive Summary

Phase 64 delivers a **Sigra → Chimeway trigger bridge** for two auth notification flows: **magic link** and **email confirmation code** (standing in for ECOS-09 “MFA token dispatch” until Sigra ships outbound MFA OTP) [CITED: 64-CONTEXT.md D-01, D-05]. There is **zero Chimeway reference to Sigra today** and **zero Sigra reference to Chimeway** [VERIFIED: grep `chimeway` in `../sigra` → no matches].

Cross-repo ownership mirrors Accrue Phase 58 [CITED: D-02]: **`Sigra.Integrations.Chimeway`** (Sigra repo, `Code.ensure_loaded?(Chimeway)` guard) + Chimeway-side notifiers, redaction hardening, optional `{:sigra, …}` dep, and `@moduletag :sigra` lifecycle tests [CITED: D-10, D-11].

**Two gaps block a correct end-to-end design:**

1. **`@sensitive_keys` too narrow** — `password`, `token`, `secret` only; `url`, `code`, `raw_token`, `magic_link_url` pass through `sanitize_payload/1` and `sanitize_render_assigns/1` today [VERIFIED: `lib/chimeway/trigger.ex` L36, L354–368].
2. **Secret reconstruction at render time** — Sigra persists **hashed** tokens only (`request_magic_link/3` inserts hashed token; confirmation stores hashed code) [VERIFIED: `../sigra/lib/sigra/auth.ex` L639–677, L808–833]. Chimeway trigger params must stay identifier-only [CITED: D-07], so notifiers need a **Sigra-owned ephemeral resolution** (pending-delivery cache keyed by `idempotency_key`, or sync-only dispatch) — raw URL/code cannot be re-derived from DB alone [ASSUMED: planner must lock pattern in 64-02].

**Install-template gap:** Generated `session_controller.ex` calls `Auth.request_magic_link/2` but **never sends email** [VERIFIED: `../sigra/priv/templates/sigra.install/core/session_controller.ex` L37–48]. Confirmation path **does** call `Sigra.Delivery.deliver/3` with `token`, `code`, `url` in job args [VERIFIED: `../sigra/priv/templates/sigra.install/core/auth.ex` L368–376; `../sigra/lib/sigra/delivery.ex` L68–74].

**Planner takeaway:** Split into **Wave 64-01 (harness + `@sensitive_keys` + CI exclude)** and **Wave 64-02 (`Sigra.Integrations.Chimeway` + notifiers + redaction lifecycle tests)** mirroring Accrue 58-01/58-02 and Threadline 63-01/63-02 [CITED: 63-RESEARCH.md §6; 58-CONTEXT vertical-slice precedent].

---

## 2. Standard Stack

| Layer | Choice | Notes |
|-------|--------|-------|
| Language | Elixir ~> 1.17 (Chimeway), ~> 1.18 (Sigra) | Chimeway `mix.exs`; Sigra `@version "0.3.0"` [VERIFIED: `../sigra/mix.exs` L4, L10] |
| Persistence | Ecto 3.x + PostgreSQL 15+ | Chimeway `Repo` + Sigra harness `Sigra.TestRepo` [ASSUMED: mirror Accrue.TestRepo] |
| Auth library | Sigra ~> 0.3 (optional path dep) | Pin TBD; local `SIGRA_PATH=../sigra` [CITED: D-10; Accrue `ACCRUE_PATH` pattern] |
| Notification spine | Chimeway `Trigger` + `Notifier` + `Traces` | No new `Chimeway.Adapter` seam [CITED: D-01] |
| Test delivery | `Chimeway.Adapters.Logger` | Accrue/Threadline harness pattern [VERIFIED: `test/support/accrue/fixtures.ex` L27–32] |
| Selective CI | `@moduletag :sigra`, `--exclude sigra` on `ci.test` | `mix verify.sigra` deferred Phase 66 [CITED: D-12, D-13] |

**OTP patterns:**

- **Optional ecosystem dep:** `{:sigra, optional: true, runtime: false}` + `SIGRA_PATH` override [CITED: D-10].
- **Conditional compile (Sigra):** entire `Sigra.Integrations.Chimeway` `defmodule` wrapped in `if Code.ensure_loaded?(Chimeway)` [VERIFIED: `../accrue/accrue/lib/accrue/integrations/chimeway.ex` L33–34].
- **Chimeway compile shim:** if integration not in hex Sigra build, `test_helper.exs` may `Code.compile_file/1` from `SIGRA_PATH` (Accrue precedent) [VERIFIED: `test/test_helper.exs` L36–49].
- **Cross-repo trigger:** Sigra integration calls `Chimeway.trigger/3` with `idempotency_key` + `tenant_id` (user id) [CITED: D-03, D-06].

---

## 3. Architecture Patterns

### 3.1 Outcome flow: Sigra auth event → Chimeway delivery → explainable trace

```
Sigra.Auth.request_magic_link/3  (or confirmation token generation + host deliver hook)
  → Sigra.Integrations.Chimeway.dispatch_* (identifier-only trigger params)
  → Chimeway.trigger(Sigra.Integrations.Chimeway.MagicLinkNotifier | ConfirmationCodeNotifier, params, opts)
  → chimeway_events.payload (sanitized) + notifications.metadata/render_assigns (sanitized)
  → policy → dispatch (Sync in tests) → attempt → Traces.get_trace/1
```

[CITED: D-01, D-03, D-06] [VERIFIED: `lib/chimeway/trigger.ex` trigger spine]

### 3.2 Accrue precedent (integration module shape)

```elixir
if Code.ensure_loaded?(Chimeway) do
  defmodule Sigra.Integrations.Chimeway do
    @compile {:no_warn_undefined, [Chimeway]}

    def dispatch_magic_link(repo, user, opts) do
      # Build idempotency_key, set pending URL in Sigra-owned store, trigger notifier
    end

    defmodule MagicLinkNotifier do
      @behaviour Chimeway.Notifier
      def notification_key, do: "sigra.auth.magic_link"
      def version, do: 1
      # recipients/1, build/2, rendering/2 — resolve URL via pending store / config callback
    end
  end
end
```

[VERIFIED: Accrue nested `DunningNotifier` in `../accrue/accrue/lib/accrue/integrations/chimeway.ex` L116–212]

### 3.3 Magic link hook point

| Step | Location | Behavior |
|------|----------|----------|
| Token generation + DB insert | `Sigra.Auth.request_magic_link/3` | Returns `{:ok, {raw_token, url}}` on success; `{:ok, :sent}` if user nil; `{:error, :rate_limited}` [VERIFIED: L616–677] |
| Install template | `session_controller.ex` | Calls host `Auth.request_magic_link/2`; **no delivery** [VERIFIED: L37–48] |
| Phase 64 integration | After `{:ok, {raw_token, url}}` in integration wrapper | Call `dispatch_magic_link/4` → `Chimeway.trigger/3`; **do not** pass `raw_token` or `url` in trigger params [CITED: D-03, D-04, D-07] |

**Idempotency key (locked):** `sigra.magic_link:{user_id}:{token_inserted_at}` [CITED: D-03]. `token_inserted_at` from inserted `user_tokens` row `inserted_at` (microsecond ISO or unix string).

### 3.4 Confirmation code hook point (second ECOS-09 flow)

| Step | Location | Behavior |
|------|----------|----------|
| Token + code generation | `Sigra.Auth.generate_confirmation_token/3` | Returns `{encoded_token, code, link_struct, code_struct}` [VERIFIED: L794–834] |
| Install delivery today | `auth.ex` `deliver_user_confirmation_instructions/2` | `Sigra.Delivery.deliver(:confirmation, %{..., token:, code:, url:})` [VERIFIED: L368–376] |
| Phase 64 | Integration wraps post-insert | `dispatch_confirmation_code/…` → `Chimeway.trigger/3` with `sigra.auth.confirmation_code` [CITED: D-05, D-06] |

**Trigger params (identifier-only):** `user_id`, `email`, `confirmation_id` (token row id or composite ref) — **not** `code`, `url`, `signed_token` [CITED: D-07].

### 3.5 Sigra native delivery (parallel path, not Chimeway trace)

`Sigra.Delivery.build_job/3` persists `token`, `code`, `url` in Oban job args [VERIFIED: `../sigra/lib/sigra/delivery.ex` L68–74]. `EmailDelivery` worker reconstructs email at perform time [VERIFIED: `../sigra/lib/sigra/workers/email_delivery.ex` L87–100]. Phase 64 **does not** fix Sigra job-table leakage (out of ECOS-09); Chimeway must not mirror those args in `chimeway_events` [CITED: D-07, D-09].

### 3.6 Rendering / dispatch timing (critical)

`Chimeway.Trigger` calls `Notifier.resolve_rendering/3` **inside the trigger transaction** (`insert_notifications`) [VERIFIED: `lib/chimeway/trigger.ex` L169–174]. For **sync** dispatcher (default in integration tests), secrets can live in a **Sigra pending-delivery store** from `dispatch_*` until `rendering/2` runs in the same process window. For **Oban** dispatch, store must survive until worker perform [ASSUMED: tests use `Chimeway.Dispatch.Sync` + Logger adapter like Accrue].

**Rejected:** Putting `url`/`code` in trigger params relying on `sanitize_payload` — `url`/`code` are not in `@sensitive_keys` today and would still appear in notification `metadata`/`render_assigns` until keys are extended [VERIFIED: trigger.ex L174–184 applies `sanitize_render_assigns` with same key list].

---

## 4. Gaps to Close

| Gap | Evidence | Phase 64 action |
|-----|----------|-----------------|
| No `Sigra.Integrations.Chimeway` | Sigra grep: no `chimeway` | Add module in Sigra + optional dep |
| Magic link never emailed in install template | `session_controller.ex` L37–48 | Integration dispatch after `request_magic_link` success [CITED: D-03] |
| Confirmation secrets in delivery args | `auth.ex` L368–376; `delivery.ex` L68–74 | Chimeway path uses identifier-only trigger; optional: later Sigra template calls integration instead of raw `Delivery.deliver` [ASSUMED: Phase 64 focuses Chimeway trace] |
| `@sensitive_keys` incomplete | `trigger.ex` L36 | Add `url`, `code`, `raw_token`, `magic_link_url` [CITED: D-08] |
| No Sigra optional dep / CI exclude | `mix.exs` has accrue/threadline only | `sigra_deps/0`, `CHIMEWAY_SKIP_SIGRA_DEP`, `--exclude sigra` [CITED: D-10] |
| No Chimeway integration tests | No `sigra_*` under `test/` | Harness + lifecycle test [CITED: D-11] |
| Secret resolution for render | Hashed-only DB storage | Sigra pending-delivery cache or config callbacks [ASSUMED: OQ-1] |

---

## 5. Notifier Contracts

### 5.1 `sigra.auth.magic_link` (version 1)

| Callback | Contract |
|----------|----------|
| `notification_key/0` | `"sigra.auth.magic_link"` [CITED: D-04] |
| `version/0` | `1` |
| `recipients/1` | `{:ok, [%{recipient_identity: email, recipient_type: "email"}]}` from params `user_id` → Sigra repo lookup [ASSUMED] |
| `build/2` | Identifier assigns only: `user_id`, `kind: "magic_link"` — no URL [CITED: D-07] |
| `channels/2` | `{:ok, [:email]}` [ASSUMED: match Accrue email-only] |
| `orchestration/2` | `{:ok, :immediate}` [ASSUMED] |
| `rendering/2` | Resolve login URL via Sigra pending store / `Application.get_env(:sigra, :chimeway)` callback; produce `subject`, `html_body`, `text_body` without persisting URL in trigger params [CITED: D-04, D-07]. Email channel validator requires all three fields [VERIFIED: `lib/chimeway/rendering/channels/email.ex` L16–17] |

**Render key:** `sigra.auth.magic_link.email` (fallback pattern `notification_key.channel` [VERIFIED: `lib/chimeway/rendering.ex` L222–228])

### 5.2 `sigra.auth.confirmation_code` (version 1)

| Callback | Contract |
|----------|----------|
| `notification_key/0` | `"sigra.auth.confirmation_code"` [CITED: D-06] |
| `version/0` | `1` |
| `recipients/1` | Same email recipient pattern |
| `build/2` | `user_id`, `confirmation_id` (opaque), `kind: "confirmation_code"` — no numeric `code`, no `url` [CITED: D-07] |
| `rendering/2` | Resolve 6-digit code + confirmation URL from pending store; email body must not echo code into fields that get copied to `render_data` if those are unsanitized — prefer generic copy in persisted `render_data`, code only in adapter delivery path [ASSUMED: redaction test uses substring refute on trace surfaces] |

### 5.3 Trigger options (both flows)

| Option | Value |
|--------|-------|
| `idempotency_key` | Required; magic link per D-03; confirmation TBD (e.g. `sigra.confirmation_code:{user_id}:{link_token_id}`) [CITED: Claude's Discretion] |
| `tenant_id` | `user_id` as string [CITED: D-03] |
| `correlation_id` | Optional; pass from host conn `request_id` when available [ASSUMED] |

---

## 6. Redaction Requirements

### 6.1 Chimeway persistence surfaces

| Surface | Mechanism | Today | Phase 64 |
|---------|-----------|-------|----------|
| `chimeway_events.payload` | `sanitize_payload/1` | Strips `password`, `token`, `secret` only [VERIFIED: `trigger.ex` L36, L78] | Extend `@sensitive_keys` [CITED: D-08] |
| `chimeway_notifications.metadata` / `render_assigns` | `sanitize_render_assigns/1` | Same key list [VERIFIED: L174–175] | Same extension |
| `chimeway_deliveries.render_data` | Set from rendering output | Email validator allows `subject`, `html_body`, `text_body` [VERIFIED: `email.ex` L10–14] | **Rendering must not place raw token, code, or full magic-link path segment in persisted render_data** [CITED: D-09] |
| Operator trace | `Chimeway.Traces.get_trace/1` | Preloads event → notifications → deliveries [VERIFIED: `lib/chimeway/traces.ex` L39–54] | Integration tests refute sensitive substrings in payload + render_data |

### 6.2 Telemetry

`Chimeway.Telemetry.safe_meta/1` allowlist excludes `url`, `code`, `email`, `body`, `payload` [VERIFIED: `lib/chimeway/telemetry.ex` L80–84]. Integration tests should attach handler and assert stop events lack sensitive substrings (pattern from `telemetry_integration_test.exs` `@pii_keys` includes `:url` [VERIFIED: L19]).

### 6.3 Integration test assertions (D-09)

Capture at trigger time: `raw_token`, `confirmation_code`, `full_magic_link_url`. After delivery, assert **refute** `inspect(trace)` and telemetry metadata contain those substrings. Use `Chimeway.Traces.get_trace/1` on returned `event_id` [CITED: D-09] [ASSUMED: helper `refute_sensitive_in_trace!/2` in `test/support/sigra/fixtures.ex`].

### 6.4 Sigra Oban jobs (informational, out of scope)

`Sigra.Delivery` job args include `token`, `code`, `url` [VERIFIED: `delivery.ex` L68–74]. ECOS-09 acceptance is **Chimeway trace database** [CITED: REQUIREMENTS ECOS-09]. Document as non-goal for Phase 64; optional hardening is a Sigra follow-up.

---

## 7. Test Harness & CI

### 7.1 mix.exs changes (Chimeway)

| Accrue/Threadline | Sigra (Phase 64) |
|-------------------|------------------|
| `accrue_deps/0` + `CHIMEWAY_SKIP_ACCRUE_DEP` | `sigra_deps/0` + `CHIMEWAY_SKIP_SIGRA_DEP` [ASSUMED] |
| `{:accrue, "~> 1.3", optional: true, runtime: false}` | `{:sigra, "~> 0.3", optional: true, runtime: false}` or path [ASSUMED pin] |
| `ACCRUE_PATH` env | `SIGRA_PATH` env [CITED: D-10] |
| `ci.test` `--exclude accrue` | `--exclude sigra` [CITED: D-10] |
| `verify.accrue` | **Deferred** — Phase 66 GATE-07 [CITED: D-12] |

### 7.2 config/test.exs

Mirror Accrue block:

```elixir
config :sigra, ecto_repos: [Sigra.TestRepo]
config :sigra, repo: Sigra.TestRepo
config :sigra, :user_schema, Chimeway.TestSupport.Sigra.User  # harness schema
config :sigra, :user_token_schema, Chimeway.TestSupport.Sigra.UserToken
config :sigra, Sigra.TestRepo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "chimeway_sigra_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox
```

[ASSUMED module names; align with vendored schemas in `test/support/sigra/`]

Sigra library has **no root `priv/repo/migrations`** — harness must vendor minimal `users` + `user_tokens` migrations (copy fields from install golden `create_sigra_auth_tables` [VERIFIED: grep `../sigra/test/fixtures/install_golden/tree/priv/repo/migrations/*auth*`]).

### 7.3 test/test_helper.exs

When `Code.ensure_loaded?(Sigra)`:

1. Optionally `Code.compile_file` `lib/sigra/integrations/chimeway.ex` from `SIGRA_PATH` if module missing (Accrue pattern [VERIFIED: L36–49])
2. `storage_up` + migrate `Sigra.TestRepo`
3. `start_link` TestRepo + `Sandbox.mode(..., :manual)`
4. Configure `:sigra` repo/schemas for `Sigra.Auth` calls in tests

### 7.4 test/support/sigra/

| File | Purpose |
|------|---------|
| `test_repo.ex` | `Sigra.TestRepo` if not provided by Sigra hex [VERIFIED: Accrue defines `Accrue.TestRepo` in Chimeway `test/support/accrue/test_repo.ex`] |
| `user.ex`, `user_token.ex` | Minimal schemas for `Sigra.Auth` (integer or binary_id — pick one, document) [VERIFIED: Sigra tests use `Sigra.TestUser` embedded + `Sigra.TestUserToken` schema — harness likely needs **real Postgres tables**] |
| `migrations/*.exs` | `users`, `user_tokens` tables |
| `data_case.ex` | Dual sandbox: `Sigra.TestRepo` + `Chimeway.Repo` [VERIFIED: `test/support/accrue/data_case.ex`] |
| `fixtures.ex` | `configure_chimeway_logger_adapter!/0`, `insert_user!/1`, `refute_sensitive_in_trace!/2`, trigger helpers |

### 7.5 Integration tests

| File | Wave | Purpose |
|------|------|---------|
| `test/chimeway/integrations/sigra_auth_harness_test.exs` | 64-01 | Module loaded, repos up, config round-trip [VERIFIED: `threadline_telemetry_harness_test.exs` shape] |
| `test/chimeway/integrations/sigra_auth_lifecycle_test.exs` | 64-02 | Magic link + confirmation: event → delivery attempt → `get_trace` redaction [CITED: D-11] |

Wrap modules in `if Code.ensure_loaded?(Sigra) and Code.ensure_loaded?(Sigra.Integrations.Chimeway)` [VERIFIED: `accrue_dunning_lifecycle_test.exs` L1].

---

## 8. Cross-Repo Work Split

| Repo | Files / changes |
|------|-----------------|
| **Sigra** | `lib/sigra/integrations/chimeway.ex` (new); `mix.exs` optional `{:chimeway, "~> 1.0", optional: true}`; hook in `Sigra.Auth.request_magic_link/3` **or** expose `dispatch_*` for host/integration to call [ASSUMED: direct call from integration wrapper keeps `Auth` API stable]; pending-delivery helper module; release notes |
| **Chimeway** | `mix.exs` sigra dep + `ci.test` exclude; `config/test.exs`; `test/test_helper.exs`; `test/support/sigra/*`; `lib/chimeway/trigger.ex` `@sensitive_keys`; `test/chimeway/integrations/sigra_auth_*`; optional `lib/chimeway/integrations/sigra/` only if notifiers live in Chimeway [CITED: D-02 says notifiers nested in Sigra module like Accrue — **prefer Sigra repo for notifiers**] |

**Host wiring (document only in Phase 64):**

```elixir
# mix.exs
{:chimeway, "~> 1.0"},
{:sigra, "~> 0.3"}

# config
config :sigra, chimeway: [enabled: true, url_fun: &MyAppWeb.UserAuth.magic_link_url/1]
```

[CITED: D-02] [ASSUMED config key shape]

---

## 9. Validation Architecture (Nyquist Dimension 8)

### 9.1 Test framework

| Property | Value |
|----------|-------|
| Framework | ExUnit |
| Quick run (Wave 1) | `mix test test/chimeway/integrations/sigra_auth_harness_test.exs --only sigra --warnings-as-errors` |
| Phase gate (partial) | `mix test --only sigra --warnings-as-errors` |
| Default CI | `mix ci.test` (excludes `:sigra`) |
| Redaction regression | `mix test test/chimeway/persistence_transaction_test.exs test/chimeway/telemetry_integration_test.exs --warnings-as-errors` |

### 9.2 ROADMAP success criteria → verification map

| # | Success criterion (ROADMAP Phase 64) | Requirement | Test type | Automated command | Wave |
|---|--------------------------------------|-------------|-----------|-------------------|------|
| 1 | Magic link or MFA token dispatch triggers notifier + durable delivery + explainable trace | ECOS-09 | integration | `mix test --only sigra` lifecycle describe (both flows) | 64-02 |
| 2 | Sensitive tokens never in trace DB, telemetry, operator surfaces | ECOS-09 | integration + unit | Lifecycle `refute` on `get_trace/1` + extend trigger sensitive-key unit coverage | 64-01/02 |
| 3 | `@moduletag :sigra` selective CI | ECOS-09 | config | `mix ci.test` excludes sigra; `--only sigra` passes | 64-01 |

### 9.3 Wave 0 gaps (for 64-VALIDATION.md)

- [ ] `mix.exs` sigra dep + `ci.test` `--exclude sigra`
- [ ] `config/test.exs` Sigra.TestRepo + schema config
- [ ] `test/test_helper.exs` conditional bootstrap
- [ ] `test/support/sigra/*` (repo, schemas, migrations, fixtures, data_case)
- [ ] `sigra_auth_harness_test.exs` (64-01)
- [ ] `lib/chimeway/trigger.ex` sensitive key extension
- [ ] `../sigra/lib/sigra/integrations/chimeway.ex` + optional chimeway dep
- [ ] `sigra_auth_lifecycle_test.exs` (64-02)

---

## 10. Wave Recommendation

| Wave | Plan focus | Delivers |
|------|------------|----------|
| **64-01** | Harness + redaction baseline | Optional sigra dep, CI exclude, test bootstrap, `@sensitive_keys` extension, harness test |
| **64-02** | Integration + notifiers + proof | `Sigra.Integrations.Chimeway`, both notifiers, pending-delivery resolution, lifecycle + redaction tests |

Blueprint, demo host, `mix verify.sigra`, doc-contract → Phases 65–66 [CITED: 64-CONTEXT.md deferred].

---

## 11. Risks / Open Questions

### OQ-1: Ephemeral secret resolution for `rendering/2`

| Option | Pros | Cons |
|--------|------|------|
| **ETS / Agent keyed by `idempotency_key`** in Sigra integration | Works with Oban dispatch; secrets never in Chimeway DB | Must TTL + cleanup; test isolation |
| **Sync-only: set pending in process dictionary before trigger** | Simple for 64-02 tests | Breaks Oban perform path |
| **Pass pre-rendered subject/body from integration into pending store** | Notifier rendering is deterministic | Store still holds secrets until delivery |

**Recommendation:** Sigra-owned `Sigra.Integrations.Chimeway.PendingDelivery` (ETS) keyed by `idempotency_key`, populated in `dispatch_*`, read in notifier `rendering/2`, deleted on first read or after attempt [ASSUMED].

### OQ-2: Where to hook magic link dispatch

| Option | Pros | Cons |
|--------|------|------|
| Call integration from **`Sigra.Auth.request_magic_link/3`** when Chimeway loaded | Fixes all callers including install template | Couples core Auth to Chimeway |
| **Host-only** via generated `Auth.request_magic_link/2` wrapper | Cleaner library boundary | Install template must be updated separately |

**Recommendation:** `Sigra.Auth.request_magic_link/3` optional keyword `dispatch: :chimeway` default `:auto` (dispatch when integration loaded) [ASSUMED] — or unconditional dispatch when `Code.ensure_loaded?(Sigra.Integrations.Chimeway)` [ASSUMED simpler for Phase 64].

### OQ-3: Confirmation flow vs existing `Sigra.Delivery`

Install template uses `Sigra.Delivery.deliver(:confirmation, ...)`. Phase 64 may **add** Chimeway trigger alongside (double send risk) or **replace** in integration-only test path.

**Recommendation:** Phase 64 tests call `Sigra.Integrations.Chimeway.dispatch_confirmation_code/…` directly; install template change deferred to Phase 65 blueprint [ASSUMED].

### OQ-4: Sigra version pin

Sigra is `0.3.0` on disk [VERIFIED: `../sigra/mix.exs` L4]. Chimeway pin `~> 0.3` until API stabilizes [ASSUMED].

### OQ-5: Coordinated release

Phase 64 needs Sigra hex release with optional `:chimeway` dep [CITED: 64-DISCUSSION-LOG.md]. CI can use `SIGRA_PATH` until published [CITED: D-10].

---

## 12. Canonical Code References

| Ref | Path | Relevance |
|-----|------|-----------|
| Phase decisions | `.planning/phases/64-sigra-auth-flows-core/64-CONTEXT.md` | D-01–D-12 |
| ROADMAP SC | `.planning/ROADMAP.md` (Phase 64) | Three success criteria |
| ECOS-09 | `.planning/REQUIREMENTS.md` | Acceptance wording |
| SEED-003 Sigra | `.planning/seeds/SEED-003-ecosystem-integrations.md` | Auth notification intent |
| Chimeway trigger | `lib/chimeway/trigger.ex` | sanitize_payload, @sensitive_keys |
| Chimeway traces | `lib/chimeway/traces.ex` | get_trace/1 operator surface |
| Chimeway telemetry | `lib/chimeway/telemetry.ex` | safe_meta/1 allowlist |
| Accrue integration | `../accrue/accrue/lib/accrue/integrations/chimeway.ex` | Cross-repo pattern |
| Accrue lifecycle test | `test/chimeway/integrations/accrue_dunning_lifecycle_test.exs` | @moduletag :accrue |
| Accrue harness | `test/support/accrue/*`, `test/test_helper.exs` | Bootstrap template |
| Threadline harness | `test/chimeway/integrations/threadline_telemetry_harness_test.exs` | Wave 1 shape |
| Phase 63 research | `.planning/phases/63-threadline-telemetry-bridge/63-RESEARCH.md` | Document structure |
| Sigra magic link | `../sigra/lib/sigra/auth.ex` | request_magic_link/3 |
| Sigra confirmation | `../sigra/lib/sigra/auth.ex` | generate_confirmation_token/3 |
| Sigra delivery | `../sigra/lib/sigra/delivery.ex` | Job args with secrets |
| Sigra email worker | `../sigra/lib/sigra/workers/email_delivery.ex` | magic_link / confirmation rebuild |
| Install session | `../sigra/priv/templates/sigra.install/core/session_controller.ex` | No email send |
| Install auth | `../sigra/priv/templates/sigra.install/core/auth.ex` | Confirmation deliver |
| Chimeway mix CI | `mix.exs` | ci.test excludes |

---

## RESEARCH COMPLETE

**Summary:** Phase 64 is a cross-repo vertical slice: **`Sigra.Integrations.Chimeway`** triggers two notifiers (`sigra.auth.magic_link`, `sigra.auth.confirmation_code`) with identifier-only params, extended **`@sensitive_keys`**, and **`@moduletag :sigra`** lifecycle proofs. The main design risk is **reconstructing URL/code at render time without persisting secrets** — planners must lock an ephemeral Sigra-side pending-delivery pattern in Wave 64-02. Wave split: **64-01 harness + redaction**, **64-02 integration + tests**.
