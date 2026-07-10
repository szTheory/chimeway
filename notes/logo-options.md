# Chimeway Logo Options — Exploration & Shortlist

> Phase 82 deliverable (v1.15 Brand Identity & Brand Book). This is a **vetted
> shortlist, not a raw gallery**: five fully-worked directions, each with
> rationale, a Ship / Defer / Reject verdict + confidence, and a self-contained
> proof strip proving 16px / mono / inverse legibility — plus a retained set of
> rejected candidates that each teach a taste gate. Phase 83 (the user
> checkpoint) picks the winner from this set; this phase does **not** pick a
> winner and does **not** emit a `brandbook/logo/*.svg` file family.

## Visual thesis

**Calm infrastructure** — quiet confidence, routed paths, warm technical
precision, no SaaS-gloss. Chimeway routes a notification from trigger through
policy, scheduling, and delivery and can always explain the path it took, so the
mark expresses "chime" as a **routed signal**, never as a literal instrument.
The metaphor set is deliberately narrow: **path / route / signal-arc / waypoint /
trace-timeline / `cw`-monogram-as-path**. There is zero literal bell, clapper,
musical note, staff line, or audio imagery in any shortlisted direction (the
brand-book §13 "chime/bell endpoint" is superseded by LOGO-06 and treated as
rejected).

## How to view this file

Inline marks render in the ephemeral `file://` gallery (path printed at the end
of authoring) or any raw-HTML-permitting Markdown preview — **not on
github.com**, which strips inline SVG from rendered Markdown by design. The
committed Markdown is the source-of-record; the gallery is the eyeball surface.

## Token legend (the only legal colors)

Committed marks use **literal token hex** (never `var(--cw-*)`, which does not
resolve in a standalone/committed SVG). Each distinct color is annotated at
first use with a `cw-*` comment. Marks are drawn `cw-ink` primary with a single
`cw-teal` accent; mono collapses to one-color ink; inverse is `cw-paper` on
`cw-night`.

| Token | Hex | Role in the marks |
|-------|-----|-------------------|
| `--cw-ink` | `#102027` | Primary mark stroke/fill; wordmark ink |
| `--cw-teal` | `#0e7c86` | The single accent (one signal node / terminal per mark) |
| `--cw-paper` | `#fffdf8` | Inverse-variant mark color (paper-on-night) |
| `--cw-night` | `#07131a` | Inverse proof-cell background (the only legal scoped rect) |

## Proof-strip gate legend

Each shortlisted direction embeds a proof strip carrying all five labels:

- **16px** — the logomark rendered at favicon size; must stay recognizable.
- **Mono** — one-color `--cw-ink`; the concept must survive without the accent.
- **Inverse** — `--cw-paper` on `--cw-night`; the only legal background rect.
- **Clear-space** — reserved margin equal to the height of the lowercase `c`.
- **Min-size** — logomark 16px min / 24px preferred; horizontal lockup 120px min.

## Scope note

This phase captures **clear-space and minimum-size intent only**. The do/don't
usage grid, clear-space diagram, and minimum-size grid as *rendered brandbook
HTML* are consciously **deferred to Phase 84** (BOOK-*, per CONTEXT Deferred
Ideas) — so LOGO-06 is not over-credited as fully satisfied here. Full
wordmark-to-outline conversion is deferred to the Phase 83 finalist; non-typemark
directions render `chimeway` as Inter `<text>`.

---

## Shortlist

Five distinct directions. Directions 3 and 4 are genuinely **integrated
typemarks** — the motif is worked *into* a `chimeway` glyph as a `<path>`, not an
icon placed beside plain text (LOGO-02 / D-04).

### Direction 1 — Waypoint Route

Primary lockup:

