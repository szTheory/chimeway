---
phase: 07
slug: delayed-fallback-runtime-wiring
status: verified
threats_open: 0
asvs_level: 1
created: 2026-04-24
---

# Phase 07 - Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Notifier -> Planner | Notifier callback output enters delayed-fallback planning and validation logic. | Channel declarations and notifier metadata |
| Planner -> Runtime Dispatch | Planned delivery rows flow into sync/Oban runtime policy checks and suppression handling. | Delivery status, delay_fallback, suppression metadata |
| Runtime -> Audit/Traces | Suppression outcomes are persisted and surfaced for operator/debug review. | policy_checkpoint and delayed_fallback_source metadata |

---

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| TM-07-01-INVALID-SUBSET-BYPASS | Tampering | `lib/chimeway/delivery_planning.ex` | mitigate | Planner rejects non-subset delayed-fallback channels with `invalid_delayed_fallback_channels`. Evidence: `invalid_delayed_fallback_channels` guard clauses present. | closed |
| TM-07-01-INAPP-SUPPRESSION-CORRUPTION | Tampering | `lib/chimeway/delivery_planning.ex` | mitigate | Planner forbids `in_app` in delayed-fallback declarations and returns typed error. Evidence: explicit `in_app` invalid-channel branch present. | closed |
| TM-07-01-COMPAT-BREAK | Denial of Service | `lib/chimeway/notifier.ex` | mitigate | Delayed-fallback callback remains optional to preserve backward compatibility. Evidence: `@optional_callbacks delayed_fallback_channels: 2`. | closed |
| TM-07-02-PERFORM-BYPASS | Elevation of Privilege | `lib/chimeway/dispatch/sync.ex`, `lib/chimeway/dispatch/oban_worker.ex` | mitigate | Both runtime paths evaluate perform-time policy with `check_read_state: delivery.delay_fallback` before execution. | closed |
| TM-07-02-ENQUEUE-LEAK | Tampering | `lib/chimeway/dispatch/oban.ex` | mitigate | Oban enqueue filters planner output to pending rows only (`delivery.status == :pending`). | closed |
| TM-07-02-EXPLAINABILITY-LOSS | Repudiation | `lib/chimeway/traces.ex` | mitigate | Suppression trace details include `policy_checkpoint` and `delayed_fallback_source`. | closed |
| TM-07-03-FIXTURE-ONLY-COVERAGE | Tampering | `test/chimeway/integration/delivery_lifecycle_test.exs` | mitigate | Trigger-driven tests assert planner-persisted delayed-fallback and provenance (`delayed_fallback_source`) from `Chimeway.trigger/3`. | closed |
| TM-07-03-PARITY-REGRESSION | Tampering | `test/chimeway/dispatch/sync_test.exs`, `test/chimeway/dispatch/oban_test.exs`, `test/chimeway/dispatch/oban_worker_test.exs` | mitigate | POLC-03 parity scenarios verify already-read suppression signature and zero attempts across sync/Oban. | closed |
| TM-07-03-INVALID-CHANNEL-DRIFT | Tampering | `test/chimeway/policy/delayed_fallback_test.exs` | mitigate | Guardrail tests assert `{:planning_failed, {:invalid_delayed_fallback_channels, ...}}` for invalid subset and `in_app` misuse. | closed |

*Status: open - closed*
*Disposition: mitigate (implementation required) - accept (documented risk) - transfer (third-party)*

---

## Accepted Risks Log

No accepted risks.

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-04-24 | 9 | 9 | 0 | Codex 5.3 agent |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-04-24
