# Phase 93: Hermetic Artifact Harness & Core Trace Proof - Research

**Researched:** 2026-08-08  
**Domain:** Elixir/Hex unpacked-artifact consumer contract, PostgreSQL-backed lifecycle proof, public trace explainability  
**Confidence:** HIGH for repository integration; MEDIUM for Mix/Hex task semantics

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

## Implementation Decisions

### Artifact Provenance Harness
- **D-01:** Implement the Core proof as an executable ExUnit contract that builds and unpacks the root Hex artifact, then runs a separately scaffolded temporary consumer whose `:chimeway` dependency points only at that unpacked directory.
- **D-02:** Do not reuse an in-repository path dependency, the repository source tree, or the DemoHost as the provenance proof; those remain useful examples but cannot establish artifact isolation.
- **D-03:** Extend the project's existing ExUnit package/release truth anchors rather than adding a parallel shell truth checker.

### Clean Host Lifecycle
- **D-04:** Give the temporary consumer its own real supported PostgreSQL database and exercise the documented default-prefixed installer/migration and application-boot path.
- **D-05:** Configure synchronous dispatch in the consumer proof so the documented Core command deterministically reaches a terminal durable delivery outcome.

### Public Evidence Contract
- **D-06:** Define an adopter-owned minimal notifier with a fixed stable `notification_key` and version, then trigger it with explicit stable `tenant_id` and `idempotency_key` inputs.
- **D-07:** Obtain and assert lifecycle evidence exclusively through `Chimeway.Traces.explain_delivery/1`; the evidence must include only sanitized public explanation fields, never private test helpers or database-only inspection.

### the agent's Discretion
- Exact temporary-consumer scaffolding, database-name isolation strategy, command wiring, notifier name, and assertion formatting, provided the artifact-only provenance, real supported PostgreSQL lifecycle, and public explainability boundaries above remain intact.

### Deferred Ideas (OUT OF SCOPE)
- Mailglass transactional-email proof and its fake-transport boundary — Phase 94.
- Accrue billing-escalation proof and provenance labeling — Phase 95.
- Adoption path selector, `mix verify.adoption_paths`, dedicated CI lane, and drift contracts across all paths — Phase 96.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|---|---|---|
| PROOF-01 | A clean consumer fixture installs Chimeway from an unpacked built package artifact without a root source-path dependency. | Build once with `mix hex.build --unpack`, then render a consumer `mix.exs` whose sole Chimeway declaration is `{:chimeway, path: unpacked_root}`. Assert the rendered dependency string does not contain the repository root. [VERIFIED: 93-CONTEXT.md, test/chimeway/release_gate_contract_test.exs] |
| PROOF-02 | The fixture can boot, migrate, and run documented proof commands reproducibly with supported PostgreSQL. | Scaffold Repo/config/application files, run `deps.get`, `chimeway.gen.migrations`, `ecto.create`, `ecto.migrate`, then the consumer proof command against a unique PostgreSQL database. [VERIFIED: guides/introduction/installation.md, test/support/generated_prefixed_runtime_case.ex] |
| PROOF-03 | Every adoption proof asserts lifecycle evidence through a public Chimeway explainability API. | The consumer script must only call `Chimeway.Traces.explain_delivery/1` after receiving `delivery_id` from `Chimeway.trigger/3`; no consumer Repo query or private Chimeway helper belongs in evidence assertions. [VERIFIED: lib/chimeway.ex, lib/chimeway/traces.ex, 93-CONTEXT.md] |
| CORE-01 | The Core path proves notifier definition through trigger, durable delivery outcome, and explainable trace in the clean consumer. | Adapt the minimal notifier shape already proven by `ReadmeSnippetTest`, configure Sync + Logger, and assert a terminal `:succeeded` explanation with expected public timeline markers. [VERIFIED: test/chimeway/integration/readme_snippet_test.exs, lib/chimeway/dispatch/sync.ex, lib/chimeway/adapters/logger.ex] |
</phase_requirements>

