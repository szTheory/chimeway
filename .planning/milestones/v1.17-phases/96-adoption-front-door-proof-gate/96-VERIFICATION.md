---
phase: 96-adoption-front-door-proof-gate
verified: 2026-08-11T21:45:07Z
status: passed
score: 7/7 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: passed
  previous_score: 7/7
  gaps_closed:
    - "Phase 96 summary frontmatter now records ADPT-01, ADPT-02, GATE-02, and DOCS-01."
    - "Phase 96 planning artifacts now match the every-event adoption lane required by both pr-gate and ci-gate."
    - "Runtime-loaded fixture parser calls use dynamic dispatch and no longer emit compiler warnings."
  gaps_remaining: []
  regressions: []
behavior_unverified_items: []
human_verification: []
---

# Phase 96: Adoption Front Door & Proof Gate Verification Report

**Phase Goal:** Prospective adopters can choose the right canonical path, understand ownership boundaries, and rely on CI-backed commands and documentation that remain truthful over time.
**Verified:** 2026-08-11T21:45:07Z
**Status:** passed
**Re-verification:** Yes — after post-audit evidence, topology-contract, and runtime-dispatch reconciliation.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | An adopter can choose Core, Mailglass, or Accrue and see the host, Chimeway, and partner responsibilities. | ✓ VERIFIED | `guides/introduction/adoption-paths.md:7-62` has exactly the three ordered paths, each with separately named Host, Chimeway, and Partner responsibility. |
| 2 | Each chosen path provides a copyable proof command, expected sanitized explainability evidence, and an explicit statement of what the proof does not cover. | ✓ VERIFIED | Each selector section contains its literal focused command, one `CHIMEWAY_*_PROOF` representative record, and a `Does not cover` boundary; package/doc contracts cover command and record drift. |
| 3 | `mix verify.adoption_paths` executes the clean-room paths without rerunning detailed repository partner suites. | ✓ VERIFIED | The runner has a fixed `[:core, :mailglass, :accrue]` serial table and invokes only package fixture `prove_*!/2` functions. Its runtime-loaded parser functions use the same dynamic-dispatch boundary, eliminating compile-time warnings. The fresh aggregate command completed Core, Mailglass, and Accrue in order with exit 0. |
| 4 | CI runs that command in one dedicated PostgreSQL-backed adoption lane and surfaces enough per-path diagnostics. | ✓ VERIFIED | Every PR runs `Adoption proof paths`; `pr-gate` requires its result. Exact-SHA run `31449129603` passed both jobs on `c13bae7c92c537f3e758330703168119703a301b`. |
| 5 | Contracts prevent selector, command, fixture-guidance, and CI-entrypoint drift. | ✓ VERIFIED | `doc_contract_test.exs` and `release_gate_contract_test.exs` assert package membership, exact commands and records, selector/guide links, CI service/job/gate wiring, and destructive in-memory mutations. Phase 96 context, research, patterns, plan, and summary now describe the same every-event/two-gate topology those contracts enforce. |
| 6 | Archive input is fail-closed before fixture loading, bounded, and its accepted digest applies to the bytes extracted. | ✓ VERIFIED | A deterministic barrier fires after the archive descriptor opens; the regression test atomically replaces the pathname before validation resumes and proves the callback sees only the originally opened bytes. |
| 7 | The phase release-gate evidence is green. | ✓ VERIFIED | Fresh local `mix ci.verify_gates`: 618 tests, 0 failures, 1 intentionally excluded dedicated E2E. Fresh local `mix verify.adoption_paths`: all three paths passed with exit 0 and no runtime fixture compiler warnings. Hosted `Release gate contract`, `Test`, `Adoption proof paths`, and `pr-gate` all passed in run `31449129603`. |

