# Roadmap: Chimeway

## Milestones

- ✅ **v1.0** — [Archived roadmap](.planning/milestones/v1.0-ROADMAP.md) (shipped 2026-04-25)
- ✅ **v1.1** — [Archived roadmap](.planning/milestones/v1.1-ROADMAP.md) (shipped 2026-04-27)
- ✅ **v1.2** — [Archived roadmap](.planning/milestones/v1.2-ROADMAP.md) (shipped 2026-04-29)
- ✅ **v1.3** — [Archived roadmap](.planning/milestones/v1.3-ROADMAP.md) (shipped 2026-04-30)
- ✅ **v1.4** — [Archived roadmap](.planning/milestones/v1.4-ROADMAP.md) · [Audit](.planning/milestones/v1.4-MILESTONE-AUDIT.md) (shipped 2026-05-08, closed 2026-05-28)
- ✅ **v1.5** — [Archived roadmap](.planning/milestones/v1.5-ROADMAP.md) · [Audit](.planning/milestones/v1.5-MILESTONE-AUDIT.md) (shipped 2026-05-29)
- ✅ **v1.6** — [Archived roadmap](.planning/milestones/v1.6-ROADMAP.md) · [Audit](.planning/milestones/v1.6-MILESTONE-AUDIT.md) (shipped 2026-05-29)
- ✅ **v1.7** — [Archived roadmap](.planning/milestones/v1.7-ROADMAP.md) · [Audit](.planning/milestones/v1.7-MILESTONE-AUDIT.md) (shipped 2026-05-29)
- ✅ **v1.8** — [Archived roadmap](.planning/milestones/v1.8-ROADMAP.md) · [Audit](.planning/milestones/v1.8-MILESTONE-AUDIT.md) (shipped 2026-05-30)
- ✅ **v1.9** — [Archived roadmap](.planning/milestones/v1.9-ROADMAP.md) · [Audit](.planning/milestones/v1.9-MILESTONE-AUDIT.md) (shipped 2026-05-30)
- ✅ **v1.10 Ecosystem Completions** — [Archived roadmap](.planning/milestones/v1.10-ROADMAP.md) · [Audit](.planning/milestones/v1.10-MILESTONE-AUDIT.md) (shipped 2026-06-04)
- ✅ **v1.11 Operator Console Polish & Hardening** — [Archived roadmap](.planning/milestones/v1.11-ROADMAP.md) · [Audit](.planning/milestones/v1.11-MILESTONE-AUDIT.md) (shipped 2026-06-04)
- ✅ **v1.13 Storage Isolation and Upgrade Path** — [Archived roadmap](.planning/milestones/v1.13-ROADMAP.md) · [Audit](.planning/milestones/v1.13-MILESTONE-AUDIT.md) (shipped 2026-07-02)
- ✅ **v1.14 Public Truth and Verification Architecture** — [Archived roadmap](.planning/milestones/v1.14-ROADMAP.md) (shipped 2026-07-03)
- ✅ **v1.15 Brand Identity & Brand Book** — [Archived roadmap](.planning/milestones/v1.15-ROADMAP.md) · [Audit](.planning/milestones/v1.15-MILESTONE-AUDIT.md) (shipped 2026-07-28, accepted-risk close)
- 🚧 **v1.16 CI/CD Performance & Reliability** — active (Phases 87-92)

## Active Milestone

**v1.16 CI/CD Performance & Reliability**

**Goal:** Make CI fast, deterministic, and trustworthy — collapse the ~6.5 min `main` wall-clock (gated by a single cold-compiling job) toward under ~3 min by fixing compiled-artifact caching, without lowering the quality signal or overcomplicating the pipeline.

**Milestone-wide invariant (applies to every phase):** doc/config/CI-only. No runtime library behavior changes — core notification behavior is frozen this milestone. Every phase touches `.github/workflows/*`, `scripts/ci/*.sh`, `config/test.exs`, `.tool-versions`, `mix.exs` project/release config, or `test/**` isolation helpers only.

**Requirements:** [REQUIREMENTS.md](.planning/REQUIREMENTS.md) — 26 requirements (OBS, CACHE, CONC, TIER, QUAL, REL)

