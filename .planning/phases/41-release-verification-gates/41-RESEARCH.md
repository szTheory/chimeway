# Phase 41: Release Verification Gates — Research

**Researched:** 2026-05-29  
**Phase:** 41-release-verification-gates  
**Requirements:** GATE-01  
**Status:** Ready for plan-phase

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Doc-contract matrix completion
- **D-01:** Extend `test/chimeway/doc_contract_test.exs` with describe blocks for adoption-surface docs not yet gated: `guides/introduction/golden-path.md`, `guides/introduction/installation.md`, `README.md`, and `guides/recipes/oban-integration.md` (closes IN-01 deferred from Phase 37).
- **D-02:** Follow the established static forbidden/required string pattern from Phases 37–38 — no new doc-contract framework or external tooling.
- **D-03:** Golden-path and installation gates require `mix chimeway.gen.migrations`, `Chimeway.trigger`, `idempotency_key`, and `Chimeway.Traces.explain_delivery` where applicable; forbid fictional APIs (`Chimeway.Workflow`, `stop_conditions`, `Workflows.Workers`, `Chimeway.Trigger.trigger`).
- **D-04:** Oban-integration gate requires `Chimeway.Dispatch.WorkflowProgressionWorker` and `Chimeway.Dispatch.SignalRouterWorker`; forbids `Workflows.Workers` namespace (Phase 37 IN-01).

#### Version alignment gate
- **D-05:** Add automated ExUnit gate asserting `mix.exs` `@version "0.1.0"` aligns with consumer-facing `{:chimeway, "~> 0.1"}` in README, `guides/introduction/installation.md`, and `guides/introduction/golden-path.md`.
- **D-06:** Forbid `~> 1.0` / `1.0.0` version drift in those consumer-facing files — replaces Phase 36 manual grep gates with persistent CI enforcement (DOCS-02 regression protection).

#### Installer task name gate
- **D-07:** Doc-contract tests require `mix chimeway.gen.migrations` in installation, golden-path, and README install blocks; forbid fictional installer task names — ties docs to Phase 35 D-01 locked task name.

#### `mix verify.example` in CI
- **D-08:** Add a dedicated GitHub Actions job in `.github/workflows/ci.yml` running `mix verify.example` on every push/PR to `main` — separate job from core `mix ci.test` matrix (preserves Phase 33 fast-feedback pattern).
- **D-09:** Do **not** add `verify.example` to default `mix ci` alias — keep explicit opt-in via named entrypoint + CI job + MAINTAINING.md runbook.

#### `verify.example` scope expansion
- **D-10:** Expand `mix verify.example` to include admin/reference-flow smoke beyond webhook E2E — run `chimeway_admin` test suite and/or add minimal demo-host admin route coverage at `/admin/chimeway` (Phase 40 deferred OPER smoke).
- **D-11:** Preserve existing demo-host webhook + feedback pipeline E2E coverage inside `verify.example`; expansion is additive, not a replacement.

#### Named pre-ship entrypoint
- **D-12:** Add `mix ci.verify_gates` alias bundling doc-contract tests + version-alignment gates as the single citeable GATE-01 command for maintainers and CI documentation.
- **D-13:** `ci.verify_gates` runs scoped test path(s) only — not full `mix test` — for fast, explicit gate semantics parallel to `ci.install_golden`.

#### MAINTAINING.md release runbook
- **D-14:** Update `MAINTAINING.md` step 3 ("Run the full local gate") to mandate `mix ci`, `mix ci.docs`, `mix ci.verify_gates`, and `mix verify.example` before tagging/publishing.
- **D-15:** Document `mix ci.install_golden` as required when installer templates or `lib/mix/tasks/chimeway.gen.migrations.ex` change (reference existing path-gated CI job; do not change gating behavior).
- **D-16:** Post-publish verify trio (`verify.clean`, `verify.parity`, `verify.published`) remains unchanged — GATE-01 gates are **pre-ship**, not post-publish.

### Claude's Discretion
- Exact forbidden/required string lists per new describe block
- Whether version-alignment lives in `doc_contract_test.exs` or a sibling `version_alignment_test.exs`
- Whether `verify.example` chains `chimeway_admin` tests via subprocess or adds demo-host admin LiveView smoke test
- CI job naming and matrix details (single OTP version vs full matrix for example host)
- Whether `ci.verify_gates` also invokes `mix ci.docs` or keeps docs separate (MAINTAINING.md already mandates both)

