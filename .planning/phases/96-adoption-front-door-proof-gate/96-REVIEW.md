---
phase: 96-adoption-front-door-proof-gate
reviewed: 2026-08-10T00:00:00Z
depth: standard
files_reviewed: 11
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
findings:
  critical: 2
  warning: 1
  info: 0
  total: 3
status: issues_found
---

# Phase 96: Code Review Report

**Reviewed:** 2026-08-10T00:00:00Z
**Depth:** standard
**Files Reviewed:** 11
**Status:** issues_found

## Summary

The public proof task, selector, CI topology, and archive implementation were reviewed. The focused archive tests pass, but the standalone Accrue command has an unhandled archive-error contract mismatch, and the new archive boundary remains vulnerable to decompression resource exhaustion and a digest/extraction time-of-check/time-of-use race.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Standalone Accrue CLI crashes and leaks an unredacted exception for every archive validation failure

**Classification:** BLOCKER

**File:** `/Users/jon/projects/chimeway/scripts/prove-accrue-consumer.exs:14-35`

**Issue:** `ArtifactArchive.with_validated_archive/3` returns `{:error, reason}` (including for a digest mismatch), but this `with` expression handles only `{:usage, reason}` and `{:provenance, reason}`. Consequently an invalid digest raises `WithClauseError`, printing a stacktrace instead of returning the intended fixed diagnostic and status. Reproduced with the command using `mix.exs` and an all-zero digest; it emitted `** (WithClauseError) no with clause matching: {:error, "archive digest mismatch"}`. This violates the phase's redacted failure surface and makes malformed archive input a crash path.

**Fix:** Match the validator's actual tuple and translate it to the redacted provenance diagnostic:

```elixir
else
  {:usage, message} -> diagnostic(message, @usage)
  {:error, message} -> diagnostic(message, @provenance)
end
```

Add a CLI-level assertion for a digest mismatch and malformed archive that requires a nonzero status, no proof record, and no `** (`/stacktrace output.

### CR-02: Gzip contents are expanded without any resource limit before validation

**Classification:** BLOCKER

**File:** `/Users/jon/projects/chimeway/priv/adoption_proof/artifact_archive.ex:99-105`

**Issue:** `:zlib.gunzip/1` fully decompresses attacker-controlled `contents.tar.gz` before the header scanner can reject it. A small valid-digest package can therefore expand to an arbitrarily large binary and exhaust the process/CI runner's memory. The expected digest does not mitigate this because the public standalone CLI accepts both archive and digest from its caller. This contradicts the phase's explicit denial-of-service boundary for malformed archive contents.

**Fix:** Enforce a documented compressed and decompressed byte limit while streaming inflate data, aborting before accumulating beyond the limit. Apply a maximum member count and per-member size during header scanning, then pass only bounded data to `:erl_tar` (or replace the second whole-archive extraction with the already-scanned bodies).

## Warnings

### WR-01: SHA validation reads a different file instance from the one extracted

**Classification:** WARNING

**File:** `/Users/jon/projects/chimeway/priv/adoption_proof/artifact_archive.ex:21-31`

**Issue:** The validator hashes `File.read!(archive)` and then reopens the pathname via `:erl_tar.extract/2`. A concurrent replacement of that path after line 21 causes the code to validate bytes from the first file and unpack different bytes from the second. The later contents can reach `Code.require_file/1` through the runner despite the advertised SHA validation.

**Fix:** Read the archive once into a binary, calculate the digest from that binary, and call `:erl_tar.extract({:binary, archive_binary}, [:memory])`; alternatively hold and validate one opened file descriptor throughout. Add a regression seam/test that makes the archive source change between the digest and extraction steps and asserts the callback never runs.

---

_Reviewed: 2026-08-10T00:00:00Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
