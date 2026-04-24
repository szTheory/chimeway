# Phase 1 Research: Durable Core Spine

**Phase**: 1 - Durable Core Spine  
**Requirements**: CORE-01, CORE-02, CORE-03, CORE-04, INBX-01, INBX-02, INBX-03  
**Researched**: 2026-04-23  
**Status**: RESEARCH COMPLETE

<phase_research>

## Executive Summary

<executive_summary>
Phase 1 should ship a durable, explainable notification core that is explicitly modeled around stable notification identity, deterministic recipient resolution, transactional persistence, and explicit inbox lifecycle semantics. The implementation should stay in a single `chimeway` package for v0.1 speed, but preserve extraction seams for future `chimeway_admin` and adapter packages.

The critical architectural guardrails are already locked in context decisions: stable `notification_key` + version identity (never module names in durable storage), UUID primary keys, event-level idempotency uniqueness, and explicit `seen/read/archive` state transitions that never mutate implicitly on fetch. Deliveries/attempts persistence remains out of phase scope and must be deferred while keeping schema/API compatibility for Phase 2.

The fastest path to confidence is a test architecture that combines pure contract tests, SQL-backed transaction tests, migration/index assertions, and serial/concurrent idempotency checks. This phase should optimize for correctness and explainability over channel breadth.
</executive_summary>

## Scope and Lock Alignment

<scope_alignment>
### Locked decisions this phase must enforce

| Decision | Enforcement in Phase 1 |
|----------|-------------------------|
| D-01 / D-02 package topology | Implement in single `chimeway` package; keep namespace seams for future extraction. |
| D-03 / D-04 contract style | Require explicit behaviour callbacks; optional DSL is thin sugar over the same runtime contract. |
| D-05 / D-06 persistence boundary | Create `events` and `notifications` durable tables now; do not introduce `deliveries`/`attempts` tables in this phase. |
| D-07 stable identity | Persist `notification_key` + `notification_version` as durable type identity. |
| D-08 identifiers and idempotency | UUID PKs and unique event idempotency constraint from day one. |
| D-09 / D-10 inbox lifecycle | Store separate `seen_at`, `read_at`, `archived_at`; only explicit transition APIs mutate these fields. |

### Requirement-to-implementation mapping

| Requirement | Implementation anchor |
|-------------|-----------------------|
| CORE-01 | `Chimeway.Notifier` behaviour requires `notification_key/0` and `version/0`; persisted on event row. |
| CORE-02 | `trigger/3` requires explicit idempotency key input and validates non-empty value. |
| CORE-03 | `trigger/3` writes event row in DB transaction before any non-DB side effects. |
| CORE-04 | recipient resolver callback returns deterministic recipient set (sorted/normalized before write). |
| INBX-01 | per-recipient notification rows inserted from resolved recipients in same transaction. |
| INBX-02 | explicit APIs: `mark_seen/2`, `mark_read/2`, `archive/2` with monotonic lifecycle semantics. |
| INBX-03 | inbox query API supports unread filtering and newest-first ordering (`inserted_at DESC`). |
</scope_alignment>

## Standard Stack

<standard_stack>
Phase 1 should stay minimal and Elixir-native:

| Layer | Recommendation | Why for Phase 1 |
|------|----------------|-----------------|
| Runtime | Elixir 1.17+, OTP 26+ | Aligns with current Phoenix/Ecto ecosystem and project baseline. |
| Persistence | Ecto SQL + PostgreSQL | Required for durable rows, transactional fanout, and unique idempotency constraints. |
| Public contract | behaviour modules + plain structs | Keeps explainability and inspectability high; avoids hidden framework magic. |
| Optional ergonomics | thin DSL macros (optional) | Improves DX without replacing explicit behaviour path. |
| Validation | NimbleOptions (or equivalent explicit option validation) | Fails fast for malformed trigger inputs and notifier definitions. |
| Testing | ExUnit + Ecto SQL Sandbox + Mox | Fast deterministic tests for contracts and DB integration slices. |

Not recommended in this phase scope:
- Oban integration as a required path (Phase 3 concern).
- Swoosh/provider adapter breadth (Phase 2 concern).
- LiveView/admin operator UI surfaces (Phase 4/v2 concern).
</standard_stack>

## Architecture Patterns

<architecture_patterns>
### Pattern 1: Stable notifier contract with durable key identity

