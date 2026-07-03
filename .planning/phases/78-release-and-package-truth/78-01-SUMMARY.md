---
phase: 78-release-and-package-truth
plan: "01"
subsystem: release-and-package-truth
tags: [elixir, hex, release-please, package-metadata, release-gate, contract-tests]
requires:
  - phase: 77-truth-baseline-and-package-model-decision
    provides: root-only package model decision and downstream truth owner map
provides:
  - Canonical szTheory/chimeway package links and HexDocs source_url in mix.exs
  - README CI badge pointed at the canonical repository Actions workflow
  - Release-gate contracts for root version/manifest parity, changelog SemVer heading, README install constraint, canonical/legacy source URL, and root-only Release Please + publish workflows
affects:
  - phase-78-02-sibling-package-status-copy
  - phase-78-03-package-artifact-proof
tech-stack:
  added: []
  patterns:
    - Extend Chimeway.ReleaseGateContractTest instead of a parallel shell checker (D-07)
    - Decode release manifest/config with Jason.decode! for exact root-only structure assertions
    - Scope workflow secret contracts by job-region string split (no secret-value assertions)
key-files:
  created:
    - .planning/phases/78-release-and-package-truth/78-01-SUMMARY.md
  modified:
    - mix.exs
    - README.md
    - test/chimeway/release_gate_contract_test.exs
decisions:
  - "[78-01]: Package/source truth is enforced by extending release_gate_contract_test.exs (no parallel shell checker) per D-07."
  - "[78-01]: Canonical package-facing repository/source URL is https://github.com/szTheory/chimeway; contracts reject the legacy jonlunsford URL."
  - "[78-01]: HEX_API_KEY scoping is contracted by asserting absence from the release-please job body, avoiding secret-value assertions (T-78-04)."
metrics:
  duration: 4 min
  completed: 2026-07-03
  tasks: 2
  files: 3
requirements-completed: [TRUTH-01, TRUTH-02]
status: complete
---

# Phase 78 Plan 01: Release and Package Truth Summary

Root package identity and canonical package-facing source links are now executable truth: `mix.exs`/`README.md` point at `https://github.com/szTheory/chimeway`, and `Chimeway.ReleaseGateContractTest` fails on package version drift, stale source URLs, or sibling publish-lane drift.

## Performance

- **Duration:** 4 min
- **Started:** 2026-07-03T08:19:27Z
- **Completed:** 2026-07-03
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Normalized `mix.exs` package `links` (`GitHub`) and HexDocs `source_url` from the legacy `jonlunsford/chimeway` owner to the canonical `szTheory/chimeway` repository, preserving `@version "1.0.0"`, `version: @version`, the `files` whitelist, and `source_ref: "v#{@version}"`.
- Moved the `README.md` CI badge image and link to `https://github.com/szTheory/chimeway/actions/workflows/ci.yml`, preserving the Hex badge and the `{:chimeway, "~> 1.0"}` install snippet.
- Added a `root package release identity uses package SemVer refs` contract that parses root `@version`, decodes `.release-please-manifest.json` with `Jason.decode!`, asserts the manifest has exactly the root `"."` entry equal to `@version`, requires a `## 1.0.0` CHANGELOG package release heading, asserts `source_ref: "v#{@version}"` is preserved, and derives the README install constraint from the current MAJOR.MINOR.
- Added a `package-facing repository and source URLs use the canonical repository` contract that rejects the legacy owner URL across `mix.exs`, `README.md`, `CHANGELOG.md`, `.github/workflows/release.yml`, and `.github/workflows/publish-hex.yml`, and positively requires the canonical repository value in `mix.exs` links/source_url and the README CI badge.
- Added a `Release Please config stays root-only` contract asserting `release-please-config.json` `packages` has exactly the `"."` key with `changelog-path: CHANGELOG.md` and `include-v-in-tag: true`.
- Added `release.yml` and `publish-hex.yml` root-only workflow contracts covering config/manifest inputs, release-tag checkout, root `RELEASE_VERSION` grep, gate replay (`mix ci.verify_gates` / `mix ci.docs`), `mix hex.build`, tag-or-40-char-SHA validation, dry-run/real `mix hex.publish` commands, HEX_API_KEY scoping off the release-please job, and rejection of `chimeway_admin`/`chimeway_inbox` publish drift.

## Task Commits

