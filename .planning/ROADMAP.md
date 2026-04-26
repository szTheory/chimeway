# Roadmap: Chimeway

## Milestones

- ✅ **v1.0** — [Archived roadmap](.planning/milestones/v1.0-ROADMAP.md) (shipped 2026-04-25)
- 🟦 **v1.1** — Production Trust (current)

## Phases

| # | Phase | Goal | Requirements | Success Criteria |
|---|-------|------|--------------|------------------|
| ✅ 13 | Policy & Preference Maturity | Make suppression and user-controlled delivery rules explicit and explainable. | POL-01, POL-02, POL-03 | 3 |
| 14 | Delivery Reliability Hardening | 11/11 | Complete    | 2026-04-26 |
| 15 | Observability & Supportability | Make lifecycle tracing and operator surfaces safe, correlated, and searchable. | OBS-01, OBS-02, OBS-03 | 3 |
| 16 | Integration Hardening | Make host-app setup and adapter seams documented, stable, and contract-tested. | INT-01, INT-02 | 2 |

## Phase Details

### Phase 13: Policy & Preference Maturity

Goal: Make suppression and preference behavior explicit so product teams can trust delivery decisions.

Requirements: POL-01, POL-02, POL-03

Plans: 3

Plan list:
- [x] 13-01-PLAN.md — Add category preference storage and lookup APIs
- [x] 13-02-PLAN.md — Add quiet-hours and delivery-cap policy settings
- [x] 13-03-PLAN.md — Wire policy evaluation and suppression enforcement

Success criteria:
1. Users can define delivery preferences by channel or category.
2. Users can configure quiet hours and delivery caps.
3. Suppression happens before enqueue and before perform, with recorded reasons.

### Phase 14: Delivery Reliability Hardening

Goal: Make delivery retries and duplicate protection safe under real-world concurrency and failure.

Requirements: REL-01, REL-02, REL-03

Plans: 11

Plan list:
- [x] 14-01-PLAN.md — Wave 0: Scaffold reliability test files (skipped placeholders)
- [x] 14-02-PLAN.md — Migration + DeliveryAttempt schema (attempt_number, error_class)
- [x] 14-03-PLAN.md — Promote terminal_states/0 + add Deliveries.exhaust_delivery/1
- [x] 14-04-PLAN.md — Executor.classify/1 3-tuple + record_attempt/2 sync convergence
- [x] 14-05-PLAN.md — ObanWorker retry contract + Traces field surfacing
- [x] 14-06-PLAN.md — REL-01 duplicate protection tests (D-02 + D-14)
- [x] 14-07-PLAN.md — REL-02/REL-03 attempt history, retry exhaustion, terminal convergence tests
- [x] 14-08-PLAN.md — D-13 oban_worker_test rewrite, sync parity, traces tests, mix ci D-15 regression
- [x] 14-09-PLAN.md — Gap closure: BL-01 stale-struct lock fix + WR-01 genuine concurrency test
- [x] 14-10-PLAN.md — Gap closure: BL-02 catch-all convergence hardening (exhaust on final attempt)
- [x] 14-11-PLAN.md — Gap closure: WR-05/06/07 trace surface drift (ordering, cancelled entries, moduledoc)

Success criteria:
1. Retry paths do not create duplicate events, notifications, or deliveries.
2. Delivery attempts preserve backoff and retry history.
3. Every delivery reaches a durable, explainable final state.

### Phase 15: Observability & Supportability

Goal: Make every lifecycle step traceable without exposing sensitive payload data.

Requirements: OBS-01, OBS-02, OBS-03

Success criteria:
1. Operators can trace one event across notification, delivery, and attempt records.
2. Structured telemetry and logs avoid leaking sensitive payload fields.
3. Correlation and tenancy context remain visible in operator surfaces.

### Phase 16: Integration Hardening

Goal: Make host-app adoption easier and safer through clear setup and stable seams.

Requirements: INT-01, INT-02

Success criteria:
1. Host apps have a documented integration path.
2. Adapter and job-dispatch seams are covered by contract tests.
3. Runtime configuration remains safe and predictable.
