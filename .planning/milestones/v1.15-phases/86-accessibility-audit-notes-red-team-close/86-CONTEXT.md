# Phase 86: Accessibility Audit, Notes & Red-Team Close - Context

**Gathered:** 2026-07-27 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Final phase of milestone **v1.15 Brand Identity & Brand Book**. Verify accessibility
against **named WCAG 2.2 criteria on the *rendered* brand book** (not discovered late),
complete the decision/research record, and run the **milestone-close red-team** that locks
the `brandbook/`-only scope boundary.

**This is a doc/asset-only phase.** It verifies already-shipped artifacts (Phases 81–85)
and writes the record under `notes/`. It does **not** touch runtime `lib/` code, and — per
the zero-drift invariant — it does **not** patch `brandbook/tokens/tokens.css` (those hexes
are copied verbatim from the shipped `chimeway_admin.css` SSOT).

**Requirements:** A11Y-01, A11Y-02, A11Y-03, A11Y-04, A11Y-05, NOTES-01, NOTES-03, NOTES-04.

**In scope to CREATE:** `notes/accessibility-checks.md`, `notes/research.md`, and the
recorded red-team pass (`notes/red-team.md`). Plus the guard-script allowlist extension
needed to machine-enforce the scope audit.

**Out of scope (defer, do not act):** any change to `brandbook/tokens/*` primitive/semantic
values (→ ADMIN-RETHEME-01 milestone); any new binary assets; any runtime `lib/` change.
</domain>

<decisions>
## Implementation Decisions

### Contrast verification method (A11Y-01 / A11Y-02 / A11Y-05)
- **D-01:** The per-pairing table in `notes/accessibility-checks.md` is produced by a **small,
  dependency-free, re-runnable offline calc** (shell/awk, matching the repo's guard-script
  idiom) that reads hex values straight from `brandbook/tokens/tokens.css` and applies the
  **same WCAG relative-luminance formula already inlined** in `brandbook/index.html`. The
  in-page live contrast matrix is cited as the *rendered-output* proof, but is **not** the
  A11Y-05 evidence of record on its own — it only scores **8 text cells** and never covers
  the status triads, borders, focus rings, or disabled states.
  - *Rationale:* A11Y-05 requires per-pairing ratios covering 1.4.11 non-text and status
    semantics; the 8-cell matrix would silently omit exactly those surfaces (vacuous-pass
    footgun). Reproducing the in-page formula keeps numbers traceable, not asserted.
  - The table must cover **light + dark** for: every text fg/bg pair, status triads
    (text/surface/border ×5), panel/card borders, focus rings, and both disabled pairs.

