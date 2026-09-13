# Phase 97: Tenant Identity & Compatible Upgrade - Context

**Gathered:** 2026-08-11 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Make notification lifecycle identity, queries, mutations, and upgrade behavior safe within an explicit tenant boundary. This phase adds immutable tenant identity to events and notifications, scopes event idempotency and operator-facing lifecycle operations by tenant, provides an explicit single-tenant compatibility path, and gives legacy adopters a non-guessing additive reconciliation path. Dynamic database prefixes, privacy redaction, multi-installation delivery, APNs dispatch, and CrossWake registration/open behavior remain outside this phase.

</domain>

<decisions>
## Implementation Decisions

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

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Active milestone contract

- `.planning/ROADMAP.md` — Phase 97 goal, fixed boundary, and four success criteria.
- `.planning/REQUIREMENTS.md` — TENANT-01, TENANT-02, and TENANT-03 acceptance requirements.
- `.planning/PROJECT.md` — v1.18 ownership boundaries, local-first posture, explainability requirements, and explicit exclusion of dynamic per-tenant database prefixes.
- `.planning/METHODOLOGY.md` — decisive, research-first, fail-closed, durable-explainability, and least-surprise decision lenses.

### Locked storage and migration contracts

- `.planning/milestones/v1.13-phases/73-storage-prefix-contract/73-CONTEXT.md` — strict static storage-prefix values and rejection of dynamic/per-tenant prefixes.
- `.planning/milestones/v1.13-phases/74-prefixed-migration-generator/74-CONTEXT.md` — deterministic copied migrations, one canonical template tree, and dual static storage-mode proof.
- `.planning/milestones/v1.13-phases/75-runtime-prefix-propagation/75-CONTEXT.md` — Repo-owned static prefix propagation and prohibition on prefix options in ordinary public APIs.
- `.planning/milestones/v1.13-phases/76-prefix-docs-demo-and-gates/76-CONTEXT.md` — explicit legacy storage compatibility, additive adopter guidance, and verification parity.

### Existing public-surface contracts

- `.planning/milestones/v1.11-phases/70-recovery-auth-and-tenancy-hardening/70-CONTEXT.md` — host-owned tenancy/auth boundaries and recovery safety constraints.
- `.planning/milestones/v1.9-phases/61-inbox-headless-package/61-CONTEXT.md` — existing inbox API and compatibility shapes that Phase 97 must upgrade safely.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `Chimeway.Trigger`: already fetches and validates `opts[:tenant_id]`, providing the natural source for event and notification tenant persistence.
- Existing delivery and workflow tenant fields: demonstrate current tenant propagation and offer consistency checks, but must not become the ownership source for events or notifications.
- `Chimeway.Install.Migrations` plus `priv/chimeway_migrations/`: existing deterministic migration generator and canonical template tree for additive upgrade artifacts.
- Existing installer golden tests, runtime-prefix proof, release-gate contracts, and Postgres integration cases: reusable executable evidence for both static storage modes and upgrade behavior.

### Established Patterns

- Chimeway uses UUID durable lifecycle rows and stable data identities, with transaction-based trigger fanout through `Ecto.Multi`.
- Public lifecycle contexts use explicit query construction and established not-found/empty outcomes; tenant enforcement should extend those predicates rather than add ambient process state.
- Static storage routing belongs to `Chimeway.Repo.default_options/1` and `Chimeway.Storage.repo_opts/1`; ordinary APIs do not accept Ecto prefix options.
- Generated host migrations are reviewable, deterministic, explicitly schema-aware, and exercised in both isolated-schema and public legacy modes.

### Integration Points

- `lib/chimeway/trigger.ex`, `lib/chimeway/events/event.ex`, and `lib/chimeway/notifications/notification.ex` for tenant persistence and composite idempotency.
- `lib/chimeway/inbox.ex`, `lib/chimeway/traces.ex`, `lib/chimeway/admin.ex`, and `lib/chimeway/deliveries.ex` for tenant-scoped reads and mutations.
- `chimeway_inbox/` and `chimeway_admin/` public delegates/auth seams for explicit tenant propagation without weakening host ownership.
- `priv/chimeway_migrations/`, installer fixtures/goldens, and migration tasks for additive schema changes, reconciliation evidence, and legacy ownership assignment.
- Focused unit, Postgres integration, generated-migration, runtime-prefix, ecosystem `verify.*`, and release-gate tests for machine-executable acceptance evidence.

</code_context>

<specifics>
## Specific Ideas

- Compatibility should look conceptually like “single-tenant mode for tenant X,” not merely `compatibility: true`.
- Tenant-scoped lookups should make a wrong-tenant UUID indistinguishable from a missing UUID at the public boundary.
- Reconciliation evidence should identify ambiguous legacy rows without fabricating ownership and should be suitable for executable verification.

</specifics>

<deferred>
## Deferred Ideas

None — analysis stayed within phase scope.

</deferred>

---

*Phase: 97-tenant-identity-compatible-upgrade*
*Context gathered: 2026-08-11*
