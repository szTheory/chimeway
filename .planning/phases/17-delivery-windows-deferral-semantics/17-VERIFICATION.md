---
phase: 17-delivery-windows-deferral-semantics
verified: 2026-04-28T09:44:45Z
status: passed
score: 8/8 must-haves verified
overrides_applied: 0
---

# Phase 17: Delivery Windows & Deferral Semantics Verification Report

**Phase Goal:** Define and implement the durable planning model for immediate sends, quiet-hours deferral, recipient-timezone-aware delivery windows, dispatch gating, and explainability for deferred/held deliveries without pulling resume scheduling forward.
**Verified:** 2026-04-28T09:44:45Z
**Status:** passed
**Re-verification:** No - initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | A delivery row can durably represent `:ready`, `:deferred`, or `:digest_held` without changing the existing `(notification_id, channel)` idempotency boundary. | ✓ VERIFIED | [lib/chimeway/delivery.ex](/Users/jon/projects/chimeway/lib/chimeway/delivery.ex:24) adds first-class orchestration fields and keeps the existing unique constraint in [lib/chimeway/delivery.ex](/Users/jon/projects/chimeway/lib/chimeway/delivery.ex:57); [lib/chimeway/deliveries.ex](/Users/jon/projects/chimeway/lib/chimeway/deliveries.ex:189) updates planning facts on the canonical row. |
| 2 | Recipient policy settings persist and validate the timezone needed for recipient-local planning decisions. | ✓ VERIFIED | [lib/chimeway/policy/settings/setting.ex](/Users/jon/projects/chimeway/lib/chimeway/policy/settings/setting.ex:19) persists `time_zone`; [lib/chimeway/policy/settings/setting.ex](/Users/jon/projects/chimeway/lib/chimeway/policy/settings/setting.ex:45) validates against the configured timezone database; [lib/chimeway/policy/settings.ex](/Users/jon/projects/chimeway/lib/chimeway/policy/settings.ex:17) includes `:time_zone` in the upsert conflict replacement. |
| 3 | Timezone-aware quiet-hours math uses a real timezone database and is covered for DST-sensitive cases. | ✓ VERIFIED | [config/config.exs](/Users/jon/projects/chimeway/config/config.exs:3) configures `Tzdata.TimeZoneDatabase`; [lib/chimeway/orchestration/window_math.ex](/Users/jon/projects/chimeway/lib/chimeway/orchestration/window_math.ex:11) shifts through the configured database; [test/chimeway/orchestration/window_math_test.exs](/Users/jon/projects/chimeway/test/chimeway/orchestration/window_math_test.exs:5) covers runtime config plus DST gap/ambiguity cases. |
| 4 | Product teams can declare immediate or digest-held participation through an explicit notifier/planner seam, and that declaration persists on the canonical delivery row. | ✓ VERIFIED | [lib/chimeway/notifier.ex](/Users/jon/projects/chimeway/lib/chimeway/notifier.ex:24) defines the optional orchestration callback and normalization; [lib/chimeway/delivery_planning.ex](/Users/jon/projects/chimeway/lib/chimeway/delivery_planning.ex:268) resolves it; [test/chimeway/orchestration/planning_declarations_test.exs](/Users/jon/projects/chimeway/test/chimeway/orchestration/planning_declarations_test.exs:46) proves `:digest_held` persists on one canonical row. |
| 5 | Quiet-hours decisions defer rather than suppress, and deferred rows persist the rule, timezone, reason, and next eligible send time. | ✓ VERIFIED | [lib/chimeway/policy/settings.ex](/Users/jon/projects/chimeway/lib/chimeway/policy/settings.ex:113) returns `{:defer, ...}` with `planning_reason`, `planning_context`, and `next_eligible_at`; [lib/chimeway/delivery_planning.ex](/Users/jon/projects/chimeway/lib/chimeway/delivery_planning.ex:240) writes that decision back to the delivery row; [test/chimeway/policy_test.exs](/Users/jon/projects/chimeway/test/chimeway/policy_test.exs:131) and [test/chimeway/orchestration/delivery_planning_test.exs](/Users/jon/projects/chimeway/test/chimeway/orchestration/delivery_planning_test.exs:54) verify the persisted deferred outcome. |
| 6 | Deferred and digest-held rows remain non-dispatchable in both Sync and Oban paths until later scheduling work exists. | ✓ VERIFIED | [lib/chimeway/dispatch/sync.ex](/Users/jon/projects/chimeway/lib/chimeway/dispatch/sync.ex:52) short-circuits non-ready rows; [lib/chimeway/dispatch/oban.ex](/Users/jon/projects/chimeway/lib/chimeway/dispatch/oban.ex:55) only enqueues `status == :pending and orchestration_state == :ready`; [lib/chimeway/dispatch/oban_worker.ex](/Users/jon/projects/chimeway/lib/chimeway/dispatch/oban_worker.ex:120) defensively returns `:ok` for manually enqueued held rows. |
| 7 | Explainability surfaces show why a delivery was deferred instead of suppressed or sent immediately, including normalized rule identity, timezone, and next eligibility. | ✓ VERIFIED | [lib/chimeway/traces.ex](/Users/jon/projects/chimeway/lib/chimeway/traces.ex:131) projects planning facts into the explanation struct; [lib/chimeway/traces.ex](/Users/jon/projects/chimeway/lib/chimeway/traces.ex:198) emits a dedicated `:deferred` timeline event; [lib/chimeway/traces.ex](/Users/jon/projects/chimeway/lib/chimeway/traces.ex:279) sanitizes persisted planning context; [test/chimeway/orchestration/traces_deferral_test.exs](/Users/jon/projects/chimeway/test/chimeway/orchestration/traces_deferral_test.exs:9) verifies the exposed fields and suppression separation. |
| 8 | Held rows stay visible as planned-but-not-dispatched lifecycle records with zero attempts in Phase 17. | ✓ VERIFIED | [test/chimeway/orchestration/dispatch_gating_test.exs](/Users/jon/projects/chimeway/test/chimeway/orchestration/dispatch_gating_test.exs:48) proves Sync and Oban leave held rows pending with zero attempts; [test/chimeway/integration/delivery_lifecycle_test.exs](/Users/jon/projects/chimeway/test/chimeway/integration/delivery_lifecycle_test.exs:583) verifies the same end-to-end via `Chimeway.trigger/3`. |

