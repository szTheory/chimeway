---
phase: 96-adoption-front-door-proof-gate
verified: 2026-08-10T23:25:44Z
status: human_needed
score: 5/7 must-haves verified
behavior_unverified: 2
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 3/7
  gaps_closed:
    - "Standalone Accrue validator failures are redacted rather than raising WithClauseError."
    - "Archive validation bounds caller-controlled input and validates/extracts one immutable binary."
    - "The canonical mix ci.verify_gates contract gate is green."
  gaps_remaining: []
  regressions: []
behavior_unverified_items:
  - truth: "The archive digest is computed from the same immutable bytes that are extracted when the caller replaces the pathname concurrently."
    test: "During with_validated_archive/3, replace the supplied pathname after its bounded read begins, then verify the callback reads only the originally accepted archive contents."
    expected: "The callback succeeds only for the bytes that were hashed and parsed; no replacement bytes are read or materialized."
    why_human: "The implementation uses one in-memory binary for hashing and extraction, but the existing adoption_archive_toctou test is a happy-path/source-shape check and does not perform a concurrent replacement."
  - truth: "CI executes the dedicated adoption proof lane successfully in its PostgreSQL-backed GitHub Actions environment."
    test: "Push or dispatch the current branch and inspect the verify_adoption_paths job and ci-gate."
    expected: "One PostgreSQL 15 job runs mix verify.adoption_paths, reports a bounded failed path/stage if it fails, and ci-gate consumes its result."
    why_human: "Workflow source and local contracts prove topology only; no hosted successful run URL/result was available."
human_verification:
  - test: "Concurrent archive pathname replacement"
    expected: "Only the originally read immutable archive bytes are hashed, parsed, and materialized."
    why_human: "The production flow is correct by inspection, but no regression test triggers the asserted replacement race."
  - test: "Live verify_adoption_paths GitHub Actions lane"
    expected: "The PostgreSQL 15 lane succeeds and ci-gate consumes its result."
    why_human: "Static workflow contracts cannot prove a hosted runner completed the job."
---

# Phase 96: Adoption Front Door & Proof Gate Verification Report

**Phase Goal:** Prospective adopters can choose the right canonical path, understand ownership boundaries, and rely on CI-backed commands and documentation that remain truthful over time.
**Verified:** 2026-08-10T23:25:44Z
**Status:** human_needed
**Re-verification:** Yes — after Plans 96-04 and 96-05 gap closure.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | An adopter can choose Core, Mailglass, or Accrue and see the host, Chimeway, and partner responsibilities. | ✓ VERIFIED | `guides/introduction/adoption-paths.md:7-62` has exactly the three ordered paths, each with separately named Host, Chimeway, and Partner responsibility. |
| 2 | Each chosen path provides a copyable proof command, expected sanitized explainability evidence, and an explicit statement of what the proof does not cover. | ✓ VERIFIED | Each selector section contains its literal focused command, one `CHIMEWAY_*_PROOF` representative record, and a `Does not cover` boundary; package/doc contracts cover command and record drift. |
| 3 | `mix verify.adoption_paths` executes the clean-room paths without rerunning detailed repository partner suites. | ✓ VERIFIED | The runner has a fixed `[:core, :mailglass, :accrue]` serial table and invokes only package fixture `prove_*!/2` functions. `adoption_paths_contract` executes `mix verify.adoption_paths`, asserts exit 0, ordered START frames, and exactly one record per path; its source rejects maintainer-suite, sibling-checkout, matrix, Compose, and async mechanisms. |
| 4 | CI runs that command in one dedicated PostgreSQL-backed adoption lane and surfaces enough per-path diagnostics. | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | `.github/workflows/ci.yml:1130-1188` defines one non-PR PostgreSQL 15 lane with `mix verify.adoption_paths`; `:1343-1365` passes its result through `VERIFY_ADOPTION_PATHS` to `ci-gate`. Static topology contracts exist, but hosted execution was not directly observed. |
| 5 | Contracts prevent selector, command, fixture-guidance, and CI-entrypoint drift. | ✓ VERIFIED | `doc_contract_test.exs` and `release_gate_contract_test.exs:2161-2278` assert package membership, exact commands and records, selector/guide links, CI service/job/gate wiring, and destructive in-memory mutations. |
| 6 | Archive input is fail-closed before fixture loading, bounded, and its accepted digest applies to the bytes extracted. | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | `artifact_archive.ex:15-53` reads one bounded binary, hashes it, then extracts from `{:binary, archive_binary}`; `:147-335` enforces compressed/decompressed/member budgets and rejects non-file/directory records before writes. Security/limit tests cover links, special members, and limits, but no test performs the concurrent pathname replacement asserted by the ordering invariant. |
| 7 | The phase release-gate evidence is green. | ✓ VERIFIED | The supplied post-Plan-05 evidence records canonical `mix ci.verify_gates` success: 611 tests, 0 failures, 486.8s. The verifier also launched the same canonical command; it remained active in the shared workspace at report time, so this row relies on the supplied authoritative result rather than a SUMMARY claim. |

