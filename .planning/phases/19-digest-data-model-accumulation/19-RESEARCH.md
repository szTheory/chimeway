# Phase 19: Digest Data Model & Accumulation - Research

**Researched:** 2026-04-28 [VERIFIED: system date]
**Domain:** Durable digest persistence, accumulation, and idempotent orchestration on Ecto/PostgreSQL [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]
**Confidence:** HIGH [VERIFIED: codebase grep] / MEDIUM on exact schema naming discretion [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]

<user_constraints>
## User Constraints (from CONTEXT.md)

Copied from `.planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md` with no scope changes. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]

### Locked Decisions
- **D-01:** Phase 19 should introduce three first-class digest artifacts: `digest_rules`, `digest_buckets`, and `digest_memberships`. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]
- **D-02:** The existing `chimeway_deliveries` row remains the canonical source work item; digest accumulation must reference held source deliveries rather than replacing them or creating a parallel delivery identity model. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]
- **D-03:** `digest_memberships` must be an explicit schema, not an opaque JSON field or anonymous join table, because membership carries business meaning and must remain auditable. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]
- **D-04:** Digest rules must use stable, durable identities separate from notifier module names, consistent with Chimeway's existing `notification_key` + version posture. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]
- **D-05:** Bucket identity should be scoped by rule, recipient, channel, grouping value, and window so cross-channel fanout semantics remain correct. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]
- **D-06:** Phase 19 should support grouping by recipient plus one of: `notification_key`, category, or an explicit host-provided digest key. If grouping by category, the resolved category value must be snapshotted durably rather than re-derived later from mutable payload shape. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]
- **D-07:** Accumulation should happen only after planning settles on a delivery that is still `status == :pending` and `orchestration_state == :digest_held`; suppressed or immediate work must not leak into digest buckets. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]
- **D-08:** Idempotency must be enforced at the database layer using durable bucket identity plus a unique membership boundary on source `delivery_id`, not by relying on Oban uniqueness or trigger-call timing. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]
- **D-09:** Accumulation writes should use targeted upserts and transactional boundaries that keep source delivery state, bucket creation/update, and membership insertion coherent under retries. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]
- **D-10:** Phase 19 should establish durable window metadata on digest buckets, but keep the initial strategy set intentionally small: fixed-duration windows and scheduled boundary windows are enough to support the milestone without turning Chimeway into a workflow engine. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]
- **D-11:** Digest windowing must be modeled independently from deferred-delivery `next_eligible_at`; quiet-hours deferral and digest accumulation are separate orchestration concepts. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]
- **D-12:** Sliding windows, nested digests, generalized workflow graphs, and centralized orchestration DSLs are deferred; they add surprise and complexity faster than value for the current milestone. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]
- **D-13:** Digest persistence must snapshot the facts Phase 20 will need for exact explanation: rule identity, grouping value, channel, recipient scope, window boundaries, and source-delivery membership. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]
- **D-14:** Oban remains an optional downstream execution seam, not the source of truth for digest state. Durable digest facts must stay queryable even in host apps that do not rely on Oban. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]
- **D-15:** The design should favor embedded-library ergonomics over SaaS-style workflow abstraction: explicit schemas, predictable keys, test/null seams, preview-friendly data, and least-surprise behavior for host developers. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]
- **D-16:** Default project posture should be cohesive and opinionated: planning/research agents should converge on a recommended design unless a fork is unusually high-impact, hard to reverse, or product-defining. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]

### Claude's Discretion
- Exact schema/module names for digest artifacts. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]
- Exact column naming for rule identity, grouping value, and window fields. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]
- Whether accumulation orchestration is expressed primarily through `Ecto.Multi` or smaller `Repo.transact/1` helpers, as long as transactional invariants remain explicit and testable. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]
- Exact preview/test helper API shape, provided it follows the embedded-library and explainability posture above. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]

### Deferred Ideas (OUT OF SCOPE)
- Sliding-window and “flush first item immediately, then batch the rest” strategies. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]
- Nested or multi-stage digests. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]
- Centralized workflow/DAG orchestration similar to hosted notification platforms. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]
- Full operator-facing inclusion/exclusion explanation surfaces and digest emission lifecycle; these belong to Phase 20. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]
- Cross-phase unread/escalation UX beyond the current phase boundary, even though the future design should stay compatible with it. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DIGEST-01 | Teams can define digest rules that group repeated notifications by recipient, notification key or category, and delivery window. [VERIFIED: .planning/REQUIREMENTS.md] | Use first-class `digest_rules` plus durable `digest_buckets` and `digest_memberships`, with grouping dimensions persisted as rule columns and bucket identity keys. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md] |
</phase_requirements>

