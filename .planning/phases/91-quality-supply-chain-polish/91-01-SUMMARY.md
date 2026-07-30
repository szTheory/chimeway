---
phase: 91-quality-supply-chain-polish
plan: 01
subsystem: infra
tags: [github-actions, ci, setup-beam, tool-versions, erlang, elixir, supply-chain]

requires:
  - phase: 90-pipeline-tiering-pr-main-nightly
    provides: resolve_tiers / nightly-gate tier architecture that this plan's converted jobs run inside unchanged

provides:
  - .tool-versions as the single canonical Erlang/Elixir toolchain source at repo root
  - All 14 single-pinned setup-beam jobs in ci.yml reading version-file + version-type strict
  - Verified exact-key strict-lookup format for erlef/setup-beam OTP resolution (patch + build suffix)

affects:
  - 91-02-dependabot-and-least-privilege-permissions
  - 91-03-mix-audit-and-ci-release-skew (test_floor_1_17 / ci-gate wiring — untouched here, D-03)

tech-stack:
  added: []
  patterns:
    - "erlef/setup-beam version-file: .tool-versions + version-type: strict (single toolchain source, replaces 14-way inline duplication)"

key-files:
  created:
    - .tool-versions
  modified:
    - .github/workflows/ci.yml

key-decisions:
  - "[91-01]: erlang pin is 27.3.4.15, not the research-documented 27.3.4 — setup-beam's strict-mode lookup is an exact map-key match against erlef's precompiled build tag (builds.hex.pm), which carries a 4th 'build' component beyond the OTP release patch. Verified against setup-beam source (src/setup-beam.js:508-557, getOTPVersions) and builds.hex.pm/builds/otp/amd64/ubuntu-24.04/builds.txt, and cross-checked against two live green main run logs (30512806893, 30524268555) that both resolved OTP-27.3.4.15."
  - "[91-01]: elixir pin 1.19.5-otp-27 matches research exactly — the elixir map key is the plain version string (no build suffix), confirmed against builds.hex.pm/builds/elixir/builds.txt."
  - "[91-01]: Task 1 tracer's checkpoint:human-verify (live CI proof) deferred per orchestrator's explicit critical_notes for this run — automated grep/actionlint verify blocks run in full; the live-runner backstop is recorded as pending below, not executed synchronously in this session."

requirements-completed: [QUAL-01]

coverage:
  - id: D1
    description: ".tool-versions created at repo root with full-patch strict pins reproducing today's resolved toolchain"
    requirement: "QUAL-01"
    verification:
      - kind: unit
        ref: "grep -qx 'erlang 27.3.4.15' .tool-versions && grep -qx 'elixir 1.19.5-otp-27' .tool-versions"
        status: pass
    human_judgment: false
  - id: D2
    description: "lint job (tracer) converted to version-file: .tool-versions + version-type: strict"
    requirement: "QUAL-01"
    verification:
      - kind: unit
        ref: "sed -n '/^  lint:/,/^  verify_gates:/p' .github/workflows/ci.yml | grep -q 'version-file: .tool-versions'"
        status: pass
    human_judgment: false
  - id: D3
    description: "Remaining 13 single-pinned setup-beam jobs converted to version-file + version-type: strict; exactly 14 pairs total"
    requirement: "QUAL-01"
    verification:
      - kind: unit
        ref: "grep -c 'version-file: .tool-versions' .github/workflows/ci.yml == 14; grep -c 'version-type: strict' .github/workflows/ci.yml == 14"
        status: pass
    human_judgment: false
  - id: D4
    description: "test matrix leg and test_floor_1_17 keep explicit pins (D-03); cache-key lines unchanged (D-04)"
    requirement: "QUAL-01"
    verification:
      - kind: unit
        ref: "diff shows exactly 26 changed lines (13 blocks x 2 lines); no cache-key line in the diff"
        status: pass
    human_judgment: false
  - id: D5
    description: "Every converted job's Setup BEAM step resolves Elixir 1.19.5 / Erlang OTP-27.3.4.15 identically on a real runner"
    requirement: "QUAL-01"
    verification: []
    human_judgment: true
    rationale: "Backstop is observable only in a live CI run; per this run's explicit orchestrator instruction, live-CI verification is deferred rather than triggered synchronously in this session. actionlint and all automated grep-based source checks pass, and the exact-key value was independently cross-verified against two live green main run logs plus the setup-beam source and builds.hex.pm listing, but the converted-block backstop itself has not yet been observed running end-to-end."

duration: 3 min
completed: 2026-07-30
status: complete
---

