# Phase 101: CrossWake Registration & Protected Open - Pattern Map

**Mapped:** 2026-08-22  
**Files analyzed:** 19 planned source/test surfaces  
**Analogs found:** 18 / 19

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `../crosswake/lib/crosswake/policy/schema.ex` | model/validator | transform | same file | exact |
| `../crosswake/lib/crosswake/policy/route.ex` | model | transform | same file | exact |
| `../crosswake/lib/crosswake/manifest/builder.ex` | service | transform | same file | exact |
| `../crosswake/lib/crosswake/manifest/types.ex` | model/serializer | transform | same file | exact |
| `../crosswake/lib/crosswake/manifest/validator.ex` | validator | transform | same file | exact |
| `../crosswake/packages/crosswake_chimeway/lib/crosswake/companions/chimeway/contracts.ex` | model/contract | request-response | same file | exact |
| `../crosswake/packages/crosswake_chimeway/lib/crosswake/companions/chimeway/intent_consumer.ex` | behaviour | request-response | same file | exact |
| `../crosswake/packages/crosswake_chimeway/lib/crosswake/companions/chimeway/resolver.ex` | service | request-response | same file | exact |
| `../crosswake/packages/crosswake_chimeway/lib/crosswake/companions/chimeway/{denial_codes,redaction,telemetry}.ex` | utility | transform/event-driven | same files | exact |
| `../crosswake/lib/crosswake/compatibility/route_gate.ex` | middleware/guard | request-response | same file | exact |
| `../crosswake/packages/crosswake-shell-core-ios/Sources/CrosswakeShellCore/CrosswakeDelegates.swift` | protocol | event-driven | same file | exact |
| `../crosswake/packages/crosswake-shell-core-ios/Sources/CrosswakeShellCore/CrosswakeShellConfig.swift` | config/provider | event-driven | same file | exact |
| `../crosswake/packages/crosswake-shell-core-ios/Sources/CrosswakeShellCore/NotificationOpenQueue.swift` | service/store | file-I/O/event-driven | `PackStore.swift` (bounded local state) + `CrosswakeDelegates.swift` | role-match |
| `../crosswake/packages/crosswake-shell-core-ios/Sources/CrosswakeShellCore/ActivationCoordinator.swift` | controller | request-response/event-driven | same file | exact |
| `../crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/{registry,token_binding,notification_open_intent}.ex` and migrations | host service/model/migration | CRUD | existing example-host Chimeway registry | exact |
| `../crosswake/test/crosswake/policy/{schema,route}_test.exs` | test | transform | same files | exact |
| `../crosswake/test/crosswake/manifest/{builder,validator}_test.exs` | test | transform | same files | exact |
| `../crosswake/packages/crosswake_chimeway/test/crosswake/companions/chimeway/{contracts,resolver,denial_codes,redaction,telemetry}_test.exs` | test | request-response | same files | exact |
| `../crosswake/packages/crosswake-shell-core-ios/Tests/CrosswakeShellCoreTests/*Notification*Tests.swift` | test | file-I/O/event-driven | `ActivationConformanceTests.swift` | role-match |

## Pattern Assignments

### Manifest policy pipeline

Apply one normalized `notification_open` value through `schema.ex`, `route.ex`, `builder.ex`, `types.ex`, and `validator.ex`; do not preserve a raw `true` branch downstream.

**Schema pattern — `lib/crosswake/policy/schema.ex` (lines 137-140, 489-512):** custom NimbleOptions validation returns normalized data or a stable error.

```elixir
notification_open: [
  type: {:custom, __MODULE__, :validate_notification_open, []},
  type_spec: quote(do: notification_open_declaration() | nil)
]

def validate_notification_open(nil), do: {:ok, nil}
def validate_notification_open(false), do: {:ok, nil}
def validate_notification_open(true), do: {:ok, true}
```

Replace the legacy output with the canonical default-action representation here, reject empty/unrecognized actions here, and expose that one type to all consumers.

**Route/build pattern — `policy/route.ex` (lines 71-91) and `manifest/builder.ex` (lines 188-216):** validate before `struct!`, then copy the already-normalized field into `Types.new_route_entry/1`.

```elixir
with {:ok, validated} <- validate_offline_contracts(validated),
     {:ok, validated} <- validate_gating_posture(validated) do
  {:ok, struct!(__MODULE__, validated)}
end

Types.new_route_entry(..., notification_open: route.notification_open)
```