## Project Constraints (from AGENTS.md)

- Persist stable `notification_key` + version and never use module names as durable identity. [VERIFIED: AGENTS.md]
- Keep the durable lifecycle spine `event -> notification -> delivery -> attempt`; this phase may extend that spine with linked digest tables but must not replace it. [VERIFIED: AGENTS.md]
- Treat idempotency and suppression reasons as first-class product behavior. [VERIFIED: AGENTS.md]
- Keep adapters replaceable and preserve host ownership boundaries for auth, tenancy, URL generation, and correlation IDs. [VERIFIED: AGENTS.md]
- Maintain `mix verify.*` and `mix ci.*` parity and avoid leaking sensitive payload fields in telemetry or operator surfaces. [VERIFIED: AGENTS.md]

## Summary

Phase 19 should be planned as a pure backend/data-layer extension of the existing planning pipeline, not as a new dispatch subsystem. The current code already keeps one canonical `chimeway_deliveries` row per `(notification_id, channel)`, persists digest intent as `orchestration_state: :digest_held`, and gates execution on `:ready`; that means accumulation belongs immediately after the canonical delivery row has been planned and policy-checked, while the row is still `status: :pending` and `orchestration_state: :digest_held`. [VERIFIED: lib/chimeway/deliveries.ex] [VERIFIED: lib/chimeway/delivery_planning.ex] [VERIFIED: lib/chimeway/delivery.ex] [VERIFIED: test/chimeway/orchestration/planning_declarations_test.exs] [VERIFIED: test/chimeway/orchestration/dispatch_gating_test.exs]

