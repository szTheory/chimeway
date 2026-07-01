# Phase 76: Prefix Docs, Demo, and Gates - Research

**Researched:** 2026-07-01
**Domain:** Elixir/Ecto storage-prefix adoption docs, demo proof, and release gates
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

Source copied from `.planning/phases/76-prefix-docs-demo-and-gates/76-CONTEXT.md`. [VERIFIED: codebase file read]

### Locked Decisions
## Implementation Decisions

### Canonical Storage Docs

- **D-01:** Use a layered documentation model. Keep short install-time truth in `README.md`,
  `guides/introduction/installation.md`, and `guides/introduction/golden-path.md`: new installs use
  `config :chimeway, prefix: "chimeway"` and existing public-schema legacy installs use
  `config :chimeway, prefix: false`.
- **D-02:** Add a dedicated HexDocs-included storage prefix upgrade/troubleshooting guide for
  public-to-`chimeway` manual moves, rollback notes, failure modes, and the full prefix matrix.
  Do not bury UPG-02/UPG-03 only in README, demo-host copy, or MAINTAINING.
- **D-03:** Preserve the existing doc-contract posture that README/install/golden path remain
  beginner-safe: no `--prefix public`, no Oban prefix details, no `mix ecto.migrate --prefix
  chimeway`, and no automatic data-move language in those first-run docs.
- **D-04:** Include the new storage/upgrade guide in `mix.exs` HexDocs extras and add doc contracts
  that lock its required claims and forbidden footguns.

### Upgrade and Public Compatibility

- **D-05:** Treat `prefix: false` as the no-silent-migration compatibility path. It means "keep
  using existing unprefixed/public Chimeway tables" and does not move, copy, rewrite, or backfill
  existing data.
- **D-06:** Frame public-to-`chimeway` movement as a manual operator database procedure with
  preflight checks, backup expectations, transaction/lock caveats, verification queries, rollback
  guidance, and clear "stop and restore" failure notes.
- **D-07:** Do not introduce or imply a first-party automated move task in Phase 76. If the guide
  mentions automation, it must be future/out-of-scope language and must not become the recommended
  production path.
- **D-08:** Keep generator language precise: `mix chimeway.gen.migrations --prefix public` is
  generator-only compatibility sugar for legacy unprefixed migration output; runtime public mode is
  still `config :chimeway, prefix: false`.

### Oban and Ecto Prefix Separation

- **D-09:** Document Chimeway's storage prefix and Oban's job-table prefix as separate operational
  concerns. `config :chimeway, prefix: "chimeway"` routes Chimeway-owned `chimeway_*` tables; it
  does not create, move, or configure `oban_jobs`.
- **D-10:** Put full Oban prefix guidance in `guides/recipes/oban-integration.md` and the new
  storage troubleshooting/upgrade guide, not in the first-run README/install/golden path.
- **D-11:** Use official Oban-style examples for Oban-owned tables, such as
  `Oban.Migration.up(prefix: "jobs")` / `Oban.Migration.down(prefix: "jobs")` and
  `config :my_app, Oban, prefix: "jobs"`. Avoid using `"chimeway"` as the Oban example prefix
  because that implies coupling.
- **D-12:** Guard docs and examples against Ecto prefix footguns: no `@schema_prefix "chimeway"`,
  no public API examples like `Chimeway.trigger(..., prefix: ...)`, no `prefix: "public"` runtime
  config, no `prefix: false` passed into generated Ecto operations, and no reliance on
  `search_path` or `mix ecto.migrate --prefix chimeway`.

### Demo and Gate Parity

- **D-13:** Make `mix verify.runtime_prefix` a first-class CI lane required by `ci-gate` and counted
  by `test/chimeway/release_gate_contract_test.exs`.
- **D-14:** Keep `mix verify.install_golden` / `mix ci.install_golden` as the path-gated installer
  proof. It is heavy and generator-specific, but release contracts should still ensure the alias
  and CI job exist.
- **D-15:** Put DEMO-01 in the existing demo/example proof path instead of creating a new browser
  smoke suite. Configure the demo host for `prefix: "chimeway"` and prove a public
  `Chimeway.trigger/3` or `DemoHost.Seeds` trigger-to-trace flow writes Chimeway rows under
  `chimeway.*` while `public.chimeway_*` remains empty.
- **D-16:** Demo proof must use public APIs and existing adopter-copyable seed paths. Avoid fixture
  inserts or storage internals as the primary acceptance path.
- **D-17:** Update local/CI/release documentation together: `mix.exs` aliases, `.github/workflows/ci.yml`,
  `MAINTAINING.md`, and release-gate contracts must agree on the storage prefix gates.

### User Experience and Voice

- **D-18:** Keep user-facing language calm, literal, and operator-safe: "isolated Chimeway schema",
  "public-schema legacy mode", "does not move data", "manual database operation", and "Oban's
  job table is separate" are preferred over Ecto-internal phrasing in first-run docs.
- **D-19:** Preserve the Chimeway brand posture from prompts: local-first ownership, explainable
  delivery, Elixir-native explicitness, and "no hidden magic." Documentation should help adopters
  make the safe choice without exposing backend internals unless the operational constraint
  requires it.

### the agent's Discretion

The user explicitly requested deep subagent research and a one-shot cohesive recommendation set
so they do not have to choose among medium-stakes options. Downstream agents should implement the
recommended set above unless fresh code evidence makes a decision impossible. If a conflict appears,
preserve the architecture: layered docs, manual upgrade guidance, split Oban guidance, runtime-prefix
CI parity, path-gated installer proof, and demo-host prefix proof through public APIs.

