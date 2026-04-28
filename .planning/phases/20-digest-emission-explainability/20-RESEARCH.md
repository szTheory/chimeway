# Phase 20: Digest Emission & Explainability - Research

**Researched:** 2026-04-28 [VERIFIED: system date]
**Domain:** Durable digest flush, canonical dispatch reuse, and operator explainability on Ecto/PostgreSQL [VERIFIED: .planning/phases/20-digest-emission-explainability/20-CONTEXT.md]
**Confidence:** HIGH on architectural direction and repo fit [VERIFIED: codebase read] / MEDIUM on exact field names for emission state and source-row convergence [VERIFIED: phase context discretion]

<user_constraints>
## User Constraints (from CONTEXT.md)

Copied from `.planning/phases/20-digest-emission-explainability/20-CONTEXT.md` with no scope expansion. [VERIFIED: .planning/phases/20-digest-emission-explainability/20-CONTEXT.md]

### Locked Decisions
- **D-01:** Emit each digest flush as its own canonical `chimeway_deliveries` row and reuse the normal dispatch lifecycle. [VERIFIED]
- **D-02:** Flush work stays limited to durable bucket claim, member resolution, digest-delivery creation, and canonical enqueue/dispatch handoff. [VERIFIED]
- **D-03:** Oban is optional execution infrastructure, not the source of truth. [VERIFIED]
- **D-04:** `digest_memberships` must persist terminal per-member resolution facts (`included`, `skipped`, `emitted_immediately`) plus reason, timestamps, and `digest_delivery_id` when included. [VERIFIED]
- **D-05:** Resolution facts must snapshot the exact rule/window identity used at flush time. [VERIFIED]
- **D-06:** Idempotency must be database-backed across bucket claim, membership resolution, digest delivery creation, and dispatch handoff. [VERIFIED]
- **D-07:** Explainability stays under `Chimeway.Traces`. [VERIFIED]
- **D-08:** Operators must be able to explain source inclusion/exclusion/immediate-send and emitted digest contents from durable data. [VERIFIED]
- **D-09:** Explainability data must remain sanitized and avoid raw payload/provider dumps. [VERIFIED]
- **D-10:** Source `:digest_held` rows must converge in place after flush. [VERIFIED]
- **D-11:** Included source rows should land on an explicit digest terminal outcome on the canonical row and link back to the emitted digest delivery. [VERIFIED]
- **D-12:** Skipped-at-flush or immediate-send outcomes must also converge durably with explicit reasons. [VERIFIED]
- **D-13:** One obvious operator story: delivery rows stay the lifecycle spine, memberships explain membership, and `Chimeway.Traces` stays the answer surface. [VERIFIED]
- **D-14:** Explainability should feel like concrete operator reasoning, not a hosted workflow debugger. [VERIFIED]
- **D-15:** Avoid N+1 flush paths; preload or join the source facts needed for rechecks and explanations. [VERIFIED]

### Claude's Discretion
- Exact schema and helper names for flush/emission modules.
- Whether the explicit digest terminal outcome on source rows is a new `Delivery.status` value or an equivalent durable shape.
- Whether flush execution is driven by service-first APIs only or also by an optional Oban worker, as long as correctness does not depend on Oban.

</user_constraints>

## Recommendation

Phase 20 should introduce one explicit digest emission transaction that turns a due bucket into:

1. One canonical emitted digest event/notification/delivery chain.
2. One durable resolution row state per membership.
3. One explicit convergence outcome on every source delivery row touched by the flush.
4. One dispatch handoff through the existing sync/Oban delivery path.

The key design choice is to keep digest emission on the same durable lifecycle spine as all other notifications. The emitted digest should not be a bucket-only artifact or a provider-only action. It should have its own canonical delivery row, with source rows linked to it through `digest_memberships`.

## Why This Fits The Repo

### The existing lifecycle spine already assumes delivery rows are the operator truth

`Chimeway.Dispatch.ObanWorker` and `Chimeway.Dispatch.Sync` both operate from `delivery_id` only and treat queue state as disposable execution detail. [VERIFIED: lib/chimeway/dispatch/oban.ex] [VERIFIED: lib/chimeway/dispatch/oban_worker.ex]

