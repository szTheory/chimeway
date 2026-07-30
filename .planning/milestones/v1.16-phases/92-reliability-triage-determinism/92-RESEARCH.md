# Phase 92: Reliability Triage & Determinism - Research

**Researched:** 2026-07-30
**Domain:** GitHub Actions CI reliability measurement (gh CLI / REST), Elixir/ExUnit determinism & app-env isolation under `async: true`, Mix path-dep compilation
**Confidence:** HIGH (all findings verified against the live repo, live CI runs, and committed code this session)

## Summary

Phase 92 is the last phase of the v1.16 CI milestone and is almost entirely a **measurement + verification + hygiene** phase, not a build phase. The pipeline is already fast, warm, tiered, and supply-chain hardened; this phase proves it is *trustworthy* and adds the last two determinism guards. There are **no new external packages** — every deliverable is a bash script, a Mix alias, a `ci.yml` lane, an ExUnit helper, and their contract tests. The milestone-wide invariant still holds: **zero `lib/` runtime behavior changes** (the `put_env` helper lives in `test/support/`).

The single most important discovery: **all four requirements are already close to satisfied by the current state of `main`, and the work is primarily to make that state *provable and re-runnable*.** Live CI shows the last 12 push-on-`main` runs at 11 green `ci-gate` / 1 `cancelled` (infra, excluded) — the `failure` conclusions in `gh run list` are all `workflow_dispatch` runs on the `release-please--branches--main` bot branch or nightly-tier dispatches, **not** `main`-branch pushes. REL-02's two lanes (`verify_accrue`, `verify_example`/`verify_journeys`) are **currently green on every push run** via interim fixes whose root causes this research has now pinned down. So the phase risk is not "can we fix it" but "can we measure/verify it honestly and re-runnably" — exactly the project's shift-left principle.

**Primary recommendation:** Build one new re-runnable, log-assertable measurement script (`scripts/ci/reliability-report.sh`) that classifies push-on-`main` `ci-gate` outcomes; promote both REL-02 lanes to *verified-fixed* (both root causes are understood and genuinely resolved — tighten the band-aids rather than quarantine); add a dedicated nightly `--seed 0` lane wired into `nightly-gate`; and add a `Chimeway.TestSupport.EnvHelper` capture/restore `put_env` helper, adopting it first in `test/chimeway/policy_test.exs` (the one `async: true` DataCase module that currently mutates global app-env unguarded). Guard every new artifact with a contract test (Phase 87/89/90 precedent).

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Cross-run failure-rate measurement (REL-01) | CI orchestration (bash + `gh` REST) | — | Reads run history from GitHub's API; not app code. New `scripts/ci/reliability-report.sh`, mirroring `obs-summary.sh`'s `gh api` + `jq` pattern |
| Backlog #2 fix verification (REL-02, demo.up) | CI job config (`ci.yml` lanes) | Mix task (`demo.up --check`) | The fix lives in the lane's env + pre-warm step; the task behavior is fixed and inspected, not changed |
| Backlog #3 fix verification (REL-02, Accrue) | CI job config + Mix deps | Build (`obs-recompile.sh` full-tree compile) | Path-dep `.app` production is a Mix compile-order concern resolved in the lane |
| Seed-0 ordering guard (REL-03) | CI job config (nightly tier) | ExUnit runner (`mix test --seed 0`) | A new nightly-gated lane; the seed is an ExUnit runtime flag |
| App-env isolation helper (REL-04) | Test support (`test/support/`) | ExUnit `setup`/`on_exit` | Test-only helper; per-test capture/restore, never touches `lib/` |

## User Constraints

No `CONTEXT.md` exists for this phase — `/gsd-discuss-phase` was intentionally skipped. The authoritative decisions are the **ROADMAP Phase 92 success criteria**, **REQUIREMENTS REL-01..04**, and **`.planning/CI-HARDENING-BACKLOG.md`**. These are treated as locked decisions.

### Locked Decisions (from ROADMAP + REQUIREMENTS + BACKLOG)

- **REL-01**: Measure real-vs-flaky failure rate via the OBS tooling; completed-run `main` `ci-gate` failure rate **under 10%**, corroborated by **≥ 5 consecutive green** `main` `ci-gate` runs. Must be automated / log-assertable (shift-left, 0 human UAT).
- **REL-02**: Backlog **#2** (`demo.up --check` dev-DB hang) and **#3** (Accrue path-dep compile) each **verified fixed on CI** OR **explicitly quarantined behind a linked tracking GitHub issue** — no silent CI-only reproduction gaps left undocumented.
- **REL-03**: A **nightly `--seed 0`** ordering run guards against test-ordering coupling going forward; the **random ExUnit seed is kept for all other runs** (PR/push).
- **REL-04**: A **capture/restore `put_env` test helper** exists and is **adopted by the async-safe DataCase modules** from Phase 89, standardizing app-env isolation.

### Milestone-wide invariants (locked, apply to every phase)

- **Doc/config/CI/test-quality only. No `lib/` runtime behavior changes.** (Verified enforced by `git diff -- lib/` being empty in Phases 89/90/91.)
- Keep the pipeline standard: `actions/cache` + `schedule:`, no self-hosted runners, no bespoke cache servers.
- Keep the random ExUnit seed for PR/push (out-of-scope: "Pinned global ExUnit seed" — green-washes coupling).

