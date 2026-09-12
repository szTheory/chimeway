# Phase 102: Alpha Digital Twin & Hermetic Gate - Research

**Researched:** 2026-08-25
**Domain:** Hermetic cross-repository Elixir/Phoenix integration proof and CI gating
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

### Clean-Room Alpha Host and Repository Boundaries

- **D-01:** Build one dedicated, committed, sanitized Adopter Alpha test host/fixture for this phase. Do not retrofit the general Chimeway demo host or the existing CrossWake example host into the Alpha twin.
- **D-02:** The host must consume Chimeway from one immutable built package artifact, apply the real copied Chimeway migrations to PostgreSQL, and exercise the public trigger, planning, dispatch, recovery, trace, and explanation paths. A unit-only harness or proof that substitutes direct Chimeway lifecycle-row inserts is insufficient.
- **D-03:** The host must consume the real `crosswake` and `crosswake_chimeway` public contracts from a sibling checkout pinned to a full immutable commit SHA. CrossWake remains authoritative for manifest normalization, notification-open resolution, RouteGate evaluation, and its existing physical-iPhone evidence contract.
- **D-04:** Keep token material, binding lifecycle authority, eligibility, and one-time open intents in explicit host-owned fixture components. Chimeway and CrossWake may receive only the already-locked opaque references, fingerprints, classifications, and closed safe facts.

### Deterministic Scenario Ledger and Evidence

- **D-05:** Define one closed, versioned scenario ledger as the source of truth for the twin. Host, Chimeway, scripted APNs transport, and CrossWake proof consumers must execute or validate the same ordered scenario identities rather than maintain disconnected happy-path fixtures.
- **D-06:** Add the narrowest injectable clock seam needed along the exercised Chimeway target/APNs/recovery and host/CrossWake open-resolution boundaries. Production defaults remain the system clock; the twin advances a fixed clock explicitly and must not use wall-clock sleeps for expiry, retry, lease, or replay assertions.
- **D-07:** Use a scripted fake APNs transport behind the shipped transport behaviour. It must observe the real bounded request and return ordered accepted, retryable, permanent, exact-invalidation, and ambiguous-handoff outcomes without Pigeon network I/O, Apple credentials, or a provider emulator.
- **D-08:** The mandatory matrix is exact and merge-blocking: two-installation fan-out; zero-target suppression; token rotation and revocation races; reason-classified retry; expiry; opt-in, installation-safe collapse; trigger-commit recovery; post-handoff crash ambiguity; recursive leak prevention; offline open queue/reauthorization; denial; and replay rejection.
- **D-09:** Each scenario must assert durable lifecycle truth through real repository and public explanation surfaces, not only returned function values. The proof must demonstrate convergence/uniqueness and preserve the distinction between local intent, provider acceptance, invalidation, protected open, inbox seen, and inbox read.
- **D-10:** Emit one closed, allowlisted, machine-readable proof summary only after scanning persisted safe facts, traces, telemetry captures, exception/error output, transport observations, and final proof bytes for recursive leak sentinels. Unknown fields and uncontrolled diagnostic maps fail closed; raw tokens, identity, URLs, payloads, credentials, and provider bodies never appear in proof output.

### Verification Gates and Physical-Proof Contract

- **D-11:** Chimeway owns two named entrypoints: `mix verify.alpha_twin` for the hermetic production-path scenario and `mix verify.physical_proof_contract` for malformed/valid future evidence fixtures. Both commands must be deterministic, credential-free, non-interactive, and independently rerunnable.
- **D-12:** Add a dedicated `verify_alpha_twin` CI job that checks out CrossWake at the locked full SHA, runs both entrypoints, and is required by both `pr-gate` and `ci-gate`. Extend `mix ci.verify_gates` contract tests so local aliases, checkout provenance, commands, job result aggregation, and required-gate membership cannot drift.
- **D-13:** Proof output must record or cryptographically bind the exact Chimeway artifact digest and CrossWake implementation SHA used by the run. A floating branch, mutable tag, unvalidated local tree, or evidence from mismatched revisions cannot satisfy the gate.
- **D-14:** Define a versioned Chimeway mobile-proof extension for Phase 103 that references the canonical CrossWake Phase 162 evidence rather than copying or reinterpreting it. The extension must separate executable facts (permission state, authenticated registration, APNs provider acceptance, one-time protected activation, replay denial) from the explicitly subjective visible-alert observation.
- **D-15:** Physical-proof contract validation must reject missing, duplicate, reordered, unknown, wrong-owner, wrong-proof-class, sensitive, malformed, or revision-mismatched evidence. CI validates schemas and negative fixtures only; it never requires Apple credentials or claims that a physical display was observed.

