# Phase 80: Verification Architecture and CI/DX - Research

**Researched:** 2026-07-03
**Domain:** GitHub Actions CI topology (required-check safety, aggregate gates, caching), Elixir `mix` alias extraction, doc-as-executable-contract (ExUnit)
**Confidence:** HIGH (topology, line refs, contract tests, caching all ground-truthed against the repo; GitHub semantics cross-checked with official docs)

## Summary

This is a CI-restructuring phase with locked decisions (D-01–D-14) already carrying exact `ci.yml` line references. Research **confirms every cited line number is accurate** against the current `.github/workflows/ci.yml` (13 lane jobs + a floating `install_golden_contract` + the `ci-gate` aggregate at 610-645). The plan's job is faithful execution plus three correctness details the planner must not get wrong:

1. **D-03 and D-08 are inseparable and must ship atomically.** The moment `ci-gate` gains `if: github.event_name != 'pull_request'`, it becomes a *skipped* job on PRs. If branch protection still requires `ci-gate` for PRs, **every PR sticks in "Expected — Waiting for status to be reported" forever** — the exact pending trap CI-03 exists to prevent. The branch-protection swap to `pr-gate` (D-08, operator action) is therefore a hard precondition, not a follow-up. `[VERIFIED: GitHub Docs troubleshooting-required-status-checks]`

2. **The `release_gate_contract_test.exs` contract actively asserts the OLD topology and will fail on the new one.** Two tests must be inverted/updated (see Doc-Contract Mechanics): `ci-gate aggregates 13 required lanes` (becomes 14 after folding `install_golden_contract`) and `install_golden_contract … stays outside ci-gate` (line 222 `refute` must become `assert`). This is the D-14 "at least as strict" lock — updating these tests is not optional cleanup, it is the phase's verification surface.

3. **`npm ci` and `npx playwright install` live inside the `mix verify.admin` alias (mix.exs:158-160), not in `ci.yml` directly.** Caches (D-11) must be added as `actions/cache` / `setup-node cache:` steps in the `verify_admin` job *before* the `mix verify.admin` run step, keyed on the root `package-lock.json` (the only npm lockfile) and `@playwright/test 1.60.0`.

**Primary recommendation:** Implement the two-aggregate split (`pr-gate` fast subset always-on-PR; `ci-gate` gains `install_golden_contract` in `needs` and an `event_name != 'pull_request'` guard), extract the three inline fragments to `scripts/ci/*.sh`, add per-lane nested/npm/Playwright caches, then update `release_gate_contract_test.exs` + `CONTRIBUTING.md` + `MAINTAINING.md` to lock the new topology. Document the D-08 branch-protection swap in `MAINTAINING.md` as an explicit operator step and mark it operator-attested in VALIDATION.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Fast PR correctness signal | CI (`pr-gate` aggregate) | Local `mix ci` | Contributor-facing required check; fast lanes only |
| Release/publish/recovery gate | CI (`ci-gate` aggregate) | release/publish/automerge workflows poll it by name | Source of truth; must stay ≥ current strictness |
| Anti-pending-trap guarantee | CI job structure (detect pattern) + branch protection | Operator (D-08 swap) | Job-level always-run + step-level `if:`; required check = `pr-gate` |
| Local reproducibility | `scripts/ci/*.sh` | `mix` aliases | Git/CI-glue is bash-shaped, not Elixir-shaped |
| Cache cost reduction | CI cache steps | — | Keyed on lockfiles so drift still recompiles |
| Topology truth enforcement | ExUnit contract (`release_gate_contract_test.exs`) | Doc prose (CONTRIBUTING/MAINTAINING) | Repo treats CI truth as executable contract |

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CI-01 | Fast always-running `pr-gate` required aggregate | Fast subset confirmed present as independent jobs (`lint`, `test`, `verify_gates`, `verify_docs`); all four have no sibling checkout, no npm/Playwright, no demo-host compile. Aggregate shape reusable from `ci-gate` (ci.yml:610-645). |
| CI-02 | `ci-gate` remains release/publish/automerge/recovery source of truth, ≥ current strictness | All three release workflows poll the check-run named `ci-gate` (release.yml:175, publish-hex.yml:84, release-pr-automerge.yml:79/136). Strictness gap found and fixable: `install_golden_contract` currently floats outside `ci-gate.needs` (D-05). |
| CI-03 | Required-check topology cannot strand pending checks | Root cause + fix confirmed against GitHub Docs: path-filter skips leave checks pending; the repo's detect-step pattern (ci.yml:569-608) makes jobs always report a conclusion. |
| CI-04 | Complex CI reproducible locally via scripts/Mix | Three inline fragments identified with exact line ranges; `scripts/` dir does not exist (this phase creates `scripts/ci/`); `mix.exs aliases/0` is the existing local-first convention. |
| CI-05 | Nested/demo/npm/Playwright caches without hiding failures | 4 mix.lock files, 1 npm lockfile (`package-lock.json`), Playwright 1.60.0 pinned; keying strategy defined so stale caches cannot mask drift. |
</phase_requirements>

