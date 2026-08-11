---
phase: 96-adoption-front-door-proof-gate
plan: "01"
subsystem: adoption-proof
tags: [elixir, mix-task, hex, artifact-proof, release-gate]
requires:
  - phase: 93-hermetic-artifact-harness-core-trace-proof
    provides: clean artifact-consumer fixture and Core proof
  - phase: 94-mailglass-transactional-email-proof
    provides: validated Mailglass evidence boundary
  - phase: 95-accrue-billing-escalation-proof
    provides: archive-plus-SHA Accrue proof contract
provides:
  - strict `mix verify.adoption_paths` selector command
  - single-build serial Core, Mailglass, and Accrue artifact proof
  - shared archive provenance validation for package proof CLIs
affects: [GATE-01, DOCS-01, phase-96-plan-02]
tech-stack:
  added: []
  patterns: [strict Mix argv allowlist, callback-scoped archive unpacking, fixed redacted proof framing]
key-files:
  created:
    - lib/mix/tasks/verify.adoption_paths.ex
    - priv/adoption_proof/artifact_archive.ex
    - scripts/prove-adoption-paths.exs
  modified:
    - scripts/prove-accrue-consumer.exs
    - priv/adoption_proof/artifact_consumer_fixture.ex
    - mix.exs
    - test/chimeway/release_gate_contract_test.exs
decisions:
  - "The public task accepts only zero arguments or one `--only` selector and rejects invalid input before loading the runner."
  - "Archive validation is package-owned and callback-scoped so every consumer CLI gets the same digest, metadata, containment, and cleanup checks."
  - "The aggregate builds and validates one archive before serial fixture dispatch; fixture output remains the sole evidence authority."
metrics:
  duration: "~46 minutes"
  tasks_completed: 2
  files_modified: 7
completed: 2026-08-09
status: complete
---

# Phase 96 Plan 01: Adoption Proof Command Summary

**A bounded `mix verify.adoption_paths` command now builds one SHA-validated package artifact and emits one redacted authoritative proof for each selected clean-room path.**

## Accomplishments

- Added strict `--only core|mailglass|accrue` parsing that rejects unknown, duplicate, malformed, and positional input before any proof work or record output.
- Extracted Accrue's archive digest, Hex metadata, safe tar, containment, package-member, and cleanup checks into `Chimeway.AdoptionProof.ArtifactArchive`.
- Added a serial runner that builds and unpacks once, then invokes the package fixture's Core, Mailglass, and Accrue proof functions in order.
- Added tagged tracer and aggregate contracts for command parsing, source boundaries, proof framing, and the real three-path aggregate.

## Task Commits

1. **Task 1: Prove the focused Core command through one SHA-validated artifact** — `946f333` (RED), `af2ee3c` (GREEN)
2. **Task 2: Expand the proven runner to exact serial Core, Mailglass, and Accrue dispatch** — `5858f80` (RED), `070f8a8` (GREEN)
3. **Rule 1 correction: retain selected path in setup diagnostics** — `53c39af`

## Verification

- PASS — `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --only adoption_paths_tracer --warnings-as-errors` (2 tests, 0 failures).
- PASS — `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --only adoption_paths_contract --warnings-as-errors` (2 tests, 0 failures; 141.8 seconds).
- PASS — `scripts/test-db env MIX_ENV=test mix verify.adoption_paths --only core`.
- PASS — `scripts/test-db env MIX_ENV=test mix verify.adoption_paths` emitted Core, Mailglass, and Accrue START/evidence/PASS frames in serial order with exit status 0.
- PASS — `mix format --check-formatted` across all plan-owned Elixir files.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Archive compatibility] Support current OTP tar table entries**
- **Found during:** Task 1.
- **Issue:** Current OTP returns simple path entries from `:erl_tar.table/2`; the prior tuple-only iteration rejected otherwise valid package archives.
- **Fix:** Preserve the same safe-path checks while accepting both entry representations.
- **Files modified:** `priv/adoption_proof/artifact_archive.ex`
- **Verification:** Focused Core proof passed from a built archive.

**2. [Rule 1 - Fixture lifecycle] Start only required host children per proof**
- **Found during:** Tasks 1 and 2.
- **Issue:** Core and Mailglass must not start an unmigrated Oban worker, while Accrue requires it for its workflow proof.
- **Fix:** The consumer starts only its repo for Core/Mailglass and adds Oban only for Accrue; the Core proof also scopes Chimeway's dynamic repo to the consumer-owned repo.
- **Files modified:** `priv/adoption_proof/artifact_consumer_fixture.ex`
- **Verification:** Each focused proof and the final aggregate passed.

**3. [Rule 1 - Evidence schema drift] Include the deterministic webhook lifecycle event**
- **Found during:** Task 2 Mailglass proof.
- **Issue:** The fixture emitted the stable `webhook_received` event, but its strict Mailglass schema allowed only the preceding four lifecycle events.
- **Fix:** Added the fixed fifth event to the allowlisted schema and contract fixture.
- **Files modified:** `priv/adoption_proof/artifact_consumer_fixture.ex`, `test/chimeway/release_gate_contract_test.exs`
- **Verification:** Focused Mailglass and aggregate proofs passed.

**4. [Rule 1 - Redacted diagnostics] Preserve the selected path for setup failures**
- **Found during:** Task 2 final review.
- **Issue:** Build/unpack failures always named Core, even for a focused Mailglass or Accrue invocation.
- **Fix:** Fixed the fallback to use the first selected path while retaining fixed stage, status, and rerun fields.
- **Files modified:** `scripts/prove-adoption-paths.exs`
- **Commit:** `53c39af`

**Total deviations:** 4 auto-fixed. **Impact:** The public proof remains bounded and redacted while all three real clean-room paths are executable.

## Known Stubs

None.

## Self-Check: PASSED

- Confirmed all three newly created production files exist.
- Confirmed task commits `946f333`, `af2ee3c`, `5858f80`, `070f8a8`, and `53c39af` exist in git history.