### Deferred Ideas (OUT OF SCOPE — do not research/plan)

- Dialyzer (`DEF-DIALYZER`), ExCoveralls coverage (`DEF-COVERAGE`), promoting audits to blocking (`DEF-AUDIT-BLOCK`), moving partner lanes to nightly (`DEF-PARTNER-NIGHTLY`).
- Backlog **#4** (compile-once warm-recompile spike, CACHE-05) — owner-decided LOW-VALUE; execution-bound, not compile-bound. Not a REL requirement.
- `mix test --partitions N` sharding; `touch`-based mtime hacks; sharing `_build` into partner lanes; mass `async: true` conversion.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| REL-01 | Measure completed-run `main` `ci-gate` failure rate < 10% + ≥5 consecutive green, re-runnably | New `scripts/ci/reliability-report.sh` using `gh run list`/`gh run view` scoped to `--branch main --event push`, reading the **`ci-gate` job conclusion** (not the run conclusion). Live evidence already meets the bar (see Common Pitfalls / Code Examples). Parser unit-testable against a committed fixture (obs-summary precedent) |
| REL-02 | Verify-or-quarantine backlog #2 and #3 | Both root causes pinned this session (below). Both lanes **currently green on every push**. Recommend **verified-fixed** for both, tighten the two band-aids, and document the mechanism. `gh issue create` path documented if owner prefers quarantine |
| REL-03 | Nightly `--seed 0` ordering guard; random seed elsewhere | Phase 90 nightly tier lives in `ci.yml` (`resolve_tiers` → `run_nightly` gate → `nightly-gate` aggregate). Add a `test_seed_zero` lane gated on `run_nightly`, running `mix test --seed 0`; wire into `nightly-gate` needs + `aggregate-gate.sh` args + contract test |
| REL-04 | `put_env` capture/restore helper adopted by async DataCase modules | Canonical `Application.get_env` snapshot + `on_exit` restore/delete pattern already exists inline in `test/support/accrue/data_case.ex:38-47`. Extract to a shared helper. Only **1** `async: true` DataCase module (`policy_test.exs`) currently mutates global app-env unguarded — that is the adoption target |

## Standard Stack

No new packages. Everything below is already in the repo and verified present.

### Core (all pre-existing)
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| `gh` CLI | 2.95.0 `[VERIFIED: gh --version this session]` | Query run history + job conclusions for REL-01 | Already used by `obs-summary.sh`; project's canonical CI-log assertion tool |
| `jq` | present on ubuntu-latest + local | Parse `gh api`/`gh run view --json` output | Already used by `obs-summary.sh` timing renderer |
| ExUnit | Elixir 1.19 (CI matrix), 1.17 floor | Test runner; `--seed 0` for ordering guard | Standard Elixir test framework; `--seed 0` disables shuffle |
| `actions/cache` (pinned SHA `0057852`) | pinned | Lane caching | Already the milestone standard |
| `erlef/setup-beam` (pinned SHA `8251c48`) | pinned | Toolchain via `.tool-versions` | Phase 91 standard |
| bash `set -euo pipefail` | — | Re-runnable CI scripts | Matches `aggregate-gate.sh`/`sigra-proof.sh` conventions |

### Supporting patterns (pre-existing, to be reused)
| Artifact | Purpose | Reuse For |
|----------|---------|-----------|
| `scripts/ci/obs-summary.sh` | `gh api .../jobs` + `jq` + `$GITHUB_STEP_SUMMARY`, secret-hygiene | Template for `reliability-report.sh` |
| `scripts/ci/aggregate-gate.sh` | Reproduces gate pass/fail locally from lane-result env vars | REL-03 wires new lane token in; REL-01 report can classify similarly |
| `test/support/accrue/data_case.ex:38-47` | Inline get_env→put_env→on_exit restore/delete | Canonical body for REL-04 helper |
| `test/chimeway/ci_observability_contract_test.exs` | Parses `ci.yml` job blocks + runs bash scripts against fixtures | Template for REL-01 parser test + REL-03 lane-structure test |

### Installation
None. `# no external packages installed in this phase`.

## Package Legitimacy Audit

