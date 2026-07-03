---
phase: 78-release-and-package-truth
plan: "03"
subsystem: release-and-package-truth
tags: [elixir, hex, hex-build, release-gate, contract-tests, package-artifact, sigra, mix-env]

# Dependency graph
requires:
  - phase: 77-truth-baseline-and-package-model-decision
    provides: root-only package model decision
  - phase: 78-release-and-package-truth
    provides: 78-01 root package/source truth and 78-02 sibling preview/path guide truth
provides:
  - Default (MIX_ENV=prod) mix hex.build --unpack succeeds without Sigra skip envs
  - Env-conditional Sigra override (dev/test only) so dev resolution and Hex builds coexist
  - Unpacked Hex package artifact contracts asserting whitelist roots, canonical source links, and sibling preview/path status
  - verify.parity alias that builds+unpacks the prod package and proves the whitelist locally
  - release.yml / publish-hex.yml build+publish steps pinned to MIX_ENV=prod
affects:
  - phase-79-front-door-docs-truth

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Env-conditional dependency override (override: true only when Mix.env() != :prod) to keep dev resolution while allowing Hex package builds
    - ExUnit artifact proof via System.cmd("mix", ["hex.build","--unpack",...], env: MIX_ENV=prod) with unique temp dir + on_exit cleanup
    - Version-tolerant unpacked-root resolution (output dir or single chimeway-* child)

key-files:
  created:
    - .planning/phases/78-release-and-package-truth/78-03-SUMMARY.md
  modified:
    - mix.exs
    - test/chimeway/release_gate_contract_test.exs
    - .github/workflows/release.yml
    - .github/workflows/publish-hex.yml

key-decisions:
  - "[78-03]: Option A (env-conditional Sigra override) chosen over a sigra ~> 1.0 version bump — lowest blast, preserves sigra ~> 0.3 and opt-out skip envs, keeps the package publishable. Coordinator-approved after Rule 4 checkpoint."
  - "[78-03]: The Hex package build runs under MIX_ENV=prod (verify.parity, the artifact test's System.cmd, and both publish workflows) so the dev/test-only override is absent and Hex accepts the build."
  - "[78-03]: Artifact whitelist contract ignores Hex-generated hex_metadata.config and otherwise requires the root to equal the mix.exs files whitelist exactly, so stray additions also fail the gate."

requirements-completed: [TRUTH-01, TRUTH-02, TRUTH-03]

# Metrics
duration: ~30 min (incl. Rule 4 dependency-architecture checkpoint)
completed: 2026-07-03
tasks: 2
files: 4
status: complete
---

# Phase 78 Plan 03: Package Artifact Truth Summary

**The root Hex package now builds and unpacks deterministically: an env-conditional Sigra override lets dev/test resolution coexist with a Hex-legal package build under MIX_ENV=prod, and `Chimeway.ReleaseGateContractTest` plus `mix verify.parity` prove the unpacked artifact carries the package whitelist, canonical source links, and sibling preview/path status.**

## Performance