Use an explicit behaviour as the canonical contract. Persist key/version from the behaviour output; module names are runtime implementation details only.

### Pattern 2: Trigger pipeline is deterministic and side-effect ordered

`trigger/3` pipeline:
1. Validate notifier contract and input.
2. Resolve recipients deterministically.
3. Build event + notification records.
4. Persist via one `Ecto.Multi` transaction.
5. Return structured result (including duplicate idempotency outcome when applicable).

No external dispatch side effects are allowed in Phase 1 flow.

### Pattern 3: Event-first persistence

Event row is canonical root for explainability and dedupe. Notification rows always reference the event and represent per-recipient canonical inbox lifecycle.

### Pattern 4: Explicit lifecycle transitions

Treat `seen_at`, `read_at`, `archived_at` as independent timestamps with explicit APIs and monotonic invariants:
- `seen_at` may be set without setting `read_at`.
- `read_at` may imply user intent and can be set from explicit API only.
- `archived_at` is orthogonal to unread/read.

### Pattern 5: Explainability-by-data, not by logs

Every decision needed for "why did/didn't this happen?" should be derivable from durable rows plus deterministic code paths. Logs/telemetry are supporting signals, not source-of-truth substitutes.
</architecture_patterns>

## Data Model Recommendations

<data_model>
### `chimeway_events` (Phase 1 required)
- `id` UUID PK
- `notification_key` string, not null
- `notification_version` integer, not null
- `idempotency_key` string, not null (or nullable with strict API enforcement; preferred not null)
- `payload`/`params` map (redacted/minimal)
- timestamps
- unique index on idempotency scope (phase default can be global, or tenant-scoped if tenant column exists)

### `chimeway_notifications` (Phase 1 required)
- `id` UUID PK
- `event_id` UUID FK, not null
- recipient identity fields (stable and explicit)
- `seen_at`, `read_at`, `archived_at` nullable timestamps
- optional metadata map for inbox rendering references (avoid storing sensitive full payloads)
- timestamps
- unique index on `(event_id, recipient_identity)` to prevent duplicate recipient records
- index for inbox query path (`recipient_identity`, `read_at`, `inserted_at DESC`)

### Deferred by decision (D-06)
- `deliveries` and `attempts` tables are not created in Phase 1.
</data_model>

## Explainability Constraints

<explainability_constraints>
- Persist stable key/version and idempotency identifiers so historical records remain interpretable after refactors.
- Keep trigger result structs explicit (`:ok`, `:duplicate`, `{:error, reason}`) rather than hiding dedupe behavior.
- Avoid automatic lifecycle mutations on read APIs; only explicit transition calls change state.
- Prefer compact, structured metadata fields over opaque blobs to preserve queryability and reduce accidental PII capture.
- Keep recipient resolution deterministic and testable so support/debug paths can be reproduced.
</explainability_constraints>

## Don't Hand-Roll

<dont_hand_roll>
- Do not build a custom persistence framework; use `Ecto.Schema`, `Ecto.Changeset`, and `Ecto.Multi`.
- Do not invent custom UUID/dedupe algorithms; rely on DB uniqueness constraints as source-of-truth.
- Do not introduce macro-only notifier APIs with hidden runtime behavior; preserve plain behaviour + plain `trigger/3`.
- Do not implement implicit lifecycle state machines through query side effects.
- Do not add outbound provider logic in this phase; keep boundary clean for later adapter phases.
</dont_hand_roll>

## Common Pitfalls

<common_pitfalls>
1. **Module-name identity leakage**: persisting module names ties data durability to refactors. Persist stable keys only.
2. **Missing deterministic recipient ordering**: can create nondeterministic insert ordering and flaky tests; normalize recipient set before write.
3. **Idempotency only in application code**: race conditions still create duplicates; DB unique indexes must enforce correctness.
4. **Auto-read semantics in inbox fetch**: violates locked decision D-10 and makes fallback logic incorrect later.
5. **Overloaded notification payloads**: storing large, sensitive blobs harms explainability and operability; persist only what is needed for trace and rendering reference.
</common_pitfalls>

## Validation Architecture

<validation_architecture>
Fast feedback for Phase 1 should use layered test slices with clear runtime targets and strict mapping to CORE/INBX requirements.