**Not applicable.** This phase installs **zero** external packages (npm/PyPI/Hex/crates). All work uses tools already present in the repo and CI image (`gh`, `jq`, bash, ExUnit, `actions/cache`, `setup-beam`). No `mix.exs`/`mix.lock` dependency changes are in scope (milestone invariant: config/CI/test-quality only).

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```
REL-01 measurement (new, re-runnable, log-assertable)
─────────────────────────────────────────────────────
  gh run list --workflow=ci.yml --branch main --event push --json ...
        │  (population: ONLY main-branch pushes; excludes dispatch/nightly/release-please)
        ▼
  for each run:  gh run view <id> --json jobs
        │
        ▼
  select job .name == "ci-gate"  →  .conclusion
        │
        ├── "success"                  → GREEN
        ├── "failure"                  → REAL FAILURE  (counts against rate)
        └── "cancelled" / "skipped"    → INFRA/SUPERSEDED (excluded from denominator)
        │
        ▼
  compute: failure_rate = real_failures / (completed − excluded)
           consecutive_green_streak (from most recent backwards)
        │
        ▼
  emit table → stdout + $GITHUB_STEP_SUMMARY (+ nonzero exit if rate ≥ 10% or streak < 5)
        │
        ▼
  parser is unit-tested offline against test/fixtures/ci/*run_list*.json  (Nyquist)


REL-03 nightly seed-0 (extends the Phase 90 tier machine)
─────────────────────────────────────────────────────────
  resolve_tiers ──run_nightly=true (schedule|dispatch)──► test_seed_zero (NEW)
                                                          │  mix test --seed 0
                                                          ▼
                                          nightly-gate  needs: [..., test_seed_zero]
                                                          │  aggregate-gate.sh ... TEST_SEED_ZERO
                                                          ▼
                                              one green/red nightly signal


REL-04 app-env isolation (test-only)
────────────────────────────────────
  Chimeway.TestSupport.EnvHelper.put_env_isolated(app, key, val)   (NEW, test/support/)
        │  snapshot = Application.fetch_env(app, key); Application.put_env(...)
        │  on_exit(restore snapshot | delete_env)
        ▼
  adopted by async:true DataCase modules that mutate app-env
  (target today: test/chimeway/policy_test.exs — :adapter mutation)
```

### Recommended Project Structure (additions only)
```
scripts/ci/
└── reliability-report.sh        # REL-01 (new): classify push-on-main ci-gate outcomes
test/support/
└── env_helper.ex                # REL-04 (new): Chimeway.TestSupport.EnvHelper capture/restore
test/fixtures/ci/
└── run_list_sample.json         # REL-01 (new): fixture for the parser unit test
mix.exs (aliases)
└── "ci.test.ordered": mix test --seed 0 --exclude ... (REL-03, optional alias)
.github/workflows/ci.yml
└── test_seed_zero job           # REL-03 (new): nightly-gated --seed 0 lane
.planning/
└── CI-RELIABILITY-REPORT.md     # REL-01 (new): committed snapshot of the measured rate + run links
```

### Pattern 1: `gh`-driven, log-assertable CI measurement (mirror `obs-summary.sh`)
**What:** A bash script that queries the GitHub REST/`gh` API, renders a markdown table, writes it to `$GITHUB_STEP_SUMMARY`, and (for REL-01) exits nonzero if the reliability bar is missed. Accept an `OBS_*_JSON`-style test-hook env var pointing at a fixture so the parser is unit-testable offline.
**When to use:** REL-01 report.
**Example:**
```bash
# Source pattern: scripts/ci/obs-summary.sh (this repo) — same gh/jq/$GITHUB_STEP_SUMMARY shape
# [CITED: scripts/ci/obs-summary.sh:92-118]
render_rows() {
  jq -r '.[] | [.databaseId, .conclusion] | @tsv'    # over gh run list --json output
}
# test hook: if RELIABILITY_RUNS_JSON set, read fixture instead of live gh call
if [ -n "${RELIABILITY_RUNS_JSON:-}" ]; then
  rows=$(render_rows <"$RELIABILITY_RUNS_JSON")
else
  rows=$(gh run list --workflow=ci.yml --branch main --event push --limit 30 --json databaseId,conclusion | render_rows)
fi
```

### Pattern 2: Scope the REL-01 population to the `ci-gate` *job* on push-to-main
**What:** The overall *run* conclusion is polluted (nightly-dispatch failures, `release-please--branches--main` bot-branch dispatch failures, `cancelled` supersessions). The trustworthy signal is the **`ci-gate` job's conclusion** on **`event=push`, `branch=main`** runs.
**When to use:** REL-01 denominator/numerator definition.
**Example (verified this session):**
```bash
# gh run view <id> --json jobs -q '.jobs[] | select(.name=="ci-gate") | .conclusion'
# Last 12 push-on-main runs → 11 "success", 1 run cancelled (ci-gate="failure" under a
# cancelled run) → exclude cancelled → 11/11 completed green, 11-run green streak.
```

### Pattern 3: Canonical Elixir capture/restore app-env helper (safe under `async: true`)
**What:** Snapshot the key with `Application.fetch_env/2`, set the test value, and register an `on_exit/1` that restores the snapshot or `delete_env`s if the key was absent. This is the exact pattern already living inline in `accrue/data_case.ex`.
**Important caveat:** `Application.put_env` mutates a **process-global** table. Even with per-test `on_exit` restore, two *concurrent* `async: true` tests in **different modules** that both mutate the **same key** can still race — `on_exit` bounds the mutation in time (per test) but not in space (across concurrently-running modules). The helper standardizes correctness *within a module's tests* and makes the mutation explicit/greppable; it does **not** make a module that mutates a shared global key safe to run `async: true` alongside another module mutating the same key. Adoption must therefore be paired with the judgment that the mutated key is not concurrently mutated elsewhere (see Pitfall 4).
**Example:**
```elixir
# Source: test/support/accrue/data_case.ex:38-47 (this repo) — the pattern to extract
# [CITED: test/support/accrue/data_case.ex]
defmodule Chimeway.TestSupport.EnvHelper do
  @moduledoc false
  import ExUnit.Callbacks, only: [on_exit: 1]

  @doc "Set app env for the duration of the test, restoring the prior value on exit."
  def put_env_isolated(app, key, value) do
    original = Application.fetch_env(app, key)   # {:ok, v} | :error
    Application.put_env(app, key, value)
    on_exit(fn ->
      case original do
        {:ok, v} -> Application.put_env(app, key, v)
        :error   -> Application.delete_env(app, key)
      end
    end)
    :ok
  end
end
```

