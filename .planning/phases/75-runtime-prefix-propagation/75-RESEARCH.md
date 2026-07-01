# Phase 75: Runtime Prefix Propagation - Research

**Researched:** 2026-07-01  
**Domain:** Elixir/Ecto runtime prefix propagation for Chimeway-owned PostgreSQL tables  
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

Source copied from `.planning/phases/75-runtime-prefix-propagation/75-CONTEXT.md`. [VERIFIED: codebase file read]

### Locked Decisions
## Implementation Decisions

### Runtime Storage Contract

- **D-01:** Use `Chimeway.Repo.default_options/1` as the primary runtime prefix propagation mechanism, implemented by delegating to `Chimeway.Storage.repo_opts/1`.
- **D-02:** Keep `Chimeway.Storage.repo_opts/1` as the single storage-prefix mapping contract. It continues to map `prefix: "chimeway"` to `[prefix: "chimeway"]`, map `prefix: false` to unprefixed repo options, and preserve explicit caller `:prefix` probes through `Keyword.put_new/3`.
- **D-03:** Runtime prefix should be a property of `Chimeway.Repo`, not an option ordinary adopters pass through `Chimeway.trigger/3`, inbox APIs, admin APIs, recovery APIs, workflow APIs, or worker args.
- **D-04:** Keep local context `repo_opts(opts)` helpers only for stripping domain/query options such as `:limit`, `:tenant_id`, `:recipient_id`, `:older_than`, `:now`, cursors, or filters. Those helpers must not invent independent prefix logic.
- **D-05:** Preserve explicit `prefix:` override probes for tests, admin/debug reads, and maintenance diagnostics. This remains a controlled escape hatch, not a public per-request or per-tenant database-prefix API.

### Rejected Interface Shapes

- **D-06:** Do not use schema-level `@schema_prefix` for Chimeway-owned schemas. It is compile-time, fights `prefix: false`, weakens explicit probe overrides, and does not cover string-source bulk operations.
- **D-07:** Do not introduce a broad `Chimeway.Storage.Repo` wrapper, storage context struct, or partial Ecto facade in Phase 75. That adds arity/options drift, complicates `Ecto.Multi.run/3`, and looks like dynamic per-request prefix support.
- **D-08:** Do not make manual per-operation `Chimeway.Storage.repo_opts/1` calls the primary propagation strategy. It is correct when needed, but too easy to miss across the existing runtime surface.

### Transactional and Async Flow Semantics

- **D-09:** Do not rely on transaction options, worker context, process state, Postgres `search_path`, or Oban config to carry Chimeway's table prefix implicitly.
- **D-10:** Audit full transactional flows, not only top-level public APIs: `Ecto.Multi` operations, `Multi.run` callback repo calls, `Repo.transaction`/`Repo.transact` bodies, preloads, duplicate lookups, worker reloads, `update_all`, `delete_all`, and `insert_all`.
- **D-11:** Treat string-source `insert_all` as a named risk area. Trigger fanout currently inserts `"chimeway_notifications"` rows through the transaction repo; planners must prove that path lands in the configured prefix.
- **D-12:** Oban job args remain backend-neutral and durable-ID based. Jobs should carry IDs such as `delivery_id`, `workflow_run_id`, or `ingress_id`, not prefix values, copied payloads, tenant-scoped DB state, or rendered data. Workers rehydrate from Chimeway storage through configured repo behavior.
- **D-13:** Chimeway's storage prefix remains separate from Oban's job-table prefix. Tests and later docs must not conflate the two.

### Verification Strategy

- **D-14:** Keep the default/root test config in explicit public-schema legacy mode (`prefix: false`). That baseline is valuable compatibility proof, not debt to remove.
- **D-15:** Add focused prefixed runtime integration proof using real Postgres and generated prefixed migrations or an equivalent normal migrate path. Migration-contract-only proof is insufficient for Phase 75 because runtime code can still leak to `public`.
- **D-16:** Required prefixed proof should cover trigger-to-trace, duplicate idempotency, inbox list/unread/mark_read/mark_seen plus signal emission, workflow progression, digest accumulation/emission, webhook ingress plus `ProcessFeedbackWorker`, admin/trace/recovery reads and writes, and worker reloads by durable IDs.
- **D-17:** Prefer a separate non-async prefixed runtime integration suite over flipping the entire test config to prefixed mode. Use dual-run selected tests only where the duplication is clearly worth the maintenance cost.
- **D-18:** Add unit/static guardrails around `Repo.default_options/1`, `Chimeway.Storage.repo_opts/1`, explicit override behavior, and string-source `insert_all` coverage, but do not treat those as acceptance evidence by themselves.
- **D-19:** If Phase 75 adds a named local alias such as `mix verify.runtime_prefix`, keep it focused on runtime proof. Phase 76 still owns final docs/demo/release-gate parity and broader ecosystem `verify.*` composition.

### DX, Persona, and Operator Lens

- **D-20:** Runtime prefix propagation is backend-only. There is no end-user UI change in this phase.
- **D-21:** The developer experience should be "configure once, use ordinary Chimeway APIs." Feature developers should not learn or pass Ecto prefix options during normal notification work.
- **D-22:** Staff/backend engineers should get deterministic evidence that Chimeway-owned rows land in the intended schema and that public legacy mode remains supported.
- **D-23:** Support operators should keep using traces, admin read models, and recovery surfaces without seeing backend storage implementation details. Diagnostics may say "isolated Chimeway schema" or "public-schema legacy mode"; reserve "Ecto prefix/repo opts" for maintainer docs and troubleshooting.
- **D-24:** Preserve Chimeway's durable explainability bias: every storage-routing decision should keep trigger, notification, delivery, attempt, signal, workflow, digest, webhook, admin, and recovery facts queryable from durable rows.

