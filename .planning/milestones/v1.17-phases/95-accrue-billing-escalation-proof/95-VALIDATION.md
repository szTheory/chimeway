---
phase: 95
slug: accrue-billing-escalation-proof
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-08-09
validated: 2026-08-11
updated: 2026-08-11
---

# Phase 95 — Validation Strategy

> Retroactively reconciled Nyquist validation contract for the completed Accrue billing-escalation proof.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs test/chimeway/doc_contract_test.exs --warnings-as-errors` |
| **Full suite command** | `mix ci.verify_gates` |
| **Focused artifact command** | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --only accrue_artifact_proof --warnings-as-errors` |
| **Focused packaged CLI command** | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --only accrue_packaged_cli --warnings-as-errors` |
| **Current audit evidence** | Quick suite: 619 tests, 0 failures on 2026-08-11 |

---

## Sampling Rate

- **After every task commit:** Run the task's focused command from the map below.
- **After every plan wave:** Run the quick command above.
- **Before phase or milestone acceptance:** Run `mix ci.verify_gates`; retain machine-readable CI evidence where the acceptance contract requires it.
- **Max feedback latency:** Focused commands provide the bounded feedback loop; full packaged-consumer coverage is intentionally slower.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 95-01-01 | 01 | 1 | ACCR-01, ACCR-02 | T-95-01, T-95-03, T-95-04, T-95-05, T-95-06 | The committed runner executes the event-to-signal path from an unpacked artifact and emits one allowlisted lifecycle/provenance record after cleanup. | integration + command contract | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors` | ✅ | ✅ green |
| 95-01-02 | 01 | 1 | ACCR-01, ACCR-02 | T-95-01, T-95-02, T-95-03, T-95-04, T-95-05, T-95-06 | Parser and failure contracts reject forged, sensitive, atomizing, mixed-provenance, source-tree, and cleanup-invalid evidence. | adversarial contract | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors` | ✅ | ✅ green |
| 95-02-01 | 02 | 2 | ACCR-01, ACCR-02 | T-95-07, T-95-08, T-95-09, T-95-11, T-95-12 | Guide contracts require the exact command, natural event ordering, sanitized public evidence, and non-terminal signal meaning. | documentation contract | `MIX_ENV=test mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` | ✅ | ✅ green |
| 95-02-02 | 02 | 2 | ACCR-01, ACCR-02 | T-95-07, T-95-08, T-95-09, T-95-10, T-95-11, T-95-12 | Release wording requires resolved-package checks and keeps the pinned SHA compatibility-only and outside installation guidance. | release + documentation contract | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs test/chimeway/doc_contract_test.exs --warnings-as-errors` | ✅ | ✅ green |
| 95-03-01 | 03 | 3 | ACCR-01, ACCR-02 | T-95-13, T-95-14, T-95-15 | A real generated consumer runs payment failure through public waiting evidence and payment outcome through public signal-received evidence. | artifact E2E | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --only accrue_artifact_proof --warnings-as-errors` | ✅ | ✅ green |
| 95-03-02 | 03 | 3 | ACCR-01, ACCR-02 | T-95-16, T-95-17 | Release and exact-SHA compatibility provenance are mutually exclusive, resolved from the consumer, and fail closed. | provenance integration | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --only accrue_artifact_proof --warnings-as-errors` | ✅ | ✅ green |
| 95-04-01 | 04 | 4 | ACCR-01, ACCR-02 | T-95-18, T-95-19, T-95-20 | The package-owned archive command validates immutable bytes, loads packaged support, executes the proof, and emits one record. | packaged CLI E2E | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --only accrue_packaged_cli --warnings-as-errors` | ✅ | ✅ green |
| 95-04-02 | 04 | 4 | ACCR-01, ACCR-02 | T-95-21, T-95-22, T-95-23 | Invalid archive/provenance, proof failure, and cleanup paths exit nonzero without authoritative proof output. | adversarial CLI contract | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors` | ✅ | ✅ green |
| 95-05-01 | 05 | 5 | ACCR-01, ACCR-02 | T-95-24, T-95-25 | Canonical guidance uses the shipped archive-plus-SHA command and describes the public non-terminal lifecycle accurately. | documentation contract | `MIX_ENV=test mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` | ✅ | ✅ green |
| 95-05-02 | 05 | 5 | ACCR-01, ACCR-02 | T-95-26, T-95-27, T-95-28 | Documentation and release contracts prevent overclaiming released-package or immutable-SHA compatibility evidence. | release + documentation contract | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs test/chimeway/doc_contract_test.exs --warnings-as-errors` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Requirement Coverage

| Requirement | Automated evidence | Classification |
|-------------|--------------------|----------------|
| ACCR-01 | Artifact and packaged CLI E2E, public workflow evidence, adversarial parser/cleanup contracts, and documentation contracts | COVERED |
| ACCR-02 | Resolved release/SHA provenance integration, negative provenance contracts, and documentation overclaim contracts | COVERED |

No missing or partial requirement coverage was found. Both requirements are exercised by implementation-facing tests and documentation/release contracts, and the current quick suite is green.

---

## Execution-Wave Test Requirements

- [x] Wave 1 added the committed runner, deterministic Accrue proof, strict parser, and release-gate contracts.
- [x] Wave 2 added exact-command, lifecycle-language, and released-package-versus-pinned-ref documentation contracts.
- [x] Wave 3 executed real release and immutable-SHA consumers through the artifact fixture.
- [x] Wave 4 moved the adopter proof behind the package-owned immutable archive CLI and covered failure/cleanup behavior.
- [x] Wave 5 bound the canonical guide to the shipped command and exact provenance schemas.

---

## Manual-Only Verifications

None. All Phase 95 behaviors and acceptance criteria are objectively machine-testable and have automated evidence.

---

## Validation Audit 2026-08-11

| Metric | Count |
|--------|-------|
| Planned tasks audited | 10 |
| Requirements audited | 2 |
| Gaps found | 0 |
| Resolved by new tests | 0 |
| Escalated | 0 |

The pre-existing draft map covered only Plans 95-01 and 95-02. This audit reconciled the completed Plans 95-03 through 95-05 and confirmed their artifact, packaged CLI, provenance, failure-path, and documentation tests are present and green. No Nyquist auditor spawn or generated test file was required because discovery found no missing or partial coverage.

Known unrelated `Threadline.Export.CleanupTask` sandbox-ownership logs appeared during the current quick suite; ExUnit completed successfully with 619 tests and 0 failures.

---

## Validation Sign-Off

- [x] All 10 tasks have an exact automated verification command.
- [x] ACCR-01 and ACCR-02 have implementation-facing and contract-facing automated coverage.
- [x] Sampling continuity has no three consecutive tasks without automated verification.
- [x] All five execution waves have green evidence.
- [x] No watch-mode flags are used.
- [x] No manual-only acceptance remains.
- [x] `status: validated` and `nyquist_compliant: true` are set in frontmatter.

**Approval:** automated evidence complete
