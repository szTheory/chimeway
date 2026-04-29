---
phase: 24
slug: workflow-contracts-state-spine
status: verified
threats_open: 0
asvs_level: 1
created: 2026-04-29
---

# Phase 24 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| notifier callback -> durable declaration rows | Untrusted callback output must normalize into explicit stable workflow identity | workflow key/version, ordered steps, channel/config metadata |
| workflow definition -> ordered steps | Durable workflow truth must not drift into opaque metadata blobs | persisted step identity and bounded config |
| trigger transaction -> workflow run state | Notification and workflow records must commit together or not at all | notification ids, workflow definition ids, initial run state |
| workflow current state -> workflow transition log | Current truth and historical why-data must stay consistent under retries and duplicates | workflow state, transition reasons, step linkage |
| workflow run -> delivery row | Execution artifacts must point back to the correct durable workflow truth | workflow run id, workflow step id, delivery channel |
| persisted workflow snapshot -> recovery replay | Recovery must reuse stored data rather than executing arbitrary notifier callback code | persisted workflow declaration, replay gating flag |

---

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-24-01 | T | `lib/chimeway/notifier.ex` | mitigate | Reject blank keys, invalid versions, duplicate step ids, invalid channels, and malformed ordering during workflow normalization. Evidence: [notifier.ex](/Users/jon/projects/chimeway/lib/chimeway/notifier.ex:336), [notifier_contract_test.exs](/Users/jon/projects/chimeway/test/chimeway/notifier_contract_test.exs:302). | closed |
| T-24-02 | R | workflow declaration persistence | mitigate | Persist stable `workflow_key` + `workflow_version` and enforce uniqueness on definition/step rows so durable identity cannot drift with module names. Evidence: [workflow_definition.ex](/Users/jon/projects/chimeway/lib/chimeway/workflows/workflow_definition.ex:14), [workflow_step.ex](/Users/jon/projects/chimeway/lib/chimeway/workflows/workflow_step.ex:14), [20260429160000_create_chimeway_workflow_definitions.exs](/Users/jon/projects/chimeway/priv/repo/migrations/20260429160000_create_chimeway_workflow_definitions.exs:14), [20260429160100_create_chimeway_workflow_steps.exs](/Users/jon/projects/chimeway/priv/repo/migrations/20260429160100_create_chimeway_workflow_steps.exs:22). | closed |
| T-24-03 | I | workflow schema shape | mitigate | Keep step identity in first-class rows and reconstruct persisted workflows from durable rows rather than opaque blobs. Evidence: [workflow_step.ex](/Users/jon/projects/chimeway/lib/chimeway/workflows/workflow_step.ex:14), [workflows.ex](/Users/jon/projects/chimeway/lib/chimeway/workflows.ex:99). | closed |
| T-24-04 | T | `lib/chimeway/trigger.ex` | mitigate | Use a single `Ecto.Multi` transaction to persist events, notifications, workflow runs, and initial transitions atomically. Evidence: [trigger.ex](/Users/jon/projects/chimeway/lib/chimeway/trigger.ex:68), [trigger.ex](/Users/jon/projects/chimeway/lib/chimeway/trigger.ex:131), [trigger.ex](/Users/jon/projects/chimeway/lib/chimeway/trigger.ex:309). | closed |
| T-24-05 | R | workflow transition history | mitigate | Append explicit `workflow_started` and `step_activated` transition reasons instead of inferring initial state from timestamps. Evidence: [workflows.ex](/Users/jon/projects/chimeway/lib/chimeway/workflows.ex:152), [workflow_transition.ex](/Users/jon/projects/chimeway/lib/chimeway/workflows/workflow_transition.ex:17), [trigger_pipeline_test.exs](/Users/jon/projects/chimeway/test/chimeway/trigger_pipeline_test.exs:451). | closed |
| T-24-06 | D | duplicate trigger path | mitigate | Reuse event idempotency plus deterministic recipient ordering so duplicate trigger attempts do not create extra run rows. Evidence: [trigger.ex](/Users/jon/projects/chimeway/lib/chimeway/trigger.ex:47), [trigger.ex](/Users/jon/projects/chimeway/lib/chimeway/trigger.ex:105), [trigger.ex](/Users/jon/projects/chimeway/lib/chimeway/trigger.ex:206), [trigger_pipeline_test.exs](/Users/jon/projects/chimeway/test/chimeway/trigger_pipeline_test.exs:489). | closed |
| T-24-07 | T | `lib/chimeway/delivery_planning.ex` | mitigate | Stamp canonical deliveries with exact `workflow_run_id` and `workflow_step_id` instead of metadata-only linkage. Evidence: [delivery_planning.ex](/Users/jon/projects/chimeway/lib/chimeway/delivery_planning.ex:88), [delivery.ex](/Users/jon/projects/chimeway/lib/chimeway/delivery.ex:47), [20260429170300_alter_chimeway_deliveries_for_workflow_linkage.exs](/Users/jon/projects/chimeway/priv/repo/migrations/20260429170300_alter_chimeway_deliveries_for_workflow_linkage.exs:5), [delivery_lifecycle_test.exs](/Users/jon/projects/chimeway/test/chimeway/integration/delivery_lifecycle_test.exs:1208). | closed |
| T-24-08 | E | `lib/chimeway/deliveries.ex` recovery path | mitigate | Gate persisted workflow replay behind explicit `use_persisted_workflow: true` validation so recovery does not re-enter notifier callbacks. Evidence: [deliveries.ex](/Users/jon/projects/chimeway/lib/chimeway/deliveries.ex:219), [deliveries.ex](/Users/jon/projects/chimeway/lib/chimeway/deliveries.ex:387), [recovery_test.exs](/Users/jon/projects/chimeway/test/chimeway/orchestration/recovery_test.exs:435). | closed |
| T-24-09 | R | workflow current-state explainability | mitigate | Keep current workflow truth on `workflow_runs` and preserve append-only transitions plus linked deliveries for auditability. Evidence: [workflow_run.ex](/Users/jon/projects/chimeway/lib/chimeway/workflows/workflow_run.ex:17), [workflow_transition.ex](/Users/jon/projects/chimeway/lib/chimeway/workflows/workflow_transition.ex:17), [workflows.ex](/Users/jon/projects/chimeway/lib/chimeway/workflows.ex:123), [deliveries.ex](/Users/jon/projects/chimeway/lib/chimeway/deliveries.ex:537). | closed |

*Status: open · closed*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

No accepted risks.

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-04-29 | 9 | 9 | 0 | Codex + `gsd-security-auditor` |

---

## Threat Flags

No `## Threat Flags` section was present in:

- `.planning/phases/24-workflow-contracts-state-spine/24-01-SUMMARY.md`
- `.planning/phases/24-workflow-contracts-state-spine/24-02-SUMMARY.md`
- `.planning/phases/24-workflow-contracts-state-spine/24-03-SUMMARY.md`

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-04-29
