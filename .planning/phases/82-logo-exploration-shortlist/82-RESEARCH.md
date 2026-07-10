# Phase 82: Logo Exploration & Shortlist - Research

**Researched:** 2026-07-10
**Domain:** Brand identity / logo exploration — hand-authored inline SVG in a Markdown decision doc (doc/asset-only, no runtime code)
**Confidence:** HIGH (technique + landmines verified against primary sources; precedent claims cited or tagged ASSUMED)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Phase 82 produces exactly **one committed artifact — `notes/logo-options.md`.** All shortlisted directions *and* rejected candidates are embedded as inline `<svg>` inside that markdown. No standalone `brandbook/logo/*.svg` file family is created this phase (that is Phase 83, finalist-only). Repo-size discipline is the reason rejected candidates stay inline.
- **D-02:** `notes/logo-options.md` is a **vetted shortlist, not a raw gallery**: every direction carries rationale, pros/cons, and an explicit ship / defer / reject recommendation with a confidence level.
- **D-03:** Fully work **5 distinct directions** (top of the 3–5 range) to give a genuine choice.
- **D-04:** **At least 2 of the 5 are integrated typemarks** — a custom motif/flourish worked *into* the lowercase `chimeway` letterforms (e.g. the `w` rendered as a routed path, a ligature carrying a signal arc), not a mark placed beside a plain font. (Spec requires ≥1 per LOGO-02; authoring 2 de-risks the eventual pick.)
- **D-05:** Each direction uses **≤2 visual ideas** and routes the "chime" concept through the **path / route / signal-arc / waypoint / trace-timeline / `cw`-monogram-as-path** metaphor set. Abstract gentle rings/arcs are allowed as "signal." **Zero literal bell, clapper, musical note, staff line, or audio/sound-effect imagery** (LOGO-06).
- **D-06:** No rectangular/enclosing background cage; transparent/background-free marks by default.
- **D-07:** Mark and wordmark read as **one unified unit** — not icon-left / text-right with a visible gap. Logotype sits appropriately close to the logomark.
- **D-08:** The **primary lockup carries no subtitle/slogan.** An optional separate tagline lockup may be shown only if it genuinely adds value — never as the primary.
- **D-09:** Programmatic SVGs must be **thoughtful and brand-based, not clipart**; unique brand-derived imagery/type.
- **D-10:** Non-typemark directions render the wordmark as `<text>` in the tokens' **Inter** stack (fast, editable during exploration); integrated-typemark directions hand-draw the flourished glyph(s) as `<path>`. **Full wordmark-to-outline vector conversion is deferred to Phase 83's finalist.**
- **D-11:** Marks drawn in `--cw-ink` (#102027) as primary with `--cw-teal` (#0e7c86) as the single accent. Mono = one-color ink. Inverse = `--cw-paper` (#fffdf8) on `--cw-night` (#07131a). **No gradients, drop shadows, stretch, or skew inside the mark.** Colors sourced only from the reconciled `--cw-*` token layer (`brandbook/tokens/tokens.css`).
- **D-12:** Each shortlisted direction embeds an inline **proof strip** in the doc demonstrating: the mark at **16px**, in **single-color mono**, and **inverse (dark)** — plus a captured **clear-space and minimum-size** intent (clear-space = height of the lowercase `c`; logomark 16px min / 24px preferred; full horizontal lockup 120px wide min).
- **D-13:** Generate an **ephemeral `file://`-safe HTML gallery in the session scratchpad** (NOT committed) so the user can eyeball all directions + proof strips at real scale during review. The committed artifact remains the markdown; the real scoped brandbook HTML is Phase 84. Preview background/ink use the `--cw-*` tokens.

### Claude's Discretion
- The specific concepts, geometry, and which candidates ultimately land as ship vs. defer vs. reject are Claude's creative call within D-03..D-12 — the human's taste sign-off is Phase 83.
- Light external research (OSS devtool logo precedents; integrated-typemark construction) may be gathered by the researcher to back rationale with citations; it is non-blocking.

### Deferred Ideas (OUT OF SCOPE)
- Finalist selection + full optimized-SVG lockup family (primary horizontal, icon-only, wordmark, stacked, mono, inverse), simplified favicon mark, and social/OpenGraph derivatives — **Phase 83 (LOGO-03/04, INTEG-03)**.
- Do/don't usage grid, clear-space diagram, and minimum-size grid as *rendered brandbook HTML* — intent is captured here; the visual grid lands in **Phase 84** (BOOK-*).
- Bundled webfont / full wordmark-to-outline conversion — Phase 83 finalist only.
- `notes/research.md` formal citations doc — **Phase 86 (NOTES-04)** (light research here is inline rationale only).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| LOGO-01 | Present 3–5 distinct, fully-worked directions, each with rationale/pros/cons/ship-defer-reject + confidence (vetted shortlist, not a raw gallery) | Doc structure pattern (§Architecture Patterns), copy vocabulary already locked in UI-SPEC; D-03 sets N=5 |
| LOGO-02 | ≥1 fully-integrated typemark (motif worked *into* the wordmark) | Integrated-typemark construction technique (§Code Examples, §Pattern 2); D-04 requires ≥2 |
| LOGO-05 | No rectangular cage; mark+wordmark one unit; primary lockup no subtitle | Taste gates locked in CONTEXT/UI-SPEC; automatable cage-guard noted in §Validation Architecture |
| LOGO-06 | No literal music/bell/note/staff; express "chime" via path/route/signal/trace | Metaphor set locked (D-05); precedents that survive at 16px (§State of the Art) back the routed-path rationale |
| NOTES-02 | `notes/logo-options.md` documents ALL explored directions (incl. rejected, inline SVG for repo-size discipline) with rationale | Repo-size + inline-SVG discipline (§Common Pitfalls); recommendation vocabulary locked in UI-SPEC |
</phase_requirements>

## Summary

Everything creative and normative for this phase is already locked in `82-CONTEXT.md` and the approved `82-UI-SPEC.md` — the metaphor set, the taste gates, the color/type tokens, the recommendation vocabulary (`Ship`/`Defer`/`Reject` + `Confidence: High/Medium/Low`), and the proof-strip label set (`16px` · `Mono` · `Inverse` · `Clear-space` · `Min-size`). This research does **not** re-derive any of that. Its job is to de-risk the *authoring* of `notes/logo-options.md` so the plan doesn't trip on the three things that reliably break inline-SVG-in-Markdown deliverables: **(1) GitHub silently strips inline `<svg>` from rendered Markdown**, **(2) `var(--cw-*)` does not resolve inside a standalone/committed SVG**, and **(3) cross-`<svg>` `<use href="#id">` fails** — you must keep each proof strip self-contained in one `<svg>` root.

The single most important finding: **GitHub's Markdown pipeline sanitizes and removes `<svg>` elements** — inline SVG will render as nothing on github.com [VERIFIED: github/markup sanitization behavior, alexwlchan.net/notes/2024]. This is *already accounted for* by the design (D-01 makes the markdown the source-of-record; D-13 gives an ephemeral `file://` HTML gallery as the real-scale eyeball surface), so it requires **no scope change** — but the planner must state it explicitly so no task wastes effort trying to make the `.md` "look right on GitHub," and so verification eyeballs the marks in the HTML gallery / a raw-HTML-permitting local previewer, not on github.com.

**Primary recommendation:** Plan the artifact as *self-contained hex-value inline SVG* (literal token hex + a comment annotating the token name), one `<svg>` root per proof strip using a single `<symbol>` + three `<use>` at the 16px/mono/inverse variants, wordmark as `<text font-family="Inter,…">` for non-typemark directions and hand-drawn monoline `<path>` (`stroke-linecap="round"`, single `stroke-width`) for the ≥2 integrated typemarks. Render the ephemeral gallery by wrapping the same SVG blocks in one `file://`-openable HTML page that links `brandbook/tokens/tokens.css`.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Logo direction authoring (marks + wordmarks) | Static / Markdown doc | — | Committed artifact is `notes/logo-options.md`; hand-authored inline SVG, no runtime |
| Per-direction proof strip (16px/mono/inverse/clear-space/min-size) | Static / inline SVG | — | Self-contained `<svg>` per strip; no external asset, no build |
| Real-scale preview | Ephemeral `file://` HTML (scratchpad, uncommitted) | Static / inline SVG | D-13 — browser renders inline SVG the committed `.md` cannot show on GitHub |
| Color/type sourcing | Token layer (`brandbook/tokens/tokens.css`) | — | Values (not `var()`) copied from the reconciled `--cw-*` SSOT into SVG attributes |

All capabilities live in the doc/static tier. There is **no browser-client, server, API, or database tier** in this phase — no runtime code is touched (confirmed: milestone is doc/asset-only, `chimeway_admin` untouched).

## Standard Stack

**No packages are installed or added in this phase.** The deliverable is hand-authored Markdown + inline SVG + one ephemeral HTML file. There is no build system, no bundler, no font binary, no npm/hex dependency (explicitly out-of-scope per REQUIREMENTS "Out of Scope" table and the pressure-test non-negotiables).

### Core (authoring surface, not dependencies)
| Surface | "Version" | Purpose | Why Standard |
|---------|-----------|---------|--------------|
| Inline SVG 1.1 / 2 (`<path>`, `<text>`, `<symbol>`, `<use>`, `<g>`, `<rect>`) | native | Draw marks + proof strips | Universally rendered by browsers and raw-HTML markdown previewers; zero deps |
| Markdown (GFM) | native | Decision-doc container for directions + rationale | The committed artifact format (D-01); consumed by Phase 83/84 |
| `--cw-*` token values (`brandbook/tokens/tokens.css`) | Phase 81 | Only legal colors/typefaces | Cross-phase contract (D-11); do not invent values |

### Supporting (optional, local only — verify availability, do not require)
| Tool | Purpose | When to Use |
|------|---------|-------------|
| Any Chromium/Firefox/Safari | Open the ephemeral `file://` gallery (D-13) | Human review at real scale |
| `xmllint` (libxml2) | Optional SVG well-formedness check | Automatable guard in Validation Architecture (skip if absent) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Hand-authored inline `<path>` | A logo-generator / icon library | Rejected by D-09 (must be brand-derived, not clipart) and out-of-scope (no deps) |
| `<text font-family="Inter">` for wordmark | Full glyph→outline conversion now | Deferred to Phase 83 (D-10); outlining every wordmark now is wasted work before the finalist pick |
| `var(--cw-ink)` in SVG fills | Literal token hex + comment | `var()` does not resolve in standalone/committed SVG (see Pitfall 2); literal hex is portable and still token-sourced |

## Package Legitimacy Audit

**Not applicable — this phase installs zero external packages.** No npm/PyPI/crates/hex dependency is added; the deliverable is Markdown + inline SVG + one uncommitted HTML preview file. No legitimacy gate needed.

- Packages removed due to [SLOP] verdict: none
- Packages flagged as suspicious [SUS]: none

## Architecture Patterns

### System Architecture Diagram

```
                      brandbook/tokens/tokens.css  (Phase 81 SSOT: --cw-* values)
                                   │  (values copied, NOT var())
                                   ▼
   ┌─────────────────────────────────────────────────────────────────┐
   │  notes/logo-options.md   (THE committed artifact — D-01)         │
   │                                                                   │
   │  ## Shortlist                                                     │
   │   Direction 1 … 5   ─ each:                                       │
   │     • inline <svg> lockup (mark + wordmark, one unit)            │
   │     • Concept / Pros / Cons / Recommendation                     │
   │     • Verdict: Ship|Defer|Reject  + Confidence: High|Med|Low     │
   │     • proof strip  ─►  one <svg> root:                            │
   │            <defs><symbol id=markN>…</symbol></defs>              │
   │            <use> 16px │ <use> mono(ink) │ <rect night>+<use> inv │
   │            + clear-space / min-size annotation                    │
   │                                                                   │
   │  ## Rejected (inline SVG kept — NOTES-02 repo-size discipline)   │
   └───────────────┬───────────────────────────────────────────────┬─┘
                   │                                                 │
     consumed by Phase 83 (finalist → lockup family)     wrapped for review by
                   │                                                 ▼
                   │                          scratchpad/gallery.html  (D-13, EPHEMERAL,
                   │                          file://-openable, links tokens.css,        )
                   ▼                          inline SVG renders at real scale — NOT committed
        GitHub web UI renders the prose;
        inline <svg> is STRIPPED by GitHub's sanitizer (expected — not a bug)
```

### Recommended Doc Structure (`notes/logo-options.md`)
```
# Chimeway Logo Options — Exploration & Shortlist
  Intro: metaphor thesis (calm infrastructure / routed paths), gate legend,
         note that inline SVG renders in the file:// gallery / raw-HTML preview,
         not on github.com.
## Shortlist (5 directions, D-03)
  ### Direction N — <name>
    <inline svg primary lockup>
    Concept:  (≤2 visual ideas + metaphor — D-05)
    Pros:  · Cons:  · Recommendation:
    Verdict: Ship|Defer|Reject   Confidence: High|Medium|Low
    Proof strip: [16px] [Mono] [Inverse] [Clear-space] [Min-size]  (D-12)
## Rejected candidates (inline SVG retained — NOTES-02)
  ### <name> — reason it failed a gate (cage / bell-literal / dies at 16px / …)
```

### Pattern 1: Self-contained proof strip (one `<svg>` root, `<symbol>` defined once)
**What:** Define the mark once as a `<symbol>`; render 16px, mono, and inverse variants via `<use>` inside the *same* `<svg>` document.
**When to use:** Every shortlisted direction's proof strip (D-12).
**Why:** Same-document `<use href="#id">` renders reliably everywhere, including under `file://`; cross-file / cross-`<svg>` `<use>` does **not** (see Pitfall 3). Defining once avoids triplicating path data (repo-size discipline, NOTES-02).

### Pattern 2: Integrated typemark — monoline glyph as a routed `<path>`
**What:** Hand-draw the flourished letterform(s) as a single continuous monoline `<path>` (`fill="none"`, one `stroke-width`, `stroke-linecap="round"`, `stroke-linejoin="round"`) so a letter *becomes* a route/waypoint/signal-arc; set the rest of `chimeway` as `<text>` on the same baseline and x-height so the unit reads as one word (D-04, D-07, D-10). The `w` as a zig-zag route with waypoint vertices, or the `c` opening as a route entry, are the strongest seeds (brand-book §13).
**When to use:** The ≥2 integrated-typemark directions (D-04 / LOGO-02).

### Anti-Patterns to Avoid
- **`var(--cw-*)` in committed SVG fills** — won't resolve outside a token-linked HTML context; renders black/transparent. Use literal token hex + a `<!-- --cw-ink -->` comment.
- **Cross-`<svg>` `<use href="#markN">`** — a `<use>` in one inline `<svg>` block referencing a `<symbol>` defined in a *different* `<svg>` block fails. Keep each strip's symbol + uses in one root.
- **Assuming the `.md` renders on GitHub** — it will not (SVG stripped). Eyeball in the gallery.
- **Full-bleed `<rect>` behind the mark** — reads as the forbidden background cage (D-06 / LOGO-05). The only legal background rect is the *inverse proof cell* (`--cw-night`), scoped to that one variant.
- **Sub-pixel strokes** — a mono monoline that is fine at 24px can vanish at 16px; verify the 16px variant actually holds (Pitfall 4).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Wordmark for non-typemark directions | Hand-drawn outlines of every glyph | `<text font-family="var stack: Inter,…">` (D-10) | Outlining is Phase-83 finalist work; premature here |
| Color values | New/eyeballed hexes | Literal values copied from `brandbook/tokens/tokens.css` | D-11 — token layer is the cross-phase SSOT; inventing values breaks Phase 83/84 |
| Proof-variant duplication | Three full copies of every path | One `<symbol>` + three `<use>` | Less path data (repo size), single source of truth per mark |
| Preview harness | A committed HTML page / a static server / a build step | One ephemeral `file://` HTML file in scratchpad (D-13) | Committed HTML brandbook is Phase 84; no build system allowed |

**Key insight:** Almost every "tool" you'd reach for here (icon set, logo generator, font bundler, bundler/preview server) is explicitly forbidden by the milestone's non-negotiables or deferred to a later phase. The correct move is *less* machinery, not more: plain SVG primitives + token hex values + one throwaway HTML wrapper.

## Common Pitfalls

### Pitfall 1: GitHub strips inline `<svg>` from rendered Markdown
**What goes wrong:** The committed `notes/logo-options.md` shows prose but *no marks* on github.com — the SVGs are silently removed.
**Why it happens:** GitHub's Markdown pipeline (`github/markup`) runs an HTML sanitizer that removes elements it deems unsafe/unsupported, including `<svg>`. SVG only displays on GitHub via an `<img>` tag pointing to a *separate, committed* `.svg` file [VERIFIED: alexwlchan.net/notes/2024/how-to-render-svgs-on-github; github/markup issues].
**How to avoid:** Accept it — it's by design (D-01 makes the `.md` the source-of-record, not a GitHub render target). Put a one-line note at the top of the doc ("inline marks render in the `file://` gallery / a raw-HTML-permitting Markdown preview, not on github.com"). Do the human eyeball in the D-13 gallery. Separate committed `.svg` files that GitHub *can* render are Phase 83's job.
**Warning signs:** A task acceptance criterion phrased as "renders on GitHub" — reword to "renders in the ephemeral gallery / VS Code Markdown preview."

### Pitfall 2: `var(--cw-*)` does not resolve inside standalone SVG
**What goes wrong:** `fill="var(--cw-ink)"` renders black or nothing when the SVG isn't inside an HTML document that both defines the custom properties and hosts the SVG inline.
**Why it happens:** CSS custom properties resolve against the DOM the element lives in. A committed inline SVG in a `.md`, or a `.svg` opened directly, has no `:root { --cw-ink }` in scope.
**How to avoid:** In the **committed** inline SVG, use the literal token hex (`#102027`, `#0e7c86`, `#fffdf8`, `#07131a`) and annotate with a comment (`<!-- --cw-ink -->`) so it's auditable and portable. `var()` is acceptable *only* inside the ephemeral gallery where `tokens.css` is linked and the SVG is inline — but even there, literal hex is simpler and avoids divergence.
**Warning signs:** Marks that look correct in the gallery but black elsewhere.

### Pitfall 3: Cross-`<svg>` / cross-file `<use>` fails (especially under `file://`)
**What goes wrong:** A `<use href="#markN">` renders empty because the referenced `<symbol>` lives in a different `<svg>` element or a different file.
**Why it happens:** `<use>` resolves the fragment within its own SVG document; cross-file `<use href="sprite.svg#id">` is additionally blocked by same-origin policy under `file://` in Chromium [VERIFIED: Chrome for Developers "Migrate away from data URLs in SVG use"; MDN same-origin note].
**How to avoid:** Keep each proof strip's `<symbol>` and all its `<use>` instances inside one `<svg>` root. Do not build a shared sprite sheet. (This also keeps BOOK-01's future `file://`-safe rule satisfied by construction.)
**Warning signs:** Empty 16px/mono/inverse cells in the gallery while the master lockup shows fine.

