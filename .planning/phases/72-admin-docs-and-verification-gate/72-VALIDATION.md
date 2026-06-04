---
phase: 72
slug: admin-docs-and-verification-gate
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-06-04
---

# Phase 72 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit, Phoenix LiveViewTest, doc-contract ExUnit tests, Playwright Chromium |
| **Config file** | `mix.exs`, `.github/workflows/ci.yml`, `playwright.config.ts` |
| **Quick run command** | `mix test` |
| **Full suite command** | `mix verify.admin` |
| **Estimated runtime** | ~120 seconds before browser install/download overhead |

---

## Sampling Rate

- **After every task commit:** Run the narrow command named by the task (`mix test <file>`, package-scoped `mix test`, or Playwright smoke for browser work).
- **After Wave 1:** Run the targeted commands created by Plans 72-01 and 72-02: `mix docs --warnings-as-errors`, `MIX_ENV=test mix test test/chimeway/doc_contract_test.exs --warnings-as-errors`, `mix ci.verify_gates`, `npm ci`, `npx playwright install chromium`, and `npx playwright test test/browser/admin_smoke.spec.ts`.
- **After Wave 2:** Run `mix verify.admin` after Plan 72-03 creates the alias and CI/release parity wiring.
- **Before `$gsd-verify-work`:** `mix verify.admin` and CI parity checks must be green.
- **Max feedback latency:** 180 seconds for non-browser tasks; browser smoke may exceed this when Playwright browsers are installed.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 72-01-docs | 01 | 1 | DOCS-12 | T-72-01 / T-72-02 | Integration guide documents fail-closed auth, redaction, host-owned tenancy/session context, and recovery permissions without exposing payload/provider secrets. | doc contract | `mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` | W0 | pending |
| 72-02-smoke | 02 | 1 | SMOKE-01 | T-72-04 / T-72-05 | Browser smoke proves the mounted admin console is nonblank, styled by packaged CSS, navigable across core pages, and minimally usable without asserting sensitive data. | Playwright | `npm ci && npx playwright install chromium && npx playwright test test/browser/admin_smoke.spec.ts` | W0 | pending |
| 72-03-gate | 03 | 2 | GATE-08 | T-72-03 | `mix verify.admin` runs admin-specific tests and cannot drift from CI/release-gate parity. | mix alias + contract | `mix verify.admin` | W0 | pending |

*Status: pending · green · red · flaky*

---

## Wave 0 Requirements

- [ ] `test/chimeway/doc_contract_test.exs` — root doc-contract coverage for DOCS-12 admin integration guide claims.
- [ ] `playwright.config.ts` — browser smoke configuration for demo-host mounted admin route.
- [ ] `test/browser/admin_smoke.spec.ts` — Playwright smoke coverage for SMOKE-01.
- [ ] `package.json` or equivalent npm metadata — pins `@playwright/test` and exposes a repeatable smoke command.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| None | DOCS-12, GATE-08, SMOKE-01 | Phase 72 acceptance is intended to be fully automated through doc contracts, verify alias parity, CI, and browser smoke. | N/A |

---

## Validation Sign-Off

- [x] All tasks have automated verification or Wave 0 dependencies.
- [x] Sampling continuity: no 3 consecutive tasks without automated verify.
- [x] Wave 0 covers all missing references.
- [x] No watch-mode flags.
- [x] Feedback latency target is defined with a browser-install exception.
- [x] `nyquist_compliant: true` set in frontmatter.

**Approval:** pending
