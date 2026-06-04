---
phase: 67-close-ecos-09-repin-sigra-ci-sha-harden-verify-lanes-against
plan: 03
subsystem: ci
tags:
  - clean-ci
  - verification
  - planning-reconciliation
requires:
  - 67-01
  - 67-02
provides:
  - ECOS-09 clean-CI binding proof
  - Phase 67 closeout
affects:
  - .github/workflows/ci.yml
  - mix.exs
  - test/test_helper.exs
  - test/support/sigra/ci_proof_runner.exs
  - test/chimeway/release_gate_contract_test.exs
  - .planning/phases/64-sigra-auth-flows-core/64-VERIFICATION.md
  - .planning/phases/64-sigra-auth-flows-core/64-VALIDATION.md
  - .planning/ROADMAP.md
  - .planning/STATE.md
metrics:
  completed_date: "2026-06-04"
---

# Phase 67 Plan 03: Clean-CI Sigra Proof and ECOS-09 Closeout Summary

## Work Completed

- Captured the binding clean-CI proof for ECOS-09 in GitHub Actions:
  - CI run `26925122158`
  - Sigra job `79433504716`
  - Commit `51dba6587294453ee279af70ba48749e54b983f0`
  - `szTheory/sigra@62ceb46a38c4e617f6c06d874ecb12e1ab19d97c`
- Confirmed root Sigra proof lane passed with `6 tests, 0 failures`.
- Confirmed demo-host Sigra proof lane passed with `2 tests, 0 failures`.
- Replaced the generic Phase 64 verification note with a concrete `64-VERIFICATION.md` record citing run/job IDs, exact counts, and redaction assertions.
- Kept `64-02-SUMMARY.md` tracked and corrected the previously untracked `67-02-SUMMARY.md` metadata.
- Reconciled Phase 67 roadmap/state tracking to complete after the CI proof.

## CI Hardening Added During Monitoring

The first clean-CI attempts exposed runner-specific failure modes that local `mix verify.sigra` did not catch. The final lane now:

- Runs the root Sigra proof through a checked `elixir` runner instead of `mix run`, avoiding Mix app-start hangs before ExUnit starts.
- Starts `:plug_crypto` for the manual root proof path so Sigra token signing has its ETS cache.
- Loads test config explicitly in `test/support/sigra/ci_proof_runner.exs`.
- Skips unrelated partner repo bootstraps during the forced root Sigra proof.
- Splits demo-host proof dependency resolution from Chimeway's optional Sigra/Mailglass transitive deps to avoid CI-only dependency cycles.
- Explicitly compiles the demo host before the bounded `--no-compile` proof test.

## Verification

- Local root proof:
  - `env CHIMEWAY_FORCE_SIGRA_TEST_REPO_SETUP=1 CHIMEWAY_MANUAL_REPO_START=1 CHIMEWAY_SKIP_OBAN=1 CHIMEWAY_SKIP_THREADLINE_DEP=1 CHIMEWAY_SKIP_ACCRUE_DEP=1 SIGRA_PATH=deps/sigra MIX_ENV=test timeout 300s elixir $(find _build/test/lib -type d -name ebin -print | sed 's/^/-pa /') test/support/sigra/ci_proof_runner.exs`
  - Result: `6 tests, 0 failures`
- Local demo-host proof after clean build:
  - `mix deps.get && timeout 600s mix deps.compile && timeout 300s mix compile && timeout 300s mix test --no-compile test/demo_host_web/sigra_auth_proof_test.exs --only sigra --warnings-as-errors --trace`
  - Result: `2 tests, 0 failures`
- Release contract:
  - `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors`
  - Result: `40 tests, 0 failures`
- Whitespace:
  - `git diff --check`
  - Result: clean
- Clean CI:
  - `Sigra auth integration gate` job `79433504716`
  - Result: success
  - Counts: root `6 tests, 0 failures`; demo `2 tests, 0 failures`

## Deviations from Plan

- The original checkpoint expected the existing `mix verify.sigra` shape to be enough. CI showed Mix could block before the root proof runner and that the demo-host lane needed explicit dependency-cycle guards and project compilation. These were fixed in Plan 03 because they were necessary to produce the binding clean-CI proof.
- Broader CI still has unrelated red lanes in run `26925122158`; the Phase 67 blocking requirement was specifically the `Sigra auth integration gate` job with non-vacuous counts, which is green.

## Self-Check: PASSED
