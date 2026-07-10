# Phase 81: Design Tokens (Reconciliation & Documentation) - Context

**Gathered:** 2026-07-09 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Establish a canonical, copy-safe `--cw-*` token layer (`brandbook/tokens/tokens.css` + `brandbook/tokens/tokens.json`) that is the single source of truth every downstream v1.15 artifact consumes — reconciled **verbatim** with the shipped `chimeway_admin/priv/static/chimeway_admin.css` primitives, with every sub-primitive divergence **recorded** in `notes/decision-log.md` as a deferred/documented decision rather than patched.

**In scope:** authoring `tokens.css`, `tokens.json`, and `notes/decision-log.md` under a new `brandbook/` tree; light/dark/system theming; contrast-checked dark values for net-new semantic tokens.

**Out of scope (hard boundary):** modifying `chimeway_admin.css` (document/defer only — the live admin re-theme is ADMIN-RETHEME-01, a separate follow-on milestone); any build tool/bundler; component-token tier; 12-step per-hue scales; bundled fonts. `brandbook/` and `notes/` are greenfield — they do not yet exist.
</domain>

<decisions>
## Implementation Decisions

### Distribution & Theming Mechanism (tokens.css)

- **D-01:** `tokens.css` publishes all `--cw-*` custom properties on **global `:root`** — NOT under a wrapper class or `@scope`. The distinct `--cw-` prefix is the collision guard (mature-precedent pattern: Shoelace `--sl-*`, Pico `--pico-*`, Open Props, Primer, GitLab all ship prefixed tokens on `:root`). `:root` is required for the file to be a true drop-in SSOT that any downstream artifact or adopter snippet can consume without wrapper markup. *(Research-backed, high confidence; this was the one public-model-defining lever — resolved by unanimous industry precedent.)*
- **D-02:** Theming = `@media (prefers-color-scheme: dark)` as the **system default**, plus an optional explicit `[data-theme="dark"]` / `[data-theme="light"]` attribute override on the root — both writing the same `--cw-*` names (one stable contract). Mirrors the shipped admin light/dark/system triple (`chimeway_admin.css:101/131/176`) minus the `.chimeway-admin` scope. No `filter: invert()` (TOKEN-05).

### Token Set & Naming (reconciliation)

