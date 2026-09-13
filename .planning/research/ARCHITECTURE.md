# Architecture Research

**Domain:** APNs-first, cross-platform mobile delivery for an embedded Elixir notification layer
**Researched:** 2026-08-11
**Confidence:** HIGH for the local integration shape; MEDIUM for physical-device operational proof

## Standard Architecture

### System Overview

```
┌──────────────────── Adopter Alpha host application ─────────────────────┐
│ Identity, eligibility, time zone, deep links, endpoint registry, APNs    │
│ raw tokens, APNs credentials and binding lifecycle                       │
│                                                                          │
│  Trigger ──► PushTargetResolver ──► APNs Gateway ──► APNs                │
│                  │                         │                             │
│                  └ opaque active endpoints ┴ provider result             │
└──────────────────────────────┬───────────────────────────────────────────┘
                               │ refs only; no raw tokens
┌──────────────────────────────▼───────────────────────────────────────────┐
│ Chimeway                                                                  │
│ Event → Notification → logical Delivery → DeliveryTarget* → Attempt      │
│          planning/policy/schedule/retry/expiry/recovery/trace             │
│                                                                          │
│ One logical reminder has one delivery decision; each active installation  │
│ has a durable DeliveryTarget and independent endpoint attempts/outcome.   │
└──────────────────────────────┬───────────────────────────────────────────┘
                               │ opaque open/binding/action refs
┌──────────────────────────────▼───────────────────────────────────────────┐
│ CrossWake shell + companion                                               │
│ Explicit permission → APNs registration → authenticated host binding      │
│ Notification open evidence → host one-time intent → RouteGate activation  │
└──────────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical implementation |
|-----------|----------------|------------------------|
| Host push registry | Own raw tokens, installation/binding state, recipient eligibility, time zone, and deep-link targets | Host Ecto context; opaque endpoint refs exposed outside it |
| `Chimeway.Push.TargetResolver` | Resolve eligible active endpoint references for a recipient and tenant | New host-implemented behaviour; returns no token or deep-link material |
| Logical `Delivery` | Durable planning, policy, schedule, expiry, suppression, recovery, and explainability decision | Existing Chimeway delivery lifecycle, extended with target children |
| `DeliveryTarget` | Per-installation endpoint state and attempts for a logical delivery | New durable child aggregate keyed by opaque endpoint ref |
| APNs gateway adapter | Dereference target internally and submit pre-rendered payload to APNs | Host adapter, selected for the push channel |
| CrossWake | Native permission/token acquisition and route-safe activation | Existing companion contracts/resolver, extended with registration lifecycle |

## Recommended Project Structure

```
lib/chimeway/
├── push/
│   ├── target_resolver.ex       # public host behaviour and contracts
│   ├── delivery_target.ex       # durable endpoint child schema
│   ├── delivery_targets.ex      # target fanout and lifecycle context
│   └── redaction.ex             # recursive boundary-safe redaction
├── delivery_planning.ex         # extend only to select/plan target children
├── deliveries.ex                # logical delivery state and tenant-scoped recovery
└── dispatch/
    └── executor.ex              # execute eligible target, record target attempt

test/chimeway/push/              # hermetic digital-twin and contract tests
```

The host’s endpoint registry and APNs adapter remain outside this project. Chimeway receives only stable opaque identifiers and minimal provider/platform/environment capability metadata.

## Architectural Patterns

### Pattern 1: Logical delivery with durable per-installation targets

**What:** Keep one `Delivery` as the explanation and orchestration aggregate for a logical reminder. Create one `DeliveryTarget` child for every active endpoint returned by the host resolver. Each child owns endpoint-specific attempts, provider feedback, retry status, and terminal reason.

**When to use:** All mobile push fanout. Non-push channels retain one implicit/default target for compatibility.

**Trade-offs:** It avoids duplicated policy/schedule decisions and keeps “why was this reminder sent?” coherent, while permitting independent device outcomes. It requires target-aware dispatch and aggregation rules.

```elixir
@callback resolve(recipient_identity :: String.t(), tenant_id :: String.t(), context :: map()) ::
  {:ok, [
    %{endpoint_ref: String.t(), provider: :apns, platform: :ios, environment: atom()}
  ]} | {:error, term()}
