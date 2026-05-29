# Phase 54: Mailglass Adapter Core - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-05-29
**Phase:** 54-mailglass-adapter-core
**Mode:** assumptions
**Areas analyzed:** Rendering handoff, Module packaging, Per-channel config, Mailglass runtime prerequisites, Error classification, Phase boundary

## Assumptions Presented

### Rendering handoff (Chimeway planning → Mailglass delivery)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Adapter calls `Mailglass.Outbound.deliver/2`, building `%Mailglass.Message{}` from `render_key`, `render_data`, `tenant_id` + config mailable map | Likely | `.planning/seeds/SEED-003-ecosystem-integrations.md`, `lib/chimeway/delivery.ex`, `lib/chimeway/delivery_planning.ex`, demo notifiers |
| Do not re-invoke notifier modules at dispatch | Confident | `lib/chimeway/adapter.ex` moduledoc |

### Module location and optional dependency packaging
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `Chimeway.Adapters.Mailglass` at `lib/chimeway/adapters/mailglass.ex` | Likely | `lib/chimeway/adapters/logger.ex`, `lib/chimeway/adapters/test.ex` |
| `{:mailglass, optional: true}` with conditional compilation | Likely | `mix.exs` Oban pattern, `lib/chimeway/dispatch/oban.ex` |

### Per-channel registration and runtime config
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Register via `:channel_adapters` + `:channel_adapter_configs` | Confident | `lib/chimeway/dispatch/executor.ex`, `lib/chimeway/dispatch/channel_adapter_config.ex` |
| Runtime config only, no compile-time secrets | Confident | `lib/chimeway/adapter.ex` |

### Mailglass runtime prerequisites (tenancy, dual lifecycle)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Stamp tenancy from `delivery.tenant_id` before outbound | Likely | Mailglass `Mailglass.Outbound` preflight (external) |
| Dual lifecycle (Chimeway + Mailglass delivery rows) intentional | Likely | `Dispatch.Executor.run_delivery/1`, Mailglass outbound pipeline |
| Tests use `Mailglass.Adapters.Fake` + full Mailglass config | Likely | Mailglass test patterns (external) |

### Error classification and contract tests
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Map `%Mailglass.Error{}` to `:temporary/:permanent/:bounced` | Likely | `test/support/chimeway/adapter/contract_test.ex`, Mailglass error modules |
| Enable `simulate_error?/0` in contract tests | Likely | Existing adapter tests all use `simulate_error?, do: false` |

### Phase boundary (outbound only)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `deliver/2` only; webhooks deferred to Phase 55 | Confident | `.planning/ROADMAP.md` phases 54 vs 55 |
| `provider_message_id` deferred to Phase 55 | Likely | `lib/chimeway/delivery_attempt.ex`, `lib/chimeway/dispatch/executor.ex` |

## Corrections Made

No corrections — all assumptions confirmed by user (option 1: "Yes, proceed").

## External Research

- **Mailglass API:** `Mailglass.Outbound.deliver/2` is stable send entrypoint; requires tenancy stamp + `%Mailglass.Message{}` with mailable module (Source: hexdocs.pm/mailglass, local Mailglass checkout)
- **Version alignment:** Mailglass requires Elixir `~> 1.18`; Chimeway is `~> 1.17` — planner must pick compatible Hex version or document host Elixir floor (Source: both `mix.exs` files)
- **Test setup:** Mailglass contract tests need Repo + Fake adapter config, not Chimeway in-memory test adapter alone (Source: Mailglass repo test patterns)