### Deferred Ideas (OUT OF SCOPE)
- First-party automated public-to-`chimeway` production move task.
- Dynamic per-tenant database prefixes.
- Broader README/package/release truth cleanup beyond storage-prefix documentation.
- New browser smoke or UI work for Phase 76 unless implementation discovers that existing demo
  proof cannot satisfy DEMO-01.
</user_constraints>

## Summary

Phase 76 should package the already-built storage-prefix behavior for adoption: keep first-run docs short, add one dedicated storage-prefix upgrade/troubleshooting guide, make Oban prefix separation explicit, prove the demo host writes through public APIs into `chimeway.*`, and make runtime-prefix verification a required CI/release-gate lane. [VERIFIED: 76-CONTEXT.md] Phase 75 is complete and verified: `mix verify.runtime_prefix`, `mix ci.test`, and `mix verify.install_golden` passed after gap closure, and runtime flows now cover trigger-to-trace, idempotency, inbox, admin, recovery, workflow, digest, webhook, preferences, policy, and public legacy mode. [VERIFIED: 75-VERIFICATION.md]

The main planning risk is copy/gate drift, not new runtime design. [VERIFIED: codebase grep] Existing doc contracts already protect README, installation, and golden-path docs from `--prefix`, automatic data-move language, and Oban-prefix details, but the new storage guide, Oban recipe, demo-host prefix proof, CI runtime-prefix lane, and release-gate parity are still missing. [VERIFIED: test/chimeway/doc_contract_test.exs] [VERIFIED: .github/workflows/ci.yml]

