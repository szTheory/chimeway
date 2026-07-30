---
phase: 91-quality-supply-chain-polish
plan: 02
subsystem: infra
tags: [dependabot, github-actions, mix, hex, mix_audit, supply-chain, ci]

requires:
  - phase: 91-quality-supply-chain-polish
    provides: 91-01 .tool-versions toolchain single-source (parallel, independent files)
provides:
  - .github/dependabot.yml — weekly grouped update PRs for mix + github-actions ecosystems
  - mix_audit dev/test dep resolved in mix.lock, providing `mix deps.audit`
  - ci.audit alias extended to run hex.audit + deps.audit (still advisory-only)
affects:
  - phase-91-quality-supply-chain-polish (91-03, if it exists, or phase gate)
  - future dependency-update PR review workflow (Dependabot will start opening PRs weekly)

tech-stack:
  added: ["mix_audit ~> 2.1 (2.1.5)"]
  patterns:
    - "Dependabot version: 2 config with groups.<name>.update-types: [minor, patch] to collapse noise per ecosystem"
    - "Advisory-only CI audit step composition: alias chains hex.audit (retired pkgs) + deps.audit (CVE scan), CI step keeps continue-on-error: true"

key-files:
  created:
    - .github/dependabot.yml
    - .planning/phases/91-quality-supply-chain-polish/91-02-SUMMARY.md
  modified:
    - mix.exs
    - mix.lock

key-decisions:
  - "[91-02]: mix_audit `~> 2.1` confirmed current (resolves 2.1.5, verified via `mix hex.info mix_audit` at execute time) — no bound change needed."
  - "[91-02]: Dependabot cosmetics (open-PR limit, commit-message prefix, labels) left at defaults — plan flagged these as Claude's Discretion and minimal/readable was preferred."
  - "[91-02]: CI advisory-audit step (ci.yml:97-98, continue-on-error: true) verified read-only, untouched — D-12 advisory-only posture preserved."

patterns-established:
  - "Dependabot groups: block with update-types only (no patterns) collapses all minor/patch per ecosystem into one weekly PR."

requirements-completed: [QUAL-02, QUAL-04]

coverage:
  - id: D1
    description: ".github/dependabot.yml configures weekly grouped update PRs for the mix and github-actions ecosystems"
    requirement: "QUAL-02"
    verification:
      - kind: other
        ref: "grep -q 'version: 2' .github/dependabot.yml && grep -q 'package-ecosystem: \"mix\"' .github/dependabot.yml && grep -q 'package-ecosystem: \"github-actions\"' .github/dependabot.yml && grep -q 'interval: \"weekly\"' .github/dependabot.yml && python3 -c \"import yaml; yaml.safe_load(open('.github/dependabot.yml'))\""
        status: pass
    human_judgment: true
    rationale: "The config-parse backstop (GitHub Insights -> Dependency graph -> Dependabot showing both ecosystems parsed with no error) is only observable in a live GitHub run post-push; recorded in .planning/WINDOWS.md as unrun-verify entry #2."
  - id: D2
    description: "mix_audit ~> 2.1 dev/test dep resolved in mix.lock; mix deps.audit task available"
    requirement: "QUAL-04"
    verification:
      - kind: other
        ref: "grep -q ':mix_audit' mix.exs && grep -q 'mix_audit' mix.lock && mix help deps.audit"
        status: pass
    human_judgment: false
  - id: D3
    description: "ci.audit alias extended to [\"hex.audit\", \"deps.audit\"]; CI advisory step unchanged and still continue-on-error: true"
    requirement: "QUAL-04"
    verification:
      - kind: other
        ref: "grep -q '\"ci.audit\": \\[\"hex.audit\", \"deps.audit\"\\]' mix.exs && grep -n 'continue-on-error' .github/workflows/ci.yml"
        status: pass
    human_judgment: true
    rationale: "The CI backstop (lint job's advisory-audit step actually running both audits and staying green even with findings) is only observable in a live CI run; recorded in .planning/WINDOWS.md as unrun-verify entry #3."

duration: 8min
completed: 2026-07-30
status: complete
---

# Phase 91 Plan 02: Dependabot + mix_audit Advisory Scan Summary

**Native Dependabot PRs for mix + github-actions ecosystems, plus a real CVE-advisory-DB scan (`mix deps.audit` via mix_audit 2.1.5) layered onto the existing advisory-only `hex.audit` step with `continue-on-error: true` left fully intact.**

## Performance

- **Duration:** 8 min
- **Started:** 2026-07-30T14:17:00Z (approx.)
- **Completed:** 2026-07-30T14:19:07Z
- **Tasks:** 2
- **Files modified:** 3 (`.github/dependabot.yml` new, `mix.exs`, `mix.lock`)

## Accomplishments

