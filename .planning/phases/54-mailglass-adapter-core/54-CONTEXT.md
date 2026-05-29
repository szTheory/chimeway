# Phase 54: Mailglass Adapter Core - Context

**Gathered:** 2026-05-29 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Host applications can deliver Chimeway email notifications through Mailglass rendering without bypassing Chimeway's durable delivery lifecycle. This phase delivers outbound `deliver/2` only — inbound webhook normalization and workflow feedback are Phase 55. Demo host wiring, reference recipes, integration docs, and `mix verify.mailglass` are Phases 56–57.

**Requirements:** ECOS-01, ECOS-02

**Success criteria (from ROADMAP):**
1. Host configuring Mailglass as the Chimeway email adapter can trigger a notifier and observe a successful delivery attempt with Mailglass-rendered content
2. `Chimeway.Adapters.Mailglass` passes shared adapter contract tests for deliver success, temporary/permanent/bounced error classification, and redacted provider metadata
3. Adapter config is read at call time via `Application.get_env/3` — no compile-time secrets
</domain>

<decisions>
## Implementation Decisions

### Rendering handoff (Chimeway planning → Mailglass delivery)
- **D-01:** The Mailglass adapter invokes `Mailglass.Outbound.deliver/2` at `deliver/2` time — not a transport-only pass-through of pre-rendered HTML from Chimeway's email channel validator.
- **D-02:** Build `%Mailglass.Message{}` from `%Chimeway.Delivery{}` fields: `render_key`, `render_data` (assigns), and `tenant_id`, plus a config-driven `render_key → mailable module` map supplied by the host.
- **D-03:** The adapter MUST NOT call back into notifier modules at dispatch time — all inputs come from the durable delivery row populated during planning (`Chimeway.DeliveryPlanning`).

### Module location and optional dependency packaging
- **D-04:** Implementation module is `Chimeway.Adapters.Mailglass` at `lib/chimeway/adapters/mailglass.ex`, following existing adapter conventions (`Chimeway.Adapters.Logger`, `Chimeway.Adapters.Test`).
- **D-05:** Add `{:mailglass, optional: true}` to `mix.exs`. Gate Mailglass callsites with `Code.ensure_loaded?/1` and `@compile {:no_warn_undefined, [...]}` — mirror the Oban optional-dep pattern in `lib/chimeway/dispatch/oban.ex`.
- **D-06:** Chimeway MUST compile cleanly when Mailglass is not installed. Hosts that opt in add Mailglass as a non-optional dependency in their own `mix.exs`.
- **D-07:** Document the REQUIREMENTS naming (`Chimeway.Adapter.Mailglass`) as the product-facing alias; implementation lives under `Chimeway.Adapters.*`. Planner may add a thin re-export module if doc/contract alignment requires it.

### Per-channel registration and runtime config
- **D-08:** Hosts register the adapter via `config :chimeway, channel_adapters: %{"email" => Chimeway.Adapters.Mailglass}`.
- **D-09:** Adapter-specific options (mailable map, Mailglass repo reference, etc.) live in `:channel_adapter_configs` keyed by `"email"`, resolved through `Chimeway.Dispatch.ChannelAdapterConfig.resolve/2`.
- **D-10:** All secrets and adapter options MUST be read at call time via `Application.get_env/3` or the `config` keyword passed to `deliver/2` — never compile-time module attributes.

### Mailglass runtime prerequisites (tenancy, dual lifecycle)
- **D-11:** Stamp Mailglass tenant context (`Mailglass.Tenancy.with_tenant/2` or equivalent) from `delivery.tenant_id` before calling `Mailglass.Outbound.deliver/2` — outbound preflight requires `Tenancy.assert_stamped!/0`.
- **D-12:** Accept dual lifecycle: Chimeway owns `chimeway_deliveries` + attempt rows via `Dispatch.Executor.run_delivery/1`; Mailglass owns its own delivery ledger via `Mailglass.Outbound`. This is intentional composition, not a bypass.
- **D-13:** Contract and integration tests use `Mailglass.Adapters.Fake` with full Mailglass app config (repo + fake adapter) — not `Chimeway.Adapters.Test` alone. Mirror Mailglass's own test-case patterns from the Mailglass repo.