### the agent's Discretion

- Exact module, fixture-directory, scenario-ledger, and proof-summary names beyond the two locked Mix task names.
- Exact internal clock behaviour/configuration shape, provided injection is narrow, production defaults are unchanged, and every time-sensitive twin assertion is sleep-free.
- Exact JSON or line-oriented encoding for the scenario ledger and proof summary, provided schemas are closed, versioned, bounded, deterministic, non-echoing, and atom-safe.
- Exact CI caching and job-internal decomposition, provided the immutable CrossWake provenance and required-gate parity are executable contracts.
- Exact stable rule IDs for malformed evidence, provided failures identify only a closed rule/path and never echo rejected sensitive values.

### Deferred Ideas (OUT OF SCOPE)

- Real APNs sandbox dispatch, physical-iPhone visible-alert confirmation, and retained dated device evidence — Phase 103 after the CrossWake Phase 162 Apple signing/provisioning gate is satisfied.
- Integration and operator documentation covering setup, migrations, outcome vocabulary, offline behavior, proof commands, and non-goals — Phase 103 (DOCS-01).
- FCM/Android transport, generic background/offline sync, engagement analytics, rich actions, and broad device management remain outside v1.18 scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TWIN-01 | Sanitized Alpha host uses real persistence, deterministic time, host token registry, and scripted APNs. | Dedicated packaged fixture, real copied migrations, host-owned registry, a clock behaviour, and the existing APNS transport seam. |
| TWIN-02 | Hermetic proof covers required delivery, recovery, privacy, and protected-open matrix. | One versioned ordered ledger drives a process-level proof and durable repository/explanation assertions. |
| GATE-01 | Named `mix verify.*` commands run in CI without Apple credentials and validate the future physical-proof contract. | Two locked Mix tasks, dedicated CI job, immutable CrossWake checkout, negative contract fixtures, and release-gate parity tests. |
</phase_requirements>

## Project Constraints (from AGENTS.md)

- Preserve stable `notification_key` plus version; never use module names as durable identity.
- Keep the durable lifecycle spine `event -> notification -> delivery -> attempt`, and make idempotency and suppression reasons first-class.
- Keep adapter seams explicit and contract-tested; preserve host ownership of authentication, tenancy, URL generation, and correlation IDs.
- Maintain named `mix verify.*` and `mix ci.*` entrypoints with local/CI parity.
- Do not expose sensitive payload fields in telemetry or operator surfaces.
- Classify all objective tracer/acceptance work as automated executable evidence; do not create human verification checkpoints, human checks, or conversational UAT for it.

## Summary

Implement this phase as a single, packaged clean-room fixture rather than a broad new test suite. The runner should build Chimeway once with `mix hex.build`, validate and unpack exactly those bytes through the existing `Chimeway.AdoptionProof.ArtifactArchive`, create a fresh Alpha-host Mix project using that package plus a CrossWake sibling checkout pinned by its full SHA, copy and run the real Chimeway migrations against PostgreSQL, then run one ordered scenario ledger. The existing adoption runner already establishes immutable-package construction, bounded extraction, one-line proof framing, and nonzero failure behavior. [VERIFIED: codebase inspection — `scripts/prove-adoption-paths.exs`, `priv/adoption_proof/artifact_archive.ex`]

