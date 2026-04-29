# Stack Research

**Domain:** Embedded notification workflow orchestration for Elixir/Phoenix apps
**Researched:** 2026-04-29
**Confidence:** HIGH

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Elixir | 1.17+ | Core workflow and delivery orchestration runtime | Keeps Chimeway aligned with the host-app runtime instead of introducing a second control plane. |
| PostgreSQL | 15+ | Durable workflow state, locking, and audit history | Multi-step progression needs transactional state changes, uniqueness, and row-level concurrency controls. |
| Oban | 2.x | Scheduled step progression, escalation timing, and async handoff | Journeys need durable waits and resumable execution; Oban already matches Chimeway's async posture. |
| Ecto | 3.x | Workflow persistence, changesets, and transactional progression | Journey transitions should remain explicit, validated, and easy to trace through DB-backed writes. |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Phoenix | 1.7/1.8 | Optional host integration and operator surfaces | Use when shipping LiveView-backed admin/reference flows or host-signal endpoints. |
| Swoosh | 1.x | Existing outbound email seam | Keep using for email steps rather than building provider logic into the journey engine. |
| Telemetry | built-in | Journey transition instrumentation | Use for workflow progression, waits, escalations, and stop conditions without leaking payloads. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| ExUnit | Concurrency and lifecycle verification | Journey progression needs race-focused integration coverage, not only unit tests. |
| Mix verify/ci tasks | Local/CI parity | Keep new workflow verification inside the existing `mix verify.*` and `mix ci.*` posture. |

## Installation

```bash
# Core runtime remains unchanged for this milestone.
mix deps.get
mix ecto.migrate
mix test
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Ecto + Oban + Chimeway-owned workflow state | External workflow engines like Temporal | Use only if Chimeway becomes a general-purpose orchestration platform instead of embedded notification infrastructure. |
| Durable DB-backed progression | In-memory or ETS workflow state | Never for production notification journeys; crash recovery and explainability would degrade immediately. |
| Explicit workflow declarations persisted as data | Runtime-only callback chains | Only acceptable for throwaway prototypes; durable replay and operator support suffer. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Generic BPMN/visual workflow engines in-core | Too much abstraction and product drag for the current embedded OSS goal | A notification-specific progression model with explicit waits, outcomes, and escalations |
| Separate hosted control-plane state | Breaks Chimeway's local-first ownership boundary | Persist journey state in the host app database |
| Module names as workflow identity | Repeats the durability problem already solved for notifications/renders | Stable workflow keys + versions stored as data |

## Stack Patterns by Variant

**If the host uses Oban:**
- Use scheduled workers for wait gates and escalations
- Because due-step promotion and retry semantics should reuse the existing durable async seam

**If the host stays sync-first:**
- Keep workflow planning durable, but document explicit host-managed progression hooks
- Because time-based workflows still need a durable progression seam even without a bundled job runner

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| Elixir 1.17+ | OTP 26+ | Matches project baseline. |
| Oban 2.x | PostgreSQL 15+ | Fits current scheduling and transactional dispatch posture. |
| Phoenix 1.7/1.8 | Elixir 1.17+ | Optional integration layer only; the core workflow engine should remain Phoenix-independent. |

## Sources

- https://laravel.com/docs/12.x/notifications — verified queueing, delay, and channel-routing expectations in mature notification systems
- https://symfony.com/doc/current/notifier.html — verified channel/transport boundaries and notification abstraction posture
- https://github.com/excid3/noticed — verified multi-delivery, delay, and conditional delivery patterns from a comparable OSS notification library
- Local project context: `.planning/PROJECT.md`, `.planning/milestones/v1.1-ROADMAP.md`, `.planning/milestones/v1.2-ROADMAP.md`

---
*Stack research for: embedded notification workflow orchestration*
*Researched: 2026-04-29*