```

`endpoint_ref` is opaque. The return type must reject token-like fields before Chimeway persists or emits it.

### Pattern 2: Host-owned token dereference

**What:** The host resolver returns a target reference; the host APNs gateway dereferences it immediately before sending. Chimeway never stores raw device tokens, credentials, deep links, or provider request bodies.

**When to use:** Every APNs submission and provider feedback path.

**Trade-offs:** Requires a host integration context but preserves Chimeway’s local-first ownership boundary and makes package telemetry/traces safe by construction.

### Pattern 3: Tenant spine before endpoint fanout

**What:** Persist immutable `tenant_id` on Event and Notification, propagate it through planning, targets, attempts, query APIs, idempotency, traces, and recovery.

**When to use:** Before new push data is accepted. Today Trigger requires tenant ID, but the Event and Notification schemas do not contain it; DeliveryPlanning can default it to `"default"`.

**Trade-offs:** Additive migration and compatibility work now prevent cross-tenant target lookup, recovery, or operator visibility leaks later.

### Pattern 4: Opaque, one-time notification open

**What:** APNs payload carries only `open_ref`, `binding_ref`, route/action refs, and expiry. The host resolves the one-time intent and its binding; CrossWake’s existing resolver then applies RouteGate with `activation_source: :notification`.

**When to use:** Every notification activation, including cold launch.

**Trade-offs:** More server interaction than embedding a deep link, but supports expiry/replay/revocation and keeps route authority with the host/CrossWake.

## Data Flow

### Trigger-to-delivery flow

```
Host trigger (tenant, idempotency key)
  → Event + Notification persisted with tenant spine
  → logical Delivery planned; policy/schedule/expiry applied once
  → TargetResolver returns active opaque endpoints
  → DeliveryTarget children inserted idempotently
  → dispatcher executes each eligible target
  → host gateway dereferences endpoint ref and calls APNs
  → target attempt/outcome persisted and rolled up for the logical trace
```

Zero active targets is a planned, explainable suppression (`no_active_targets`), not a successful APNs delivery. Ineligible or stale targets have individual target reasons without exposing token material.

### Binding and feedback flow

```
CrossWake native snapshot / APNs token rotation
  → authenticated host binding service (raw token boundary)
  → opaque binding_ref / endpoint_ref state
  → Chimeway target resolver sees only active refs

APNs response or feedback
  → host gateway classifies provider evidence
  → host deactivates/rotates binding where appropriate
  → Chimeway records a redacted target attempt outcome
```

CrossWake’s existing `TokenEvidence`, `TokenBinding`, `ProviderFeedback`, and `NotificationOpenEvidence` contracts are appropriate boundary vocabulary. They do not make CrossWake a delivery or authentication authority.

### Trigger-to-planning recovery

```
Committed Event/Notification with no logical Delivery
  → tenant-scoped recovery scan/claim
  → replan persisted notification declarations
  → resolve current eligible targets
  → enqueue target execution idempotently
