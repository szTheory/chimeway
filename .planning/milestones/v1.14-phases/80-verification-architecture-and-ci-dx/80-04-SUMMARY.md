---
phase: 80-verification-architecture-and-ci-dx
plan: 04
subsystem: ci-dx
tags: [docs, contributing, maintaining, branch-protection, ruleset, ci-topology]
requires:
  - phase: 80-verification-architecture-and-ci-dx
    provides: two-aggregate pr-gate/ci-gate topology (80-01) + cache cost centers (80-02) + scripts/ci extraction (80-03)
provides:
  - CONTRIBUTING.md pr-gate fast-feedback story + scripts/ci local-repro pointer + canonical clone URL
  - MAINTAINING.md pr-gate/ci-gate split, D-08 branch-protection operator step, scripts/ci note, corrected Sigra ref
  - D-08 realized — main branch gated on pr-gate via GitHub ruleset id 18486746
affects: []
tech-stack:
  added: []
  patterns:
    - Docs describe the two-aggregate topology in lockstep with ci.yml; contract-asserted pre-ship copy preserved
    - Branch protection realized as a GitHub repository ruleset (not a classic rule) requiring the pr-gate status check
key-files:
  created:
    - .planning/phases/80-verification-architecture-and-ci-dx/80-04-SUMMARY.md
  modified:
    - CONTRIBUTING.md
    - MAINTAINING.md
decisions:
  - "[80-04]: D-08 realized as a NEW ruleset (id 18486746, 'main: require pr-gate') rather than a swap — main had no prior branch protection, so there was never a ci-gate strand to remediate"
  - "[80-04]: Sigra sibling-checkout ref corrected b186f03->62ceb46a to match the ci.yml pin (D-13 opportunistic drift fix)"
  - "[80-04]: install_golden_contract gating doc reconciled to push+dispatch-only (D-04); false 'on PRs' claim and 'Do not change that gating behavior' directive removed; path-gated detect-step copy preserved"
metrics:
  duration: 12 min
  completed: 2026-07-03
  tasks: 3
  files_modified: 2
requirements-completed: []
status: complete
---

# Phase 80 Plan 04: Gate Docs Alignment + D-08 Branch Protection Summary

**Aligned CONTRIBUTING.md and MAINTAINING.md with the two-aggregate `pr-gate`/`ci-gate` topology (fast PR feedback vs. release/publish/automerge/recovery source of truth), pointed both at the `scripts/ci/*.sh` local-repro helpers, corrected the drifted Sigra sibling-checkout ref, reconciled the installer-gating copy to push+dispatch-only, and realized D-08 — `main` is now gated on the `pr-gate` required check via a GitHub repository ruleset.**

## Performance

- **Duration:** ~12 min (spanning the human-action checkpoint)
- **Started:** 2026-07-03T16:44Z
- **Completed:** 2026-07-03
- **Tasks:** 3 (2 doc-writing + 1 operator branch-protection action)
- **Files modified:** 2

## Accomplishments

- **CONTRIBUTING.md (Task 1, `2d8d16b`):** added a "What runs on your PR" section explaining that the required PR check is the fast `pr-gate` aggregate (lint + test + `mix ci.verify_gates` + `mix ci.docs`) which mirrors local `mix ci`, while the full `ci-gate` (all lanes incl. ecosystem integrations) runs on push-to-`main` / release dispatch. Added a `scripts/ci/*.sh` table (`detect-installer-changes.sh`, `aggregate-gate.sh`, `sigra-proof.sh`) for local reproduction. Fixed the clone URL from the legacy `github.com/jonlunsford/chimeway` to the canonical `github.com/szTheory/chimeway`.
- **MAINTAINING.md (Task 2, `7a56e48`):** added a "CI gate topology (pr-gate / ci-gate)" section documenting the split and `ci-gate`'s release/publish/automerge/recovery role (push/dispatch-only, PR-exempt); added a prominent "Operator action: swap the PR required check" subsection stating the pending-trap hazard verbatim in intent and that code cannot enforce branch protection; noted local reproducibility via `scripts/ci/*.sh`; corrected the Sigra sibling-checkout ref `b186f03…`→`62ceb46a…` to match the ci.yml pin; reconciled the `install_golden_contract` gating sentence to push+dispatch-only (D-04), removing the false "on PRs that touch installer surfaces" claim and the "Do not change that gating behavior" directive while preserving the contract-asserted `path-gated` / `mix verify.install_golden` / `mix ci.install_golden` copy and the three `*_PATH` sibling-checkout entries.
- **D-08 realized (Task 3, operator action):** the repo admin created a GitHub repository ruleset requiring the `pr-gate` status check on `main` (see "D-08 Operator Action" below). `pr-gate` is now the required PR check.

## Task Commits

Each doc task was committed atomically before the human-action checkpoint:

1. **Task 1: CONTRIBUTING.md pr-gate story + scripts/ci + clone URL** — `2d8d16b` (docs)
2. **Task 2: MAINTAINING.md split + D-08 operator step + Sigra ref fix + gating reconcile** — `7a56e48` (docs)
3. **Task 3: D-08 branch-protection operator action** — no repo commit (out-of-repo GitHub settings; realized as ruleset id 18486746)

## Files Created/Modified

- `CONTRIBUTING.md` (modified) — pr-gate fast-feedback section, scripts/ci local-repro table, canonical clone URL.
- `MAINTAINING.md` (modified) — CI gate topology section, operator swap step + pending-trap hazard, scripts/ci note, corrected Sigra ref, reconciled installer-gating copy.
- `.planning/phases/80-verification-architecture-and-ci-dx/80-04-SUMMARY.md` — this summary.

## D-08 Operator Action (realized)

