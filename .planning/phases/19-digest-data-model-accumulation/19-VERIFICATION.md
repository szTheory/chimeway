---
phase: 19-digest-data-model-accumulation
verified: 2026-04-28T14:49:09Z
status: passed
score: 12/12 must-haves verified
overrides_applied: 0
---

# Phase 19: Digest Data Model & Accumulation Verification Report

**Phase Goal:** Introduce first-class digest rules and durable accumulation records for repeated notification streams.
**Verified:** 2026-04-28T14:49:09Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Teams can declare digest grouping rules by recipient and notification grouping key. | ✓ VERIFIED | `DigestRule` persists grouping and window contracts in `lib/chimeway/digests/digest_rule.ex:15-69`; rule API upserts and looks up by stable rule identity in `lib/chimeway/digests.ex:16-49`; buckets snapshot `recipient_id`, `grouping_mode`, and `grouping_value` in `lib/chimeway/digests/digest_bucket.ex:17-61`. |
| 2 | Repeated events accumulate into durable digest buckets instead of emitting redundant immediate deliveries when configured to batch. | ✓ VERIFIED | `Accumulation.accumulate_delivery/2` locks the canonical delivery, finds a matching rule, derives a bucket window, and upserts a durable bucket plus membership in `lib/chimeway/digests/accumulation.ex:35-93,207-258`; tests prove bucket creation, reuse, and window splitting in `test/chimeway/digests/accumulation_test.exs:11-277`. |
| 3 | Digest planning remains idempotent under retries and duplicate trigger conditions. | ✓ VERIFIED | Membership uniqueness is enforced on `delivery_id` in `lib/chimeway/digests/digest_membership.ex:16-33` and `priv/repo/migrations/20260428102200_create_chimeway_digest_memberships.exs:32-36`; repeated planner calls keep one delivery row and one membership in `test/chimeway/orchestration/delivery_planning_test.exs:79-109`. |
| 4 | Teams can persist digest rules with stable `rule_key` + `rule_version` identity instead of notifier module names. | ✓ VERIFIED | `upsert_rule/1` uses `conflict_target: [:rule_key, :rule_version]` in `lib/chimeway/digests.ex:18-25`; schema and migration enforce the same contract in `lib/chimeway/digests/digest_rule.ex:31-52` and `priv/repo/migrations/20260428102000_create_chimeway_digest_rules.exs:22-30`. |
| 5 | Digest bucket identity is durable and unique by rule, recipient, channel, grouping value, and window boundaries. | ✓ VERIFIED | Bucket schema requires the snapshot identity fields in `lib/chimeway/digests/digest_bucket.ex:17-61`; the database unique index spans `digest_rule_id`, `recipient_id`, `channel`, `grouping_value`, `window_starts_at`, and `window_ends_at` in `priv/repo/migrations/20260428102100_create_chimeway_digest_buckets.exs:30-44`. |
| 6 | Digest rule and bucket storage only persist explainable grouping and window facts, not raw payload snapshots. | ✓ VERIFIED | Digest tables contain only rule selectors, grouping facts, recipient/channel scope, and window metadata in `priv/repo/migrations/20260428102000_create_chimeway_digest_rules.exs:5-19` and `priv/repo/migrations/20260428102100_create_chimeway_digest_buckets.exs:5-27`; no payload/provider fields are present. |
| 7 | A source delivery can be added to at most one digest membership record, even under repeated planning retries. | ✓ VERIFIED | Membership uniqueness is enforced by both the named unique index and `insert_all(... on_conflict: :nothing, conflict_target: [:delivery_id])` in `lib/chimeway/digests/accumulation.ex:242-258`; tests prove duplicate accumulation stays at one membership in `test/chimeway/digests/accumulation_test.exs:53-85`. |
| 8 | Only deliveries that remain `status: :pending` and `orchestration_state: :digest_held` accumulate into digest buckets. | ✓ VERIFIED | Accumulation gates on `accumulatable?/1` in `lib/chimeway/digests/accumulation.ex:101-102`; planning only invokes accumulation after policy evaluation when the row is still pending and held in `lib/chimeway/delivery_planning.ex:100-101,327-345`; suppressed and immediate cases create no memberships in `test/chimeway/orchestration/delivery_planning_test.exs:136-168`. |
| 9 | Bucket counters and timestamps advance only when a new membership is inserted. | ✓ VERIFIED | `insert_membership/3` increments bucket counters only when `inserted_count == 1`, otherwise it only reloads the bucket in `lib/chimeway/digests/accumulation.ex:242-260`; retry tests show `member_count` remains `1` on a repeated call in `test/chimeway/digests/accumulation_test.exs:71-85`. |
| 10 | Planner-triggered digest accumulation only occurs after the canonical delivery row remains pending and `:digest_held`. | ✓ VERIFIED | `plan_one_channel/5` evaluates policy before `maybe_accumulate_digest_delivery/1` and the helper checks `delivery.status == :pending and delivery.orchestration_state == :digest_held` before calling accumulation in `lib/chimeway/delivery_planning.ex:89-103,327-345`. |
| 11 | Teams can declare digest participation with an optional explicit digest key while preserving the normalized persisted mode `:digest_held`. | ✓ VERIFIED | `Notifier.resolve_orchestration/4` normalizes `:digest`, `:digest_held`, and `{:digest, [digest_key: ...]}` into `:digest_held` plus normalized digest-key metadata in `lib/chimeway/notifier.ex:58-238`; planning persists that metadata on the delivery row in `lib/chimeway/delivery_planning.ex:282-325`; declaration tests verify the stored row shape in `test/chimeway/orchestration/planning_declarations_test.exs:48-90`. |
| 12 | Repeated planning calls keep one delivery row and one digest membership for the same held source work item. | ✓ VERIFIED | `Deliveries.plan_delivery/3` is reused through the planner choke point and repeated planning tests confirm one canonical row and one membership in `test/chimeway/orchestration/planning_declarations_test.exs:72-90` and `test/chimeway/orchestration/delivery_planning_test.exs:79-109`. |