```

Recovery must scope all lookups by tenant. The current event recovery path intentionally returns no recoverable events when tenant-scoped; correct this before production push uses it.

## Persistence, API, and Migration Direction

### Additions

| Surface | Change |
|---------|--------|
| Event and Notification | Add non-null `tenant_id` after a safe staged backfill; scope idempotency uniqueness by tenant |
| Delivery | Retain logical lifecycle fields; add target aggregation/read-model fields only if needed for trace efficiency, never token material |
| DeliveryTarget | New child: `delivery_id`, `tenant_id`, `endpoint_ref`, provider/platform/environment, status/reason, eligibility timestamps, redacted metadata; unique `(delivery_id, endpoint_ref)` |
| DeliveryTargetAttempt | New append-only target attempt, or extend existing attempts with `delivery_target_id`; provider response is recursively redacted |
| Resolver behaviour | New target-resolution contract, required only for push channel |
| Query APIs | Tenant-required trace/admin/inbox/recovery forms; target summaries exposed without raw token/fingerprint unless explicitly safe |

### Backward compatibility

1. Ship additive nullable tenant fields and target tables first; write all new records with tenant ID.
2. Backfill only from unambiguous existing Delivery/Workflow tenant evidence. Report ambiguous legacy rows as `legacy_unscoped`; never guess a tenant.
3. Represent existing non-push deliveries with an implicit `default` target during the compatibility release; preserve current channel adapters unchanged.
4. Add target-aware indexes, backfill, then switch new push planning to child targets. Retire the old `(notification_id, channel)` delivery uniqueness only after legacy readers tolerate the new shape.
5. Require tenant scope on public operational APIs in the following breaking-major/minor boundary, with explicitly named legacy read shims only where necessary.

## Security and Redaction Boundary

Create one recursive redactor and use it before every persistence, telemetry, logging, DTO, adapter-return, provider-feedback, and error boundary. It must traverse nested maps/lists and reject/drop token, raw/device/APNs/FCM/registration token, secret, password, auth, API-key, URL, code, and magic-link forms regardless of nesting or string/atom key shape. Opaque refs and keyed fingerprints are permitted; raw tokens are never recoverable from Chimeway data.

This strengthens the current shallow Trigger sanitization and adapter convention. Contract tests must inspect nested persistence, attempts, telemetry, traces, `inspect/1` diagnostics, and negative adapter-return cases.

## Scaling Considerations

| Scale | Architecture adjustment |
|-------|-------------------------|
| Alpha | PostgreSQL-backed target fanout and Oban per-target jobs; bounded installation count and payload size |
| Growth | Batch resolver reads and job enqueue, index `(tenant_id, status, next_eligible_at)` plus target uniqueness, paginate operator target summaries |
| Large fleet | Partition/archive attempts by tenant/time and apply provider-aware concurrency/rate limits in the host gateway; retain Chimeway as the orchestration ledger |

The first bottleneck is multi-installation target fanout, not a need to split services. Enforce a resolver-return limit and use chunked target planning before introducing distributed fanout infrastructure.

## Anti-Patterns

### Store tokens or deep links in Chimeway

**Why it is wrong:** It violates the host ownership boundary and risks leaking credentials or private navigation data through traces, telemetry, attempts, and support exports.

**Do this instead:** Persist opaque endpoint/open/binding refs only; dereference in the host at the final provider or route-activation boundary.

### Duplicate the logical delivery for each device

**Why it is wrong:** Policy, scheduling, expiry, and explanation become inconsistent across installations and make one reminder look like many unrelated notifications.

**Do this instead:** One logical Delivery with durable `DeliveryTarget` children and independently inspectable attempts.

### Treat CrossWake’s current token snapshot as push delivery support

**Why it is wrong:** The current `notification_token` capability is prompt-free, advisory provider evidence and CrossWake explicitly reports Chimeway delivery as not shipped.

**Do this instead:** Add an explicit native permission/registration/binding lifecycle and prove it separately from the existing snapshot contract.

### Promise generic offline push or background sync

**Why it is wrong:** CrossWake’s supported offline posture is limited to cached read-only routes and one explicit study-session island; it does not provide background sync guarantees.

**Do this instead:** Keep reminder truth server-authoritative, let push cause safe re-entry, and make offline state explicit in the host UI.

## Phase Dependency and Proof Order

1. **Tenant and redaction foundation** — tenant spine, recursive redaction, scoped operational APIs, and migration/backfill report.
2. **Logical delivery / DeliveryTarget model** — new target tables, host resolver behaviour, target fanout, zero-target suppression, trace projection, and recovery integration.
3. **APNs-first execution** — host APNs gateway, target retries/expiry/failure classification, binding invalidation feedback, and rate/error boundaries.
4. **CrossWake mobile lifecycle** — explicit permission, APNs registration, authenticated binding/rotation, opaque notification-open issuance, and RouteGate re-entry.
5. **Production proof** — hermetic digital twin followed by physical iPhone sandbox evidence. The twin gates CI; the phone proof validates credentials, provisioning, and real APNs behavior without becoming a flaky CI requirement.

The hermetic twin must cover denied permission, two active installations, rotation/revocation, no-target suppression, retry/exhaustion, expiry, post-trigger planning recovery, recursive-redaction negatives, and replay/expired notification opens.

## Local Sources

- `lib/chimeway/trigger.ex` — tenant input, durable event/notification creation, shallow sanitization, post-commit planning.
- `lib/chimeway/delivery_planning.ex`, `lib/chimeway/delivery.ex`, `lib/chimeway/deliveries.ex` — existing single-channel planning identity, lifecycle, and recovery seam.
- `lib/chimeway/dispatch/executor.ex`, `lib/chimeway/adapter.ex` — per-channel adapter and append-only attempt boundary.
- `lib/chimeway/inbox.ex`, `lib/chimeway/traces.ex` — tenant derivation/query surfaces needing spine propagation.
- `crosswake_chimeway` contracts, redaction, and resolver — ref-only token/binding/open vocabulary and safe RouteGate activation.
- `crosswake/guides/offline.md` — deliberately narrow offline boundary.

---
*Architecture research for: Chimeway v1.18 Adopter Alpha mobile delivery readiness*
*Researched: 2026-08-11*
