---
phase: 86
slug: accessibility-audit-notes-red-team-close
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-27
---

# Phase 86 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | shell guard scripts (dependency-free, file://-safe; no test framework installed) |
| **Config file** | none — reuses `scripts/brandbook-guards.sh`, `scripts/logo-guards.sh`; adds a contrast-audit calc |
| **Quick run command** | `bash scripts/brandbook-guards.sh --scope` |
| **Full suite command** | `bash scripts/contrast-audit.sh && bash scripts/brandbook-guards.sh --scope && bash scripts/logo-guards.sh` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run the relevant guard/calc script for the touched note.
- **After every plan wave:** Run the full suite command.
- **Before `/gsd-verify-work`:** Full suite must be green (contrast calc reproduces recorded ratios; scope audit passes; binary budget passes).
- **Max feedback latency:** ~5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| (planner fills) | — | — | A11Y-01..05 / NOTES-01/03/04 | — | N/A (doc/asset-only phase) | script | (planner fills) | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `scripts/contrast-audit.sh` — dependency-free offline WCAG contrast calc reading `brandbook/tokens/tokens.css` (D-01)
- [ ] `notes/accessibility-checks.md`, `notes/research.md`, `notes/red-team.md` — created this phase
- [ ] `scripts/brandbook-guards.sh --scope` allowlist widened to `README.md`, `mix.exs`, `notes/**`, guard/render/calc scripts (D-03)

*Existing `logo-guards.sh` binary budget (3 rasters ≤200KB) covers the NOTES-03 binary check.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| CVD safety via "never color-alone" + DevTools vision-deficiency emulation | A11Y-04 | No CVD tooling / no committed screenshot binaries permitted (milestone forbids binaries) | Open `brandbook/index.html` via `file://`, DevTools → Rendering → Emulate vision deficiencies; record checklist per status/state in `notes/accessibility-checks.md` |
| Focus visible / not obscured, target size adjudication | A11Y-03 | Verified against rendered geometry (SC 2.4.7 / 2.4.11 / 2.5.8) | Tab through rendered page; record borderline jump-nav/toggle findings against SC 2.5.8 exception text |

---

## Validation Sign-Off

- [ ] All tasks have automated script verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (contrast calc + notes + allowlist widening)
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
