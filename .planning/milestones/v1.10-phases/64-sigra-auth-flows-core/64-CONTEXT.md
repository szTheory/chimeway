# Phase 64: Sigra Auth Flows Core - Context

**Gathered:** 2026-05-30 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Sigra auth events drive Chimeway notification delivery for **magic link** and **auth token dispatch** flows with security-first trace redaction — sensitive token values never persist in Chimeway trace database, telemetry, or operator surfaces.

**In scope:** `Sigra.Integrations.Chimeway` (Sigra repo, conditional compile), Chimeway notifiers + trigger wiring, optional `sigra` dep in Chimeway, test harness (`test/support/sigra_*`), `@moduletag :sigra` integration tests proving event → notification → delivery with redacted payloads, `--exclude sigra` on default `ci.test`.

**Out of scope (later phases):** Sigra auth reference blueprint + doc-contract (Phase 65 ECOS-10), demo host proof + operator inspectability (Phase 65 DEMO-10), golden-path guide + doc-contract (Phase 66 DOCS-10/11), `mix verify.sigra` CI gate + MAINTAINING checklist entry (Phase 66 GATE-07).

**Depends on:** v1.9 durable spine (trigger, delivery attempts, explainable traces, `sanitize_payload/1`, telemetry redaction). Parallel-safe with Phase 63 — no hard dependency.

**Requirements:** ECOS-09
</domain>

<decisions>
## Implementation Decisions

### Integration seam (not `Chimeway.Adapter`)
- **D-01:** Phase 64 delivers a **Sigra → Chimeway trigger bridge** only — no new `Chimeway.Adapter` delivery seam. Sigra owns auth state, token generation, and rate limits; Chimeway owns orchestration (when/why send, durable attempts, explainability).
- **D-02:** Cross-repo ownership mirrors Accrue Phase 58: **`Sigra.Integrations.Chimeway`** in Sigra (conditionally compiled on `Code.ensure_loaded?(Chimeway)`) + Chimeway integration tests and test harness. Host wiring: `{:chimeway, "~> 1.0"}` + `{:sigra, "~> …"}` + runtime config activating the integration module.

### Magic link dispatch
- **D-03:** On successful `Sigra.Auth.request_magic_link/3` (existing user, not rate-limited), **`Sigra.Integrations.Chimeway.dispatch_magic_link/4`** (or equivalent) calls `Chimeway.trigger/3` with a stable idempotency key (e.g. `sigra.magic_link:{user_id}:{token_inserted_at}`) and **`tenant_id` = user id**. Closes the generated-host gap where session controllers receive `{:ok, {raw_token, url}}` but never send email.
- **D-04:** Magic link notifier stable key: **`sigra.auth.magic_link`** (version 1). Notifier `build/2` reconstructs the login URL at render/dispatch time from host-supplied `url_fun` + opaque handle — **raw token never enters Chimeway trigger params or event payload**.

### Auth token dispatch (second flow)
- **D-05:** **“MFA token dispatch”** for ECOS-09 is implemented as **email confirmation code dispatch** (`:confirmation` with numeric `code` + signed URL) — the existing Sigra auth notification path with sensitive `code`/`token`/`url` in delivery args today. True email/SMS MFA OTP (SEED-003 “MFA Token SMS” example) is **not** in Sigra library yet; dedicated MFA outbound dispatch deferred until Sigra grows that API.
- **D-06:** Confirmation-code notifier stable key: **`sigra.auth.confirmation_code`** (version 1). Integration entry: wrap existing confirmation delivery seam (e.g. after token/code generation in host `Auth` module) → `Chimeway.trigger/3` with identifier-only params (`user_id`, `email`, `confirmation_id` or similar opaque ref).