### Error classification and contract tests
- **D-14:** Map `%Mailglass.Error{}` structs to Chimeway's `{:error, :temporary | :permanent | :bounced, detail}` using Mailglass error types and `Mailglass.Error.retryable?/1` where applicable.
- **D-15:** Explicit classification table: suppressions → `:bounced`; rate limits / adapter 5xx → `:temporary`; template/validation 4xx → `:permanent`. Planner may refine per Mailglass error module inventory.
- **D-16:** Enable `simulate_error?/0` in the Mailglass adapter contract test module, injecting failures via Fake adapter or config flag, so ECOS-02 error-shape assertions pass.
- **D-17:** Redact sensitive keys (`password`, `token`, `secret`, `api_key`, `auth`) from success `meta` before returning — enforced by shared `Chimeway.Adapter.ContractTest`.

### Phase boundary (outbound only)
- **D-18:** Phase 54 implements `deliver/2` only. Do NOT implement webhook callbacks (`verify_webhook`, `resolve_delivery`, `normalize_feedback`, `resolve_provider_event_id`) — those are Phase 55 (ECOS-03/04).
- **D-19:** Defer `provider_message_id` persistence on attempt rows to Phase 55 unless a zero-cost forward-compat lift from adapter `meta` is trivial. The column exists on `chimeway_delivery_attempts` but `Executor` does not populate it today.

### Claude's Discretion
- Exact `render_key → mailable` config key naming (`:mailables`, `:render_key_map`, etc.)
- Recipient email extraction convention from `notification.recipient_identity` (demo uses `"user:alex@teampulse.test"`) vs explicit email in `render_data`
- Compatible Mailglass Hex version pin given Elixir `~> 1.17` (Chimeway) vs `~> 1.18` (Mailglass) version floors
- Whether Phase 54 adjusts email channel validation for Mailglass-only assigns (no pre-rendered html_body) or accepts demo-style placeholder fields until Phase 56 notifier refactors
- Thin `Chimeway.Adapter.Mailglass` re-export module vs docs-only alias
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope and requirements
- `.planning/ROADMAP.md` — Phase 54 goal, success criteria, outbound-only boundary
- `.planning/REQUIREMENTS.md` — ECOS-01, ECOS-02 acceptance criteria
- `.planning/seeds/SEED-003-ecosystem-integrations.md` — Chimeway orchestration vs Mailglass templating responsibility split

### Chimeway adapter contract
- `lib/chimeway/adapter.ex` — `Chimeway.Adapter` behaviour, return shapes, runtime config discipline
- `test/support/chimeway/adapter/contract_test.ex` — shared contract test macro (success meta redaction, error classification)
- `guides/recipes/custom-adapter.md` — adapter authoring guide, return shapes, contract test usage

### Dispatch and config resolution
- `lib/chimeway/dispatch/executor.ex` — adapter execution, error classification, per-channel resolution
- `lib/chimeway/dispatch/channel_adapter_config.ex` — per-channel config resolution without atom creation from runtime strings
- `test/chimeway/dispatch/executor_adapter_resolution_test.exs` — channel adapter routing tests

### Rendering and delivery planning
- `lib/chimeway/delivery.ex` — delivery struct fields (`render_key`, `render_data`, `tenant_id`, `actor_id`)
- `lib/chimeway/delivery_planning.ex` — render application during planning, persisted render result flow
- `lib/chimeway/rendering.ex` — rendering declaration normalization
- `lib/chimeway/rendering/channels/email.ex` — email channel render contract (subject/html_body/text_body)

### Reference implementations
- `lib/chimeway/adapters/logger.ex` — minimal always-succeed adapter
- `lib/chimeway/adapters/test.ex` — in-memory test adapter pattern
- `test/chimeway/adapters/logger_adapter_test.exs` — contract test usage example
- `mix.exs` — optional dep pattern (`:oban`)
- `lib/chimeway/dispatch/oban.ex` — conditional compilation when optional dep absent

### Demo host (future Phase 56 alignment, read for render_key conventions)
- `examples/chimeway_demo_host/lib/demo_host/notifiers/password_reset.ex` — stable `render_key` strings and assigns shape

