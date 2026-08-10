---
phase: 96-adoption-front-door-proof-gate
verified: 2026-08-10T00:00:00Z
status: gaps_found
score: 4/6 must-haves verified
behavior_unverified: 1
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 4/6
  gaps_closed: []
  gaps_remaining:
    - "The shared archive-validation seam safely validates and unpacks proof artifacts before fixture code is loaded."
  regressions: []
gaps:
  - truth: "The shared archive-validation seam safely validates and unpacks proof artifacts before fixture code is loaded."
    status: failed
    reason: "CR-01 is confirmed by source: tar member names receive only lexical checks before :erl_tar.extract/2 extracts all member types. Subsequent File.regular?/1, File.read!/1, and Code.require_file/1 operations follow links; the caller-controlled SHA-256 only proves equality with caller input, not archive trust."
    artifacts:
      - path: "priv/adoption_proof/artifact_archive.ex"
        issue: "Lines 89-106 validate member names but do not reject symlinks, hard links, devices, FIFOs, or other non-regular/non-directory entries before extraction. Lines 120-129 use lexical containment and link-following file operations."
      - path: "test/chimeway/release_gate_contract_test.exs"
        issue: "The archive cases cover malformed/digest-altered archives but no symlink or hard-link escape case."
    missing:
      - "Reject every non-regular/non-directory tar member before extraction, including symbolic and hard links."
      - "Use link-safe extraction or real-path containment and add adversarial tests proving a link cannot create, read, or load a file outside scratch."
behavior_unverified_items:
  - truth: "CI executes the dedicated adoption proof lane successfully in its PostgreSQL-backed GitHub Actions environment."
    test: "Push the current branch or dispatch CI and inspect the verify_adoption_paths job."
    expected: "The job runs mix verify.adoption_paths once, emits bounded per-path diagnostics on failure, and ci-gate receives its result."
    why_human: "Workflow source proves topology only. This report-only recovery did not run tests or CI, and 96-02-SUMMARY.md records the first live CI execution as pending."
---

# Phase 96: Adoption Front Door & Proof Gate Verification Report

**Phase Goal:** Prospective adopters can choose the right canonical path, understand ownership boundaries, and rely on CI-backed commands and documentation that remain truthful over time.
**Verified:** 2026-08-10T00:00:00Z
**Status:** gaps_found
**Re-verification:** Yes — report recovery; no tests or long-running commands were run.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Adopters can choose Core, Mailglass, or Accrue and see host, Chimeway, and partner responsibilities. | ✓ VERIFIED | `guides/introduction/adoption-paths.md:5-63` contains exactly those three ordered paths, each with separate responsibility statements. |
| 2 | Every path provides a copyable proof command, sanitized evidence, and an explicit coverage limit. | ✓ VERIFIED | Each selector section includes its literal focused command, one `CHIMEWAY_*_PROOF` record shape, and `Does not cover` boundary. |
| 3 | `mix verify.adoption_paths` routes the clean-room proof paths without invoking detailed partner suites. | ✓ VERIFIED | `lib/mix/tasks/verify.adoption_paths.ex:11-24` strictly loads the runner only after parsing; `scripts/prove-adoption-paths.exs:71-80` dispatches only the three fixture proof functions. |
| 4 | A dedicated PostgreSQL-backed CI lane runs the aggregate command and reports its result to `ci-gate`. | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | `.github/workflows/ci.yml:1130-1167` defines a non-PR PostgreSQL 15 job; `:1341-1365` connects its result through all three `ci-gate` edges. No live CI execution was verified. |
| 5 | Contracts cover selector, command, package surface, and CI topology drift. | ✓ VERIFIED | `test/chimeway/doc_contract_test.exs:1968+` and `test/chimeway/release_gate_contract_test.exs:1846-1958` contain focused static and mutation-oriented contracts for those links. |
| 6 | The archive-validation boundary is safe before code from an artifact is loaded. | ✗ FAILED — BLOCKER | CR-01 is confirmed: `artifact_archive.ex:89-106` extracts after path-name-only checks; `:120-129` then reads link-following paths. |