### Slice A - Pure contract and pipeline tests (no DB, under 1s per file)
- Assert behaviour contract validation (`notification_key`, `version`, recipient resolver output shape).
- Assert trigger input validation rejects missing/blank idempotency keys.
- Assert deterministic recipient normalization (dedupe + stable ordering).
- Tag suggestion: `@moduletag :phase1_fast`.

### Slice B - Transactional persistence integration (SQL sandbox, under ~10s suite)
- `trigger/3` persists exactly one event row and N notification rows atomically.
- Failure in notification insertion rolls back event row (`Ecto.Multi` rollback integrity).
- No external side effects are required or asserted in this phase.
- Tag suggestion: `@moduletag :phase1_db`.

### Slice C - Migration/index checks (fast migration smoke)
- Run fresh migration on empty database and assert expected tables/columns/indexes exist.
- Validate unique idempotency index and recipient uniqueness index are present and enforced.
- Validate lifecycle columns (`seen_at`, `read_at`, `archived_at`) exist and remain nullable.
- Command loop suggestion for local iteration: `mix ecto.reset && mix test --only phase1_schema`.

### Slice D - Idempotency checks (serial + concurrent)
- Serial: same idempotency key called twice returns one canonical persisted event.
- Concurrent: parallel triggers with same idempotency key still produce one canonical event (others return duplicate outcome).
- Verify no duplicate notification rows for same `(event_id, recipient_identity)`.
- Tag suggestion: `@moduletag :phase1_idempotency`.

### Slice E - Inbox lifecycle and query semantics
- `mark_seen/2`, `mark_read/2`, `archive/2` update only their respective fields and keep transitions explicit.
- Inbox query supports unread filtering (`read_at IS NULL`) and newest-first ordering.
- Fetching inbox does not mutate lifecycle state.
- Tag suggestion: `@moduletag :phase1_inbox`.

### Requirement coverage matrix

| Requirement | Primary validation slice |
|-------------|--------------------------|
| CORE-01 | Slice A + B |
| CORE-02 | Slice A + D |
| CORE-03 | Slice B |
| CORE-04 | Slice A + B |
| INBX-01 | Slice B |
| INBX-02 | Slice E |
| INBX-03 | Slice E |
</validation_architecture>

## Code Examples

<code_examples>
```elixir
defmodule Chimeway.Notifier do
  @callback notification_key() :: String.t()
  @callback version() :: pos_integer()
  @callback recipients(map()) :: {:ok, [map()]} | {:error, term()}
end

def trigger(notifier, params, opts) do
  idempotency_key = Keyword.fetch!(opts, :idempotency_key)

  with :ok <- validate_notifier(notifier),
       {:ok, recipients} <- notifier.recipients(params) do
    recipients = recipients |> normalize_recipients()

    Ecto.Multi.new()
    |> insert_event(notifier, params, idempotency_key)
    |> insert_notifications(recipients)
    |> Repo.transaction()
    |> normalize_trigger_result()
  end
end
```

```elixir
def inbox_for(recipient_id, opts \\ []) do
  unread_only? = Keyword.get(opts, :unread_only, false)

  Notification
  |> where([n], n.recipient_id == ^recipient_id)
  |> maybe_unread_filter(unread_only?)
  |> order_by([n], desc: n.inserted_at)
  |> Repo.all()
end
```
</code_examples>

## Plan-Oriented Recommendations

<plan_recommendations>
### Plan 01-01 (contract + trigger pipeline)
- Implement behaviour-first notifier contract and plain `trigger/3` path first.
- If DSL is included, ensure it compiles to the same callbacks and keep tests against behaviour API.

### Plan 01-02 (migrations + schemas)
- Create only `events` and `notifications` schemas/migrations.
- Add idempotency and recipient uniqueness constraints immediately (not as follow-up cleanup).

### Plan 01-03 (inbox APIs + tests)
- Build explicit state transition APIs and query functions.
- Land Validation Architecture slices in same plan so behavior remains locked while API evolves.
</plan_recommendations>

## Confidence

<confidence>
| Area | Confidence | Notes |
|------|------------|-------|
| Phase 1 stack and architecture | HIGH | Uses mature Elixir/Ecto patterns and locked project decisions. |
| Idempotency strategy | HIGH | DB constraints + deterministic trigger path are standard and reliable. |
| Inbox lifecycle semantics | HIGH | Explicit timestamp model is clear and requirement-aligned. |
| Deferred boundaries (deliveries/attempts) | HIGH | Matches D-06 and roadmap phase boundaries. |
</confidence>

</phase_research>
