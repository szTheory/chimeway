# Stack Research

**Domain:** APNs-first mobile push delivery for Adopter Alpha
**Researched:** 2026-08-11
**Confidence:** HIGH

## Recommendation

Add a thin APNs adapter backed by **Pigeon `~> 2.0`** (current published release: 2.0.1), but keep it an optional Chimeway integration. The host owns registration-token storage, installation state, identity binding, and CrossWake open-intent state; Chimeway owns durable planning, per-installation fanout, provider attempt history, error classification, and explainability.

Pigeon is the correct boundary because APNs requires HTTP/2, TLS, JWT provider-token authentication, persistent connections, and response-level failure handling. Chimeway should not reimplement that protocol stack. Configure a host-owned `Pigeon.Dispatcher`; the Chimeway adapter creates exactly one APNs request for one resolved opaque endpoint reference, then converts Pigeon's response into Chimeway's existing `:temporary | :permanent | :bounced` result contract.

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Chimeway adapter + dispatch spine | Existing, Elixir `~> 1.17` | Durable per-installation delivery/attempt records and retry classification | The executor already selects per-channel adapters and preserves the error class into durable attempts; Oban retries only temporary errors. Extend this spine rather than create a push-specific queue. |
| Pigeon | `~> 2.0` (2.0.1) | APNs HTTP/2 client, connection dispatcher, JWT/certificate auth, response normalization | Purpose-built Elixir APNs implementation. Its current API supports APNs token authentication, persistent dispatchers, sandbox/prod selection, URI override for tests, and APNs response symbols. |
| Apple Push Notification service | HTTP/2 provider API | iOS push provider | Apple’s official API requires HTTP/2 and TLS 1.2+, supports token-based provider authentication, and returns an `apns-id` for observability. Use token authentication (`.p8`, `kid`, team ID), not certificate lifecycle by default. |
| Oban | Existing optional `~> 2.x` | Retry scheduling and durable job execution | Existing worker behavior already retries temporary outcomes and records terminal permanent/bounced failure without retry. APNs classifications fit it directly. |
| Host-owned endpoint/open registry | Existing host application database | Opaque endpoint lookup, installation state, deactivation, one-time opens | Keeps raw APNs device tokens and business identity out of Chimeway. CrossWake’s companion contracts already model opaque installation, token, binding, provider/platform/environment, and one-time-open refs. |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `pigeon` | `~> 2.0` | APNs integration implementation | Only in an APNs-enabled Chimeway host/integration package. Declare optional and conditionally compile the adapter, as with the Mailglass integration. |
| ExUnit | Built in | Hermetic digital-twin verification | Always: classify all APNs responses, assert payload/header construction, redaction, expiry behavior, binding deactivation, and one-time open outcomes. |
| Explicit fake APNs transport/dispatcher facade | Project code; no package | Deterministic APNs twin | Default unit/integration proof. It avoids provider network calls while exercising Chimeway’s public adapter/registry boundaries. |
| Mox | Do not add initially | Optional behaviour mock generator | Only if explicit transport fakes become repetitive. The existing adapter contract/fake approach is clearer and remains async-safe without another dependency. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| Existing `Chimeway.Adapter.ContractTest` | Contract guard for APNs adapter | Extend it with APNs-specific fixtures/outcomes; retain its no-sensitive-meta checks. |
| Pigeon `:uri` config | Focused HTTP integration seam | Use only where a genuine HTTP/2 local fixture is available; it is not the primary digital twin. |
| Physical iPhone sandbox proof | Release evidence | Verify device registration, sandbox push acceptance/observation, and replay rejection separately from CI. Never place tokens or Apple credentials in test fixtures or CI logs. |

## Installation

```elixir
# mix.exs — optional APNs adapter dependency
{:pigeon, "~> 2.0", optional: true}
```

```elixir
# host config — values loaded from the host's runtime secret source
config :adopter_alpha, AdopterAlpha.APNS,
  adapter: Pigeon.APNS,
  key: System.fetch_env!("APNS_AUTH_KEY_P8"),
  key_identifier: System.fetch_env!("APNS_KEY_ID"),
  team_id: System.fetch_env!("APNS_TEAM_ID"),
  mode: :prod

config :chimeway,
  channel_adapters: %{"push" => Chimeway.Adapters.APNS},
  channel_adapter_configs: %{
    "push" => [dispatcher: AdopterAlpha.APNS, topic: "host.bundle.id"]
  }
```

