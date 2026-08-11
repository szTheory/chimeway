---
phase: 96-adoption-front-door-proof-gate
plan: "04"
subsystem: adoption-proof
tags: [elixir, hex, archive-security, zlib, tar]
requires:
  - phase: 96-adoption-front-door-proof-gate
    provides: link-safe archive materialization and adoption proof topology
provides:
  - immutable single-read archive validation
  - bounded gzip expansion and tar-member resource controls
  - race and resource-limit release-gate regressions
affects: [GATE-01, DOCS-01]
tech-stack:
  added: []
  patterns: [single-read-validation, bounded-binary-read, streaming-inflate, pre-materialization-budgets]
key-files:
  created:
    - .planning/phases/96-adoption-front-door-proof-gate/96-04-SUMMARY.md
  modified:
    - priv/adoption_proof/artifact_archive.ex
    - test/chimeway/release_gate_contract_test.exs
decisions:
  - "The accepted SHA-256 and outer tar extraction share one bounded immutable binary, eliminating pathname replacement between validation and extraction."
  - "Adoption proof archives cap outer bytes at 32 MiB, compressed contents at 16 MiB, expanded tar bytes at 64 MiB, members at 4,096, and regular members at 8 MiB."
  - "Gzip inflation is incremental and rejects malformed or trailing input before tar-body extraction and scratch materialization."
metrics:
  tasks_completed: 2
  files_modified: 2
completed: 2026-08-10
status: complete
---

# Phase 96 Plan 04: Immutable Archive and Resource Limits Summary

**The packaged adoption proof now validates and extracts exactly one bounded archive byte sequence, while every decompression and tar-materialization dimension fails closed at an explicit limit.**

## Accomplishments

- Replaced the digest/read-then-path-extract sequence with one bounded binary read, SHA-256 over that binary, and in-memory outer tar extraction from the same value.
- Added 32 MiB outer, 16 MiB compressed, 64 MiB expanded, 4,096-member, and 8 MiB regular-member budgets before any archive-controlled scratch write.
- Replaced whole-buffer gzip expansion with incremental `:zlib.safeInflate/2` processing and retained the prior link/type/path reject-before-write protections.
- Added focused release-gate regression coverage for immutable-byte validation, every over-budget boundary, exact 8 MiB member acceptance, and normal callback behavior.

## Task Commits

1. Task 1 RED: Add failing immutable archive regression — 7a58c1e
2. Task 1 GREEN: Bind archive validation to immutable bytes — 9d7187b
3. Task 2 RED: Add failing archive budget regression — 167fde3
4. Task 2 GREEN: Bound adoption archive resources — 9380bf6

## Verification

- PASS — `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --only adoption_archive_limits --only adoption_archive_toctou --only adoption_archive_security --warnings-as-errors` (10 tests, 0 failures).
- PASS — `mix format --check-formatted priv/adoption_proof/artifact_archive.ex test/chimeway/release_gate_contract_test.exs`.
- PASS — source scan confirms no caller-controlled `File.read!(archive)`, pathname-based outer extraction, or `:zlib.gunzip/1` remains.
- PASS — `mix hex.build --output /tmp/chimeway-96-04.tar` builds the production `chimeway 1.1.1` archive successfully; normal archives remain far below all selected limits.

## Decisions Made

- Immutable package identity is a bounded binary, not a mutable pathname: hashing and extraction use the same bytes.
- Resource limits are deliberately local to the private archive seam, preserving all proof commands, evidence records, selector copy, and CI topology.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED

- Confirmed `priv/adoption_proof/artifact_archive.ex` and `test/chimeway/release_gate_contract_test.exs` exist.
- Confirmed commits 7a58c1e, 9d7187b, 167fde3, and 9380bf6 exist in git history.