**Score:** 12/12 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `lib/chimeway/digests.ex` | Public rule API for upsert, fetch, listing, and lookup | ✓ VERIFIED | Substantive at 117 lines; wired into accumulation and tests via `DigestRule.changeset/2` and `find_matching_rule/1`. |
| `lib/chimeway/digests/digest_rule.ex` | Rule schema and validation for stable identity, grouping mode, and window strategy | ✓ VERIFIED | Required fields, enums, and fixed/boundary validation are implemented and exercised by tests. |
| `lib/chimeway/digests/digest_bucket.ex` | Bucket schema and uniqueness contract for recipient/channel/grouping/window accumulation | ✓ VERIFIED | Snapshot identity, window metadata, and unique constraint are present and match the migration contract. |
| `priv/repo/migrations/20260428102000_create_chimeway_digest_rules.exs` | Digest rules table with durable rule identity and window columns | ✓ VERIFIED | Concrete migration exists and matches the plan intent; `verify.artifacts` false-negative was due to the helper not resolving wildcard plan paths. |
| `priv/repo/migrations/20260428102100_create_chimeway_digest_buckets.exs` | Digest buckets table with composite uniqueness for digest accumulation | ✓ VERIFIED | Concrete migration exists with the declared composite identity index; helper false-negative only. |
| `lib/chimeway/digests/digest_membership.ex` | Explicit auditable membership schema linked to source delivery rows | ✓ VERIFIED | Substantive schema with `delivery_id` uniqueness and associations to bucket, delivery, and notification. |
| `lib/chimeway/digests/accumulation.ex` | Transactional bucket upsert and membership insert service | ✓ VERIFIED | Locks the delivery, derives lookup facts and windows, upserts buckets, and conditionally inserts membership. |
| `priv/repo/migrations/20260428102200_create_chimeway_digest_memberships.exs` | Membership table with one-row-per-source-delivery uniqueness | ✓ VERIFIED | Concrete migration exists with the required `delivery_id` unique index; helper false-negative only. |
| `test/chimeway/digests/digest_rule_test.exs` | Proof of rule validation and stable identity upsert behavior | ✓ VERIFIED | Covers required rule fields, grouping modes, window validation, and durable upsert behavior. |
| `test/chimeway/digests/digest_bucket_test.exs` | Proof of bucket validation and uniqueness behavior | ✓ VERIFIED | Covers snapshot required fields, uniqueness, counters, and non-use of `next_eligible_at`. |
| `test/chimeway/digests/accumulation_test.exs` | Proof of idempotent accumulation and held-delivery gating | ✓ VERIFIED | Covers no-op states, membership idempotency, category snapshotting, and fixed/boundary windows. |
| `lib/chimeway/notifier.ex` / `lib/chimeway/delivery_planning.ex` / `test/chimeway/orchestration/delivery_planning_test.exs` | Planner-side digest declaration normalization and accumulation wiring | ✓ VERIFIED | Normalized digest-key declarations persist on the canonical row, and repeated planning remains row- and membership-idempotent. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `lib/chimeway/digests.ex` | `lib/chimeway/digests/digest_rule.ex` | rule upsert and lookup use `DigestRule.changeset/2` instead of ad hoc maps | ✓ WIRED | `verify.key-links` passed for `19-01-PLAN.md`; direct evidence at `lib/chimeway/digests.ex:18-25,43-49`. |
| `lib/chimeway/digests/digest_bucket.ex` | `priv/repo/migrations/20260428102100_create_chimeway_digest_buckets.exs` | schema fields match composite uniqueness and window metadata columns | ✓ WIRED | Schema and migration both expose `grouping_value`, `window_starts_at`, `window_ends_at`, and `member_count`. |
| `lib/chimeway/digests/accumulation.ex` | `lib/chimeway/digests/digest_membership.ex` | transaction inserts membership with `delivery_id` uniqueness before updating bucket counters | ✓ WIRED | `verify.key-links` passed for `19-02-PLAN.md`; `insert_all` with `conflict_target: [:delivery_id]` is implemented at `lib/chimeway/digests/accumulation.ex:242-258`. |
| `lib/chimeway/digests/accumulation.ex` | `lib/chimeway/digests/digest_bucket.ex` | accumulation computes and upserts bucket identity using snapshot window fields | ✓ WIRED | `verify.key-links` passed for `19-02-PLAN.md`; upsert path uses `grouping_value`, `window_starts_at`, and `window_ends_at` at `lib/chimeway/digests/accumulation.ex:75-87,207-239`. |
| `lib/chimeway/notifier.ex` | `lib/chimeway/delivery_planning.ex` | normalized orchestration carries `digest_key` while persisting `:digest_held` | ✓ WIRED | `verify.key-links` passed for `19-03-PLAN.md`; normalization is in `lib/chimeway/notifier.ex:153-238` and persistence is in `lib/chimeway/delivery_planning.ex:282-325`. |
| `lib/chimeway/delivery_planning.ex` | `lib/chimeway/digests/accumulation.ex` | planner calls accumulation only after policy leaves the canonical delivery pending and held | ✓ WIRED | `verify.key-links` passed for `19-03-PLAN.md`; call order is `evaluate_planning_policy` then `maybe_accumulate_digest_delivery` in `lib/chimeway/delivery_planning.ex:89-103`. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| `lib/chimeway/digests/accumulation.ex` | `lookup` and `grouping_value` | Canonical `Delivery` row plus persisted `Notification` and `Event` loaded in `load_context!/1` and `build_lookup_attrs/4` | Yes | ✓ FLOWING |
| `lib/chimeway/digests/accumulation.ex` | `window_starts_at` / `window_ends_at` | Derived from rule-backed fixed or boundary window configuration in `derive_window!/2` | Yes | ✓ FLOWING |
| `lib/chimeway/digests/accumulation.ex` | `member_count`, `first_accumulated_at`, `last_accumulated_at` | Real DB writes through `insert_all` + conditional `update_all` in `insert_membership/3` and `increment_bucket!/2` | Yes | ✓ FLOWING |
| `lib/chimeway/delivery_planning.ex` | planner lookup attrs passed into accumulation | Persisted delivery row plus notification/event lookups and `Policy.delivery_category/1` at `lib/chimeway/delivery_planning.ex:327-366` | Yes | ✓ FLOWING |
| `lib/chimeway/notifier.ex` | normalized `digest_keys` / `default_digest_key` | Notifier or planner override declaration normalized by `resolve_orchestration/4` | Yes | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Phase 19 digest storage, accumulation, and planner wiring suites pass | `mix test test/chimeway/digests/digest_rule_test.exs test/chimeway/digests/digest_bucket_test.exs test/chimeway/digests/accumulation_test.exs test/chimeway/orchestration/planning_declarations_test.exs test/chimeway/orchestration/delivery_planning_test.exs` | `25 tests, 0 failures` | ✓ PASS |
| Phase 19 schema drift | `gsd-sdk query verify.schema-drift 19` | `{ "valid": true, "issues": [], "checked": 3 }` | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| `DIGEST-01` | `19-01`, `19-02`, `19-03` | Teams can define digest rules that group repeated notifications by recipient, notification key or category, and delivery window. | ✓ SATISFIED | Rule declaration and validation are implemented in `lib/chimeway/digests/digest_rule.ex:15-69`; recipient-scoped bucket identity is persisted in `lib/chimeway/digests/digest_bucket.ex:17-61` and `priv/repo/migrations/20260428102100_create_chimeway_digest_buckets.exs:14-40`; accumulation and planner idempotency are proven by `test/chimeway/digests/accumulation_test.exs:11-277` and `test/chimeway/orchestration/delivery_planning_test.exs:79-109`. |

Orphaned requirements: none. `REQUIREMENTS.md` maps `DIGEST-01` to Phase 19 and all Phase 19 plans declare that ID.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| None | - | No TODO/FIXME placeholders, empty implementations, or hollow-data paths found in the scoped production files. | - | - |

### Human Verification Required

None.

### Gaps Summary

No goal-blocking gaps found. The only automated helper anomaly was `verify.artifacts` reporting wildcard migration paths as missing; manual verification confirmed the concrete timestamped migration files exist and match the declared digest rule, bucket, and membership contracts.

---

_Verified: 2026-04-28T14:49:09Z_
_Verifier: Claude (gsd-verifier)_