### Lessons Applied

- **D-25:** Learn from Rails engines: visible namespace ownership and collision resistance are good, but connection-level `schema_search_path`-style ambient state is a footgun for explainable storage routing.
- **D-26:** Learn from Laravel package migrations: generated/published host migrations should be inspectable and deterministic; runtime should not hide storage behavior behind unreviewable magic.
- **D-27:** Learn from Laravel Notifications and Noticed: persisting class/module names as durable identity creates rename footguns. Chimeway must keep stable `notification_key` plus version as the durable identity while prefix routing stays storage plumbing.
- **D-28:** Learn from Symfony Notifier DSNs: compact overloaded strings create escaping/configuration footguns. Chimeway should keep boring typed config, structured errors, and explicit adapter/storage contracts.
- **D-29:** Learn from Ecto and Oban: prefixes are powerful but operationally expensive when dynamic. Phase 75 stays static per install and does not introduce prefix-per-tenant runtime tenancy.

### the agent's Discretion

Downstream agents may choose the narrowest implementation that satisfies these decisions. If `Repo.default_options/1` cannot cover a specific Ecto operation in the project's pinned version, planners should add explicit `Chimeway.Storage.repo_opts/1` only at that operation while keeping repo defaults as the primary contract.

### Deferred Ideas (OUT OF SCOPE)

- Dynamic per-tenant database prefixes remain out of scope for v1.13.
- First-party automated public-to-`chimeway` data move remains deferred.
- Full prefix documentation, manual move guide, demo-host proof, Oban-prefix docs, and release-gate/doc-contract parity belong to Phase 76.
- Broader tenant spine redesign remains deferred beyond this storage-isolation milestone.
</user_constraints>

## Summary

Phase 75 should wire the existing storage-prefix contract into normal runtime behavior by adding `Chimeway.Repo.default_options/1` and delegating normal operations to `Chimeway.Storage.repo_opts/1`. `Chimeway.Storage.repo_opts/1` already maps `"chimeway"` to `[prefix: "chimeway"]`, leaves `false` unprefixed, and preserves explicit caller `:prefix` via `Keyword.put_new/3`. [VERIFIED: codebase grep]

The pinned Ecto source confirms this is the correct primary hook: repo operation options merge defaults first and caller-supplied options second, so explicit diagnostic `prefix:` probes keep overriding the configured default. [VERIFIED: deps/ecto] Ecto docs also state repo operations accept `:prefix`, query prefixes act as a fallback, and schema operations such as `insert_all`, `insert`, and `update` can be routed by an operation prefix. [CITED: https://hexdocs.pm/ecto/multi-tenancy-with-query-prefixes.html]

The main non-obvious exception is `Oban.Job`. Oban's own repo wrapper injects Oban's configured job-table prefix, while `Oban.Job` itself is an unprefixed Ecto schema. Direct `Chimeway.Repo` queries against `Oban.Job` in `lib/chimeway/dispatch/oban.ex` must explicitly use Oban's job-table prefix or public/default behavior; they must not inherit Chimeway's storage prefix. [VERIFIED: deps/oban] [VERIFIED: codebase grep]

**Primary recommendation:** add `Chimeway.Repo.default_options/1`, normalize local option filtering helpers to delegate to `Chimeway.Storage.repo_opts/1`, add an explicit Oban-job-table escape for direct `Oban.Job` queries, and prove trigger-to-trace plus async/runtime flows in a separate non-async prefixed integration suite. [VERIFIED: 75-CONTEXT.md]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Static storage prefix selection | API / Backend | Database / Storage | The storage mode is application config consumed by `Chimeway.Storage` and `Chimeway.Repo`; table placement is enforced by Ecto repo options. [VERIFIED: codebase grep] |
| Trigger fanout and idempotency | API / Backend | Database / Storage | `Chimeway.Trigger` owns event creation, notification fanout, duplicate lookup, and dispatch handoff over Chimeway-owned tables. [VERIFIED: codebase grep] |
| Traces, explainability, admin, inbox, recovery | API / Backend | Database / Storage | These are Chimeway read/write surfaces over persisted lifecycle rows, not client or UI storage concerns. [VERIFIED: codebase grep] |
| Workflow, signal, digest, webhook progression | API / Backend | Oban / Database | Runtime modules persist Chimeway state and enqueue durable-ID Oban jobs; workers rehydrate state through repo reads. [VERIFIED: codebase grep] |
| Oban job-table lookup and cleanup | Oban / Backend | Database / Storage | Oban's `oban_jobs` prefix is configured independently from Chimeway's storage prefix and needs separate handling when queried directly. [VERIFIED: deps/oban] |
| Prefixed runtime proof | Test Harness | PostgreSQL | Phase 75 acceptance requires real Postgres runtime flows against prefixed generated migrations, while default tests remain public legacy mode. [VERIFIED: 75-CONTEXT.md] |

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| RUN-01 | Trigger fanout persists events, notifications, deliveries, and attempts into the configured Chimeway prefix. | `Chimeway.Trigger` uses `Ecto.Multi`, `repo.insert_all("chimeway_notifications", rows)`, and post-commit dispatch; default repo options plus explicit string-source proof are required. [VERIFIED: codebase grep] |
| RUN-02 | Idempotency, duplicate detection, lifecycle reads, traces, and explainability queries resolve data from the configured prefix, not accidentally from `public`. | Duplicate lookup, trace reads, preloads, and lifecycle queries are broad repo call sites; Ecto default options cover ordinary operations, while tests must prove no public fallback. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html] |
| RUN-03 | Workflow progression, signal routing, digest buckets, policy/preferences, webhook ingress, dispatch workers, and string-source `insert_all` calls propagate prefix options correctly. | Runtime modules use transactions, workers, `update_all`, `delete_all`, schema `insert_all`, and Oban handoffs; the planner must audit each flow and treat `Oban.Job` direct queries as separate from Chimeway storage. [VERIFIED: codebase grep] [VERIFIED: deps/oban] |
| RUN-04 | Admin, inbox, trace, and recovery read/write surfaces use the configured prefix and remain tenant/redaction-safe. | Admin, inbox, trace, and recovery modules already filter domain options and tenant data; Phase 75 should preserve tenant filters/redaction while adding storage-prefix routing. [VERIFIED: codebase grep] |
</phase_requirements>