### Anti-Patterns to Avoid
- **Using the run-level conclusion for REL-01.** It conflates nightly-dispatch and release-please-branch failures with `main` health. Always drill into the `ci-gate` job.
- **Counting `cancelled` runs as failures.** Concurrency supersession is infra noise, not a reliability defect. Exclude from the denominator (but count/print them for transparency).
- **Adding the seed-0 lane to `ci-gate` or the PR path.** REL-03 is explicitly nightly-only; the random seed must stay for PR/push. Adding it to `ci-gate` would also break the release_gate_contract's exact 14-lane assertion.
- **A global pinned seed.** Out-of-scope; green-washes coupling.
- **`Application.put_env` without `on_exit` restore in an `async: true` module.** This is exactly the latent hazard REL-04 addresses (`policy_test.exs`).
- **Quarantining a lane that is actually green.** REL-02's #2/#3 are green on every push; a tracking-issue quarantine would misrepresent the state. Prefer verified-fixed + band-aid tightening.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Query CI run history | A custom GitHub API HTTP client | `gh run list --json` / `gh run view --json` | Already authenticated in CI via `GH_TOKEN`; `obs-summary.sh` precedent |
| Reproduce gate pass/fail | New logic | `scripts/ci/aggregate-gate.sh` | Exists; already reproduces the exact gate loop locally |
| App-env snapshot/restore | Ad-hoc per-test `previous = get_env; put_env; on_exit` scattered everywhere | One `EnvHelper.put_env_isolated/3` | 239 `put_env` occurrences across `test/` — a single helper is the DRY fix REL-04 asks for |
| Disable test shuffle | Custom ordering harness | `mix test --seed 0` | ExUnit built-in; Phase 89 already used `--seed 0` for the CONC-04 proof |
| Consecutive-green proof | Manual run-page inspection | The re-runnable `reliability-report.sh` | Shift-left: assert against API output, not human eyes |

**Key insight:** Every capability this phase needs already has a blessed in-repo pattern (obs-summary, aggregate-gate, accrue data_case, --seed 0). The phase is composition + contract-guarding, not invention.

## Runtime State Inventory

This is a CI/config/test phase, not a rename/refactor/migration, so a full runtime-state inventory is not the primary lens. The one migration-shaped concern is the **CI reliability history itself**:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — no datastore keys renamed | None |
| Live service config | GitHub Actions run **history** is the "data" REL-01 reads (not in git). Run *pages* persist far longer than logs/artifacts (per CI-PERF-BASELINE note). | Commit the measured numbers + run permalinks into `.planning/CI-RELIABILITY-REPORT.md` so the signal survives log retention |
| OS-registered state | None | None |
| Secrets/env vars | `GH_TOKEN` (`github.token`) already granted `actions: read` on obs lanes; the REL-01 report job needs the same escalation | New report job (if run in CI) must declare `permissions: contents: read, actions: read` (D-08/D-09 pattern: job-level block REPLACES top-level, so re-declare both) |
| Build artifacts | Accrue `.app` (`_build/test/lib/accrue/ebin/accrue.app`) — the #3 subject | Verified produced on green runs by full-tree `mix deps.compile`; no stale-artifact action |

## Common Pitfalls

### Pitfall 1: REL-01 population contamination (the biggest trap)
**What goes wrong:** `gh run list --workflow=ci.yml` shows recent `failure` conclusions, tempting a "we're flaky" conclusion.
**Why it happens:** Those failures are **not** `main` pushes. Verified this session: the failing runs are `workflow_dispatch` on `release-please--branches--main` (SHA `c1e22e4d`, "Release gate contract" + Test lanes failing) and nightly-tier dispatches. Push-on-`main` `ci-gate` is 11/11 completed-green in the last window.
**How to avoid:** Filter `--branch main --event push` AND read the **`ci-gate` job** conclusion. Exclude `cancelled`. Document the exact `gh` query in the script.
**Warning signs:** A "failure rate" that moves when release PRs are open, or that counts `workflow_dispatch` runs.

### Pitfall 2: Backlog #2/#3 look "already fixed," so skipping the honest write-up
**What goes wrong:** Both lanes are green, so the phase declares victory without documenting *why*, leaving the exact "silent CI-only reproduction gap" REL-02 forbids.
**Why it happens:** The fixes are subtle (see State of the Art). The 300s timeout tag and the full-tree `deps.compile` both *look* like band-aids.
**How to avoid:** Record the pinned root causes (below), then either tighten (verified-fixed) or `gh issue create` (quarantine). Do not leave the interim `@tag timeout: 300_000` unexamined — the backlog explicitly says "reconsider afterward."
**Warning signs:** A SUMMARY that says "green, done" with no mechanism explanation.

