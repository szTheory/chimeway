---
phase: 95-accrue-billing-escalation-proof
verified: 2026-08-10T00:50:11Z
status: gaps_found
score: 4/9 must-haves verified
behavior_unverified: 0
overrides_applied: 0
gaps:
  - truth: "A clean consumer can prove Accrue's invoice.payment_failed -> waiting -> invoice.paid -> signal_received workflow path."
    status: failed
    reason: "The generated proof fabricates both lifecycle states from literal maps and never calls public workflow APIs; its fake processor is also never started."
    artifacts:
      - path: "test/support/artifact_consumer_fixture.ex"
        issue: "accrue_proof_ex/0 assigns waiting/outcome literals at generated lines 587 and 591; no Chimeway.Workflows.explain/2 or list_traces/2 call exists."
    missing:
      - "Create the billing fixture and derive both asserted states and ordered reasons from public workflow APIs."
      - "Start/reset Accrue.Processor.Fake before invoking Accrue.Test.trigger_event/2."
  - truth: "The proof is an independently runnable unpacked-package adopter proof with truthful released-package provenance."
    status: failed
    reason: "The documented runner and fixture are excluded from the Hex package, and an arbitrary absolute source checkout passes the directory-only artifact-root validation."
    artifacts:
      - path: "mix.exs"
        issue: "package files whitelist excludes scripts and test."
      - path: "scripts/prove-accrue-consumer.exs"
        issue: "requires ../test/support/artifact_consumer_fixture.ex and accepts any absolute directory."
    missing:
      - "Ship a self-contained packaged proof entrypoint or stop presenting this repository-only script as adopter evidence."
      - "Validate immutable package/release provenance rather than merely accepting a directory path."
  - truth: "Released-package and immutable-SHA compatibility classifications are derived fail-closed from the generated consumer's resolved Accrue dependency."
    status: failed
    reason: "The generated proof unconditionally prints released_package/1.3.0; it has no compatibility resolution branch and does not validate a resolved dependency ref."
    artifacts:
      - path: "test/support/artifact_consumer_fixture.ex"
        issue: "accrue_proof_ex/0 has a fixed released_package output and no exact-SHA dependency/source classification."
    missing:
      - "Implement and exercise exact release-version/module validation and an exact-SHA-only compatibility branch before output."
  - truth: "The runner's evidence, lifecycle, provenance, cleanup, and package boundary are exercised by release-gate contracts."
    status: failed
    reason: "The added contracts parse hand-written strings and inspect source text; they never invoke prove_accrue!/1 or the documented CLI against an unpacked package."
    artifacts:
      - path: "test/chimeway/release_gate_contract_test.exs"
        issue: "Accrue tests at 1504-1611 use accrue_evidence_line/0 and File.read!/1 only."
    missing:
      - "Build/unpack the package and execute the public proof process, including invalid source-root and failure/cleanup cases."
---

# Phase 95: Accrue Billing-Escalation Proof Verification Report

**Phase Goal:** Prospective adopters can evaluate Accrue-driven billing escalation through its natural event and outcome-signal boundaries, with provenance that does not overstate release support.
**Verified:** 2026-08-10T00:50:11Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | A clean consumer runs the natural Accrue failure-to-outcome workflow without direct notifier use. | ✗ FAILED | Generated proof calls events but then assigns literal `waiting`/`outcome` maps; it neither creates a credible billing fixture nor queries a Chimeway workflow. |
| 2 | The proof shows sanitized public trace evidence of progression and outcome. | ✗ FAILED | No `Chimeway.Workflows.explain/2` or `list_traces/2` call occurs in the generated proof; the emitted record is not public evidence. |
| 3 | Released-package proof labels actual resolved release versions truthfully. | ✗ FAILED | Script/test fixture are absent from package; arbitrary absolute source directories are accepted and output is hard-coded `released_package`. |
| 4 | Immutable-SHA fallback is compatibility-only, never release guidance. | ✗ FAILED | Parser and prose model this distinction, but executable proof has no resolved-SHA compatibility branch. |
| 5 | Isolation, artifact-only dependency, provenance validation, serialized execution, and cleanup protect the proof. | ✗ FAILED | Temporary DB/filesystem cleanup and generated path dependency exist, but directory-only validation cannot distinguish a source checkout from a package artifact. |
| 6 | Guide narrates Accrue event boundaries without teaching direct notifier/signal invocation. | ✓ VERIFIED | Guide §5 and Clean-consumer proof use `invoice.payment_failed` then `invoice.paid` and explicitly prohibit host direct calls. |
| 7 | Guide limits evidence to waiting/signal_received and says it is non-terminal. | ✓ VERIFIED | Clean-consumer proof example and following paragraph state `active / signal_received` ends the wait, not the workflow. |
| 8 | Guide conditionally describes exact 1.3.0 release support and SHA compatibility only. | ✓ VERIFIED | Guide §§1 and Provenance labels contain the required conditional wording and no SHA install snippet. |
| 9 | Maintainer mechanics are not represented as packaged-consumer proof. | ✓ VERIFIED | Guide §6 labels `ACCRUE_PATH`, sibling checkout, CI checkout, and `mix verify.accrue` as repository-maintainer regression analogs. |

