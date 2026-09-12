# Phase 98: Privacy-Safe Delivery Evidence - Research

**Researched:** 2026-08-12  
**Domain:** Elixir/Ecto durable privacy boundary and explainable delivery evidence  
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

### One Recursive Privacy Boundary

- **D-01:** Establish one core, atom-safe recursive privacy boundary for maps, lists, and keyword-shaped values. It must normalize atom and string keys case-insensitively without creating atoms from caller-controlled input.
- **D-02:** Apply the shared boundary before every Chimeway persistence write and diagnostic projection. Surface-specific shallow filters may remain only as defense-in-depth; they are not the privacy contract.
- **D-03:** Forbidden keys and their values are removed recursively rather than masked inside otherwise retained sensitive blobs. Nested and mixed-case forms must behave identically.

### Opaque Durable Evidence, Not Sanitized Sensitive Blobs

- **D-04:** Raw device tokens, endpoints, credentials, recipient or adopter data, trusted deep links, rendered content, and provider bodies are prohibited at Chimeway-owned write boundaries.
- **D-05:** Durable evidence is explicit and allowlisted: opaque references or fingerprints, stable outcomes and error classifications, lifecycle identifiers and timestamps, render identity, and narrowly allowlisted provider facts.
- **D-06:** Do not retain redacted provider bodies or generic diagnostic maps as a fallback. Explainability must come from structured safe facts, not sanitized copies of sensitive source material.

### Explainability Through Safe Projections

- **D-07:** Delivery traces, attempt results, telemetry, logs, admin DTOs, and proof artifacts share one safe evidence vocabulary and never expose raw lifecycle schemas or uncontrolled diagnostic values.
- **D-08:** Preserve the facts operators need to explain behavior—status, reason, classification, timeline, timestamps, render identity, and opaque identifiers—while excluding raw identity, content, endpoint, credential, link, and provider-controlled values.
- **D-09:** Core API and projection boundaries must be safe independently of `chimeway_admin`. View-layer recipient masking and timeline allowlisting remain defense-in-depth, not the primary privacy control.

### the agent's Discretion

- Exact module and function names for the shared recursive privacy boundary.
- Exact forbidden-key taxonomy and safe provider-fact allowlist, provided they cover PRIV-03/PRIV-04 fixtures, are case-normalized, and default closed for diagnostic blobs.
- Exact opaque-reference and fingerprint representation, provided it is stable enough for correlation, cannot recover the source value, and does not transfer host-owned identity or credential custody into Chimeway.
- Exact internal migration or compatibility mechanics for existing generic JSON fields, provided new writes cannot retain prohibited data and existing lifecycle explainability remains intact.

### Deferred Ideas (OUT OF SCOPE)

None — analysis stayed within Phase 98 scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PRIV-03 | Nested maps, lists, and keyword-shaped values are recursively redacted with case-normalized forbidden-key handling before persistence, telemetry, logs, traces, DTOs, and proof output. | A single term walker must be invoked at every write/projection boundary and proven with adversarial nested map/list/keyword fixtures. [VERIFIED: codebase grep] |
| PRIV-04 | Raw device tokens, credentials, recipient or adopter data, trusted deep links, and provider bodies never enter Chimeway-owned storage or diagnostics; only opaque references, fingerprints, stable classifications, and allowlisted provider facts are retained. | Replace generic evidence blobs and raw identity projections with a closed structured evidence vocabulary; verify persisted rows, emitted metadata/logs, DTOs, traces, and proof text all reject sentinel values. [VERIFIED: codebase grep] |
</phase_requirements>

## Summary

Phase 98 is a core data-contract correction, not an Admin UI masking pass. The current `Trigger` and `Deliveries` sanitizers only remove a small, shallow set of keys; `Deliveries` still persists arbitrary `provider_response`, `metadata`, `planning_context`, and `render_data`, while `Traces.Explanation`, `Admin`, telemetry, and the logger adapter currently project raw recipient/correlation or generic values. [VERIFIED: codebase grep]

