---
phase: 80-verification-architecture-and-ci-dx
plan: 03
subsystem: ci-dx
tags: [github-actions, ci, scripts-extraction, local-reproducibility, contract-test]
requires:
  - phase: 80-verification-architecture-and-ci-dx
    provides: two-aggregate pr-gate/ci-gate topology (80-01) + cache cost centers (80-02)
provides:
  - scripts/ci/detect-installer-changes.sh — installer-change git-diff detection, locally runnable (CI-04)
  - scripts/ci/aggregate-gate.sh — required-lane pass/fail loop shared by pr-gate and ci-gate (CI-04)
  - scripts/ci/sigra-proof.sh — root + demo-host Sigra proof lanes with full env contract (CI-04)
  - Contract-test lock for script extraction + Sigra-in-script strictness
affects:
  - phase-80-plan-04-docs-and-branch-protection
tech-stack:
  added: []
  patterns:
    - Extract complex inline CI bash into committed scripts/ci/*.sh invoked verbatim by the workflow
    - Verbatim-copy of load-bearing regex/commands (no paraphrase) locked by contract-test substrings
    - Aggregate gate reads lane results via bash indirect expansion so one script serves both gates
key-files:
  created:
    - scripts/ci/detect-installer-changes.sh
    - scripts/ci/aggregate-gate.sh
    - scripts/ci/sigra-proof.sh
    - .planning/phases/80-verification-architecture-and-ci-dx/80-03-SUMMARY.md
  modified:
    - .github/workflows/ci.yml
    - test/chimeway/release_gate_contract_test.exs
decisions:
  - "[80-03]: Added a checkout step to pr-gate and ci-gate (they previously had none) so the aggregate script is present in the runner (Rule 3 blocking fix)"
  - "[80-03]: sigra-proof.sh sets the proof env-var contract internally (subshell per lane) so the script is the single source of truth and the contract test asserts env names against script content"
  - "[80-03]: verify_sigra job-level env (SIGRA_PATH, PG*, CHIMEWAY_SKIP_ACCRUE/THREADLINE_DEP) and the Prepare-root-test-database step stay in ci.yml; only proof commands + proof env moved to the script"
metrics:
  duration: 5 min
  completed: 2026-07-03
  tasks: 3
  files_modified: 2
requirements-completed: [CI-04]
status: complete
---

# Phase 80 Plan 03: CI Verification Extraction to scripts/ci Summary

**Extracted the three complex inline `ci.yml` verification fragments — installer-change detection, the required-lane aggregate loop, and the root/demo-host Sigra proof runner — into committed, locally-runnable `scripts/ci/*.sh`, rewired the workflow to call them, and re-locked the extraction (including Sigra proof strictness) in `release_gate_contract_test.exs`.**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-07-03T16:39Z
- **Completed:** 2026-07-03T16:44Z
- **Tasks:** 3
- **Files modified:** 2 (plus 3 scripts created)

## Accomplishments

- **detect-installer-changes.sh:** reproduces the `install_golden_contract` detect logic — `git fetch origin <base_ref>` + `git diff --name-only origin/<base>...HEAD | grep -qE '<regex>'` — with the installer-trigger regex copied VERBATIM from ci.yml:706 (all triggers: `priv/chimeway_migrations/`, gen-migrations task, `lib/chimeway/install/`, `test/chimeway/install/`, `migration_contract_test.exs`, both `installer_golden_*` fixture dirs, `installer_fixture.ex`, `mix.exs`, `ci.yml`, `.formatter.exs`, `.credo.exs`). Prints `run=true|false`; base ref defaults to `$GITHUB_BASE_REF` then `main`. The detect step now calls the script and appends its line to `$GITHUB_OUTPUT`, preserving the early `run=true` on non-`pull_request` events and the `steps.detect.outputs.run == 'true'` conditionals.
- **aggregate-gate.sh:** reproduces the pr-gate/ci-gate required-lane loop — reads each named env var via bash indirect expansion, prints any lane not exactly `success`, exits 1 if any failed. Both `pr-gate` (4 lanes) and `ci-gate` (14 lanes) now call the single script with their lane lists; each gate keeps its `env:` block binding names to `needs.<lane>.result`. `ci-gate` `needs` stays inline and unchanged; its literal `name: ci-gate` and PR-exemption guard are intact.
- **sigra-proof.sh:** reproduces both proof lanes verbatim under a `root|demo|all` argument — root runs `timeout 300s elixir $(find _build/test/lib -type d -name ebin -print | sed 's/^/-pa /') test/support/sigra/ci_proof_runner.exs` under `CHIMEWAY_FORCE_SIGRA_TEST_REPO_SETUP/CHIMEWAY_MANUAL_REPO_START/CHIMEWAY_SKIP_OBAN`; demo runs the `cd examples/chimeway_demo_host && mix deps.get && timeout 600s mix deps.compile && timeout 300s mix compile && timeout 300s mix test --no-compile … sigra_auth_proof_test.exs …` chain under `CHIMEWAY_SKIP_THREADLINE_DEP/CHIMEWAY_SKIP_MAILGLASS_DEP/CHIMEWAY_SKIP_SIGRA_TRANSITIVE_DEP/CHIMEWAY_PATH/SIGRA_PATH`. Each lane runs in a subshell so env and `cd` are scoped. `verify_sigra`'s two proof steps now call the script; checkout/setup-beam/cache/`Prepare root test database` steps and job-level env are untouched.
- **Contract lock:** redirected the fragile `verify_sigra` proof-string assertions to read `scripts/ci/sigra-proof.sh` (every load-bearing proof command + env name asserted there) while keeping the job-level env + db-prep assertions against the ci.yml job block — at least as strict as before. Added a new `CI verification extraction (CI-04)` describe: script existence, ci.yml references each script, the verbatim installer-regex core lives in the detect script, install_golden detect step calls the detect script, both gates call the aggregate script, and verify_sigra calls the Sigra script.

## Task Commits

Each task was committed atomically:

1. **Task 1: Extract installer-detect + aggregate-gate and wire ci.yml** — `412d178` (feat)
2. **Task 2: Extract Sigra proof runner to scripts/ci/sigra-proof.sh** — `47041b1` (feat)
3. **Task 3: Lock the extraction + Sigra-in-script in the contract test** — `ceb65bc` (test)

## Files Created/Modified

- `scripts/ci/detect-installer-changes.sh` (created, +x) — verbatim installer regex, prints `run=true|false`.
- `scripts/ci/aggregate-gate.sh` (created, +x) — required-lane loop, fails on any non-`success`.
- `scripts/ci/sigra-proof.sh` (created, +x) — root + demo Sigra proof lanes with full env contract.
- `.github/workflows/ci.yml` (modified) — detect step, pr-gate, ci-gate, and verify_sigra rewired to call the scripts; checkout added to pr-gate/ci-gate.
- `test/chimeway/release_gate_contract_test.exs` (modified) — Sigra assertions redirected to the script; new extraction describe.
- `.planning/phases/80-verification-architecture-and-ci-dx/80-03-SUMMARY.md` — this summary.

## Decisions Made

- **Checkout added to pr-gate/ci-gate:** both aggregate jobs previously carried no checkout (they only read env). Calling a repo-local script requires the tree, so a single pinned `actions/checkout` (no setup-beam) was added to each. Cheap; required for correctness.
- **Sigra env owned by the script:** the proof env-var contract is set inside `sigra-proof.sh` (per-lane subshells) with `:-`/`:?` defaults, making the script the single source of truth and locally runnable, while the contract test asserts the env names against script content (D-14).
- **Job-level Sigra env kept in ci.yml:** `SIGRA_PATH`, PG*, `CHIMEWAY_SKIP_ACCRUE_DEP`, `CHIMEWAY_SKIP_THREADLINE_DEP` and the `Prepare root test database` step stay in the job; only the proof commands + their proof-specific env moved to the script.

## Verification

- PASS: Task 1 — `bash scripts/ci/aggregate-gate.sh FOO` exits non-zero; `FOO=success bash …` exits zero; ci.yml references both scripts; `python3 yaml.safe_load` parses ci.yml.
- PASS: Task 2 — `sigra-proof.sh` contains `ci_proof_runner.exs` + `sigra_auth_proof_test.exs`; ci.yml calls it; bad-arg usage exits 2; ci.yml parses.
- PASS: Task 3 — `mix ci.verify_gates` → 529 tests, 0 failures (up from 523 in Plan 02; +6 extraction tests). `mix format` applied to the contract test.
- PASS: No `release.yml` / `publish-hex.yml` / `release-pr-automerge.yml` touched (scope boundary held; D-10 polling JS untouched).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] pr-gate / ci-gate lacked a checkout step**
- **Found during:** Task 1
- **Issue:** Both aggregate jobs had no `actions/checkout` (they only read `needs.*.result` env), so a call to the repo-local `scripts/ci/aggregate-gate.sh` would fail with the script absent from the runner.
- **Fix:** Added one pinned `actions/checkout@34e114…` step (no setup-beam) to each of `pr-gate` and `ci-gate` before the aggregate call.
- **Files modified:** `.github/workflows/ci.yml`
- **Commit:** `412d178`

**Total deviations:** 1 auto-fixed (Rule 3).

## Threat Mitigations Applied

- **T-80-07 (installer detect regex narrowed):** regex copied verbatim; the contract test asserts representative verbatim triggers (`priv/chimeway_migrations/`, `installer_golden_prefixed`, `installer_golden_public`, `installer_fixture`, `migration_contract_test`) live in the detect script, so a paraphrase fails `mix ci.verify_gates`.
- **T-80-08 (Sigra strictness lost on extraction):** every load-bearing Sigra proof string + env name is re-asserted against `scripts/ci/sigra-proof.sh`, and the job block is asserted to call the script (D-14 "at least as strict").
- **T-80-09 (aggregate mishandling non-success):** the script fails on any lane != `success` (covers failure/skipped/cancelled), asserted by the contract test and the local non-`success` smoke.
- **T-80-SC (package installs):** none introduced; scripts are repo-local bash invoked with the pinned toolchain.

## Known Stubs

None. The three scripts are complete bash reproductions of the inline logic; no placeholder/TODO/FIXME or runtime stub content.

## Threat Flags

None. No new network endpoints, auth paths, file-access patterns, or schema changes — the extraction moves existing logic into scripts with identical command + env contracts.

## User Setup Required

None for this plan. Local runs of `sigra-proof.sh demo` require `SIGRA_PATH` set to a sigra checkout (the script errors clearly if unset), matching the existing MAINTAINING.md SIGRA_PATH guidance.

## Next Phase Readiness

Ready for Plan 04 (docs + branch-protection). The three CI fragments are now reproducible locally and contract-locked; the two-aggregate topology (80-01) and cache coverage (80-02) are unchanged.

## Self-Check: PASSED

- Found created file: `scripts/ci/detect-installer-changes.sh`.
- Found created file: `scripts/ci/aggregate-gate.sh`.
- Found created file: `scripts/ci/sigra-proof.sh`.
- Found task commits: `412d178`, `47041b1`, `ceb65bc`.
- `mix ci.verify_gates` green (529 tests, 0 failures).
- No release/publish/automerge workflow modified.

---
*Phase: 80-verification-architecture-and-ci-dx*
*Completed: 2026-07-03*
