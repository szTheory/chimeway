# Phase 96: Adoption Front Door & Proof Gate - Research

**Researched:** 2026-08-10  
**Domain:** Elixir Mix-task orchestration, ExDoc/Markdown adoption guidance, artifact-consumer proof contracts, and PostgreSQL-backed GitHub Actions gates  
**Confidence:** HIGH for repository integration; MEDIUM for upstream Mix/ExDoc/GitHub Actions guidance

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Create one canonical static Markdown adoption selector in `guides/introduction/`, listed first in the ExDoc Introduction extras and linked prominently from the README documentation/quick-start surface. Do not build cards, a browser experience, or a second tutorial.
- **D-02:** Make the selector outcome-first with exactly Core, Mailglass, and Accrue rows. Every row must consistently provide: “Choose this when”, a Host / Chimeway / partner responsibility split, a copyable focused proof command, one representative sanitized `CHIMEWAY_*_PROOF` record shape, an explicit “Does not cover” boundary, and a link to its canonical detailed guide.
- **D-03:** Preserve progressive disclosure: the selector helps an adopter choose and evaluate; the existing Golden Path, Mailglass, and Accrue guides remain the sole owners of detailed setup and lifecycle explanation. README stays concise and links through rather than copying the selector content.
- **D-04:** Use literal, calm developer-to-developer microcopy: what happened → why it matters → next step. Use “proof”, “trace”, “attempt”, “host-owned”, and “compatibility evidence”; never overclaim delivery or expose fixture/CI internals.
- **D-05:** Implement `mix verify.adoption_paths` as one documented, purpose-built Mix task with a bounded `--only core|mailglass|accrue` option; without `--only`, it runs all three paths. The all-path form is the canonical CI/release gate, and the scoped form is the local recovery loop.
- **D-06:** Have the Mix task delegate orchestration to one local runner rather than a long inline alias command. It must serially compose the existing artifact-consumer proof capabilities and keep proof construction, unpacked-artifact provenance, lifecycle validation, evidence parsing, and cleanup in the package-owned fixture.
- **D-07:** Preserve the existing strict, one-record `CHIMEWAY_CORE_PROOF`, `CHIMEWAY_MAILGLASS_PROOF`, and `CHIMEWAY_ACCRUE_PROOF` formats as the automation interface. Add fixed, redacted path `START`, `PASS`, and `FAIL` framing with only path, safe stage, exit status, safe token/provenance facts, and rerun command.
- **D-08:** Never present `verify.mailglass` or `verify.accrue` as adopter proof commands: they remain broader repository-maintainer regression suites. Do not dump generated-host output, database URLs/names, archive or temporary paths, payloads, recipients, credentials, provider responses, raw structs, SQL, or full exceptions.
- **D-09:** Preserve the prior proof truth boundaries verbatim in selector-facing language: Core proves a durable lifecycle/public trace, not external delivery; Mailglass Fake proves local host composition and Chimeway adapter orchestration, not provider acceptance/sender verification/inbox placement/live feedback; Accrue preserves its event-to-signal and non-terminal `active / signal_received` semantics plus released-package versus SHA-qualified compatibility terminology.
- **D-10:** Add exactly one dedicated PostgreSQL 15-backed `verify_adoption_paths` CI job that invokes the aggregate `mix verify.adoption_paths` command, uses the established root setup/cache/service-container patterns, retains bounded per-path diagnostics, and runs serially.
- **D-11:** Run the dedicated adoption job on every CI event and make both `pr-gate` and full push/dispatch `ci-gate` consume it. The clean-room adopter proof is a release-critical contract whose exact-SHA behavior must be visible before merge as well as on main/release paths.
- **D-12:** Do not run detailed partner suites, check out sibling partner repositories, add a local registry/Compose stack/source-path fallback, cache generated temporary hosts/databases, or split into three jobs/matrix legs. One lane is the lower-risk baseline; split later only if measured timing and failure isolation justify it.
- **D-13:** Extend the existing documentation and release-gate ExUnit contracts rather than creating a parallel shell truth checker. Contract coverage must bind all-and-only the three path keys, selector wording, guide locations, responsibility/limitation anchors, exact command forms, safe evidence tokens, fixture capabilities, Mix task option validation, CI job/service/command, and both `pr-gate` and `ci-gate` aggregation.
- **D-14:** Include negative drift cases: unknown/duplicate `--only` values fail without a proof record; an aggregate run invokes each path once; focused runs invoke only their selected path; commands cannot regress to partner suites; unsafe/duplicate proof records, missing selector links, missing PostgreSQL CI service, removed aggregator membership, or renamed job/task fail the contract.
- **D-15:** Keep behavioral execution and structural contracts separate: contracts protect low-cost textual/config parity on PRs; the adoption CI lane proves the actual three clean-room behaviors from a built/unpacked artifact. Neither is a substitute for the other.

