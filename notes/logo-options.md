# Chimeway Logo Options — Exploration & Shortlist

> Phase 82 deliverable (v1.15 Brand Identity & Brand Book). This is a **vetted
> shortlist, not a raw gallery**: fully-worked directions, each with rationale, a
> Ship / Defer / Reject verdict + confidence, and a self-contained proof strip
> proving 16px / mono / inverse legibility — plus a retained set of rejected
> candidates that each teach a taste gate. Phase 83 (the user checkpoint) picks
> the winner from this set; this phase does **not** pick a winner and does **not**
> emit a `brandbook/logo/*.svg` file family.

## Provenance — this is the second, broadened tournament

The first shortlist (five directions all built on a single **path / route /
signal / trace** metaphor) was **rejected in full** at the human-verify checkpoint
— the routing idea did not resonate for a notification product and the marks read
variously as a power button, a smudge, or a floating monogram. Root cause: every
direction shared one root metaphor. This shortlist is the result of reopening the
concept aperture (decision **D-14**) and running a **wide divergent tournament** —
~18 candidates generated across six metaphor families, culled to the six below.
The **no literal bell / music / note / audio** exclusion is retained (Chimeway is
not an audio product; "Chime" is trademark-crowded); only the single-family
metaphor lock was lifted.

## Visual thesis

**Calm infrastructure** — quiet confidence, warm technical precision, no
SaaS-gloss. Chimeway is an embedded, **local-first** notification-orchestration
library whose signature is **explainability** — it can always answer "why wasn't
this sent?" from a durable trace. The marks express that as **structure, a way in,
orchestration, stewardship, and record** — never as a literal instrument. Metaphor
families explored: **keystone/foundation, aperture/threshold, geometric fan-out,
containment/stewardship, ledger/seal, and pure logotype.** Zero literal bell,
clapper, musical note, staff line, or audio imagery appears in any direction.

## How to view this file

Inline marks render in the ephemeral `file://` gallery (path printed at the end of
authoring) or any raw-HTML-permitting Markdown preview — **not on github.com**,
which strips inline SVG from rendered Markdown by design. The committed Markdown is
the source-of-record; the gallery is the eyeball surface.

## Token legend (the only legal colors)

Committed marks use **literal token hex** (never `var(--cw-*)`, which does not
resolve in a standalone/committed SVG). Marks are drawn `cw-ink` primary with a
single `cw-teal` accent; mono collapses to one-color ink; inverse is `cw-paper` on
`cw-night`.

| Token | Hex | Role in the marks |
|-------|-----|-------------------|
| `--cw-ink` | `#102027` | Primary mark stroke/fill; wordmark ink |
| `--cw-teal` | `#0e7c86` | The single accent (one node / facet per mark) |
| `--cw-paper` | `#fffdf8` | Inverse-variant mark color (paper-on-night) |
| `--cw-night` | `#07131a` | Inverse proof-cell background (the only legal scoped rect) |

## Proof-strip gate legend

Each shortlisted direction embeds a proof strip carrying all five labels:

- **16px** — the logomark at favicon size; must stay recognizable.
- **Mono** — one-color `--cw-ink`; the concept must survive without the accent.
- **Inverse** — `--cw-paper` on `--cw-night`; the only legal background rect.
- **Clear-space** — reserved margin equal to the height of the lowercase `c`.
- **Min-size** — logomark 16px min / 24px preferred; horizontal lockup 120px min.

## Scope note

This phase captures **clear-space and minimum-size intent only**. The do/don't
usage grid, clear-space diagram, and minimum-size grid as *rendered brandbook HTML*
are consciously **deferred to Phase 84** (BOOK-*, per CONTEXT Deferred Ideas) — so
LOGO-06 is not over-credited as fully satisfied here. Full wordmark-to-outline
conversion is deferred to the Phase 83 finalist; non-typemark directions render
`chimeway` as Inter `<text>`, and the one integrated typemark hand-draws only its
distinctive glyph as `<path>`.

---

## Shortlist

Six distinct directions across five metaphor families. Direction 5 is a genuinely
**integrated typemark** — the leading `c` of `chimeway` is re-cut as the mark, not
an icon placed beside plain text (LOGO-02 / D-04).

### Direction 1 — Keystone

Primary lockup:

