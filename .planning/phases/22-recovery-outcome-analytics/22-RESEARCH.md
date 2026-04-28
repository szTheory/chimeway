# Phase 22: Recovery & Outcome Analytics - Research

**Researched:** 2026-04-28
**Domain:** Elixir/Ecto recovery orchestration and operator outcome aggregation over canonical delivery rows
**Confidence:** MEDIUM

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

### Reconciliation Mechanism
- **D-01:** Reconciliation will recover "stuck" deliveries by re-enqueuing them to the dispatcher and mutating the canonical delivery rows in place, without deleting or replacing them.

### Stuck Delivery Detection
- **D-02:** Detection of undispatched persisted deliveries will rely on querying Chimeway's schema state (e.g., `status == :pending` and `orchestration_state == :ready` past a safe time threshold) without interrogating the Oban queue.

### Aggregate Outcomes API
- **D-03:** Aggregate query capabilities will be implemented as new functions within `Chimeway.Traces` rather than introducing a separate top-level module (like `Chimeway.Analytics`).

### Outcome Aggregation Data Source
- **D-04:** Outcome analytics will aggregate directly over `chimeway_deliveries.status`, `chimeway_deliveries.orchestration_state`, and `chimeway_deliveries.suppression_reason` rather than traversing the `chimeway_delivery_attempts` history.

### Claude's Discretion
None.

### Deferred Ideas (OUT OF SCOPE)
None — analysis stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| OPS-01 | Operators can detect and reconcile persisted events or deliveries that were never fully dispatched after trigger-time failures. | Use canonical delivery-state scans plus guarded in-place row mutation and transactional dispatch re-handoff; do not use Oban tables as correctness truth. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html] [CITED: https://hexdocs.pm/ecto/Ecto.Multi.html] [CITED: https://hexdocs.pm/oban/unique_jobs.html] |
| OPS-02 | Operators can query aggregate outcomes by notification key, channel, and lifecycle result, including sent, suppressed, delayed, digested, failed, and exhausted flows. | Implement grouped aggregates in `Chimeway.Traces` over `chimeway_deliveries` with an explicit lifecycle-result projection derived from delivery fields, not attempt history. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/ecto/Ecto.Query.html] |
</phase_requirements>

## Project Constraints (from AGENTS.md)

- Persist stable `notification_key` plus version and never use module names as durable identity. [VERIFIED: codebase grep]
- Preserve the durable lifecycle spine `event -> notification -> delivery -> attempt`. [VERIFIED: codebase grep]
- Treat idempotency and suppression reasons as first-class behavior. [VERIFIED: codebase grep]
- Keep adapters replaceable with explicit behaviours and contract tests. [VERIFIED: codebase grep]
- Preserve host ownership boundaries for auth, tenancy, URL generation, and correlation IDs. [VERIFIED: codebase grep]
- Maintain `mix verify.*` and `mix ci.*` entrypoints with CI/local parity. [VERIFIED: codebase grep]
- Avoid leaking sensitive payload fields in telemetry and operator surfaces. [VERIFIED: codebase grep]

## Summary

Phase 22 should extend the existing canonical-row model rather than invent a recovery subsystem beside it. Chimeway already keeps durable business truth on `chimeway_deliveries`, already guards dispatch on `status` and `orchestration_state`, already resumes deferred rows with compare-and-swap style `update_all`, and already explains outcomes through `Chimeway.Traces`; the missing piece is a recovery path for `pending + ready` rows that never made it to execution plus grouped aggregate queries over the delivery table. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html] [CITED: https://hexdocs.pm/ecto/Ecto.Multi.html]

The safest design is: detect candidate rows from Chimeway tables only, claim or mutate those rows in place with guarded `update_all` writes, then re-handoff to the existing configured dispatcher using the delivery id as the only execution pointer. This matches the current deferred-resume and digest-emission patterns, and it respects the explicit Phase 20/22 decision that Oban remains an execution artifact instead of business truth. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/oban/Oban.html] [CITED: https://hexdocs.pm/oban/unique_jobs.html]

Outcome analytics should stay in `Chimeway.Traces` and derive a normalized lifecycle-result dimension from delivery fields, not attempt rows. Attempt history is durable and useful for explanations, but it is the wrong source for dashboard counts because retries would inflate totals and sync-vs-Oban execution differences would leak into operator reporting. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/ecto/Ecto.Query.html]