### Pitfall 3: New nightly seed-0 lane breaks the contract tests
**What goes wrong:** Adding `test_seed_zero` to `nightly-gate` fails `release_gate_contract_test.exs:487` — it asserts nightly-gate needs is **exactly** `[resolve_tiers, nightly_cold_build, test, test_floor_1_17, verify_admin]` and passes **exactly four** tokens to `aggregate-gate.sh` (`:496-498`).
**Why it happens:** The contract intentionally pins nightly composition (TIER-04).
**How to avoid:** Update `release_gate_contract_test.exs` (nightly-gate needs + token list) in the **same** change. Decide whether `test_seed_zero` also joins `@build_lanes` in `ci_observability_contract_test.exs` — recommend **exempting** it (like `test_floor_1_17`) unless it carries the full obs cache+summary wiring, and documenting the exemption in the contract comment.
**Warning signs:** Contract suite red after the `ci.yml` edit.

### Pitfall 4: REL-04 helper adopted where it doesn't make async safe
**What goes wrong:** Assuming the helper makes any app-env-mutating module safe to flip to `async: true`.
**Why it happens:** `Application.put_env` is process-global; `on_exit` bounds mutation per-test-in-time, not across concurrently-running modules mutating the same key.
**How to avoid:** Adopt the helper in modules that are **already** `async: true` and mutate app-env (today: only `policy_test.exs`, which sets `:chimeway, :adapter`). Do **not** use REL-04 as license to flip the ~25 `async: false` app-env mutators (explicitly out-of-scope per REQUIREMENTS). Confirm the mutated key isn't concurrently mutated by another async module.
**Warning signs:** A plan task that flips an `async: false` mutator to `async: true` "because the helper makes it safe."

### Pitfall 5: `demo.up --check` env inheritance is load-bearing
**What goes wrong:** "Simplifying" the demo lane by removing the job-level `DATABASE_URL` or the pre-warm `:dev` build step reintroduces the hang.
**Why it happens:** The fix depends on `System.cmd` inheriting `DATABASE_URL` into the `:dev` subprocess (below) AND the pre-warmed `:dev` build. Both are load-bearing.
**How to avoid:** Treat both as part of the verified fix; document them. Only *tighten* the timeout tag after confirming warm-compile timing.

## Code Examples

### REL-01: the exact live query proving the bar is met (verified this session)
```bash
# [VERIFIED: run this session against szTheory/chimeway]
# Population = push-on-main; signal = ci-gate JOB conclusion (not run conclusion)
for rid in $(gh run list --workflow=ci.yml --branch main --event push --limit 12 \
               --json databaseId -q '.[].databaseId'); do
  gate=$(gh run view "$rid" --json jobs -q '.jobs[]|select(.name=="ci-gate")|.conclusion')
  echo "$rid ci-gate=$gate"
done
# Result: 11× success, 1× failure-under-a-cancelled-run (30502247481, superseded).
#   completed-green = 11/11 (excluding cancelled) → 0% failure; 11-run green streak.
#   Bar: <10% failure AND ≥5 consecutive green → ALREADY MET; script makes it re-runnable.
```

### REL-03: nightly-only seed-0 lane (shape)
```yaml
# [CITED: .github/workflows/ci.yml — mirror test_floor_1_17's nightly gating]
  test_seed_zero:
    name: Test ordering guard (--seed 0)
    runs-on: ubuntu-latest
    needs: [resolve_tiers]
    if: needs.resolve_tiers.outputs.run_nightly == 'true'
    services: { postgres: { image: postgres:15, ... } }
    env: { MIX_ENV: test, DATABASE_URL: postgres://postgres:postgres@localhost/chimeway_test }
    steps:
      - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5
      - uses: erlef/setup-beam@8251c48667b97e88a0a24ec512f5b72a039fcea7
        with: { version-file: .tool-versions, version-type: strict }
      # ... deps.get, compile, ecto.create/migrate ...
      - run: mix test --seed 0 --exclude mailglass --exclude accrue --exclude threadline --exclude sigra --warnings-as-errors
  # then: add TEST_SEED_ZERO to nightly-gate needs + aggregate-gate.sh args
  #       + update release_gate_contract_test.exs nightly-gate assertion
```

### REL-04: adoption at the one current async hazard
```elixir
# test/chimeway/policy_test.exs is `use Chimeway.DataCase, async: true`
# and calls Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test) unguarded
# (lines 248, 279). Replace with the helper:
# [CITED: test/chimeway/policy_test.exs:248]
Chimeway.TestSupport.EnvHelper.put_env_isolated(:chimeway, :adapter, Chimeway.Adapters.Test)
```

## State of the Art — pinned root causes for REL-02 (the key research deliverable)

### Backlog #2 — `demo.up --check` "dev-DB hang" → **verified-fixed** (two load-bearing mechanisms)
The original backlog hypothesis ("`:dev` needs the dev DB which CI never provisions → connection-retry hang") and the test-file comment ("cold-compiles `:dev` inside the 60s default timeout → slow-not-hung") *both* had a piece of the truth. Pinned this session:

