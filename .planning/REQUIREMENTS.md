# Requirements: Chimeway — v1.16 CI/CD Performance & Reliability

**Defined:** 2026-07-28
**Core Value:** Every notification decision is explainable, so teams can reliably answer why a notification sent, failed, was deferred, or was suppressed.

> Milestone scope is CI/CD, tooling, and test-suite quality — **doc/config/CI-only, no runtime library behavior changes**. Baseline measured 2026-07-28: `main` CI ~373–395s, entire wall-clock gated by the 373s `install_golden` job (a 135s cold compile hidden in `mix ecto.create`); compile times dead-flat across 3 identical-`mix.lock` runs (cache never warms). Runner ≈ 4 cores.

## v1 Requirements

### OBS — CI Observability & Cache Diagnostics (Phase 87)

- [x] **OBS-01**: A maintainer can see per-lane cache hit/miss in the GitHub Actions job summary for every build lane.
- [x] **OBS-02**: A maintainer can see how many files were recompiled (deps + app) on each build lane, exposed after `deps.get`.
- [x] **OBS-03**: A maintainer can see a per-step timing summary written to `$GITHUB_STEP_SUMMARY` for each lane.
- [x] **OBS-04**: The measured pre-optimization baseline is recorded (with a run link) so every later win is provable by a before/after delta.

### CACHE — Cache Correctness & Compile-Once (Phase 88)

- [ ] **CACHE-01**: Every `_build` cache key includes `MIX_ENV` and the resolved OTP/Elixir versions; the `deps` (source) cache is split from `_build` and keyed on `mix.lock` (not `**/mix.lock`).
- [ ] **CACHE-02**: Plain-hex-graph lanes share a single warm `build-test` cache; partner lanes (accrue/threadline/sigra) retain graph-specific keys.
- [ ] **CACHE-03**: An explicit `mix compile --warnings-as-errors` runs before `ecto.create` on the critical-path lane(s), so `ecto.create` is a fast DB op rather than a disguised full compile.
- [ ] **CACHE-04**: A single producer `build` job compiles deps once per run; plain-hex lanes consume its cache via `needs:` instead of each recompiling the tree.
- [ ] **CACHE-05**: Consecutive warm `main` runs show near-zero dependency recompilation (proven by the OBS probe), and warm `ci-gate` wall-clock is under ~3 minutes.

### CONC — Test-Lane Concurrency (Phase 89)

- [x] **CONC-01**: Pure-DB `Chimeway.DataCase` test modules run `async: true`; the ~25 app-env mutators and ~5 `:prefix` mutators remain `async: false`.
- [x] **CONC-02**: `config/test.exs` sets an explicit `Chimeway.Repo` `pool_size` sized for the async concurrency.
- [x] **CONC-03**: The `ci.test` lane runs with `--warnings-as-errors` (parity with the `verify.*` lanes).
- [x] **CONC-04**: The suite passes across randomized seeds **and** an ordered `--seed 0` run after the async conversion (no ordering coupling introduced).

### TIER — Pipeline Tiering (PR / main / nightly) (Phase 90)

- [x] **TIER-01**: A `schedule:` nightly tier exists that runs one full **cold** build, the full OTP {26,27} matrix, and a 1.17 floor leg (honoring `mix.exs` `~> 1.17`).
- [x] **TIER-02**: The heavy Playwright `verify_admin` lane runs on the nightly tier.
- [x] **TIER-03**: The PR path runs a single OTP version (27); push and nightly run the full matrix.
- [x] **TIER-04**: A nightly aggregate gate mirrors `ci-gate` decision semantics for the relocated lanes.

### QUAL — Quality & Supply-Chain Polish (Phase 91)

- [x] **QUAL-01**: `.tool-versions` is the single toolchain source and feeds `setup-beam` (`version-file:`) and the cache keys.
- [x] **QUAL-02**: `.github/dependabot.yml` covers `mix` and `github-actions`.
- [x] **QUAL-03**: `ci.yml` declares top-level least-privilege `permissions: contents: read` (jobs escalate only where needed).
- [x] **QUAL-04**: `mix_audit` runs (advisory-only, matching the deliberate `hex.audit` posture) as a real advisory-DB scan.
- [x] **QUAL-05**: The CI↔release Elixir version skew is resolved — release stays on the 1.17 floor and a 1.17 CI leg is added on push/nightly so the floor is actually exercised.

### REL — Reliability Triage & Determinism (Phase 92)

- [ ] **REL-01**: Real-vs-flaky failure rate is measured via the OBS tooling; completed-run failure rate is under 10% with ≥ 5 consecutive green `main` `ci-gate` runs.
- [ ] **REL-02**: The two documented CI-only backlog issues (`CI-HARDENING-BACKLOG.md` #2 `demo.up --check` dev-DB hang, #3 Accrue path-dep compile) are verified fixed or quarantined with a tracking issue.
- [ ] **REL-03**: A nightly `--seed 0` ordering run guards against test-ordering coupling.
- [ ] **REL-04**: A capture/restore `put_env` test helper standardizes app-env isolation so the async split stays safe long-term.

## v2 Requirements (deferred — tracked, not this milestone)

### Deferred CI/quality

- **DEF-DIALYZER**: Dialyzer static analysis (nightly-only if ever adopted) — deferred; specs are relaxed today.
- **DEF-COVERAGE**: ExCoveralls coverage reporting/threshold (nightly-only) — deferred; no gate threshold set.
- **DEF-AUDIT-BLOCK**: Promote `mix_audit`/`hex.audit` from advisory to blocking — deferred pending upstream-patch policy.
- **DEF-PARTNER-NIGHTLY**: Move partner integration lanes from push-to-main to nightly — deferred; they anchor release confidence.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Any runtime library behavior change | Milestone is CI/config/test-quality only; core notification behavior is frozen |
| `mix test --partitions N` sharding on one runner | N× compile contention on a 4-core box; looks fast, hides cost |
| Pinned global ExUnit seed | Green-washes real test-ordering coupling; keep the random seed |
| `touch`-based mtime cache hacks | Wrong fix; the real bug is the MIX_ENV-absent cache key |
| Self-hosted / larger runners, bespoke cache servers | Over-engineering; standard `actions/cache` + `schedule:` suffice |
| Sharing `_build` into partner lanes | Different dep graph via `*_PATH` path-deps → wrong-artifact reuse |
| Mass `async: true` conversion of all test modules | The 25 app-env / 5 prefix mutators would data-race |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| OBS-01..04 | Phase 87 | Complete |
| CACHE-01..05 | Phase 88 | Pending |
| CONC-01..04 | Phase 89 | Complete |
| TIER-01..04 | Phase 90 | Complete |
| QUAL-01..05 | Phase 91 | Complete |
| REL-01..04 | Phase 92 | Pending |

**Coverage:**

- v1 requirements: 26 total (OBS 4, CACHE 5, CONC 4, TIER 4, QUAL 5, REL 4)
- Mapped to phases: 26
- Unmapped: 0

---
*Requirements defined: 2026-07-28*
*Last updated: 2026-07-28 at milestone v1.16 start*