### Pitfall 4: Monoline dies at 16px / in mono
**What goes wrong:** A direction that looks refined at display size becomes an illegible smudge at 16px or a filled blob in one-color mono — it should then be moved to Rejected with the reason recorded (per UI-SPEC error-state rule), not shipped.
**Why it happens:** Thin strokes fall below one device pixel; tight counters close up; two-color separation that carried the concept collapses when mono flattens it to one ink.
**How to avoid:** Author the 16px and mono variants *first* as the gate, not last. Keep counters open, stroke weight generous relative to mark height, and ensure the concept survives without the teal accent (mono = ink only, D-11). Precedent marks that survive at favicon size (below) are monoline with wide apertures.
**Warning signs:** You can't tell the mark from a generic squiggle at 16px.

### Pitfall 5: Repo bloat / clipart drift
**What goes wrong:** 5 directions + rejected × proof strips balloons the `.md`, or paths look generic.
**Why it happens:** Base64-embedded rasters, `<image>` data-URIs, machine-exported over-noded paths, or reused stock geometry.
**How to avoid:** Text-only inline SVG, hand-authored concise `<path>` data, no `<image>`/data-URIs, no binary. Rejected candidates stay inline (NOTES-02) but keep their SVG minimal. Each mark must be brand-derived (D-09).
**Warning signs:** `git diff --stat` shows a large `notes/logo-options.md`; any base64 blob; any file outside `notes/` touched.

