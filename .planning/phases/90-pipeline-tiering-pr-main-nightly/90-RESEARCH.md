# Phase 90: Pipeline Tiering (PR/main/nightly) - Research

**Researched:** 2026-07-30
**Domain:** GitHub Actions workflow orchestration — event-conditional job scheduling, matrix generation, and gate aggregation for a single-repo Elixir/Hex CI pipeline
**Confidence:** HIGH

## Summary

Phase 90 restructures `.github/workflows/ci.yml` (1053 lines, 16 jobs, no `schedule:` trigger today) into three cadences — PR (fast, single-OTP), push (current full behavior), and a new nightly nightly tier (cold build, full OTP matrix, 1.17-floor leg, heavy Playwright smoke) — without touching any `lib/` code or the underlying `mix verify.*`/`mix ci.*` task bodies. All four requirements (TIER-01..04) are satisfiable inside the **existing** `ci.yml` file: no new workflow file is needed, and no new third-party GitHub Action is required.

The single most important discovery is a **hidden coupling that will silently break `ci-gate` on every push** if not handled explicitly: `ci-gate`'s `needs:` list is currently a hard-coded 14-job list (including `verify_admin`), and `test/chimeway/release_gate_contract_test.exs` asserts that list is *exactly* 14 lanes by name. Once `verify_admin` becomes nightly-only, it is `skipped` on every push run, and `scripts/ci/aggregate-gate.sh` treats `skipped` as a failure (`!= "success"`) — so `ci-gate` goes red on every single push unless `verify_admin` is removed from `ci-gate`'s `needs:` list **and** the contract test's `@ci_gate_lanes` list is updated in the same phase. The second landmine is `concurrency: group: ${{ github.workflow }}-${{ github.ref }}` — on `main`, `schedule` and `push` events resolve to the *same* group, so an incoming push would cancel an in-flight nightly cold-build run (`cancel-in-progress: true`), defeating TIER-01's cache-correctness backstop.

**Primary recommendation:** Add `schedule:` and a `workflow_dispatch.inputs.run_nightly` boolean to the existing `ci.yml`; introduce one tiny `resolve_tiers` setup job that emits `run_nightly` and `otp_matrix` (JSON) outputs consumed via `fromJSON()`; gate `verify_admin` plus two new jobs (`nightly_cold_build`, `test_floor_1_17`) on `needs.resolve_tiers.outputs.run_nightly == 'true'`; add a `nightly-gate` job that reuses `scripts/ci/aggregate-gate.sh` over exactly those relocated lanes; fix the `concurrency` group to key on `github.event_name` so nightly and push runs can never cancel each other; and update the two existing YAML contract tests (`release_gate_contract_test.exs`, `ci_observability_contract_test.exs`) in the same phase so they encode the new lane topology instead of the old one.

## Architectural Responsibility Map