The planner should assume three explicit Postgres-backed schemas: one for rules, one for buckets, and one for memberships. That direction is locked by context, matches Ecto’s guidance to use a join schema when the relationship itself has fields or business meaning, and fits Chimeway’s explainability posture better than JSON blobs or anonymous join tables. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md] [CITED: https://hexdocs.pm/ecto/Ecto.Schema.html] [CITED: https://hexdocs.pm/ecto/Ecto.Schema.html#module-migration]

The critical planning insight is that idempotency for this phase must live in the database, not in Oban job uniqueness. Oban’s own docs explicitly state that unique jobs do not rely on database unique constraints and can still race in some circumstances, while PostgreSQL `ON CONFLICT` and Ecto upserts are the right primitives for bucket creation and membership insertion under retries. [CITED: https://hexdocs.pm/oban/unique_jobs.html] [CITED: https://www.postgresql.org/docs/current/sql-insert.html] [CITED: https://hexdocs.pm/ecto/constraints-and-upserts.html]

**Primary recommendation:** Use explicit Ecto schemas plus Postgres unique indexes and targeted upserts, and hook accumulation into `Chimeway.DeliveryPlanning` only after the canonical delivery remains pending and `:digest_held`. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md] [VERIFIED: lib/chimeway/delivery_planning.ex]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Digest rule declaration and validation | API / Backend [ASSUMED] | Database / Storage [ASSUMED] | Rules are configured and validated in Elixir, then persisted durably for later planning and emission. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md] |
| Bucket identity, window metadata, and membership storage | Database / Storage [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md] | API / Backend [ASSUMED] | Idempotency is explicitly required at the database layer and bucket identity is defined as durable data. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md] |
| Accumulation during notification planning | API / Backend [VERIFIED: lib/chimeway/delivery_planning.ex] | Database / Storage [VERIFIED: lib/chimeway/deliveries.ex] | The planning pipeline already resolves orchestration and policy in backend code, then persists results through repo writes. [VERIFIED: lib/chimeway/delivery_planning.ex] [VERIFIED: lib/chimeway/deliveries.ex] |
| Explainable future digest inspection | Database / Storage [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md] | API / Backend [VERIFIED: lib/chimeway/traces.ex] | Phase 19 must snapshot facts Phase 20 explanation will need, and current trace surfaces already read durable rows instead of queue state. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md] [VERIFIED: lib/chimeway/traces.ex] |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `ecto` | `3.13.5` locked and current on Hex as of 2026-04-28. [VERIFIED: mix deps] [VERIFIED: https://hex.pm/packages/ecto_sql] | Schema modeling, changesets, query composition, and `Repo.transact/1` transaction boundaries. [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html] [CITED: https://hexdocs.pm/ecto/Ecto.Multi.html] | The codebase already uses Ecto everywhere for durable lifecycle storage, and current docs recommend `Repo.transact/1` with `Ecto.Multi` reserved for dynamic operation sets. [VERIFIED: mix.exs] [CITED: https://hexdocs.pm/ecto/Ecto.Multi.html] |
| `ecto_sql` | `3.13.5` locked and current on Hex, released 2026-03-03. [VERIFIED: mix deps] [VERIFIED: https://hex.pm/packages/ecto_sql] | Migrations and SQL-backed repo behavior for new digest tables and indexes. [VERIFIED: mix.exs] | This phase is fundamentally a migration/index/upsert phase, so `ecto_sql` remains the canonical migration tool with no need for an additional persistence library. [VERIFIED: mix.exs] |
| `postgrex` | `0.22.0` locked in the project and the current stable Hex package version page on 2026-04-28. [VERIFIED: mix deps] [VERIFIED: https://hex.pm/packages/postgrex] | PostgreSQL adapter backing `ON CONFLICT`, unique indexes, and transactional writes. [VERIFIED: mix.exs] [CITED: https://www.postgresql.org/docs/current/sql-insert.html] | The phase’s idempotency guarantees depend on PostgreSQL uniqueness and upsert semantics rather than queue-level dedupe. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md] [CITED: https://www.postgresql.org/docs/current/sql-insert.html] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `oban` | `2.21.1` locked in the project; `2.22.0` is current on Hex as of 2026-04-28. [VERIFIED: mix deps] [VERIFIED: https://hex.pm/packages/oban] | Optional downstream execution seam for later digest flush jobs, not the source of truth for accumulation. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md] | Keep Oban out of Phase 19 persistence invariants except where future flush scheduling needs a seam. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md] |
| `tzdata` | `1.1.3` locked and current on Hex as of 2026-04-28. [VERIFIED: mix deps] [VERIFIED: https://hex.pm/packages/tzdata] | Time zone support for scheduled boundary windows if rules need local boundary interpretation. [VERIFIED: mix.exs] | Use when the chosen scheduled boundary strategy must compute `window_start_at` and `window_end_at` in recipient or rule time zones. [ASSUMED] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Explicit `digest_memberships` schema with timestamps and business fields. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md] | Bare `many_to_many` join table or JSON array on bucket rows. [ASSUMED] | Ecto docs treat explicit join schemas as the right fit when the relationship needs fields, timestamps, or direct access; that matches Chimeway’s auditability requirement. [CITED: https://hexdocs.pm/ecto/Ecto.Schema.html] |
| DB unique indexes plus `ON CONFLICT` upserts. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md] | Oban unique jobs or in-memory dedupe. [ASSUMED] | Oban uniqueness is helpful for enqueue dedupe but does not provide strong DB-level guarantees for this phase’s accumulation records. [CITED: https://hexdocs.pm/oban/unique_jobs.html] |
| Small `Repo.transact/1` helpers around accumulation steps. [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html] | Large unconditional `Ecto.Multi` chains for every write path. [ASSUMED] | Ecto docs say `Ecto.Multi` is especially useful when operations are dynamic; otherwise normal control flow inside `Repo.transact/1` is more straightforward. [CITED: https://hexdocs.pm/ecto/Ecto.Multi.html] |

**Installation:** No new dependency is required for Phase 19; use the existing stack and run `mix deps.get` only if the lockfile changes for unrelated reasons. [VERIFIED: mix.exs] [VERIFIED: mix.lock]

**Version verification:** `mix deps` shows `ecto 3.13.5`, `ecto_sql 3.13.5`, `postgrex 0.22.0`, `oban 2.21.1`, and `tzdata 1.1.3` in the current project lock. Hex package pages confirm current releases for `ecto_sql 3.13.5` (2026-03-03), `postgrex 0.22.0` (2026-01-10), `oban 2.22.0` (2026-04-28), `tzdata 1.1.3` (2025-03-06), and `phoenix 1.8.5` (2026-03-05). Phase 19 does not require a version bump to implement DIGEST-01. [VERIFIED: mix deps] [VERIFIED: https://hex.pm/packages/ecto_sql] [VERIFIED: https://hex.pm/packages/postgrex] [VERIFIED: https://hex.pm/packages/oban] [VERIFIED: https://hex.pm/packages/tzdata] [VERIFIED: https://hex.pm/packages/phoenix]

## Architecture Patterns

### System Architecture Diagram

```text
Notifier orchestration / planner override
            |
            v
DeliveryPlanning.plan_notification/2
            |
            v
Canonical chimeway_deliveries row upsert
            |
            v
Apply declared orchestration + planning policy
            |
            +--> immediate or suppressed -> existing path only
            |
            v
pending + digest_held?
            |
            +--> no -> return canonical delivery unchanged
            |
            v
Resolve digest rule for recipient/channel/grouping/window
            |
            v
Repo.transact/1 or Ecto.Multi transaction
            |
            +--> upsert digest_bucket on durable identity
            |
            +--> insert digest_membership on unique delivery_id
            |
            +--> update bucket counters / last_accumulated_at
            |
            v
Return canonical delivery + durable digest facts for later Phase 20 flush/explain
```

The architecture keeps `chimeway_deliveries` as the source work item and adds digest tables as linked aggregates, which matches the locked context and current row-centric trace model. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md] [VERIFIED: lib/chimeway/traces.ex]

### Recommended Project Structure

```text
lib/chimeway/digests/
├── digest_rule.ex          # rule schema + changeset + durable identity helpers
├── digest_bucket.ex        # bucket schema + unique identity helpers + counters
├── digest_membership.ex    # explicit membership schema linking source delivery_id
└── accumulation.ex         # transactional accumulation entry point used by planning

priv/repo/migrations/
├── *_create_chimeway_digest_rules.exs
├── *_create_chimeway_digest_buckets.exs
└── *_create_chimeway_digest_memberships.exs

test/chimeway/digests/
├── digest_rule_test.exs
├── digest_bucket_test.exs
└── accumulation_test.exs
```

This structure mirrors the existing explicit context/module layout and keeps the phase localized to backend schemas, migrations, and orchestration helpers. [VERIFIED: lib/chimeway] [VERIFIED: priv/repo/migrations] [VERIFIED: test]

### Pattern 1: Explicit Join Schema for Membership
**What:** Model `digest_memberships` as a full schema with its own primary key, timestamps, foreign keys, and any future explanation fields. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]
**When to use:** Whenever the relationship between a bucket and a source delivery has business meaning, audit value, or future lifecycle data. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]
**Example:**
```elixir
# Source: https://hexdocs.pm/ecto/Ecto.Schema.html
create table(:posts_tags) do
  add :post_id, references(:posts, on_delete: :delete_all), null: false
  add :tag_id, references(:tags, on_delete: :delete_all), null: false
  timestamps()
end
```

### Pattern 2: Targeted Upsert for Bucket Creation
**What:** Use `INSERT ... ON CONFLICT` through Ecto to create-or-update digest buckets on a composite unique identity. [CITED: https://www.postgresql.org/docs/current/sql-insert.html] [CITED: https://hexdocs.pm/ecto/constraints-and-upserts.html]
**When to use:** On every accumulation attempt after a delivery is still pending and `:digest_held`. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]
**Example:**
```elixir
# Source: https://hexdocs.pm/ecto/constraints-and-upserts.html
Repo.insert!(
  %MyApp.Tag{name: name},
  on_conflict: [set: [name: name]],
  conflict_target: :name
)
```

### Pattern 3: Transaction Helper First, Multi When Operations Are Dynamic
**What:** Express accumulation as a transaction boundary that may use either `Repo.transact/1` or `Ecto.Multi`, but prefer `Repo.transact/1` if the operation list is small and fixed. [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html] [CITED: https://hexdocs.pm/ecto/Ecto.Multi.html]
**When to use:** The planner can choose smaller helper functions for deterministic writes, and reserve `Ecto.Multi` for cases where rule-dependent steps make the operation set dynamic. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md] [CITED: https://hexdocs.pm/ecto/Ecto.Multi.html]
**Example:**
```elixir
# Source: https://hexdocs.pm/ecto/Ecto.Repo.html
Repo.transact(fn ->
  # bucket upsert
  # membership insert
  # counter update
  {:ok, :done}
end)
```

### Anti-Patterns to Avoid
- **Opaque JSON membership storage:** It violates the locked explicit-schema requirement and makes exact inclusion audits harder. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]
- **Using Oban uniqueness as the only dedupe layer:** Oban docs explicitly call out race-window limitations for uniqueness. [CITED: https://hexdocs.pm/oban/unique_jobs.html]
- **Re-deriving category grouping at flush time:** Current category data is derived from event payload at runtime, so grouping-by-category must snapshot the resolved category during accumulation. [VERIFIED: lib/chimeway/policy.ex] [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]
- **Overloading `next_eligible_at` for digest windows:** Context explicitly separates deferred-delivery timing from digest window timing. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Strict accumulation idempotency | Custom in-memory lock registry or job-level dedupe only. [ASSUMED] | Postgres unique indexes plus `ON CONFLICT` and Ecto upsert APIs. [CITED: https://www.postgresql.org/docs/current/sql-insert.html] [CITED: https://hexdocs.pm/ecto/constraints-and-upserts.html] | The database already arbitrates concurrent writers atomically; job uniqueness does not give the same guarantee. [CITED: https://hexdocs.pm/oban/unique_jobs.html] |
| Membership relationship storage | Anonymous join table or array/json membership field. [ASSUMED] | Explicit Ecto schema for `digest_memberships`. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md] | Membership itself is durable business data and will later need explanation fields. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md] |
| Workflow engine semantics | Generic DAG/workflow DSL for windows and branching. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md] | Fixed-duration and scheduled-boundary windows only. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md] | The phase explicitly defers workflow-engine complexity. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md] |