**Score:** 8/8 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `lib/chimeway/delivery.ex` | Explicit orchestration fields on the canonical delivery row | ✓ VERIFIED | Schema adds `orchestration_state`, `next_eligible_at`, `planning_reason`, and `planning_context`. |
| `priv/repo/migrations/20260428093000_add_delivery_orchestration_fields_to_chimeway_deliveries.exs` | Durable delivery orchestration columns and query index | ✓ VERIFIED | Adds orchestration columns plus index on `[:orchestration_state, :next_eligible_at]`. |
| `lib/chimeway/policy/settings/setting.ex` | Recipient timezone persistence and validation | ✓ VERIFIED | `time_zone` field is stored and validated against `Calendar.get_time_zone_database/0`. |
| `lib/chimeway/policy/settings.ex` | Recipient settings upsert persists timezone and returns planning deferrals | ✓ VERIFIED | Upsert conflict replacement includes `:time_zone`; quiet-hours evaluation returns durable deferral decisions. |
| `priv/repo/migrations/20260428093100_add_time_zone_to_chimeway_policy_settings.exs` | Database support for recipient timezone storage | ✓ VERIFIED | Adds `time_zone` column to `chimeway_policy_settings`. |
| `lib/chimeway/orchestration/window_math.ex` | DST-safe recipient-local window math | ✓ VERIFIED | Computes next eligible UTC timestamps from recipient-local quiet hours. |
| `lib/chimeway/notifier.ex` | Optional notifier declaration contract for orchestration participation | ✓ VERIFIED | Adds explicit orchestration callback and normalization for immediate vs digest-held. |
| `lib/chimeway/delivery_planning.ex` | Planner seam that persists ready/deferred/digest-held outcomes on the existing row | ✓ VERIFIED | Plans idempotent rows, applies declarations, then evaluates policy. |
| `lib/chimeway/policy.ex` | Policy contract distinguishes suppression from deferral | ✓ VERIFIED | Returns `{:defer, decision}` at planning time while preserving suppressive outcomes. |
| `lib/chimeway/dispatch/sync.ex` | Immediate dispatch gate on `orchestration_state == :ready` | ✓ VERIFIED | Non-ready rows are returned untouched. |
| `lib/chimeway/dispatch/oban.ex` | Enqueue gate for held rows | ✓ VERIFIED | Only ready pending rows are enqueued. |
| `lib/chimeway/dispatch/oban_worker.ex` | Defensive perform-time guard for held rows | ✓ VERIFIED | Worker exits early if row is held or already terminal. |
| `lib/chimeway/traces.ex` | Deferred timeline shaping sourced from persisted orchestration facts | ✓ VERIFIED | Explanation builder emits sanitized deferred detail from delivery-row state. |
| `lib/chimeway/traces/explanation.ex` | Expanded explanation contract for held deliveries | ✓ VERIFIED | Adds `planning_reason`, `planning_context`, and `next_eligible_at`. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `config/config.exs` | `lib/chimeway/policy/settings/setting.ex` | configured timezone database used by planning math | ✓ VERIFIED | Config sets `:elixir, :time_zone_database` to `Tzdata.TimeZoneDatabase`, which changeset validation and `WindowMath` consume. |
| `lib/chimeway/policy/settings.ex` | `lib/chimeway/policy/settings/setting.ex` | upsert conflict replacement persists `time_zone` | ✓ VERIFIED | `Repo.insert(on_conflict: {:replace, [..., :time_zone, ...]})` keeps existing recipients updatable. |
| `priv/repo/migrations/20260428093000_add_delivery_orchestration_fields_to_chimeway_deliveries.exs` | `lib/chimeway/delivery.ex` | schema mirrors durable delivery columns | ✓ VERIFIED | Migration and schema expose the same orchestration columns; the plan placeholder path resolved to the concrete timestamped migration. |
| `lib/chimeway/notifier.ex` | `lib/chimeway/delivery_planning.ex` | optional notifier callback resolves declared orchestration participation | ✓ VERIFIED | `Notifier.resolve_orchestration/4` feeds `apply_declared_orchestration/3`. |
| `lib/chimeway/delivery_planning.ex` | `lib/chimeway/deliveries.ex` | idempotent row creation followed by orchestration-state update on the same delivery row | ✓ VERIFIED | Planner calls `Deliveries.plan_delivery/3` then `Deliveries.apply_planning_decision/2`. |
| `lib/chimeway/policy.ex` | `lib/chimeway/policy/settings.ex` | planning-time policy preserves suppressions and converts quiet-hours into deferral facts | ✓ VERIFIED | `Policy.evaluate/2` propagates `{:defer, decision}` from `Settings.evaluate/2`. |
| `lib/chimeway/dispatch/sync.ex` | `lib/chimeway/dispatch/oban.ex` | shared gating on ready-for-dispatch orchestration state | ✓ VERIFIED | Sync short-circuits held rows; Oban only enqueues ready rows. |
| `lib/chimeway/dispatch/oban_worker.ex` | `lib/chimeway/delivery_planning.ex` | defensive perform-time guard honors planning state | ✓ VERIFIED | Worker checks persisted `orchestration_state` before any adapter execution. |
| `lib/chimeway/traces.ex` | `lib/chimeway/traces/explanation.ex` | explanation struct exposes deferred reason, timezone context, rule identity, and next eligible time | ✓ VERIFIED | `Traces.explain_delivery/2` populates the added explanation fields from persisted delivery state. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| `lib/chimeway/policy/settings.ex` | `decision.next_eligible_at` | `WindowMath.next_eligible_at/2` using persisted settings `time_zone` and quiet-hour fields | Yes | ✓ FLOWING |
| `lib/chimeway/delivery_planning.ex` | `delivery.orchestration_state` | `Notifier.resolve_orchestration/4` plus `Policy.evaluate/2` | Yes | ✓ FLOWING |
| `lib/chimeway/deliveries.ex` | persisted planning columns | `Repo.update/1` on the canonical `Delivery` row | Yes | ✓ FLOWING |
| `lib/chimeway/traces.ex` | `Explanation.planning_context` and `timeline[:deferred]` | persisted `delivery.planning_reason`, `delivery.planning_context`, and `delivery.next_eligible_at` | Yes | ✓ FLOWING |
| `lib/chimeway/dispatch/oban.ex` / `lib/chimeway/dispatch/sync.ex` | dispatch gating condition | persisted `delivery.orchestration_state` from planning writes | Yes | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Phase 17 orchestration, policy, trace, and gating suites pass | `mix test test/chimeway/policy_settings_test.exs test/chimeway/orchestration/window_math_test.exs test/chimeway/orchestration/delivery_planning_test.exs test/chimeway/orchestration/planning_declarations_test.exs test/chimeway/policy_test.exs test/chimeway/notifier_contract_test.exs` | `34 tests, 0 failures` | ✓ PASS |
| Full project suite still passes with Phase 17 code present | `mix test` | `269 tests, 0 failures` | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| `ORCH-01` | `17-01`, `17-02`, `17-03` | Product teams can declare whether a delivery sends immediately, defers, or participates in digesting. | ✓ SATISFIED | Notifier orchestration callback and planner persistence in [lib/chimeway/notifier.ex](/Users/jon/projects/chimeway/lib/chimeway/notifier.ex:24) and [lib/chimeway/delivery_planning.ex](/Users/jon/projects/chimeway/lib/chimeway/delivery_planning.ex:277); canonical-row proof in [test/chimeway/orchestration/planning_declarations_test.exs](/Users/jon/projects/chimeway/test/chimeway/orchestration/planning_declarations_test.exs:46). |
| `ORCH-02` | `17-01`, `17-02`, `17-03` | Delivery-window decisions respect recipient timezone and persist reason, window rule, and next eligible send time. | ✓ SATISFIED | Timezone validation/upsert in [lib/chimeway/policy/settings/setting.ex](/Users/jon/projects/chimeway/lib/chimeway/policy/settings/setting.ex:45) and [lib/chimeway/policy/settings.ex](/Users/jon/projects/chimeway/lib/chimeway/policy/settings.ex:17); deferred persistence in [lib/chimeway/policy/settings.ex](/Users/jon/projects/chimeway/lib/chimeway/policy/settings.ex:113); explainability in [lib/chimeway/traces.ex](/Users/jon/projects/chimeway/lib/chimeway/traces.ex:198). |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| None | - | No blocking placeholder, stub, or hollow-data patterns found in the phase implementation paths. | - | - |

### Human Verification Required

None.

### Gaps Summary

No goal-blocking gaps found. The only automated artifact false negative came from the plan using a `<timestamp>` placeholder path for the delivery migration; the concrete migration file exists and matches the schema/wiring.

---

_Verified: 2026-04-28T09:44:45Z_
_Verifier: Claude (gsd-verifier)_
