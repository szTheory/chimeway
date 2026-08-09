---
phase: 94-mailglass-transactional-email-proof
plan: 01
subsystem: testing
tags: [elixir, exunit, ecto, mailglass, fake-transport, artifact-proof]
requires:
  - phase: 93-hermetic-artifact-harness-core-trace-proof
    provides: isolated unpacked-artifact consumer fixture and Core trace proof
provides:
  - Serialized host-owned Mailglass proof from an unpacked Chimeway artifact
  - Fixed trace-derived Fake-transport evidence allowlist with atom-safe parsing
affects: [phase-94-plan-02, release-gates, mailglass-integration]
tech-stack:
  added: []
  patterns:
    - Generated consumer owns Mailglass configuration, migration wrapper, notifier, and mailable
    - Public subprocess evidence is parsed through a complete string-key allowlist
key-files:
  created: [.planning/phases/94-mailglass-transactional-email-proof/94-01-SUMMARY.md]
  modified:
    - test/support/artifact_consumer_fixture.ex
    - test/chimeway/release_gate_contract_test.exs
key-decisions:
  - "The generated host declares Mailglass directly on the resolved ~> 1.3 line while retaining the Phase 93 Oban opt-in."
  - "One public explanation is the only serialized lifecycle source; Fake records remain private assertions."
  - "Mailglass evidence parsing uses a closed string-to-existing-atom map and requires one complete Fake-labeled line."
patterns-established:
  - "Artifact consumer integrations add host-owned adapters and migrations to the existing hermetic fixture rather than adding a new harness."
  - "Untrusted proof output rejects unknown, duplicate, missing, malformed, repeated-prefix, and sensitive fields before returning a map."
requirements-completed: [MAIL-01, MAIL-02]
coverage:
  - id: D1
    description: "An unpacked Chimeway artifact runs one host-owned Mailglass notifier through its render-key map, mailable, Fake transport, and public trace."
    requirement: MAIL-01
    verification:
      - kind: integration
        ref: "MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors"
        status: pass
    human_judgment: false
  - id: D2
    description: "Mailglass proof evidence is Fake-labeled, allowlisted, atom-safe, and failure-cleaned."
    requirement: MAIL-02
    verification:
      - kind: integration
        ref: "MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors"
        status: pass
    human_judgment: false
duration: 6 min
completed: 2026-08-09
status: complete
---

# Phase 94 Plan 01: Mailglass Transactional Email Proof Summary

**An unpacked Chimeway artifact now proves one host-owned Mailglass email through the exact render-key, mailable, Fake transport, and sanitized public trace path.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-08-09T03:28:00Z
- **Completed:** 2026-08-09T03:34:53Z
- **Tasks:** 2/2
- **Files modified:** 2

## Accomplishments

- Extended the Phase 93 generated consumer with a Mailglass dependency, host repo configuration, public migration wrapper, stable email notifier, and host mailable.
- Added a serialized, one-record Fake transport proof that derives lifecycle facts solely from Chimeway.Traces.explain_delivery/1.
- Locked the public proof boundary against unknown, duplicate, missing, malformed, repeated, unsafe, and atomizing output.

## Task Commits

1. **Task 1 RED: Mailglass artifact proof contract** — a7bef8d (test)
2. **Task 1 GREEN: Host-owned Mailglass lifecycle proof** — adeea5a (feat)
3. **Task 2: Mailglass evidence boundary contracts** — 66b7a34 (test)

## Files Created/Modified

- test/support/artifact_consumer_fixture.ex — Generates and cleans the Mailglass-capable consumer, serializes safe trace evidence, and parses it fail closed.
- test/chimeway/release_gate_contract_test.exs — Covers the complete artifact path, sensitive-output rejection, atom safety, and failure cleanup.

## Decisions Made

- The generated host retains direct Oban opt-in and adds direct Mailglass 1.3 without changing root dependencies.
- Fake delivery state is asserted only inside the generated proof; its records do not enter the adopter-facing output.
- The parser requires a complete fixed allowlist and transport=fake, mapping only compile-time known string keys.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added the strict parser with the tracer**
- **Found during:** Task 1
- **Issue:** The tracer needed to parse untrusted subprocess output before its end-to-end contract could safely consume it.
- **Fix:** Added the closed Mailglass evidence parser during Task 1; Task 2 adds its full malformed and sensitive-input contract suite.
- **Files modified:** test/support/artifact_consumer_fixture.ex, test/chimeway/release_gate_contract_test.exs
- **Verification:** Focused and full release-gate contract runs pass.
- **Committed in:** adeea5a

**Total deviations:** 1 auto-fixed (Rule 2).
**Impact on plan:** The security boundary shipped earlier than its dedicated test expansion; no production scope changed.

## TDD Gate Compliance

- Task 1 follows RED (a7bef8d) then GREEN (adeea5a).
- Task 2's parser implementation was necessarily included in the Task 1 tracer to avoid consuming untrusted output; its expanded contract suite therefore passed when added.

## Verification

- PASS — MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors
- PASS — MIX_ENV=test mix format --check-formatted test/support/artifact_consumer_fixture.ex test/chimeway/release_gate_contract_test.exs
- PASS — git diff --name-only -- lib mix.exs .github/workflows produced no output.

## Issues Encountered

The release-gate suite continues to log pre-existing Threadline sandbox ownership errors during teardown; the test command completed with no failures.

## User Setup Required

None.

## Next Phase Readiness

The strict artifact proof can now be documented as a bounded Mailglass integration claim in Plan 94-02.

## Self-Check: PASSED

- Confirmed a7bef8d, adeea5a, and 66b7a34 exist in git history.
- Confirmed both modified test files exist.

---
*Phase: 94-mailglass-transactional-email-proof*
*Completed: 2026-08-09*