<svg xmlns="http://www.w3.org/2000/svg" width="240" height="56" viewBox="0 0 240 56" role="img" aria-label="chimeway waypoint-route primary lockup">
  <g transform="translate(10,16)">
    <path d="M17 6.5 A 7.5 7.5 0 1 0 17 17.5" fill="none" stroke="#102027" stroke-width="2.4" stroke-linecap="round"/> <!-- cw-ink -->
    <path d="M15 12 H22" fill="none" stroke="#102027" stroke-width="2.4" stroke-linecap="round"/>
    <circle cx="23.6" cy="12" r="2" fill="#0e7c86"/> <!-- cw-teal signal waypoint -->
  </g>
  <text x="46" y="38" font-family="Inter, ui-sans-serif, system-ui, sans-serif" font-size="28" font-weight="600" fill="#102027" letter-spacing="0.3">chimeway</text>
</svg>

Concept: An open `c`-curve whose mouth releases a short route line that
terminates at a single teal waypoint node (two ideas: the `c`-as-route-entry and
the waypoint endpoint). The mark reads as "a path that arrives."

Pros: Simplest silhouette in the set; the open aperture and generous stroke
survive 16px and mono cleanly; the waypoint gives one calm accent without noise.

Cons: The `c`-arc is a common devtool shape, so it leans on the wordmark to feel
brand-specific; risks reading as a generic "copy" glyph if the route line is too
short.

Recommendation: Lead candidate for an icon-only favicon — it is the most legible
at small size and pairs frictionlessly with the Inter wordmark.

Verdict: Ship
Confidence: High

<svg xmlns="http://www.w3.org/2000/svg" width="520" height="88" viewBox="0 0 520 88" role="img" aria-label="Direction 1 legibility proof — small, single-color, and dark variants">
  <defs>
    <symbol id="d1" viewBox="0 0 24 24">
      <path d="M16 6.5 A 7.5 7.5 0 1 0 16 17.5" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
      <path d="M14 12 H20.5" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
      <circle cx="21.5" cy="12" r="1.8" fill="currentColor"/>
    </symbol>
  </defs>
  <use href="#d1" x="12" y="18" width="16" height="16" color="#102027"/> <!-- cw-ink 16px -->
  <use href="#d1" x="48" y="14" width="24" height="24" color="#102027"/> <!-- cw-ink mono -->
  <rect x="92" y="6" width="40" height="40" rx="6" fill="#07131a"/> <!-- cw-night inverse cell -->
  <use href="#d1" x="100" y="14" width="24" height="24" color="#fffdf8"/> <!-- cw-paper -->
  <text x="12" y="72" font-family="Inter, ui-sans-serif, system-ui, sans-serif" font-size="11" fill="#102027">16px &#183; Mono &#183; Inverse &#183; Clear-space = height of lowercase c &#183; Min-size 16px min / 24px pref, lockup 120px</text>
</svg>

### Direction 2 — Signal Arc

Primary lockup:

<svg xmlns="http://www.w3.org/2000/svg" width="240" height="56" viewBox="0 0 240 56" role="img" aria-label="chimeway signal-arc primary lockup">
  <g transform="translate(10,14)">
    <path d="M4 18 H20" fill="none" stroke="#102027" stroke-width="2.4" stroke-linecap="round"/> <!-- cw-ink route baseline -->
    <path d="M4 18 Q12 5 20 18" fill="none" stroke="#102027" stroke-width="2.4" stroke-linecap="round"/>
    <circle cx="4" cy="18" r="2" fill="#102027"/>
    <circle cx="20" cy="18" r="2" fill="#102027"/>
    <circle cx="12" cy="8.5" r="2" fill="#0e7c86"/> <!-- cw-teal signal apex -->
  </g>
  <text x="46" y="38" font-family="Inter, ui-sans-serif, system-ui, sans-serif" font-size="28" font-weight="600" fill="#102027" letter-spacing="0.3">chimeway</text>
</svg>

Concept: Two route nodes joined by a baseline, with one gentle signal arc rising
between them and a teal accent at the apex (two ideas: the node-to-node route and
the signal rising from it). It reads as "a quiet signal travels the route."

Pros: The clearest literal statement of the routed-signal metaphor; the arc gives
a calm, non-technical warmth; symmetrical and balanced beside the wordmark.

