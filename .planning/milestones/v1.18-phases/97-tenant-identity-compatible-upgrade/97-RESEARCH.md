# Phase 97: Tenant Identity & Compatible Upgrade - Research

**Researched:** 2026-08-11  
**Domain:** Elixir/Ecto/PostgreSQL tenant-scoped durable lifecycle upgrade  
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

### Durable Tenant Identity

- **D-01:** Persist an immutable `tenant_id` directly on every new event and notification. Tenant ownership must be available from the lifecycle row itself rather than inferred from deliveries, workflow runs, recipient identity, or other optional child state.
- **D-02:** Enforce event idempotency by the composite identity `{tenant_id, idempotency_key}`. Duplicate recovery must query by both values, so the same idempotency key can create independent events in different tenants.
- **D-03:** Propagate the explicitly supplied tenant through the trigger transaction into both event and notification writes. Retain stable `notification_key` plus version as durable notification definition identity; tenant identity supplements rather than replaces that contract.

### Explicit Tenant-Scoped Public Boundary

- **D-04:** Inbox, trace, admin, and recovery operations must require an explicit tenant scope and include it in every underlying read, reload, nested lookup, and mutation predicate. A UUID or recipient identity alone is never sufficient authority.
- **D-05:** Formerly unscoped signatures fail closed by default. They may continue only when the host explicitly enables single-tenant compatibility and configures the one tenant identity those calls represent.
- **D-06:** Compatibility configuration must declare a concrete tenant identity; a boolean compatibility switch or fabricated default tenant is insufficient because Chimeway must not guess ownership.
- **D-07:** Cross-tenant and absent-row outcomes must not disclose whether lifecycle state exists outside the supplied tenant. Preserve each surface's established not-found/empty/error contract while enforcing the tenant predicate.

### Non-Guessing Additive Upgrade

- **D-08:** Ship additive migration changes for tenant identity and tenant-scoped indexes. Existing rows must not be assigned a sentinel such as `"default"` and Chimeway must not infer ownership from recipient, delivery, workflow, actor, or storage-prefix data.
- **D-09:** Produce explicit reconciliation evidence for legacy rows whose tenant ownership has not been assigned. Only host-supplied reconciliation may assign ownership and make those rows available through tenant-scoped lifecycle operations.
- **D-10:** Keep Chimeway's storage routing static per host installation. Tenant scope is durable row identity and a query/mutation predicate, never an Ecto prefix, dynamic database prefix, Oban prefix, or per-request storage route.
- **D-11:** Preserve the existing deterministic copied-migration model and both static storage modes (`prefix: "chimeway"` and explicit `prefix: false`) while adding the upgrade/reconciliation path.

### the agent's Discretion

- Exact public option/config key names, provided they express a concrete compatibility tenant and preserve fail-closed defaults.
- Exact reconciliation report/task interface and staged constraint mechanics, provided evidence is machine-readable, no ownership is guessed, and host assignment is explicit.
- Exact internal helper/module boundaries and structured error names, provided all public and nested lifecycle paths enforce one coherent tenant-scope contract.

### Deferred Ideas (OUT OF SCOPE)

None — analysis stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|---|---|---|
| TENANT-01 | Persist immutable event/notification tenant identity and tenant-scoped event idempotency. | Add durable columns, composite unique index, composite conflict recovery, and transaction propagation. |
| TENANT-02 | Scope lifecycle reads/mutations explicitly; allow only configured concrete single-tenant compatibility. | Centralize scope resolution and apply it to every query, update, reload, preload, and optional Phoenix delegate. |
| TENANT-03 | Make additive upgrades reconcilable without inferred ownership or storage-prefix changes. | Append copied migration template(s), retain NULL for legacy ambiguity, expose JSON evidence and explicit host assignment. |
</phase_requirements>

## Summary

Phase 97 is a durable identity migration plus a public-boundary hardening pass, not a delivery-row filter change. Events currently have globally unique `idempotency_key` and no `tenant_id`; notifications likewise have no tenant field. The trigger already validates `opts[:tenant_id]`, but only passes it to workflow-run insertion and later delivery planning. [VERIFIED: codebase grep]

Use the tenant supplied at `Chimeway.trigger/3` as the one transaction-local ownership value: write it onto the event and every notification row, declare the `{tenant_id, idempotency_key}` uniqueness contract in both the database and changeset, and recover duplicate events using both fields. A lifecycle query must resolve one required tenant before any database work; it must never discover ownership from delivery/workflow children. [VERIFIED: codebase grep]

