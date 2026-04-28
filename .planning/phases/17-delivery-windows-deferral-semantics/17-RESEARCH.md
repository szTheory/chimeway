# Phase 17: Delivery Windows & Deferral Semantics - Research

**Researched:** 2026-04-28 [VERIFIED: user prompt]
**Domain:** Durable delivery-planning state for immediate, deferred, and digest-held deliveries in an Elixir/Ecto/Oban notification pipeline [VERIFIED: .planning/ROADMAP.md, .planning/REQUIREMENTS.md]
**Confidence:** HIGH [VERIFIED: codebase grep]

<user_constraints>
## User Constraints

- Research Phase 17 only, for `Delivery Windows & Deferral Semantics`. [VERIFIED: user prompt]
- Focus on ORCH-01 and ORCH-02 only; Phase 18 scheduled resume behavior is out of scope except for sequencing and prep work. [VERIFIED: user prompt, .planning/REQUIREMENTS.md, .planning/ROADMAP.md]
- Use the current Chimeway codebase as the primary source of truth and cite concrete modules/tests/patterns. [VERIFIED: user prompt]
- Cover durable schema/model changes for immediate send vs deferred window vs digest eligibility. [VERIFIED: user prompt]
- Cover explainability requirements for deferred decisions, including rule, timezone context, decision reason, and next eligible send time. [VERIFIED: user prompt]
- Preserve the existing `Delivery` / `DeliveryPlanning` / `Policy` / `Traces` lifecycle, idempotency guarantees, and host ownership boundaries. [VERIFIED: user prompt, .planning/PROJECT.md, lib/chimeway/trigger.ex, lib/chimeway/deliveries.ex]
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ORCH-01 | Product teams can declare whether a notification delivery sends immediately, defers to the next allowed window, or participates in digesting. [VERIFIED: .planning/REQUIREMENTS.md] | Durable per-delivery planning fields, planning-time resolver split from suppression checks, and dispatcher/Oban gating on planning disposition. [VERIFIED: lib/chimeway/delivery_planning.ex, lib/chimeway/dispatch/sync.ex, lib/chimeway/dispatch/oban.ex] |
| ORCH-02 | Delivery-window decisions respect recipient timezone and persist the reason, window rule, and next eligible send time. [VERIFIED: .planning/REQUIREMENTS.md] | Recipient timezone in policy settings, timezone database dependency, explicit persisted planning facts, and trace timeline expansion for deferral details. [VERIFIED: lib/chimeway/policy/settings.ex, lib/chimeway/traces.ex][CITED: https://hexdocs.pm/elixir/1.12/DateTime.html][CITED: https://hexdocs.pm/tzdata/Tzdata.TimeZoneDatabase.html] |
</phase_requirements>

## Summary

The current pipeline has a strong durable spine for `event -> notification -> delivery -> attempt`, but it does not yet have a durable planning model for "not now." Deliveries are created idempotently per `(notification_id, channel)` in `Chimeway.Deliveries.plan_delivery/3`, and explainability today is limited to execution-facing fields such as `status`, `suppression_reason`, `delay_fallback`, and `metadata`. Quiet hours are currently evaluated inside `Chimeway.Policy.Settings.evaluate/1` as a UTC-time suppression, which cannot satisfy ORCH-02 because it does not persist recipient timezone, rule context, or the next eligible send time. [VERIFIED: lib/chimeway/deliveries.ex, lib/chimeway/delivery.ex, lib/chimeway/policy/settings.ex, test/chimeway/policy_settings_test.exs]

Phase 17 should keep `Delivery` as the canonical durable row and add explicit planning facts to it instead of inventing a parallel "delivery plan" table. That preserves the existing idempotency contract, avoids split-brain between delivery and scheduling state, and fits the current trace API, which already explains a delivery by loading one delivery row plus its event/notification/attempt associations. [VERIFIED: lib/chimeway/deliveries.ex, lib/chimeway/trigger.ex, lib/chimeway/traces.ex, test/chimeway/reliability/duplicate_protection_test.exs, test/chimeway/traces_test.exs]

The minimum implementation-ready boundary for this phase is: persist the planning disposition on each delivery, persist enough decision detail to explain deferral, change planning-time policy evaluation so quiet hours defer instead of suppress, and teach Sync/Oban dispatchers to execute only deliveries whose planning disposition is ready for immediate send. Phase 17 may establish a durable rule abstraction that can represent future delivery-window rules, but the user-facing scope stays limited to recipient-timezone-aware quiet-hours deferral plus durable `:digest_held` planning state. Phase 17 must not create resume jobs, mutate Oban `scheduled_at`, introduce a broader allowed-window configuration surface, or implement digest accumulation. [VERIFIED: .planning/ROADMAP.md, lib/chimeway/dispatch/sync.ex, lib/chimeway/dispatch/oban.ex][CITED: https://hexdocs.pm/oban/Oban.Job.html]

**Primary recommendation:** Extend `chimeway_deliveries` with explicit orchestration fields, move quiet-hours/window logic out of pure suppression, and make deferred/digest-held deliveries durable-but-non-dispatchable in Phase 17. [VERIFIED: lib/chimeway/delivery.ex, lib/chimeway/policy/settings.ex, lib/chimeway/dispatch/oban.ex]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Immediate vs deferred vs digest-held planning | API / Backend | Database / Storage | Planning already happens in `Chimeway.Trigger` -> `Chimeway.DeliveryPlanning` -> `Chimeway.Deliveries`, and the result must survive retries and duplicate triggers. [VERIFIED: lib/chimeway/trigger.ex, lib/chimeway/delivery_planning.ex, lib/chimeway/deliveries.ex] |
| Recipient-timezone-aware window evaluation | API / Backend | Database / Storage | Window evaluation is business logic, but the winning decision, timezone, and next eligible time must be persisted in host-owned tables. [VERIFIED: .planning/PROJECT.md, lib/chimeway/policy/settings.ex][CITED: https://hexdocs.pm/elixir/1.12/DateTime.html] |
| Deferred decision explainability | API / Backend | Database / Storage | `Traces.explain_delivery/2` derives explanations from persisted delivery state and timestamps, so deferral facts must live with the delivery. [VERIFIED: lib/chimeway/traces.ex, lib/chimeway/traces/explanation.ex, test/chimeway/traces_test.exs] |
| Future scheduled resume handoff | Database / Storage | API / Backend | Phase 18 can schedule from persisted `next_eligible_at` facts, but Phase 17 must establish those facts first. [VERIFIED: .planning/ROADMAP.md][CITED: https://hexdocs.pm/oban/Oban.Job.html] |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `ecto` | `3.13.5` [VERIFIED: mix.lock, https://hex.pm/packages/ecto/versions] | Durable schema changes, changesets, and query composition | The codebase already persists all lifecycle state with Ecto schemas and migrations. [VERIFIED: mix.lock, priv/repo/migrations, lib/chimeway/delivery.ex] |
| `ecto_sql` | `3.13.5` [VERIFIED: mix.lock] | PostgreSQL-backed migrations and transactions | The current trigger, planning, and attempt history contracts rely on `Ecto.Multi` and SQL transactions. [VERIFIED: mix.lock, lib/chimeway/trigger.ex, lib/chimeway/deliveries.ex, lib/chimeway/dispatch/oban.ex] |
| `oban` | `2.21.1` [VERIFIED: mix.lock, https://hex.pm/packages/oban] | Async dispatch seam and later scheduled resume seam | The project already uses `ObanWorker.new/1` plus transactional enqueue, and Oban natively supports future execution via `scheduled_at` / `schedule_in` for Phase 18. [VERIFIED: mix.lock, lib/chimeway/dispatch/oban.ex, lib/chimeway/dispatch/oban_worker.ex][CITED: https://hexdocs.pm/oban/Oban.Job.html] |
| `tzdata` | `1.1.3` [VERIFIED: https://hex.pm/packages/tzdata] | IANA timezone database for recipient-local window evaluation | Elixir defaults to `Calendar.UTCOnlyTimeZoneDatabase`, so non-UTC timezone evaluation is not reliable without an installed timezone database. [CITED: https://hexdocs.pm/elixir/1.12/DateTime.html][CITED: https://hexdocs.pm/tzdata/Tzdata.TimeZoneDatabase.html] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `nimble_options` | `1.1.1` [VERIFIED: mix.lock] | Validate any new notifier/planning callback options | Use when Phase 17 exposes new declarative planning configuration to notifiers or host code. [VERIFIED: mix.lock, mix.exs] |
| Elixir `DateTime` + `Calendar` | `1.19.5 runtime` [VERIFIED: `mix --version`, `elixir --version`] | UTC/local-time conversion and DST-safe next-window computation | Use for all window calculations after configuring a real timezone database. [VERIFIED: current environment][CITED: https://hexdocs.pm/elixir/1.12/DateTime.html][CITED: https://hexdocs.pm/elixir/Calendar.TimeZoneDatabase.html] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Explicit planning columns on `chimeway_deliveries` | Metadata-only planning facts | Metadata-only is cheaper short-term, but it weakens queryability for later delayed/digested analytics and makes dispatcher gating depend on opaque JSON. [VERIFIED: lib/chimeway/delivery.ex, .planning/ROADMAP.md] |
| `tzdata` | `tz` | `tz` is viable, but Elixir’s own `DateTime` docs explicitly call out `tzdata`, and `tzdata` is the smaller change for this codebase. [CITED: https://hexdocs.pm/elixir/1.12/DateTime.html][VERIFIED: https://hex.pm/packages/tzdata, https://hex.pm/packages/tz] |

**Installation:**
```elixir
# mix.exs
{:tzdata, "~> 1.1"}
```

```elixir
# config/config.exs
config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase
```

**Version verification:** `ecto 3.13.5`, `oban 2.21.1`, and `tzdata 1.1.3` were verified from the checked-in lockfile or current Hex package pages during this research. [VERIFIED: mix.lock, https://hex.pm/packages/ecto/versions, https://hex.pm/packages/oban, https://hex.pm/packages/tzdata]

## Architecture Patterns

### System Architecture Diagram

```text
Trigger.trigger/3
  -> Event insert (idempotent by event.idempotency_key)
  -> Notification insert(s)
  -> DeliveryPlanning.plan_notification/2
      -> channel resolution
      -> suppression checks (preferences, category, delivery cap)
      -> timing/orchestration evaluation
          -> immediate
          -> deferred with next_eligible_at
          -> digest-held
      -> Deliveries.plan_delivery/3 persists canonical delivery row
  -> dispatcher path
      -> Sync: dispatch only orchestration_ready deliveries
      -> Oban: enqueue only orchestration_ready deliveries
  -> Traces.explain_delivery/2
      -> event + notification + delivery + attempts
      -> planning facts added to timeline
```

The current architecture already commits event and notification rows before dispatch and already threads `notification_key`, `event_id`, and `correlation_id` into delivery metadata. Phase 17 should extend that same planning stage rather than introducing a separate scheduler-owned source of truth. [VERIFIED: lib/chimeway/trigger.ex, lib/chimeway/deliveries.ex, test/chimeway/telemetry_correlation_test.exs]

### Recommended Project Structure
```text
lib/chimeway/
├── delivery.ex                    # add explicit orchestration fields
├── deliveries.ex                  # persist planning facts and expose orchestration updates
├── delivery_planning.ex           # resolve planning disposition before dispatch
├── policy/
│   ├── settings.ex                # split suppressive checks from window evaluation
│   └── settings/setting.ex        # add timezone + window config fields
├── traces.ex                      # explain planning/deferred state in timeline
└── dispatch/
    ├── sync.ex                    # skip non-ready deliveries
    └── oban.ex                    # enqueue only ready deliveries
```

### Pattern 1: Keep `Delivery` As The Canonical Durable Planning Row
**What:** Add explicit delivery-level orchestration fields instead of a separate planning table. [VERIFIED: lib/chimeway/delivery.ex, lib/chimeway/traces.ex]
**When to use:** Use for Phase 17 because planning is already one-row-per-delivery and idempotent per `(notification_id, channel)`. [VERIFIED: lib/chimeway/deliveries.ex, test/chimeway/reliability/duplicate_protection_test.exs]
**Recommended fields:**

| Field | Type | Purpose |
|-------|------|---------|
| `orchestration_state` | `Ecto.Enum` string-backed: `:ready | :deferred | :digest_held` | Separates execution lifecycle from planning disposition. [VERIFIED: lib/chimeway/delivery.ex][CITED: https://hexdocs.pm/ecto/Ecto.Enum.html] |
| `next_eligible_at` | `:utc_datetime_usec` | Durable UTC resume target for deferred deliveries. [VERIFIED: .planning/REQUIREMENTS.md] |
| `planning_reason` | `:string` | Machine-queryable reason such as `quiet_hours`, `outside_delivery_window`, or `digest_rule`. [VERIFIED: .planning/ROADMAP.md] |
| `planning_context` | `:map` | Explainability payload containing timezone, local evaluation time, rule identity, and any digest/window parameters. [VERIFIED: .planning/ROADMAP.md, lib/chimeway/traces.ex] |

**Example:**
```elixir
# Source: local delivery metadata + enum pattern
field :status, Ecto.Enum, values: [:pending, :dispatched, :succeeded, :failed, :suppressed, :cancelled]
field :orchestration_state, Ecto.Enum, values: [:ready, :deferred, :digest_held], default: :ready
field :next_eligible_at, :utc_datetime_usec
field :planning_reason, :string
field :planning_context, :map
```
[VERIFIED: lib/chimeway/delivery.ex][CITED: https://hexdocs.pm/ecto/Ecto.Enum.html]

### Pattern 2: Split Suppression From Timing Decisions
**What:** Quiet hours and delivery windows should no longer be expressed as `{:suppress, :quiet_hours}` at planning time; they should produce a deferral decision with persisted facts. Delivery caps, channel preference, category preference, and read-state suppression remain suppressive. [VERIFIED: lib/chimeway/policy.ex, lib/chimeway/policy/settings.ex, test/chimeway/policy_test.exs, test/chimeway/policy/delayed_fallback_test.exs]
**When to use:** Use whenever the delivery is still intended to send later instead of being permanently blocked. [VERIFIED: .planning/REQUIREMENTS.md, .planning/ROADMAP.md]
**Example:**
```elixir
# Source: current policy return shape, extended for orchestration
{:ok, :proceed}
{:suppress, :delivery_cap_reached}
{:defer, %{reason: "quiet_hours", time_zone: "America/New_York", next_eligible_at: next_at}}
{:digest, %{reason: "digest_rule", digest_key: "..."}}
```
[VERIFIED: lib/chimeway/policy.ex, lib/chimeway/policy/settings.ex][ASSUMED]

### Pattern 3: Make Dispatchers Gate On Planning Disposition, Not Only `status`
**What:** `Sync` and `Oban` currently dispatch or enqueue any planned delivery unless it is already `:suppressed`; Phase 17 should gate on `orchestration_state == :ready`. [VERIFIED: lib/chimeway/dispatch/sync.ex, lib/chimeway/dispatch/oban.ex]
**When to use:** Immediately in this phase, otherwise deferred or digest-held rows will leak into immediate execution. [VERIFIED: lib/chimeway/dispatch/sync.ex, lib/chimeway/dispatch/oban.ex]
**Example:**
```elixir
Enum.filter(deliveries, &(&1.status == :pending and &1.orchestration_state == :ready))
```
[VERIFIED: lib/chimeway/dispatch/oban.ex][ASSUMED]

### Pattern 4: Persist Enough Deferral Context To Recompute Or Audit Later
**What:** Store the evaluated timezone, local wall-clock context, normalized rule identity, and the UTC `next_eligible_at` used for the decision. [VERIFIED: .planning/ROADMAP.md, .planning/REQUIREMENTS.md]
**When to use:** Every deferred delivery row. [VERIFIED: .planning/ROADMAP.md]
**Suggested `planning_context` shape:**
```elixir
%{
  "time_zone" => "America/New_York",
  "rule_type" => "quiet_hours",
  "rule_source" => "recipient_settings",
  "window" => %{"start_minute" => 1320, "end_minute" => 480},
  "evaluated_at_utc" => "2026-04-28T05:12:00.000000Z",
  "evaluated_local" => "2026-04-28T01:12:00-04:00",
  "next_eligible_at" => "2026-04-28T12:00:00.000000Z"
}
```
[VERIFIED: lib/chimeway/traces.ex][ASSUMED]

### Anti-Patterns to Avoid
- **Using `suppression_reason` for deferral:** `suppression_reason` is currently the terminal/operator surface for suppressed or cancelled outcomes, so overloading it for deferral would blur "not allowed" and "allowed later." [VERIFIED: lib/chimeway/delivery.ex, lib/chimeway/traces/explanation.ex, lib/chimeway/traces.ex]
- **Leaving deferred facts only in Oban jobs:** Oban can schedule work, but `Traces.explain_delivery/2` only inspects Chimeway tables today, and duplicate-trigger recovery is intentionally inert. [VERIFIED: lib/chimeway/traces.ex, lib/chimeway/trigger.ex][CITED: https://hexdocs.pm/oban/Oban.Job.html]
- **Continuing UTC-only quiet-hours math:** the current `DateTime.utc_now()` minute-of-day check ignores recipient locale and DST. [VERIFIED: lib/chimeway/policy/settings.ex][CITED: https://hexdocs.pm/elixir/1.12/DateTime.html]
- **Creating digest rows in Phase 17:** ORCH-01 only requires durable digest eligibility planning; digest accumulation and emission belong to Phases 19-20. [VERIFIED: .planning/ROADMAP.md, .planning/REQUIREMENTS.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Timezone conversions and DST handling | Custom offset math from UTC minutes | `DateTime.shift_zone/3` with a configured timezone database | Elixir’s default timezone database is UTC-only, and DST introduces ambiguous/gap wall times that custom minute math will mishandle. [CITED: https://hexdocs.pm/elixir/1.12/DateTime.html][CITED: https://hexdocs.pm/elixir/Calendar.TimeZoneDatabase.html] |
| Future execution timing | Ad hoc timestamps in metadata only | Durable `next_eligible_at` on delivery now; Oban `scheduled_at` in Phase 18 | Operators need Chimeway-owned facts now, and Oban already knows how to stage future jobs later. [VERIFIED: .planning/ROADMAP.md, lib/chimeway/traces.ex][CITED: https://hexdocs.pm/oban/Oban.Job.html] |
| Querying delayed/digest state | JSON-only filtering on arbitrary metadata | Explicit delivery columns for orchestration state, reason, and next eligible time | Phase 22 outcome analytics will need stable query surfaces. [VERIFIED: .planning/ROADMAP.md, lib/chimeway/delivery.ex] |

**Key insight:** Chimeway’s differentiation is explainable lifecycle state, so "deferred" must become first-class delivery data rather than an incidental job scheduler detail. [VERIFIED: .planning/PROJECT.md, .planning/STATE.md]

## Common Pitfalls

### Pitfall 1: Quiet Hours Are Currently Suppression, Not Deferral
**What goes wrong:** A recipient in quiet hours is permanently suppressed instead of queued for the next allowed send window. [VERIFIED: lib/chimeway/policy/settings.ex, test/chimeway/policy_settings_test.exs]
**Why it happens:** `Settings.evaluate/1` returns `{:suppress, :quiet_hours}` based on `DateTime.utc_now()` minute-of-day logic. [VERIFIED: lib/chimeway/policy/settings.ex]
**How to avoid:** Move quiet-hours/window logic into a planning decision function that returns durable deferral facts, and keep `Settings.evaluate/1` or its replacement for genuinely suppressive rules only. [VERIFIED: lib/chimeway/policy/settings.ex, lib/chimeway/policy.ex][ASSUMED]
**Warning signs:** Deferred deliveries still show `status: :suppressed` or `suppression_reason: "quiet_hours"`. [VERIFIED: lib/chimeway/traces.ex][ASSUMED]

### Pitfall 2: Deferred Rows Will Leak Into Immediate Oban Execution Unless Explicitly Gated
**What goes wrong:** The Oban dispatcher enqueues every planned delivery with `status == :pending`, so a newly deferred row would still get a worker immediately. [VERIFIED: lib/chimeway/dispatch/oban.ex]
**Why it happens:** `do_enqueue/2` filters only on delivery status, and Sync similarly dispatches any non-suppressed planned delivery. [VERIFIED: lib/chimeway/dispatch/oban.ex, lib/chimeway/dispatch/sync.ex]
**How to avoid:** Add a planning disposition column and require `orchestration_state == :ready` in both dispatch paths. [VERIFIED: lib/chimeway/dispatch/oban.ex, lib/chimeway/dispatch/sync.ex][ASSUMED]
**Warning signs:** A deferred row accumulates attempts or transitions to `:dispatched` before Phase 18 exists. [VERIFIED: lib/chimeway/traces.ex, lib/chimeway/deliveries.ex][ASSUMED]

### Pitfall 3: Reusing `metadata` Alone Will Undercut Later Analytics
**What goes wrong:** Phase 22 delayed/digested reporting becomes expensive or inconsistent because key facts are hidden inside JSON blobs. [VERIFIED: .planning/ROADMAP.md, lib/chimeway/delivery.ex]
**Why it happens:** The current delivery schema exposes only `status`, `suppression_reason`, `delay_fallback`, and `metadata` as durable planning/execution fields. [VERIFIED: lib/chimeway/delivery.ex]
**How to avoid:** Use explicit columns for `orchestration_state`, `planning_reason`, and `next_eligible_at`, with `planning_context` reserved for explanatory detail. [VERIFIED: lib/chimeway/delivery.ex][ASSUMED]
**Warning signs:** Planner proposals rely on `fragment("metadata->>...")` to answer basic product questions. [VERIFIED: lib/chimeway/delivery.ex][ASSUMED]

### Pitfall 4: Timezone Support Will Fail Silently Without A Real Time Zone Database
**What goes wrong:** Recipient-local scheduling works in UTC-only tests but fails for non-UTC zones or DST transitions. [CITED: https://hexdocs.pm/elixir/1.12/DateTime.html]
**Why it happens:** Elixir defaults to `Calendar.UTCOnlyTimeZoneDatabase`; the current codebase has no timezone dependency or `:elixir, :time_zone_database` config. [VERIFIED: mix.exs, mix.lock, config, lib/chimeway/policy/settings.ex][CITED: https://hexdocs.pm/elixir/1.12/DateTime.html]
**How to avoid:** Add `tzdata`, configure `Tzdata.TimeZoneDatabase`, and add DST gap/ambiguous-time tests before locking window math. [VERIFIED: https://hex.pm/packages/tzdata][CITED: https://hexdocs.pm/tzdata/Tzdata.TimeZoneDatabase.html][CITED: https://hexdocs.pm/elixir/Calendar.TimeZoneDatabase.html]
**Warning signs:** `DateTime.shift_zone/3` returns `{:error, :utc_only_time_zone_database}` in tests or runtime. [CITED: https://hexdocs.pm/elixir/1.12/DateTime.html]

## Code Examples

Verified patterns from current code and official docs:

### Idempotent Delivery Planning Row
```elixir
# Source: lib/chimeway/deliveries.ex
Repo.insert(changeset, on_conflict: :nothing, conflict_target: [:notification_id, :channel])
```
[VERIFIED: lib/chimeway/deliveries.ex]

### Oban Future Scheduling Primitive For Phase 18 Handoff
```elixir
# Source: Oban.Job docs
MyApp.Worker.new(%{delivery_id: id}, scheduled_at: next_eligible_at)
MyApp.Worker.new(%{delivery_id: id}, schedule_in: {5, :minutes})
```
[CITED: https://hexdocs.pm/oban/Oban.Job.html]

### Elixir Timezone Conversion Primitive
```elixir
# Source: DateTime docs
DateTime.shift_zone(utc_datetime, "America/Los_Angeles", Calendar.get_time_zone_database())
```
[CITED: https://hexdocs.pm/elixir/1.12/DateTime.html]

### Trace Timeline Expansion Target
```elixir
%{
  at: delivery.updated_at,
  event: :deferred,
  detail: %{
    reason: delivery.planning_reason,
    time_zone: delivery.planning_context["time_zone"],
    next_eligible_at: delivery.next_eligible_at
  }
}
```
[VERIFIED: lib/chimeway/traces.ex][ASSUMED]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Quiet hours as a suppressive policy setting | Quiet hours should become a deferral rule with durable timing facts | Needed for Phase 17 / ORCH-02. [VERIFIED: .planning/REQUIREMENTS.md, .planning/ROADMAP.md] | Preserves explainability and allows later resume scheduling without inventing missing state. [VERIFIED: .planning/ROADMAP.md, lib/chimeway/traces.ex] |
| Execution status alone describes lifecycle | Execution status plus orchestration state should describe "ready vs deferred vs digest-held" | Needed for Phase 17 because `pending` alone is not enough. [VERIFIED: lib/chimeway/delivery.ex, lib/chimeway/dispatch/oban.ex] | Prevents deferred rows from being dispatched while keeping retry/failure semantics intact. [VERIFIED: lib/chimeway/dispatch/oban.ex, lib/chimeway/dispatch/sync.ex] |

**Deprecated/outdated:**
- Treating `quiet_hours` as a terminal suppression reason is outdated for Phase 17’s requirements, even though it matches current tests. [VERIFIED: test/chimeway/policy_settings_test.exs, .planning/REQUIREMENTS.md]

## Scope Resolution

**Resolved on 2026-04-28 for revision iteration 1.**

1. **Recipient timezone ownership**
   - Decision: Phase 17 persists recipient timezone on `chimeway_policy_settings.time_zone` and treats `Policy.Settings.upsert_settings/1` as the durable write path for both inserts and updates. [VERIFIED: lib/chimeway/policy/settings.ex, lib/chimeway/policy/settings/setting.ex]
   - Boundary: no per-delivery or trigger-time timezone override is added in Phase 17. If later phases need override precedence, that becomes new roadmap scope instead of implicit Phase 17 work. [VERIFIED: .planning/ROADMAP.md]

2. **Delivery-window breadth**
   - Decision: Phase 17 implements recipient-timezone-aware quiet-hours deferral only, while persisting a normalized planning reason/context shape that can also represent future broader delivery-window rules. [VERIFIED: .planning/ROADMAP.md, .planning/REQUIREMENTS.md]
   - Boundary: no new general allowed-window configuration schema, no cross-day scheduling surface beyond quiet-hours minute ranges, and no Phase 18 resume scheduling behavior. [VERIFIED: .planning/ROADMAP.md]

3. **Digest boundary**
   - Decision: `:digest_held` exists only as durable planning state in Phase 17 so ORCH-01 can distinguish immediate, deferred, and digest-held outcomes on the canonical delivery row. [VERIFIED: .planning/REQUIREMENTS.md]
   - Boundary: no digest bucket creation, accumulation, or emission work lands in this phase. Those remain scoped to Phases 19-20. [VERIFIED: .planning/ROADMAP.md]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir / Mix | Migrations, tests, compile | ✓ [VERIFIED: local shell] | `Elixir 1.19.5`, `Mix 1.19.5` [VERIFIED: `mix --version`, `elixir --version`] | — |
| PostgreSQL client | Local DB workflows and schema verification | ✓ [VERIFIED: local shell] | `psql 14.17` [VERIFIED: `psql --version`] | Server version not verified from this session. [VERIFIED: local shell] |
| Oban dependency | Async path parity and later resume scheduling seam | ✓ in `mix.lock` [VERIFIED: mix.lock] | `2.21.1` [VERIFIED: mix.lock, https://hex.pm/packages/oban] | Sync dispatcher still exists for non-Oban hosts, but Phase 18 depends on Oban semantics. [VERIFIED: lib/chimeway/dispatch/sync.ex, lib/chimeway/dispatch/oban.ex] |
| Time zone database package | Recipient-local window evaluation | ✗ in current project deps [VERIFIED: mix.exs, mix.lock, `rg tzdata`] | — | None if ORCH-02 must support non-UTC recipients. [VERIFIED: mix.exs, mix.lock][CITED: https://hexdocs.pm/elixir/1.12/DateTime.html] |

**Missing dependencies with no fallback:**
- `tzdata` or an equivalent configured `Calendar.TimeZoneDatabase` implementation is required for correct non-UTC window evaluation. [CITED: https://hexdocs.pm/elixir/1.12/DateTime.html][CITED: https://hexdocs.pm/tzdata/Tzdata.TimeZoneDatabase.html]

**Missing dependencies with fallback:**
- None for ORCH-02. UTC-only behavior would contradict the requirement. [VERIFIED: .planning/REQUIREMENTS.md][CITED: https://hexdocs.pm/elixir/1.12/DateTime.html]

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit with `Chimeway.DataCase` and `Oban.Testing`. [VERIFIED: test/chimeway/policy_settings_test.exs, test/chimeway/dispatch/oban_test.exs] |
| Config file | `mix.exs` aliases plus existing `test/` tree; no standalone test runner config file detected in the required reads. [VERIFIED: mix.exs, test directory grep] |
| Quick run command | `mix test test/chimeway/policy_settings_test.exs test/chimeway/policy_test.exs test/chimeway/traces_test.exs` [VERIFIED: existing test file layout] |
| Full suite command | `mix test` [VERIFIED: mix.exs] |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ORCH-01 | Planner persists `ready`, `deferred`, or `digest_held` without duplicate delivery rows | integration | `mix test test/chimeway/orchestration/delivery_planning_test.exs -x` | ❌ Wave 0 [VERIFIED: current test tree grep] |
| ORCH-01 | Oban/Sync skip deferred and digest-held rows during Phase 17 | integration | `mix test test/chimeway/orchestration/dispatch_gating_test.exs -x` | ❌ Wave 0 [VERIFIED: current test tree grep] |
| ORCH-02 | Deferral explanation persists rule, timezone, and `next_eligible_at` in traces | integration | `mix test test/chimeway/orchestration/traces_deferral_test.exs test/chimeway/policy_test.exs -x` | ❌ Wave 0 [VERIFIED: current test tree grep] |
| ORCH-02 | DST edge cases compute the correct next eligible time | unit/integration | `mix test test/chimeway/orchestration/window_math_test.exs -x` | ❌ Wave 0 [VERIFIED: current test tree grep] |

### Sampling Rate
- **Per task commit:** `mix test test/chimeway/policy_settings_test.exs test/chimeway/policy_test.exs test/chimeway/traces_test.exs`
- **Per wave merge:** `mix test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/chimeway/orchestration/delivery_planning_test.exs` — covers ORCH-01 planning disposition persistence and idempotent re-entry.
- [ ] `test/chimeway/orchestration/dispatch_gating_test.exs` — proves Sync and Oban do not execute deferred/digest-held rows.
- [ ] `test/chimeway/orchestration/traces_deferral_test.exs` — proves `Traces.explain_delivery/2` surfaces deferred facts.
- [ ] `test/chimeway/orchestration/window_math_test.exs` — covers recipient timezone, DST gap, and DST ambiguity cases.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Host application remains owner of auth context; Chimeway should not infer user identity beyond persisted recipient IDs. [VERIFIED: .planning/PROJECT.md] |
| V3 Session Management | no | No session mechanism is introduced in Phase 17. [VERIFIED: phase scope] |
| V4 Access Control | yes | Preserve tenancy-aware trace/query boundaries and avoid introducing cross-recipient scheduling lookups outside existing host-owned recipient IDs. [VERIFIED: .planning/PROJECT.md, .planning/STATE.md, lib/chimeway/traces.ex] |
| V5 Input Validation | yes | Validate timezone strings, window minutes, and planning option enums through Ecto changesets and option validation. [VERIFIED: lib/chimeway/policy/settings/setting.ex, mix.exs][CITED: https://hexdocs.pm/elixir/Calendar.TimeZoneDatabase.html] |
| V6 Cryptography | no | No new cryptographic primitive is required in this phase. [VERIFIED: phase scope] |

### Known Threat Patterns for This Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Invalid or hostile timezone identifiers causing crashes or bad scheduling | Tampering / DoS | Validate against configured timezone database and fail changesets early. [CITED: https://hexdocs.pm/elixir/1.12/DateTime.html][CITED: https://hexdocs.pm/elixir/Calendar.TimeZoneDatabase.html] |
| Sensitive planning context leaking into telemetry or traces | Information Disclosure | Reuse the project’s existing metadata sanitization discipline and keep redaction expectations on planning context payloads. [VERIFIED: lib/chimeway/deliveries.ex, lib/chimeway/trigger.ex, .planning/PROJECT.md] |
| Cross-recipient query mistakes in deferred resume lookups | Elevation of Privilege | Keep delivery rows keyed to existing notification/event ownership and let host app remain source of truth for tenancy boundaries. [VERIFIED: .planning/PROJECT.md, lib/chimeway/trigger.ex, lib/chimeway/traces.ex] |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | A new planner return shape such as `{:defer, map}` / `{:digest, map}` is the cleanest fit for current policy/planning flow. [ASSUMED] | Architecture Patterns | Low to medium; callback naming can change, but the need for a non-suppressive planning decision remains. |
| A2 | `orchestration_state`, `planning_reason`, `planning_context`, and `next_eligible_at` are the right explicit column set for Phase 17. [ASSUMED] | Pattern 1 | Medium; exact column names may change, but explicit queryable planning fields are still needed. |
| A3 | A dedicated delivery-plan table is unnecessary for this phase. [ASSUMED] | Summary / Pattern 1 | Medium; if later requirements need multiple planning revisions per delivery, a separate audit table may be added later. |

## Sources

### Primary (HIGH confidence)
- Local code: `lib/chimeway/delivery.ex`, `lib/chimeway/deliveries.ex`, `lib/chimeway/delivery_planning.ex`, `lib/chimeway/policy.ex`, `lib/chimeway/policy/settings.ex`, `lib/chimeway/traces.ex`, `lib/chimeway/dispatch/oban.ex`, `lib/chimeway/dispatch/oban_worker.ex`. [VERIFIED: codebase grep]
- Local tests: `test/chimeway/policy_settings_test.exs`, `test/chimeway/policy_test.exs`, `test/chimeway/policy/delayed_fallback_test.exs`, `test/chimeway/trigger_pipeline_test.exs`, `test/chimeway/traces_test.exs`, `test/chimeway/reliability/duplicate_protection_test.exs`, `test/chimeway/integration/delivery_lifecycle_test.exs`. [VERIFIED: codebase grep]
- Local planning docs: `.planning/PROJECT.md`, `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`, `.planning/STATE.md`. [VERIFIED: required reads]

### Secondary (MEDIUM confidence)
- Oban `Oban.Job` docs for `scheduled_at`, `schedule_in`, and scheduled job lifecycle: https://hexdocs.pm/oban/Oban.Job.html [CITED]
- Elixir `DateTime` docs for timezone database requirements and `shift_zone/3`: https://hexdocs.pm/elixir/1.12/DateTime.html [CITED]
- Elixir `Calendar.TimeZoneDatabase` docs for ambiguity/gap semantics: https://hexdocs.pm/elixir/Calendar.TimeZoneDatabase.html [CITED]
- `tzdata` docs: https://hexdocs.pm/tzdata/Tzdata.TimeZoneDatabase.html [CITED]
- Hex package pages for version verification: https://hex.pm/packages/oban, https://hex.pm/packages/ecto/versions, https://hex.pm/packages/tzdata [VERIFIED]

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - existing project dependencies and the needed timezone addition were verified from lockfile, package pages, and official docs. [VERIFIED: mix.lock][CITED: https://hex.pm/packages/tzdata]
- Architecture: HIGH - recommendations align directly with current trigger/planning/dispatch/trace contracts and roadmap boundaries. [VERIFIED: lib/chimeway/trigger.ex, lib/chimeway/delivery_planning.ex, lib/chimeway/traces.ex, .planning/ROADMAP.md]
- Pitfalls: HIGH - each pitfall maps to a current code path or official time/scheduling behavior. [VERIFIED: lib/chimeway/policy/settings.ex, lib/chimeway/dispatch/oban.ex][CITED: https://hexdocs.pm/elixir/1.12/DateTime.html]

**Research date:** 2026-04-28 [VERIFIED: user prompt]
**Valid until:** 2026-05-28 for codebase-grounded findings; revisit sooner if the dependency stack or roadmap changes. [VERIFIED: current phase scope][ASSUMED]
