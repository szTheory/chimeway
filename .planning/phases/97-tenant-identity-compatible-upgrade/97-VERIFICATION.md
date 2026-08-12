---
phase: 97-tenant-identity-compatible-upgrade
verified: 2026-08-12T17:47:31Z
status: gaps_found
score: 2/4 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 3/4
  gaps_closed:
    - "The runtime-prefix recovery proof now supplies an explicit tenant and mix verify.runtime_prefix passes."
  gaps_remaining: []
  regressions:
    - "Admin lifecycle joins can disclose cross-tenant parent/child data when a lifecycle tree has inconsistent tenant IDs."
    - "Reconciliation can assign only an event and notifications, leaving a delivery in another tenant."
gaps:
  - truth: "A host cannot read or mutate inbox, trace, admin, or recovery state outside the tenant it explicitly supplies."
    status: failed
    reason: "Admin read models predicate only one lifecycle level. Because delivery planning accepts a caller-supplied tenant without validating the notification tenant, a malformed or partially reconciled tree can return another tenant's recipient, event, correlation, channels, statuses, or counts. Feed Debug also queries after permission revocation because its handler does not re-check authorization."
    artifacts:
      - path: "lib/chimeway/admin.ex"
        issue: "recent_problem_deliveries, definitions, feed, and recovery_candidates join child rows without applying the supplied tenant to every joined lifecycle level."
      - path: "chimeway_admin/lib/chimeway_admin/live/feed_live.ex"
        issue: "search calls Chimeway.admin_feed/1 without ChimewayAdmin.LiveAuth.ensure_authorized/3."
    missing:
      - "Require the resolved tenant on every joined event, notification, and delivery (and preferably assert tenant equality in joins); add adversarial linked-row tests for every Admin DTO."
      - "Re-check :view_feed authorization in FeedLive.handle_event/3 and test revocation after mount."
  - truth: "An adopter can apply additive migrations, receive ambiguous-row reconciliation evidence, and assign ownership without Chimeway inferring a tenant or changing its static storage prefix."
    status: failed
    reason: "Reconciliation locks, validates, and updates only Event and Notification rows. It neither locks nor validates Delivery rows already belonging to that lifecycle; assigning a legacy event tree can therefore create cross-tenant ownership immediately after the supported upgrade operation."
    artifacts:
      - path: "lib/chimeway/reconciliation.ex"
        issue: "assign_locked_event_tree/3 updates lines 106-117 only; there is no Delivery query, lock, conflict check, or update."
    missing:
      - "Include deliveries in the same transaction: reject conflicting non-NULL delivery ownership with :ownership_conflict, or atomically update only NULL delivery tenants under a documented policy and report delivery counts."
      - "Add a reconciliation test for a NULL event/notification tree with a conflicting delivery tenant."
---

# Phase 97: Tenant Identity & Compatible Upgrade Verification Report

**Phase Goal:** Hosts can safely identify, query, and upgrade notification lifecycle state within an explicit tenant boundary.
**Verified:** 2026-08-12T17:47:31Z
**Status:** gaps_found
**Re-verification:** Yes — after gap closure

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | A host can create independent events with the same idempotency key in two tenants without collision, and each resulting notification retains its immutable tenant identity. | ✓ VERIFIED | `Trigger` canonicalizes the explicit tenant and propagates it to event, notification, workflow, duplicate recovery, and dispatch. The focused core suite passed 47 tests, including cross-tenant same-key, padded/canonical, and concurrency cases. |
| 2 | A host cannot read or mutate inbox, trace, admin, or recovery state outside the tenant it explicitly supplies. | ✗ FAILED | Core paths are scoped, but `Admin` scopes only one side of multi-table joins; `Deliveries.plan_delivery/3` accepts an arbitrary tenant. A mismatched row can disclose joined data. Feed Debug also omits its event-time authorization check. |
| 3 | A legacy single-tenant host continues only after it explicitly enables the compatibility configuration; otherwise formerly unscoped calls fail closed. | ✓ VERIFIED | `TenantScope.resolve/1` and the core contracts enforce a concrete compatibility tenant; focused core tests pass. `mix verify.runtime_prefix` also passed all 17 tests with explicit recovery scope. |
| 4 | An adopter can apply additive migrations, receive ambiguous-row reconciliation evidence, and assign ownership without Chimeway inferring a tenant or changing its static storage prefix. | ✗ FAILED | Migrations/reporting are substantive and their focused tests pass, but supported assignment skips Delivery rows. It can create a split-tenant lifecycle tree and invalidate safe querying/recovery after upgrade. |

