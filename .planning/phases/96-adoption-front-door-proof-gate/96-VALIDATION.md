---
phase: 96
slug: adoption-front-door-proof-gate
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-10
---

# Phase 96 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (existing project suite) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/doc_contract_test.exs test/chimeway/release_gate_contract_test.exs --warnings-as-errors` |
| **Full suite command** | `mix ci.verify_gates` plus `mix verify.adoption_paths` for the behavioral clean-room proof |
| **Estimated runtime** | Structural contracts: under 2 minutes; aggregate proof: measure in CI |

## Sampling Rate

- **After every task commit:** Run `mix ci.verify_gates` for contracts; run `mix verify.adoption_paths --only <path>` after runner changes.
- **After every plan wave:** Run `mix ci.verify_gates`; run `mix verify.adoption_paths` once the aggregate runner is present.
- **Before phase verification:** `mix ci.verify_gates` must be green and the dedicated `verify_adoption_paths` PostgreSQL CI job must pass.
- **Max feedback latency:** under 2 minutes for structural contracts; bounded focused proof run for runner changes.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 96-01-01 | 01 | 1 | GATE-01 | T-96-01 | Bounded `--only` parsing rejects unknown, duplicate, and positional input before proof output; selected paths run serially through existing fixture capabilities. | task/runner contract | `mix ci.verify_gates` and `mix verify.adoption_paths --only core` | ❌ extend release-gate contract | ⬜ pending |
| 96-01-02 | 01 | 1 | GATE-01 | T-96-02 | Output preserves exactly one allowlisted proof record per selected path and uses only fixed, redacted START/PASS/FAIL framing. | runner contract | `mix ci.verify_gates` and focused proof commands | ❌ extend release-gate contract | ⬜ pending |
| 96-02-01 | 02 | 2 | ADPT-01, ADPT-02, DOCS-01 | — | Selector presents all-and-only Core, Mailglass, and Accrue paths with ownership, commands, safe evidence, boundaries, guide links, and README/ExDoc placement. | documentation contract | `mix ci.verify_gates` | ✅ extend doc contract | ⬜ pending |
| 96-02-02 | 02 | 2 | GATE-02, DOCS-01 | T-96-03 | One non-PR PostgreSQL 15 CI lane runs the aggregate command, is included in `ci-gate`, and is excluded from `pr-gate`. | CI topology contract | `mix ci.verify_gates` | ✅ extend release-gate contract | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

## Wave 0 Requirements

- [ ] Extend `test/chimeway/doc_contract_test.exs` with selector-first, README, guide-link, command, responsibility, and limitation assertions.
- [ ] Extend `test/chimeway/release_gate_contract_test.exs` with option parsing, runner dispatch/framing, fixture capability, CI service/command, and `ci-gate` membership assertions.
- [ ] Add focused task/runner tests only if the existing release-gate contracts cannot safely cover direct invocation; do not introduce a parallel truth checker.

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Dedicated GitHub Actions proof lane succeeds from a built/unpacked artifact | GATE-02 | Requires GitHub-hosted PostgreSQL service execution | Confirm one green `verify_adoption_paths` run and inspect only bounded per-path diagnostics. |

## Validation Sign-Off

- [ ] All tasks have `<automated>` verification or Wave 0 dependencies.
- [ ] Sampling continuity: no 3 consecutive tasks without automated verification.
- [ ] Wave 0 covers all missing test references.
- [ ] No watch-mode flags.
- [ ] Feedback latency is bounded.
- [ ] `nyquist_compliant: true` set in frontmatter.

**Approval:** pending
