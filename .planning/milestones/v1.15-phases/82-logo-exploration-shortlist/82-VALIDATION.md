---
phase: 82
slug: logo-exploration-shortlist
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-10
---

# Phase 82 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
>
> **Phase shape:** static doc/asset phase — the only artifact is `notes/logo-options.md` (inline `<svg>`). There is **no test framework** (Elixir project; no JS runner; adding one is out of scope). Validation is **checker-verifiable gates + shell grep guards + human visual review of the ephemeral `file://` gallery** — the honest, correct shape for a doc phase, not a gap to paper over with machinery.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | none — no test runner for Markdown/SVG; adding one is out of scope |
| **Config file** | none |
| **Quick run command** | `scripts/logo-guards.sh` (grep + optional `xmllint`; shell, no deps) — authored in Wave 0 |
| **Full suite command** | Human visual review of the ephemeral `file://` gallery against the D-12 legibility + taste gates |
| **Estimated runtime** | ~2 seconds (guards); manual review ~5 min |

---

## Sampling Rate

- **After every task commit:** Run the grep guards (verdict count, confidence count, token-hex subset, proof-label presence).
- **After every plan wave:** Open the `file://` gallery; visually confirm each direction survives 16px / mono / inverse and honors the taste gates.
- **Before `/gsd-verify-work`:** All 5 directions present with verdict + confidence + proof strip; ≥2 integrated typemarks; rejected retained inline with reasons; `git diff --stat` shows only `notes/logo-options.md` changed.
- **Max feedback latency:** ~5 seconds (guards); visual review is a per-wave manual step.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 82-01-01 | 01 | 1 | — | T-82-01 | Guard script exists; SVG-hygiene grep (no `<script>`/`on*`/`<foreignObject>`/remote `href`) returns zero | shell | `scripts/logo-guards.sh` | ❌ W0 | ⬜ pending |
| 82-01-02 | 01 | 1 | LOGO-01 / NOTES-02 | — | N/A | grep | `grep -cE '^Verdict: (Ship\|Defer\|Reject)' notes/logo-options.md` (≥5); `grep -cE 'Confidence: (High\|Medium\|Low)'` (≥5) | ❌ W0 | ⬜ pending |
| 82-01-03 | 01 | 1 | LOGO-02 | — | N/A | manual + grep | Direction labels grep + visual confirm motif is *in* the letterform (≥2 integrated typemarks) | ❌ W0 | ⬜ pending |
| 82-01-04 | 01 | 1 | LOGO-05 / LOGO-06 | — | N/A | manual | Visual review — no bg cage, no primary subtitle, unified unit, path/route/signal metaphor only (zero literal bell/note/staff) | ❌ W0 | ⬜ pending |
| 82-01-05 | 01 | 1 | D-11 | — | N/A | grep | Extract `#[0-9a-fA-F]{6}` in SVG blocks; assert ⊆ token hex set (`102027,07131a,fffdf8,0e7c86,d6a84f,9adbcf`) | ❌ W0 | ⬜ pending |
| 82-01-06 | 01 | 1 | D-12 (LOGO-04 intent) | — | N/A | grep + manual | Per shortlisted direction: presence of `16px`, `Mono`, `Inverse`, `Clear-space`, `Min-size` labels + visual 16px/mono/inverse legibility | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `scripts/logo-guards.sh` — shell guard: verdict/confidence counts, proof-label presence per direction, token-hex-subset assertion, SVG-hygiene scan (no active content), optional `xmllint --noout` well-formedness per `<svg>` block (skipped if `xmllint` absent). No framework install.

*No test framework to install — the "Wave 0 gap" is a single shell guard script authored alongside the doc and run before each commit.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Mark reads recognizably at 16px, mono, and inverse | D-12 / LOGO-04 | Legibility is a perceptual judgment; no automated proxy for "recognizable" | Open the `file://` gallery; view each shortlisted mark's proof strip at real scale; confirm the concept survives all three |
| Motif is genuinely integrated into the letterform | LOGO-02 / D-04 | "Integrated vs. placed-beside" is a design judgment, not textually greppable | Visual review — confirm ≥2 directions work the motif *into* a `chimeway` glyph (routed path / ligature), not an icon next to plain font |
| No literal bell/clapper/note/staff; metaphor is path/route/signal/trace | LOGO-06 / D-05 | Semantic image meaning is not greppable | Visual review of every direction (shortlisted + rejected) |
| No rectangular/enclosing cage; unified mark+wordmark; no primary subtitle | LOGO-05 / D-06/07/08 | Layout/enclosure judgment | Visual review; guard flags only full-bleed `<rect>` outside inverse proof cells for a closer look |

*Not all phase behaviors have automated verification — this is expected and correct for a creative doc/asset phase. Grep guards cover countable/structural gates; perceptual and semantic gates are human-verified against the `file://` gallery.*

---

## Validation Sign-Off

- [ ] All tasks have a grep guard or a documented Manual-Only verification (no silent gaps)
- [ ] Sampling continuity: grep guards run per commit; visual review per wave
- [ ] Wave 0 covers the guard script (the only "MISSING" reference)
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s (guards)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