<svg xmlns="http://www.w3.org/2000/svg" width="240" height="56" viewBox="0 0 240 56" role="img" aria-label="chimeway keystone primary lockup">
  <path d="M14 16 L34 16 L30.5 44 L17.5 44 Z" fill="#102027"/> <!-- cw-ink -->
  <path d="M24 16 L34 16 L30.5 44 L24 44 Z" fill="#0e7c86"/> <!-- cw-teal keyed facet -->
  <text x="50" y="40" font-family="Inter, ui-sans-serif, system-ui, sans-serif" font-size="28" font-weight="600" fill="#102027" letter-spacing="0.3">chimeway</text>
</svg>

Concept: The central wedge of an arch — the keystone, the one piece that makes the
structure hold — with a single teal facet catching light (one idea: durable
infrastructure you own). It says "the calm foundation your notifications sit on."

Pros: The most confidently infrastructural mark in the set; a solid filled form
that never smudges, survives 16px and mono trivially, and reads instantly as
"foundation." Distinctive without being a literal icon.

Cons: A bare trapezoid can read generic if the wedge proportion is not held
distinctive; carries no direct nod to the letter `c` or the name.

Recommendation: Lead candidate for a standalone icon/favicon — the strongest, most
timeless silhouette. Pairs cleanly with the Inter wordmark.

Verdict: Ship
Confidence: High

<svg xmlns="http://www.w3.org/2000/svg" width="520" height="88" viewBox="0 0 520 88" role="img" aria-label="Direction 1 legibility proof — small, single-color, and dark variants">
  <defs>
    <symbol id="p1" viewBox="0 0 24 24">
      <path d="M6 5 L18 5 L15.5 19 L8.5 19 Z" fill="currentColor"/>
    </symbol>
  </defs>
  <use href="#p1" x="12" y="18" width="16" height="16" color="#102027"/> <!-- cw-ink 16px -->
  <use href="#p1" x="48" y="14" width="24" height="24" color="#102027"/> <!-- cw-ink mono -->
  <rect x="92" y="6" width="40" height="40" rx="6" fill="#07131a"/> <!-- cw-night inverse cell -->
  <use href="#p1" x="100" y="14" width="24" height="24" color="#fffdf8"/> <!-- cw-paper -->
  <text x="12" y="72" font-family="Inter, ui-sans-serif, system-ui, sans-serif" font-size="11" fill="#102027">16px &#183; Mono &#183; Inverse &#183; Clear-space = height of lowercase c &#183; Min-size 16px min / 24px pref, lockup 120px</text>
</svg>

### Direction 2 — Way (Threshold)

Primary lockup:

<svg xmlns="http://www.w3.org/2000/svg" width="240" height="56" viewBox="0 0 240 56" role="img" aria-label="chimeway threshold primary lockup">
  <path d="M14 44 L14 27 A11 11 0 0 1 36 27 L36 44" fill="none" stroke="#102027" stroke-width="3.4" stroke-linecap="round" stroke-linejoin="round"/> <!-- cw-ink doorway -->
  <circle cx="25" cy="41" r="3.1" fill="#0e7c86"/> <!-- cw-teal at the threshold -->
  <text x="52" y="40" font-family="Inter, ui-sans-serif, system-ui, sans-serif" font-size="28" font-weight="600" fill="#102027" letter-spacing="0.3">chimeway</text>
</svg>

Concept: A calm archway — the way *in* — with a single teal node resting at the
threshold (one idea: a doorway a notification passes through). It leans directly on
the name: **chime-way = the way**.

Pros: The strongest name tie in the set; a distinctive, warm form that is neither a
route line nor a common UI glyph; the node at the threshold gives one quiet accent.
Holds at 16px and reads inverse cleanly.

Cons: An open arch can flirt with an "n" or a horseshoe read until the threshold
node anchors it; the node can crowd the posts at the smallest sizes.

Recommendation: Strong shortlist lead alongside Keystone — the concept is on-brand
and the mark is memorable. Carry forward for the finalist pick.

Verdict: Ship
Confidence: High