# Phase 91 Plan 01: Toolchain Source of Truth (QUAL-01 Tracer) Summary

**`.tool-versions` established as the single Erlang/Elixir source of truth; all 14 single-pinned `setup-beam` jobs converted to `version-file: .tool-versions` + `version-type: strict`, using the exact-key pin `erlang 27.3.4.15` (corrected from research's imprecise `27.3.4`) after verifying setup-beam's strict-lookup source and two live green `main` run logs.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-07-30T14:09:00Z (approx, first tool call)
- **Completed:** 2026-07-30T14:12:47Z
- **Tasks:** 2
- **Files modified:** 2 (1 created, 1 modified)

## Accomplishments

- Created `.tool-versions` at repo root with strict full-patch pins: `erlang 27.3.4.15`, `elixir 1.19.5-otp-27`.
- Converted the `lint` job's `setup-beam` block (the phase tracer) to `version-file:` + `version-type: strict`.
- Fanned out the identical conversion to all 13 remaining single-pinned jobs (`verify_gates`, `verify_docs`, `verify_example`, `verify_runtime_prefix`, `verify_journeys`, `verify_mailglass`, `verify_accrue`, `verify_inbox`, `verify_threadline`, `verify_sigra`, `verify_admin`, `install_golden_contract`, `nightly_cold_build`) — exactly 14 `version-file`/`version-type: strict` pairs now exist in `ci.yml`.
- Left the `test` matrix leg (`matrix.elixir`/`matrix.otp`) and `test_floor_1_17` (pinned `1.17`) untouched (D-03); no cache-key line was edited (D-04).
- `actionlint .github/workflows/ci.yml` exits 0.

## Task Commits

Each task was committed atomically:

1. **Task 1: Create .tool-versions and convert the `lint` job (end-to-end tracer)** - `86edab6` (feat)
2. **Task 2: Fan out — convert the remaining 13 single-pinned jobs** - `8f010ed` (feat)

_Note: no plan-metadata-only commit yet; STATE.md/ROADMAP.md/SUMMARY.md land in the final docs commit below._

## Files Created/Modified

- `.tool-versions` - New repo-root file, the single canonical toolchain source (`erlang 27.3.4.15`, `elixir 1.19.5-otp-27`).
- `.github/workflows/ci.yml` - 14 `setup-beam` blocks converted from inline `elixir-version`/`otp-version` pins to `version-file: .tool-versions` + `version-type: strict`; `test` matrix and `test_floor_1_17` legs and all cache-key lines left byte-for-byte unchanged.

## Decisions Made

- **Corrected the exact-key pin from research's `erlang 27.3.4` to `erlang 27.3.4.15`.** Research documented `27.3.4` as the resolved OTP version; live re-verification (per the plan's explicit "re-capture from the latest green main run" instruction) showed the actually-installed build tag on both a 2026-07-30T04:03 and a 2026-07-30T07:50 green `main` run is `OTP-27.3.4.15`. Reading `erlef/setup-beam`'s source confirmed strict-mode OTP resolution is a direct `versions0[spec]` map lookup keyed on the exact build tag from `builds.hex.pm/builds/otp/.../builds.txt` (erlef's precompiled OTP builds append a 4th "build" component beyond the 3-part OTP release version — e.g. `OTP-27.3.4.15` was published 2026-07-27, superseding `OTP-27.3.4` from 2025-05-09). Pinning the research's `27.3.4` would have hard-failed every converted job's Setup BEAM step with "Requested strict Erlang/OTP version (27.3.4) not found in version list" (Pitfall 1, exactly as the research warned, just with a more precise real-world value than research had at hand).
- Kept the `elixir 1.19.5-otp-27` pin exactly as researched — its map key format (bare version string, no build suffix) was independently confirmed against `builds.hex.pm/builds/elixir/builds.txt` and matched what both live runs logged (`Using Elixir 1.19.5 (built for Erlang/OTP 27)`).
- Followed the plan's tracer-feedback-gate override for this run: rather than pausing after Task 1 for an interactive `checkpoint:human-verify` on a live CI push, executed both tasks straight through per the orchestrator's explicit critical_notes instruction, running only the automated grep/actionlint verify blocks and recording the live-runner backstop as pending (see Known Stubs below).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected `.tool-versions` erlang pin from `27.3.4` to `27.3.4.15`**
- **Found during:** Task 1 (Create .tool-versions and convert the `lint` job)
- **Issue:** The plan and RESEARCH.md documented `erlang 27.3.4` as the strict-mode pin. Re-verification against `erlef/setup-beam`'s source (`getOTPVersion`/`getVersionFromSpec`, exact map-key lookup under `version-type: strict`) and `builds.hex.pm`'s live builds listing showed the correct exact key is `27.3.4.15` — using `27.3.4` would have hard-failed every converted job at the Setup BEAM step with "not found in version list" (exactly the Pitfall 1 failure mode the research flagged, just with a staler value than the live listing now shows).
- **Fix:** Wrote `.tool-versions` with `erlang 27.3.4.15`, cross-verified against two independent live green `main` run logs (30512806893 at 04:03 UTC and 30524268555 at 07:50 UTC, both same day) that both resolved `Installing Erlang/OTP OTP-27.3.4.15`.
- **Files modified:** `.tool-versions`
- **Verification:** `grep -qx 'erlang 27.3.4.15' .tool-versions` passes; `actionlint .github/workflows/ci.yml` exits 0; the plan's own acceptance criteria explicitly permit "the exact strings re-captured from the latest green main run" as an alternative to the literal `27.3.4` text.
- **Committed in:** `86edab6` (Task 1 commit)