**Key insight:** The hard part of this phase is not “batching logic”; it is durable identity, race-safe accumulation, and future explainability, all of which are better served by Postgres constraints and explicit schemas than by abstraction-heavy orchestration code. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md] [CITED: https://hexdocs.pm/oban/unique_jobs.html] [CITED: https://www.postgresql.org/docs/current/sql-insert.html]

## Common Pitfalls

### Pitfall 1: Accumulating before the canonical row is finalized
**What goes wrong:** Suppressed or immediate deliveries can leak into digest storage. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]
**Why it happens:** The current planning flow first creates the canonical delivery row, then applies orchestration and policy decisions; accumulation inserted too early will race ahead of those outcomes. [VERIFIED: lib/chimeway/delivery_planning.ex]
**How to avoid:** Hook accumulation only after the row remains `status: :pending` and `orchestration_state: :digest_held`. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]
**Warning signs:** Buckets contain deliveries whose final planning state is `:ready` or `:suppressed`. [ASSUMED]

### Pitfall 2: Using a join table that cannot carry explanation data
**What goes wrong:** Phase 20 will need a schema migration or rewrite just to explain why a delivery was included. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]
**Why it happens:** Developers treat membership like a dumb many-to-many instead of a first-class audit record. [CITED: https://hexdocs.pm/ecto/Ecto.Schema.html]
**How to avoid:** Start with `digest_memberships` as an explicit schema with timestamps and room for future inclusion/exclusion facts. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]
**Warning signs:** Membership data can only be queried through bucket JSON or anonymous Ecto joins. [ASSUMED]

