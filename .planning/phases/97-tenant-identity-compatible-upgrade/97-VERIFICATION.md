---
phase: 97-tenant-identity-compatible-upgrade
verified: 2026-08-12T16:17:49Z
status: gaps_found
score: 3/4 must-haves verified
behavior_unverified: 0
overrides_applied: 0
gaps:
  - truth: "Hosts can safely identify and query lifecycle state using the same explicit tenant identity supplied to Trigger."
    status: failed
    reason: "Trigger accepts a whitespace-padded nonblank tenant ID but persists the untrimmed value; every scoped reader trims that value first, making the resulting tree unqueryable through the accepted tenant identity."
    artifacts:
      - path: "lib/chimeway/trigger.ex"
        issue: "fetch_tenant_id/1 returns the original input and validate_tenant_id/1 only checks it; do_trigger/7 persists the uncanonical value."
      - path: "lib/chimeway/tenant_scope.ex"
        issue: "resolve/1 canonically trims tenant input, so it cannot address Trigger's padded rows."
    missing:
      - "Normalize tenant_id once at the trigger write boundary and propagate that canonical value through events, notifications, and dispatch options."
      - "Add a regression test that triggers with padded tenant input and retrieves the trace with the canonical tenant ID."
  - truth: "An adopter can safely upgrade and retain the migration down/up contract after valid tenant-scoped idempotency activity."
    status: failed
    reason: "Both migration down functions recreate the old globally unique idempotency index while valid rows with the same key in different tenants still exist; PostgreSQL rejects that index creation."
    artifacts:
      - path: "priv/repo/migrations/20260812000000_add_tenant_identity_to_events_and_notifications.exs"
        issue: "down/0 recreates chimeway_events_idempotency_key_index after only dropping the tenant-scoped index."
      - path: "priv/chimeway_migrations/032_add_tenant_identity_to_events_and_notifications.exs"
        issue: "Copied installer migration has the same rollback failure."
    missing:
      - "Make the migration explicitly irreversible with a clear error, or implement and document a deterministic loss-aware downgrade before recreating global uniqueness."
      - "Add a migration regression test covering two tenants with the same idempotency_key."
---

# Phase 97: Tenant Identity & Compatible Upgrade Verification Report

**Phase Goal:** Hosts can safely identify, query, and upgrade notification lifecycle state within an explicit tenant boundary.
**Verified:** 2026-08-12T16:17:49Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | A host can create independent events with the same idempotency key in two tenants without collision, and each resulting notification retains its immutable tenant identity. | ✓ VERIFIED | `tenant_identity_test.exs` exercises same-key isolation, concurrent same-tenant convergence, persistence, and immutability; the focused suite passed. |
| 2 | A host cannot read or mutate inbox, trace, admin, or recovery state outside the tenant it explicitly supplies. | ✓ VERIFIED | `TenantScope.resolve/1` is applied before core queries/mutations; tenant predicates are present in `Traces`, `Inbox`, `Admin`, and `Deliveries`. Core and package cross-tenant tests passed. |
| 3 | A legacy single-tenant host continues only after it explicitly enables compatibility configuration; otherwise formerly unscoped calls fail closed. | ✓ VERIFIED | `TenantScope.compatibility_tenant/0` accepts only a concrete nonblank configured value; `tenant_scope_contract_test.exs` proves missing/malformed configuration fails closed. |
| 4 | An adopter can apply additive migrations, receive ambiguous-row reconciliation evidence, and assign ownership without inference or storage-prefix changes. | ✗ FAILED | Additive/reconciliation/static-prefix behavior is implemented and tested, but the submitted down migrations fail after valid cross-tenant duplicate idempotency keys, so the planned safe down/up upgrade contract is not achieved. |

**Score:** 3/4 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact group | Expected | Status | Details |
| --- | --- | --- | --- |
| `tenant_scope.ex`, event/notification schemas, `trigger.ex`, `traces.ex` | Durable tenant identity, validation, trigger propagation, and trace lookup | ⚠️ PARTIAL | All exist, are substantive, and are wired. Trigger does not propagate the canonical trimmed tenant identity that `TenantScope` resolves. |
| `inbox.ex`, `admin.ex`, `deliveries.ex`, `chimeway.ex` | Tenant-scoped core read/mutate/recovery APIs | ✓ VERIFIED | All resolve scope and use `tenant_id` in relevant Ecto predicates; no tenant-to-prefix routing found. |
| Inbox/Admin auth, context, and LiveViews | Host-selected authorized tenant passed to package reads/mutations | ✓ VERIFIED | `Context.read_opts/2` and `recovery_opts/3` usages cover all listed Admin LiveViews; Inbox assigns tenant alongside recipient. |
| `reconciliation.ex` and `chimeway.reconcile_tenants` | JSON ambiguity report and explicit atomic assignment | ✓ VERIFIED | Real Repo queries and `Repo.transaction` perform NULL-only reporting/assignment; focused reconciliation tests passed. |
| Public/prefixed migration copies and migration contract tests | Additive nullable tenant fields and deterministic static-prefix rendering | ⚠️ PARTIAL | Migration up path and deterministic rendered copies exist; both `down/0` implementations are invalid for a permitted production state. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `trigger.ex` | Event and Notification persistence | tenant ID in changeset and `insert_all` rows | ⚠️ PARTIAL | Link exists, but uses raw Trigger input rather than the canonical scope representation. |
| `traces.ex` | `tenant_scope.ex` | `TenantScope.resolve/1` before event query | ✓ WIRED | Scope resolution precedes the `Event` tenant predicate and preloads are tenant-filtered. |
| `inbox.ex` | Notification lifecycle | resolved tenant in list/count/transition predicates and signals | ✓ WIRED | Direct `notification.tenant_id` is used for lifecycle signals. |
| `deliveries.ex` | `tenant_scope.ex` | scope before recovery discovery, claims, reloads, and replanning | ✓ WIRED | Focused recovery tests passed, including wrong-tenant no-op behavior. |
| Admin Context | Admin LiveViews | `Context.read_opts/2` / `recovery_opts/3` | ✓ WIRED | Manual usage scan found calls in dashboard, definitions, feed, health, trace search/detail, and recovery LiveViews. (`verify.key-links` produced two pattern-parser false negatives.) |
| Reconcile Mix task | `Reconciliation` | report/assignment delegation and JSON encoding | ✓ WIRED | Task directly calls `Reconciliation.report/1` and `assign_event_tree/3`. |

