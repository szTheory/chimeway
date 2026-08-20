# Phase 100: Optional APNs Adapter - Research

**Researched:** 2026-08-20
**Domain:** Optional Elixir/Pigeon APNs target dispatch with tenant-safe durable delivery evidence
**Confidence:** MEDIUM

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Optional Adapter and Host Custody

- **D-01:** APNs is an explicit opt-in `Chimeway.TargetAdapter` implementation. A non-push consumer must be able to fetch, compile, boot, and use Chimeway without Pigeon in its dependency tree and without any APNs configuration; an opted-in host explicitly adds and starts Pigeon.
- **D-02:** The host supervises credential-bearing Pigeon dispatchers and retains custody of `.p8` keys, key identifiers, team identifiers, and connection configuration. Chimeway receives only an opaque dispatcher reference selected for the exact environment and credential posture.
- **D-03:** At the final send boundary, a host-owned lookup resolves the exact tenant-scoped `binding_revision_ref` to transient request material. The raw device token may exist only ephemerally for request construction and must never enter Chimeway-owned persistence, logs, telemetry, traces, DTOs, exceptions, or proof artifacts.
- **D-04:** Missing, stale, mismatched, or invalid host lookup results fail before provider handoff with stable, safe evidence. Lookup and invalidation contracts remain tenant-explicit and non-disclosing.

#### Durable, Bounded Request Intent

- **D-05:** Persist and validate safe APNs request intent before target execution: exact environment and topic, stable UUID-shaped `apns-id`, host-supplied absolute expiry, opaque one-time open reference, and optional replaceability/collapse identity. Raw tokens, credentials, rendered provider payloads, and provider bodies are never part of that durable intent.
- **D-06:** Every retry or recovery attempt reuses the original stable request identity and safe intent, re-resolves only the exact binding revision's transient token/dispatcher material, and rechecks absolute expiry before provider I/O. Expired work terminates with explicit expiry evidence and no APNs request.
- **D-07:** Construct a closed, allowlisted APNs payload from validated push rendering plus the opaque open reference. Do not expose a general top-level custom-map merge; enforce Apple's ordinary 4,096-byte payload limit before provider I/O and preserve Phase 98 recursive privacy rejection.
- **D-08:** Omit `apns-collapse-id` by default. Emit it only for a host-opted replaceable occurrence, using a stable opaque value no longer than 64 bytes and scoped to the occurrence plus exact binding revision, environment, and topic so it cannot coalesce a distinct notification or installation.
- **D-09:** Treat stable `apns-id` as correlation only. It does not provide provider deduplication and does not make a re-drive after an ambiguous handoff safe.

#### Honest Outcomes and Exact Invalidation

- **D-10:** Extend the target-adapter result contract so every conclusive result follows one of four durable paths: accepted provider handoff, retryable rejection with a defined corrective action/backoff, permanent payload or configuration rejection, or exact-binding invalidation. Preserve the original attempt and safe provider facts in all cases.
- **D-11:** A confirmed APNs 200/Pigeon success is `provider_accepted` handoff only. It never means device receipt, display, protected open, inbox seen/read, or engagement.
- **D-12:** Retry only confirmed pre-provider failures or conclusive APNs rejections whose documented remedy is retry/backoff or connection/provider-token refresh, and recheck expiry first. Treat ordinary request, topic, environment, credential, authorization, and payload errors as terminal for the unchanged request.
- **D-13:** Any Pigeon synchronous `:timeout`, process exit, connection loss, or missing durable response after request emission may have occurred is `ambiguous_handoff`, not retryable. Do not blindly resend it.
- **D-14:** Pin and contract-test the supported Pigeon result vocabulary. Pigeon 2.0.1's normalized response is not sufficient as the sole reason source because it discards HTTP status and 410 timestamp and maps current Apple reasons to `:unknown_error`; preserve status/reason through a narrow reason-aware seam where required. Any still-unknown conclusive provider rejection fails closed as permanent and must neither retry nor invalidate.
- **D-15:** Only APNs 410 `ExpiredToken` or `Unregistered` may trigger provider-driven binding invalidation. `BadDeviceToken`, `DeviceTokenNotForTopic`, and other routing/configuration failures do not authorize invalidation.
- **D-16:** Host invalidation is a conditional compare-and-update against the exact `{tenant_id, environment, topic, binding_revision_ref}` used by the request. It must never resolve and invalidate a later current revision, a different installation, another environment, or another tenant. Chimeway marks only the matching delivery target invalidated and retains the attempt evidence.