### Deferred (OUT OF SCOPE)
- **Full fresh-Phoenix-host UAT automation** — Create app → migrate → trigger → explain in IEx; manual UAT acceptable; not CI-automated in this phase
- **Hex 1.0.0 coordinated release** — Version bump + publish checklist expansion — out of scope; gates enforce current `0.1.0` alignment
- **Doc-contract gates for every guide under `guides/`** — Only adoption-surface docs with known drift history; cheatsheet and flow guides not in GATE-01 matrix unless planning discovers gaps
- **Adding `verify.example` to default `mix ci`** — Explicitly rejected; keep fast local gate + named CI job
- **Engine/API changes** — Out of scope for v1.5 adoption surface
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| GATE-01 | Doc-contract checks and `mix verify.example` are part of the release checklist so doc drift is caught before ship | Extend `doc_contract_test.exs` (4 adoption-surface files + version/installer gates); add `mix ci.verify_gates`; wire `verify.example` CI job; expand `verify.example` for admin smoke; update `MAINTAINING.md` pre-ship runbook |
</phase_requirements>

## Summary

Phase 41 closes the v1.5 adoption-surface quality loop by making **doc truth** (Phases 36–38) and **reference proof** (Phases 39–40) **release-blocking gates** instead of maintainer grep checklists.

Today the repo has strong partial coverage: `test/chimeway/doc_contract_test.exs` runs **37 ExUnit tests** across moduledoc (4 modules), journey guide (DOCS-03), and two reference recipes (RECP-01/02). Adoption-surface docs that drove the most adopter pain — **README**, **golden-path**, **installation**, and **oban-integration** (IN-01) — have **no automated gates**. Phase 36 shipped manual grep gates in `36-03-PLAN.md` (version alignment, API drift, trigger-opt parity) that are **not yet codified** in ExUnit. `mix verify.example` runs only `examples/chimeway_demo_host` tests (webhook + feedback E2E) and is **not in CI**. `MAINTAINING.md` step 3 mandates only `mix ci` — GATE-01 entrypoints are absent from the runbook.

**Primary recommendation:**

1. **Extend `doc_contract_test.exs`** with four new `describe` blocks mirroring the Phase 37–38 pattern (`setup` + `@forbidden_strings` / `@required` + `for` macro expansion). Add a **version-alignment describe** (or sibling `version_alignment_test.exs`) that reads `mix.exs` `@version` dynamically and derives expected `~> 0.N` constraint — avoids hard-coding `0.1.0` on every release.
2. **Add `mix ci.verify_gates`** scoped to doc-contract test path(s) only — parallel to `ci.install_golden`, no Postgres required (file-read tests, `async: true`).
3. **Add `verify_example` CI job** — always runs on push/PR (unlike path-gated `install_golden_contract`); needs Postgres + root `ecto.create`/`ecto.migrate` before `mix verify.example` because demo host tests use `Chimeway.Repo` sandbox.
4. **Expand `verify.example`** by chaining `chimeway_admin` subprocess tests (11 tests, ~5s) — lowest-friction admin smoke; optional follow-on demo-host `/admin/chimeway` route test if plan wants host-mount proof.
5. **Update `MAINTAINING.md`** step 3 to list all four pre-ship commands plus `ci.install_golden` conditional note (D-15).

**Confidence: HIGH** — all target files, aliases, CI patterns, and deferred work are verified in-repo. Medium confidence only on `verify.example` expansion shape (subprocess vs demo-host LiveView).

---

## Architectural Responsibility Map

