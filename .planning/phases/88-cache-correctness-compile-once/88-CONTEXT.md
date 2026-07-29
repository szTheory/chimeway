# Phase 88: Cache Correctness & Compile-Once - Context

**Gathered:** 2026-07-28 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix the root-cause CI cache-key collision so `_build` actually warms across runs, standardize
cache keys on `MIX_ENV` + resolved OTP/Elixir + `mix.lock`, split the source `deps` cache from the
compiled `_build` cache, de-fragment the plain-hex lanes onto one shared `build-test` key, and
compile dependencies exactly once per run via a producer `build` job — collapsing the gated
~6.5 min `main` wall-clock toward under ~3 min.

**In scope:** `.github/workflows/ci.yml` job/cache/`needs:` structure, `scripts/ci/*.sh` cache
helpers, and the contract-test edits those structural changes force (`ci_observability_contract_test.exs`,
`release_gate_contract_test.exs`). CI/config/docs-only.

**Explicitly OUT of scope (later phases, do NOT fold in):**
- Test-lane `async: true` conversion, `pool_size`, `ci.test --warnings-as-errors` → Phase 89 (CONC-*).
- `schedule:` nightly tier, cold-build backstop, OTP-matrix reduction on the PR path, Playwright
  relocation → Phase 90 (TIER-*).
- `.tool-versions` as toolchain SSOT, `setup-beam version-file:`, dependabot, `permissions:`,
  `mix_audit`, CI↔release Elixir skew → Phase 91 (QUAL-*).
- **No runtime library behavior changes.** This phase touches CI config, shell helpers, and the
  CI-structure contract tests only.
</domain>

<decisions>
## Implementation Decisions

### Cache-key schema & env split (CACHE-01)
- **D-01:** Every plain-hex lane replaces its single `path: [deps, _build]` cache with **two**
  `actions/cache` steps: a source **`deps`** cache and a compiled **`build-test`** cache.
- **D-02:** Cache keys follow the schema `<role>-<os>-<elixir>-<otp>-${{ hashFiles('mix.lock') }}`,
  where `<role>` ∈ {`deps`, `build-test`, `build-dev`, and partner variants}.
- **D-03:** Resolved toolchain versions come from a newly-`id:`'d `setup-beam` step (add `id: beam`)
  via `${{ steps.beam.outputs.elixir-version }}` and `${{ steps.beam.outputs.otp-version }}`.
  (Research-confirmed against `erlef/setup-beam` `action.yml`; `erlang-version` is a README typo and
  does NOT exist — never use it. Safe fallback if the pinned SHA lacks these: the literal
  `"1.19"`/`"27"` strings already at `ci.yml:33-34`, which the `test` matrix key already proves.)
- **D-04:** Lock glob is the **root** `mix.lock`, NOT `**/mix.lock` — `**/mix.lock` currently globs
  partner/nested lockfiles (`ci.yml:278`, `:633`, `:888`) so the root key churns on unrelated bumps.

### Lane de-fragmentation & sharing (CACHE-02)
- **D-05:** All default-graph `:test` lanes use the **identical** `build-test-<os>-<elixir>-<otp>-<lock>`
  string so they collapse onto one warm cache entry (fixes the ~11-way fragmentation under 10 GB LRU).
- **D-06:** Move the `lint` lane to `MIX_ENV: test` so it joins `build-test` (credo is
  `only: [:dev, :test]` per `mix.exs:42`, so format/compile/credo run fine in `:test`).
- **D-07:** **`verify_docs` stays on `MIX_ENV: dev`** with its own env-scoped `build-dev` cache key —
  it does NOT join `build-test`. Reason: `ex_doc` is `only: :dev` (`mix.exs:41`), so `mix ci.docs`
  (`docs --warnings-as-errors`) would fail in `:test`. **This is a deliberate, user-confirmed
  divergence from CACHE-02's literal wording** ("docs shares build-test"); the requirement text is
  treated as imprecise. `mix.exs` / the dep graph is NOT modified to pull ex_doc into `:test`.