**Serialization pattern — `manifest/types.ex` (lines 1240-1268, 1463-1471):** use a private serializer and omit only `nil`; update the struct/type at lines 283-331 and constructor at lines 869-893 together.

```elixir
"notification_open" => serialize_notification_open(route.notification_open)

defp serialize_notification_open(nil), do: nil
defp serialize_notification_open(%{actions: actions}),
  do: %{"actions" => Enum.map(actions, &Atom.to_string/1)}
```

**Validator pattern — `manifest/validator.ex` (lines 344-353):** add a dedicated `validate_route_notification_open/2` into `route_errors/4`, producing the existing `%{key, route_id, path, message, hint}` finding format. This must reject raw/empty/malformed compiled values.

**Tests:** extend `policy/schema_test.exs`, `policy/route_test.exs`, `manifest/builder_test.exs` (notification transfer examples at lines 75-110), and `manifest/validator_test.exs`. Cover legacy true -> one default action, explicit membership, absent/false/empty/malformed deny, and serialized/runtime equality.

### Companion contracts, resolver, and safe outcomes

**Contract construction — `contracts.ex` (lines 524-544, 581-611):** use required opaque fields plus closed vocabularies, then centralize struct construction through `build/3` so forbidden raw token keys cannot leak.

```elixir
[]
|> validate_required_string(:open_ref, evidence.open_ref)
|> validate_required_string(:binding_ref, evidence.binding_ref)
|> validate_closed(:provider, evidence.provider, @providers)
|> validate_required_string(:action_ref, evidence.action_ref)
|> to_result()

with :ok <- reject_forbidden_token_attrs(attrs),
     {:ok, struct} <- struct_from_attrs(module, attrs),
     :ok <- validator.(struct), do: {:ok, struct}
```

Extend evidence/resolution only with opaque, bounded values. The `IntentConsumer` behaviour is intentionally the sole host boundary (`intent_consumer.ex` lines 7-14):

```elixir
@callback consume_intent(NotificationOpenEvidence.t()) ::
  {:ok, OpenResolution.t()} | {:error, map() | keyword()}
```

The host implementation must atomically perform its own tenant, session/version, expiry, exact-binding, and replay predicate; CrossWake receives only the closed resolution.

**Resolver order — `resolver.ex` (lines 20-62):** current code is the direct analog, but Phase 101 must harden it: validate evidence; consume first through the host seam; use the server-bound route/action from the valid resolution; then recheck the *current normalized* manifest exact action membership and RouteGate. Any unexpected consumer shape/state maps to a generic denial.

```elixir
case intent_consumer.consume_intent(evidence) do
  {:ok, %OpenResolution{state: :valid}} ->
    decision = RouteGate.evaluate(manifest, evidence.route_id, target,
      activation_source: :notification, auth_context: evidence.auth_context)
    if decision.status == :allow, do: {:allow, decision}, else: {:deny, decision.denial}
  {:ok, %OpenResolution{state: state}} -> deny(route, denial_code_for_intent_state(state), ...)
  {:error, state} -> deny(route, denial_code_for_intent_state(state), ...)
end
```

Do not retain current permissive branches at `resolver.ex` lines 64-71 (`notification_open: _` and fallback `action_allowed?`). Exact membership is mandatory.

**Denial/telemetry pattern:** retain closed allowlists. `denial_codes.ex` lines 6-13 and 39-47 uses `Map.take/2`; `telemetry.ex` lines 10-38 and 119-149 accepts only known event names, known metadata keys, and scalar bounded values. Add queue/consumed/authorized/replayed/expired/binding/session-policy outcomes only to these lists; never pass maps from APNs/host state through.

**Redaction pattern — `redaction.ex` lines 51-101, 174-180:** raw input may be accepted only at the boundary, fingerprinted immediately, and converted to `TokenEvidence`; reject forbidden token keys recursively for every new public queue/intent contract.

**Tests:** use `resolver_test.exs` lines 16-27 for a behaviour-conforming fake and lines 71-156 for table-style safe denials. Add race-aware host example tests using `RegistryNotificationOpenTest` lines 51-212; assert one winner and that the loser observes `:replayed`, never an activation.

### RouteGate and iOS shell

**RouteGate — `route_gate.ex` lines 33-85:** route authorization is evaluated fresh, aggregates fail-closed denials, and notification-source denials return `:halt` before any fallback.