| Layer | Responsibility | Phase 41 touch |
|-------|----------------|----------------|
| **Doc-contract tests** (`test/chimeway/doc_contract_test.exs`) | Static forbidden/required string gates on markdown surfaces | **Primary deliverable** — 4 new describe blocks + version/installer gates |
| **Mix aliases** (`mix.exs`) | Named maintainer/CI entrypoints | Add `ci.verify_gates`; expand `verify.example`; **do not** modify `ci` default |
| **CI workflows** (`.github/workflows/ci.yml`) | Merge-blocking proof lanes | New `verify_example` job (Postgres); doc gates can ride `ci.test` via full suite OR stay fast via dedicated alias |
| **Example host** (`examples/chimeway_demo_host/`) | Webhook + feedback E2E proof | Unchanged tests; still first step in `verify.example` |
| **Admin package** (`chimeway_admin/`) | Operator UI smoke | Second subprocess in `verify.example` (recommended) |
| **Release runbook** (`MAINTAINING.md`) | Human pre-ship checklist | Step 3 expansion; D-15 installer conditional |
| **Post-publish verify** (`verify.clean/parity/published`) | Hex publish proof | **Untouched** (D-16) |

```mermaid
flowchart LR
  subgraph pre_ship [Pre-ship GATE-01]
    CG["mix ci.verify_gates"]
    VE["mix verify.example"]
    CD["mix ci.docs"]
    CI["mix ci"]
  end
  subgraph ci_jobs [GitHub Actions]
    TEST["ci.test matrix"]
    VEX["verify_example job"]
    IG["install_golden_contract path-gated"]
    DOCS["docs.yml ci.docs"]
  end
  CG --> DCT["doc_contract_test.exs"]
  VE --> DH["demo_host tests"]
  VE --> ADM["chimeway_admin tests"]
  VEX --> VE
  TEST --> CI
```

---

## Standard Stack

| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| ExUnit | built-in | Doc-contract + version gates | Established Phases 37–38 pattern |
| Mix aliases | `mix.exs` | `ci.verify_gates`, `verify.example` | AGENTS.md + Phase 33/35 precedent |
| GitHub Actions | `ci.yml` | Dedicated proof lanes | `install_golden_contract` template |
| PostgreSQL 15 | service container | Demo host E2E | `Chimeway.Repo` sandbox in example tests |
| Elixir 1.17 / OTP 27 | CI pin | Example host job | Matches lint + install_golden jobs |

**No new dependencies.** No external doc-lint tooling.

---

## Architecture Patterns

### 1. Doc-contract describe block (canonical — extend, do not replace)

Source: `test/chimeway/doc_contract_test.exs` (37 tests today)

```elixir
describe "golden path doc contract (DOCS-01)" do
  @guide "guides/introduction/golden-path.md"

  setup do
    %{content: File.read!(@guide)}
  end

  @forbidden_strings ~w(
    stop_conditions
    Workflows.Workers
    Chimeway.Trigger.trigger
    mix chimeway.install
  )

  for forbidden <- @forbidden_strings do
    test "forbids #{forbidden}", %{content: content} do
      refute String.contains?(content, unquote(forbidden)), ...
    end
  end

  test "forbids Chimeway.Workflow module (not Workflows)", %{content: content} do
    refute Regex.match?(~r/Chimeway\.Workflow(?![s])/, content), ...
  end

  @required ~w(
    mix chimeway.gen.migrations
    Chimeway.trigger
    idempotency_key
    tenant_id
    Chimeway.Traces.explain_delivery
    {:chimeway, "~> 0.1"}
  )

  for required <- @required do
    test "requires #{required}", %{content: content} do
      assert String.contains?(content, unquote(required)), ...
    end
  end
end
```

**Per-file variance (from codebase audit):**

| File | Extra required | Extra forbidden | Notes |
|------|----------------|-----------------|-------|
| `README.md` | `golden-path`, `mix chimeway.gen.migrations`, `{:chimeway, "~> 0.1"}` | fictional APIs + `mix chimeway.install` | Quick Start already has `idempotency_key` + `tenant_id` |
| `installation.md` | installer task, `explain_delivery`, dep constraint | same fiction set | No trigger example — skip `Chimeway.trigger` required |
| `golden-path.md` | full vertical slice (D-03) | same fiction set | Add trigger-opt parity test (see §Phase 36 gates) |
| `oban-integration.md` | both dispatch workers (D-04) | `Workflows.Workers` | Already correct in repo; gate prevents regression |

### 2. Version alignment gate (codify Phase 36 Gate 1 + Gate 4)

**Current repo state (verified 2026-05-29):**

| Source | Value |
|--------|-------|
| `mix.exs` `@version` | `"0.1.0"` |
| README dep | `{:chimeway, "~> 0.1"}` |
| `installation.md` dep | `{:chimeway, "~> 0.1"}` |
| `golden-path.md` dep | `{:chimeway, "~> 0.1"}` |
| Forbidden `~> 1.0` / `1.0.0` in consumer files | **0 matches** |

