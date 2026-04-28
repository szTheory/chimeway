# Phase 20: Digest Emission & Explainability - Research

**Researched:** 2026-04-28
**Domain:** Digest emission, canonical delivery reuse, and operator explainability in Chimeway
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
### Digest Emission Lifecycle
- **D-01:** Phase 20 should emit each digest flush as its own canonical `chimeway_deliveries` row,
  then hand that row to the existing sync/Oban dispatch lifecycle instead of introducing a
  digest-only execution pipeline.
- **D-02:** Bucket flush work should stay limited to durable bucket claim, member resolution,
  digest-delivery creation, and canonical enqueue/dispatch handoff; provider calls, attempt
  history, retries, and final delivery convergence belong on the emitted digest delivery row.
- **D-03:** Oban remains an optional execution seam, not the source of truth. All facts required to
  reproduce or explain a digest send must persist in Chimeway tables before queue handoff.

### Membership Resolution Facts
- **D-04:** `digest_memberships` must gain durable per-member resolution facts rather than relying on
  indirect derivation. Each membership should persist a terminal resolution such as included,
  skipped, or emitted_immediately plus a machine-readable `resolution_reason`, `resolved_at`, and
  `digest_delivery_id` when included in an emitted digest.
- **D-05:** Membership resolution facts must snapshot the exact rule/window identity used at flush
  time so later rule edits, policy changes, or bucket mutations cannot rewrite history.
- **D-06:** Digest emission must be idempotent at the database layer by combining bucket/member
  claiming, membership resolution writes, digest-delivery creation, and enqueue/dispatch handoff in
  one transaction. Queue uniqueness may reduce duplicate work, but it cannot be the correctness
  boundary.

### Explainability Surface
- **D-07:** Operator explainability should stay under `Chimeway.Traces` as the primary entrypoint.
  Phase 20 may add digest-specific trace functions and structs, but it should not introduce a
  separate top-level operator API.
- **D-08:** Source delivery explanations must answer "why did this source notification join digest D,
  skip digest D, or send immediately instead?" Emitted digest explanations must answer "which source
  deliveries were included, under which rule/window, and what was excluded or deferred?"
- **D-09:** Explainability data must be durable and sanitized. Do not solve digest explanation by
  dumping raw event payloads, rendered content, or provider responses into `planning_context` or
  metadata blobs.

### Source Delivery Convergence
- **D-10:** Source `:digest_held` rows must converge in place after flush; they must not remain
  indefinitely `status == :pending`.
- **D-11:** Included source rows should land on an explicit digest terminal outcome on the existing
  canonical row, with lightweight linkage back to the emitted digest delivery rather than pretending
  the source row itself was sent.
- **D-12:** Skipped-at-flush or immediate-send outcomes must also converge durably on the canonical
  source row with explicit reasons so later traces, reconciliation, and Phase 22 analytics can
  distinguish "digested", "sent immediately", "skipped by policy", and "still waiting for a future
  flush" without secondary inference.

### Developer Experience and Least Surprise
- **D-13:** The design should optimize for one obvious operator story and one obvious developer story:
  delivery rows remain the lifecycle spine, digest memberships explain membership decisions, and
  `Chimeway.Traces` remains the place to ask "why did this happen?"
- **D-14:** Preview/inspection helpers for digest behavior should feel more like Discourse/GitHub
  reasoning surfaces than a hosted workflow debugger: concrete reasons, clear included/excluded
  lists, and stable durable identifiers.
- **D-15:** Planning and implementation should avoid Ecto N+1 flush paths. Bucket/member resolution
  must preload or join the source notification/event facts needed for policy rechecks and operator
  explanations rather than `Repo.get!` looping per membership.

### the agent's Discretion
- Exact schema/module names for emitted digest delivery linkage and membership resolution enums.
- Whether digest-specific operator queries live as new `Traces.*` functions or adjacent structs
  under the same namespace, as long as `Chimeway.Traces` remains the primary entrypoint.
- Whether the explicit source-row terminal outcome is represented as a new delivery status such as
  `:digested` or an equivalent durable terminal shape, provided dispatcher guards, traces, and
  future analytics all treat it coherently.

### Deferred Ideas (OUT OF SCOPE)
- Full workflow-debugger or hosted-style visual orchestration UX.
- Rich template preview/rendering contracts beyond digest explainability needs; those belong to Phase
  21.
- Broader aggregate outcome dashboards and reconciliation tooling; those belong to Phase 22.
- Multi-stage or nested digest workflows and advanced SaaS-style batching policies.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DIGEST-02 | Digest generation is idempotent and records which source events and notifications were included in each digest delivery. [VERIFIED: .planning/REQUIREMENTS.md] | Bucket claim plus digest artifact creation, membership resolution, source-row convergence, and dispatch handoff must occur in one DB transaction, with explicit membership snapshots and emitted digest linkage. [VERIFIED: .planning/phases/20-digest-emission-explainability/20-CONTEXT.md] [VERIFIED: lib/chimeway/delivery.ex] |
| DIGEST-03 | Operators can explain why a notification was included in a digest, skipped from a digest, or emitted immediately instead. [VERIFIED: .planning/REQUIREMENTS.md] | Extend `Chimeway.Traces` with source-delivery and emitted-digest explanation queries backed by durable membership resolution facts and sanitized delivery metadata. [VERIFIED: .planning/phases/20-digest-emission-explainability/20-CONTEXT.md] [VERIFIED: lib/chimeway/traces.ex] |
</phase_requirements>

## Project Constraints (from AGENTS.md)

