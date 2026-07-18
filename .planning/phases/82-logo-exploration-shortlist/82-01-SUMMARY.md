---
phase: 82-logo-exploration-shortlist
plan: 01
subsystem: ui
tags: [logo, branding, svg, wordmark, keystone, optima, typography]

requires:
  - phase: 81-tokens
    provides: "brandbook/tokens/tokens.css — the --cw-* colour token set the marks draw from"
provides:
  - "notes/logo-options.md — vetted 6-direction logo shortlist (broadened metaphor families) + a Selected-Direction section recording the chosen final logotype"
  - "scripts/logo-guards.sh — Wave-0 automated acceptance gate (grep + xmllint) for the logo doc"
  - "Selected logotype: 'chimeway' in Optima (outlined SVG paths) with the i replaced by the keystone wedge (ink body + 65% teal facet); standalone two-tone keystone = icon/favicon"
affects: [phase-83-direction-selection, phase-84-html-brandbook, phase-85-repo-integration]

tech-stack:
  added: []
  patterns:
    - "Font-independent wordmarks: convert the chosen typeface to SVG <path> outlines (fontTools) so the committed logo carries no font dependency"
    - "Chrome-headless render loop for visual self-verification of every mark before human review"

key-files:
  created:
    - notes/logo-options.md
    - scripts/logo-guards.sh
  modified:
    - .planning/REQUIREMENTS.md
    - .planning/phases/82-logo-exploration-shortlist/82-CONTEXT.md

key-decisions:
  - "D-14: after the first shortlist (5 route/signal/trace marks) was rejected in full at the human checkpoint, the LOGO-06 metaphor lock was broadened to new families (logotype, aperture, geometric fan-out, keystone, containment, ledger); no-bell/music exclusion retained"
  - "Human selected Direction 1 (Keystone) as the mark"
  - "Final wordmark typeface = Optima (flared humanist); earlier rounds had accidentally rendered in the macOS system font, which read as undesigned"
  - "Integrated typemark = the i of chimeway IS the keystone wedge (ink body + teal facet at 65% width) — elegant teal accent that stays structurally identical to the icon"

patterns-established:
  - "Two-tone keystone as one consistent object: same ink-body + teal-facet appears as the wordmark's i and as the standalone favicon"
  - "Ephemeral file:// galleries + PNG contact sheets for taste review; only notes/logo-options.md + scripts/logo-guards.sh are committed"

requirements-completed: [LOGO-01, LOGO-02, LOGO-05, LOGO-06, NOTES-02]

coverage:
  - id: D1
    description: "notes/logo-options.md presents a vetted 6-direction shortlist, each with Concept/Pros/Cons/Recommendation + Verdict + Confidence + a 16px/mono/inverse proof strip, plus retained rejected candidates"
    requirement: LOGO-01
    verification:
      - kind: other
        ref: "bash scripts/logo-guards.sh notes/logo-options.md — ALL GUARDS PASSED (verdict>=5, confidence>=5, 5 proof labels>=5, rejected section, token-hex subset, no var(, hygiene, xmllint 19/19)"
        status: pass
      - kind: manual_procedural
        ref: "human-verify checkpoint (ephemeral file:// gallery) — reviewer rejected round 1, approved Keystone from the broadened set"
        status: pass
    human_judgment: true
    rationale: "16px/mono/inverse legibility, integrated-typemark judgment, and taste gates are perceptual — not textually greppable"
  - id: D2
    description: "At least one direction is a genuinely integrated typemark — the keystone worked into the i of the chimeway wordmark, not an icon beside plain type"
    requirement: LOGO-02
    verification:
      - kind: manual_procedural
        ref: "final-preview render + Selected-Direction lockup in notes/logo-options.md — the i slot carries the keystone wedge"
        status: pass
    human_judgment: true
    rationale: "'integrated vs placed-beside' is a visual/semantic judgment"
  - id: D3
    description: "Taste gates: no enclosing cage, unified mark+wordmark, no primary subtitle (LOGO-05); no literal bell/music/note, metaphor from an approved family (LOGO-06)"
    requirement: LOGO-05
    verification:
      - kind: manual_procedural
        ref: "human visual review of every shortlisted + rejected mark in the file:// gallery"
        status: pass
    human_judgment: true
    rationale: "enclosure/cohesion/imagery-meaning are perceptual gates held out of automation per 82-VALIDATION.md"
  - id: D4
    description: "scripts/logo-guards.sh Wave-0 automated gate exists, is executable, and passes against the finished doc"
    verification:
      - kind: other
        ref: "test -x scripts/logo-guards.sh; bash scripts/logo-guards.sh --scope — scope OK"
        status: pass
    human_judgment: false
---

## Accomplishments

- Shipped `scripts/logo-guards.sh` (Wave 0) — 9-check grep + optional `xmllint` gate; every logo-doc
  commit is sampled against it. Green on the final doc (19/19 SVG blocks well-formed).
- Authored `notes/logo-options.md`. The first shortlist (5 directions, all on the route/signal/trace
  metaphor) was **rejected in full** at the blocking human-verify checkpoint.
- Recorded **D-14** (amended `LOGO-06` + superseded `D-05`): reopened the metaphor aperture to six
  broadened families while retaining the no-bell/music exclusion and all hygiene/taste gates.
- Ran a **wide divergent tournament** (~18 candidates across 6 families via parallel generators,
  rendered and culled) → a fresh 6-direction shortlist (Keystone, Way/Threshold, Dispatch, Held
  Record, Aperture-c typemark, Cornerstone-c) with 4 instructive rejects (each a distinct gate).
- Human review selected **Keystone**. Follow-on refinement tournaments — lockup sizing/placement,
  wordmark typeface, "the `i` as the graphic", and a teal-amount dial — converged on the final
  logotype: **`chimeway` in Optima, outlined to font-independent SVG paths, with the `i` replaced by
  the keystone wedge (ink body + `--cw-teal` facet at 65%)**; the standalone two-tone keystone is the
  icon/favicon. Recorded in the doc's Selected-Direction section with primary / inverse / favicon SVGs.

## Notable deviations

- The plan scoped Phase 82 as *shortlist only* ("does not pick a winner; outline conversion deferred
  to Phase 83"). At the user's direction the phase went further: it **selected** Keystone and refined
  it into a specific outlined logotype. This pre-stages Phase 83's finalist work. Phase 83 still owns
  the **full asset family** (stacked/social/size-grid/do-don't) and licensing finalization; Phase 84
  the HTML brandbook.
- A useful discovery mid-phase: the wordmark had been rendering in the macOS **system font** (Inter
  was not installed), which is what read as "undesigned" — resolved by choosing Optima and outlining.

## Self-Check: PASSED

- `bash scripts/logo-guards.sh notes/logo-options.md` → ALL GUARDS PASSED
- `bash scripts/logo-guards.sh --scope` → only `notes/logo-options.md` + `scripts/logo-guards.sh`
- Human checkpoint: Keystone + Optima keystone-`i` (65% facet) approved.
