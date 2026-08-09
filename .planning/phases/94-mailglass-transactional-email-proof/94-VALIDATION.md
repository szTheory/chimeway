---
phase: 94
slug: mailglass-transactional-email-proof
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-08-08
---

# Phase 94 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit / Mix |
| **Config file** | `mix.exs` |
| **Quick run command** | `mix test test/chimeway/release_gate_contract_test.exs test/chimeway/doc_contract_test.exs` |
| **Full suite command** | `mix ci.verify_gates` |
| **Estimated runtime** | ~60 seconds |

## Sampling Rate

- **After every task commit:** Run `mix test test/chimeway/release_gate_contract_test.exs test/chimeway/doc_contract_test.exs`
- **After every plan wave:** Run `mix ci.verify_gates`
- **Before phase verification:** `mix ci.verify_gates` must be green.
- **Max feedback latency:** 60 seconds

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 94-01-01 | 01 | 1 | MAIL-01, MAIL-02 | T-94-01, T-94-03, T-94-04, T-94-05 | The unpacked-artifact tracer proves the exact host-owned Mailglass path, sanitized public trace, provenance, Fake ownership, and cleanup. | integration / release-gate contract | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors` | ✅ | ⬜ pending |
| 94-01-02 | 01 | 1 | MAIL-01, MAIL-02 | T-94-02, T-94-04 | The strict parser rejects unknown, duplicate, missing, malformed, repeated-prefix, and unsafe evidence without atom creation or leaked resources. | integration / release-gate contract | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors` | ✅ | ⬜ pending |
| 94-02-01 | 02 | 2 | MAIL-02 | T-94-06, T-94-07, T-94-08 | Documentation contracts require one-repo ownership, the exact Fake/adapter-attempt distinction, all live-provider exclusions, and the blueprint link. | documentation contract | `MIX_ENV=test mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` | ✅ | ⬜ pending |
| 94-02-02 | 02 | 2 | MAIL-02 | T-94-06, T-94-09 | Negative documentation contracts reject live-delivery overclaims and Hex-consumer presentation of the maintainer-only suite; release/doc gates remain in parity. | documentation contract / gate suite | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs test/chimeway/doc_contract_test.exs --warnings-as-errors && mix ci.verify_gates` | ✅ | ⬜ pending |

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
- [x] Feedback latency < 60 seconds.
- [x] `nyquist_compliant: true` set in frontmatter.

**Approval:** pending