- Chimeway is local-first, so digest state, memberships, source linkage, and explainability facts must remain host-owned data in the application database. [VERIFIED: AGENTS.md] [VERIFIED: .planning/PROJECT.md]
- Persist stable `notification_key` plus version as durable identity and never depend on module names for history. [VERIFIED: AGENTS.md] [VERIFIED: .planning/PROJECT.md]
- Keep the lifecycle spine `event -> notification -> delivery -> attempt`; Phase 20 should extend that spine rather than bypass it. [VERIFIED: AGENTS.md] [VERIFIED: .planning/PROJECT.md]
- Idempotency and suppression reasons are first-class behavior, so digest emission and source-row convergence need named helpers and explicit reasons instead of implicit queue behavior. [VERIFIED: AGENTS.md] [VERIFIED: lib/chimeway/deliveries.ex]
- Adapter seams stay replaceable and contract-testable, so digest emission should reuse the existing dispatch lifecycle instead of embedding provider behavior in digest code. [VERIFIED: AGENTS.md] [VERIFIED: .planning/phases/20-digest-emission-explainability/20-CONTEXT.md]
- Operator and telemetry surfaces must not leak sensitive payload fields; digest explanations must stay sanitized. [VERIFIED: AGENTS.md] [VERIFIED: lib/chimeway/traces.ex] [VERIFIED: test/chimeway/orchestration/traces_deferral_test.exs]
- Maintain `mix verify.*` and `mix ci.*` parity and keep new behavior covered by executable tests. [VERIFIED: AGENTS.md] [VERIFIED: mix.exs]

## Summary

Phase 20 should treat a digest flush as a new durable notification lifecycle, not as a mutation-only side channel. A canonical digest delivery row already implies a parent notification, and a notification already implies a parent event, so the least-surprise design is to create a synthetic digest `event -> notification -> delivery` chain whose durable identity comes from the matched digest rule's `rule_key` and `rule_version`. That preserves Chimeway's stable-key posture and gives the emitted digest its own attempt history, retries, and final convergence without corrupting source delivery history. [VERIFIED: lib/chimeway/delivery.ex] [VERIFIED: lib/chimeway/notifications/notification.ex] [VERIFIED: lib/chimeway/events/event.ex] [VERIFIED: AGENTS.md]