Cons: Three dots plus an arc is the busiest mark in the set; the apex accent can
fill in at 16px, and the arc flattens toward the baseline in mono if the rise is
too shallow.

Recommendation: Strong for a horizontal lockup and headers where it renders ≥24px;
watch the 16px favicon crop where the apex node may merge with the arc.

Verdict: Ship
Confidence: Medium

<svg xmlns="http://www.w3.org/2000/svg" width="520" height="88" viewBox="0 0 520 88" role="img" aria-label="Direction 2 legibility proof — small, single-color, and dark variants">
  <defs>
    <symbol id="d2" viewBox="0 0 24 24">
      <path d="M4 17 H20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
      <path d="M4 17 Q12 5 20 17" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
      <circle cx="4" cy="17" r="1.6" fill="currentColor"/>
      <circle cx="20" cy="17" r="1.6" fill="currentColor"/>
      <circle cx="12" cy="8" r="1.6" fill="currentColor"/>
    </symbol>
  </defs>
  <use href="#d2" x="12" y="18" width="16" height="16" color="#102027"/> <!-- cw-ink 16px -->
  <use href="#d2" x="48" y="14" width="24" height="24" color="#102027"/> <!-- cw-ink mono -->
  <rect x="92" y="6" width="40" height="40" rx="6" fill="#07131a"/> <!-- cw-night inverse cell -->
  <use href="#d2" x="100" y="14" width="24" height="24" color="#fffdf8"/> <!-- cw-paper -->
  <text x="12" y="72" font-family="Inter, ui-sans-serif, system-ui, sans-serif" font-size="11" fill="#102027">16px &#183; Mono &#183; Inverse &#183; Clear-space = height of lowercase c &#183; Min-size 16px min / 24px pref, lockup 120px</text>
</svg>

### Direction 3 — Routed-w typemark (integrated)

Primary lockup — the `w` of `chimeway` is drawn as a zig-zag route with waypoint
vertices and a teal terminal; `chime` and `ay` are Inter `<text>` on the same
baseline so the word reads as one unit:

<svg xmlns="http://www.w3.org/2000/svg" width="250" height="56" viewBox="0 0 250 56" role="img" aria-label="chimeway integrated typemark — the w rendered as a routed path">
  <text x="12" y="38" font-family="Inter, ui-sans-serif, system-ui, sans-serif" font-size="28" font-weight="600" fill="#102027" letter-spacing="0.3">chime</text> <!-- cw-ink -->
  <path d="M92 20 L98 36 L104 24 L110 36 L116 20" fill="none" stroke="#102027" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="98" cy="36" r="2.2" fill="#102027"/>
  <circle cx="110" cy="36" r="2.2" fill="#102027"/>
  <circle cx="116" cy="20" r="2.4" fill="#0e7c86"/> <!-- cw-teal route terminal -->
  <text x="120" y="38" font-family="Inter, ui-sans-serif, system-ui, sans-serif" font-size="28" font-weight="600" fill="#102027" letter-spacing="0.3">ay</text>
</svg>

Concept: The single letter `w` becomes a routed path — a zig-zag with two
waypoint vertices at the baseline and a teal signal terminal at the last upstroke
(one idea, worked into the letterform). The route *is* a glyph.

Pros: Genuinely integrated (LOGO-02) yet reads instantly as `chimeway`; the
routed `w` is distinctive and brand-specific; monoline construction survives mono
and holds at 16px as an icon (the `w` alone works as a standalone motif).

Cons: The routed `w` sits slightly taller than the Inter x-height and needs
per-metric tuning against the outlined finalist in Phase 83; at very small sizes
the two waypoint dots can crowd the vertices.

Recommendation: Strongest integrated typemark — carry it forward as the primary
candidate for the finalist selection; the routed `w` doubles as an icon-only mark.

Verdict: Ship
Confidence: High

