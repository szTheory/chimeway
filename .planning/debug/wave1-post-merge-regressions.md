---
status: investigating
trigger: "Phase 99 Wave 1 post-merge integration: mix test has 24 failures in installer migration fixtures, prefixed/runtime proofs, trace shape, and Threadline/Accrue lifecycle tests."
created: 2026-08-19T00:00:00-04:00
updated: 2026-08-19T00:00:00-04:00
---

## Current Focus
<!-- OVERWRITE on each update - reflects NOW -->

reasoning_checkpoint:
  hypothesis: "Phase 99-01 added migration 035 and a :targets trace key, while pre-existing generated fixtures and exact assertions remain at the 034 shape; legacy partner fixtures supply non-opaque recipient values rejected by SafeEvidence."
  confirming_evidence:
    - "Focused generated-prefix execution fails with PostgreSQL 42P01 for chimeway_delivery_targets; both committed fixture trees contain only the prior 34 migrations."
    - "Focused installer execution reports 35 generated files against 34-count assertions, and Traces.get_trace now preloads targets."
    - "Threadline recipient IDs are user-tl-* and Accrue harness supplies a raw email; SafeEvidence.recipient_reference accepts only cw_* or user:UUID references."
  falsification_test: "After adding migration 035 to generated fixtures, updating exact fixture contracts, and changing only test identities to opaque references, focused tests still fail with 42P01, missing :targets, or unsafe_evidence."
  fix_rationale: "Regenerating copied migration fixtures makes the schema match the loaded target association; updating exact count/shape assertions matches additive Wave 1 behavior; opaque test identities comply with the established privacy contract without admitting raw emails."
  blind_spots: "Accrue's published adapter still passes customer email as recipient_identity in production; this Wave 1 repository fixture makes its test harness privacy-safe but does not alter the external package's implementation."
  candidate_causes:
    - "code: generated-runtime support omits the new copied migration and exact trace assertion predates target child projection"
    - "data: Threadline and Accrue test fixtures inject identities outside SafeEvidence's closed vocabulary"
  and_gate: "no — the clusters are independent compatibility regressions introduced by the same additive merge, not jointly required conditions for one failure."
next_action: "Regenerate both committed migration golden fixture sets and run focused suites."

## Symptoms
<!-- Written during gathering, then IMMUTABLE -->

expected: "The complete Mix test suite passes after Phase 99-01 is merged."
actual: "mix test ran 1466 tests with 24 failures: migration counts/golden fixtures expect 34 not 35; generated prefix/runtime proofs miss chimeway_delivery_targets; exact trace assertion misses :targets; Threadline and Accrue dunning workflows reject evidence as unsafe or create no run."
errors: "{:error, :unsafe_evidence}; missing chimeway_delivery_targets; trace map lacks :targets; migration count expected 34, got 35."
reproduction: "Run the focused failing test files, then mix test."
started: "Post-merge of Phase 99 Plan 99-01 at HEAD."

## Eliminated
<!-- APPEND only - prevents re-investigating -->

## Evidence
<!-- APPEND only - facts discovered -->

- timestamp: 2026-08-19T00:00:00-04:00
  checked: "Post-merge failure report"
  found: "Four deterministic failure clusters were reported after 99-01."
  implication: "Classify as Bohrbugs and reproduce with focused tests before changing code."
- timestamp: 2026-08-19T00:00:00-04:00
  checked: "99-01 plan and code search"
  found: "99-01 deliberately added copied migration 035, Delivery.targets trace preload, and closed target evidence. Existing test files retain hard-coded 34 migration counts and exact pre-target trace contracts."
  implication: "Data-shape and fixture-contract candidates are concrete; lifecycle failures still require direct input tracing."
- timestamp: 2026-08-19T00:00:00-04:00
  checked: "Focused failure execution and integration implementations"
  found: "Generated prefixed fixture trees contain 34 migrations, so the runtime schema lacks chimeway_delivery_targets. Traces now preload targets. Threadline uses user-tl-* direct recipients and Accrue's harness customer email is passed as recipient_identity; both fail the documented SafeEvidence opaque-reference contract."
  implication: "Confirmed root causes are fixture/contract drift, not a target runtime defect or an acceptable relaxation of privacy validation."

## Resolution
<!-- OVERWRITE as understanding evolves -->

root_cause: "Phase 99-01 added copied migration 035 and nested target trace projection, but generated migration fixtures and exact contracts remained on the 34-migration/pre-target shape; Threadline and Accrue harness values did not use SafeEvidence-approved opaque recipient references."
fix: "Regenerated public/prefixed migration fixtures with 035; updated exact count/runtime/trace expectations; changed test-only Threadline and Accrue fixture identities to opaque references without changing SafeEvidence."
verification: "Focused post-merge suites exercised the reported clusters without errors. Full `mix test` completed after its adoption-path and installer consumer subprocesses with no failure output."
files_changed:
  - .planning/phases/99-multi-installation-delivery-recovery/99-01-SUMMARY.md
  - test/chimeway/generated_prefixed_runtime_proof_test.exs
  - test/chimeway/install/golden_diff_test.exs
  - test/chimeway/install/idempotency_test.exs
  - test/chimeway/install/migrations_test.exs
  - test/chimeway/install/prefix_contract_test.exs
  - test/chimeway/integrations/threadline_telemetry_lifecycle_test.exs
  - test/chimeway/migration_contract_test.exs
  - test/chimeway/traces_test.exs
  - test/fixtures/installer_golden_prefixed/
  - test/fixtures/installer_golden_public/
  - test/support/accrue/fixtures.ex
  - test/support/generated_prefixed_runtime_case.ex
