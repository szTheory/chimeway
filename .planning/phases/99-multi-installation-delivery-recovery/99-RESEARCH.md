# Phase 99: Multi-Installation Delivery & Recovery - Research

**Researched:** 2026-08-19  
**Domain:** Durable, tenant-safe push target fan-out and recovery in Elixir/Ecto/PostgreSQL  
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

### Opaque Target Model and Logical Outcome

- **D-01:** Keep one canonical logical push delivery per notification and channel. Fan-out is represented by durable child targets beneath that delivery, not by one top-level delivery per installation.
- **D-02:** The public resolver returns every active eligible installation as an opaque, tenant-scoped binding revision. Chimeway persists one target per selected revision and never stores raw tokens, endpoints, credentials, or uncontrolled resolver payloads.
- **D-03:** Target identity is unique within the logical delivery. Repeated resolution or planning converges on the same target row for the same selected binding revision.
- **D-04:** No eligible targets suppresses the logical delivery with one stable explainable reason. After every target terminates, the logical delivery succeeds only when at least one target has provider acceptance; target-level terminal failures remain visible as partial-failure evidence and the aggregate must never claim all-device delivery.

### Target-Scoped Handoff Truth

- **D-05:** The child target is the independent state machine for claim, attempt-start, retry, expiry, invalidation, and provider outcome. The logical delivery aggregates target truth but does not replace it.
- **D-06:** Persist target claim and attempt-start evidence before provider I/O. Attempt history remains append-only and ordered so every possible provider request has a durable explanation.
- **D-07:** If execution stops after provider processing may have occurred but before a conclusive response is durably recorded, close the interrupted attempt with an explicit indeterminate/ambiguous handoff outcome. Do not silently treat it as an unsent failure or automatically resend it.
- **D-08:** Any later policy-authorized re-drive after an indeterminate handoff must create linked new attempt evidence and preserve the duplicate-risk explanation. It must never be presented as exactly-once delivery.
- **D-09:** Provider acceptance means observed provider handoff only. It never implies device receipt, display, app handling, protected open, inbox seen/read, or engagement.

### Tenant-Scoped Recovery and Idempotency

- **D-10:** Extend the existing recovery spine with an explicit tenant-scoped, bounded worker for stranded event planning and target work. Every discovery, claim, reload, mutation, and dispatch decision retains the resolved tenant predicate.
- **D-11:** Recovery claims are atomic and converge duplicate planning, execution, jobs, and recovery onto the existing target revision. Terminal, already-claimed, expired, invalidated, and otherwise ineligible targets short-circuit before provider I/O.
- **D-12:** Recovery evidence uses the Phase 98 safe-evidence vocabulary and records why work was claimed, skipped, resumed, or left indeterminate without exposing host-owned identity or endpoint data.

### the agent's Discretion

- Exact behaviour, callback, struct, table, and enum names, provided the public contract is data-first, tenant-explicit, opaque, and stable.
- Exact target lifecycle transition implementation, claim lease mechanics, worker batch size, and concurrency limits, provided work is bounded, atomically claimed, and executable evidence proves convergence under races.
- Exact aggregate recomputation mechanism and stable reason strings, provided no-target suppression, provider-acceptance semantics, partial failures, and indeterminate handoffs remain distinguishable.
- Exact migration sequencing and internal module boundaries, provided copied migrations remain deterministic in both supported static storage modes.

### Deferred Ideas (OUT OF SCOPE)