### External (Mailglass — not in Chimeway repo; read from Hex docs or local Mailglass checkout)
- `Mailglass.Outbound` — canonical send pipeline (`deliver/2`, tenancy preflight, renderer invocation)
- `Mailglass.Message` — message struct wrapping `%Swoosh.Email{}` + mailable metadata
- `Mailglass.Tenancy` — tenant stamping required before outbound
- `Mailglass.Adapters.Fake` — deterministic test adapter for contract tests
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Chimeway.Adapter` behaviour with documented return contract and optional webhook callbacks (Phase 55)
- `Chimeway.Adapter.ContractTest` macro — injects success/redaction/error-shape tests
- `Chimeway.Adapters.Logger` / `Chimeway.Adapters.Test` — reference adapter implementations
- `Chimeway.Dispatch.Executor` + `ChannelAdapterConfig` — adapter module + config resolution seam
- `Chimeway.Dispatch.ExecutorAdapterResolutionTest` — per-channel routing + fallback telemetry patterns
- Oban optional-dep conditional compilation pattern (`mix.exs`, `lib/chimeway/dispatch/oban.ex`)
- Demo notifiers with stable `render_key` strings and render assigns (`examples/chimeway_demo_host/lib/demo_host/notifiers/*.ex`)

### Established Patterns
- Adapters live under `Chimeway.Adapters.*`, implement `@behaviour Chimeway.Adapter`, export `deliver/2`
- Config at call time only — no compile-time secrets in module attributes
- Per-channel routing via `:channel_adapters` map; config via `:channel_adapter_configs` or legacy `:adapter_<channel>`
- `Executor.classify/1` maps adapter tuples to attempt outcome + error_class strings
- Contract tests: `use Chimeway.Adapter.ContractTest`, implement `adapter_module/0`, `sample_delivery/0`, optionally `simulate_error?/0`
- Durable render identity: `render_key` + `render_version` on delivery rows; channel payload validated per `Chimeway.Rendering.Channels.*`
- Optional deps: `optional: true` in mix.exs + `Code.ensure_loaded?/1` file guards

### Integration Points
| Seam | Role in Phase 54 |
|------|------------------|
| `Dispatch.Executor.run_delivery/1` | Invokes adapter after `:dispatched` transition; records attempt |
| `ChannelAdapterConfig.resolve/2` | Supplies Mailglass-specific keyword config to `deliver/2` |
| `:channel_adapters` / `:adapter` | Host registers Mailglass adapter for `"email"` channel |
| `%Chimeway.Delivery{}` | Input: `render_key`, `render_data`, `tenant_id`, `actor_id`, `notification_id`, `channel` |
| `%Chimeway.Notification{}` (via preload) | Source for `recipient_identity` / `render_assigns` if needed by adapter |
| `Mailglass.Outbound.deliver/2` | External send + render pipeline |
| `Mailglass.Tenancy` | Must be stamped before outbound call |
| `Mailglass.Adapters.Fake` | Contract/integration tests without real SMTP |
| `Deliveries.record_attempt/2` | Persists `provider_response` meta from adapter success |
</code_context>

<specifics>
## Specific Ideas

- SEED-003 vision: Chimeway orchestrates when/why (workflows, escalations, deduplication); Mailglass handles what/how (templating, MJML, Swoosh delivery)
- v1.8 is Mailglass-only — Accrue/Threadline/Sigra deferred to v1.9+ (INV-003 resolved)
- Demo notifiers already use stable string render keys like `teampulse.password_reset.email` — adapter mailable map should align with these identifiers for Phase 56 recipe/demo convergence
- No specific UI or demo host wiring in this phase — adapter core + contract tests only

</specifics>

<deferred>
## Deferred Ideas

- Inbound webhook callbacks (`verify_webhook`, `resolve_delivery`, `normalize_feedback`) — Phase 55 (ECOS-03/04)
- `provider_message_id` correlation on attempt rows for webhook identity resolution — Phase 55 (unless trivial forward-compat in Phase 54)
- Demo host TeamPulse notifier wiring through Mailglass — Phase 56 (DEMO-06)
- Reference recipe documenting orchestration vs templating split — Phase 56 (ECOS-05)
- Integration guide and doc-contract tests — Phase 57 (DOCS-06/07)
- `mix verify.mailglass` CI gate — Phase 57 (GATE-04)
- Separate Hex package (`chimeway_mailglass`) — rejected for Phase 54; optional dep in core is sufficient
- Mailglass-as-transport-only (pre-rendered HTML pass-through) — rejected; weakens ECOS-01 "Mailglass-rendered content" proof

### Reviewed Todos (not folded)
None — no pending todos matched Phase 54.

</deferred>

---

*Phase: 54-mailglass-adapter-core*
*Context gathered: 2026-05-29 (assumptions mode)*
