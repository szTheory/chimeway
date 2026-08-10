---
phase: 95-accrue-billing-escalation-proof
reviewed: 2026-08-10T00:47:49Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - scripts/prove-accrue-consumer.exs
  - test/support/artifact_consumer_fixture.ex
  - test/chimeway/release_gate_contract_test.exs
  - guides/introduction/accrue-dunning-integration.md
  - test/chimeway/doc_contract_test.exs
findings:
  critical: 4
  warning: 1
  info: 0
  total: 5
status: issues_found
---

# Phase 95: Code Review Report

**Reviewed:** 2026-08-10T00:47:49Z
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

The new Accrue proof is not credible release evidence. Its proof record is fabricated from literal maps rather than a created workflow, and the generated consumer cannot start the fake processor that its event fixture requires. The published guide also points adopters to a script deliberately omitted from the Hex package, while the runner accepts source checkouts as alleged artifacts.

## Critical Issues

### CR-01: The proof emits fabricated workflow lifecycle values

**Classification:** BLOCKER

**File:** `/Users/jon/projects/chimeway/test/support/artifact_consumer_fixture.ex:584`

**Issue:** After triggering the events, the generated script assigns literal `waiting` and `outcome` maps at lines 587 and 591, then serializes those constants at line 594. It never obtains a workflow-run ID, calls `Chimeway.Workflows.explain/2` or `list_traces/3`, or proves that either event created, waited, or signalled a Chimeway workflow. Consequently any run that reaches the print statement produces the required `waiting / waiting_for_step_progression` and `active / signal_received` record even if no corresponding workflow state exists.

**Fix:** Create the actual billing fixture, capture the run ID through the supported public API, and derive both records from `Chimeway.Workflows.explain/2` plus the ordered transitions from `list_traces/3`. Fail unless those public results exactly match the allowlisted states before emitting the record.

### CR-02: The generated proof never starts the required Accrue fake processor

**Classification:** BLOCKER

**File:** `/Users/jon/projects/chimeway/test/support/artifact_consumer_fixture.ex:577`

**Issue:** `Accrue.Test.setup_fake_processor/0` only configures the adapter; it does not start `Accrue.Processor.Fake`. The proof immediately calls `Accrue.Test.trigger_event/2` at line 584, whose webhook reducer calls the fake processor. Accrue documents that this GenServer is not started by its application, and this fixture never calls `Accrue.Processor.Fake.start_link/1`. The first event therefore fails with a missing-process exit (returned as `{:error, ...}`), making the `{:ok, result}` match fail before any proof can be produced.

**Fix:** Start the fake processor explicitly (tolerating `{:error, {:already_started, pid}}`), reset it, and register cleanup before calling `setup_fake_processor/0` and triggering events.

### CR-03: The advertised packaged-consumer command is not in the package

**Classification:** BLOCKER

**File:** `/Users/jon/projects/chimeway/guides/introduction/accrue-dunning-integration.md:120`

**Issue:** The guide tells an adopter of an unpacked package to run `scripts/prove-accrue-consumer.exs`. That script is not package content, and it immediately requires `../test/support/artifact_consumer_fixture.ex` ([`scripts/prove-accrue-consumer.exs`](/Users/jon/projects/chimeway/scripts/prove-accrue-consumer.exs:3)), which is also test-only and absent from the Hex artifact. The current package file allowlist contains neither `scripts` nor `test`, so the documented command cannot be run from the artifact it claims to validate.

**Fix:** Ship a self-contained proof executable/Mix task with the package, or explicitly make this a repository-maintainer-only tool and remove its use as packaged-consumer evidence. Add a test that executes the documented command from a freshly unpacked artifact.

### CR-04: Any source checkout can be presented as an unpacked artifact

**Classification:** BLOCKER

**File:** `/Users/jon/projects/chimeway/scripts/prove-accrue-consumer.exs:7`

**Issue:** Input validation accepts any absolute directory. The later provenance check only confirms that the generated host's `:chimeway` path equals that argument and is not the *current* repository root ([`artifact_consumer_fixture.ex`](/Users/jon/projects/chimeway/test/support/artifact_consumer_fixture.ex:265)). A sibling clone or arbitrary source checkout passes both checks and can yield `provenance=released_package`, contradicting the guide's promise that a source checkout is invalid and bypassing the phase's artifact-only trust boundary.

**Fix:** Accept a verifiable package artifact (for example, an archive plus its expected package metadata/checksum) and unpack it in the runner, or otherwise require and validate immutable release provenance. A directory path alone cannot substantiate the claimed package origin.

## Warnings

### WR-01: Contract tests never execute the Accrue proof runner

**Classification:** WARNING

**File:** `/Users/jon/projects/chimeway/test/chimeway/release_gate_contract_test.exs:1504`

**Issue:** The added tests validate a hand-written evidence string and source-text markers (lines 1504-1576), but never call `prove_accrue!/1` or the CLI against an unpacked package. They therefore pass despite the unstarted fake processor, literal lifecycle maps, unavailable packaged script, and source-tree provenance bypass.

**Fix:** Build/unpack the package in the release-gate test, invoke the public runner in a clean process, parse its sole output record, and assert its artifact/provenance and lifecycle behavior. Include negative cases for a source checkout and a missing packaged runner.

---

_Reviewed: 2026-08-10T00:47:49Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
