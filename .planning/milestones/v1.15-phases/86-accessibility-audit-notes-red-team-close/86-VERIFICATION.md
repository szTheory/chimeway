---
phase: 86-accessibility-audit-notes-red-team-close
verified: 2026-07-28T15:17:36Z
status: human_needed
score: 4/6 must-haves verified (2 owner-waived accepted-risk human-verification items)
behavior_unverified: 0
overrides_applied: 0
human_verification:
  - test: "A11Y-04 CVD emulation — open brandbook/index.html via file:// in Chrome; DevTools → Rendering → 'Emulate vision deficiencies'; cycle Protanopia/Deuteranopia/Tritanopia/Achromatopsia and confirm every status pill (Succeeded/Suppressed/Failed/Enqueued/Planned/Sending) stays tellable apart by label + icon, not hue."
    expected: "Every status remains distinguishable by label + icon under all four CVD emulations (never color-alone)."
    why_human: "CVD emulation is an inherently manual browser pass (no CVD tooling/binaries permitted this milestone). WAIVED by project owner 2026-07-28 — recorded as accepted-risk known gap in notes/accessibility-checks.md §6.1, NOT a PASS. Mitigated (not substituted) by the grep-backed never-color-alone architecture (§5, index.html:176-183). Surface for ship decision."
  - test: "A11Y-03 focus-not-obscured (SC 2.4.11) — click into the rendered file:// page, Tab through every interactive control (brandmark link, 10 jump-nav anchors, 3 theme-toggle buttons, in-content links) and confirm no focused control is ENTIRELY hidden behind the sticky .cwb-nav bar (partial overlap allowed)."
    expected: "No focused control is entirely hidden behind the sticky nav on keyboard tab."
    why_human: "Focus-not-obscured requires a real keyboard-tab pass on the rendered page. WAIVED by project owner 2026-07-28 — recorded as accepted-risk known gap in notes/accessibility-checks.md §6.2, NOT a PASS. Mitigated (not substituted) by RESEARCH A3 low-risk assessment + rendered-CSS focus evidence (§4). Surface for ship decision."
---

# Phase 86: Accessibility Audit, Notes & Red-Team Close — Verification Report

**Phase Goal:** Verify accessibility against named WCAG 2.2 criteria on the *rendered* brand book (not discovered late), complete the decision/research record, and run the milestone-close red-team that locks the `brandbook/`-only scope boundary.
**Verified:** 2026-07-28T15:17:36Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Owner Decision — 2026-07-28

The project owner reviewed this verdict and **accepted the risk** on the two waived manual checks (A11Y-03 focus-not-obscured, A11Y-04 CVD emulation) rather than running the manual browser verification. Phase 86 is therefore **marked complete carrying a documented accepted-risk gap**: A11Y-03 and A11Y-04 remain **Pending / not-manually-verified** in REQUIREMENTS.md and ride forward to the v1.15 milestone ship gate as a conscious, visible accepted-risk item — not a pass. The verifier's `human_needed` verdict above is preserved unaltered; this section records the owner's downstream disposition of it. A follow-up manual pass (`/gsd-verify-work 86`) can still close the gap before v1.15 ships.

## Goal Achievement

The phase goal decomposes into three deliverables: (1) accessibility verified against named WCAG 2.2 criteria on the rendered book, (2) the decision/research record completed, (3) the milestone-close red-team locking the `brandbook/`-only scope boundary. Deliverables (2) and (3) are fully machine-verified. Deliverable (1) is machine-verified for every criterion that can be evidenced without a browser (contrast, focus-visible, reduced-motion, target-size, never-color-alone architecture); the two genuinely-manual criteria — A11Y-03 focus-not-obscured (SC 2.4.11) and A11Y-04 CVD emulation (SC 1.4.1 intent) — were **WAIVED by the project owner on 2026-07-28** and are recorded truthfully as accepted-risk known gaps, not passes. The verifier surfaces these two waived items for the ship decision rather than fabricating a pass or failing the phase.

### Observable Truths

