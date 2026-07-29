---
phase: 76-prefix-docs-demo-and-gates
plan: 01
subsystem: documentation
tags: [docs, hexdocs, storage-prefix, oban, doc-contracts]
requires:
  - phase: 75-runtime-prefix-propagation
    provides: Runtime prefix behavior and public legacy compatibility
provides:
  - HexDocs-included storage prefix upgrade and troubleshooting guide
  - First-run doc links to the dedicated storage prefix guide
  - Oban job-table prefix separation documentation
  - Doc contracts for storage guide, Oban examples, and HexDocs extras
affects:
  - phase-76-demo-proof
  - phase-76-release-gates
tech-stack:
  added: []
  patterns:
    - Layered first-run docs link to a dedicated operator guide
    - Stable string contracts lock storage-prefix guidance without prose snapshots
key-files:
  created:
    - guides/introduction/storage-prefix-upgrade.md
    - .planning/phases/76-prefix-docs-demo-and-gates/76-01-SUMMARY.md
  modified:
    - README.md
    - guides/introduction/installation.md
    - guides/introduction/golden-path.md
    - guides/recipes/oban-integration.md
    - mix.exs
    - test/chimeway/doc_contract_test.exs
key-decisions:
  - "[76-01]: Keep README, installation, and golden path beginner-safe; put manual public-to-chimeway move guidance in the dedicated storage prefix guide."
  - "[76-01]: Treat mix chimeway.gen.migrations --prefix public as generator-only compatibility sugar; runtime public compatibility remains prefix: false."
  - "[76-01]: Document Oban job-table prefixing with jobs examples and explicitly separate it from Chimeway storage prefixing."
patterns-established:
  - "Storage prefix guide owns manual move, preflight, backup, verification, rollback, and stop-and-restore guidance."
  - "Doc contracts cover required storage guide claims, forbidden first-run drift, Oban jobs examples, and HexDocs extras ordering."
requirements-completed: [UPG-02, UPG-03, DOCS-01, DOCS-02]
duration: 35 min
completed: 2026-07-02
status: complete
---

# Phase 76 Plan 01: Storage Prefix Docs and Contracts Summary

**Storage prefix adoption docs now include a HexDocs upgrade guide, Oban prefix separation copy, and contract tests for required and forbidden claims.**

## Performance

- **Duration:** 35 min
- **Started:** 2026-07-02T15:04:00Z
- **Completed:** 2026-07-02T15:39:40Z
- **Tasks:** 3
- **Files modified:** 7

## Accomplishments

- Added `guides/introduction/storage-prefix-upgrade.md` with prefix matrix, manual move guidance, preflight checks, backup, transaction/lock caveats, verification queries, rollback, and stop-and-restore failure handling.
- Linked README, installation, and golden path to the dedicated guide without adding operator runbook or Oban-prefix detail to first-run docs.
- Added Oban database-prefix documentation using `jobs` as the Oban-owned prefix example and stating that Chimeway storage prefix does not configure `oban_jobs`.
- Extended `Chimeway.DocContractTest` to lock storage guide claims, unsafe footgun exclusions, Oban jobs examples, and HexDocs extras registration.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add storage prefix upgrade guide and first-run links** - `18a47bc` (docs)
2. **Task 2: Document Oban prefix separation safely** - `ae1908a` (docs)
3. **Task 3: Lock storage docs and Oban caveats with doc contracts** - `5125463` (test)

## Files Created/Modified

- `guides/introduction/storage-prefix-upgrade.md` - Dedicated storage prefix upgrade, troubleshooting, manual move, rollback, and Oban separation guide.
- `README.md` - Added a short documentation link to the storage prefix guide.
- `guides/introduction/installation.md` - Added a short upgrade/troubleshooting cross-link.
- `guides/introduction/golden-path.md` - Added a short upgrade/troubleshooting cross-link.
- `guides/recipes/oban-integration.md` - Added Oban-owned jobs prefix examples and separation caveat.
- `mix.exs` - Registered the storage prefix guide in HexDocs extras.
- `test/chimeway/doc_contract_test.exs` - Added required/forbidden storage-prefix, Oban, and HexDocs extras contracts.

## Decisions Made

- Kept operator data-move detail out of README, installation, and golden path to preserve the beginner-safe first-run path.
- Used `jobs` as the Oban example prefix to avoid implying Chimeway and Oban share a schema.
- Contracted the storage guide with required strings and targeted forbidden patterns rather than full prose snapshots.

## Deviations from Plan

The storage guide received one small follow-up edit during Task 3 after the new contract caught missing lowercase operator-facing `lock` language. This was an in-scope documentation correction and is included in `5125463`.

**Total deviations:** 1 auto-fixed wording gap.
**Impact on plan:** Positive; the guide now states the lock caveat explicitly.

## Issues Encountered

- Initial new guide contract failed because the guide had SQL `LOCK TABLE` but not plain `lock` language. Added an explicit exclusive table lock caveat and re-ran the gate successfully.

## Verification

- `MIX_ENV=test mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` - passed, 429 tests.
- `mix ci.verify_gates` - passed, 472 tests.
- `mix ci.docs` - passed, docs generated.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 76-02 can use the documented default `config :chimeway, prefix: "chimeway"` behavior in the demo host and prove trigger-to-trace placement against `chimeway.*`.

---
*Phase: 76-prefix-docs-demo-and-gates*
*Completed: 2026-07-02*
