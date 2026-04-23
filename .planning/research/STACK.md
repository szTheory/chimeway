# Stack Research

**Domain:** Embedded notification infrastructure for Elixir/Phoenix apps  
**Researched:** 2026-04-23  
**Confidence:** HIGH

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Elixir + OTP | Elixir 1.17+, OTP 26+ | Runtime and language foundation | Aligns with active Phoenix ecosystem and sibling OSS baselines; strong BEAM reliability story. |
| Phoenix | 1.7/1.8 | Host-app integration, optional LiveView admin/inbox surfaces | Native fit for mountable admin/trace UI and PubSub-driven inbox updates. |
| Ecto + PostgreSQL | Ecto 3.x, PostgreSQL 15+ | Durable records for events, inbox state, deliveries, and attempts | Transactional durability and indexing are central to explainability and idempotency. |
| Oban (optional but blessed) | 2.x | Durable async dispatch, retries, scheduling, queue controls | Standard Elixir production job substrate for notification fanout and retry behavior. |
| Swoosh (email adapter seam) | 1.x | Email provider abstraction and testing adapters | Mature, adapter-rich email ecosystem integration without reinventing channel foundations. |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Telemetry | 1.x | Structured events/spans for traceability and ops dashboards | Always; explainability requires event-level observability. |
| NimbleOptions | 1.x | Config validation for adapters and runtime setup | Always; fail-fast config errors beat runtime surprises. |
| Mox | 1.x | Behaviour-based mocking for unit and contract tests | For core and adapter contract tests. |
| Bypass | 2.x | Provider simulation for HTTP-based adapters (webhooks, SMS, chat) | For deterministic integration tests without live credentials. |
| Pigeon / Web Push libs | latest compatible | Push channel adapters | Introduce in later phases once durable spine is stable. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| `mix format`, `credo`, `dialyzer` | Static quality and consistency | Required in `mix verify.*` and CI lint lanes. |
| ExUnit + Postgres service | Unit and integration testing | Include tagged integration suite for Ecto/Oban workflows. |
| Release Please | Versioning and release PR automation | Keeps release flow reproducible and changelog-driven. |
| HexDocs/ExDoc | Public API and guide publishing | Pair with doc-contract checks for snippet and API drift. |

## Installation

```bash
# Core foundation
mix deps.get

# Typical core deps (exact versions finalized in implementation)
# {:ecto_sql, "~> 3.x"}
# {:postgrex, ">= 0.0.0"}
# {:phoenix, "~> 1.7", optional: true}
# {:oban, "~> 2.x", optional: true}
# {:swoosh, "~> 1.x", optional: true}

# Development and test quality gates
# {:credo, "~> 1.x", only: [:dev, :test], runtime: false}
# {:dialyxir, "~> 1.x", only: [:dev], runtime: false}
# {:mox, "~> 1.x", only: :test}
# {:bypass, "~> 2.x", only: :test}
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Oban-backed dispatch | Pure sync-only delivery | Early prototypes or tiny internal apps without async requirements. |
| Swoosh adapter seam | Direct provider clients in core | Only for app-local spikes; not suitable for reusable OSS framework core. |
| Structured config (NimbleOptions) | DSN-heavy string config | DSN can be offered as optional convenience once parser/validation is robust. |
| Embedded local-first architecture | Hosted notifications platform model | Only if product direction pivots away from OSS embedded scope. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Persisting module names as notification type identity | Renames/backfills become brittle and break historical traceability | Persist stable `notification_key` + version. |
| Hard dependency on one provider SDK in core | Locks architecture and bloats dependencies for unrelated users | Behaviour-based optional adapters per channel/provider. |
| Queue-only view of deliverability | Loses canonical in-app state and explainability when providers fail | Keep durable DB spine (events, notifications, deliveries, attempts) first. |
| Unvalidated config loaded lazily | Production-only failures and hard-to-debug startup issues | Validate on boot with explicit actionable errors. |

## Stack Patterns by Variant

**If v0.1 sync-first:**
- Use Ecto + in-app + one adapter seam with direct/sync execution.
- Because this validates the domain model and explainability quickly.

**If production fanout is required early:**
- Add Oban workers and transactional enqueue in same milestone as outbound delivery.
- Because retries, scheduling, and queue observability become mandatory.

**If admin UI is deferred:**
- Keep telemetry and trace schemas fully available from day one.
- Because operator debugging requirements should not depend on LiveView timeline completion.

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| Phoenix 1.7/1.8 | Elixir 1.17+, OTP 26+ | Confirm exact matrix in CI before public 1.0 support promise. |
| Ecto 3.x | PostgreSQL 15+ | Index and migration strategies should target Postgres first. |
| Oban 2.x | Ecto 3.x + PostgreSQL | Optional dependency in core; required for durable async mode. |
| Swoosh 1.x | Any supported mail adapter | Keep adapter package optional to reduce baseline deps. |

## Sources

- `prompts/elixir_notifykit_research_brief.md` - ecosystem stack recommendations and comparative analysis.
- `prompts/chimeway-engineering-dna-from-prior-libs.md` - CI/release/testing standards inherited from sibling OSS repos.
- [Swoosh docs](https://hexdocs.pm/swoosh/Swoosh.html) - adapter/test-mode references from research brief source map.
- [Oban docs](https://hexdocs.pm/oban/Oban.html) - queue/retry/transactional dispatch guidance from research brief source map.

---
*Stack research for: Chimeway*
*Researched: 2026-04-23*
