---
phase: 96-adoption-front-door-proof-gate
verified: 2026-08-10T17:15:00-04:00
status: gaps_found
score: 3/7 must-haves verified
behavior_unverified: 1
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 4/6
  gaps_closed:
    - "Link-bearing archive members are rejected before filesystem materialization or fixture loading."
  gaps_remaining:
    - "Archive validation and the standalone Accrue command still fail unsafe-input trust boundaries."
    - "mix ci.verify_gates is not green."
  regressions: []
gaps:
  - truth: "The clean-room aggregate proof is safe and redacts failures across its Core, Mailglass, and Accrue entrypoints."
    status: failed
    reason: "The standalone Accrue CLI does not match ArtifactArchive's {:error, reason} result, so an invalid digest raises WithClauseError and prints a stacktrace. The archive validator also fully gunzips caller-controlled contents before any size/member limit is enforced."
    artifacts:
      - path: "scripts/prove-accrue-consumer.exs"
        issue: "The with else only matches {:usage, message} and {:provenance, message}; a validator {:error, message} is unhandled."
      - path: "priv/adoption_proof/artifact_archive.ex"
        issue: ":zlib.gunzip/1 expands the entire untrusted contents.tar.gz with no compressed/decompressed byte, member-count, or member-size limit."
    missing:
      - "Translate {:error, reason} to the fixed provenance diagnostic and add CLI-level malformed/digest regression tests requiring no stacktrace or proof record."
      - "Bound compressed and decompressed archive input, member count, and member size before materializing or parsing the contents."
  - truth: "The Phase 96 release-gate evidence is green."
    status: failed
    reason: "The verifier ran mix ci.verify_gates and it failed in release_gate_contract_test.exs:1622. Execution records also identify a Mailglass contract failure near :1228; no accepted override exists."
    artifacts:
      - path: "test/chimeway/release_gate_contract_test.exs"
        issue: "The full release-gate entrypoint is red, so it cannot certify the phase's contract-checked guidance/release-gate parity."
    missing:
      - "Resolve the failing release-gate contract cases and rerun mix ci.verify_gates successfully."
  - truth: "The archive digest protects the exact bytes that are extracted."
    status: partial
    reason: "The validator hashes File.read!(archive) and separately reopens archive by pathname for :erl_tar.extract/2. A replacement between those operations can make the validated bytes differ from the extracted bytes."
    artifacts:
      - path: "priv/adoption_proof/artifact_archive.ex"
        issue: "Digest and extraction use separate reads of a mutable pathname."
    missing:
      - "Extract from the already validated archive binary (or hold one file descriptor) and add a replacement-race regression test."
behavior_unverified_items:
  - truth: "CI executes the dedicated adoption proof lane successfully in its PostgreSQL-backed GitHub Actions environment."
    test: "Push the current branch or dispatch CI and inspect the verify_adoption_paths job."
    expected: "The PostgreSQL 15 job runs mix verify.adoption_paths once, emits bounded per-path diagnostics if it fails, and ci-gate receives its result."
    why_human: "Workflow source and static contract tests prove topology only; no hosted run URL or successful result was supplied."
---

# Phase 96: Adoption Front Door & Proof Gate Verification Report

**Phase Goal:** Prospective adopters can choose the right canonical path, understand ownership boundaries, and rely on CI-backed commands and documentation that remain truthful over time.
**Verified:** 2026-08-10T17:15:00-04:00
**Status:** gaps_found
**Re-verification:** Yes — after Plan 96-03 archive-link closure.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | An adopter can choose Core, Mailglass, or Accrue and see the host, Chimeway, and partner responsibilities. | ✓ VERIFIED | `guides/introduction/adoption-paths.md` has exactly those three ordered sections and each names all three responsibility boundaries. The focused documentation contract passed. |
| 2 | Each path supplies a copyable command, sanitized expected evidence, and an explicit coverage limit. | ✓ VERIFIED | Each selector section contains `mix verify.adoption_paths --only <path>`, one matching `CHIMEWAY_*_PROOF` example, and `Does not cover`; `adoption_paths_docs_contract` passed. |
| 3 | `mix verify.adoption_paths` provides a trustworthy clean-room aggregate without repository partner suites. | ✗ FAILED — BLOCKER | Static dispatch is bounded to the three fixture functions, but the shared archive boundary has an unbounded decompression path and the standalone Accrue consumer leaks raw exception details for ordinary validator errors. |
| 4 | CI runs the aggregate command in one PostgreSQL-backed adoption lane and surfaces the result. | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | `.github/workflows/ci.yml:1130-1184` defines exactly one non-PR PostgreSQL 15 job and `:1344,1363-1365` joins it to `ci-gate`; no hosted execution was observed. |
| 5 | Contracts keep selector, commands, fixture guidance, and CI topology from silently drifting. | ✓ VERIFIED | Focused doc and CI-topology contracts passed (1 and 2 tests respectively); package, task, runner, selector, service, and gate links are asserted in source. |
| 6 | Artifact validation is safe before proof fixture code is loaded. | ✗ FAILED — BLOCKER | Plan 96-03 correctly closes the symlink/special-member escape (six focused security tests pass), but whole-input gunzip has no resource limits and mutable-path digest/extract operations retain a TOCTOU gap. |
| 7 | The phase's release-gate evidence is green. | ✗ FAILED — BLOCKER | `mix ci.verify_gates` was run and failed at `test/chimeway/release_gate_contract_test.exs:1622`; prior phase execution evidence also records a failure near `:1228`. |