## Code Examples

> Illustrative technique only — geometry is Claude's creative call (D-05 discretion). Hex values are the literal token values from `brandbook/tokens/tokens.css`.

### Self-contained proof strip (Pattern 1)
```svg
<!-- one <svg> root: symbol defined once, three legibility variants via <use> -->
<svg xmlns="http://www.w3.org/2000/svg" width="320" height="72" viewBox="0 0 320 72" role="img" aria-label="Direction N — legibility proof">
  <defs>
    <!-- the mark, authored once. fill/stroke set on <use>, not here -->
    <symbol id="markN" viewBox="0 0 24 24">
      <path d="M4 14 C 8 14, 9 8, 13 8 L 20 8"
            fill="none" stroke="currentColor" stroke-width="2"
            stroke-linecap="round" stroke-linejoin="round"/>
      <circle cx="20" cy="8" r="1.6" fill="currentColor"/> <!-- waypoint -->
    </symbol>
  </defs>

  <!-- 16px variant (min favicon size, D-12) -->
  <use href="#markN" x="8"  y="28" width="16" height="16" color="#102027"/> <!-- --cw-ink -->

  <!-- mono variant, one-color ink (D-11) -->
  <use href="#markN" x="40" y="24" width="24" height="24" color="#102027"/> <!-- --cw-ink -->

  <!-- inverse cell: the ONLY legal background rect (scoped to this variant, not a cage) -->
  <rect x="80" y="16" width="40" height="40" rx="6" fill="#07131a"/>       <!-- --cw-night -->
  <use href="#markN" x="88" y="24" width="24" height="24" color="#fffdf8"/> <!-- --cw-paper -->
</svg>
```
Notes: `color=` + `stroke/fill="currentColor"` lets one `<symbol>` recolor per `<use>` without duplicating paths. `href` (not the deprecated `xlink:href`) is correct for modern renderers.

