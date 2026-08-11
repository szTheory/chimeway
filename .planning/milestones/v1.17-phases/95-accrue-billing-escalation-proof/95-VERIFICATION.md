---
phase: 95-accrue-billing-escalation-proof
verified: 2026-08-10T02:24:37Z
status: passed
score: 9/9 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 4/9
  gaps_closed:
    - "A clean consumer can prove Accrue's invoice.payment_failed -> waiting -> invoice.paid -> signal_received workflow path."
    - "The proof is an independently runnable packaged adopter proof with truthful immutable archive provenance."
    - "Released-package and immutable-SHA compatibility classifications are derived fail-closed from the generated consumer's resolved Accrue dependency."
    - "The runner's evidence, lifecycle, provenance, cleanup, and package boundary are exercised by release-gate contracts."
  gaps_remaining: []
  regressions: []
---

# Phase 95: Accrue Billing-Escalation Proof Verification Report

**Phase Goal:** Prospective adopters can evaluate Accrue-driven billing escalation through its natural event and outcome-signal boundaries, with provenance that does not overstate release support.
**Verified:** 2026-08-10T02:24:37Z
**Status:** passed
**Re-verification:** Yes — after gap closure

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | A clean consumer begins dunning through `invoice.payment_failed`, reaches waiting, and exits the wait through `invoice.paid`, without host-side notifier or signal calls. | ✓ VERIFIED | The generated proof starts/resets `Accrue.Processor.Fake`, calls only `Accrue.Test.trigger_event/2` at `priv/adoption_proof/artifact_consumer_fixture.ex:648` and `:666`, then drains `:chimeway_signals`; the packaged CLI contract executes this path successfully. |
| 2 | The proof exposes sanitized public workflow evidence for progression and the non-terminal outcome. | ✓ VERIFIED | The proof reads `Chimeway.Workflows.explain/2` and `list_traces/2` before and after the signal (`:655-:676`), asserts `waiting / waiting_for_step_progression` then `active / signal_received`, and the strict parser allows only the fixed safe schema. |
| 3 | The built package owns the documented runner and all loaded proof support. | ✓ VERIFIED | `mix.exs:231-233` packages `priv` and the exact runner; the runner loads `priv/adoption_proof/artifact_consumer_fixture.ex` package-relatively (`scripts/prove-accrue-consumer.exs:7-19`). The executed archive contract verifies both package members and rejects `test/support` reliance. |
| 4 | The public command proves a freshly validated archive, not an arbitrary directory or source checkout. | ✓ VERIFIED | The CLI requires an absolute regular archive plus lowercase SHA-256 (`:32-51`), compares its digest, validates Hex metadata/manifest, rejects unsafe paths, and contains extraction under runner-owned scratch storage (`:54-170`). Negative executable cases reject directories, relative paths, altered archives, and bad checksums without a proof record. |
| 5 | Exact Accrue `1.3.0` can be labeled released-package evidence only after resolved dependency, metadata, source, and module-origin validation. | ✓ VERIFIED | Generated-consumer code checks `Mix.Dep`, lock tuple, `Hex.SCM`, application/Hex metadata version, integration membership, resolved path, and loaded module source (`fixture:677-719`). The emitted schema contains exact Accrue and Chimeway versions only in this branch. |
| 6 | The immutable pinned SHA is compatibility evidence only and is mutually exclusive with release guidance. | ✓ VERIFIED | The sole compatibility branch matches exact SHA `236fa2f1649e771f3b515603495436badeed3c7b` and emits only `accrue_ref` (`fixture:721-726`). The executed compatibility contract asserts that release-version fields are absent. |
| 7 | Failures in lifecycle, provenance, evidence parsing, or cleanup cannot print an authoritative proof line. | ✓ VERIFIED | The CLI prints only after `prove_accrue!/2` succeeds and removes extracted contents in `after` (`runner:13-29`). Contracts cover invalid provenance and malformed/sensitive/duplicate proof fields; invalid CLI cases assert nonzero status and no `CHIMEWAY_ACCRUE_PROOF`. |
| 8 | Canonical guidance copies the packaged command and accurately describes public, non-terminal lifecycle evidence. | ✓ VERIFIED | `guides/introduction/accrue-dunning-integration.md` documents archive-plus-SHA invocation, natural event boundaries, and that `active / signal_received` ends the waiting path rather than completing the workflow; named doc contracts enforce the wording and safe vocabulary. |
| 9 | Release and CI gates execute and retain the proof/documentation boundary. | ✓ VERIFIED | `mix ci.verify_gates` completed successfully, running the documentation and release-gate contract files. CI wires that task through `verify_gates` and separately retains the ecosystem `verify_accrue` lane. |

