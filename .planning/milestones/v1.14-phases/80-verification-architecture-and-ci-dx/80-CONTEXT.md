# Phase 80: Verification Architecture and CI/DX - Context

**Gathered:** 2026-07-03 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Restructure the verification surface so contributor PRs get a fast, always-running required
aggregate (`pr-gate`) while the full release matrix (`ci-gate`) remains the source of truth for
release, publish, automerge, and recovery. Eliminate the required-check pending trap, extend cache
coverage to nested packages / npm / Playwright, move complex inline CI fragments into locally
reproducible scripts or Mix tasks, and align contributor/maintainer gate docs with the new topology.

**In scope:** CI job topology in `.github/workflows/ci.yml`; the `pr-gate`/`ci-gate` aggregate
split; anti-pending-trap structure; cache steps; extraction of CI *verification* fragments to
`scripts/ci/` and/or Mix tasks; `CONTRIBUTING.md`, `MAINTAINING.md`, release/gate docs, and
doc-contract updates. Requirements CI-01, CI-02, CI-03, CI-04, CI-05.

**Out of scope:** Rewriting the release/publish/automerge `github-script` polling JS (release-path
risk, not contributor-reproducible); changing what any `mix verify.*` lane actually asserts; adding
new ecosystem integrations or new test coverage beyond what topology/caching require; the GitHub
branch-protection setting change itself (documented here, applied by an operator).
</domain>

<decisions>
## Implementation Decisions

### Topology: pr-gate / ci-gate split (CI-01, CI-02)

- **D-01:** Keep a **single `.github/workflows/ci.yml`** and express the split as **two aggregate
  jobs**, not a second workflow file. Rationale: avoids duplicating setup/cache boilerplate and
  reusable-workflow indirection; the aggregate pattern already exists (`ci.yml:610-645`). Least
  surprise, one source of truth.
- **D-02:** Add a new **`pr-gate`** aggregate job that `needs` **only the fast lanes**: `lint`,
  `test`, `verify_gates`, `verify_docs`. These have no sibling checkouts, no npm/Playwright, and no
  demo-host compile — the genuine fast correctness signal a contributor needs. `pr-gate` becomes the
  **required check on contributor PRs**.
- **D-03:** Keep **`ci-gate`** aggregating **all** lanes and make it **main-push + `workflow_dispatch`
  only** (`if: github.event_name != 'pull_request'`). It stays the source of truth that
  `release.yml`, `publish-hex.yml` (recovery), and `release-pr-automerge.yml` already poll by name.
  Release PRs (opened by Release Please) receive `ci-gate` via `workflow_dispatch`, consistent with
  the existing `ci.yml:9` comment — so removing `ci-gate` from the `pull_request` event does not
  break the release path.
- **D-04:** Gate the **heavy/ecosystem lanes off the `pull_request` event** — `verify_example`,
  `verify_runtime_prefix`, `verify_journeys`, `verify_mailglass`, `verify_accrue`, `verify_inbox`,
  `verify_threadline`, `verify_sigra`, `verify_admin`, and `install_golden_contract` run on
  push-to-main + `workflow_dispatch` only. Fast lanes run on `pull_request` + `push` +
  `workflow_dispatch` (they must be available for the `ci-gate` dispatch on release).
  **[Recommended default — chosen in user's absence; reversible.]** The alternative (targeted
  per-path heavy lanes on PRs) was considered and set aside to keep PRs fast/cheap and minimize the
  path-filter surface that CI-03 warns about. Flag for user confirmation before execution if
  pre-merge integration coverage is a priority.
- **D-05:** `ci-gate` must remain **at least as strict** as today. Fold **`install_golden_contract`
  into `ci-gate`'s `needs`** (it currently floats outside the aggregate at `ci.yml:544`/`613`, so
  its failure does not fail ci-gate — a strictness gap). It stays path-conditional via the
  detect-step pattern, so folding it in cannot introduce a pending/skip hazard on the aggregate.

### Anti-pending-trap structure (CI-03)

- **D-06:** The structural guarantee is **exactly one required aggregate per context that always
  runs** (`pr-gate` for PRs), with individual lanes **never independently required** in branch
  protection. No lane that feeds a required aggregate may use a job-level `paths:`/`paths-ignore:`
  filter.