### Trace redaction (integration boundary)
- **D-07:** **`Chimeway.trigger/3` params MUST be identifier-only** — `user_id`, recipient email, event kind, opaque refs. URLs, raw tokens, and numeric confirmation codes are resolved inside notifier `build/2` / render at dispatch time from Sigra repo or closure-scoped config — never written to `chimeway_events.payload`.
- **D-08:** Defense-in-depth: extend `Chimeway.Trigger` `@sensitive_keys` (and/or integration-layer param filter) to strip **`url`, `code`, `raw_token`, `magic_link_url`** in addition to `password`, `token`, `secret`. Existing `sanitize_payload/1` alone is insufficient — `url`/`code` pass through today.
- **D-09:** Integration tests assert **no sensitive substrings** (raw token, confirmation code, full magic-link URL path segment) in `Chimeway.Traces.get_trace/1` event payload, delivery `render_data`, or telemetry meta beyond `safe_meta/1` allowlist.

### Test harness & CI (Wave 64-01)
- **D-10:** Mirror Accrue/Threadline selective CI: optional `{:sigra, …}` dep with **`SIGRA_PATH`** env override; `@moduletag :sigra`; `--exclude sigra` on default `ci.test`; unconditional Sigra test config in `config/test.exs` (Accrue 58-01 / Threadline 63-01 precedent); `test/support/sigra_*` shim bootstraps Sigra test repo.
- **D-11:** Integration tests in Chimeway prove **both flows** (magic link + confirmation code) end-to-end: Sigra auth event → `Chimeway.trigger/3` → durable delivery attempt → explainable trace — no demo host glue in test path.
- **D-12:** **`mix verify.sigra` alias deferred to Phase 66** (GATE-07). Phase 64 only adds tag + exclude wiring prep.

### Claude's Discretion
- Exact `Sigra.Integrations.Chimeway` function names and config keys (`config :sigra, chimeway: [...]` vs `config :chimeway, :sigra_integration`).
- Whether outbound delivery uses Chimeway Logger adapter in tests vs delegates to `Sigra.Delivery` worker for actual email send (trace proof is Chimeway-owned either way).
- Sigra version pin when not using `SIGRA_PATH` path-dep.
- Idempotency key composition for confirmation-code retriggers.
- Test-support shim file layout (`test/support/sigra_*` vs nested under `integrations/`).
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

