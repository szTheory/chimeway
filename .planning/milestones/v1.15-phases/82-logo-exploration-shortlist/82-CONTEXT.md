# Phase 82: Logo Exploration & Shortlist - Context

**Gathered:** 2026-07-10 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Produce a **vetted shortlist of 3–5 fully-worked logo directions** — each a coherent concept
with rationale, pros/cons, and a ship/defer/reject recommendation + confidence — that all
satisfy the non-negotiable taste constraints and survive the legibility gates, so a human can
make an informed pick in Phase 83.

**In scope:** exploration + shortlist authored into `notes/logo-options.md` (inline SVG), each
direction proven against the 16px / mono / inverse gates.

**Out of scope (belongs to Phase 83, the User Checkpoint):** selecting the finalist and
promoting it to the full optimized-SVG lockup family (LOGO-03/04), simplified favicon file,
and social derivatives. This phase does **not** pick a winner and does **not** emit a standalone
`brandbook/logo/*.svg` file family.

**Requirements:** LOGO-01, LOGO-02, LOGO-05, LOGO-06, NOTES-02.
</domain>

<decisions>
## Implementation Decisions

### Deliverable Scope & Format
- **D-01:** Phase 82 produces exactly **one committed artifact — `notes/logo-options.md`.**
  All shortlisted directions *and* rejected candidates are embedded as inline `<svg>` inside
  that markdown. No standalone `brandbook/logo/*.svg` file family is created this phase (that is
  Phase 83, finalist-only). Repo-size discipline is the reason rejected candidates stay inline.
- **D-02:** `notes/logo-options.md` is a **vetted shortlist, not a raw gallery**: every direction
  carries rationale, pros/cons, and an explicit ship / defer / reject recommendation with a
  confidence level.

### Direction Set
- **D-03:** Fully work **5 distinct directions** (top of the 3–5 range) to give a genuine choice.
- **D-04:** ~~At least 2 of the 5 are integrated typemarks~~ **RELAXED by D-14** to the LOGO-02
  floor: **at least 1** of the shortlist is a genuinely integrated typemark (motif worked *into* a
  `chimeway` glyph). The first tournament's two typemarks (routed-`w`, trace-`y`) were rejected as
  not resonating, so 2 is no longer forced — the tournament may surface strong non-typemark
  directions instead, provided ≥1 typemark survives to satisfy LOGO-02.
- **D-05:** ~~Each direction routes the "chime" concept through the path / route / signal-arc /
  waypoint / trace-timeline / `cw`-monogram-as-path metaphor set.~~ **SUPERSEDED by D-14.** This
  narrow single-family metaphor lock is exactly what produced the rejected first shortlist. The
  **≤2 visual ideas per direction** discipline and the **zero literal bell/clapper/note/staff/audio**
  exclusion both survive under D-14; only the single-family restriction is lifted.

### Taste Constraints (non-negotiable, applied to every direction)
- **D-06:** No rectangular/enclosing background cage; transparent/background-free marks by default.
- **D-07:** Mark and wordmark read as **one unified unit** — not icon-left / text-right with a
  visible gap. Logotype sits appropriately close to the logomark.
- **D-08:** The **primary lockup carries no subtitle/slogan.** An optional separate tagline lockup
  may be shown only if it genuinely adds value — never as the primary.
- **D-09:** Programmatic SVGs must be **thoughtful and brand-based, not clipart**; unique
  brand-derived imagery/type.

### Rendering & Color
- **D-10:** Non-typemark directions render the wordmark as `<text>` in the tokens' **Inter** stack
  (fast, editable during exploration); integrated-typemark directions hand-draw the flourished
  glyph(s) as `<path>`. **Full wordmark-to-outline vector conversion is deferred to Phase 83's
  finalist** (the milestone's "SVG outlines, no bundled font" rule is a *ship* rule, not an
  exploration rule).