**Score:** 2/4 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact group | Expected | Status | Details |
| --- | --- | --- | --- |
| Tenant scope, schemas, trigger, traces, and identity tests | Explicit immutable write identity and scoped trace lookup | ✓ VERIFIED | All required Plan 97-01/09 files exist, are substantive, and are connected; focused behavioral tests pass. |
| Inbox and recovery surfaces | Explicit scope before reads/mutations | ✓ VERIFIED | `TenantScope.resolve/1` precedes scoped core predicates; tenant-scope and recovery tests pass. |
| Admin read models and LiveViews | Tenant-bound DTOs and re-authorized operator actions | ✗ PARTIAL | Files are substantive and context reaches callers, but joined rows are not all tenant-predicated and Feed Debug has no event-time authorization call. |
| Reconciliation and CLI | Atomic, non-guessing assignment of a lifecycle tree | ✗ PARTIAL | Report/CLI wiring exists, but assignment only updates Event/Notification rows rather than the durable event → notification → delivery spine. |
| Repository/canonical/generated migrations | Additive nullable identity, static-prefix behavior, safe rollback | ✓ VERIFIED | Artifact scan passed; migration contracts passed in the focused suite. |
| Runtime-prefix proof | Explicit-tenant recovery under static prefix | ✓ VERIFIED | Calls at `runtime_prefix_integration_test.exs:272`, `:299`, and `:327` include `tenant_id: "acme"`; `mix verify.runtime_prefix` passed (17 tests). |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- |
| `trigger.ex` | event/notification/workflow persistence and dispatcher | one normalized explicit tenant | ✓ WIRED | Source and focused tests prove propagation and scoped idempotency. |
| Core Inbox/Traces/Deliveries | `tenant_scope.ex` | resolve before predicates/mutations | ✓ WIRED | Source scans and focused tenant/recovery contracts pass. |
| Admin DTO query roots | joined Event/Notification/Delivery rows | tenant predicate on every lifecycle level | ✗ NOT WIRED | `admin.ex` applies only `d.tenant_id`, `n.tenant_id`, or `e.tenant_id` per query, not all joined rows. |
| Reconciliation | Event, Notification, Delivery ownership | one locked transaction | ✗ NOT WIRED | No Delivery access occurs in `assign_locked_event_tree/3`. |
| Feed Debug | `LiveAuth.ensure_authorized/3` | recheck `:view_feed` before search | ✗ NOT WIRED | No `ensure_authorized` call in `FeedLive.handle_event/3`. |
| Runtime-prefix test | recovery APIs | explicit tenant options | ✓ WIRED | Each recovery invocation supplies `tenant_id: "acme"`; alias executes the test. |

### Data-Flow Trace (Level 4)