| #   | Truth (mapped to ROADMAP Success Criteria)                                                                                                  | Status                    | Evidence |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------- | -------- |
| 1   | SC1 — `accessibility-checks.md` records per-pairing ratios (text SC 1.4.3, non-text SC 1.4.11) via a re-runnable offline calc (A11Y-01/02/05) | ✓ VERIFIED                | `contrast-audit.sh` exits 0; 38 rows (19 pairings × light/dark); output **byte-identical** to the quoted §1 table (backstop confirmed via diff); all load-bearing text ≥4.5:1, focus rings ≥3:1; sub-threshold pairs carry verbatim-cited exemptions |
| 2   | SC2 (machine part) — focus-visible (2.4.7), reduced-motion honored (2.3.3 AAA), targets ≥24px (2.5.8) recorded against rendered CSS (A11Y-03 partial) | ✓ VERIFIED                | §4 cites brandbook.css: `:focus-visible` rings (350-353), `prefers-reduced-motion` (465), `.cwb-btn` 40×40 (319-320), theme-toggle 32px (405-408), jump-nav ~26.9px documented finding |
| 3   | SC2 (manual) — keyboard-tab confirms no focused control entirely hidden behind sticky nav (A11Y-03 SC 2.4.11 focus-not-obscured)             | ⚠️ WAIVED — accepted-risk | Owner-waived 2026-07-28; §6.2 recorded as documented known gap, NOT a PASS; §4 CSS evidence mitigates only → Human Verification |
| 4a  | SC2 — never-color-alone architecture: every status = surface + text + label + icon (A11Y-04 architectural)                                   | ✓ VERIFIED                | Grep-backed §5, index.html:176-183; every `.cwb-badge` carries token + `aria-hidden` icon glyph + text label |
| 4b  | SC2 (manual) — CVD emulation confirms palette colorblind-safe across protan/deuter/tritan/achromat (A11Y-04 CVD, SC 1.4.1 intent)            | ⚠️ WAIVED — accepted-risk | Owner-waived 2026-07-28; §6.1 recorded as documented known gap, NOT a PASS; four DevTools boxes in §5 deliberately unticked → Human Verification |
| 5   | SC3 — `research.md` captures research basis + verbatim WCAG citations + design-system analogues; every recommendation carries full NOTES-01 format (NOTES-01/04) | ✓ VERIFIED                | 6 SCs cited verbatim (1.4.3/1.4.11/2.4.7/2.4.11/2.3.3/2.5.8); USWDS+Carbon+GOV.UK analogues; R-1..R-5 each with Pros/Cons/Analogue/Cost/Verdict/Confidence (5 Verdicts, 5 Confidence) |
| 6   | SC4 — red-team pass machine-enforces `brandbook/`-only scope boundary + binary budget, closing with captured scope audit + repo-size/binary check (NOTES-03) | ✓ VERIFIED                | `--scope` exits 0 on tree, exits 1 on stray `STRAY-SCRATCH.tmp` (deny-by-default proven); `logo-guards.sh --assets` PASS: 3 rasters, 38579B ≤ 204800B; red-team.md closes with both captured outputs |

