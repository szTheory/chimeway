# Phase 39: Demo Host Trace Path — Research

**Researched:** 2026-05-28  
**Phase:** 39-demo-host-trace-path  
**Requirements:** DEMO-01  
**Status:** Ready for plan-phase

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Primary adopter path is IEx walkthrough in `examples/chimeway_demo_host/README.md` — not Phoenix route/LiveView.
- **D-02:** Minimal demo host notifier + document `Chimeway.trigger/3` — no `Repo.insert!` fixture pattern from E2E test.
- **D-03:** Sync dispatcher (`Chimeway.Dispatch.Sync`) in demo host dev/IEx config.
- **D-04:** Simple delivery trace scenario (trigger → `explain_delivery/1` → status/suppression/planning/timeline) — not webhook/workflow progression.
- **D-05:** README contrasts with webhook E2E; links golden-path webhook appendix for progression proof.
- **D-06:** Add "Validate in the demo host (no webhooks)" subsection to `guides/introduction/golden-path.md` (§6 or §7).
- **D-07:** Optional cross-link from `guides/recipes/password-reset-support-trace.md` § Support Operator.
- **D-08:** Optional `priv/scripts/trace_demo.exs` or Mix alias — not required for DEMO-01.
- **D-09:** Do **not** expand root `mix verify.example` or doc-contract gates (Phase 41).
- **D-10:** Extend `examples/chimeway_demo_host/config/dev.exs` with `Chimeway.Repo` (non-sandbox) + Chimeway runtime config for IEx outside ExUnit.

### Claude's Discretion
- Notifier module name, notification_key, channel choice (in_app vs email) if sync dispatch + explainable timeline demonstrated.
- README section headings; script vs `mix demo.trace` alias.
- Golden-path wording/placement within §6–§7.

### Deferred Ideas (OUT OF SCOPE)
- Operator trace LiveView (`chimeway_admin`) — Phase 40
- `mix verify.example` + doc-contract CI — Phase 41
- Minimal HTTP trace lookup route — only if IEx README insufficient during execute
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DEMO-01 | Demo host documents non-webhook trace inspection path (IEx/script/minimal UI) so adopters validate explainability without provider webhooks | IEx README + dev config + notifier + golden-path cross-link satisfy all three ROADMAP success criteria |
</phase_requirements>

## Summary

Phase 39 delivers **DEMO-01** by making `examples/chimeway_demo_host` a runnable, documented explainability sandbox. The codebase already has webhook E2E proof in tests; the gap is adopter-facing **non-webhook** instructions: dev runtime config, a real notifier, `Chimeway.trigger/3`, and `Chimeway.Traces.explain_delivery/1` in IEx.

**Primary recommendation:** Extend existing `config/dev.exs` (file exists but is Phoenix-only today), add `DemoHost.Notifiers.TraceDemo` using `:in_app` channel, document IEx bootstrap including `Application.ensure_all_started(:chimeway)`, and cross-link from golden-path §7 as lowest-friction validation after first `explain_delivery/1`.

**Confidence: HIGH** — all APIs verified in source; test.exs provides a proven config template; Phase 38 recipes provide narrative cross-link targets.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Dev/IEx runtime config | Demo host config | Root `config/dev.exs` conventions | Host owns DB connection; demo host is path-dep example app |
| Notifier definition | Demo host `lib/` | `Chimeway.Notifier` behaviour | Host-owned notification definitions per golden-path |
| Trigger + sync dispatch | Chimeway library | Demo host config `:dispatcher` | Engine owns lifecycle; Sync completes in-session |
| Trace explainability | Chimeway.Traces | IEx operator | Public query API — no custom tooling |
| Adopter documentation | Demo host README + guides | — | Adoption surface milestone deliverable |

## Standard Stack

### Core (in-repo — no new packages)

| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| Elixir / OTP | ~> 1.17 | Runtime | Project baseline |
| Chimeway (path dep) | 0.1.0 | trigger + traces | Demo host already depends on `../..` |
| `Chimeway.Dispatch.Sync` | built-in | In-session delivery | Locked D-03; test.exs pattern |
| PostgreSQL | 15+ | Durable spine | Same DB as root `chimeway_dev` |
| `:in_app` channel | default | Simplest successful delivery | Golden-path §4; no adapter config required |

**No new Hex packages.** Package Legitimacy Audit: N/A (docs + example app only).