Do not treat the example secret-loading form as an instruction to store credentials in Chimeway config or delivery metadata. The host owns secret resolution and supervisor startup.

## Integration Pattern

```
host registry resolves opaque endpoint ref
  -> one Chimeway delivery per active installation binding
  -> Chimeway.Adapters.APNS resolves raw token only at send boundary
  -> host-owned Pigeon dispatcher sends APNs request
  -> adapter returns redacted APNs result
  -> Chimeway records attempt and Oban retries/converges
  -> CrossWake open evidence atomically consumes one-time open_ref
```

For every request, set a stable APNs topic, `apns-push-type: alert`, and `apns-id` equal to the Chimeway delivery UUID. Store only the returned APNs ID and compact response class/reason. The APNs `apns-expiration` must be bounded by the server-side CrossWake open-intent expiry; choose `0` for no offline storage or a Unix timestamp no later than intent expiry when delayed delivery is intended. APNs acceptance is not proof that the device displayed the notification or opened it.

Map Pigeon responses as follows:

| APNs/Pigeon result | Chimeway result | Registry action |
|--------------------|-----------------|-----------------|
| `:success` | `{:ok, redacted_meta}` | none |
| `:bad_device_token`, `:device_token_not_for_topic`, `:expired_token`, `:unregistered` | `{:error, :bounced, compact_detail}` | atomically deactivate/supersede that binding; no retry |
| `:timeout`, `:too_many_requests`, `:internal_server_error`, `:service_unavailable`, `:shutdown` | `{:error, :temporary, compact_detail}` | retain binding; Oban backoff retry |
| malformed payload/topic/auth/config and other non-recoverable request errors | `{:error, :permanent, compact_detail}` | retain or flag configuration; no retry |

An `ExpiredProviderToken` needs provider-token refresh/reconnect rather than a new device endpoint; classify the immediate attempt as temporary only if the Pigeon integration can safely refresh credentials before the current open intent expires. Otherwise make it permanent and surface an operator configuration incident. This choice must be covered by the APNs adapter’s explicit contract tests.

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Pigeon `~> 2.0` behind Chimeway adapter | Direct Finch/Mint/JWT client | Only if Pigeon demonstrably fails the Elixir 1.17 floor or lacks a required APNs behavior. This option makes Chimeway responsible for JWT rotation, HTTP/2 multiplexing, TLS/GOAWAY lifecycle, and protocol classification. |
| Host-owned registry behaviour | Chimeway-owned endpoint/token tables | Never for the Alpha production path. It violates local-first host ownership and couples Chimeway to authentication, tenant, and installation semantics. |
| Explicit deterministic fake | Bypass | Bypass is useful for generic HTTP clients, but a local Plug test does not prove APNs’s required HTTP/2 semantics and its latest published release is old. |
| APNs only | Generic cross-provider abstraction / FCM | Defer until FCM is an actual adopter requirement. Keep schema/provider fields extensible, but do not add the Firebase SDK, FCM credentials, or Android operational surface now. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| A hand-built APNs provider client | Recreates complex HTTP/2, JWT, connection and GOAWAY correctness obligations | Pigeon behind a small Chimeway adapter/transport seam |
| Raw device tokens in Chimeway deliveries, attempts, telemetry, or CrossWake evidence | Leaks an endpoint credential and violates the opaque-ref/local-first boundary | Host registry resolves opaque `token_ref` only at send time; retain a non-reversible fingerprint where required |
| APNs receipt/webhook implementation | APNs provides per-request responses, not delivery-confirmation webhooks | Record `apns-id` and provider acceptance; treat client open evidence as a separate CrossWake flow |
| APNs `200` as notification-open proof | It confirms provider acceptance only | Atomically consume `open_ref` through the host intent consumer before CrossWake route authorization |
| FCM/Firebase SDK now | Expands platform, credentials, provider behavior, and test matrix without Alpha value | APNs-first implementation; add a provider only when an adopter requires it |