**Primary recommendation:** implement Phase 76 as four tightly linked slices: storage guide plus doc contracts, Oban prefix caveat updates, demo-host prefixed proof through `DemoHost.Seeds` or `Chimeway.trigger/3`, and local/CI/release-gate parity for `verify.runtime_prefix`, path-gated `verify.install_golden`, and docs contracts. [VERIFIED: 76-CONTEXT.md]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| First-run storage docs | Documentation / HexDocs | API / Backend | README, installation, and golden path teach adopter config only; they must not own operational migration detail. [VERIFIED: 76-CONTEXT.md] |
| Manual public-to-`chimeway` move guide | Documentation / Operator Runbook | Database / Storage | The move is an optional operator database procedure; Chimeway does not ship an automated production move task in this phase. [VERIFIED: 76-CONTEXT.md] |
| Oban prefix caveats | Documentation / Oban Integration | Database / Storage | Oban owns `oban_jobs` prefixing through Oban migration/config, while Chimeway owns `chimeway_*` table routing. [CITED: https://hexdocs.pm/oban/isolation.html#database-prefixes] [VERIFIED: 75-04-SUMMARY.md] |
| Demo prefix proof | Example Host / Test Harness | API / Backend, Database / Storage | DEMO-01 must call public seed/trigger APIs and assert schema placement, not insert fixtures as the primary proof. [VERIFIED: 76-CONTEXT.md] |
| Named verification gates | Mix / CI | ExUnit / GitHub Actions | Project policy requires `mix verify.*` and `mix ci.*` entrypoints with CI/local parity. [VERIFIED: AGENTS.md] |
| Release-gate parity | ExUnit contract tests | GitHub Actions | `test/chimeway/release_gate_contract_test.exs` already enforces CI/local gate agreement and should count the new runtime-prefix lane. [VERIFIED: test/chimeway/release_gate_contract_test.exs] |

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| UPG-02 | Documentation includes an optional manual move guide for teams that choose to move `public.chimeway_*` tables into the `chimeway` schema. | Add a HexDocs extra under `guides/introduction/` and lock preflight, backup, transaction/lock caveats, verification queries, and rollback notes with doc contracts. [VERIFIED: REQUIREMENTS.md] [VERIFIED: 76-CONTEXT.md] |
| UPG-03 | Rollback and failure-mode guidance is documented clearly enough that operators know when the library can help and when the move is a manual database operation. | Use explicit "manual database operation", "stop and restore", and no-silent-migration language; forbid automatic move/task claims. [VERIFIED: REQUIREMENTS.md] [VERIFIED: 76-CONTEXT.md] |
| DOCS-01 | README, installation, golden path, and troubleshooting docs explain the default `chimeway` schema, explicit public mode, and copy-paste config. | Existing first-run docs already include `prefix: "chimeway"` and `prefix: false`; Phase 76 should add the troubleshooting/upgrade guide and cross-link without overloading first-run docs. [VERIFIED: README.md] [VERIFIED: guides/introduction/installation.md] [VERIFIED: guides/introduction/golden-path.md] |
| DOCS-02 | Oban guidance states that Oban's prefix is separate from Chimeway's table prefix and shows safe test/production examples. | Official Oban docs show `Oban.Migration.up/down(prefix: ...)` plus `config :my_app, Oban, prefix: ...`; use `"jobs"` as the example prefix and keep it out of first-run docs. [CITED: https://hexdocs.pm/oban/Oban.Migration.html] [VERIFIED: 76-CONTEXT.md] |
| DEMO-01 | The demo host or equivalent example runs against the default `chimeway` schema and proves a trigger-to-trace flow. | Demo host configs currently omit `config :chimeway, prefix: "chimeway"`; existing seed/admin trace tests can be extended to assert `chimeway.*` rows and empty `public.chimeway_*`. [VERIFIED: examples/chimeway_demo_host/config/test.exs] [VERIFIED: examples/chimeway_demo_host/test/demo_host_web/admin_trace_live_test.exs] |
| GATE-01 | Named verify/CI gates cover prefixed install/runtime behavior and public-schema legacy compatibility. | `mix verify.runtime_prefix` and `mix verify.install_golden` exist, but CI `ci-gate` does not yet need a `verify_runtime_prefix` lane and release-gate contracts do not count it. [VERIFIED: mix.exs] [VERIFIED: .github/workflows/ci.yml] |
</phase_requirements>

## Project Constraints (from AGENTS.md)

- Chimeway is an open-source embedded notification layer for Elixir and Phoenix apps; host applications own their data, policies, and delivery history. [VERIFIED: AGENTS.md]
- Every notification decision must remain explainable: why a notification was sent, failed, or suppressed. [VERIFIED: AGENTS.md]
- Stack constraints are Elixir 1.17+ / OTP 26+, Ecto 3.x with PostgreSQL 15+, optional Phoenix 1.7/1.8, optional recommended Oban 2.x, and Swoosh 1.x email adapter seams. [VERIFIED: AGENTS.md]
- Persist stable `notification_key` plus version; do not use module names as durable identity. [VERIFIED: AGENTS.md]
- Keep the durable lifecycle spine: event -> notification -> delivery -> attempt. [VERIFIED: AGENTS.md]
- Treat idempotency and suppression reasons as first-class product behavior. [VERIFIED: AGENTS.md]
- Keep adapters replaceable with explicit behaviours and contract tests. [VERIFIED: AGENTS.md]
- Preserve host ownership boundaries for auth, tenancy, URL generation, and correlation IDs. [VERIFIED: AGENTS.md]
- Maintain `mix verify.*` and `mix ci.*` entrypoints with CI/local parity. [VERIFIED: AGENTS.md]
- Avoid leaking sensitive payload fields in telemetry and operator surfaces. [VERIFIED: AGENTS.md]
- Docs/release-gate phases accept contract-test evidence through `mix ci.verify_gates` plus ecosystem `verify.*` CI jobs and skip `/gsd-verify-work`. [VERIFIED: AGENTS.md]

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Elixir / Mix | 1.19.5 local; project minimum 1.17+ | Docs, ExUnit, Mix aliases, example-host tests | Project targets Elixir 1.17+ and local Mix is available. [VERIFIED: local command] [VERIFIED: AGENTS.md] |
| Erlang/OTP | 28 local; project minimum 26+ | BEAM runtime for tests and examples | Project targets OTP 26+ and local runtime exceeds the minimum. [VERIFIED: local command] [VERIFIED: AGENTS.md] |
| Ecto | 3.13.6 locked; published 2026-05-05 | Repo prefix behavior and runtime storage reads/writes | Phase 75 uses `Repo.default_options/1` and Ecto operation prefixes as the storage seam. [VERIFIED: mix deps] [VERIFIED: mix hex.info ecto] |
| Ecto SQL | 3.13.5 locked; published 2026-03-03 | Migration generator proof, SQL Sandbox, Postgres integration | Ecto migration docs define prefix behavior for table, index, and reference operations. [VERIFIED: mix deps] [VERIFIED: mix hex.info ecto_sql] [CITED: https://hexdocs.pm/ecto_sql/Ecto.Migration.html#module-prefixes] |
| PostgreSQL | 15+ target; 14.17 local; CI uses postgres:15 | Storage schemas and demo/test proof | The project target is PostgreSQL 15+; local service is reachable but below target, so CI is the exact target-version proof. [VERIFIED: AGENTS.md] [VERIFIED: .github/workflows/ci.yml] [VERIFIED: local command] |
| Oban | 2.23.0 locked; published 2026-05-27 | Optional async dispatch and job table | Oban database-prefix docs are the authoritative source for `oban_jobs` isolation examples. [VERIFIED: mix deps] [VERIFIED: mix hex.info oban] [CITED: https://hexdocs.pm/oban/isolation.html#database-prefixes] |
| ExDoc | 0.40.1 locked; published 2026-01-31 | HexDocs extras and docs build gate | ExDoc supports `extras` and `groups_for_extras`; the project already uses both. [VERIFIED: mix deps] [VERIFIED: mix hex.info ex_doc] [CITED: https://hexdocs.pm/ex_doc/ExDoc.html] |

### Supporting

| Library / Surface | Version | Purpose | When to Use |
|-------------------|---------|---------|-------------|
| Phoenix / LiveView | Phoenix 1.8.7, LiveView 1.1.31 locked | Demo-host and admin LiveView proof | Use existing demo-host LiveView tests; do not add a new browser suite for DEMO-01 unless existing proof cannot satisfy it. [VERIFIED: mix deps] [VERIFIED: 76-CONTEXT.md] |
| `test/chimeway/doc_contract_test.exs` | local | Locks documentation truth and forbidden phrases | Extend for the new storage guide, Oban caveats, and first-run doc boundaries. [VERIFIED: codebase grep] |
| `test/chimeway/release_gate_contract_test.exs` | local | Locks local/CI/release gate parity | Extend to count `verify.runtime_prefix`, preserve `install_golden_contract`, and require MAINTAINING copy. [VERIFIED: codebase grep] |
| `examples/chimeway_demo_host` | local | Public adopter-copyable demo proof | Configure prefix mode here and assert seed/trigger-to-trace rows land in `chimeway`. [VERIFIED: examples/chimeway_demo_host/config/test.exs] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Dedicated storage-prefix guide | README-only upgrade section | README would become unsafe for beginners and would bury UPG-02/UPG-03 operational detail. [VERIFIED: 76-CONTEXT.md] |
| Manual operator move guide | First-party automated move task | Automated production data move is explicitly out of scope and would need migration/runtime design beyond this phase. [VERIFIED: REQUIREMENTS.md] |
| Existing demo-host proof | New browser smoke suite | Existing Phase 76 decision rejects a new browser suite unless the public API/demo proof cannot cover DEMO-01. [VERIFIED: 76-CONTEXT.md] |
| Oban docs in first-run install path | Full Oban caveats in README/install/golden path | First-run docs already forbid Oban prefix details; put full caveats in the Oban recipe and storage guide. [VERIFIED: test/chimeway/doc_contract_test.exs] |

**Installation:**

```bash
# No new packages are recommended for Phase 76.
mix deps.get
```

**Version verification performed:**

```bash
mix deps | rg 'ecto|ecto_sql|postgrex|oban|ex_doc|phoenix|swoosh'
mix hex.info ecto
mix hex.info ecto_sql
mix hex.info oban
mix hex.info ex_doc
elixir --version
mix --version
psql -Atqc 'SHOW server_version'
```

## Package Legitimacy Audit

Phase 76 should not install new external packages; it uses existing locked dependencies and project-local docs/tests/CI. [VERIFIED: 76-CONTEXT.md] [VERIFIED: mix deps]

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| None added | - | - | - | - | OK | No package gate required. [VERIFIED: research scope] |

**Packages removed due to [SLOP] verdict:** none. [VERIFIED: research scope]
**Packages flagged as suspicious [SUS]:** none. [VERIFIED: research scope]

## Architecture Patterns

### System Architecture Diagram

```text
Adopter docs entry points
  -> README / Installation / Golden Path
       -> short config truth only
       -> prefix: "chimeway" for new installs
       -> prefix: false for existing public-schema legacy mode
       -> no Oban prefix details, no --prefix public, no migrate --prefix

Operational docs branch
  -> New storage prefix upgrade/troubleshooting guide
       -> prefix matrix
       -> manual public-to-chimeway move procedure
       -> backup/preflight/lock caveats
       -> verification queries
       -> rollback and stop/restore guidance
       -> Oban job-table separation caveat

Oban branch
  -> guides/recipes/oban-integration.md
       -> Oban.Migration.up/down(prefix: "jobs")
       -> config :my_app, Oban, prefix: "jobs"
       -> separate from config :chimeway, prefix: "chimeway"

Demo proof branch
  -> examples/chimeway_demo_host config prefix: "chimeway"
  -> DemoHost.Seeds or Chimeway.trigger/3 public API
  -> Chimeway.Traces.explain_delivery/1
  -> assert chimeway.chimeway_* rows exist and public.chimeway_* rows stay empty

Gate branch
  -> mix verify.runtime_prefix
  -> mix verify.install_golden / ci.install_golden path-gated
  -> mix ci.verify_gates
  -> .github/workflows/ci.yml required lanes
  -> release_gate_contract_test parity assertions
```

### Recommended Project Structure

```text
guides/
+-- introduction/
|   +-- installation.md                 # short first-run config truth
|   +-- golden-path.md                  # short first-run config truth
|   +-- storage-prefix-upgrade.md       # new UPG-02/UPG-03 guide
+-- recipes/
    +-- oban-integration.md             # Oban prefix separation examples

examples/chimeway_demo_host/
+-- config/
|   +-- dev.exs                         # demo default prefix config
|   +-- test.exs                        # DEMO-01 test prefix config
+-- test/demo_host_web/
    +-- admin_trace_live_test.exs       # or sibling proof file for schema placement

test/chimeway/
+-- doc_contract_test.exs               # storage guide and docs footgun contracts
+-- release_gate_contract_test.exs      # runtime/install gate parity contracts

.github/workflows/
+-- ci.yml                              # verify_runtime_prefix lane plus ci-gate need
```

### Pattern 1: Layered Documentation

**What:** Keep README, installation, and golden path short, with only the copy-paste runtime prefix values and a cross-link to the new guide. [VERIFIED: 76-CONTEXT.md]

**When to use:** Use first-run docs for new adopters; use the storage guide for upgrade/move/troubleshooting details. [VERIFIED: 76-CONTEXT.md]

**Example:**

```markdown
<!-- Source: 76-CONTEXT.md -->
New installs use `config :chimeway, prefix: "chimeway"`.
Existing public-schema legacy installs use `config :chimeway, prefix: false`.
That legacy mode keeps using existing unprefixed tables and does not move data.
```

### Pattern 2: Prefix Matrix in the Storage Guide

**What:** Put generator mode, runtime mode, and Oban mode in one matrix so adopters do not conflate them. [VERIFIED: 76-CONTEXT.md]

**When to use:** Use in `guides/introduction/storage-prefix-upgrade.md` for UPG-02/UPG-03 and DOCS-02. [VERIFIED: 76-CONTEXT.md]

**Example:**

```markdown
<!-- Source: 76-CONTEXT.md and Oban official docs -->
| Concern | Default / safe value |
|---|---|
| Chimeway generator default | `mix chimeway.gen.migrations` |
| Chimeway generator legacy output | `mix chimeway.gen.migrations --prefix public` |
| Chimeway runtime default | `config :chimeway, prefix: "chimeway"` |
| Chimeway runtime legacy public mode | `config :chimeway, prefix: false` |
| Oban job table example | `Oban.Migration.up(prefix: "jobs")` and `config :my_app, Oban, prefix: "jobs"` |
```

### Pattern 3: Public-API Demo Proof

**What:** Use `DemoHost.Seeds` or `Chimeway.trigger/3`, then assert schema placement with SQL count helpers after the public flow creates durable rows. [VERIFIED: 76-CONTEXT.md] [VERIFIED: examples/chimeway_demo_host/lib/demo_host/seeds.ex]

**When to use:** Use for DEMO-01; do not satisfy demo proof with direct fixture inserts. [VERIFIED: 76-CONTEXT.md]

**Example:**

```elixir
# Source: Phase 75 PrefixedRuntimeCase pattern, adapted for demo proof planning.
assert {:ok, %{trace: %{delivery_ids: [delivery_id | _]}}} = DemoHost.Seeds.seed_invite()
assert {:ok, explanation} = Chimeway.Traces.explain_delivery(delivery_id)
assert explanation.timeline != []
assert chimeway_schema_count("chimeway_events") > 0
assert public_schema_count("chimeway_events") == 0
```

### Anti-Patterns to Avoid

- **First-run docs as migration runbooks:** README/install/golden path must not include `--prefix public`, Oban prefix internals, or `mix ecto.migrate --prefix chimeway`. [VERIFIED: 76-CONTEXT.md]
- **`prefix: "public"` runtime config:** Runtime public mode is `prefix: false`; `"public"` is an invalid runtime shape from Phase 73. [VERIFIED: 73-CONTEXT.md]
- **Oban/Chimeway prefix coupling:** `config :chimeway, prefix: "chimeway"` does not configure `oban_jobs`; Oban uses its own migration/config prefix. [CITED: https://hexdocs.pm/oban/isolation.html#database-prefixes] [VERIFIED: 76-CONTEXT.md]
- **Automated move implication:** Do not imply Chimeway will move, backfill, rewrite, or copy public data automatically. [VERIFIED: 76-CONTEXT.md]
- **Fixture-only demo proof:** DEMO-01 must exercise public APIs and adopter-copyable seed paths. [VERIFIED: 76-CONTEXT.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Production public-to-`chimeway` data movement | New Mix task or hidden automated migrator | Manual operator guide with preflight, backup, transaction, verification, and rollback steps | Automated move is out of scope and dangerous without host-specific data/lock review. [VERIFIED: REQUIREMENTS.md] |
| Oban prefix semantics | Custom Chimeway explanation of Oban internals | Official Oban `Oban.Migration.up/down(prefix: ...)` and `config :my_app, Oban, prefix: ...` examples | Oban owns `oban_jobs` migration/config semantics. [CITED: https://hexdocs.pm/oban/Oban.Migration.html] |
| HexDocs navigation | Custom docs index logic | ExDoc `extras` and existing `groups_extras` regexes | ExDoc supports additional pages and grouping natively. [CITED: https://hexdocs.pm/ex_doc/ExDoc.html] |
| Demo proof harness from scratch | New browser smoke suite | Existing demo-host ExUnit/LiveView proof path plus schema count assertions | Phase 76 explicitly prefers existing demo/example proof. [VERIFIED: 76-CONTEXT.md] |
| Release-gate parity checker | Shell grep scripts outside tests | Extend `release_gate_contract_test.exs` | The project already uses ExUnit contracts for CI/local parity. [VERIFIED: test/chimeway/release_gate_contract_test.exs] |

**Key insight:** Phase 76 should make existing storage behavior supportable; new automation or new runtime semantics would expand risk without satisfying the locked docs/demo/gate scope. [VERIFIED: 76-CONTEXT.md]

## Common Pitfalls

### Pitfall 1: Blurring Generator Public Mode and Runtime Public Mode

**What goes wrong:** Docs teach `--prefix public` as runtime configuration or show `config :chimeway, prefix: "public"`. [VERIFIED: 76-CONTEXT.md]
**Why it happens:** Phase 74 uses `--prefix public` as generator-only compatibility sugar, while Phase 73 runtime public compatibility is `prefix: false`. [VERIFIED: 73-CONTEXT.md] [VERIFIED: 74-CONTEXT.md]
**How to avoid:** Put the distinction in the storage guide matrix and doc-contract both forms. [VERIFIED: 76-CONTEXT.md]
**Warning signs:** README/golden/install contain `--prefix` or runtime docs contain `"public"`. [VERIFIED: test/chimeway/doc_contract_test.exs]

### Pitfall 2: Telling Users to Run `mix ecto.migrate --prefix chimeway`

**What goes wrong:** Users run host migrations under the wrong migrator prefix instead of running Chimeway's generated explicitly qualified migrations normally. [VERIFIED: 74-CONTEXT.md]
**Why it happens:** Ecto supports command-line migration prefixes, but Phase 74 intentionally generated explicit table/index/reference prefixes so ordinary `mix ecto.migrate` works. [CITED: https://hexdocs.pm/ecto/multi-tenancy-with-query-prefixes.html] [VERIFIED: 74-CONTEXT.md]
**How to avoid:** Forbid the command in docs contracts and explain that generated migrations carry the selected Chimeway schema. [VERIFIED: 76-CONTEXT.md]
**Warning signs:** Any guide includes `mix ecto.migrate --prefix chimeway`. [VERIFIED: 76-CONTEXT.md]

### Pitfall 3: Coupling Oban's Job Prefix to Chimeway's Table Prefix

**What goes wrong:** Adopters assume `prefix: "chimeway"` creates or moves `oban_jobs`. [VERIFIED: 76-CONTEXT.md]
**Why it happens:** Ecto and Oban both use the word "prefix", but they apply to different table sets. [CITED: https://hexdocs.pm/oban/isolation.html#database-prefixes]
**How to avoid:** Use `"jobs"` for Oban examples and state that Chimeway storage and Oban job storage are separate. [VERIFIED: 76-CONTEXT.md]
**Warning signs:** Oban examples use `"chimeway"` as the Oban prefix or first-run docs mention Oban prefix details. [VERIFIED: 76-CONTEXT.md]

### Pitfall 4: Demo Proof Writes Through Fixtures

**What goes wrong:** Tests prove only table placement, not adopter behavior. [VERIFIED: 76-CONTEXT.md]
**Why it happens:** Direct inserts are easier than running demo seeds, but they bypass Chimeway trigger and trace behavior. [VERIFIED: examples/chimeway_demo_host/lib/demo_host/seeds.ex]
**How to avoid:** Start with `DemoHost.Seeds.seed_invite/0`, `DemoHost.Seeds.run/0`, or `Chimeway.trigger/3`, then assert `Chimeway.Traces.explain_delivery/1` and schema counts. [VERIFIED: examples/chimeway_demo_host/lib/demo_host/seeds.ex]
**Warning signs:** DEMO-01 test creates `Chimeway.Event`, `Notification`, or `Delivery` structs directly. [VERIFIED: 76-CONTEXT.md]

### Pitfall 5: CI Gate Drift

**What goes wrong:** Local aliases exist but `ci-gate`, MAINTAINING, or release-gate contracts do not count them. [VERIFIED: mix.exs] [VERIFIED: .github/workflows/ci.yml]
**Why it happens:** `verify.runtime_prefix` was added in Phase 75, but Phase 76 owns broader release-gate parity. [VERIFIED: 75-07-SUMMARY.md] [VERIFIED: 76-CONTEXT.md]
**How to avoid:** Add a `verify_runtime_prefix` CI job, include it in `ci-gate` needs/env loop, and extend release-gate contracts and MAINTAINING. [VERIFIED: 76-CONTEXT.md]
**Warning signs:** `release_gate_contract_test.exs` still counts 12 lanes and excludes runtime prefix from pre-ship command contracts. [VERIFIED: test/chimeway/release_gate_contract_test.exs]

## Code Examples

Verified patterns from project and official sources.

### ExDoc Extra Inclusion

```elixir
# Source: mix.exs docs/0 pattern and ExDoc extras docs.
extras: [
  "guides/introduction/getting-started.md",
  "guides/introduction/installation.md",
  "guides/introduction/golden-path.md",
  "guides/introduction/storage-prefix-upgrade.md"
],
groups_extras: [
  Introduction: ~r/guides\/introduction\//,
  Flows: ~r/guides\/flows\//,
  Recipes: ~r/guides\/recipes\//
]
```

### Release Gate Contract Extension Shape

```elixir
# Source: test/chimeway/release_gate_contract_test.exs existing pattern.
@pre_ship_verify_commands [
  {"verify.runtime_prefix", "verify_runtime_prefix", "mix verify.runtime_prefix"},
  {"verify.example", "verify_example", "mix verify.example"}
]
```

### Oban Prefix Example Shape

```elixir
# Source: Oban official docs, with Phase 76 example prefix choice.
def up, do: Oban.Migration.up(prefix: "jobs")
def down, do: Oban.Migration.down(prefix: "jobs")

config :my_app, Oban,
  repo: MyApp.Repo,
  prefix: "jobs",
  queues: [default: 10]
```

### Demo Schema Placement Assertion Shape

```elixir
# Source: Phase 75 PrefixedRuntimeCase table-count pattern.
defp schema_count(schema, table_name) do
  Ecto.Adapters.SQL.query!(
    Chimeway.Repo,
    ~s(SELECT count(*) FROM "#{schema}"."#{table_name}"),
    []
  ).rows
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Public schema as implicit runtime baseline | Static runtime config accepts `prefix: "chimeway"` or explicit `prefix: false` | Phase 73, 2026-06-30 | Docs must frame public mode as legacy compatibility, not default. [VERIFIED: 73-CONTEXT.md] |
| Unprefixed generated migrations | Generated default migrations target `chimeway` and public mode is `--prefix public` | Phase 74, 2026-06-30 | Upgrade guide must distinguish generator mode from runtime mode. [VERIFIED: 74-CONTEXT.md] |
| Runtime rows could leak to public under prefix mode | Runtime storage uses `Repo.default_options/1` and focused runtime-prefix proof | Phase 75, 2026-07-01 | Demo and CI gates can now rely on `mix verify.runtime_prefix`. [VERIFIED: 75-VERIFICATION.md] |
| Release gates counted ecosystem/admin lanes only | Phase 76 should count runtime prefix as a required lane | Phase 76 scope | Planner must update CI, release contracts, and MAINTAINING together. [VERIFIED: 76-CONTEXT.md] |

**Deprecated/outdated:**
- `config :chimeway, prefix: "public"` is invalid runtime config; use `prefix: false` for public-schema legacy mode. [VERIFIED: 73-CONTEXT.md]
- `mix ecto.migrate --prefix chimeway` is not the Chimeway generated-migration adoption path. [VERIFIED: 74-CONTEXT.md]
- Using `"chimeway"` as the Oban prefix example implies coupling and should be avoided. [VERIFIED: 76-CONTEXT.md]

## Assumptions Log

All planning-relevant claims in this research were verified from project files, local tool output, Hex package metadata, or cited official docs. [VERIFIED: codebase file read]

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| None | No `[ASSUMED]` claims were used. | All | No user confirmation needed before planning. [VERIFIED: research provenance] |

## Open Questions

1. **Exact storage guide filename**
   - What we know: Phase context suggests `guides/introduction/storage-prefix-upgrade.md` or `guides/introduction/storage-isolation-upgrade.md`. [VERIFIED: 76-CONTEXT.md]
   - What's unclear: The filename is not locked by the user. [VERIFIED: 76-CONTEXT.md]
   - Recommendation: Use `guides/introduction/storage-prefix-upgrade.md` because it matches the phase vocabulary and ExDoc Introduction grouping. [VERIFIED: mix.exs]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Elixir | Mix aliases, ExUnit, docs | yes | 1.19.5 local | CI matrix uses 1.17. [VERIFIED: local command] [VERIFIED: .github/workflows/ci.yml] |
| Erlang/OTP | BEAM runtime | yes | 28 local | CI matrix uses OTP 26/27. [VERIFIED: local command] [VERIFIED: .github/workflows/ci.yml] |
| Mix | Docs/tests/gates | yes | 1.19.5 local | CI installs Hex/Rebar before Mix commands. [VERIFIED: local command] [VERIFIED: .github/workflows/ci.yml] |
| PostgreSQL | Demo/schema placement tests | yes | 14.17 local, accepting connections | CI postgres:15 is target-version fallback. [VERIFIED: local command] [VERIFIED: .github/workflows/ci.yml] |
| Git | CI diff/path gates and docs commit | yes | 2.41.0 | None needed. [VERIFIED: local command] |
| Node/npm | Existing Playwright/admin smoke if running full `verify.admin` | yes | Node 22.14.0, npm 11.1.0 | Not required for Phase 76 focused demo proof unless running existing browser gate. [VERIFIED: local command] [VERIFIED: mix.exs] |

**Missing dependencies with no fallback:**
- None found for writing and planning Phase 76. [VERIFIED: local command]

**Missing dependencies with fallback:**
- Local PostgreSQL is 14.17 while project target and CI service are PostgreSQL 15; use CI or a local PG15 service for exact release-gate parity. [VERIFIED: local command] [VERIFIED: AGENTS.md] [VERIFIED: .github/workflows/ci.yml]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit via Mix; docs built by ExDoc. [VERIFIED: mix.exs] |
| Config file | `mix.exs`, `config/test.exs`, `examples/chimeway_demo_host/config/test.exs`. [VERIFIED: codebase file read] |
| Quick run command | `mix ci.verify_gates` for doc/release contracts. [VERIFIED: mix.exs] |
| Full suite command | `mix verify.runtime_prefix && mix verify.install_golden && mix verify.example && mix ci.verify_gates`. [VERIFIED: mix.exs] |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| UPG-02 | Storage guide includes optional manual public-to-`chimeway` move guide with preflight and verification steps | doc contract | `MIX_ENV=test mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` | Partially; guide/test additions needed in Wave 0. [VERIFIED: test/chimeway/doc_contract_test.exs] |
| UPG-03 | Guide includes rollback and failure-mode guidance and forbids automatic move claims | doc contract | `MIX_ENV=test mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` | Partially; new guide contract needed. [VERIFIED: 76-CONTEXT.md] |
| DOCS-01 | README/install/golden/troubleshooting docs state default schema and public legacy config | doc contract/docs build | `mix ci.verify_gates && mix ci.docs` | Partially; troubleshooting guide missing. [VERIFIED: README.md] [VERIFIED: mix.exs] |
| DOCS-02 | Oban guide states Oban prefix is separate and uses safe `"jobs"` examples | doc contract | `MIX_ENV=test mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` | Existing Oban contract exists but lacks prefix separation checks. [VERIFIED: test/chimeway/doc_contract_test.exs] |
| DEMO-01 | Demo host runs with `prefix: "chimeway"` and public API trigger-to-trace writes only under `chimeway` schema | integration | `cd examples/chimeway_demo_host && MIX_ENV=test mix test test/demo_host_web/admin_trace_live_test.exs --warnings-as-errors` or a focused sibling test | Existing demo test file exists; prefix assertions/config missing. [VERIFIED: examples/chimeway_demo_host/test/demo_host_web/admin_trace_live_test.exs] |
| GATE-01 | Runtime prefix and install golden gates are named locally, represented in CI, and counted by release contracts | release contract | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors` | Existing contract file exists; runtime-prefix lane assertions missing. [VERIFIED: test/chimeway/release_gate_contract_test.exs] |

### Sampling Rate

- **Per task commit:** Run the focused file or alias touched by the task, such as `mix ci.verify_gates`, `mix verify.runtime_prefix`, or the demo-host focused test. [VERIFIED: mix.exs]
- **Per wave merge:** Run `mix ci.verify_gates`, `mix ci.docs`, and the relevant storage/demo gate. [VERIFIED: AGENTS.md]
- **Phase gate:** Run `mix ci.verify_gates`, `mix verify.runtime_prefix`, `mix verify.install_golden`, and `mix verify.example`; rely on CI for PostgreSQL 15 exactness. [VERIFIED: mix.exs] [VERIFIED: .github/workflows/ci.yml]

### Wave 0 Gaps

- [ ] `guides/introduction/storage-prefix-upgrade.md` - covers UPG-02, UPG-03, DOCS-01, DOCS-02. [VERIFIED: 76-CONTEXT.md]
- [ ] `test/chimeway/doc_contract_test.exs` additions - required/forbidden strings for storage guide and Oban prefix separation. [VERIFIED: test/chimeway/doc_contract_test.exs]
- [ ] `examples/chimeway_demo_host/config/dev.exs` and `examples/chimeway_demo_host/config/test.exs` prefix config updates - required for DEMO-01. [VERIFIED: examples/chimeway_demo_host/config/test.exs]
- [ ] Demo-host schema placement test/helper - prove public APIs write `chimeway.*` and leave `public.chimeway_*` empty. [VERIFIED: 76-CONTEXT.md]
- [ ] `.github/workflows/ci.yml` `verify_runtime_prefix` job plus `ci-gate` needs/env loop update. [VERIFIED: .github/workflows/ci.yml]
- [ ] `test/chimeway/release_gate_contract_test.exs` update - count `verify.runtime_prefix` and installer-golden path-gate expectations. [VERIFIED: test/chimeway/release_gate_contract_test.exs]
- [ ] `MAINTAINING.md` update - storage prefix gates and pre-ship command list. [VERIFIED: MAINTAINING.md]

## Security Domain

Security enforcement is enabled because `.planning/config.json` does not set `security_enforcement: false`. [VERIFIED: .planning/config.json] OWASP states ASVS is a basis for testing web application technical security controls and the current stable ASVS is 5.0.0. [CITED: https://owasp.org/www-project-application-security-verification-standard/]

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | no | Phase 76 does not add auth surfaces; preserve host-owned auth boundaries in docs. [VERIFIED: 76-CONTEXT.md] [VERIFIED: prompts/chimeway-host-app-integration-seam.md] |
| V3 Session Management | no | No session behavior changes are in scope. [VERIFIED: 76-CONTEXT.md] |
| V4 Access Control | yes | Demo/admin docs must preserve host-owned admin authorization and not broaden operator access. [VERIFIED: AGENTS.md] |
| V5 Input Validation | yes | Docs must constrain accepted prefix values and forbid dangerous copy-paste variants such as `prefix: "public"` and runtime `prefix:` API args. [VERIFIED: 73-CONTEXT.md] [VERIFIED: 76-CONTEXT.md] |
| V6 Cryptography | no | No new cryptographic feature or secret storage is in scope; avoid exposing secrets in docs/demo output. [VERIFIED: 76-CONTEXT.md] [VERIFIED: AGENTS.md] |

### Known Threat Patterns for Phase 76

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Unsafe manual data-move guidance causes loss or partial move | Tampering | Require backup, preflight counts, transaction/lock caveats, verification queries, rollback, and "stop and restore" language. [VERIFIED: 76-CONTEXT.md] |
| Docs imply automatic migration of public data | Tampering / Repudiation | Doc contracts must forbid automatic move/backfill/copy claims. [VERIFIED: test/chimeway/doc_contract_test.exs] |
| Oban prefix confused with Chimeway storage prefix | Tampering | Use separate Oban examples and state that Chimeway prefix does not create/move/configure `oban_jobs`. [CITED: https://hexdocs.pm/oban/isolation.html#database-prefixes] [VERIFIED: 76-CONTEXT.md] |
| Demo/docs leak payload, render data, provider bodies, tokens, or full recipient PII | Information Disclosure | Preserve existing redaction posture and avoid raw payload examples in new guide/tests. [VERIFIED: AGENTS.md] [VERIFIED: test/chimeway/doc_contract_test.exs] |
| CI gate documents a command that CI does not run | Repudiation | Extend release-gate contracts so MAINTAINING, Mix aliases, CI jobs, and `ci-gate` agree. [VERIFIED: test/chimeway/release_gate_contract_test.exs] |

## Sources

### Primary (HIGH confidence)

- `.planning/phases/76-prefix-docs-demo-and-gates/76-CONTEXT.md` - locked decisions, phase boundary, demo/gate constraints. [VERIFIED: codebase file read]
- `.planning/REQUIREMENTS.md` - UPG-02, UPG-03, DOCS-01, DOCS-02, DEMO-01, GATE-01. [VERIFIED: codebase file read]
- `.planning/ROADMAP.md` - Phase 76 goal, dependency on Phase 75, and success criteria. [VERIFIED: codebase file read]
- `.planning/phases/75-runtime-prefix-propagation/75-VERIFICATION.md` - Phase 75 runtime-prefix evidence and green gates. [VERIFIED: codebase file read]
- `mix.exs`, `.github/workflows/ci.yml`, `test/chimeway/doc_contract_test.exs`, `test/chimeway/release_gate_contract_test.exs`, and demo-host files - current implementation surfaces. [VERIFIED: codebase grep]
- `AGENTS.md` - project constraints and docs/release-gate acceptance posture. [VERIFIED: codebase file read]
- Local commands: `mix deps`, `mix hex.info`, `elixir --version`, `mix --version`, `psql`, `pg_isready`, `git --version`, `node --version`, `npm --version`. [VERIFIED: local command]

### Secondary (MEDIUM confidence)

- `https://hexdocs.pm/ecto_sql/Ecto.Migration.html#module-prefixes` - migration table/index/reference prefix behavior. [CITED: https://hexdocs.pm/ecto_sql/Ecto.Migration.html#module-prefixes]
- `https://hexdocs.pm/ecto/multi-tenancy-with-query-prefixes.html` - query/schema prefix precedence and migration prefix options. [CITED: https://hexdocs.pm/ecto/multi-tenancy-with-query-prefixes.html]
- `https://hexdocs.pm/ecto/Ecto.Repo.html#c:default_options/1` - `Repo.default_options/1` can set query-specific defaults such as `:prefix`. [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html#c:default_options/1]
- `https://hexdocs.pm/oban/isolation.html#database-prefixes` - Oban database prefix semantics. [CITED: https://hexdocs.pm/oban/isolation.html#database-prefixes]
- `https://hexdocs.pm/oban/Oban.Migration.html` - Oban migration prefix examples. [CITED: https://hexdocs.pm/oban/Oban.Migration.html]
- `https://hexdocs.pm/oban/Oban.Testing.html` - Oban testing prefix option. [CITED: https://hexdocs.pm/oban/Oban.Testing.html]
- `https://hexdocs.pm/ex_doc/ExDoc.html` - ExDoc `extras` and `groups_for_extras`. [CITED: https://hexdocs.pm/ex_doc/ExDoc.html]
- `https://owasp.org/www-project-application-security-verification-standard/` - ASVS purpose and current stable version. [CITED: https://owasp.org/www-project-application-security-verification-standard/]

### Tertiary (LOW confidence)

- None used for planning decisions. [VERIFIED: research provenance]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - verified from local dependency output, Hex metadata, and project constraints. [VERIFIED: mix deps] [VERIFIED: mix hex.info]
- Architecture: HIGH - locked by Phase 76 context and Phase 75 verification evidence. [VERIFIED: 76-CONTEXT.md] [VERIFIED: 75-VERIFICATION.md]
- Pitfalls: HIGH - derived from explicit context decisions, existing doc contracts, and official Ecto/Oban docs. [VERIFIED: test/chimeway/doc_contract_test.exs] [CITED: https://hexdocs.pm/oban/isolation.html#database-prefixes]

**Research date:** 2026-07-01
**Valid until:** 2026-07-31 for project-local planning facts; recheck HexDocs/Hex package metadata before dependency upgrades. [VERIFIED: local command]