## Architecture Patterns

### System Architecture Diagram

```
Adopter (IEx)
    │
    ├─► Application.ensure_all_started(:chimeway)  [Repo + optional Oban]
    │
    ├─► Chimeway.trigger(DemoHost.Notifiers.TraceDemo, params, opts)
    │       ├─► Event + Notification persisted (Chimeway.Repo)
    │       └─► Dispatch.Sync → delivery :succeeded (in_app)
    │
    └─► Chimeway.Traces.explain_delivery(delivery_id)
            └─► %{status, suppression_reason, planning_reason, timeline}
```

### Recommended Project Structure

```
examples/chimeway_demo_host/
├── README.md                          # NEW — primary deliverable (D-01)
├── config/
│   ├── dev.exs                        # EXTEND — Chimeway.Repo + Sync (D-10)
│   └── test.exs                       # EXISTING — template for dev config
├── lib/demo_host/
│   └── notifiers/
│       └── trace_demo.ex              # NEW — minimal notifier (D-02)
└── priv/scripts/trace_demo.exs        # OPTIONAL (D-08)
```

### Pattern 1: Mirror test.exs Chimeway config in dev.exs [VERIFIED: examples/chimeway_demo_host/config/test.exs]

```elixir
config :chimeway,
  ecto_repos: [Chimeway.Repo],
  time_zone_database: Tzdata.TimeZoneDatabase,
  dispatcher: Chimeway.Dispatch.Sync

config :chimeway, Chimeway.Repo,
  username: System.get_env("PGUSER") || System.get_env("USER") || "postgres",
  password: System.get_env("PGPASSWORD"),
  hostname: System.get_env("PGHOST") || "localhost",
  database: "chimeway_dev",
  pool_size: 10
```

Use `chimeway_dev` (not sandbox pool) — matches root `config/dev.exs` database name convention.

### Pattern 2: Minimal notifier (adapt TestSupportNotifier) [VERIFIED: test/support/chimeway/test_support_notifier.ex]

```elixir
defmodule DemoHost.Notifiers.TraceDemo do
  use Chimeway.Notifier

  @impl true
  def notification_key, do: "trace_demo"

  @impl true
  def version, do: 1

  @impl true
  def recipients(%{user_id: user_id}) do
    {:ok, [%{recipient_identity: "user:#{user_id}", recipient_type: "user"}]}
  end

  @impl true
  def build(_params, _recipient) do
    {:ok, %{"headline" => "Trace demo", "body" => "Explainability walkthrough"}}
  end
end
```

Omit `channels/2` → defaults to `:in_app` per golden-path §4.

### Pattern 3: IEx walkthrough trigger + explain [VERIFIED: lib/chimeway/traces.ex moduledoc, guides/introduction/golden-path.md §5–§6]

```elixir
{:ok, result} =
  Chimeway.trigger(
    DemoHost.Notifiers.TraceDemo,
    %{user_id: "demo_user_1"},
    idempotency_key: "trace-demo-1",
    tenant_id: "demo"
  )

[delivery_id | _] = result.trace.delivery_ids
{:ok, explanation} = Chimeway.Traces.explain_delivery(delivery_id)
explanation.status
explanation.timeline
```

### Anti-Patterns to Avoid

- **Fixture inserts in adopter docs:** `feedback_pipeline_e2e_test.exs` uses `Deliveries.plan_delivery/3` + raw inserts — internal test pattern only (D-02, D-05).
- **Oban drain choreography:** Sync dispatcher avoids `Oban.drain_queue/2` in IEx walkthrough (D-03).
- **Duplicating webhook progression narrative:** Link golden-path webhook appendix instead (D-05).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Trace explanation | Custom SQL joins | `Chimeway.Traces.explain_delivery/1` | Durable spine + timeline assembly already in library |
| Delivery dispatch in IEx | Manual adapter calls | `Chimeway.trigger/3` + Sync | Full lifecycle + explainability |
| Test fixture path for adopters | Copy E2E helpers | Real trigger | Adopters need production entrypoint |

## Common Pitfalls

### Pitfall 1: Chimeway.Repo not started in IEx
**What goes wrong:** `Chimeway.trigger/3` fails with DB connection errors.  
**Why:** `DemoHost.Application` only supervises PubSub + Endpoint — does not start `Chimeway.Application`.  
**How to avoid:** README documents `Application.ensure_all_started(:chimeway)` before trigger; optionally add `{Chimeway.Application, []}` to demo host children in dev.  
**Warning signs:** `(DBConnection.ConnectionError)` in IEx.

