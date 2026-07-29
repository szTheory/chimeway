---
phase: 78-release-and-package-truth
plan: "02"
subsystem: documentation
tags: [elixir, hex, doc-contracts, exunit, package-truth, guides]

# Dependency graph
requires:
  - phase: 77-truth-baseline-and-package-model-decision
    provides: Package-model decision that chimeway is the only Hex-published package; siblings remain in-repo preview/path packages
  - phase: 78-release-and-package-truth
    provides: 78-01 root package/source truth via release_gate_contract_test.exs
provides:
  - Admin console integration guide states chimeway_admin is an in-repo preview/path package not published on Hex yet
  - Inbox integration guide states chimeway_inbox is an in-repo preview/path package not published on Hex yet
  - Doc contracts requiring preview/path status and forbidding current-Hex install snippets for both sibling packages
  - Source-evidence contracts asserting sibling mix files stay path-package-only (no package:/docs: metadata)
affects:
  - phase-78-03-package-artifact-proof
  - phase-79-front-door-docs-truth

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Positive-and-negative public copy guards for sibling package install-status
    - Source-evidence ExUnit assertions against sibling mix.exs files as path-package proof

key-files:
  created: []
  modified:
    - guides/introduction/admin-console-integration.md
    - guides/introduction/inbox-integration.md
    - test/chimeway/doc_contract_test.exs

key-decisions:
  - "[78-02]: Sibling install-status truth is enforced by extending doc_contract_test.exs (no parallel shell checker) per D-07."
  - "[78-02]: Guides omit any Hex install snippet for chimeway_admin/chimeway_inbox; a package-promotion milestone is required before current-Hex install guidance returns (D-05/D-06)."
  - "[78-02]: Sibling mix.exs files are treated as evidence-only; contracts assert app/version/path-dep presence and absence of package:/docs: metadata (D-05)."

patterns-established:
  - "Sibling package status guard: assert 'in-repo preview/path package' + 'not published on Hex yet' and refute '{:chimeway_*, \"~> 1.0\"}' current-Hex snippets."
  - "Source-evidence guard: File.read! sibling mix.exs and assert path-package shape without editing the sibling project."

requirements-completed: [TRUTH-03]

coverage:
  - id: D1
    description: "Admin console integration guide states chimeway_admin preview/path status and uses a path dependency instead of a current Hex install claim"
    requirement: "TRUTH-03"
    verification:
      - kind: unit
        ref: "test/chimeway/doc_contract_test.exs#documents chimeway_admin preview/path install status (TRUTH-03 / D-05)"
        status: pass
      - kind: unit
        ref: "test/chimeway/doc_contract_test.exs#forbids current-Hex chimeway_admin install claim (D-06)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Inbox integration guide states chimeway_inbox preview/path status and keeps the path dependency without a current Hex install claim"
    requirement: "TRUTH-03"
    verification:
      - kind: unit
        ref: "test/chimeway/doc_contract_test.exs#documents chimeway_inbox preview/path install status (TRUTH-03 / D-05)"
        status: pass
      - kind: unit
        ref: "test/chimeway/doc_contract_test.exs#forbids current-Hex chimeway_inbox install claim (D-06)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Source-evidence contracts assert chimeway_admin/mix.exs and chimeway_inbox/mix.exs remain path-package evidence without Hex package metadata"
    requirement: "TRUTH-03"
    verification:
      - kind: unit
        ref: "test/chimeway/doc_contract_test.exs#chimeway_admin/mix.exs remains path-package evidence, not a Hex package (D-05)"
        status: pass
      - kind: unit
        ref: "test/chimeway/doc_contract_test.exs#chimeway_inbox/mix.exs remains path-package evidence, not a Hex package (D-05)"
        status: pass
    human_judgment: false

# Metrics
duration: 5min
completed: 2026-07-03
status: complete
---

# Phase 78 Plan 02: Sibling Package Install-Status Truth Summary

**Admin and inbox integration guides now declare chimeway_admin and chimeway_inbox as in-repo preview/path packages not published on Hex yet, enforced by positive/negative doc contracts and sibling mix.exs source-evidence assertions.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-07-03T08:28:58Z
- **Completed:** 2026-07-03T08:30:23Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Replaced the admin guide's `{:chimeway_admin, "~> 1.0"}` current-Hex install claim with an in-repo preview/path `{:chimeway_admin, path: "../chimeway_admin"}` dependency plus explicit preview-status prose.
- Replaced the inbox guide's future-publish `{:chimeway_inbox, "~> 1.0"}` sentence with present-tense preview/path status while preserving the existing path dependency.
- Extended `Chimeway.DocContractTest` with positive status assertions, negative current-Hex snippet guards, and source-evidence assertions that both sibling mix.exs files remain path-package-only (no `package:`/`docs:` metadata).
- Full `doc_contract_test.exs` suite green at 438 tests with `--warnings-as-errors`; both sibling mix.exs files left unmodified (evidence-only).

## Task Commits

Each task was committed atomically:

1. **Task 1: Replace admin Hex install claim with preview/path status contract** - `42fe9b1` (docs)
2. **Task 2: Tighten inbox path-package status and future-publish wording** - `7cb7332` (docs)

**Plan metadata:** committed separately (docs: complete plan)

## Files Created/Modified

- `guides/introduction/admin-console-integration.md` - Section 1 now states chimeway_admin is an in-repo preview/path package not published on Hex yet and uses `{:chimeway_admin, path: "../chimeway_admin"}`.
- `guides/introduction/inbox-integration.md` - Section 1 now states chimeway_inbox is an in-repo preview/path package not published on Hex yet and drops the future-publish current-Hex snippet.
- `test/chimeway/doc_contract_test.exs` - Extended DOCS-12 admin and DOCS-08/09 inbox contracts with preview/path status assertions, current-Hex snippet guards, and sibling mix.exs source-evidence assertions.

## Decisions Made

- Omitted any Hex install snippet for the sibling packages entirely rather than showing a "future" snippet, so the negative contracts (`refute {:chimeway_*, "~> 1.0"}`) stay simple and drift-proof.
- Kept sibling mix.exs files evidence-only; the new contracts read them via `File.read!` and assert path-package shape without adding package metadata or publish lanes (D-05/T-78-07).

## Deviations from Plan

None - plan executed exactly as written.

**Total deviations:** 0 auto-fixed.
**Impact on plan:** No scope change. Edits stayed within the two guide dependency sections and the doc-contract test; sibling mix.exs files were read but not modified.

## Issues Encountered

None.

## Known Stubs

None. Stub-pattern scan found no placeholder/TODO/FIXME or runtime/UI stub content in the modified guide and test files.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for 78-03 (package artifact proof), which consumes the corrected sibling install-status guides. No blockers.

## Self-Check: PASSED

- Found modified files: admin-console-integration.md, inbox-integration.md, doc_contract_test.exs.
- Found task commits: `42fe9b1`, `7cb7332`.
- Verified stale snippets removed: `grep -c '{:chimeway_admin, "~> 1.0"}'` and `grep -c '{:chimeway_inbox, "~> 1.0"}'` both return 0.
- `MIX_ENV=test mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` → 438 tests, 0 failures.
- `mix format --check-formatted test/chimeway/doc_contract_test.exs` → exit 0.
- No tracked file deletions introduced by the plan commits.

---
*Phase: 78-release-and-package-truth*
*Completed: 2026-07-03*
