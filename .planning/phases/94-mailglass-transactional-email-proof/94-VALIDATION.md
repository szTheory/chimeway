---
phase: 94
slug: mailglass-transactional-email-proof
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-08-08
audited: 2026-08-10
---

# Phase 94 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit / Mix |
| **Config file** | `mix.exs` |
| **Quick run command** | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs test/chimeway/doc_contract_test.exs --warnings-as-errors` |
| **Full suite command** | `mix ci.verify_gates` |
| **Observed focused runtime** | 613.4 seconds on 2026-08-10 |
| **Observed full-suite runtime** | 445.1 seconds on 2026-08-10 |

## Sampling Rate

- **After every task commit:** Run the task's focused release-gate or documentation-contract command from the map below.
- **After every plan wave:** Run `mix ci.verify_gates`
- **Before phase verification:** `mix ci.verify_gates` must be green.
- **Task-feedback latency:** The clean-consumer release-gate file is serialized and may take several minutes because it builds temporary artifacts, consumers, and databases. The aggregate gate remains wave/phase scoped.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 94-01-01 | 01 | 1 | MAIL-01, MAIL-02 | T-94-01, T-94-03, T-94-04, T-94-05 | The unpacked-artifact tracer proves the exact host-owned Mailglass path, sanitized public trace, provenance, Fake ownership, and cleanup. | integration / release-gate contract | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors` | ✅ | ✅ green |
| 94-01-02 | 01 | 1 | MAIL-01, MAIL-02 | T-94-02, T-94-04 | The strict parser rejects unknown, duplicate, missing, malformed, repeated-prefix, and unsafe evidence without atom creation or leaked resources. | integration / release-gate contract | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors` | ✅ | ✅ green |
| 94-02-01 | 02 | 2 | MAIL-02 | T-94-06, T-94-07, T-94-08 | Documentation contracts require one-repo ownership, the exact Fake/adapter-attempt distinction, all live-provider exclusions, and the blueprint link. | documentation contract | `MIX_ENV=test mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` | ✅ | ✅ green |
| 94-02-02 | 02 | 2 | MAIL-02 | T-94-06, T-94-09 | Negative documentation contracts reject live-delivery overclaims and Hex-consumer presentation of the maintainer-only suite; release/doc gates remain in parity. | documentation contract | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs test/chimeway/doc_contract_test.exs --warnings-as-errors` | ✅ | ✅ green |
| 94-03-01 | 03 | 3 | MAIL-01, MAIL-02 | — | The generated host executes both libraries through one `ArtifactConsumer.Repo`, normal migrations, and the existing sanitized proof boundary. | integration / release-gate contract | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors` | ✅ | ✅ green |
| 94-03-02 | 03 | 3 | MAIL-02 | — | Documentation is coupled to the executable single-repo topology while retaining the exact Fake and public-trace boundaries. | integration / documentation contract | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs test/chimeway/doc_contract_test.exs --warnings-as-errors` | ✅ | ✅ green |
| 94-04-01 | 04 | 4 | MAIL-02 | — | Canonical trace-derived evidence crosses the exact value-validating schema while one forged value fails closed. | integration / release-gate contract | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors` | ✅ | ✅ green |
| 94-04-02 | 04 | 4 | MAIL-02 | — | Adversarial mutations cover every allowlisted value, UUID/numeric aliases, sensitive values, and timeline ordering without atom creation. | unit / integration / release gate | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors && mix ci.verify_gates` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

## Wave 0 Requirements

Existing ExUnit release-gate and documentation-contract infrastructure covers all phase requirements.

## Manual-Only Verifications

All phase behaviors have automated verification.

## Validation Sign-Off

- [x] All tasks have automated verification.
- [x] Sampling continuity: no 3 consecutive tasks without automated verification.
- [x] Existing infrastructure covers all requirements.
- [x] No watch-mode flags.
- [x] Every task has a focused command; the multi-minute aggregate gate is wave/phase scoped.
- [x] `nyquist_compliant: true` set in frontmatter.

**Approval:** validated 2026-08-10 from executable contract evidence

## Validation Audit 2026-08-10

| Metric | Count |
|--------|-------|
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |

Audit evidence:

- `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs test/chimeway/doc_contract_test.exs --warnings-as-errors` — 613 tests, 0 failures.
- `mix ci.verify_gates` — 612 tests, 0 failures, 1 excluded.
- Plans 03 and 04 were added to the per-task map; all eight phase tasks map to existing green automated contracts.