<svg xmlns="http://www.w3.org/2000/svg" width="520" height="88" viewBox="0 0 520 88" role="img" aria-label="Direction 2 legibility proof — small, single-color, and dark variants">
  <defs>
    <symbol id="p2" viewBox="0 0 24 24">
      <path d="M5.5 20 L5.5 12 A6.5 6.5 0 0 1 18.5 12 L18.5 20" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>
      <circle cx="12" cy="18" r="1.9" fill="currentColor"/>
    </symbol>
  </defs>
  <use href="#p2" x="12" y="18" width="16" height="16" color="#102027"/> <!-- cw-ink 16px -->
  <use href="#p2" x="48" y="14" width="24" height="24" color="#102027"/> <!-- cw-ink mono -->
  <rect x="92" y="6" width="40" height="40" rx="6" fill="#07131a"/> <!-- cw-night inverse cell -->
  <use href="#p2" x="100" y="14" width="24" height="24" color="#fffdf8"/> <!-- cw-paper -->
  <text x="12" y="72" font-family="Inter, ui-sans-serif, system-ui, sans-serif" font-size="11" fill="#102027">16px &#183; Mono &#183; Inverse &#183; Clear-space = height of lowercase c &#183; Min-size 16px min / 24px pref, lockup 120px</text>
</svg>

### Direction 3 — Dispatch (fan-out)

Primary lockup:

<svg xmlns="http://www.w3.org/2000/svg" width="240" height="56" viewBox="0 0 240 56" role="img" aria-label="chimeway dispatch primary lockup">
  <g transform="translate(9,16)">
    <circle cx="4.5" cy="12" r="2.4" fill="#102027"/> <!-- cw-ink single source -->
    <path d="M6.5 12 H12" fill="none" stroke="#102027" stroke-width="2.8" stroke-linecap="round"/>
    <path d="M12 12 L19 6.5 M12 12 L21.5 12 M12 12 L19 17.5" fill="none" stroke="#102027" stroke-width="2.8" stroke-linecap="round"/>
    <circle cx="19.8" cy="6" r="2.7" fill="#0e7c86"/> <!-- cw-teal delivered channel -->
  </g>
  <text x="54" y="40" font-family="Inter, ui-sans-serif, system-ui, sans-serif" font-size="28" font-weight="600" fill="#102027" letter-spacing="0.3">chimeway</text>
</svg>

Concept: One source branching calmly to three channels, the top channel teal (one
idea: orchestration — one notification fanned out to many delivery paths). It is
the most literal picture of what the library actually does.

Pros: The clearest concept-to-product fit in the set (dispatch to channels); low
element count keeps it calm; the single teal endpoint reads as "delivered."

Cons: A branch/fan glyph sits near a generic "share/distribute" icon and can read
directionally ambiguous at a glance; the thinnest of the marks at 16px.

Recommendation: Keep as a strong secondary — the meaning is excellent but the form
needs the finalist's tuning to fully escape the "share icon" neighborhood before it
ships. Defer the ship/reject call to Phase 83.

Verdict: Defer
Confidence: Medium

<svg xmlns="http://www.w3.org/2000/svg" width="520" height="88" viewBox="0 0 520 88" role="img" aria-label="Direction 3 legibility proof — small, single-color, and dark variants">
  <defs>
    <symbol id="p3" viewBox="0 0 24 24">
      <circle cx="4.5" cy="12" r="1.8" fill="currentColor"/>
      <path d="M6 12 H11" fill="none" stroke="currentColor" stroke-width="2.1" stroke-linecap="round"/>
      <path d="M11 12 L17.5 7 M11 12 L19.2 12 M11 12 L17.5 17" fill="none" stroke="currentColor" stroke-width="2.1" stroke-linecap="round"/>
      <circle cx="18.2" cy="6.6" r="1.9" fill="currentColor"/>
    </symbol>
  </defs>
  <use href="#p3" x="12" y="18" width="16" height="16" color="#102027"/> <!-- cw-ink 16px -->
  <use href="#p3" x="48" y="14" width="24" height="24" color="#102027"/> <!-- cw-ink mono -->
  <rect x="92" y="6" width="40" height="40" rx="6" fill="#07131a"/> <!-- cw-night inverse cell -->
  <use href="#p3" x="100" y="14" width="24" height="24" color="#fffdf8"/> <!-- cw-paper -->
  <text x="12" y="72" font-family="Inter, ui-sans-serif, system-ui, sans-serif" font-size="11" fill="#102027">16px &#183; Mono &#183; Inverse &#183; Clear-space = height of lowercase c &#183; Min-size 16px min / 24px pref, lockup 120px</text>
</svg>

### Direction 4 — Held Record