- **D-07:** For any path-conditional lane, reuse the repo's existing **"job always runs, steps are
  `if:`-conditional"** detect pattern (`ci.yml:569-608`, `install_golden_contract`) so the job
  always reports a concrete success/failure and never leaves a required check pending.
- **D-08:** The PR-required-check swap (branch protection must require **`pr-gate`, not `ci-gate`**,
  for PRs into `main`) is an **operator action in GitHub settings**, outside the repo. The plan
  documents it in `MAINTAINING.md` as an explicit execution-time step; code cannot enforce it.

### Local reproducibility (CI-04)

- **D-09:** Extract the **CI verification** inline fragments to committed, locally-runnable
  artifacts: the `install_golden` git-diff **detect** logic (`ci.yml:572-583`), the
  **`pr-gate`/`ci-gate` result-aggregation** bash (`ci.yml:631-645`), and the bespoke **Sigra
  proof-runner** invocation (`ci.yml:478-499`). Prefer **`scripts/ci/*.sh`** for git/CI-glue logic
  and **Mix tasks** where the logic is Elixir-shaped (matching the existing `mix verify.*` / `mix
  ci.*` convention). CI YAML then calls the script/task; the same command runs locally.
  **[Recommended default — chosen in user's absence; reversible.]**
- **D-10:** **Do NOT** rewrite the large `github-script` polling blocks in `release.yml`,
  `publish-hex.yml`, or `release-pr-automerge.yml`. That is release orchestration bound to the
  Actions/GitHub-API context, is not contributor-reproducible, and touching it risks the release
  path CI-02 requires preserving. Explicitly deferred (see Deferred Ideas).

### Cache coverage (CI-05)

- **D-11:** Add caches for the three uncovered cost centers, keyed so stale caches cannot mask
  dependency drift ("without hiding failures"):
  1. **Nested mix projects** — `chimeway_admin`, `chimeway_inbox`, `examples/chimeway_demo_host`
     each cache their own `deps`/`_build` keyed on that project's `mix.lock` (today run uncached via
     `cd … && mix deps.get` in the `verify.admin` / `verify.inbox` / `verify.example` aliases).
  2. **npm** — `verify_admin` runs `npm ci` uncached (`ci.yml:525-542`); add npm/`~/.npm` caching
     keyed on the lockfile.
  3. **Playwright browsers** — cache `~/.cache/ms-playwright` keyed on the Playwright version so
     `npx playwright install` stops re-downloading Chromium every run.
- **D-12:** Do not cache test results or compiled test artifacts in a way that could skip
  recompilation of changed code; keep `_build` caches keyed on lockfiles only (pre-existing choice)
  so changed app code still recompiles.

### Docs & contract alignment