Implement one pure `Chimeway.Privacy` boundary that recursively traverses maps, ordinary lists, and keyword-shaped lists; canonicalizes only the comparison form of atom/string keys with `to_string/1` and `String.downcase/1`; and never calls `String.to_atom/1`. Elixir maps may use arbitrary key types and keyword lists are two-tuple lists with atom keys, so a shape-aware walker is required rather than `Map.drop/2` at one level. [CITED: https://hexdocs.pm/elixir/keywords-and-maps.html]

Then make explainability typed and closed: store/projection fields such as lifecycle IDs, opaque refs/fingerprints, outcome, error classification, timestamps, render key/version, fixed reason vocabulary, and a small provider-fact map whose keys and values are validated. Do not preserve a redacted copy of a provider response or a generic diagnostic map. The existing trace timeline, `last_attempt` summary, and release-proof allowlist demonstrate that stable lifecycle facts already explain most behavior without provider bodies. [VERIFIED: codebase grep]

**Primary recommendation:** Introduce `Chimeway.Privacy` as the sole recursive term sanitizer plus explicit `safe_evidence` builders at persistence and diagnostic edges; migrate/write only structured safe evidence and have all trace/admin/telemetry/log/proof output consume those builders.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Recursive redaction of caller/provider diagnostics | API / Backend | Database / Storage | The pure core boundary must execute before Ecto writes and diagnostic emissions; the database should never receive forbidden values. [VERIFIED: codebase grep] |
| Durable opaque evidence and safe attempt facts | Database / Storage | API / Backend | Durable schemas/JSON columns carry only the fixed evidence vocabulary; contexts validate/build it. [VERIFIED: codebase grep] |
| Trace, DTO, proof, telemetry, and Logger projections | API / Backend | Frontend Server (SSR) | Core contexts create safe projections independently; Admin/LiveView display them as defense-in-depth. [VERIFIED: codebase grep] |
| Recipient/endpoint/credential custody | Host application | API / Backend | The locked boundary keeps host-owned raw identity and credentials outside Chimeway; Chimeway correlates via non-reversible opaque references only. [VERIFIED: 98-CONTEXT.md] |
| Migration of existing generic evidence | Database / Storage | API / Backend | A copied migration must eliminate or neutralize legacy sensitive blobs in both static storage-prefix modes. [VERIFIED: codebase grep] |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Elixir standard library | project requires `~> 1.17`; local OTP 28 | Pure recursive term traversal, key normalization, fixed literal output keys. | No dependency is needed for maps/lists/keywords; use existing atoms and string comparisons only. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/elixir/keywords-and-maps.html] |
| `ecto` / `ecto_sql` | locked 3.13.6 / 3.13.5 | Changesets, transactions, copied migrations, PostgreSQL JSON/map persistence. | Already owns all Chimeway lifecycle persistence and migrations. [VERIFIED: mix.lock] |
| `:telemetry` / Logger | locked 1.4.2 / Elixir stdlib | Fixed diagnostic event metadata and default logs. | Existing `Chimeway.Telemetry` is the central event seam; Logger metadata can be process- or call-scoped and must be bounded before use. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/logger/Logger.html] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Existing `Chimeway.Telemetry` | project internal | Metadata allowlist and default logger handler. | Replace its current “allowed key, arbitrary value” model with safe-evidence projection/value validation. [VERIFIED: codebase grep] |
| Existing `Chimeway.Traces.Explanation` | project internal | Operator-facing typed trace contract. | Narrow fields to opaque IDs and structured safe evidence; do not return raw Ecto schemas. [VERIFIED: codebase grep] |
| Existing release-gate artifact fixture | project internal | Machine-readable proof allowlist. | Extend this established evidence contract instead of introducing a parallel proof format. [VERIFIED: codebase grep] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| One core recursive boundary | Per-surface shallow `Map.drop`/view masks | Rejected: it misses nested map/list/keyword values and contradicts D-01/D-02. [VERIFIED: 98-CONTEXT.md] |
| Typed, allowlisted provider facts | Persisting a redacted provider body | Rejected by D-05/D-06: a sanitized blob has uncontrolled shape and provides a future leak path. [VERIFIED: 98-CONTEXT.md] |
| Opaque reference supplied/generated by a bounded contract | Reversible encryption or raw identity hash of host-owned data | Rejected: retaining/recovering source identity moves custody into Chimeway; a fingerprint must be non-reversible and domain-separated. [VERIFIED: 98-CONTEXT.md] |

