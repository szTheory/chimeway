---
phase: 87-ci-observability-cache-diagnostics
plan: 01
subsystem: infra
tags: [github-actions, ci, bash, elixir, exunit, observability]

requires: []
provides:
  - "scripts/ci/obs-recompile.sh — explicit deps.compile + compile probe emitting deps/app recompile counts, correct 0 0 on a warm cache (OBS-02)"
  - "scripts/ci/obs-summary.sh — cache hit/matched/primary classifier (EXACT HIT/PARTIAL/MISS), recompile table reader, and REST /jobs step-timing renderer with graceful fallback, single consolidated write to $GITHUB_STEP_SUMMARY (OBS-01, OBS-03)"
  - "test/chimeway/ci_observability_contract_test.exs — Wave 0 ExUnit contract proving both scripts offline against committed fixtures plus lint-lane wiring"
  - "test/fixtures/ci/{compile_cold.log,compile_warm.log,jobs_api_sample.json} — offline parser fixtures"
  - "lint lane in .github/workflows/ci.yml fully instrumented end-to-end (id: cache_main, obs-recompile.sh probe, trailing if: always() obs-summary.sh step)"
affects: [87-02-plan (fans the identical pattern out to the other 13 build lanes)]

tech-stack:
  added: []
  patterns:
    - "obs-recompile.sh uses set -uo pipefail (NO -e) + PIPESTATUS capture so a warm-cache grep miss never aborts the step, while the real mix compile exit code is preserved"
    - "obs-summary.sh discovers caches generically via compgen -e | grep '^CACHE_.*_HIT$' + indirect ${!name} expansion — the same env-var-name-iteration idiom as scripts/ci/aggregate-gate.sh"
    - "Three tables accumulated into $RUNNER_TEMP scratch files, then ONE consolidated append to $GITHUB_STEP_SUMMARY — avoids the 20-summaries/job + 1 MiB/step caps"
    - "OBS_SKIP_COMPILE=1 / OBS_JOBS_JSON test hooks make both scripts unit-testable offline via System.cmd + fixtures, following the release_gate_contract_test.exs pattern"

key-files:
  created:
    - scripts/ci/obs-recompile.sh
    - scripts/ci/obs-summary.sh
    - test/chimeway/ci_observability_contract_test.exs
    - test/fixtures/ci/compile_cold.log
    - test/fixtures/ci/compile_warm.log
    - test/fixtures/ci/jobs_api_sample.json
  modified:
    - .github/workflows/ci.yml
    - .gitignore

key-decisions:
  - "obs-recompile.sh opens with set -uo pipefail (no -e); obs-summary.sh opens with set -euo pipefail — matches the research's Pitfall 1 divergence from the repo's usual set -euo pipefail header idiom."
  - "Cache classification and recompile-table logic stay inlined in obs-summary.sh (2 scripts total, not 3) per the phase research's resolved open question."
  - "Plain mix compile only — no --warnings-as-errors in the new instrumented step (that upgrade is Phase 88 / CACHE-03, explicitly out of scope here)."
  - "Added a scoped .gitignore exception (!test/fixtures/ci/*.log) — the repo-wide *.log rule would otherwise silently block committing the plan-required compile_cold.log/compile_warm.log fixtures (Rule 3 auto-fix)."

requirements-completed: [OBS-01, OBS-02, OBS-03]

