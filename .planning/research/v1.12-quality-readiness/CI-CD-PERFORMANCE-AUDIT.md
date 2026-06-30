# CI/CD Performance and DX Audit

**Date:** 2026-06-30  
**Baseline:** current working tree  
**Live run history:** not collected. The repo does not contain `scripts/ci_monitor.cjs`, which the local GitHub workflow skill requires for live GitHub Actions inspection. Findings use workflow files, local commands, and repo evidence.

## 1. Executive Summary

Top recommendations:
1. Fix current green-state blockers first: `mix ci.lint` fails formatting and root `mix ci.test` equivalent fails 6 tests in the current working tree.
2. Keep a fast always-on PR gate, but move full ecosystem sweep to release/main/scheduled unless touched paths require it.
3. Add nested caches for demo/admin/inbox projects and Node/Playwright cache for `verify_admin`.
4. Move long inline CI scripts into local scripts or Mix tasks so failures are reproducible outside GitHub Actions.
5. Rework installer/golden tests so they remain high-value but do not dominate root test runtime.

Expected impact:
- Faster PR feedback.
- Lower runner-minute waste.
- Fewer contributor surprises.
- Better release confidence because full gates still run where they matter.

Risk level:
- Medium. The main risk is weakening release gates accidentally. Avoid this by keeping full 12-lane `ci-gate` for release PRs/tags until there is data proving a narrower set is safe.

First PR to make:
- Do not start with a YAML rewrite. First fix formatting/test isolation, add CI timing/job summary instrumentation, and document "fast local gate" vs "full release gate".

## 2. Current Pipeline Map

| Workflow | Trigger | Job/lane | Runner | Matrix/services | Command(s) | Cache | Quality signal | Likely bottleneck |
|---|---|---|---|---|---|---|---|---|
| `CI` | push main, pull_request main, workflow_dispatch | `lint` | ubuntu-latest | none | `mix ci.lint`, `mix ci.audit` | root `deps`, `_build` | format/compile/credo/hex audit | compile + credo |
| `CI` | same | `verify_gates` | ubuntu-latest | none | `mix ci.verify_gates` | root separate key | doc/release contracts | compile/setup duplication |
| `CI` | same | `verify_docs` | ubuntu-latest | none | `mix ci.docs` | root separate key | ExDoc warning gate | docs compile |
| `CI` | same | `test` | ubuntu-latest | Elixir 1.17 x OTP 26/27, Postgres 15 | create/migrate, `mix ci.test` | root matrix key | root suite on two OTP versions | DB setup + serialized tests |
| `CI` | same | `verify_example` | ubuntu-latest | Postgres 15 | create/migrate, `mix verify.example` | root only | demo/admin/inbox smoke | nested deps/compile not cached |
| `CI` | same | `verify_journeys` | ubuntu-latest | Postgres 15 | `mix verify.journeys` | root only | TeamPulse journeys | demo setup |
| `CI` | same | `verify_mailglass` | ubuntu-latest | Postgres 15 | `mix verify.mailglass` | root only | Mailglass integration | demo setup |
| `CI` | same | `verify_accrue` | ubuntu-latest | Postgres 15, external checkout | `mix verify.accrue` | root only | Accrue dunning proof | external deps/compile |
| `CI` | same | `verify_inbox` | ubuntu-latest | Postgres 15 | `mix verify.inbox` | root only | inbox package/demo | nested deps/compile |
| `CI` | same | `verify_threadline` | ubuntu-latest | Postgres 15, external checkout | `mix verify.threadline` | root only | Threadline telemetry proof | external deps/compile |
| `CI` | same | `verify_sigra` | ubuntu-latest | Postgres 15, external checkout | custom inline runner + demo test | root only | Sigra auth proof | custom setup + compile |
| `CI` | same | `verify_admin` | ubuntu-latest | Postgres 15, Node 22 | `mix verify.admin` | root only | admin/browser smoke | npm, Playwright install, demo server |
| `CI` | same | `install_golden_contract` | ubuntu-latest | path-gated | `mix ci.install_golden` | root broad key | installer idempotency/golden | subprocess app generation |
| `CI` | same | `ci-gate` | ubuntu-latest | needs 12 lanes | shell checks results | none | required aggregate | waits for slowest lane |
| `Release` | push main, dispatch | Release Please, CI bootstrap, CI polling, publish | ubuntu-latest | GitHub API, Hex | release-please, wait for `ci-gate`, publish | root deps in publish | release automation | polling and token complexity |
| `Release PR Auto-Merge` | workflow_run, dispatch | merge release PR | ubuntu-latest | GitHub API | verify `ci-gate`, merge, dispatch release | none | release PR automation | branch protection sync |
| `Publish Hex Recovery` | workflow_dispatch | gate CI, publish | ubuntu-latest | GitHub API, Hex | wait for `ci-gate`, dry-run/publish | root deps | manual recovery | polling |