<svg xmlns="http://www.w3.org/2000/svg" width="520" height="88" viewBox="0 0 520 88" role="img" aria-label="Direction 3 legibility proof — small, single-color, and dark variants">
  <defs>
    <symbol id="d3" viewBox="0 0 24 24">
      <path d="M3 7 L8 18 L12 10 L16 18 L21 7" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>
      <circle cx="8" cy="18" r="1.7" fill="currentColor"/>
      <circle cx="16" cy="18" r="1.7" fill="currentColor"/>
      <circle cx="21" cy="7" r="1.8" fill="currentColor"/>
    </symbol>
  </defs>
  <use href="#d3" x="12" y="18" width="16" height="16" color="#102027"/> <!-- cw-ink 16px -->
  <use href="#d3" x="48" y="14" width="24" height="24" color="#102027"/> <!-- cw-ink mono -->
  <rect x="92" y="6" width="40" height="40" rx="6" fill="#07131a"/> <!-- cw-night inverse cell -->
  <use href="#d3" x="100" y="14" width="24" height="24" color="#fffdf8"/> <!-- cw-paper -->
  <text x="12" y="72" font-family="Inter, ui-sans-serif, system-ui, sans-serif" font-size="11" fill="#102027">16px &#183; Mono &#183; Inverse &#183; Clear-space = height of lowercase c &#183; Min-size 16px min / 24px pref, lockup 120px</text>
</svg>

### Direction 4 — Trace-timeline typemark (integrated)

Primary lockup — a trace timeline runs beneath the word with tick nodes, and the
final `y` is hand-drawn as a `<path>` whose descender routes into the timeline and
terminates at a teal waypoint; `chimewa` is Inter `<text>` on the same baseline:

<svg xmlns="http://www.w3.org/2000/svg" width="250" height="60" viewBox="0 0 250 60" role="img" aria-label="chimeway integrated typemark — trace timeline with the y descender as a routed path">
  <text x="12" y="34" font-family="Inter, ui-sans-serif, system-ui, sans-serif" font-size="28" font-weight="600" fill="#102027" letter-spacing="0.3">chimewa</text> <!-- cw-ink -->
  <path d="M150 20 L158 32 M166 20 L158 32 L156 38 Q156 44 162 44 L182 44" fill="none" stroke="#102027" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="182" cy="44" r="2.4" fill="#0e7c86"/> <!-- cw-teal route terminal -->
  <path d="M14 46 H140" fill="none" stroke="#102027" stroke-width="1.6" stroke-linecap="round"/>
  <circle cx="44" cy="46" r="1.6" fill="#102027"/>
  <circle cx="86" cy="46" r="1.6" fill="#102027"/>
  <circle cx="128" cy="46" r="1.6" fill="#102027"/>
</svg>

Concept: The word sits on a trace timeline (tick nodes = lifecycle events), and
the `y` descender leaves the word to route down onto that timeline, ending at a
teal waypoint (two ideas: the timeline baseline and the routed descender). It
literalizes Chimeway's core value — an explainable trace.

Pros: The most on-brand concept in the set (explainable trace = the product
thesis); the integrated `y` is distinctive and the timeline gives a calm,
infrastructural rhythm.

Cons: Two ideas competing under the word get delicate at small sizes — the
timeline ticks and the routed descender can collapse toward each other at 16px;
the standalone icon (routed `y`) is less self-evident than the routed `w`.

Recommendation: Keep as a strong secondary — the concept is excellent but the
small-size execution needs the finalist's outlined metrics before it can ship;
defer the ship/reject call to the Phase 83 pick.

Verdict: Defer
Confidence: Medium