### Integrated typemark — routed glyph + `<text>` wordmark (Pattern 2)
```svg
<svg xmlns="http://www.w3.org/2000/svg" width="240" height="48" viewBox="0 0 240 48" role="img" aria-label="chimeway — integrated typemark (w as routed path)">
  <!-- 'chime' + 'ay' as Inter text; the 'w' is hand-drawn as a routed path between them -->
  <text x="8" y="32" font-family="Inter, ui-sans-serif, system-ui, sans-serif"
        font-size="28" font-weight="600" fill="#102027" letter-spacing="0.5">chime</text>
  <!-- 'w' rendered as a zig-zag route with waypoint vertices (the motif worked INTO the letter) -->
  <path d="M104 18 L110 34 L116 22 L122 34 L128 18"
        fill="none" stroke="#102027" stroke-width="3"
        stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="128" cy="18" r="2.4" fill="#0e7c86"/> <!-- single teal accent = signal endpoint, D-11 -->
  <text x="134" y="32" font-family="Inter, ui-sans-serif, system-ui, sans-serif"
        font-size="28" font-weight="600" fill="#102027" letter-spacing="0.5">ay</text>
</svg>
```
Notes: keep one `stroke-width` and rounded terminals across every drawn glyph so the routed letter reads as the same weight as the Inter glyphs (unified unit, D-07). `<text>` falls back to system-ui if Inter isn't installed on the viewing machine — acceptable for exploration (D-10); the finalist is outlined in Phase 83.

