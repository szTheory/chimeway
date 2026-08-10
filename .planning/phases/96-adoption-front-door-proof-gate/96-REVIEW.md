---
phase: 96-adoption-front-door-proof-gate
reviewed: 2026-08-10T04:00:51Z
depth: standard
files_reviewed: 11
files_reviewed_list:
  - lib/mix/tasks/verify.adoption_paths.ex
  - priv/adoption_proof/artifact_archive.ex
  - scripts/prove-adoption-paths.exs
  - scripts/prove-accrue-consumer.exs
  - priv/adoption_proof/artifact_consumer_fixture.ex
  - mix.exs
  - README.md
  - guides/introduction/adoption-paths.md
  - .github/workflows/ci.yml
  - test/chimeway/doc_contract_test.exs
  - test/chimeway/release_gate_contract_test.exs
findings:
  critical: 1
  warning: 0
  info: 0
  total: 1
status: issues_found
---

# Phase 96: Code Review Report

**Reviewed:** 2026-08-10T04:00:51Z
**Depth:** standard
**Files Reviewed:** 11
**Status:** issues_found

## Summary

The new selector, package surface, CI wiring, and contract tests were reviewed in context. The focused documentation/CI contract suite passes (4 tests), but the shared archive validator accepts link-bearing tar members. Because the standalone Accrue CLI accepts an attacker-supplied archive plus its matching digest, this is an extraction-boundary security defect rather than a theoretical malformed-package case.

## Critical Issues

### CR-01: Archive extraction permits symlink and hard-link escapes

**File:** `priv/adoption_proof/artifact_archive.ex:89-106`

**Issue:** `extract_contents!/2` validates only each member's pathname before calling `:erl_tar.extract/2`. A tar member with a safe-looking name can still be a symbolic link or hard link whose target is outside `scratch`; subsequent entries can be written through it. The later `Path.expand/1` check at lines 120-123 is lexical and does not resolve links, while `File.regular?/1`, `File.read!/1`, and `Code.require_file/1` follow them. Thus a crafted archive accepted by `scripts/prove-accrue-consumer.exs` can write outside the temporary directory and/or cause host files to be read and evaluated as the package fixture. Checking the caller-provided SHA-256 does not provide provenance: an attacker controls both the archive and the digest argument.

**Fix:** Inspect verbose tar metadata before extraction and reject every symlink, hard-link, device, FIFO, or other non-regular/non-directory entry; also reject link targets that are absolute or escape the intended root. Extract only after this validation, and verify containment with real-path resolution (or use an extraction routine that refuses links). Add adversarial tests for a symlinked `mix.exs`/fixture and for a link followed by a regular file entry, asserting no path outside `scratch` is created or read.

---

_Reviewed: 2026-08-10T04:00:51Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
