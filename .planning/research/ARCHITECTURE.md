# Architecture Research: v1.15 Brandbook Package

**Domain:** Repo-embedded brand/design-system package for an OSS Elixir/Phoenix library (no build step, no hosted site)
**Researched:** 2026-07-09
**Confidence:** HIGH (token inventory and scoping rules are read directly from the shipped `chimeway_admin.css`/`mix.exs` source; the one external claim — ExDoc's `:logo`/`:favicon` config — is verified against ExDoc's own docs, see Sources)

> Note: this file replaces the earlier (2026-04-30) `ARCHITECTURE.md`, which covered channel/
> feedback engine architecture from the v1.4 milestone. That content is superseded by shipped
> code (Phases 24-33+) and archived in git history; this file is scoped to the v1.15 Brand
> Identity & Brand Book milestone only.

## Standard Architecture

### System Overview

```
┌───────────────────────────────────────────────────────────────────────┐
│  brandbook/tokens/tokens.css   ← SINGLE reconciled --cw-* source       │
│  (primitives + new brand-wide semantic tier, :root-scoped, no resets)  │
└───────────────┬───────────────────────────────────┬────────────────────┘
                │ consumed by                       │ consumed by (later,
                │                                    │ separate milestone)
                ▼                                    ▼
┌───────────────────────────────┐   ┌───────────────────────────────────┐
│ brandbook/ (this milestone)   │   │ chimeway_admin/priv/static/        │
│ index.html + assets/brandbook │   │ chimeway_admin.css (UNTOUCHED      │
│ .css, examples/*.html         │   │ this milestone — re-theme is a     │
│ (own scoped chrome + .cwb-*   │   │ follow-on that will re-point its   │
│ demonstrative components)     │   │ existing --cw-admin-* aliases at   │
└───────────────┬───────────────┘   │ the reconciled tokens above)       │
                │                    └───────────────────────────────────┘
                │ referenced by (relative paths, file:// safe)
                ▼
┌───────────────────────────────────────────────────────────────────────┐
│ Repo root: README.md (header lockup), mix.exs docs() (logo/favicon)    │
│ — both MODIFIED, minimal, no brandbook code executes at runtime        │
└───────────────────────────────────────────────────────────────────────┘
```