**Primary recommendation:** split Phase 22 into two plans, with recovery first and aggregate outcomes second, because the analytics query contract depends on the recovery-safe canonical outcome semantics already established on delivery rows. [ASSUMED]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Detect stuck deliveries | API / Backend | Database / Storage | Detection is a query over canonical delivery state and must not depend on queue state. [VERIFIED: codebase grep] |
| Claim and re-drive a stuck delivery | API / Backend | Database / Storage | Correctness depends on guarded row mutation plus transactional enqueue/dispatch handoff. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html] [CITED: https://hexdocs.pm/ecto/Ecto.Multi.html] |
| Execute delivery after recovery | API / Backend | Database / Storage | Existing sync/Oban dispatch paths already own adapter execution and attempt recording. [VERIFIED: codebase grep] |
| Aggregate operator outcomes | API / Backend | Database / Storage | Aggregation is a grouped query over delivery state exposed through `Chimeway.Traces`. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/ecto/Ecto.Query.html] |
| Render dashboard charts/tables in host app | Browser / Client | Frontend Server (SSR) | Phase 22 only needs a query API; UI composition remains host-owned and out of Chimeway core. [VERIFIED: codebase grep] |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `ecto` | `3.13.5` | Query composition, transactions, grouped aggregates, guarded `update_all`. Published 2025-11-09. [VERIFIED: hex registry] | Chimeway already uses Ecto as its canonical mutation/query layer, and the recovery/aggregate work fits its transaction and query primitives directly. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html] [CITED: https://hexdocs.pm/ecto/Ecto.Query.html] |
| `ecto_sql` | `3.13.5` | SQL adapter layer and migrations. Published 2026-03-03. [VERIFIED: hex registry] | Recovery will likely need a migration for recovery metadata or indexes, and the repo already depends on `ecto_sql`. [VERIFIED: codebase grep] |
| `postgrex` | `0.22.0` | PostgreSQL adapter for Chimeway’s host-owned database. Published 2026-01-10. [VERIFIED: hex registry] | All durable truth for this phase stays in PostgreSQL-backed Chimeway tables. [VERIFIED: codebase grep] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `oban` | locked `2.21.1`; latest `2.22.0` published 2026-03-26. [VERIFIED: hex registry] | Optional async execution seam for recovery re-drive handoff. [VERIFIED: codebase grep] | Use when the configured dispatcher is `Chimeway.Dispatch.Oban`; do not use Oban tables for stuck-row detection or correctness truth. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/oban/Oban.html] [CITED: https://hexdocs.pm/oban/unique_jobs.html] |
| `phoenix` | `1.8.5` | Optional host integration surface for dashboards/operators. Published 2026-03-05. [VERIFIED: hex registry] | Relevant only for host apps consuming the aggregate query API in UI surfaces; Chimeway itself should stay framework-light here. [VERIFIED: codebase grep] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Canonical delivery-state recovery | Oban job inspection/retry APIs | Rejected by locked decisions and by current architecture because queue state is execution artifact, not business truth. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/oban/unique_jobs.html] |
| Delivery-row aggregates | Attempt-history aggregates | Attempt rows represent retries and would overcount operator outcomes that are meant to summarize delivery lifecycle state. [VERIFIED: codebase grep] |
| `Chimeway.Traces` aggregate functions | New `Chimeway.Analytics` module | Rejected by locked decision D-03; `Chimeway.Traces` is already the operator query surface. [VERIFIED: codebase grep] |

**Installation:**
```bash
mix deps.get
```

**Version verification:** Versions were checked with `mix hex.info` for locked/configured package state and Hex package pages for current published releases/dates. [VERIFIED: hex registry]