### Ephemeral `file://` gallery wrapper (D-13, scratchpad, uncommitted)
```html
<!doctype html><html><head><meta charset="utf-8">
<link rel="stylesheet" href="../../brandbook/tokens/tokens.css">
<style>
  body{background:var(--cw-paper);color:var(--cw-ink);
       font-family:var(--cw-font-family-sans);padding:var(--cw-space-3xl)}
  .dir{margin-bottom:var(--cw-space-2xl)}
</style></head><body>
  <!-- paste each direction's inline <svg> blocks here at real scale; browser renders them -->
  <div class="dir"><!-- svg + proof strip --></div>
</body></html>
```
Note: relative `../../` path assumes the file sits in the session scratchpad; adjust to an absolute `file://` path or copy `tokens.css` values inline if the relative link doesn't resolve. This file is **not committed** (D-13).

## State of the Art — routed-path / trace precedents in devtool branding

> Backs the LOGO-06 rationale that "chime" can be expressed through path/route/signal/trace without any bell. Precedent *metaphor* claims below are training-knowledge unless a source URL is given; treat as illustrative rationale, not verified brand-history fact. Phase 86 (NOTES-04) is where formal citations land.

| Precedent | Metaphor it proves | Why it survives at 16px / mono |
|-----------|--------------------|-------------------------------|
| **Traefik** (edge router / reverse proxy) | Traffic *routing* — arrows/paths converging | Monoline, high-aperture mark; brand guidelines exist [CITED: traefik.io/downloads/Traefik_Labs_Brand_Guidelines.pdf] [ASSUMED: routing-metaphor reading] |
| **Vector** (observability data pipeline, by Datadog) | Directed *pipeline / flow* | Simple geometric "V"/arrow; one-color legible [ASSUMED] |
| **OpenTelemetry / Jaeger** (distributed *tracing*) | Trace / span timeline | Bold geometric glyph, no fine detail [ASSUMED] |
| **Linear** | Clean routed geometry, monoline | Reduces to a favicon-safe monogram [ASSUMED] |
| **n8n** (workflow automation) | *Nodes connected by paths* / waypoints | Node-and-edge mark reads at small size [ASSUMED] |