- **D-08:** Partner lanes (`verify_accrue`/`verify_threadline`/`verify_sigra`) keep **graph-scoped**
  keys (e.g. `build-test-accrue-…`) and never consume the shared `build-test` cache — they inject
  path-deps (`ACCRUE_PATH`/`THREADLINE_PATH`/`SIGRA_PATH`, `ci.yml:534/691/769`) that genuinely
  change the graph. `verify_mailglass`/`verify_inbox`/`verify_admin`/`verify_example`/`verify_journeys`
  join `build-test` for their **root** cache; their demo/nested caches stay on separate keys.

### Producer `build` job & consumer wiring (CACHE-04)
- **D-09:** Add one **`build` producer job**: checkout → `setup-beam` (id) → `mix deps.get` →
  `mix deps.compile` → `mix compile` in `MIX_ENV=test`, saving the `deps` + `build-test` caches with
  the **full `actions/cache`** action.
- **D-10:** Every default-graph consumer declares `needs: [build]` and uses **`actions/cache/restore`**
  (restore-only, `fail-on-cache-miss: true`) for the shared key — NOT the full `actions/cache`.
  Research-confirmed: restore-only is the documented producer/consumer pattern and avoids ~10×
  "Unable to reserve cache / Cache already exists" warnings + the reservation race; `fail-on-cache-miss:
  true` guards the vacuous-pass footgun (a missing producer cache fails loudly, not a silent cold build).
- **D-11:** **`build` is NOT added to the `needs:` arrays of `pr-gate` or `ci-gate`.** It stays a
  transitive dependency of the leaf lanes only. `release_gate_contract_test.exs` asserts `ci-gate`
  needs **exactly** 14 lanes (`:236`) and `pr-gate` **exactly** the 4-lane subset (`:256`); adding
  `build` breaks those assertions and risks renaming the required-check set ruleset 18486746 enforces
  on `main`. Safe because `aggregate-gate.sh:17` treats `skipped` as failure — a failed `build` skips
  consumers and the aggregate still fails (no vacuous pass).
- **D-12:** The `test` matrix OTP-26 leg (`ci.yml:170-172`) cannot consume an OTP-27 `build-test`, so
  it keeps an OTP-parameterized key and **self-caches** (no `needs: [build]`). `verify_docs` (`:dev`)
  self-caches `build-dev` and takes no `needs: [build]`.

### Warnings-as-errors on the critical path (CACHE-03)
- **D-13:** Add an explicit `- run: mix compile --warnings-as-errors` to `install_golden` **before**
  `mix ecto.create` (`ci.yml:990`), so the Phase-87 timing summary shows `ecto.create` as a fast
  DB-only step rather than a disguised ~135s compile. Do NOT bury the flag in shared
  `obs-recompile.sh` (that would wrongly apply it to all 14 lanes and perturb committed fixtures).
- **D-14:** **Required contract edit:** relax/remove the assertion in
  `ci_observability_contract_test.exs:248-256` that currently `refute`s `--warnings-as-errors` on all
  build lanes. That test was authored in Phase 87 to defer exactly this change and names CACHE-03 as
  the revisiting phase (`obs-recompile.sh:8-9`). Scope the relaxation to `install_golden` only; do not
  open the door to Phase 89's separate `ci.test --warnings-as-errors` (CONC-03).

### Proof of win (CACHE-05)
- **D-15:** Prove the win by run-link delta against `.planning/CI-PERF-BASELINE.md`: two consecutive
  warm `main` runs on an identical `mix.lock` must show near-zero dependency recompilation per the
  Phase-87 OBS probe, and warm `ci-gate` wall-clock under ~3 min. The "under ~3 min" target is a
  **warm** target; the cold path (new lock / dependabot PR) is not gated here (Phase 90 moves cold
  builds to nightly).

