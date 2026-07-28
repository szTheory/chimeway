# Phase 81: Design Tokens (Reconciliation & Documentation) - Pattern Map

**Mapped:** 2026-07-09
**Files analyzed:** 3 new files (greenfield `brandbook/` + `notes/` trees)
**Analogs found:** 3 / 3 (1 exact structural analog, 1 secondary `:root` analog, 2 decision-doc analogs; JSON DTCG shape has no repo analog — house indentation only)

## File Classification

| New File | Role | Data Flow | Closest Analog | Match Quality |
|----------|------|-----------|----------------|---------------|
| `brandbook/tokens/tokens.css` | config (design-token asset) | transform (SSOT → `:root` publication) | `chimeway_admin/priv/static/chimeway_admin.css` (token layer, lines 3-222) | exact (same token set, de-scoped) |
| `brandbook/tokens/tokens.json` | config (DTCG mirror) | transform (CSS ↔ JSON hand-sync) | none for DTCG shape → RESEARCH.md §DTCG; house JSON = `package.json` / `.mcp.json` (2-space) | partial (structure from spec, style from repo) |
| `notes/decision-log.md` | documentation (divergence ledger) | event-driven (per-divergence records) | `.planning/phases/77-…/77-PACKAGE-MODEL-DECISION.md` (primary) + `.planning/research/v1.12-quality-readiness/PG-SCHEMA-ISOLATION-DECISION.md` (header block) | role-match (house decision-doc format) |

---

## Pattern Assignments

### `brandbook/tokens/tokens.css` (config, transform)

**Primary analog:** `chimeway_admin/priv/static/chimeway_admin.css` — the authoritative SSOT. Copy its token *values* and *block structure* verbatim; strip only its scoping wrapper (`@layer cw.tokens` + `:where(.chimeway-admin…)` → bare `:root` / `[data-theme]` / `@media`, per D-01/D-02 and RESEARCH Pitfall 3).

**Secondary analog (the `:root` publication pattern, already in-repo):** `prompts/chimeway-brand-book.md:623-639` already ships the 15 primitives on a bare `:root { --cw-*: … }` block — this is the exact D-01 shape to mirror, but its hexes are UPPERCASE. Copy values from the shipped CSS (lowercase SSOT), NOT this block (RESEARCH Pitfall 1: case-only drift).

**Formatting conventions to carry over (from shipped CSS):**
- 2-space indentation; one token per line; `--cw-name: value;` (single space after colon).
- Lowercase hex throughout (`#07131a`, never `#07131A`).
- **Blank-line grouping, no section comments** — the shipped file separates families (primitives / scalars / status / alias / control) with a single blank line and zero comments (lines 19→21, 49→51, 65→67, 78→80). Adding light section comments is Claude's-discretion (CONTEXT D-50); if added, keep them terse — do not invent a heavier comment convention than the SSOT.
- Each theme block ends with a `color-scheme:` declaration (shipped lines 98, 128, 173, 219).

**In-`:root` ordering to replicate (shipped base block, lines 4-99):**
1. 15 primitives — VERBATIM (`chimeway_admin.css:5-19`, D-03).
2. Non-color scalars: spacing, font-family/size/line-height/weight, radius, shadow, focus-ring/offset, z-index, motion — VERBATIM (`:21-49`, D-08). Note `--cw-motion-*` stay CSS shorthands (`120ms ease-out`) verbatim; only the JSON decomposes them (DIV-5).
3. `--cw-status-*` triads (success/warning/danger/info/neutral) — VERBATIM (`:51-65`, D-05). Info triad is teal-hued — copy as-is (DIV-3, DEFERRED).
4. **Generalize the alias layer** (`:67-78`): emit the **7 D-04 names** (`--cw-surface-bg`, `--cw-surface-panel`, `--cw-fg`, `--cw-fg-muted`, `--cw-border`, `--cw-accent`, `--cw-focus`) pointing at the same primitives the `--cw-admin-*` aliases do; the 5 non-color `--cw-admin-*` rows (shadow/radius/radius-sm/transition/panel-soft) are already exposed under their primitive names — do NOT re-alias (RESEARCH Open Q1: expose only the 7). The `--cw-admin-*` names never appear in the brandbook.
5. Generic control/surface layer — VERBATIM (`:80-96`, D-05).
6. `color-scheme: light;`

