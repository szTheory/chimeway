---
phase: 97-tenant-identity-compatible-upgrade
verified: 2026-08-12T17:18:09Z
status: gaps_found
score: 3/4 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 3/4
  gaps_closed:
    - "Hosts can safely identify and query lifecycle state using the same explicit tenant identity supplied to Trigger."
    - "An adopter can safely upgrade and retain the migration down/up contract after valid tenant-scoped idempotency activity."
  gaps_remaining:
    - "The runtime-prefix verification gate is red because its recovery proof does not pass an explicit tenant_id."
  regressions: []
gaps:
  - truth: "The tenant-safe runtime-prefix recovery contract is executable through the maintained mix verify.runtime_prefix gate."
    status: failed
    reason: "mix verify.runtime_prefix fails in RuntimePrefixIntegrationTest because its recovery calls omit tenant_id. Deliveries correctly fails closed and returns {:noop, nil}, but the maintained gate still expects an unscoped mutation to succeed."
    artifacts:
      - path: "test/chimeway/runtime_prefix_integration_test.exs"
        issue: "Lines 272, 299, and 324 invoke begin_recovery/2, recover_delivery/2, and recover_event/2 without the required explicit tenant_id."
    missing:
      - "Pass tenant_id: \"acme\" to every recovery invocation in the runtime-prefix operator proof and retain its assertion that operations remain in the configured runtime prefix."
      - "Run mix verify.runtime_prefix successfully after updating the proof."
---

# Phase 97: Tenant Identity & Compatible Upgrade Verification Report

**Phase Goal:** Hosts can safely identify, query, and upgrade notification lifecycle state within an explicit tenant boundary.
**Verified:** 2026-08-12T17:18:09Z
**Status:** gaps_found
**Re-verification:** Yes — after gap closure

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | A host can create independent events with the same idempotency key in two tenants without collision, and each resulting notification retains its immutable tenant identity. | ✓ VERIFIED | `Trigger.trigger/3` normalizes the supplied tenant before `Event.changeset/2`, notification rows, workflow runs, and dispatch options. The focused core suite passed 40 tests, including padded/canonical retries, concurrent convergence, case distinction, cross-tenant same-key activity, and immutability. |
| 2 | A host cannot read or mutate inbox, trace, admin, or recovery state outside the tenant it explicitly supplies. | ✓ VERIFIED | `TenantScope.resolve/1` precedes core query/mutation predicates in `Inbox`, `Traces`, `Admin`, and `Deliveries`; the core, Inbox, and Admin focused suites passed (40 + 7 + 12 tests), including wrong-tenant non-disclosure and recovery no-op behavior. |
| 3 | A legacy single-tenant host continues only after it explicitly enables the compatibility configuration; otherwise formerly unscoped calls fail closed. | ✓ VERIFIED | `TenantScope.compatibility_tenant/0` accepts only a concrete nonblank configured tenant. `tenant_scope_contract_test.exs` proves absent/malformed compatibility fails closed and recovery without scope returns `{:noop, nil}`. |
| 4 | An adopter can apply additive migrations, receive ambiguous-row reconciliation evidence, and assign ownership without Chimeway inferring a tenant or changing its static storage prefix. | ✗ FAILED | Migration/reconciliation implementation and their direct PostgreSQL contracts pass, including irreversible down behavior. However, the required `mix verify.runtime_prefix` gate is red because its recovery proof still asserts unscoped recovery succeeds, so the phase does not retain a green runtime-prefix verification contract. |

**Score:** 3/4 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact group | Expected | Status | Details |
| --- | --- | --- | --- |
| `tenant_scope.ex`, schemas, `trigger.ex`, `traces.ex` | Durable tenant identity, canonical writes, and scoped trace lookup | ✓ VERIFIED | All exist, are substantive, and are wired; the canonical trigger regression test passes. |
| `inbox.ex`, `admin.ex`, `deliveries.ex`, `chimeway.ex` | Tenant-scoped public reads, mutations, and recovery | ✓ VERIFIED | Scope resolution and `tenant_id` predicates are present before operations; focused behavior tests pass. |
| Inbox/Admin auth, context, and LiveViews | Host-authorized tenant context reaches package calls | ✓ VERIFIED | `Context.read_opts/2` / `recovery_opts/3` are used by dashboard, definitions, feed, health, trace, and recovery LiveViews; focused package tests pass. |
| `reconciliation.ex` and `chimeway.reconcile_tenants` | Non-guessing JSON report and atomic explicit assignment | ✓ VERIFIED | Real Repo queries report only NULL ownership, and transaction/row-lock logic updates an event tree only after a host provides a nonblank tenant. |
| Repository/canonical/generated migration copies and contract tests | Additive fields, static-prefix preservation, and safe down behavior | ⚠️ PARTIAL | All copies are substantive and `down/0` now deterministically raises before DDL; `mix verify.install_golden` passes. The separate runtime-prefix verification alias is red due to a stale unscoped recovery test. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `trigger.ex` | Event/Notification/Workflow persistence and dispatcher | one normalized tenant passed through transaction and `Keyword.put(opts, :tenant_id, tenant_id)` | ✓ WIRED | Manual source trace plus padded-input dispatch/persistence test passed. |
| `traces.ex`, `inbox.ex`, `admin.ex`, `deliveries.ex` | `tenant_scope.ex` | `TenantScope.resolve/1` before Ecto predicates/mutations | ✓ WIRED | Manual source scan and cross-tenant tests prove scoped behavior. |
| Admin Context | Admin LiveViews | `Context.read_opts/2` / `Context.recovery_opts/3` | ✓ WIRED | Manual call-site scan found all relevant LiveViews. The generic key-link parser's two glob-pattern false negatives are not implementation failures. |
| Reconciliation Mix task | `Reconciliation` | report/assignment delegation and JSON encoding | ✓ WIRED | Task directly calls `Reconciliation.report/1` / `assign_event_tree/3`. |
| Migration template | public and prefixed rendered copies | static prefix sentinel only | ✓ WIRED | Both fixture copies contain the identical pre-DDL irreversible error; `mix verify.install_golden` passed. |
| Runtime-prefix recovery proof | `Deliveries` recovery APIs | explicit tenant scope in each recovery call | ✗ NOT WIRED | The test omits `tenant_id`, so it exercises fail-closed behavior while asserting success and makes `mix verify.runtime_prefix` fail. |