## Summary

Phase 93 should add one hermetic, PostgreSQL-backed ExUnit contract to the existing package/release truth anchor, supported by a focused temporary-consumer fixture module. The existing anchor already builds the root artifact in an isolated directory using `MIX_ENV=prod mix hex.build --unpack --output ...`, handles both possible unpacked-root layouts, and removes the output on exit. [VERIFIED: test/chimeway/release_gate_contract_test.exs] Hex documents `--unpack` specifically as a way to inspect a package before publishing, and defines `--output` as the unpack directory for that mode. [CITED: https://hex.hexdocs.pm/Mix.Tasks.Hex.Build.html]

The temporary consumer must be a genuinely separate Mix app: its generated `mix.exs`, config, Repo, application module, notifier, and proof script live under a unique system temporary directory. Its Chimeway dependency points at the unpacked artifact, not the repository. It must use a unique real PostgreSQL database, generate copied migrations with the public installer, run the host's migration task, boot normally, and run a public trigger-to-explain script. The repository already has a robust pattern for unique database names, forcing `url: nil` when `DATABASE_URL` is present, explicitly verifying the connected database, and cleaning up database, process, and temporary directory. [VERIFIED: test/support/generated_prefixed_runtime_case.ex]

**Primary recommendation:** Add a reusable `ArtifactConsumerFixture` under `test/support/`, then invoke it from a new `async: false` Core-proof describe block in `test/chimeway/release_gate_contract_test.exs`; do not add production dependencies, a shell truth checker, DemoHost reuse, or a Phase-96 adoption selector/CI lane. [VERIFIED: 93-CONTEXT.md, mix.exs, test/chimeway/release_gate_contract_test.exs]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|---|---|---|---|
| Build and unpack artifact | Build / Package | ExUnit contract | Only a Hex-built artifact can establish the required provenance boundary. [VERIFIED: 93-CONTEXT.md, test/chimeway/release_gate_contract_test.exs] |
| Temporary consumer scaffold and commands | Test harness | Mix / Ecto | The test harness owns disposable files and subprocess diagnostics; the consumer remains an ordinary host app. [VERIFIED: test/support/installer_fixture.ex, guides/introduction/installation.md] |
| Host migration ownership | Consumer API / Database | Chimeway installer | The host Repo owns `ecto.create`/`ecto.migrate`; Chimeway copies its migrations through the public Mix task. [CITED: https://hexdocs.pm/ecto/Mix.Tasks.Ecto.Create.html] [CITED: https://hexdocs.pm/ecto_sql/Mix.Tasks.Ecto.Migrate.html] |
| Runtime lifecycle | Chimeway application / Database | Consumer notifier | Chimeway owns durable event → notification → delivery → attempt rows; the consumer owns notifier identity, recipient mapping, and trigger inputs. [VERIFIED: AGENTS.md, lib/chimeway/application.ex, lib/chimeway/trigger.ex] |
| Explainability evidence | Public API | Consumer proof script | `Chimeway.Traces.explain_delivery/1` is the required public query surface; the script must not inspect private storage. [VERIFIED: lib/chimeway/traces.ex, 93-CONTEXT.md] |

## Project Constraints (from AGENTS.md)

- Keep the durable `event -> notification -> delivery -> attempt` lifecycle and stable `notification_key` + version identity. [VERIFIED: AGENTS.md]
- Preserve host ownership of auth, tenancy, URL generation, correlation IDs, policies, data, and delivery history. [VERIFIED: AGENTS.md]
- Use the supported Elixir 1.17+, Ecto 3.x, PostgreSQL 15+ stack; this environment has Elixir/Mix 1.19.5, PostgreSQL client 14.17, Docker 29.5.2, and a live local Postgres listener. [VERIFIED: AGENTS.md, local version/availability probe]
- Do not leak sensitive payload data into telemetry or operator/evidence surfaces. [VERIFIED: AGENTS.md]
- Maintain `mix verify.*` / `mix ci.*` parity; Phase 96 alone owns the dedicated adoption command and CI lane. [VERIFIED: AGENTS.md, 93-CONTEXT.md]

## Standard Stack

### Core

| Library / Tool | Version | Purpose | Why Standard |
|---|---:|---|---|
| Elixir / Mix / ExUnit | project floor `~> 1.17`; local 1.19.5 | Scaffold/run consumer and execute contract. | Existing package and release truth is ExUnit, not shell tooling. [VERIFIED: mix.exs, test/chimeway/release_gate_contract_test.exs, local probe] |
| Hex `mix hex.build --unpack` | local Hex task; project package build | Produce the only allowed Chimeway source for the consumer. | Existing release contract uses this exact command under `MIX_ENV=prod`. [VERIFIED: test/chimeway/release_gate_contract_test.exs] [CITED: https://hex.hexdocs.pm/Mix.Tasks.Hex.Build.html] |
| Ecto SQL + Postgrex | existing Chimeway dependencies | Host Repo, database creation, and migrations. | The documented host flow uses `mix ecto.migrate`; Ecto uses configured repos and the conventional `priv/repo/migrations` path. [VERIFIED: mix.exs, guides/introduction/installation.md] [CITED: https://hexdocs.pm/ecto_sql/Mix.Tasks.Ecto.Migrate.html] |
| PostgreSQL | supported 15+; CI uses `postgres:15` | Real durable host lifecycle. | Phase requires real supported PostgreSQL; current relevant CI jobs provision PostgreSQL 15. [VERIFIED: AGENTS.md, .github/workflows/ci.yml] |
| `Chimeway.Dispatch.Sync` + `Chimeway.Adapters.Logger` | existing public configuration seam | Deterministic terminal success with a recorded attempt. | Sync runs the pipeline in-process; Logger returns success. [VERIFIED: lib/chimeway/dispatch/sync.ex, lib/chimeway/adapters/logger.ex] |

### Supporting

| Tool / Pattern | Purpose | When to use |
|---|---|---|
| `System.cmd/3` with `stderr_to_stdout: true` | Execute each consumer Mix command and retain failure diagnostics. | All temp-host subprocesses. [VERIFIED: test/support/installer_fixture.ex, test/chimeway/release_gate_contract_test.exs] |
| `on_exit` cleanup plus failure-path cleanup | Drop disposable DB and remove temporary source/artifact trees. | Every created external resource. [VERIFIED: test/support/generated_prefixed_runtime_case.ex, test/chimeway/release_gate_contract_test.exs] |
| Public proof script | Keep lifecycle assertions inside the consumer boundary. | After application boot/migration, return structured/printed safe evidence and exit nonzero on mismatch. [ASSUMED] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|---|---|---|
| Unpacked artifact path dependency | Root source path or DemoHost | Rejected by D-02: either permits source-tree leakage and cannot prove package completeness. [VERIFIED: 93-CONTEXT.md] |
| ExUnit fixture + contract | Standalone shell checker | Rejected by D-03: creates a second truth system outside established package/release contracts. [VERIFIED: 93-CONTEXT.md] |
| Sync + Logger | Oban or a provider adapter | Oban adds scheduling/process timing; provider adapters introduce external credentials and nondeterministic behavior. D-05 locks synchronous dispatch. [VERIFIED: 93-CONTEXT.md, lib/chimeway/dispatch/sync.ex] |

**Installation:** No new Chimeway dependency is needed. The generated consumer may directly declare existing host dependencies (`ecto_sql` and `postgrex`) so its own Repo compiles, while its Chimeway dependency remains artifact-only. [ASSUMED]

## Package Legitimacy Audit

No package is added to the repository in this phase, so no package-legitimacy gate is required. The consumer's dependencies are existing project stack packages, not a new product recommendation. [VERIFIED: mix.exs, 93-CONTEXT.md]

## Architecture Patterns

### System Architecture Diagram

```text
root source tree
  |
  | MIX_ENV=prod mix hex.build --unpack
  v
unpacked chimeway artifact (unique temp directory)
  |
  | only Chimeway dependency source
  v
separately scaffolded temporary consumer
  |-- config: host Repo + Chimeway.Repo share unique PostgreSQL DB
  |-- config: prefix "chimeway", Sync dispatcher, Logger adapter
  |-- mix chimeway.gen.migrations
  |-- mix ecto.create && mix ecto.migrate
  |-- application boot
  v
consumer proof script
  |-- adopter-owned notifier: fixed key + version
  |-- Chimeway.trigger(... tenant_id:, idempotency_key:)
  |-- delivery_id from trigger trace
  `-- Chimeway.Traces.explain_delivery(delivery_id)
          |
          v
    sanitized public evidence: key, final status, timeline events
```

### Recommended Project Structure

```text
test/support/artifact_consumer_fixture.ex         # temporary app rendering, command runner, cleanup
test/chimeway/release_gate_contract_test.exs      # existing package/artifact truth anchor; calls fixture
<system tmp>/chimeway_artifact_consumer_<unique>/ # generated, never committed
├── mix.exs
├── config/config.exs
├── lib/artifact_consumer/repo.ex
├── lib/artifact_consumer/application.ex
├── lib/artifact_consumer/notifiers/core_trace.ex
└── priv/prove_core.exs
```

### Pattern 1: Artifact-Only Dependency Boundary

**What:** Create the consumer only after determining the real unpacked package root. Render its dependency as `{:chimeway, path: unpacked_root}` and reject repository-root paths before running `deps.get`. [VERIFIED: 93-CONTEXT.md, test/chimeway/release_gate_contract_test.exs]

**When to use:** Required for PROOF-01. Keep package building in the existing contract, whose helper already accounts for Hex placing content directly in the output directory or inside one `chimeway-*` child. [VERIFIED: test/chimeway/release_gate_contract_test.exs]

### Pattern 2: Isolated Database with Explicit URL Override

**What:** Generate a unique database name and build repo config from `DATABASE_URL` credentials while setting `url: nil` and explicit `database:`; assert `SELECT current_database()` equals the generated name before migration. [VERIFIED: test/support/generated_prefixed_runtime_case.ex]

**When to use:** Required whenever CI's `DATABASE_URL` could otherwise silently route the consumer to `chimeway_test`. [VERIFIED: test/support/generated_prefixed_runtime_case.ex, .github/workflows/ci.yml]

### Pattern 3: Public-Evidence-Only Consumer Script

**What:** Let the script assert its notification definition and trigger return, then derive evidence solely from `Chimeway.Traces.explain_delivery(delivery_id)`. Assert `notification_key`, terminal `:succeeded`, an attempt summary, and required lifecycle entries such as `:event_created`, `:notification_created`, `:delivery_planned`, and `:attempt_recorded`; print only a whitelisted map of those public fields. [VERIFIED: lib/chimeway/traces.ex, lib/chimeway/traces/explanation.ex, test/chimeway/traces_test.exs]

**When to use:** Required for PROOF-03 and CORE-01. Do not call `Chimeway.Traces.get_trace/1`, a consumer Repo, or direct SQL for lifecycle evidence. [VERIFIED: 93-CONTEXT.md]

### Anti-Patterns to Avoid

- **Source fallback:** Never add a second path dep, `CHIMEWAY_PATH` override, copied `lib/`, or DemoHost reference; it invalidates artifact provenance. [VERIFIED: 93-CONTEXT.md]
- **Ambient database reuse:** Never use `chimeway_test` or accept `:already_up` without first proving the unique database connection; it can make a dirty database look like a clean-host success. [VERIFIED: test/support/generated_prefixed_runtime_case.ex]
- **Private evidence inspection:** Do not query `chimeway_events`, use `Chimeway.Repo`, or assert private structs after triggering. Migration verification is allowed, but lifecycle proof must be public API only. [VERIFIED: 93-CONTEXT.md]
- **Unsafe proof output:** Do not print notifier params, payload, recipient email, render assigns, provider response, or raw database URL. [VERIFIED: AGENTS.md, test/chimeway/traces_test.exs]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| Package assembly | Custom archive/copy script | `mix hex.build --unpack` | Hex controls the exact publish artifact. [CITED: https://hex.hexdocs.pm/Mix.Tasks.Hex.Build.html] |
| Host migration files | Hand-copied SQL/schema | `mix chimeway.gen.migrations` then host `mix ecto.migrate` | This is the documented installer and tests the consumer-facing path. [VERIFIED: guides/introduction/installation.md] |
| Delivery completion polling | Ad hoc retry/sleep loop | `Chimeway.Dispatch.Sync` | Sync completes the delivery pipeline in the caller process. [VERIFIED: lib/chimeway/dispatch/sync.ex] |
| Explainability projection | Consumer SQL joins or test-only serializers | `Chimeway.Traces.explain_delivery/1` | It is the public sanitized explanation contract. [VERIFIED: lib/chimeway/traces.ex, lib/chimeway/traces/explanation.ex] |

## Common Pitfalls

### Pitfall 1: The consumer compiles against source instead of the artifact
**What goes wrong:** A helper uses the repository root or a pre-existing path dependency, so omitted package files are never discovered.  
**How to avoid:** Pass only the located unpack root to generated `mix.exs`; assert the root is neither project root nor inside a source dependency declaration. Build in `MIX_ENV=prod` exactly like the release anchor. [VERIFIED: 93-CONTEXT.md, test/chimeway/release_gate_contract_test.exs]

### Pitfall 2: `DATABASE_URL` overrides the unique database name
**What goes wrong:** Ecto honors the database encoded in `url`, causing migrations to touch the root test DB.  
**How to avoid:** Follow the generated-prefix fixture: parse connection credentials, set `url: nil`, explicitly set `database`, and assert the connection target. [VERIFIED: test/support/generated_prefixed_runtime_case.ex]

### Pitfall 3: Migrations succeed but the app never boots against the migrated schema
**What goes wrong:** The proof stops at `ecto.migrate` or starts only the host Repo.  
**How to avoid:** Configure both host Repo and `Chimeway.Repo` to the same unique database, add `Chimeway.Application` to the host supervision tree, and execute the proof via `mix run` after migration. [VERIFIED: guides/introduction/golden-path.md, lib/chimeway/application.ex]

### Pitfall 4: A planned delivery is mistaken for a terminal proof
**What goes wrong:** An async/Oban configuration leaves a delivery pending.  
**How to avoid:** Configure `Chimeway.Dispatch.Sync` and Logger explicitly, then assert `explanation.status == :succeeded` plus public attempt/timeline evidence. [VERIFIED: 93-CONTEXT.md, lib/chimeway/dispatch/sync.ex, lib/chimeway/adapters/logger.ex]

### Pitfall 5: Safe API use is weakened by unsafe output
**What goes wrong:** The script serializes the full explanation or trigger parameters and exposes fields not necessary for the contract.  
**How to avoid:** Emit an allowlisted evidence map only; retain an explicit negative assertion that timeline details do not expose payload, recipient, email, phone, or provider response. [VERIFIED: AGENTS.md, test/chimeway/traces_test.exs]

## Code Examples

### Consumer configuration shape

```elixir
# Source: repository installation/golden-path configuration, adapted for the temporary consumer
config :artifact_consumer, ecto_repos: [ArtifactConsumer.Repo]

config :chimeway,
  repo: ArtifactConsumer.Repo,
  prefix: "chimeway",
  dispatcher: Chimeway.Dispatch.Sync,
  adapter: Chimeway.Adapters.Logger

config :chimeway, Chimeway.Repo,
  url: nil,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: unique_database
```

[VERIFIED: guides/introduction/installation.md, guides/introduction/golden-path.md, lib/chimeway/dispatch/executor.ex]

### Public proof shape

```elixir
{:ok, result} =
  Chimeway.trigger(ArtifactConsumer.Notifiers.CoreTrace, %{user_id: "proof-user"},
    tenant_id: "proof-tenant",
    idempotency_key: "core-trace-proof-v1"
  )

[delivery_id] = result.trace.delivery_ids
{:ok, explanation} = Chimeway.Traces.explain_delivery(delivery_id)

assert explanation.notification_key == "artifact_consumer.core_trace"
assert explanation.status == :succeeded
assert :event_created in Enum.map(explanation.timeline, & &1.event)
assert :attempt_recorded in Enum.map(explanation.timeline, & &1.event)
```

[VERIFIED: test/chimeway/integration/readme_snippet_test.exs, lib/chimeway/traces.ex]

## State of the Art

| Old Approach | Current Approach | Impact |
|---|---|---|
| Phase 79 packaged-doc marker proof | Phase 93 runnable unpacked-artifact consumer | Packaging documentation alone cannot prove a host can install, migrate, boot, trigger, and explain a durable lifecycle. [VERIFIED: .planning/milestones/v1.14-phases/79-front-door-and-docs-ia/79-CONTEXT.md, 93-CONTEXT.md] |
| In-repo installer fixture path dependency | Artifact-only temporary consumer dependency | The existing fixture remains useful for generator tests but is not provenance evidence. [VERIFIED: test/support/installer_fixture.ex, 93-CONTEXT.md] |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|---|---|---|
| A1 | The generated consumer should directly declare `ecto_sql` and `postgrex` to compile its own Repo rather than rely on transitive compilation visibility. | Standard Stack | Consumer Mix compilation may need a small dependency declaration adjustment. |
| A2 | A public script with `assert`/nonzero exit is the clearest evidence boundary. | Supporting / Patterns | Planner may instead select a compiled `mix` task; either is valid if it remains consumer-owned and public-API-only. |

## Open Questions

1. **Should the Core artifact contract stay inside `mix ci.verify_gates`?**
   - What we know: that job already provisions PostgreSQL 15 and runs the existing release gate contract. [VERIFIED: .github/workflows/ci.yml, mix.exs]
   - Recommendation: keep this Phase-93 contract in the existing anchor now; do not create a dedicated lane before Phase 96.
2. **What exact safe evidence serialization should the consumer print?**
   - What we know: the explanation struct exposes safe public lifecycle fields, and existing tests forbid sensitive keys in timeline details. [VERIFIED: lib/chimeway/traces/explanation.ex, test/chimeway/traces_test.exs]
   - Recommendation: print only a fixed map of notification key, delivery ID, status, last-attempt outcome, and timeline event atoms; do not print full structs.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|---|---|---:|---|---|
| Elixir / Mix | artifact build and consumer commands | ✓ | 1.19.5 | project floor is 1.17+ |
| PostgreSQL listener | temporary consumer DB | ✓ | `/tmp:5432` accepting connections | CI PostgreSQL 15 service |
| `psql` | optional diagnostics | ✓ | 14.17 | Ecto storage API |
| Docker | local PostgreSQL provisioning if needed | ✓ | 29.5.2 | existing local listener / CI service |
| Hex | artifact build | ✓ | installed via Mix environment | no fallback; required |

**Missing dependencies with no fallback:** none detected. [VERIFIED: local availability probe]

## Validation Architecture

### Test Framework

| Property | Value |
|---|---|
| Framework | ExUnit via Mix. [VERIFIED: mix.exs, test/chimeway/release_gate_contract_test.exs] |
| Config file | `config/test.exs`. [VERIFIED: config/test.exs] |
| Quick run command | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors` |
| Full suite command | `mix ci.verify_gates` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|---|---|---|---|---|
| PROOF-01 | Build/unpack then consumer resolves only artifact path | integration contract | `mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors` | ❌ Wave 0 |
| PROOF-02 | Consumer generates migrations, creates/migrates unique DB, boots | integration contract | same | ❌ Wave 0 |
| PROOF-03 | Consumer uses only `explain_delivery/1` for lifecycle evidence | integration contract | same | ❌ Wave 0 |
| CORE-01 | Notifier → trigger → terminal delivery → sanitized explanation | integration contract | same | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** targeted release-gate contract command.
- **Per wave merge:** `mix ci.verify_gates`.
- **Phase gate:** `mix ci.verify_gates` green; no Phase-96 command/lane is added early. [VERIFIED: mix.exs, 93-CONTEXT.md]

### Wave 0 Gaps
- [ ] `test/support/artifact_consumer_fixture.ex` — deterministic scaffold, command runner, unique DB cleanup, and diagnostics.
- [ ] `test/chimeway/release_gate_contract_test.exs` — Core artifact proof describe block that calls the fixture.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---|---|---|
| V2 Authentication | No | The proof has no auth surface; tenant is an explicit stable host-owned input. [VERIFIED: 93-CONTEXT.md] |
| V3 Session Management | No | No session management in the temporary CLI consumer. [VERIFIED: 93-CONTEXT.md] |
| V4 Access Control | No | No operator/admin endpoint is introduced. [VERIFIED: 93-CONTEXT.md] |
| V5 Input Validation | Yes | Use fixed test inputs; Chimeway validates tenant and idempotency inputs. [VERIFIED: lib/chimeway/trigger.ex] |
| V6 Cryptography | No | No cryptographic feature is added. [VERIFIED: 93-CONTEXT.md] |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---|---|---|
| Sensitive test data printed in failure/success output | Information disclosure | Fixed non-sensitive IDs and allowlisted evidence map only. [VERIFIED: AGENTS.md, test/chimeway/traces_test.exs] |
| Database collision/destructive cleanup | Tampering / DoS | Unique generated DB name, explicit `current_database()` assertion, and cleanup only for that known name. [VERIFIED: test/support/generated_prefixed_runtime_case.ex] |
| Artifact provenance bypass | Tampering | Consumer source contains only unpacked artifact dependency and contract rejects root path. [VERIFIED: 93-CONTEXT.md] |

## Sources

### Primary (HIGH confidence)
- Repository contracts and fixtures: `93-CONTEXT.md`, `mix.exs`, `test/chimeway/release_gate_contract_test.exs`, `test/support/generated_prefixed_runtime_case.ex`, `test/support/installer_fixture.ex`.
- Public APIs and safety contracts: `lib/chimeway/trigger.ex`, `lib/chimeway/traces.ex`, `lib/chimeway/traces/explanation.ex`, `test/chimeway/integration/readme_snippet_test.exs`, `test/chimeway/traces_test.exs`.
- Project and CI constraints: `AGENTS.md`, `.github/workflows/ci.yml`, `guides/introduction/installation.md`, `guides/introduction/golden-path.md`.

### Secondary (MEDIUM confidence)
- [Hex `mix hex.build` documentation](https://hex.hexdocs.pm/Mix.Tasks.Hex.Build.html).
- [Ecto `mix ecto.create` documentation](https://hexdocs.pm/ecto/Mix.Tasks.Ecto.Create.html).
- [Ecto SQL `mix ecto.migrate` documentation](https://hexdocs.pm/ecto_sql/Mix.Tasks.Ecto.Migrate.html).

### Tertiary (LOW confidence)
- None beyond A1/A2, which are explicitly logged as assumptions.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — existing project toolchain and CI directly establish it.
- Architecture: HIGH — directly constrained by Phase 93 decisions and proven local fixture patterns.
- Pitfalls: HIGH — derived from existing artifact and temporary-PostgreSQL test code.

**Research date:** 2026-08-08  
**Valid until:** 2026-09-07 (repository-local implementation guidance; re-check Hex/Ecto docs before a major toolchain update).