1. **`demo.up --check` boots the app in `:dev`** — it **skips `ecto.create`** but still runs `ecto.migrate` + `app.start` + `demo.seed`, all of which need a live Repo. `[CITED: lib/mix/tasks/demo.up.ex:20-30, 84-107]`
2. **Root `config/dev.exs` selects the DB by `DATABASE_URL`:** if set → `url: DATABASE_URL`; else → `database: "chimeway_dev"`. `[CITED: config/dev.exs:4-20]`
3. **`System.cmd(... env: [{"MIX_ENV","dev"}, ...])` inherits the parent environment** and merges the given entries — it does **not** clear `DATABASE_URL`. The demo lanes set job-level `DATABASE_URL=…/chimeway_test`, so the `:dev` subprocess connects to the **already-created `chimeway_test`** DB, not the never-provisioned `chimeway_dev`. `[CITED: examples/chimeway_demo_host/test/mix/tasks/demo_up_test.exs:14-24]` → **no missing-DB hang.**
4. **The `Warm :dev build for JOUR-05` step** pre-compiles the `:dev` build outside the test, so the readiness check runs warm — removing the >60s cold-compile that blew the default ExUnit timeout. `[CITED: .github/workflows/ci.yml:372-378, 512-518]`

**Verdict:** genuinely fixed; green on every push (`verify_example` + `verify_journeys` success on run `30558617430`, verified). **Recommended REL-02 action:** mark verified-fixed, document mechanisms 1–4, and **tighten/remove the interim `@tag timeout: 300_000`** now that compile is pre-warmed (confirm by a run with a smaller timeout, e.g. 120s). Note the `DATABASE_URL` inheritance is load-bearing (Pitfall 5).

### Backlog #3 — Accrue path-dep `.app` missing → **verified-fixed** (full-tree compile order)
- **Original failure:** `mix ecto.create`/`mix test --only accrue` runs Mix's dependency-completeness check, which requires `_build/test/lib/accrue/ebin/accrue.app`. Accrue is a **path dep** on CI (`ACCRUE_PATH=$WORKSPACE/accrue/accrue/accrue`, a package nested one level inside the `szTheory/accrue` monorepo checkout at `accrue/accrue`), declared `optional: true, runtime: false`. `[CITED: .github/workflows/ci.yml:629-635, mix.exs:172-176]`
- **Why `deps.compile accrue --force` in isolation failed (per backlog):** the accrue monorepo package needs *its own* deps (ecto, etc.) compiled first; compiling accrue alone can't satisfy them.
- **The working fix:** `scripts/ci/obs-recompile.sh` runs a **full-tree `mix deps.compile`** (no target) then `mix compile` **before** `ecto.create`, compiling the whole graph in dependency order so `accrue.app` is produced. The `verify.accrue` alias also leads with `deps.compile`. `[CITED: scripts/ci/obs-recompile.sh:32-35, mix.exs:136-139]`
- **Contrast with the passing `verify_sigra` lane:** Sigra's **root** proof sidesteps the deps-check entirely by invoking compiled beams directly (`elixir $(find _build/test/lib -name ebin -exec ...) ...`) instead of `mix test`. `[CITED: scripts/ci/sigra-proof.sh:run_root]` Accrue instead relies on full-tree `deps.compile` producing the `.app`. Both are valid; Accrue's is now green.

**Verdict:** genuinely fixed; `verify_accrue` success on run `30558617430`, verified. **Recommended REL-02 action:** mark verified-fixed, document the full-tree-compile mechanism and the nested-path `ACCRUE_PATH` layout, and (optional hardening) drop the now-redundant explicit `deps.compile` if `obs-recompile.sh` already covers it — verify by a push run.

**Deprecated/outdated:**
- The backlog's framing of #2 as a pure "dev DB hang" is superseded by the `DATABASE_URL`-inheritance finding above.
- The backlog's "`deps.compile accrue --force` still doesn't work" is superseded by the full-tree `deps.compile` that does.

### `gh issue create` quarantine path (only if owner prefers over verified-fixed)
```bash
# [CITED: .planning/CI-HARDENING-BACKLOG.md:59-62]
gh issue create --title "CI-only: demo.up --check dev-DB/timeout hardening" \
  --body "See .planning/CI-HARDENING-BACKLOG.md #2. Currently green via inherited DATABASE_URL + :dev pre-warm; tracking timeout-tag tightening." \
  --label ci
# Link the issue number back into CI-HARDENING-BACKLOG.md so no gap is undocumented.
```

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The `chimeway_test` DB reached by `demo.up --check` via inherited `DATABASE_URL` is sufficient for `ecto.migrate`+`app.start`+`demo.seed` (i.e. the fix is fully env-inheritance-driven) | State of the Art #2 | LOW — lane is green, confirming end-to-end success; the *why* is inferred from config+System.cmd semantics. Plan should confirm by a one-line log check (which DB the `:dev` Repo connected to) before removing the timeout tag |
| A2 | Only `policy_test.exs` is an `async: true` DataCase module that mutates global app-env (grep found exactly one) | REL-04 | LOW — grep was exhaustive over `test/`; if another exists it just adds one adoption site |
| A3 | The current 11/11 green window persists through the phase's own commits (docs/CI/test commits won't themselves flake) | REL-01 | LOW — the phase adds no `lib/` changes; the re-runnable script re-measures on demand |

