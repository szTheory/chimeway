---
phase: 41
slug: release-verification-gates
status: draft
nyquist_compliant: false
wave_0_complete: true
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
| 41-01-01 | 01 | 1 | GATE-01 / D-01–D-04 | — | Adoption-surface doc strings gated | unit | `mix ci.verify_gates` | ✅ W0 | ✅ green |
| 41-01-02 | 01 | 1 | GATE-01 / D-05–D-07 | — | Version + installer alignment | unit | `mix ci.verify_gates` | ✅ W0 | ✅ green |
| 41-02-01 | 02 | 2 | GATE-01 / D-12–D-16 | — | Named alias + runbook | integration | `mix ci.verify_gates` | ✅ W0 | ✅ green |
| 41-02-02 | 02 | 2 | GATE-01 / D-14–D-16 | — | MAINTAINING.md pre-ship quartet + installer conditional | manual+grep | `grep mix ci.verify_gates MAINTAINING.md` | ✅ W0 | ✅ green |
| 41-02-03 | 02 | 2 | GATE-01 | — | Partial validation sign-off after wave 2 | integration | `mix ci.verify_gates && mix ci.docs && mix ci` | ✅ W0 | ✅ green |
| 41-03-01 | 03 | 3 | GATE-01 / D-08–D-11 | — | Example host + admin smoke in CI | integration | `mix verify.example` | ❌ W0 | ⬜ pending |
| 41-03-02 | 03 | 3 | GATE-01 / D-08 | — | verify_example CI job with Postgres | integration | `grep verify_example .github/workflows/ci.yml` | ❌ W0 | ⬜ pending |
| 41-03-03 | 03 | 3 | GATE-01 | — | Final nyquist_compliant sign-off | integration | full GATE-01 quartet | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Golden-path describe block in `doc_contract_test.exs`
- [x] Installation describe block
- [x] README describe block
- [x] Oban-integration describe block (IN-01)
- [x] Version alignment describe (or sibling test module)
- [x] Golden-path trigger opt parity test
- [x] `mix ci.verify_gates` alias in `mix.exs`
- [ ] `verify.example` admin subprocess expansion
- [ ] `verify_example` job in `.github/workflows/ci.yml`
- [x] `MAINTAINING.md` step 3 + installer conditional (D-14, D-15)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Fresh Phoenix host walkthrough | GATE-01 (deferred) | Full host bootstrap too heavy for CI | Manual UAT once per release |
| MAINTAINING.md prose review | D-14, D-15 | Doc readability | Read step 3 for four mandated commands |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (partial — verify.example CI items deferred to 41-03)
- [x] No watch-mode flags
- [x] Feedback latency < 90s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending (wave 2 partial — 41-03 remains)

---

## Wave 2 Verification Record (41-02-03)

| Command | Result | Notes |
|---------|--------|-------|
| `mix ci.verify_gates` | ✅ exit 0 | 94 tests, 0 failures, ~0.08s |
| `mix ci.docs` | ❌ exit 1 | Pre-existing: ex_doc warnings for `../../examples/chimeway_demo_host/README.md` and `../../chimeway_admin/` relative links in guides (present before 41-02) |
| `mix ci` | ✅ exit 0 | 655 tests, 0 failures (after format fix to `doc_contract_test.exs`) |
