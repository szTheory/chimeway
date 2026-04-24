# Phase 6: Delivery Planning and Policy Checkpoint Repair - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves alternatives and rationale.

**Date:** 2026-04-24
**Phase:** 06-delivery-planning-and-policy-checkpoint-repair
**Areas discussed:** Channel fanout contract, planning-time suppression semantics, sync/Oban parity architecture, verification scope

---

## Channel fanout contract

| Option | Description | Selected |
|--------|-------------|----------|
| Channels encoded directly in `recipients/1` output | Fast patch, but blurs identity vs routing and increases shape drift risk | |
| Add `channels/2` callback; keep `recipients/1` identity-only | Explicit, deterministic, and easiest to enforce consistently across sync+Oban | ✓ |
| `delivery_intents/1` fully expanded callback | Powerful but too heavy and easy to misuse for current phase scope | |
| Config-first global channel policy map | Easy defaults but weak recipient-level precision and higher surprise risk | |

**User's choice:** Delegated to Claude for one-shot recommendation; locked to `channels/2` + shared planner approach.
**Notes:** Recommendation prioritized explicit contracts, deterministic fanout, and least-surprise Elixir DX with staged backward compatibility.

---

## Planning-time suppression semantics

| Option | Description | Selected |
|--------|-------------|----------|
| Persist suppressed delivery row | Durable explainability and operator visibility; keeps lifecycle model complete | ✓ |
| Skip row creation for suppressed channels | Lower write volume but breaks explainability and creates ambiguous absence | |
| Separate suppression ledger table | Preserves evidence but adds schema/join complexity prematurely | |
| Reason-dependent hybrid persistence | Inconsistent semantics and high user surprise risk | |

**User's choice:** Delegated to Claude for one-shot recommendation; locked to durable suppressed rows with explicit reasons.
**Notes:** Recommendation aligned with project core value ("why wasn't this sent?") and existing status model.

---

## Sync/Oban parity architecture

| Option | Description | Selected |
|--------|-------------|----------|
| Keep duplicated planning/policy logic in each dispatcher | Minimal immediate churn, high long-term drift risk | |
| Shared planning service + thin sync/Oban executors | Single source of truth for parity and better maintainability | ✓ |
| Monolithic unified dispatcher with mode branches | Enforces parity but becomes branch-heavy and harder to reason about | |
| Planner plugin behavior boundary now | Flexible but premature abstraction for this repair phase | |

**User's choice:** Delegated to Claude for one-shot recommendation; locked to shared planning context and thin execution strategies.
**Notes:** Recommendation follows Phoenix context style and reduces sync/Oban drift risk by construction.

---

## Verification scope for standard outbound success flow

| Option | Description | Selected |
|--------|-------------|----------|
| Unit-heavy only | Fast but weak seam confidence for Phase 6 success criteria | |
| Integration-heavy everywhere | High realism but brittle/slower and harder to maintain | |
| Contract matrix only | Good parity but insufficient end-to-end flow confidence alone | |
| Hybrid: thin E2E spine + parity matrix + targeted units | Balanced confidence, speed, and contributor ergonomics | ✓ |

**User's choice:** Delegated to Claude for one-shot recommendation; locked to hybrid verification strategy.
**Notes:** Recommendation preserves fast local feedback while enforcing parity and durable chain assertions.

---

## Claude's Discretion

- Exact module names and helper boundaries for planner/executor extraction.
- Fallback/deprecation messaging details for `channels/2` migration.
- Final shape of parity test support helpers and tagging strategy.

## Deferred Ideas

- Planner/plugin extension point for host-app overrides after parity baseline is stable.
- Separate suppression-ledger table optimization.
- Future major-version requirement to make `channels/2` mandatory.
