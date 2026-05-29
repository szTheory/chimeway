---
phase: 41
slug: release-verification-gates
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-29
---

# Phase 41 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (`doc_contract_test.exs` + optional `version_alignment_test.exs`) |
| **Config file** | `mix.exs` aliases — `ci.verify_gates`, `verify.example`, `ci`, `ci.docs` |
| **Quick run command** | `mix ci.verify_gates` |
| **Full suite command** | `mix ci` + `mix verify.example` |
| **Estimated runtime** | `ci.verify_gates` ~1–3s; `verify.example` ~30–90s |

---

## Sampling Rate

- **After every task commit:** Run `mix ci.verify_gates`
- **After every plan wave:** Run `mix ci.verify_gates` + affected `mix verify.example` if wave touches example host/admin
- **Before `/gsd-verify-work`:** `mix ci`, `mix ci.docs`, `mix ci.verify_gates`, `mix verify.example` green
- **Max feedback latency:** 90 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 41-01-01 | 01 | 1 | GATE-01 / D-01–D-04 | — | Adoption-surface doc strings gated | unit | `mix ci.verify_gates` | ❌ W0 | ⬜ pending |
| 41-01-02 | 01 | 1 | GATE-01 / D-05–D-07 | — | Version + installer alignment | unit | `mix ci.verify_gates` | ❌ W0 | ⬜ pending |
| 41-02-01 | 02 | 2 | GATE-01 / D-12–D-16 | — | Named alias + runbook | integration | `mix ci.verify_gates` | ❌ W0 | ⬜ pending |
| 41-02-02 | 02 | 2 | GATE-01 / D-14–D-16 | — | MAINTAINING.md pre-ship quartet + installer conditional | manual+grep | `grep mix ci.verify_gates MAINTAINING.md` | ❌ W0 | ⬜ pending |
| 41-02-03 | 02 | 2 | GATE-01 | — | Partial validation sign-off after wave 2 | integration | `mix ci.verify_gates && mix ci.docs && mix ci` | ❌ W0 | ⬜ pending |
| 41-03-01 | 03 | 3 | GATE-01 / D-08–D-11 | — | Example host + admin smoke in CI | integration | `mix verify.example` | ❌ W0 | ⬜ pending |
| 41-03-02 | 03 | 3 | GATE-01 / D-08 | — | verify_example CI job with Postgres | integration | `grep verify_example .github/workflows/ci.yml` | ❌ W0 | ⬜ pending |
| 41-03-03 | 03 | 3 | GATE-01 | — | Final nyquist_compliant sign-off | integration | full GATE-01 quartet | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Golden-path describe block in `doc_contract_test.exs`
- [ ] Installation describe block
- [ ] README describe block
- [ ] Oban-integration describe block (IN-01)
- [ ] Version alignment describe (or sibling test module)
- [ ] Golden-path trigger opt parity test
- [ ] `mix ci.verify_gates` alias in `mix.exs`
- [ ] `verify.example` admin subprocess expansion
- [ ] `verify_example` job in `.github/workflows/ci.yml`
- [ ] `MAINTAINING.md` step 3 + installer conditional (D-14, D-15)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Fresh Phoenix host walkthrough | GATE-01 (deferred) | Full host bootstrap too heavy for CI | Manual UAT once per release |
| MAINTAINING.md prose review | D-14, D-15 | Doc readability | Read step 3 for four mandated commands |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 90s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