## Stack Patterns by Variant

**If a notification has a one-time CrossWake action:**
- Set its APNs expiration to no later than the server-side `open_ref` expiry.
- Because APNs may retain/retry a nonzero-expiry notification, while the open must never become valid after its server intent expires.

**If the host has multiple active iOS installations for one recipient:**
- Plan one push delivery per host registry binding and retain the binding reference on each delivery.
- Because a failure on one token must not suppress delivery to another installation, and APNs invalidation is per token/topic.

**If the host needs a hermetic twin:**
- Use the explicit fake facade to return each Pigeon/APNs normalized outcome without network access.
- Because it validates Chimeway policy, durable attempts, deactivation calls, and CrossWake handoff deterministically; physical-device proof remains release evidence.

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| Chimeway `~> 1.17` | Elixir 1.17+ / OTP 26+ | Keep Pigeon optional and conditionally compile its adapter so Chimeway core preserves its stated floor. Run an enabled-dependency floor compile/test lane before locking the release constraint. |
| Pigeon `2.0.1` | Host-owned Pigeon dispatcher, APNs HTTP/2 API | Official docs show token auth, sandbox/prod mode, persistent dispatchers, and response normalization. Validate the enabled combination against Chimeway’s Elixir 1.17 floor in CI. |
| Chimeway Oban integration | Oban `~> 2.x` | Existing worker retries `:temporary`, completes permanent/bounced terminal outcomes, and records each attempt durably. No new worker technology is needed. |
| `crosswake_chimeway` | Crosswake companion Elixir `~> 1.19` | Preserve its existing no-new-runtime-dependency boundary. It supplies contracts/resolution semantics; it must not depend on Pigeon or expose raw tokens. |

## Local Evidence

- [Chimeway dependencies](/Users/jon/projects/chimeway/mix.exs:33) — Elixir `~> 1.17`, optional Oban and optional companion pattern.
- [Adapter contract](/Users/jon/projects/chimeway/lib/chimeway/adapter.ex:12) — runtime config, compact redacted metadata, and three error classes.
- [Executor integration](/Users/jon/projects/chimeway/lib/chimeway/dispatch/executor.ex:29) — per-channel adapter resolution and durable error classification.
- [Oban retry contract](/Users/jon/projects/chimeway/lib/chimeway/dispatch/oban_worker.ex:77) — temporary retry versus terminal permanent/bounced convergence.
- [CrossWake binding contract](/Users/jon/projects/crosswake/packages/crosswake_chimeway/lib/crosswake/companions/chimeway/contracts.ex:138) — opaque installation/token/binding fields and lifecycle timestamps.
- [CrossWake one-time open evidence](/Users/jon/projects/crosswake/packages/crosswake_chimeway/lib/crosswake/companions/chimeway/contracts.ex:246) and [resolver](/Users/jon/projects/crosswake/packages/crosswake_chimeway/lib/crosswake/companions/chimeway/resolver.ex:20) — host intent consumption precedes route authorization.

## Sources

- [Pigeon APNS 2.0.1 official docs](https://pigeon.hexdocs.pm/Pigeon.APNS.html) — dispatcher startup, token authentication, sandbox/prod, URI test override, and synchronous send behavior.
- [Pigeon APNS notification API](https://pigeon.hexdocs.pm/Pigeon.APNS.Notification.html) — supported response classes and request fields including `id`, expiration, priority, push type, and topic.
- [Pigeon package on Hex](https://hex.pm/packages/pigeon) — current published version 2.0.1.
- [Apple: Sending notification requests to APNs](https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns?changes=_3_4) — HTTP/2/TLS, required headers, payload limit, expiry semantics, connection reuse, and `apns-id` tracking.
- [Apple: Handling notification responses from APNs](https://developer.apple.com/documentation/usernotifications/handling-notification-responses-from-apns?changes=_7) — definitive non-retry, delayed retry, and 5xx-backoff response guidance.
- [Bypass package](https://hex.pm/packages/bypass) — scope as generic HTTP mock server and release information.

---
*Stack research for: Chimeway v1.18 Adopter Alpha Mobile Delivery Readiness*
*Researched: 2026-08-11*
