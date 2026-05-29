---
phase: 41-release-verification-gates
plan: "01"
subsystem: testing
tags: [exunit, doc-contract, gate-01, version-alignment]

requires:
  - phase: 37-doc-truth-journey-guides
    provides: "Journey guide doc-contract pattern (forbidden/required strings)"
  - phase: 38-reference-recipes
    provides: "Recipe doc-contract describe block pattern"
  - phase: 36-golden-path-version-alignment
    provides: "Manual version grep gates to codify"
provides:
  - "Adoption-surface doc-contract gates for golden-path, installation, README, oban-integration"
  - "Dynamic consumer version alignment gates derived from mix.exs @version"
  - "Golden-path trigger opt parity test (idempotency_key + tenant_id per call site)"
affects:
  - 41-02 (ci.verify_gates alias will invoke these tests)
  - 41-03 (verify.example CI job)

tech-stack:
  added: []
  patterns:
    - "Phase 37–38 static forbidden/required string gates extended to adoption surfaces"
    - "Dynamic @version → {:chimeway, \"~> MAJOR.MINOR\"} alignment with drift-pattern forbids"

key-files:
  created: []
  modified:
    - test/chimeway/doc_contract_test.exs

key-decisions:
  - "Trigger parity counts Chimeway.trigger( call sites only — excludes Chimeway.trigger/3 arity prose references"
  - "identity: forbidden via negative lookbehind to permit recipient_identity: in golden-path notifier example"
  - "mix chimeway.install forbidden via phrase lists — ~w() splits multi-word tokens"

patterns-established:
  - "Adoption-surface describe blocks share @adoption_forbidden_strings with per-surface phrase lists for multi-word forbids"
  - "Consumer version alignment lives in doc_contract_test.exs for future ci.verify_gates single-path invocation"

requirements-completed: []

duration: 12min
completed: 2026-05-29
---

# Phase 41 Plan 01: Adoption-Surface Doc-Contract Gates Summary

**Automated GATE-01 doc-contract gates for golden-path, installation, README, and oban-integration adoption surfaces plus dynamic mix.exs version alignment**

## Performance

- **Duration:** 12 min
- **Started:** 2026-05-29T12:15:00Z
- **Completed:** 2026-05-29T12:27:00Z
- **Tasks:** 2 completed
- **Files modified:** 1

## Accomplishments

- Added four adoption-surface describe blocks (golden-path, installation, README, oban-integration) with forbidden/required string gates per D-01–D-04 and D-07
- Closed IN-01 deferred oban-integration doc-contract gap with Dispatch worker namespace assertions
- Added consumer version alignment describe block with dynamic `mix.exs` `@version` derivation and drift-pattern forbids (D-05, D-06)
- Golden-path trigger opt parity test ensures every `Chimeway.trigger(` call site includes `idempotency_key:` and `tenant_id:`

## Task Commits

Each task was committed atomically:

1. **Task 41-01-01: Add adoption-surface doc-contract describe blocks** - `26a1442` (test)
2. **Task 41-01-02: Add consumer version alignment describe block** - `776a5fa` (test)

**Plan metadata:** pending (docs commit after this file)

## Files Created/Modified

- `test/chimeway/doc_contract_test.exs` - Extended from 37 to 94 tests with adoption-surface and version-alignment gates

## Decisions Made

- Trigger parity regex uses `Chimeway\.trigger\(` to count call sites only, not `/3` arity prose references on line 150 of golden-path.md
- `identity:` gate uses `(?<!recipient_)identity:` regex in golden-path to avoid false positive on `recipient_identity:`
- `mix chimeway.install` stored in per-surface phrase lists because Elixir `~w()` splits on whitespace

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `~w()` splits multi-word forbidden strings**
- **Found during:** Task 41-01-01
- **Issue:** `mix chimeway.install` in `~w()` became separate `mix` and `chimeway.install` tokens, causing false failures on all adoption surfaces
- **Fix:** Per-surface `@adoption_forbidden_phrases_*` lists with `"mix chimeway.install"` string
- **Files modified:** test/chimeway/doc_contract_test.exs
- **Verification:** `mix test test/chimeway/doc_contract_test.exs` — 84 tests, 0 failures
- **Committed in:** 26a1442

**2. [Rule 1 - Bug] `identity:` substring matches `recipient_identity:`**
- **Found during:** Task 41-01-01
- **Issue:** Plain `identity:` forbid failed on golden-path notifier `recipient_identity:` field (D-03 research pitfall)
- **Fix:** Negative lookbehind regex `(?<!recipient_)identity:` for golden-path; plain substring for installation/README
- **Files modified:** test/chimeway/doc_contract_test.exs
- **Verification:** golden-path identity gate passes; installation/README unchanged
- **Committed in:** 26a1442

**3. [Rule 1 - Bug] Trigger parity regex counted arity prose reference**
- **Found during:** Task 41-01-01
- **Issue:** `Chimeway.trigger/3` on golden-path line 150 inflated trigger count vs idempotency_key/tenant_id opts
- **Fix:** Changed parity regex from `Chimeway\.trigger` to `Chimeway\.trigger\(` to count call sites only
- **Files modified:** test/chimeway/doc_contract_test.exs
- **Verification:** parity test passes with single trigger example block
- **Committed in:** 26a1442

**4. [Rule 1 - Bug] `~w()` invalid for drift patterns with special characters**
- **Found during:** Task 41-01-02
- **Issue:** `@drift_patterns ~w(~> 1.0 1.0.0 {:chimeway, "~> 1.)` split into invalid tokens (`~>`, `{:chimeway,`, etc.)
- **Fix:** Regular list `["~> 1.0", "1.0.0", ~s({:chimeway, "~> 1.)]`
- **Files modified:** test/chimeway/doc_contract_test.exs
- **Verification:** `mix test test/chimeway/doc_contract_test.exs --seed 0` — 94 tests, 0 failures
- **Committed in:** 776a5fa

---

**Total deviations:** 4 auto-fixed (4 bugs)
**Impact on plan:** All fixes necessary for correct gate semantics. No scope creep. Current docs pass without modification.

## Issues Encountered

None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Ready for 41-02: `mix ci.verify_gates` alias can invoke `test/chimeway/doc_contract_test.exs`
- GATE-01 partial: doc-contract matrix complete for adoption surfaces; CI entrypoint and verify.example expansion remain in 41-02/41-03

## Self-Check: PASSED

- [x] `test/chimeway/doc_contract_test.exs` exists on disk
- [x] `git log --oneline --grep="41-01"` returns ≥1 commit (26a1442, 776a5fa)
- [x] `mix test test/chimeway/doc_contract_test.exs` — 94 tests, 0 failures
- [x] `mix test test/chimeway/doc_contract_test.exs --seed 0` — 94 tests (>37 baseline)
- [x] Drift simulation: `~> 1.0` appended to README → drift test fails → reverted
- [x] Acceptance grep counts: golden-path/installation/README/oban describe blocks present; `mix chimeway.gen.migrations` ≥3; `mix chimeway.install` ≥3; `WorkflowProgressionWorker` ≥2

---
*Phase: 41-release-verification-gates*
*Completed: 2026-05-29*
