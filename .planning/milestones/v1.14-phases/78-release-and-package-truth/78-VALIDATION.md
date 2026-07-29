---
phase: 78
slug: release-and-package-truth
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-03
---

# Phase 78 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit through Mix |
| **Config file** | `mix.exs` aliases; `test/test_helper.exs` |
| **Quick run command** | `MIX_ENV=test mix test test/chimeway/doc_contract_test.exs test/chimeway/release_gate_contract_test.exs --warnings-as-errors` |
| **Full suite command** | `mix ci.verify_gates && mix ci.docs && mix verify.parity` |
| **Estimated runtime** | ~60 seconds for quick contracts; artifact parity runtime depends on `mix hex.build --unpack` |

---

## Sampling Rate

- **After every task commit:** Run `MIX_ENV=test mix test test/chimeway/doc_contract_test.exs test/chimeway/release_gate_contract_test.exs --warnings-as-errors`
- **After package/artifact edits:** Run `mix verify.parity`
- **After every plan wave:** Run `mix ci.verify_gates && mix ci.docs && mix verify.parity`
- **Before `/gsd:verify-work`:** Full suite and package artifact proof must be green
- **Max feedback latency:** 90 seconds for contract-only tasks; package artifact tasks may exceed this because they build/unpack a Hex package

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 78-01-01 | 01 | 1 | TRUTH-01 | T-78-01 | Release/package metadata, changelog, docs refs, README install constraints, and release automation agree without exposing secrets | contract | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors` | yes | pending |
| 78-01-02 | 01 | 1 | TRUTH-02 | T-78-02 | Package-facing repository/source links point to `https://github.com/szTheory/chimeway` and reject stale `jonlunsford/chimeway` links | contract | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs test/chimeway/doc_contract_test.exs --warnings-as-errors` | yes | pending |
| 78-02-01 | 02 | 1 | TRUTH-03 | T-78-03 | Sibling package docs state preview/path status and do not advertise unpublished Hex dependency installs | doc contract | `MIX_ENV=test mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` | yes | pending |
| 78-03-01 | 03 | 2 | TRUTH-01 | T-78-04 | Root package artifact proof covers whitelisted package files and unpacked Hex behavior | artifact smoke | `mix verify.parity` | yes | pending |
| 78-03-02 | 03 | 2 | TRUTH-01, TRUTH-02, TRUTH-03 | T-78-05 | Release/package truth gates fail on package, release, install, source-ref, or sibling-status drift | CI gate | `mix ci.verify_gates && mix ci.docs && mix verify.parity` | yes | pending |

*Status: pending | green | red | flaky*

---

## Wave 0 Requirements

- [ ] `test/chimeway/release_gate_contract_test.exs` - add TRUTH-01 guards for root version, release manifest, changelog release anchor, HexDocs `source_ref`, README install constraint, Release Please root config, package files whitelist, and artifact unpack proof.
- [ ] `test/chimeway/release_gate_contract_test.exs` - add TRUTH-02 canonical package-facing URL guards for `mix.exs`, README badge/source surfaces, changelog/source-facing links, and release/publish workflow references.
- [ ] `test/chimeway/doc_contract_test.exs` - add TRUTH-03 positive and negative sibling install-status checks for admin and inbox guides.
- [ ] `mix.exs` - fix the default `mix hex.build --unpack` failure caused by `sigra` using `override: true`.
- [ ] `mix verify.parity` - preserve or update the alias so it proves package files and unpacked Hex behavior without stale source links.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Live Hex package status for sibling packages | TRUTH-03 | Live Hex state can change independently of this repository | Before release, re-check `chimeway_admin` and `chimeway_inbox` on Hex and update copy/tests if either package is published. |
| Published `chimeway` metadata for existing `1.0.0` release | TRUTH-01 | Existing Hex metadata cannot be changed by local tests alone | Confirm whether remediation requires a new release; do not claim old published metadata was retroactively changed unless Hex proves it. |

---

## Validation Sign-Off

- [ ] All tasks have automated verification or explicit manual-only rationale
- [ ] Sampling continuity: no 3 consecutive tasks without automated verification
- [ ] Wave 0 covers all missing references
- [ ] No watch-mode flags
- [ ] Feedback latency is acceptable for contract checks
- [ ] `nyquist_compliant: true` set in frontmatter after the plan checker confirms coverage

**Approval:** pending