**2. [Rule 3 - Blocking, tooling quirk, no file change] `ugrep`'s BRE handling of `${{ matrix.elixir }}` required a fixed-string re-check**
- **Found during:** Task 2 self-verification
- **Issue:** The plan's own `<verify>` command for Task 2 includes `grep -q 'elixir-version: ${{ matrix.elixir }}' .github/workflows/ci.yml`. In this environment `grep` resolves to `ugrep`, whose basic-regex handling of the literal `{{ }}` sequence does not match even though the exact substring is present in the file (confirmed via `grep -F` fixed-string match and an escaped-ERE match, both of which passed). This is a local tool-flavor artifact of the verify command, not a defect in the converted file.
- **Fix:** No file change — re-verified the matrix leg is byte-for-byte untouched via `grep -F` and `sed -n '234p' | od -c`, and via `git diff --stat` showing exactly 26 changed lines (13 blocks × 2 lines) with zero cache-key lines touched.
- **Files modified:** none
- **Verification:** `grep -F 'elixir-version: ${{ matrix.elixir }}' .github/workflows/ci.yml` passes; `git diff .github/workflows/ci.yml | grep -c '^-'` / `'^+'` both equal 27 (26 content lines + 1 diff-header line each), matching exactly 13 converted blocks.
- **Committed in:** n/a (verification-only; no code changed)

---

**Total deviations:** 2 (1 auto-fixed correctness bug, 1 verification-tooling note with no code impact)
**Impact on plan:** The erlang-pin correction is essential — without it the entire phase tracer would fail on first live CI run. No scope creep; both fixes stayed within the plan's declared `files_modified`.

## Issues Encountered

None beyond the deviations documented above.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `.tool-versions` is now the canonical toolchain source for Plans 91-02 and 91-03 to build on (dependabot config, permissions, mix_audit, and the QUAL-05 gate wiring all sit alongside this file/job set without touching it further).
- **Pending live verification (backstop, QUAL-01):** a real CI run (push or dispatch) has not yet been observed against these commits. Per this plan's `<verify><human-check>`, the phase gate for QUAL-01 requires confirming every converted job's Setup BEAM step logs `Elixir 1.19.5` / `Erlang/OTP 27.3.4.15` identically, and that the `test` matrix + `test_floor_1_17` legs still run their non-canonical versions. Recommend triggering this before or alongside the Plan 91-03 phase-gate push (which also needs a live run for QUAL-05's floor-gating wiring), so both backstops are covered by a single push.

## Known Stubs

- **Backstop verification (D5 above): live-CI proof of identical toolchain resolution across all 14 converted jobs.** Not yet observed running end-to-end in this session (deferred per explicit orchestrator instruction for this run — see Decisions Made). All source-level and static (`actionlint`) checks pass; the runtime confirmation is the only remaining unverified claim. Should resolve automatically on the next push/dispatch CI run once Plans 91-02/91-03 land, or can be triggered standalone.

## Self-Check: PASSED

- FOUND: `.tool-versions`
- FOUND: `.planning/phases/91-quality-supply-chain-polish/91-01-SUMMARY.md`
- FOUND: commit `86edab6` (Task 1)
- FOUND: commit `8f010ed` (Task 2)
- WINDOWS.md ledger entry #1 recorded for the pending live-CI backstop (unrun-verify, phase 91).

---
*Phase: 91-quality-supply-chain-polish*
*Completed: 2026-07-30*
