---
phase: 69
slug: console-design-system
status: draft
nyquist_compliant: true
wave_0_complete: not_applicable
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
| 69-01-01 | 01 | 1 | DES-01 | T-69-01 | Scoped `.chimeway-admin` and `--cw-*` tokens remain package-local | contract | `cd chimeway_admin && mix test test/chimeway_admin/design_system_test.exs` | Created by Plan 01 Task 1 | pending |
| 69-01-02 | 01 | 1 | DES-02 | T-69-02 | Theme state tokens preserve contrast hooks without exposing new data | contract | `cd chimeway_admin && mix test test/chimeway_admin/design_system_test.exs` | Created/extended by Plan 01 Tasks 1-2 | pending |
| 69-02-01 | 02 | 2 | DES-03 | T-69-03 | Responsive hooks do not alter auth, recovery, or DTO behavior | LiveView/structure | `cd chimeway_admin && mix test test/chimeway_admin/live/design_system_live_test.exs` | Created by Plan 02 Task 1 | pending |
| 69-02-02 | 02 | 2 | DES-04 | T-69-04 | Motion is CSS-only, reduced-motion-safe, and non-blocking | contract | `cd chimeway_admin && mix test test/chimeway_admin/design_system_test.exs` | Extended by Plan 02 Task 2 | pending |
| 69-02-03 | 02 | 2 | DES-03 | T-69-06 | Mobile/desktop evidence records responsive observations without adding Phase 72 browser gate work | manual visual evidence plus file contract | `cd chimeway_admin && mix test test/chimeway_admin/design_system_test.exs test/chimeway_admin/live/design_system_live_test.exs --warnings-as-errors` plus evidence-file assertions from Plan 02 Task 3 | Created by Plan 02 Task 3 | pending |

---

## Test File Creation In Planned Waves

- No separate Wave 0 exists for Phase 69.
- Wave 1 Plan 01 Task 1 creates `chimeway_admin/test/chimeway_admin/design_system_test.exs`; Wave 1 Plan 01 Task 2 extends it for theme-state contrast and reduced-motion contracts.
- Wave 2 Plan 02 Task 1 creates `chimeway_admin/test/chimeway_admin/live/design_system_live_test.exs`; Wave 2 Plan 02 Task 2 extends CSS contract coverage for responsive primitives.
- Wave 2 Plan 02 Task 3 creates `.planning/phases/69-console-design-system/69-EVIDENCE.md` with responsive visual observations. Test files and evidence files are created in-place by their planned tasks, not by a separate setup wave.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Mobile and desktop visual evidence for no overlap or broken hierarchy | DES-03 | Phase 72 owns durable browser smoke and `mix verify.admin`; Phase 69 should produce screenshot-ready evidence without making browser automation the release gate | Run the admin demo locally after implementation and record manual 390px mobile plus 1280px desktop observations for command center, trace search, trace detail, feed, definitions, health, and recovery. Each viewport/surface observation must record PASS/FAIL notes for no text overlap, no unintended horizontal page overflow outside intentional table wrappers, stable controls, readable hierarchy, and long IDs unclipped or wrapped. Optional screenshot references may be included, but do not commit large binary screenshots unless the executor finds an existing project convention. |

---

## Validation Sign-Off

- [x] All tasks have automated verify commands; test files are created in-place by the planned tasks.
- [x] Sampling continuity: no 3 consecutive tasks without automated verify.
- [x] No separate Wave 0 is required; Plan 01 runs in Wave 1 and Plan 02 runs in Wave 2.
- [x] No watch-mode flags.
- [x] Feedback latency < 90s.
- [x] `nyquist_compliant: true` set in frontmatter.

**Approval:** approved 2026-06-04 for planning