**Score:** 9/9 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `scripts/prove-accrue-consumer.exs` | Package-owned archive-and-digest CLI | ✓ VERIFIED | Substantive argument/provenance validation, fixture loading, error-only diagnostics, and extraction cleanup; invoked by the archived-package test. |
| `priv/adoption_proof/artifact_consumer_fixture.ex` | Real lifecycle, safe evidence, provenance, and cleanup implementation | ✓ VERIFIED | Generates and executes the isolated consumer, obtains public workflow evidence, validates exact provenance, and cleans temporary host/database state. |
| `test/support/artifact_consumer_fixture.ex` | Non-divergent test bootstrap | ✓ VERIFIED | One-line package-relative loader for the shipped fixture; it contains no competing implementation. |
| `mix.exs` | Package inclusion and gate entrypoint | ✓ VERIFIED | Package allowlist includes `priv` and exact runner; `ci.verify_gates` runs the relevant contract files. |
| `test/chimeway/release_gate_contract_test.exs` | Executed archive proof and adversarial boundary contracts | ✓ VERIFIED | Builds Hex archive, unpacks it, runs its package-contained command, parses one record, and exercises invalid archive/provenance cases. |
| `guides/introduction/accrue-dunning-integration.md` | Canonical command and truthful lifecycle/provenance guidance | ✓ VERIFIED | Matches archive CLI spelling and distinguishes release evidence from SHA-only compatibility. |
| `test/chimeway/doc_contract_test.exs` | Documentation overclaim prevention | ✓ VERIFIED | Contracts at `:825-:958` bind command, archive, lifecycle, safe evidence, version, and SHA language. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `mix.exs` | Runner | Hex package allowlist | ✓ WIRED | Exact `scripts/prove-accrue-consumer.exs` entry is in package files. |
| Runner | Package fixture | `Code.require_file` then `prove_accrue!/2` | ✓ WIRED | `scripts/prove-accrue-consumer.exs:16-19` loads the extracted package copy and invokes it. |
| Generated Accrue events | Public Workflows evidence | events → waiting/signals → `explain/2` / `list_traces/2` | ✓ WIRED | The generated script uses real event calls, queue drain, and public API projection; executed by the package contract. |
| Resolved dependency | Provenance record | exact release or exact SHA branch | ✓ WIRED | Descriptor inputs are resolved in the generated consumer and serialization occurs only after all branch checks pass. |
| Release-gate contracts | Package CLI | build → unpack → run → strict parse | ✓ WIRED | `release_gate_contract_test.exs:1703-1767` executes both positive and negative archive cases. |
| Documentation contracts | Canonical guide | required and forbidden statements | ✓ WIRED | The guide fixture is loaded and asserted by the named contract tests. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Generated Accrue proof | `waiting`, `outcome`, trace reasons | `Chimeway.Workflows.explain/2` and `list_traces/2` after real Accrue events | Yes — state/reason values are asserted from public APIs | ✓ FLOWING |
| Generated provenance | descriptor and proof fields | resolved Mix dependency, lock, Hex metadata, source containment, module origin | Yes — classification is fail-closed and mutually exclusive | ✓ FLOWING |
| Packaged CLI | artifact root | digest-validated archive extraction and manifest validation | Yes — command runs only extracted package-owned contents | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Package-owned archive CLI runs the real release proof and rejects invalid provenance | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --only accrue_packaged_cli --warnings-as-errors` | Exit 0; focused package-positive and adversarial-invalid CLI contract completed. Known Threadline sandbox-cleanup ownership logs were emitted but did not fail the command. | ✓ PASS |
| Documentation/release-gate contract path is runnable | `mix ci.verify_gates` | Exit 0; PostgreSQL test container became healthy and the documentation/release-gate suite completed. | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| ACCR-01 | 95-01 through 95-05 | Billing-event escalation, public workflow progression, outcome-signal termination, and trace evidence | ✓ SATISFIED | Real package-contained consumer executes `invoice.payment_failed` → public waiting evidence → `invoice.paid` → drained signal queue → public `signal_received` evidence. |
| ACCR-02 | 95-01 through 95-05 | Truthful released-package adopter proof versus pinned-ref compatibility evidence | ✓ SATISFIED | Archive immutability, exact 1.3.0/module validation, exact SHA-only branch, guide restrictions, and executable negative cases prevent overclaiming. |

All requirements declared by the five Phase 95 plans are present in `.planning/REQUIREMENTS.md`; no orphaned Phase 95 requirement was found.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| — | — | No unreferenced `TBD`, `FIXME`, `XXX`, placeholder, empty proof implementation, or hard-coded public lifecycle evidence found in Phase 95 artifacts. | ℹ️ Info | No blocker. The fixture's private setup uses database records by design; its emitted record is schema-restricted and trace-derived. |

The focused contract emitted known `Threadline.Export.CleanupTask` sandbox ownership logs. The command exited successfully; these logs are unrelated to the Accrue proof and are not a Phase 95 failure.

### Gaps Summary

None. The four previously failed areas are now implemented, wired through a package-owned immutable archive command, and exercised by focused executable contracts plus the release-gate command.

---

_Verified: 2026-08-10T02:24:37Z_
_Verifier: the agent (gsd-verifier)_