Two independent CSS "root" scopes exist on purpose and must stay independent this milestone:
`.chimeway-admin` (shipped, real LiveView UI, untouched) and `.cw-brandbook` (new, static
showcase only). They share the same primitive `--cw-*` variable *names and values* by design
(that's the reconciliation), but nothing in `brandbook/` overwrites, imports, or executes
against `chimeway_admin/`.

### Component Responsibilities

| Component | Responsibility | Notes |
|-----------|-----------------|-------|
| `brandbook/tokens/tokens.css` | Canonical, copy-safe `--cw-*` custom properties (primitive + semantic tiers) | Only file in the package safe to reference from *outside* `brandbook/` or from a future host app / future admin re-theme |
| `brandbook/tokens/tokens.json` | Same token set as data, for programmatic consumption (no build step required to *read* it — it's a reference/export artifact, not compiled into tokens.css) | Hand-kept in sync with tokens.css; a tiny node/mix script MAY generate tokens.css from tokens.json later, but is not required this milestone |
| `brandbook/assets/brandbook.css` | Presentation-only chrome for the standalone book itself (nav, prose, code chrome, `.cwb-*` demonstrative components) | Scoped to `.cw-brandbook`; never meant to be copied into a host app |
| `brandbook/index.html` | Primary deliverable; renders logo directions, palette, type scale, tokens, components, do/don't | Static, `file://`-safe, no JS build step |
| `brandbook/examples/*.html` | Copy-pasteable snippets (components, landing section, README header) | Each snippet is self-contained: only depends on `tokens.css` + its own inline `<style>`, never on `brandbook.css` |
| `brandbook/assets/*.svg` | Final, chosen logo/favicon/social-card vector assets | Only *shipped* directions live here; rejected/candidate directions live in `notes/logo-options.md` |
| `brandbook/notes/*.md` | Research, decision log (incl. token-reconciliation decisions), accessibility checks, logo rationale | Living documents, updated throughout, not a single terminal step |
| `README.md` (repo root) | GitHub front door; MODIFIED to add header lockup | Uses a relative path into `brandbook/assets/`, resolved by GitHub natively |
| `mix.exs` `docs()` (repo root) | HexDocs sidebar logo + browser-tab favicon | MODIFIED with `:logo` / `:favicon` keys — the correct, minimal ExDoc integration point (not README image hacks) |
| `chimeway_admin/priv/static/chimeway_admin.css` | Shipped admin design system | **NOT modified this milestone** — reconciliation is one-directional (brandbook conforms to admin's already-shipped primitive values, not the reverse) |

## Recommended Project Structure

```
brandbook/
  README.md                       # NEW — how to use this package, token-reconciliation summary
  index.html                      # NEW — standalone HTML brandbook (primary deliverable)
  assets/
    brandbook.css                 # NEW — book-only chrome, scoped to .cw-brandbook (not copy-paste-safe)
    logo-primary.svg              # NEW — horizontal lockup, no tagline (primary, final direction)
    logo-primary-inverse.svg      # NEW — dark-background variant
    logo-mark.svg                 # NEW — icon-only
    logo-mark-mono.svg            # NEW — single-color icon-only (stickers/print)
    logo-typemark.svg             # NEW — integrated typemark direction (flourish worked into wordmark)
    logo-stacked.svg              # NEW — stacked lockup
    logo-with-tagline.svg         # NEW — optional secondary lockup, tagline underneath
    favicon.svg                   # NEW — simplified small-size mark, legible at 16px
    social-card.svg                # NEW — 1200×630 OG source
    social-card.png                # NEW, OPTIONAL — raster export ONLY because GitHub's repo
                                   #   social-preview upload and most OG consumers require a
                                   #   raster file; explicit, documented exception to vector-first
  tokens/
    tokens.json                   # NEW — primitive + semantic tokens as data
    tokens.css                    # NEW — the single reconciled --cw-* source (see below)
  examples/
    components.html               # NEW — .cwb-* component snippets, copy-paste marked
    landing-page-section.html     # NEW — example hero/feature section
    readme-header.md              # NEW — exact markdown used in README.md, kept in sync
  notes/
    research.md                   # NEW
    decision-log.md               # NEW — includes the token-reconciliation decision matrix below
    accessibility-checks.md       # NEW
    logo-options.md               # NEW — rationale per direction, ship/defer/reject; rejected
                                   #   candidate SVGs embedded inline as fenced <svg> markup,
                                   #   not committed as loose files (repo-size discipline)

README.md                         # MODIFIED — add header lockup (image + tagline), top of file only
mix.exs                           # MODIFIED — docs(): add `logo:`/`favicon:`; package(): OPTIONAL
                                   #   append "brandbook/assets" to files: so Hex.pm's package
                                   #   README preview also renders the header image

chimeway_admin/                   # NOT MODIFIED — zero files touched this milestone
```

### Structure Rationale

- **`tokens/` is the only cross-boundary artifact.** Everything else in `brandbook/` is
  presentational and self-contained; `tokens.css` is the one file designed to be imported by
  something outside the folder in the future (a landing page, or the deferred admin re-theme).
  Keeping that boundary to a single file makes the eventual re-theme milestone a one-file
  dependency change, not a search-and-replace across the package.
- **`assets/` holds only shipped, final vectors.** Candidate/rejected logo directions are
  recorded as inline SVG markup in `notes/logo-options.md` rather than as loose files, so the
  "show me options" requirement doesn't leave 10+ abandoned SVGs in the shipped tree (repo-size
  discipline, per PROJECT.md's "no build system, no bloat" constraint).
- **`examples/` is intentionally decoupled from `brandbook.css`.** A snippet copied out of
  `components.html` must work in a host app that has never heard of `brandbook.css` — it only
  needs `tokens.css` (or nothing at all, if the snippet inlines its own tiny `<style>`).

## Token Reconciliation

### What already exists (read directly from `chimeway_admin/priv/static/chimeway_admin.css`)

The shipped admin CSS already implements a real **primitive → semantic → component** three-tier
system, scoped under `:where(.chimeway-admin)` inside `@layer cw.tokens`, with light/dark/system
variants selected via `[data-cw-theme]` + `@media (prefers-color-scheme: dark)`. This is the
system the brandbook must conform to, not replace.

**Primitive tier (15 vars) — verified identical to brand-book §14, zero drift:**

| Token | Admin CSS value | Brand-book §14 value | Status |
|---|---|---|---|
| `--cw-ink` | `#102027` | `#102027` | agree |
| `--cw-night` | `#07131a` | `#07131A` | agree |
| `--cw-paper` | `#fffdf8` | `#FFFDF8` | agree |
| `--cw-porcelain` | `#f7f4ea` | `#F7F4EA` | agree |
| `--cw-line` | `#d8d3c7` | `#D8D3C7` | agree |
| `--cw-muted` | `#5e6b72` | `#5E6B72` | agree |
| `--cw-teal` | `#0e7c86` | `#0E7C86` | agree |
| `--cw-blue` | `#2d6cdf` | `#2D6CDF` | agree |
| `--cw-brass` | `#d6a84f` | `#D6A84F` | agree |
| `--cw-mint` | `#9adbcf` | `#9ADBCF` | agree |
| `--cw-violet` | `#6d5df6` | `#6D5DF6` | agree |
| `--cw-success` | `#0b7a50` | `#0B7A50` | agree |
| `--cw-warning` | `#8a5a00` | `#8A5A00` | agree |
| `--cw-danger` | `#b83232` | `#B83232` | agree |
| `--cw-code` | `#0b1720` | `#0B1720` | agree |

**Verdict:** the primitive palette needs zero changes. `brandbook/tokens/tokens.css` should copy
these 15 values byte-for-byte as its primitive tier — this is the easiest, highest-confidence
part of the reconciliation and should be locked first (see Build Order).

**Structural / naming conflicts (real drift, found by diffing scale + component usage):**

| Area | Admin CSS (shipped) | Brand-book §15/§16/§28 spec | Conflict |
|---|---|---|---|
| Spacing naming | T-shirt scale: `--cw-space-xs/sm/md/lg/xl/2xl/3xl` (4/8/16/24/32/48/64px) | Numeric scale: `--cw-space-1/2/3/4/6/8/12/16/24/32` (4/8/12/16/24/32/48/64/96/128px) | Different naming convention; admin also lacks a `12px` step and the two marketing-only steps (96px/128px) |
| Radius small | `--cw-radius-sm: 5px` | `--cw-radius-sm: 4px` | **Actual value drift** (5px shipped vs 4px specified) |
| Radius scale | Only `sm`/`md`/`pill` (2 sizes + pill) | `sm/md/lg/xl/2xl` (5 sizes) | Admin never needed `lg/xl/2xl` — fine as a subset, not a conflict |
| Shadow | Single `--cw-shadow-panel: 0 16px 42px rgb(16 32 39 / 0.08)` (rgb base = `--cw-ink`) | `--cw-shadow-sm`/`-md`/`-focus`, `--cw-shadow-sm` rgb base = `rgb(7 19 26 / …)` = `--cw-night` | Different rgb base color (ink vs night) and different scale granularity |
| Type scale | 4 semantic sizes: `label(14)/body(16)/heading(20)/display(28)` | 9-step numeric scale: `xs(12)…5xl(60)`, plus a 76px rare-display step | Admin's `display: 28px` doesn't land on any brand-book step (h4=24px, h3=32px) — a genuine gap, not just a naming difference |
| Font weights | `regular(400)`, `semibold(600)` only | `400/450-500/600/700` | Admin is a documented subset (fine); brand book's "500 Medium" has no admin equivalent yet |
| Line-height tokens | `--cw-line-height-label/body/heading/display` (admin invented these) | Prose ranges only (1.55–1.7 body, 1.05–1.2 headings), never tokenized | Brand book should adopt admin's *already-shipped* line-height token names rather than invent new ones |
| Focus ring | `--cw-focus-ring: var(--cw-blue)`, `--cw-focus-offset: 3px` (admin invented these) | Prose guidance only ("use visible focus states"), no token | Same — brand book should adopt, not reinvent |
| Motion duration | `--cw-motion-fast: 120ms ease-out`, `--cw-motion-pressed: 80ms ease-out` (admin invented) | Prose principles only (§20), no duration tokens | Same — adopt shipped values as canonical |
| Status "info" | `--cw-status-info-*` triad built from **teal** family (`#0e5f67`/`#e8f6f5`/`#94d4d7`) | "Enqueued" status prescribes **`--cw-blue`** (blue pill) | **Real conflict** — shipped "info" reads as teal, not blue |
| Status "sending" | No `.cw-status--sending` class and no violet status triad exists in component CSS | "Sending → `--cw-violet` → violet pill" | **Gap** — violet is used decoratively (timeline rail) but never wired as a status triad |
| Status "cancelled" | `.cw-status--cancelled` is mapped to the **danger** (red) triad | "Cancelled → `--cw-muted` → neutral outline" | **Real, currently-shipped conflict** — cancelled renders as red today, spec says neutral |
| Status "expired" | No `.cw-status--expired` class exists at all | "Expired → `--cw-warning` → warning outline" | **Gap** — never implemented |

### Reconciliation strategy (single source of truth without an admin rewrite)

1. **Primitive tier — copy verbatim, freeze.** `tokens/tokens.css` reproduces the 15 primitive
   `--cw-*` values exactly as shipped in `chimeway_admin.css`. No new primitive colors are
   invented this milestone. This is the actual "single conceptual source" claim: the *values*
   already agree; the brandbook's job is to formalize and document that agreement, not create a
   second palette.
2. **Semantic tier — new, generalized, non-conflicting names.** Admin's semantic tier is
   deliberately prefixed `--cw-admin-*` / component-specific (`--cw-button-primary-bg`,
   `--cw-row-bg`, …) and scoped to `.chimeway-admin`. The brandbook introduces a **parallel,
   product-wide** semantic tier with generalized names — `--cw-surface`, `--cw-surface-soft`,
   `--cw-fg`, `--cw-muted-fg`, `--cw-border`, `--cw-accent`, `--cw-focus`, `--cw-status-*`
   (fixing the info/sending/cancelled/expired gaps found above) — structurally parallel to, but
   never colliding with, `--cw-admin-*`. This lets a future admin re-theme alias
   `--cw-admin-panel: var(--cw-surface)` etc. with no visual regression, without this milestone
   touching a single line of `chimeway_admin.css`.
3. **Component tier — brandbook-local only.** `.cwb-*` demonstrative components in
   `examples/*.html` consume the semantic tier but are not meant to become admin's real
   component classes. Admin's real `.cw-button`, `.cw-card`, `.cw-status--*` etc. stay exactly
   as shipped.
4. **Record every conflict as a ship/defer decision, don't silently "fix" shipped code.** Each
   row in the conflict table above becomes a `notes/decision-log.md` entry, e.g.: *"Radius-sm:
   5px shipped vs 4px specified — defer: standardize on 4px in the re-theme milestone; do not
   patch chimeway_admin.css now (out of rollout boundary)."* This gives the re-theme milestone a
   ready-made punch list instead of a fresh audit.
5. **Future admin re-theme consumption path (documented, not built this milestone):** the
   re-theme milestone loads `brandbook/tokens/tokens.css` ahead of `chimeway_admin.css` in the
   admin layout, then replaces each `--cw-admin-*` / component-specific value with a `var(--cw-*)`
   reference to the new semantic tier — a mechanical aliasing pass, not a redesign, because the
   primitive values never moved.

## CSS-Scoping Architecture

**Goal:** the standalone book and its copy-pasteable snippets must never leak into the repo's
own admin UI, and a snippet copied into a host app must never leak into that host app's other
styles.

| Artifact | Root scope | Cascade layer(s) | Copy-paste safe? |
|---|---|---|---|
| `tokens/tokens.css` | `:root` (token declarations only — no element selectors, no resets) | `@layer cw.tokens` — **same layer name as `chimeway_admin.css`** on purpose | Yes — this is the one file explicitly designed to be imported elsewhere |
| `assets/brandbook.css` | `:where(.cw-brandbook)` / `:where(.cw-brandbook *)` — mirrors `chimeway_admin.css`'s own `:where(.chimeway-admin)` defensive pattern | Own namespace: `@layer cw.brandbook.reset, cw.brandbook.base, cw.brandbook.layout, cw.brandbook.components, cw.brandbook.utilities;` | No — book chrome only, never meant to be lifted out |
| `examples/*.html` snippets | `.cwb-*` prefixed classes (distinct from admin's real `.cw-*` classes) | **No `@layer` wrapper** in the copy-paste block itself | Yes — deliberately plain-specificity so it works whether or not the host app uses cascade layers |
| `index.html` itself | `.cw-brandbook` on `<body>` | consumes both `tokens.css` and `brandbook.css` | N/A — it's the book, not a snippet |

Rationale for each rule:

- **`tokens.css` reuses the literal layer name `cw.tokens`.** Per the CSS Cascade Layers spec,
  same-named `@layer` declarations *merge* rather than duplicate or conflict, in the order first
  encountered. If `tokens.css` and `chimeway_admin.css` were ever loaded on the same page (not a
  real scenario today, but a useful correctness property), their `cw.tokens` layers would merge
  additively — and since the primitive values are identical, the merge is a no-op. This is a
  concrete, verifiable proof that the two systems are the "same" token space, not two systems
  that happen to look similar.
- **`brandbook.css` gets its own layer namespace (`cw.brandbook.*`) and its own scoping class
  (`.cw-brandbook`)**, distinct from `.chimeway-admin` and from `cw.base/cw.layout/cw.components`
  used by admin. Even though these two stylesheets are never loaded together in practice
  (`brandbook/index.html` is static/`file://`; `chimeway_admin.css` is LiveView-mounted), the
  double isolation (different root class *and* different layer names) means an accidental
  co-load — e.g., someone pastes `brandbook.css` into a docs site that also loads the admin CSS —
  fails safe instead of producing surprising cascade interactions.
- **`.cwb-*` class prefix (not `.cw-*`) for every demonstrative component in `examples/`.**
  Admin's shipped classes (`.cw-button`, `.cw-card`, `.cw-status--*`, `.cw-row`, …) are real,
  behavior-bearing LiveView component classes. If brandbook examples reused those same names —
  even under a different `@layer` — a developer who has both `chimeway_admin.css` and a
  copy-pasted brandbook snippet loaded on one page would get cascade-layer-order-dependent,
  hard-to-debug results. A distinct `cwb-` prefix makes collision structurally impossible.
- **Example snippets skip `@layer` entirely.** Cascade layers are a repo-internal convention
  here (admin and the brandbook's own chrome both use them), but a copied snippet is landing in
  an *unknown* host app that may not use layers at all. Plain, moderate-specificity `.cwb-*`
  selectors behave predictably regardless of the host's own cascade-layer maturity — this is the
  actual mechanism that keeps "nothing leaks into a host app that copies a snippet" true.
- **`tokens.css` is the one file allowed to touch `:root`.** Because it contains *only* custom
  property declarations (no element selectors, no `box-sizing`, no `body` rules), attaching it to
  `:root` is additive-only and safe — this is the standard, well-understood pattern for
  distributing a design-token file (Tailwind, Radix, and most token systems ship exactly this
  way). All *behavioral* CSS (resets, layout, base typography) stays scoped to `.cw-brandbook`
  the same way `chimeway_admin.css` scopes to `.chimeway-admin`.

## Repo Integration Points

**GitHub README header.** `README.md` (MODIFIED, header only) adds an image + tagline block at
the very top, referencing `brandbook/assets/logo-primary.svg` via a **relative repo path**
(`![Chimeway](brandbook/assets/logo-primary.svg)`). GitHub's README renderer resolves relative
paths against the repo at the viewed ref natively — no absolute URL, no CDN, no extra config
needed. Keep this edit confined to the top of the file; do not restructure the rest of the
README (it was deliberately rewritten as an adopter decision page in v1.14, per PROJECT.md).

**HexDocs logo + favicon.** This repo's HexDocs `main` page is generated from the `Chimeway`
module's `@moduledoc` (`main: "Chimeway"` in `mix.exs` `docs()`), **not** from `README.md` —
`README.md` isn't even in the `extras:` list today. That means a README image edit alone does
**not** reach HexDocs. The correct, minimal-footprint integration point is ExDoc's own
`docs()` config keys:

```elixir
defp docs do
  [
    main: "Chimeway",
    logo: "brandbook/assets/favicon.svg",     # or a small square mark variant; SVG is supported
    favicon: "brandbook/assets/favicon.svg",  # SVG supported directly (needs width/height/viewBox)
    # ...existing extras/groups_extras unchanged
  ]
end
```

ExDoc accepts PNG, JPEG, or **SVG** for both `:logo` (shown ~48×48px in the sidebar) and
`:favicon` (browser tab icon); files are copied into the generated doc output's `assets/`
directory at `mix docs` time, read directly from the source tree — this does **not** require
`brandbook/` to be part of the published Hex package (`mix docs` runs against the working repo,
not the packaged tarball). This is a 2-line `mix.exs` change and the single correct HexDocs
integration point — no README hack, no separate doc-site build needed.

**Hex.pm package README preview (optional, small, recommended).** The Hex.pm package page also
renders `README.md`, but from the *packaged tarball*, which is controlled by `package() files:`
(currently `~w(lib priv guides CHANGELOG.md LICENSE.md README.md mix.exs .formatter.exs)` —
`brandbook/` is not included). Without a files: change, the header image in `README.md` would
404 specifically on Hex.pm's package page (GitHub and HexDocs are unaffected, per above). Fix
by appending only the assets directory, not the whole package:

```elixir
files: ~w(lib priv guides CHANGELOG.md LICENSE.md README.md mix.exs .formatter.exs) ++
  ~w(brandbook/assets)
```

This pulls in only the small, final SVG/PNG set (`assets/`), not `index.html`, `tokens/`,
`examples/`, or `notes/` — keeping the shipped Hex tarball's footprint growth to a handful of
vector files.

**GitHub repo social preview image.** GitHub's own repo-level "social preview" (Settings →
General → Social preview) is a manual dashboard upload, not something wired from code. Document
in `brandbook/README.md` that `assets/social-card.png` (the one justified raster export) is the
file to upload there — this is a one-time manual step, not a repo integration point.

**Summary of MODIFIED files outside `brandbook/`:** `README.md` (header block only) and
`mix.exs` (`docs()` logo/favicon keys; optional `package() files:` addition). Nothing else
outside `brandbook/` changes this milestone. `chimeway_admin/` is untouched.

## Asset Organization & `file://` Compatibility

Naming convention for the final, shipped set in `assets/` (matches the structure already agreed
in PROJECT.md / the pressure-test prompt):

`logo-primary.svg` · `logo-primary-inverse.svg` · `logo-mark.svg` · `logo-mark-mono.svg` ·
`logo-typemark.svg` · `logo-stacked.svg` · `logo-with-tagline.svg` · `favicon.svg` ·
`social-card.svg` (+ `social-card.png` raster export, the one deliberate vector-first exception).

Candidate/rejected directions from the logo-options exploration are **not** committed as loose
files in `assets/` — they live as inline `<svg>` markup inside `notes/logo-options.md` (fenced
code blocks, viewable by copy-paste into any browser or SVG viewer). This satisfies "show me
options" without leaving abandoned variant files in the shipped tree.

**`file://` correctness — this is a real, concrete constraint, not a formality:**

- All references inside `index.html` and `examples/*.html` must use **relative paths**
  (`assets/logo-primary.svg`, `tokens/tokens.css`, …), never a leading-slash root-relative path
  (`/brandbook/assets/…` resolves to the filesystem root under `file://`, not the repo root —
  it will 404 when the file is opened directly).
- Use plain `<img src="assets/logo-mark.svg">` or CSS `background-image: url(...)` /
  `<link rel="icon" href="assets/favicon.svg">` for every logo/favicon reference. These are
  ordinary resource loads and work under `file://` in every browser, Chrome included.
- **Do not** use `fetch()`-based SVG sprite loading or cross-file `<use href="sprite.svg#icon">`
  references anywhere in the brandbook. Chromium treats every `file://` path as its own unique
  origin, so both `fetch()` of a local file and `<use>` references into an *external* SVG file
  are blocked under `file://` in Chrome specifically (Firefox is more permissive, which makes
  this an easy trap to miss if only tested in one browser). Where a color-variant mark needs to
  react to light/dark mode via CSS (`currentColor` etc.), inline the `<svg>...</svg>` markup
  directly into `index.html`'s HTML source rather than referencing it as an external file with
  `<use>`.
- This constraint has zero cost here: nothing in the brandbook needs sprite-sheet reuse — each
  logo variant is already a distinct file, and `<img>`/`<link>` references cover every actual use
  case (display, favicon, OG source).

## Suggested Build Order / Dependency Sequence

1. **`tokens/tokens.json` + `tokens/tokens.css`** — lock the reconciled token vocabulary first;
   every downstream artifact (logo colors, HTML brandbook, examples) consumes it. Copy the 15
   primitive values verbatim from `chimeway_admin.css` (zero-risk); add the new generalized
   semantic tier; record every conflict found above as a `decision-log.md` entry inline as it's
   written, not deferred to a later step.
2. **Logo exploration → `notes/logo-options.md`** — 3–5 directions (per PROJECT.md's
   milestone-start decision), using the locked palette from step 1. Depends on step 1 for color;
   independent of the HTML shell.
3. **Direction selection (human checkpoint)** — promote the chosen direction(s) into `assets/`
   under the canonical names; write the corresponding ship/defer entries in `decision-log.md`.
4. **`assets/favicon.svg` + `assets/social-card.svg` (+ `.png`)** — small derivatives of the
   chosen mark; depends on step 3 being final so they aren't redone.
5. **`index.html` + `assets/brandbook.css`** — the primary deliverable; depends on steps 1–4
   (needs final tokens and final logos to actually show). Most labor-intensive artifact; build
   its component-showcase section before step 6 so the `.cwb-*` conventions are proven once, not
   invented twice.
6. **`examples/components.html`, `examples/landing-page-section.html`** — reuse the `.cwb-*`
   patterns drafted in step 5's showcase; depends on step 5 existing first.
7. **`examples/readme-header.md` + `README.md` header edit + `mix.exs` (`docs()` logo/favicon,
   optional `package() files:`)** — depends on step 3–4's final filenames; do this last among
   the integration edits so the header/config isn't revised mid-flight.
8. **`notes/research.md`, `notes/accessibility-checks.md`** — `accessibility-checks.md`
   specifically depends on step 5/6's *rendered* output (real contrast/focus states to audit);
   `research.md` can be drafted earlier in parallel since it captures ecosystem lessons, not
   final artifacts. `decision-log.md` is not a terminal step — it accumulates across steps
   1, 3, and throughout.

No build tooling (bundler, Tailwind/daisyUI, Node build step) is introduced. The repo already
has zero CSS/asset build tooling (`chimeway_admin.css` is hand-authored and served as a static
file via `ChimewayAdmin.Assets.css_path/0` / `inline_css/0`) — the brandbook follows the same
precedent: plain files, plain relative references, nothing to compile.

## Anti-Patterns to Avoid

### Anti-Pattern 1: Re-deriving the primitive palette instead of copying it

**What people do:** treat `brandbook/tokens/tokens.css` as a fresh design-token exercise and
recompute hex values "to match the brand book more precisely."
**Why it's wrong:** the shipped admin CSS and the brand-book §14 prose already agree on all 15
primitive values today. Recomputing them risks introducing a *second*, slightly different
palette — the exact fork this milestone exists to prevent.
**Instead:** copy the 15 values from `chimeway_admin.css` verbatim as the frozen primitive tier.

### Anti-Pattern 2: Reusing `.cw-*` class names in copy-paste examples

**What people do:** name brandbook example components `.cw-button`, `.cw-card` etc. to "match
the brand."
**Why it's wrong:** those class names already have real, shipped behavior in
`chimeway_admin.css`. A host app that has both loaded gets silent, layer-order-dependent
collisions.
**Instead:** prefix all brandbook-local demonstrative components `.cwb-*`.

### Anti-Pattern 3: Silently "fixing" shipped admin CSS conflicts during this milestone

**What people do:** notice `.cw-status--cancelled` renders red instead of neutral (per the
conflict table above) and patch `chimeway_admin.css` to match the brand-book spec while in this
milestone.
**Why it's wrong:** PROJECT.md explicitly defers the admin re-theme to a follow-on milestone;
a "small fix" here re-opens that scope boundary and risks an unreviewed visual regression in a
shipped, LiveView-mounted UI.
**Instead:** record the conflict in `decision-log.md` as a defer, ship the brandbook's own
(correct) semantic tier, and let the re-theme milestone consume it deliberately.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---|---|---|
| GitHub README rendering | Relative image path from repo root | No config needed; works immediately |
| HexDocs (ExDoc) | `docs()` `:logo` / `:favicon` keys, SVG supported | Verified against ExDoc's own documentation (see Sources) |
| Hex.pm package page | `package() files:` must include the referenced asset path | Optional; only affects Hex.pm's own README preview, not GitHub or HexDocs |
| GitHub repo social preview | Manual dashboard upload of `social-card.png` | Not a code integration point; documented as a manual step |

### Internal Boundaries

| Boundary | Communication | Notes |
|---|---|---|
| `brandbook/tokens/tokens.css` ↔ `chimeway_admin/priv/static/chimeway_admin.css` | Shared primitive `--cw-*` values only, by convention (no `@import`, no runtime link) | Reconciliation is documentation + identical values, not a code dependency this milestone |
| `brandbook/examples/*.html` ↔ any host app | Copy-paste only | No package, no import path — deliberately not npm/hex-installable this milestone |
| `brandbook/index.html` ↔ `brandbook/assets/brandbook.css`, `brandbook/tokens/tokens.css` | Plain relative `<link>` tags | `file://`-safe, no build step |

## Sources

- Direct repo read: `/Users/jon/projects/chimeway/chimeway_admin/priv/static/chimeway_admin.css` (full token/layer/component inventory)
- Direct repo read: `/Users/jon/projects/chimeway/mix.exs` (`package()`/`docs()` config)
- Direct repo read: `/Users/jon/projects/chimeway/chimeway_admin/lib/chimeway_admin/assets.ex` (how the admin CSS is served — no build step precedent)
- Direct repo read: `/Users/jon/projects/chimeway/README.md`, `/Users/jon/projects/chimeway/lib/chimeway.ex` (confirms HexDocs `main` renders from moduledoc, not README)
- Direct repo read: `/Users/jon/projects/chimeway/prompts/chimeway-brand-book.md` §14/15/16/28 (brand-book palette/spacing/type/radius spec)
- Direct repo read: `/Users/jon/projects/chimeway/.planning/PROJECT.md` (v1.15 rollout-boundary and taste constraints)
- [mix docs — ExDoc](https://hexdocs.pm/ex_doc/Mix.Tasks.Docs.html) — confirms `:logo`/`:favicon` accept PNG/JPEG/SVG and are copied into generated doc output
- CSS Cascade Layers behavior (same-named `@layer` declarations merge rather than duplicate) — used to justify reusing the `cw.tokens` layer name between `tokens.css` and `chimeway_admin.css`

---
*Architecture research for: Chimeway v1.15 Brand Identity & Brand Book — brandbook/ package integration*
*Researched: 2026-07-09*
