---
phase: 32
slug: operator-traces-audit
status: verified
threats_open: 0
asvs_level: 1
created: 2026-05-01
---

# Phase 32 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| provider feedback signal -> `route_signal/1` | Untrusted signal payload must update workflow state without leaking payload data into durable operator surfaces. | `event_name`, `actor_id`, optional `payload["delivery_id"]` |
| `route_signal/1` -> `workflow_transitions` | Signal receipt must persist linkage on the FK column while preserving the context-map safety contract. | `workflow_run_id`, `delivery_id`, `event_name`, transition reason |
| delivery explanation -> timeline projection | Operator explanation reads must project only bounded, explainable fields into the timeline. | attempt outcomes, provider message id, workflow step metadata, event atoms |
| `workflow_transitions` join -> tenant-scoped traces | Read-side linkage by `delivery_id` must not surface transitions from another tenant. | `delivery_id`, `workflow_run_id`, `tenant_id`, workflow reasons |
| companion signal lookup -> webhook timeline entry | The event-name companion query must inherit the same tenant scope as the primary projection. | `delivery_id`, `tenant_id`, `context["event_name"]` |

---

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-32-01 | T | `Chimeway.Workflows.route_signal/1` concurrent signal routing | accept (preserved) | Phase 32 does not change the existing transaction/lock discipline. `route_signal/1` still runs inside `Repo.transaction/1` and `find_runs_waiting_for_signal/3` still uses `FOR UPDATE`. Evidence: [workflows.ex](/Users/jon/projects/chimeway/lib/chimeway/workflows.ex:398), [workflows.ex](/Users/jon/projects/chimeway/lib/chimeway/workflows.ex:447), [workflows_test.exs](/Users/jon/projects/chimeway/test/chimeway/workflows_test.exs:409). | closed |
| T-32-02 | I | `WorkflowTransition.context` payload safety | mitigate | `delivery_id` is written to the FK column, not copied into `context`; runtime tests refute both `payload` and `delivery_id` keys in the persisted context. Evidence: [workflows.ex](/Users/jon/projects/chimeway/lib/chimeway/workflows.ex:418), [workflows.ex](/Users/jon/projects/chimeway/lib/chimeway/workflows.ex:419), [workflows_test.exs](/Users/jon/projects/chimeway/test/chimeway/workflows_test.exs:349), [workflows_test.exs](/Users/jon/projects/chimeway/test/chimeway/workflows_test.exs:352), [workflows_inspection_test.exs](/Users/jon/projects/chimeway/test/chimeway/workflows_inspection_test.exs:304). | closed |
| T-32-03 | D | atom-safety on `payload["delivery_id"]` handling | mitigate | The write path uses `Map.get/2` and a literal `:delivery_id` attrs key only; Phase 32 introduces no dynamic atom conversion in `workflows.ex`. Evidence: [workflows.ex](/Users/jon/projects/chimeway/lib/chimeway/workflows.ex:419). Verification: `mix compile --warnings-as-errors` passed on 2026-05-01 and targeted tests passed. | closed |
| T-32-04 | T | malformed `payload["delivery_id"]` input | mitigate | The value flows through the normal transition changeset path inside the existing transaction; invalid UUIDs fail through the insert/rollback path instead of being coerced into unsafe state. Missing keys stay nil and are covered by runtime tests. Evidence: [workflows.ex](/Users/jon/projects/chimeway/lib/chimeway/workflows.ex:412), [workflows.ex](/Users/jon/projects/chimeway/lib/chimeway/workflows.ex:427), [workflows_test.exs](/Users/jon/projects/chimeway/test/chimeway/workflows_test.exs:355). | closed |
| T-32-05 | I | cross-tenant write-time `delivery_id` reference supplied by host | accept (low-severity) | Phase 32 adds no new write-time tenant guard on the FK itself; host applications remain responsible for not crossing tenant boundaries when constructing signals. The read side adds defensive tenant filtering so this accepted risk does not become a disclosure vector in operator traces. Evidence: [32-01-PLAN.md](/Users/jon/projects/chimeway/.planning/phases/32-operator-traces-audit/32-01-PLAN.md:484), [traces.ex](/Users/jon/projects/chimeway/lib/chimeway/traces.ex:541). | closed |
| T-32-T1 | I | cross-tenant data leakage in workflow trace projection | mitigate | The primary projection query joins `WorkflowRun` and filters `wr.tenant_id == ^tenant_id`; runtime tests synthesize adversarial cross-tenant state and verify foreign transitions are excluded. Evidence: [traces.ex](/Users/jon/projects/chimeway/lib/chimeway/traces.ex:541), [traces_test.exs](/Users/jon/projects/chimeway/test/chimeway/traces_test.exs:489), [traces_test.exs](/Users/jon/projects/chimeway/test/chimeway/traces_test.exs:501). | closed |
| T-32-T2 | D | atom-table exhaustion in `transition.reason` projection | mitigate | Reason dispatch is a closed set of compile-time literals with a nil fallback; no dynamic string-to-atom conversion was introduced in the Phase 32 traces path. Evidence: [traces.ex](/Users/jon/projects/chimeway/lib/chimeway/traces.ex:570), [traces.ex](/Users/jon/projects/chimeway/lib/chimeway/traces.ex:575). Verification: `mix compile --warnings-as-errors` passed and `traces_test.exs` passed on 2026-05-01. | closed |
| T-32-T3 | I | PII leakage in timeline `detail` maps | mitigate | The projection selects only explicit fields and the tests assert that the five new event atoms never expose `payload`, `data`, `recipient`, `email`, `phone`, or `provider_response`. Evidence: [traces.ex](/Users/jon/projects/chimeway/lib/chimeway/traces.ex:542), [traces.ex](/Users/jon/projects/chimeway/lib/chimeway/traces.ex:523), [traces_test.exs](/Users/jon/projects/chimeway/test/chimeway/traces_test.exs:506), [traces_test.exs](/Users/jon/projects/chimeway/test/chimeway/traces_test.exs:551), [traces_test.exs](/Users/jon/projects/chimeway/test/chimeway/traces_test.exs:556). | closed |
| T-32-T4 | I | cross-tenant timing oracle in `explain_delivery/1` | accept (preserved) | Phase 32 does not widen the pre-existing delivery lookup surface; the new helpers run only after the delivery has already been tenant-scoped. This accepted risk remains unchanged by the phase. Evidence: [32-02-PLAN.md](/Users/jon/projects/chimeway/.planning/phases/32-operator-traces-audit/32-02-PLAN.md:1102). | closed |
| T-32-T5 | T | SQL injection via trace query construction | mitigate | The new projection and companion lookup use parameterized Ecto `from/join/where` clauses only, with bound variables for `delivery_id` and `tenant_id`. Evidence: [traces.ex](/Users/jon/projects/chimeway/lib/chimeway/traces.ex:536), [traces.ex](/Users/jon/projects/chimeway/lib/chimeway/traces.ex:541), [traces.ex](/Users/jon/projects/chimeway/lib/chimeway/traces.ex:611), [traces.ex](/Users/jon/projects/chimeway/lib/chimeway/traces.ex:616). | closed |
| T-32-T6 | D | unbounded read in `workflow_transition_entries/1` | accept (low-severity) | The per-delivery transition set is intentionally left unpaginated in this phase because the expected cardinality is low and the contract remains bounded to a single delivery timeline. Evidence: [32-02-PLAN.md](/Users/jon/projects/chimeway/.planning/phases/32-operator-traces-audit/32-02-PLAN.md:1104). | closed |
| T-32-T7 | I | tenant leak in `lookup_signal_received_event_name/1` | mitigate | The companion event-name lookup repeats the defensive `wr.tenant_id == ^tenant_id` filter before reading `context["event_name"]`. Evidence: [traces.ex](/Users/jon/projects/chimeway/lib/chimeway/traces.ex:609), [traces.ex](/Users/jon/projects/chimeway/lib/chimeway/traces.ex:616). | closed |