**Installation:** No external packages. Use the locked project stack; therefore no package legitimacy audit is required. [VERIFIED: mix.exs]

## Architecture Patterns

### System Architecture Diagram

```text
Host/provider input (may contain endpoint, credential, recipient, link, body)
  -> Chimeway.Privacy.drop_forbidden_recursive/1
       map / list / keyword traversal; case-normalized comparison; no atom creation
  -> explicit safe-evidence builder
       accepts only fixed facts: opaque refs, status/reason/classification,
       IDs, timestamps, render identity, narrow provider facts
  -> Ecto write boundaries
       Event/Notification/Delivery/Attempt fields and metadata patches
  -> durable safe lifecycle rows
  -> one projection vocabulary
       Trace Explanation -> Admin DTO / LiveView
       Telemetry.safe_meta -> :telemetry handlers -> default Logger
       proof builder -> machine-readable proof text

Any generic diagnostic map/provider body/raw identity
  -> rejected/dropped before write and omitted from every projection
```

### Recommended Project Structure

```text
lib/chimeway/
├── privacy.ex                      # atom-safe recursive walker and forbidden-key taxonomy
├── safe_evidence.ex                # closed constructors/projections and provider-fact allowlist
├── trigger.ex                      # event/notification write boundary
├── deliveries.ex                   # delivery, planning, recovery, attempt write boundaries
├── dispatch/executor.ex            # classify adapter result into safe facts only
├── telemetry.ex                    # typed metadata projection and bounded Logger event data
├── traces.ex                       # safe explanation/timeline construction
└── admin.ex                        # safe core DTOs, no raw identity/schema return
test/chimeway/
├── privacy_test.exs                # recursive map/list/keyword and atom-safety regression tests
├── privacy_boundary_test.exs       # DB, trace, DTO, telemetry, log, proof sentinel leak matrix
└── ...existing focused suites...   # Trigger/Deliveries/Telemetry/Traces/Admin updates
priv/chimeway_migrations/
└── 033_privacy_safe_delivery_evidence.exs # copied migration template and matching fixtures
```

### Pattern 1: Shape-aware, atom-safe recursive removal