### the agent's Discretion

- Exact module, behaviour, callback, struct, and configuration names, provided the public contracts remain data-first, explicit, tenant-safe, and optional.
- Exact optional-dependency and conditional-compilation packaging, provided clean-consumer executable evidence proves Chimeway fetches, compiles, and boots with Pigeon absent and opted-in evidence proves the adapter path.
- Exact table/column placement for safe request intent and exact reason-preserving Pigeon integration mechanism, provided the locked durability, privacy, version-pinning, and response-classification contracts hold.
- Exact closed APS allowlist, validation error names, safe provider-fact keys, retry schedule, and backoff implementation, provided Apple limits and documented retry delays are honored and classifications remain stable and executable.

### Deferred Ideas (OUT OF SCOPE)

- CrossWake token registration, rotation/revocation, offline tap queueing, one-time protected-open consumption, and authorization — Phase 101.
- Hermetic fake-APNs adopter twin, cross-repository verification entrypoints, and provider-reason scenario matrix — Phase 102.
- Physical-iPhone sandbox evidence and final integration/operator guidance — Phase 103.
- FCM/Android transport and a broad channel matrix — future milestone scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| APNS-01 | Opt-in Pigeon adapter without Pigeon/APNs configuration for other hosts. | A dynamically invoked adapter boundary and clean-consumer proof avoid static Pigeon references. |
| APNS-02 | Host token custody; correct environment/topic; stable ID; bounded payload; opaque open ref. | Durable intent + final tenant-scoped lookup + closed payload builder. |
| APNS-03 | Reason classification and exact-binding invalidation. | Pin Pigeon 2.0.1, preserve status/reason through a narrow seam, and use compare-and-update invalidation. |
| APNS-04 | Absolute expiry checked before send/retry and mapped to APNs. | Store UTC deadline, check before lookup/I/O, set integer epoch expiration. |
| APNS-05 | Optional installation-safe collapse key only for replaceable occurrences. | Derive a bounded opaque key from occurrence plus exact binding/topic/environment. |
| APNS-06 | Distinguish dispatch, APNs, exhaustion, invalidation, open, seen, and read. | Closed provider facts and explicit target/attempt outcomes; retain engagement as later independent facts. |
</phase_requirements>

## Project Constraints (from AGENTS.md)

- Persist stable `notification_key` plus version; never durable module names.
- Preserve the lifecycle spine: event → notification → delivery → attempt.
- Treat idempotency and suppression reasons as first-class behavior.
- Keep replaceable adapters behind explicit behaviours and contract tests.
- Preserve host ownership of authentication, tenancy, URLs, and correlation IDs.
- Maintain `mix verify.*` and `mix ci.*` parity; use executable evidence for machine-testable acceptance, never conversational UAT.
- Do not leak sensitive payload fields in telemetry or operator surfaces.

## Summary

[VERIFIED: codebase grep] Phase 99 already supplies a tenant-qualified target claim and append-only attempt spine, but its adapter contract currently collapses all successful maps into `provider_accepted` and all non-pre-handoff failures into ambiguity. Phase 100 therefore needs a richer, data-first target result union plus durable safe intent, not a separate push lifecycle.