coverage:
  - id: D1
    description: "obs-recompile.sh reports 0 0 on a warm-cache log and the fixture's known nonzero counts on a cold-cache log"
    requirement: "OBS-02"
    verification:
      - kind: unit
        ref: "test/chimeway/ci_observability_contract_test.exs#obs-recompile.sh parser (OBS-02)"
        status: pass
    human_judgment: false
  - id: D2
    description: "obs-summary.sh classifies cache-step outputs into EXACT HIT / PARTIAL / MISS"
    requirement: "OBS-01"
    verification:
      - kind: unit
        ref: "test/chimeway/ci_observability_contract_test.exs#obs-summary.sh cache classification (OBS-01)"
        status: pass
    human_judgment: false
  - id: D3
    description: "obs-summary.sh renders REST /jobs step-timing rows from a fixture and degrades gracefully to a non-fatal 'timing unavailable' row (zero exit) when the jobs JSON is missing"
    requirement: "OBS-03"
    verification:
      - kind: unit
        ref: "test/chimeway/ci_observability_contract_test.exs#obs-summary.sh timing rows (OBS-03)"
        status: pass
    human_judgment: false
  - id: D4
    description: "obs-summary.sh never leaks raw env/token values into the rendered summary"
    verification:
      - kind: unit
        ref: "test/chimeway/ci_observability_contract_test.exs#obs-summary.sh secret hygiene"
        status: pass
    human_judgment: false
  - id: D5
    description: "lint lane wired end-to-end: cache step carries id: cache_main, runs scripts/ci/obs-recompile.sh, and has a trailing if: always() scripts/ci/obs-summary.sh step that is the LAST step in the lane"
    requirement: "OBS-01"
    verification:
      - kind: unit
        ref: "test/chimeway/ci_observability_contract_test.exs#lint lane wiring (OBS-01 lint-scoped)"
        status: pass
    human_judgment: true
    rationale: "Offline contract tests prove the static wiring shape, but rendering all three tables on a real GitHub-hosted runner (gh api reachability, actual cache-hit semantics, real compiler stdout format) is only provable by a live push-to-main run — deferred to the OBS-04 baseline evidence in a later Phase 87 plan."

duration: 12min
completed: 2026-07-29
status: complete
---

# Phase 87 Plan 01: CI Observability Core + Lint Lane Tracer Summary

**Shared `obs-recompile.sh`/`obs-summary.sh` observability machinery proven offline against fixtures and wired end-to-end onto the `lint` lane (cache id, recompile probe, trailing summary step).**

## Performance

- **Duration:** 12 min
- **Started:** 2026-07-29T01:52:18Z
- **Completed:** 2026-07-29T01:59:42Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments

- `scripts/ci/obs-recompile.sh`: explicit, behavior-neutral `mix deps.compile` + `mix compile` probe that tees to `$RUNNER_TEMP` logs, sums `Compiling N files` via a `PIPESTATUS`-safe parse, and preserves the real compile exit code — correctly reports `0 0` on a fully warm cache and the fixture's known `260 260` on a cold one.
- `scripts/ci/obs-summary.sh`: generic cache-output classifier (EXACT HIT/PARTIAL/MISS via `compgen -e` + indirect `${!name}` expansion), a recompile-count table reader, and a REST `/jobs` step-timing renderer that degrades gracefully to a non-fatal `timing unavailable` row — all three tables accumulated into scratch files and written to `$GITHUB_STEP_SUMMARY` in a single consolidated append.
- `test/chimeway/ci_observability_contract_test.exs`: Wave 0 ExUnit contract (11 tests) proving both scripts offline via `System.cmd` against three committed fixtures, plus a lint-lane wiring assertion (`id: cache_main`, the `obs-recompile.sh` probe, and a trailing `if: always()` `obs-summary.sh` step that never gates `mix ci.lint`).
- `lint` lane in `.github/workflows/ci.yml` fully instrumented end-to-end: the existing cache step now carries `id: cache_main`, a new "Compile (instrumented — deps then app)" step runs `obs-recompile.sh` before `mix ci.lint`, and a trailing "CI observability summary" step (`if: always()`) wires `cache_main`'s outputs into `obs-summary.sh`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Create obs-recompile.sh + obs-summary.sh + three fixtures** - `83db6d2` (feat)
2. **Task 2: Create the Wave 0 contract test and instrument the lint lane end-to-end** - `7e9367f` (feat)

## Files Created/Modified

- `scripts/ci/obs-recompile.sh` - Explicit recompile probe; `set -uo pipefail` (no `-e`); `OBS_SKIP_COMPILE=1` test hook.
- `scripts/ci/obs-summary.sh` - Cache/recompile/timing table renderer; `set -euo pipefail`; `OBS_JOBS_JSON` test hook.
- `test/fixtures/ci/compile_cold.log` - Mixed deps/app `Compiling N files` lines summing to 260.
- `test/fixtures/ci/compile_warm.log` - No `Compiling` lines (proves the `0 0` warm path).
- `test/fixtures/ci/jobs_api_sample.json` - Minimal hand-trimmed `/jobs` REST response with 3 timed steps.
- `test/chimeway/ci_observability_contract_test.exs` - Wave 0 contract test (11 tests): recompile parser, cache classifier, timing renderer + fallback, secret hygiene, lint-lane wiring.
- `.github/workflows/ci.yml` - `lint` lane: `id: cache_main`, instrumented compile step, trailing observability summary step.
- `.gitignore` - Scoped exception for `test/fixtures/ci/*.log` (see Deviations).