**What:** Accept any term. For a map, iterate pairs; for any key whose canonical comparison string is forbidden, omit the pair and do not traverse/retain its value; otherwise retain the original key and recurse into its value. For a list, preserve ordinary list order while recursing each item; if `Keyword.keyword?/1` is true, recurse each keyword value and omit forbidden entries while preserving the original atom key. Scalars pass through only when the enclosing typed evidence builder permits their field. [CITED: https://hexdocs.pm/elixir/keywords-and-maps.html]

**When to use:** Before every persistence mutation and before any diagnostic projection. The term walker is a removal boundary; `SafeEvidence` decides whether a remaining field/value is eligible for durable evidence. [VERIFIED: 98-CONTEXT.md]

```elixir
# Source: locked D-01..D-03 + Elixir maps/keywords docs
def drop_forbidden(value) when is_map(value) do
  Map.new(value, fn {key, child} -> {key, drop_forbidden(child)} end)
  |> Map.reject(fn {key, _child} -> forbidden_key?(key) end)
end

def drop_forbidden(value) when is_list(value) do
  if Keyword.keyword?(value) do
    Enum.reduce(value, [], fn {key, child}, acc ->
      if forbidden_key?(key), do: acc, else: [{key, drop_forbidden(child)} | acc]
    end)
    |> Enum.reverse()
  else
    Enum.map(value, &drop_forbidden/1)
  end
end

def drop_forbidden(value), do: value

defp forbidden_key?(key) when is_atom(key), do: forbidden_key?(Atom.to_string(key))
defp forbidden_key?(key) when is_binary(key), do: String.downcase(key) in @forbidden_keys
defp forbidden_key?(_), do: false
```

Do not turn a caller string into an atom; retain a key unchanged or map it only through compile-time literal keys. [VERIFIED: 98-CONTEXT.md]

### Pattern 2: Closed evidence constructors at writes, closed projections at reads

**What:** Replace `provider_response: sanitize_metadata(response)` and generic JSON pass-through with a constructor that selects a small fixed shape, validates scalar types/enums, and returns `{:error, :unsafe_evidence}` (or drops the unknown fact) for uncontrolled diagnostics. Store no `provider_response` body fallback. Build `Trace`, Admin, telemetry, log, and proof maps from the same public vocabulary rather than from schemas. [VERIFIED: codebase grep]

```elixir
# Source: locked D-05..D-08 + existing trace summary pattern
@provider_fact_keys ~w(provider_code retry_after_ms accepted_at)a

def attempt_evidence(%{outcome: outcome, error_class: class} = attrs) do
  %{}
  |> put_required(:outcome, normalize_outcome(outcome))
  |> put_optional(:error_class, normalize_error_class(class))
  |> put_optional(:provider_facts, allowlisted_provider_facts(attrs[:provider_facts]))
end

def telemetry_meta(evidence) do
  Map.take(evidence, [:delivery_id, :attempt_id, :outcome, :error_class, :classification])
end
```

### Pattern 3: Compatibility migration treats existing generic blobs as unsafe

**What:** Add a copied, prefix-aware migration that clears/replaces unsafe persisted generic diagnostic fields and backfills only deterministic safe facts derivable without inspecting/retaining sensitive contents. If a safe value cannot be derived, leave it absent and preserve explanation through lifecycle timestamps/status/reason instead. Extend the existing copied-migration generator/golden fixtures and runtime-prefix proof for both `prefix: "chimeway"` and `prefix: false`. [VERIFIED: codebase grep]

**Why:** Ecto migrations support intentional schema changes; the project already uses copied migration templates and validates both storage modes. [CITED: https://hexdocs.pm/ecto_sql/3.13.5/Ecto.Migration.html] [VERIFIED: codebase grep]

### Anti-Patterns to Avoid

- **`String.to_atom/1` / dynamically created atoms:** Forbidden for caller/provider keys; only compare normalized strings to a compile-time list. [VERIFIED: 98-CONTEXT.md]
- **“Sanitize then persist arbitrary response”:** Removing `token`/`secret` from a provider body still stores uncontrolled endpoint/content/identity fields. Replace with typed facts. [VERIFIED: 98-CONTEXT.md]
- **Projection-only privacy:** `ChimewayAdmin.Redaction` is useful defense-in-depth but cannot make an already-persisted raw value safe. [VERIFIED: codebase grep]
- **Allowlisted key with unvalidated value:** `Telemetry.safe_meta/1` currently takes known keys but retains their values; opaque IDs/reasons/classifications require type/value bounds too. [VERIFIED: codebase grep]
- **Interpolating `inspect(reason)` into logs:** Unknown adapter returns can embed provider-controlled terms. Log a stable classification and safe IDs only. [VERIFIED: codebase grep]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Durable privacy policy split across callers | New local scrubber per context/view | One `Chimeway.Privacy` term walker + `SafeEvidence` constructors | One contract covers mixed key casing/nesting and prevents drift. [VERIFIED: 98-CONTEXT.md] |
| Provider-response explainability | Generic JSON archive with regex masks | Fixed provider-fact allowlist and stable classifications | D-06 explicitly rejects a retained sanitized body. [VERIFIED: 98-CONTEXT.md] |
| Operator evidence | Raw Ecto schema serialization | Existing DTO/explanation/proof pattern, narrowed to safe facts | Current project already proves small DTO and proof maps. [VERIFIED: codebase grep] |
| Migration rollout | Runtime DDL or host-side ad hoc scrubber | Existing copied Ecto migration templates and prefix golden tests | Keeps static storage modes deterministic. [VERIFIED: codebase grep] |

**Key insight:** Redaction is necessary for untrusted incoming diagnostics, but allowlisting—not redaction—is the durable evidence policy. [VERIFIED: 98-CONTEXT.md]

## Runtime State Inventory

| Category | Items Found | Action Required |
|----------|-------------|-----------------|
| Stored data | `events.payload`, notification `metadata`/`render_assigns`, delivery `metadata`/`planning_context`/`render_data`, and attempt `provider_response` are persisted map fields; current write paths can retain uncontrolled data. [VERIFIED: codebase grep] | Data migration plus code edits: clear/replace unsafe existing evidence and prevent new writes; preserve only fixed lifecycle facts. |
| Live service config | No external provider or observability configuration is tracked as Chimeway-owned runtime state for this phase. [VERIFIED: repository inspection] | None in repository; document that host-owned telemetry handlers must only receive the bounded Chimeway metadata. |
| OS-registered state | None found in repository inspection. [VERIFIED: repository inspection] | None. |
| Secrets/env vars | No Phase-98 privacy key or secret-retention configuration found in tracked configuration. [VERIFIED: repository inspection] | None; do not add a “retain raw for debugging” switch. |
| Build artifacts | Copied migrations and committed public/prefixed migration fixtures reflect the schema template count and output. [VERIFIED: codebase grep] | Update template, generated fixtures, golden diff, migration contract, and runtime-prefix evidence. |

## Common Pitfalls

### Pitfall 1: Recursing maps but not keyword lists

**What goes wrong:** Sensitive data in `[Authorization: ..., nested: [...]]` escapes a map-only sanitizer.  
**Why it happens:** Keyword lists are lists of atom-keyed pairs, not maps. [CITED: https://hexdocs.pm/elixir/keywords-and-maps.html]  
**How to avoid:** Branch on `Keyword.keyword?/1`, remove forbidden entries, and recurse their values; test mixed map/list/keyword nesting with casing variants. [VERIFIED: 98-CONTEXT.md]  
**Warning signs:** Tests only construct `%{}` or assert a key is missing at the root. [VERIFIED: codebase grep]

### Pitfall 2: “Safe” projection leaks an unsafe value

**What goes wrong:** A known key such as `:correlation_id`, `:adapter_module`, or `:provider_message_id` carries endpoint/identity/content.  
**Why it happens:** Current telemetry allows known keys but does not enforce a value contract, and core traces/admin still return raw identity fields. [VERIFIED: codebase grep]  
**How to avoid:** Give every exported fact an explicit scalar format or enum; use opaque references instead of raw recipient/correlation/provider IDs. [VERIFIED: 98-CONTEXT.md]  
**Warning signs:** Any projection uses `Map.take` over an arbitrary map or passes an Ecto field through unvalidated. [VERIFIED: codebase grep]

### Pitfall 3: Log/error path bypasses the regular sanitizer

**What goes wrong:** Normal success uses safe facts, but failure logs `inspect(reason)` or an exception/provider body.  
**Why it happens:** Error/exception paths are separate diagnostic surfaces; Logger can include invocation/process metadata. [CITED: https://hexdocs.pm/logger/Logger.html]  
**How to avoid:** Classify adapter outcomes before logging and test captured logs for every sentinel; emit only fixed event names, classification, and opaque lifecycle IDs. [VERIFIED: codebase grep]  
**Warning signs:** String interpolation of arbitrary terms or direct `Logger.metadata()` propagation. [VERIFIED: codebase grep]

### Pitfall 4: Cleaning new writes while historical blobs remain readable

**What goes wrong:** New paths are safe but old JSON fields remain in existing rows or copied-migration fixtures.  
**Why it happens:** Ecto schema changes do not automatically rewrite prior values. [CITED: https://hexdocs.pm/ecto_sql/3.13.5/Ecto.Migration.html]  
**How to avoid:** Make legacy cleanup a migration task with public/prefixed fixture coverage; do not rely on read-side masking as the retention fix. [VERIFIED: codebase grep]  
**Warning signs:** A migrated database can still find fixture sentinels via direct Repo reads. [VERIFIED: codebase grep]

## Code Examples

### Cross-surface sentinel leak test

```elixir
# Source: existing Trigger/Telemetry/Traces/Admin privacy fixtures, strengthened for PRIV-03/04
sentinels = [
  "apns-token-98", "Bearer credential-98", "recipient@example.test",
  "https://trusted.example/open/98", "provider-body-98"
]

assert {:ok, %{delivery: delivery}} = run_adversarial_delivery(nested_input_with(sentinels))

persisted = reload_all_lifecycle_rows(delivery.id)
assert_no_sentinel(persisted, sentinels)
assert_no_sentinel(explain_delivery!(delivery.id), sentinels)
assert_no_sentinel(admin_dtos_for(delivery), sentinels)
assert_no_sentinel(received_telemetry(), sentinels)
assert_no_sentinel(capture_log(&emit_failure/0), sentinels)
assert_no_sentinel(build_proof!(delivery), sentinels)
```

### Safe evidence projection

```elixir
# Source: locked D-05/D-07; all keys are literals and values are validated.
def trace_attempt(%DeliveryAttempt{} = attempt) do
  %{
    attempt_ref: opaque_ref(attempt.id),
    outcome: attempt.outcome,
    classification: safe_error_class(attempt.error_class),
    recorded_at: attempt.inserted_at
  }
  |> maybe_put(:provider_facts, SafeEvidence.provider_facts(attempt))
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Shallow sensitive-key removal per module | One recursive, case-normalized core boundary plus typed allowlisted evidence | Phase 98 | Closes nesting/casing bypasses and prevents sensitive diagnostic retention. [VERIFIED: 98-CONTEXT.md] |
| UI masking/raw-schema avoidance | Safe core projections before optional Admin rendering | Phase 98 | Core API, telemetry, logs, and proof become safe without `chimeway_admin`. [VERIFIED: 98-CONTEXT.md] |
| Generic sanitized provider response | Stable classification plus narrow provider facts | Phase 98 | Explainability no longer depends on a retained provider-controlled blob. [VERIFIED: 98-CONTEXT.md] |

**Deprecated/outdated:** The private `Trigger.sanitize_map/1` and `Deliveries.sanitize_metadata/1` shallow filters are inadequate as privacy contracts; retain no competing policy after the shared boundary lands. [VERIFIED: codebase grep]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The host supplies each tenant/domain-bound opaque `cw_...` reference; Chimeway validates and persists it but never derives it from raw identity, endpoint, token, credential, correlation, or provider data. [RESOLVED: 98-CONTEXT.md D-04/D-05 and 98-01/98-02 plans] | Architecture Patterns | Rotation/versioning remains host-owned; a changed reference is supplied explicitly and does not require Chimeway to retain source material. |
| A2 | A single migration can remove/neutralize legacy sensitive JSON without breaking an existing adopter’s required operational behavior. [ASSUMED] | Pattern 3 | Migration may need staged compatibility or explicit host migration documentation. |

## Open Questions (RESOLVED)

1. **Opaque-reference source and rotation semantics**
   - Resolution: The host/provider supplies a pre-opaque, domain-tagged, bounded `cw_...` reference. Chimeway validates and persists that value exactly; it never hashes, encrypts, fingerprints, or otherwise derives a reference from raw identity, endpoint, token, credential, correlation, or provider data. Rotation/versioning is therefore host-owned: callers supply a new opaque reference when their correlation key changes. [RESOLVED: 98-CONTEXT.md D-04/D-05; 98-01 Task 1; 98-02 Task 1]

2. **Legacy raw-recipient data required by Inbox compatibility**
   - Resolution: Inbox list/count and read/seen/archive mutations accept the same validated host-supplied tenant/domain-bound opaque recipient reference that Trigger persists in the existing physical identity column. The predicate is the resolved tenant plus that opaque reference; post-update reloads use the identical predicate. Existing pagination, ordering, idempotency, and wrong-tenant/absent/unknown-recipient result semantics remain unchanged, while raw host identity stays outside Chimeway storage, signals, logs, telemetry, and DTOs. [RESOLVED: 98-CONTEXT.md D-02/D-04/D-08/D-09; 98-02 Task 2]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Elixir/Mix | implementation and ExUnit suites | ✓ | Elixir project requires `~> 1.17`; local OTP 28 | — [VERIFIED: mix.exs] |
| PostgreSQL CLI | Ecto migration/runtime validation | ✓ | local `psql` 14.17; project contract is PostgreSQL 15+ | Existing project test database workflow. [VERIFIED: local CLI; AGENTS.md] |
| Existing Ecto/Telemetry dependencies | lifecycle persistence and diagnostics | ✓ | Ecto 3.13.6, Ecto SQL 3.13.5, Telemetry 1.4.2 locked | — [VERIFIED: mix.lock] |

**Missing dependencies with no fallback:** None. [VERIFIED: local CLI]

**Missing dependencies with fallback:** None. [VERIFIED: local CLI]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit with Ecto SQL/PostgreSQL integration. [VERIFIED: mix.exs] |
| Config file | `test/test_helper.exs` and `config/test.exs`. [VERIFIED: codebase grep] |
| Quick run command | `env MIX_ENV=test mix test test/chimeway/privacy_test.exs test/chimeway/privacy_boundary_test.exs test/chimeway/trigger_sanitization_test.exs test/chimeway/telemetry_integration_test.exs test/chimeway/traces_test.exs test/chimeway/admin_test.exs --warnings-as-errors` |
| Full suite command | `mix ci` (local/CI parity entrypoint). [VERIFIED: mix.exs; AGENTS.md] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PRIV-03 | Case-insensitive recursion removes forbidden keys/values through maps, ordinary lists, and keyword lists; no runtime atom allocation path. | unit | `env MIX_ENV=test mix test test/chimeway/privacy_test.exs --warnings-as-errors` | ❌ Wave 0 |
| PRIV-03 | Every persistence and diagnostic boundary invokes shared privacy/evidence projection rather than a local shallow filter. | integration | `env MIX_ENV=test mix test test/chimeway/privacy_boundary_test.exs --warnings-as-errors` | ❌ Wave 0 |
| PRIV-04 | Sentinel token, credential, recipient, link, and provider body do not exist in persisted lifecycle rows, trace, DTO, telemetry, captured log, or proof output. | integration | `env MIX_ENV=test mix test test/chimeway/privacy_boundary_test.exs test/chimeway/telemetry_integration_test.exs test/chimeway/traces_test.exs test/chimeway/admin_test.exs --warnings-as-errors` | ❌ Wave 0 (focused existing suites exist) |
| PRIV-04 | Copied migration removes/neutralizes legacy unsafe evidence under public and prefixed storage modes. | migration/integration | `mix verify.install_golden && mix verify.runtime_prefix` | Existing infrastructure; Phase-specific cases ❌ Wave 0. [VERIFIED: mix.exs] |

### Sampling Rate

- **Per task commit:** Run the touched focused ExUnit command with `--warnings-as-errors`. [VERIFIED: mix.exs]
- **Per wave merge:** `mix ci` plus `mix verify.install_golden`/`mix verify.runtime_prefix` for migration work. [VERIFIED: mix.exs]
- **Phase gate:** Full suite green before `$gsd-verify-work`; PRIV-03/PRIV-04 are objectively machine-testable and must use executable evidence, not conversational UAT. [VERIFIED: AGENTS.md]

### Wave 0 Gaps

- [ ] `test/chimeway/privacy_test.exs` — recursion, case normalization, keyword/mixed shape, and atom-safety regression coverage for PRIV-03.
- [ ] `test/chimeway/privacy_boundary_test.exs` — one adversarial sentinel matrix that asserts no Chimeway-owned storage or diagnostics leak for PRIV-03/PRIV-04.
- [ ] Extend existing Trigger, Deliveries, Telemetry, Traces, Admin, release-gate, migration golden, and runtime-prefix suites with phase-specific assertions. [VERIFIED: codebase grep]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Host retains authentication and identity authority; this phase must not invent a Chimeway auth store. [VERIFIED: AGENTS.md] |
| V3 Session Management | no | No session protocol is introduced; do not place host session/adopter data in evidence. [VERIFIED: 98-CONTEXT.md] |
| V4 Access Control | yes | Preserve Phase 97 tenant-scoped core access while projections return only safe evidence. [VERIFIED: codebase grep] |
| V5 Input Validation | yes | Recursive key comparison plus typed, closed evidence constructors at every write/diagnostic boundary. [VERIFIED: 98-CONTEXT.md] |
| V6 Cryptography | no | The resolved contract accepts host/provider-supplied opaque references and performs no Chimeway-owned fingerprinting, encryption, or derivation from raw values. [RESOLVED: Open Questions; 98-01/98-02 plans] |

### Known Threat Patterns for Elixir/Ecto diagnostics

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Nested/mixed-case forbidden key evades shallow sanitizer | Information disclosure | One recursive case-normalized walker applied before all writes/projections. [VERIFIED: 98-CONTEXT.md] |
| Provider-controlled response body reaches JSON/trace/log | Information disclosure | Reject generic response blobs; persist only allowlisted typed facts/classifications. [VERIFIED: 98-CONTEXT.md] |
| Untrusted string converted to atom | Denial of service | Never create atoms from input; compare string forms and output only literals. [VERIFIED: 98-CONTEXT.md] |
| Failure path inspects arbitrary adapter return | Information disclosure | Convert to stable `unknown_classification` and log bounded safe evidence only. [VERIFIED: codebase grep] |
| Cross-tenant safe fact accidentally joins unsafe row | Information disclosure | Retain Phase 97 tenant predicates for all lifecycle/projection queries. [VERIFIED: codebase grep] |

## Sources

### Primary (HIGH confidence)

- Project codebase (`lib/chimeway/trigger.ex`, `deliveries.ex`, `telemetry.ex`, `traces.ex`, `admin.ex`, `dispatch/executor.ex`, schemas and focused tests) — current write/projection/leak seams and established contracts. [VERIFIED: codebase grep]
- [Phase 98 CONTEXT.md](./98-CONTEXT.md) — binding D-01 through D-09 privacy decisions. [VERIFIED: 98-CONTEXT.md]
- [AGENTS.md](../../../AGENTS.md) — host ownership and executable-verification constraints. [VERIFIED: AGENTS.md]

### Secondary (MEDIUM confidence)

- [Elixir maps and keywords](https://hexdocs.pm/elixir/keywords-and-maps.html) — maps accept arbitrary key types; keyword lists are atom-keyed pair lists.
- [Elixir Logger](https://hexdocs.pm/logger/Logger.html) — Logger metadata sources and per-call/process metadata behavior.
- [Ecto SQL migrations](https://hexdocs.pm/ecto_sql/3.13.5/Ecto.Migration.html) — deliberate migration/schema-change mechanics.

### Tertiary (LOW confidence)

- None beyond the two assumptions explicitly listed above.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new dependency; locked versions and existing internal seams are directly verified. [VERIFIED: mix.lock]
- Architecture: HIGH — locked Phase 98 decisions align with concrete current write/projection seams. [VERIFIED: 98-CONTEXT.md; codebase grep]
- Pitfalls: HIGH — each reflects a current shallow/generic data path or a locked privacy constraint. [VERIFIED: codebase grep; 98-CONTEXT.md]

**Research date:** 2026-08-12  
**Valid until:** 2026-09-11 (stable internal architecture; revisit if the opaque-reference decision changes). [ASSUMED]