**Design lesson extracted (HIGH confidence, independent of any single brand):** marks that survive 16px + mono are **monoline with wide apertures and ≤2 ideas** — exactly the construction rules brand-book §13 already mandates. Fine clappers, note-heads, and staff lines (LOGO-06 bans these) are precisely the details that collapse at favicon size, which is an independent, technical reason to avoid literal bell/music imagery beyond the brand rationale.

**Deprecated/superseded for this project:**
- Brand-book §13's "small chime/bell-like endpoint" logomark suggestion is **superseded** by LOGO-06 / the pressure-test — treat the literal bell as rejected (already flagged in CONTEXT canonical refs).

## Runtime State Inventory

Not applicable — this is a **greenfield doc/asset phase**, not a rename/refactor/migration. No stored data, live-service config, OS-registered state, secrets/env vars, or build artifacts are touched. The only new artifact is `notes/logo-options.md`; the gallery is ephemeral and uncommitted. Verified: milestone is doc/asset-only, touches no runtime code, `chimeway_admin` untouched (REQUIREMENTS.md, CONTEXT code_context).

## Common Constraints (from brand book + pressure-test, LOCKED — do not re-derive)

- Construction rules (brand-book §13): rounded terminals; simple geometry; ≤2 visual ideas; must work at 16px, one color, and dark; recognizable without the wordmark; **avoid tiny clappers, musical notes, staff lines, detailed bell drawings.**
- Clear-space = height of the lowercase `c`; logomark min 16px / preferred 24px; full horizontal lockup min 120px wide.
- Usage don'ts: no drop shadows, no gradients inside the mark, no stretch/skew, no full-color mark on noisy backgrounds, no bell emoji, no musical-note imagery, don't look like a sound-effects/audio app.
- Wordmark casing: lowercase `chimeway` in every graphic; title-case "Chimeway" only in prose (VOICE-03 precedent).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Traefik/Vector/OTel/Jaeger/Linear/n8n *metaphor readings* are as described | State of the Art | Low — used only as illustrative rationale; formal citation is Phase 86 (NOTES-04). Do not present as verified brand history. |
| A2 | `<text font-family="Inter,…">` falling back to system-ui is acceptable proof fidelity for exploration | Code Examples / D-10 | Low — D-10 explicitly permits it; finalist is outlined in Phase 83 |
| A3 | Common local Markdown previewers (VS Code, Obsidian) render raw inline SVG | Pitfall 1 | Low — some previewers also sanitize; the *authoritative* render surface is the D-13 `file://` gallery, which always works |