**Score:** 3/7 truths verified (1 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `guides/introduction/adoption-paths.md` | Canonical three-path selector | ✓ VERIFIED | Complete static selector and contract coverage. |
| `lib/mix/tasks/verify.adoption_paths.ex` | Strict task facade | ✓ VERIFIED | Strict selector parsing precedes runner load. |
| `scripts/prove-adoption-paths.exs` | Build-once serial dispatcher | ✓ VERIFIED | Calls only Core → Mailglass → Accrue fixture proof functions with fixed framing. |
| `priv/adoption_proof/artifact_archive.ex` | Safe validated archive boundary | ✗ UNSAFE | Link materialization is fixed; unbounded decompression and digest/extraction TOCTOU remain. |
| `scripts/prove-accrue-consumer.exs` | Redacted standalone Accrue failure surface | ✗ UNSAFE | Invalid digest produces `WithClauseError` stacktrace. |
| `.github/workflows/ci.yml` | Dedicated PostgreSQL proof lane | ⚠️ WIRED, LIVE RUN UNVERIFIED | Static CI topology contract passes. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `README.md` | adoption selector | Quick Start link | ✓ WIRED | README routes to `guides/introduction/adoption-paths.md`. |
| Mix task | proof runner | `Code.require_file` + `AdoptionProofRunner.run!/1` | ✓ WIRED | `lib/mix/tasks/verify.adoption_paths.ex:11-20`. |
| proof runner | archive validator | `with_validated_archive/3` | ✗ WIRED BUT UNSAFE | The callback is connected, but its trust boundary has the two blocker defects above. |
| CI job | aggregate task and `ci-gate` | job command, `needs`, environment, aggregate arguments | ✓ WIRED | Job invokes `mix verify.adoption_paths`; ci-gate consumes `VERIFY_ADOPTION_PATHS`. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| adoption runner | `proof.output` | `ArtifactConsumerFixture.prove_*!/2` | Parsed then directly emitted | ✓ FLOWING |
| archive validator | unpacked root | caller archive path | Link-safe materialization passes, but full gzip expansion is unbounded and extraction can use a later file instance | ✗ UNSAFE FLOW |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Link/special-member archive rejection | focused `adoption_archive_security` release-gate test | 6 tests, 0 failures | ✓ PASS |
| Phase-owned formatting | `mix format --check-formatted` for Plan 96-03 files | exit 0 | ✓ PASS |
| Full release-gate entrypoint | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix ci.verify_gates` | failed at `release_gate_contract_test.exs:1622` | ✗ FAIL |
| Standalone invalid-digest redaction | `elixir scripts/prove-accrue-consumer.exs ... --sha256 000...` | emitted `WithClauseError` and stacktrace | ✗ FAIL |

### Requirements Coverage

| Requirement | Source Plan | Status | Evidence |
| --- | --- | --- | --- |
| ADPT-01 | 96-02 | ✓ SATISFIED | Selector has all three paths and explicit ownership boundaries. |
| ADPT-02 | 96-02 | ✓ SATISFIED | Every path exposes a literal command, safe record, and coverage boundary. |
| GATE-01 | 96-01, 96-03 | ✗ BLOCKED | Dispatch is bounded, but the archive/CLI trust boundary is unsafe. |
| GATE-02 | 96-02 | ? NEEDS HUMAN | Topology is contract-checked, but no live GitHub Actions proof exists. |
| DOCS-01 | 96-01, 96-02 | ⚠️ PARTIAL | Focused drift contracts pass, but the required full release-gate entrypoint is red. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `scripts/prove-accrue-consumer.exs` | 14-35 | Unmatched `{:error, reason}` result | 🛑 BLOCKER | Malformed/digest-invalid input exposes exception details. |
| `priv/adoption_proof/artifact_archive.ex` | 21-26, 99-105 | Separate digest/extraction reads; whole-buffer `:zlib.gunzip/1` | 🛑 BLOCKER / ⚠️ WARNING | Unbounded resource use and a mutable-path integrity race. |

### Human Verification Required

### 1. Live adoption CI lane

**Test:** Push or dispatch CI and open `verify_adoption_paths`.
**Expected:** One PostgreSQL-backed aggregate proof runs and `ci-gate` consumes its result.
**Why human:** Static workflow inspection cannot establish GitHub-hosted execution.

### Gaps Summary

Plan 96-03 successfully fixed the prior link-bearing archive escape. It did not resolve the separately reviewed unsafe-input paths: an unbounded gzip expansion, a digest/extract TOCTOU window, and an unhandled archive validator result in the standalone Accrue CLI that leaks a stacktrace. The release-gate command is also currently red. These are blockers for a proof gate that adopters are meant to trust; Phase 96 must not be marked passed. No later milestone phase exists to defer these items to.

_Verified: 2026-08-10T17:15:00-04:00_
_Verifier: the agent (gsd-verifier)_
