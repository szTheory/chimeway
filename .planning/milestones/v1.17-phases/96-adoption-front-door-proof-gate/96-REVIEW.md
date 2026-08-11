---
phase: 96-adoption-front-door-proof-gate
reviewed: 2026-08-10T23:32:31Z
depth: standard
files_reviewed: 12
files_reviewed_list:
  - .github/workflows/ci.yml
  - README.md
  - guides/introduction/adoption-paths.md
  - lib/mix/tasks/verify.adoption_paths.ex
  - mix.exs
  - priv/adoption_proof/artifact_archive.ex
  - priv/adoption_proof/artifact_consumer_fixture.ex
  - scripts/prove-accrue-consumer.exs
  - scripts/prove-adoption-paths.exs
  - test/chimeway/doc_contract_test.exs
  - test/chimeway/release_gate_contract_test.exs
  - test/support/artifact_consumer_fixture.ex
findings:
  critical: 1
  warning: 1
  info: 0
  total: 2
status: issues_found
---

# Phase 96: Code Review Report

**Reviewed:** 2026-08-10T23:32:31Z
**Depth:** standard
**Files Reviewed:** 12
**Status:** issues_found

## Summary

All Phase 96 source files were reviewed, including the final archive hardening and CLI-redaction follow-up. The current archive-specific and CLI regression command still exposes a real timeout failure in a newly added subprocess test. More importantly, the archive validator parses caller-controlled Erlang source terms with `:file.consult/1`; because a caller supplies both archive and digest, this permits permanent VM atom-table exhaustion before archive validation rejects the package.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Caller-controlled archive metadata can exhaust the BEAM atom table

**Classification:** BLOCKER

**File:** `/Users/jon/projects/chimeway/priv/adoption_proof/artifact_archive.ex:86-97`

**Issue:** After accepting only a caller-provided digest (which is not a trust decision), `parse_metadata!/1` writes attacker-controlled `metadata.config` and invokes `:file.consult/1`. Erlang term parsing interns every previously unseen atom in the input permanently. A malicious, correctly-digested archive containing many unique atoms therefore grows the VM atom table until the process/node is denied service; the later `validate_metadata!/1` allowlist cannot undo that mutation. This affects the standalone public `prove-accrue-consumer.exs` boundary as well as the adoption runner.

**Fix:** Do not parse arbitrary Erlang terms from an untrusted archive. Use a bounded metadata format/parser that never creates atoms (for example, parse only the required binary-string fields into a binary-keyed map), or first lexically reject atom tokens and any non-whitelisted metadata grammar before invoking an Erlang term parser. Add an adversarial valid-digest archive test containing many unique atom literals and assert it fails without increasing `:erlang.system_info(:atom_count)`.

## Warnings

### WR-01: New malformed-archive subprocess contract is flaky on a cold environment

**Classification:** WARNING

**File:** `/Users/jon/projects/chimeway/test/chimeway/release_gate_contract_test.exs:1757-1781`

**Issue:** This test has the default 60-second ExUnit timeout but starts up to seven fresh `elixir scripts/prove-accrue-consumer.exs` subprocesses. The focused Phase 96 regression command timed out at line 1781 after 60 seconds while running the malformed-provenance cases (13 tests, 1 failure). The adjacent end-to-end package test already carries a 600-second timeout, so this new process-heavy test can make the release gate fail based on cold compilation or host load rather than behavior.

**Fix:** Add an explicit timeout appropriate for the subprocess loop (for example, `@tag timeout: 600_000`), and keep the exact CLI-output assertions. Alternatively, retain a smaller number of subprocess boundary checks and move pure usage validation to direct unit tests.

---

_Reviewed: 2026-08-10T23:32:31Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