**Recommendation:** Dynamic version test — read `@version` from `mix.exs`, compute minor-series constraint `~> 0.N` from semver, assert presence in three consumer files. Forbid `~> 1.0`, `1.0.0`, and `{:chimeway, "~> 1.` patterns. Keeps gate valid across future `0.2.0` bumps without rewriting tests.

```elixir
describe "consumer version alignment (DOCS-02 / GATE-01)" do
  @consumer_files ~w(
    README.md
    guides/introduction/installation.md
    guides/introduction/golden-path.md
  )

  test "mix.exs @version aligns with ~> 0.N in consumer docs" do
    mix_content = File.read!("mix.exs")
    [_, version] = Regex.run(~r/@version "([^"]+)"/, mix_content)
    [major, minor, _patch] = String.split(version, ".")
    expected = "{:chimeway, \"~> #{major}.#{minor}\"}"

    for path <- @consumer_files do
      content = File.read!(path)
      assert String.contains?(content, expected),
             "#{path} must include #{expected} aligned with mix.exs @version #{version}"
    end
  end

  @drift_patterns ~w(~> 1.0 1.0.0 {:chimeway, "~> 1.)

  for path <- @consumer_files, pattern <- @drift_patterns do
    test "forbids version drift #{pattern} in #{path}" do
      refute String.contains?(File.read!(unquote(path)), unquote(pattern)), ...
    end
  end
end
```

**Placement:** Same file as doc-contract tests (keeps `ci.verify_gates` one path) unless file size becomes unwieldy.

### 3. Phase 36 manual gates → ExUnit mapping

From `36-03-PLAN.md` Task 36-03-03:

| Phase 36 gate | Automation target | Status |
|---------------|-------------------|--------|
| Gate 1 — `~> 1.0` / `1.0.0` forbidden | Version alignment describe (D-06) | ❌ manual only |
| Gate 2 — `resolve_recipients` / `identity:` forbidden | Golden-path + README describe | ❌ manual only; **use exact strings** — `recipient_identity` is valid API |
| Gate 3 — trigger opt parity in golden-path | Dedicated test: `Chimeway.trigger` count == `idempotency_key:` count == `tenant_id:` count | ❌ manual only |
| Gate 4 — `@version` ↔ `~> 0.1` | Version alignment describe (D-05) | ❌ manual only |
| Gate 5 — cross-link enumeration | Optional required strings (`golden-path` in README/installation) | Partially covered by D-03 required lists |
| Gate 6 — `mix ci.docs` | Unchanged; MAINTAINING.md mandates separately | ✅ exists |
| Gate 7 — `mix ci` | Unchanged | ✅ exists |

### 4. `ci.verify_gates` alias (mirror `ci.install_golden`)

Current `ci.install_golden` pattern:

```elixir
"ci.install_golden": [
  "cmd env MIX_ENV=test mix test test/chimeway/install/golden_diff_test.exs test/chimeway/install/idempotency_test.exs --warnings-as-errors"
]
```

Proposed `ci.verify_gates`:

```elixir
"ci.verify_gates": [
  "cmd env MIX_ENV=test mix test test/chimeway/doc_contract_test.exs --warnings-as-errors"
]
```

Add sibling path if version alignment splits to `version_alignment_test.exs`. **Do not** bundle `mix ci.docs` — MAINTAINING.md already mandates it separately (D-14 discretion resolved toward separation).

**Runtime:** ~1–3s (file I/O only, no DB). Safe to run without Postgres.

### 5. `verify.example` expansion (D-10/D-11)

**Current alias:**

```elixir
"verify.example": [
  "cmd cd examples/chimeway_demo_host && mix deps.get && mix test"
]
```

**Demo host test inventory:**

| File | Coverage |
|------|----------|
| `feedback_pipeline_e2e_test.exs` | Full webhook → signal → workflow progression trace |
| `webhooks_controller_test.exs` | Phase 33 host-mount atomic handoff + auth leak |

**Admin test inventory (`chimeway_admin/test/`):** 11 tests — routes (mount prefix `/admin/chimeway`), LiveAuth fail-closed, redaction, TraceSearchLive mount.

