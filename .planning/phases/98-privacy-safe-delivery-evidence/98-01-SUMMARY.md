---
phase: 98-privacy-safe-delivery-evidence
plan: 01
subsystem: privacy-safe delivery evidence
tags: [elixir, ecto, postgres, privacy, redaction, traces]
requires: []
provides:
  - Atom-safe recursive forbidden-key redaction for maps and lists
  - Closed durable provider facts and opaque attempt references
  - Safe attempt persistence and tenant-scoped trace projections
affects:
  - Phase 98 telemetry, log, DTO, proof, and historical-data surfaces
tech-stack:
  added: []
  patterns:
    - Literal-key safe-evidence builders at persistence and projection boundaries
    - Case- and separator-normalized key comparison without dynamic atom creation
key-files:
  created:
    - lib/chimeway/privacy.ex
    - lib/chimeway/safe_evidence.ex
    - test/chimeway/privacy_boundary_test.exs
    - test/chimeway/privacy_test.exs
  modified:
    - lib/chimeway/deliveries.ex
    - lib/chimeway/traces.ex
key-decisions:
  - "[98-01]: Provider diagnostics persist only the provider_code, retry_after_ms, and accepted_at fact vocabulary."
  - "[98-01]: Opaque provider references must be caller-supplied cw_-prefixed bounded identifiers; raw provider IDs are not retained."
  - "[98-01]: Recursive comparison canonicalizes case and separators while retaining allowed original keys and list order."
metrics:
  duration: 8 min
  completed: 2026-08-12
status: complete
---

# Phase 98 Plan 01: Privacy-Safe Delivery Evidence Summary

**A hostile adapter result now becomes closed, validated attempt evidence that can be explained tenant-safely without retaining provider bodies or sensitive nested values.**

## Accomplishments

- Added `Chimeway.Privacy`, an atom-safe recursive walker for maps, ordinary lists, and keyword lists that drops forbidden pairs without traversing their values.
- Added `Chimeway.SafeEvidence`, which validates opaque `cw_` provider references and narrows durable facts to `provider_code`, `retry_after_ms`, and UTC `accepted_at`.
- Routed `Deliveries.record_attempt/2` through the closed evidence builder before the Ecto transaction, retaining existing locking, attempt ordinal, transition, and workflow progression behavior.
- Projected attempt summaries and timeline details through the same safe evidence vocabulary.
- Added focused PostgreSQL tracer and pure recursive boundary contracts, including serialized sentinel scans and atom-count evidence.

## Task Commits

1. **Task 1: Record and explain one hostile adapter attempt without a leak**
   - `5c236fb` — RED PostgreSQL boundary contract
   - `77b50ea` — closed persistence and trace implementation
2. **Task 2: Lock recursive shape, equality, empty, and ordering semantics**
   - `966a223` — RED recursive/privacy contract
   - `3f36ea0` — canonical key-spelling implementation

## Verification

- PASS: `mix format --check-formatted lib/chimeway/privacy.ex lib/chimeway/safe_evidence.ex test/chimeway/privacy_test.exs`
- PASS: `env MIX_ENV=test mix test test/chimeway/privacy_test.exs --warnings-as-errors` — 4 tests, 0 failures.
- PASS: `env MIX_ENV=test mix test test/chimeway/privacy_boundary_test.exs --warnings-as-errors` — 3 tests, 0 failures with PostgreSQL persistence enabled.

## Decisions Made

- Unknown provider fact keys are discarded; malformed values for allowlisted facts reject the attempt with a stable `:unsafe_evidence` result.
- `provider_response` remains the physical JSON column for compatibility but now stores only typed provider facts.
- Trace attempt maps include outcome, timestamp, ordinal, error class, opaque provider reference, and typed facts, not adapter/provider diagnostic bodies.

## Deviations from Plan

### Auto-fixed Issues

1. **[Rule 1 - Bug] Preserve structs during recursive redaction**
   - **Found during:** Task 1
   - **Issue:** `DateTime` provider facts are structs and were being traversed as generic maps.
   - **Fix:** Treat structs as scalar values in `Privacy.redact/1`, then validate accepted timestamps in `SafeEvidence`.
   - **Files modified:** `lib/chimeway/privacy.ex`
   - **Commit:** `77b50ea`

2. **[Rule 2 - Missing critical functionality] Normalize common sensitive-key separators**
   - **Found during:** Task 2
   - **Issue:** A camel-case sensitive key such as `renderedContent` did not match the underscore spelling in the fixed taxonomy.
   - **Fix:** Canonicalize case, underscores, hyphens, and spaces for comparison only.
   - **Files modified:** `lib/chimeway/privacy.ex`
   - **Commit:** `3f36ea0`

## Known Stubs

None. The plan-owned code contains no placeholder, TODO/FIXME, empty UI data flow, or unrun verification.

## Self-Check: PASSED

- Found all six plan-owned implementation and test files.
- Found task commits `5c236fb`, `77b50ea`, `966a223`, and `3f36ea0`.
- No tracked file deletions were introduced.