*Status: open · closed*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-32-01 | T-32-01 | The concurrency contract is inherited unchanged from the pre-Phase-32 signal router and remains covered by existing transaction/lock behavior. | Codex security audit | 2026-05-01 |
| AR-32-02 | T-32-05 | Host applications own tenant correctness for signal payload construction; Phase 32 does not add a tenant column to the FK edge. | Codex security audit | 2026-05-01 |
| AR-32-03 | T-32-T4 | The delivery existence/timing surface is preserved from earlier phases; Phase 32 adds no new oracle path before tenant-scoped delivery resolution. | Codex security audit | 2026-05-01 |
| AR-32-04 | T-32-T6 | The per-delivery read remains intentionally unpaginated because the expected transition cardinality is low and no evidence in this phase justifies widening the contract. | Codex security audit | 2026-05-01 |

*Accepted risks do not resurface in future audit runs.*

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-05-01 | 12 | 12 | 0 | Codex |

---

## Threat Flags

No `## Threat Flags` section was present in:

- `.planning/phases/32-operator-traces-audit/32-01-SUMMARY.md`
- `.planning/phases/32-operator-traces-audit/32-02-SUMMARY.md`

---

## Verification Evidence

- `mix compile --warnings-as-errors` passed on 2026-05-01.
- `mix test test/chimeway/workflows_test.exs test/chimeway/workflows_inspection_test.exs` passed with `29 tests, 0 failures` on 2026-05-01.
- `mix test test/chimeway/traces_test.exs` passed with `45 tests, 0 failures` on 2026-05-01.

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-05-01