**Recommended expansion (subprocess chain):**

```elixir
"verify.example": [
  "cmd cd examples/chimeway_demo_host && mix deps.get && mix test",
  "cmd cd chimeway_admin && mix deps.get && mix test"
]
```

**Alternative:** Add `demo_host_web/live/admin_mount_test.exs` hitting `GET /admin/chimeway` via `DemoHostWeb.Endpoint` — proves host router + `chimeway_admin_routes()` wiring but duplicates `chimeway_admin` package tests. Use only if plan wants single-subprocess `verify.example`.

**Postgres requirement:** Both subprocesses use `Chimeway.Repo` sandbox — CI job must run root `mix ecto.create` + `mix ecto.migrate` (same as `test` job).

### 6. `verify_example` CI job (D-08)

**Template:** `install_golden_contract` job structure, but **always run** (no path-gating per D-08).

```yaml
verify_example:
  name: Example host + admin smoke
  runs-on: ubuntu-latest
  services:
    postgres: # same as test job
  env:
    MIX_ENV: test
    DATABASE_URL: postgres://postgres:postgres@localhost/chimeway_test
  steps:
    - checkout
    - setup-beam (elixir 1.17, otp 27)  # single matrix — discretion
    - cache deps/_build
    - mix deps.get
    - mix ecto.create --quiet
    - mix ecto.migrate --quiet
    - mix verify.example
```

**Differences from `install_golden_contract`:**

| Property | `install_golden_contract` | `verify_example` (proposed) |
|----------|---------------------------|----------------------------|
| Path gating | PRs only when installer paths change | **Always** on push/PR |
| Postgres | No | **Yes** |
| fetch-depth: 0 | Yes (git diff) | Not required |

**Doc-contract gates:** Ride existing `ci.test` matrix automatically once tests land (full `mix test` includes `doc_contract_test.exs`). `ci.verify_gates` is the **named fast entrypoint** for maintainers and MAINTAINING.md — does not need its own CI job unless plan wants explicit lane (optional; not required by D-08).

### 7. MAINTAINING.md runbook update (D-14/D-15)

**Current step 3:** `mix ci` only.

**Target step 3:**

```bash
mix ci
mix ci.docs
mix ci.verify_gates
mix verify.example
```

Add subsection: **Installer changes** — when modifying `priv/chimeway_migrations/`, `lib/mix/tasks/chimeway.gen.migrations.ex`, or install tests/fixtures, also run `mix ci.install_golden` (path-gated in CI on PRs, always on main).

**Post-publish steps 8–9:** unchanged (D-16).

---

## Don't Hand-Roll

| Problem | Don't build | Use instead |
|---------|-------------|-------------|
| Markdown API linting | Custom AST doc linter, remark/rehype pipeline | ExUnit `String.contains?` / regex — Phase 37–38 proven pattern |
| Version sync | Pre-commit hook only | ExUnit gate reading `mix.exs` `@version` |
| Example proof | Fresh Phoenix app generator in CI | Existing demo host + chimeway_admin subprocess tests |
| Release gates in default CI | Add `verify.example` to `mix ci` | Named alias + dedicated CI job (D-09) |
| Admin smoke | Full browser/system test | Package-level LiveView isolated tests + optional route smoke |

---

## Common Pitfalls

1. **False positive on `identity:` grep** — Phase 36 used `resolve_recipients|identity:` but docs correctly use `recipient_identity`. Gate must target `resolve_recipients` and `identity:` as option keys, not substring-match `recipient_identity`.
2. **Hard-coding `0.1.0` in tests** — D-05 requires alignment with `@version`; dynamic derivation survives patch/minor bumps.
3. **Forgetting Postgres in `verify_example` job** — Demo host tests checkout `Chimeway.Repo`; job will fail without `ecto.create`/`migrate`.
4. **Path-gating `verify.example`** — D-08 requires every push/PR; do not copy `install_golden_contract` detect step.
5. **Replacing demo-host E2E with admin tests** — D-11 requires additive expansion; webhook + feedback pipeline must remain.
6. **Adding `verify.example` to `mix ci`** — Explicitly rejected (D-09); slows default local gate.
7. **Requiring `Chimeway.trigger` in installation.md** — Installation guide has no trigger snippet; scope required strings to file content.
8. **Oban-integration over-constraint** — Recipe mentions `Chimeway.Workflows.Progression` (valid); only forbid `Workflows.Workers` namespace and fictional `Chimeway.Workflow` module.
9. **`mix chimeway.install` in forbidden list** — Phase 35 D-02 deferred this task; docs must not advertise it; gate prevents regression.
10. **Bundling post-publish verify into pre-ship** — `verify.published` polls Hex; pre-ship uses GATE-01 quartet only (D-16).