<svg xmlns="http://www.w3.org/2000/svg" width="520" height="88" viewBox="0 0 520 88" role="img" aria-label="Direction 4 legibility proof — small, single-color, and dark variants">
  <defs>
    <symbol id="d4" viewBox="0 0 24 24">
      <path d="M6 5 L12 14 M18 5 L12 14 L10 19 Q10 22 13 22 L21 22" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>
      <circle cx="21" cy="22" r="1.8" fill="currentColor"/>
    </symbol>
  </defs>
  <use href="#d4" x="12" y="18" width="16" height="16" color="#102027"/> <!-- cw-ink 16px -->
  <use href="#d4" x="48" y="14" width="24" height="24" color="#102027"/> <!-- cw-ink mono -->
  <rect x="92" y="6" width="40" height="40" rx="6" fill="#07131a"/> <!-- cw-night inverse cell -->
  <use href="#d4" x="100" y="14" width="24" height="24" color="#fffdf8"/> <!-- cw-paper -->
  <text x="12" y="72" font-family="Inter, ui-sans-serif, system-ui, sans-serif" font-size="11" fill="#102027">16px &#183; Mono &#183; Inverse &#183; Clear-space = height of lowercase c &#183; Min-size 16px min / 24px pref, lockup 120px</text>
</svg>

### Direction 5 — cw-monogram-as-path

Primary lockup — a `cw` monogram whose strokes form one continuous route (the
`c` opens directly into a `w`-like zig-zag), paired tightly with the wordmark:

<svg xmlns="http://www.w3.org/2000/svg" width="240" height="56" viewBox="0 0 240 56" role="img" aria-label="chimeway cw-monogram-as-path primary lockup">
  <g transform="translate(10,15)">
    <path d="M16 6.5 A 7 7 0 1 0 16 17.5 L18 12 L20 16.5 L22 12" fill="none" stroke="#102027" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/> <!-- cw-ink continuous cw route -->
    <circle cx="22" cy="12" r="2" fill="#0e7c86"/> <!-- cw-teal route terminal -->
  </g>
  <text x="46" y="38" font-family="Inter, ui-sans-serif, system-ui, sans-serif" font-size="28" font-weight="600" fill="#102027" letter-spacing="0.3">chimeway</text>
</svg>

Concept: A `cw` monogram drawn as a single unbroken monoline — the `c` aperture
flows into a compact `w` zig-zag ending at a teal terminal (one idea: the
initials as one continuous route). It compresses the whole route metaphor into a
two-letter mark.

Pros: The most "logo-like" standalone monogram; encodes the brand initials; the
continuous stroke keeps it unified and calm.

Cons: Two letterforms in one small glyph is the busiest icon at 16px — the `w`
tail crowds the `c` aperture and can read as a squiggle; the least self-evident
of the five at favicon size.

Recommendation: Hold as a monogram/avatar option rather than the primary lockup;
needs simplification before it survives 16px — defer to the finalist review.

Verdict: Defer
Confidence: Low

<svg xmlns="http://www.w3.org/2000/svg" width="520" height="88" viewBox="0 0 520 88" role="img" aria-label="Direction 5 legibility proof — small, single-color, and dark variants">
  <defs>
    <symbol id="d5" viewBox="0 0 24 24">
      <path d="M16 6.5 A 6.8 6.8 0 1 0 16 17.5 L18 12 L20 16.5 L22 12" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
      <circle cx="22" cy="12" r="1.8" fill="currentColor"/>
    </symbol>
  </defs>
  <use href="#d5" x="12" y="18" width="16" height="16" color="#102027"/> <!-- cw-ink 16px -->
  <use href="#d5" x="48" y="14" width="24" height="24" color="#102027"/> <!-- cw-ink mono -->
  <rect x="92" y="6" width="40" height="40" rx="6" fill="#07131a"/> <!-- cw-night inverse cell -->
  <use href="#d5" x="100" y="14" width="24" height="24" color="#fffdf8"/> <!-- cw-paper -->
  <text x="12" y="72" font-family="Inter, ui-sans-serif, system-ui, sans-serif" font-size="11" fill="#102027">16px &#183; Mono &#183; Inverse &#183; Clear-space = height of lowercase c &#183; Min-size 16px min / 24px pref, lockup 120px</text>
</svg>

<!-- Rejected candidates and the ephemeral gallery are appended in Task 3. -->