## Open Questions (RESOLVED)

_All three resolved at planning (2026-07-30); each recommendation is implemented by a Phase 92 plan._

1. **Should the REL-01 report run *in* CI or as a maintainer-run script?**
   - What we know: `obs-summary.sh` runs in-lane; the reliability report reads *cross-run* history, which is awkward to run inside the very run it measures.
   - Recommendation: implement as a **maintainer-runnable script** (`scripts/ci/reliability-report.sh`) whose parser is unit-tested in CI against a fixture; commit the measured snapshot + run links to `.planning/CI-RELIABILITY-REPORT.md`. Optionally add a nightly informational job that prints the report to `$GITHUB_STEP_SUMMARY` (non-gating). This keeps the measurement re-runnable and log-assertable without making CI depend on its own history.
   - **RESOLVED:** adopted maintainer-runnable script + fixture-tested parser + committed snapshot → implemented in `92-02-PLAN.md`.

2. **Verified-fixed vs. quarantine for #2/#3?**
   - What we know: both green on every push; both root causes pinned.
   - Recommendation: **verified-fixed** for both, with the two band-aids tightened and mechanisms documented in the SUMMARY + backlog. Reserve `gh issue create` only if the owner wants the timeout-tag tightening tracked separately.
   - **RESOLVED:** verified-fixed (with quarantine+linked-issue as the documented data-driven fallback if a lane regresses) → implemented in `92-03-PLAN.md` Task 3.

3. **Does `test_seed_zero` join `@build_lanes` (full obs wiring) or stay exempt like `test_floor_1_17`?**
   - Recommendation: **exempt** (nightly, ordering-focused, not an OBS-parity target); document the exemption in `ci_observability_contract_test.exs`, matching the `test_floor_1_17`/`nightly_cold_build` precedent.
   - **RESOLVED:** exempt from `@build_lanes` (mirrors `test_floor_1_17`) → implemented in `92-03-PLAN.md` Task 1.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `gh` CLI | REL-01 measurement + REL-02 verification | ✓ | 2.95.0 | — |
| `jq` | REL-01 JSON parsing | ✓ (local + ubuntu-latest) | — | — |
| `GH_TOKEN` w/ `actions: read` | REL-01 in-CI job (if run in CI) | ✓ pattern exists | — | Run script locally with maintainer token |
| Postgres 15 service | REL-03 seed-0 lane | ✓ (every test lane uses it) | 15 | — |
| ExUnit `--seed 0` | REL-03 | ✓ built-in | Elixir 1.19 | — |

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** the in-CI reliability job (if chosen) needs a token with `actions: read`; fallback is maintainer-run.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir 1.19 CI matrix; 1.17 floor on push/nightly) |
| Config file | `config/test.exs` (pool sizing), `test/test_helper.exs` (`ExUnit.start()`) |
| Quick run command | `mix test test/chimeway/<file>.exs` |
| Full suite command | `mix ci.test` (excludes mailglass/accrue/threadline/sigra; `--warnings-as-errors`) |
| Bash-script tests | `System.cmd("bash", [script], env: [...])` against committed fixtures (obs-summary precedent) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| REL-01 | `reliability-report.sh` classifies success/failure/cancelled and computes rate+streak correctly | unit (bash-against-fixture) | `mix test test/chimeway/ci_reliability_contract_test.exs` | ❌ Wave 0 (new test + `test/fixtures/ci/run_list_sample.json`) |
| REL-01 | Live bar met: <10% failure, ≥5 consecutive green | integration (log-assert) | `scripts/ci/reliability-report.sh` exits 0 on live `main` history | ❌ Wave 0 (new script) |
| REL-02 | #2 lanes green on push | integration (log-assert) | `gh run view <push-run> --json jobs -q '...Example.../.conclusion == "success"'` | ✅ live CI |
| REL-02 | #3 lane green on push | integration (log-assert) | `gh run view <push-run> --json jobs -q '...Accrue.../.conclusion == "success"'` | ✅ live CI |
| REL-02 | If quarantined: tracking issue linked in backlog | doc-contract | grep backlog for `#<issue>` | N/A unless quarantine chosen |
| REL-03 | `test_seed_zero` exists, nightly-gated, runs `--seed 0`, in `nightly-gate` needs+tokens | contract (ci.yml parse) | `mix test test/chimeway/release_gate_contract_test.exs` (extended) | ⚠️ existing file, needs new assertions |
| REL-03 | Lane green on a real nightly dispatch | integration (log-assert) | `gh workflow run ci.yml -f run_nightly=true` then assert `test_seed_zero` success | ❌ Wave 0 (live proof) |
| REL-04 | `EnvHelper.put_env_isolated/3` restores prior value and deletes when absent | unit | `mix test test/chimeway/test_support/env_helper_test.exs` | ❌ Wave 0 (new test) |
| REL-04 | `policy_test.exs` (async) adopts the helper (no raw `put_env` in async DataCase modules) | contract (grep) | `mix test test/chimeway/ci_observability_contract_test.exs` (or new adoption contract) | ❌ Wave 0 (new assertion) |