### the agent's Discretion

- Exact guide filename/title, table markup, ordered headings, task/runner module and script names, safe diagnostic stage vocabulary, focused test-module placement, CI timeout, and cache-key spelling, provided the locked command semantics, redaction boundary, one-lane topology, and contracts remain intact.

### Deferred Ideas (OUT OF SCOPE)

- A visual/browser adoption chooser, cards, responsive UI, or admin/operator proof — outside this documentation and CI phase.
- Three parallel/matrix adoption CI jobs or per-path required checks — defer unless measured runtime/failure-isolation needs justify expanding the current single required lane.
- A broadly supported Hex-consumer CLI, arbitrary path selectors, JSON reporting, or user-facing task APIs beyond bounded repository proof invocation — reconsider only if a later milestone establishes that support contract.
- Live provider/payment acceptance, credentials, sender/domain verification, inbox placement, webhooks, and production partner feedback — remain host/provider responsibility outside deterministic proofs.
- Sigra, Threadline, Inbox, and other future adoption paths — future ADPT-03 work after the three primary paths establish the reusable model.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|---|---|---|
| ADPT-01 | Adopter chooses Core, Mailglass, or Accrue and understands Chimeway/partner responsibility. | Selector is one first-listed ExDoc extra with exactly three canonical-path rows and responsibility/limitation anchors. [VERIFIED: 96-CONTEXT.md] |
| ADPT-02 | Each path documents a proof command, observable outcome, and coverage boundary. | Preserve the fixture parsers’ fixed safe records and canonical guide boundaries; selector links through rather than reproducing setup. [VERIFIED: `priv/adoption_proof/artifact_consumer_fixture.ex`, `guides/introduction/*.md`] |
| GATE-01 | `mix verify.adoption_paths` runs clean-room proofs without partner-suite duplication. | A Mix task plus a local runner should build/unpack once and call fixture `prove_core!/2`, `prove_mailglass!/2`, and `prove_accrue!/2` serially. [VERIFIED: `priv/adoption_proof/artifact_consumer_fixture.ex`, 96-CONTEXT.md] |
| GATE-02 | CI has a dedicated PostgreSQL adopter-proof lane with useful diagnostics. | Reuse the PostgreSQL 15 root-lane shape; run one bounded lane on every CI event and require it from both `pr-gate` and `ci-gate`. [VERIFIED: `.github/workflows/ci.yml`, 96-CONTEXT.md] |
| DOCS-01 | Selector, commands, fixture guidance, and CI entrypoint cannot silently drift. | Extend the two existing ExUnit contract modules with positive and negative parity cases. [VERIFIED: `test/chimeway/doc_contract_test.exs`, `test/chimeway/release_gate_contract_test.exs`] |
</phase_requirements>

## Project Constraints (from AGENTS.md)

- Retain stable `notification_key` plus version as durable identity; do not use module names as durable identity. [VERIFIED: `AGENTS.md`]
- Preserve the durable `event -> notification -> delivery -> attempt` lifecycle and make idempotency/suppression explainable. [VERIFIED: `AGENTS.md`]
- Keep adapter seams replaceable and preserve host ownership of auth, tenancy, URLs, and correlation IDs. [VERIFIED: `AGENTS.md`]
- Maintain `mix verify.*` and `mix ci.*` entrypoints, keep CI/local parity, and do not expose sensitive payload fields in telemetry or operator/developer surfaces. [VERIFIED: `AGENTS.md`]

## Summary

