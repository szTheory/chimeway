# Phase 54: Mailglass Adapter Core — Research

**Researched:** 2026-05-29  
**Domain:** Elixir optional-dependency adapter bridging Chimeway `deliver/2` to Mailglass outbound rendering  
**Confidence:** HIGH for Chimeway seams; MEDIUM for cross-version Elixir pin; HIGH for Mailglass API shapes (local checkout verified)

## Summary

Phase 54 adds `Chimeway.Adapters.Mailglass` behind an optional `{:mailglass, optional: true}` dependency, mirroring the Oban conditional-compilation pattern. At `deliver/2` time the adapter resolves a host-supplied `render_key → {mailable_module, function}` map, builds a `%Mailglass.Message{}` from `delivery.render_data` and recipient email, stamps `Mailglass.Tenancy.with_tenant/2` from `delivery.tenant_id`, and calls `Mailglass.Outbound.deliver/2`. Chimeway's executor continues to own `chimeway_deliveries` + attempts; Mailglass owns its parallel delivery ledger — intentional dual lifecycle per CONTEXT D-12.

Contract tests require the real Mailglass application stack (`Mailglass.TestRepo`, `Mailglass.Adapters.Fake`, `Mailglass.DataCase`) — not `Chimeway.Adapters.Test` alone.

**Primary recommendation:** Ship in three waves — (1) optional dep + Mailglass test harness, (2) adapter `deliver/2` + error mapper, (3) `Chimeway.Adapter.ContractTest` suite with `simulate_error?/0` via config flag or Mailglass test stub adapter.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| mailglass | `~> 1.3` [VERIFIED: local mix.exs] | Outbound render + send | SEED-003 / v1.8 wedge |
| swoosh | transitive via mailglass | Email transport struct | Mailglass.Message wraps Swoosh |
| ecto_sql | existing chimeway | Chimeway durable spine | unchanged |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Mailglass.Adapters.Fake | mailglass built-in | Deterministic adapter tests | All Phase 54 contract tests |
| Mailglass.TestRepo | mailglass test | Outbound persistence in tests | DataCase-backed adapter tests |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Optional dep in core | Separate `chimeway_mailglass` Hex package | Rejected in CONTEXT — optional dep sufficient |
| Pre-rendered HTML pass-through | Mailglass transport-only | Rejected — fails ECOS-01 Mailglass-rendered proof |
| Mox-only Mailglass stubs | Real Fake + TestRepo | Rejected per D-13 — misses integration fidelity |

## Architecture Patterns

### Recommended Module Layout

```
lib/chimeway/adapters/mailglass.ex          # Code.ensure_loaded? wrapper + deliver/2
test/support/chimeway/mailglass_fixtures.ex # Test mailable + render_key map helpers
test/support/chimeway/mailglass_case.ex     # Chimeway-specific Mailglass config (optional thin wrapper)
test/chimeway/adapters/mailglass_adapter_test.exs
```

### Pattern 1: Optional dependency compile guard

**What:** Entire adapter module wrapped in `if Code.ensure_loaded?(Mailglass) do ... end` with `@compile {:no_warn_undefined, [Mailglass.Outbound, ...]}`.

**When to use:** Any callsite into optional Hex dep (see `lib/chimeway/dispatch/oban.ex`).

**Example:** `lib/chimeway/dispatch/oban.ex` — Oban optional dep pattern.

### Pattern 2: Render-key → mailable resolution

**What:** Host config (via `ChannelAdapterConfig.resolve("email", [])`) supplies `:mailables` map:

```elixir
%{
  "teampulse.password_reset.email" => {MyApp.Mailers.PasswordReset, :email}
}
```

**When to use:** Every `deliver/2` — lookup `delivery.render_key`, apply mailable builder with `delivery.render_data` assigns, set recipient from parsed `recipient_identity` or `render_data["to"]`.

**Mailglass builder convention:** `mailable_module.new(assigns) |> Mailglass.Message.put_function(function) |> Swoosh.Email.to(email)` (or mailable-specific builder returning `%Message{}`).

### Pattern 3: Tenancy stamping

**What:** `Mailglass.Tenancy.with_tenant(delivery.tenant_id, fn -> Mailglass.Outbound.deliver(msg, opts) end)`.

**When to use:** Before every outbound call — `Tenancy.assert_stamped!/0` runs in Mailglass preflight.

### Pattern 4: Error classification bridge

**What:** Map `%Mailglass.Error{}` structs to `{:error, :temporary | :permanent | :bounced, detail}`:

| Mailglass struct | Chimeway class | Notes |
|------------------|----------------|-------|
| `Mailglass.SuppressedError` | `:bounced` | D-15 |
| `Mailglass.RateLimitError` | `:temporary` | `retryable?/1` true |
| `Mailglass.SendError` `:adapter_failure` | `:temporary` | per `Mailglass.Error.retryable?/1` |
| `Mailglass.TemplateError` | `:permanent` | validation/template |
| `Mailglass.ConfigError` | `:permanent` | |
| `Mailglass.TenancyError` | `:permanent` | missing stamp |
| Other / unknown | `:permanent` | safe default; log type in detail |

**Detail map:** Include only `type`, `module` (string), no raw provider bodies — align with adapter moduledoc.

### Anti-Patterns to Avoid