## Architecture Patterns

### System Architecture Diagram
```text
host operator/API call
  -> Chimeway.Deliveries.list_reconcilable_deliveries(opts)
    -> SELECT pending + ready rows older than threshold from chimeway_deliveries
      -> candidate delivery ids
        -> reconcile_delivery(id, opts)
          -> guarded row claim / metadata stamp on canonical delivery row
          -> Repo.transact / Ecto.Multi
            -> dispatcher handoff by delivery_id
              -> existing Sync or Oban path
                -> transition_status(:dispatched)
                -> Deliveries.record_attempt(...)
                -> durable terminal or non-terminal delivery state

host operator/API call
  -> Chimeway.Traces.aggregate_outcomes(filters)
    -> grouped Ecto query over chimeway_deliveries
      -> derived lifecycle_result CASE/projection
        -> counts by notification_key + channel + lifecycle_result
          -> host dashboard
```

### Recommended Project Structure
```text
lib/chimeway/
├── deliveries.ex              # detection query + guarded reconciliation helpers
├── traces.ex                  # aggregate outcome query functions
├── dispatch/
│   ├── sync.ex                # existing execution path reused by recovery
│   ├── oban.ex                # existing enqueue path reused by recovery
│   └── oban_worker.ex         # existing canonical performer reused by recovery
test/chimeway/
├── recovery/
│   ├── reconciliation_test.exs
│   └── reconciliation_oban_test.exs
└── traces_outcomes_test.exs
```

### Pattern 1: Guarded Canonical Reconciliation
**What:** Detect reconcilable rows with a pure Ecto query, then mutate only rows still matching the expected preconditions using `update_all`, explicitly setting `updated_at` because `update_all` does not do that automatically. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html]
**When to use:** Any recovery action that must be idempotent under duplicate operator clicks, concurrent jobs, or repeated scans. [VERIFIED: codebase grep]
**Example:**
```elixir
# Source: https://hexdocs.pm/ecto/Ecto.Repo.html
def list_reconcilable_deliveries(opts \\ []) do
  now = Keyword.get(opts, :now, DateTime.utc_now())
  older_than = Keyword.fetch!(opts, :older_than)

  from(d in Delivery,
    where:
      d.status == :pending and
        d.orchestration_state == :ready and
        d.updated_at <= ^DateTime.add(now, -older_than, :second),
    order_by: [asc: d.updated_at, asc: d.inserted_at]
  )
  |> Repo.all()
end

def claim_for_reconcile(delivery_id, now, source) do
  {count, _} =
    Repo.update_all(
      from(d in Delivery,
        where:
          d.id == ^delivery_id and
            d.status == :pending and
            d.orchestration_state == :ready
      ),
      set: [metadata: %{"recovery_source" => source}, updated_at: now]
    )

  if count == 1, do: :claimed, else: :noop
end
```

### Pattern 2: Transactional Re-Drive Handoff
**What:** Reuse the existing dispatcher boundary and hand off by `delivery_id` inside `Repo.transact` or `Ecto.Multi`, just as deferred resume and digest emission already do. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/ecto/Ecto.Multi.html] [CITED: https://hexdocs.pm/oban/Oban.html]
**When to use:** When a claimed row must be safely reintroduced to the configured async/sync execution path without inventing a recovery-only executor. [VERIFIED: codebase grep]
**Example:**
```elixir
# Source: https://hexdocs.pm/ecto/Ecto.Multi.html
def reconcile_delivery(delivery_id, dispatcher, now) do
  Ecto.Multi.new()
  |> Ecto.Multi.run(:claim, fn _repo, _changes ->
    case claim_for_reconcile(delivery_id, now, "manual_reconcile") do
      :claimed -> {:ok, delivery_id}
      :noop -> {:error, :not_reconcilable}
    end
  end)
  |> Ecto.Multi.run(:dispatch, fn _repo, %{claim: id} ->
    dispatcher.dispatch_delivery(id, pre_planned: true, post_commit: true)
  end)
  |> Repo.transact()
end
```

### Pattern 3: Delivery-State Lifecycle Projection for Aggregates
**What:** Project operator lifecycle results from delivery-row columns with a deterministic case split before grouping. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/ecto/Ecto.Query.html]
**When to use:** Dashboard counts, rollups, and support queries that need one bucket per canonical delivery result. [VERIFIED: codebase grep]
**Example:**
```elixir
# Source: https://hexdocs.pm/ecto/Ecto.Query.html
from(d in Delivery,
  group_by: [d.channel, fragment("?::text", d.status), d.suppression_reason],
  select: %{
    channel: d.channel,
    status: d.status,
    suppression_reason: d.suppression_reason,
    count: count(d.id)
  }
)
```