- **D-11:** Marks drawn in `--cw-ink` (#102027) as primary with `--cw-teal` (#0e7c86) as the
  single accent. Mono = one-color ink. Inverse = `--cw-paper` (#fffdf8) on `--cw-night` (#07131a).
  **No gradients, drop shadows, stretch, or skew inside the mark.** Colors sourced only from the
  reconciled `--cw-*` token layer (`brandbook/tokens/tokens.css`).

### Legibility Gates (proven before shortlisting)
- **D-12:** Each shortlisted direction embeds an inline **proof strip** in the doc demonstrating:
  the mark at **16px**, in **single-color mono**, and **inverse (dark)** — plus a captured
  **clear-space and minimum-size** intent (clear-space = height of the lowercase `c`; logomark
  16px min / 24px preferred; full horizontal lockup 120px wide min).

### Preview
- **D-13:** Generate an **ephemeral `file://`-safe HTML gallery in the session scratchpad**
  (NOT committed) so the user can eyeball all directions + proof strips at real scale during
  review. The committed artifact remains the markdown; the real scoped brandbook HTML is Phase 84.
  Preview background/ink use the `--cw-*` tokens.

### Claude's Discretion
- The specific concepts, geometry, and which candidates ultimately land as ship vs. defer vs.
  reject are Claude's creative call within D-03..D-12 — the human's taste sign-off is Phase 83.
- Light external research (OSS devtool logo precedents; integrated-typemark construction) may be
  gathered by the researcher to back rationale with citations; it is non-blocking.

### Post-Checkpoint Reset (2026-07-18)
- **D-14:** The first shortlist (5 route/signal/trace directions) was **rejected in full** at the
  Task 4 human-verify checkpoint — D1 "looks like a power button," D2 "doesn't read," D3 routing
  "doesn't resonate for notifications," D4 "AI slop… not readable," D5 (cw-monogram, the user's
  favorite) "not a coherent logo, just a floating monogram." Root cause: all five shared the single
  D-05 metaphor family. **Resolution (approved with the user):** reopen the concept aperture (D-05
  superseded, D-04 relaxed) and run a **wide divergent tournament + cull** — ~15–20 rough candidates
  generated across broadened families in parallel, judged, culled to a fresh **5–6** shortlist for a
  second checkpoint. Broadened families: **pure logotype/wordmark, aperture/opening, abstract
  geometric fan-out, keystone/anchor, containment/stewardship, ledger/seal/mark-of-record** (plus
  route/signal/trace still permitted if executed far better). **Retained non-negotiables:** the
  no-bell/music/note exclusion (LOGO-06), all D-06..D-12 hygiene/taste gates, the ≤2-visual-ideas
  discipline, and repo scope (only `notes/logo-options.md` + `scripts/logo-guards.sh` committed).
  **Added anti-slop guardrails** judged in the cull: must read at a glance, must not collide with a
  common UI glyph (power button / copy icon / circle-arrow), must cohere as a lockup (no floating
  monogram beside plain text), must survive 16px + mono as authored. Old D5 kept as a *reference*
  lesson only, not a lead. `notes/logo-options.md` is rewritten in place (new commit, history kept).

### Folded Todos
None — `todo.match-phase 82` returned zero matches.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `prompts/chimeway-brand-book.md` — §12 Visual identity overview + §13 Logo direction
  (metaphor set, wordmark, logomark concepts, construction rules, clearspace, min sizes, usage
  do/don't). NOTE: the brand book's "small chime/bell-like endpoint" suggestion is **superseded**
  by LOGO-06 / the pressure-test (no literal bell) — treat the bell as rejected.
- `prompts/brand-book-pressure-test.md` — the hard taste constraints (no cages, unified
  mark+wordmark, no subtitle, ≥1 integrated typemark, options-not-a-single-answer, not clipart),
  the artifact manifest, and the red-team stance.
- `brandbook/tokens/tokens.css` — canonical `--cw-*` color/scalar SSOT the marks draw from.
- `brandbook/tokens/tokens.json` — DTCG mirror of the same tokens.
- `notes/decision-log.md` — token divergence ledger (context for which values are locked).
- `.planning/REQUIREMENTS.md` — LOGO-01/02/05/06, NOTES-02 acceptance text.
- `.planning/METHODOLOGY.md` — Cohesive-Recommendation / One-Shot / High-Impact-Escalation lenses.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Reconciled token palette** (`brandbook/tokens/tokens.css`, Phase 81): 15 verbatim primitives
  incl. `--cw-ink #102027`, `--cw-night #07131a`, `--cw-paper #fffdf8`, `--cw-teal #0e7c86`,
  `--cw-brass #d6a84f`, `--cw-mint #9adbcf`; light/dark/system theming; type stack Inter /
  IBM Plex Mono. These are the only colors/typefaces the logo work may use.
- **Font seed:** `--cw-font-family-sans: Inter` (wordmark base); `--cw-font-family-mono: IBM Plex Mono`.

### Established Patterns
- **Repo discipline (milestone-wide):** self-contained `brandbook/`-only + `notes/`; SVG/HTML/CSS/
  JSON/MD first; no large binaries, no new build system. Rejected candidates stay inline as SVG.
- **Doc-as-deliverable pattern:** Phase 81 shipped tokens + a `notes/decision-log.md` ledger with
  explicit DOCUMENTED/DEFERRED entries — Phase 82 mirrors that "recommendation + confidence + defer"
  shape in `notes/logo-options.md`.
- **Doc/asset-only milestone:** touches no runtime code, so no CI-runtime risk (the 3 known red CI
  lanes on `main` are unrelated and unaffected).

### Integration Points
- `notes/logo-options.md` is consumed by **Phase 83** (finalist selection → full lockup family) and
  referenced by **Phase 84** (brandbook HTML renders the chosen logo family). Token names are the
  cross-phase contract — do not invent new color values.
</code_context>

<specifics>
## Specific Ideas

- Brand-book §13 concept seeds worth exploring: a rounded path entering an endpoint; a `c`-like
  curve that becomes a route; two route nodes connected by a line with a gentle signal arc; a `cw`
  monogram where the `w` implies a path.
- Wordmark is lowercase `chimeway` in the graphic; title-case "Chimeway" only in prose.
- Visual thesis to hit: "calm infrastructure" — quiet confidence, routed paths, warm technical
  precision; no SaaS-gloss.
</specifics>

<deferred>
## Deferred Ideas

- Finalist selection + full optimized-SVG lockup family (primary horizontal, icon-only, wordmark,
  stacked, mono, inverse), simplified favicon mark, and social/OpenGraph derivatives — **Phase 83
  (LOGO-03/04, INTEG-03)**.
- Do/don't usage grid, clear-space diagram, and minimum-size grid as *rendered brandbook HTML* —
  intent is captured here; the visual grid lands in **Phase 84** (BOOK-*).
- Bundled webfont / full wordmark-to-outline conversion — Phase 83 finalist only.
- `notes/research.md` formal citations doc — **Phase 86 (NOTES-04)** (light research here is inline
  rationale only).

### Reviewed Todos (not folded)
None — no pending todos matched this phase.
</deferred>