| Artifact | Data variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Trigger/lifecycle persistence | `tenant_id` | explicit opts → canonical local → Ecto/dispatch | PostgreSQL-backed | ✓ FLOWING |
| Core inbox, trace, recovery | resolved `tenant_id` | host opts → `TenantScope.resolve/1` → predicates | PostgreSQL-backed | ✓ FLOWING |
| Admin joined DTOs | event/notification/delivery tenant identity | one joined-table predicate only | Mismatched rows can enter DTOs | ✗ HOLLOW |
| Reconciliation | event-tree ownership | NULL event/notification queries only | Delivery ownership bypassed | ✗ DISCONNECTED |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Identity, compatibility, reconciliation, migration, recovery, and Admin core contracts | `mix test test/chimeway/tenant_identity_test.exs test/chimeway/tenant_scope_contract_test.exs test/chimeway/reconciliation_test.exs test/chimeway/migration_contract_test.exs test/chimeway/orchestration/recovery_test.exs test/chimeway/admin_test.exs --warnings-as-errors` | 47 tests, 0 failures | ✓ PASS — insufficient to cover the adversarial linked-row paths above |
| Runtime-prefix recovery scope | `mix verify.runtime_prefix` | 17 tests, 0 failures | ✓ PASS |
| Admin package authorization/recovery/trace contracts | `mix cmd --cd chimeway_admin mix test ... --warnings-as-errors` | 15 tests, 0 failures | ✓ PASS — no Feed post-mount revocation case exists |
| Inbox LiveView contract | `mix cmd --cd chimeway_inbox mix test test/chimeway_inbox/live/bell_dropdown_live_test.exs --warnings-as-errors` | 7 tests, 0 failures | ✓ PASS — no changed-recipient/tenant recheck case exists |

### Requirements Coverage

| Requirement | Source Plan(s) | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| TENANT-01 | 97-01, 97-09 | Immutable tenant identity and tenant-scoped event idempotency | ✓ SATISFIED | Canonical write-boundary implementation and focused persistence/concurrency tests pass. |
| TENANT-02 | 97-01, 97-02, 97-03, 97-05, 97-07, 97-08, 97-09, 97-11 | Explicit tenant scope across inbox, trace, admin, and recovery; compatibility only when configured | ✗ BLOCKED | Admin joins and Feed Debug let invalid lifecycle rows or a revoked live session bypass the required isolation/authorization boundary. |
| TENANT-03 | 97-01, 97-04, 97-06, 97-10, 97-11 | Additive migration, no inferred owner, deterministic reconciliation, static-prefix preservation | ✗ BLOCKED | Migration/static-prefix evidence passes, but reconciliation can leave an existing Delivery under a different tenant. |

No orphaned Phase 97 requirements were found: all roadmap-mapped IDs are declared in Plan frontmatter. No later roadmap phase explicitly owns either gap, so neither is deferred.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `lib/chimeway/reconciliation.ex` | 95-124 | Partial lifecycle-tree assignment | 🛑 Blocker | An upgrade can produce cross-tenant ownership. |
| `lib/chimeway/admin.ex` | 43-224 | Multi-table DTO queries predicate only one tenant column | 🛑 Blocker | Cross-tenant event/notification/delivery data can appear in Admin output. |
| `chimeway_admin/lib/chimeway_admin/live/feed_live.ex` | 15-28 | No event-time authorization recheck | 🛑 Blocker | A revoked operator can keep searching while the LiveView is connected. |
| `chimeway_inbox/lib/chimeway_inbox/live_auth.ex` | 39-47 | Missing successful-mismatch clause | ⚠️ Warning | Tenant/recipient switch crashes rather than redirecting fail-closed. |

No phase-surface `TBD`, `FIXME`, or `XXX` debt markers were found. The Threadline sandbox-cleanup errors emitted by passing test commands are pre-existing harness noise; every command exited successfully.

### Gaps Summary

The prior runtime-prefix verification failure is closed, but the phase still misses its central tenant-safety outcome. The reconciliation path can manufacture a split-tenant lifecycle tree, and the Admin layer assumes such a tree cannot exist while joining it without checking all tenant identities. These are mutually reinforcing defects, not deferred future work. Correct both, add adversarial tests, and repair the Inbox authorization mismatch before re-verification.

---

_Verified: 2026-08-12T17:47:31Z_
_Verifier: the agent (gsd-verifier)_
