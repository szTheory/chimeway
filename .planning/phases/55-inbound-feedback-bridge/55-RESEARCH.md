# Phase 55: Inbound Feedback Bridge — Research

**Researched:** 2026-05-29  
**Domain:** Mailglass provider webhooks → Chimeway durable feedback spine (ECOS-03/04)  
**Confidence:** HIGH for Chimeway seams; HIGH for Mailglass Provider API; MEDIUM for batched-payload v1 limitation

## Summary

Phase 55 closes the outbound→inbound loop deferred from Phase 54. Three seams must ship together: (1) persist `provider_message_id` on outbound attempt rows so webhooks correlate, (2) extend the webhook ingest boundary so Mailglass can delegate crypto + normalization to `Mailglass.Webhook.Provider` without re-parsing provider dialects, (3) implement the four optional `Chimeway.Adapter` webhook callbacks on `Chimeway.Adapters.Mailglass`.

The existing spine (`Chimeway.Webhooks.process/4` → `Ingress` → `ProcessFeedbackWorker` → `Signal.track/4` → workflow progression → `Traces`) already satisfies ECOS-04 once Mailglass events normalize to `:delivered | :bounced | :failed`. No new Signal engine or host routes in this phase.

**Primary recommendation:** Ship in three waves — (1) spine extensions (`provider_message_id` + webhook parse seam), (2) Mailglass adapter webhook callbacks, (3) contract + Chimeway-level feedback pipeline integration tests mirroring `feedback_pipeline_e2e_test.exs`.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| mailglass | `~> 1.3` [VERIFIED: mix.exs] | Provider verify + normalize | D-03 — delegate HMAC/Basic auth |
| chimeway webhook spine | existing | Durable ingress + worker | Phase 33–34; unchanged vocabulary |
| oban | optional | Async ProcessFeedbackWorker | Existing queue `:chimeway_delivery` |

### Mailglass Webhook APIs (do NOT duplicate)

| Module | Role in Phase 55 |
|--------|------------------|
| `Mailglass.Webhook.Provider` | `verify!/3` + `normalize/2` behaviour |
| `Mailglass.Webhook.Providers.Postmark` | Primary test provider (Basic auth, Delivery/Bounce RecordTypes) |
| `Mailglass.Events.Event` | Anymail taxonomy for outcome mapping (D-08) |
| `Mailglass.SignatureError` | Map to `{:error, :unauthorized}` in verify_webhook |

**Explicitly NOT used:** `Mailglass.Webhook.Plug` — separate ledger (`mailglass_webhook_events`), does not feed Chimeway ingress (D-02).

## Architecture Patterns

### Pattern 1: Outbound correlation spine (D-05)

**What:** After successful `adapter.deliver/2`, `Dispatch.Executor.run_delivery/1` lifts `provider_message_id` from adapter meta into `Deliveries.record_attempt/2` attrs.

**Current gap:** `executor.ex:40-46` passes `provider_response: meta` but not top-level `provider_message_id` field on attempt row.

**Example target:**
```elixir
attempt_attrs = %{
  outcome: attempt_outcome,
  error_class: error_class,
  provider_response: provider_response,
  adapter_module: inspect(adapter),
  provider_message_id: Map.get(provider_response, :provider_message_id) || Map.get(provider_response, "provider_message_id")
}
```

**When:** Every outbound success where meta includes `provider_message_id` (Mailglass already returns it in meta at `mailglass.ex:70`).

### Pattern 2: Webhook parse seam (D-11, D-12)

**Problem:** `Chimeway.Webhooks.process/4` currently `Jason.decode/1`s the raw body, then calls `normalize_feedback(parsed)`. Mailglass `Provider.normalize/2` requires `(raw_body, headers)` and returns `[%Mailglass.Events.Event{}]`, not decoded JSON maps.

**Recommended seam (backward compatible):**

1. Merge `:raw_body` and `:headers` into `config` before `verify_webhook/3`.
2. Add optional adapter callback `parse_webhook_body/3` returning `{:ok, parsed}` | `{:error, :unparseable_body}`.
3. Default path: `Jason.decode/1` when callback not exported (EchoAdapter, MockAdapter unchanged).
4. Mailglass adapter implements `parse_webhook_body/3`:
   - Resolve provider module from config (`:webhook_provider` or `Application.get_env(:mailglass, :webhook_providers)`)
   - `Provider.normalize(raw_body, headers)`
   - Filter to delivery-relevant types (`:delivered`, `:sent`, `:bounced`, `:failed`, `:rejected`)
   - Take **first** delivery-relevant event (D-12 v1 limitation)
   - Return `{:ok, %{"_mailglass_event" => event}}` as internal parsed shape

**Mailglass callbacks then pattern-match `%{"_mailglass_event" => %Mailglass.Events.Event{}}`.**

### Pattern 3: verify_webhook delegation (D-03)

**What:** Read provider atom + secrets from runtime config; call `provider.verify!(raw_body, headers, provider_config)`.

**Error mapping:**
- `%Mailglass.SignatureError{}` → `{:error, :unauthorized}`
- `%Mailglass.ConfigError{type: :webhook_verification_key_missing}` → `{:error, :unauthorized}`