---

## Code Examples

### Installer task name gate (D-07)

```elixir
describe "README install doc contract" do
  setup do
    %{content: File.read!("README.md")}
  end

  test "requires mix chimeway.gen.migrations", %{content: content} do
    assert content =~ "mix chimeway.gen.migrations"
  end

  test "forbids fictional mix chimeway.install", %{content: content} do
    refute content =~ "mix chimeway.install"
  end
end
```

### Golden-path trigger opt parity (Phase 36 Gate 3)

```elixir
test "every Chimeway.trigger example includes idempotency_key and tenant_id", %{content: content} do
  triggers = Regex.scan(~r/Chimeway\.trigger/, content) |> length()
  idem = Regex.scan(~r/idempotency_key:/, content) |> length()
  tenant = Regex.scan(~r/tenant_id:/, content) |> length()

  assert triggers > 0
  assert triggers == idem, "expected idempotency_key on every trigger (got #{idem}/#{triggers})"
  assert triggers == tenant, "expected tenant_id on every trigger (got #{tenant}/#{triggers})"
end
```

### Oban-integration worker gate (D-04 / IN-01)

```elixir
describe "oban integration doc contract" do
  @guide "guides/recipes/oban-integration.md"
  @required ~w(
    Chimeway.Dispatch.WorkflowProgressionWorker
    Chimeway.Dispatch.SignalRouterWorker
    chimeway_delivery
    chimeway_signals
  )
  @forbidden ~w(Workflows.Workers Chimeway.Trigger.trigger)
  # ... standard for-loop pattern
end
```

### `ci.verify_gates` + MAINTAINING.md citation

Maintainers and plans cite one command:

```bash
mix ci.verify_gates   # GATE-01 doc + version gates (~2s, no DB)
```

---

## Validation Architecture

*Nyquist sampling strategy for GATE-01 verification loop.*

### Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (`doc_contract_test.exs` + optional `version_alignment_test.exs`) |
| **Config file** | `mix.exs` aliases — `ci.verify_gates`, `verify.example`, `ci`, `ci.docs` |
| **GATE-01 fast command** | `mix ci.verify_gates` |
| **Example proof command** | `mix verify.example` |
| **Docs command** | `mix ci.docs` (separate, already mandated) |
| **Full core command** | `mix ci` (includes doc-contract via full test suite once landed) |
| **Estimated runtime** | `ci.verify_gates` ~1–3s; `verify.example` ~30–90s (deps + DB tests) |

### Requirement → Test Map

| Requirement / Decision | Verification | Automated Command | Wave 0 |
|------------------------|--------------|-------------------|--------|
| GATE-01 — doc-contract on adoption surfaces | ExUnit static assertions (D-01–D-04, D-07) | `mix ci.verify_gates` | ❌ **W0 gap** — 4 describe blocks missing |
| GATE-01 — version alignment (D-05, D-06) | ExUnit dynamic `@version` check | `mix ci.verify_gates` | ❌ **W0 gap** |
| GATE-01 — installer task name (D-07) | ExUnit required/forbidden strings | `mix ci.verify_gates` | ❌ **W0 gap** |
| GATE-01 — `verify.example` in CI (D-08) | GitHub Actions job | `mix verify.example` in `ci.yml` | ❌ **W0 gap** — no job |
| GATE-01 — admin smoke (D-10) | chimeway_admin + demo_host tests | `mix verify.example` | ❌ **W0 gap** — admin not chained |
| GATE-01 — release runbook (D-14) | MAINTAINING.md lists gates | Manual review | ❌ **W0 gap** |
| D-09 — not in default `mix ci` | Alias audit | `mix help ci` shows no verify.example | ✅ satisfied |
| D-15 — install_golden conditional docs | MAINTAINING.md | Manual review | ❌ **W0 gap** |
| D-16 — post-publish trio unchanged | MAINTAINING.md steps 8–9 | Manual review | ✅ satisfied |
| IN-01 — oban-integration doc-contract | ExUnit (D-04) | `mix ci.verify_gates` | ❌ **W0 gap** — deferred since Phase 37 |
| DOCS-02 regression | Version drift forbidden patterns | `mix ci.verify_gates` | ❌ **W0 gap** — Phase 36 manual only |