- APNs-specific status/reason mapping, stable `apns-id`, payload construction, expiry header, retry classification, and optional collapse behavior — Phase 100.
- CrossWake token registration, binding rotation/revocation, one-time protected opens, offline queueing, and authorization — Phase 101.
- Hermetic adopter twin and physical-iPhone evidence — Phases 102 and 103.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PUSH-01 | Public resolver returns active eligible opaque tenant-scoped binding revisions. | Define a data-only behaviour and strict normalized value object; reject raw/unrecognized fields before persistence. [VERIFIED: 99-CONTEXT.md] |
| PUSH-02 | One target per selected installation with independent lifecycle and trace history. | Add durable target + append-only target-attempt schemas beneath `Delivery`; preload/project only tenant-scoped target records. [VERIFIED: codebase grep] |
| PUSH-03 | Duplicate planning/execution/recovery creates neither duplicate targets nor unexplained provider requests. | Enforce a database unique index on `(delivery_id, binding_revision_ref)`, then use atomic target claims and pre-I/O attempt-start rows. [VERIFIED: 99-CONTEXT.md] [CITED: https://oban.hexdocs.pm/unique_jobs.html] |
| PUSH-04 | Stable no-target suppression and honest mixed-result aggregation. | Recompute parent only from terminal target rows; use `provider_accepted` language and retain partial/indeterminate target evidence. [VERIFIED: 99-CONTEXT.md] |
| RECOV-01 | Tenant-scoped bounded worker recovers stranded events. | Reuse the explicit `TenantScope` + conditional `update_all` recovery pattern; add bounded batches and target discovery. [VERIFIED: codebase grep] |
| RECOV-02 | Pre-I/O evidence and explicit ambiguous post-handoff crash outcome. | Persist claim and `attempt_started` before adapter I/O; recovery closes stale started attempts as `ambiguous_handoff` and does not resend automatically. [VERIFIED: 99-CONTEXT.md] |
</phase_requirements>

## Project Constraints (from AGENTS.md)

- Preserve stable `notification_key` plus version; never use module names as durable identity. [VERIFIED: AGENTS.md]
- Preserve the durable `event -> notification -> delivery -> attempt` spine, extending it with child targets rather than replacing the logical delivery. [VERIFIED: AGENTS.md] [VERIFIED: 99-CONTEXT.md]
- Treat idempotency and suppression reasons as first-class behavior. [VERIFIED: AGENTS.md]
- Keep adapter seams replaceable through explicit behaviours and contract tests; the host retains auth, tenancy, URL generation, and correlation IDs. [VERIFIED: AGENTS.md]
- Maintain `mix verify.*` and `mix ci.*` parity, avoid sensitive payloads in telemetry/operator surfaces, and use executable evidence for objectively machine-testable behavior. [VERIFIED: AGENTS.md]

## Summary

Phase 99 is a persistence and state-machine phase, not an APNs integration. Keep the existing unique logical `Delivery` row for `{notification_id, channel}` and model fan-out as a new `DeliveryTarget` child keyed by the opaque binding revision selected by the host resolver. Each target needs its own durable lifecycle and append-only attempt evidence; parent state is a derived aggregate that never overwrites target truth. [VERIFIED: codebase grep] [VERIFIED: 99-CONTEXT.md]

The critical ordering is: resolve an explicit tenant; normalize opaque revisions; insert targets idempotently; atomically claim one eligible target; persist a claim and an `attempt_started` record; only then invoke the provider seam. A recovery pass that finds a stale started attempt must record `ambiguous_handoff` because provider processing may already have happened. It must not map that state to “not sent” or quietly retry it. [VERIFIED: 99-CONTEXT.md]

Existing code already has suitable primitives: `DeliveryPlanning` is the mandatory planning seam; `Deliveries` uses tenant predicates and conditional `update_all` claims; `DeliveryAttempt` demonstrates append-only ordered attempts; `SafeEvidence` and `Traces` own closed evidence/projection vocabularies. Extend these patterns to targets and target attempts rather than introduce a second delivery pipeline. [VERIFIED: codebase grep]

**Primary recommendation:** Add a data-first target resolver, durable `DeliveryTarget`/`DeliveryTargetAttempt` tables with database uniqueness, atomic tenant-scoped claims, and an aggregate recomputation function; make target attempts—not Oban job uniqueness—the source of truth for possible provider handoff.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Eligibility and raw token/endpoint custody | Host application | API / Backend | The resolver decides eligibility and returns opaque revisions; Chimeway must never obtain raw target material. [VERIFIED: 99-CONTEXT.md] |
| Target normalization and lifecycle transitions | API / Backend | Database / Storage | The core validates public values, owns state transitions, and uses durable records as the concurrency boundary. [VERIFIED: codebase grep] |
| Target/attempt identity, claims, and histories | Database / Storage | API / Backend | Uniqueness, ordering, and conditional claims require durable database state rather than process/job memory. [CITED: https://oban.hexdocs.pm/unique_jobs.html] |
| Bounded recovery and asynchronous execution | API / Backend | Database / Storage | Worker code schedules bounded work, but queries and atomic mutations retain the tenant predicate. [VERIFIED: codebase grep] |
| Operator trace and aggregate outcome | API / Backend | Database / Storage | Core trace DTOs must show safe target evidence and an honest parent aggregate. [VERIFIED: codebase grep] |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Elixir | `~> 1.17` required; local Mix 1.19.5 / OTP 28 | Behaviours, structs, pure target transition functions. | The phase adds to the existing Elixir core; no new runtime library is needed. [VERIFIED: mix.exs] [VERIFIED: local runtime] |
| `ecto_sql` | locked `3.13.5`; latest registry `3.14.0` published 2026-05-19 | Migrations, unique indexes, transactions, locks, and conditional updates. | Existing delivery/attempt/recovery contracts already use Ecto. [VERIFIED: mix.lock] [VERIFIED: Hex registry] [VERIFIED: codebase grep] |
| PostgreSQL | local client 14.17; project requires 15+ | Database-enforced target uniqueness and atomic claim predicates. | The active lifecycle system uses PostgreSQL/Ecto persistence. [VERIFIED: AGENTS.md] [VERIFIED: local environment] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `oban` | locked `2.23.0`; latest registry `2.23.1` published 2026-08-03 | Optional bounded target/recovery scheduling and retry execution. | Rework job args/uniqueness to be target-aware after durable target persistence; do not treat a job as correctness evidence. [VERIFIED: mix.lock] [VERIFIED: Hex registry] [CITED: https://oban.hexdocs.pm/Oban.Worker.html] |
| Existing `Chimeway.SafeEvidence` | internal | Closed safe facts for persisted diagnostics, traces, telemetry, and proof. | Extend its allowlists for target identifiers, lifecycle facts, and unambiguous vocabulary. [VERIFIED: codebase grep] |
| Existing `Chimeway.Traces` | internal | Tenant-filtered explainability projection. | Preload targets/target attempts under tenant-filtered delivery queries and project a parent aggregate plus child facts. [VERIFIED: codebase grep] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| One child target per binding revision | One top-level delivery per installation | Rejected by locked D-01: it loses one logical decision/aggregate and breaks the parent spine. [VERIFIED: 99-CONTEXT.md] |
| Database unique target index plus conditional claim | Oban uniqueness only | Rejected: Oban documents that uniqueness applies to insertion, not execution concurrency, and its OSS approach can race. [CITED: https://oban.hexdocs.pm/unique_jobs.html] |
| Explicit `ambiguous_handoff` terminal attempt outcome | Auto-retry after worker crash | Rejected by D-07/D-08 because possible provider handoff carries duplicate risk. [VERIFIED: 99-CONTEXT.md] |

**Installation:** None. This phase uses already-installed project dependencies; do not add APNs/Pigeon/CrossWake dependencies before Phase 100/101. [VERIFIED: mix.exs] [VERIFIED: 99-CONTEXT.md]

## Architecture Patterns

### System Architecture Diagram

```text
Host notification + explicit tenant
  -> DeliveryPlanning plans canonical {notification, "push"} Delivery
  -> TargetResolver.resolve(notification, tenant)
       returns only opaque binding_revision_ref + safe selection facts
  -> normalize + stable sort + INSERT ... ON CONFLICT target identity
       one DeliveryTarget per {delivery_id, binding_revision_ref}
  -> no rows? parent Delivery -> suppressed("no_eligible_targets")
  -> target worker/recovery discovery (tenant predicate retained)
       -> atomic claim eligible target
       -> append claim + attempt_started evidence BEFORE I/O
       -> replaceable provider executor
            -> conclusive target attempt result
            -> target terminal/retry state
            -> recompute parent aggregate

Stale attempt_started during recovery
  -> append/close as ambiguous_handoff
  -> target becomes terminal/explicitly policy-gated for a linked re-drive
  -> recompute parent aggregate; never automatic resend
```

### Recommended Project Structure

```text
lib/chimeway/
├── delivery_target.ex                 # schema + target state/validation
├── delivery_target_attempt.ex         # append-only claim/start/outcome evidence
├── target_resolver.ex                 # public behaviour and opaque revision normalization
├── deliveries.ex                      # parent planning, target inserts, aggregate/recovery APIs
├── delivery_planning.ex               # resolver fan-out through the mandatory planner seam
├── dispatch/executor.ex               # split pre-I/O target attempt start from result recording
├── dispatch/oban_worker.ex            # target-id job path and terminal short-circuit
├── dispatch/recovery_worker.ex        # bounded tenant-scoped event/target recovery
├── traces.ex                          # parent plus target safe projection
└── safe_evidence.ex                   # target-safe facts/timeline vocabulary
priv/chimeway_migrations/
└── 035_create_chimeway_delivery_targets.exs  # copied, prefix-aware template(s)
test/chimeway/
├── delivery_target_test.exs
├── dispatch/target_worker_test.exs
├── orchestration/target_recovery_test.exs
├── traces_target_test.exs
└── migration_contract_test.exs
```

### Pattern 1: Data-first opaque resolver boundary

**What:** Define a behaviour whose callback receives the explicit tenant and notification context and returns `{:ok, [binding_revision]}` or a stable error. A binding revision is a closed struct/map with an opaque revision reference and only allowlisted, non-sensitive selection facts. Reject raw tokens, endpoint URLs, credentials, uncontrolled nested data, and an unscoped result. [VERIFIED: 99-CONTEXT.md]

**When to use:** Once for each canonical push delivery planning operation; retry/recovery may re-resolve but must converge through the target unique key. [VERIFIED: 99-CONTEXT.md]

```elixir
# Source: locked D-02/D-03; names are planner discretion
@callback resolve(opaque_notification_context(), tenant_id :: String.t()) ::
  {:ok, [BindingRevision.t()]} | {:error, :resolution_failed}

def normalize_revision(%{binding_revision_ref: ref} = value, tenant_id) do
  with {:ok, ref} <- SafeEvidence.opaque_ref(:binding_revision, ref),
       ^tenant_id <- Map.get(value, :tenant_id) do
    {:ok, %{binding_revision_ref: ref}}
  else
    _ -> {:error, :invalid_target_resolution}
  end
end
```

The exact `SafeEvidence` domain extension is discretionary, but it must remain closed and opaque. [VERIFIED: 99-CONTEXT.md]

### Pattern 2: Database identity before jobs

**What:** In the same planning transaction, insert child rows with an explicit unique index on `delivery_id, binding_revision_ref` and reload the authoritative target rows. Use `on_conflict: :nothing` plus the unique index for convergence; never infer uniqueness from transient resolver iteration or a job’s `conflict?` flag. [VERIFIED: codebase grep] [CITED: https://oban.hexdocs.pm/unique_jobs.html]

```elixir
# Source: existing Deliveries.plan_delivery/3 conflict/reload pattern
Repo.insert(target_changeset,
  on_conflict: :nothing,
  conflict_target: [:delivery_id, :binding_revision_ref]
)

# Always reload by delivery_id + opaque revision; conflict inserts return no authority.
Repo.get_by!(DeliveryTarget,
  delivery_id: delivery.id,
  binding_revision_ref: revision_ref,
  tenant_id: tenant_id
)
```

### Pattern 3: Lease/claim and pre-I/O append-only evidence

**What:** An atomic update must move only an eligible target to a claimed state, bound to its tenant, target id, nonterminal status, and expired/missing lease condition. The successful claimant inserts a claim record and `attempt_started` record before the provider call. The target attempt ordinal is assigned under a target row lock, mirroring the existing delivery attempt transaction. [VERIFIED: codebase grep] [VERIFIED: 99-CONTEXT.md]

```elixir
# Source: existing Deliveries.begin_recovery/2 + record_attempt/2 patterns
from(t in DeliveryTarget,
  where: t.id == ^target_id and t.tenant_id == ^tenant_id and
    t.status in ^[:pending, :retryable] and
    (is_nil(t.claimed_until) or t.claimed_until < ^now),
  update: [set: [status: :claimed, claimed_at: ^now, claimed_until: ^lease_until]]
)
|> Repo.update_all([])

# Only after the conditional update returned {1, _}:
# transactionally insert claim evidence and `attempt_started`, then invoke provider I/O.
```

### Pattern 4: Parent aggregate is derived, not inferred from a last attempt

**What:** Recompute under a parent/target lock after every target terminal transition. Parent state remains nonterminal while a target is actionable. Once all targets are terminal: suppress only when no targets were ever selected; mark success only if one or more targets are `provider_accepted`; otherwise retain a terminal aggregate failure/cancellation. Include an explicit `partial_failure` aggregate fact when any accepted target coexists with a terminal target failure/expiry/invalidation/ambiguous outcome. [VERIFIED: 99-CONTEXT.md]

Use a stable no-target reason such as `no_eligible_targets` and a distinct target outcome vocabulary such as `provider_accepted`, `expired`, `invalidated`, `retry_exhausted`, and `ambiguous_handoff`; exact names are discretionary, but all states must be distinguishable. [VERIFIED: 99-CONTEXT.md]

### Anti-Patterns to Avoid

- **Passing token or endpoint material through job args, target metadata, traces, or telemetry:** Phase 98 forbids it; pass only Chimeway durable IDs and opaque refs. [VERIFIED: 98-CONTEXT.md] [VERIFIED: 99-CONTEXT.md]
- **Calling provider I/O after only a parent delivery transition:** It makes the individual possible handoff unexplainable and prevents safe recovery. [VERIFIED: 99-CONTEXT.md]
- **Using `provider_accepted` as device delivery:** Provider acceptance is only observed handoff, not receipt, display, protected open, or engagement. [VERIFIED: 99-CONTEXT.md]
- **Treating target failure as parent failure immediately:** Other targets may still succeed; aggregate only after all terminal states are known. [VERIFIED: 99-CONTEXT.md]
- **Using a release of an expired lease as permission to resend a started attempt:** A stale `attempt_started` is ambiguous, not known-unsent. [VERIFIED: 99-CONTEXT.md]
- **Filtering tenant only at resolver entry:** Retain tenant in all joins, target claim updates, reloads, preloads, and worker args. [VERIFIED: 97-CONTEXT.md] [VERIFIED: codebase grep]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Fan-out correctness | In-memory dedupe/set of resolver results | PostgreSQL unique index + `on_conflict` + reload | Survives concurrent planners, process crashes, and recovery. [VERIFIED: codebase grep] |
| Job-level exactly-once | Long unique-job periods | Target unique identity + atomic claims + attempt evidence | Oban uniqueness is insertion-oriented and does not control concurrent execution. [CITED: https://oban.hexdocs.pm/unique_jobs.html] |
| Target attempt ordering | Application-side counter | Locked target row and append-only target attempt table | Existing attempt history uses a lock/transaction for contiguous ordinal assignment. [VERIFIED: codebase grep] |
| Privacy filtering | Per-worker/manual field removal | Existing `SafeEvidence` and closed trace/telemetry constructors | A single Phase-98 vocabulary prevents sensitive resolver/provider data escaping. [VERIFIED: 98-CONTEXT.md] |
| Recovery scanner | Unbounded `Repo.all` loop | Existing tenant-scoped recovery API plus bounded keyset/batch worker | Keeps work predictable and tenant-safe. [VERIFIED: codebase grep] |

**Key insight:** A job answers “what work was scheduled”; a target attempt answers “what provider handoff may have happened.” The latter must be durable before I/O. [VERIFIED: 99-CONTEXT.md]

## Runtime State Inventory

| Category | Items Found | Action Required |
|----------|-------------|-----------------|
| Stored data | Existing delivery/attempt rows, new target/target-attempt rows, and copied migrations are durable state. [VERIFIED: codebase grep] | Code plus additive migrations; no raw binding material migration is permitted. |
| Live service config | Host resolver/provider configuration is external and host-owned; no provider-specific setup belongs in Phase 99. [VERIFIED: 99-CONTEXT.md] | Define the public resolver contract only; defer APNs configuration to Phase 100. |
| OS-registered state | None found in repository inspection. [VERIFIED: repository inspection] | None. |
| Secrets/env vars | Phase 99 must not add token/credential env names or store secret values. [VERIFIED: 99-CONTEXT.md] | None; resolver owns custody. |
| Build artifacts | Installer copies all templates and has public/prefixed migration tests. [VERIFIED: codebase grep] | Update templates, generated migration fixtures/goldens, contract tests, and both static runtime-prefix proofs. |

## Common Pitfalls

### Pitfall 1: Job uniqueness mistaken for a provider-call guarantee

**What goes wrong:** Concurrent jobs/processes can still execute target work, producing duplicate provider calls.  
**Why it happens:** Oban’s unique jobs prevent matching insertion but do not govern execution concurrency; its documentation warns the OSS mechanism can race. [CITED: https://oban.hexdocs.pm/unique_jobs.html]  
**How to avoid:** Unique target rows plus a conditional tenant-scoped claim and pre-I/O attempt state are mandatory; target worker uniqueness is only scheduling defense-in-depth. [VERIFIED: 99-CONTEXT.md]  
**Warning signs:** Tests assert only a single Oban row and never race two `claim_target` calls. [VERIFIED: codebase grep]

### Pitfall 2: Crash window erased as a generic failure

**What goes wrong:** A process dies after provider I/O and a generic retry sends again while reporting “exactly once.”  
**Why it happens:** Current `Executor.run_delivery/1` calls `adapter.deliver/1` before `Deliveries.record_attempt/2`, leaving a pre-I/O evidence gap. [VERIFIED: codebase grep]  
**How to avoid:** Make `attempt_started` durable before calling the adapter; recovery marks stale started attempts `ambiguous_handoff`, and any later re-drive links to it with duplicate-risk facts. [VERIFIED: 99-CONTEXT.md]  
**Warning signs:** The only persisted target attempt record appears after adapter return. [VERIFIED: codebase grep]

### Pitfall 3: Cross-tenant target visibility through joins/preloads

**What goes wrong:** An event is tenant-filtered but child targets or attempts from another tenant appear in trace/aggregate queries.  
**Why it happens:** Ecto association preloads and joins do not automatically express every tenant predicate. [VERIFIED: codebase grep]  
**How to avoid:** Carry the resolved tenant ID in all child query `where`/`on` clauses and require it for direct APIs and workers. [VERIFIED: 97-CONTEXT.md]  
**Warning signs:** A test creates the same opaque revision reference in two tenants and only asserts parent delivery isolation. [VERIFIED: 99-CONTEXT.md]

### Pitfall 4: Parent aggregation hides a partial result

**What goes wrong:** One accepted target turns the parent into generic “delivered”, hiding expiry, invalidation, or failure on another device.  
**Why it happens:** Aggregating from one “last attempt” rather than all target terminal states erases information. [VERIFIED: 99-CONTEXT.md]  
**How to avoid:** Persist all target terminal facts and project both aggregate `provider_accepted`/partial state and per-target histories. [VERIFIED: 99-CONTEXT.md]  
**Warning signs:** A two-target mixed-result test checks only parent `:succeeded`. [VERIFIED: 99-CONTEXT.md]

## Code Examples

### Target-aware Oban job is a scheduling hint, not an authorization to send

```elixir
# Source: existing Oban worker pattern + official unique-job documentation
use Oban.Worker,
  queue: :chimeway_delivery,
  max_attempts: 5,
  unique: [fields: [:args], keys: [:delivery_target_id], period: 60]

def perform(%Oban.Job{args: %{"delivery_target_id" => id, "tenant_id" => tenant_id}}) do
  case Deliveries.claim_target(id, tenant_id: tenant_id, source: "oban") do
    {:ok, target} -> Dispatch.Executor.run_target(target)
    {:noop, _target} -> :ok
  end
end
```

The planner must ensure `run_target/1` writes the target claim/start before I/O and that `claim_target/2` is the only gate. Oban documents that `{:error, reason}` drives retries within the worker’s configured budget. [CITED: https://oban.hexdocs.pm/Oban.Worker.html]

### Aggregate recomputation shape

```elixir
# Source: locked D-04/D-05; exact names discretionary
def aggregate_terminal_targets(targets) do
  accepted? = Enum.any?(targets, &(&1.status == :provider_accepted))
  all_terminal? = Enum.all?(targets, &terminal_target?/1)
  partial? = accepted? and Enum.any?(targets, &(&1.status != :provider_accepted))

  cond do
    not all_terminal? -> %{status: :dispatched, partial_failure: false}
    accepted? -> %{status: :succeeded, provider_accepted: true, partial_failure: partial?}
    true -> %{status: :failed, provider_accepted: false, partial_failure: false}
  end
end
```

Do not emit a bare `delivered` field from this function. [VERIFIED: 99-CONTEXT.md]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| One delivery row and append-only delivery attempts per channel | One logical delivery plus child target rows and target-scoped attempt history | Phase 99 | Supports multi-installation truth without multiplying logical notification decisions. [VERIFIED: 99-CONTEXT.md] |
| Delivery-level pre/post adapter outcome recording | Target `attempt_started` before I/O and explicit ambiguous recovery closeout | Phase 99 | Makes the provider handoff crash window explainable without false exactly-once claims. [VERIFIED: 99-CONTEXT.md] |
| Delivery-ID Oban uniqueness | Target-aware worker args plus durable claim gate | Phase 99 | Job dedupe becomes supplemental; database state establishes actual request eligibility. [CITED: https://oban.hexdocs.pm/unique_jobs.html] |

**Deprecated/outdated:** Treating `DeliveryAttempt.outcome == :succeeded` as a universal “delivery” result is unsuitable for push fan-out. Phase 99 must use explicit provider-handoff terminology and target-level facts. [VERIFIED: 99-CONTEXT.md]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | A target-level terminal status set can be represented with Ecto enums/strings without changing a public stable contract. | Architecture Patterns | Low: names are explicitly discretionary, but migration/API names need design review. [ASSUMED] |
| A2 | Target claims will use a timestamp lease such as `claimed_until` rather than a separate claim table as the exclusive concurrency primitive. | Pattern 3 | Medium: D-05 permits either mechanics; planner must choose one that preserves append-only evidence. [ASSUMED] |

## Open Questions (RESOLVED)

1. **Which target attempts are terminal after `ambiguous_handoff`? — RESOLVED**
   - **Selected contract:** `ambiguous_handoff` is an explicit terminal, non-actionable target outcome. It is never eligible for automatic resend. A later policy-authorized re-drive creates a new numbered attempt linked to the ambiguous predecessor and records duplicate-risk evidence; it does not reopen, rewrite, or hide the terminal predecessor. [VERIFIED: D-07/D-08 in 99-CONTEXT.md]

2. **How should generic provider execution receive host-owned target material? — RESOLVED**
   - **Selected contract:** the Phase 99 provider boundary accepts only the durable target ID, the opaque binding revision reference, and closed safe context admitted by `SafeEvidence`. It never accepts raw token, endpoint, credential, provider-body, or uncontrolled host payload material. Host-owned material lookup and APNs-specific request construction remain Phase 100 responsibilities. [VERIFIED: D-02/D-09 and Deferred Ideas in 99-CONTEXT.md]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Elixir/Mix | schemas, migrations, tests | ✓ | Mix 1.19.5 / OTP 28 | — [VERIFIED: local environment] |
| PostgreSQL client/service | Ecto race, recovery, and migration tests | ✓ | client 14.17; local port accepts connections | Project/CI PostgreSQL 15+ remains required. [VERIFIED: local environment] [VERIFIED: AGENTS.md] |
| Oban | optional async target/recovery worker tests | ✓ | locked 2.23.0 | Sync target execution must retain same durable claim path. [VERIFIED: mix.lock] |
| Docker | isolated service tooling if needed | ✓ | 29.5.2 | Existing test DB service is available. [VERIFIED: local environment] |

**Missing dependencies with no fallback:** None identified. [VERIFIED: local environment]

**Missing dependencies with fallback:** None identified. [VERIFIED: local environment]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit + Ecto SQL sandbox; Oban test support where configured. [VERIFIED: codebase grep] |
| Config file | `test/test_helper.exs`, `test/support/data_case.ex`, and `config/test.exs`. [VERIFIED: codebase grep] |
| Quick run command | `MIX_ENV=test mix test test/chimeway/delivery_target_test.exs test/chimeway/orchestration/target_recovery_test.exs --warnings-as-errors` [ASSUMED] |
| Full suite command | `mix ci.test` [VERIFIED: mix.exs] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PUSH-01 | Resolver rejects unscoped/raw/uncontrolled input and accepts only opaque tenant-scoped revisions. | unit/integration | `MIX_ENV=test mix test test/chimeway/delivery_target_test.exs --warnings-as-errors` | ❌ Wave 0 [ASSUMED] |
| PUSH-02 | Two selected revisions create two targets, isolated attempts/lifecycle, and safe traces. | integration | `MIX_ENV=test mix test test/chimeway/delivery_target_test.exs test/chimeway/traces_target_test.exs --warnings-as-errors` | ❌ Wave 0 [ASSUMED] |
| PUSH-03 | Planner/job/recovery races converge on one target and one started attempt per actual claim. | integration/concurrency | `MIX_ENV=test mix test test/chimeway/orchestration/target_recovery_test.exs --warnings-as-errors` | ❌ Wave 0 [ASSUMED] |
| PUSH-04 | No-target suppression and mixed accepted/failed aggregation remain distinct and truthful. | integration | `MIX_ENV=test mix test test/chimeway/delivery_target_test.exs test/chimeway/traces_target_test.exs --warnings-as-errors` | ❌ Wave 0 [ASSUMED] |
| RECOV-01 | Tenant-scoped bounded event/target recovery claims only qualifying rows and records safe evidence. | integration | `MIX_ENV=test mix test test/chimeway/orchestration/target_recovery_test.exs --warnings-as-errors` | ❌ Wave 0 [ASSUMED] |
| RECOV-02 | Started-before-I/O crash becomes ambiguous and cannot auto-resend; authorized re-drive links risk. | integration/fault injection | `MIX_ENV=test mix test test/chimeway/dispatch/target_worker_test.exs --warnings-as-errors` | ❌ Wave 0 [ASSUMED] |

### Sampling Rate

- **Per task commit:** focused ExUnit command for edited target/recovery/trace/migration files. [VERIFIED: AGENTS.md]
- **Per wave merge:** `mix ci.test` plus `mix verify.install_golden` and `mix verify.runtime_prefix` when copied migration/runtime behavior changes. [VERIFIED: mix.exs]
- **Phase gate:** full executable suite green; all concurrency/recovery assertions are `type="auto"`, not conversational UAT. [VERIFIED: AGENTS.md]

### Wave 0 Gaps

- [ ] `test/chimeway/delivery_target_test.exs` — resolver normalization, unique target rows, state transitions, no-target/mixed aggregate. [ASSUMED]
- [ ] `test/chimeway/dispatch/target_worker_test.exs` — claim/start-before-I/O and crash-window fault injection. [ASSUMED]
- [ ] `test/chimeway/orchestration/target_recovery_test.exs` — bounded tenant recovery and concurrent claims. [ASSUMED]
- [ ] `test/chimeway/traces_target_test.exs` — target histories and safe target trace DTO projection. [ASSUMED]
- [ ] Extend existing migration/prefix/golden suites for every copied template in both static storage modes. [VERIFIED: codebase grep]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Host owns authentication; Phase 99 consumes only explicit host-scoped inputs. [VERIFIED: AGENTS.md] |
| V3 Session Management | no | CrossWake session/open rules are Phase 101. [VERIFIED: 99-CONTEXT.md] |
| V4 Access Control | yes | Explicit tenant resolution and tenant predicate on every child query/mutation/worker action. [VERIFIED: 97-CONTEXT.md] |
| V5 Input Validation | yes | Closed resolver value object, `SafeEvidence` allowlists, and no uncontrolled nested resolver/provider fields. [VERIFIED: 98-CONTEXT.md] |
| V6 Cryptography | no | Chimeway must not take custody of raw tokens/credentials; no custom cryptography belongs in this phase. [VERIFIED: 99-CONTEXT.md] |

### Known Threat Patterns for the stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Cross-tenant target read/claim/recovery | Information disclosure / Elevation of privilege | Resolve tenant before discovery and repeat it in joins, `update_all`, reloads, and trace preloads; non-disclosing noop on mismatch. [VERIFIED: 97-CONTEXT.md] |
| Duplicate provider handoff under races/crash | Tampering / Repudiation | Database unique identity, atomic claim, append-only pre-I/O attempt record, and explicit ambiguous closeout. [VERIFIED: 99-CONTEXT.md] |
| Token/endpoint/identity leakage | Information disclosure | Opaque resolver refs only and Phase-98 safe evidence at all persistence/diagnostic edges. [VERIFIED: 98-CONTEXT.md] |
| False receipt/engagement claim | Repudiation | Restrict this phase’s affirmative provider outcome to `provider_accepted`; preserve distinct later phases/states. [VERIFIED: 99-CONTEXT.md] |

## Sources

### Primary (HIGH confidence)

- `99-CONTEXT.md` — locked target, handoff, aggregate, recovery, and privacy decisions. [VERIFIED: 99-CONTEXT.md]
- `lib/chimeway/{deliveries,delivery_planning,traces,safe_evidence}.ex` and dispatch modules — existing persistence, scoped recovery, attempt, trace, and safe-evidence seams. [VERIFIED: codebase grep]
- `mix.exs`, `mix.lock`, and local availability probes — dependency/runtime facts. [VERIFIED: mix.exs] [VERIFIED: mix.lock] [VERIFIED: local environment]

### Secondary (MEDIUM confidence)

- [Oban unique jobs guide](https://oban.hexdocs.pm/unique_jobs.html) — uniqueness is insertion-time, distinct from concurrency, and OSS uniqueness can race. [CITED: https://oban.hexdocs.pm/unique_jobs.html]
- [Oban worker docs](https://oban.hexdocs.pm/Oban.Worker.html) — worker retry/max-attempt and unique job options. [CITED: https://oban.hexdocs.pm/Oban.Worker.html]

### Tertiary (LOW confidence)

- None beyond the explicitly recorded assumptions. [VERIFIED: research log]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — exact locked versions and local registry/runtime checks; no new package decision. [VERIFIED: mix.lock] [VERIFIED: Hex registry]
- Architecture: HIGH — locked phase decisions map directly to existing planning, attempt, recovery, trace, and privacy seams. [VERIFIED: 99-CONTEXT.md] [VERIFIED: codebase grep]
- Pitfalls: HIGH — crash window and tenant/recovery risks are explicit locked requirements; job-uniqueness limits are official Oban guidance. [VERIFIED: 99-CONTEXT.md] [CITED: https://oban.hexdocs.pm/unique_jobs.html]

**Research date:** 2026-08-19  
**Valid until:** 2026-09-18 (stable internal architecture; recheck locked dependency versions before implementation).