- **Calling notifier modules at dispatch** — violates D-03 and `Chimeway.Adapter` moduledoc; use delivery row fields only.
- **Compile-time API keys** — use `Application.get_env/3` / `config` keyword at call time (D-10).
- **Implementing webhook callbacks** — Phase 55 scope (D-18).
- **String.to_atom on render_key** — use map lookup with string keys only.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Email rendering in Chimeway | Custom MJML pipeline in adapter | `Mailglass.Outbound.deliver/2` | ECOS-01 proof |
| Test SMTP capture | Custom GenServer mailbox | `Mailglass.Adapters.Fake` | Production-parity write path |
| Adapter contract assertions | Copy-paste meta redaction tests | `Chimeway.Adapter.ContractTest` | ECOS-02 |

## Common Pitfalls

### Pitfall 1: Elixir version floor mismatch

**What goes wrong:** Chimeway `~> 1.17` vs Mailglass `~> 1.18` — CI or host on 1.17 cannot compile mailglass 1.x.

**How to avoid:** Pin `{:mailglass, "~> 1.3", optional: true}` and document in adapter moduledoc that hosts need Elixir 1.18+ when enabling Mailglass. Run Chimeway CI on 1.18+ for mailglass test suite (planner discretion D-56).

**Warning signs:** `mix compile` fails on version requirement in CI matrix.

### Pitfall 2: Mailglass TestRepo not started in Chimeway tests

**What goes wrong:** `Mailglass.Outbound.deliver/2` fails persistence preflight without sandbox checkout.

**How to avoid:** Use `Mailglass.DataCase` (or equivalent setup): Fake.checkout, TestRepo sandbox, `Application.put_env(:mailglass, adapter: {Fake, []})`.

### Pitfall 3: Email channel validator vs Mailglass-only assigns

**What goes wrong:** Planning still requires `subject/html_body/text_body` in render assigns (demo placeholders) while adapter ignores them for Mailglass render.

**How to avoid:** Phase 54 accepts demo-style placeholder fields (CONTEXT discretion); Phase 56 may relax email validator for Mailglass hosts.

### Pitfall 4: Missing notification preload for recipient

**What goes wrong:** `delivery` row lacks email address if adapter expects `notification.recipient_identity`.

**How to avoid:** Parse `actor_id` / `render_data["email"]` / `metadata["to"]` with documented precedence; document host must include email in `render_data` or standard `user:email` identity format.

## Code Examples

### Verified API shapes (local Mailglass checkout)

```elixir
# Outbound deliver — returns {:ok, %Mailglass.Outbound.Delivery{}} | {:error, %Mailglass.Error{}}
Mailglass.Outbound.deliver(%Mailglass.Message{}, [])

# Tenancy
Mailglass.Tenancy.with_tenant(tenant_id, fn -> ... end)

# Fake test setup (from Mailglass.OutboundTest)
Mailglass.Adapters.Fake.checkout()
```

### Chimeway executor invocation

```elixir
# lib/chimeway/dispatch/executor.ex — adapter.deliver(delivery, ChannelAdapterConfig.resolve(channel, []))
adapter.deliver(dispatched, adapter_config)
|> classify()
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Global `:adapter` only | Per-channel `:channel_adapters` | Phase 29 | Register Mailglass on `"email"` key |
| Adapter renders content | Pre-planned delivery (Logger/Test) | Phase 14+ | Mailglass adapter is explicit exception: renders at deliver via Mailglass |

## Open Questions

1. **Exact `:mailables` config key** — `:mailables` vs `:render_key_map` (Claude discretion; recommend `:mailables`).
2. **Recipient extraction precedence** — `render_data["to"]` > parse `user:email` from `actor_id` > `metadata["to"]`.
3. **Chimeway CI Elixir version** — bump test matrix to 1.18 for mailglass tests or tag `@moduletag :mailglass` excluded on 1.17.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Chimeway + Mailglass TestRepo) |
| **Config file** | `config/test.exs` (Chimeway) + inline Mailglass config in test helper |
| **Quick run command** | `mix test test/chimeway/adapters/mailglass_adapter_test.exs --warnings-as-errors` |
| **Full suite command** | `mix test --warnings-as-errors` |
| **Estimated runtime** | ~15–30s (Mailglass TestRepo sandbox) |

### Coverage Targets

| Category | Target | Strategy |
|----------|--------|----------|
| Adapter contract | 100% macro tests | `Chimeway.Adapter.ContractTest` + `simulate_error?/0` |
| Error classification | Each class once | Dedicated tests per Mailglass error struct |
| Optional-dep absent compile | `mix compile` without mailglass | CI job or compile-only check |

### Sampling Cadence

- After each plan wave: run mailglass adapter test file
- Before phase verify: full `mix test --warnings-as-errors`

## Sources

### Local verification [VERIFIED: codebase]

- `/Users/jon/projects/chimeway/lib/chimeway/adapter.ex`
- `/Users/jon/projects/chimeway/lib/chimeway/dispatch/executor.ex`
- `/Users/jon/projects/chimeway/lib/chimeway/dispatch/oban.ex`
- `/Users/jon/projects/mailglass/lib/mailglass/outbound.ex`
- `/Users/jon/projects/mailglass/lib/mailglass/error.ex`
- `/Users/jon/projects/mailglass/lib/mailglass/tenancy.ex`
- `/Users/jon/projects/mailglass/test/mailglass/outbound_test.exs`

### Context [VERIFIED: discuss-phase]

- `.planning/phases/54-mailglass-adapter-core/54-CONTEXT.md`

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — local mailglass checkout + chimeway patterns
- Architecture: HIGH — CONTEXT locks rendering handoff
- Pitfalls: MEDIUM — Elixir version matrix needs CI confirmation

**Research date:** 2026-05-29  
**Valid until:** ~30 days (mailglass 1.x stable)