### Data-Flow Trace (Level 4)

| Artifact | Data variable | Source | Produces real data | Status |
| --- | --- | --- | --- | --- |
| Trigger / lifecycle schemas | `tenant_id` | Trigger option → Event changeset / Notification `insert_all` | Yes — persisted PostgreSQL rows | ⚠️ HOLLOW EDGE | Input is real but padded input is persisted differently from query normalization. |
| Inbox, traces, admin, recovery | resolved `tenant_id` | Host option/context → `TenantScope.resolve/1` → Ecto predicates | Yes — Repo queries | ✓ FLOWING |
| Reconciliation | ambiguous event trees | `Repo.all` report queries and transactional `Repo.update_all` | Yes — database-backed report/assignment | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Tenant persistence, idempotency, compatibility, reconciliation, migration contracts, recovery isolation | `mix test test/chimeway/tenant_identity_test.exs test/chimeway/tenant_scope_contract_test.exs test/chimeway/reconciliation_test.exs test/chimeway/migration_contract_test.exs test/chimeway/orchestration/recovery_test.exs` | 33 tests, 0 failures | ✓ PASS |
| Inbox package tenant authorization/non-disclosure | `mix test test/chimeway_inbox/live/bell_dropdown_live_test.exs` (in `chimeway_inbox`) | 7 tests, 0 failures | ✓ PASS |
| Admin tenant authorization, trace, and recovery non-disclosure | `mix test test/chimeway_admin/live/live_auth_test.exs test/chimeway_admin/live/recovery_live_test.exs test/chimeway_admin/live/trace_search_live_test.exs` (in `chimeway_admin`) | 12 tests, 0 failures | ✓ PASS |
| Migration rollback after two tenants use the same idempotency key | Source inspection of both `down/0` paths | No regression test exists; recreating the global unique index necessarily conflicts with the permitted duplicate keys | ✗ FAIL |

### Requirements Coverage

| Requirement | Source Plan(s) | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| TENANT-01 | 97-01 | Persist immutable tenant identity and tenant-scoped event idempotency | ✓ SATISFIED | Schema, composite index, trigger persistence, concurrency/immutability tests. The padded-input gap is separately actionable because it breaks interoperability with scoped readers. |
| TENANT-02 | 97-01, 97-02, 97-03, 97-05, 97-07, 97-08 | Scope inbox, trace, admin, and recovery APIs; explicit compatibility only | ✓ SATISFIED | Core/package tenant predicates and focused cross-tenant behavioral tests passed. |
| TENANT-03 | 97-01, 97-04, 97-06 | Additive migration, non-guessing reconciliation, static-prefix preservation | ✗ BLOCKED | Reconciliation and migration-up contracts work, but valid upgraded data makes both migration down paths fail. |

No orphaned Phase 97 requirements were found: all roadmap-mapped IDs are declared in plan frontmatter.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `lib/chimeway/trigger.ex` | 141–156 | Validation-only tenant trimming | 🛑 Blocker | A valid padded ID persists a lifecycle tree that scoped readers cannot retrieve. |
| `priv/repo/migrations/20260812000000_add_tenant_identity_to_events_and_notifications.exs` | 27–37 | Unsafe recreation of global unique index in `down/0` | 🛑 Blocker | Rollback fails after valid cross-tenant idempotency activity. |
| `priv/chimeway_migrations/032_add_tenant_identity_to_events_and_notifications.exs` | 30–40 | Same unsafe copied migration rollback | 🛑 Blocker | Installer-generated public/prefixed migrations have the same defect. |
| `chimeway_inbox/lib/chimeway_inbox/live_auth.ex` | 39–48 | No valid-but-changed auth-context clause | ⚠️ Warning | A connected LiveView can raise `CaseClauseError` instead of denying/redirecting when recipient or active tenant changes; no data exposure was demonstrated. |

No `TBD`, `FIXME`, or `XXX` debt markers were found in the phase-owned runtime files. The committed `97-REVIEW.md` was treated as a lead and independently confirmed against the migration and Trigger source.

### Gaps Summary

The phase has real tenant scoping and a non-guessing reconciliation implementation, with passing targeted behavior tests. It is not safe to declare the goal achieved: accepted tenant identifiers do not have one consistent durable representation, and the upgrade cannot safely preserve its down/up contract once ordinary cross-tenant idempotency usage has occurred. Neither issue is explicitly assigned to a later roadmap phase, so neither is deferred.

---

_Verified: 2026-08-12T16:17:49Z_
_Verifier: the agent (gsd-verifier)_