### Wave 0 Gaps (all GATE-01 automation)

- [ ] Golden-path describe block in `doc_contract_test.exs`
- [ ] Installation describe block
- [ ] README describe block
- [ ] Oban-integration describe block (IN-01)
- [ ] Version alignment describe (or sibling test module)
- [ ] Golden-path trigger opt parity test
- [ ] `mix ci.verify_gates` alias in `mix.exs`
- [ ] `verify.example` admin subprocess expansion
- [ ] `verify_example` job in `.github/workflows/ci.yml`
- [ ] `MAINTAINING.md` step 3 + installer conditional (D-14, D-15)

### Already Available (reuse, do not rebuild)

- [x] `test/chimeway/doc_contract_test.exs` pattern (37 tests, journey + recipes)
- [x] `mix verify.example` alias (demo host only)
- [x] `mix ci.install_golden` path-gated CI job template
- [x] `mix ci.docs` + `docs.yml` workflow
- [x] Demo host webhook + feedback E2E tests
- [x] `chimeway_admin` test suite (11 tests)
- [x] Consumer docs currently aligned (`0.1.0` / `~> 0.1`)
- [x] `install_golden_contract` CI job (D-15 reference, no behavior change)

### Sampling Strategy

| Surface | Strategy |
|---------|----------|
| Forbidden APIs in adoption docs | **Full enumeration** via ExUnit `for` macros |
| Required installer/API strings | **Full enumeration** per file |
| Version strings | **Full enumeration** — finite file set + dynamic `@version` |
| Trigger opt parity (golden-path) | **Full count** — regex parity test |
| Semantic prose correctness | **Out of scope** — grep cannot verify |
| Fresh Phoenix host walkthrough | **Manual UAT once** — deferred from CI (CONTEXT deferred) |
| Cross-link URL validity | **Existence check** via required substring (`golden-path`) |
| Admin operator flows | **Package test suite** — not full browser UAT |
| Webhook E2E | **Full demo host test files** — already in `verify.example` |

### CI Job Map

| Job | Command | Blocks merge? | Postgres? |
|-----|---------|---------------|-----------|
| `lint` | `mix ci.lint`, `mix ci.audit` | yes | no |
| `test` | `mix ci.test` (includes doc-contract once added) | yes | yes |
| `install_golden_contract` | `mix ci.install_golden` | yes (when triggered) | no |
| `verify_example` (new) | `mix verify.example` | yes | yes |
| `docs` (docs.yml) | `mix ci.docs` | yes (main push) | no |

### Nyquist UAT

Minimum execute-phase UAT (manual, acceptable per CONTEXT):

1. `mix ci.verify_gates` — passes with zero false positives on current docs
2. `mix verify.example` — demo host + admin green locally with Postgres
3. `mix ci` + `mix ci.docs` — no regression
4. Simulate drift: add `~> 1.0` to README → `ci.verify_gates` fails
5. MAINTAINING.md step 3 read-through — all four commands documented

Full fresh-Phoenix-host automation remains **deferred**.

---

## Security Domain

**Scope:** CI/test infrastructure phase — minimal security surface.

| Concern | Assessment |
|---------|------------|
| Secrets in CI | No new secrets; existing Postgres service credentials only |
| Doc-contract tests | Read-only file I/O; no user input |
| `verify.example` | Runs trusted in-repo tests; no network egress |
| Supply chain | Reuse SHA-pinned actions from existing `ci.yml` |
| Maintainer runbook | Documents commands only; no credential handling changes |

No STRIDE threat register required for this phase. Standard CI hygiene: pin action SHAs, do not echo `DATABASE_URL` in logs.

---

## Suggested Plan Decomposition