**Score:** 4/6 truths verified (1 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `lib/mix/tasks/verify.adoption_paths.ex` | Strict public task | ✓ VERIFIED | Bounded selector parsing occurs before runner loading. |
| `scripts/prove-adoption-paths.exs` | Build-once serial runner | ✓ VERIFIED | Static Core → Mailglass → Accrue fixture dispatch and fixed framing are present. |
| `priv/adoption_proof/artifact_archive.ex` | Safe shared digest/unpack seam | ✗ UNSAFE | Substantive and wired, but its extraction boundary permits link-bearing archives. |
| `guides/introduction/adoption-paths.md` | Canonical selector | ✓ VERIFIED | Three complete selector sections; README and first ExDoc-extra wiring exists. |
| `.github/workflows/ci.yml` | Dedicated proof lane | ⚠️ WIRED, LIVE RUN UNVERIFIED | Static job/service/aggregation topology exists; it was not executed in this recovery. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- |
| `README.md` | adoption selector | Quick Start route | ✓ WIRED | `README.md:102` points to `guides/introduction/adoption-paths.md`. |
| Mix task | proof runner | `Code.require_file` + `AdoptionProofRunner.run!` | ✓ WIRED | `verify.adoption_paths.ex:12-19`. |
| proof runner | archive validator | `with_validated_archive/3` | ✗ WIRED BUT UNSAFE | `prove-adoption-paths.exs:14-26` reaches the vulnerable shared seam. |
| CI job | aggregate task and `ci-gate` | command, needs, env, aggregate args | ✓ WIRED | Source has `mix verify.adoption_paths`, `verify_adoption_paths` need, result env, and aggregate argument. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| adoption runner | `proof.output` | Fixture `prove_*!/2` result | Parsed then emitted directly | ✓ FLOWING |
| archive validator | `root` | Archive extraction | Can be redirected through accepted link members before `Code.require_file/1` | ✗ UNSAFE FLOW |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Phase 96 runnable behavior | Not run by instruction | Report-only recovery; no tests or long commands executed | ? SKIPPED |

### Requirements Coverage

| Requirement | Source Plan | Status | Evidence |
| --- | --- | --- | --- |
| ADPT-01 | 96-02 | ✓ SATISFIED | Source selector presents all three outcome paths and ownership boundaries. |
| ADPT-02 | 96-02 | ✓ SATISFIED | Each path has a literal command, representative sanitized record, and explicit limitation. |
| GATE-01 | 96-01 | ✗ BLOCKED | The command avoids partner suites, but its shared artifact trust boundary is unsafe, so the claimed trustworthy clean-room gate is not achieved. |
| GATE-02 | 96-02 | ? NEEDS HUMAN | The dedicated PostgreSQL topology is wired, but no live GitHub Actions run was verified. |
| DOCS-01 | 96-01, 96-02 | ✓ SATISFIED | Contract modules statically cover selector, command, package membership, and CI topology drift. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `priv/adoption_proof/artifact_archive.ex` | 89-106 | Extracts after pathname-only validation | 🛑 BLOCKER | Link-bearing tar entries can escape scratch and cause external files to be written, read, or loaded. |
| `test/chimeway/release_gate_contract_test.exs` | archive tests | No link-escape regression case | 🛑 BLOCKER | The shared boundary lacks a test that would prevent recurrence. |

### Human Verification Required

### 1. Live adoption CI lane

**Test:** Push or dispatch CI and open `verify_adoption_paths`.
**Expected:** One PostgreSQL-backed aggregate proof runs and `ci-gate` consumes its result.
**Why human:** Static workflow inspection cannot establish runner behavior in GitHub Actions.

### Gaps Summary

CR-01 remains a blocking failure. The archive validator's SHA comparison is not provenance because the standalone Accrue CLI accepts both the archive and digest from its caller. An archive with safe-looking names but link-bearing members is extracted before the validator establishes a link-safe containment boundary; later file reads and fixture loading follow those links. No contrary source evidence or symlink/hard-link regression test exists. This is an escalation gate for a developer decision and remediation; Phase 96 must not proceed as passed.

_Verified: 2026-08-10T00:00:00Z_
_Verifier: the agent (gsd-verifier)_