### Anti-Patterns to Avoid
- **Queue-truth recovery:** Do not scan `oban_jobs` to decide which business rows are stuck; sync dispatch and failed transaction scenarios already make that incomplete. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/oban/unique_jobs.html]
- **Attempt-based dashboard counts:** Do not group by `delivery_attempts` for operator outcomes because retries are implementation detail, not delivery truth. [VERIFIED: codebase grep]
- **Opaque recovery rewrites:** Do not delete/reinsert delivery rows or silently rewrite terminal history; recovery must mutate the canonical row and remain explainable. [VERIFIED: codebase grep]
- **Blind `:cancelled` counting:** Do not treat all `:cancelled` rows as exhausted; current code uses `suppression_reason` to distinguish `retries_exhausted`, `permanent_failure`, `bounced`, `superseded`, and manual cancellation paths. [VERIFIED: codebase grep]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Recovery queue truth | Custom queue/job reconciliation logic over `oban_jobs` | Canonical delivery-state queries plus existing dispatcher seams | Oban uniqueness only applies at insertion time and does not govern concurrent execution or business truth. [CITED: https://hexdocs.pm/oban/unique_jobs.html] |
| Transaction choreography | Ad hoc nested `case` chains with partial writes | `Repo.transact` / `Ecto.Multi.run` | Ecto already provides transaction composition with dependency-aware steps. [CITED: https://hexdocs.pm/ecto/Ecto.Multi.html] |
| Analytics rollups | Manual Elixir-side grouping over loaded deliveries | SQL/Ecto grouped queries | Grouping and aggregate semantics belong in the database and avoid N+1 and memory blowups. [CITED: https://hexdocs.pm/ecto/Ecto.Query.html] |

**Key insight:** Phase 22’s hard parts are already solved in the stack Chimeway uses; the correct work is to compose those primitives around canonical delivery rows, not to build a second lifecycle system. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/ecto/Ecto.Multi.html]

## Common Pitfalls

### Pitfall 1: Counting recovery candidates from `updated_at` without explicit writes
**What goes wrong:** Rows never age into or out of the recovery window correctly if recovery helpers use `update_all` but forget to set `updated_at`. [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html]
**Why it happens:** Ecto documents that `update_all` does not update autogenerated timestamps automatically. [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html]
**How to avoid:** Every guarded reconciliation `update_all` should set `updated_at` explicitly and persist recovery metadata on the same write. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html]
**Warning signs:** The same row keeps reappearing in successive scans immediately after reconcile attempts. [ASSUMED]

### Pitfall 2: Treating Oban uniqueness as a correctness boundary
**What goes wrong:** Duplicate re-drive jobs can still happen under race conditions, or a job can execute concurrently even if insert uniqueness prevented another enqueue. [CITED: https://hexdocs.pm/oban/unique_jobs.html]
**Why it happens:** Oban states that uniqueness only applies on insertion, has no bearing on concurrent execution, and OSS uniqueness is still race-prone in some circumstances. [CITED: https://hexdocs.pm/oban/unique_jobs.html]
**How to avoid:** Put correctness on canonical row preconditions and idempotent delivery transitions; use Oban uniqueness only as load reduction. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/oban/unique_jobs.html]
**Warning signs:** Recovery code assumes “job exists” means “row is safe,” or assumes “unique job” means “single execution.” [ASSUMED]

### Pitfall 3: Double-counting suppressed vs digest-skipped outcomes
**What goes wrong:** Analytics that group only on `status` collapse ordinary policy suppression and digest skip outcomes into the same bucket. [VERIFIED: codebase grep]
**Why it happens:** Current digest emission writes `status: :suppressed` for skip-at-flush and stores the distinguishing fact in `digest_flush_outcome`. [VERIFIED: codebase grep]
**How to avoid:** Define a `lifecycle_result` projection that branches on digest fields before final grouping. [VERIFIED: codebase grep]
**Warning signs:** “Suppressed” counts jump when digest-heavy flows are enabled. [ASSUMED]

### Pitfall 4: Using attempt rows for OPS-02 rollups
**What goes wrong:** Temporary failures, retries, and sync-vs-Oban execution paths inflate dashboard counts or fragment meaning across attempts. [VERIFIED: codebase grep]
**Why it happens:** Attempt rows are append-only execution history, while OPS-02 asks for lifecycle outcomes at the delivery level. [VERIFIED: codebase grep]
**How to avoid:** Aggregate from `chimeway_deliveries` and reserve attempt history for drill-down and `explain_delivery/1`. [VERIFIED: codebase grep]
**Warning signs:** A single delivery contributes more than one dashboard count. [ASSUMED]

## Code Examples

Verified patterns from official sources and the current codebase:

### Grouped outcome counts
```elixir
# Source: https://hexdocs.pm/ecto/Ecto.Query.html
from(d in Delivery,
  group_by: [d.channel, d.status, d.suppression_reason],
  select: %{
    channel: d.channel,
    status: d.status,
    suppression_reason: d.suppression_reason,
    count: count(d.id)
  }
)
```

### Multi step with dependent dispatch handoff
```elixir
# Source: https://hexdocs.pm/ecto/Ecto.Multi.html
Ecto.Multi.new()
|> Ecto.Multi.run(:delivery, fn repo, _changes ->
  case repo.get(Delivery, delivery_id) do
    nil -> {:error, :not_found}
    delivery -> {:ok, delivery}
  end
end)
|> Ecto.Multi.run(:dispatch, fn _repo, %{delivery: delivery} ->
  dispatcher.dispatch_delivery(delivery.id, pre_planned: true, post_commit: true)
end)
|> Repo.transact()
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Trigger retry as recovery | Explicit recovery over persisted canonical rows | Recovery was explicitly deferred until Phase 22 and duplicate trigger re-fire remains inert. [VERIFIED: codebase grep] | Operators need a dedicated reconcile API instead of re-triggering the original event. [VERIFIED: codebase grep] |
| Queue-state inference | Chimeway-table business truth | Reinforced by Phase 20 context and current dispatch code. [VERIFIED: codebase grep] | Recovery and analytics must read Chimeway tables first. [VERIFIED: codebase grep] |
| Attempt-history reporting | Delivery-state reporting with trace drill-down | Required by locked decision D-04. [VERIFIED: codebase grep] | Dashboard totals stay stable while detailed explanations still use attempts. [VERIFIED: codebase grep] |

**Deprecated/outdated:**
- Re-firing a duplicate trigger as an operational recovery mechanism is outdated for this codebase because `Chimeway.Trigger` explicitly leaves existing rows untouched on duplicate. [VERIFIED: codebase grep]
- Treating all `:cancelled` rows as one outcome is outdated because the codebase now uses `suppression_reason` to distinguish exhausted, bounced, permanent, and superseded paths. [VERIFIED: codebase grep]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Phase 22 should be split into exactly two plans, with recovery before analytics. | Summary | Planning granularity may be off; implementation can still proceed but wave structure may need refinement. |
| A2 | The warning-sign examples in the pitfalls section are representative enough for planner verification steps. | Common Pitfalls | Verification checklist may miss a project-specific signal and need adjustment during planning. |

## Open Questions

1. **Should reconciliation remain entirely inside `Chimeway.Deliveries`, or get a thin dedicated public module such as `Chimeway.Recovery`?**
   - What we know: canonical mutation helpers already live in `Chimeway.Deliveries`, while dispatch ownership lives under `Chimeway.Dispatch`. [VERIFIED: codebase grep]
   - What's unclear: whether the team prefers public API consolidation over stricter context boundaries. [ASSUMED]
   - Recommendation: keep detection and compare-and-swap helpers in `Chimeway.Deliveries`, but allow a thin orchestration wrapper if planner ergonomics would otherwise force `Deliveries` to know too much about dispatch configuration. [ASSUMED]

2. **Does OPS-01 need event-level recovery APIs now, or is delivery-level recovery sufficient for the phase goal?**
   - What we know: the discuss-phase boundary mentions “persisted events or deliveries,” but the concrete locked detection example is delivery-state-based and the canonical lifecycle work in this repo is delivery-centric. [VERIFIED: codebase grep]
   - What's unclear: whether planner should include an event-scan helper for events whose notifications or deliveries were never planned. [ASSUMED]
   - Recommendation: plan delivery-level recovery as the required path, and only add event-level helpers if roadmap review finds a specific persisted-event gap not already covered by existing trigger transactions. [ASSUMED]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | implementation, tests, Mix tasks | ✓ | `1.19.5` [VERIFIED: codebase grep] | — |
| Mix | test and CI entrypoints | ✓ | `1.19.5` [VERIFIED: codebase grep] | — |
| PostgreSQL | Ecto integration tests and canonical storage | ✓ | client `14.17`; local server accepting connections on default socket [VERIFIED: codebase grep] | — |

**Missing dependencies with no fallback:**
- None found during the environment audit. [VERIFIED: codebase grep]

**Missing dependencies with fallback:**
- None found during the environment audit. [VERIFIED: codebase grep]

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit via `mix test` on Elixir `1.19.5`. [VERIFIED: codebase grep] |
| Config file | `mix.exs` aliases plus `config/test.exs`. [VERIFIED: codebase grep] |
| Quick run command | `mix test test/chimeway/recovery/reconciliation_test.exs test/chimeway/traces_outcomes_test.exs` [ASSUMED] |
| Full suite command | `mix ci.test` [VERIFIED: codebase grep] |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| OPS-01 | Detect `pending + ready` rows older than threshold, reconcile exactly once, preserve row identity/explainability, and safely no-op on duplicates. [VERIFIED: codebase grep] | integration | `mix test test/chimeway/recovery/reconciliation_test.exs -x` [ASSUMED] | ❌ Wave 0 |
| OPS-01 | Re-drive through Oban path without using Oban as source-of-truth and without duplicate sends under repeated reconcile attempts. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/oban/unique_jobs.html] | integration | `mix test test/chimeway/recovery/reconciliation_oban_test.exs -x` [ASSUMED] | ❌ Wave 0 |
| OPS-02 | Aggregate counts by notification key, channel, and normalized lifecycle result using only delivery-row fields. [VERIFIED: codebase grep] | integration | `mix test test/chimeway/traces_outcomes_test.exs -x` [ASSUMED] | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `mix test test/chimeway/recovery/reconciliation_test.exs test/chimeway/traces_outcomes_test.exs` [ASSUMED]
- **Per wave merge:** `mix ci.test` [VERIFIED: codebase grep]
- **Phase gate:** Full suite green before `/gsd-verify-work`. [VERIFIED: codebase grep]

### Wave 0 Gaps
- [ ] `test/chimeway/recovery/reconciliation_test.exs` — locks OPS-01 canonical detection, claim, no-op, and explainability behavior. [ASSUMED]
- [ ] `test/chimeway/recovery/reconciliation_oban_test.exs` — locks OPS-01 re-drive handoff under Oban and repeated reconcile attempts. [ASSUMED]
- [ ] `test/chimeway/traces_outcomes_test.exs` — locks OPS-02 lifecycle-result projection and grouped counts. [ASSUMED]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Host application owns operator authentication; Chimeway should not add its own auth layer in this phase. [VERIFIED: codebase grep] |
| V3 Session Management | no | Host application owns session management; Phase 22 exposes query/recovery APIs only. [VERIFIED: codebase grep] |
| V4 Access Control | yes | Keep operator surfaces tenancy-aware and pass repo options/prefixes through query APIs as existing traces functions already do. [VERIFIED: codebase grep] |
| V5 Input Validation | yes | Use Ecto query parameterization and explicit option validation for thresholds, limits, and filters. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/ecto/Ecto.Query.html] |
| V6 Cryptography | no | No new cryptographic requirement is introduced by this phase; continue not to hand-roll crypto. [VERIFIED: codebase grep] |

### Known Threat Patterns for Elixir/Ecto recovery analytics

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Duplicate reconcile calls causing duplicate sends | Tampering | Guard on canonical row state first; use Oban uniqueness only as a secondary load reducer. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/oban/unique_jobs.html] |
| Operator query leakage across tenant/prefix boundaries | Information Disclosure | Preserve existing `opts` passthrough and host-owned repo scoping in new trace aggregate functions. [VERIFIED: codebase grep] |
| Raw payload leakage in recovery metadata or aggregates | Information Disclosure | Follow existing sanitized metadata/planning-context posture and avoid projecting payload/render data into analytics. [VERIFIED: codebase grep] |
| Unbounded dashboard queries | Denial of Service | Require bounded filters, grouped queries, and default limits/time windows. [ASSUMED] |

## Sources

### Primary (HIGH confidence)
- Local codebase: `lib/chimeway/deliveries.ex`, `lib/chimeway/traces.ex`, `lib/chimeway/dispatch/*.ex`, `lib/chimeway/trigger.ex`, relevant tests — lifecycle rules, current mutation patterns, trace contract, and recovery gap. [VERIFIED: codebase grep]
- https://hexdocs.pm/ecto/Ecto.Repo.html — `update_all`, `Repo.transact`, timestamp caveat. [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html]
- https://hexdocs.pm/ecto/Ecto.Multi.html — transaction step composition and `run/3` callback semantics. [CITED: https://hexdocs.pm/ecto/Ecto.Multi.html]
- https://hexdocs.pm/ecto/Ecto.Query.html — grouped query and aggregate projection rules. [CITED: https://hexdocs.pm/ecto/Ecto.Query.html]
- https://hexdocs.pm/oban/Oban.html — recommended job insertion APIs and transactional enqueue support. [CITED: https://hexdocs.pm/oban/Oban.html]
- https://hexdocs.pm/oban/unique_jobs.html — uniqueness semantics and race-condition caveat. [CITED: https://hexdocs.pm/oban/unique_jobs.html]
- https://hexdocs.pm/oban/Oban.Worker.html — JSON/string-key job args semantics. [CITED: https://hexdocs.pm/oban/Oban.Worker.html]
- Hex package pages and `mix hex.info` for current/locked versions: `ecto`, `ecto_sql`, `postgrex`, `oban`, `phoenix`. [VERIFIED: hex registry]

### Secondary (MEDIUM confidence)
- `.planning/phases/20-digest-emission-explainability/20-CONTEXT.md` — prior decision continuity about queue state and canonical explainability. [VERIFIED: codebase grep]

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - versions were verified against Hex and the repo lock/config state. [VERIFIED: hex registry]
- Architecture: HIGH - recommendations mostly extend patterns already implemented in `Deliveries`, `Dispatch`, and `Traces`. [VERIFIED: codebase grep]
- Pitfalls: MEDIUM - the core failure modes are well supported by code and docs, but some warning-sign examples are inferred for future planner checks. [VERIFIED: codebase grep] [ASSUMED]

**Research date:** 2026-04-28
**Valid until:** 2026-05-28
