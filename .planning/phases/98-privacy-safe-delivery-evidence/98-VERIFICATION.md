---
phase: 98-privacy-safe-delivery-evidence
verified: 2026-08-16T16:39:57Z
status: gaps_found
score: 10/11 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 7/11
  gaps_closed:
    - "Every persisted or emitted delivery fact is recursively free of raw sensitive values."
    - "Operators can inspect delivery traces using opaque references, classifications, and allowlisted facts only."
  gaps_remaining: []
  regressions:
    - "The default/released-package Accrue proof acceptance path still fails under mix ci."
gaps:
  - truth: "Proof output is closed and the complete Core/Mailglass adoption-path commands emit proof records."
    status: failed
    reason: "The default full CI gate exits non-zero. Its released/default-package artifact consumer proofs fail, including the packaged Accrue archive proof (which reports 'Accrue package proof: proof failed') and the clean consumer Accrue lifecycle proof (MatchError on an empty result)."
    artifacts:
      - path: "priv/adoption_proof/artifact_consumer_fixture.ex"
        issue: "The updated immutable compatibility branch is reachable and the compatibility fixture is wired, but released-package/default-package proof acceptance remains non-green."
      - path: "test/chimeway/release_gate_contract_test.exs"
        issue: "Default CI reproduces failures in clean-consumer and packaged-archive proof tests."
    missing:
      - "Make the released-package/default-release Accrue artifact proof pass, then rerun mix ci successfully."
---

# Phase 98: Privacy-Safe Delivery Evidence Verification Report

**Phase Goal:** Operators can explain delivery behavior without Chimeway retaining or emitting sensitive endpoint, credential, identity, or content data.
**Verified:** 2026-08-16T16:39:57Z
**Status:** gaps_found
**Re-verification:** Yes — after the latest compatibility remediation

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Nested map, list, and keyword-shaped diagnostics redact forbidden keys consistently regardless of casing before persistence or emission. | ✓ VERIFIED | `Privacy.redact/1` recursively projects non-temporal structs through `Map.from_struct/1`, filters keys at every map/list/keyword depth, and focused regressions cover hostile mixed-case struct fields. |
| 2 | Operators can inspect delivery trace, attempt result, telemetry projection, and proof artifact using opaque references, classifications, and allowlisted facts. | ✓ VERIFIED | `SafeEvidence.trace/1` rebuilds nested attempts/timeline data through fixed constructors; `traces.ex` projects all public results through safe constructors; the full suite ran these regressions without a privacy/trace failure. |
| 3 | Raw tokens, credentials, recipient data, trusted deep links, and provider bodies cannot expose through Chimeway-owned storage or diagnostics. | ✓ VERIFIED | The hostile struct and nested-trace tests assert all sentinel values are absent. `record_attempt/2`, telemetry, Trigger, and public trace boundaries route through the closed evidence vocabulary. |
| 4 | Attempt persistence retains only outcome, classification, opaque provider reference, and narrowly validated provider facts. | ✓ VERIFIED | `Deliveries.record_attempt/2` calls `SafeEvidence.attempt_attrs/1` before the attempt changeset; only the closed returned fields persist. |
| 5 | Trigger, planning, and Inbox use tenant/domain-bound opaque identity references. | ✓ VERIFIED | `SafeEvidence.recipient_reference/1` remains fail-closed and Trigger validates aliases before lifecycle writes; integration coverage ran in the default suite. |
| 6 | Telemetry and default logs use bounded metadata and avoid arbitrary adapter-term inspection. | ✓ VERIFIED | `SafeEvidence.telemetry_meta/1` redacts then applies its explicit metadata vocabulary; adapters pass projected attempt data to persistence/logging paths. |
| 7 | Trace and Admin DTOs are safe before optional Admin redaction while retaining explanation. | ✓ VERIFIED | Public query APIs use `SafeEvidence.trace_event/1`, `trace_notification/1`, `trace_delivery/1`, and `trace/1`; they no longer return lifecycle schemas. |
| 8 | Proof output is closed, non-atomizing, and the complete Core/Mailglass adoption path emits proof records. | ✗ FAILED | Compatibility source is fixed, but the required default/released-package proof acceptance is not green: `mix ci` exits 1 with released/artifact consumer proof failures. |
| 9 | Migration 034 purges historical generic payload/content/provider blobs without deriving facts from raw data. | ✓ VERIFIED | Existing migration and migration-contract coverage remained green in the full default suite. |
| 10 | Repository, template, public, and prefixed migration paths have equivalent cleanup semantics. | ✓ VERIFIED | Existing installer/migration contract coverage remained green in the full default suite. |
| 11 | Phase-focused checks provide automated evidence. | ✓ VERIFIED | `mix ci.verify_gates` passed (480 tests, 0 failures); remote reachability and static contract checks independently confirm the new compatibility SHA wiring. |