```elixir
denials = gate_denials ++ auth_denials ++ compatibility_denials
status = if(denials == [], do: :allow, else: :deny)
transition: transition_for(status, route, opts)

if Keyword.get(opts, :activation_source) == :notification, do: :halt
```

Keep this as the only final policy/auth gate. Protected-open code must inspect an allow decision before calling native activation, and must never call `ActivationCoordinator.openURL` after a denial.

**Host delegate/config seam — `CrosswakeDelegates.swift` lines 11-17 and 27-46; `CrosswakeShellConfig.swift` lines 3-50:** define a narrow `AnyObject` host protocol, add an optional weak config property/initializer parameter, and advertise capability only when configured.

```swift
public protocol NotificationTokenDelegate: AnyObject {
    func currentToken() -> BridgeChannel.NotificationTokenCommandSnapshot
}

public weak var notificationTokenDelegate: NotificationTokenDelegate?
if notificationTokenDelegate != nil { caps.append("notification_token") }
```

Follow this for a `NotificationOpenDelegate` / reconnect-consumer seam. It takes and returns opaque evidence/outcome only; token custody, authentication, persistence, and CAS remain in the app.

**Queue/activation:** create a bounded `NotificationOpenQueue.swift` as a local opaque-evidence store. It may enqueue while offline and drain only into the host consumer; it must contain neither URL, route target, authorization boolean, payload, raw token, subject, nor session. Treat its local state as pending display-safe evidence, not authority. Use `ActivationCoordinator.activate/resolve` at lines 335-456 only after resolver allow. Its denial constructor at lines 636-668 appends a fallback, so notification protected-open needs a separate no-fallback halt path rather than reusing it blindly.

**Swift tests:** follow `ActivationConformanceTests.swift` lines 22-78 helper/factory structure. Add deterministic tests for bounded queue eviction, offline no-activation, reconnect single consumption, replay/expiry/revocation/route-action removal denial, and no fallback presentation on notification denial.

### Host registry model and persistence

The example Phoenix host is the closest executable analog for the adopter-owned Ecto implementation:

- `examples/phoenix_host/lib/crosswake_example/chimeway/registry.ex` — transaction plus `repo.update_all` exact active-revision predicates (observed at lines 254-266 and 526-539).
- `examples/phoenix_host/lib/crosswake_example/chimeway/token_binding.ex` — scoped `TokenBinding` model and constraints (fields begin at lines 21-43; unique binding ref at lines 108-115).
- `examples/phoenix_host/test/crosswake_example/chimeway/registry_notification_open_test.exs` — issue/consume and exact binding tests at lines 51-212.

Copy the test’s `async: false`, unique opaque refs, inserted active binding setup (lines 1-48), and post-consume state/event assertions (lines 122-159). Strengthen its implementation with one transactional predicate covering scope + current revision + active state + unconsumed + expiry + session/version; do not broaden invalidation by installation alone.

## Shared Patterns

### Fail closed and no fallback

**Sources:** `resolver.ex` lines 20-62; `route_gate.ex` lines 66-85.  
**Apply to:** resolver, host consumer result projection, queue drain, native activation.  
Unknown/malformed state, missing route, missing action policy, consumer error, and auth denial must activate nothing.

### Privacy boundary

**Sources:** `contracts.ex` lines 593-611; `redaction.ex` lines 74-101; `denial_codes.ex` lines 39-47; `telemetry.ex` lines 119-167.  
**Apply to:** token observation, queue records, intents, denials, telemetry, logs, test fixtures.  
Use opaque refs/fingerprints and closed scalar metadata only.

### Test evidence

**Sources:** `resolver_test.exs` lines 16-27 and 71-156; `registry_notification_open_test.exs` lines 51-212; `ActivationConformanceTests.swift` lines 22-118.  
**Apply to:** every OPEN-01 through OPEN-04 case. Use executable ExUnit/XCTest race and denial tables, not human UAT.

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `NotificationOpenQueue.swift` (new) | local queue/store | file-I/O/event-driven | No existing notification-open queue; combine bounded local store conventions with the existing delegate/config seam. |

## Metadata

**Analog search scope:** `../crosswake/lib`, `../crosswake/packages/crosswake_chimeway`, `../crosswake/packages/crosswake-shell-core-ios`, `../crosswake/examples/phoenix_host`, and associated tests.  
**Files scanned:** 31 targeted source/test files.  
**Pattern extraction date:** 2026-08-22