- **D-13:** Update `CONTRIBUTING.md` (local `mix ci` ≈ the fast `pr-gate` story) and `MAINTAINING.md`
  (`ci-gate` remains the release/publish/automerge/**recovery** source of truth; document the
  `pr-gate`-vs-`ci-gate` split and the branch-protection required-check swap from D-08).
- **D-14:** Lock the new topology language with an **extended doc-contract test** rather than a new
  file — this project treats docs/CI truth as executable ExUnit contracts (Phase 79 `D-09`
  precedent). Expect `test/chimeway/release_gate_contract_test.exs` to need updating if it asserts
  the current lane structure; keep it at least as strict.

### Claude's Discretion

Downstream agents may choose the exact `if:` guard expressions, script/task file names and split,
cache key/restore-key strings, and the specific asserted doc-contract markers — provided the
topology in D-01–D-05, the anti-pending rule in D-06/D-07, and the "at least as strict" constraint
in D-05/D-14 hold, and the release-path JS in D-10 stays untouched.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/ROADMAP.md` — Phase 80 goal and success criteria
- `.planning/REQUIREMENTS.md` — CI-01, CI-02, CI-03, CI-04, CI-05
- `.planning/METHODOLOGY.md` — decisive one-shot / low-escalation / least-surprise DX lenses
- `.github/workflows/ci.yml` — the 13 lanes + `ci-gate` aggregate being restructured
- `.github/workflows/release.yml` — polls `ci-gate` on release SHA (do not weaken)
- `.github/workflows/publish-hex.yml` — "Publish Hex Recovery"; polls `ci-gate` (CI-02 recovery role)
- `.github/workflows/release-pr-automerge.yml` — automerge waits on `ci-gate`
- `mix.exs` — `aliases/0`: `ci.*` and `verify.*` lane definitions
- `CONTRIBUTING.md` — contributor pre-merge gate language
- `MAINTAINING.md` — maintainer release/recovery + verify.* command map
- `test/chimeway/release_gate_contract_test.exs` — release-gate ExUnit contract (may assert lanes)
- `test/chimeway/doc_contract_test.exs` — doc-contract pattern to extend (Phase 79 precedent)
- `.planning/phases/79-front-door-and-docs-ia/79-CONTEXT.md` — doc-as-executable-contract precedent
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Aggregate-gate pattern** (`ci.yml:610-645`): `ci-gate` `needs: [...]` all lanes, `if: always()`,
  bash loops over `needs.<lane>.result` and fails on any non-`success`. `pr-gate` reuses this shape
  over the fast subset.
- **Detect-then-conditional-steps pattern** (`ci.yml:569-608`, `install_golden_contract`): job runs
  always; a `detect` step sets `run=true/false` from a `git diff --name-only` path regex; subsequent
  steps are `if: steps.detect.outputs.run == 'true'`. This is the CI-03 anti-pending-trap primitive.
- **Per-lane cache blocks**: every job caches `deps`/`_build` keyed on `${{ runner.os }}-mix-<lane>-
  ${{ hashFiles('**/mix.lock') }}` — the template for adding nested/npm/Playwright caches.
- **`mix verify.*` / `mix ci.*` alias convention** (`mix.exs`): the established home for local-first
  verification logic; new extracted Mix tasks should follow it.

### Established Patterns
- Docs/CI truth is enforced as **executable ExUnit contracts** (`doc_contract_test.exs`,
  `release_gate_contract_test.exs`), not prose — new topology must be lockable the same way.
- `workflow_dispatch` is the release-PR CI trigger because bot pushes skip `pull_request` CI
  (`ci.yml:9`) — the reason `ci-gate` can be `pull_request`-exempt without breaking release.
- Sibling ecosystem repos (accrue/threadline/sigra) are pinned by SHA and checked out per-lane;
  their lanes are the expensive part of the matrix.

### Integration Points
- Branch protection required-checks (GitHub settings, external) — must be swapped `ci-gate` →
  `pr-gate` for PRs (D-08).
- `release.yml` / `publish-hex.yml` / `release-pr-automerge.yml` poll `ci-gate` **by job name** —
  renaming `ci-gate` would break all three; keep the name stable.
- Nested packages: `chimeway_admin/`, `chimeway_inbox/`, `examples/chimeway_demo_host/` each have
  their own `mix.lock` and are compiled inside the heavy verify lanes.
- `package.json` + `test/browser/admin_smoke.spec.ts` — Playwright surface for the npm/browser cache.
</code_context>

<specifics>
## Specific Ideas

- Fast pr-gate set is exactly `{lint, test, verify_gates, verify_docs}`; everything else is
  "release matrix" behind `ci-gate`.
- Keep the `ci-gate` **job name** literally `ci-gate` (three workflows poll it by name).
- New scripts under `scripts/ci/` (no `scripts/` dir exists yet — this phase creates it).
</specifics>

<deferred>
## Deferred Ideas

- **Extracting the release/publish/automerge `github-script` polling JS** into reusable modules
  (D-10) — higher-risk release-path refactor; its own future decision, not Phase 80.
- **Targeted per-path heavy lanes on PRs** — the alternative to D-04; revisit if post-merge-only
  regression detection proves too coarse.
- **Reducing OTP/Elixir matrix breadth on PRs** (`test` runs OTP 26 + 27) — a further pr-gate speed
  lever, not required by CI-01; note but do not act unless the planner finds pr-gate still slow.

### Reviewed Todos (not folded)
None — `todo.match-phase 80` returned zero matches.
</deferred>
</content>
</invoke>