For installed adopters, add nullable tenant columns and the new tenant-scoped index without backfilling a fake owner. Existing `NULL` rows remain deliberately unavailable to tenant-scoped operations until a host explicitly assigns them. Chimeway's generated migration architecture already supports one canonical prefix-aware template tree and both static storage modes, so the upgrade must extend that model rather than introduce dynamic prefixes. [VERIFIED: codebase grep]

**Primary recommendation:** Implement a small `Chimeway.TenantScope`/configuration seam that returns either an explicit nonblank tenant or a configured concrete compatibility tenant; every public lifecycle entrypoint consumes this seam before composing its Ecto query.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|---|---|---|---|
| Immutable event/notification ownership | Database / Storage | API / Backend | Durable rows and uniqueness constraints own tenant identity; trigger supplies the value. [VERIFIED: codebase grep] |
| Idempotent trigger recovery | API / Backend | Database / Storage | Trigger maps the unique-constraint conflict to the existing event, while PostgreSQL enforces the composite identity. [VERIFIED: codebase grep] |
| Inbox, trace, admin, recovery tenant enforcement | API / Backend | Frontend Server (SSR) | Core contexts add predicates; optional LiveViews only pass host-provided scope and authorization context. [VERIFIED: codebase grep] |
| Single-tenant compatibility | API / Backend | — | Application config converts old calls to one declared tenant; no browser/session default may fabricate ownership. [VERIFIED: codebase grep] |
| Legacy reconciliation evidence and assignment | Database / Storage | API / Backend | Database state provides the candidates; a bounded maintenance interface reports and assigns host-supplied tenant IDs. [VERIFIED: codebase grep] |
| Storage routing | Database / Storage | — | Existing `Chimeway.Storage` maps a single static host prefix to Repo options; tenant is not a storage route. [VERIFIED: codebase grep] |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---|---|---|---|
| `ecto_sql` / `ecto` | locked 3.13.5 / 3.13.x | Schema changes, query predicates, changesets, transactions. | Already the project persistence layer; Ecto migration APIs provide `alter`, nullable `add`, `unique_index`, `flush`, and explicit `up/down` paths. [VERIFIED: codebase grep] [CITED: https://ecto-sql.hexdocs.pm/Ecto.Migration.html] |
| PostgreSQL | local CLI 14.17; project contract 15+ | Durable tenant columns, indexes, atomic updates. | Existing repository contract and migration tests target Postgres. [VERIFIED: codebase grep] |

### Supporting

| Library | Version | Purpose | When to Use |
|---|---|---|---|
| Existing `Chimeway.Storage` | project internal | Static Repo prefix handling. | Preserve its `prefix: "chimeway"` / `prefix: false` behavior; drop tenant options before it produces Repo opts. [VERIFIED: codebase grep] |
| Existing `Chimeway.Install.Migrations` | project internal | Deterministic copied host migration generation. | Append canonical migration template(s), then refresh both public and prefixed fixtures. [VERIFIED: codebase grep] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|---|---|---|
| Durable row tenant columns | Infer tenant from deliveries/workflow/recipient | Rejected by locked D-01/D-08: optional child state cannot be an ownership authority. |
| Tenant predicates | Dynamic Ecto/Oban/database prefixes | Rejected by locked D-10 and the established static-prefix contract. [VERIFIED: codebase grep] |
| Explicit compatibility tenant | `single_tenant: true` or default `"default"` | Rejected by locked D-05/D-06: a boolean/sentinel does not identify ownership. |

**Installation:** No external packages. This phase uses the locked project dependencies only. [VERIFIED: codebase grep]

## Architecture Patterns

### System Architecture Diagram

```text
Host trigger(opts: [tenant_id: T])
  -> Tenant scope validation
  -> Ecto.Multi transaction
       -> Event{tenant_id: T, idempotency_key: K}
       -> Notification{tenant_id: T, event_id: E}
       -> workflow/delivery planning with T
  -> composite conflict {T, K} -> reload Event where tenant_id == T

Inbox / Trace / Admin / Recovery API
  -> explicit T OR configured compatibility tenant
  -> all root + nested queries / update_all predicates include T
  -> wrong-tenant row -> existing empty/not_found/noop contract

Legacy migration
  -> nullable event/notification tenant columns + composite index
  -> JSON reconciliation report for NULL ownership
  -> host-supplied assignment {row_id, tenant_id}
  -> tenant-scoped lifecycle availability
```

### Recommended Project Structure

```text
lib/chimeway/
├── tenant_scope.ex                 # explicit/compatibility scope normalization and errors
├── reconciliation.ex               # report + explicit assignment maintenance interface
├── trigger.ex                      # tenant propagation and duplicate lookup
├── inbox.ex                        # scoped read/lifecycle transitions
├── traces.ex                       # scoped root reads and nested preloads
├── admin.ex                        # scoped DTO/recovery candidate queries
└── deliveries.ex                   # scoped recovery reads, claims, reloads and replan
priv/chimeway_migrations/
└── 032_add_tenant_identity_to_events_and_notifications.exs
```

### Pattern 1: Resolve scope once, fail before querying

**What:** A single helper accepts an explicit nonblank `:tenant_id`, or—only for legacy call signatures—uses a configured nonblank compatibility tenant. Missing/invalid scope returns a stable error and does not run an unscoped query. [VERIFIED: codebase grep]

**When to use:** Every public core function and every delegate/LiveView call that can read or mutate lifecycle state. `tenant_id` passed through options must be consumed as a query predicate, never forwarded as an Ecto prefix. [VERIFIED: codebase grep]

```elixir
# Source: project pattern + locked D-04/D-06
with {:ok, tenant_id} <- Chimeway.TenantScope.resolve(opts) do
  query = from n in Notification,
    where: n.id == ^notification_id and n.tenant_id == ^tenant_id,
    where: n.recipient_identity == ^recipient_identity

  case Repo.update_all(query, set: [read_at: timestamp, updated_at: timestamp]) do
    {1, _} -> :ok
    {0, _} -> {:error, :not_found}
  end
end
```

### Pattern 2: Database uniqueness and conflict lookup agree

**What:** Insert `tenant_id` into Event changesets, add the changeset named unique constraint for the composite database index, and use the same `{tenant_id, idempotency_key}` predicate on conflict recovery. [VERIFIED: codebase grep]

```elixir
# Source: Ecto changeset/migration APIs + project Trigger pattern
create unique_index(:chimeway_events, [:tenant_id, :idempotency_key],
  name: :chimeway_events_tenant_id_idempotency_key_index
)

Repo.get_by(Event, tenant_id: tenant_id, idempotency_key: idempotency_key)
```

Ecto migrations support `alter`, nullable columns, `unique_index`, `flush`, and explicit `up/down`; PostgreSQL migrations run transactionally where possible. [CITED: https://ecto-sql.hexdocs.pm/Ecto.Migration.html]

### Pattern 3: Non-guessing staged upgrade

**What:** Add nullable `tenant_id` to events and notifications, create tenant-scoped indexes, and leave legacy rows `NULL`. Emit a deterministic JSON report with row type/id/count and `tenant_id: null`; require a host-supplied tenant value for each assignment operation. [VERIFIED: codebase grep]

**Important:** The precise enforcement rollout should be planned as two states: new writes require nonblank tenants at the application/schema boundary immediately; legacy NULL rows remain reportable/reconcilable until the host completes assignment. Do not make a global `NOT NULL` migration part of this phase unless the migration contract includes a safe adopter-controlled completion gate. [CITED: https://ecto-sql.hexdocs.pm/Ecto.Migration.html]

### Anti-Patterns to Avoid

- **Tenant fallback from child rows:** Existing inbox signal code derives tenant from workflow/delivery rows; replace this with `notification.tenant_id`. [VERIFIED: codebase grep]
- **Optional filter helpers:** `maybe_filter_tenant(query, nil)` currently permits unscoped Admin queries; scope resolution must happen before query construction. [VERIFIED: codebase grep]
- **Unscoped re-fetch after a scoped update:** Recovery's `get!`, event reload, notifications reload, and trace `preload` must retain tenant predicates. [VERIFIED: codebase grep]
- **Sentinel backfill:** A prior delivery migration writes `"default"`; Phase 97 must not repeat that behavior for event/notification ownership. [VERIFIED: codebase grep]
- **Storage-prefix coupling:** Never pass `tenant_id` as `:prefix`, add a dynamic prefix config, or change Oban routing. [VERIFIED: codebase grep]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| Atomic tenant/idempotency enforcement | In-memory duplicate map | PostgreSQL composite unique index + Ecto unique constraint | Works across nodes and concurrent triggers. [VERIFIED: codebase grep] |
| Database change application | Bespoke runtime DDL/task that mutates host schema | Existing copied Ecto migration templates/generator | Existing dual static-prefix golden and migration proof is the project contract. [VERIFIED: codebase grep] |
| Tenant authorization/membership | Chimeway tenant ACL | Host auth seams (`ChimewayAdmin.Auth`, inbox auth) | Host retains identity, membership, and policy ownership. [VERIFIED: codebase grep] |
| Wrong-tenant disclosure handling | Separate “forbidden” lifecycle result | Existing not-found/empty/noop public outcome shape after tenant predicate | Locked D-07 requires no existence disclosure. |

**Key insight:** The database should establish tenant identity and uniqueness, while host auth decides whether a caller may claim a tenant scope; Chimeway must not blur those separate responsibilities. [VERIFIED: codebase grep]

## Runtime State Inventory

| Category | Items Found | Action Required |
|---|---|---|
| Stored data | `chimeway_events` and `chimeway_notifications` lack `tenant_id`; delivery migration 030 contains prior inferred `"default"` values. [VERIFIED: codebase grep] | Add nullable columns/indexes; report NULL legacy event/notification rows; do not infer/backfill ownership. Data migration only occurs through explicit host reconciliation. |
| Live service config | No live external tenant config is versioned in this repo. [VERIFIED: codebase grep] | Add documented application configuration requiring a concrete compatibility tenant if old signatures are enabled; host deploys it. |
| OS-registered state | None found in repository inspection. [VERIFIED: codebase grep] | None. |
| Secrets/env vars | No tenant-identity secret/env-key contract found in tracked configuration. [VERIFIED: codebase grep] | None; compatibility tenant is ordinary app config, not a Chimeway-owned secret. |
| Build artifacts | Generated host migration files and committed public/prefixed golden fixture trees encode the migration template count/output. [VERIFIED: codebase grep] | Add template, update both fixture trees/stdout/contracts, and prove generator idempotency. |

## Common Pitfalls

### Pitfall 1: Composite index with old global index still active

**What goes wrong:** Keeping the old unique `idempotency_key` index prevents two tenants from using the same key.  
**How to avoid:** The migration must replace or remove the global unique index and both the Event changeset and Trigger conflict detector must use the new index name. [VERIFIED: codebase grep]

### Pitfall 2: Scope only at the outer fetch

**What goes wrong:** A scoped event fetch followed by unscoped preload, reload, `Repo.get!`, `Repo.get_by`, or nested query can leak/mutate cross-tenant state.  
**How to avoid:** Treat scope as required input to every query function; use tenant predicates in all direct reads, joins, preloads, atomic updates, and recovery reloads. [VERIFIED: codebase grep]

### Pitfall 3: Admin/UI looks scoped but core remains permissive

**What goes wrong:** `ChimewayAdmin.Context.read_opts/2` passes tenant when present but accepts absence, while core `Admin` has nil/no-op filter branches.  
**How to avoid:** Core APIs fail closed; optional packages surface the stable error/empty contract only after the host supplies scope and authorizes it. [VERIFIED: codebase grep]

### Pitfall 4: Reconciliation makes ambiguous rows visible too early

**What goes wrong:** A report process or compatibility default turns NULL legacy rows into a guessed tenant.  
**How to avoid:** Keep `tenant_id IS NULL` rows excluded from tenant-scoped lifecycle queries; report them as ambiguous and only update them with a supplied tenant ID. [VERIFIED: codebase grep]

### Pitfall 5: Prefix regression hidden by unit tests

**What goes wrong:** New migration helpers/queries work in public schema but omit the static `chimeway` prefix path.  
**How to avoid:** Extend the existing generated-migration golden, DB migration-contract, and runtime-prefix suites for both `prefix: "chimeway"` and `prefix: false`. [VERIFIED: codebase grep]

## Code Examples

### Scoped trace lookup that preserves non-disclosure

```elixir
# Source: project Traces contract + locked D-07
def get_trace(event_id, opts) do
  with {:ok, tenant_id} <- TenantScope.resolve(opts) do
    case Repo.one(from(e in Event, where: e.id == ^event_id and e.tenant_id == ^tenant_id)) do
      nil -> {:error, :not_found}
      event -> {:ok, Repo.preload(event, [notifications: [deliveries: :attempts]])}
    end
  end
end
```

### Machine-readable ambiguity report shape

```json
{
  "schema_version": 1,
  "status": "ambiguous_tenant_ownership",
  "events": [{"id": "uuid", "tenant_id": null}],
  "notifications": [{"id": "uuid", "event_id": "uuid", "tenant_id": null}],
  "counts": {"events": 1, "notifications": 1},
  "assignment": "host must explicitly supply tenant_id; no inference performed"
}
```

This is a recommended contract shape under the phase's discretion, not an existing public API. [ASSUMED]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|---|---|---|---|
| Tenant on workflow/delivery children and optional filters | Immutable tenant ownership on event + notification, enforced at all lifecycle boundaries | Phase 97 | Enables tenant-safe idempotency, queries, and future delivery targets. [VERIFIED: codebase grep] |
| Global event idempotency key | `{tenant_id, idempotency_key}` database identity | Phase 97 | Same key may represent independent tenant events. |
| Sentinel/default backfill | Explicit ambiguous-row reconciliation | Phase 97 | No false ownership claim. |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|---|---|---|
| A1 | A JSON report with `schema_version`, per-row IDs, counts, and explicit assignment statement is the selected reconciliation interface shape. | Code Examples | Resolved by the plan-selected callable module plus strict JSON Mix task contract below. |

## Open Questions (RESOLVED)

1. **RESOLVED — What exact compatibility API preserves source compatibility without weakening fail-closed behavior?**
   - Selected contract: `config :chimeway, :single_tenant_compatibility, tenant_id: "<host-tenant-id>"` is the only compatibility declaration. `Chimeway.TenantScope.resolve/1` gives an explicit nonblank `opts[:tenant_id]` precedence, otherwise accepts only that nested concrete tenant value. Missing scope returns `{:error, :tenant_scope_required}`; a present but malformed compatibility value returns `{:error, :invalid_compatibility_tenant}`. All former unscoped arities invoke this resolver and no boolean or fabricated default is accepted. This is the concrete plan-selected API under D-05/D-06.

2. **RESOLVED — How is host reconciliation invoked?**
   - Selected contract: `Chimeway.Reconciliation.report/1` returns the versioned JSON-safe ambiguity map and `assign_event_tree/3` performs explicit host-supplied assignment. The strict `Mix.Tasks.Chimeway.ReconcileTenants` wrapper accepts exactly `--report` or the pair `--event-id UUID --tenant-id TENANT`, delegates to the callable module, emits exactly one Jason-encoded JSON object, and raises `Mix.Error` for invalid combinations or failed assignment. This is the concrete plan-selected interface under D-09.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|---|---|---|---|---|
| Elixir/Mix | Compile/tests/migrations | ✓ | OTP 28 runtime observed | — [VERIFIED: local command] |
| PostgreSQL | Migration and tenant integration proofs | ✓ | psql 14.17; localhost accepts connections | CI/project contract is PostgreSQL 15+. [VERIFIED: local command] |
| Docker | Existing integration test environment when needed | ✓ | 29.5.2 | Local PostgreSQL service. [VERIFIED: local command] |

**Missing dependencies with no fallback:** None. [VERIFIED: local command]

## Validation Architecture

### Test Framework

| Property | Value |
|---|---|
| Framework | ExUnit with Ecto/PostgreSQL integration tests. [VERIFIED: codebase grep] |
| Config file | `test/test_helper.exs` plus `config/test.exs`. [VERIFIED: codebase grep] |
| Quick run command | `mix test test/chimeway/trigger_pipeline_test.exs test/chimeway/inbox_query_test.exs test/chimeway/traces_test.exs test/chimeway/admin_test.exs test/chimeway/orchestration/recovery_test.exs --warnings-as-errors` |
| Full suite command | `mix ci.test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|---|---|---|---|---|
| TENANT-01 | Same idempotency key succeeds in two tenants; duplicates only within tenant; Event/Notification tenant cannot change. | DB integration + unit | focused trigger pipeline test | ❌ Wave 0 |
| TENANT-02 | Missing scope fails; wrong tenant matches not-found/empty/noop; every listed surface scopes reads/mutations; configured compatibility succeeds. | unit + integration + package tests | focused core/inbox/admin/traces/recovery tests and `mix verify.inbox`, `mix verify.admin` | ❌ Wave 0 |
| TENANT-03 | Both copied migration modes generate/apply; legacy NULL report is JSON; explicit assignment works; no sentinel/dynamic prefix. | migration contract + installer golden + DB integration | `mix verify.install_golden` and `mix verify.runtime_prefix` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** the focused test command for changed context plus `mix format --check-formatted`.
- **Per wave merge:** `mix ci.test` and the applicable `mix verify.install_golden`, `mix verify.runtime_prefix`, `mix verify.inbox`, and `mix verify.admin` gates. [VERIFIED: codebase grep]
- **Phase gate:** Full suite and all affected named verification entrypoints green; no conversational UAT for machine-testable tenant isolation. [VERIFIED: AGENTS.md]

### Wave 0 Gaps

- [ ] `test/chimeway/tenant_identity_test.exs` — TENANT-01 event/notification tenant persistence, immutability, and idempotency.
- [ ] `test/chimeway/tenant_scope_contract_test.exs` — TENANT-02 core surface matrix and compatibility failure/success cases.
- [ ] Installer/migration contract additions — TENANT-03 public and prefixed golden outputs, NULL rows, report/assignment, and static prefix invariants.
- [ ] `chimeway_inbox` and `chimeway_admin` tenant-context tests — require explicit tenant propagation and absence fail-closed behavior.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---|---|---|
| V2 Authentication | Yes | Host-owned inbox/admin auth seams must provide/authorize the tenant context; Chimeway does not authenticate identities. [VERIFIED: codebase grep] |
| V3 Session Management | Yes | Re-read host context at LiveView event time for mutations, retaining existing authorization design. [VERIFIED: codebase grep] |
| V4 Access Control | Yes | Required tenant predicate on every lifecycle read/update/reload; wrong scope uses indistinguishable absent result. |
| V5 Input Validation | Yes | Validate nonblank binary tenant IDs at trigger, scope resolution, compatibility config, and reconciliation assignment. [VERIFIED: codebase grep] |
| V6 Cryptography | No | This phase adds neither secret handling nor cryptographic data. [VERIFIED: codebase grep] |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---|---|---|
| UUID/recipient enumeration across tenants | Information Disclosure | Scope all root/nested read and mutation predicates; preserve not-found/empty/noop. |
| Cross-tenant recovery mutation | Tampering / Elevation of Privilege | Scope the atomic claim/update and every subsequent reload/replan by tenant. [VERIFIED: codebase grep] |
| Legacy ownership fabrication | Tampering | Nullable legacy rows plus machine-readable report and host-supplied assignment only. |
| Prefix-based tenant routing | Elevation of Privilege / DoS | Retain exactly one static host prefix; never derive prefix from tenant input. [VERIFIED: codebase grep] |

## Project Constraints (from AGENTS.md)

- Use Elixir 1.17+/OTP 26+, Ecto 3.x with PostgreSQL 15+, optional Phoenix/Oban/Swoosh integration surfaces.
- Preserve stable `notification_key` + version and the durable event → notification → delivery → attempt spine.
- Treat idempotency and suppression reasons as first-class behavior; keep adapter seams replaceable and host ownership of auth, tenancy, URL generation, and correlation IDs.
- Maintain `mix verify.*` and `mix ci.*` entrypoints with CI/local parity; avoid sensitive payload leakage.
- Machine-test objective verification and use executable CI evidence rather than conversational UAT. [VERIFIED: AGENTS.md]

## Sources

### Primary (HIGH confidence)

- Project source: `lib/chimeway/trigger.ex`, event/notification schemas, Inbox, Traces, Admin, Deliveries, Storage, copied migration generator/template tree, and tests — current gaps and reusable patterns. [VERIFIED: codebase grep]
- Phase 97 context, requirements, roadmap, and prior Phase 70/73/74 contexts — locked boundary, host ownership, and static-prefix contracts. [VERIFIED: codebase grep]

### Secondary (MEDIUM confidence)

- [Ecto.Migration 3.14.0 documentation](https://ecto-sql.hexdocs.pm/Ecto.Migration.html) — `alter`, nullable `add`, index helpers, prefix support, `flush`, `up/down`, and transactional migration notes. [CITED: https://ecto-sql.hexdocs.pm/Ecto.Migration.html]
- [PostgreSQL ALTER TABLE documentation](https://www.postgresql.org/docs/current/sql-altertable.html) and [CREATE INDEX documentation](https://www.postgresql.org/docs/current/sql-createindex.html) — consulted for current PostgreSQL DDL/index semantics. [CITED: https://www.postgresql.org/docs/current/sql-altertable.html]

### Tertiary (LOW confidence)

- None; the recommended report/task interface is explicitly logged as an assumption.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — locked project dependencies and live lockfile/source verified.
- Architecture: HIGH — locked decisions align with identified transaction/query/migration seams.
- Pitfalls: HIGH — each is evidenced by current unscoped/fallback code or locked migration boundary.

**Research date:** 2026-08-11  
**Valid until:** 2026-09-10