- Added `.github/dependabot.yml` (`version: 2`) covering the `mix` and `github-actions` ecosystems, both `directory: "/"`, weekly schedule, grouped minor/patch (D-05/D-06).
- Added `{:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false}` to `mix.exs` deps and resolved it (2.1.5) plus its transitive `yaml_elixir`/`yamerl` into `mix.lock` via `mix deps.get` (D-10).
- Extended the `ci.audit` alias from `["hex.audit"]` to `["hex.audit", "deps.audit"]` (D-11), confirmed `mix ci.audit` now runs both scans and surfaces real findings.
- Confirmed the CI "Dependency advisory audit" step (`ci.yml:97-98`) is unchanged and still carries `continue-on-error: true` — advisory-only posture preserved (D-12).

## Task Commits

Each task was committed atomically:

1. **Task 1: Add .github/dependabot.yml (mix + github-actions)** - `8c7aef0` (feat)
2. **Task 2: Add mix_audit dep + extend the ci.audit alias** - `4c039a5` (feat)

_Note: no TDD tasks in this plan — both tasks are `tdd="false"` config/dependency edits._

## Files Created/Modified

- `.github/dependabot.yml` - New: `version: 2`, `mix` + `github-actions` ecosystems, weekly, grouped minor/patch.
- `mix.exs` - Added `mix_audit` dep tuple; extended `ci.audit` alias to include `deps.audit`.
- `mix.lock` - Resolved `mix_audit` 2.1.5 + transitive `yaml_elixir` 2.12.2 / `yamerl` 0.10.0.

## Decisions Made

- Kept Dependabot cosmetics (PR limits, commit-message prefixes, labels) at defaults per Claude's Discretion — plan explicitly called these out as non-blocking and preferred minimal/readable config.
- Confirmed `~> 2.1` for `mix_audit` is still current (`mix hex.info mix_audit` shows 2.1.5 as latest) — no bound change needed, matching the RESEARCH assumption.
- Did not touch `.github/workflows/ci.yml` in this plan — only read-verified its advisory step remains `continue-on-error: true`, per the plan's explicit prohibition and the note that 91-01 already owns that file this phase.

## Deviations from Plan

None - plan executed exactly as written. No Rule 1-4 triggers encountered; both tasks matched their `<action>` blocks precisely.

## Issues Encountered

- `mix deps.get` (Hex's own built-in advisory scanner, unrelated to `mix_audit`) printed "Found packages with security advisories" for pre-existing transitive deps (`hackney` 1.25.0, `decimal` 2.4.1) not touched by this plan. This is out of scope per the SCOPE BOUNDARY rule (pre-existing, not caused by this task's changes) — not fixed, not a deviation. It corroborates that `mix_audit`/`deps.audit` will have real, non-trivial findings to report once wired into CI, which is the intended QUAL-04 behavior.
- Initial `mix help deps.audit` returned "task could not be found" until `mix deps.compile yaml_elixir mix_audit` ran — dependency-provided Mix tasks require compilation before they're discoverable via `mix help`. Resolved locally (compile step, not a code change); `mix.lock` itself was unaffected by this discovery step.

## User Setup Required

None - no external service configuration required. Dependabot activates automatically on push (GitHub-native, reads `.github/dependabot.yml` from the default branch).

## Next Phase Readiness

QUAL-02 and QUAL-04 are structurally satisfied and locally verified. Two backstops remain open in `.planning/WINDOWS.md` (unrun-verify, pending a live push/CI run — not executable from this sandbox):

1. Dependabot config-parse backstop — GitHub Insights → Dependency graph → Dependabot should list both `mix` and `github-actions` ecosystems with no config error.
2. CI advisory-audit step backstop — the `lint` job's step should run `hex.audit` + `deps.audit`, print findings (confirmed locally findings exist: hackney/decimal CVEs), and the gate should stay green due to `continue-on-error: true`.

Both are expected to pass given: (a) the dependabot.yml is valid YAML matching the documented v2 schema exactly, and (b) `mix ci.audit` was run locally and confirmed to execute both audits, print findings, and exit non-zero — the exact case `continue-on-error: true` is designed to absorb. Ready for phase-level integration/push verification alongside 91-01's and 91-03's (if any) backstops.

## Self-Check: PASSED

- FOUND: `.github/dependabot.yml`
- FOUND: `mix.exs` contains `:mix_audit` dep tuple and extended `ci.audit` alias
- FOUND: `mix.lock` contains `mix_audit` entry (2.1.5)
- FOUND commit `8c7aef0` (Task 1) in `git log --oneline --all`
- FOUND commit `4c039a5` (Task 2) in `git log --oneline --all`
- No unexpected file deletions in either task commit (both were pure additions).

---
*Phase: 91-quality-supply-chain-polish*
*Completed: 2026-07-30*