**Score:** 7/7 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `guides/introduction/adoption-paths.md` | Canonical three-path selector | ✓ VERIFIED | Substantive 63-line selector, linked from README and first in ExDoc extras. |
| `lib/mix/tasks/verify.adoption_paths.ex` | Strict task facade | ✓ VERIFIED | `OptionParser` rejects invalid/duplicate/positional arguments before `Code.require_file`; valid input dispatches the runner. |
| `scripts/prove-adoption-paths.exs` | Build-once serial dispatcher | ✓ VERIFIED | Builds once, validates once, iterates the fixed path list, dynamically dispatches runtime-loaded proof/parser functions, validates fixture-owned output, and produces fixed redacted framing. |
| `priv/adoption_proof/artifact_archive.ex` | Safe archive boundary | ✓ VERIFIED | 606 lines of bounded immutable read, atom-free metadata parsing, digest validation, streaming inflate, tar scan, contained materialization, and cleanup—not a stub. |
| `scripts/prove-accrue-consumer.exs` | Redacted standalone Accrue surface | ✓ VERIFIED | Handles `{:error, _reason}` with the fixed provenance diagnostic/65 status and does not interpolate the reason. |
| `.github/workflows/ci.yml` | Dedicated PostgreSQL lane | ✓ VERIFIED | Job, service, task, PR execution, `pr-gate` dependency, environment result, and aggregate argument are contract tested and passed live on run `31449129603`. |
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
| CI lane | task and PR gate | job command, `needs`, result env, aggregate argument | ✓ VERIFIED | Static mutation contracts and exact-SHA live assertion both pass; `pr-gate` cannot pass without the adoption lane. |
| Accrue CLI | archive validator | `{:error, _reason}` → fixed diagnostic/65 | ✓ WIRED | The generic source-to-command probe is not a meaningful direct import link; the CLI result algebra is present and covered by the release-gate test. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Adoption runner | `proof.output` | `ArtifactConsumerFixture.prove_*!/2` from the validated package root | Parsed by the fixture's strict per-path parser, then emitted unchanged | ✓ FLOWING |
| Archive validator | `archive_binary` / unpacked root | one bounded `File.open`/`IO.binread`, then in-memory outer extraction and bounded inner extraction | Metadata, required members, and materialized root derive from the same archive binary; deterministic pathname replacement and atom-safe hostile metadata cases pass | ✓ FLOWING |
| Selector | commands/evidence/limits | literal contract-checked guide content | README/ExDoc package surface exposes the document | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Concurrent pathname replacement | focused location test in `release_gate_contract_test.exs` | Deterministic open/replace/resume test completed with 1 test, 0 failures. | ✓ PASS |
| Complete packaged adoption proof | `mix verify.adoption_paths` | Fresh current-tree run: Core, Mailglass, and Accrue passed in fixed order with exit 0 and no runtime fixture compiler warnings; hosted adoption job also succeeded. | ✓ PASS |
| Canonical documentation/release gate | `mix ci.verify_gates` | Fresh current-tree result: 618 tests, 0 failures, 1 dedicated E2E excluded. Hosted release-gate job succeeded. | ✓ PASS |
| Exact-SHA PR evidence | `scripts/ci/assert-adoption-run.sh c13bae7c92c537f3e758330703168119703a301b` | Accepted run `31449129603` with successful adoption and `pr-gate` jobs. | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| ADPT-01 | 96-02, 96-03 | Choose the appropriate path and understand responsibility boundaries. | ✓ SATISFIED | Complete, separate responsibility fields for all three canonical paths; 96-02 SUMMARY frontmatter records completion. |
| ADPT-02 | 96-02, 96-03 | Document command, outcome, and coverage boundary per path. | ✓ SATISFIED | Literal commands, sanitized records, explicit exclusions, and guide links are contract protected; 96-02 SUMMARY frontmatter records completion. |
| GATE-01 | 96-01, 96-03, 96-04, 96-05 | Run clean-room proofs without detailed partner suites. | ✓ SATISFIED | Real aggregate contract proves fixed fixture-only serial dispatch; archive and CLI boundaries are fail-closed. |
| GATE-02 | 96-02, 96-03 | CI runs the proof entrypoint in a PostgreSQL lane with useful diagnostics. | ✓ SATISFIED | Exact-SHA PR run `31449129603` passed the PostgreSQL adoption lane and its required `pr-gate` consumer; 96-02 SUMMARY frontmatter and all Phase 96 planning contracts now match the implemented two-gate topology. |
| DOCS-01 | 96-01, 96-02, 96-03, 96-04, 96-05 | Contract-check front door, commands, fixture guidance, and CI entrypoint. | ✓ SATISFIED | Canonical gate plus doc/release mutation contracts cover all declared surfaces. |

All Phase 96 requirement IDs are declared by at least one plan; no orphaned requirements or deferred verification items remain.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| — | — | No Phase 96 `TBD`, `FIXME`, `XXX`, placeholder UI/API, hardcoded output data, or console-only implementation found. | ℹ️ None | No blocker debt marker or stub evidence. |

### Human Verification Required

None. Both former items now have deterministic, machine-readable evidence.

### Gaps Summary

All post-audit gaps are closed in canonical evidence. Summary requirements converge, the planning contract matches the every-event lane required by both aggregate gates, runtime-loaded parser dispatch is warning-free, the archive replacement invariant is exercised deterministically, and exact-SHA evidence remains fail-closed. No human UAT remains.

_Verified: 2026-08-11T21:45:07Z_
_Verifier: the agent (gsd-verifier)_
