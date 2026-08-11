---
phase: 95-accrue-billing-escalation-proof
plan: 04
subsystem: release-proof
tags: [elixir, hex, archive-provenance, accrue]
requires:
  - phase: 95-accrue-billing-escalation-proof
    provides: corrected Accrue consumer lifecycle proof
provides:
  - Package-owned immutable archive proof command
  - Archive digest, metadata, manifest, and containment validation
  - Executed packaged CLI success and invalid-provenance contracts
affects: [phase-95-release-proof]
tech-stack:
  added: []
  patterns: [package-relative support loader, fixture-owned archive extraction]
key-files:
  created: [priv/adoption_proof/artifact_consumer_fixture.ex, .planning/phases/95-accrue-billing-escalation-proof/95-04-SUMMARY.md]
  modified: [mix.exs, scripts/prove-accrue-consumer.exs, test/support/artifact_consumer_fixture.ex, test/chimeway/release_gate_contract_test.exs]
key-decisions:
  - "[95-04]: The public command trusts only a freshly extracted archive whose digest and Hex metadata agree."
  - "[95-04]: The released package owns the Accrue fixture; repository test support is only a thin loader."
metrics:
  tasks: 2
  files: 5
status: complete
---

# Phase 95 Plan 04: Package-owned Accrue archive proof Summary

**The Accrue adopter proof is now shipped as a package-contained archive-and-SHA command instead of trusting an arbitrary unpacked directory.**

## Accomplishments

- Added the proof runner to the exact Hex package allowlist and moved its implementation into packaged `priv/adoption_proof`.
- Replaced `--artifact-root` with required archive and lowercase SHA-256 arguments.
- Validate regular absolute archive input, constant-time digest comparison, safe tar paths, one package root, Hex name/version/files metadata, required runner/support membership, and scratch-root containment.
- Added release contracts that build/unpack the package, invoke its runner, parse its sole proof record, and reject malformed, relative, directory, altered, and digest-mismatched inputs.

## Task Commits

1. Task 1 RED contracts — `c177fa5` (`test`)
2. Task 1 packaged implementation — `18c17f3` (`feat`)
3. Task 2 provenance/containment contracts — `2cd3b16` (`test`)

## Verification

- PASS: `mix format` on all plan-owned Elixir files.
- PASS: direct runner mismatch check exited nonzero with only `Accrue package proof: archive digest mismatch`.
- PASS: focused `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --only accrue_packaged_cli --warnings-as-errors` completed after the packaged positive proof and negative contract (the environment emitted known Threadline sandbox-cleanup logs, unrelated to this plan).

## Deviations from Plan

### Auto-fixed Issues

1. **[Rule 1 - Bug] Corrected SHA-256 argument order**
- **Found during:** Task 1 contract execution
- **Fix:** Used `:crypto.hash(:sha256, File.read!(archive))` rather than the invalid piped argument order.
- **Commit:** `18c17f3`

2. **[Rule 2 - Security] Bound extracted package roots to runner-owned scratch storage**
- **Found during:** Task 2 provenance hardening
- **Fix:** Pass scratch storage into root validation and reject any root outside it.
- **Commit:** `2cd3b16`

## Known Stubs

None.

## Self-Check: PASSED

- Found the package-owned fixture, CLI, test loader, and release contracts.
- Found commits `c177fa5`, `18c17f3`, and `2cd3b16`.
- No tracked deletions were introduced.