### Phase 19 already established digest buckets and explicit memberships as durable business data

`DigestBucket` persists grouping/window identity and `DigestMembership` already provides the durable join point to extend with resolution facts. [VERIFIED: lib/chimeway/digests/digest_bucket.ex] [VERIFIED: lib/chimeway/digests/digest_membership.ex]

### Trace surfaces are row-centric today

`Traces.explain_delivery/2` already builds a single canonical explanation from persisted delivery status, planning context, metadata, and attempts. Phase 20 should extend that model instead of inventing a separate digest-debug API. [VERIFIED: lib/chimeway/traces.ex] [VERIFIED: lib/chimeway/traces/explanation.ex]

## Recommended Architecture

### 1. Emit a synthetic digest event/notification/delivery chain

The emitted digest needs a real event/notification/delivery spine so it can:
- pass through the same dispatch code path as normal deliveries,
- gain attempt history, retries, and final status convergence for free,
- remain explainable through existing trace contracts,
- preserve local-first host ownership of delivery history.

Recommended shape:
- create a digest event with stable digest identity metadata,
- create a digest notification for the recipient/channel scope,
- plan one emitted digest delivery row in `:ready`,
- dispatch that row through existing `Dispatch.Sync` / `Dispatch.Oban`.

This is the cleanest way to satisfy D-01 and D-02 without special-casing provider execution.

### 2. Extend memberships with immutable resolution facts

`digest_memberships` should become the durable answer to "what happened to this source row when the bucket flushed?"

Recommended added fields:
- `resolution` or `resolution_status`
- `resolution_reason`
- `resolved_at`
- `resolved_rule_key`
- `resolved_rule_version`
- `resolved_window_starts_at`
- `resolved_window_ends_at`
- `digest_delivery_id`

These should be written once when the membership leaves unresolved state. They should not be re-derived later from mutable bucket or rule rows.

### 3. Add a durable bucket claim / emission identity boundary

The flush service needs a DB-backed claim so retries or duplicate workers cannot emit the same bucket twice.

Recommended bucket additions:
- `flush_state` (`pending`, `processing`, `emitted`, `partial`, or equivalent)
- `claimed_at`
- `emitted_at`
- `digest_delivery_id`

The claim must happen inside the same transaction that resolves members and creates the emitted digest delivery row. If a retry sees `digest_delivery_id` already present, it should reuse that digest delivery instead of creating a second one.

### 4. Converge source rows explicitly

Included source rows should not remain `status: :pending`.

Recommended posture:
- add a new terminal `Delivery.status` such as `:digested` for included source rows,
- keep a durable link to the emitted digest delivery in metadata or a first-class field,
- use explicit reason strings for skipped-at-flush and immediate-send outcomes,
- keep source-row convergence separate from the emitted digest delivery's own lifecycle.

This is the most coherent fit for D-10 through D-12 because it lets traces and later analytics distinguish:
- still waiting,
- digested,
- emitted immediately,
- suppressed/skipped,
- cancelled for other lifecycle reasons.

### 5. Re-evaluate at flush time, but only on already-snapshotted facts

The flush service should not trust only the Phase 19 accumulation outcome. It should re-evaluate final eligibility at flush time using already persisted source facts and current policy seams where necessary. That is how Phase 20 can explain why a row entered a bucket but later:
- stayed included,
- was skipped,
- was released to immediate send instead.

This recheck should preload source notifications/events in bulk to avoid N+1 queries. [VERIFIED: phase context D-15]

## Recommended Project Structure

```text
lib/chimeway/digests/
├── emission.ex                # flush claim, membership resolution, digest row creation
├── digest_bucket.ex           # flush-state fields and emitted digest linkage
└── digest_membership.ex       # resolution facts and digest_delivery linkage

lib/chimeway/
├── delivery.ex                # explicit source-row digest terminal outcome
├── deliveries.ex              # helper(s) for source-row convergence
└── traces.ex                  # source + emitted digest explanation extensions

lib/chimeway/dispatch/
└── digest_flush_worker.ex     # optional Oban worker for due bucket execution, if used

priv/repo/migrations/
├── *_alter_chimeway_digest_memberships_for_resolution.exs
├── *_alter_chimeway_digest_buckets_for_emission.exs
└── *_alter_chimeway_deliveries_for_digest_outcome.exs

test/chimeway/digests/
├── emission_test.exs
└── flush_worker_test.exs

test/chimeway/orchestration/
└── digest_explainability_test.exs

test/chimeway/integration/
└── digest_delivery_lifecycle_test.exs
```