## Project Constraints (from AGENTS.md)

- Chimeway is an open-source embedded notification layer for Elixir and Phoenix apps; host applications own data, policies, and delivery history. [VERIFIED: AGENTS.md]
- Every notification decision must remain explainable: why a notification was sent, failed, or suppressed. [VERIFIED: AGENTS.md]
- Stack constraints are Elixir 1.17+ / OTP 26+, Ecto 3.x with PostgreSQL 15+, optional Phoenix 1.7/1.8, optional recommended Oban 2.x, and Swoosh 1.x email adapter seams. [VERIFIED: AGENTS.md]
- Persist stable `notification_key` plus version; do not use module names as durable identity. [VERIFIED: AGENTS.md]
- Keep the durable lifecycle spine: event -> notification -> delivery -> attempt. [VERIFIED: AGENTS.md]
- Treat idempotency and suppression reasons as first-class product behavior. [VERIFIED: AGENTS.md]
- Keep adapters replaceable with explicit behaviours and contract tests. [VERIFIED: AGENTS.md]
- Preserve host ownership boundaries for auth, tenancy, URL generation, and correlation IDs. [VERIFIED: AGENTS.md]
- Maintain `mix verify.*` and `mix ci.*` entrypoints with CI/local parity. [VERIFIED: AGENTS.md]
- Avoid leaking sensitive payload fields in telemetry and operator surfaces. [VERIFIED: AGENTS.md]

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Elixir / Mix | 1.19.5 local, project minimum 1.17+ | Runtime and test execution | Project target is Elixir 1.17+ and local tooling is available. [VERIFIED: local command] [VERIFIED: AGENTS.md] |
| Erlang/OTP | 28 local, project minimum 26+ | BEAM runtime | Project target is OTP 26+ and local tooling is available. [VERIFIED: local command] [VERIFIED: AGENTS.md] |
| Ecto | 3.13.6 | Repo defaults, schema/query operations, transactions, `insert_all` | `Ecto.Repo.default_options/1` and operation-level `:prefix` are the correct routing seam. [VERIFIED: mix deps] [VERIFIED: deps/ecto] |
| Ecto SQL | 3.13.5 | PostgreSQL adapter integration, SQL Sandbox, migrations | Existing tests and migration contracts depend on Ecto SQL and SQL Sandbox. [VERIFIED: mix deps] |
| Postgrex | 0.22.2 | PostgreSQL driver | Existing Repo uses `Ecto.Adapters.Postgres` through Postgrex. [VERIFIED: mix deps] |
| PostgreSQL | 15+ target; 14.17 local server | Runtime storage and integration tests | Project target is PostgreSQL 15+; local service is running but below target, so CI remains the authoritative version proof. [VERIFIED: AGENTS.md] [VERIFIED: local command] |
| Oban | 2.23.0 | Optional async job persistence and workers | Chimeway already uses Oban workers; Oban job-table prefix is separate from Chimeway storage prefix. [VERIFIED: mix deps] [VERIFIED: deps/oban] |

### Supporting