**Test provider:** Postmark with `basic_auth: {user, pass}` — matches `Mailglass.Webhook.Providers.Postmark` and avoids HMAC fixture complexity in v1.

### Pattern 4: Outcome mapping (D-08, D-09)

| Mailglass Event `:type` | Chimeway `normalize_feedback` status |
|-------------------------|--------------------------------------|
| `:delivered`, `:sent` | `:delivered` |
| `:bounced` (+ suppression reject reasons) | `:bounced` |
| `:failed`, `:rejected` | `:failed` |
| `:opened`, `:clicked`, `:complained`, `:autoresponded`, etc. | `:error` (no ingress row) |

**resolve_delivery:** Extract `message_id` / `provider_message_id` from `event.metadata` string keys → `{:ok, %{provider_message_id: id}}`.

**resolve_provider_event_id:** Use `metadata["provider_event_id"]` when present → `{:ok, id}` | `:none`.

### Pattern 5: ECOS-04 proof (D-13)

**What:** Chimeway-level integration test (not demo host — D-17):

1. Outbound deliver via Mailglass adapter → attempt row has `provider_message_id`
2. `Chimeway.Webhooks.process/4` with Postmark Delivery fixture + valid Basic auth
3. `Oban.drain_queue(:chimeway_delivery)` → attempt outcome `:succeeded`
4. Assert signal `chimeway.delivery.succeeded`
5. Assert `Traces` timeline includes `:webhook_received` with `provider_message_id` + `adapter_module`

Mirror structure from `examples/chimeway_demo_host/test/.../feedback_pipeline_e2e_test.exs` but call `Webhooks.process/4` directly.

## Pitfalls

### Pitfall 1: Jason.decode before Mailglass normalize

**Symptom:** Adapter receives generic map; loses provider-specific batch structure.  
**Fix:** Optional `parse_webhook_body/3` callback (Pattern 2).

### Pitfall 2: Engagement events create ingress noise

**Symptom:** `:opened` events create workflow signals.  
**Fix:** Return `:error` from `normalize_feedback/1` for non-delivery types (D-09).

### Pitfall 3: Missing provider_message_id on outbound attempt

**Symptom:** Worker marks ingress `:ignored` with `:provider_message_id_not_found`.  
**Fix:** Executor lift (Pattern 1) — must land in Wave 1 before webhook tests.

### Pitfall 4: SendGrid multi-event batches

**Symptom:** Only first event processed; others dropped silently.  
**Fix:** Document v1 limitation in adapter moduledoc; defer multi-row fan-out (deferred ideas).

### Pitfall 5: Using Mailglass.Webhook.Plug as Chimeway ingress

**Symptom:** Dual durable tracking without Chimeway workflow progression.  
**Fix:** Rejected in CONTEXT — hosts call `Chimeway.Webhooks.process/4` only.

## Validation Architecture

### Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + Mailglass.DataCase + Chimeway.DataCase |
| **Config file** | `config/test.exs`, Mailglass webhook provider config in test setup |
| **Quick run command** | `mix test test/chimeway/adapters/mailglass_adapter_test.exs test/chimeway/webhooks/ --warnings-as-errors` |
| **Full suite command** | `mix test --warnings-as-errors` |
| **Estimated runtime** | ~30–45s (webhook tests); ~2 min (full suite) |

### Coverage Targets

| Category | Target | Strategy |
|----------|--------|----------|
| verify_webhook | success + unauthorized | Postmark Basic auth fixtures |
| resolve_delivery | provider_message_id path | Metadata from normalized Event |
| normalize_feedback | delivered/bounced/failed + reject engagement | Unit tests per type |
| dedup | provider_event_id retry | Reuse Phase 33 ingress dedup tests pattern |
| ECOS-04 E2E | signal + trace | Chimeway integration test with workflow fixture |

### Sampling Cadence

- After each plan wave: quick run command
- Before phase verify: full `mix test --warnings-as-errors`

## Sources

### Local verification [VERIFIED: codebase]

- `lib/chimeway/webhooks.ex` — process/4 pipeline
- `lib/chimeway/dispatch/executor.ex` — provider_message_id gap
- `lib/chimeway/adapters/mailglass.ex` — outbound meta shape
- `lib/chimeway/webhooks/process_feedback_worker.ex` — correlation + signals
- `deps/mailglass/lib/mailglass/webhook/provider.ex` — Provider behaviour
- `deps/mailglass/lib/mailglass/webhook/providers/postmark.ex` — test provider
- `examples/chimeway_demo_host/test/.../feedback_pipeline_e2e_test.exs` — E2E pattern

### Context [VERIFIED: assumptions mode]

- `.planning/phases/55-inbound-feedback-bridge/55-CONTEXT.md`

## Metadata

**Confidence breakdown:**
- Chimeway spine: HIGH — existing Phase 33–34 code paths
- Mailglass Provider API: HIGH — local deps checkout
- Parse seam design: MEDIUM — optional callback not explicitly named in CONTEXT; aligned with D-11 intent

**Research date:** 2026-05-29  
**Valid until:** ~30 days

## RESEARCH COMPLETE