**Score:** 4/9 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `scripts/prove-accrue-consumer.exs` | Adopter-facing unpacked-artifact command | ⚠️ HOLLOW | Exists and invokes fixture in a repository checkout, but package excludes both it and its test-support dependency; accepts arbitrary absolute directories. |
| `test/support/artifact_consumer_fixture.ex` | Real Accrue topology, lifecycle proof, provenance parser | ✗ STUB | Parser/cleanup are substantive, but the claimed lifecycle proof is fabricated from literal maps and lacks compatibility classification. |
| `test/chimeway/release_gate_contract_test.exs` | Executed artifact proof and boundary contracts | ⚠️ PARTIAL | Parser/source-marker tests are substantive but do not run fixture or CLI against an unpacked artifact. |
| `guides/introduction/accrue-dunning-integration.md` | Canonical lifecycle and provenance guidance | ✓ VERIFIED | Textual lifecycle, safe record, and compatibility wording are substantive; its command link is broken at package boundary. |
| `test/chimeway/doc_contract_test.exs` | Documentation overclaim prevention | ✓ VERIFIED | Contract at line 825 passed, though it only validates wording. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| Runner | Artifact fixture | `prove_accrue!/1` | ⚠️ PARTIAL | Import/call exists, but cannot be wired in the unpacked package because `scripts/` and `test/` are absent. |
| Release-gate tests | Fixture | `prove_accrue!/2` and parser | ⚠️ PARTIAL | Parser is called; `prove_accrue!` is never called. |
| Generated Accrue events | Public Workflows evidence | event -> explain/list_traces -> proof | ✗ NOT_WIRED | Event calls exist but no public API calls exist; literal maps replace the required data flow. |
| Generated dependency resolution | Proof provenance | exact release/module or exact SHA | ✗ NOT_WIRED | Fixed release string; no resolved-ref compatibility validation. |
| Guide | Packaged runner/proof contract | documented command | ✗ NOT_WIRED | Command cannot exist in the package it asks the adopter to unpack. |
| Doc contracts | Guide | required/forbidden text | ✓ WIRED | Named documentation contract passes. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Generated `priv/prove_accrue.exs` | `waiting`, `outcome` | Literal maps | No | ✗ DISCONNECTED |
| Generated proof provenance | fixed proof string | Literal `released_package` / `1.3.0` | No resolved dependency classification | ✗ STATIC |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Strict released-package parser accepts/rejects its hand-written lifecycle record | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs:1504 --warnings-as-errors` | 1 test, 0 failures | ✓ PASS — parser only |
| Guide contains its documented command contract | `MIX_ENV=test mix test test/chimeway/doc_contract_test.exs:825 --warnings-as-errors` | 1 test, 0 failures | ✓ PASS — wording only |
| Actual clean consumer lifecycle / CLI | No test invokes it; static trace shows literal states and no public APIs | Not executable proof | ✗ FAIL |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| ACCR-01 | 95-01, 95-02 | Billing-event escalation, workflow progression, outcome-signal termination, and trace evidence | ✗ BLOCKED | Literal maps stand in for workflow evidence; no end-to-end clean-consumer execution exists. |
| ACCR-02 | 95-01, 95-02 | Accurate released-package adopter proof versus pinned-ref compatibility evidence | ✗ BLOCKED | Documentation says the right thing but promotes an unpacked-package command unavailable in the package; runtime does not classify compatibility. |

All requirement IDs declared by both plans are present in `.planning/REQUIREMENTS.md`; no phase-95 orphaned requirement was found.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `test/support/artifact_consumer_fixture.ex` | 587, 591 | Hard-coded lifecycle maps used for proof output | 🛑 Blocker | Allows claimed state evidence without a workflow. |
| `scripts/prove-accrue-consumer.exs` | 3 | Runtime dependency on package-excluded `test/support` fixture | 🛑 Blocker | Documented adopter command cannot run from the target package. |
| `test/chimeway/release_gate_contract_test.exs` | 1504-1611 | Hand-written evidence/source-text checks instead of proof execution | ⚠️ Warning | Passing tests cannot detect the broken real path. |

No unreferenced `TBD`, `FIXME`, or `XXX` marker was found in the changed phase files.

### Review Cross-Check

The independent scan confirms every material finding in `95-REVIEW.md`: fabricated lifecycle values (CR-01), no fake processor startup (CR-02), package-excluded command/fixture (CR-03), source-directory provenance bypass (CR-04), and non-executing contracts (WR-01). The named tests passing above do not refute those findings because each only exercises text/parser assertions.

### Gaps Summary

The phase goal is not achieved. The code has a strict proof-string parser and accurate-looking guide, but the claimed clean-consumer proof is neither a real workflow trace nor a runnable artifact command. Phase 96 adds selector/CI infrastructure, not the missing Phase 95 workflow implementation or package-valid executable, so these gaps are not deferred.

---

_Verified: 2026-08-10T00:50:11Z_
_Verifier: the agent (gsd-verifier)_