Each task was committed atomically:

1. **Task 1: Normalize root package source metadata and contract release identity** - `f310c92` (feat)
2. **Task 2: Contract root-only Release Please and publish workflows** - `767c961` (test)

## Files Created/Modified

- `mix.exs` - Package links and HexDocs source_url normalized to the canonical szTheory repository.
- `README.md` - CI badge image/link moved to the canonical repository Actions workflow.
- `test/chimeway/release_gate_contract_test.exs` - Added canonical URL/legacy rejection attributes, `root_version!/0` helper, and two describe blocks (root package/source truth; root-only Release Please and publish workflows) — 8 new tests.
- `.planning/phases/78-release-and-package-truth/78-01-SUMMARY.md` - Execution evidence and plan metadata.

## Decisions Made

- Extended the existing ExUnit release-gate anchor rather than adding a shell checker (D-07).
- Chose to positively require the canonical repository URL only in files that carry a package-facing source URL (`mix.exs`, README badge) while rejecting the legacy URL across all Phase 78-owned package-facing surfaces; `CHANGELOG.md` and the two workflows carry no legacy owner URL.
- Contracted HEX_API_KEY hygiene (T-78-04) by scoping the release-please job body via a header-to-next-job string split and asserting the secret is absent there, rather than asserting on secret values.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Release-please job region could not be extracted by the existing helper**
- **Found during:** Task 2
- **Issue:** The pre-existing `extract_ci_job_block/2` helper bounds a job with a `[a-z_]+:` next-job pattern, but every job name in `release.yml` contains hyphens, so the helper swallowed the whole file (including the `publish-hex` `HEX_API_KEY` step and the file-level comment header that names the secret), making the HEX_API_KEY-absence assertion impossible.
- **Fix:** Scoped the release-please job body with an explicit `String.split/3` from the `\n  release-please:` header to the next `\n  bootstrap-release-pr-ci:` job header instead of reusing `extract_ci_job_block/2`. The existing helpers were preserved unchanged.
- **Files modified:** `test/chimeway/release_gate_contract_test.exs`
- **Commit:** `767c961`

**Total deviations:** 1 auto-fixed (Rule 3).
**Impact on plan:** No scope change. All planned contracts landed; the fix only changed how one job region is delimited.

## Verification

- PASS: `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors` (53 tests, 0 failures).
- PASS: `mix format --check-formatted mix.exs test/chimeway/release_gate_contract_test.exs` (exit 0).
- PASS: combined gate `MIX_ENV=test mix test test/chimeway/doc_contract_test.exs test/chimeway/release_gate_contract_test.exs --warnings-as-errors` (482 tests, 0 failures) — no regression in the broader `ci.verify_gates` surface.
- PASS: canonical `szTheory/chimeway` present in `mix.exs` (2) and `README.md` (1); legacy `jonlunsford` absent from both.

## Threat Mitigations Applied

- **T-78-01 (Tampering, package metadata):** Contract-tests root `@version`, manifest version parity, README install constraint, changelog SemVer heading, and preserved `source_ref: "v#{@version}"`.
- **T-78-02 (Spoofing, source links):** Normalized package-facing links to the canonical repository and added legacy-URL rejection across package-facing surfaces.
- **T-78-03 (Tampering, release/publish workflows):** Contract-tests release-tag checkout, root `RELEASE_VERSION` grep, gate replay, root `mix hex.build`/`mix hex.publish`, and absence of sibling publish lanes.
- **T-78-04 (Information Disclosure, HEX_API_KEY):** Contracts assert secret-context shape and absence from the release-please job body without asserting secret values.

## Known Stubs

None. Stub-pattern scan of the modified files found no placeholder/TODO/FIXME or runtime/UI stub content.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for 78-02 (sibling package status copy/contracts) and 78-03 (package artifact proof). Root package/source/release truth is now contract-locked as the baseline those plans build on.

## Self-Check: PASSED

- Found modified files: `mix.exs`, `README.md`, `test/chimeway/release_gate_contract_test.exs`.
- Found task commits: `f310c92` (feat), `767c961` (test).
- Verified canonical URL present and legacy URL absent in `mix.exs` and `README.md`.
- No tracked file deletions were introduced by the 78-01 task commits.

---
*Phase: 78-release-and-package-truth*
*Completed: 2026-07-03*
