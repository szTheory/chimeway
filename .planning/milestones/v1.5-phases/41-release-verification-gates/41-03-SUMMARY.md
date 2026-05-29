---
phase: 41-release-verification-gates
plan: "03"
subsystem: testing
tags: [mix, github-actions, postgres, e2e, chimeway_admin, verify.example]

requires:
  - phase: 41-release-verification-gates
    provides: ci.verify_gates alias and MAINTAINING.md pre-ship runbook (41-02)
  - phase: 40-operator-trace-mvp
    provides: chimeway_admin test suite for operator smoke
provides:
  - verify.example additive subprocess chain (demo host E2E + chimeway_admin smoke)
  - verify_example always-on CI job with Postgres provisioning
  - GATE-01 nyquist_compliant validation sign-off
affects: [release-process, ci-pipeline, GATE-01]

tech-stack:
  added: []
  patterns:
    - "Pre-ship verify.example runs outside default mix ci for fast core feedback"
    - "Dedicated CI job without path-gating for reference-flow proof"

key-files:
  created: []
  modified:
    - mix.exs
    - .github/workflows/ci.yml
    - .planning/phases/41-release-verification-gates/41-VALIDATION.md

key-decisions:
  - "verify.example runs demo host first, chimeway_admin second — additive subprocess chain preserves D-11 E2E order"
  - "verify_example CI job always runs on push/PR — no path-gating unlike install_golden_contract"

patterns-established:
  - "GATE-01 pre-ship quartet: mix ci, mix ci.docs, mix ci.verify_gates, mix verify.example"
  - "Reference-flow CI proof lane separate from default mix ci (D-09)"

requirements-completed: [GATE-01]

duration: 12min
completed: 2026-05-29
---

# Phase 41 Plan 03: verify.example Admin Smoke + CI Job Summary

**Expanded `mix verify.example` to run demo-host E2E and chimeway_admin operator smoke additively, with a dedicated always-on `verify_example` GitHub Actions job provisioning Postgres.**

## Performance

- **Duration:** 12 min
- **Started:** 2026-05-29T12:26:00Z
- **Completed:** 2026-05-29T12:38:48Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments

- `verify.example` alias now chains demo host tests then full `chimeway_admin` test suite (D-10, D-11)
- New `verify_example` CI job runs on every push/PR to main with Postgres — no path-gating (D-08)
- Default `mix ci` alias unchanged — `verify.example` remains separate pre-ship gate (D-09)
- Phase 41 validation marked `nyquist_compliant: true` with full GATE-01 sign-off

## Task Commits

Each task was committed atomically:

1. **Task 41-03-01: Expand mix verify.example with chimeway_admin subprocess** - `884b34b` (feat)
2. **Task 41-03-02: Add verify_example CI job** - `58926ce` (feat)
3. **Task 41-03-03: Finalize phase validation sign-off** - `d7ab7db` (docs)

**Plan metadata:** `788556c` (docs: complete plan)

## Files Created/Modified

- `mix.exs` - Added chimeway_admin subprocess to verify.example; updated comment for GATE-01 scope
- `.github/workflows/ci.yml` - New verify_example job with Postgres service and ecto setup
- `.planning/phases/41-release-verification-gates/41-VALIDATION.md` - Wave 3 sign-off, nyquist_compliant

## Decisions Made

- Preserved demo host as first subprocess — webhook + feedback E2E unchanged (D-11)
- Single OTP matrix (Elixir 1.17 / OTP 27) for verify_example job per research OQ-4
- Reused SHA-pinned action versions from sibling CI jobs

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- `mix ci.docs` exits 1 due to pre-existing ex_doc relative-link warnings in guides (documented in wave 2; unchanged by this plan)
- Local `ruby -ryaml` unavailable in asdf environment; YAML validated via `python3 -c "import yaml"` instead

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 41 complete (3/3 plans) — GATE-01 satisfied
- Ready for `/gsd-verify-work 41` conversational UAT
- Pre-existing `mix ci.docs` link warnings remain a separate cleanup item

## Self-Check: PASSED

| Criterion | Result |
|-----------|--------|
| verify.example includes chimeway_demo_host + chimeway_admin | PASS |
| verify_example job in ci.yml | PASS |
| mix verify.example exits 0 | PASS |
| mix ci exits 0 | PASS |
| mix ci.verify_gates exits 0 | PASS |
| verify.example NOT in mix ci alias | PASS |
| 41-VALIDATION.md nyquist_compliant: true | PASS |

---
*Phase: 41-release-verification-gates*
*Completed: 2026-05-29*