## 3. Baseline Metrics

| Evidence | Result | Notes |
|---|---|---|
| `elixir -e 'System.schedulers_online()'` | 18 local schedulers | Local machine only, not GitHub runner proxy |
| `MIX_ENV=test mix compile --profile time` | Completed, no profile output emitted because everything was already compiled | Need cold compile timing in CI/job summary |
| `mix xref graph --format cycles --label compile-connected` | No cycles found | Architecture compile graph is healthy |
| `MIX_ENV=test mix test --exclude mailglass --exclude accrue --exclude threadline --exclude sigra --slowest 20` | 1008 tests, 6 failures, 41 excluded, 73.3s | Current working tree is not green |
| Same root test run | `max_cases: 1` | Root suite is effectively serialized |
| Same root test run | Top 3 tests consume about 68.2s | Golden/subprocess installer tests dominate runtime |
| Same root test run | Fixture warning for golden migration files | Test load filters need cleanup |
| `mix ci.lint` | Failed formatting check | Current working tree lint is red |
| `mix test --profile-require` | Failed because current Mix expects a string argument | Do not use without an argument on this version |

Top slow tests from local root run:

| Test | Time |
|---|---:|
| `Chimeway.Install.GoldenDiffTest` first run matches fixture | 24.4s |
| `Chimeway.Install.IdempotencyTest` second run produces no fixture diff | 24.0s |
| `Chimeway.Install.MigrationsTest` subprocess CLI generates migrations | 19.7s |
| Next slowest runtime tests | 0.1s or less each | Root suite cost is dominated by installer subprocess checks |

Critical path inference:
- On PRs, wall-clock is likely the slowest of `verify_admin`, `verify_sigra`, `verify_accrue/threadline`, and the two-entry OTP test matrix.
- `verify_admin` likely dominates cold runs because it performs Node setup, `npm ci`, Playwright browser install, and starts the demo host through Playwright config.
- Required `ci-gate` waits for all 12 lanes, so unrelated README or small core changes still wait on ecosystem integrations unless a future path-gate design changes that.

## 4. Findings by Category

### Correctness

- The broad CI gate is high-signal but too blunt. It catches integration drift, but it runs every ecosystem lane for every PR.
- Release gate contract tests intentionally lock the current 12-lane model, so CI changes must update tests and MAINTAINING together.
- Current working tree is red locally. That must be fixed before any CI optimization PR.

### Performance

- Repeated checkout/setup/cache/deps/create/migrate across lanes wastes runner minutes.
- Root test runtime is dominated by installer subprocess/golden tests, not normal engine tests.
- Nested projects are not cached despite prompt guidance warning that nested apps need separate cache keys.

### Determinism / Flakiness

- Local failures show database state leakage or non-isolated tests in the current tree: preference/upsert and webhook worker assertions counted rows left by other tests.
- `max_cases: 1` masks concurrency bugs and lengthens feedback. Some serialization is legitimate because many tests use shared DB sandbox/global env, but it should be explicit and measured.
- Warnings about golden fixture migration files not matching test filters create noisy logs and reduce signal.