| Library / Module | Version | Purpose | When to Use |
|------------------|---------|---------|-------------|
| `Chimeway.Storage` | local | Validates static prefix config and maps repo options | Use as the only Chimeway storage-prefix mapping contract. [VERIFIED: codebase grep] |
| `Chimeway.Repo` | local | Target for repo-wide runtime default options | Implement `default_options/1` here; do not introduce a wrapper repo. [VERIFIED: 75-CONTEXT.md] |
| `Ecto.Multi` | Ecto 3.13.6 | Transactional event, workflow, webhook, and digest flows | Audit `Multi.run/3` callbacks because callback functions receive the transaction repo. [CITED: https://hexdocs.pm/ecto/Ecto.Multi.html] |
| `Ecto.Adapters.SQL.Sandbox` | Ecto SQL 3.13.5 | Non-async DB integration tests | Use shared/non-async mode for global prefix-env tests and worker processes. [CITED: https://hexdocs.pm/ecto_sql/Ecto.Adapters.SQL.Sandbox.html] |
| `Oban.Testing` | Oban 2.23.0 | Job assertions and inline/manual worker testing | Keep Oban testing prefix separate from Chimeway storage prefix. [CITED: https://hexdocs.pm/oban/testing.html] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `Chimeway.Repo.default_options/1` | Manual `Storage.repo_opts/1` at every call | Too easy to miss nested transactions, worker reloads, and later call sites. [VERIFIED: 75-CONTEXT.md] |
| Runtime repo default options | Schema-level `@schema_prefix` | Compile-time schema prefix fights explicit public mode and does not cover string-source `insert_all`. [VERIFIED: 75-CONTEXT.md] [CITED: https://hexdocs.pm/ecto/Ecto.Schema.html] |
| Existing `Chimeway.Repo` | Wrapper repo/facade | Adds API drift and complicates `Ecto.Multi.run/3` without adding needed dynamic tenancy. [VERIFIED: 75-CONTEXT.md] |
| Static install prefix | Dynamic per-tenant database prefix | Explicitly out of scope for v1.13 because runtime/job/idempotency complexity is high. [VERIFIED: REQUIREMENTS.md] |

**Installation:**

```bash
# No new packages are recommended for Phase 75.
mix deps.get
```

**Version verification performed:**

```bash
mix deps | rg 'ecto|oban|postgrex'
elixir --version
mix --version
psql -Atqc "SHOW server_version"
```

## Package Legitimacy Audit

Phase 75 should not install new external packages. Existing packages are already present in `mix.lock` and `mix deps` output. [VERIFIED: mix deps]

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| None added | - | - | - | - | OK | No package gate required. [VERIFIED: research scope] |

**Packages removed due to [SLOP] verdict:** none  
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```text
Application config (:chimeway, :prefix)
  -> Chimeway.Storage.validate_prefix!/0 at boot
  -> Chimeway.Storage.repo_opts/1
  -> Chimeway.Repo.default_options(operation)
       -> :transaction => []
       -> normal repo operation => [prefix: "chimeway"] or []
       -> explicit caller prefix => caller prefix wins
  -> Chimeway public/runtime APIs
       -> Trigger fanout and duplicate lookup
       -> Inbox, admin, trace, recovery reads/writes
       -> Workflow, signal, digest, webhook transactions
       -> Dispatch/webhook/workflow/digest workers reload by durable IDs
  -> PostgreSQL Chimeway-owned chimeway_* tables

Separate branch:
Oban.insert / Oban workers / direct Oban.Job cleanup
  -> Oban configured job-table prefix or public/default
  -> public.oban_jobs by current config unless host config changes
```

### Recommended Project Structure

```text
lib/chimeway/
├── repo.ex                         # Add Repo.default_options/1
├── storage.ex                      # Keep existing repo_opts/1 contract
├── admin.ex                        # Normalize local repo_opts/1 filtering
├── traces.ex                       # Preserve explicit prefix probes
├── trigger.ex                      # Prove string-source insert_all route
├── dispatch/oban.ex                # Add explicit Oban job-table query opts
└── ...                             # Audit runtime Repo call sites by flow

test/
├── support/prefixed_runtime_case.ex        # New serialized prefixed DB/env harness
├── chimeway/repo_prefix_test.exs           # New unit guardrails
└── chimeway/runtime_prefix_integration_test.exs
                                             # New RUN-01..RUN-04 prefixed proof
```

### Pattern 1: Repo Default Options

**What:** Put static Chimeway storage routing on `Chimeway.Repo`, not on caller-facing API options. [VERIFIED: 75-CONTEXT.md]

**When to use:** Always for Chimeway-owned runtime tables; add narrow explicit options only for operations that are not Chimeway storage, such as direct `Oban.Job` queries. [VERIFIED: deps/oban]

**Example:**

```elixir
# Source: .planning/phases/75-runtime-prefix-propagation/75-CONTEXT.md
defmodule Chimeway.Repo do
  use Ecto.Repo,
    otp_app: :chimeway,
    adapter: Ecto.Adapters.Postgres

  @impl true
  def default_options(:transaction), do: []
  def default_options(_operation), do: Chimeway.Storage.repo_opts()
end
```

Ecto's local pinned source merges default operation options before explicit caller options, preserving explicit `prefix:` probes. [VERIFIED: deps/ecto]

### Pattern 2: Local Domain Option Filtering

**What:** Keep context-specific option filters only for non-repo domain options, then delegate prefix handling to `Chimeway.Storage.repo_opts/1`. [VERIFIED: 75-CONTEXT.md]

**When to use:** Admin, traces, inbox, recovery, or similar contexts that accept filters such as tenant, recipient, cursor, limit, or time options. [VERIFIED: codebase grep]

**Example:**

```elixir
# Source: .planning/phases/75-runtime-prefix-propagation/75-CONTEXT.md
defp repo_opts(opts) do
  opts
  |> Keyword.drop([:limit, :tenant_id, :recipient_id, :older_than, :now])
  |> Chimeway.Storage.repo_opts()
end
```

### Pattern 3: Oban Job-Table Escape Hatch

**What:** Direct `Oban.Job` queries must use Oban's configured prefix/defaults instead of inheriting Chimeway storage prefix. [VERIFIED: deps/oban] [VERIFIED: codebase grep]

**When to use:** `lib/chimeway/dispatch/oban.ex` currently queries and deletes duplicate digest-flush `Oban.Job` rows through `Chimeway.Repo`. [VERIFIED: codebase grep]

**Example planning shape:**

```elixir
# Source basis: deps/oban/lib/oban/repo.ex default_options/1
defp oban_job_repo_opts do
  case Oban.config() do
    %{prefix: false} -> [prefix: nil]
    %{prefix: nil} -> [prefix: nil]
    %{prefix: prefix} when is_binary(prefix) -> [prefix: prefix]
  end
end
```

Planner note: verify the exact `Oban.config/0` call shape against the current app supervision mode before implementation; the invariant is that these options come from Oban config, not from `Chimeway.Storage.repo_opts/1`. [VERIFIED: deps/oban]

### Pattern 4: Prefixed Runtime Test Harness

**What:** Run a small non-async suite that switches Chimeway to `prefix: "chimeway"` and runs real Chimeway flows against tables created by generated prefixed migrations. [VERIFIED: 75-CONTEXT.md]

**When to use:** Acceptance proof for RUN-01 through RUN-04. [VERIFIED: REQUIREMENTS.md]

**Recommended harness:**

```elixir
# Source basis: .planning/phases/75-runtime-prefix-propagation/75-CONTEXT.md
setup_all do
  original_prefix = Application.fetch_env!(:chimeway, :prefix)
  Application.put_env(:chimeway, :prefix, "chimeway")

  on_exit(fn ->
    Application.put_env(:chimeway, :prefix, original_prefix)
  end)

  :ok
end
```

Planner note: prefer an isolated temporary database plus temporary `Chimeway.Repo` config restart if the suite needs to run generated migrations without polluting the root test database. If that is too invasive, create/drop the `chimeway` schema in the existing test DB inside a serialized suite and document the cleanup. [VERIFIED: 75-CONTEXT.md] [VERIFIED: codebase grep]

### Anti-Patterns to Avoid

- **Adding `@schema_prefix`:** compile-time schema prefixes fight explicit public legacy mode and do not cover string-source `insert_all`. [VERIFIED: 75-CONTEXT.md] [CITED: https://hexdocs.pm/ecto/Ecto.Schema.html]
- **Passing prefix through public APIs or job args:** this creates a dynamic per-request prefix API that is explicitly out of scope. [VERIFIED: 75-CONTEXT.md]
- **Using `search_path` or process state:** ambient database/session routing is hard to explain and was rejected for this phase. [VERIFIED: 75-CONTEXT.md]
- **Letting `Oban.Job` inherit Chimeway prefix:** Oban's job table is governed by Oban config, not Chimeway storage config. [VERIFIED: deps/oban]
- **Ad hoc raw SQL fixture setup:** Phase 74 already produced generated prefixed migrations; runtime proof should use generated migrations or an equivalent normal migrate path. [VERIFIED: 75-CONTEXT.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Runtime prefix mapping | Scattered `[prefix: ...]` clauses | `Chimeway.Repo.default_options/1` delegating to `Chimeway.Storage.repo_opts/1` | Centralized mapping prevents missed nested calls. [VERIFIED: 75-CONTEXT.md] |
| Schema routing | `@schema_prefix` on Chimeway schemas | Operation/query prefix via repo defaults | Must preserve public mode, explicit probes, and string-source bulk operations. [CITED: https://hexdocs.pm/ecto/multi-tenancy-with-query-prefixes.html] |
| Transaction propagation | Prefix through transaction opts or process state | Inner repo calls using repo defaults | Ecto transaction defaults are not the storage contract; inner operations still prepare their own opts. [VERIFIED: deps/ecto] |
| Oban job table routing | Chimeway storage prefix for `Oban.Job` | Oban config-derived prefix/default options | Oban has its own prefix semantics and repo wrapper defaults. [VERIFIED: deps/oban] |
| Prefixed test schema setup | Hand-written partial DDL | Phase 74 generated prefixed migrations or normal migrate path | Acceptance needs real generated table shape, not approximate tables. [VERIFIED: 75-CONTEXT.md] |
| Duplicate/idempotency behavior | New duplicate-detection logic | Existing constraints and trigger duplicate path | Requirement is storage placement, not a redesign of idempotency semantics. [VERIFIED: REQUIREMENTS.md] |

**Key insight:** The hard part is not computing `[prefix: "chimeway"]`; it is preventing a small number of non-Chimeway-storage operations and nested runtime paths from silently taking the wrong default. [VERIFIED: codebase grep]

## Common Pitfalls

### Pitfall 1: Transaction Defaults Mistaken For Runtime Propagation

**What goes wrong:** adding `[prefix: "chimeway"]` to transaction options is treated as sufficient proof. [VERIFIED: 75-CONTEXT.md]

**Why it happens:** transactions and inner repo operations have separate option preparation paths. [VERIFIED: deps/ecto]

**How to avoid:** implement `default_options(:transaction), do: []` and rely on normal inner operation defaults. [VERIFIED: 75-CONTEXT.md]

**Warning signs:** tests only assert `Repo.transaction(prefix: ...)` behavior and do not run trigger/workflow/digest/webhook flows. [VERIFIED: 75-CONTEXT.md]

### Pitfall 2: String-Source `insert_all` Escapes Schema Routing

**What goes wrong:** trigger fanout inserts notifications through `repo.insert_all("chimeway_notifications", rows)` and could land in `public` if prefix defaults do not apply. [VERIFIED: codebase grep]

**Why it happens:** binary table-source `insert_all` has less schema metadata than module-based inserts. [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html]

**How to avoid:** keep repo defaults and add a targeted integration assertion that notifications appear in `chimeway.chimeway_notifications` and are not read from public. [VERIFIED: 75-CONTEXT.md]

**Warning signs:** guardrail tests grep for `insert_all` but no runtime trigger-to-trace assertion exists. [VERIFIED: 75-CONTEXT.md]

### Pitfall 3: Oban Job Queries Use The Wrong Prefix

**What goes wrong:** direct `Repo.all(from job in Oban.Job)` or `Repo.delete_all(from job in Oban.Job)` inherits Chimeway's storage prefix and queries `chimeway.oban_jobs`. [VERIFIED: deps/oban] [VERIFIED: codebase grep]

**Why it happens:** `Oban.Job` is an unprefixed schema, while Oban's wrapper injects Oban config options separately. [VERIFIED: deps/oban]

**How to avoid:** add an explicit Oban-job option helper for direct `Oban.Job` reads/deletes, or replace the direct query with an Oban-supported API if one fits the behavior. [VERIFIED: deps/oban]

**Warning signs:** prefixed runtime tests fail around digest flush dedupe, public Oban jobs disappear when Chimeway storage prefix is enabled, or test cleanup calls such as direct `Repo.delete_all(Oban.Job)` inherit the Chimeway prefix. [VERIFIED: codebase grep]

### Pitfall 4: Local `repo_opts/1` Helpers Become Parallel Prefix Logic

**What goes wrong:** admin/traces helpers drop domain options but skip `Chimeway.Storage.repo_opts/1`, or accidentally drop explicit `:prefix` probes. [VERIFIED: codebase grep]

**Why it happens:** these helpers predate repo-wide defaults and were written for filtering, not routing. [VERIFIED: codebase grep]

**How to avoid:** standardize helpers as `Keyword.drop(...) |> Chimeway.Storage.repo_opts()` and keep `Keyword.put_new/3` semantics. [VERIFIED: 75-CONTEXT.md]

**Warning signs:** explicit prefix probe tests in traces/admin fail, or helpers contain hard-coded `"chimeway"`. [VERIFIED: codebase grep]

### Pitfall 5: Prefixed Tests Pollute Public Legacy Tests

**What goes wrong:** global app env or test database state leaks from prefixed runtime tests into the default public-suite baseline. [VERIFIED: config/test.exs]

**Why it happens:** `Application.put_env(:chimeway, :prefix, "chimeway")` is process-global. [VERIFIED: codebase grep]

**How to avoid:** make the prefixed suite non-async, restore app env on exit, and isolate schema/database setup. [CITED: https://hexdocs.pm/ecto_sql/Ecto.Adapters.SQL.Sandbox.html]

**Warning signs:** public-mode tests pass alone but fail after runtime-prefix tests. [VERIFIED: 75-CONTEXT.md]

### Pitfall 6: Tenant/Redaction Filters Regress While Adding Prefixes

**What goes wrong:** admin, inbox, trace, or recovery code starts returning cross-tenant rows or sensitive payloads while plumbing prefix options. [VERIFIED: AGENTS.md]

**Why it happens:** prefix plumbing touches the same call sites as tenant filters and redacted DTO construction. [VERIFIED: codebase grep]

**How to avoid:** make changes mechanically small and keep existing tenant/redaction assertions in the phase gate. [VERIFIED: AGENTS.md]

**Warning signs:** changes rewrite query predicates or DTO fields unrelated to `opts` handling. [VERIFIED: codebase grep]

## Code Examples

Verified patterns from official and local sources:

### Repo Default Options

```elixir
# Source: .planning/phases/75-runtime-prefix-propagation/75-CONTEXT.md
@impl true
def default_options(:transaction), do: []
def default_options(_operation), do: Chimeway.Storage.repo_opts()
```

### Explicit Prefix Probe Preservation

```elixir
# Source: lib/chimeway/storage.ex
def repo_opts(opts \\ []) do
  case validate_prefix!() do
    "chimeway" -> Keyword.put_new(opts, :prefix, "chimeway")
    false -> opts
  end
end
```

### Oban Job Query Must Not Use Chimeway Storage Options

```elixir
# Source basis: deps/oban/lib/oban/repo.ex
from(job in Oban.Job, where: job.worker == ^worker)
|> Chimeway.Repo.all(oban_job_repo_opts())
```

### Runtime Placement Assertion Shape

```elixir
# Source basis: test/chimeway/migration_contract_test.exs plus Phase 75 context
assert Repo.aggregate(Chimeway.Event, :count, :id) == 1
assert public_count("chimeway_events") == 0
assert prefixed_count("chimeway", "chimeway_events") == 1
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Missing or implicit public storage config | Explicit `prefix: false` public legacy mode or `"chimeway"` isolated mode | Phase 73 | Missing prefix config is invalid and existing public installs remain explicit. [VERIFIED: STATE.md] |
| Public-only generated migrations | Generated prefixed migrations by default with explicit public generation mode | Phase 74 | New installs can create Chimeway-owned tables in `chimeway` schema through normal migrations. [VERIFIED: STATE.md] |
| Runtime mostly bare `Repo` calls | Planned repo-wide default options plus narrow exceptions | Phase 75 | Ordinary runtime APIs should read/write the configured schema without adopter-supplied options. [VERIFIED: 75-CONTEXT.md] |
| Migration proof only | Prefixed runtime integration proof | Phase 75 | Runtime code can still leak to public without trigger/workflow/inbox/webhook/recovery tests. [VERIFIED: 75-CONTEXT.md] |

**Deprecated/outdated:**

- Treating `public` as an implicit default for Chimeway runtime storage is outdated; public mode must be explicit through `prefix: false`. [VERIFIED: STATE.md]
- Using schema prefixes as durable tenancy strategy is out of scope and should not be introduced by Phase 75. [VERIFIED: REQUIREMENTS.md]

## Assumptions Log

All claims in this research were verified from project files, installed dependency source, local commands, or official documentation. No user confirmation is needed before planning.

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| - | None | - | - |

## Open Questions

1. **Exact prefixed runtime harness shape**
   - What we know: Phase 75 requires non-async prefixed runtime proof using real Postgres and generated migrations or an equivalent normal migrate path. [VERIFIED: 75-CONTEXT.md]
   - What's unclear: whether implementation will prefer a temporary database with temporary `Chimeway.Repo` reconfiguration or a serialized `chimeway` schema inside the existing test DB. [VERIFIED: codebase grep]
   - Recommendation: plan Wave 0 to build `PrefixedRuntimeCase`; choose temporary database if restarting/reconfiguring `Chimeway.Repo` is reliable, otherwise use serialized schema setup with explicit cleanup. [VERIFIED: 75-CONTEXT.md]

2. **Named phase gate**
   - What we know: Phase 75 may add `mix verify.runtime_prefix` if kept focused, while Phase 76 owns broad gate composition. [VERIFIED: 75-CONTEXT.md]
   - What's unclear: whether the planner wants a named alias in this phase or only direct test commands. [VERIFIED: 75-CONTEXT.md]
   - Recommendation: add `mix verify.runtime_prefix` for developer ergonomics and keep it limited to unit guardrails plus the prefixed runtime integration suite. [VERIFIED: AGENTS.md]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | Tests and implementation | yes | 1.19.5 | Project minimum is 1.17+. [VERIFIED: local command] |
| Erlang/OTP | Tests and implementation | yes | 28 | Project minimum is OTP 26+. [VERIFIED: local command] |
| Mix | Test/verify aliases | yes | 1.19.5 | None needed. [VERIFIED: local command] |
| PostgreSQL service | Runtime integration tests | yes | 14.17 local server | CI should remain target-version proof for PostgreSQL 15+. [VERIFIED: local command] [VERIFIED: AGENTS.md] |
| psql client | DB inspection | yes | 14.17 | Ecto migrations/tests can run without direct psql use. [VERIFIED: local command] |
| Ecto / Ecto SQL | Repo prefix behavior and tests | yes | Ecto 3.13.6, Ecto SQL 3.13.5 | None. [VERIFIED: mix deps] |
| Oban | Worker paths and job table prefix | yes | 2.23.0 | Tests can run manual/inline where configured. [VERIFIED: mix deps] |

**Missing dependencies with no fallback:** none identified. [VERIFIED: local command]

**Missing dependencies with fallback:**

- Local PostgreSQL server is 14.17 while the project target is PostgreSQL 15+; run final acceptance in CI or a PostgreSQL 15 local service before declaring release-quality evidence. [VERIFIED: local command] [VERIFIED: AGENTS.md]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit with Ecto SQL Sandbox and Oban testing support. [VERIFIED: codebase grep] |
| Config file | `mix.exs`, `config/test.exs`, `test/support/data_case.ex`. [VERIFIED: codebase grep] |
| Quick run command | `MIX_ENV=test mix test test/chimeway/storage_test.exs --warnings-as-errors` [VERIFIED: codebase grep] |
| Phase quick command | `MIX_ENV=test mix test test/chimeway/repo_prefix_test.exs test/chimeway/runtime_prefix_integration_test.exs --warnings-as-errors` after Wave 0 creates those files. [VERIFIED: 75-CONTEXT.md] |
| Full suite command | `mix ci.test` plus `mix verify.install_golden`; add `mix verify.runtime_prefix` if the phase creates the alias. [VERIFIED: mix.exs] |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| RUN-01 | Trigger fanout writes events, notifications, deliveries, and attempts into configured prefix | integration | `MIX_ENV=test mix test test/chimeway/runtime_prefix_integration_test.exs --warnings-as-errors` | no - Wave 0 |
| RUN-02 | Duplicate idempotency, lifecycle reads, traces, explainability read configured prefix and not public | integration + unit probes | `MIX_ENV=test mix test test/chimeway/runtime_prefix_integration_test.exs test/chimeway/traces_test.exs --warnings-as-errors` | partial - traces probes exist |
| RUN-03 | Workflows, signals, digests, preferences/policy, webhooks, dispatch workers, and string-source `insert_all` propagate prefix | integration | `MIX_ENV=test mix test test/chimeway/runtime_prefix_integration_test.exs --warnings-as-errors` | no - Wave 0 |
| RUN-04 | Admin, inbox, trace, and recovery read/write surfaces remain prefixed, tenant-safe, and redacted | integration + existing focused tests | `MIX_ENV=test mix test test/chimeway/runtime_prefix_integration_test.exs test/chimeway/inbox_integration_test.exs test/chimeway/orchestration/recovery_test.exs --warnings-as-errors` | partial - public-mode tests exist |

### Sampling Rate

- **Per task commit:** run the smallest touched test plus `MIX_ENV=test mix test test/chimeway/repo_prefix_test.exs --warnings-as-errors` after Wave 0. [VERIFIED: 75-CONTEXT.md]
- **Per wave merge:** run `MIX_ENV=test mix test test/chimeway/runtime_prefix_integration_test.exs --warnings-as-errors`. [VERIFIED: 75-CONTEXT.md]
- **Phase gate:** run `mix verify.runtime_prefix` if added, plus `mix ci.test` and `mix verify.install_golden` before `$gsd-verify-work`. [VERIFIED: AGENTS.md] [VERIFIED: mix.exs]

### Wave 0 Gaps

- [ ] `test/chimeway/repo_prefix_test.exs` - covers `Repo.default_options/1`, `Storage.repo_opts/1`, explicit override preservation, and transaction default behavior. [VERIFIED: 75-CONTEXT.md]
- [ ] `test/support/prefixed_runtime_case.ex` - serialized prefix env and DB/schema/migration setup for prefixed runtime integration tests. [VERIFIED: 75-CONTEXT.md]
- [ ] `test/chimeway/runtime_prefix_integration_test.exs` - covers RUN-01 through RUN-04 with real flows. [VERIFIED: REQUIREMENTS.md]
- [ ] Direct `Oban.Job` test cleanup audit - ensure prefixed runtime tests and any shared cleanup do not query the Oban job table through Chimeway storage defaults. [VERIFIED: codebase grep]
- [ ] Optional `mix verify.runtime_prefix` alias - focused local gate for Phase 75 only. [VERIFIED: 75-CONTEXT.md]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Host app owns auth; Phase 75 must not add auth state to Chimeway runtime APIs. [VERIFIED: AGENTS.md] |
| V3 Session Management | no | No browser session handling changes in this backend-only phase. [VERIFIED: 75-CONTEXT.md] |
| V4 Access Control | yes | Preserve tenant filters and host ownership boundaries in admin, inbox, trace, and recovery queries. [VERIFIED: AGENTS.md] |
| V5 Input Validation | yes | Continue strict prefix validation through `Chimeway.Storage.validate_prefix!/0`; do not accept dynamic prefixes. [VERIFIED: codebase grep] |
| V6 Cryptography | no | No new cryptographic primitive is introduced by runtime prefix propagation. [VERIFIED: research scope] |

### Known Threat Patterns for Elixir/Ecto Prefix Routing

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Cross-schema data disclosure from accidental `public` fallback | Information Disclosure | Repo default options plus prefixed runtime tests that assert configured-schema reads/writes and practical public absence. [VERIFIED: 75-CONTEXT.md] |
| Oban job table queried through Chimeway storage prefix | Tampering / Information Disclosure | Use Oban config-derived prefix/defaults for direct `Oban.Job` queries; do not reuse `Chimeway.Storage.repo_opts/1`. [VERIFIED: deps/oban] |
| Dynamic prefix injection through API opts | Tampering | Keep prefix static per install and preserve explicit probes only as diagnostic/test escape hatches. [VERIFIED: 75-CONTEXT.md] |
| Tenant predicate regression during prefix edits | Elevation of Privilege / Information Disclosure | Keep edits scoped to repo options and rerun tenant/redaction tests for admin/inbox/trace/recovery. [VERIFIED: AGENTS.md] |
| Sensitive payload leakage in new diagnostics | Information Disclosure | Use operator language like "isolated Chimeway schema" and avoid payload-bearing telemetry/log output. [VERIFIED: AGENTS.md] [VERIFIED: 75-CONTEXT.md] |

## Sources

### Primary (HIGH confidence)

- `.planning/phases/75-runtime-prefix-propagation/75-CONTEXT.md` - locked decisions, discretion, verification scope, and implementation sketches. [VERIFIED: codebase file read]
- `.planning/REQUIREMENTS.md` - RUN-01 through RUN-04 and out-of-scope constraints. [VERIFIED: codebase file read]
- `.planning/STATE.md` - Phase 73/74 decisions and current phase position. [VERIFIED: codebase file read]
- `AGENTS.md` - project constraints, stack, lifecycle, explainability, and quality gates. [VERIFIED: AGENTS.md]
- `lib/chimeway/storage.ex`, `lib/chimeway/repo.ex`, `lib/chimeway/trigger.ex`, `lib/chimeway/dispatch/oban.ex` - current implementation hotspots. [VERIFIED: codebase grep]
- `deps/ecto/lib/ecto/repo.ex` - default option merge behavior and transaction option preparation. [VERIFIED: deps/ecto]
- `deps/oban/lib/oban/job.ex`, `deps/oban/lib/oban/repo.ex`, `deps/oban/lib/oban/config.ex` - Oban job schema and Oban prefix handling. [VERIFIED: deps/oban]

### Secondary (MEDIUM confidence)

- Ecto Repo docs - operation options, `default_options/1`, and `insert_all` source forms. [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html]
- Ecto query-prefix guide - query and schema operation prefix semantics. [CITED: https://hexdocs.pm/ecto/multi-tenancy-with-query-prefixes.html]
- Ecto Multi docs - `Multi.run/3` callback repo semantics. [CITED: https://hexdocs.pm/ecto/Ecto.Multi.html]
- Ecto Schema docs - `@schema_prefix` behavior. [CITED: https://hexdocs.pm/ecto/Ecto.Schema.html]
- Ecto SQL Sandbox docs - non-async/shared process testing guidance. [CITED: https://hexdocs.pm/ecto_sql/Ecto.Adapters.SQL.Sandbox.html]
- Oban testing docs - testing prefix support and default public behavior. [CITED: https://hexdocs.pm/oban/testing.html]
- Oban migration docs - Oban job-table prefix support. [CITED: https://hexdocs.pm/oban/Oban.Migration.html]

### Tertiary (LOW confidence)

- None used for recommendations. Context7 was unavailable in the local environment, so official docs and installed dependency source were used directly. [VERIFIED: local command]

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH - package versions, local tool versions, and project constraints were verified from local commands and files. [VERIFIED: mix deps]
- Architecture: HIGH - runtime hotspots and dependency prefix behavior were verified from codebase grep and installed dependency source. [VERIFIED: codebase grep] [VERIFIED: deps/ecto] [VERIFIED: deps/oban]
- Pitfalls: HIGH - pitfalls are derived from locked Phase 75 decisions plus confirmed current code paths. [VERIFIED: 75-CONTEXT.md] [VERIFIED: codebase grep]
- Validation: MEDIUM - existing test infrastructure is verified, while exact new prefixed runtime harness shape remains a planning choice. [VERIFIED: codebase grep]

**Research date:** 2026-07-01  
**Valid until:** 2026-07-31 for project-local planning; re-check Ecto/Oban docs and dependency versions if planning starts after that date.