## Decisions Made

- Kept `obs-recompile.sh` and `obs-summary.sh` as 2 scripts (not 3) with cache classification inlined in `obs-summary.sh`, per the phase research's resolved open question.
- `obs-recompile.sh` diverges from the repo's usual `set -euo pipefail` header idiom to `set -uo pipefail` (no `-e`) so a warm-cache grep miss never aborts the step, while still preserving the real `mix compile`/`mix deps.compile` exit code via explicit `${drc}`/`${arc}` checks at the end.
- Left the `install_golden_contract`-style conditional-step pitfall out of scope here — the `lint` lane has no `steps.detect.outputs.run` gate, so no extra `if:` guard was needed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added a scoped `.gitignore` exception for `test/fixtures/ci/*.log`**
- **Found during:** Task 1 (fixture creation)
- **Issue:** The repo's existing `*.log` gitignore rule silently excluded `test/fixtures/ci/compile_cold.log` and `compile_warm.log` from `git add`, which would have committed only 3 of the plan's 5 required fixture/script files with no visible error until a later `git status` audit.
- **Fix:** Added `!test/fixtures/ci/*.log` immediately after the `*.log` rule in `.gitignore`, with a comment naming the owning test file.
- **Files modified:** `.gitignore`
- **Verification:** `git add` + `git status --short` confirmed both `.log` fixtures staged as `A` after the fix.
- **Committed in:** `83db6d2` (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking).
**Impact on plan:** No scope change — purely a gitignore-hygiene fix required to actually commit the plan's declared fixture files. No scope creep.

## Issues Encountered

- The MISS-classification unit test initially passed `CACHE_MAIN_HIT`/`CACHE_MAIN_MATCHED` as empty strings (`""`) via `System.cmd`'s `env:` option. Elixir/Erlang's port-based env passing does not reliably export empty-string values to the child process on this platform (`compgen -e` never saw the var), so the test was rewritten to use a definite non-`"true"` value (`"false"`) for `CACHE_MAIN_HIT` and to simply omit `CACHE_MAIN_MATCHED` — the script's `${!name:-}` default handles the unset case identically to a real GitHub Actions empty output. No script code changed; this was a test-harness-only fix, verified by all 11 tests passing green.
- `mix format` reformatted one long `assert` line in the new test file to two lines on first `mix ci.lint`-equivalent check; re-ran the full test suite after formatting to confirm no regression (still 11/11 green).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for 87-02. The `scripts/ci/obs-recompile.sh` + `scripts/ci/obs-summary.sh` machinery and the ExUnit contract test scaffold (`extract_ci_job_block/2`, fixture-driven `System.cmd` helpers) are proven end-to-end on one representative lane offline; 87-02 can fan the identical `id:`/probe/trailing-summary pattern out to the remaining 13 build lanes with confidence. A live push-to-main run to visually confirm the three tables render on the actual GitHub-hosted runner (real `gh api` reachability, real compiler stdout, real cache hit/miss) remains outstanding and is the natural OBS-04 baseline-evidence checkpoint for a later plan in this phase.

## Self-Check: PASSED

- Found `scripts/ci/obs-recompile.sh` and `scripts/ci/obs-summary.sh`, both executable, both pass `bash -n`.
- Found `test/chimeway/ci_observability_contract_test.exs`; `mix test test/chimeway/ci_observability_contract_test.exs` — 11 tests, 0 failures.
- Found all three fixtures under `test/fixtures/ci/`.
- `grep -q "id: cache_main" .github/workflows/ci.yml` matches; lint lane's trailing observability summary step confirmed as the LAST step via contract test.
- Found task commits `83db6d2` and `7e9367f` in `git log --oneline`.
- No unexpected tracked-file deletions in either task commit (`git diff --diff-filter=D` empty for both).

---
*Phase: 87-ci-observability-cache-diagnostics*
*Completed: 2026-07-29*
