---
phase: 103-physical-iphone-adoption-truth
plan: "04"
subsystem: physical-iphone-proof-promotion
tags: [elixir, ios, apns, crosswake, physical-proof, documentation]
requires:
  - phase: 103-physical-iphone-adoption-truth
    provides: Selected CrossWake authority, physical-v1 validator, and signed-device runner
provides:
  - Four-file completion-bound physical proof retained with no-replace publication
  - Source-bound CrossWake and Chimeway outcome separation plus isolated visible-alert attestation
  - Promoted-but-bounded mobile support, requirements, roadmap, and project truth
affects: [TWIN-03, DOCS-01, v1.18-closeout]
tech-stack:
  added: []
  patterns:
    - Completion marker written last after three canonical typed records
    - Component and overall bundle digests revalidated from retained bytes
    - Physical support wording accepted only through the verified promoted snapshot
key-files:
  created:
    - evidence/mobile_physical/promoted/chimeway-envelope.json
    - evidence/mobile_physical/promoted/crosswake-record.json
    - evidence/mobile_physical/promoted/visible-alert-attestation.json
    - evidence/mobile_physical/promoted/.complete
  modified:
    - lib/chimeway/mobile_proof/physical_bundle.ex
    - lib/mix/tasks/chimeway.mobile_physical_proof.ex
    - lib/mix/tasks/verify.physical_proof_contract.ex
    - guides/introduction/mobile-adoption-operations.md
    - .planning/REQUIREMENTS.md
    - .planning/ROADMAP.md
    - .planning/PROJECT.md
decisions:
  - "The three typed JSON records are canonical bytes; .complete is written last and binds their digests plus one overall bundle digest."
  - "The explicit observer confirmation is retained only as observed state and an opaque reference, separate from every machine assertion."
  - "physical_support_promoted applies only to this recorded iPhone-first path; provider acceptance remains handoff only."
requirements-completed: [TWIN-03, DOCS-01]
metrics:
  completed: 2026-09-12
  tasks: 2
  files: 18
status: complete
---

# Phase 103 Plan 04: Physical iPhone Proof Promotion Summary

**One genuine signed APNs-sandbox iPhone run is retained as a four-file, completion-bound, no-replace snapshot, and public support truth is promoted only for that recorded path.**

## Accomplishments

- Completed a signed-device run with passed permission, authenticated registration, APNs provider handoff, visible presentation, one-time protected activation, durable delivery, and explainable trace outcomes.
- Replaced the incomplete single-file publisher with three independently typed canonical JSON records and a `.complete` marker that binds component hashes and bundle digest.
- Published opaque run `cw-physical-57aa04f3f7f2c1a81d9d2c93` with bundle digest `e84ba08c151af2f227f2e0a9e550289f576c8004f3f9b65c13b57ba17e3863fc`.
- Published the selected CrossWake revision on the canonical named remote branch and made local/CI verification consume that exact advertised revision.
- Updated the canonical guide and project truth to `physical_support_promoted` while preserving explicit non-claims for receipt breadth, inbox state, engagement, Android/FCM, generic background sync, device management, rich actions, analytics, and broad device support.

## Task Commit

- `fe64123` — physical proof contract, runner, promoted evidence, guide, CI reference, and coordinated planning truth.

## Verification

- `mix chimeway.mobile_physical_proof --verify-promoted --json` — `physical_support_promoted`; completion and all component digests passed.
- `mix ci.verify_gates` — 633 tests, 0 failures, 4 excluded; packaged Accrue lane 3 tests, 0 failures.
- `mix verify.alpha_twin` — emitted the expected hermetic Alpha proof.
- `mix verify.physical_proof_contract` — fresh canonical-remote checkout and focused source-bound proof passed.
- Focused physical bundle/runner suite — 7 tests, 0 failures.
- Retained-evidence and staged-diff scans found no account identifiers or email addresses.

## Deviations from Plan

### Auto-fixed Issues

**1. The planned four-file publication contract had been implemented as one file.**

- Replaced the single file with canonical typed leaves and a last-written digest-bound marker.
- Added retained-directory verification and byte-preserving collision coverage.

**2. The selected CrossWake revision was only available through the local proxy remote.**

- Published the already-tested clean revision to the canonical named branch and verified its advertised SHA before promotion.

**3. The APNs warning-gate script used equivalent but contract-divergent stderr pipe syntax.**

- Normalized the script to the locked Bash `|&` spelling; the targeted test and full release gate pass.

## Privacy and Claim Boundary

No credentials, account identity, device identity, raw provider response, payload, endpoint, native output, log, screenshot, video, or canonical CrossWake source bytes are retained. Provider acceptance proves handoff only; visible presentation and protected activation remain separate facts, and no inbox or engagement state is inferred.

## Next Phase Readiness

Phase 103 implementation and automated acceptance are complete. The v1.18 milestone can proceed to phase verification/audit and closeout without another physical-device run.

## Self-Check: PASSED

- All four promoted files exist and revalidate from their retained bytes.
- The selected CrossWake SHA is advertised by the canonical branch and passes fresh detached verification.
- TWIN-03 and DOCS-01, roadmap, project truth, and the canonical guide agree on the bounded promoted state.