### Caching

- Root caches often key off `hashFiles('**/mix.lock')` while caching only root `deps/_build`. Nested lockfile changes can invalidate root caches without caching nested outputs.
- Optional dependency env vars differ by lane, but cache keys do not always encode those differences.
- Node and Playwright browser caches are missing.

### Matrix / Version Policy

- Tests run Elixir 1.17 against OTP 26/27. Lint/docs/gates use Elixir 1.17/OTP 27.
- If the support promise is Elixir 1.17+ / OTP 26+, this is reasonable. Broader matrix should be scheduled/main, not every PR, unless compatibility is actively breaking.

### Test Suite Quality

- Breadth is strong: root, demo, admin, inbox, integration, docs contracts, release contracts.
- Installer tests are valuable but misplaced in default root feedback because they dominate time.
- Missing prefix/upgrade tests are now the biggest coverage gap for planned storage work.

### Security / Supply Chain

- Actions are SHA-pinned, which is strong.
- `ci.yml` lacks explicit top-level `permissions: contents: read`.
- Release workflows need write permissions, but broad writes should be scoped per job where practical.

### Release

- Release automation is sophisticated: Release Please, automerge, CI polling, recovery publish, Hex dry-run/publish.
- Release/package truth is still split; CI cannot compensate for mismatched version/changelog/docs.

### DX / Docs

- `CONTRIBUTING.md` presents `mix ci` as the quality gate, but GitHub CI runs many more gates.
- Non-trivial CI logic is inline YAML, especially Sigra and release polling, despite project prompt guidance preferring local scripts.

## 5. Prioritized Recommendations

### P0: Re-green current working tree before optimizing

- **Category:** correctness/DX
- **Current issue:** root test equivalent fails 6 tests; `mix ci.lint` fails formatting.
- **Proposed change:** fix formatting and DB isolation failures first.
- **Why idiomatic:** Elixir libraries should keep `mix format --check-formatted` and deterministic ExUnit runs as table stakes.
- **Pros:** restores trust in all later measurements.
- **Cons:** not a speed improvement by itself.
- **Expected impact:** high reliability, medium DX.
- **Risk:** low.
- **How to verify:** `mix ci.lint`; root `mix ci.test`.
- **Rollback:** revert targeted fixes if they overreach.

### P0: Split fast PR gate from full release gate

- **Category:** performance/release confidence
- **Current issue:** all 12 lanes block every PR.
- **Proposed change:** always PR-gate lint, core tests, docs, release contracts; path-gate ecosystem/admin/inbox lanes; keep full sweep on release PR/main/schedule.
- **Why idiomatic:** OSS libs commonly keep fast representative PR checks and broader release/scheduled checks.
- **Pros:** faster feedback and lower runner cost.
- **Cons:** path filters can create required-check traps if designed poorly.
- **Expected impact:** high runtime improvement.
- **Risk:** medium.
- **How to implement:** make `ci-gate` understand skipped path-gated jobs or create separate required aggregate jobs for fast vs full gates.
- **How to verify:** PR touching docs only should pass fast gate; release PR should run full gate.
- **Rollback:** restore all lanes to `ci-gate` needs.

### P0: Fix release-gate parity drift

- **Category:** correctness
- **Current issue:** Sigra pin in `MAINTAINING.md` differs from `.github/workflows/ci.yml`.
- **Proposed change:** align docs/tests/workflow around one SHA.
- **Why idiomatic:** release gates must be self-documenting and reproducible.
- **Pros:** small high-value fix.
- **Cons:** none beyond choosing canonical SHA.
- **Impact:** high trust, low runtime.
- **Risk:** low.
- **Verify:** release gate contract tests.
- **Rollback:** revert docs/workflow pair.

### P1: Add nested and browser caches

