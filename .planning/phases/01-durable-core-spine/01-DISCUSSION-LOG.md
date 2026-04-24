# Phase 1: Durable Core Spine - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `01-CONTEXT.md` - this log preserves alternatives considered.

**Date:** 2026-04-23  
**Phase:** 01-durable-core-spine  
**Areas discussed:** Package topology, API contract style, Persistence boundary, Identifier strategy, Inbox lifecycle semantics  
**Mode:** Auto (`--auto`)

---

## Package topology

| Option | Description | Selected |
|--------|-------------|----------|
| Single `chimeway` package now | Fastest v0.1 iteration, with documented extraction seam for later package split | ✓ |
| Split now: `chimeway`, `chimeway_ecto`, `chimeway_admin` | Early package boundaries, higher setup overhead while APIs are still moving | |
| Split now: `chimeway` + `chimeway_ecto` | Partial modularization with some overhead reduction vs full split | |

**User's choice:** Auto-selected recommended option (`single package now with extraction seam`)  
**Notes:** `[auto] Package topology — selected recommended default`

---

## API contract style

| Option | Description | Selected |
|--------|-------------|----------|
| Explicit behaviours + optional DSL + plain `trigger/3` | Keeps contracts inspectable while offering ergonomic helpers | ✓ |
| DSL-first macros only | Fast onboarding but risk of opaque behavior and reduced debuggability | |
| Plain structs only (no DSL) | Maximum explicitness, less approachable DX for early adopters | |

**User's choice:** Auto-selected recommended option (`behaviour-first with optional DSL`)  
**Notes:** `[auto] API contract style — selected recommended default`

---

## Persistence boundary

| Option | Description | Selected |
|--------|-------------|----------|
| Implement durable `events` + `notifications` now, defer `deliveries`/`attempts` | Matches phase boundary while preserving path to phase 2 delivery model | ✓ |
| Implement all four tables in phase 1 | Higher upfront complexity and phase scope expansion | |
| Implement notifications only without event root | Simpler start but weakens traceability and idempotency model | |

**User's choice:** Auto-selected recommended option (`events + notifications now; deliveries/attempts later`)  
**Notes:** `[auto] Persistence boundary — selected recommended default`

---

## Identifier strategy

| Option | Description | Selected |
|--------|-------------|----------|
| UUID IDs + stable `notification_key` identity + idempotency constraints | Rename-safe identity with early dedupe guarantees | ✓ |
| Bigint IDs + module-name identity | Simpler migration ergonomics but brittle for refactors | |
| UUID IDs, defer idempotency constraints | Faster short-term schema work, higher duplicate risk | |

**User's choice:** Auto-selected recommended option (`UUID + stable keys + idempotency constraints`)  
**Notes:** `[auto] Identifier strategy — selected recommended default`

---

## Inbox lifecycle semantics

| Option | Description | Selected |
|--------|-------------|----------|
| Separate `seen_at`, `read_at`, `archived_at` with explicit APIs | Preserves clear semantics and supports later fallback logic | ✓ |
| Single read/unread boolean | Simpler model, lower semantic precision for future policy features | |
| Auto-mark read on fetch | Easy UX but introduces hidden side effects and policy ambiguity | |

**User's choice:** Auto-selected recommended option (`separate timestamps + explicit transitions`)  
**Notes:** `[auto] Inbox lifecycle semantics — selected recommended default`

---

## Claude's Discretion

- Exact Ecto migration/index details that satisfy the selected data-model decisions.
- Final module organization and naming, as long as stable-key identity and explicit API intent stay intact.

## Deferred Ideas

None.