**Theming block structure to mirror (4 blocks, de-scoped):**

| Shipped block (with `:where(.chimeway-admin…)`) | Lines | tokens.css mirror (bare) |
|---|---|---|
| base `:where(.chimeway-admin)` = light | 4-99 | `:root { … color-scheme: light }` |
| `:where(.chimeway-admin[data-cw-theme="light"])` | 101-129 | `[data-theme="light"] { … }` (explicit light override, D-02) |
| `:where(.chimeway-admin[data-cw-theme="dark"])` | 131-174 | `[data-theme="dark"] { … color-scheme: dark }` |
| `@media (prefers-color-scheme: dark) { …[data-cw-theme="system"] }` | 176-221 | `@media (prefers-color-scheme: dark) { :root { … } }` |

Dark generalized-semantic values are copied verbatim from the shipped dark admin block (`:132-139` → the 7 D-04 dark values in RESEARCH §5 table). Dark status triads and dark control/surface layer copy verbatim from `:141-172`. No `filter: invert()` anywhere (D-02, TOKEN-05).

**Excerpt — the alias layer to generalize (shipped `chimeway_admin.css:67-74`):**
```css
--cw-admin-bg: var(--cw-paper);      /* → --cw-surface-bg */
--cw-admin-panel: #ffffff;           /* → --cw-surface-panel */
--cw-admin-fg: var(--cw-ink);        /* → --cw-fg */
--cw-admin-muted: var(--cw-muted);   /* → --cw-fg-muted */
--cw-admin-border: var(--cw-line);   /* → --cw-border */
--cw-admin-accent: var(--cw-teal);   /* → --cw-accent */
--cw-admin-focus: var(--cw-focus-ring); /* → --cw-focus */
```
(Comments shown here for mapping only — do not copy the `--cw-admin-*` names into the brandbook.)

**Add exactly one net-new color token (D-06):** `--cw-info: var(--cw-blue);` — an alias of the existing blue primitive, never a new hex. Place with the primitives or as a documented semantic; log DIV-2 DOCUMENTED.

---

### `brandbook/tokens/tokens.json` (config, transform)

**Analog for DTCG shape:** none exists in the repo (grep confirms zero design-token JSON). Author against **RESEARCH.md → "DTCG Hand-Authoring Reference (verified against 2025.10)"** — that table is the authority for `$type`/`$value` shapes. Key gotchas already resolved there:
- `dimension` / `duration` `$value` = **object** `{ "value": 16, "unit": "px" }`, never a bare string (RESEARCH Pitfall 2).
- alias refs = `{ "$value": "{color.primitive.teal}" }` (D-10), never duplicated hex (RESEARCH Pitfall 4).
- `$type`/`$description` inherit from the closest parent group — set `$type` once per group.
- light/dark = two sibling groups `color.semantic.light.*` / `color.semantic.dark.*`; "system" has no JSON node (D-11).

**Analog for JSON house style:** `package.json` and `.mcp.json` — **2-space indentation**, double-quoted keys, no trailing commas. Match this exactly (the only repo-level JSON convention that applies; DTCG structure itself is spec-driven).

**Mirror the tokens.css value set:** the JSON is a hand-authored mirror of the CSS — every CSS token maps to a JSON token; semantic tokens use alias refs into `color.primitive.*`. Motion decomposes to a `duration` token + easing note in `$description` (DIV-5, RESEARCH Open Q2: emit `duration`, keep CSS shorthand, note `ease-out` in `$description` rather than hard-coding the `cubicBezier` assumption A1).

---

### `notes/decision-log.md` (documentation, event-driven)

**Primary analog:** `.planning/phases/77-truth-baseline-and-package-model-decision/77-PACKAGE-MODEL-DECISION.md`. This is the house "decision record" format and maps almost 1:1 onto a divergence ledger.