**All rendering/behavioral claims (GitHub SVG stripping, `var()` non-resolution, cross-`<svg>` `<use>`, `file://` same-origin) are VERIFIED against primary sources — not assumptions.**

## Open Questions (RESOLVED)

1. **Literal token hex vs `var(--cw-*)` in the committed SVG**
   - What we know: `var()` won't resolve in the committed `.md` or a standalone `.svg` (Pitfall 2).
   - What's unclear: whether the planner wants an auditable comment convention (`<!-- --cw-ink -->`) on every fill, or a legend at the top of the doc.
   - Recommendation: literal hex + one comment per distinct color the first time it appears, plus a token→hex legend in the doc intro. Cheap, keeps D-11 auditable.
   - **RESOLVED:** adopted verbatim in 82-01-PLAN.md `<constraints>` + Task 2 (literal hex, first-use `<!-- --cw-ink -->` comment, token→hex legend in the doc intro).

2. **How many rejected candidates to retain inline**
   - What we know: NOTES-02 requires rejected directions kept inline for repo-size discipline; D-01 confirms.
   - What's unclear: exact count — "all explored" is open-ended.
   - Recommendation: retain 2–4 instructive rejects (each failing a *different* gate: cage, bell-literal, dies-at-16px, icon+text-gap) so the doc teaches the taste gates; keep each SVG minimal.
   - **RESOLVED:** adopted verbatim in 82-01-PLAN.md Task 3 (2–4 rejects, each failing a different gate).

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Web browser (Chromium/Firefox/Safari) | D-13 ephemeral gallery review | ✓ (dev machine, macOS) | n/a | Open the `.md` in a raw-HTML Markdown previewer |
| `xmllint` (libxml2) | Optional SVG well-formedness guard | likely (ships with macOS) | — | Skip the automated guard; rely on browser render + visual check |
| Node / build tooling | — | not required | — | Not used — no build step (out of scope) |

**Missing dependencies with no fallback:** none — the phase needs only a text editor and a browser.

## Validation Architecture

> `workflow.nyquist_validation: true`. This is a static doc/SVG phase with **no test framework** (Elixir project; no JS test runner; adding one is out of scope). Validation is therefore **checker-verifiable gates + a few grep-based guards**, not an automated unit suite. This is the honest, correct shape for a doc phase — not a gap to fill with machinery.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | none — no test runner for Markdown/SVG; adding one is out-of-scope |
| Config file | none |
| Quick run command | `grep`/`xmllint` guards below (shell, no deps) |
| Full suite command | Human visual review of the `file://` gallery against D-12 gates |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| LOGO-01 | 5 directions, each with verdict + confidence | grep | `grep -cE '^Verdict: (Ship\|Defer\|Reject)' notes/logo-options.md` (expect ≥5); `grep -cE 'Confidence: (High\|Medium\|Low)'` (expect ≥5) | ❌ Wave 0 |
| LOGO-02 / D-04 | ≥2 integrated typemarks present | manual + grep | Section labels grep + visual confirm the motif is *in* the letterform | ❌ Wave 0 |
| LOGO-05 | No background cage; no primary subtitle | manual | Visual review; guard: full-bleed `<rect>` appears only in inverse proof cells | ❌ Wave 0 |
| LOGO-06 | No literal bell/note/staff; path/route/signal only | manual | Visual review (semantic — not textually greppable) | ❌ Wave 0 |
| NOTES-02 | Rejected directions retained inline with reason | grep | `grep -c 'Rejected' notes/logo-options.md`; confirm each has a reason line | ❌ Wave 0 |
| D-11 | Only token colors used | grep | Extract all `#[0-9a-fA-F]{6}` in SVG blocks; assert ⊆ {102027,07131a,fffdf8,0e7c86 (+ any other used token hex)} | ❌ Wave 0 |
| D-12 | Every shortlisted direction has all 5 proof labels | grep | Per direction: presence of `16px`, `Mono`, `Inverse`, `Clear-space`, `Min-size` | ❌ Wave 0 |
| — | SVG well-formedness | xmllint | Extract each `<svg>…</svg>` block, `xmllint --noout` each (skip if xmllint absent) | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** run the grep guards (verdict count, confidence count, token-hex subset, proof-label presence).
- **Per wave merge:** open the `file://` gallery; visually confirm each direction survives 16px/mono/inverse and honors the taste gates.
- **Phase gate:** all 5 directions present with verdict+confidence+proof strip; ≥2 integrated typemarks; rejected retained with reasons; `git diff --stat` shows only `notes/logo-options.md` changed (scope-boundary check, mirrors NOTES-03 discipline).

