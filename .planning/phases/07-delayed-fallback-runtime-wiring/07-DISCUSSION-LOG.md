# Phase 07: delayed-fallback-runtime-wiring - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `07-CONTEXT.md` — this log preserves the assumptions and alternatives considered.

**Date:** 2026-04-24
**Phase:** 07-delayed-fallback-runtime-wiring
**Mode:** assumptions
**Areas analyzed:** Delayed fallback intent source, fallback channel strategy, suppression checkpoint architecture, suppression data contract, end-to-end verification strategy

## Assumptions Presented

### Delayed fallback intent source
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Runtime planning must set `delay_fallback`, and current planner contract cannot express it from trigger flow. | Confident | `lib/chimeway/delivery_planning.ex`, `lib/chimeway/deliveries.ex`, `lib/chimeway/delivery.ex`, `lib/chimeway/notifier.ex`, `priv/repo/migrations/20260424082833_create_chimeway_deliveries.exs` |

| Option | Description | Selected |
|--------|-------------|----------|
| Policy-side global mapping | No notifier API change but more hidden behavior | |
| Richer `channels/2` payload shape | Powerful but raises callback complexity | |
| Separate delayed-fallback callback + additive plan API | Explicit, backwards-compatible, least-surprise | ✓ |
| Pluggable intent resolver | Flexible but too heavy for current phase | |

**User's choice:** Proceed with recommended explicit callback + additive API path.
**Notes:** Emphasis on coherent architecture and reduced decision burden for future phases.

---

### Fallback channel strategy
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Delayed fallback should apply to outbound channels only and never suppress `in_app`. | Unclear | `lib/chimeway/policy.ex`, `.planning/ROADMAP.md`, `test/chimeway/integration/delivery_lifecycle_test.exs` |

| Option | Description | Selected |
|--------|-------------|----------|
| Convention default all outbound | Fast adoption, higher hidden-magic risk | |
| Policy-module-only mapping | Centralized but more indirection | |
| Hybrid precedence with explicit overrides and safe default | Deterministic, explainable, user-friendly | ✓ |

**User's choice:** Proceed with recommendation set.
**Notes:** Final recommendation uses explicit default false with deterministic override precedence.

---

### Suppression checkpoint architecture
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Dual-checkpoint model (planning + perform) is the right runtime architecture for delayed fallback and async drift. | Confident | `lib/chimeway/delivery_planning.ex`, `lib/chimeway/dispatch/sync.ex`, `lib/chimeway/dispatch/oban_worker.ex`, `lib/chimeway/deliveries.ex` |

| Option | Description | Selected |
|--------|-------------|----------|
| Planning-only suppression | Faster but stale under delayed execution | |
| Perform-only suppression | Misses early suppression opportunities and planning parity guarantees | |
| Dual-checkpoint strict parity | Highest correctness and explainability | ✓ |
| Post-send reconciliation | Contradicts suppression guarantees | |

**User's choice:** Proceed with recommended parity architecture.
**Notes:** Keep perform-time check as the final gate before adapter invocation.

---

### Suppression data contract
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Current compact suppression contract should remain authoritative in v1 and be hardened with taxonomy/provenance metadata. | Confident | `lib/chimeway/deliveries.ex`, `lib/chimeway/traces.ex`, `lib/chimeway/delivery.ex` |

| Option | Description | Selected |
|--------|-------------|----------|
| Keep compact contract only | Stable but weaker extensibility | |
| Compact contract + strict reason taxonomy + provenance metadata | Best v1 balance of clarity and evolvability | ✓ |
| Dedicated suppression events table | Powerful but out of scope for this phase | |

**User's choice:** Proceed with recommendation set.
**Notes:** Defer suppression-events table until explicit product need.

---

### End-to-end verification strategy
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Trigger-driven tests are required to close the runtime wiring gap; fixture-only delayed-fallback tests are insufficient. | Confident | `test/support/chimeway/dispatch_helpers.ex`, `test/chimeway/policy/delayed_fallback_test.exs`, `test/chimeway/integration/delivery_lifecycle_test.exs` |

| Option | Description | Selected |
|--------|-------------|----------|
| Fixture tests + minimal smoke only | Fast but high false-confidence risk | |
| Trigger-only large integration suite | Good evidence, harder diagnosis/maintenance | |
| Parity matrix (sync + Oban) plus trigger-driven integration evidence | Strong confidence with maintainable structure | ✓ |

**User's choice:** Proceed with recommendation set.
**Notes:** Keep fixture tests as branch-level guards, but acceptance requires trigger-path evidence.

---

## Corrections Made

No corrections — user approved proceeding with synthesized recommendations.

## External Research

- Cross-ecosystem patterns were considered from Laravel Notifications, Symfony Notifier, Rails Noticed, and queue-worker best practices (Oban/Sidekiq-style idempotency and late-checkpoint behavior).
- Research was used to compare explicit callback contracts vs config-driven policy rules, and to avoid known notification-framework footguns (hidden routing magic, scattered decision points, fixture-only confidence).