### Pitfall 3: Letting bucket identity drift from the locked grouping dimensions
**What goes wrong:** Cross-channel or cross-window data can coalesce into the wrong digest bucket. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]
**Why it happens:** The uniqueness index omits `channel`, `window`, or the resolved grouping value. [ASSUMED]
**How to avoid:** Put the full durable identity in both schema columns and the unique index: rule, recipient, channel, grouping value, and window. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]
**Warning signs:** A single bucket contains sources from multiple channels or multiple window boundaries. [ASSUMED]

### Pitfall 4: Reusing deferred-delivery timing fields for digest windows
**What goes wrong:** Quiet-hours resume and digest flush semantics become entangled. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]
**Why it happens:** The code already has `next_eligible_at`, so it is tempting to overload it. [VERIFIED: lib/chimeway/delivery.ex]
**How to avoid:** Keep digest bucket window columns separate from delivery deferral columns. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]
**Warning signs:** Planner code reads or writes `next_eligible_at` while computing digest bucket boundaries. [ASSUMED]

### Pitfall 5: Leaking payload data into digest explanation storage
**What goes wrong:** Operator surfaces and telemetry may expose sensitive payload fields. [VERIFIED: AGENTS.md]
**Why it happens:** Current delivery traces sanitize `planning_context`, but a new digest table could accidentally snapshot raw payload or provider metadata. [VERIFIED: test/chimeway/orchestration/traces_deferral_test.exs] [VERIFIED: lib/chimeway/traces.ex]
**How to avoid:** Persist only stable grouping facts, rule identity, recipient scope, channel, and window metadata in digest tables. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]
**Warning signs:** Digest schemas contain free-form payload snapshots unrelated to grouping or explanation. [ASSUMED]

## Code Examples

Verified patterns from official sources:

### Upsert with explicit conflict target
```elixir
# Source: https://hexdocs.pm/ecto/constraints-and-upserts.html
Repo.insert!(
  %MyApp.Tag{name: name},
  on_conflict: [set: [name: name]],
  conflict_target: :name
)
```