Primary lockup:

<svg xmlns="http://www.w3.org/2000/svg" width="240" height="56" viewBox="0 0 240 56" role="img" aria-label="chimeway held-record primary lockup">
  <g transform="translate(9,16)">
    <path d="M9 5 A8 8 0 0 0 9 19" fill="none" stroke="#102027" stroke-width="3" stroke-linecap="round"/> <!-- cw-ink open bracket -->
    <path d="M16 5 A8 8 0 0 1 16 19" fill="none" stroke="#102027" stroke-width="3" stroke-linecap="round"/>
    <circle cx="12.5" cy="12" r="2.9" fill="#0e7c86"/> <!-- cw-teal the kept record -->
  </g>
  <text x="52" y="40" font-family="Inter, ui-sans-serif, system-ui, sans-serif" font-size="28" font-weight="600" fill="#102027" letter-spacing="0.3">chimeway</text>
</svg>

Concept: A single record held in an open embrace — parentheses of stewardship
around one teal node (one idea: your notifications and their history stay inside
your app, on the record, in your keeping). Local-first made into a gesture.

Pros: The most tasteful, minimal mark; expresses the local-first stewardship story
no other direction reaches; the open top and bottom keep it emphatically *not* a
cage; echoes the teal record-node motif used throughout.

Cons: Minimalism cuts both ways — `( • )` is quiet and could read as a generic
bullet/button until the brand context accrues; leans on restraint over
distinctiveness.

Recommendation: Keep as a considered option, especially for stewardship/privacy
messaging; its calm is a genuine differentiator. Defer to Phase 83 to judge whether
it is distinctive enough to lead.

Verdict: Defer
Confidence: Medium

<svg xmlns="http://www.w3.org/2000/svg" width="520" height="88" viewBox="0 0 520 88" role="img" aria-label="Direction 4 legibility proof — small, single-color, and dark variants">
  <defs>
    <symbol id="p4" viewBox="0 0 24 24">
      <path d="M9 7 A6 6 0 0 0 9 17" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/>
      <path d="M15.5 7 A6 6 0 0 1 15.5 17" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/>
      <circle cx="12.25" cy="12" r="2" fill="currentColor"/>
    </symbol>
  </defs>
  <use href="#p4" x="12" y="18" width="16" height="16" color="#102027"/> <!-- cw-ink 16px -->
  <use href="#p4" x="48" y="14" width="24" height="24" color="#102027"/> <!-- cw-ink mono -->
  <rect x="92" y="6" width="40" height="40" rx="6" fill="#07131a"/> <!-- cw-night inverse cell -->
  <use href="#p4" x="100" y="14" width="24" height="24" color="#fffdf8"/> <!-- cw-paper -->
  <text x="12" y="72" font-family="Inter, ui-sans-serif, system-ui, sans-serif" font-size="11" fill="#102027">16px &#183; Mono &#183; Inverse &#183; Clear-space = height of lowercase c &#183; Min-size 16px min / 24px pref, lockup 120px</text>
</svg>

### Direction 5 — Aperture-c typemark (integrated)

Primary lockup — the leading `c` of `chimeway` is hand-drawn as an open aperture
holding a teal node; `himeway` is Inter `<text>` on the same baseline so the word
reads as one unit:

<svg xmlns="http://www.w3.org/2000/svg" width="250" height="56" viewBox="0 0 250 56" role="img" aria-label="chimeway integrated typemark — the c drawn as an aperture">
  <path d="M30 22 A 9 9 0 1 0 30 36" fill="none" stroke="#102027" stroke-width="3" stroke-linecap="round"/> <!-- cw-ink the c as aperture -->
  <circle cx="31" cy="29" r="2.2" fill="#0e7c86"/> <!-- cw-teal node in the aperture -->
  <text x="34" y="38" font-family="Inter, ui-sans-serif, system-ui, sans-serif" font-size="28" font-weight="600" fill="#102027" letter-spacing="0.3">himeway</text>
</svg>

Concept: The first letter becomes the brand mark — an open `c` re-cut as an
aperture (the way in) with a single teal node resting in its mouth (one idea worked
*into* the letterform). Symbol and wordmark are literally the same object.

Pros: A genuine integrated typemark (LOGO-02) that still reads instantly as
`chimeway`; the `c`-aperture doubles as a favicon; unifies the "way in" concept
with the name in one move; distinctive yet quiet.