**Score:** 10/11 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `lib/chimeway/privacy.ex` | Recursive forbidden-key boundary | ✓ VERIFIED | 50 substantive lines; non-temporal structs are converted to maps before recursive filtering. |
| `lib/chimeway/safe_evidence.ex` | Closed durable and diagnostic evidence vocabulary | ✓ VERIFIED | `trace/1` calls closed nested helpers; `proof/1` delegates to `Privacy.redact/1`. |
| `lib/chimeway/traces.ex` | Safe public trace APIs | ✓ VERIFIED | `get_trace/2`, recipient lookup, correlation lookup, and explanation construction invoke named SafeEvidence projections. |
| `priv/adoption_proof/artifact_consumer_fixture.ex` | Runnable opaque-recipient proof construction | ⚠️ PARTIAL | Uses the corrected immutable compatibility SHA and opaque recipient refs, but the default released-package proof behavior fails. |
| `test/chimeway/release_gate_contract_test.exs` | Executable release/adoption proof contract | ✓ VERIFIED | Substantive and exercised by `mix ci`; its failures correctly expose the unsatisfied acceptance gate. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `lib/chimeway/traces.ex` | `lib/chimeway/safe_evidence.ex` | public query and explanation projections | ✓ WIRED | Calls at lines 76, 123, 160, 229, and 361 use trace constructors. |
| `lib/chimeway/safe_evidence.ex` | `lib/chimeway/privacy.ex` | proof and metadata redaction | ✓ WIRED | `Privacy.redact/1` is invoked at all shared untrusted-term boundaries. |
| `SafeEvidence.trace/1` | `trace_attempt/1` / `timeline_detail/1` | closed nested trace construction | ✓ WIRED | Manual source check confirms `trace_attempt_or_nil/1` and `trace_timeline/1` rebuild nested data; the generic key-link query cannot parse a function name as a file path. |
| artifact fixture | Accrue compatibility checkout | immutable SHA provenance | ✓ WIRED | Fixture, CI, docs, and contracts all use `0752b8d0b59eb53936498daa4bb0be4b14ffd0e4`; `git ls-remote https://github.com/szTheory/accrue.git` resolves it at `fix/chimeway-opaque-recipient`. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| `Privacy.redact/1` | nested maps/lists/struct fields | caller-provided evidence | Yes; forbidden fields are removed recursively | ✓ FLOWING |
| `SafeEvidence.trace/1` | `last_attempt`, `timeline` | trace caller map | Yes; source values are rebuilt to fixed literal maps | ✓ FLOWING |
| artifact consumer fixture | Accrue proof record | unpacked/default package consumer | Not reliably: released-package proof exits non-zero | ✗ FAILED |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Compatibility ref is remotely reachable | `git ls-remote https://github.com/szTheory/accrue.git 0752b8d0b59eb53936498daa4bb0be4b14ffd0e4 refs/heads/fix/chimeway-opaque-recipient` | SHA resolves to the named branch | ✓ PASS |
| Focused doc/release contracts | `mix ci.verify_gates` | 480 tests, 0 failures | ✓ PASS |
| Full default gate | `mix ci` | Exit 1; 1423 tests, 4 failures (31 excluded) | ✗ FAIL |

The full run’s four failures are all release/artifact consumer proof tests. The decisive product failures are the clean consumer Accrue lifecycle proof (`MatchError` on `[]`) and packaged Accrue archive proof (`Accrue package proof: proof failed`). Two additional artifact consumer failures are environment-sensitive dependency/work-directory failures, but they do not soften the non-zero acceptance gate.

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| PRIV-03 | 98-01 through 98-15 | Recursively redact case-normalized sensitive values before every observable surface. | ✓ SATISFIED | Current code closes the previous struct/nested-trace bypasses and the relevant regressions pass in the full suite. |
| PRIV-04 | 98-01 through 98-15 | Retain only opaque references, classifications, and allowlisted facts. | ✗ BLOCKED | The release/default-package proof acceptance required to demonstrate safe output is non-green under `mix ci`. |

No Phase 98 requirement is orphaned. No later milestone phase explicitly schedules a repair for the Accrue released-package/default-release proof; it is not deferred.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `priv/adoption_proof/artifact_consumer_fixture.ex` | proof execution path | Default-package acceptance fails | 🛑 BLOCKER | The phase’s required executable adoption/proof evidence is not reliable. |

No unreferenced `TBD`, `FIXME`, or `XXX` markers were found in the reviewed Phase 98 implementation and contract artifacts.

### Gaps Summary

The latest remediation really did close the two prior privacy boundary defects: arbitrary structs are recursively projected before redaction, and nested trace data is rebuilt from a closed vocabulary. The corrected Accrue SHA is also genuinely remotely reachable and consistently wired at commit `ab1a83f`.

Nevertheless, Phase 98 cannot be accepted. The default full gate remains red at the released/default-package proof boundary, which is a machine-testable must-have. The observed full run has four failures rather than the previously reported two; the test count is the claimed 1423, but the reported failure count is not reproducible. No human decision or UAT can resolve a failing executable acceptance gate.

---

_Verified: 2026-08-16T16:39:57Z_
_Verifier: the agent (gsd-verifier)_