- **Category:** caching/performance
- **Current issue:** root cache only; nested projects and Playwright downloads repeat work.
- **Proposed change:** add separate caches for `examples/chimeway_demo_host/deps`, `examples/chimeway_demo_host/_build`, `chimeway_admin/deps`, `chimeway_admin/_build`, `chimeway_inbox/deps`, `chimeway_inbox/_build`, npm cache, and Playwright browsers.
- **Why idiomatic:** cache keys should match actual build roots and lockfiles.
- **Pros:** large cold/warm improvement.
- **Cons:** YAML complexity and cache invalidation care.
- **Impact:** high runtime.
- **Risk:** medium.
- **Verify:** CI summary should report cache hits and shorter nested compile steps.
- **Rollback:** remove caches without changing test commands.

### P1: Move inline CI logic into local scripts or Mix tasks

- **Category:** DX/maintainer experience
- **Current issue:** Sigra proof and release polling are hard to reproduce locally.
- **Proposed change:** create `scripts/ci/*.sh` or Mix tasks for non-trivial lanes.
- **Why idiomatic:** local/CI parity is a core project principle.
- **Pros:** easier debug and clearer logs.
- **Cons:** more files.
- **Impact:** high DX, medium reliability.
- **Risk:** low-medium.
- **Verify:** CI invokes scripts; local script reproduces failure.
- **Rollback:** inline commands again.

### P1: Reduce installer test cost in default root lane

- **Category:** test performance
- **Current issue:** three installer tests consume most root runtime.
- **Proposed change:** keep installer golden/idempotency path-gated and release-gated; remove duplicate expensive subprocess checks from the default root test path or tag them `:installer`.
- **Why idiomatic:** expensive generator/golden tests are high value but should run when relevant.
- **Pros:** root suite becomes much faster.
- **Cons:** less install coverage on unrelated PRs.
- **Impact:** high runtime.
- **Risk:** medium.
- **Verify:** installer path changes still run installer gate; unrelated root tests finish much faster.
- **Rollback:** include installer tests in default again.

### P1: Clarify local commands

- **Category:** contributor DX
- **Current issue:** `mix ci` is narrower than CI.
- **Proposed change:** rename docs: `mix ci` = fast local gate; add `mix ci.full` or documented pre-release command sequence.
- **Why idiomatic:** contributors need a short command and maintainers need a full command.
- **Pros:** less surprise.
- **Cons:** another alias/docs row.
- **Impact:** medium.
- **Risk:** low.
- **Verify:** CONTRIBUTING and MAINTAINING match mix aliases and workflow tests.
- **Rollback:** revert docs/aliases.

### P2: Add least-privilege permissions

- **Category:** security
- **Current issue:** `ci.yml` has no explicit default permissions; release workflows use broad writes.
- **Proposed change:** `permissions: contents: read` by default; per-job writes only where needed.
- **Why idiomatic:** GitHub Actions hardening best practice.
- **Pros:** supply-chain risk reduction.
- **Cons:** may expose hidden assumptions.
- **Impact:** medium security.
- **Risk:** medium.
- **Verify:** all workflows still pass.
- **Rollback:** widen permissions temporarily.

### P2: Add CI observability summary

- **Category:** measurement/DX
- **Current issue:** no baseline job summaries for version/cache/test timing.
- **Proposed change:** print BEAM versions, schedulers, cache hit flags, slowest tests, and elapsed timings into `$GITHUB_STEP_SUMMARY`.
- **Why idiomatic:** measurement before optimization.
- **Pros:** easier future tuning.
- **Cons:** more log content.
- **Impact:** medium.
- **Risk:** low.
- **Verify:** summary appears on CI runs.
- **Rollback:** remove summary step.

## 6. Proposed Target Pipeline

### PR workflow

- Always:
  - setup Beam
  - restore precise root cache
  - `mix deps.get --check-locked` if compatible with current lock policy
  - `mix format --check-formatted`
  - `mix compile --warnings-as-errors`
  - `mix credo --strict`
  - `mix hex.audit`
  - root core tests on primary Elixir/OTP
  - docs gate
  - release/doc contract gate