### Wave 0 Gaps
- [ ] A tiny shell guard script (grep + optional `xmllint`) that asserts verdict/confidence counts, proof-label presence, and token-hex subset — authored alongside the doc, run before each commit. No framework install needed.

*(No test framework to install — the "gaps" are the grep guards above, which are shell one-liners.)*

## Security Domain

> `security_enforcement` is not set in `.planning/config.json` (treated as enabled). This phase touches **no runtime code, no input handling, no auth, no data** — so the standard web-app ASVS surface is not exercised. One SVG-specific hygiene item genuinely applies and is worth enforcing, because these marks are the seed for assets that later ship in README/HexDocs (Phase 83/85).

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — (no auth surface) |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | no | — (static hand-authored content, no user input) |
| V6 Cryptography | no | — |
| V14 Config / hygiene | yes (light) | SVG must contain no active content — see below |

### Known Threat Patterns for hand-authored SVG
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Malicious/active SVG content (`<script>`, `on*` handlers, `<foreignObject>`, external `href`/`xlink:href` to remote URLs) | Tampering / XSS-when-embedded | Author marks with **presentation elements only** (`path/text/g/rect/circle/symbol/use`); no `<script>`, no `on*` attributes, no `<foreignObject>`, no remote references. GitHub sanitizes anyway, but downstream embedders (Phase 83/85) may not. |
| Repo bloat / binary smuggling | — (hygiene) | No base64 rasters, no `<image>` data-URIs; text-only SVG (also NOTES-02 / NOTES-03 discipline). |

## Sources

### Primary (HIGH confidence)
- alexwlchan.net/notes/2024/how-to-render-svgs-on-github/ — GitHub only renders SVG via `<img>` to a separate file; inline `<svg>` in Markdown is stripped.
- github.com/github/markup (issues #556, #1160) — Markdown HTML sanitization affecting SVG.
- developer.chrome.com/blog/migrate-way-from-data-urls-in-svg-use — cross-origin / data-URL restrictions on SVG `<use>`; same-document use is the safe path.
- brandbook/tokens/tokens.css (Phase 81) — the only legal `--cw-*` color/type values.
- prompts/chimeway-brand-book.md §12–13 — visual thesis, metaphor set, construction rules, clear-space, min sizes (with bell superseded by LOGO-06).
- prompts/brand-book-pressure-test.md — hard taste non-negotiables (no cage, unified unit, no subtitle, ≥1 integrated typemark, options-not-a-single-answer, not clipart).

### Secondary (MEDIUM confidence)
- traefik.io/downloads/Traefik_Labs_Brand_Guidelines.pdf — a devtool with a routing-metaphor mark and published brand guidelines.

### Tertiary (LOW confidence)
- Metaphor readings of Vector / OpenTelemetry / Jaeger / Linear / n8n marks — training-knowledge illustration only; formal citation deferred to Phase 86 (NOTES-04).

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — there is no stack; hand-authored SVG + Markdown + token values, all verified against the milestone constraints.
- Architecture / doc structure: HIGH — derived directly from locked D-01..D-13 and UI-SPEC.
- Rendering pitfalls: HIGH — GitHub SVG stripping, `var()` non-resolution, cross-`<svg>` `<use>`, and `file://` same-origin all verified against primary sources.
- Precedents: LOW/MEDIUM — routing-metaphor examples are illustrative rationale; only Traefik has a cited brand doc.

**Research date:** 2026-07-10
**Valid until:** 2026-08-09 (30 days — stable domain; GitHub sanitization behavior is long-standing, unlikely to change)