- **D-03:** The **15 primitive colors are copied verbatim** from shipped `chimeway_admin.css` (zero drift): ink, night, paper, porcelain, line, muted, teal, blue, brass, mint, violet, success, warning, danger, code. This is the "no forked palette" SSOT invariant (TOKEN-01).
- **D-04:** Generalize the shipped **`--cw-admin-*` alias layer** (`chimeway_admin.css:67-78`) into **brand-neutral semantic names**: `--cw-surface-bg`, `--cw-surface-panel`, `--cw-fg`, `--cw-fg-muted`, `--cw-border`, `--cw-accent`, `--cw-focus`. The `--cw-admin-*` names stay only in the (untouched) admin CSS; the brandbook exposes the generalized names.
- **D-05:** **Copy already-brand-neutral semantic vars verbatim** (no rename): `--cw-status-*` triads (success/warning/danger/info/neutral), `--cw-control-*`, `--cw-surface-hover/active`, `--cw-border-strong`, `--cw-focus-halo`, `--cw-button-*`, `--cw-row-*`, `--cw-link-fg`, `--cw-table-row-hover`.
- **D-06:** Add **`--cw-info: var(--cw-blue)`** (#2d6cdf) — a net-new primitive **aliasing** the existing blue, NOT a new hex. Logged as DOCUMENTED in the decision log (brand book maps info→blue at `chimeway-brand-book.md:612`, but the shipped `--cw-status-info-*` triad is teal-hued at `chimeway_admin.css:60-62` — the conflict is recorded, not resolved this phase).
- **D-07:** Keep **`--cw-danger` / `--cw-status-danger-*` verbatim**. "error" (TOKEN-03 wording) is exposed as a **documented role that maps to `danger`**, not a rename — verbatim/zero-drift (TOKEN-01) outranks the loose "error" label.
- **D-08:** Token coverage (TOKEN-03, two-tier primitive→semantic only): color (primitive + generalized semantic + status incl. info), type scale, spacing, radius, border, shadow, motion, focus-ring, z-index. No component-token tier, no 12-step per-hue scales.

### tokens.json (DTCG) Structure

- **D-09:** `tokens.json` = hand-authored DTCG (`$value`/`$type`/`$description`), **no build tool**. Nested groups (`color.primitive.*`, `color.semantic.*`, `space.*`, `radius.*`, `type.*`, `border.*`, `shadow.*`, `motion.*`, `focus.*`, `z.*`).
- **D-10:** Semantic→primitive links use DTCG **alias references** (`{color.primitive.teal}`), never duplicated raw hex — keeps JSON and CSS diff-legibly in sync by hand.
- **D-11:** Light/dark represented as **two sibling semantic groups** (`color.semantic.light.*` / `color.semantic.dark.*`), each a plain spec-valid token aliasing the single primitive tier. "system" has **no JSON representation** — it is a CSS consumption strategy only. Explicitly NOT `$extensions` mode blobs, NOT mode-keyed `$value` objects, NOT a `$themes` manifest (all either spec-invalid or build-time). *(Research-backed against DTCG Format Module 2025.10.)*

### Divergence Logging (notes/decision-log.md)

- **D-12:** Record every named sub-primitive divergence from shipped admin CSS as **DOCUMENTED or DEFERRED** (TOKEN-04), and confirm `chimeway_admin.css` shows **zero changes** (`git diff` proof). Divergences to log:
  - `--cw-radius-sm` 5px (shipped) vs 4px (brand intent) — DEFERRED.
  - Missing `--cw-info` primitive — DOCUMENTED (added as alias per D-06).
  - Teal-hued shipped `--cw-status-info-*` triad vs blue brand intent — DEFERRED.
  - Status-pill mapping conflicts (brand book Sending→violet, Cancelled→muted-outline, Expired→warning-outline at `chimeway-brand-book.md:674/678/679` vs shipped danger/neutral grouping) — DOCUMENTED/DEFERRED.
  - Net-new motion + z-index tokens (values sourced verbatim from shipped where present) — DOCUMENTED.

### Claude's Discretion

- Exact file-internal ordering/comment style of `tokens.css` and `tokens.json`; precise `$description` wording; which net-new tokens (border tokens, any motion/z-index gaps) need fresh values vs verbatim copy — resolve during planning/execution against the shipped CSS, favoring verbatim copy and least-surprise defaults.
- Dark values for any net-new semantic token get an independently contrast-checked value (TOKEN-05); the contrast verification itself is finalized against the *rendered* output in Phase 86 (A11Y), but each new dark value must be authored with a checked ratio here.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `chimeway_admin/priv/static/chimeway_admin.css` — the authoritative shipped SSOT for `--cw-*` tokens (the `:root` block, light `[data-cw-theme]` block, dark `[data-cw-theme="dark"]` block). The 15 primitives and all semantic vars are copied verbatim from here. (`assets/css/chimeway_admin.css` merely `@import`s it — the packaged `priv/static` file is authoritative.)
- `prompts/chimeway-brand-book.md` — the written brand spec under pressure-test; token table + status-pill mapping at ~lines 600-680. Used to identify spec-vs-shipped divergences to log.
- `.planning/REQUIREMENTS.md` — TOKEN-01..05 (+ Out-of-Scope table). Authoritative requirement text.
- `.planning/ROADMAP.md` — Phase 81 success criteria and dependency notes.
- `.planning/phases/69-console-design-system/69-CONTEXT.md` — the phase that ORIGINALLY established the `--cw-*` tokens; explains why the divergences exist and what is locked.
- `prompts/brand-book-pressure-test.md` — v1.15 milestone handoff context and hard taste/deliverable constraints.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`chimeway_admin/priv/static/chimeway_admin.css`** is the complete, shipped, production token set — 15 primitives, spacing (xs..3xl), type scale, radius (sm 5px / md 8px / pill), shadow, focus-ring/offset, z-index (sidebar 10 / focus 50), motion (fast 120ms / pressed 80ms), full `--cw-status-*` triads for success/warning/danger/info/neutral, and a light/dark/system theme implementation via `@media (prefers-color-scheme)` + `[data-cw-theme]`. Phase 81 copies from it; it is not modified.

### Established Patterns

- Shipped CSS already models a clean **two-layer split**: brand-neutral generic vars (`chimeway_admin.css:51-64`, `:80-96`) + an admin-scoped `--cw-admin-*` alias layer (`:67-78`) that only re-points to primitives. Phase 81's "generalized semantic tier" is a mechanical de-scoping of that alias layer — not a new design.
- Shipped theming uses `@layer cw.tokens` + `:where(.chimeway-admin[data-cw-theme="light|dark"])` + `@media (prefers-color-scheme: dark)`. The brandbook mirrors this minus the `.chimeway-admin` scope.

### Integration Points

- **Downstream (this milestone):** Phase 84 (HTML brandbook) consumes `tokens.css` on `:root` + its own scoped `.cwb-*` demo CSS (BOOK-02). Phase 85 (README/HexDocs) consumes final asset filenames, not tokens directly. The token names locked here are a cross-phase contract — renaming after Phase 84 consumes them is a break.
- **Deferred (future milestone):** ADMIN-RETHEME-01 will make `chimeway_admin` consume `tokens.css` and resolve the deferred sub-primitive conflicts live. Phase 81 only documents them.
</code_context>

<specifics>
## Specific Ideas

- DTCG light/dark convention (D-11) validated against **DTCG Format Module 2025.10** (first stable version, 2025-10-28): `$extensions` "SHOULD" hold only data not crucial to a token's value (so mode blobs are out); mode-keyed `$value` is spec-invalid; the Resolver Module is build-time. Sibling `light`/`dark` groups are the only hand-authorable, spec-valid, diff-legible option.
- `:root` distribution (D-01) validated against Shoelace, Pico, Open Props, GitHub Primer, GitLab Pajamas — all ship prefixed tokens on `:root`; the prefix, not scoping, is the sanctioned collision guard.
</specifics>

<deferred>
## Deferred Ideas

- **Patching the sub-primitive conflicts live** (radius-sm 4px, blue info triad, status-pill remapping) — belongs to ADMIN-RETHEME-01 (future milestone). This phase documents/defers only.
- **DTCG Resolver Module adoption** — sibling groups migrate cleanly into resolver `sets` later if a build step is ever introduced; note in a `$description`, do not build now.
- **Bundled webfont** (BRAND-WEBFONT-01) — out of milestone; system stack + documented recommendation only.

### Reviewed Todos (not folded)

None — no pending todos matched Phase 81 scope.
</deferred>