Phase 96 should compose, not recreate, the three completed artifact-consumer proofs. The package already contains one fixture module with independently callable Core, Mailglass, and Accrue proof functions; each creates an isolated temporary host/database, validates artifact provenance, parses a fixed allowlisted proof line, and cleans up. The new public entrypoint therefore needs only to build an artifact once, dispatch bounded path keys serially to those functions through a local runner, and emit its own redacted framing around the authoritative existing record. [VERIFIED: `priv/adoption_proof/artifact_consumer_fixture.ex`, `scripts/prove-accrue-consumer.exs`]

The documentation front door should be a short, static Markdown selector placed first in `mix.exs` ExDoc Introduction extras and linked from README. Its job is decision and proof evaluation, while the existing Core, Mailglass, and Accrue guides retain installation/lifecycle detail. ExDoc explicitly supports ordered Markdown extras, which fits this constrained information architecture. [VERIFIED: `mix.exs`; CITED: https://ex-doc.hexdocs.pm/ExDoc.html]

The new CI behavior belongs in one PostgreSQL 15 lane that runs on every CI event and is required by both `pr-gate` and `ci-gate`. The bounded clean-room proof is an adopter-facing release contract, so exact behavior is proven before merge as well as on main/release paths; the structural `verify_gates` contracts remain a separate, cheaper parity check. GitHub’s service-container guidance supports the repository’s existing Ubuntu + mapped PostgreSQL service pattern. [VERIFIED: `.github/workflows/ci.yml`, 96-CONTEXT.md; CITED: https://docs.github.com/en/actions/tutorials/use-containerized-services/create-postgresql-service-containers]

**Primary recommendation:** Implement a bounded `Mix.Tasks.Verify.AdoptionPaths` façade backed by one artifact-build/dispatch runner, then atomically add selector/docs, the single CI lane, and structural ExUnit drift contracts.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|---|---|---|---|
| Adoption path selection and ownership explanation | Static docs / ExDoc | README | It is documentation-first decision support, with README only routing to the canonical selector. [VERIFIED: 96-CONTEXT.md] |
| Path parsing and aggregate command behavior | API / Backend (Mix task) | Local runner | The repository command owns bounded CLI validation and orchestration; it is not a browser or host-app feature. [VERIFIED: 96-CONTEXT.md] |
| Artifact build, clean-host lifecycle, evidence parsing, cleanup | Package-owned fixture | PostgreSQL storage | Existing fixture already owns provenance, generated consumer, lifecycle assertions, and cleanup. [VERIFIED: `priv/adoption_proof/artifact_consumer_fixture.ex`] |
| Durable lifecycle persistence | Generated consumer PostgreSQL database | Fixture | Each proof migrates a unique temporary database and removes it afterward. [VERIFIED: `priv/adoption_proof/artifact_consumer_fixture.ex`] |
| CI execution and aggregation | GitHub Actions | PostgreSQL service container | The workflow owns runner/service/cache setup and membership in both `pr-gate` and `ci-gate`. [VERIFIED: `.github/workflows/ci.yml`] |
| Drift prevention | ExUnit contract suites | PR gate | Existing doc and release-gate contracts already test file/CI/package truth and run through `mix ci.verify_gates`. [VERIFIED: `mix.exs`, `test/chimeway/doc_contract_test.exs`, `test/chimeway/release_gate_contract_test.exs`] |

## Standard Stack

### Core

| Library / facility | Version | Purpose | Why Standard |
|---|---:|---|---|
| Elixir / Mix.Task | project floor `~> 1.17`; local `1.19.5` | Purpose-built `mix verify.adoption_paths` command. | Existing project tasks use `Mix.Task`; Elixir’s `OptionParser.parse/2` is the documented argv parser. [VERIFIED: `mix.exs`, `lib/mix/tasks/verify_published.ex`; CITED: https://hexdocs.pm/elixir/OptionParser.html] |
| Existing `ArtifactConsumerFixture` | package-owned local module | Executes and validates all three clean-room proofs. | It already exposes the exact Core/Mailglass/Accrue paths and strict proof parsers; duplicating the proofs would weaken parity. [VERIFIED: `priv/adoption_proof/artifact_consumer_fixture.ex`] |
| ExUnit contract suites | existing | Enforce doc, task, fixture, workflow, and aggregate truth. | `ci.verify_gates` already executes the two established contract modules. [VERIFIED: `mix.exs`, `test/chimeway/doc_contract_test.exs`, `test/chimeway/release_gate_contract_test.exs`] |
| ExDoc extras | existing `ex_doc ~> 0.31` | Canonical selector navigation. | ExDoc supports ordered Markdown extras and the repository already groups Introduction guides through `groups_extras`. [VERIFIED: `mix.exs`; CITED: https://ex-doc.hexdocs.pm/ExDoc.html] |
| GitHub Actions + PostgreSQL 15 service | existing | Aggregate behavioral proof lane. | Existing root jobs provide the service health-check and `localhost` configuration; this lane applies the shape on every event. [VERIFIED: `.github/workflows/ci.yml`; CITED: https://docs.github.com/en/actions/tutorials/use-containerized-services/create-postgresql-service-containers] |

### Supporting

| Facility | Version | Purpose | When to Use |
|---|---:|---|---|
| `scripts/test-db` | existing | Starts the project-scoped Docker PostgreSQL service for local test commands when no `DATABASE_URL` is set. | Use for contract tests/local verification; do not make it a second adoption orchestration stack. [VERIFIED: `scripts/test-db`] |
| `scripts/ci/aggregate-gate.sh` | existing | Fails an aggregate job when a required dependency fails. | Extend both aggregate gates' environment/argument lists with the new job’s result. [VERIFIED: `.github/workflows/ci.yml`, `scripts/ci/aggregate-gate.sh`] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|---|---|---|
| Purpose-built Mix task + runner | Long `mix.exs` alias | Rejected: aliases cannot cleanly own bounded option validation, safe per-path framing, build-once state, or focused test seams. [VERIFIED: 96-CONTEXT.md] |
| One serial aggregate CI lane | Three jobs/matrix | Rejected by locked scope: increases topology/cache/failure-isolation surface before timing data justifies it. [VERIFIED: 96-CONTEXT.md] |
| Existing two ExUnit contract suites | New shell truth checker | Rejected by locked scope: duplicates truth ownership and bypasses `ci.verify_gates`. [VERIFIED: 96-CONTEXT.md] |

**Installation:** No external packages are required or permitted for this phase. [VERIFIED: 96-CONTEXT.md, `mix.exs`]

## Architecture Patterns

### System Architecture Diagram

```text
README + ExDoc Introduction
          |
          v
Canonical adoption selector (Core | Mailglass | Accrue)
          |                         |                  |
          +---- canonical guide ----+------------------+
          |
          v
mix verify.adoption_paths [--only path]
          |
          +--> validate exactly zero or one bounded --only value
          |
          v
local runner: build/unpack artifact once; serially dispatch selected paths
          |
          +--> ArtifactConsumerFixture.prove_core! ----> CHIMEWAY_CORE_PROOF
          +--> ArtifactConsumerFixture.prove_mailglass! > CHIMEWAY_MAILGLASS_PROOF
          +--> ArtifactConsumerFixture.prove_accrue! --> CHIMEWAY_ACCRUE_PROOF
          |
          v
redacted START / PASS / FAIL framing + safe rerun command
          |
          +--> local focused recovery
          \--> verify_adoption_paths CI job (PostgreSQL 15) --> pr-gate + ci-gate

doc_contract_test + release_gate_contract_test ---------> enforce selector/task/fixture/CI parity
```

### Recommended Project Structure

```text
lib/mix/tasks/
└── verify.adoption_paths.ex          # CLI façade: parse/validate --only; delegate only

scripts/
└── prove-adoption-paths.exs          # build/unpack once; serial dispatch; safe framing

guides/introduction/
└── adoption-paths.md                 # selector only; links to the three existing guides

test/chimeway/
├── doc_contract_test.exs             # selector/README/guide anchors and limitations
└── release_gate_contract_test.exs    # task/runner/fixture/CI/both gates + negative drift
```

### Pattern 1: Thin bounded task, stateful local runner

**What:** `Mix.Tasks.Verify.AdoptionPaths` accepts only `--only core|mailglass|accrue`, exits before proof work for invalid/duplicate/positional input, then invokes a single runner with the selected list. The runner owns one artifact build/unpack and calls existing fixture functions serially. [VERIFIED: 96-CONTEXT.md]

**When to use:** Always for the new entrypoint; it supports the all-path release gate and a focused local recovery loop without a public arbitrary-path API. [VERIFIED: 96-CONTEXT.md]

**Example:**

```elixir
# Source: https://hexdocs.pm/elixir/OptionParser.html; adapt to project runner API.
def run(argv) do
  {opts, args, invalid} = OptionParser.parse(argv, strict: [only: :string])

  case {opts, args, invalid} do
    {[only: path], [], []} when path in ["core", "mailglass", "accrue"] ->
      Chimeway.AdoptionProofRunner.run!([path])

    {[], [], []} ->
      Chimeway.AdoptionProofRunner.run!(["core", "mailglass", "accrue"])

    _ ->
      Mix.raise("usage: mix verify.adoption_paths [--only core|mailglass|accrue]")
  end
end
```

Do not use a permissive parser: `OptionParser` returns invalid options separately, so route that branch to usage before building an artifact. [CITED: https://hexdocs.pm/elixir/OptionParser.html]

### Pattern 2: Keep authoritative evidence untouched; frame it safely

**What:** Print a deterministic per-path `START`, exactly one already-validated `CHIMEWAY_*_PROOF`, then `PASS`; on any exception/nonzero, print one bounded `FAIL stage=<safe-stage> status=<integer>` plus the focused rerun command and re-raise/exit nonzero. [VERIFIED: 96-CONTEXT.md]

**When to use:** At runner boundaries only. The fixture remains the owner of proof construction, parser validation, provenance checks, and cleanup. [VERIFIED: `priv/adoption_proof/artifact_consumer_fixture.ex`, 96-CONTEXT.md]

**Anti-patterns to Avoid**

- **Re-emitting parsed maps with `inspect/1`:** leaks values and breaks the existing explicit proof allowlist; print the original validated record only. [VERIFIED: `priv/adoption_proof/artifact_consumer_fixture.ex`, 96-CONTEXT.md]
- **Calling `mix verify.mailglass` or `mix verify.accrue`:** these are root-plus-demo/sibling-maintainer suites, not artifact-consumer adopter proof. [VERIFIED: `mix.exs`, `guides/introduction/mailglass-integration.md`, `guides/introduction/accrue-dunning-integration.md`]
- **Task delegates each proof to a fresh `mix` subprocess:** loses build-once provenance and creates repeated artifact work; runner dispatch must be serial in-process/local. [VERIFIED: 96-CONTEXT.md]
- **A second detailed selector tutorial:** duplicates guide ownership and will drift. [VERIFIED: 96-CONTEXT.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| Clean consumer scaffolding and lifecycle proof | New Core/Mailglass/Accrue host scripts | `ArtifactConsumerFixture.prove_core!/2`, `prove_mailglass!/2`, `prove_accrue!/2` | Existing code performs provenance validation, migrations, public-trace assertions, strict evidence parsing, and cleanup. [VERIFIED: `priv/adoption_proof/artifact_consumer_fixture.ex`] |
| Evidence schema/parser | Generic JSON/log dump parser | Existing `parse_*_evidence!` functions and original proof lines | Existing parsers reject unknown/duplicate/malformed fields and constrain the safe vocabulary. [VERIFIED: `priv/adoption_proof/artifact_consumer_fixture.ex`] |
| Adoption CI service setup | New Compose/local-registry lane | Existing GitHub PostgreSQL-15/root-cache/job pattern | It is already proven in repository CI and aligns with scope. [VERIFIED: `.github/workflows/ci.yml`, 96-CONTEXT.md] |
| Documentation drift checker | Standalone shell grep script | `doc_contract_test.exs` and `release_gate_contract_test.exs` | Established `mix ci.verify_gates` entrypoint protects the release/docs boundary. [VERIFIED: `mix.exs`, 96-CONTEXT.md] |

**Key insight:** the phase’s value is a truthful composition boundary. Any replacement implementation introduces a second proof source and makes “what adopters ran” diverge from “what CI proved.” [VERIFIED: 96-CONTEXT.md]

## Common Pitfalls

### Pitfall 1: Accidentally treating a maintainer regression suite as adopter proof

**What goes wrong:** Selector copy or runner dispatch points at `mix verify.mailglass`/`mix verify.accrue`, bringing demo-host/sibling checkout behavior into a purported clean-room proof. [VERIFIED: `mix.exs`, existing integration guides]

**How to avoid:** Contracts must forbid those command forms in selector-facing material and assert the runner maps only three bounded keys to fixture proof functions. [VERIFIED: 96-CONTEXT.md]

### Pitfall 2: Safe evidence becomes an unsafe diagnostic dump

**What goes wrong:** Rescuing exceptions with `Exception.message`, `inspect`, raw subprocess output, database names, or temp paths exposes inputs the proof deliberately redacts. [VERIFIED: 96-CONTEXT.md]

**How to avoid:** A fixed stage enum and fixed `START/PASS/FAIL` grammar; test forbidden tokens and require no proof record on invalid CLI input. [VERIFIED: 96-CONTEXT.md]

### Pitfall 3: CI gate wiring drifts while the job still exists

**What goes wrong:** `verify_adoption_paths` exists but is omitted from either aggregate gate or skipped on an event where that gate runs. [VERIFIED: `.github/workflows/ci.yml`, 96-CONTEXT.md]

**How to avoid:** Contract-test job ID, PostgreSQL 15 service, aggregate command, every-event execution, and needs/env/argument membership in both `pr-gate` and `ci-gate`. [VERIFIED: 96-CONTEXT.md]

### Pitfall 4: Building/unpacking separately for each path

**What goes wrong:** CI cost triples and path provenance is harder to compare; temporary resources may be left after a partial run. [VERIFIED: 96-CONTEXT.md]

**How to avoid:** Runner builds/unpacks once, invokes paths serially, lets each fixture invocation retain unique resource identity/cleanup, and stops on failure after emitting bounded path context. [VERIFIED: `priv/adoption_proof/artifact_consumer_fixture.ex`, 96-CONTEXT.md]

## Code Examples

### CI lane shape

```yaml
# Source: existing .github/workflows/ci.yml plus GitHub Actions PostgreSQL service docs.
verify_adoption_paths:
  name: Adoption proof paths
  runs-on: ubuntu-latest
  services:
    postgres:
      image: postgres:15
      env:
        POSTGRES_PASSWORD: postgres
      options: >-
        --health-cmd pg_isready
        --health-interval 10s
        --health-timeout 5s
        --health-retries 5
      ports: ["5432:5432"]
  env:
    MIX_ENV: test
    DATABASE_URL: postgres://postgres:postgres@localhost/chimeway_test
  # Same checkout/setup-beam/cache/deps/compile/DB-prep pattern as current root lanes.
  # Final behavioral command: mix verify.adoption_paths
```

Runner-machine jobs access the mapped PostgreSQL service at `localhost`; retain the project’s existing health checks and cache strategy instead of adding Docker Compose. [CITED: https://docs.github.com/en/actions/tutorials/use-containerized-services/create-postgresql-service-containers; VERIFIED: `.github/workflows/ci.yml`]

### Selector row contract

```markdown
| Path | Choose this when | Ownership | Proof | Does not cover | Details |
| --- | --- | --- | --- | --- | --- |
| Mailglass | You want deterministic transactional-email composition. | Host: mailable/config. Chimeway: adapter attempt/trace. Partner: provider acceptance. | `mix verify.adoption_paths --only mailglass` → one `CHIMEWAY_MAILGLASS_PROOF transport=fake ...` record. | Provider acceptance, sender/domain verification, inbox placement, live feedback. | [Mailglass guide](mailglass-integration.md) |
```

The final wording must retain the canonical guide’s exact limitation vocabulary; this is a layout pattern, not authority to shorten the coverage boundary. [VERIFIED: `guides/introduction/mailglass-integration.md`, 96-CONTEXT.md]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|---|---|---|---|
| Individual Core, Mailglass, and Accrue proof capabilities with no unified adopter entrypoint | One documented aggregate command composed from the three existing capabilities | Phase 96 | Gives a prospective adopter a bounded choice and CI a single behavior gate without altering runtime integrations. [VERIFIED: 96-CONTEXT.md] |
| Root/demo/sibling integration verification commands | Artifact-consumer proof as adopter-facing evidence; maintainer suites remain separate | Phases 93–95 | Prevents source checkout and partner-suite mechanics from being presented as package-consumer proof. [VERIFIED: `mix.exs`, phase 93–95 guides and contexts] |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|---|---|---|
| — | None. All implementation recommendations are constrained by locked phase decisions, existing repository seams, or cited official documentation. | — | — |

## Open Questions (RESOLVED)

1. **Safe failure-stage names and runner file/module name**
   - Resolution: keep `Mix.Tasks.Verify.AdoptionPaths` as the thin CLI facade in `lib/mix/tasks/verify.adoption_paths.ex`; after strict option validation it requires the package-shipped `scripts/prove-adoption-paths.exs` and calls `Chimeway.AdoptionProofRunner.run!/1`. The runner owns build-once/unpack-once serial orchestration while `ArtifactConsumerFixture` remains the proof authority. [VERIFIED: 96-CONTEXT.md; selected in 96-01-PLAN.md]
   - Stable safe stage vocabulary: exactly `build`, `unpack`, `core`, `mailglass`, and `accrue`. `FAIL` framing may emit only one of these literals as `stage=<stage>`; contracts reject any other stage and any interpolated exception, output, path, database, or private value. [VERIFIED: 96-CONTEXT.md; selected in 96-01-PLAN.md]

2. **CI timeout value**
   - Resolution: set `timeout-minutes: 30` on the `verify_adoption_paths` GitHub Actions job. This bounds the single serial lane while allowing three existing proof paths whose individual release-gate contracts already permit up to ten minutes; future changes require measured CI evidence and a coordinated contract update. [VERIFIED: `test/chimeway/release_gate_contract_test.exs`, 96-CONTEXT.md; selected in 96-02-PLAN.md]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|---|---|---|---|---|
| Elixir / Mix | task, runner, ExUnit contracts | ✓ | Elixir/Mix 1.19.5, OTP 28 locally | CI pins repository `.tool-versions`. [VERIFIED: local command, `.tool-versions`] |
| Docker | local `scripts/test-db` PostgreSQL setup | ✓ | Docker 29.5.2 | Existing project-local PostgreSQL service only; no Compose adoption-proof stack. [VERIFIED: local command, `scripts/test-db`] |
| PostgreSQL client | local diagnostics | ✓ | psql 14.17 | CI uses PostgreSQL 15 service container. [VERIFIED: local command, `.github/workflows/ci.yml`] |
| GitHub Actions PostgreSQL service | dedicated behavioral lane | configured | PostgreSQL 15 | No fallback required; reuse existing workflow pattern. [VERIFIED: `.github/workflows/ci.yml`] |

**Missing dependencies with no fallback:** None. [VERIFIED: local availability probes]

## Validation Architecture

### Test Framework

| Property | Value |
|---|---|
| Framework | ExUnit (existing project suite). [VERIFIED: `test/test_helper.exs`] |
| Config file | `test/test_helper.exs`. [VERIFIED: `test/test_helper.exs`] |
| Quick run command | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/doc_contract_test.exs test/chimeway/release_gate_contract_test.exs --warnings-as-errors` [VERIFIED: `mix.exs`] |
| Full suite command | `mix ci.verify_gates` for contracts; `mix verify.adoption_paths` for actual clean-room behavior. [VERIFIED: `mix.exs`, 96-CONTEXT.md] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|---|---|---|---|---|
| ADPT-01 | Selector has all-and-only three paths, ownership splits, README link, first ExDoc extra, and canonical guide links. | documentation contract | `mix ci.verify_gates` | ✅ extend existing contracts |
| ADPT-02 | Every selector row has exact focused command, one safe evidence shape, and canonical limitation wording. | documentation/release contract | `mix ci.verify_gates` | ✅ extend existing contracts |
| GATE-01 | No-option aggregate invokes each path once; `--only` invokes exactly one; invalid/duplicate selectors fail before a proof record; no partner suite commands. | task/runner contract + integration | `mix ci.verify_gates`; `mix verify.adoption_paths` | ✅ extend existing contracts; runner tests are Wave 0 additions |
| GATE-02 | One every-event PostgreSQL-15 job invokes the aggregate command and is required by both `pr-gate` and `ci-gate`. | CI topology contract | `mix ci.verify_gates` | ✅ extend `release_gate_contract_test.exs` |
| DOCS-01 | Negative drift cases reject unsafe/duplicate records, missing links/service, task/job rename, or removed aggregation. | negative contract | `mix ci.verify_gates` | ✅ extend existing contracts |

### Sampling Rate

- **Per task commit:** `mix ci.verify_gates` for structural changes; `mix verify.adoption_paths --only <path>` for runner changes. [VERIFIED: 96-CONTEXT.md]
- **Per wave merge:** `mix verify.adoption_paths`. [VERIFIED: 96-CONTEXT.md]
- **Phase gate:** green `mix ci.verify_gates` and one successful dedicated `verify_adoption_paths` CI run before phase verification. [VERIFIED: `AGENTS.md`, 96-CONTEXT.md]

### Wave 0 Gaps

- [ ] Extend `test/chimeway/doc_contract_test.exs` with selector-first/README/guide/limitation contracts.
- [ ] Extend `test/chimeway/release_gate_contract_test.exs` with task option, runner dispatch/framing, fixture capability, CI service/command, and gate-membership contracts.
- [ ] Add focused task/runner tests only if direct invocation cannot be safely covered through release-gate contracts; do not add a parallel checker. [VERIFIED: 96-CONTEXT.md]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---|---|---|
| V2 Authentication | No | No authentication surface is introduced. [VERIFIED: 96-CONTEXT.md] |
| V3 Session Management | No | No session surface is introduced. [VERIFIED: 96-CONTEXT.md] |
| V4 Access Control | No | The task operates only in the maintainer repository/CI context; it must not become a host-app API. [VERIFIED: 96-CONTEXT.md] |
| V5 Input Validation | Yes | Strictly parse the bounded `--only` value; reject unknown, duplicate, malformed, and positional input before artifact/proof work. [VERIFIED: 96-CONTEXT.md; CITED: https://hexdocs.pm/elixir/OptionParser.html] |
| V6 Cryptography | No new control | Reuse existing package archive SHA-256 validation; do not implement a new digest scheme. [VERIFIED: `scripts/prove-accrue-consumer.exs`] |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---|---|---|
| CLI option expands proof scope or invokes an unintended path | Tampering | Literal allowlist and failure-before-output contracts. [VERIFIED: 96-CONTEXT.md] |
| Generated-host/proof error discloses private details | Information disclosure | Fixed safe stage grammar; no raw output, exception, archive, temp path, DB, payload, recipient, credential, SQL, or struct output. [VERIFIED: 96-CONTEXT.md] |
| Forged/malformed evidence record is treated as proof | Tampering | Existing exact-one-line parsers reject unknown, duplicate, malformed, and unsafe values. [VERIFIED: `priv/adoption_proof/artifact_consumer_fixture.ex`] |
| CI workflow appears gated while the job is omitted/skipped | Tampering / repudiation | Structural contracts bind job/service/command/every-event execution plus both aggregate-gate memberships. [VERIFIED: 96-CONTEXT.md] |

## Sources

### Primary (HIGH confidence)

- `96-CONTEXT.md` — locked Phase 96 scope, topology, redaction, and contract decisions.
- `mix.exs`, `.github/workflows/ci.yml`, `scripts/test-db`, `scripts/ci/aggregate-gate.sh` — current command, package, test, CI service/cache, and aggregate patterns.
- `priv/adoption_proof/artifact_consumer_fixture.ex`, `scripts/prove-accrue-consumer.exs` — reusable proof, evidence, provenance, and cleanup behavior.
- `test/chimeway/doc_contract_test.exs`, `test/chimeway/release_gate_contract_test.exs` — existing contract seams and negative-test patterns.
- `README.md` and the three canonical introduction guides — current front door and proof-boundary language.

### Secondary (MEDIUM confidence)

- [Elixir OptionParser](https://hexdocs.pm/elixir/OptionParser.html) — argv parsing behavior.
- [ExDoc configuration](https://ex-doc.hexdocs.pm/ExDoc.html) — Markdown extras and grouping.
- [GitHub Actions PostgreSQL service containers](https://docs.github.com/en/actions/tutorials/use-containerized-services/create-postgresql-service-containers) — runner PostgreSQL service configuration.

### Tertiary (LOW confidence)

- None.

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — existing repository technologies and no new dependencies; upstream API details cited.
- Architecture: HIGH — locked decisions map directly to existing fixture/task/CI/contract seams.
- Pitfalls: HIGH — derived from explicit phase constraints and existing maintainer/adopter-suite split.

**Research date:** 2026-08-10  
**Valid until:** 2026-09-09 for repository findings; revisit upstream tool guidance when upgrading Elixir, ExDoc, or CI actions.
