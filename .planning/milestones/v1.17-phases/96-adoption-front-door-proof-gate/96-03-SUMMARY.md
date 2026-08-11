---
phase: 96-adoption-front-door-proof-gate
plan: "03"
subsystem: adoption-proof
tags: [elixir, tar, artifact-security, release-gate]
requires:
  - phase: 96-adoption-front-door-proof-gate
    provides: shared packaged-artifact proof runner and CI topology
provides:
  - fail-closed tar header classifier for adoption artifacts
  - in-memory regular-file materialization under private scratch
  - adversarial archive regression contracts
affects: [GATE-01, GATE-02, DOCS-01]
tech-stack:
  added: []
  patterns: [classify-before-write, memory-only-tar-extraction, post-write-lstat]
key-files:
  created: []
  modified:
    - priv/adoption_proof/artifact_archive.ex
    - test/chimeway/release_gate_contract_test.exs
decisions:
  - "Matching caller-provided SHA-256 is transport integrity only; tar member type and path validation remains mandatory."
  - "Only regular-file and directory headers may reach memory extraction and explicit contained writes."
  - "Hosted verify_adoption_paths evidence is machine-checked at an exact implementation SHA together with its required pr-gate consumer."
metrics:
  tasks_completed: 2
  files_modified: 2
completed: 2026-08-10
status: complete
---

# Phase 96 Plan 03: Archive Safety Gap Closure Summary

**The shared adoption-artifact seam now rejects link-bearing and special tar members before any scratch write, then materializes only scanned regular-file bytes in memory.**

## Accomplishments

- Replaced filesystem tar extraction with a full tar-header scan, strict regular-file/directory allowlist, bounded size/padding validation, and explicit contained writes.
- Rejects symbolic and hard links, devices, FIFOs, sparse/contiguous records, PAX/extension metadata, malformed headers, absolute/traversal paths, duplicates, and file/directory conflicts before callbacks.
- Performs an lstat walk before mix.exs inspection or fixture loading, so validation and Code.require_file/1 cannot follow archive-created links.
- Added valid-digest adversarial contracts for outside-create, outside-read/load, special-member, malformed, traversal, and conflicting-path cases while proving normal directory and regular-file archives still invoke the callback.

## Task Commits

1. Task 1 RED: Reject a symbolic-link escape before any artifact byte reaches scratch — e5ca13f
2. Task 1 GREEN: Materialize adoption archives safely — 8dad070
3. Task 2: Cover every special tar type and lock the archive boundary against regression — cf2bf7a

## Verification

- PASS — focused adoption_archive_security release-gate command (6 tests, 0 failures).
- PASS — mix format --check-formatted for both plan-owned files.
- PARTIAL — the real packaged Core command reached [adoption:core] START, confirming the new validator accepted a built package before the runner began; its terminal result was not captured by the execution harness.
- FAIL (unrelated to Plan 03 files; retried) — mix ci.verify_gates failed existing release-gate cases at release_gate_contract_test.exs:1228 (Mailglass fixture timeline_events) and :1622 (existing Accrue proof source assertion). Neither owning file was modified by this plan.
- PASS — exact-SHA GitHub Actions run `31449129603` recorded successful `verify_adoption_paths` and `pr-gate` jobs at `c13bae7c92c537f3e758330703168119703a301b`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Archive compatibility] Permit explicit directory parents while retaining file/path conflict rejection**
- **Found during:** Task 2.
- **Issue:** A broad prefix-conflict check would reject ordinary archives that declare a directory before files beneath it.
- **Fix:** Track each normalized member's type and reject only duplicates or paths nested beneath an existing regular file.
- **Files modified:** priv/adoption_proof/artifact_archive.ex, test/chimeway/release_gate_contract_test.exs
- **Commit:** cf2bf7a

### Deferred Verification

- mix ci.verify_gates is red in pre-existing Mailglass/Accrue release-gate contracts outside this plan's files. It was retried without change; no unrelated fix was applied.
- Live verify_adoption_paths GitHub Actions execution was subsequently closed by the exact-SHA machine-readable evidence above.

## Known Stubs

None.

## Self-Check: PASSED

- Confirmed both plan-owned source/test files exist.
- Confirmed commits e5ca13f, 8dad070, and cf2bf7a exist in git history.