| Ref | Path | Why |
|-----|------|-----|
| Phase goal | `.planning/ROADMAP.md` (Phase 64) | Success criteria, scope boundary vs Phases 65–66 |
| Requirement | `.planning/REQUIREMENTS.md` (ECOS-09) | Locked acceptance: magic link + token dispatch, redaction, selective CI |
| SEED-003 Sigra slice | `.planning/seeds/SEED-003-ecosystem-integrations.md` | Auth notification intent — secure token delivery without trace logging |
| Accrue integration precedent | `../accrue/accrue/lib/accrue/integrations/chimeway.ex` | Conditional compile, `Chimeway.trigger/3`, cross-repo ownership |
| Phase 58 context | `.planning/milestones/v1.9-phases/58-accrue-dunning-core/58-CONTEXT.md` | Vertical-slice scope split (core vs demo/docs/gate) |
| Phase 63 context | `.planning/phases/63-threadline-telemetry-bridge/63-CONTEXT.md` | Selective CI + deferred verify gate pattern |
| Chimeway trigger + redaction | `lib/chimeway/trigger.ex` | `sanitize_payload/1`, `@sensitive_keys`, event persistence |
| Chimeway traces | `lib/chimeway/traces.ex` | Operator trace payload exposure (`get_trace/1`) |
| Chimeway telemetry | `lib/chimeway/telemetry.ex` | `safe_meta/1` allowlist |
| Accrue lifecycle test | `test/chimeway/integrations/accrue_dunning_lifecycle_test.exs` | `@moduletag :accrue` selective CI proof pattern |
| Threadline lifecycle test | `test/chimeway/integrations/threadline_telemetry_lifecycle_test.exs` | Optional-dep harness pattern |
| Accrue test harness | `test/support/accrue/` | TestRepo + DataCase shim template |
| Threadline test harness | `test/support/threadline/` | Optional-dep migration shim template |
| Sigra magic link API | `../sigra/lib/sigra/auth.ex` | `request_magic_link/3` contract, hashed token persistence |
| Sigra delivery | `../sigra/lib/sigra/delivery.ex` | Async job args carry token/code/url (T-3-INFRA-01) |
| Sigra email worker | `../sigra/lib/sigra/workers/email_delivery.ex` | `"magic_link"` / `"confirmation"` reconstruction |
| Sigra install auth gap | `../sigra/priv/templates/sigra.install/core/session_controller.ex` | Magic link requested but email not sent |
| Sigra confirmation delivery | `../sigra/priv/templates/sigra.install/core/auth.ex` | Confirmation `Sigra.Delivery.deliver/3` with code+url |
| Sigra email templates | `../sigra/priv/templates/sigra.install/core/emails.ex` | `magic_link_email/2`, confirmation builders |
| Chimeway CI excludes | `mix.exs` | `ci.test` exclude list, optional dep path env vars |
| v1.10 planning | `.planning/PROJECT.md`, `.planning/STATE.md` | Milestone scope, Mailglass/Accrue template reuse |
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`Chimeway.trigger/3`** + **`sanitize_payload/1`** — existing idempotent trigger spine; extend sensitive key list for auth flows.
- **`Chimeway.Traces.get_trace/1`** — integration tests can assert payload redaction on real trace rows.
- **Accrue/Threadline test harness** — `test/support/{accrue,threadline}/` TestRepo + DataCase + migration shims for optional hex deps.
- **`Accrue.Integrations.Chimeway`** — canonical cross-repo integration module pattern (conditional compile, `Chimeway.trigger/3`, notifier nested module).
- **Sigra `request_magic_link/3`** — returns `{raw_token, url}` after DB insert; integration hook point before host email send.
- **Sigra confirmation delivery** — existing `:confirmation` delivery with `token`, `code`, `url` args — second flow candidate with redaction hardening.

### Established Patterns
- Optional ecosystem dep: `optional: true, runtime: false` + path env override (`ACCRUE_PATH` / `THREADLINE_PATH` → `SIGRA_PATH`).
- Selective CI: `@moduletag`, exclude from `ci.test`, dedicated `mix verify.*` in later gate phase.
- Phase scope split: core integration in N, blueprint + demo + verify gate in N+1/N+2.
- Cross-repo: ecosystem lib owns event → trigger; Chimeway owns tests proving lifecycle + redaction.

### Integration Points
- `Sigra.Integrations.Chimeway` calls `Chimeway.trigger/3` after auth events (magic link success, confirmation code generated).
- Notifiers resolve sensitive URL/code at `build/2` from Sigra repo or integration config — not from persisted Chimeway event payload.
- Gap to close: magic link install template never sends email; confirmation passes secrets into delivery args — both need Chimeway-side redaction enforcement.
</code_context>

<specifics>
## Specific Ideas

No user corrections — all assumptions confirmed as presented.

**MFA token dispatch resolution (user confirmed proceed):** Use confirmation-code dispatch as the second ECOS-09 proof flow until Sigra ships dedicated email/SMS MFA OTP API.
</specifics>

<deferred>
## Deferred Ideas

- **Dedicated Sigra MFA email/SMS OTP dispatch** — true “MFA token dispatch” per SEED-003 SMS example; requires new Sigra auth notification API beyond TOTP-in-app flows.
- **Sigra auth reference blueprint** — Phase 65 ECOS-10.
- **Demo host Sigra proof at `/admin/chimeway`** — Phase 65 DEMO-10.
- **`mix verify.sigra` + MAINTAINING checklist** — Phase 66 GATE-07.

### Reviewed Todos (not folded)

No pending todos matched Phase 64 scope.
</deferred>
