# Phase 2: First Outbound Delivery Slice - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `02-CONTEXT.md` - this log preserves alternatives considered.

**Date:** 2026-04-24
**Phase:** 02-first-outbound-delivery-slice
**Areas discussed:** Recipient-to-channel planning contract, first outbound seam scope, delivery schema breadth timing, attempt contract and metadata depth

---

## Recipient-to-channel planning contract

| Option | Description | Selected |
|--------|-------------|----------|
| Canonical recipient notification then planner expands channels | Keeps `event -> notification -> delivery -> attempt` clean and deterministic | |
| Recipient+channel emitted directly by notifier resolver | Maximizes notifier flexibility but pushes complexity into each notifier | |
| Hybrid intent model | Notifier declares intent; planner expands channels and enforces policy/idempotency | ✓ |

**User's choice:** Hybrid intent model (delegated recommendation accepted from deep subagent research).  
**Notes:** Chosen for least surprise, deterministic planning, and compatibility with existing `normalize_recipients/1` behavior.

---

## First outbound seam scope

| Option | Description | Selected |
|--------|-------------|----------|
| Test + Logger adapters only | Fastest low-risk seam proving core contract and attempt tracking | |
| Ship Swoosh wrapper now | Real provider integration sooner, but broader scope/risk in this slice | |
| Test+Logger now with Swoosh-ready contract path | Lean Phase 2 plus no-rewrite migration path to real provider adapter | ✓ |

**User's choice:** Test+Logger now with Swoosh-ready contract path (delegated recommendation accepted).  
**Notes:** Maximizes Phase 2 execution focus while preserving clear adoption path toward production adapters.

---

## Delivery schema breadth timing

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal now, defer policy columns to Phase 3 | Smaller initial schema; extra later migration churn | |
| Add policy columns now and activate immediately | Fewer migrations; risks premature semantics | |
| Add now with reserved semantics until Phase 3 | Forward-compatible schema with disciplined activation later | ✓ |

**User's choice:** Add now with reserved semantics until Phase 3 (delegated recommendation accepted).  
**Notes:** Aligns with additive Ecto migration strategy and avoids avoidable upgrade churn for OSS users.

---

## Attempt outcome contract and metadata depth

| Option | Description | Selected |
|--------|-------------|----------|
| Strict canonical classified outcomes + compact redacted metadata | Strong consistency and safety; limited deep diagnostics | |
| Loose tuples + mostly raw provider response | Fast to ship but inconsistent and high leak risk | |
| Canonical classified outcomes + optional controlled deep diagnostics | Keeps consistency while allowing deeper incident debug with guardrails | ✓ |

**User's choice:** Canonical classified outcomes plus optional controlled deep diagnostics (delegated recommendation accepted).  
**Notes:** Canonical fields stay authoritative; optional detail must be redacted, bounded, and policy-governed.

---

## Claude's Discretion

- Exact callback naming for channel intent contract.
- Final enum/type mapping for delivery and attempt outcomes.
- Concrete redaction allowlist, truncation limits, and retention implementation for optional diagnostics.

## Deferred Ideas

- Implementing full Swoosh adapter in this same slice (kept as follow-up path, not required to prove seam).
- Expanding provider-specific deep diagnostics policy beyond canonical metadata baseline.
- Wider multi-channel routing ergonomics after base contracts are proven.