| Plan | Scope | Decisions |
|------|-------|-----------|
| 41-01 | Doc-contract describe blocks (golden-path, installation, README, oban-integration) + version alignment | D-01–D-07 |
| 41-02 | `mix ci.verify_gates` alias + `MAINTAINING.md` runbook | D-12–D-16 |
| 41-03 | `verify.example` expansion + `verify_example` CI job | D-08–D-11 |

Suggested commit granularity:

1. `test: add adoption-surface doc-contract gates (GATE-01)`
2. `chore: add mix ci.verify_gates and update release runbook`
3. `ci: wire verify.example job and expand admin smoke`

---

## Open Questions (for plan-phase)

| # | Question | Recommendation | Owner |
|---|----------|----------------|-------|
| OQ-1 | Version alignment in same file vs `version_alignment_test.exs`? | **Same file** — one `ci.verify_gates` path | Plan-phase |
| OQ-2 | `verify.example` subprocess vs demo-host admin route test? | **Subprocess `chimeway_admin`** first; demo-host route optional in 41-03 | Plan-phase |
| OQ-3 | Dedicated CI job for `ci.verify_gates`? | **No** — rides `test` matrix; named alias for maintainers | Plan-phase |
| OQ-4 | `verify_example` OTP matrix? | **Single** 1.17/27 — example host, not core lib matrix | Plan-phase |
| OQ-5 | Include `getting-started.md` in GATE-01 matrix? | **No** — not in D-01; golden-path is canonical slice | Plan-phase |

---

## Sources

### Primary (verified — HIGH confidence)

| Path | Use |
|------|-----|
| `.planning/phases/41-release-verification-gates/41-CONTEXT.md` | Locked D-01–D-16, deferred scope |
| `.planning/REQUIREMENTS.md` | GATE-01 acceptance text |
| `.planning/ROADMAP.md` | Phase 41 success criteria |
| `test/chimeway/doc_contract_test.exs` | Existing 37-test pattern |
| `mix.exs` | `@version`, `verify.example`, `ci.*` aliases |
| `.github/workflows/ci.yml` | `install_golden_contract` job template |
| `MAINTAINING.md` | Current runbook gap |
| `README.md`, `guides/introduction/*.md`, `guides/recipes/oban-integration.md` | Gate targets — content verified aligned |
| `examples/chimeway_demo_host/mix.exs` | Path deps, test alias |
| `examples/chimeway_demo_host/test/` | 2 E2E test modules |
| `chimeway_admin/test/` | 11 admin tests |
| `.planning/phases/36-golden-path-version-alignment/36-03-PLAN.md` | Manual grep gates to codify |
| `.planning/phases/37-doc-truth-journey-guides/37-VERIFICATION.md` | IN-01 deferred evidence |
| `AGENTS.md` | Named `mix verify.*` / `mix ci.*` mandate |

### Secondary (MEDIUM confidence)

| Path | Use |
|------|-----|
| `.planning/phases/40-operator-trace-mvp/40-CONTEXT.md` | Admin smoke deferred to Phase 41 |
| `.planning/phases/35-installer-task/35-CONTEXT.md` | Installer task name lock |
| `prompts/chimeway-testing-and-e2e-strategy.md` | Named entrypoint philosophy |

### Not consulted (LOW — not needed)

| Source | Reason |
|--------|--------|
| External doc-lint tools (vale, alex) | D-02 forbids new framework |
| Hex.pm publish API | Post-publish trio unchanged |

---

## Metadata

| Field | Value |
|-------|-------|
| Phase | 41-release-verification-gates |
| Milestone | v1.5 Adoption Surface |
| Requirements | GATE-01 |
| Depends on | Phase 40 — complete |
| Phase type | Test + CI + docs (runbook) — no engine changes |
| Files to modify | `doc_contract_test.exs`, `mix.exs`, `ci.yml`, `MAINTAINING.md` |
| Files to optionally create | `demo_host_web/live/admin_mount_test.exs` (if plan chooses host-mount proof) |
| Estimated new tests | ~40–60 ExUnit cases (4 describe blocks × forbid/require loops + version gate) |
| Risk level | Low — additive gates; docs already aligned |
| Closes deferred | IN-01 (oban-integration), Phase 36 manual gates, Phase 40 admin smoke |

---

*Phase: 41-release-verification-gates*  
*Research completed: 2026-05-29*
