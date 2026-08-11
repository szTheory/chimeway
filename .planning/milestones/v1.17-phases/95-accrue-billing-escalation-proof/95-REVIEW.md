---
phase: 95-accrue-billing-escalation-proof
reviewed: 2026-08-10T02:27:40Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - guides/introduction/accrue-dunning-integration.md
  - mix.exs
  - priv/adoption_proof/artifact_consumer_fixture.ex
  - scripts/prove-accrue-consumer.exs
  - test/chimeway/doc_contract_test.exs
  - test/chimeway/release_gate_contract_test.exs
  - test/support/artifact_consumer_fixture.ex
findings:
  critical: 2
  warning: 1
  info: 0
  total: 3
status: issues_found
---

# Phase 95: Code Review Report

**Reviewed:** 2026-08-10T02:27:40Z
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found

## Summary

The packaged command now has a credible lifecycle and provenance flow, but its archive boundary is unsafe. A supplied archive can create filesystem links outside the runner-owned scratch directory and can exhaust the BEAM atom table while its metadata is parsed. The cleanup path also leaks its outer scratch directory for one supported archive layout.

## Critical Issues

### CR-01: Tar extraction permits symlink/hardlink path escape

**Classification:** BLOCKER

**File:** `/Users/jon/projects/chimeway/scripts/prove-accrue-consumer.exs:129`

**Issue:** `extract_contents!/2` validates only the pathname of each tar entry, then calls `:erl_tar.extract/2` at line 142. It does not reject link entry types or validate link targets. A tar entry such as `safe -> /target` (or a hard link), followed by `safe/file`, has a safe entry name and passes line 134, but extraction can write outside `scratch`. The later lexical `Path.expand` containment check cannot undo an already-written file. This breaks the stated guarantee that archive extraction is confined to runner-owned storage.

**Fix:** Reject every non-regular/non-directory entry before extraction, including symbolic links, hard links, devices, FIFOs, and extended link metadata. Prefer a dedicated extraction routine that creates files with `:exclusive` beneath an opened scratch directory and validates every resolved parent is inside that directory. Add a malicious-link archive contract that proves no file is created outside scratch.

### CR-02: Untrusted package metadata is parsed as Erlang terms

**Classification:** BLOCKER

**File:** `/Users/jon/projects/chimeway/scripts/prove-accrue-consumer.exs:98`

**Issue:** `parse_metadata!/1` writes archive-controlled bytes to a temporary file and passes them to `:file.consult/1` (line 108). Erlang term parsing interns any previously unseen atom in the VM permanently. An archive containing a large set of unique atom literals can exhaust the atom table and crash the process/VM before the later metadata allowlist check runs. The archive and expected digest are command inputs, so this is an attacker-controlled parser boundary.

**Fix:** Do not use `:file.consult/1` for externally supplied package metadata. Parse the small expected Hex metadata format with a non-atomizing parser, or verify the archive through Hex tooling/signatures and restrict metadata decoding to existing atoms/binary keys with strict size and entry-count limits. Add a regression test containing unique atom literals and assert rejection without increasing `:erlang.system_info(:atom_count)`.

## Warnings

### WR-01: Successful nested-root archives leak the scratch directory

**Classification:** WARNING

**File:** `/Users/jon/projects/chimeway/scripts/prove-accrue-consumer.exs:24`

**Issue:** `artifact_root!/1` explicitly accepts either `scratch` or a single child package root (lines 148-156), but the success `after` clause deletes only `root`. For a valid archive extracted under a top-level package directory, that leaves the runner-created `scratch` directory behind. This contradicts the documented archive-unpack cleanup guarantee and accumulates directories on every successful invocation.

**Fix:** Return both `scratch` and `root` from `unpack_and_validate/2`, and always delete `scratch` in the outer `after` clause. Add a successful nested-root archive test that asserts the scratch parent no longer exists.

---

_Reviewed: 2026-08-10T02:27:40Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