Cons: The hand-drawn monoline `c` runs slightly lighter than the filled Inter
letters and needs weight/metric matching against the outlined finalist in Phase 83;
at favicon size the `c`-plus-node can read like a loading spinner until tuned.

Recommendation: Carry forward as the integrated-typemark candidate — it is the
subtle, wordmark-native option. The `c`-aperture is the strongest favicon seed.

Verdict: Ship
Confidence: Medium

<svg xmlns="http://www.w3.org/2000/svg" width="520" height="88" viewBox="0 0 520 88" role="img" aria-label="Direction 5 legibility proof — small, single-color, and dark variants">
  <defs>
    <symbol id="p5" viewBox="0 0 24 24">
      <path d="M17 7.5 A 7.5 7.5 0 1 0 17 16.5" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"/>
      <circle cx="17.6" cy="12" r="1.8" fill="currentColor"/>
    </symbol>
  </defs>
  <use href="#p5" x="12" y="18" width="16" height="16" color="#102027"/> <!-- cw-ink 16px -->
  <use href="#p5" x="48" y="14" width="24" height="24" color="#102027"/> <!-- cw-ink mono -->
  <rect x="92" y="6" width="40" height="40" rx="6" fill="#07131a"/> <!-- cw-night inverse cell -->
  <use href="#p5" x="100" y="14" width="24" height="24" color="#fffdf8"/> <!-- cw-paper -->
  <text x="12" y="72" font-family="Inter, ui-sans-serif, system-ui, sans-serif" font-size="11" fill="#102027">16px &#183; Mono &#183; Inverse &#183; Clear-space = height of lowercase c &#183; Min-size 16px min / 24px pref, lockup 120px</text>
</svg>

### Direction 6 — Cornerstone-c

Primary lockup — a solid architectural `c` block (the cornerstone), a single teal
facet cut into its top edge, paired tightly with the wordmark:

<svg xmlns="http://www.w3.org/2000/svg" width="240" height="56" viewBox="0 0 240 56" role="img" aria-label="chimeway cornerstone-c primary lockup">
  <path d="M14 16 L38 16 L38 23 L23 23 L23 37 L38 37 L38 44 L14 44 Z" fill="#102027"/> <!-- cw-ink solid c cornerstone -->
  <path d="M31 16 L38 16 L38 23 L31 23 Z" fill="#0e7c86"/> <!-- cw-teal cut facet -->
  <text x="54" y="40" font-family="Inter, ui-sans-serif, system-ui, sans-serif" font-size="28" font-weight="600" fill="#102027" letter-spacing="0.3">chimeway</text>
</svg>

Concept: The initial `c` rendered as a solid cornerstone block — foundation and
brand letter in one confident form, with a single teal facet (one idea: the
owned, durable footing your app builds on). A monogram that is architecture, not
ornament.

Pros: Bold and unmistakable; a solid form that holds at 16px, mono, and inverse
without effort; nods to the name via the `c` while directly answering the earlier
"floating monogram" critique — this `c` is a structural block, not a glyph placed
beside text.

Cons: Heavier than the rest of the set; a blocky open form must keep stone-like
proportions or it can drift toward a generic bracket `[`.

Recommendation: Strong shortlist option and the most "logo-like" standalone
monogram/avatar. Excellent icon-only mark; carry forward for the finalist.

Verdict: Ship
Confidence: High

<svg xmlns="http://www.w3.org/2000/svg" width="520" height="88" viewBox="0 0 520 88" role="img" aria-label="Direction 6 legibility proof — small, single-color, and dark variants">
  <defs>
    <symbol id="p6" viewBox="0 0 24 24">
      <path d="M6 5 L18 5 L18 8.5 L9.5 8.5 L9.5 15.5 L18 15.5 L18 19 L6 19 Z" fill="currentColor"/>
    </symbol>
  </defs>
  <use href="#p6" x="12" y="18" width="16" height="16" color="#102027"/> <!-- cw-ink 16px -->
  <use href="#p6" x="48" y="14" width="24" height="24" color="#102027"/> <!-- cw-ink mono -->
  <rect x="92" y="6" width="40" height="40" rx="6" fill="#07131a"/> <!-- cw-night inverse cell -->
  <use href="#p6" x="100" y="14" width="24" height="24" color="#fffdf8"/> <!-- cw-paper -->
  <text x="12" y="72" font-family="Inter, ui-sans-serif, system-ui, sans-serif" font-size="11" fill="#102027">16px &#183; Mono &#183; Inverse &#183; Clear-space = height of lowercase c &#183; Min-size 16px min / 24px pref, lockup 120px</text>