**Score:** 5/7 truths verified (2 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `guides/introduction/adoption-paths.md` | Canonical three-path selector | ✓ VERIFIED | Substantive 63-line selector, linked from README and first in ExDoc extras. |
| `lib/mix/tasks/verify.adoption_paths.ex` | Strict task facade | ✓ VERIFIED | `OptionParser` rejects invalid/duplicate/positional arguments before `Code.require_file`; valid input dispatches the runner. |
| `scripts/prove-adoption-paths.exs` | Build-once serial dispatcher | ✓ VERIFIED | Builds once, validates once, iterates the fixed path list, validates fixture-owned output, and produces fixed redacted framing. |
| `priv/adoption_proof/artifact_archive.ex` | Safe archive boundary | ✓ VERIFIED (ordering behavior pending) | 429 lines of bounded read, digest, metadata, streaming inflate, tar scan, contained materialization, and cleanup—not a stub. |
| `scripts/prove-accrue-consumer.exs` | Redacted standalone Accrue surface | ✓ VERIFIED | Handles `{:error, _reason}` with the fixed provenance diagnostic/65 status and does not interpolate the reason. |
| `.github/workflows/ci.yml` | Dedicated PostgreSQL lane | ⚠️ WIRED, live run unverified | Job, service, task, gate dependency, environment result, and aggregate argument are static-contract tested. |
| `test/support/artifact_consumer_fixture.ex` | Current-source fixture contract | ✓ VERIFIED | Marks the package fixture as `@external_resource` before requiring it, preventing stale test-support compilation. |

All 17 declared artifacts passed the tool's existence/substance checks. No artifact is missing, stubbed, or orphaned.

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| Mix task | adoption runner | strict parse → `Code.require_file` → `apply(..., :run!, [paths])` | ✓ WIRED | The generic link probe misses the indirect `apply/3`, but task lines 12-20 directly establish the call after parse success. |
| Runner | archive validator | `with_validated_archive/3` | ✓ WIRED | One built archive and SHA enter the callback-scoped validator before fixture loading. |
| Runner | package fixture | fixed Core → Mailglass → Accrue function map | ✓ WIRED | `production_proof_function/1` contains only the three package proof entrypoints. |
| README | selector | concise Adoption Paths link | ✓ WIRED | `README.md:102,158` routes without duplicating selector content. |
| Selector | detailed guides | per-path next-step links | ✓ WIRED | Core, Mailglass, and Accrue link to their respective canonical guide. |
| CI lane | task and `ci-gate` | job command, `needs`, result env, aggregate argument | ✓ WIRED | The static CI contract verifies all three gate coupling points; hosted completion remains human verification. |
| Accrue CLI | archive validator | `{:error, _reason}` → fixed diagnostic/65 | ✓ WIRED | The generic source-to-command probe is not a meaningful direct import link; the CLI result algebra is present and covered by the release-gate test. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Adoption runner | `proof.output` | `ArtifactConsumerFixture.prove_*!/2` from the validated package root | Parsed by the fixture's strict per-path parser, then emitted unchanged | ✓ FLOWING |
| Archive validator | `archive_binary` / unpacked root | one bounded `File.open`/`IO.binread`, then in-memory outer extraction and bounded inner extraction | Metadata, required members, and materialized root derive from the same archive binary | ✓ FLOWING (replacement race unexercised) |
| Selector | commands/evidence/limits | literal contract-checked guide content | README/ExDoc package surface exposes the document | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Focused tagged contract invocation | requested multi-`--only` release/doc contract command | The command remained in the shared test database during inspection and its completion result was unavailable. Its multiple tag filters intersect in ExUnit, so it is not used as proof of all requested tags. | ? IN PROGRESS |
| Canonical documentation/release gate | `mix ci.verify_gates` | Supplied authoritative post-Plan-05 result: 611 tests, 0 failures, 486.8s. Verifier also launched the exact command; it was still active in the shared workspace at report time. | ✓ PASS (supplied authoritative evidence) |

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| ADPT-01 | 96-02, 96-03 | Choose the appropriate path and understand responsibility boundaries. | ✓ SATISFIED | Complete, separate responsibility fields for all three canonical paths. |
| ADPT-02 | 96-02, 96-03 | Document command, outcome, and coverage boundary per path. | ✓ SATISFIED | Literal commands, sanitized records, explicit exclusions, and guide links are contract protected. |
| GATE-01 | 96-01, 96-03, 96-04, 96-05 | Run clean-room proofs without detailed partner suites. | ✓ SATISFIED | Real aggregate contract proves fixed fixture-only serial dispatch; archive and CLI boundaries are fail-closed. |
| GATE-02 | 96-02, 96-03 | CI runs the proof entrypoint in a PostgreSQL lane with useful diagnostics. | ? NEEDS HUMAN | Workflow and contracts prove configuration/wiring, but hosted execution is not observed. |
| DOCS-01 | 96-01, 96-02, 96-03, 96-04, 96-05 | Contract-check front door, commands, fixture guidance, and CI entrypoint. | ✓ SATISFIED | Canonical gate plus doc/release mutation contracts cover all declared surfaces. |

All Phase 96 requirement IDs are declared by at least one plan; no orphaned requirements were found. No later milestone phase exists to defer either human-verification item.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| — | — | No Phase 96 `TBD`, `FIXME`, `XXX`, placeholder UI/API, hardcoded output data, or console-only implementation found. | ℹ️ None | No blocker debt marker or stub evidence. |

### Human Verification Required

### 1. Archive replacement invariant

**Test:** Concurrently replace a valid archive pathname after validator read begins, using a deterministic test seam or a controlled filesystem barrier.

**Expected:** The validator only hashes, parses, and materializes the original bounded binary; replacement contents never reach the callback.

**Why human:** Current source satisfies this through its immutable binary flow, but the existing named TOCTOU test does not trigger the replacement race.

### 2. Live adoption CI lane

**Test:** Push/dispatch CI and inspect `verify_adoption_paths` and `ci-gate`.

**Expected:** A non-PR PostgreSQL 15 lane completes `mix verify.adoption_paths`; its result is visible to and required by `ci-gate`.

**Why human:** Static workflow inspection and mutation contracts cannot establish a GitHub-hosted execution result.

### Gaps Summary

The prior blockers are closed in actual source: archive resource and immutable-byte protections are implemented, standalone Accrue validator failures are fixed/redacted, current-source fixture compilation is tracked, and the supplied canonical gate result is green. No observable truth failed and no artifact/link is missing or stubbed. The phase cannot receive an automated `passed` verdict yet because two behavior-dependent assertions lack direct runtime evidence; the escalation gate requires the two human checks above.

_Verified: 2026-08-10T23:25:44Z_
_Verifier: the agent (gsd-verifier)_