The correctness boundary belongs in Postgres, not in Oban. Emission should lock one due bucket, preload its unresolved memberships with source notification and event rows, re-run the final policy gate for each source delivery, write a durable per-membership resolution, converge the source delivery row in place, create the emitted digest event/notification/delivery chain, and enqueue or execute that emitted delivery through the normal dispatch path in the same transaction. That matches the phase context, the current transactional enqueue posture, and the existing row-centric delivery helpers. [VERIFIED: .planning/phases/20-digest-emission-explainability/20-CONTEXT.md] [VERIFIED: lib/chimeway/dispatch/oban.ex] [VERIFIED: lib/chimeway/deliveries.ex] [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html] [CITED: https://www.postgresql.org/docs/current/static/sql-insert.html]

Explainability should remain centered on `Chimeway.Traces`. The source-delivery question is "why was this row included, skipped, or emitted immediately?" and the emitted-digest question is "which source rows were included, under which rule/window, and what was excluded?" Current traces already sanitize planning context and derive timelines from durable rows, so Phase 20 should add digest-aware trace queries and timeline events rather than introduce a second operator API or free-form metadata blobs. [VERIFIED: .planning/phases/20-digest-emission-explainability/20-CONTEXT.md] [VERIFIED: lib/chimeway/traces.ex] [VERIFIED: lib/chimeway/traces/explanation.ex]

**Primary recommendation:** Emit each flushed digest as a new synthetic digest `event -> notification -> delivery` chain keyed by `rule_key` plus `rule_version`, resolve memberships and source-row outcomes in one transaction, and expose all inclusion/exclusion reasoning through `Chimeway.Traces`. [VERIFIED: AGENTS.md] [VERIFIED: .planning/phases/20-digest-emission-explainability/20-CONTEXT.md]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Due-bucket selection and claim | API / Backend | Database / Storage | Bucket due-ness and single-emitter correctness depend on row locks and transactional state, not client or queue behavior. [VERIFIED: lib/chimeway/digests/digest_bucket.ex] [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html] |
| Membership resolution at flush time | API / Backend | Database / Storage | Resolution needs policy rechecks plus durable writes to memberships and source deliveries. [VERIFIED: .planning/phases/20-digest-emission-explainability/20-CONTEXT.md] [VERIFIED: lib/chimeway/deliveries.ex] |
| Emitted digest identity and lifecycle creation | API / Backend | Database / Storage | A delivery requires a notification and a notification requires an event, so the backend owns creation of the synthetic lifecycle chain. [VERIFIED: lib/chimeway/delivery.ex] [VERIFIED: lib/chimeway/notifications/notification.ex] [VERIFIED: lib/chimeway/events/event.ex] |
| Queue handoff for emitted digest delivery | API / Backend | — | Oban is an optional seam; the backend decides whether to enqueue a worker or run sync dispatch for the already-created ready delivery. [VERIFIED: .planning/phases/20-digest-emission-explainability/20-CONTEXT.md] [VERIFIED: lib/chimeway/dispatch/oban.ex] [VERIFIED: lib/chimeway/dispatch/sync.ex] |
| Source delivery convergence | API / Backend | Database / Storage | Source rows must land on explicit durable outcomes on the canonical delivery row for future analytics and traces. [VERIFIED: .planning/phases/20-digest-emission-explainability/20-CONTEXT.md] [VERIFIED: lib/chimeway/deliveries.ex] |
| Operator explanation queries | API / Backend | Database / Storage | `Chimeway.Traces` already owns the query surface and timeline projection over persisted rows. [VERIFIED: lib/chimeway/traces.ex] |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `ecto` | `3.13.5` locked; `3.13.5` current. [VERIFIED: mix deps] [VERIFIED: mix hex.info ecto] | Transaction orchestration, row locking, and structured preload/query composition for digest emission. [VERIFIED: lib/chimeway/delivery_planning.ex] | Chimeway already uses Ecto as the canonical persistence boundary, and current docs prefer `Repo.transact/1` while keeping `Ecto.Multi` for dynamic operation sets. [VERIFIED: lib/chimeway/digests/accumulation.ex] [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html] [CITED: https://hexdocs.pm/ecto/Ecto.Multi.html] |
| `ecto_sql` | `3.13.5` locked; `3.13.5` current. [VERIFIED: mix deps] [VERIFIED: mix hex.info ecto_sql] | SQL-backed migrations and upsert support for bucket claim and emitted digest linkage. [VERIFIED: mix.exs] | The phase needs DB-enforced idempotency, unique indexes, and migrations rather than queue-only dedupe. [VERIFIED: .planning/phases/20-digest-emission-explainability/20-CONTEXT.md] [CITED: https://hexdocs.pm/ecto/constraints-and-upserts.html] |
| PostgreSQL | Local server available on `5432`; project target is `15+`. [VERIFIED: pg_isready] [VERIFIED: AGENTS.md] | Atomic conflict handling, row locks, and durable claim semantics for digest emission. [VERIFIED: lib/chimeway/digests/accumulation.ex] | `INSERT ... ON CONFLICT` plus transactional locking is the right correctness layer for idempotent flushes. [CITED: https://www.postgresql.org/docs/current/static/sql-insert.html] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `oban` | `2.21.1` locked; `2.22.0` current. [VERIFIED: mix deps] [VERIFIED: mix hex.info oban] | Optional async handoff for due-bucket flush workers and emitted digest delivery workers. [VERIFIED: mix.lock] [VERIFIED: lib/chimeway/dispatch/oban.ex] | Use for durable scheduling and background execution, but keep queue records non-authoritative. [VERIFIED: .planning/phases/20-digest-emission-explainability/20-CONTEXT.md] [CITED: https://hexdocs.pm/oban/Oban.Worker.html] [CITED: https://hexdocs.pm/oban/unique_jobs.html] |
| `tzdata` | `1.1.3` locked and current. [VERIFIED: mix deps] [VERIFIED: mix hex.info tzdata] | Existing rule window calculations for boundary windows. [VERIFIED: lib/chimeway/digests/accumulation.ex] | Reuse when deciding whether a bucket is due by its persisted boundary window. [VERIFIED: lib/chimeway/digests/accumulation.ex] |
| `phoenix` | Not a direct dependency here; `1.8.5` is current in the ecosystem. [VERIFIED: mix hex.info phoenix] | Optional host integration only. [VERIFIED: AGENTS.md] | Phase 20 stays backend-only and must not depend on Phoenix-specific runtime features. [VERIFIED: AGENTS.md] [VERIFIED: .planning/PROJECT.md] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Synthetic digest `event -> notification -> delivery` chain keyed by digest rule identity. [VERIFIED: lib/chimeway/delivery.ex] [VERIFIED: lib/chimeway/notifications/notification.ex] [VERIFIED: lib/chimeway/events/event.ex] | Delivery-only digest row with membership metadata blobs. [ASSUMED] | Delivery-only emission breaks the existing lifecycle spine and makes attempt history, trace joins, and notification ownership irregular. [VERIFIED: AGENTS.md] [VERIFIED: .planning/PROJECT.md] |
| Explicit source delivery terminal outcome such as `:digested`. [VERIFIED: .planning/phases/20-digest-emission-explainability/20-CONTEXT.md] | Leave source rows `:pending` and infer final state from memberships later. [ASSUMED] | Inference conflicts with the requirement to explain and analyze outcomes directly from canonical rows. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .planning/phases/20-digest-emission-explainability/20-CONTEXT.md] |
| Bucket claim and emission transaction with row locks plus unique indexes. [VERIFIED: lib/chimeway/digests/accumulation.ex] | Oban uniqueness as the main anti-duplication control. [ASSUMED] | Oban documents uniqueness as non-constraint-based and therefore race-prone under some conditions. [CITED: https://hexdocs.pm/oban/unique_jobs.html] |

**Installation:** No new Hex dependency is required for Phase 20. Reuse the existing Ecto, PostgreSQL, and optional Oban stack already locked in the project. [VERIFIED: mix.exs] [VERIFIED: mix.lock]

**Version verification:** `mix deps` confirms `ecto 3.13.5`, `ecto_sql 3.13.5`, `postgrex 0.22.0`, `oban 2.21.1`, and `tzdata 1.1.3` in the current lockfile. `mix hex.info` confirms current releases `ecto 3.13.5`, `ecto_sql 3.13.5`, `oban 2.22.0`, `tzdata 1.1.3`, and `phoenix 1.8.5` as of 2026-04-28. [VERIFIED: mix deps] [VERIFIED: mix hex.info ecto] [VERIFIED: mix hex.info ecto_sql] [VERIFIED: mix hex.info oban] [VERIFIED: mix hex.info tzdata] [VERIFIED: mix hex.info phoenix]

## Architecture Patterns

### System Architecture Diagram

```text
Digest-held source deliveries accumulate into bucket
            |
            v
Find due bucket (window_ends_at <= now, not yet emitted)
            |
            v
Repo.transact/1
  |
  +--> lock bucket + preload unresolved memberships + source notification/event rows
  |
  +--> re-run final policy gate for each source delivery
  |      |
  |      +--> include -> mark membership included + converge source row to :digested
  |      +--> emit immediately -> mark membership emitted_immediately + source row to :ready
  |      +--> skip -> mark membership skipped + source row to terminal suppress/cancel state
  |
  +--> create synthetic digest event (rule_key/rule_version identity)
  +--> create digest notification for recipient
  +--> create digest delivery row with orchestration_state :ready
  +--> persist digest_delivery_id on included memberships + bucket emitted linkage
  +--> enqueue or sync-dispatch emitted digest delivery through canonical dispatch seam
            |
            v
Existing dispatch lifecycle
delivery -> attempt(s) -> terminal emitted digest outcome
            |
            v
Chimeway.Traces
  - source delivery explanation
  - emitted digest explanation
```

The key design choice is that digest emission adds a new lifecycle chain and converges existing source rows in place, instead of asking one row to be both the source notification and the emitted digest. That matches the existing schema relationships and the phase context's "canonical row" posture. [VERIFIED: lib/chimeway/delivery.ex] [VERIFIED: lib/chimeway/notifications/notification.ex] [VERIFIED: .planning/phases/20-digest-emission-explainability/20-CONTEXT.md]

### Recommended Project Structure

```text
lib/chimeway/digests/
├── accumulation.ex          # existing Phase 19 bucket/member accumulation
├── emission.ex              # due-bucket claim, preload, transaction, digest artifact creation
├── source_resolution.ex     # pure resolution decisions + source-row convergence helpers
├── digest_bucket.ex         # add emitted/claimed linkage fields
└── digest_membership.ex     # add durable resolution fields and resolution snapshots

lib/chimeway/dispatch/
├── digest_flush_worker.ex   # optional due-bucket scheduler/worker
├── oban.ex                  # helper to enqueue an already-planned ready delivery
└── sync.ex                  # helper to execute an already-planned ready delivery

lib/chimeway/
├── deliveries.ex            # add named helpers for :digested and digest source linkage updates
└── traces.ex                # add source and emitted digest explanation queries

test/chimeway/digests/
├── emission_test.exs
├── source_resolution_test.exs
└── flush_idempotency_test.exs

test/chimeway/orchestration/
└── digest_dispatch_test.exs

test/chimeway/
└── traces_digest_test.exs
```

This structure naturally decomposes into three execution plans: persistence plus source convergence, emission and dispatch handoff, and trace/explainability coverage. It also keeps the phase localized to digest, dispatch, and trace seams already present in the repo. [VERIFIED: lib/chimeway] [VERIFIED: test/chimeway] [VERIFIED: .planning/ROADMAP.md]

### Pattern 1: Create a Synthetic Digest Lifecycle Instead of a Delivery-Only Record
**What:** Create a new digest event and notification before the emitted digest delivery so the digest has a full canonical lifecycle of its own. [VERIFIED: lib/chimeway/delivery.ex] [VERIFIED: lib/chimeway/notifications/notification.ex] [VERIFIED: lib/chimeway/events/event.ex]
**When to use:** On every successful bucket flush that has at least one included membership. [VERIFIED: .planning/phases/20-digest-emission-explainability/20-CONTEXT.md]
**Example:**
```elixir
# Source: https://hexdocs.pm/ecto/Ecto.Repo.html
MyRepo.transact(fn repo ->
  digest_event = repo.insert!(event_changeset)
  digest_notification = repo.insert!(notification_changeset(digest_event))
  digest_delivery = repo.insert!(delivery_changeset(digest_notification))
  {:ok, digest_delivery}
end)
```

### Pattern 2: Use Dynamic Transaction Composition for Per-Membership Resolution
**What:** Build emission as a transaction that can merge per-membership operations dynamically after the preload step. [CITED: https://hexdocs.pm/ecto/Ecto.Multi.html]
**When to use:** When the flush path must branch per membership into included, skipped, or immediate-emission outcomes. [VERIFIED: .planning/phases/20-digest-emission-explainability/20-CONTEXT.md]
**Example:**
```elixir
# Source: https://hexdocs.pm/ecto/Ecto.Multi.html
Ecto.Multi.new()
|> Ecto.Multi.run(:bucket, fn repo, _changes -> {:ok, repo.one!(bucket_query)} end)
|> Ecto.Multi.merge(fn %{bucket: bucket} -> resolve_memberships_multi(bucket) end)
|> MyApp.Repo.transact()
```

### Pattern 3: Reuse the Existing Dispatch Lifecycle Through an Already-Planned Delivery Handoff
**What:** Add a small dispatch seam for a ready delivery row created by digest emission rather than routing emitted digests back through planning. [VERIFIED: lib/chimeway/dispatch/sync.ex] [VERIFIED: lib/chimeway/dispatch/oban.ex]
**When to use:** After the digest delivery row already exists and the bucket emission transaction needs canonical dispatch or enqueue behavior. [VERIFIED: .planning/phases/20-digest-emission-explainability/20-CONTEXT.md]
**Example:**
```elixir
# Source: https://hexdocs.pm/oban/Oban.Worker.html
%{delivery_id: delivery.id}
|> Chimeway.Dispatch.ObanWorker.new(unique: [fields: [:args], keys: [:delivery_id], period: 60])
|> Oban.insert()
```

### Pattern 4: Keep Source Delivery Convergence on Named Helpers, Not Ad-Hoc `Repo.update_all`
**What:** Introduce named `Deliveries` helpers for digest convergence the same way deferred resume and retry exhaustion already use named helpers. [VERIFIED: lib/chimeway/deliveries.ex]
**When to use:** When marking a source delivery as `:digested`, restoring it to `:ready` for immediate emission, or suppressing it during the flush-time policy gate. [VERIFIED: .planning/phases/20-digest-emission-explainability/20-CONTEXT.md]
**Example:**
```elixir
# Source: https://hexdocs.pm/ecto/Ecto.Repo.html
MyRepo.transact(fn _repo ->
  {:ok, digested} = Deliveries.mark_digested(source_delivery, digest_delivery_id: digest_delivery.id)
  {:ok, digested}
end)
```

### Anti-Patterns to Avoid
- **Digest-only execution pipeline:** It duplicates attempt, retry, and terminal-state logic that already lives in the existing dispatch path. [VERIFIED: .planning/phases/20-digest-emission-explainability/20-CONTEXT.md] [VERIFIED: lib/chimeway/dispatch/oban_worker.ex]
- **Replanning emitted digests through `DeliveryPlanning.plan_notification/2`:** That path is designed for source notifications and currently re-enters digest accumulation for `:digest_held` rows. Emitted digests need a direct ready-delivery handoff instead. [VERIFIED: lib/chimeway/delivery_planning.ex]
- **Leaving source rows pending after flush:** That hides final behavior from traces and future analytics and violates the explicit source convergence decision. [VERIFIED: .planning/phases/20-digest-emission-explainability/20-CONTEXT.md]
- **Using `planning_context` or `metadata` as a generic digest audit log:** Current traces intentionally sanitize those fields; Phase 20 needs explicit schema fields and joins. [VERIFIED: lib/chimeway/traces.ex] [VERIFIED: test/chimeway/orchestration/traces_deferral_test.exs]
- **Per-membership `Repo.get!` loops during flush:** Phase context explicitly forbids N+1 resolution paths. [VERIFIED: .planning/phases/20-digest-emission-explainability/20-CONTEXT.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Digest flush dedupe | Queue-only uniqueness or ETS lock registries. [ASSUMED] | Postgres row lock plus unique indexes and one transaction boundary. [VERIFIED: lib/chimeway/digests/accumulation.ex] [CITED: https://www.postgresql.org/docs/current/static/sql-insert.html] | The DB is the only authoritative place where bucket emission, membership resolution, and digest-delivery creation can succeed or fail together. [VERIFIED: .planning/phases/20-digest-emission-explainability/20-CONTEXT.md] |
| Source outcome inference | Reconstructing source outcomes later from bucket joins and delivery status guesses. [ASSUMED] | Explicit source-row convergence plus durable membership resolution columns. [VERIFIED: .planning/phases/20-digest-emission-explainability/20-CONTEXT.md] | Future traces and analytics need direct durable facts, not inference code. [VERIFIED: .planning/REQUIREMENTS.md] |
| Trace debugging side channel | New top-level digest operator API or raw JSON dumps. [ASSUMED] | `Chimeway.Traces` extensions and dedicated structs backed by sanitized fields. [VERIFIED: .planning/phases/20-digest-emission-explainability/20-CONTEXT.md] [VERIFIED: lib/chimeway/traces.ex] | The project's operator story is already row-centric and sanitized. [VERIFIED: .planning/PROJECT.md] [VERIFIED: test/chimeway/orchestration/traces_deferral_test.exs] |

**Key insight:** The hard part of Phase 20 is not producing a batch of digest content. It is preserving one durable, explainable story across three identities at once: the source delivery row, the membership resolution row, and the emitted digest lifecycle chain. The design should make those identities explicit instead of collapsing them into one record or one job. [VERIFIED: .planning/phases/20-digest-emission-explainability/20-CONTEXT.md] [VERIFIED: AGENTS.md]

## Common Pitfalls

### Pitfall 1: Emitting a digest delivery without a real event and notification parent
**What goes wrong:** The emitted digest has attempt history but no durable notification/event identity, which breaks the project's lifecycle spine and makes trace joins irregular. [VERIFIED: AGENTS.md] [VERIFIED: lib/chimeway/delivery.ex] [VERIFIED: lib/chimeway/notifications/notification.ex]
**Why it happens:** The phase goal says "digest delivery", and it is easy to stop at the delivery row without following the schema chain. [VERIFIED: .planning/ROADMAP.md]
**How to avoid:** Create a synthetic digest event and notification keyed by digest rule identity before creating the emitted digest delivery. [VERIFIED: lib/chimeway/events/event.ex] [VERIFIED: AGENTS.md]
**Warning signs:** New code inserts directly into `chimeway_deliveries` for digests without inserting a notification and event first. [VERIFIED: lib/chimeway/delivery.ex] [VERIFIED: lib/chimeway/notifications/notification.ex]

### Pitfall 2: Reusing the planning pipeline for emitted digests
**What goes wrong:** The emitted digest can accidentally re-enter accumulation logic or inherit planning paths intended for source notifications. [VERIFIED: lib/chimeway/delivery_planning.ex]
**Why it happens:** The current dispatch entrypoints plan notifications before dispatching them. [VERIFIED: lib/chimeway/dispatch/sync.ex] [VERIFIED: lib/chimeway/dispatch/oban.ex]
**How to avoid:** Add a minimal "dispatch already-planned ready delivery" seam in the dispatch layer and keep emitted digest creation separate from planning. [VERIFIED: lib/chimeway/dispatch/sync.ex] [VERIFIED: lib/chimeway/dispatch/oban_worker.ex]
**Warning signs:** Emission code calls `DeliveryPlanning.plan_notification/2` or `Dispatch.dispatch/2` with a synthetic notification and relies on it not to re-digest. [VERIFIED: lib/chimeway/delivery_planning.ex]

### Pitfall 3: Recording only bucket-level success and not per-membership resolution
**What goes wrong:** Operators can answer "the bucket emitted" but not "why this source row joined, skipped, or emitted immediately." [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .planning/phases/20-digest-emission-explainability/20-CONTEXT.md]
**Why it happens:** Phase 19 memberships currently stop at bucket linkage and source delivery linkage. [VERIFIED: lib/chimeway/digests/digest_membership.ex]
**How to avoid:** Add resolution enum, reason, resolved timestamp, emitted digest linkage, and resolved rule/window snapshot columns to `digest_memberships`. [VERIFIED: .planning/phases/20-digest-emission-explainability/20-CONTEXT.md]
**Warning signs:** Trace code needs to infer inclusion or exclusion by joining current bucket state and current source delivery status. [VERIFIED: lib/chimeway/traces.ex]

### Pitfall 4: Forgetting source delivery convergence
**What goes wrong:** Source rows remain `status: :pending` and `orchestration_state: :digest_held` after the bucket flush, which makes later analytics and traces ambiguous. [VERIFIED: .planning/phases/20-digest-emission-explainability/20-CONTEXT.md]
**Why it happens:** Accumulation intentionally left held rows unchanged in Phase 19, so emission code can miss the need to finish the story on the source row. [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md] [VERIFIED: test/chimeway/orchestration/dispatch_gating_test.exs]
**How to avoid:** Add an explicit source-row terminal outcome for included memberships and explicit durable outcomes for skipped or immediate-emission resolutions. [VERIFIED: .planning/phases/20-digest-emission-explainability/20-CONTEXT.md]
**Warning signs:** Emission tests pass while source delivery traces still show a pending digest-held row after flush. [VERIFIED: lib/chimeway/traces.ex]

### Pitfall 5: Letting raw payload or provider data leak into digest explainability
**What goes wrong:** Trace and operator surfaces expose sensitive fields or become opaque JSON blobs. [VERIFIED: AGENTS.md] [VERIFIED: test/chimeway/orchestration/traces_deferral_test.exs]
**Why it happens:** It is tempting to store "everything needed to explain the digest" inside `planning_context` or `metadata`. [VERIFIED: lib/chimeway/traces.ex]
**How to avoid:** Persist only stable rule, grouping, window, linkage, and resolution facts on digest schemas, and keep rendered payload or provider details out of trace-facing fields. [VERIFIED: .planning/phases/20-digest-emission-explainability/20-CONTEXT.md]
**Warning signs:** New schemas or metadata maps include payload snapshots, rendered content, or provider responses. [VERIFIED: lib/chimeway/traces.ex]

### Pitfall 6: N+1 membership resolution
**What goes wrong:** A flush of a large bucket runs one query per membership for event, notification, or policy context. [VERIFIED: .planning/phases/20-digest-emission-explainability/20-CONTEXT.md]
**Why it happens:** Current Phase 19 helpers fetch notification and event context by delivery during accumulation, and that pattern does not scale to emission-time fan-in. [VERIFIED: lib/chimeway/delivery_planning.ex] [VERIFIED: lib/chimeway/digests/accumulation.ex]
**How to avoid:** Preload or join all unresolved memberships and source rows before resolution, then resolve in memory inside one transaction. [VERIFIED: .planning/phases/20-digest-emission-explainability/20-CONTEXT.md] [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html]
**Warning signs:** Flush code loops over memberships and calls `Repo.get!` for each delivery, notification, or event. [VERIFIED: lib/chimeway/delivery_planning.ex]

## Code Examples

Verified patterns from official sources:

### Transaction boundary for digest emission
```elixir
# Source: https://hexdocs.pm/ecto/Ecto.Repo.html
MyRepo.transact(fn repo ->
  digest_event = repo.insert!(event_changeset)
  digest_notification = repo.insert!(notification_changeset(digest_event))
  digest_delivery = repo.insert!(delivery_changeset(digest_notification))
  {:ok, digest_delivery}
end)
```

### Dynamic multi composition for per-membership work
```elixir
# Source: https://hexdocs.pm/ecto/Ecto.Multi.html
multi =
  Ecto.Multi.new()
  |> Ecto.Multi.insert(:post, %Post{title: "first"})

multi
|> Ecto.Multi.merge(fn %{post: post} ->
  Ecto.Multi.new()
  |> Ecto.Multi.insert(:comment, Ecto.build_assoc(post, :comments))
end)
|> MyApp.Repo.transact()
```

### Upsert on a unique target
```elixir
# Source: https://hexdocs.pm/ecto/constraints-and-upserts.html
Repo.insert!(
  %MyApp.Tag{name: name},
  on_conflict: [set: [name: name]],
  conflict_target: :name
)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `Repo.transaction/2` as the preferred Ecto transaction API. [ASSUMED] | Current Ecto docs document `transaction/2` as deprecated in favor of `Repo.transact/2`. [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html] | Present in Ecto `3.13.5` docs. [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html] | New digest emission helpers should prefer `transact/1` and only use `Ecto.Multi` where dynamic composition is clearer. [CITED: https://hexdocs.pm/ecto/Ecto.Multi.html] |
| Queue-layer uniqueness treated as hard correctness. [ASSUMED] | Oban docs still describe uniqueness as non-constraint-based and prone to race conditions in some cases. [CITED: https://hexdocs.pm/oban/unique_jobs.html] | Present in Oban `2.21.1` docs. [CITED: https://hexdocs.pm/oban/unique_jobs.html] | Digest emission must keep correctness in DB rows and use Oban uniqueness only as hygiene. [VERIFIED: .planning/phases/20-digest-emission-explainability/20-CONTEXT.md] |
| Anonymous join tables for pure many-to-many links. [CITED: https://hexdocs.pm/ecto/Ecto.Schema.html] | Current Ecto docs recommend a join schema when the relationship needs fields or timestamps. [CITED: https://hexdocs.pm/ecto/Ecto.Schema.html] | Present in Ecto `3.13.5` docs. [CITED: https://hexdocs.pm/ecto/Ecto.Schema.html] | `digest_memberships` should become the durable explanation record, not remain a minimal join. [VERIFIED: lib/chimeway/digests/digest_membership.ex] [VERIFIED: .planning/phases/20-digest-emission-explainability/20-CONTEXT.md] |

**Deprecated/outdated:**
- Using `Repo.transaction/2` in new examples is outdated relative to the current Ecto docs. [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html]
- Treating `digest_memberships` as a pure link table is outdated for Phase 20 because the phase requires durable membership resolution facts. [VERIFIED: .planning/phases/20-digest-emission-explainability/20-CONTEXT.md] [VERIFIED: lib/chimeway/digests/digest_membership.ex]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | A distinct source-row status such as `:digested` is the cleanest representation of "included in a digest" on canonical source deliveries. [ASSUMED] | Summary / Architecture Patterns | Medium; if implementation chooses a different durable shape, plans must adjust traces, terminal-state guards, and analytics hooks together. |
| A2 | The best emitted digest identity is the digest rule's `rule_key` plus `rule_version` rather than introducing a second digest-specific durable key. [ASSUMED] | Summary / Common Pitfalls | Medium; if a later phase needs a separate namespace, event identity and policy integration may need a follow-up migration. |

## Open Questions

1. **Should the emitted digest event use the digest rule identity directly or a separate future digest template identity?**
   - What we know: The current project requires stable `notification_key` plus version identities, and Phase 20 explicitly defers template versioning to Phase 21. [VERIFIED: AGENTS.md] [VERIFIED: .planning/ROADMAP.md]
   - What's unclear: Whether Phase 21 template versioning will want a digest-specific render identity distinct from rule identity. [VERIFIED: .planning/ROADMAP.md]
   - Recommendation: Use `rule_key` plus `rule_version` in Phase 20 and keep the emitted digest payload minimal so Phase 21 can layer rendering identity without invalidating Phase 20 persistence. [ASSUMED]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | Mix tasks, tests, and implementation work. [VERIFIED: mix.exs] | ✓ [VERIFIED: `elixir --version`] | `1.19.5`. [VERIFIED: `elixir --version`] | — |
| Mix | Test and migration execution. [VERIFIED: mix.exs] | ✓ [VERIFIED: `mix --version`] | `1.19.5`. [VERIFIED: `mix --version`] | — |
| PostgreSQL server | Digest bucket claim, emission transaction, and integration tests. [VERIFIED: lib/chimeway/digests/accumulation.ex] | ✓ [VERIFIED: `pg_isready`] | Reachable on `5432`; project target remains PostgreSQL `15+`. [VERIFIED: `pg_isready`] [VERIFIED: AGENTS.md] | Validate against PostgreSQL `15+` before release if local dev remains on an older major. [ASSUMED] |
| Oban dependency | Optional async digest flush scheduling and emitted digest workers. [VERIFIED: AGENTS.md] | ✓ [VERIFIED: mix deps] | Locked `2.21.1`. [VERIFIED: mix deps] | Sync dispatch helper can execute emitted ready deliveries without Oban. [VERIFIED: lib/chimeway/dispatch/sync.ex] |

**Missing dependencies with no fallback:**
- None. [VERIFIED: mix deps] [VERIFIED: pg_isready]

**Missing dependencies with fallback:**
- None. [VERIFIED: mix deps]

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit via Mix, with Oban test helpers already in use where needed. [VERIFIED: test/chimeway/orchestration/dispatch_gating_test.exs] |
| Config file | none — project uses `mix test` without a separate test config file. [VERIFIED: mix.exs] |
| Quick run command | `mix test test/chimeway/digests/accumulation_test.exs test/chimeway/orchestration/dispatch_gating_test.exs test/chimeway/orchestration/traces_deferral_test.exs -x` [VERIFIED: test/chimeway/digests/accumulation_test.exs] [VERIFIED: test/chimeway/orchestration/dispatch_gating_test.exs] [VERIFIED: test/chimeway/orchestration/traces_deferral_test.exs] |
| Full suite command | `mix test` [VERIFIED: mix.exs] |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DIGEST-02 | One flush creates at most one emitted digest lifecycle and records included source memberships and linkage idempotently. [VERIFIED: .planning/REQUIREMENTS.md] | integration | `mix test test/chimeway/digests/emission_test.exs -x` | ❌ Wave 0 |
| DIGEST-02 | Duplicate flush execution converges source rows and does not create a second digest delivery or second membership resolution. [VERIFIED: .planning/REQUIREMENTS.md] | integration | `mix test test/chimeway/digests/flush_idempotency_test.exs -x` | ❌ Wave 0 |
| DIGEST-03 | Source delivery traces explain included, skipped, and immediate-emission outcomes from durable membership facts. [VERIFIED: .planning/REQUIREMENTS.md] | integration | `mix test test/chimeway/traces_digest_test.exs -x` | ❌ Wave 0 |
| DIGEST-03 | Dispatch guards still prevent digest-held source rows from dispatching before emission while allowing emitted ready digest deliveries to dispatch canonically. [VERIFIED: .planning/REQUIREMENTS.md] | regression | `mix test test/chimeway/orchestration/digest_dispatch_test.exs -x` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `mix test test/chimeway/digests/emission_test.exs test/chimeway/traces_digest_test.exs -x` once those files exist. [ASSUMED]
- **Per wave merge:** `mix test test/chimeway/digests/accumulation_test.exs test/chimeway/orchestration/dispatch_gating_test.exs test/chimeway/orchestration/traces_deferral_test.exs test/chimeway/digests/emission_test.exs test/chimeway/traces_digest_test.exs` [ASSUMED]
- **Phase gate:** `mix test` green before `/gsd-verify-work`. [VERIFIED: mix.exs]

### Wave 0 Gaps
- [ ] `test/chimeway/digests/emission_test.exs` — covers DIGEST-02 emitted digest chain creation and membership linkage.
- [ ] `test/chimeway/digests/flush_idempotency_test.exs` — covers duplicate execution, partial-failure rollback, and source-row convergence.
- [ ] `test/chimeway/orchestration/digest_dispatch_test.exs` — covers emitted ready delivery handoff vs held source row gating.
- [ ] `test/chimeway/traces_digest_test.exs` — covers source and emitted digest explanation surfaces under `Chimeway.Traces`.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Host application remains responsible. [VERIFIED: AGENTS.md] |
| V3 Session Management | no | Not part of digest emission scope. [VERIFIED: .planning/ROADMAP.md] |
| V4 Access Control | yes | Keep trace queries tenancy-aware and avoid cross-recipient or cross-tenant bucket joins without explicit filters. [VERIFIED: .planning/PROJECT.md] [VERIFIED: lib/chimeway/traces.ex] |
| V5 Input Validation | yes | Use schema changesets and enum validation on new membership resolution and bucket emission fields. [VERIFIED: lib/chimeway/delivery.ex] [VERIFIED: lib/chimeway/digests/digest_bucket.ex] [VERIFIED: lib/chimeway/digests/digest_membership.ex] |
| V6 Cryptography | no | No new crypto surface is introduced in this phase. [VERIFIED: .planning/ROADMAP.md] |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Duplicate bucket flush under concurrent workers | Tampering | Row lock the bucket, keep a single emitted digest linkage on the bucket, and persist resolution plus digest creation in one transaction. [VERIFIED: .planning/phases/20-digest-emission-explainability/20-CONTEXT.md] [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html] |
| Trace payload leakage through digest explanations | Information Disclosure | Expose only sanitized rule, window, and linkage facts through `Chimeway.Traces`; do not persist raw payload or provider responses in digest trace fields. [VERIFIED: AGENTS.md] [VERIFIED: lib/chimeway/traces.ex] |
| Source-row policy drift between accumulation and flush | Elevation of Privilege | Re-run the final policy gate at flush time before including a source row in the emitted digest. [VERIFIED: .planning/phases/20-digest-emission-explainability/20-CONTEXT.md] [VERIFIED: lib/chimeway/dispatch/sync.ex] [VERIFIED: lib/chimeway/dispatch/oban_worker.ex] |
| Cross-recipient or cross-channel membership contamination | Tampering | Keep bucket identity scoped by recipient, channel, grouping value, and window and preload members through that bucket boundary only. [VERIFIED: lib/chimeway/digests/digest_bucket.ex] [VERIFIED: .planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md] |

## Sources

### Primary (HIGH confidence)
- `AGENTS.md` - project posture, lifecycle spine, stable identity, local-first ownership, and sensitive-data constraints.
- `.planning/PROJECT.md` - milestone direction, explainability value, and product constraints.
- `.planning/REQUIREMENTS.md` - `DIGEST-02` and `DIGEST-03` requirement definitions.
- `.planning/ROADMAP.md` - Phase 20 success criteria and phase boundary.
- `.planning/STATE.md` - carried-forward orchestration and digest decisions through Phase 19.
- `.planning/phases/20-digest-emission-explainability/20-CONTEXT.md` - locked phase implementation decisions.
- `.planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md` - accumulation model and explicit Phase 20 handoff.
- `.planning/phases/19-digest-data-model-accumulation/19-RESEARCH.md` - established research style and Phase 19 standard stack direction.
- `lib/chimeway/delivery.ex` - current delivery statuses and orchestration states.
- `lib/chimeway/deliveries.ex` - terminal convergence patterns, named helpers, and attempt transaction behavior.
- `lib/chimeway/delivery_planning.ex` - digest-held planning and current accumulation hook.
- `lib/chimeway/digests/accumulation.ex` - current digest bucket and membership transaction pattern.
- `lib/chimeway/digests/digest_bucket.ex` - bucket identity fields and counters.
- `lib/chimeway/digests/digest_membership.ex` - current membership schema.
- `lib/chimeway/events/event.ex` - canonical event identity requirements.
- `lib/chimeway/notifications/notification.ex` - notification-to-event and delivery-to-notification relationships.
- `lib/chimeway/dispatch/sync.ex` - current planning-plus-sync dispatch path.
- `lib/chimeway/dispatch/oban.ex` - current planning-plus-enqueue dispatch path.
- `lib/chimeway/dispatch/oban_worker.ex` - ready-only worker behavior and queue uniqueness posture.
- `lib/chimeway/traces.ex` - trace query ownership and planning-context sanitization.
- `lib/chimeway/traces/explanation.ex` - explanation contract fields.
- `test/chimeway/digests/accumulation_test.exs` - accumulation invariants and window behavior.
- `test/chimeway/traces_test.exs` - current explanation contract expectations.
- `test/chimeway/orchestration/dispatch_gating_test.exs` - digest-held dispatch gating.
- `test/chimeway/orchestration/traces_deferral_test.exs` - sanitized trace expectations for held/deferred rows.
- `https://hexdocs.pm/ecto/Ecto.Repo.html` - current `Repo.transact/2` guidance and transaction API.
- `https://hexdocs.pm/ecto/Ecto.Multi.html` - dynamic transaction composition guidance.
- `https://hexdocs.pm/ecto/Ecto.Schema.html` - explicit join schema guidance.
- `https://hexdocs.pm/ecto/constraints-and-upserts.html` - upsert and conflict-target guidance.
- `https://hexdocs.pm/oban/Oban.Worker.html` - worker job options and runtime handoff semantics.
- `https://hexdocs.pm/oban/unique_jobs.html` - uniqueness limitations and race-condition caveat.
- `https://www.postgresql.org/docs/current/static/sql-insert.html` - `INSERT ... ON CONFLICT` semantics.

### Secondary (MEDIUM confidence)
- `mix deps` - locked dependency versions in the current project.
- `mix hex.info ecto`
- `mix hex.info ecto_sql`
- `mix hex.info oban`
- `mix hex.info tzdata`
- `mix hex.info phoenix`
- `elixir --version`
- `mix --version`
- `pg_isready`

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - no new dependency is required and the relevant Ecto/Oban/Postgres guidance was verified against current official docs and the current lockfile.
- Architecture: HIGH - the recommendation is tightly constrained by the current schema chain, the locked phase context, and existing dispatch/trace behavior in code.
- Pitfalls: HIGH - each listed pitfall maps directly to existing code paths, locked decisions, or official Ecto/Oban guidance.

**Research date:** 2026-04-28
**Valid until:** 2026-05-28

## RESEARCH COMPLETE