</svg>

---

## Rejected candidates

Retained inline (NOTES-02 repo-size discipline) so the doc teaches the taste gates.
Each fails a **different** gate and is annotated with the single gate it violates.
None of these are shortlist directions — they are counter-examples, including
lessons carried from the first (fully rejected) tournament.

### Power-button c

<svg xmlns="http://www.w3.org/2000/svg" width="52" height="52" viewBox="0 0 52 52" role="img" aria-label="rejected power-button c">
  <path d="M38 15 A 15 15 0 1 1 14 15" fill="none" stroke="#102027" stroke-width="3" stroke-linecap="round"/> <!-- cw-ink -->
  <path d="M26 8 V22" fill="none" stroke="#102027" stroke-width="3" stroke-linecap="round"/>
</svg>

Reason: fails the **universal-glyph collision** gate — an open ring broken by a
vertical bar at the top is the near-universal power/standby symbol. This is the
exact trap the first tournament's open-`c` mark fell into ("looks like a power
button"); it is retained here as the boundary to stay away from.

### Iris / eye lens

<svg xmlns="http://www.w3.org/2000/svg" width="60" height="44" viewBox="0 0 60 44" role="img" aria-label="rejected iris eye lens">
  <path d="M8 22 Q30 4 52 22 Q30 40 8 22 Z" fill="none" stroke="#102027" stroke-width="3" stroke-linejoin="round"/> <!-- cw-ink -->
  <circle cx="30" cy="22" r="5" fill="#0e7c86"/> <!-- cw-teal -->
</svg>

Reason: fails the **semantic-mismatch** gate — a lens with a central node reads as
an **eye / surveillance**, the opposite of Chimeway's local-first, "your data stays
in your app" stewardship story. A technically clean mark can still carry the wrong
meaning.

### Octagon seal + bar

<svg xmlns="http://www.w3.org/2000/svg" width="52" height="52" viewBox="0 0 52 52" role="img" aria-label="rejected octagon seal with a bar">
  <path d="M34.9 10 L42 17.1 L42 27.9 L34.9 35 L24.1 35 L17 27.9 L17 17.1 L24.1 10 Z" fill="none" stroke="#102027" stroke-width="2.4" stroke-linejoin="round"/> <!-- cw-ink -->
  <path d="M23 22.5 H36" fill="none" stroke="#0e7c86" stroke-width="2.4" stroke-linecap="round"/> <!-- cw-teal -->
</svg>

Reason: fails the **wrong-connotation** gate — an octagon (the stop-sign silhouette)
crossed by a bar reads as "no entry / do-not / minus," a negative signal for a
product about reliably *delivering* and *explaining* notifications.

### Literal bell

<svg xmlns="http://www.w3.org/2000/svg" width="52" height="52" viewBox="0 0 52 52" role="img" aria-label="rejected literal bell">
  <path d="M26 8 C18 8 16 16 16 24 C16 32 12 34 12 38 H40 C40 34 36 32 36 24 C36 16 34 8 26 8 Z" fill="none" stroke="#102027" stroke-width="2.4" stroke-linejoin="round"/> <!-- cw-ink -->
  <path d="M22 38 Q26 44 30 38" fill="none" stroke="#102027" stroke-width="2.4" stroke-linecap="round"/>
</svg>

Reason: fails the **off-limits-metaphor** gate — literal bell imagery is excluded by
LOGO-06 (Chimeway is not an audio product; the brand-book §13 "chime/bell endpoint"
is superseded). Retained as the metaphor boundary; a detailed bell also collapses
into a blob at 16px.

---

## Ephemeral gallery

An uncommitted, `file://`-openable HTML gallery rendering every direction's primary
lockup + proof strip and every rejected mark at real scale is generated in the
executor session scratchpad (outside the repo tree, so it can never be committed —
D-13). Its absolute `file://` path is printed at execution time for the Phase 82
human-verify checkpoint. The committed source-of-record is this Markdown; the real
scoped brandbook HTML is Phase 84.