- **Duration:** ~30 min (including a Rule 4 dependency-architecture checkpoint and coordinator decision)
- **Completed:** 2026-07-03
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Made `sigra_dep/0`'s `override: true` conditional on `Mix.env() != :prod` (both the `~> 0.3` Hex branch and the `SIGRA_PATH` path branch), keeping `optional: true` and `runtime: false` on both. Dev/test keep the override needed to co-resolve root `sigra ~> 0.3` with `mailglass`'s `sigra ~> 1.0`; the prod package omits it so `mix hex.build` no longer fails with `Can't build package with overridden dependency sigra`.
- Preserved `sigra_deps/0` skip-env behavior (`CHIMEWAY_SKIP_SIGRA_DEP`, `CHIMEWAY_SKIP_SIGRA_TRANSITIVE_DEP`) unchanged.
- Added two artifact contracts to `Chimeway.ReleaseGateContractTest` with helpers `build_unpacked_package!/0` (runs `System.cmd("mix", ["hex.build","--unpack",...], env: [{"MIX_ENV","prod"}])` into a unique temp dir with `on_exit` cleanup), `unpacked_package_root!/1` (tolerant of both output-dir and `chimeway-*` child shapes), and `top_level_entries/1`.
  - `unpacked Hex package contains the package file whitelist`: asserts the root carries every `files: ~w(lib priv guides CHANGELOG.md LICENSE.md README.md mix.exs .formatter.exs)` entry and nothing outside it (ignoring Hex's generated `hex_metadata.config`).
  - `unpacked Hex package carries package truth docs and source links`: reads unpacked `mix.exs`, `README.md`, and both sibling guides, asserting the canonical `https://github.com/szTheory/chimeway` links (and rejecting the legacy owner), the `{:chimeway, "~> 1.0"}` install constraint, and admin/inbox `in-repo preview/path package` + `not published on Hex yet` status.
- Rewrote the `verify.parity` alias to `cmd --shell env MIX_ENV=prod mix hex.build --unpack --output /tmp/chimeway_verify` (after removing the prior dir), resolve the unpacked root, and fail unless it contains all whitelist entries. No Sigra skip envs, no live Hex API calls.
- Pinned the `mix hex.build` / `mix hex.publish` (dry-run + real) steps in `release.yml` and `publish-hex.yml` to `MIX_ENV=prod` so CI/publish builds omit the override exactly as the local proof does.

## Task Commits

Each task was committed atomically:

1. **Task 1: Scope Sigra override to non-prod so default Hex build succeeds** - `b547ec1` (fix)
2. **Task 2: Prove unpacked Hex package artifact truth (D-08)** - `0861b9d` (test)

## Files Created/Modified

- `mix.exs` - `sigra_dep/0` env-conditional override; `verify.parity` alias rewritten to a prod build + whitelist assertion.
- `test/chimeway/release_gate_contract_test.exs` - New describe block with two unpacked-artifact contracts and three helpers.
- `.github/workflows/release.yml` - `MIX_ENV: prod` added to Build/Dry-run/Publish steps.
- `.github/workflows/publish-hex.yml` - `MIX_ENV: prod` added to Build/Dry-run/Publish steps.
- `.planning/phases/78-release-and-package-truth/78-03-SUMMARY.md` - This summary.

## Decisions Made

- **Option A (env-conditional override)** was selected after a Rule 4 checkpoint. The plan-as-written (unconditionally remove `override: true`) is internally contradictory given the current dependency graph: removing the override makes `mix hex.build` succeed but makes `mix deps.get` fail everywhere (root `sigra ~> 0.3` vs the locked `mailglass 1.3.0 → sigra ~> 1.0`, non-overlapping ranges). Option A preserves `sigra ~> 0.3`, avoids a lockfile-churning/security-advisory-flagged `sigra ~> 1.0` bump, and keeps the package publishable. Coordinator approved Option A as the lowest-blast, fully-reversible path.
- Hex package builds run under `MIX_ENV=prod` (the conventional package-build env), which is not a skip env; the D-08 "succeeds without `CHIMEWAY_SKIP_SIGRA_DEP`" truth is honored.
- The whitelist contract ignores only Hex's generated `hex_metadata.config` and otherwise requires an exact match, so both omissions and stray additions fail the gate.

## Deviations from Plan

### Auto-fixed / approach adjustments

**1. [Rule 4 - Architectural, coordinator-approved] Env-conditional override instead of unconditional removal**
- **Found during:** Task 1
- **Issue:** The plan instructed removing `override: true` outright. Verified empirically that this fixes `mix hex.build` but breaks `mix deps.get` for local dev, CI `test`, CI `verify_gates` (which runs this very test), and the release/publish workflows' `mix deps.get` — because `mailglass 1.3.0` (locked) requires `sigra ~> 1.0` while root requires `sigra ~> 0.3` (non-overlapping; the override was load-bearing).
- **Fix:** Scoped `override: true` to `Mix.env() != :prod`; the prod package build omits it.
- **Files modified:** `mix.exs`
- **Commit:** `b547ec1`

**2. [Rule 3 - Blocking, forced by Deviation 1] Build/publish steps pinned to MIX_ENV=prod**
- **Found during:** Task 2
- **Issue:** With the override present in default (dev) env, `mix hex.build` still fails; the artifact proof and CI/publish builds must run in the env where the override is absent.
- **Fix:** The artifact test's `System.cmd` build, the `verify.parity` alias, and the `hex.build`/`hex.publish` steps in `release.yml` and `publish-hex.yml` all run under `MIX_ENV=prod`. Workflow edits are minimal (env-only on the build/publish steps; no restructuring).
- **Files modified:** `test/chimeway/release_gate_contract_test.exs`, `mix.exs`, `.github/workflows/release.yml`, `.github/workflows/publish-hex.yml`
- **Commit:** `0861b9d`

**3. [Rule 1 - Bug] List-subtraction precedence in the whitelist contract**
- **Found during:** Task 2
- **Issue:** `entries -- whitelist -- ["hex_metadata.config"]` parsed as `entries -- (whitelist -- [...])` (`--` is right-associative), leaving `hex_metadata.config` in `extra` and failing the test spuriously.
- **Fix:** Added explicit parens: `(entries -- whitelist) -- ["hex_metadata.config"]`. Also changed `setup_all` (illegal inside a `describe`) to `setup`.
- **Files modified:** `test/chimeway/release_gate_contract_test.exs`
- **Commit:** `0861b9d`

**Total deviations:** 1 architectural (coordinator-approved), 1 blocking (forced), 1 bug.
**Impact on plan:** No scope change to the deliverables. The dependency-resolution approach adjusted from "remove override" to "scope override to non-prod + build in prod"; all plan success criteria are met (with the package build under `MIX_ENV=prod`).

## Verification

- PASS: `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors` → 55 tests, 0 failures.
- PASS: `mix verify.parity` → exit 0 (`verify.parity OK: unpacked package root /tmp/chimeway_verify contains all whitelist entries`).
- PASS: `mix ci.verify_gates` → 493 tests, 0 failures.
- PASS: `mix ci.docs` → exit 0.
- PASS: `mix format --check-formatted mix.exs test/chimeway/release_gate_contract_test.exs` → exit 0.
- PASS: `mix deps.get` resolves in dev; `MIX_ENV=prod mix hex.build --unpack` exits 0 without any Sigra skip env.

## Threat Mitigations Applied

- **T-78-09 (DoS, mix hex.build):** The default (prod) package build succeeds; the override blocker is removed from the build path.
- **T-78-10 (Tampering, package whitelist):** ExUnit artifact contract + `verify.parity` assert the unpacked root equals the mix.exs whitelist (ignoring `hex_metadata.config`).
- **T-78-11 (Spoofing, source links):** Artifact contract reads the unpacked `mix.exs`/`README.md` and requires `https://github.com/szTheory/chimeway`, rejecting the legacy owner.
- **T-78-12 (Spoofing, sibling guide status):** Artifact contract reads the unpacked admin/inbox guides and requires preview/path status with no current-Hex install claim.
- **T-78-13 (Info Disclosure, publish creds):** The artifact proof uses `mix hex.build --unpack` only; it never sets or prints `HEX_API_KEY`.

## Known Stubs

None. Stub-pattern scan of the modified files found no placeholder/TODO/FIXME or runtime/UI stub content.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for Phase 79 (front-door docs truth). The root Hex package is now provably buildable and its public-truth files are contract-locked in the unpacked artifact. Note for maintainers: the Sigra override is intentionally env-scoped — the Hex package build must run under `MIX_ENV=prod`, which the `verify.parity` alias and both publish workflows now do.

## Self-Check: PASSED

- Found modified files: `mix.exs`, `test/chimeway/release_gate_contract_test.exs`, `.github/workflows/release.yml`, `.github/workflows/publish-hex.yml`.
- Found task commits: `b547ec1` (fix), `0861b9d` (test).
- Verified `MIX_ENV=prod mix hex.build --unpack` exits 0 and `mix deps.get` resolves in dev.
- No tracked file deletions were introduced by the plan commits.

---
*Phase: 78-release-and-package-truth*
*Completed: 2026-07-03*