## Ground-Truth: Current `ci.yml` Topology (line refs VERIFIED)

**Workflow triggers (ci.yml:3-9):** `push` to `main`, `pull_request` to `main`, `workflow_dispatch` (comment at line 9 explains dispatch is for release PRs whose bot pushes skip `pull_request` CI). `concurrency` with `cancel-in-progress: true` (11-13).

**14 jobs total** — 13 lane jobs + 1 aggregate:

| Job | Lines | Fast/Heavy | Sibling checkout / npm / demo-host | In `ci-gate.needs`? |
|-----|-------|-----------|-------------------------------------|---------------------|
| `lint` | 16-38 | **FAST** | no | yes |
| `verify_gates` | 40-61 | **FAST** | no | yes |
| `verify_docs` | 63-84 | **FAST** | no | yes |
| `test` (OTP 26+27 matrix) | 86-129 | **FAST** | postgres only | yes |
| `verify_example` | 131-169 | heavy | demo-host + admin + inbox | yes |
| `verify_runtime_prefix` | 171-209 | heavy | — | yes |
| `verify_journeys` | 211-249 | heavy | demo-host | yes |
| `verify_mailglass` | 251-289 | heavy | demo-host | yes |
| `verify_accrue` | 291-335 | heavy | szTheory/accrue + demo-host | yes |
| `verify_inbox` | 337-375 | heavy | inbox + demo-host | yes |
| `verify_threadline` | 377-421 | heavy | szTheory/threadline + demo-host | yes |
| `verify_sigra` | 423-499 | heavy | szTheory/sigra + demo-host + **bespoke proof runner (478-499)** | yes |
| `verify_admin` | 501-542 | heavy | setup-node (525) + demo-host + **npm/Playwright (in alias)** | yes |
| `install_golden_contract` | 544-608 | heavy, **detect-gated** | — | **NO — floats outside (the D-05 gap)** |
| `ci-gate` | 610-645 | aggregate | `needs:` 13 lanes (613), `if: always()` (614), bash loop (631-645) | — |

**Confirmed against CONTEXT.md citations — no drift:**
- D-01 aggregate `ci.yml:610-645` ✓
- D-05 `install_golden_contract` starts line 544; `ci-gate.needs` (line 613) does **not** list it ✓ (its failure cannot fail `ci-gate` today = the strictness gap)
- D-07 detect pattern: `detect` step 569-583, conditional steps `if: steps.detect.outputs.run == 'true'` through 608 ✓
- D-09 extract targets: git-diff detect 572-583 ✓, result-aggregation bash 631-645 ✓, Sigra proof-runner 478-499 ✓
- D-11 npm: `setup-node` at 525; the literal `npm ci` / `npx playwright install` are **inside `mix verify.admin` (mix.exs:158-160)**, invoked by the `mix verify.admin` step at ci.yml:542 — correction to the CONTEXT phrasing "ci.yml:525-542 runs npm ci uncached": npm ci is in the alias, cache steps go in the job around line 528-542.

## Release-Path Polling Contract (CI-02 — what must NOT change)