### Pitfall 2: dev.exs missing Chimeway config
**What goes wrong:** IEx loads demo host but Chimeway has no Repo/dispatcher config.  
**Why:** Current `config/dev.exs` is Phoenix endpoint only (lines 1–12); Chimeway config lives only in `test.exs`.  
**How to avoid:** Extend dev.exs per D-10 mirroring test.exs minus sandbox.

### Pitfall 3: Unmigrated database
**What goes wrong:** trigger fails on missing `chimeway_*` tables.  
**How to avoid:** README prerequisite: from repo root run `mix ecto.create && mix ecto.migrate` (or document existing `chimeway_dev` setup).

## Code Examples

See Pattern sections above — all verified against repo source.

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| Webhook E2E only proof | + IEx explainability path | Adopters validate traces without SendGrid/webhooks |
| Golden-path §6 IEx in host app | + demo host as clone-and-run sandbox | Lowest-friction validation (ROADMAP criterion 3) |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `:in_app` default channel succeeds under Sync without `:channel_render_modules` | Pattern 2 | Walkthrough shows `:failed` — switch to documented test adapter pattern |
| A2 | `chimeway_dev` DB from root migrations is correct for demo host IEx | Pitfall 3 | Adopters need separate migrate instructions |

## Open Questions

1. **Start Chimeway in Application vs IEx one-liner?**
   - What we know: tests rely on implicit chimeway app start via mix test; demo host Application has no Chimeway child.
   - Recommendation: Document IEx one-liner in README (minimal diff); optionally add Chimeway to Application children if execute proves fragile.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| PostgreSQL | Chimeway.Repo | ✓ (typical dev) | 15+ | Document PGHOST/PGUSER env vars |
| Elixir 1.17+ | Demo host mix.exs | ✓ | — | — |
| Repo migrations | trigger/explain | ✓ (root priv) | — | README prerequisite steps |

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (existing demo host + root) |
| Config file | `examples/chimeway_demo_host/config/test.exs` |
| Quick run command | `cd examples/chimeway_demo_host && mix test` |
| Full suite command | `mix verify.example` (existing — **do not expand per D-09**) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DEMO-01 | Documented IEx path works | manual UAT | Follow README in fresh IEx session | ❌ README Wave 1 |
| DEMO-01 | Golden-path cross-link present | grep/doc | `rg 'Validate in the demo host' guides/introduction/golden-path.md` | ❌ Wave 2 |
| DEMO-01 | Notifier compiles | compile | `cd examples/chimeway_demo_host && mix compile` | ❌ Wave 1 |

### Sampling Rate
- **Per task commit:** `cd examples/chimeway_demo_host && mix compile --warnings-as-errors`
- **Per wave merge:** Manual UAT — maintainer runs README IEx steps
- **Phase gate:** Manual walkthrough sign-off in `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `examples/chimeway_demo_host/README.md` — primary DEMO-01 surface
- [ ] `examples/chimeway_demo_host/lib/demo_host/notifiers/trace_demo.ex` — runnable notifier
- [ ] Extended `config/dev.exs` — IEx runtime

## Security Domain

Docs/example phase — minimal attack surface. No new HTTP routes or auth.

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V5 Input Validation | no | N/A — no new input surface |
| V6 Cryptography | no | Existing demo host secret_key_base unchanged |

## Sources

### Primary (HIGH confidence)
- `examples/chimeway_demo_host/config/test.exs` — Chimeway config template
- `examples/chimeway_demo_host/config/dev.exs` — current gap (Phoenix only)
- `lib/chimeway/traces.ex` — explain_delivery API
- `lib/chimeway/trigger.ex` — trigger contract (idempotency_key, tenant_id)
- `.planning/phases/39-demo-host-trace-path/39-CONTEXT.md` — locked decisions

### Secondary
- `.planning/phases/38-reference-recipes/38-RESEARCH.md` — doc cross-link patterns
- `guides/introduction/golden-path.md` §6–§7 — cross-link insertion point

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — in-repo Elixir/Chimeway only
- Architecture: HIGH — test.exs proves config pattern
- Pitfalls: MEDIUM — IEx app startup needs execute verification

**Research date:** 2026-05-28  
**Valid until:** 2026-06-28