### Actual findings → document-as-exempt, never patch tokens (A11Y-01 / A11Y-02)
- **D-02:** Sub-threshold pairings are recorded as **documented WCAG exemptions**, not fixed.
  Confirmed computed findings (evidence for the record):
    - **No text pair forces a change.** Only sub-4.5 text is **disabled** text
      (`--cw-control-disabled-fg` on `-bg` = **3.92:1** light) — SC 1.4.3 **exempts**
      inactive/disabled components (dark disabled = 4.92, passes anyway).
    - **All status borders fail 3:1 vs. their own surface** (light: success 1.45, warning
      1.53, danger 1.77, info 1.50, neutral 1.29) and panel border `--cw-line #d8d3c7` on
      paper = **1.47:1**, `--cw-border-strong #a9bebf` = 1.91 — these are **decorative
      boundaries** whose component identity is carried by surface fill + text + **label +
      icon** (STATE-02 "never color-alone"), so **not "required"** under SC 1.4.11.
    - **All load-bearing pairs pass:** focus rings (blue 4.78/4.86 light, brass 8.57/7.37
      dark), all status **text/surface** (5.88–7.10 light, 11+ dark), body/muted/links.
    - **Watch item (record, don't fix):** primary button **white on teal `#0e7c86` = 4.95:1**
      (also the theme-toggle active segment) — clears 4.5, but any token nudge breaks it.
  - *Rationale:* `tokens.css:3-7` primitives are verbatim from shipped `chimeway_admin.css`;
    editing them violates the TOKEN-01 zero-drift invariant (`notes/decision-log.md`
    DIV-1/DIV-3) and turns a doc phase into the deferred retheme milestone.

### Red-team recording + scope/binary audit (NOTES-03)
- **D-03:** The scope boundary is **machine-enforced**, not hand-asserted. The red-team
  **extends the existing allowlist** so the audit passes on the correct milestone tree and
  fails on anything else — `scripts/brandbook-guards.sh --scope` already does the
  `git diff --stat` + porcelain allowlist walk, and `scripts/logo-guards.sh` already
  implements the repo-size/binary budget (3 committed rasters, ≤200KB). The current `--scope`
  allowlist **excludes** the two allowed integration edits (`README.md`, `mix.exs`) and the
  new `notes/` files, so it would false-FAIL as-is and **must be widened** to exactly:
  `brandbook/**` + the two integration edits + `notes/**` + the guard/render scripts.
- **D-04:** The skeptic pass is recorded in a **new `notes/red-team.md`**, closing with the
  captured `git diff --stat` scope audit output and the repo-size/binary check result.
  - *Rationale:* A pasted manual `git diff` asserts the boundary without enforcing it — a
    future stray edit outside `brandbook/` + the two integration files would pass unnoticed
    (the precise footgun NOTES-03 exists to close).

### CVD verification + research record (A11Y-04 / A11Y-03 / NOTES-01 / NOTES-04)
- **D-05:** Colorblind safety (A11Y-04) is argued primarily from the **architectural
  "never color-alone" property** (every status = surface + text + **label + icon**), backed
  by a **documented manual pass through Chrome DevTools "Emulate vision deficiencies"** on the
  rendered `file://` page, recorded as a checklist in `notes/accessibility-checks.md`.
  **No CVD tooling or binary/screenshot artifacts are added** (milestone forbids binaries).
- **D-06:** A11Y-03 (focus visible/not obscured SC 2.4.7/2.4.11, reduced-motion SC 2.3.3,
  target size ≥24px SC 2.5.8) is verified against the **rendered** output and recorded. Known
  in-code satisfactions: reduced-motion honored (`brandbook.css` `prefers-reduced-motion`),
  primary `.cwb-btn` ≥2.5rem. Known **borderline items to adjudicate against the SC 2.5.8
  spec text**: inline jump-nav anchors (~22px tall) and theme-toggle segments — apply the
  inline/essential exceptions if they qualify, else record as a finding.
- **D-07:** `notes/research.md` follows the established `notes/decision-log.md` voice —
  sourced claims with dispositions and confidence — citing WCAG 2.2 SC text plus 2–3 mature
  design-system analogues. Every major recommendation across the notes carries
  pros/cons/tradeoffs, an analogue, implementation cost, ship/reject/defer, and confidence
  (NOTES-01 cohesive, not a buffet).

### Claude's Discretion
- Exact filename/shape of the offline contrast calc (standalone `scripts/*.sh` vs. a function
  in `brandbook-guards.sh`), provided it is dependency-free and its output is quoted into
  `notes/accessibility-checks.md`.
- Whether the red-team transcript lives in a dedicated `notes/red-team.md` (preferred, D-04)
  or is folded — planner may consolidate if it keeps the `git diff --stat` + binary check
  verbatim and machine-enforced.
- Whether the allowlist widening (D-03) is a change to the default `--scope` list or a new
  `--milestone-scope` mode, provided the boundary is enforced (not just asserted).

### Folded Todos
None — `todo.match-phase 86` returned 0 matches.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/REQUIREMENTS.md` — A11Y-01..05, NOTES-01/03/04 (acceptance criteria).
- `notes/decision-log.md` — established notes voice + the TOKEN-01 zero-drift invariant and
  DIV-1..DIV-7 divergence ledger (why tokens must not be patched).
- `notes/logo-options.md` — NOTES-01 recommendation format precedent (pros/cons/analogue/
  cost/ship-defer-reject/confidence).
- `brandbook/index.html` — rendered output under audit; the inline live contrast matrix +
  inline WCAG luminance formula to reproduce offline.
- `brandbook/brandbook.css` — component states, focus rings, reduced-motion, target sizes,
  status label+icon enforcement (the "never color-alone" architecture).
- `brandbook/tokens/tokens.css` — SSOT hexes to verify (light/dark/system); DO NOT edit.
- `scripts/brandbook-guards.sh` — `--scope` git-diff/allowlist walk to extend (D-03).
- `scripts/logo-guards.sh` — repo-size/binary budget block reused for the NOTES-03 audit.
- `.planning/phases/84-html-brandbook-voice-component-states/84-UI-SPEC.md` — design contract:
  status triads, "never color-alone", component states, security posture.
- `.planning/phases/84-html-brandbook-voice-component-states/84-RESEARCH.md` — inline WCAG
  relative-luminance formula + file:// safety basis.
- `.planning/phases/84-html-brandbook-voice-component-states/84-VALIDATION.md` — guard-script
  design the brandbook guards were modeled on.
- `README.md` + `mix.exs` — the **two allowed integration edits** (Phase 85 D-01 header
  lockup; D-02 ExDoc `:logo`/`:favicon`) that the scope audit must permit alongside
  `brandbook/**` and `notes/**`.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **In-page live contrast matrix + WCAG luminance JS** (`brandbook/index.html`) — reproduce
  its formula offline for the authoritative per-pairing table.
- **`scripts/brandbook-guards.sh --scope`** — `git diff --stat` + porcelain allowlist walk
  (the NOTES-03 scope machinery already exists; only the allowlist needs widening).
- **`scripts/logo-guards.sh` binary budget** — repo-size/binary check (3 rasters, ≤200KB
  ceiling) with a comment that it "feeds NOTES-03"; reuse verbatim.
- **`brandbook/tokens/tokens.css` status triads** — success/warning/danger/info/neutral
  text/surface/border, focus-ring, borders, dark-theme values already defined.

### Established Patterns
- **Zero-drift token invariant** — primitives copied verbatim from shipped admin CSS; changes
  are a separate deferred milestone. This is the hard constraint that makes D-02
  (document-as-exempt) the only in-scope disposition for sub-threshold pairs.
- **"Never color-alone" status architecture** — every status carries label + icon
  (`brandbook.css`, `84-UI-SPEC.md`); this is the primary A11Y-04 defense.
- **Guard-script idiom** — `pass`/`fail`/`skip` helpers, `--scope` boundary mode, optional
  tools that SKIP when absent, dependency-free. New contrast calc should mirror it.

### Integration Points
- The scope audit must permit exactly `brandbook/**` + `README.md` + `mix.exs` + `notes/**`
  + the guard/render scripts. The current allowlist omits the integration edits and `notes/`.
</code_context>

<specifics>
## Specific Ideas

- Recommendation format across all notes must mirror `notes/decision-log.md` and
  `notes/logo-options.md`: sourced claims, pros/cons/tradeoffs, analogue, implementation cost,
  ship/reject/defer, confidence (NOTES-01 cohesive, not a buffet).
- CVD check = Chrome DevTools "Emulate vision deficiencies" on the rendered `file://` page,
  recorded as a checklist — no committed simulated screenshots.
</specifics>

<deferred>
## Deferred Ideas

- **Token contrast improvements** (raising status-border ratios to 3:1, tightening the 4.95:1
  primary-button pair) — deferred to the **ADMIN-RETHEME-01** milestone; editing tokens here
  violates the v1.15 zero-drift invariant.
- **Extending the in-page live matrix** to score all status/border/focus cells — a possible
  future enhancement; not required (the offline calc is the phase's evidence of record).

### Reviewed Todos (not folded)
None — no pending todos matched this phase.

### Flagged for the phase-researcher (citation basis, not execution blockers)
- Exact WCAG 2.2 normative exemption wording for SC 1.4.3 (inactive/disabled components) and
  SC 1.4.11 (non-required/decorative boundaries) — quote, don't paraphrase, in `research.md`.
- SC 2.5.8 (24px target size) applicability to the borderline inline jump-nav anchors (~22px)
  and theme-toggle segments — needs the spec's inline/essential exception text.
- 2–3 mature design-system analogues for how they document contrast exemptions and CVD
  verification (NOTES-04 precedent).
</deferred>