This phase has no application-tier (browser/API/DB) capabilities — the "architecture" is the CI/CD orchestration graph itself. Capabilities are mapped to GitHub Actions orchestration layers instead of app tiers:

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Event routing (which lanes run on PR vs push vs nightly) | Workflow trigger layer (`on:` block + per-job `if:`) | — | GHA evaluates `on:`/`if:` before any job body runs; this is the only layer that can change cadence without touching job logic |
| OTP/Elixir version selection per event | Job orchestration layer (`resolve_tiers` setup job + `strategy.matrix` + `fromJSON()`) | — | Matrix legs are fixed at job-dispatch time; the value must be computed and exposed as a job *output* before the `test` job starts |
| Cold-cache correctness backstop | Job orchestration layer (dedicated `nightly_cold_build` job) | Cache layer (deliberate absence of any `actions/cache` step) | A cache-correctness canary must be a job that literally never calls `actions/cache`, not a flag on a shared job |
| Heavy browser smoke (`verify_admin` / Playwright) | Job orchestration layer (relocated job, condition change only) | — | The job body (Playwright/npm setup, `mix verify.admin`) is untouched; only its `if:` trigger condition moves |
| 1.17-floor exercise | Job orchestration layer (`test_floor_1_17` job) | Release-parity layer (mirrors `release.yml`'s existing `elixir-version: "1.17"` pin) | Proves the floor `mix.exs` declares (`~> 1.17`) is exercised by the same toolchain combination the release/publish pipeline already uses |
| Nightly pass/fail signal | Gate aggregation layer (`nightly-gate` job + `scripts/ci/aggregate-gate.sh`) | — | Must reuse the exact script/pattern `ci-gate`/`pr-gate` already use, scoped to only the relocated lanes |
| Existing push/PR gate integrity | Gate aggregation layer (`ci-gate`, `pr-gate` `needs:` lists) | Contract-test layer (`release_gate_contract_test.exs`) | Removing a relocated lane from a `needs:` list is *mandatory*, not optional — a `skipped` dependency fails `aggregate-gate.sh` |

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TIER-01 | A `schedule:` nightly tier exists that runs one full **cold** build, the full OTP {26,27} matrix, and a 1.17 floor leg (honoring `mix.exs` `~> 1.17`) | Decision rows 2–4, 6; job-relocation map rows `nightly_cold_build`, `test`, `test_floor_1_17`; Validation Architecture TIER-01 row |
| TIER-02 | The heavy Playwright `verify_admin` lane runs on the nightly tier | Decision row 2; job-relocation map row `verify_admin`; Validation Architecture TIER-02 row |
| TIER-03 | The PR path runs a single OTP version (27); push and nightly run the full matrix | Decision row 1; job-relocation map row `test`/`resolve_tiers`; Validation Architecture TIER-03 row |
| TIER-04 | A nightly aggregate gate mirrors `ci-gate` decision semantics for the relocated lanes | Decision row 5; job-relocation map row `nightly-gate`; Validation Architecture TIER-04 row; Pitfall "the `skipped`-dependency trap" |
</phase_requirements>

## Decision Table

Firm recommendations for the seven research questions (one recommendation per row, not an option menu):

| # | Question | Recommendation | Why |
|---|----------|-----------------|-----|
| 1 | Event-conditional OTP matrix | **(a) A tiny `resolve_tiers` setup job** emits `otp_matrix` as a JSON-string output (`["27"]` on `pull_request`, `["26","27"]` otherwise); `test` job does `needs: [resolve_tiers]` + `strategy.matrix.otp: ${{ fromJSON(needs.resolve_tiers.outputs.otp_matrix) }}`. [ASSUMED — pattern synthesized from CITED sources below, not copy-pasted from one canonical doc] | (b) duplicating the `test` job with mutually-exclusive `if:` guards means two job definitions (and two cache-key schemes) to keep in sync forever — exactly the anti-pattern CACHE-01/02 in Phase 88 fought to eliminate. GHA cannot skip individual matrix *legs* conditionally (the `if:` on a matrix job applies to the whole job, not one leg), so per-leg `if:` inside the matrix job is not viable; the setup-job pattern is the standard workaround `[CITED: multiple engineering blogs — see Sources]`. The `resolve_tiers` job must be a bare job (no checkout) to keep its added serial latency near-zero on the PR path (a few seconds of runner boot + one shell step). |
| 2 | Nightly tier shape: same `ci.yml` vs `nightly.yml` | **(a) Add `schedule:` to the existing `ci.yml`**; gate nightly-only jobs on `needs.resolve_tiers.outputs.run_nightly == 'true'`. | A separate `nightly.yml` would duplicate ~14 jobs' boilerplate (checkout SHA pins, Postgres service blocks, PG env vars, cache-key conventions) that Phase 88 just finished de-duplicating — a second file to keep in sync forever. Same-file keeps `lint`/`verify_gates`/`verify_docs` reused unmodified across all three tiers, keeps `ci-gate`/`pr-gate`/new `nightly-gate` in one script-driven pattern (`aggregate-gate.sh`), and keeps `release.yml`'s existing `gh workflow run ci.yml` dispatch working unchanged (see row 6). |
| 3 | Cold-build backstop | **A dedicated `nightly_cold_build` job that never calls `actions/cache` at all** (not a cache-restore skip, not a key salt). Elixir 1.19 / OTP 27 (matches the PR-path default toolchain) so the backstop targets the most-trafficked combination. `[CITED: actions/cache README + community pattern — see Sources]` | Skipping only the *restore* step but still attempting a *save* at job end (via `if: github.event_name != 'schedule'` on the cache step) still writes a cache entry every night, adding storage churn for no benefit. A unique-key salt (e.g. `run_id`) still writes an entry per run. Omitting the `actions/cache` step entirely from a standalone job is the cleanest, most literal "no restored cache" — zero ambiguity, zero storage cost, and it does not touch the warm caches every other tier depends on. |
| 4 | 1.17 floor leg | **A separate dedicated job (`test_floor_1_17`), not a matrix `include:` entry**, pinned to `elixir-version: "1.17"` / `otp-version: "27"` — the exact pair `release.yml`/`publish-hex.yml` already use to build/publish (`elixir-version: "1.17"`, `otp-version: "27"`, verified at `.github/workflows/release.yml:257-260` and `.github/workflows/publish-hex.yml:153-156`). | A matrix `include:` entry inside `test` would make the job's display name and its `needs:`-list entry ambiguous (one job name covering three different toolchain combos), complicating `nightly-gate`'s `needs:` enumeration (TIER-04). A standalone job with its own cache key namespace (`build-floor-1.17-...`) is simplest to reference and to reason about. **Boundary with Phase 91 (QUAL-05):** this job only proves the floor *compiles and passes tests*; it does **not** touch `release.yml`/`publish-hex.yml`'s own Elixir pin or resolve the CI↔release version-skew narrative — that reconciliation (documenting/confirming CI and release now agree on 1.17) is explicitly QUAL-05's job in Phase 91. Phase 90 should not edit `release.yml`. |
| 5 | Nightly aggregate gate | **A new `nightly-gate` job**, `needs: [nightly_cold_build, test, test_floor_1_17, verify_admin]`, `if: always() && needs.resolve_tiers.outputs.run_nightly == 'true'`, calling `scripts/ci/aggregate-gate.sh` with the same `NAME=${{ needs.<job>.result }}` + args pattern `ci-gate` uses today (verified at `ci.yml:1029-1052`). Do **not** add `nightly-gate` (or the three new nightly-only jobs) to `ci-gate`'s existing `needs:` list. | This is a byte-for-byte reuse of the proven `aggregate-gate.sh` contract (`scripts/ci/aggregate-gate.sh:1-27`, `[VERIFIED: read from repo]`) — no new gate-decision logic to write or test. `test` is included because it is part of "the nightly tier" per TIER-01's own wording (cold build + full matrix + floor leg), even though `test` is *also* a dependency of `ci-gate`/`pr-gate` — a job can be a `needs:` target of more than one gate job simultaneously with no conflict. |
| 6 | `schedule:` mechanics & pitfalls | Cron **`"0 7 * * *"`** (07:00 UTC, chosen off a round hour per GitHub's own guidance to reduce queueing delay at `:00`) `[CITED: docs.github.com/en/actions/using-workflows/events-that-trigger-workflows]`. Add `workflow_dispatch.inputs.run_nightly` (boolean, default `false`) alongside the existing bare `workflow_dispatch:` (used today by `release.yml`'s bootstrap dispatch, which must keep defaulting to `false` so a release-PR CI bootstrap does *not* accidentally trigger the full nightly tier). **Also fix `concurrency.group` to include `github.event_name`** (`group: ${{ github.workflow }}-${{ github.event_name }}-${{ github.ref }}`, `cancel-in-progress: ${{ github.event_name == 'pull_request' }}`). | Cron is best-effort and can be delayed or dropped under GitHub-wide load, especially at `:00` `[CITED: docs.github.com — see Sources]`; today's group key `${{ github.workflow }}-${{ github.ref }}` puts `push` and `schedule` events on `main` in the **same** concurrency group, so `cancel-in-progress: true` (current value, unconditional) would let a routine push cancel an in-flight nightly cold-build run — silently defeating TIER-01's backstop. Scoping `cancel-in-progress` to `pull_request` only preserves today's "cancel superseded PR runs" behavior while never cancelling a push or nightly run mid-flight. |
| 7 | Verifying without a 24h cron wait | **Layered static + dynamic checks**, see Validation Architecture below; the headline dynamic check is `gh workflow run ci.yml --ref <branch> -f run_nightly=true` (the `workflow_dispatch` input from row 6) followed by `gh run watch`/`gh run view --json jobs` to confirm `nightly_cold_build`, `test` (both OTP legs), `test_floor_1_17`, `verify_admin`, and `nightly-gate` all executed and passed — a full real execution of the nightly path, on demand, same day. | `act` (installed locally, v0.2.87) and `actionlint` (installed locally, v1.7.12) are available as fast pre-push static/local checks but neither replicates hosted-runner Postgres services or `actions/cache` semantics with full fidelity `[VERIFIED: locally installed — see Environment Availability]`; the `gh workflow run` dispatch is the only check that proves the *real* GitHub-hosted execution path end-to-end without waiting for the actual 07:00 UTC cron. |

## Job-Relocation Map

Every job whose trigger condition or matrix changes, current state -> target state (verified line numbers against the `ci.yml` read in this research session):

| Job | Current trigger (`ci.yml` line) | Target tier(s) | What changes |
|-----|----------------------------------|----------------|---------------|
| `resolve_tiers` (**new**) | — | PR, push, nightly (always runs) | New bare setup job; no `actions/checkout`; emits `run_nightly` + `otp_matrix` outputs |
| `test` | Runs on all events; `matrix.otp: ["26","27"]` unconditionally (`ci.yml:169-176`) | PR (otp 27 only), push (otp 26+27), nightly (otp 26+27) | Add `needs: [resolve_tiers]`; `matrix.otp: ${{ fromJSON(needs.resolve_tiers.outputs.otp_matrix) }}` |
| `verify_admin` | `if: github.event_name != 'pull_request'` (push + dispatch) (`ci.yml:853`) | Nightly only | `if: needs.resolve_tiers.outputs.run_nightly == 'true'`; add `needs: [resolve_tiers]` |
| `nightly_cold_build` (**new**) | — | Nightly only | New job: no `actions/cache` step at all; elixir 1.19 / otp 27; full `deps.get` -> `compile --warnings-as-errors` -> `ecto.create`/`migrate` -> `mix ci.test` |
| `test_floor_1_17` (**new**) | — | Nightly only | New job: elixir 1.17 / otp 27 (matches `release.yml`); warm self-cache under a distinct `build-floor-1.17-...` key; `deps.get` -> `compile --warnings-as-errors` -> `ecto.create`/`migrate` -> `mix ci.test` |
| `nightly-gate` (**new**) | — | Nightly only | New aggregate job: `needs: [nightly_cold_build, test, test_floor_1_17, verify_admin]`; calls `scripts/ci/aggregate-gate.sh` |
| `ci-gate` | `needs:` includes `verify_admin` (14 lanes) (`ci.yml:1032`) | Push (unchanged semantics) | **Remove `verify_admin` from `needs:`** (13 lanes) — mandatory, see Pitfall below |
| `pr-gate` | `needs: [lint, test, verify_gates, verify_docs]` (`ci.yml:232`) | PR (unchanged) | No change — `test`'s matrix shrinking to 1 leg on PR does not change `pr-gate`'s `needs:` list, only how many `test` matrix jobs run underneath it |
| `concurrency` (top-level) | `group: ${{ github.workflow }}-${{ github.ref }}`, `cancel-in-progress: true` (`ci.yml:11-13`) | All tiers | `group: ${{ github.workflow }}-${{ github.event_name }}-${{ github.ref }}`; `cancel-in-progress: ${{ github.event_name == 'pull_request' }}` |
| `on:` (top-level) | `push`, `pull_request`, `workflow_dispatch` (no inputs) (`ci.yml:3-9`) | All tiers | Add `schedule: - cron: "0 7 * * *"`; add `workflow_dispatch.inputs.run_nightly` (boolean, default `false`) |
| `lint`, `verify_gates`, `verify_docs`, `verify_example`, `verify_runtime_prefix`, `verify_journeys`, `verify_mailglass`, `verify_accrue`, `verify_inbox`, `verify_threadline`, `verify_sigra`, `install_golden_contract` | Unchanged (`if: github.event_name != 'pull_request'` for the push-only ones; unconditional for `lint`/`verify_gates`/`verify_docs`) | Unchanged (still run on push AND schedule — **not** relocated; DEF-PARTNER-NIGHTLY is deferred, see boundary note below) | No trigger changes. These jobs continue running on both push and nightly runs exactly as they do today. |

**DEF-PARTNER-NIGHTLY boundary (explicit):** the deferred backlog item to move partner integration lanes (`verify_accrue`, `verify_threadline`, `verify_sigra`, `verify_mailglass`, `verify_inbox`, `verify_journeys`, `verify_example`, `install_golden_contract`) to nightly-only is **out of scope for Phase 90**. Only `verify_admin` relocates per TIER-02's explicit text ("The heavy Playwright `verify_admin` lane runs on the nightly tier"). All the partner/integration lanes above keep their current `if: github.event_name != 'pull_request'` guard unchanged and will continue to run on **both** push and nightly-triggered workflow runs (harmless — they already run on every push today; a nightly run is just an additional non-PR event that satisfies the same guard). Do not narrow their conditions in this phase.

## Standard Stack

No new libraries or third-party GitHub Actions are introduced by this phase — it is a pure `ci.yml` restructuring using already-adopted, already-SHA-pinned actions.

### Core (already in use, unchanged versions)
| Action | Pinned ref | Purpose | Why Standard |
|--------|------------|---------|--------------|
| `actions/checkout` | `34e114876b0b11c390a56381ad16ebd13914f8d5` | Repo checkout | Already the repo convention; new jobs (`nightly_cold_build`, `test_floor_1_17`) reuse the same pin `[VERIFIED: read from ci.yml]` |
| `erlef/setup-beam` | `8251c48667b97e88a0a24ec512f5b72a039fcea7` | Elixir/OTP toolchain install | Already the repo convention; `test_floor_1_17` reuses the same pin with different `with:` version inputs `[VERIFIED: read from ci.yml]` |
| `actions/cache` | `0057852bfaa89a56745cba8c7296529d2fc39830` | Dependency/build caching | Used by every warm-tier job; deliberately **absent** from `nightly_cold_build` `[VERIFIED: read from ci.yml]` |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Same-file `ci.yml` with `schedule:` | Separate `nightly.yml` workflow file | Rejected — duplicates ~14 jobs' boilerplate; two files to keep in sync; complicates `release.yml`'s existing `gh workflow run ci.yml` dispatch pattern |
| `resolve_tiers` setup job + `fromJSON()` | Duplicate `test` job with `if:`-guarded mutually-exclusive definitions | Rejected — doubles the job definition and cache-key surface area; violates the DRY lesson from Phase 88's cache-key de-duplication |
| Omit `actions/cache` step entirely for cold build | Cache-key salt (e.g., `run_id`) to force a guaranteed miss | Rejected — still performs a cache *save* every night, growing storage for a job whose entire point is to never read a cache |
| `resolve_tiers`-driven `workflow_dispatch.inputs.run_nightly` | Gate nightly jobs on `github.event_name == 'workflow_dispatch'` unconditionally | Rejected — would make `release.yml`'s existing unconditional `gh workflow run ci.yml` dispatch (used to bootstrap CI on open Release PRs) accidentally trigger the full nightly tier on every release, adding ~15+ min per release for no reason |

## Package Legitimacy Audit

**Not applicable.** This phase modifies only `.github/workflows/ci.yml` (and two Elixir test files that assert against it); no `mix.exs`/`mix.lock`/`package.json` dependency is added, upgraded, or introduced. No package-legitimacy check was run because there is nothing to check.

## Architecture Patterns

### System Architecture Diagram

```
                         ┌─────────────────────────────┐
                         │   on: push | pull_request |  │
                         │   schedule (07:00 UTC) |     │
                         │   workflow_dispatch          │
                         └───────────────┬──────────────┘
                                         │
                                         ▼
                          ┌───────────────────────────┐
                          │   resolve_tiers (new)      │
                          │   - run_nightly: bool      │
                          │   - otp_matrix: JSON       │
                          └───────────┬───────────────┘
                    ┌─────────────────┼────────────────────────┐
                    ▼                 ▼                        ▼
        ┌─────────────────┐ ┌──────────────────┐   ┌────────────────────────┐
        │ lint             │ │ test (matrix)     │   │  nightly-only jobs      │
        │ verify_gates     │ │ otp: fromJSON(     │   │  (if: run_nightly)      │
        │ verify_docs      │ │  resolve_tiers.    │   │  - nightly_cold_build   │
        │ (all events)     │ │  otp_matrix)       │   │  - test_floor_1_17      │
        └────────┬─────────┘ └─────────┬─────────┘   │  - verify_admin         │
                 │                    │              └────────────┬────────────┘
                 │                    │                            │
                 ▼                    ▼                            ▼
        ┌─────────────────────────────────────┐        ┌───────────────────────┐
        │  pr-gate (PR only)                    │        │  nightly-gate (new)    │
        │  needs: lint,test,verify_gates,docs   │        │  needs: cold_build,    │
        └─────────────────────────────────────┘        │  test, floor, admin    │
                                                          └───────────────────────┘
                 ┌─────────────────────────────────────────────────┐
                 │  ci-gate (push/dispatch, NOT pull_request)        │
                 │  needs: lint, test, verify_gates, verify_docs,    │
                 │  verify_example..install_golden_contract          │
                 │  (verify_admin REMOVED — now nightly-only)         │
                 └─────────────────────────────────────────────────┘
```

A reader can trace: an event enters at the top, `resolve_tiers` computes the two tier flags once, `test`'s matrix and every nightly-only job's `if:` read those flags, and exactly one of `pr-gate` / `ci-gate` / `nightly-gate` renders the pass/fail verdict for that event.

### Recommended Project Structure

No new directories. All changes land in the existing `.github/workflows/ci.yml` plus updates to two existing test files:

```
.github/workflows/
└── ci.yml                              # resolve_tiers, nightly_cold_build, test_floor_1_17,
                                         # nightly-gate added; test/verify_admin/ci-gate/
                                         # concurrency/on: modified
test/chimeway/
├── release_gate_contract_test.exs      # @ci_gate_lanes drops verify_admin (13 not 14);
│                                        # new nightly-gate assertions
└── ci_observability_contract_test.exs  # optionally extend @build_lanes coverage to the
                                         # new nightly-only jobs (not required, but keeps
                                         # OBS-01/02/03 parity if the new jobs reuse obs-summary.sh)
```

### Pattern 1: Setup-job-driven conditional matrix (`fromJSON`)
**What:** A tiny upstream job computes a JSON array as a string output; a downstream job's `strategy.matrix` consumes it via `fromJSON()`.
**When to use:** Whenever a matrix's dimension set must differ by trigger event, and duplicating the whole job is undesirable.
**Example:**
```yaml
# Source: pattern synthesized from GitHub Actions expression-language docs +
# multiple engineering write-ups (see Sources) — [ASSUMED: exact field names
# generalized, not copied verbatim from one canonical source]
jobs:
  resolve_tiers:
    name: Resolve tier flags
    runs-on: ubuntu-latest
    outputs:
      run_nightly: ${{ steps.flags.outputs.run_nightly }}
      otp_matrix: ${{ steps.flags.outputs.otp_matrix }}
    steps:
      - id: flags
        shell: bash
        run: |
          set -euo pipefail
          if [ "${{ github.event_name }}" = "pull_request" ]; then
            echo 'otp_matrix=["27"]' >>"$GITHUB_OUTPUT"
          else
            echo 'otp_matrix=["26","27"]' >>"$GITHUB_OUTPUT"
          fi

          if [ "${{ github.event_name }}" = "schedule" ] || \
             { [ "${{ github.event_name }}" = "workflow_dispatch" ] && \
               [ "${{ github.event.inputs.run_nightly }}" = "true" ]; }; then
            echo "run_nightly=true" >>"$GITHUB_OUTPUT"
          else
            echo "run_nightly=false" >>"$GITHUB_OUTPUT"
          fi

  test:
    name: Test (Elixir ${{ matrix.elixir }} / OTP ${{ matrix.otp }})
    needs: [resolve_tiers]
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        elixir: ["1.19"]
        otp: ${{ fromJSON(needs.resolve_tiers.outputs.otp_matrix) }}
    # ...unchanged steps below (services, cache key already parameterizes on matrix.otp)
```

### Pattern 2: Cache-free job as a cold-build backstop
**What:** A job that omits the `actions/cache` action entirely, guaranteeing every dependency is fetched and every module compiled from nothing.
**When to use:** When the requirement is "prove the build works with zero cached state," not "prove the build is fast."
**Example:**
```yaml
# Source: no actions/cache step present at all — verified by its absence.
# [VERIFIED: read from repo — existing warm lanes for comparison, e.g.
# ci.yml:169-227 `test` job, always include an actions/cache step; this job
# intentionally does not]
nightly_cold_build:
  name: Nightly cold build (cache-correctness backstop)
  runs-on: ubuntu-latest
  needs: [resolve_tiers]
  if: needs.resolve_tiers.outputs.run_nightly == 'true'
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
      ports:
        - 5432:5432
  env:
    MIX_ENV: test
    DATABASE_URL: postgres://postgres:postgres@localhost/chimeway_test
  steps:
    - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5
    - uses: erlef/setup-beam@8251c48667b97e88a0a24ec512f5b72a039fcea7
      id: beam
      with:
        elixir-version: "1.19"
        otp-version: "27"
    # NOTE: deliberately no actions/cache step here — this is the whole point.
    - run: |
        mix local.rebar --force
        mix local.hex --force
        mix deps.get
    - run: mix compile --warnings-as-errors
    - run: mix ecto.create --quiet
    - run: mix ecto.migrate --quiet
    - run: mix ci.test
    - name: CI observability summary
      if: always()
      shell: bash
      env:
        GH_TOKEN: ${{ github.token }}
        RUN_URL: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}/attempts/${{ github.run_attempt }}
      run: scripts/ci/obs-summary.sh
```

### Pattern 3: Nightly aggregate gate mirroring `ci-gate`
**What:** A gate job with the identical `needs:`-then-`aggregate-gate.sh` pattern, scoped to a different job set.
**Example:**
```yaml
# Source: mirrors ci-gate verbatim (ci.yml:1029-1052), [VERIFIED: read from repo]
nightly-gate:
  name: nightly-gate
  runs-on: ubuntu-latest
  needs: [resolve_tiers, nightly_cold_build, test, test_floor_1_17, verify_admin]
  if: always() && needs.resolve_tiers.outputs.run_nightly == 'true'
  steps:
    - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5
    - name: Verify required nightly lanes
      env:
        NIGHTLY_COLD_BUILD: ${{ needs.nightly_cold_build.result }}
        TEST: ${{ needs.test.result }}
        TEST_FLOOR_1_17: ${{ needs.test_floor_1_17.result }}
        VERIFY_ADMIN: ${{ needs.verify_admin.result }}
      run: scripts/ci/aggregate-gate.sh NIGHTLY_COLD_BUILD TEST TEST_FLOOR_1_17 VERIFY_ADMIN
```

### Anti-Patterns to Avoid
- **Per-leg `if:` inside a matrix job:** GitHub Actions cannot conditionally skip a single matrix *leg* — `if:` on a matrix job applies to the whole job (all legs run or none do). Do not attempt `matrix.otp[1]` conditional exclusion tricks; use the `resolve_tiers` output pattern instead.
- **Leaving `verify_admin` in `ci-gate`'s `needs:` after relocating its trigger:** produces a `skipped` result that `aggregate-gate.sh` treats as a hard failure on every push. This is the single most important thing to get right in this phase (see Pitfalls).
- **Unconditional `workflow_dispatch` nightly trigger:** would make `release.yml`'s existing bootstrap dispatch (`gh workflow run ci.yml --ref release-please--branches--main`, `.github/workflows/release.yml:119`) accidentally run the full nightly tier on every open release PR update.
- **A cache-key salt to force a "cold" build:** still performs a cache *write* every night; not a true absence of caching, and grows cache storage for no benefit.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|--------------|-----|
| Nightly pass/fail aggregation | A bespoke bash script duplicating `aggregate-gate.sh`'s success-check loop | `scripts/ci/aggregate-gate.sh` (already exists, already tested by `Chimeway.CIObservabilityContractTest`/`ReleaseGateContractTest`) | It already does exactly this: takes N env-var names, fails if any isn't literally `success` |
| Manual nightly-run polling for CI verification | A custom polling script | `gh run watch <run-id>` / `gh run view --json jobs` (gh CLI already used the same way in `release.yml`'s `gate-ci-green` job) | The repo already has this exact polling pattern in `release.yml:150-241`; reuse the muscle memory, don't invent a new one |
| Detecting whether the current run is "nightly-equivalent" | Repeating the `github.event_name == 'schedule' || (...)` expression in every nightly job's `if:` | The `resolve_tiers.outputs.run_nightly` boolean output, computed once | DRY — one truth for "is this a nightly-tier run," referenced everywhere else |

**Key insight:** every piece of gate-decision logic this phase needs (aggregation, polling, dispatch) already exists somewhere in this repo's own `ci.yml`/`release.yml`. The job is relocation and composition, not invention.

## Common Pitfalls

### Pitfall 1: The `skipped`-dependency trap (breaks `ci-gate` on every push)
**What goes wrong:** `ci-gate`'s `needs:` list (`ci.yml:1032`) currently includes `verify_admin`. Once `verify_admin`'s `if:` becomes nightly-only, every push-triggered run has `needs.verify_admin.result == 'skipped'`. `scripts/ci/aggregate-gate.sh` fails any lane whose value `!= "success"` — `skipped` fails exactly like a real failure.
**Why it happens:** GitHub Actions job `needs:` dependencies don't distinguish "intentionally not applicable" from "ran and failed" — both surface as a non-`success` `result`.
**How to avoid:** Remove `verify_admin` from `ci-gate`'s `needs:` list in the same commit that changes `verify_admin`'s `if:` condition. Update `test/chimeway/release_gate_contract_test.exs`'s `@ci_gate_lanes` list (currently 14 entries including `"verify_admin"`, `ci.yml`-verified count) to 13 entries, and update the `"ci-gate aggregates 14 required lanes"` test name/assertion to 13.
**Warning signs:** `ci-gate` goes red on the very first push after the trigger change lands, with `aggregate-gate.sh` output literally reading `Required lane VERIFY_ADMIN: skipped`.

### Pitfall 2: Shared concurrency group cancels the nightly cold-build backstop
**What goes wrong:** `concurrency.group: ${{ github.workflow }}-${{ github.ref }}` (`ci.yml:11-13`) resolves identically for `push` and `schedule` events on `main` (same `github.ref`). With `cancel-in-progress: true` (current, unconditional), a routine push to `main` while the nightly run is in flight cancels the nightly run.
**Why it happens:** `github.ref` alone doesn't distinguish event type; GHA's concurrency model treats same-group runs as mutually exclusive regardless of *why* each was triggered `[CITED: docs.github.com/en/actions/using-jobs/using-concurrency]`.
**How to avoid:** Change the group key to `${{ github.workflow }}-${{ github.event_name }}-${{ github.ref }}` and scope `cancel-in-progress` to `${{ github.event_name == 'pull_request' }}` so push and schedule runs never contend for the same slot, while PR runs keep today's "cancel the superseded run" behavior.
**Warning signs:** A nightly run's status shows `cancelled` in the Actions UI with a "Canceling since a higher priority waiting request... exists" annotation, timestamped near an unrelated push to `main`.

### Pitfall 3: `resolve_tiers` adds serial latency to the PR path if it's not kept trivial
**What goes wrong:** Introducing a new upstream job that everything else `needs:` adds one job's worth of runner-boot latency (typically 5-15s) in series before `test`/nightly jobs can start — directly working against this milestone's own <3 min PR-path goal.
**Why it happens:** Any `needs:` edge is a hard serialization point; GitHub Actions cannot start the dependent job before the dependency completes.
**How to avoid:** Keep `resolve_tiers` a bare job with no `actions/checkout` and a single tiny shell step — no compile, no dependency install, no external action calls. Its entire cost should be runner-provisioning time plus milliseconds of shell.
**Warning signs:** `resolve_tiers`'s own step timing (visible via the existing OBS tooling) exceeds ~15s.

### Pitfall 4: `workflow_dispatch` default coupling with `release.yml`'s bootstrap dispatch
**What goes wrong:** `release.yml`'s `bootstrap-release-pr-ci` job (`release.yml:101-122`) already calls `gh workflow run ci.yml --ref release-please--branches--main` with no inputs. If nightly-only jobs are gated merely on `github.event_name == 'workflow_dispatch'` (without checking an explicit input), every release-PR bootstrap dispatch would trigger the full nightly tier (cold build + floor leg + Playwright), adding significant time to every release.
**Why it happens:** `workflow_dispatch` is reused today for a narrow purpose (bootstrapping PR-parity CI on a release branch) that predates this phase's nightly-tier concept.
**How to avoid:** Add an explicit `workflow_dispatch.inputs.run_nightly` boolean input defaulting to `false`; gate nightly jobs on `github.event.inputs.run_nightly == 'true'` (in addition to `schedule`), not on `workflow_dispatch` alone. `release.yml`'s existing dispatch call needs no change — omitting the new input defaults it to `false`.
**Warning signs:** A routine release PR update triggers `verify_admin`/`nightly_cold_build` in its bootstrap CI run.

### Pitfall 5: `schedule:` cron only fires from the default branch and is best-effort
**What goes wrong:** Testing the cron trigger itself (as opposed to the jobs it gates) cannot be done from a feature branch — `schedule:` workflows only run from whatever is committed on the repository's default branch `[CITED: docs.github.com/en/actions/using-workflows/events-that-trigger-workflows]`. Additionally, GitHub explicitly documents that scheduled runs can be delayed or dropped during periods of high platform load, especially at the top of the hour.
**Why it happens:** GitHub Actions scheduling infrastructure is shared and best-effort, not a guaranteed-delivery cron daemon.
**How to avoid:** Do not gate phase completion on observing an actual 07:00 UTC cron firing during the plan's execution window (see Validation Architecture — use `workflow_dispatch` dispatch instead). Pick an off-the-hour cron minute if avoiding queueing delay matters (`"0 7 * * *"` fires exactly on the hour; a stricter reading of GitHub's own advice would pick e.g. `"17 7 * * *"` — either is acceptable for this phase, but the plan should note the tradeoff was considered).

## Code Examples

### `on:` block additions (schedule + dispatch input)
```yaml
# Source: pattern extends the existing ci.yml on: block (ci.yml:3-9) [VERIFIED: read from repo]
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:
    - cron: "0 7 * * *"
  workflow_dispatch:
    inputs:
      run_nightly:
        description: "Run the nightly tier (cold build, full OTP matrix, 1.17 floor, verify_admin)."
        required: false
        type: boolean
        default: false
```

### Concurrency fix
```yaml
# Source: fixes ci.yml:11-13 [VERIFIED: read from repo]
concurrency:
  group: ${{ github.workflow }}-${{ github.event_name }}-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}
```

### `test_floor_1_17` job (1.17 floor leg)
```yaml
# Source: mirrors the `test` matrix job body (ci.yml:169-227) with a pinned
# elixir-version matching release.yml's own pin (release.yml:257-260)
# [VERIFIED: read from repo]
test_floor_1_17:
  name: Test (Elixir 1.17 floor / OTP 27)
  runs-on: ubuntu-latest
  needs: [resolve_tiers]
  if: needs.resolve_tiers.outputs.run_nightly == 'true'
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
      ports:
        - 5432:5432
  env:
    MIX_ENV: test
    DATABASE_URL: postgres://postgres:postgres@localhost/chimeway_test
  steps:
    - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5
    - uses: erlef/setup-beam@8251c48667b97e88a0a24ec512f5b72a039fcea7
      id: beam
      with:
        elixir-version: "1.17"
        otp-version: "27"
    - uses: actions/cache@0057852bfaa89a56745cba8c7296529d2fc39830
      id: cache_main
      with:
        path: |
          deps
          _build
        key: test-floor-${{ runner.os }}-${{ steps.beam.outputs.elixir-version }}-${{ steps.beam.outputs.otp-version }}-${{ hashFiles('mix.lock') }}
        restore-keys: |
          test-floor-${{ runner.os }}-${{ steps.beam.outputs.elixir-version }}-${{ steps.beam.outputs.otp-version }}-
    - run: |
        mix local.rebar --force
        mix local.hex --force
        mix deps.get
    - run: mix compile --warnings-as-errors
    - run: mix ecto.create --quiet
    - run: mix ecto.migrate --quiet
    - run: mix ci.test
```

### `verify_admin` trigger change (unified diff sketch)
```diff
  verify_admin:
    name: Admin integration gate
    runs-on: ubuntu-latest
-   if: github.event_name != 'pull_request'
+   needs: [resolve_tiers]
+   if: needs.resolve_tiers.outputs.run_nightly == 'true'
```

### `ci-gate` needs-list fix (unified diff sketch)
```diff
  ci-gate:
    name: ci-gate
    runs-on: ubuntu-latest
-   needs: [lint, test, verify_gates, verify_docs, verify_example, verify_runtime_prefix, verify_journeys, verify_mailglass, verify_accrue, verify_inbox, verify_threadline, verify_sigra, verify_admin, install_golden_contract]
+   needs: [lint, test, verify_gates, verify_docs, verify_example, verify_runtime_prefix, verify_journeys, verify_mailglass, verify_accrue, verify_inbox, verify_threadline, verify_sigra, install_golden_contract]
    if: always() && github.event_name != 'pull_request'
    steps:
      - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5
      - name: Verify required CI lanes
        env:
          LINT: ${{ needs.lint.result }}
          TEST: ${{ needs.test.result }}
          VERIFY_GATES: ${{ needs.verify_gates.result }}
          VERIFY_DOCS: ${{ needs.verify_docs.result }}
          VERIFY_EXAMPLE: ${{ needs.verify_example.result }}
          VERIFY_RUNTIME_PREFIX: ${{ needs.verify_runtime_prefix.result }}
          VERIFY_JOURNEYS: ${{ needs.verify_journeys.result }}
          VERIFY_MAILGLASS: ${{ needs.verify_mailglass.result }}
          VERIFY_ACCRUE: ${{ needs.verify_accrue.result }}
          VERIFY_INBOX: ${{ needs.verify_inbox.result }}
          VERIFY_THREADLINE: ${{ needs.verify_threadline.result }}
          VERIFY_SIGRA: ${{ needs.verify_sigra.result }}
-         VERIFY_ADMIN: ${{ needs.verify_admin.result }}
          INSTALL_GOLDEN: ${{ needs.install_golden_contract.result }}
        run: scripts/ci/aggregate-gate.sh LINT TEST VERIFY_GATES VERIFY_DOCS VERIFY_EXAMPLE VERIFY_RUNTIME_PREFIX VERIFY_JOURNEYS VERIFY_MAILGLASS VERIFY_ACCRUE VERIFY_INBOX VERIFY_THREADLINE VERIFY_SIGRA INSTALL_GOLDEN
```

### Contract-test update sketch (`release_gate_contract_test.exs`)
```elixir
# Source: existing test file at test/chimeway/release_gate_contract_test.exs:19
# [VERIFIED: read from repo]
# BEFORE (14 lanes, includes verify_admin):
@ci_gate_lanes ~w(lint test verify_gates verify_docs verify_example verify_runtime_prefix verify_journeys verify_mailglass verify_accrue verify_inbox verify_threadline verify_sigra verify_admin install_golden_contract)

# AFTER (13 lanes, verify_admin removed — it is now nightly-only):
@ci_gate_lanes ~w(lint test verify_gates verify_docs verify_example verify_runtime_prefix verify_journeys verify_mailglass verify_accrue verify_inbox verify_threadline verify_sigra install_golden_contract)

# The test name "ci-gate aggregates 14 required lanes" (line 236) must also be
# renamed to "ci-gate aggregates 13 required lanes" (or a name independent of
# the count) so the assertion text doesn't lie about what it checks.
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|-------------------|---------------|--------|
| `test` matrix runs `otp: ["26","27"]` on every event including `pull_request` | `otp` matrix resolved per-event via a setup job + `fromJSON()` | This phase | Halves PR-path `test` job count (1 leg instead of 2), directly serving TIER-03 and the milestone's <3 min PR-path goal |
| `verify_admin` (Playwright) runs on every push/dispatch | `verify_admin` runs only on the nightly tier | This phase | Removes the heaviest single non-matrix lane (npm install + Playwright browser download + browser automation) from the push-blocking `ci-gate`/release path; release confidence for admin-console smoke becomes nightly-cadence rather than release-gated (accepted tradeoff, explicit per TIER-02) |
| No cache-cold canary exists anywhere in `ci.yml` | `nightly_cold_build` proves the pipeline still builds/tests green with zero cached state, nightly | This phase | Directly answers the open question left by `CI-HARDENING-BACKLOG.md` #4 (Phase 88's deferred compile-once investigation) — a nightly cold run is a standing regression detector for cache-key correctness bugs, independent of whether the compile-once optimization is ever revisited |
| CI never exercises `mix.exs`'s declared `~> 1.17` floor (CI pins 1.19 everywhere except `release.yml`/`publish-hex.yml`, which pin 1.17 for *build only*, not for running the test suite) | Nightly `test_floor_1_17` job runs the full test suite under Elixir 1.17 / OTP 27 | This phase | Closes the gap where the floor constraint was declared but never actually tested — sets up (but does not complete) the version-skew reconciliation QUAL-05 finishes in Phase 91 |

**Deprecated/outdated:** none — this phase adds tiering to an already-modernized pipeline (Phase 87 added observability, Phase 88 fixed cache correctness, Phase 89 added test concurrency); there is no legacy tiering approach being replaced.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|-----------------|
| A1 | The exact `resolve_tiers` job shape (field names `run_nightly`/`otp_matrix`, bash-based flag computation) is a synthesized pattern, not copied verbatim from one single canonical GitHub doc — the *technique* (setup job + `fromJSON()`) is well-documented, but this repo's specific implementation is original | Decision row 1, Pattern 1 | Low — the pattern is a thin shell script; if GitHub Actions expression syntax details are slightly off, `actionlint` will catch it before merge (see Validation Architecture) |
| A2 | Cron `"0 7 * * *"` (07:00 UTC) is a reasonable nightly time with no stated project-specific constraint on exact hour | Decision row 6 | Low — cosmetic; any off-peak UTC hour works equally well for TIER-01's intent, and the owner can trivially change the cron string later |
| A3 | `nightly-gate`'s `needs:` list should include `test` (in addition to `nightly_cold_build`, `test_floor_1_17`, `verify_admin`) even though `test` is also a `ci-gate`/`pr-gate` dependency | Decision row 5, job-relocation map | Low-medium — if the planner/owner intends "nightly-gate" to cover *only* the genuinely-new nightly-exclusive jobs, `test` should be dropped from its `needs:` list; either choice is internally consistent, this is a judgment call on TIER-04's exact scope, not a technical constraint |

**If this table is empty:** N/A — see rows above; none of these assumptions block planning, but A3 in particular is worth a one-line confirmation during `/gsd-discuss-phase` or plan review since it changes `nightly-gate`'s `needs:` list by one entry.

## Open Questions

1. **Should `nightly-gate` include `test` in its `needs:` list?**
   - What we know: `test` already gates both `pr-gate` (PR) and `ci-gate` (push); TIER-01's wording lists "the full OTP {26,27} matrix" as part of the nightly tier's composition, which argues for inclusion.
   - What's unclear: whether the milestone intends `nightly-gate` to report on strictly-new-to-nightly jobs only, or on "everything material to a nightly run's confidence."
   - Recommendation: include `test` (per this research's Decision row 5) — it costs nothing (a job can be a dependency of multiple gates) and gives a more complete single-glance nightly signal. Flag for `/gsd-discuss-phase` confirmation if the owner wants a narrower `nightly-gate`.

2. **Exact cron minute/hour.**
   - What we know: any off-peak UTC time satisfies TIER-01; GitHub advises avoiding exact-hour boundaries under heavy platform load.
   - What's unclear: no project-stated preference exists.
   - Recommendation: `"0 7 * * *"` is fine as a default; treat as Claude's discretion unless the owner has an operational reason (e.g., wanting results ready before a specific timezone's morning) to pick differently.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|--------------|-----------|---------|----------|
| `actionlint` | Static validation of the restructured `ci.yml` (Validation Architecture, all TIER-0x) | Yes | 1.7.12 (Homebrew, built from source) | — |
| `gh` (GitHub CLI) | Dynamic `workflow_dispatch` verification (row 7, Validation Architecture) | Yes | 2.95.0 | — |
| `act` (nektos/act) | Optional local dry-run of the job graph / `if:` preview before pushing | Yes | 0.2.87 | Not required — `actionlint` + `gh workflow run` dispatch are sufficient; `act` does not faithfully replicate hosted-runner Postgres services or `actions/cache` semantics, so treat it as an optional pre-push sanity pass only |
| GitHub-hosted `ubuntu-latest` runners | All new/modified jobs execute there, same as every existing job | Yes (already used by 16 jobs today) | — | — |

**Missing dependencies with no fallback:** none.

**Missing dependencies with fallback:** none — all tooling needed for both static and dynamic verification is already installed locally.

## Validation Architecture

This phase has no application test suite to extend (it is CI/CD orchestration, not Elixir library code), but the project already treats `ci.yml` itself as a tested contract via `test/chimeway/release_gate_contract_test.exs` and `test/chimeway/ci_observability_contract_test.exs` (ExUnit tests that regex-parse `ci.yml` and assert structural invariants). This phase's "test framework" is the combination of that existing ExUnit contract-test pattern plus GitHub-Actions-native static/dynamic checks — all executable without waiting for a real 07:00 UTC cron.

### Test Framework
| Property | Value |
|----------|-------|
| Framework (structural/contract) | ExUnit — `test/chimeway/release_gate_contract_test.exs`, `test/chimeway/ci_observability_contract_test.exs` |
| Framework (workflow-syntax) | `actionlint` v1.7.12 (installed locally) |
| Framework (live execution) | GitHub Actions itself, driven via `gh workflow run` / `gh run watch` |
| Config file | none — `actionlint` needs no config for this repo's usage; ExUnit config is the existing `mix.exs`/`config/test.exs` |
| Quick run command | `actionlint .github/workflows/ci.yml` (sub-second) |
| Full suite command | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs test/chimeway/ci_observability_contract_test.exs` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|---------------------|--------------|
| TIER-01 (cold build) | `nightly_cold_build` job exists, has no `actions/cache` step, runs on `schedule`/`run_nightly` dispatch | static (regex) | `mix test test/chimeway/release_gate_contract_test.exs --only nightly_cold_build` (new test, see Wave 0 Gaps) | ❌ Wave 0 |
| TIER-01 (full matrix) | `test` job's `otp` matrix resolves to `["26","27"]` on push/schedule | static (regex/actionlint) | `actionlint .github/workflows/ci.yml` + new ExUnit assertion on `resolve_tiers` output logic | ❌ Wave 0 |
| TIER-01 (1.17 floor) | `test_floor_1_17` job exists, pins `elixir-version: "1.17"` / `otp-version: "27"` | static (regex) | new ExUnit test asserting the job block contains both pins | ❌ Wave 0 |
| TIER-01 (all three, live) | A dispatched nightly-equivalent run actually executes and passes all three | dynamic (live GH Actions) | `gh workflow run ci.yml --ref <branch> -f run_nightly=true` then `gh run watch <run-id> --exit-status` | n/a (execution-time check, not a repo file) |
| TIER-02 (`verify_admin` relocated) | `verify_admin`'s `if:` references `resolve_tiers.outputs.run_nightly`, not `github.event_name != 'pull_request'` | static (regex) | update existing/`new ExUnit test on the `verify_admin` job block | ❌ Wave 0 (update existing lane assertions) |
| TIER-02 (relocated, live) | A push-triggered run shows `verify_admin` as `skipped`; a nightly dispatch shows it `success` | dynamic (live GH Actions) | `gh run view <push-run-id> --json jobs --jq '.jobs[] \| select(.name==\"Admin integration gate\") \| .conclusion'` == `skipped`; same query on the nightly dispatch run == `success` | n/a |
| TIER-03 (PR single OTP) | `pull_request`-triggered `test` job shows exactly one matrix leg (OTP 27) | dynamic (live GH Actions, or `act pull_request -n` dry list) | Open/update a PR and run `gh pr checks` or `gh run view --json jobs --jq '.jobs[] \| select(.name \| startswith(\"Test\"))'` and count == 1 | n/a |
| TIER-03 (push/nightly full matrix) | `push`/`schedule`-triggered `test` job shows two matrix legs (OTP 26 and 27) | dynamic (live GH Actions) | Same query on a push run or the `run_nightly=true` dispatch run, count == 2 | n/a |
| TIER-04 (nightly-gate mirrors ci-gate) | `nightly-gate` job exists with `needs:` scoped to the relocated lanes and calls `scripts/ci/aggregate-gate.sh` | static (regex) | new ExUnit test asserting `nightly-gate`'s job block contains `scripts/ci/aggregate-gate.sh` and its `needs:` list | ❌ Wave 0 |
| TIER-04 (decision semantics, live) | A dispatched nightly run with all relocated lanes green shows `nightly-gate` = success | dynamic (live GH Actions) | `gh run watch <dispatch-run-id> --exit-status` then inspect the `nightly-gate` job conclusion | n/a |
| Regression guard (Pitfall 1) | `ci-gate`'s `needs:` no longer references `verify_admin`; `@ci_gate_lanes` count drops from 14 to 13 | static (ExUnit, already exists — must be updated) | `mix test test/chimeway/release_gate_contract_test.exs` (must pass with the updated `@ci_gate_lanes`) | ✅ exists, needs update |

### Sampling Rate
- **Per task commit:** `actionlint .github/workflows/ci.yml` (sub-second, run locally before every commit that touches `ci.yml`)
- **Per wave merge:** `mix test test/chimeway/release_gate_contract_test.exs test/chimeway/ci_observability_contract_test.exs` (structural contract, seconds) + `gh workflow run ci.yml --ref <branch> -f run_nightly=true` followed by `gh run watch --exit-status` (live nightly-equivalent execution, several minutes — this is the phase's real proof and should run at least once before closing the phase, and again on the final state before merge)
- **Phase gate:** Both the full ExUnit contract suite AND one green `gh run watch` on a `run_nightly=true` dispatch must be evidenced before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/chimeway/release_gate_contract_test.exs` — update `@ci_gate_lanes` (14 -> 13, drop `verify_admin`); add assertions for `resolve_tiers`, `nightly_cold_build`, `test_floor_1_17`, `nightly-gate` job existence/shape; add assertion that `verify_admin`'s `if:` no longer contains the bare `github.event_name != 'pull_request'` guard
- [ ] `test/chimeway/ci_observability_contract_test.exs` — decide whether the three new jobs join `@build_lanes` (if they reuse `obs-summary.sh`, which is recommended for observability parity) or are explicitly exempted
- [ ] No new Elixir test framework/config needed — `mix test` already covers `.exs` contract tests; `actionlint` needs no project config file for this repo's usage
- [ ] A short runbook line (in the plan or a code comment) documenting the `gh workflow run ci.yml -f run_nightly=true` command, since this is the only way to exercise the nightly tier without waiting for the cron

*(If no gaps: N/A — gaps listed above)*

## Security Domain

### Applicable ASVS Categories

This phase changes only workflow trigger/orchestration logic; it introduces no new authentication, session, input-validation, or cryptography surface. None of the standard ASVS categories (V2 Authentication, V3 Session Management, V4 Access Control, V5 Input Validation, V6 Cryptography) apply to a CI-trigger-condition restructuring.

| ASVS Category | Applies | Standard Control |
|-----------------|---------|---------------------|
| V2 Authentication | No | n/a — no auth surface touched |
| V3 Session Management | No | n/a |
| V4 Access Control | No | n/a |
| V5 Input Validation | No | n/a — the only new user-facing input is the `workflow_dispatch.inputs.run_nightly` boolean, which GitHub Actions itself type-validates as `boolean` before the workflow body ever sees it |
| V6 Cryptography | No | n/a |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|-------------------------|
| Script injection via untrusted `workflow_dispatch` input interpolated into a `run:` step | Tampering | Not applicable here — `run_nightly` is a `boolean`-typed input compared only via `==` inside `if:` expressions and shell string comparisons against the literal `"true"`; it is never interpolated into a shell command as free text. `actionlint`'s security checks (script-injection detection) will flag this automatically if a future edit changes that. |
| A malicious PR modifying `ci.yml` to grant itself nightly-tier secrets/permissions | Elevation of Privilege | Already mitigated by the repo's existing model: `pull_request` (not `pull_request_target`) is used everywhere, so a PR from a fork runs with the fork's own limited `GITHUB_TOKEN` and cannot access repo secrets regardless of what it edits in `ci.yml` — this phase does not change that trust boundary |

## Sources

### Primary (HIGH confidence)
- `.github/workflows/ci.yml` (this repo, read in full this session) — job list, triggers, cache keys, gate `needs:` lists
- `.github/workflows/release.yml`, `.github/workflows/publish-hex.yml` (this repo) — Elixir 1.17/OTP 27 pin for build/publish, `gh workflow run` dispatch pattern, `gate-ci-green` polling pattern
- `scripts/ci/aggregate-gate.sh` (this repo) — exact gate-decision script contract
- `test/chimeway/release_gate_contract_test.exs`, `test/chimeway/ci_observability_contract_test.exs` (this repo) — existing structural contract tests that must be updated
- `mix.exs` (this repo) — `elixir: "~> 1.17"` floor constraint
- `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`, `.planning/CI-HARDENING-BACKLOG.md`, `.planning/phases/88-*/88-03-SUMMARY.md`, `.planning/phases/89-*/89-06-SUMMARY.md` (this repo) — milestone scope fences and Phase 88/89 economics this phase is designed against

### Secondary (MEDIUM confidence — WebSearch, cross-referenced with official docs)
- [Events that trigger workflows - GitHub Docs](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows) — `schedule:` default-branch-only, best-effort delay/drop under load
- [Control the concurrency of workflows and jobs - GitHub Docs](https://docs.github.com/enterprise-cloud@latest/actions/using-jobs/using-concurrency) — same-group FIFO/cancel semantics
- [actions/cache - GitHub](https://github.com/actions/cache) — `cache-hit` output semantics, conditional-restore pattern
- [rhysd/actionlint](https://github.com/rhysd/actionlint) / [actionlint usage docs](https://github.com/rhysd/actionlint/blob/main/docs/usage.md) — static-check capabilities (expression type-checking, script-injection detection, cron syntax)
- Elixir compatibility: [Elixir v1.17 released blog post](https://elixir-lang.org/blog/2024/06/12/elixir-v1-17-0-released/) — confirms Elixir 1.17 supports Erlang/OTP 25/26/27

### Tertiary (LOW confidence — synthesized pattern, not a single canonical source)
- The exact `resolve_tiers` job field names and bash-flag-computation shape (Decision row 1, Pattern 1) — generalized from multiple dynamic-matrix engineering write-ups referenced by WebSearch (oneuptime.com, devopsdirective.com, peterbe.com, thekevinwang.com); the *technique* is well-established, the specific field names/script are this research's own synthesis and should be actionlint-validated before being treated as final

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new dependencies; every action/SHA pin already verified in-repo
- Architecture (job relocation, gate fix, concurrency fix): HIGH — every claim about current `ci.yml` behavior was verified by reading the actual file; the `skipped`-dependency and concurrency-group findings are direct logical consequences of documented GitHub Actions semantics, not speculation
- Pitfalls: HIGH — Pitfall 1 (skipped-dependency) and Pitfall 2 (concurrency group) are both provable from the current `ci.yml` content plus `[CITED]` GitHub documentation, not hypothetical
- `resolve_tiers` exact implementation shape: MEDIUM — pattern is standard, specific script is this research's synthesis (see Assumptions Log A1); mitigated by `actionlint` validation at execute-time

**Research date:** 2026-07-30
**Valid until:** GitHub Actions core semantics (`schedule:`, `concurrency:`, `fromJSON()`) are stable/mature features unlikely to change; this research should be re-validated only if the phase execution window extends past ~90 days or if GitHub ships a native "conditional matrix leg" feature that would obsolete the `resolve_tiers` workaround.

## RESEARCH COMPLETE

**Phase:** 90 - Pipeline Tiering (PR/main/nightly)
**Confidence:** HIGH

### Key Findings
- All four requirements (TIER-01..04) fit inside the existing `ci.yml` — no new workflow file, no new third-party Action.
- **Critical landmine:** `ci-gate`'s hard-coded `needs:` list (and its ExUnit contract test asserting exactly 14 lanes) will break on every push unless `verify_admin` is removed from it in the same change that relocates `verify_admin` to nightly-only — a `skipped` dependency fails `aggregate-gate.sh` identically to a real failure.
- **Second landmine:** the current `concurrency` group key (`${{ github.workflow }}-${{ github.ref }}`) puts `push` and `schedule` events on `main` in the same group, so an ordinary push would cancel an in-flight nightly cold-build run under today's unconditional `cancel-in-progress: true` — fix by keying the group on `github.event_name` too.
- Recommended design: one tiny `resolve_tiers` setup job emits `run_nightly` (bool) and `otp_matrix` (JSON) outputs consumed via `fromJSON()`; three new jobs (`nightly_cold_build` with no cache step at all, `test_floor_1_17` pinned to release.yml's own Elixir 1.17/OTP 27, and `nightly-gate` reusing `aggregate-gate.sh`) plus one relocated job (`verify_admin`).
- `test_floor_1_17` should match `release.yml`/`publish-hex.yml`'s existing Elixir 1.17 / OTP 27 pin exactly — this sets up (but does not complete) Phase 91's QUAL-05 CI-vs-release version-skew reconciliation.
- Verification does not require waiting for the real cron: `actionlint` (installed, v1.7.12) validates syntax/expressions statically, and `gh workflow run ci.yml -f run_nightly=true` + `gh run watch --exit-status` (gh CLI installed, v2.95.0) exercises the entire nightly path live, same day.

### File Created
`.planning/phases/90-pipeline-tiering-pr-main-nightly/90-RESEARCH.md`

### Confidence Assessment
| Area | Level | Reason |
|------|-------|--------|
| Standard Stack | HIGH | Zero new dependencies; all action SHAs already pinned and verified in-repo |
| Architecture | HIGH | Every current-state claim verified by reading `ci.yml`/`release.yml`/`publish-hex.yml`/test files directly; landmines are provable, not speculative |
| Pitfalls | HIGH | Both critical pitfalls are direct, demonstrable consequences of existing code + documented GHA semantics |

### Open Questions
- Whether `nightly-gate`'s `needs:` list should include `test` (recommended: yes) or be scoped strictly to the three brand-new nightly-exclusive jobs — low-stakes, flag for discuss-phase/plan-review confirmation.
- Exact cron minute/hour (recommended: `"0 7 * * *"`) — cosmetic, Claude's discretion absent an owner preference.

### Ready for Planning
Research complete. Planner can now create PLAN.md files — pay particular attention to sequencing the `ci-gate` `needs:`-list fix and the `release_gate_contract_test.exs` update in the same task/commit as the `verify_admin` trigger relocation, since either one alone leaves the pipeline in a broken intermediate state.