Conventions to carry over:
- **`## Sources` list** up front (analog lines 3-18) — bullet list of every file cited with a one-line role. Mirror with `chimeway_admin.css`, `chimeway-brand-book.md`, `81-CONTEXT.md`, `81-RESEARCH.md`, `.planning/REQUIREMENTS.md`.
- **A decision table with an explicit ID column** (analog lines 22-29: `| Decision | Rationale | Outcome | Decision IDs |`). Mirror for the ledger: `| # | Divergence | Shipped side | Brand-book / intent side | Disposition |` seeded directly from RESEARCH.md's DIV-1..DIV-7 table (which already carries both-side line refs).
- **Explicit disposition wording** — the house style states an outcome per row; here each row is `DOCUMENTED` or `DEFERRED` (D-12, TOKEN-04).
- **A closing `## Validation Commands` + `## Scope Guard`** (analog lines 105-121). Mirror with the zero-drift invariant, run per entry and once at close:
  ```bash
  git diff --exit-code chimeway_admin/priv/static/chimeway_admin.css
  ```
  Every divergence entry MUST close with this invariant (RESEARCH §Divergence Ledger).

**Secondary analog (lighter ADR header block):** `.planning/research/v1.12-quality-readiness/PG-SCHEMA-ISOLATION-DECISION.md:1-9` — the `# Title` + `**Date:** … **Decision status:** … **Scope:** …` metadata block, then `## Decision` prose. Use this header convention for the file's top matter (Date 2026-07-09, status "reconciliation phase — documented/deferred, not patched", scope "sub-primitive divergences from shipped `chimeway_admin.css`").

**Recommended minimal entry format** (hybrid of the two analogs), one per DIV-#:
```markdown
### DIV-N: <short title>  —  DOCUMENTED | DEFERRED

- **Shipped side:** <value> (`chimeway_admin.css:<line>`)
- **Brand-book / intent side:** <value> (`chimeway-brand-book.md:<line>`)
- **Disposition:** DOCUMENTED (added as alias, D-0X) | DEFERRED (patch = ADMIN-RETHEME-01)
- **Zero-drift invariant:** `git diff --exit-code chimeway_admin/priv/static/chimeway_admin.css` → exit 0
```

---

## Shared Patterns

### `--cw-*` prefix + lowercase-hex from the SSOT
**Source:** `chimeway_admin/priv/static/chimeway_admin.css:5-96`
**Apply to:** `tokens.css` and `tokens.json`
The distinct `--cw-` prefix is the sanctioned collision guard (D-01); values are copied lowercase from the shipped CSS, never from the uppercase brand-book block. Validate with case-insensitive hex-equality (RESEARCH Validation Architecture, TOKEN-01).

### Zero-drift proof
**Source:** RESEARCH §Divergence Ledger + `77-PACKAGE-MODEL-DECISION.md` §Scope Guard (lines 113-121)
**Apply to:** `decision-log.md` (every entry) and the phase gate
`git diff --exit-code chimeway_admin/priv/static/chimeway_admin.css` — the hard gate; `chimeway_admin.css` is document/defer-only, never edited (out-of-scope boundary, CONTEXT).

### Decision-ID + disposition table
**Source:** `77-PACKAGE-MODEL-DECISION.md:22-29` (Decision Summary table)
**Apply to:** `decision-log.md`
House convention: every recorded decision carries an explicit ID and a stated outcome; here IDs = DIV-1..DIV-7, outcomes = DOCUMENTED/DEFERRED.

---

## No Analog Found

| File | Aspect | Reason | Planner action |
|------|--------|--------|----------------|
| `brandbook/tokens/tokens.json` | DTCG `$type`/`$value` structure | No design-token JSON exists anywhere in the repo (grep: zero) | Use RESEARCH.md §DTCG Hand-Authoring Reference as the shape authority; adopt only 2-space indentation from `package.json`/`.mcp.json` |
| `brandbook/` + `notes/` trees | directory layout | Both are greenfield (`ls` confirms absent) | Create per RESEARCH §Recommended File Structure |

---

## Metadata

**Analog search scope:** `chimeway_admin/priv/static/`, `prompts/`, `.planning/` (phases + research), repo-root JSON configs.
**Files scanned:** `chimeway_admin.css` (1020 lines, token layer 3-222 read in full), `chimeway-brand-book.md:600-708`, `77-PACKAGE-MODEL-DECISION.md`, `PG-SCHEMA-ISOLATION-DECISION.md`, `.planning/config.json`, `package.json`, `.mcp.json`.
**Pattern extraction date:** 2026-07-09
