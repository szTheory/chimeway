---
phase: 81-design-tokens-reconciliation-documentation
plan: 03
subsystem: design-tokens
tags: [design-tokens, dtcg, tokens-json, alias-refs, reconciliation, brandbook]

# Dependency graph
requires:
  - phase: 81-01
    provides: brandbook/tokens/tokens.css — the canonical --cw-* value set this JSON mirrors by hand
provides:
  - brandbook/tokens/tokens.json — hand-authored DTCG 2025.10 mirror of tokens.css (TOKEN-02, TOKEN-03)
  - Tool-portable design-token export consumable by DTCG-aware tooling (Style Dictionary, Tokens Studio, etc.)
affects: [ADMIN-RETHEME-01, admin-console-retheme, design-tokens, brand-book]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Hand-authored DTCG (Design Tokens Format Module 2025.10): $type inheritance per parent group, alias refs {color.primitive.*}, dimension/duration as {value,unit} objects (no build tool, D-09)"
    - "Two-tier only: color.primitive.* (raw hex, SSOT) + color.semantic.light/dark siblings aliasing the primitive tier (D-10/D-11)"
    - "2-space JSON house style (package.json/.mcp.json), double-quoted keys, no trailing commas"

key-files:
  created:
    - brandbook/tokens/tokens.json
  modified: []

key-decisions:
  - "Semantic values equal to a primitive hex are authored as alias refs, never duplicated hex (D-10)"
  - "Light/dark are two sibling groups color.semantic.light/dark; 'system' has no JSON node — CSS-only strategy (D-11)"
  - "--cw-info authored as {color.primitive.blue} alias, not a hex literal (D-06)"
  - "Motion emits duration-only {value,unit:ms}; ease-out easing kept in CSS shorthand and noted in $description, not hard-coded as cubicBezier (DIV-5, RESEARCH Open Q2)"
  - "Shadow.panel decomposed to a light-theme {color,offsetX,offsetY,blur,spread} object; dark elevation is a CSS theming concern, not a JSON sibling (D-11)"
  - "radius.sm authored verbatim as 5px (DIV-1 DEFERRED, not the brand-book 4px)"

metrics:
  duration: ~10m
  completed: 2026-07-10
  tasks: 2
  files-created: 1
  files-modified: 0

status: complete
---

# Phase 81 Plan 03: Author brandbook/tokens/tokens.json (DTCG mirror) Summary

Hand-authored `brandbook/tokens/tokens.json` — the spec-valid DTCG 2025.10 mirror of `tokens.css` (81-01) with `$type` inheritance, `{color.primitive.*}` alias refs, and `{value,unit}` dimension/duration objects — kept diff-legible with no build tool (D-09), and all 15 primitive hexes byte-equal to the shipped SSOT.

## What was built

**Task 1 — Primitive + non-color scalar groups** (commit `d96e42e`)
- `color.primitive` (`$type: color`): the 15 primitives as verbatim lowercase hex strings copied from the shipped `chimeway_admin/priv/static/chimeway_admin.css`, plus `info` → `{color.primitive.blue}` alias (D-06).
- `space` (dimension, 4/8/16/24/32/48/64px), `type.family` (fontFamily arrays for sans/mono), `type.size` (dimension 14/16/20/28px), `type.lineHeight` (number), `type.weight` (fontWeight 400/600).
- `radius` (sm 5px verbatim — DIV-1 DEFERRED, md 8px, pill 999px), `border.width` (1px, DIV-7 DOCUMENTED), `shadow.panel` (decomposed shadow object, light-theme), `focus.ring`/`focus.offset`, `z` (sidebar 10, focus 50 — DIV-6), `motion.fast`/`motion.pressed` (duration, ease-out noted in `$description` — DIV-5).

**Task 2 — Semantic light/dark sibling groups** (commit `a2f9077`)
- `color.semantic.light` and `color.semantic.dark` (`$type: color`), no `system` node (D-11).
- 7 generalized names, 5 status triads (text/surface/border), and the control/surface/button/row/link layer per theme.
- Every value equal to a primitive hex is an alias ref (D-10): light `accent`→teal, `control-hover`/`row-bg`→porcelain, `button-primary-bg`→teal, `button-danger-bg`→danger, `status.neutral.border`→line; dark `fg`→paper, `accent`/`button-primary-bg`/`link-fg`→mint, `button-primary-fg`/`button-danger-fg`/`surface-bg`→night, `focus`→brass. Unique hexes (e.g. light `surface-panel` #ffffff, dark `surface-panel` #10232c, `fg-muted` #b8c5c9, `border` #29414a) held directly.

## Verification

All acceptance criteria passed:
- JSON parses (`JSON.parse`, exit 0).
- DTCG shape lint: zero bare-string dimension/duration values (every such `$value` is a `{value,unit}` object).
- Alias-resolution walk: zero unresolved `{a.b.c}` refs.
- `--cw-info` = `{color.primitive.blue}` (no hex literal).
- 15-primitive hex-equality: every `color.primitive.<name>.$value` byte-equal (lowercase) to `--cw-<name>` in the shipped CSS (15/15).
- Two sibling semantic groups present, no `system` node.
- Catch-all guard: no raw hex outside `color.primitive` equals a primitive hex (all such values are aliases).
- **Hard gate:** `git diff --exit-code` over both admin CSS files (priv/static SSOT + assets/css wrapper) → exit 0, zero drift.

## Deviations from Plan

None — plan executed exactly as written. No auto-fixes, no auth gates, no checkpoints, no architectural decisions required.

## Known Stubs

None. Every token carries a concrete `$value` (raw hex, alias ref, `{value,unit}` object, number, array, or decomposed shadow object). No placeholders, empty values, or TODO markers.

## Notes for downstream

- `tokens.json` is a **hand-synced** mirror: there is no build step (D-09). Any future edit to `tokens.css` must be mirrored here manually, and the primitive hex-equality + zero-drift guards re-run.
- The dark elevation shadow (`0 18px 50px rgb(0 0 0 / 0.35)`) is intentionally NOT in the JSON — D-11 splits only `color.semantic` into light/dark; elevation remains a CSS theming concern. A future DTCG consumer needing themed shadows would add a semantic shadow tier.
- Divergences (DIV-1 radius, DIV-5 motion easing, DIV-6 z-index, DIV-7 border-width) are DOCUMENTED in `$description` here and in `notes/decision-log.md` (81-02); live re-theme is deferred to ADMIN-RETHEME-01.

## Self-Check: PASSED

- `brandbook/tokens/tokens.json` — FOUND
- `81-03-SUMMARY.md` — FOUND
- Commit `d96e42e` (Task 1) — FOUND
- Commit `a2f9077` (Task 2) — FOUND