## Implementation Patterns To Use

### Pattern 1: Canonical-row mutation with explicit named helpers

`Deliveries.resume_deferred_delivery/2`, `cancel_deferred_delivery/3`, and `exhaust_delivery/1` already show the house style: add a named helper for a meaningful lifecycle convergence instead of letting callers assemble ad hoc updates. [VERIFIED: lib/chimeway/deliveries.ex]

Use the same pattern for:
- marking a source delivery as digested,
- releasing a source delivery to immediate-send at flush,
- marking a source delivery skipped at flush.

### Pattern 2: Thin-job execution, transaction-backed truth

`ObanWorker` proves the repo wants jobs that carry only durable identifiers. [VERIFIED: lib/chimeway/dispatch/oban_worker.ex]

If Phase 20 adds a flush worker, its job args should contain only bucket identity or emitted digest delivery identity. It must never carry raw membership payloads.

### Pattern 3: Single transaction around claim + create + resolve

`Accumulation.accumulate_delivery/2` already establishes the pattern of row lock, database gating, and idempotent write behavior. [VERIFIED: lib/chimeway/digests/accumulation.ex]

Phase 20 should mirror that structure for emission:
- lock bucket,
- load unresolved memberships in bulk,
- resolve membership outcomes,
- create or reuse emitted digest delivery row,
- converge source rows,
- persist bucket emitted state,
- hand off to dispatcher.

### Pattern 4: Trace timeline extension, not sidecar logs

`Traces.explain_delivery/2` builds operator explanations from one delivery row plus related attempts. [VERIFIED: lib/chimeway/traces.ex]

Phase 20 should extend:
- source delivery explanations with digest membership resolution,
- emitted digest explanations with included/excluded membership summaries,
- timeline events such as `:digested`, `:digest_skipped`, or `:digest_emitted`.

## Anti-Patterns To Avoid

- **Bucket-only truth:** a bucket row alone cannot replace a canonical emitted delivery row.
- **Queue-shaped truth:** never require Oban job state to explain what happened.
- **Opaque JSON resolution blobs:** resolution facts belong in first-class membership columns.
- **Leaving included source rows pending forever:** this breaks explainability and later analytics.
- **Per-membership `Repo.get!` loops:** bulk-load membership/source facts for one flush.
- **Raw payload/provider dumps in traces:** keep explanation surfaces limited to durable sanitized facts.
- **Creating a second parallel dispatch pipeline for digests:** reuse normal delivery execution.

## Suggested Plan Split

### Plan 20-01
Lock and implement the durable emission contract:
- schema/migration changes for membership resolution facts,
- bucket flush claim fields,
- explicit source-row digest outcome contract,
- RED/GREEN tests for emitted digest identity and idempotent bucket claim.

### Plan 20-02
Implement runtime emission and dispatch reuse:
- `Chimeway.Digests.Emission`,
- optional due-bucket runner / worker,
- canonical emitted digest event/notification/delivery creation,
- source-row convergence and duplicate-execution safety.

### Plan 20-03
Extend operator explainability:
- source-row digest reasoning in `Chimeway.Traces`,
- emitted digest explanation surface listing included/excluded rows,
- integration tests proving exact reasons and sanitized output.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Retry safety for flush | worker uniqueness only | row lock + claimed/emitted DB state | Worker uniqueness is advisory; the DB must arbitrate correctness. |
| Digest explainability | separate debug log store | `Traces` + durable delivery/membership facts | The repo already treats the lifecycle spine as the operator truth. |
| Source outcome modeling | pending rows plus inference | explicit source-row convergence helper and durable resolution fields | Later analytics and traces should not reconstruct intent from absence. |
| Digest provider execution | digest-only performer path | existing sync/Oban delivery dispatch | Reuse preserves attempts, retries, and lifecycle continuity. |

## RESEARCH COMPLETE
