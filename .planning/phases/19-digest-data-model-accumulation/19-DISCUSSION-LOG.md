# Phase 19: Digest Data Model & Accumulation - Discussion Log (Assumptions Mode)

**Date:** 2026-04-28
**Mode:** assumptions

## Assumptions Presented

### Digest persistence model
- Assumption: Phase 19 should add first-class digest persistence instead of inferring buckets later
  from `digest_held` delivery rows.
- Evidence: Phase 17 intentionally stopped at state-only `:digest_held`; Phase 19 is the first
  phase allowed to add accumulation artifacts.
- Outcome: Confirmed and strengthened through repo-specific and ecosystem research.

### Canonical source of truth
- Assumption: Canonical source work must remain the existing delivery row, with digest artifacts
  linking to held deliveries rather than replacing them.
- Evidence: Existing one-row-per-`(notification_id, channel)` contract, dispatch gating, and
  row-centric explainability.
- Outcome: Confirmed.

### Grouping and idempotency
- Assumption: Grouping should remain recipient- and channel-aware, with idempotency anchored on
  durable source delivery identity rather than trigger timing or job uniqueness.
- Evidence: Current orchestration is channel-aware; duplicate trigger retries do not create new
  deliveries; Oban uniqueness is not a durable semantic invariant.
- Outcome: Confirmed.

### Product posture and DX
- Assumption: Chimeway should emulate the strengths of successful notification systems without
  becoming a hosted workflow engine, and GSD should default toward cohesive recommendations instead
  of escalating every medium-stakes fork.
- Evidence: Project vision is embedded/local-first and explainability-first; ecosystem research
  showed workflow-heavy systems create complexity and surprise quickly.
- Outcome: Confirmed and lifted into project methodology.

## User Direction Applied

- User requested “discuss all” rather than a narrow assumption correction loop.
- User requested subagent-backed research across architecture, ecosystem patterns, tradeoffs,
  Elixir/Ecto idioms, DX, and footguns.
- User requested one coherent recommendation set rather than a menu of loosely related options.
- User requested that this preference shift left into GSD where possible, except for unusually
  impactful decisions.

## Research Threads

### Repo architecture pass
- Converged on `digest_rules` + `digest_buckets` + `digest_memberships`, while preserving the
  canonical held delivery row as the source work item.
- Flagged category snapshotting and channel-scoped bucket identity as locked invariants.

### Elixir/Ecto idioms pass
- Converged on explicit schemas with database-enforced dedupe, targeted upserts, and durable
  membership rows instead of JSON-only accumulation or queue-centric truth.

### Ecosystem lessons pass
- Copy Knock's boundary rigor, GitHub's reason semantics, Laravel's late send checks, Noticed's
  embedded-library posture, and Discourse's previewability.
- Avoid centralized workflow-engine architecture, mutable opaque windows, and code-name-based
  durable identity.

## Corrections

No fine-grained corrections requested. The user asked for a full researched recommendation set and
accepted the shift from assumption validation into opinionated context capture.

## Final Direction

- Persist first-class digest rules.
- Accumulate into explicit digest buckets.
- Record one durable membership row per source delivery.
- Keep delivery rows canonical.
- Keep Oban optional and downstream.
- Keep the design small, explicit, and explainable.

---

*Phase: 19-digest-data-model-accumulation*
*Discussion logged: 2026-04-28*
