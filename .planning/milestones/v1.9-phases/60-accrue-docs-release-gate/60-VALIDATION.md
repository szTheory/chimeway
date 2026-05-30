---
phase: 60
slug: accrue-docs-release-gate
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-30
---

# Phase 60 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Mix) |
| **Config file** | `mix.exs` aliases `verify.accrue`, `ci.verify_gates`, `ci.test` excludes |
| **Quick run command** | `mix ci.verify_gates` |
| **Full suite command** | `ACCRUE_PATH="${ACCRUE_PATH:-../accrue/accrue}" mix verify.accrue --warnings-as-errors` |
| **Estimated runtime** | ~15s verify_gates; ~2–3 min verify.accrue |

---

## Sampling Rate

- **After every task commit:** Run `mix ci.verify_gates` when doc-contract or release-gate files changed
- **After every plan wave:** Run full `mix verify.accrue` when Accrue sibling available (or rely on `verify_accrue` CI job)
- **Phase acceptance:** Green `mix ci.verify_gates` + green `verify_accrue` CI job — no `/gsd-verify-work` required
- **Max feedback latency:** 180 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 60-01-01 | 01 | 1 | DOCS-08 | T-60-01 | Guide uses billing-event path, not fictional modules | doc | `accrue dunning integration guide doc contract` | ✅ | ✅ green |
| 60-01-02 | 01 | 1 | DOCS-08 | — | Reciprocal blueprint/README links | doc | README + hexdocs extras + ECOS-07 blueprint contracts | ✅ | ✅ green |
| 60-02-01 | 02 | 2 | DOCS-09 | T-60-02 | Doc-contract locks guide truth | unit | `mix ci.verify_gates` | ✅ | ✅ green |
| 60-03-01 | 03 | 1 | GATE-05 | T-60-03 | CI checks out Accrue sibling before verify | integration | `verify_accrue` CI job + release gate parity contract | ✅ | ✅ green |
| 60-03-02 | 03 | 1 | GATE-05 | — | MAINTAINING lists seven gates | doc | `release gate parity doc contract (GATE-05)` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements — no Wave 0 install.

- Doc-contract harness exists (`doc_contract_test.exs`)
- Release gate parity harness exists (`release_gate_contract_test.exs`)
- `mix verify.accrue` alias exists (Phase 59)
- `verify_mailglass` CI job is copy template

---

## Automated Acceptance (Zero-Human UAT)

All former manual checks are now machine-verified:

| Former manual item | Automated replacement |
|--------------------|----------------------|
| Guide golden-path walkthrough | Section-ordering + required-string doc contracts in `doc_contract_test.exs` |
| CI job green on GitHub | `verify_accrue` job in `.github/workflows/ci.yml` + release gate parity contract |
| MAINTAINING ↔ CI parity | `release_gate_contract_test.exs` |

Prose readability remains a code-review concern, not a release gate.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 180s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** complete — automated UAT signed off 2026-05-30