### Sampling Rate
- **Per task commit:** the specific new/changed test file (`mix test <file>`), fast.
- **Per wave merge:** `mix ci.test` (full default suite, `--warnings-as-errors`).
- **Phase gate:** full `ci-gate` green on push + one nightly dispatch green (for REL-03) + `reliability-report.sh` exit 0, before `/gsd-verify-work`.

### Wave 0 Gaps
- [ ] `scripts/ci/reliability-report.sh` — REL-01 measurement (new)
- [ ] `test/fixtures/ci/run_list_sample.json` — fixture for the parser test (new)
- [ ] `test/chimeway/ci_reliability_contract_test.exs` — REL-01 parser unit test (new; mirror `ci_observability_contract_test.exs` bash-against-fixture harness)
- [ ] `test/support/env_helper.ex` + `test/chimeway/test_support/env_helper_test.exs` — REL-04 helper + test (new)
- [ ] Extend `test/chimeway/release_gate_contract_test.exs` — nightly-gate needs/tokens for `test_seed_zero`
- [ ] Extend `ci_observability_contract_test.exs` — `test_seed_zero` exemption note + async-DataCase-no-raw-put_env adoption assertion
- [ ] `.planning/CI-RELIABILITY-REPORT.md` — committed measured snapshot + run permalinks (durability)

## Security Domain

`security_enforcement` is not disabled in config, so this section is included. This is a CI/test phase; most ASVS categories are N/A. The relevant controls:

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V5 Input Validation | yes | `reliability-report.sh` parses `gh --json` output with `jq` (structured), not fragile string scraping; treat run titles/branch names as untrusted display strings (never `eval`) |
| V6 Cryptography | no | — |
| V7 Errors/Logging & secret hygiene | yes | Job summaries are **world-readable on a public repo**. The REL-01 report must mirror `obs-summary.sh`'s hygiene: emit only run ids, conclusions, counts, and permalinks — **never** raw env, `GH_TOKEN`, or `DATABASE_URL`. The existing obs-summary secret-hygiene contract test is the model |
| V14 Configuration | yes | New in-CI job (if any) declares least-privilege `permissions: contents: read` + `actions: read` only (D-07/D-08), re-declaring both because a job-level block replaces the top-level default |

### Known Threat Patterns for {bash CI scripts + gh API}
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Secret leakage into world-readable job summary | Information Disclosure | Whitelist-emit fields only; secret-hygiene contract test (obs-summary precedent) |
| Untrusted run/branch titles injected into shell | Tampering | Use `jq`/`--json -q`; never interpolate API strings into `eval`/unquoted expansions |
| Over-broad token scope | Elevation of Privilege | `actions: read` only; no `contents: write` |

## Sources

### Primary (HIGH confidence — verified in-repo / live this session)
- `.github/workflows/ci.yml` — all lanes, tiers, gates, nightly composition, demo pre-warm steps, Accrue nested-path env
- `config/dev.exs`, `config/test.exs`, `examples/chimeway_demo_host/config/dev.exs` — DB selection by `DATABASE_URL`; `chimeway_dev` vs `chimeway_test`
- `lib/mix/tasks/demo.up.ex`, `examples/chimeway_demo_host/test/mix/tasks/demo_up_test.exs` — `--check` semantics + spawn env
- `scripts/ci/obs-summary.sh`, `obs-recompile.sh`, `aggregate-gate.sh`, `sigra-proof.sh` — reusable patterns
- `test/support/accrue/data_case.ex` — canonical capture/restore body for REL-04
- `test/chimeway/ci_observability_contract_test.exs`, `release_gate_contract_test.exs` — contract structure REL-03 must satisfy
- `mix.exs` (aliases + partner path-dep declarations)
- **Live CI (`gh`, this session):** `gh run list`/`gh run view` — 11/11 push-on-main `ci-gate` green window; failing runs isolated to `release-please--branches--main` dispatch + nightly; `verify_accrue`/`verify_example`/`verify_journeys` green on run `30558617430`
- `.planning/CI-HARDENING-BACKLOG.md`, `.planning/CI-PERF-BASELINE.md`, `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, phase 87/89 SUMMARYs

### Secondary (MEDIUM confidence)
- Elixir `System.cmd/3` env-merge semantics (inherits parent env, merges `:env` entries) — standard behavior, corroborated by the green demo lane. [ASSUMED-standard, cross-checked against observed CI behavior]

### Tertiary (LOW confidence)
- None material — every load-bearing claim was verified against repo or live CI.

## Metadata

**Confidence breakdown:**
- REL-01 measurement mechanism: HIGH — exact `gh` query designed and run against live data; bar already met.
- REL-02 root causes: HIGH — pinned against code + config + live green lanes (one inferred mechanism flagged A1, LOW risk).
- REL-03 wiring: HIGH — nightly tier + contract assertions read directly from `ci.yml` and the contract test.
- REL-04 helper + adoption sizing: HIGH — canonical pattern already in-repo; exhaustive grep found exactly one async adoption target.

**Research date:** 2026-07-30
**Valid until:** 2026-08-29 (30 days — stable CI/config domain; re-verify the live green window if the phase spans a release-please cycle or new flakes appear)