**Key context:** Baseline measured 2026-07-28 — `main` CI ~373–395s, entire wall-clock gated by the 373s `install_golden` job whose `mix ecto.create` hides a 135s cold compile; compile times are dead-flat across 3 identical-`mix.lock` runs (cache never warms). Runner ≈ 4 cores. Two CI-only backlog issues remain open (`.planning/CI-HARDENING-BACKLOG.md` #2 `demo.up --check` dev-DB hang, #3 Accrue path-dep compile) — carried into Phase 92.

**Dependency chain:** Phase 87 → Phase 88 → {Phase 89, Phase 90} → Phase 91 → Phase 92 (Phase 91 leans on Phase 90's nightly tier for its 1.17 CI leg).

## Phases

### v1.16 CI/CD Performance & Reliability

- [x] **Phase 87: CI Observability & Cache Diagnostics** — Per-lane cache hit/miss, recompile counts, and step timing land in job summaries; pre-optimization baseline recorded for provable before/after deltas (completed 2026-07-29)
- [ ] **Phase 88: Cache Correctness & Compile-Once** — Fix the MIX_ENV-absent cache-key collision, standardize keys, split deps from `_build`, de-fragment plain-hex lanes, and compile deps once via a producer job
- [x] **Phase 89: Test-Lane Concurrency** — Flip ~32 pure-DB DataCase files to async, size the pool, enforce warnings-as-errors, and shake out ordering coupling across seeds
- [ ] **Phase 90: Pipeline Tiering (PR/main/nightly)** — Add a `schedule:` nightly tier (cold build, full OTP matrix, 1.17 floor leg, heavy Playwright lane); PR path stays single-OTP
- [ ] **Phase 91: Quality & Supply-Chain Polish** — `.tool-versions`, dependabot, least-privilege permissions, advisory `mix_audit`, and closing the CI↔release Elixir skew
- [ ] **Phase 92: Reliability Triage & Determinism** — Measure real-vs-flaky rate, close the two CI-only backlog issues, keep seed determinism, and add a put_env capture/restore helper

### Phase 87: CI Observability & Cache Diagnostics

**Goal:** Make cache hit/miss, recompile-count, and per-step timing visible in every job summary, and record the pre-optimization baseline — so every later optimization in this milestone is provable by a run-link delta rather than a feeling.

**Depends on:** Nothing (first phase; low-risk enabler — must land before any cache/tiering change so wins are measurable)

**Requirements:** OBS-01, OBS-02, OBS-03, OBS-04

**Success Criteria** (what must be TRUE):

1. Every build lane's GitHub Actions job summary shows a cache hit/miss line for its `_build`/`deps` caches, surfaced via `$GITHUB_STEP_SUMMARY`.
2. Every build lane's job summary reports a recompiled-file count (deps vs. app split out), captured immediately after `deps.get`/`mix compile`.
3. Every lane writes a per-step timing table (step name + duration) to `$GITHUB_STEP_SUMMARY`.
4. The pre-optimization baseline (~373–395s `main` wall-clock, 373s `install_golden`, 135s hidden compile inside `ecto.create`, dead-flat compile time across 3 identical-lock runs) is committed with a run link, so Phase 88's fix and every later phase can cite a before/after delta.

**Plans:** 3 plans

- [x] 87-01-PLAN.md — Tracer: shared `obs-*.sh` scripts + Wave 0 contract test + fixtures + instrument the `lint` lane end-to-end (OBS-01/02/03)
- [x] 87-02-PLAN.md — Fan-out the observability pattern to the remaining 13 build lanes + extend the contract test to all 14 (OBS-01/02/03)
- [x] 87-03-PLAN.md — Commit `.planning/CI-PERF-BASELINE.md` with the four baseline facts + delta ledger + run permalink; live-render human check (OBS-04)

### Phase 88: Cache Correctness & Compile-Once

**Goal:** Fix the root-cause cache-key collision so `_build` actually warms across runs, standardize cache keys on env + resolved toolchain + lockfile, split source deps from compiled `_build`, de-fragment the plain-hex lanes onto one shared key, and compile dependencies exactly once per run — collapsing the gated ~6.5 min `main` wall-clock toward under ~3 min.

**Depends on:** Phase 87 (needs the OBS probe + recorded baseline to prove the win by run-link delta)

**Requirements:** CACHE-01, CACHE-02, CACHE-03, CACHE-04, CACHE-05

**Success Criteria** (what must be TRUE):

1. Every `_build` cache key includes `MIX_ENV` and the resolved OTP/Elixir versions; the source `deps` cache is a separate key scoped to `mix.lock` (not the overly broad `**/mix.lock`).
2. All plain-hex-graph lanes (lint, test, docs, etc.) share a single warm `build-test` cache key; partner lanes (accrue/threadline/sigra) keep their own graph-specific keys and never consume the shared cache.
3. `install_golden`'s critical path runs an explicit `mix compile --warnings-as-errors` before `mix ecto.create`, so the Phase 87 timing summary shows `ecto.create` as a fast DB-only step, not a disguised full compile.
4. A single producer `build` job compiles dependencies once per run; consuming plain-hex lanes declare `needs: [build]` and restore its cache instead of each recompiling the tree independently.
5. Two consecutive warm `main` runs against an identical `mix.lock` show near-zero dependency recompilation per the OBS probe from Phase 87, and warm `ci-gate` wall-clock is under ~3 minutes — provable by a run-link delta against the recorded baseline.

**Plans:** 3 plans
- [ ] 88-01-PLAN.md — Tracer: `build` producer job + `lint`/`install_golden` converted to restore-only consumers + CACHE-03 warnings-as-errors (wave 1)
- [ ] 88-02-PLAN.md — Fan-out: 7 default-graph lanes → shared cache consumers; docs/OTP-matrix/partners reschemed to distinct self-cached roles; contract extended (wave 2)
- [ ] 88-03-PLAN.md — Proof: fill the delta-ledger after-row + human-verify the warm-run compile-once win (near-zero dep recompile, sub-3-min ci-gate) (wave 3)

### Phase 89: Test-Lane Concurrency

**Goal:** Convert the pure-DB portion of the test suite to safe parallel execution, size the connection pool for that concurrency, enforce the same warnings-as-errors bar as the `verify.*` lanes, and prove the conversion introduced no ordering coupling.

**Depends on:** Phase 88 (measuring concurrency wins against an already warm, compile-once pipeline gives a clean signal, uncontaminated by cache-miss noise)

**Requirements:** CONC-01, CONC-02, CONC-03, CONC-04

**Success Criteria** (what must be TRUE):

1. The ~32 pure-DB `Chimeway.DataCase` test modules run with `async: true`; the ~25 app-env mutators and ~5 `:prefix` mutators remain `async: false`, with no data races across 3 consecutive CI runs.
2. `config/test.exs` sets an explicit `Chimeway.Repo` `pool_size` sized for the new async concurrency, with no connection-pool-exhaustion failures.
3. The `ci.test` lane runs with `--warnings-as-errors` and fails the lane on any compiler warning, at parity with the `verify.*` lanes.
4. The suite passes across randomized-seed CI runs and one ordered `--seed 0` run with identical pass/fail results, proving the async conversion introduced no test-ordering coupling.

**Plans:** 6 plans

Plans:
- [x] 89-01-PLAN.md — Tracer: size Chimeway.Repo test pool + flip signal_test.exs to async, prove the mechanism end-to-end
- [x] 89-02-PLAN.md — Flip inbox-suite + digest + remaining top-level workflow DataCase modules to async (9 files)
- [x] 89-03-PLAN.md — Flip orchestration + integration + remaining trigger/persistence DataCase modules to async (7 files)
- [x] 89-04-PLAN.md — Flip rendering + dispatch/webhooks worker DataCase modules to async — completes the 20-file flip set (3 files)
- [x] 89-05-PLAN.md — Add --warnings-as-errors to ci.test, fix surfaced warnings, one-time negative proof, contract guard
- [x] 89-06-PLAN.md — Closing CONC-04 proof: 3 random-seed + 1 --seed 0 mix ci.test runs, contract guard, success-criteria closure

### Phase 90: Pipeline Tiering (PR/main/nightly)

**Goal:** Introduce a `schedule:`-driven nightly tier that absorbs the expensive full-matrix, cold-build, and heavy-browser work, so the PR path stays fast and single-OTP while release confidence is preserved on a slower, honest cadence.

**Depends on:** Phase 88 (tiering should be designed against the real, already-fixed cache economics, not the broken baseline)

**Requirements:** TIER-01, TIER-02, TIER-03, TIER-04

**Success Criteria** (what must be TRUE):

1. A `schedule:`-triggered nightly workflow run performs one full cold build (no restored cache, a live cache-correctness backstop), the full OTP {26, 27} matrix, and a 1.17-floor leg honoring `mix.exs`'s `~> 1.17` constraint.
2. The heavy Playwright `verify_admin` browser-smoke lane runs on the nightly tier instead of on every PR/push.
3. The PR path (`pr-gate`) runs a single OTP version (27); only the push and nightly tiers run the full OTP matrix.
4. A nightly aggregate gate job mirrors `ci-gate`'s pass/fail decision semantics for every lane relocated to the nightly tier, so a maintainer can tell from one job whether the nightly tier is green.

**Plans:** 3 plans
- [x] 90-01-PLAN.md — Tracer: resolve_tiers setup job + event-conditional OTP matrix on test + Wave-0 contract backstop (TIER-03)
- [x] 90-02-PLAN.md — Atomic fix: relocate verify_admin to nightly-only + strip from ci-gate + update lane-count contract, live-proven (TIER-02)
- [ ] 90-03-PLAN.md — nightly_cold_build + test_floor_1_17 + nightly-gate + closing live nightly/PR-path proof (TIER-01, TIER-04)

### Phase 91: Quality & Supply-Chain Polish

**Goal:** Close the remaining small-but-compounding toolchain-truth and supply-chain gaps — one source of truth for toolchain versions, automated dependency update PRs, least-privilege workflow permissions, an advisory vulnerability scan, and a reconciled CI-vs-release Elixir version.

**Depends on:** Phase 90 (QUAL-05's added 1.17 CI leg is homed on the push/nightly tier Phase 90 establishes)

**Requirements:** QUAL-01, QUAL-02, QUAL-03, QUAL-04, QUAL-05

**Success Criteria** (what must be TRUE):

1. `.tool-versions` is the single toolchain source of truth; `setup-beam`'s `version-file:` reads it, and cache keys derive from its resolved versions rather than hard-coded strings duplicated in `ci.yml`.
2. `.github/dependabot.yml` exists and opens update PRs for both the `mix` and `github-actions` ecosystems.
3. `ci.yml` declares a top-level `permissions: contents: read`, with individual jobs escalating only the specific permissions they actually need.
4. `mix_audit` runs in CI as a real advisory-database vulnerability scan (non-blocking, matching the existing deliberate `hex.audit` posture), with findings visible in job output.
5. The release workflow's Elixir version and CI's 1.17-floor leg (added in Phase 90) are reconciled — release stays pinned to the 1.17 floor, and CI actually exercises that floor on push/nightly, closing the prior skew.

**Plans:** TBD

### Phase 92: Reliability Triage & Determinism

**Goal:** Establish a trustworthy CI reliability signal — measure and reduce real-vs-flaky failures, close the two outstanding CI-only backlog issues, and add the last determinism/isolation guards — now that the pipeline is fast, warm, and tiered enough to make the measurement meaningful.

**Depends on:** Phase 91 (last phase — cheapest and clearest once CI is fast/warm/tiered; measuring flake rate against a slow, cold, cache-broken baseline would be noise)

**Requirements:** REL-01, REL-02, REL-03, REL-04

**Success Criteria** (what must be TRUE):

1. Using the OBS tooling from Phase 87, the measured completed-run failure rate on `main` `ci-gate` is under 10%, corroborated by 5 consecutive green `main` `ci-gate` runs.
2. `CI-HARDENING-BACKLOG.md` issue #2 (`demo.up --check` dev-DB hang) and issue #3 (Accrue path-dep compile failure) are each verified fixed on CI, or explicitly quarantined behind a linked tracking issue — no silent CI-only reproduction gaps remain undocumented.
3. A nightly `--seed 0` ordering run (building on Phase 89's shakeout) continues to guard against test-ordering coupling going forward; the random ExUnit seed is kept for all other runs.
4. A capture/restore `put_env` test helper exists and is adopted by the async-safe DataCase modules from Phase 89, standardizing app-env isolation so the async split stays safe as the suite grows.

**Plans:** TBD

<details>
<summary>✅ v1.15 Brand Identity & Brand Book (Phases 81-86) — SHIPPED 2026-07-28 (accepted-risk close)</summary>

- [x] Phase 81: Design Tokens (Reconciliation & Documentation) (3/3 plans) — completed 2026-07-10
- [x] Phase 82: Logo Exploration & Shortlist (1/1 plan) — completed 2026-07-18
- [x] Phase 83: Direction Selection & Final Asset Family (User Checkpoint) (3/3 plans) — completed 2026-07-18
- [x] Phase 84: HTML Brandbook, Voice & Component States (4/4 plans) — completed 2026-07-27
- [x] Phase 85: Repo Integration (README + HexDocs + Favicon Wiring) (1/1 plan) — completed 2026-07-27
- [x] Phase 86: Accessibility Audit, Notes & Red-Team Close (4/4 plans) — completed 2026-07-28 — accepted-risk: A11Y-03 (focus-not-obscured) + A11Y-04 (CVD emulation) manual browser checks owner-waived

Full detail: [milestones/v1.15-ROADMAP.md](.planning/milestones/v1.15-ROADMAP.md)

</details>

<details>
<summary>✅ v1.14 Public Truth and Verification Architecture (Phases 77-80) — SHIPPED 2026-07-03</summary>

- [x] Phase 77: Truth Baseline and Package Model Decision (2/2 plans) — completed 2026-07-03
- [x] Phase 78: Release and Package Truth (3/3 plans) — completed 2026-07-03
- [x] Phase 79: Front Door and Docs IA (1/1 plan) — completed 2026-07-03
- [x] Phase 80: Verification Architecture and CI/DX (4/4 plans) — completed 2026-07-03

Full detail: [milestones/v1.14-ROADMAP.md](.planning/milestones/v1.14-ROADMAP.md)

</details>

<details>
<summary>✅ v1.13 Storage Isolation and Upgrade Path (Phases 73-76.1) — SHIPPED 2026-07-02</summary>

- [x] Phase 73: Storage Prefix Contract (3/3 plans) — completed 2026-06-30
- [x] Phase 74: Prefixed Migration Generator (10/10 plans) — completed 2026-06-30
- [x] Phase 75: Runtime Prefix Propagation (8/8 plans) — completed 2026-07-01
- [x] Phase 76: Prefix Docs, Demo, and Gates (3/3 plans) — completed 2026-07-02
- [x] Phase 76.1: Close gap: GATE-01 - generated prefixed migration runtime proof (1/1 plan) — completed 2026-07-02

Full detail: [milestones/v1.13-ROADMAP.md](.planning/milestones/v1.13-ROADMAP.md)

</details>

## Progress

| Milestone | Phases | Plans | Requirements | Status | Shipped |
|-----------|--------|-------|--------------|--------|---------|
| v1.16 CI/CD Performance & Reliability | 87-92 | 0/TBD | 0/26 | Not started — roadmap created | - |
| v1.15 Brand Identity & Brand Book | 81-86 | 16/16 | 30/32 | Complete (accepted-risk: 2 A11Y manual checks owner-waived) | 2026-07-28 |
| v1.14 Public Truth and Verification Architecture | 77-80 | 10/10 | 14/14 | Complete | 2026-07-03 |
| v1.13 Storage Isolation and Upgrade Path | 73-76.1 | 25/25 | 20/20 | Complete | 2026-07-02 |
| v1.11 Operator Console Polish & Hardening | 68-72 | 12/12 | 18/18 | Complete | 2026-06-04 |
| v1.10 Ecosystem Completions | 63-67 | 13/13 | 8/8 | Complete | 2026-06-04 |

### v1.16 Phase Status

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 87. CI Observability & Cache Diagnostics | 3/3 | Complete    | 2026-07-29 |
| 88. Cache Correctness & Compile-Once | 0/TBD | Not started | - |
| 89. Test-Lane Concurrency | 0/TBD | Not started | - |
| 90. Pipeline Tiering (PR/main/nightly) | 2/3 | In Progress|  |
| 91. Quality & Supply-Chain Polish | 0/TBD | Not started | - |
| 92. Reliability Triage & Determinism | 0/TBD | Not started | - |

---
*Roadmap updated: 2026-07-29 — v1.16 CI/CD Performance & Reliability milestone initialized (Phases 87-92, continued numbering from Phase 86); 26/26 requirements mapped (OBS/CACHE/CONC/TIER/QUAL/REL). Doc/config/CI-only invariant. Next: /gsd-plan-phase 87.*
