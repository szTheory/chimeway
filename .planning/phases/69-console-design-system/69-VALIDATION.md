---
phase: 69
slug: console-design-system
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-06-04
---

# Phase 69 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit plus Phoenix.LiveViewTest; Floki available for structural HTML parsing |
| **Config file** | `chimeway_admin/test/test_helper.exs` |
| **Quick run command** | `cd chimeway_admin && mix test test/chimeway_admin/design_system_test.exs` |
| **Full suite command** | `cd chimeway_admin && mix test` |
| **Estimated runtime** | ~30 seconds quick, ~90 seconds full |

---

## Sampling Rate

- **After every task commit:** Run the focused design-system test once it exists.
- **After every plan wave:** Run `cd chimeway_admin && mix test`.
- **Before `$gsd-verify-work`:** Full `chimeway_admin` suite must be green.
- **Max feedback latency:** 90 seconds.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 69-01-01 | 01 | 0 | DES-01 | T-69-01 | Scoped `.chimeway-admin` and `--cw-*` tokens remain package-local | contract | `cd chimeway_admin && mix test test/chimeway_admin/design_system_test.exs` | No, W0 | pending |
| 69-01-02 | 01 | 0 | DES-02 | T-69-02 | Theme state tokens preserve contrast hooks without exposing new data | contract | `cd chimeway_admin && mix test test/chimeway_admin/design_system_test.exs` | No, W0 | pending |
| 69-02-01 | 02 | 1 | DES-03 | T-69-03 | Responsive hooks do not alter auth, recovery, or DTO behavior | LiveView/structure | `cd chimeway_admin && mix test test/chimeway_admin/live/design_system_live_test.exs` | No, W0 | pending |
| 69-02-02 | 02 | 1 | DES-04 | T-69-04 | Motion is CSS-only, reduced-motion-safe, and non-blocking | contract | `cd chimeway_admin && mix test test/chimeway_admin/design_system_test.exs` | No, W0 | pending |

---

## Wave 0 Requirements

- [ ] `chimeway_admin/test/chimeway_admin/design_system_test.exs` - focused CSS contract tests for DES-01, DES-02, and DES-04.
- [ ] `chimeway_admin/test/chimeway_admin/live/design_system_live_test.exs` - rendered shell/component hook tests for DES-03.
- [ ] Test helpers, if needed, for loading `chimeway_admin/priv/static/chimeway_admin.css` and asserting required token/state selectors.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Mobile and desktop visual evidence for no overlap or broken hierarchy | DES-03 | Phase 72 owns durable browser smoke and `mix verify.admin`; Phase 69 should produce screenshot-ready evidence without making browser automation the release gate | Run the admin demo locally after implementation and capture 390px mobile plus 1280px desktop views for command center, trace search, trace detail, feed, definitions, health, and recovery. Do not commit large binary screenshots unless the executor finds an existing project convention. |

---

## Validation Sign-Off

- [x] All tasks have automated verify commands or Wave 0 dependencies.
- [x] Sampling continuity: no 3 consecutive tasks without automated verify.
- [x] Wave 0 covers all missing references.
- [x] No watch-mode flags.
- [x] Feedback latency < 90s.
- [x] `nyquist_compliant: true` set in frontmatter.

**Approval:** approved 2026-06-04 for planning