- Path-gated:
  - admin/browser
  - inbox
  - Mailglass
  - Accrue
  - Threadline
  - Sigra
  - installer golden
- Required check:
  - one stable aggregate fast gate.

### Main workflow

- Fast PR gate plus selected broader compatibility/runtime matrix.
- Full ecosystem gate can run on main if cost is acceptable.

### Scheduled/nightly workflow

- Full 12-lane ecosystem sweep.
- Full Playwright desktop + mobile.
- Compatibility matrix.
- Optional flake repeat/slow integration checks.

### Release/tag workflow

- Full 12-lane `ci-gate`.
- Docs build.
- Hex build/dry-run.
- Publish only from trusted release ref.

## 7. Concrete Patch Concepts

Do not apply these until after the current tree is green.

```yaml
permissions:
  contents: read
```

```yaml
- uses: actions/setup-node@49933ea5288caeca8642d1e84afbd3f7d6820020
  with:
    node-version: "22"
    cache: "npm"
```

```yaml
- uses: actions/cache@0057852bfaa89a56745cba8c7296529d2fc39830
  with:
    path: |
      chimeway_admin/deps
      chimeway_admin/_build
    key: ${{ runner.os }}-admin-${{ matrix.elixir || '1.17' }}-${{ matrix.otp || '27' }}-${{ hashFiles('mix.lock', 'chimeway_admin/mix.lock') }}
```

```bash
scripts/ci/verify-sigra.sh
scripts/ci/verify-admin-browser.sh
scripts/ci/wait-ci-gate.sh
```

## 8. Test Cleanup Plan

Keep in PR:
- root core behavior tests
- formatter/compile/credo
- docs and release contracts
- migration contract for touched migrations
- one admin smoke when admin paths change

Optimize:
- installer subprocess/golden tests
- demo host nested dependency setup
- Playwright browser install
- non-async DB tests where safe

Fix/quarantine before trusting:
- current DB state leakage failures in preferences/webhook tests
- fixture test-load warning noise

Move to release/scheduled unless touched:
- full external ecosystem gates
- full Playwright mobile matrix
- broad compatibility matrix
- exhaustive installer golden checks on unrelated code changes

Delete/rewrite:
- no deletion recommended yet. The slow tests have real value; move or optimize them first.

## 9. Validation Plan

Track before/after:
- PR wall-clock p50/p95.
- Slowest job and slowest step.
- Cache hit rate by root/admin/inbox/demo/npm/Playwright.
- Root test runtime.
- Installer gate runtime.
- Failure/rerun rate.
- Flaky test list with seed.
- Compile time cold/warm.
- Time to actionable failure.

Local reproduction commands:

```bash
mix ci.lint
MIX_ENV=test mix test --exclude mailglass --exclude accrue --exclude threadline --exclude sigra --slowest 20
mix ci.verify_gates
mix ci.docs
```

Full pre-release sequence should remain in `MAINTAINING.md` and should call the same scripts/aliases as CI.

## 10. Recommended Local Commands

Fast contributor gate:

```bash
mix ci.lint
mix ci.test
```

Maintainer pre-release gate after CI cleanup:

```bash
mix ci.lint
mix ci.test
mix ci.docs
mix ci.verify_gates
mix verify.example
mix verify.journeys
mix verify.mailglass
mix verify.accrue
mix verify.inbox
mix verify.threadline
mix verify.sigra
mix verify.admin
```

## 11. Open Assumptions

- Live GitHub run timings were not available because the repo lacks the required `scripts/ci_monitor.cjs` wrapper.
- The current local DB may contain state from prior runs, but test failures still expose isolation fragility because tests assert global counts.
- GitHub-hosted runner CPU should be measured in CI; local 18 schedulers is not the runner baseline.

