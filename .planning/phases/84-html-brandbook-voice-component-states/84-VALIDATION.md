---
phase: 84
slug: html-brandbook-voice-component-states
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-18
---

# Phase 84 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Dependency-free shell guards (`scripts/brandbook-guards.sh`, modeled on `scripts/logo-guards.sh`) |
| **Config file** | none — guard script authored in this phase |
| **Quick run command** | `bash scripts/brandbook-guards.sh` |
| **Full suite command** | `bash scripts/brandbook-guards.sh` (file://-safety negative-greps + scope non-leakage + section presence) |
| **Estimated runtime** | ~2 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bash scripts/brandbook-guards.sh`
- **After every plan wave:** Run `bash scripts/brandbook-guards.sh`
- **Before `/gsd-verify-work`:** Guards must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| {N}-01-01 | 01 | 1 | BOOK-01 | — | `index.html` contains no `fetch(`, no cross-file `<use href=".*\.svg#`, all asset refs relative | guard | `bash scripts/brandbook-guards.sh` | ❌ W0 | ⬜ pending |

*Populated by the planner. Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `scripts/brandbook-guards.sh` — file://-safety + scope non-leakage + section-presence guards
- [ ] Establish negative-grep patterns for `fetch(`, XHR, ES-module `import`, cross-file `<use href="*.svg#…">`

*Guards are authored in this phase; no external test framework is installed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Book renders correctly opened via `file://` in Chromium | BOOK-01 | Visual/browser behavior not scriptable in CI without a headless harness | Open `brandbook/index.html` directly (double-click / `file://` URL) in Chromium; confirm logos, swatches, states, theme toggle, and contrast matrix all render with no console errors |
| Theme toggle (light/dark/system) flips correctly and "system" respects OS preference | BOOK-03 | Requires interaction + OS-level preference change | Toggle through light → dark → system; change OS appearance and confirm "system" follows |
| Component states + do/don't pairs read as professional/responsive across viewports | STATE-01, BOOK-03 | Subjective visual quality | Resize viewport; inspect each state and do/don't pair |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