All three release workflows reference the aggregate **by the literal check-run name `ci-gate`** (the job's `name: ci-gate`, ci.yml:611). Renaming the job breaks all three: `[VERIFIED: grep across .github/workflows]`

- **release.yml:175** — `jobs.find((job) => job.name === 'ci-gate')`; polls until success on the release SHA. Also **dispatches `ci.yml` via `workflow_dispatch`** for release PRs: `gh workflow run ci.yml --ref release-please--branches--main` (line 119) and `createWorkflowDispatch({ workflow_id: 'ci.yml' })` on the tag (line 194-201).
- **publish-hex.yml:84** (recovery) — same `job.name === 'ci-gate'` find; gates recovery publish.
- **release-pr-automerge.yml** — triggered by `workflow_run` of workflow `CI` completed + branch `startsWith('release-please--')` (lines 9-10, 30-34); filters `check_runs[] | select(.name == "ci-gate")` (79, 136) and requires its `conclusion == success`.

**Why D-03 provably does not break release:** release PRs receive `ci-gate` via `workflow_dispatch` (event_name = `workflow_dispatch`), which satisfies `if: github.event_name != 'pull_request'`. The dispatch mechanism (release.yml:119, 194-201) is the reason `ci-gate` can be exempt from the `pull_request` event without starving the release path. **Constraints that must hold:** (a) keep job name literally `ci-gate`; (b) keep `ci-gate` runnable on `workflow_dispatch` and `push`; (c) keep `pr-gate`/other fast lanes runnable on `workflow_dispatch` too (they must be available when release dispatches CI so `ci-gate.needs` resolves).

## Standard Stack

No new packages. This phase edits YAML, bash scripts, `mix.exs`, Markdown, and one ExUnit test. Pinned action SHAs already in use (keep them):

| Action | Pinned SHA (in repo) | Purpose |
|--------|----------------------|---------|
| `actions/checkout` | `34e114876b0b11c390a56381ad16ebd13914f8d5` | checkout |
| `erlef/setup-beam` | `8251c48667b97e88a0a24ec512f5b72a039fcea7` | Elixir/OTP |
| `actions/cache` | `0057852bfaa89a56745cba8c7296529d2fc39830` | caching (reuse this SHA for new caches) |
| `actions/setup-node` | `49933ea5288caeca8642d1e84afbd3f7d6820020` | node 22 (verify_admin) |

**No `## Package Legitimacy Audit` needed** — this phase installs no external packages.

## Architecture Patterns

### Target Topology (data-flow)

```
                          ┌──────────── pull_request event ───────────┐
                          │                                           │
   fast lanes (always run on PR + push + dispatch):                   │
     lint ─┐                                                          │
     test ─┤                                                          │
   v_gates ┤──► pr-gate (needs = fast subset, if: always())  ◄── REQUIRED CHECK on PRs (D-08)
   v_docs ─┘                                                          │
                          └───────────────────────────────────────────┘

   push-to-main / workflow_dispatch event (NOT pull_request):
     fast lanes  ─┐
     heavy lanes  ┤  (verify_example … verify_admin, if: event != pull_request)
     install_golden_contract ┤  (detect-gated job, always reports a conclusion)
                  └──► ci-gate (needs = ALL 14, if: always() && event != pull_request)
                              ▲
                              └── polled by name by release.yml / publish-hex.yml / release-pr-automerge.yml
```

### Pattern 1: Aggregate gate (reuse ci.yml:610-645 shape)
**What:** A job with `needs: [<lanes>]`, `if: always()`, and a bash loop over `needs.<lane>.result` that exits non-zero on any non-`success`.
**When:** Both `pr-gate` (fast subset) and `ci-gate` (all 14).
**pr-gate skeleton:**
```yaml
pr-gate:
  name: pr-gate
  runs-on: ubuntu-latest
  needs: [lint, test, verify_gates, verify_docs]
  if: always()
  steps:
    - name: Verify fast PR lanes
      env:
        LINT: ${{ needs.lint.result }}
        TEST: ${{ needs.test.result }}
        VERIFY_GATES: ${{ needs.verify_gates.result }}
        VERIFY_DOCS: ${{ needs.verify_docs.result }}
      run: scripts/ci/aggregate-gate.sh LINT TEST VERIFY_GATES VERIFY_DOCS
```
**ci-gate change:** add `install_golden_contract` to `needs`, add its `INSTALL_GOLDEN: ${{ needs.install_golden_contract.result }}` env + loop entry, and set `if: always() && github.event_name != 'pull_request'`.

### Pattern 2: Detect-then-conditional-steps (the CI-03 anti-pending primitive, ci.yml:569-608)
**What:** Job always runs (no job-level `paths:`); a `detect` step sets `run=true/false`; every subsequent step is `if: steps.detect.outputs.run == 'true'`. A job whose steps all skip still reports **success** (never pending). `[VERIFIED: GitHub Docs — "if a job is skipped … it reports Success; path filters instead leave the check pending"]`
**When:** Any path-conditional lane that feeds a required aggregate. `install_golden_contract` already uses it; folding it into `ci-gate.needs` is safe because it reports `success` (not `skipped`) when steps skip.

### Anti-Patterns to Avoid
- **Job-level `paths:` / `paths-ignore:` on any lane feeding a required aggregate** (D-06). A path-filtered *job* leaves the required check pending forever. Use the detect pattern instead. `[VERIFIED: GitHub community Discussion #54877, #49124]`
- **Shipping D-03 without D-08.** `ci-gate` skipped-on-PR + still-required = permanent PR block.
- **Renaming `ci-gate`.** Breaks three release workflows that match by name.
- **Reformatting `ci-gate`'s `needs` to a multi-line YAML list.** The contract helper `extract_ci_gate_needs` parses `needs:\s*\[(.*?)\]` (inline bracket form). Keep `needs: [ ... ]` inline, or update the helper too.
- **A shared demo-host deps cache across lanes.** Different lanes resolve demo-host optional deps differently (accrue vs sigra vs threadline via `CHIMEWAY_SKIP_*` envs) — a shared key would let one lane's resolution mask another's. Key per-lane (see Caching).

## Local-Reproducibility Extraction (D-09)

`scripts/` does not exist — this phase creates `scripts/ci/`. All three targets are git/CI-glue bash, not Elixir-shaped → **`scripts/ci/*.sh`** (not Mix tasks). Rationale: the detect logic is `git diff`, the aggregate is over CI job results, the Sigra runner is a raw `elixir -pa … .exs` invocation outside `mix compile`.

| Target | Current location | Extract to | Local invocation |
|--------|------------------|-----------|------------------|
| Installer-change detect (git-diff regex) | ci.yml:572-583 | `scripts/ci/detect-installer-changes.sh` | `scripts/ci/detect-installer-changes.sh <base_ref>` → prints `run=true/false`; in CI append to `$GITHUB_OUTPUT` |
| Aggregate result check (bash loop) | ci.yml:631-645 | `scripts/ci/aggregate-gate.sh` | `aggregate-gate.sh LANE1 LANE2 …` reads each `$LANE` env, exits 1 on any non-`success` |
| Sigra proof runner | ci.yml:478-499 (two steps) | `scripts/ci/sigra-proof.sh` (root proof) + demo-host proof (one or two scripts — Claude's discretion) | `scripts/ci/sigra-proof.sh` with the same `CHIMEWAY_*` / `SIGRA_PATH` envs |

**CI then calls the script** (e.g. `run: scripts/ci/aggregate-gate.sh …`), so the identical command runs locally. Keep `set -euo pipefail` and preserve exact env-var contracts. `chmod +x` the scripts and reference as `scripts/ci/x.sh` (or `bash scripts/ci/x.sh` to avoid perms-bit dependence).

**Extraction fidelity note:** the detect regex (ci.yml:579) is long and load-bearing — copy it verbatim, including the `ci.yml`, `.formatter.exs`, `.credo.exs`, and `mix.exs` triggers, or installer-related changes will silently stop gating.

## Caching Specifics (D-11 / D-12)

**Lockfile inventory (VERIFIED):**
- mix.lock files (4): `./mix.lock` (already cached per-lane), `./chimeway_admin/mix.lock`, `./chimeway_inbox/mix.lock`, `./examples/chimeway_demo_host/mix.lock`.
- npm lockfile (1): `./package-lock.json` (root; 2201 bytes). **No `npm-shrinkwrap.json`.** The `smoke:admin` script and `@playwright/test: 1.60.0` devDep live in root `package.json`.
- Playwright: version `1.60.0`, browser cache dir `~/.cache/ms-playwright`.

### (a) Nested mix projects — cache per lane on that project's `mix.lock`
The nested projects are compiled via `cd <dir> && mix deps.get` inside heavy lanes (verify.example/admin/inbox/journeys/mailglass/accrue/threadline/sigra). Add `actions/cache` steps for the nested `deps`/`_build`:
```yaml
# in verify_admin, before `mix verify.admin`:
- uses: actions/cache@0057852bfaa89a56745cba8c7296529d2fc39830
  with:
    path: |
      chimeway_admin/deps
      chimeway_admin/_build
    key: ${{ runner.os }}-mix-nested-admin-${{ hashFiles('chimeway_admin/mix.lock') }}
    restore-keys: ${{ runner.os }}-mix-nested-admin-
```
Repeat for `chimeway_inbox/*` (in verify_inbox) and `examples/chimeway_demo_host/*` (**keyed per-lane** — include the lane slug: `…-demo-<lane>-${{ hashFiles('examples/chimeway_demo_host/mix.lock') }}` — so accrue/sigra/threadline resolutions don't cross-contaminate; D-12 "without hiding failures").

### (b) npm — prefer `setup-node` built-in cache
`setup-node` is already present in `verify_admin` (ci.yml:525). Add its built-in npm cache rather than a manual `actions/cache`:
```yaml
- uses: actions/setup-node@49933ea5288caeca8642d1e84afbd3f7d6820020
  with:
    node-version: "22"
    cache: 'npm'
    cache-dependency-path: package-lock.json
```
This caches `~/.npm`, keyed on the lockfile hash; `npm ci` (run later inside `mix verify.admin`) reuses it. `[CITED: docs.github.com/actions/setup-node caching]`

### (c) Playwright browsers — cache `~/.cache/ms-playwright`, key on the lockfile
Add before the `mix verify.admin` step (so browsers are present when the alias runs `npx playwright install`):
```yaml
- uses: actions/cache@0057852bfaa89a56745cba8c7296529d2fc39830
  id: playwright-cache
  with:
    path: ~/.cache/ms-playwright
    key: ${{ runner.os }}-playwright-${{ hashFiles('package-lock.json') }}
    restore-keys: ${{ runner.os }}-playwright-
```
Keying on `package-lock.json` invalidates whenever the pinned `@playwright/test` version changes — the recommended practice. `[CITED: playwrightsolutions.com, dev.to/jpoehnelt]` On a cache hit, `npx playwright install --with-deps chromium` (mix.exs:159) finds the browser already present and skips the download (it still runs `apt-get` OS deps — a smaller, unavoidable cost unless the install command is split; leave as-is per D-10 scope discipline).

**D-12 guard (do not hide failures):** all `_build`/`deps` caches key on `**/mix.lock` or the specific `mix.lock` only — never on source hashes or test artifacts — so changed app code still recompiles. Do not add `mix test` result caching.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| npm dependency cache | manual `actions/cache` for `~/.npm` | `setup-node` `cache: 'npm'` | Built-in, correct key, less YAML |
| "did installer files change?" | new bespoke logic | existing detect pattern (ci.yml:569-608) verbatim → script | Already correct + path-safe |
| Aggregate pass/fail | per-lane required checks in branch protection | one aggregate job per context | Individually-required lanes reintroduce the pending trap (D-06) |
| Topology enforcement | prose-only docs | extend `release_gate_contract_test.exs` | Repo convention: CI truth is an executable ExUnit contract |

**Key insight:** every "cheap-looking" custom addition here (a second workflow file, a path filter, a per-lane required check) reintroduces exactly the failure mode CI-03 exists to kill. The safe primitives already exist in the repo — reuse their shapes.

## Doc-Contract Mechanics (D-14) — exact assertions to update

`test/chimeway/release_gate_contract_test.exs` (644 lines) is the topology lock. **These will fail on the new topology and MUST be updated to stay "at least as strict":**

| Line(s) | Current assertion | Required change |
|---------|-------------------|-----------------|
| 19 | `@ci_gate_lanes` = 13 lanes | Add `install_golden_contract` → 14 lanes (folds into ci-gate) |
| 205-213 | `test "ci-gate aggregates 13 required lanes"` — `length(needs) == 13` | Update count to 14 and rename the test; each of the 14 must be in `needs` |
| 215-223 | `test "install_golden_contract … stays outside ci-gate"` — **line 222 `refute "install_golden_contract" in needs`** | **Invert to `assert "install_golden_contract" in needs`** (D-05 strictness increase); keep the `mix verify.install_golden` presence assertion |
| — (new) | none | Add: `pr-gate` job exists, `needs == [lint, test, verify_gates, verify_docs]`, and none of those four carries a job-level `paths:`/`paths-ignore:` (CI-03 lock) |
| — (new) | none | Add: `ci-gate` carries `github.event_name != 'pull_request'` guard and job name is literally `ci-gate` (CI-02 lock) |
| — (new) | none | Add: `scripts/ci/*.sh` exist and `ci.yml` references them (CI-04 lock) |

**Helper constraint:** `extract_ci_gate_needs` (632-644) uses `Regex.run(~r/ci-gate:.*?needs:\s*\[(.*?)\]/s, …)` — non-greedy from the literal `ci-gate:`. Adding `pr-gate` before `ci-gate` is safe (regex anchors on `ci-gate:`), **but keep `needs` in inline `[...]` form**. If you add a `pr-gate` needs-extraction test, write a sibling helper anchored on `pr-gate:`.

`test/chimeway/doc_contract_test.exs` (1733 lines): grep found **no CI-topology assertions** (its `pending_signals` at line 79 is about the journey guide, unrelated). The topology contract lives entirely in `release_gate_contract_test.exs`. Extend there, not in doc_contract_test.

**Docs to update (D-13):**
- `CONTRIBUTING.md` (CI Entrypoints table, lines ~44-47): add the `pr-gate` ≈ `mix ci` fast-feedback story.
- `MAINTAINING.md` (lines 12-13, 31, 80): document `ci-gate` as release/publish/automerge/**recovery** source of truth, the `pr-gate`-vs-`ci-gate` split, and **the branch-protection required-check swap (D-08) as an explicit operator step**. The "twelve local commands map to ci-gate lanes" note (line 80) may need adjustment if the plan changes lane membership.

## Runtime State Inventory

This phase touches CI config, scripts, docs, and one test — **not** a rename/data migration. The one out-of-repo state item is intentional and central:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — no datastore keys involved | none |
| Live service config | **GitHub branch-protection required-checks** for PRs into `main` currently require `ci-gate`; must be swapped to `pr-gate` (D-08). Lives in GitHub settings, not git. | **Operator action, execution-time, MUST accompany D-03.** Document in MAINTAINING.md; code cannot enforce. |
| OS-registered state | None | none |
| Secrets/env vars | `HEX_API_KEY` (release/recovery) — unchanged; `RELEASE_PLEASE_TOKEN` — unchanged. No new secrets. | none |
| Build artifacts | New `scripts/ci/` dir + `+x` bits on scripts | create dir, chmod, or invoke via `bash scripts/ci/x.sh` |

**Canonical question:** after `ci.yml` is edited, the branch-protection setting still requires the *old* check name. If not swapped, PRs stick. This is the single highest-risk coupling in the phase.

## Common Pitfalls

### Pitfall 1: D-03 without D-08 → permanent PR block
**What goes wrong:** `ci-gate` gains `if: event != pull_request`, so on PRs it's skipped; branch protection still requires `ci-gate` → PR shows "Expected — Waiting for status to be reported" indefinitely.
**Why:** A required check that is never reported (skipped/absent) blocks merge forever. `[VERIFIED: GitHub Docs]`
**How to avoid:** Treat D-08 (swap required check to `pr-gate`) as a hard precondition documented in MAINTAINING.md; the plan should sequence it and surface it in the completion report.
**Warning signs:** First PR after merge won't go green even though all jobs pass.

### Pitfall 2: Path filter on a required-feeding lane
**What goes wrong:** Adding `paths:` to skip a lane on unrelated PRs leaves its check pending.
**Why:** Path-filtered *jobs/workflows* leave checks pending, unlike step-level `if:` skips which report success. `[VERIFIED: GitHub community #54877]`
**How to avoid:** Use the detect-step pattern (D-07); never job-level `paths:` on a lane in `pr-gate`/`ci-gate` `needs` (D-06).

### Pitfall 3: Shared demo-host cache masking per-lane dep drift
**What goes wrong:** One cache for `examples/chimeway_demo_host/deps` reused across accrue/sigra/threadline lanes serves a resolution built under different `CHIMEWAY_SKIP_*` envs.
**Why:** Optional-dep resolution differs per lane; a shared key hides drift (violates CI-05 "without hiding failures").
**How to avoid:** Include the lane slug in the demo-host cache key.

### Pitfall 4: Renaming or reformatting `ci-gate`
**What goes wrong:** Renaming breaks 3 release workflows (name match); reformatting `needs` to multi-line breaks the contract-test regex.
**How to avoid:** Keep name `ci-gate` and inline `needs: [...]`.

### Pitfall 5: Extraction changes the git-diff detect regex
**What goes wrong:** Paraphrasing the installer-change regex silently narrows what gates the installer contract.
**How to avoid:** Copy ci.yml:579 verbatim into the script.

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| Single required `ci-gate` for both PRs and release | Split: `pr-gate` (PR-required, fast) + `ci-gate` (release source of truth) | Contributors get fast feedback; release confidence preserved |
| Path filters to skip lanes | Detect-step pattern (job always reports) | No pending trap; GitHub's documented required-check workaround |
| Manual `npm`/Playwright re-download | `setup-node cache:npm` + `~/.cache/ms-playwright` cache | ~40s/run saved; keyed on lockfile so drift recompiles |

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir/mix | run `release_gate_contract_test.exs` locally, `mix ci` | ✓ | 1.19.5 / OTP 28 (CI pins 1.17/27) | — |
| bash | new `scripts/ci/*.sh` | ✓ | GNU bash 5.2 | — |
| git | detect script | ✓ | 2.41.0 | — |
| node/npm | validate npm/Playwright cache locally | ✓ | node 22.14 / npm 11.1 | CI-only validation |

No blocking gaps. (Local Elixir is 1.19/OTP28 vs CI's 1.17/OTP27 — irrelevant for this phase's YAML/script/doc/contract edits; the contract test is pure file-reading assertions.)

## Validation Architecture

`workflow.nyquist_validation: true` — section required.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir 1.17 in CI) |
| Config file | none — standard `mix test` |
| Quick run command | `mix test test/chimeway/release_gate_contract_test.exs` |
| Full suite command | `mix ci` (lint + test) |

### Requirement → Validation Map (Nyquist Dimension 8)
| Req | Behavior | Validation type | Command / Method | Verifiable in code? |
|-----|----------|-----------------|------------------|---------------------|
| CI-01 | `pr-gate` exists, needs only fast subset, no path filter | ExUnit static | new assertions in `release_gate_contract_test.exs` | ✅ (structure) |
| CI-01 | `pr-gate` is the *required* PR check | Operator-attested | MAINTAINING.md step + GitHub settings screenshot | ❌ branch protection (D-08) |
| CI-02 | 3 workflows still poll `ci-gate` by name | ExUnit static | existing tests (release_gate_contract 243-269) kept green | ✅ |
| CI-02 | `ci-gate` strictness ↑ (`install_golden_contract` in needs) | ExUnit static | inverted line-222 assertion + 14-lane count | ✅ |
| CI-02 | `ci-gate` actually gates release on push/dispatch | CI-run behavioral | observe a `workflow_dispatch` CI run + release replay | ⚠️ CI-observable, not unit |
| CI-03 | no job-level `paths:` on required-feeding lanes; detect pattern used | ExUnit static | grep-style assertion over `ci.yml` | ✅ |
| CI-03 | required check never strands pending | Operator-attested | depends on D-08 swap + a real skipped-path PR | ❌ inherently branch-protection |
| CI-04 | `scripts/ci/*.sh` exist and `ci.yml` calls them | ExUnit static | `File.exists?` + `ci.yml` contains path | ✅ |
| CI-04 | scripts run locally | Behavioral smoke | run `scripts/ci/detect-installer-changes.sh main` locally | ⚠️ manual/CI smoke |
| CI-05 | cache steps for admin/inbox/demo mix.lock, npm, Playwright present + correctly keyed | ExUnit static | assert `ci.yml` contains the cache paths/keys | ✅ |
| D-08 | branch-protection required check = `pr-gate` | Operator-attested | manual GitHub settings change | ❌ non-code-verifiable |

**Summary:** CI-01/02/03/04/05 each have a **code-verifiable structural core** (extend `release_gate_contract_test.exs`) plus a **behavioral/operator tail** (the actual CI run and the D-08 branch-protection swap) that VALIDATION.md must record as CI-observed or operator-attested, not unit-tested.

## Security Domain

`security_enforcement` absent → treated enabled. This phase changes **no** app auth/crypto/input-handling code; classic ASVS categories (V2–V6) do not apply to the notification library here. Relevant surface is **CI supply-chain**:

| Pattern | STRIDE | Standard Mitigation | Status in repo |
|---------|--------|---------------------|----------------|
| Malicious action version | Tampering | Pin actions by full commit SHA | ✓ already pinned — reuse existing SHAs for new cache steps |
| Cache poisoning masking a bad dep | Tampering | Key caches on lockfile hashes only; never restore across trust boundaries | Enforced by D-11/D-12 keying rules above |
| Widening `workflow_dispatch` / token scope | Elevation | Keep existing `permissions:` blocks; don't touch release-path JS (D-10) | Out of scope by decision |

No new secrets, no new external network calls, no permission escalation. ASVS V-categories: **not applicable** (no user-facing auth/session/access-control/validation/crypto code changes).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `--with-deps` still re-runs apt-get on Playwright cache hit (only browser download is skipped) | Caching (c) | LOW — smaller-than-download cost; if wrong, cache saves even more |
| A2 | Splitting the Sigra proof into one vs two scripts is free (Claude's discretion) | Extraction | LOW — behavior identical if envs preserved |
| A3 | No other repo file cross-checks the Sigra integration ref (noticed MAINTAINING.md line lists sigra ref `b186f03…` while ci.yml pins `62ceb46…` — a pre-existing doc/CI drift) | Open Questions | LOW for phase 80 scope; flag only |

## Open Questions

1. **MAINTAINING.md ↔ ci.yml Sigra-ref drift.**
   - Known: MAINTAINING.md (sibling-checkout list) cites sigra ref `b186f03ccc5bbc9416f495df3e5dd0bec2f814a4`; `ci.yml:454` pins `62ceb46a38c4e617f6c06d874ecb12e1ab19d97c`.
   - Unclear: whether to fix opportunistically while editing MAINTAINING.md (D-13).
   - Recommendation: out of Phase 80's topology scope; note it, let the planner decide a one-line correction or defer.

2. **Does `pr-gate` also need a `workflow_dispatch`-availability note?**
   - Known: fast lanes run on all three events today; `pr-gate` inherits that.
   - Recommendation: no guard on `pr-gate` (harmless if it also runs on push/dispatch); only `ci-gate` gets the `!= pull_request` guard.

## Sources

### Primary (HIGH confidence)
- Repo files (ground-truthed this session): `.github/workflows/ci.yml`, `release.yml`, `publish-hex.yml`, `release-pr-automerge.yml`, `mix.exs` (aliases/0), `test/chimeway/release_gate_contract_test.exs`, `test/chimeway/doc_contract_test.exs`, `CONTRIBUTING.md`, `MAINTAINING.md`, `package.json`, `package-lock.json`, nested `mix.lock` files.
- [GitHub Docs — Troubleshooting required status checks](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/collaborating-on-repositories-with-code-quality-features/troubleshooting-required-status-checks)

### Secondary (MEDIUM confidence)
- [GitHub community Discussion #54877 — branch protections when actions use `paths-ignore`](https://github.com/orgs/community/discussions/54877)
- [GitHub community Discussion #49124 — required checks stuck "Waiting for status to be reported"](https://github.com/orgs/community/discussions/49124)
- [Caching Playwright browsers in GitHub Actions (playwrightsolutions.com)](https://playwrightsolutions.com/playwright-github-action-to-cache-the-browser-binaries/)
- [Caching Playwright Binaries in GitHub Actions — Justin Poehnelt (dev.to)](https://dev.to/jpoehnelt/caching-playwright-binaries-in-github-actions-2mfc)

## Metadata

**Confidence breakdown:**
- Topology / line refs: HIGH — every CONTEXT citation verified against the file this session.
- Release-path contract: HIGH — grep-confirmed name-based polling in all 3 workflows + dispatch mechanism.
- Contract-test impact: HIGH — exact failing assertions and helper regex read directly.
- Caching: HIGH (paths/lockfiles verified) / MEDIUM (best-practice keying cited from community + GitHub docs).
- GitHub pending-trap semantics: HIGH (official docs) / MEDIUM (edge behavior of skipped-vs-path from community threads).

**Research date:** 2026-07-03
**Valid until:** ~2026-08-03 (stable; GitHub Actions required-check semantics and `actions/cache`/`setup-node` behavior are slow-moving).