### Data-Flow Trace (Level 4)

| Artifact | Data variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Trigger/lifecycle persistence | `tenant_id` | explicit option → normalized Trigger local → Ecto changeset/rows/dispatch opts | PostgreSQL-backed | ✓ FLOWING |
| Inbox, trace, admin, recovery | resolved `tenant_id` | host option/context → `TenantScope.resolve/1` → Ecto predicates | PostgreSQL-backed | ✓ FLOWING |
| Reconciliation | ambiguous event trees | NULL-owner Repo queries → locked transactional assignment | PostgreSQL-backed | ✓ FLOWING |
| Runtime-prefix recovery verification | `tenant_id` | test recovery calls | Missing at call sites | ✗ DISCONNECTED |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Canonical tenant persistence, idempotency, compatibility, reconciliation, migration refusal, and recovery isolation | `mix test test/chimeway/tenant_identity_test.exs test/chimeway/tenant_scope_contract_test.exs test/chimeway/reconciliation_test.exs test/chimeway/migration_contract_test.exs test/chimeway/orchestration/recovery_test.exs --warnings-as-errors` | 40 tests, 0 failures | ✓ PASS |
| Inbox tenant authorization/non-disclosure | `mix cmd --cd chimeway_inbox mix test test/chimeway_inbox/live/bell_dropdown_live_test.exs --warnings-as-errors` | 7 tests, 0 failures | ✓ PASS |
| Admin tenant authorization, trace, and recovery non-disclosure | `mix cmd --cd chimeway_admin mix test test/chimeway_admin/live/live_auth_test.exs test/chimeway_admin/live/recovery_live_test.exs test/chimeway_admin/live/trace_search_live_test.exs --warnings-as-errors` | 12 tests, 0 failures | ✓ PASS |
| Installer golden migrations, including generated public/prefixed rollback refusal | `mix verify.install_golden` | exit 0 | ✓ PASS |
| Runtime-prefix tenant-safe recovery | `mix verify.runtime_prefix` | 17 tests, 1 failure: `Deliveries.begin_recovery/2` returned `{:noop, nil}` for an unscoped call | ✗ FAIL |

### Requirements Coverage

| Requirement | Source Plan(s) | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| TENANT-01 | 97-01, 97-09 | Immutable tenant identity and tenant-scoped event idempotency | ✓ SATISFIED | Canonical write-boundary code and focused persistence/concurrency tests pass. |
| TENANT-02 | 97-01, 97-02, 97-03, 97-05, 97-07, 97-08, 97-09 | Explicit tenant scope across inbox, trace, admin, and recovery; compatibility only when configured | ✗ BLOCKED | Runtime code and targeted tests meet the fail-closed behavior, but the maintained runtime-prefix recovery proof is stale and makes its required verification command fail. |
| TENANT-03 | 97-01, 97-04, 97-06, 97-10 | Additive migration, no inferred owner, deterministic reconciliation, static-prefix preservation | ✓ SATISFIED | Reconciliation and migration-contract tests pass; generated public/prefixed copies refuse lossy rollback before mutation. |

No orphaned Phase 97 requirements were found: every roadmap-mapped requirement ID is declared in plan frontmatter.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `test/chimeway/runtime_prefix_integration_test.exs` | 272, 299, 324 | Tenant-scoped recovery calls without `tenant_id` | 🛑 Blocker | The objective runtime-prefix verification gate fails and no longer proves the current explicit-scope contract. |

No `TBD`, `FIXME`, or `XXX` debt markers were found in the phase runtime surface. The Threadline sandbox-cleanup errors emitted during otherwise passing focused suites are pre-existing test-harness noise; they did not change any command exit status.

### Gaps Summary

The two prior blockers are closed with direct executable evidence: Trigger persists a single canonical tenant identity, and all migration copies refuse unsafe rollback before mutation. The phase still cannot pass because a maintained runtime-prefix verification gate is red. Its test invokes recovery APIs without the tenant scope this phase deliberately requires, then asserts success. Add `tenant_id: "acme"` to those recovery calls and rerun `mix verify.runtime_prefix`; no later roadmap phase explicitly owns this correction.

---

_Verified: 2026-08-12T17:18:09Z_
_Verifier: the agent (gsd-verifier)_