**Score:** 4/6 truths verified (2 owner-waived accepted-risk human-verification items). Truths 4a/4b are two facets of A11Y-04; 4a verified, 4b waived.

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `scripts/contrast-audit.sh` | Dependency-free re-runnable WCAG calc over token SSOT | ✓ VERIFIED | 8530B, executable; runs POSIX shell+awk, no node/npm/network; exits 0; reproduces every RESEARCH headline value |
| `notes/accessibility-checks.md` | Per-pairing evidence-of-record + cited exemptions + A11Y-03/04 sections | ✓ VERIFIED | 38-row table quoted verbatim; SC 1.4.3/1.4.11 exemptions verbatim; §6.1/6.2 waivers honestly recorded |
| `notes/research.md` | WCAG verbatim citations + analogues + NOTES-01 recommendations | ✓ VERIFIED | 6 SCs verbatim, 3 analogues, R-1..R-5 full format; record/recommendation split honored |
| `notes/red-team.md` | Skeptic pass closing with scope audit + binary budget | ✓ VERIFIED | Boundary table, skeptic-challenge table, both captured command outputs; accepted-risk gap carried honestly |
| `scripts/brandbook-guards.sh` | `--scope` allowlist widened to exact milestone boundary | ✓ VERIFIED | Allowlist = brandbook/* + README.md + mix.exs + notes/* + 4 named scripts + .planning/*; deny-by-default `*)` retained; no broad glob |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | -- | --- | ------ | ------- |
| `contrast-audit.sh` | `brandbook/tokens/tokens.css` | reads `--cw-*` hexes read-only | ✓ WIRED | Calc reads real token file; `git diff --quiet` clean (zero-drift held) |
| `contrast-audit.sh` output | `accessibility-checks.md` §1 | quoted verbatim as evidence of record | ✓ WIRED | Byte-identical diff confirmed |
| `brandbook.css` focus/motion/target rules | A11Y-03 §4 | cited line numbers | ✓ WIRED | Line refs verified against rendered CSS |
| `index.html` status markup | A11Y-04 §5 never-color-alone | grep-backed | ✓ WIRED | index.html:176-183 label+icon structure |
| `--scope` case block | machine-enforced boundary | git porcelain walk | ✓ WIRED | Deny-by-default fails on stray path (exit 1), passes on clean tree (exit 0) |
| `logo-guards.sh --assets` | red-team.md binary budget | captured output | ✓ WIRED | 3 rasters / 38579B ≤ ceiling, captured verbatim |

### Requirements Coverage

All 8 phase requirement IDs accounted for against REQUIREMENTS.md. No orphaned requirements — the traceability table maps exactly these 8 to Phase 86, and REQUIREMENTS.md already honestly marks A11Y-03/A11Y-04 as **Pending** (not falsely complete).

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ----------- | ----------- | ------ | -------- |
| A11Y-01 | 86-01 | Text contrast SC 1.4.3 (4.5:1) verified + recorded | ✓ SATISFIED | All load-bearing text ≥4.5:1; disabled 3.92 EXEMPT (Incidental, verbatim); wordmark EXEMPT (Logotypes) |
| A11Y-02 | 86-01 | Non-text/UI contrast SC 1.4.11 (3:1) verified | ✓ SATISFIED | Focus rings ≥4.78; borders EXEMPT (required-to-identify, verbatim) |
| A11Y-03 | 86-01, 86-03 | Focus visible/not-obscured (2.4.7/2.4.11), reduced motion (2.3.3), targets ≥24px (2.5.8) | ◐ PARTIAL | Machine parts VERIFIED (§4); focus-not-obscured (2.4.11) manual pass WAIVED/accepted-risk → NEEDS HUMAN |
| A11Y-04 | 86-01, 86-03 | Never-color-alone + CVD-safe palette | ◐ PARTIAL | Architecture VERIFIED (grep §5); CVD emulation WAIVED/accepted-risk → NEEDS HUMAN |
| A11Y-05 | 86-01 | Per-pairing ratios recorded vs rendered book | ✓ SATISFIED | 38-row evidence-of-record table; re-runnable calc |
| NOTES-01 | 86-02 | Cohesive recommendations (not a buffet) | ✓ SATISFIED | R-1..R-5, full format, stable topic order |
| NOTES-03 | 86-04 | Red-team pass + scope audit + binary check | ✓ SATISFIED | Machine-enforced boundary verified re-runnable; binary budget captured |
| NOTES-04 | 86-02 | Research basis + citations | ✓ SATISFIED | Verbatim WCAG + design-system analogues |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| — | — | No TBD/FIXME/XXX debt markers in any phase-modified file | — | Clean |
| — | — | No TODO/HACK/PLACEHOLDER in the record files | — | Clean |
| `accessibility-checks.md` | §6.1/6.2 | Unticked `[ ]` checklist boxes | ℹ️ Info | Intentional WAIVED markers, explicitly labeled "unticked — not verified"; NOT code stubs. Honest by design |

All 8 task commits (e239707, 138d29d, 63e7661, 5976142, d570151, fb75383, 966afee, c38ee47) exist in history.

### Human Verification Required

Two genuinely-manual browser accessibility checks were **WAIVED by the project owner on 2026-07-28** (risk accepted, manual verification not performed). They are recorded honestly as accepted-risk known gaps in `notes/accessibility-checks.md` §6.1/§6.2 and re-flagged in `notes/red-team.md` — explicitly NOT passes. Corroborating machine/CSS evidence mitigates but does not substitute for the human attestation. The milestone ship decision must consciously accept (or schedule a follow-up pass for) these two items:

#### 1. A11Y-04 — CVD emulation (SC 1.4.1 intent)

**Test:** Open `brandbook/index.html` via `file://` in Chrome; DevTools → Rendering → "Emulate vision deficiencies"; cycle Protanopia / Deuteranopia / Tritanopia / Achromatopsia; confirm every status pill stays distinguishable by label + icon, not hue.
**Expected:** All statuses remain distinguishable under all four emulations.
**Why human:** Inherently manual browser pass; no CVD tooling/binaries permitted this milestone. WAIVED (accepted-risk). Mitigation: grep-backed never-color-alone architecture (§5).

#### 2. A11Y-03 — Focus-not-obscured (SC 2.4.11)

**Test:** Click into the rendered `file://` page; Tab through all interactive controls; confirm no focused control is entirely hidden behind the sticky `.cwb-nav` bar (partial overlap allowed).
**Expected:** No focused control entirely hidden on keyboard tab.
**Why human:** Requires a real keyboard-tab pass on the rendered page. WAIVED (accepted-risk). Mitigation: RESEARCH A3 low-risk + rendered-CSS focus evidence (§4).

### Gaps Summary

There are **no defects** — the phase produced exactly what it claimed, and every machine-evidenceable claim was independently re-verified (calc re-runs byte-identical, both guards pass, deny-by-default boundary proven to fail on a stray path, zero-drift held, no new binaries). The single open item is the owner-waived manual A11Y-03/A11Y-04 browser attestation, which is honestly recorded as accepted-risk and NOT fabricated as a pass. REQUIREMENTS.md already reflects A11Y-03/A11Y-04 as Pending. Status is `human_needed` (not `passed`, not `gaps_found`): the two waived checks are inherently human-verification items surfaced here so the v1.15 milestone ship gate sees the accepted-risk gap and can close it or schedule a follow-up manual pass.

---

_Verified: 2026-07-28T15:17:36Z_
_Verifier: Claude (gsd-verifier)_