[CITED: https://pigeon.hexdocs.pm/Pigeon.APNS.Notification.html] Pigeon 2.0.1 exposes the fields needed to construct an APNs request (`id`, `topic`, `expiration`, `collapse_id`, `payload`, and `push_type`), while its public response vocabulary is too coarse for the locked invalidation policy. [VERIFIED: https://github.com/codedge-llc/pigeon/blob/v2.0.1/lib/pigeon/apns/shared.ex#L42-L56] Its shared transport receives the raw `%Pigeon.Http2.Stream{status, headers, body}` but converts non-200 responses to a parsed reason only. [VERIFIED: https://github.com/codedge-llc/pigeon/blob/v2.0.1/lib/pigeon/apns.ex#L219-L263] The APNS adapter owns a public `Pigeon.Adapter` callback boundary and retains the notification queue keyed by stream id until `handle_info/2`, so a pinned adapter wrapper can intercept the raw end-stream, correlate the queued notification, and return a closed status/reason/timestamp result without modifying Pigeon.

[CITED: https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns] Build and size-check the complete JSON payload before provider I/O, then send only a closed APS allowlist plus the opaque one-time open reference. [CITED: https://developer.apple.com/documentation/usernotifications/handling-notification-responses-from-apns] Classify known APNs responses conservatively, and reserve invalidation exclusively for recognized 410 `ExpiredToken`/`Unregistered` results.

**Primary recommendation:** Add a Pigeon-neutral `Chimeway.Adapters.APNS` facade that dynamically loads a pinned, host-provided Pigeon runtime seam; persist only safe request intent and resolve raw token/dispatcher transiently for every attempt.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Stable APNs request intent, expiry, attempts, and outcome transitions | Database / Storage | API / Backend | [VERIFIED: codebase grep] Existing `DeliveryTarget` and append-only attempts are the durable explanation spine. |
| Tenant-scoped binding lookup and conditional invalidation | API / Backend | Host storage | [VERIFIED: CONTEXT.md D-03/D-16] Host retains token/binding authority; Chimeway invokes explicit contracts and records only safe results. |
| APNs payload/header construction and Pigeon handoff | API / Backend | External APNs/Pigeon boundary | [CITED: https://pigeon.hexdocs.pm/Pigeon.APNS.Notification.html] Pigeon sends server-side APNs notifications; no client-tier concern exists here. |
| Credentials, dispatcher supervision, and environment connection config | Host application | External APNs/Pigeon boundary | [VERIFIED: CONTEXT.md D-02] Chimeway must never own `.p8` material or dispatcher configuration. |
| Protected open, seen, and read | Client / host application | API / Backend | [VERIFIED: ROADMAP.md] Phase 101 owns authorization/open; APNs acceptance cannot establish engagement. |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `pigeon` | 2.0.1, released 2024-12-28 | Host-owned APNs dispatcher and notification transport | [VERIFIED: Hex registry] Official Hex metadata identifies 2.0.1 as latest stable; official docs expose APNs notification construction. |
| Ecto/PostgreSQL | existing project versions | Durable safe intent, target transitions, and exact conditional invalidation | [VERIFIED: codebase grep] Phase 99 already uses Ecto transactions and tenant-qualified target records. |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|
| Jason | existing `~> 1.4` | Encode candidate APNs payload and enforce byte limit | [VERIFIED: mix.exs] Use before Pigeon handoff; do not persist encoded payload. |
| `:crypto` / `Ecto.UUID` | OTP/project built-in | Validate/generate stable UUID-shaped APNs ID and derive opaque collapse value | [ASSUMED] Use only with a deterministic, bounded derivation and test it as opaque. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Narrow Pigeon response-preserving seam | Pigeon normalized `notification.response` alone | [VERIFIED: Pigeon v2.0.1 source] Normalization drops HTTP status and body timestamp and maps unmapped reasons to `:unknown_error`, contradicting D-14. |
| Dynamic Pigeon invocation | Static Pigeon structs/calls in Chimeway source | [VERIFIED: CONTEXT.md D-01] Static compile references risk failing a non-push consumer with Pigeon absent. |

**Installation:** Hosts opting in add Pigeon; Chimeway itself must not add it to `mix.exs`.

```elixir
# host mix.exs
{:pigeon, "~> 2.0"}
```

**Version verification:** `mix hex.info pigeon` confirmed 2.0.1, published 2024-12-28. [VERIFIED: Hex registry]

## Package Legitimacy Audit

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| `pigeon` | Hex | since 2015; 2.0.1 released 2024-12-28 | 27,108,494 all-time | github.com/codedge-llc/pigeon | OK | Approved host-only dependency |

**Packages removed due to [SLOP] verdict:** none.

**Packages flagged as suspicious [SUS]:** none.

[VERIFIED: Hex registry] The standard legitimacy seam currently accepts only npm/PyPI/crates, not Hex; `mix hex.info pigeon` and Hex API metadata were used instead, alongside the official Pigeon docs/source supplied in CONTEXT.md.

## Architecture Patterns

### System Architecture Diagram

```text
DeliveryTarget (tenant + binding revision)
        │ durable safe intent: topic, env, apns-id, expiry, open-ref, replaceability
        ▼
Target claim + attempt_started (transactional, pre-I/O)
        │
        ├─ expired? ───────────────► target/attempt = expired (no lookup, no APNs I/O)
        │
        ▼
Host binding lookup(tenant, env, topic, binding_revision_ref)
        │ returns transient token + opaque dispatcher ref only
        ├─ missing/mismatch ───────► stable pre-handoff failure (safe fact only)
        ▼
Closed payload builder → JSON byte check → Pigeon reason-aware seam → APNs
        │                                        │
        │                                        ├─ 200 → provider_accepted
        │                                        ├─ recognized retryable → failed + retry schedule
        │                                        ├─ 410 expired/unregistered → host CAS invalidation + target invalidated
        │                                        ├─ known/unknown terminal → failed permanent
        │                                        └─ timeout/exit/lost response → ambiguous_handoff
        ▼
Safe evidence / trace projections (never token, credentials, payload, or APNs body)
```

### Recommended Project Structure

```text
lib/chimeway/
├── adapters/apns.ex                 # Pigeon-neutral TargetAdapter facade
├── apns/request_intent.ex           # closed durable intent validation/derivation
├── apns/binding_lookup.ex           # host-owned transient lookup contract
├── apns/transport.ex                # narrow, pinned reason-aware Pigeon seam
├── apns/payload.ex                  # APS allowlist + 4,096-byte validation
├── delivery_targets.ex              # transactional classification/result mutations
└── safe_evidence.ex                 # closed APNs fact vocabulary/projections
test/chimeway/adapters/apns_test.exs
test/chimeway/apns/*_test.exs
test/chimeway/dispatch/target_worker_test.exs
```

### Pattern 1: Persist intent; resolve secrets only at final boundary

**What:** Store a safe request-intent struct on the target (or a target-owned table) before claiming execution; call the host resolver after the expiry check and immediately before constructing the Pigeon notification. [VERIFIED: CONTEXT.md D-03/D-05/D-06]

**When to use:** Every initial attempt, retry, recovery, and policy-authorized redrive.

**Example:**

```elixir
# Source: Phase 100 locked contract + existing DeliveryTargets claim pattern
with :ok <- APNS.Intent.unexpired?(target.intent, now),
     {:ok, transient} <- BindingLookup.resolve(tenant_id, target.binding_revision_ref, target.intent),
     {:ok, request} <- APNS.Payload.build(rendered_push, target.intent, transient.token),
     {:ok, result} <- APNS.Transport.push(transient.dispatcher_ref, request) do
  result
end
```

### Pattern 2: Static-free optional runtime boundary

**What:** Keep all core structs, behaviours, and validation Pigeon-free; the adapter checks Pigeon availability at runtime and calls the host-selected transport through `apply/3` or an injected behaviour. [VERIFIED: CONTEXT.md D-01]

**When to use:** The production adapter and the clean-consumer compile/boot test.

**Example:**

```elixir
# Source: D-01; deliberately no compile-time Pigeon module alias
def push(dispatcher_ref, attrs) do
  pigeon = Module.concat([Pigeon])
  notification = Module.concat([Pigeon, APNS, Notification])

  with true <- Code.ensure_loaded?(pigeon),
       request <- struct(notification, attrs) do
    apply(pigeon, :push, [dispatcher_ref, request, []])
  else
    _ -> {:error, :pre_handoff, :pigeon_unavailable}
  end
end
```

### Pattern 3: Closed result algebra, then one transactional mutation

**What:** Return explicit data variants such as `{:accepted, safe_facts}`, `{:retryable, safe_facts, retry_after_ms}`, `{:permanent, safe_facts}`, `{:invalidate, safe_facts, invalidation_key}`, `{:pre_handoff, safe_facts}`, and `{:ambiguous, safe_facts}`. Executor owns no provider-string parsing. [VERIFIED: codebase grep] This replaces the present success-or-ambiguity-only target path.

**When to use:** Every adapter result, including host lookup failures.

### Anti-Patterns to Avoid

- **Persisting a Pigeon notification or raw response:** [VERIFIED: CONTEXT.md D-03/D-05] Both can contain token, payload, credentials, or body data forbidden by Phase 98.
- **Using Pigeon’s `:timeout` as proof of no handoff:** [VERIFIED: Pigeon v2.0.1 source] `Pigeon.push/3` locally returns a timeout after waiting for a callback, so request emission may already have occurred.
- **Invalidating by current token or unscoped binding:** [VERIFIED: CONTEXT.md D-16] It can invalidate a rotated installation or another tenant/environment.
- **Passing `render_data.data` into `put_custom/2`:** [CITED: https://pigeon.hexdocs.pm/Pigeon.APNS.Notification.html] Pigeon performs a top-level merge, which violates the required closed payload boundary.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| HTTP/2 APNs connection, JWT provider auth, connection pool | Custom APNs client | Host-supervised Pigeon dispatcher | [CITED: https://developer.apple.com/documentation/usernotifications/establishing-a-token-based-connection-to-apns] Credential/connection handling belongs to host-owned Pigeon setup. |
| Lifecycle claims, retry exhaustion, ambiguity, target aggregation | Parallel APNs-specific delivery state machine | Existing `DeliveryTargets` lifecycle spine | [VERIFIED: codebase grep] It already locks parent/target/attempt transitions and preserves pre-I/O evidence. |
| Secret/token persistence or binding authority | Chimeway token registry | Host lookup + conditional invalidation behaviours | [VERIFIED: CONTEXT.md D-02/D-03/D-16] Host owns data and authority. |
| Generic provider-body storage | JSON provider response archive | `SafeEvidence` closed fact allowlist | [VERIFIED: codebase grep] Existing evidence boundary redacts and rejects unsafe facts. |

**Key insight:** APNs transport is a replaceable edge; the trustworthy product behavior is the existing durable target/attempt lifecycle plus a small, explicit APNs intent/result vocabulary.

## Common Pitfalls

### Pitfall 1: Letting the optional adapter import Pigeon statically

**What goes wrong:** A non-push package compile or boot resolves `Pigeon.*` even though its host never chose APNs. [VERIFIED: CONTEXT.md D-01]

**How to avoid:** Add a clean-consumer test that obtains the packaged artifact with no Pigeon dep/config, runs `mix deps.get`, `mix compile --warnings-as-errors`, and boots the app; separately prove the host opt-in fixture. [VERIFIED: codebase grep]

### Pitfall 2: Losing APNs status/reason data

**What goes wrong:** The Pigeon shared transport maps non-200 bodies to a reason atom and discards HTTP status/body timestamp. [VERIFIED: https://github.com/codedge-llc/pigeon/blob/v2.0.1/lib/pigeon/apns/shared.ex]

**How to avoid:** Pin Pigeon 2.0.1 and use `Chimeway.APNS.Transport.PigeonAdapter` as the host-supervised dispatcher's adapter. It dynamically delegates connection/request callbacks to `Pigeon.APNS`, intercepts the raw end-stream before Pigeon's normalizer, correlates `stream.id` against the pinned APNS queue, decodes only bounded `reason` and 410 `timestamp`, and invokes the original response callback with Chimeway's closed provider result. All other messages delegate unchanged. No raw body crosses the seam. [VERIFIED: https://github.com/codedge-llc/pigeon/blob/v2.0.1/lib/pigeon/apns.ex#L164-L263; https://github.com/codedge-llc/pigeon/blob/v2.0.1/lib/pigeon/apns/shared.ex#L42-L56]

### Pitfall 3: Retrying a local timeout as if I/O never happened

**What goes wrong:** Pigeon’s synchronous function sends first and then times out waiting for the response. [VERIFIED: https://github.com/codedge-llc/pigeon/blob/v2.0.1/lib/pigeon.ex]

**How to avoid:** Map timeout, process exit, connection loss, and any missing post-emission response to `ambiguous_handoff`; allow only explicit policy-authorized redrive. [VERIFIED: CONTEXT.md D-13]

### Pitfall 4: Invalidating a rotated binding

**What goes wrong:** A provider invalidation that resolves a token again can target its newer replacement. [VERIFIED: CONTEXT.md D-16]

**How to avoid:** Send the original `{tenant_id, environment, topic, binding_revision_ref}` as a compare-and-update key and mark only the already-claimed target invalidated when the host reports an exact match.

### Pitfall 5: Over-broad custom payloads or byte counting before encoding

**What goes wrong:** A generic map merge creates unreviewed top-level data, and character count can differ from encoded JSON byte size. [CITED: https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns]

**How to avoid:** Construct the complete JSON map from a closed schema, `Jason.encode!/1`, then require `byte_size(encoded) <= 4096` before Pigeon I/O. [ASSUMED]

## Code Examples

### Stable Pigeon request fields

```elixir
# Source: https://pigeon.hexdocs.pm/Pigeon.APNS.Notification.html
%Pigeon.APNS.Notification{
  device_token: transient_token,
  topic: intent.topic,
  id: intent.apns_id,
  expiration: DateTime.to_unix(intent.expires_at),
  collapse_id: intent.collapse_id,
  push_type: "alert",
  payload: closed_payload
}
```

### Exact invalidation callback

```elixir
# Source: D-15/D-16
case host.invalidate_binding(%{
       tenant_id: tenant_id,
       environment: intent.environment,
       topic: intent.topic,
       binding_revision_ref: target.binding_revision_ref
     }) do
  :invalidated_exactly -> {:invalidate, %{provider_code: "apns_unregistered"}}
  :stale_or_missing -> {:permanent, %{provider_code: "binding_not_current"}}
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Single coarse `TargetAdapter` success/failure outcome | Explicit APNs result algebra with preserved safe provider classification | Phase 100 | [VERIFIED: codebase grep + CONTEXT.md D-10] Enables retry, permanent failure, exact invalidation, and ambiguity to remain explainable. |
| Pigeon normalized response as provider truth | Pinned narrow seam preserves required status/reason | Pigeon 2.0.1 contract | [VERIFIED: CONTEXT.md D-14] Required for precise invalidation and retry decisions. |

**Deprecated/outdated:** Treating APNs 200 as device delivery or engagement is prohibited; it means provider acceptance only. [VERIFIED: CONTEXT.md D-11]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | A deterministic OTP cryptographic derivation is the chosen implementation for collapse identity. | Standard Stack | Choose an alternative opaque deterministic derivation while preserving D-08 constraints. |
| A2 | JSON `byte_size` is measured with Jason after full map encoding. | Common Pitfalls | Must be verified by direct Apple API documentation or a contract test against the selected encoder. |

## Open Questions (RESOLVED)

1. **Reason/status/410-timestamp seam — resolved:** `Chimeway.APNS.Transport.PigeonAdapter` is a Pigeon-neutral module loaded dynamically by the opted-in host as the adapter for its host-supervised `Pigeon.Dispatcher`. It delegates init, push, connection, ping, and non-response messages to Pigeon 2.0.1's APNS adapter, but intercepts the raw end-stream in `handle_info/2` before `Pigeon.APNS.Shared.handle_end_stream/3`. The wrapper correlates `stream.id` with the APNS state's queued notification, accepts an integer HTTP status, decodes a bounded JSON body containing only a recognized string `reason` and an integer `timestamp` when status is 410, discards the body, and invokes the queued notification's response callback with Chimeway's closed result struct. A missing queue entry, malformed/oversized body, unknown reason, or incomplete 410 triple fails closed and cannot invalidate. This uses Pigeon's documented custom-adapter dispatcher boundary and pinned callback/state contracts; it does not patch or fork Pigeon. [VERIFIED: https://hexdocs.pm/pigeon/Pigeon.Adapter.html; https://github.com/codedge-llc/pigeon/blob/v2.0.1/lib/pigeon/apns.ex#L164-L263; https://github.com/codedge-llc/pigeon/blob/v2.0.1/lib/pigeon/notification_queue.ex#L1-L43; https://github.com/codedge-llc/pigeon/blob/v2.0.1/lib/pigeon/apns/shared.ex#L42-L56] Apple defines `timestamp` only for status 410 and describes it as milliseconds since Epoch, so invalidation requires the exact `(410, ExpiredToken|Unregistered, non-negative timestamp)` triple. [CITED: https://developer.apple.com/documentation/usernotifications/handling-notification-responses-from-apns]

2. **Closed APS allowlist — resolved:** Phase 100 emits exactly `%{"aps" => %{"alert" => %{"title" => title, "body" => body}}, "chimeway_open_ref" => open_ref}`. `badge`, `sound`, `category`, `content-available`, `mutable-content`, `interruption-level`, thread/target-content identifiers, and arbitrary custom keys are rejected. Apple documents `alert` as sufficient for a visible notification while badge, sound, category, and other presentation behaviors are independently optional; no Phase 100 adopter decision authorizes those policies. [CITED: https://developer.apple.com/library/archive/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/PayloadKeyReference.html; VERIFIED: CONTEXT.md D-07]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Elixir/Mix | adapter compile/tests | ✓ | 1.19.5 / Mix 1.19.5 | project supports 1.17+ |
| PostgreSQL | durable target migration/tests | ✓ | 14.17, local port accepting | project Docker test service |
| Docker | `scripts/test-db` | ✓ | 29.5.2 | existing `DATABASE_URL` |
| Pigeon/APNs credentials | host opt-in runtime only | ✗ (intentionally not configured) | — | fake/injected transport in unit tests; physical proof deferred to Phase 103 |

**Missing dependencies with no fallback:** none for Phase 100’s machine-testable contracts.

**Missing dependencies with fallback:** Real Apple credentials/device are intentionally out of scope; use a fake host transport seam for adapter contracts.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (project-native) |
| Config file | `test/test_helper.exs` |
| Quick run command | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/apns --warnings-as-errors` |
| Full suite command | `mix ci` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| APNS-01 | Pigeon-absent clean consumer fetches/compiles/boots; opt-in host adapter works | integration/compile | `mix verify.apns` | ❌ Wave 0 |
| APNS-02 | transient token never persists; topic/env/id/payload/open ref are valid | unit + integration | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/apns/request_test.exs --warnings-as-errors` | ❌ Wave 0 |
| APNS-03 | reason matrix, safe facts, exact compare-and-update invalidation | unit + DB integration | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/apns/result_test.exs --warnings-as-errors` | ❌ Wave 0 |
| APNS-04 | expired initial/retry produces no lookup/provider call and records expiry | DB integration | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/dispatch/target_worker_test.exs --warnings-as-errors` | ✅ extend |
| APNS-05 | collapse absent by default; scoped/bounded on replaceable occurrence | unit | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/apns/request_test.exs --warnings-as-errors` | ❌ Wave 0 |
| APNS-06 | trace projection distinguishes lifecycle/provider facts without engagement conflation | DB integration | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/safe_evidence_test.exs --warnings-as-errors` | ✅ extend |

### Sampling Rate

- **Per task commit:** focused `scripts/test-db … mix test` command for changed contract.
- **Per wave merge:** `mix ci` plus `mix verify.apns` once introduced.
- **Phase gate:** full suite green and a clean-consumer APNS-01 proof; no conversational UAT.

### Wave 0 Gaps

- [ ] `test/chimeway/apns/request_test.exs` — intent, payload, size, expiry, collapse, privacy.
- [ ] `test/chimeway/apns/result_test.exs` — provider matrix and exact invalidation contracts.
- [ ] `test/support/apns_fake_transport.ex` — no-network reason/status-preserving fake.
- [ ] `mix verify.apns` + matching `ci.apns` CI job — clean-consumer optionality and opt-in proof with local/CI parity.
- [ ] New copied migration fixture entries and migration contract updates for public/prefixed storage.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | [VERIFIED: ROADMAP.md] Host identity and protected open are Phase 101. |
| V3 Session Management | no | [VERIFIED: ROADMAP.md] No client session is created in Phase 100. |
| V4 Access Control | yes | [VERIFIED: CONTEXT.md D-03/D-16] Tenant-explicit lookup and exact compare-and-update invalidation. |
| V5 Input Validation | yes | [VERIFIED: CONTEXT.md D-05/D-07] Closed intent/payload schemas and pre-I/O byte bounds. |
| V6 Cryptography | yes | [VERIFIED: CONTEXT.md D-02] Host-owned Pigeon/Apple credential handling; never hand-roll JWT signing. |

### Known Threat Patterns for APNs adapter

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Device token or `.p8` leaks in storage/evidence | Information Disclosure | [VERIFIED: CONTEXT.md D-02/D-03] Transient-only lookup; SafeEvidence allowlist; fixture leak tests. |
| Cross-tenant/revision invalidation | Tampering | [VERIFIED: CONTEXT.md D-16] Conditional exact four-field host invalidation key plus target-specific mutation. |
| Replay after uncertain provider handoff | Tampering | [VERIFIED: CONTEXT.md D-09/D-13] Persist attempt-start before I/O; terminal ambiguous state; explicit authorized redrive only. |
| Payload abuse or stale reminder | Denial of Service / Integrity | [VERIFIED: CONTEXT.md D-06/D-07] Size check, closed payload, absolute expiry before lookup and I/O. |

## Sources

### Primary (HIGH confidence)

- [Pigeon 2.0.1 shared APNs transport source](https://github.com/codedge-llc/pigeon/blob/v2.0.1/lib/pigeon/apns/shared.ex) — headers and non-200 normalization.
- [Pigeon 2.0.1 synchronous push source](https://github.com/codedge-llc/pigeon/blob/v2.0.1/lib/pigeon.ex) — send-before-receive timeout behavior.
- [Project source: target lifecycle and evidence](../../../lib/chimeway/delivery_targets.ex) — current claims, attempts, expiration/invalidation hooks, and aggregate contract.

### Secondary (MEDIUM confidence)

- [Pigeon APNS notification docs](https://pigeon.hexdocs.pm/Pigeon.APNS.Notification.html) — supported fields and normalized result vocabulary.
- [Apple APNs request documentation](https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns) — request headers, payload limits, expiry/collapse semantics.
- [Apple APNs response documentation](https://developer.apple.com/documentation/usernotifications/handling-notification-responses-from-apns) — response reasons and retry/invalidation guidance.
- [Apple token-based connection documentation](https://developer.apple.com/documentation/usernotifications/establishing-a-token-based-connection-to-apns) — credentials/connection ownership.
- [Hex package metadata](https://hex.pm/packages/pigeon) — Pigeon release/version provenance.

### Tertiary (LOW confidence)

- None beyond the two explicit implementation assumptions in the assumptions log.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — locked Pigeon version and Hex metadata were verified.
- Architecture: HIGH — phase decisions map directly to inspected Phase 99 target/attempt seams.
- Pitfalls: MEDIUM — Pigeon source verified; Apple pages were cited but their dynamic rendering prevented line-level extraction in this session.

**Research date:** 2026-08-20
**Valid until:** 2026-08-27 (provider library/API integration; recheck before execution).
