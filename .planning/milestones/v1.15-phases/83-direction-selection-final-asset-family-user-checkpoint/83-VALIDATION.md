---
phase: 83
slug: direction-selection-final-asset-family-user-checkpoint
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-18
---

# Phase 83 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution. This phase ships
> static vector/raster brand assets — the "test framework" is `scripts/logo-guards.sh`
> (bash + grep/awk + xmllint + `magick identify`), NOT ExUnit. Asset tooling is kept out
> of the Elixir suite and out of CI (the milestone is doc/asset-only). Perceptual gates
> (16px/mono/inverse legibility, "reads as a keystone", direction ratification) are
> human-judgment and recorded at the checkpoint in `notes/decision-log.md`.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `scripts/logo-guards.sh` (bash + grep/awk + xmllint + `magick identify`) |
| **Config file** | none — the guard is self-contained; extend it in-place (new `--assets` mode) |
| **Quick run command** | `bash scripts/logo-guards.sh --assets` (over `brandbook/assets/**`) |
| **Full suite command** | `bash scripts/logo-guards.sh --assets && bash scripts/logo-guards.sh --scope` |
| **Estimated runtime** | ~3 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bash scripts/logo-guards.sh --assets` (presence/xmllint/token-hex/hygiene/viewBox for what exists so far)
- **After every plan wave:** Run `bash scripts/logo-guards.sh --assets && bash scripts/logo-guards.sh --scope` (full file gate + scope boundary)
- **Before `/gsd-verify-work`:** Both guard modes green AND the human perceptual checkpoint (16px/mono/inverse + selection ratified) recorded in `notes/decision-log.md`
- **Max feedback latency:** ~5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 83-01-01 | 01 | 0 | (infra) | T-83-01 | SVG hygiene grep covers asset files | script | `bash scripts/logo-guards.sh --assets` (self-test) | ❌ W0 (new `--assets` mode) | ⬜ pending |
| 83-01-02 | 01 | 0 | Scope | — | Working tree carries only allowed paths | script | `bash scripts/logo-guards.sh --scope` | ⚠️ exists; needs allowlist widen | ⬜ pending |
| 83-02-01 | 02 | 1 | LOGO-03 | — | Seven named optimized SVGs present, well-formed, token-hex only, viewBox present | script | `bash scripts/logo-guards.sh --assets` | ❌ W0 | ⬜ pending |
| 83-02-02 | 02 | 1 | LOGO-03 | — | SVGs optimized (precision-reduced, no editor cruft) | script (proxy) | byte-ceiling + long-float `grep -c` in guard | ❌ W0 | ⬜ pending |
| 83-02-03 | 02 | 1 | LOGO-04 | — | Inverse reads on dark, no baked bg rect | script + human | guard grep (no `#07131a` rect) + checkpoint | ❌ W0 | ⬜ pending |
| 83-03-01 | 03 | 2 | INTEG-03 | — | `favicon.svg` + `favicon.ico`(16/32/48) + `apple-touch-icon.png`(180²) shipped | script | `magick identify` dim/size assertions in guard | ❌ W0 | ⬜ pending |
| 83-03-02 | 03 | 2 | OG card | — | `og.png` = 1200×630, derived from mark | script + human | `magick identify` dims + checkpoint | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Extend `scripts/logo-guards.sh` with an `--assets` mode (presence, xmllint well-formedness, token-hex-only, no-`var(`, hygiene, viewBox present, raster dims via `magick identify`, per-file byte budget)
- [ ] Widen `scripts/logo-guards.sh --scope` allowlist to include `brandbook/assets/**` + the logo-direction section of `notes/decision-log.md`
- [ ] `svgo.config.mjs` — safe-plugin config (authoring input; keep at repo root or `scripts/`, NOT committed inside `brandbook/`)
- [ ] Tiny Chrome-render helper (render an SVG at N px → PNG) for the 16px non-blank check — may live in `scripts/` or scratchpad

*Existing infrastructure (`scripts/logo-guards.sh`, Chrome-headless render loop, fontTools) covers the rest; Wave 0 only extends it.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Mono variant survives without the teal facet (still reads as the mark) | LOGO-04 | Perceptual — "recognizable in one colour" is not textually greppable | Render mono variant, review in file:// gallery at multiple sizes, ratify at checkpoint |
| Simplified favicon reads as the keystone at 16px (not a shrunk lockup) | LOGO-04 / INTEG-03 | Perceptual legibility judgment at tiny size | Render `favicon.svg` at 16px, confirm the wedge reads; visual diff vs. naive-resize |
| Inverse mark reads on dark without a cage | LOGO-04 / LOGO-05 | "Reads cleanly, no enclosing background" is a taste gate | Render inverse on `--cw` dark bg, confirm no baked rect and adequate contrast |
| Direction ratified (Keystone/Optima confirmed or re-opened) + ship/defer rationale | LOGO-03 (SC #1) | Human taste checkpoint — the milestone's largest quality lever | Record decision + rationale in `notes/decision-log.md` |
| OG/social card derived-from-mark (not lockup naively resized) reads at feed scale | OG card | Compositional/taste judgment | Review `og.png` at typical social-preview scale |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify (guard command) or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (`--assets` mode, widened `--scope`)
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] Perceptual gates explicitly routed to the human checkpoint (not faked as automated)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
