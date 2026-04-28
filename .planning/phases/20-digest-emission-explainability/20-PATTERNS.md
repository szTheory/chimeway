# Phase 20: Digest Emission & Explainability - Pattern Map

**Mapped:** 2026-04-28
**Files analyzed:** 14
**Analogs found:** 14 / 14

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/chimeway/digests/emission.ex` | service | event-driven | `lib/chimeway/digests/accumulation.ex` | role+flow |
| `lib/chimeway/digests/digest_membership.ex` | model | lifecycle | `lib/chimeway/digests/digest_membership.ex` | exact |
| `lib/chimeway/digests/digest_bucket.ex` | model | lifecycle | `lib/chimeway/digests/digest_bucket.ex` | exact |
| `lib/chimeway/delivery.ex` | model | lifecycle | `lib/chimeway/delivery.ex` | exact |
| `lib/chimeway/deliveries.ex` | service | lifecycle | `lib/chimeway/deliveries.ex` | exact |
| `lib/chimeway/dispatch/digest_flush_worker.ex` | worker | async | `lib/chimeway/dispatch/deferred_resume_worker.ex` | role+flow |
| `lib/chimeway/dispatch/oban.ex` | dispatcher | async | `lib/chimeway/dispatch/oban.ex` | exact |
| `lib/chimeway/dispatch/oban_worker.ex` | worker | async | `lib/chimeway/dispatch/oban_worker.ex` | exact |
| `lib/chimeway/traces.ex` | query/explainability | operator | `lib/chimeway/traces.ex` | exact |
| `lib/chimeway/traces/explanation.ex` | contract | operator | `lib/chimeway/traces/explanation.ex` | exact |
| `priv/repo/migrations/*_alter_chimeway_digest_memberships_for_resolution.exs` | migration | lifecycle | `priv/repo/migrations/20260428102200_create_chimeway_digest_memberships.exs` | role-match |
| `priv/repo/migrations/*_alter_chimeway_digest_buckets_for_emission.exs` | migration | lifecycle | `priv/repo/migrations/20260428102100_create_chimeway_digest_buckets.exs` | role-match |
| `test/chimeway/digests/emission_test.exs` | test | event-driven | `test/chimeway/digests/accumulation_test.exs` | role+flow |
| `test/chimeway/orchestration/digest_explainability_test.exs` | test | operator | `test/chimeway/orchestration/traces_deferral_test.exs` | role+flow |

## Pattern Assignments

### `lib/chimeway/digests/emission.ex` (service, event-driven)

**Analog:** `lib/chimeway/digests/accumulation.ex`

Copy forward:
- `Repo.transact/1` as the top-level correctness boundary.
- `SELECT ... FOR UPDATE` locking on the canonical row being advanced.
- explicit `:noop` return shapes for already-converged rows.
- bulk data loading and deterministic branching inside one transaction.

Phase 20 difference:
- lock the digest bucket rather than one source delivery,
- operate over a set of unresolved memberships,
- create an emitted digest delivery row and resolve many source rows in one pass.

### `lib/chimeway/deliveries.ex` (service, lifecycle helpers)

**Analog:** `lib/chimeway/deliveries.ex`

Copy forward:
- named lifecycle helpers for meaningful convergences (`resume_deferred_delivery/2`, `cancel_deferred_delivery/3`, `exhaust_delivery/1`),
- direct update helpers when the generic transition table is not expressive enough,
- metadata limited to sanitized operator-facing facts.

Phase 20 should add named helpers rather than inline `change/2` calls scattered through emission code.

### `lib/chimeway/dispatch/digest_flush_worker.ex` (worker, async)

**Analog:** `lib/chimeway/dispatch/deferred_resume_worker.ex`

Copy forward:
- tiny job args carrying only durable IDs,
- due-time or explicit execution semantics outside the business-truth tables,
- no queue payloads containing source notification details.

Phase 20 worker should claim a bucket or emitted digest by ID only, then defer all business decisions to durable DB reads.

### `lib/chimeway/dispatch/oban.ex` + `lib/chimeway/dispatch/oban_worker.ex`

**Analog:** current files

Copy forward:
- dispatch only `status: :pending` + `orchestration_state: :ready`,
- job enqueue inside the same transaction when possible,
- worker-side short-circuit for non-ready or terminal rows,
- no provider calls until after durable planning state is committed.

Phase 20 should reuse these exact patterns for the emitted digest delivery instead of introducing a digest-specific dispatch execution layer.

### `lib/chimeway/traces.ex` + `lib/chimeway/traces/explanation.ex`

**Analog:** current files

Copy forward:
- explanation structs as stable operator-facing contracts,
- sanitized `planning_context`,
- timeline built from durable row state rather than support-only logs,
- additive extension of operator fields instead of API replacement.

Phase 20 likely needs:
- source-row digest resolution fields,
- emitted digest explanation helpers that summarize included/excluded members,
- timeline events for digest emission or digest convergence.

### `test/chimeway/digests/emission_test.exs` (test, event-driven)

**Analog:** `test/chimeway/digests/accumulation_test.exs`

Copy forward:
- deterministic time fixtures,
- explicit bucket/membership assertions,
- retry and duplicate-call tests as first-class contract tests,
- database-level proof of idempotency.

Phase 20 should add failure-path tests for duplicate bucket execution, partial completion retries, and emitted digest reuse.

### `test/chimeway/orchestration/digest_explainability_test.exs` (test, operator)

**Analog:** `test/chimeway/orchestration/traces_deferral_test.exs`

Copy forward:
- assert sanitized explanation fields,
- assert exact timeline event names,
- assert no payload/provider leakage,
- distinguish planning holds from final lifecycle convergence.

Phase 20 should test:
- included vs skipped vs immediate-send source explanations,
- emitted digest explanation contents,
- linkage from source rows to emitted digest delivery.

## Reusable Code Cues

| Target | Reuse | Why |
|--------|-------|-----|
| bucket claim + idempotent flush | `Accumulation.accumulate_delivery/2` | same transaction/lock/idempotency posture |
| source-row convergence helper | deferred/cancel/exhaust helpers in `Deliveries` | same named-helper lifecycle idiom |
| emitted digest dispatch | `Dispatch.Oban.enqueue_delivery/1` + `ObanWorker.perform/1` posture | keeps queue state non-authoritative |
| operator reasoning surface | `Traces.explain_delivery/2` and `Traces.Explanation` | avoids parallel operator API |

## Coverage Table

| Area | Primary Analog | Status |
|------|----------------|--------|
| Durable batch claim | `lib/chimeway/digests/accumulation.ex` | covered |
| Canonical lifecycle convergence | `lib/chimeway/deliveries.ex` | covered |
| Async execution seam | `lib/chimeway/dispatch/oban.ex` / `oban_worker.ex` | covered |
| Operator explainability | `lib/chimeway/traces.ex` | covered |
| Retry/idempotency tests | `test/chimeway/digests/accumulation_test.exs` | covered |
| Sanitized reasoning tests | `test/chimeway/orchestration/traces_deferral_test.exs` | covered |