### Claude's Discretion
- Exact `restore-keys:` fallback prefixes per lane (decisive, reversible — planner picks least-surprising).
- Whether the producer job also emits a job-summary line via the existing OBS helpers (nice-to-have).
- Exact naming of partner graph-scoped keys, as long as they never collide with `build-test`.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/ROADMAP.md` — Phase 88 section (goal, CACHE-01..05 success criteria, dependency chain).
- `.planning/REQUIREMENTS.md` — CACHE-01..05 requirement text.
- `.planning/CI-PERF-BASELINE.md` — the four baseline facts + delta ledger + run permalink; the
  before/after CACHE-05 proof cites this.
- `.github/workflows/ci.yml` — primary edit target. Key line refs: `lint` (`:41`), `install_golden`
  (`:947` env, `:978` cache, `:990` ecto.create), `test` matrix (`:170-172`, `:199`), partner path-dep
  injection (`:534`/`:691`/`:769`), `pr-gate` needs (`:226`), `ci-gate` needs (`:1010`), setup-beam
  version literals (`:33-34`).
- `scripts/ci/obs-recompile.sh` — deps/app recompile probe; header comment (`:8-9`) defers CACHE-03.
- `scripts/ci/obs-summary.sh` — cache HIT/PARTIAL/MISS + per-step timing renderer.
- `scripts/ci/aggregate-gate.sh` — treats non-`success` (incl. `skipped`) as failure (`:17-21`);
  keeps the transitive `build` job vacuous-pass-safe.
- `test/chimeway/ci_observability_contract_test.exs` — Phase-87 contract; iterates 14 `@build_lanes`
  (`:18`); the `refute --warnings-as-errors` assertion (`:248-256`) MUST be relaxed for D-14.
- `test/chimeway/release_gate_contract_test.exs` — asserts `ci-gate` needs exactly 14 (`:236`) and
  `pr-gate` exactly the 4-lane subset (`:256-269`); the `needs:` extractor is at `:892-916`. D-11
  wiring must keep these green.
- `mix.exs` — `ex_doc` `only: :dev` (`:41`), `credo` `only: [:dev, :test]` (`:42`); aliases
  `ci.lint` (`:70`), `ci.docs` (`:80`), `verify.install_golden` (`:111`).
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Phase-87 OBS probe (`scripts/ci/obs-recompile.sh` + `obs-summary.sh`) already renders per-lane cache
  HIT/PARTIAL/MISS + deps-vs-app recompile counts + per-step timing — this IS the CACHE-05 proof
  instrument; no new measurement tooling needed.
- `scripts/ci/aggregate-gate.sh` already treats `skipped` as a gate failure, so a transitive producer
  job is safe against vacuous passes without new guard code.
- The `test` matrix lane already interpolates `${{ matrix.elixir }}-${{ matrix.otp }}` into its cache
  key (`ci.yml:199`) — proves version-in-key interpolation works; the new schema generalizes this.

### Established Patterns
- Complex CI logic lives in `scripts/ci/*.sh` (v1.14 Phase 80 pattern) — new cache/producer helpers,
  if any, follow suit rather than inlining large `run:` blocks.
- Two-aggregate topology (`pr-gate` fast + `ci-gate` 14-lane) is contract-locked by
  `release_gate_contract_test.exs`; structural changes must keep the exact `needs:` counts/names.
- `pr-gate` is the required PR check via ruleset 18486746 (needs only lint/test/verify_gates/verify_docs).

### Integration Points
- Producer `build` job → default-graph consumers via `needs: [build]` + `actions/cache/restore`.
- Contract tests (`ci_observability_contract_test.exs`, `release_gate_contract_test.exs`) are the
  guardrails that make this refactor safe — every structural edit is paired with a contract check.
</code_context>

<specifics>
## Specific Ideas

- Consumers use `actions/cache/restore` with `fail-on-cache-miss: true`; producer uses full
  `actions/cache` (or `actions/cache/save`) — the documented granular producer/consumer split.
- setup-beam outputs are `elixir-version` / `otp-version` (NOT `erlang-version`).
- User confirmed (2026-07-28): docs lane stays on its own `build-dev` key; `mix.exs`/ex_doc `only:` is
  NOT changed to pull ex_doc into `:test`.
</specifics>

<deferred>
## Deferred Ideas

- Adding `:test` to `ex_doc`'s `only:` so `verify_docs` could literally share `build-test` — considered
  and rejected this phase (higher blast radius on the dep graph; docs-on-`build-dev` is cleaner).
- `.tool-versions` as the SSOT for the OTP/Elixir versions that feed cache keys — that's Phase 91
  (QUAL-01). This phase reads versions from the resolved `setup-beam` outputs, not from a version-file.

### Reviewed Todos (not folded)
None — no pending todos matched Phase 88.
</deferred>