The main implementation risk is nondeterministic time, not APNs emulation. `DeliveryTargets` directly calls `DateTime.utc_now/0` for attempts, claims, leases, retry transitions, and expiry-related persistence; `Adapters.APNS` directly calls it for expiry and accepted-at evidence. `TargetRecovery` already accepts `now:`. Add a local Chimeway clock behaviour/provider and pass its resolved time through only these exercised entry points, while host registry and CrossWake resolver receive an explicit `now`/clock option. Production remains system-clock backed. [VERIFIED: codebase inspection — `lib/chimeway/delivery_targets.ex`, `lib/chimeway/adapters/apns.ex`, `lib/chimeway/target_recovery.ex`, `../crosswake/.../resolver.ex`] [CITED: https://hexdocs.pm/elixir/DateTime.html]

Proof must assert persisted targets/attempts/traces and public `Chimeway.Traces.explain_delivery/2`, not return values alone. CrossWake must be consumed through `crosswake_chimeway` contracts and `Resolver.resolve/3`, with fixture-owned `IntentConsumer` authority. The current resolver already maps expired, replayed, revoked, binding-mismatch, authorization, and policy failures to sanitized denials after consuming the host intent and evaluating RouteGate. [VERIFIED: codebase inspection — `lib/chimeway/traces.ex`, `../crosswake/packages/crosswake_chimeway/lib/crosswake/companions/chimeway/resolver.ex`]

**Primary recommendation:** Build a closed `AlphaTwin` fixture/runner around one scenario ledger, an explicit test clock, an ordered scripted transport, immutable provenance, and durable safe-proof scanning; make `verify_alpha_twin` the only CI lane that runs both required Mix entrypoints.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Immutable Chimeway package/migration execution | API / Backend | Database / Storage | The runner builds/unpacks the library and the host applies its actual migrations to PostgreSQL. [VERIFIED: codebase inspection — adoption proof runner] |
| Binding/token lifecycle and one-time open intents | API / Backend | Database / Storage | The Alpha host retains token custody, eligibility, CAS lifecycle authority, and intent consumption. [CITED: `.planning/phases/102-alpha-digital-twin-hermetic-gate/102-CONTEXT.md`] |
| Logical delivery, targets, attempts, recovery, explanation | API / Backend | Database / Storage | Chimeway owns lifecycle persistence and explanation; tests must observe durable rows/projections. [VERIFIED: codebase inspection — `lib/chimeway/delivery_targets.ex`, `lib/chimeway/target_recovery.ex`, `lib/chimeway/traces.ex`] |
| APNs request observation/outcomes | API / Backend | — | A transport behaviour consumes bounded real requests and returns scripted provider results, with no network. [VERIFIED: codebase inspection — `lib/chimeway/apns/transport.ex`] |
| Offline notification-open handling and current-policy route activation | Browser / Client | API / Backend | CrossWake owns the queued client evidence and RouteGate decision; host consumption reauthorizes current state. [VERIFIED: codebase inspection — CrossWake `IntentConsumer` and `Resolver`] |
| CI gate and proof-schema validation | API / Backend | CDN / Static | GitHub Actions runs credential-free commands; fixtures validate contract bytes without a device or provider. [VERIFIED: codebase inspection — `.github/workflows/ci.yml`, `test/chimeway/release_gate_contract_test.exs`] |

## Standard Stack

### Core

| Library / component | Version | Purpose | Why Standard |
|---------------------|---------|---------|--------------|
| Chimeway package artifact | build-local immutable SHA-256 | The host consumes the actual published-package shape, not source-path code. | Existing proof runner builds and validates the archive before invoking a fixture. [VERIFIED: codebase inspection — `scripts/prove-adoption-paths.exs`] |
| Ecto SQL / PostgreSQL | `ecto_sql` 3.13.5; PostgreSQL service | Run actual copied migrations and inspect durable lifecycle state. | Existing project persistence and CI use this stack. [VERIFIED: codebase inspection — `mix.lock`, `.github/workflows/ci.yml`] |
| CrossWake + `crosswake_chimeway` | sibling checkout pinned to full SHA | Use authoritative manifest, protected-open, and physical-proof contracts. | Locked cross-repository boundary; current checkout is `f2c502cdb1ce572a4a57257d9e3c051665704b90`. [VERIFIED: codebase inspection — `git -C ../crosswake rev-parse HEAD`] |
| ExUnit / Mix tasks | Elixir 1.19.5 | Execute repeatable fixture proof and contract fixtures. | Existing project verification uses named `mix verify.*` commands. [VERIFIED: local environment and `mix.exs`] |

### Supporting

| Component | Purpose | When to Use |
|-----------|---------|-------------|
| `Chimeway.APNS.Transport` behaviour | Script ordered accepted/retryable/permanent/invalidation/ambiguous outcomes. | Always in Alpha twin; never Pigeon network I/O. [VERIFIED: codebase inspection — `lib/chimeway/apns/transport.ex`] |
| `Chimeway.AdoptionProof.ArtifactArchive` | Bound and validate archive bytes before fixture execution. | Reuse for immutable Chimeway package provenance. [VERIFIED: codebase inspection — `priv/adoption_proof/artifact_archive.ex`] |
| `Chimeway.SafeEvidence` | Recurse/allowlist safety checks for proof inputs and output. | Scan persisted facts, transport observations, captures, errors, and final bytes before emitting proof. [VERIFIED: codebase inspection — `lib/chimeway/safe_evidence.ex`] |
| `Ecto.Adapters.SQL.Sandbox` | Own/share test database connections across fixture processes. | Unit/contract tests that start registry/transport/recovery processes; use a synchronous shared owner and finish work before teardown. [CITED: https://ecto-sql.hexdocs.pm/Ecto.Adapters.SQL.Sandbox.html] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Dedicated Alpha fixture | Existing demo/CrossWake example | Rejected by D-01: changes test semantics and violates clean-room ownership. [CITED: `102-CONTEXT.md`] |
| Scripted transport | Pigeon provider emulator or APNs sandbox | Rejected by D-07/D-11: requires unavailable network/Apple state and cannot be hermetic. [CITED: `102-CONTEXT.md`] |
| Explicit clock seam | Wall-clock sleeps | Rejected by D-06: slow/flaky and cannot deterministically cover lease, retry, expiry, or replay boundaries. [CITED: `102-CONTEXT.md`] |

**Installation:** No new external package is recommended or required. Reuse locked project dependencies and the immutable sibling CrossWake checkout. [VERIFIED: codebase inspection — `mix.exs`, `102-CONTEXT.md`]

## Architecture Patterns

### System Architecture Diagram

```text
locked CrossWake SHA ──checkout/provenance──┐
                                            ▼
Chimeway source ──hex.build──> archive + digest ──validate/unpack──> Alpha host fixture
                                                                    │
scenario ledger + fixed clock ──ordered actions────────────────────┤
                                                                    ▼
host registry (opaque binding + intent authority) ──public trigger──> Chimeway
                                                                    │
                                            PostgreSQL <──migrations─┤
                                                                    ▼
      scripted APNs transport <──real bounded request── APNS adapter / target attempt
                │                                   │
                └──ordered result──> targets/attempts/recovery/traces ──> explanation
                                                                    │
offline opaque open ──> CrossWake IntentConsumer -> Resolver -> RouteGate
                                                                    │
all safe facts/captures/errors/output ──recursive scanner──> closed proof summary
                                                                    │
CI verify_alpha_twin ──both Mix tasks + provenance + gate aggregation──> pass/fail
```

### Recommended Project Structure

```text
test/fixtures/alpha_twin/                 # dedicated committed, sanitized host Mix project
├── mix.exs                               # artifact path + CROSSWAKE_PATH/full SHA contract
├── config/config.exs                     # Repo and fixture-only runtime configuration
├── lib/alpha_twin/
│   ├── registry.ex                       # host-owned opaque bindings/CAS/intents
│   ├── clock.ex                          # fixed production-compatible clock seam
│   ├── scripted_apns_transport.ex        # ordered request observer and result script
│   ├── scenario_ledger.ex                # closed versioned ordered scenarios
│   ├── runner.ex                         # public host -> Chimeway -> CrossWake narrative
│   └── proof_summary.ex                  # closed encoding, provenance, recursive scanner
├── priv/repo/migrations/                 # copied Chimeway migrations actually applied
└── test/alpha_twin_test.exs              # process-level scenario/proof assertions
lib/mix/tasks/verify.alpha_twin.ex        # locked entrypoint
lib/mix/tasks/verify.physical_proof_contract.ex
scripts/prove-alpha-twin.exs              # build/archive/checkout/fixture orchestration
test/fixtures/alpha_twin_physical_proof/  # valid and one-fault negative evidence fixtures
```

### Pattern 1: Closed Scenario Ledger Drives Every Participant

**What:** Define ordered string scenario IDs and a schema version once; the host runner selects actions, scripted transport dequeues outcomes, proof summary records allowed result IDs, and contract tests reject absent/duplicate/reordered/unknown IDs. [CITED: `102-CONTEXT.md`]

**When to use:** Every TWIN-02 condition, including negative cases. Keep scenario data opaque and atom-safe: decode only closed string IDs, then map to internal known operations. [CITED: `102-CONTEXT.md`]

### Pattern 2: Narrow Clock Provider With Explicit Advance

**What:** Resolve `now` from a small local clock behaviour (production adapter delegates to `DateTime.utc_now/0`; fixture adapter returns fixed state). Pass the resolved value into target claim/transition, APNs expiry/classification, recovery, host registry, and open-resolution code. [VERIFIED: codebase inspection — existing `now:` in `TargetRecovery`; direct calls in delivery targets/APNs] [CITED: https://hexdocs.pm/elixir/DateTime.html]

**When to use:** Only time-sensitive operations reached by the Alpha ledger. Do not replace global system time, monkey-patch DateTime, or advance time with sleeps. [CITED: `102-CONTEXT.md`]

### Pattern 3: Two-layer Proof Validation

**What:** First run the production-path twin and build its closed proof summary. Separately validate Phase 103 future-evidence fixtures against a Chimeway extension that references CrossWake's canonical physical contract. The second task is serialization/schema-only and has no Apple/device dependency. [VERIFIED: codebase inspection — CrossWake `PhysicalIphoneContract`, `Evidence`] [CITED: `102-CONTEXT.md`]

**When to use:** Always run both in the same CI job, but keep their truth claims separate: hermetic executable facts may pass; visible-alert observation remains only a Phase 103 subjective claim. [CITED: `102-CONTEXT.md`]

### Anti-Patterns to Avoid

- **Direct lifecycle-row setup:** It bypasses public trigger/planning/dispatch/recovery and violates D-02. [CITED: `102-CONTEXT.md`]
- **Independent scenario fixtures per layer:** They can drift while each local test passes; use one ordered ledger. [CITED: `102-CONTEXT.md`]
- **Returning raw exception/transport maps in the proof:** Unknown maps can leak; scan and reduce to a closed rule/path/fact vocabulary. [CITED: `102-CONTEXT.md`]
- **Treating APNs acceptance as a device/open/read fact:** Retain distinct lifecycle claims. [CITED: `102-CONTEXT.md`]
- **Calling the current CrossWake physical-iPhone shell script from Linux CI:** it invokes `xcodebuild`; this phase should call a pure validator over fixtures instead. [VERIFIED: codebase inspection — `../crosswake/script/verify_physical_iphone_report_contract.sh`]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Package extraction/traversal validation | New archive unpacker | `Chimeway.AdoptionProof.ArtifactArchive` | Existing bounded archive scanner validates digest and materialized tree. [VERIFIED: codebase inspection] |
| APNs provider protocol | Fake HTTP/2 server or emulator | `Chimeway.APNS.Transport` behaviour with scripted fixture transport | The existing adapter calls this seam and real request construction remains exercised. [VERIFIED: codebase inspection — `lib/chimeway/apns/transport.ex`, `lib/chimeway/adapters/apns.ex`] |
| Protected-open policy | Reimplementation of manifest/actions/RouteGate | `crosswake_chimeway` `IntentConsumer` and `Resolver` | CrossWake is authoritative and resolver already performs consumer then current RouteGate evaluation. [VERIFIED: codebase inspection — CrossWake resolver] |
| Generic proof envelope | Arbitrary JSON/`inspect` diagnostics | Closed allowlisted summary plus `SafeEvidence` and CrossWake `Evidence` patterns | Both projects explicitly use closed privacy-safe evidence contracts. [VERIFIED: codebase inspection — `lib/chimeway/safe_evidence.ex`, CrossWake `Evidence`] |
| CI aggregate parsing | Bespoke pass/fail policy | Existing `scripts/ci/aggregate-gate.sh` and release-gate contract pattern | Current `pr-gate`/`ci-gate` already aggregate named lanes and tests lock their membership. [VERIFIED: codebase inspection — `.github/workflows/ci.yml`, release-gate test] |

**Key insight:** The phase adds composition and contractual evidence, not a new delivery, APNs, authentication, or mobile-policy implementation.

## Common Pitfalls

### Pitfall 1: A “deterministic” runner still reads the wall clock

**What goes wrong:** Lease, retry, expiry, and replay scenarios pass/fail based on execution timing. [VERIFIED: codebase inspection — direct `DateTime.utc_now/0` calls]

**How to avoid:** Inventory every time read along the ledger path and inject a resolved timestamp through it; assert time values in safe proof facts and never sleep. [CITED: `102-CONTEXT.md`]

### Pitfall 2: Test processes lose DB ownership

**What goes wrong:** Registry/transport/recovery processes see Ecto ownership errors or survive cleanup. [CITED: https://ecto-sql.hexdocs.pm/Ecto.Adapters.SQL.Sandbox.html]

**How to avoid:** Run fixture process tests synchronously under an explicit shared Sandbox owner, await all work, and stop all fixture processes before owner teardown. [CITED: https://ecto-sql.hexdocs.pm/Ecto.Adapters.SQL.Sandbox.html]

### Pitfall 3: Provenance is stated but not enforced

**What goes wrong:** A local tree, branch, or mutable tag masquerades as the tested CrossWake/Chimeway implementation. [CITED: `102-CONTEXT.md`]

**How to avoid:** Pin a 40-character SHA in source/ledger, check out detached at that exact SHA, reject dirty tree or mismatch, and bind archive digest + SHA into the final proof bytes. [CITED: `102-CONTEXT.md`]

### Pitfall 4: Invalidation races revoke a replacement binding

**What goes wrong:** A delayed 410 affects a newly rotated token rather than the exact binding revision. [CITED: `102-CONTEXT.md`]

**How to avoid:** Script the old-revision provider result after rotation and assert host CAS only changes the original `{tenant, environment, topic, binding_revision_ref}`. [VERIFIED: codebase inspection — `Chimeway.Adapters.APNS.invalidation_key/2`]

### Pitfall 5: Physical-proof fixture validation claims device proof

**What goes wrong:** CI validates JSON and incorrectly reports APNs/iPhone display observation. [CITED: `102-CONTEXT.md`]

**How to avoid:** Emit only `hermetic` validation facts and rule IDs; require the Phase 103 extension to reference, not duplicate, CrossWake canonical physical assertion ownership. [CITED: `102-CONTEXT.md`]

## Code Examples

### Process-level proof clock shape

```elixir
# Fixture-only clock; production adapter delegates to DateTime.utc_now/0.
{:ok, now} = AlphaTwin.Clock.now(clock)
{:ok, result} = Chimeway.TargetRecovery.recover_tenant("alpha-tenant", now: now)
{:ok, next_clock} = AlphaTwin.Clock.advance(clock, 61)
```

This matches the existing recovery `now:` option and keeps time under scenario control. [VERIFIED: codebase inspection — `lib/chimeway/target_recovery.ex`]

### Scripted transport discipline

```elixir
# Assert the actual request after redaction, then consume exactly one expected outcome.
def push(_dispatcher_ref, %Chimeway.APNS.Transport.Request{} = request, opts) do
  AlphaTwin.ScriptedAPNS.consume(opts[:script_pid], redact_and_validate!(request))
end
```

The adapter must continue to build and send the real transport request through the shipped behaviour. [VERIFIED: codebase inspection — `lib/chimeway/apns/transport.ex`]

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| Isolated unit fixtures for individual paths | One ledger-backed production-path twin with durable proof | Detects cross-layer contract drift and regression in safety-critical ordering. [CITED: `102-CONTEXT.md`] |
| Device/provider dependence for proof | Scripted transport plus fixture-only physical-proof schema validation | CI is credential-free; actual device claims remain deferred. [CITED: `102-CONTEXT.md`] |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The selected CrossWake implementation SHA is publicly fetchable from the canonical repository during CI. | Open Questions (RESOLVED) | FALSE as measured on 2026-08-25: canonical GitHub upload-pack returns `not our ref`. Phase execution therefore begins with a credential-dependent publication prerequisite for that exact immutable commit, followed by an isolated unauthenticated exact-SHA fetch; it remains blocked until that check passes. |

## Open Questions (RESOLVED)

1. **Resolved pin; publication remains an execution prerequisite:** the only implementation pin satisfying D-03 is canonical origin `https://github.com/szTheory/crosswake.git` at the sibling Phase 101 full commit `f2c502cdb1ce572a4a57257d9e3c051665704b90`; substituting advertised `origin/main` (`d16e475abee4e1602bea51c07dc3adf6e8bc91b9` when inspected) is invalid because the sibling Phase 101 contracts differ from it. The pin is **not currently public-CI fetchable**: the 2026-08-25 isolated `git fetch --depth=1 https://github.com/szTheory/crosswake.git f2c502cdb1ce572a4a57257d9e3c051665704b90` returned `upload-pack: not our ref`, `git ls-remote` advertised no ref at that commit, and the sibling branch's upstream was gone. Plan 01 therefore starts with an authorized maintainer publishing that existing exact commit to the canonical remote, then requires a fresh isolated unauthenticated fetch whose `FETCH_HEAD` equals the literal SHA before any twin or CI implementation begins. Publication is a planned prerequisite, not evidence of present availability. If either action fails, execution stops rather than floating to another revision or using the local mutable checkout. After the prerequisite passes, CI still performs its own detached public checkout at the literal 40-hex SHA, followed by exact `remote get-url origin`, `rev-parse HEAD`, detached-HEAD, and empty-porcelain assertions before either proof command runs. A release-gate mutation test rejects a shortened SHA, branch/tag, different remote, attached HEAD, dirty tree, or proof SHA mismatch. [VERIFIED current state: `git -C ../crosswake remote -v`; `git -C ../crosswake rev-parse HEAD`; `git -C ../crosswake status --short --branch`; canonical-remote `git ls-remote`; isolated canonical-remote `git fetch --depth=1 <url> <sha>`]

2. **Resolved trigger-commit crash seam:** use the existing configured dispatcher boundary in `Chimeway.Trigger.dispatch_after_trigger/4`. `Chimeway.Trigger.do_trigger/7` commits the `Ecto.Multi` containing the event and notifications, normalizes the committed result, and only then calls `plan_deliveries_span/4` -> `dispatch_after_trigger/4` -> `Application.get_env(:chimeway, :dispatcher, Chimeway.Dispatch.Sync).dispatch/2`. The Alpha fixture will configure a fixture-owned crash-once dispatcher whose first `dispatch/2` invocation terminates the trigger process before delivery planning and whose subsequent invocation delegates to the real synchronous dispatcher. The scenario then advances the fixed clock and invokes public `Chimeway.TargetRecovery.recover_tenant/2`, asserting one stranded committed event, one recovered delivery tree, and durable explanation convergence. This names a precise post-commit/pre-plan injection point, exercises real public trigger and recovery paths, and requires no new production callback or direct lifecycle-row insertion. [VERIFIED: `lib/chimeway/trigger.ex` transaction and `dispatch_after_trigger/4`; `lib/chimeway/target_recovery.ex`; `lib/chimeway/deliveries.ex`]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Elixir / Mix | fixture and tasks | ✓ | 1.19.5 / OTP 28 | — |
| PostgreSQL | real migration/persistence proof | ✓ | server listening locally; client 14.17 | CI PostgreSQL 15 service, matching project topology |
| Git | immutable CrossWake checkout | ✓ | 2.41.0 | — |
| CrossWake commit on canonical public remote | all twin and CI execution | ✗ as measured 2026-08-25 | exact SHA `f2c502cdb1ce572a4a57257d9e3c051665704b90` | authorized publication of this same commit, then isolated unauthenticated exact-SHA fetch; no substitute revision |
| Docker | optional local CI parity | ✓ | 29.5.2 | native PostgreSQL service |
| Apple credentials / APNs | intentionally not required | — | — | scripted transport and schema fixtures |
| Xcode / `xcodebuild` | intentionally not required by Phase 102 CI | ✗ | — | pure CrossWake/Chimeway contract validation only |

**Missing dependencies with no fallback:** The exact D-03 CrossWake commit is not currently served by the canonical public remote. Plan 01 owns the credential-dependent publication prerequisite and isolated machine verification; all twin and CI work remains blocked until it passes. [VERIFIED current state: canonical upload-pack inspection on 2026-08-25]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit, Elixir 1.19.5 [VERIFIED: local environment and `test/test_helper.exs`] |
| Config file | `test/test_helper.exs` (manual SQL Sandbox mode) [VERIFIED: codebase inspection] |
| Quick run command | `mix verify.physical_proof_contract` |
| Full phase command | `mix verify.alpha_twin && mix verify.physical_proof_contract` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TWIN-01 | artifact, copied migrations, deterministic host registry, scripted APNs | process integration | `mix verify.alpha_twin` | ❌ Wave 0 |
| TWIN-02 | exact ledger matrix with durable lifecycle/explanation and safe output assertions | process integration + fixture contracts | `mix verify.alpha_twin` | ❌ Wave 0 |
| GATE-01 | both entrypoints, SHA/digest provenance, invalid physical evidence rejection, CI aggregation | contract + CI topology | `mix ci.verify_gates` and `mix verify.physical_proof_contract` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** the narrow relevant `mix test` target or a single Mix verification command.
- **Per wave merge:** `mix verify.alpha_twin && mix verify.physical_proof_contract`.
- **Phase gate:** `mix ci.verify_gates` plus both verification commands, with `verify_alpha_twin` green in `pr-gate` and `ci-gate`.

### Wave 0 Gaps

- [ ] `test/fixtures/alpha_twin/` — committed clean host, migrations, and host-owned registries.
- [ ] `scripts/prove-alpha-twin.exs` plus `Mix.Tasks.Verify.AlphaTwin` — immutable package/check-out orchestration.
- [ ] `Mix.Tasks.Verify.PhysicalProofContract` and negative fixture corpus — closed physical-proof extension validation.
- [ ] Clock seam tests — prove production default and fixture advancement without sleeps.
- [ ] Release-gate contract tests and `verify_alpha_twin` CI job assertions — prove alias/job/aggregate/provenance parity.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | Yes | Host-owned authenticated binding and one-time-intent authority; CrossWake resolver receives opaque evidence only. [CITED: `102-CONTEXT.md`] |
| V3 Session Management | Yes | Reauthorize session/tenant/binding state at protected-open consumption and test replay/denial. [CITED: `102-CONTEXT.md`] |
| V4 Access Control | Yes | Explicit tenant scope and current RouteGate evaluation; no fallback route. [VERIFIED: codebase inspection — CrossWake resolver] |
| V5 Input Validation | Yes | Closed ledger/proof schema, duplicate/order checks, bounded strings, and fail-closed unknown fields. [CITED: `102-CONTEXT.md`] |
| V6 Cryptography | Yes | Reuse SHA-256 artifact digest; do not implement custom cryptography. [VERIFIED: codebase inspection — adoption proof runner] |

### Known Threat Patterns for the twin

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Raw token/payload/URL/provider body leaks through captures or proof | Information Disclosure | Recursive safe-fact scanning plus closed summary; reject unknown maps and final bytes containing sentinels. [CITED: `102-CONTEXT.md`] |
| Mutable CrossWake/chimeway source substituted for tested revision | Tampering | Detached full-SHA checkout and artifact digest bound into proof bytes. [CITED: `102-CONTEXT.md`] |
| Old invalidation revokes rotated binding | Tampering | Exact revision CAS and race ledger scenario. [CITED: `102-CONTEXT.md`] |
| Offline/replayed open activates a route | Elevation of Privilege | Host one-time consumption plus current CrossWake RouteGate reauthorization and denial assertions. [VERIFIED: codebase inspection — CrossWake resolver] |
| Broad error serialization discloses sensitive facts | Information Disclosure | Stable closed rule/path only; no echoed rejected values. [CITED: `102-CONTEXT.md`] |

## Sources

### Primary (HIGH confidence)

- `102-CONTEXT.md`, `REQUIREMENTS.md`, `ROADMAP.md` — locked scope, requirements, success criteria, and exclusions.
- Chimeway `scripts/prove-adoption-paths.exs`, `priv/adoption_proof/artifact_archive.ex`, `lib/chimeway/{delivery_targets,target_recovery,traces,adapters/apns,apns/transport}.ex` — existing artefact, lifecycle, transport, recovery, and explanation seams.
- Chimeway `test/chimeway/release_gate_contract_test.exs`, `.github/workflows/ci.yml`, `mix.exs` — existing verify/CI/gate topology.
- CrossWake `crosswake_chimeway` contracts/resolver and proof-lane modules — authoritative protected-open and physical-proof boundaries.

### Secondary (MEDIUM confidence)

- [Ecto SQL Sandbox](https://ecto-sql.hexdocs.pm/Ecto.Adapters.SQL.Sandbox.html) — explicit owner/shared connection pattern for spawned test processes.
- [Elixir DateTime](https://hexdocs.pm/elixir/DateTime.html) — system UTC time API that a local seam must encapsulate for deterministic proof.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — locked decisions and directly inspected existing seams.
- Architecture: HIGH — responsibility boundaries are locked and current implementations were inspected.
- Pitfalls: HIGH — direct wall-clock calls, CI topology, current physical-script Xcode requirement, and security boundaries were inspected.

**Research date:** 2026-08-25
**Valid until:** 2026-09-01 (fast-moving cross-repository SHA and CI topology)