The operator (repo admin) established branch protection for `main` via a GitHub **repository ruleset** using the REST API:

- **Ruleset:** "main: require pr-gate" (id **18486746**), enforcement `active`, target `branch`, conditions `ref_name` include `["~DEFAULT_BRANCH"]`.
- **Rule:** `required_status_checks` requiring context `pr-gate`; `strict_required_status_checks_policy: false`; `do_not_enforce_on_create: true`.
- **bypass_actors:** RepositoryRole `admin` (actor_id 5), bypass_mode `always` — the maintainer's direct pushes to `main` are not blocked; PRs are gated on `pr-gate`.

End state matches the plan's intent: `pr-gate` is the required PR check.

## Deviations from Plan

### Realized-vs-planned mechanism (documented, not auto-fixed)

**1. [D-08 realization] Branch protection was SET UP, not swapped from `ci-gate`**
- **Plan assumption:** MAINTAINING's operator step and the checkpoint framed D-08 as swapping the existing PR required check `ci-gate` → `pr-gate`, with a pending-trap hazard if the swap were skipped.
- **Reality:** `main` had **no prior branch protection** — no classic rule and no rulesets — so there was never a `ci-gate` required check to remove and never any strand risk to remediate. The planned strand hazard was conditional and did not apply.
- **Action taken:** the operator created a new ruleset (id 18486746) requiring the `pr-gate` status check instead of editing a non-existent rule. Functionally equivalent end state (`pr-gate` is the required PR check); no repo files changed for this step.
- **Docs impact:** the MAINTAINING operator step is written as REMOVE `ci-gate` / ADD `pr-gate`; it remains correct guidance for any future state where `ci-gate` is required, and harmlessly over-specifies the "remove" half for the current no-prior-protection reality. Left as-is (code frozen; no ci.yml/scripts/contract-test changes permitted this plan).

**Total deviations:** 1 documented realization difference; 0 code auto-fixes.

## Requirements

No requirement IDs are newly completed by this plan. The plan frontmatter lists `[CI-01, CI-02, CI-03, CI-04]`, but those were already marked complete by Plan 01 (CI-01/02/03) and Plan 03 (CI-04); this plan documents them rather than re-claiming. `requirements-completed: []` reflects that no double-claim was made.

## Verification

- PASS: Task 1 — `grep` confirms `pr-gate`, `scripts/ci/`, `github.com/szTheory/chimeway` present in CONTRIBUTING.md; no `jonlunsford` reference remains.
- PASS: Task 2 — `grep` confirms `pr-gate`, `ci-gate`, `62ceb46a…`, "All twelve must pass", `path-gated`, `mix verify.install_golden`, `mix ci.install_golden`, `ACCRUE_PATH`/`THREADLINE_PATH`/`SIGRA_PATH`, "configured-schema runtime behavior", "public-schema legacy compatibility" all present; the stale `b186f03…` ref and "Do not change that gating behavior" directive are gone.
- PASS: `mix ci.verify_gates` — 529 tests, 0 failures (contract-asserted MAINTAINING copy intact; unchanged from Plan 03 baseline).
- PASS: D-08 operator action confirmed by the coordinator — `pr-gate` is the required PR check via ruleset id 18486746.
- PASS: No `ci.yml`, `scripts/ci/*`, `release.yml`, `publish-hex.yml`, `release-pr-automerge.yml`, or contract test modified (code frozen; docs+tracking finalization only).

## Threat Mitigations Applied

- **T-80-10 (required-check pending trap, D-08 not performed):** MAINTAINING documents the branch-protection step as an explicit operator action with the hazard stated, and the blocking human-action checkpoint surfaced it at execution time. Realized: `main` now requires `pr-gate` (ruleset 18486746). The conditional strand hazard did not materialize because `main` had no prior protection.
- **T-80-11 (maintainer docs drift from gate topology):** CONTRIBUTING + MAINTAINING updated in lockstep with the two-aggregate topology; contract-asserted pre-ship copy preserved so `mix ci.verify_gates` still guards the doc surface (529 tests green).
- **T-80-12 (under-gating by requiring only a fast check):** accepted by design — `pr-gate` (fast subset) is the PR required check; release confidence stays on `ci-gate` (push/dispatch). The ruleset's admin bypass_actors keep maintainer direct pushes unblocked while gating PRs.
- **T-80-SC (package installs):** none introduced — docs-only plan.

## Known Stubs

None. Both docs are complete prose; no placeholder/TODO/FIXME or runtime stub content.

## Threat Flags

None. No new network endpoints, auth paths, file-access patterns, or schema changes — docs-only plan. The D-08 ruleset is an out-of-repo GitHub settings change scoped to requiring an existing status check.

## User Setup Required

Completed this plan: D-08 branch-protection realized via GitHub ruleset id 18486746 (requires `pr-gate` on `main`).

## Next Phase Readiness

Phase 80 verification-architecture-and-CI-DX is doc-complete: contributor and maintainer gate docs agree with the two-aggregate topology, local reproducibility (`scripts/ci`) is documented, and branch protection requires `pr-gate` on PRs. All four plans (80-01..80-04) are complete.

## Self-Check: PASSED

- Found modified file: `CONTRIBUTING.md`.
- Found modified file: `MAINTAINING.md`.
- Found created file: `.planning/phases/80-verification-architecture-and-ci-dx/80-04-SUMMARY.md`.
- Found task commits: `2d8d16b`, `7a56e48`.
- `mix ci.verify_gates` green (529 tests, 0 failures).
- No ci.yml / scripts/ci / contract-test / release-workflow changes.

---
*Phase: 80-verification-architecture-and-ci-dx*
*Completed: 2026-07-03*