### Execute transactional write orchestration
```elixir
# Source: https://hexdocs.pm/ecto/Ecto.Repo.html
Repo.transact(PasswordManager.reset(account, params))
```

### Full join schema migration when relationship carries its own fields
```elixir
# Source: https://hexdocs.pm/ecto/Ecto.Schema.html
create table(:posts_tags) do
  add :post_id, references(:posts, on_delete: :delete_all), null: false
  add :tag_id, references(:tags, on_delete: :delete_all), null: false
  timestamps()
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `Repo.transaction/2` as the common transaction entry point. [ASSUMED] | `Repo.transact/1` is the current Ecto API and `transaction/2` is documented as deprecated in Ecto `3.13.5`. [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html] | Present in current docs as of Ecto `3.13.5`. [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html] | New phase code should prefer `transact/1` in examples and helpers. [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html] |
| Anonymous `many_to_many` join table for pure linking. [CITED: https://hexdocs.pm/ecto/Ecto.Schema.html] | Explicit join schema when the relationship needs timestamps or direct access. [CITED: https://hexdocs.pm/ecto/Ecto.Schema.html] | Present in current docs as of Ecto `3.13.5`. [CITED: https://hexdocs.pm/ecto/Ecto.Schema.html] | `digest_memberships` should be a full schema from the start. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md] |
| Queue-layer dedupe as the primary anti-duplication strategy. [ASSUMED] | DB-backed unique indexes and upserts for durable race-safe accumulation. [CITED: https://hexdocs.pm/oban/unique_jobs.html] [CITED: https://www.postgresql.org/docs/current/sql-insert.html] | Current Oban docs still describe uniqueness as non-constraint-based in `2.22.0`. [CITED: https://hexdocs.pm/oban/unique_jobs.html] | Planner should treat Oban uniqueness as optional queue hygiene, not product truth. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md] |

**Deprecated/outdated:**
- Relying on `Repo.transaction/2` in new examples is outdated relative to the current Ecto docs, which document `transaction/2` as deprecated and `transact/1` as the preferred API. [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html]
- Treating digest membership as an opaque join table is outdated for this phase because the locked design requires auditable membership and future explanation fields. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Scheduled boundary windows may need explicit time zone columns or rule-level time zone metadata in addition to UTC `window_start_at/window_end_at`. [ASSUMED] | Standard Stack / Architecture Patterns | Medium; planner could under-spec window columns and need a corrective migration in Phase 20. |
| A2 | The cleanest module layout is a dedicated `lib/chimeway/digests/` namespace rather than extending `Deliveries` directly. [ASSUMED] | Recommended Project Structure | Low; naming/layout can change without altering the core persistence design. |
| A3 | A fixed set of bucket counters such as `member_count`, `first_accumulated_at`, and `last_accumulated_at` is sufficient for Phase 19 even before flush logic exists. [ASSUMED] | Architecture Patterns | Medium; planner may need to adjust bucket fields once Phase 20 emission tasks are decomposed. |

## Open Questions

1. **Should rule identity be split into `digest_key` plus `version`, or should one stable `rule_key` column carry the durable identity?**
   - What we know: The phase must avoid notifier module names and stay consistent with `notification_key` + version posture. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md] [VERIFIED: AGENTS.md]
   - What's unclear: The exact column naming is explicitly left to agent discretion. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]
   - Recommendation: Prefer `rule_key` plus integer `rule_version` because it mirrors current notification identity and makes bucket identity and future trace displays simpler. [ASSUMED]

2. **Should category grouping snapshot live only on the bucket, or also on each membership?**
   - What we know: Category currently resolves from event payload at runtime, and the chosen category value must be snapshotted durably. [VERIFIED: lib/chimeway/policy.ex] [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]
   - What's unclear: Phase 19 scope does not force duplication vs normalization. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]
   - Recommendation: Snapshot grouping value on the bucket as the primary identity field, and copy it to membership only if planner wants future single-row explanation queries without joining buckets. [ASSUMED]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | Mix tasks, tests, migrations, phase implementation. [VERIFIED: mix.exs] | ✓ [VERIFIED: `elixir --version`] | `1.19.5` locally, which exceeds the project baseline `~> 1.17`. [VERIFIED: `elixir --version`] [VERIFIED: mix.exs] | — |
| Mix | Test and migration execution. [VERIFIED: mix.exs] | ✓ [VERIFIED: `mix --version`] | `1.19.5`. [VERIFIED: `mix --version`] | — |
| PostgreSQL server | Digest tables, indexes, and transactional upserts. [VERIFIED: mix.exs] | ✓ [VERIFIED: `pg_isready`] | `14.17` locally. [VERIFIED: `SHOW server_version`] | Validate on PostgreSQL `15+` before release because the project target is `15+`. [VERIFIED: AGENTS.md] |

**Missing dependencies with no fallback:**
- None for planning or local research. [VERIFIED: `elixir --version`] [VERIFIED: `pg_isready`]

**Missing dependencies with fallback:**
- PostgreSQL is available locally, but the local server is one major version below the project target; the practical fallback is to keep planning on local `14.17` and require at least one CI or container validation run on `15+` before implementation is considered phase-complete. [VERIFIED: `SHOW server_version`] [VERIFIED: AGENTS.md]

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit via `mix test`, with Ecto SQL sandbox DataCase patterns and manual Oban testing where needed. [VERIFIED: config/test.exs] [VERIFIED: test/support/data_case.ex] [VERIFIED: test/test_helper.exs] |
| Config file | `config/test.exs`. [VERIFIED: config/test.exs] |
| Quick run command | `mix test test/chimeway/orchestration/planning_declarations_test.exs test/chimeway/orchestration/delivery_planning_test.exs test/chimeway/orchestration/dispatch_gating_test.exs test/chimeway/orchestration/traces_deferral_test.exs --trace`. [VERIFIED: test/chimeway/orchestration/planning_declarations_test.exs] [VERIFIED: test/chimeway/orchestration/delivery_planning_test.exs] [VERIFIED: test/chimeway/orchestration/dispatch_gating_test.exs] [VERIFIED: test/chimeway/orchestration/traces_deferral_test.exs] |
| Full suite command | `mix test` and project parity gate `mix ci.test`. [VERIFIED: mix.exs] |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DIGEST-01 | Rule declaration persists durable grouping/window identity and accumulation creates one bucket membership per held source delivery under retries. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md] | unit + integration [ASSUMED] | `mix test test/chimeway/digests/digest_rule_test.exs test/chimeway/digests/accumulation_test.exs test/chimeway/orchestration/delivery_planning_test.exs --trace`. [ASSUMED] | ❌ Wave 0. [VERIFIED: test] |

### Sampling Rate
- **Per task commit:** Run the targeted digest/orchestration subset above. [ASSUMED]
- **Per wave merge:** Run `mix ci.test`. [VERIFIED: mix.exs]
- **Phase gate:** Run `mix test` before `/gsd-verify-work`. [VERIFIED: mix.exs]

### Wave 0 Gaps
- [ ] `test/chimeway/digests/digest_rule_test.exs` — lock rule identity, grouping-mode validation, and migration constraints for DIGEST-01. [ASSUMED]
- [ ] `test/chimeway/digests/digest_bucket_test.exs` — lock composite bucket identity and window-boundary uniqueness. [ASSUMED]
- [ ] `test/chimeway/digests/accumulation_test.exs` — prove retries and duplicate planning create one membership per source `delivery_id`. [ASSUMED]
- [ ] Extend `test/chimeway/orchestration/delivery_planning_test.exs` — prove accumulation happens only after the canonical delivery remains pending and `:digest_held`. [VERIFIED: test/chimeway/orchestration/delivery_planning_test.exs] [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]

## Security Domain

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no [ASSUMED] | Host app owns auth boundaries; this phase does not add authentication logic. [VERIFIED: AGENTS.md] |
| V3 Session Management | no [ASSUMED] | Not applicable to Chimeway’s persistence layer phase. [ASSUMED] |
| V4 Access Control | yes [ASSUMED] | Keep recipient/channel/rule scope explicit in bucket identity so data cannot bleed across tenants or channels accidentally. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md] |
| V5 Input Validation | yes [ASSUMED] | Ecto changesets and enum/column validation for rule mode, grouping strategy, and window strategy. [CITED: https://hexdocs.pm/ecto/Ecto.Schema.html] |
| V6 Cryptography | no [ASSUMED] | No cryptographic primitive is introduced in this phase. [ASSUMED] |

### Known Threat Patterns for this stack
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Duplicate accumulation under concurrent planning retries. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md] | Tampering [ASSUMED] | Composite unique bucket identity plus unique membership on `delivery_id`, enforced with Postgres and `ON CONFLICT`. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md] [CITED: https://www.postgresql.org/docs/current/sql-insert.html] |
| Cross-recipient or cross-channel digest bleed. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md] | Information Disclosure [ASSUMED] | Include recipient scope and channel in the bucket arbiter key and never infer them from later queue state. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md] |
| Sensitive payload leakage into operator surfaces. [VERIFIED: AGENTS.md] | Information Disclosure [ASSUMED] | Snapshot only stable digest facts and follow the existing trace sanitization posture. [VERIFIED: test/chimeway/orchestration/traces_deferral_test.exs] [VERIFIED: lib/chimeway/traces.ex] |
| Raw SQL or ad hoc query construction around upserts. [ASSUMED] | Tampering [ASSUMED] | Stay inside Ecto query and upsert APIs unless a migration requires database-native DDL. [CITED: https://hexdocs.pm/ecto/constraints-and-upserts.html] [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html] |

## Sources

### Primary (HIGH confidence)
- `.planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md` - locked phase decisions, scope, and deferred ideas. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]
- `.planning/REQUIREMENTS.md` - `DIGEST-01` requirement boundary. [VERIFIED: .planning/REQUIREMENTS.md]
- `.planning/STATE.md` - carried-forward orchestration decisions and current milestone status. [VERIFIED: .planning/STATE.md]
- `AGENTS.md` - project constraints and quality gates. [VERIFIED: AGENTS.md]
- `lib/chimeway/delivery_planning.ex` - current planning hook and digest-held persistence path. [VERIFIED: lib/chimeway/delivery_planning.ex]
- `lib/chimeway/deliveries.ex` - canonical delivery upsert and current transaction/update patterns. [VERIFIED: lib/chimeway/deliveries.ex]
- `lib/chimeway/delivery.ex` - canonical delivery schema and orchestration fields. [VERIFIED: lib/chimeway/delivery.ex]
- `lib/chimeway/policy.ex` - current runtime category derivation behavior. [VERIFIED: lib/chimeway/policy.ex]
- `lib/chimeway/traces.ex` and digest-related orchestration tests - current explainability posture and held-row invariants. [VERIFIED: lib/chimeway/traces.ex] [VERIFIED: test/chimeway/orchestration/planning_declarations_test.exs] [VERIFIED: test/chimeway/orchestration/dispatch_gating_test.exs] [VERIFIED: test/chimeway/orchestration/traces_deferral_test.exs]
- Ecto docs: `Ecto.Repo`, `Ecto.Multi`, `Ecto.Schema`, and `Constraints and Upserts`. [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html] [CITED: https://hexdocs.pm/ecto/Ecto.Multi.html] [CITED: https://hexdocs.pm/ecto/Ecto.Schema.html] [CITED: https://hexdocs.pm/ecto/constraints-and-upserts.html]
- Oban unique jobs guide. [CITED: https://hexdocs.pm/oban/unique_jobs.html]
- PostgreSQL current `INSERT` docs. [CITED: https://www.postgresql.org/docs/current/sql-insert.html]

### Secondary (MEDIUM confidence)
- Hex package pages for current release/version verification: `ecto_sql`, `postgrex`, `oban`, `tzdata`, `phoenix`. [VERIFIED: https://hex.pm/packages/ecto_sql] [VERIFIED: https://hex.pm/packages/postgrex] [VERIFIED: https://hex.pm/packages/oban] [VERIFIED: https://hex.pm/packages/tzdata] [VERIFIED: https://hex.pm/packages/phoenix]

### Tertiary (LOW confidence)
- None. [VERIFIED: research session review]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - the phase reuses the existing Ecto/PostgreSQL stack and current versions were verified from the lockfile plus Hex package pages. [VERIFIED: mix deps] [VERIFIED: https://hex.pm/packages/ecto_sql]
- Architecture: HIGH - the planning hook, canonical delivery model, and explainability posture are already explicit in code and locked context. [VERIFIED: lib/chimeway/delivery_planning.ex] [VERIFIED: lib/chimeway/deliveries.ex] [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md]
- Pitfalls: HIGH - the main failure modes are directly implied by locked decisions, current code behavior, and official Ecto/Oban/Postgres docs. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md] [CITED: https://hexdocs.pm/oban/unique_jobs.html] [CITED: https://www.postgresql.org/docs/current/sql-insert.html]

**Research date:** 2026-04-28 [VERIFIED: system date]
**Valid until:** 2026-05-28 for codebase-specific guidance, with dependency/version checks worth refreshing sooner if the phase is delayed. [ASSUMED]
