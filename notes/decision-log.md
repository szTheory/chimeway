# Chimeway Design-Token Divergence Log

**Date:** 2026-07-09
**Decision status:** reconciliation phase — documented/deferred, not patched
**Scope:** sub-primitive divergences from shipped `chimeway_admin/priv/static/chimeway_admin.css`

This log records every named sub-primitive divergence (DIV-1..DIV-7) between the shipped
`chimeway_admin.css` token layer (the SSOT) and the brand-book intent. Per D-12 / TOKEN-04,
divergences are **RECORDED**, not resolved this phase: each carries both-side line refs, a
`DOCUMENTED` or `DEFERRED` disposition, and closes with the zero-drift invariant proving the
shipped CSS was never patched. The live re-theme is the separate **ADMIN-RETHEME-01** milestone.

## Sources

- `chimeway_admin/priv/static/chimeway_admin.css` — shipped SSOT; the authoritative token layer (`@layer cw.tokens`, lines 3-222). All "shipped side" line refs point here.
- `chimeway_admin/assets/css/chimeway_admin.css` — 3-line `@import` wrapper of the SSOT above; re-exported for the packaged asset, never an independent source.
- `prompts/chimeway-brand-book.md` — brand intent (palette table, status-pill mapping); the "brand-book / intent side" of each divergence.
- `.planning/phases/81-design-tokens-reconciliation-documentation/81-CONTEXT.md` — locked decisions D-01..D-12.
- `.planning/phases/81-design-tokens-reconciliation-documentation/81-RESEARCH.md` — divergence ledger inputs (DIV-1..DIV-7 with both-side line refs and dispositions).
- `.planning/REQUIREMENTS.md` — TOKEN-01..TOKEN-05.

## Divergence Summary

| # | Divergence | Shipped side | Brand-book / intent side | Disposition |
|---|-----------|--------------|---------------------------|-------------|
| DIV-1 | `--cw-radius-sm` = 5px vs 4px brand intent | `chimeway_admin.css:40` (`5px`) | 4px brand intent | **DEFERRED** — keep shipped 5px; patch = ADMIN-RETHEME-01 |
| DIV-2 | Missing `--cw-info` primitive | absent in shipped (grep: zero matches) | info→blue `#2d6cdf` (`chimeway-brand-book.md:612`) | **DOCUMENTED** — add `--cw-info: var(--cw-blue)` alias (D-06), no new hex |
| DIV-3 | `--cw-status-info-*` triad is teal-hued, not blue | `chimeway_admin.css:60-62` (`#0e5f67/#e8f6f5/#94d4d7`) | info = blue `#2d6cdf` (`chimeway-brand-book.md:612`) | **DEFERRED** — copy teal verbatim; blue-info reconciliation = ADMIN-RETHEME-01 |
| DIV-4 | Status-pill mapping conflicts | no `sending`/`cancelled`/`expired` triads in shipped | Sending→violet (`:674`), Cancelled→muted/neutral outline (`:678`), Expired→warning outline (`:679`) | **DOCUMENTED / DEFERRED** — do not invent triads; log intended mapping |
| DIV-5 | Net-new motion representation | shorthand `120ms ease-out` / `80ms ease-out` (`:48-49`) | DTCG needs duration + easing split | **DOCUMENTED** — CSS keeps shorthand verbatim; JSON decomposes |
| DIV-6 | Net-new z-index DTCG tokens | `--cw-z-sidebar: 10` / `--cw-z-focus: 50` (`:46-47`) | first expressed in DTCG | **DOCUMENTED** — verbatim, `$type: number` |
| DIV-7 | Net-new border-width dimension | no border-width in shipped (only `--cw-line` color, `--cw-admin-border`, `--cw-border-strong`) | TOKEN-03 lists "border" as a required family | **DOCUMENTED** — add `--cw-border-width: 1px` least-surprise default |

---

### DIV-1: `--cw-radius-sm` = 5px vs 4px brand intent — DEFERRED

- **Shipped side:** `--cw-radius-sm: 5px` (`chimeway_admin.css:40`)
- **Brand-book / intent side:** 4px small-radius intent (`prompts/chimeway-brand-book.md`, radius scale)
- **Disposition:** DEFERRED — the shipped 5px value is copied verbatim; the TOKEN-01 zero-drift invariant outranks the 4px intent this phase. Patching the shipped small radius to 4px is the ADMIN-RETHEME-01 milestone's job.
- **Zero-drift invariant:** `git diff --exit-code chimeway_admin/priv/static/chimeway_admin.css chimeway_admin/assets/css/chimeway_admin.css` → exit 0

### DIV-2: Missing `--cw-info` primitive — DOCUMENTED

- **Shipped side:** no `--cw-info` token exists (grep confirms zero matches in `chimeway_admin.css`)
- **Brand-book / intent side:** the brand book maps info→blue `#2d6cdf` (`chimeway-brand-book.md:612`)
- **Disposition:** DOCUMENTED — added as `--cw-info: var(--cw-blue)` (D-06), a net-new alias of the existing blue primitive. No new hex is introduced; the value resolves to the already-shipped `#2d6cdf`.
- **Zero-drift invariant:** `git diff --exit-code chimeway_admin/priv/static/chimeway_admin.css chimeway_admin/assets/css/chimeway_admin.css` → exit 0

### DIV-3: `--cw-status-info-*` triad is teal-hued, not blue — DEFERRED

- **Shipped side:** `--cw-status-info-text: #0e5f67`, `--cw-status-info-surface: #e8f6f5`, `--cw-status-info-border: #94d4d7` (`chimeway_admin.css:60-62`) — a teal-hued triad
- **Brand-book / intent side:** the brand book intends info = blue `#2d6cdf` (`chimeway-brand-book.md:612`)
- **Disposition:** DEFERRED — the teal triad is copied verbatim (zero-drift outranks). Reconciling the info status triad to a blue-based set is the ADMIN-RETHEME-01 milestone. Note: DIV-2's `--cw-info` alias (→blue) is distinct from this teal status triad; they are intentionally not unified this phase.
- **Zero-drift invariant:** `git diff --exit-code chimeway_admin/priv/static/chimeway_admin.css chimeway_admin/assets/css/chimeway_admin.css` → exit 0

### DIV-4: Status-pill mapping conflicts — DOCUMENTED / DEFERRED

- **Shipped side:** the shipped token layer provides only the `success` / `warning` / `danger` / `info` / `neutral` status triads (`chimeway_admin.css:51-65`). There are **no** `sending`, `cancelled`, or `expired` triads.
- **Brand-book / intent side:** the brand-book status-pill mapping intends `Sending`→violet (`chimeway-brand-book.md:674`), `Cancelled`→muted / neutral outline (`:678`), `Expired`→warning outline (`:679`).
- **Disposition:** DOCUMENTED / DEFERRED — the intended mapping is recorded here for the future STATE/component phases, but no new triads are invented this phase (inventing `sending`/`cancelled`/`expired` hex triads would violate the zero-drift invariant). Live pill-remapping is deferred to ADMIN-RETHEME-01 and the downstream component work.
- **Zero-drift invariant:** `git diff --exit-code chimeway_admin/priv/static/chimeway_admin.css chimeway_admin/assets/css/chimeway_admin.css` → exit 0

### DIV-5: Net-new motion representation — DOCUMENTED

- **Shipped side:** `--cw-motion-fast: 120ms ease-out`, `--cw-motion-pressed: 80ms ease-out` (`chimeway_admin.css:48-49`) — CSS transition shorthands (duration + easing keyword), not pure durations.
- **Brand-book / intent side:** DTCG 2025.10 has no transition-shorthand scalar; the mirror must decompose each into a `duration` token plus an easing note.
- **Disposition:** DOCUMENTED — the CSS keeps the `120ms ease-out` / `80ms ease-out` shorthand verbatim (zero-drift); only the `tokens.json` mirror decomposes each into a `duration` token (`{ "value": 120, "unit": "ms" }`) and notes the `ease-out` easing keyword in `$description` (rather than hard-coding a `cubicBezier`). Values are sourced verbatim from the shipped shorthands; this is a net-new *representation*, not a value change.
- **Zero-drift invariant:** `git diff --exit-code chimeway_admin/priv/static/chimeway_admin.css chimeway_admin/assets/css/chimeway_admin.css` → exit 0

### DIV-6: Net-new z-index DTCG tokens — DOCUMENTED

- **Shipped side:** `--cw-z-sidebar: 10`, `--cw-z-focus: 50` (`chimeway_admin.css:46-47`) — already exist in the shipped CSS as plain numbers.
- **Brand-book / intent side:** these z-index tokens are expressed in DTCG for the first time in the `tokens.json` mirror.
- **Disposition:** DOCUMENTED — copied verbatim with `$type: number`. No value change; only a first-time DTCG expression of already-shipped values.
- **Zero-drift invariant:** `git diff --exit-code chimeway_admin/priv/static/chimeway_admin.css chimeway_admin/assets/css/chimeway_admin.css` → exit 0

### DIV-7: Net-new border-width dimension — DOCUMENTED

- **Shipped side:** no border-*width* dimension exists in shipped (grep: only the `--cw-line` color, the `--cw-admin-border` alias, and `--cw-border-strong` color — all colors, not widths).
- **Brand-book / intent side:** TOKEN-03 lists "border" as a required token family, which implies a border-width dimension in the generalized set.
- **Disposition:** DOCUMENTED — a net-new `--cw-border-width: 1px` least-surprise default is added, flagged net-new. This width dimension is **distinct** from the `--cw-border` color alias (D-04, → `--cw-line`); the two share the "border" name root but are different `$type`s (dimension vs color).
- **Zero-drift invariant:** `git diff --exit-code chimeway_admin/priv/static/chimeway_admin.css chimeway_admin/assets/css/chimeway_admin.css` → exit 0

---

## Validation Commands

```bash
# All seven divergence ids are recorded
for n in 1 2 3 4 5 6 7; do grep -q "DIV-$n" notes/decision-log.md || echo "missing DIV-$n"; done

# Both dispositions are used
grep -q 'DOCUMENTED' notes/decision-log.md && grep -q 'DEFERRED' notes/decision-log.md

# The zero-drift invariant (naming both admin CSS files) appears once per entry (>= 7)
[ "$(grep -c 'git diff --exit-code chimeway_admin/priv/static/chimeway_admin.css chimeway_admin/assets/css/chimeway_admin.css' notes/decision-log.md)" -ge 7 ]

# DEFERRED items point to the follow-on milestone
grep -q 'ADMIN-RETHEME-01' notes/decision-log.md

# HARD GATE — the shipped admin CSS (SSOT + wrapper) is unmodified
git diff --exit-code chimeway_admin/priv/static/chimeway_admin.css chimeway_admin/assets/css/chimeway_admin.css
```

## Scope Guard

This phase **documents and defers** — it never patches the shipped admin CSS. The hard gate over
both admin CSS files (the `priv/static` SSOT and its `assets/css` `@import` wrapper) is:

```bash
git diff --exit-code chimeway_admin/priv/static/chimeway_admin.css chimeway_admin/assets/css/chimeway_admin.css
```

exit 0 proves neither file was touched. All live sub-primitive reconciliation (radius-sm 4px,
blue-info triad, status-pill remapping) belongs to the **ADMIN-RETHEME-01** milestone, which
consumes this log as its provenance record.

---

## Logo Direction Ratification

**Date:** 2026-07-18
**Decision status:** RATIFIED (finalist selected in Phase 82; formally recorded + human-gated here)
**Scope:** the shipped `chimeway` brand-mark direction and its wordmark typeface, plus the INTEG-03 wiring boundary

This section is the written record for **Phase 83 Success Criterion #1** — "the user selects a
direction at an explicit checkpoint, and the choice (with ship/defer rationale) is recorded in
`notes/decision-log.md`." The direction is **not re-opened** here: Phase 82 already ran the metaphor
tournament and selected the finalist. Phase 83 ships the mark-derived asset family, records the
ratification, and gates the whole family at a blocking human perceptual checkpoint (16px / mono /
inverse / favicon / OG legibility).

### Sources

- `notes/logo-options.md` — the vetted shortlist and the embedded finalist SVGs: primary logotype (L41), inverse (L45), icon-only keystone (L49). The "Rejected" directions and their gate-failure reasons live here.
- `.planning/phases/82-logo-exploration-shortlist/82-01-SUMMARY.md` — the **D-14** lineage: the first route/signal/trace shortlist was rejected in full at the human checkpoint, the LOGO-06 metaphor lock was broadened to six families, and the **Keystone** direction emerged as the finalist.
- `.planning/ROADMAP.md` — Phase 83 Success Criteria #1-#4 (direction recorded; full lockup family shipped; 16px/mono/inverse verified; favicon + OG derived from the mark, not the lockup resized).
- `.planning/REQUIREMENTS.md` — **LOGO-03** (primary lockup + wordmark), **LOGO-04** (icon / mono / inverse / simplified-favicon family), **INTEG-03** (favicon assets + wiring handoff).
- `.planning/phases/83-.../83-02-SUMMARY.md` — the OFL face selection + fontTools re-cut of the wordmark.

### Ratified direction — Keystone

- **Shipped side:** the **Keystone** direction is RATIFIED as the chimeway identity. The two-tone keystone (a `--cw-ink #102027` body + a single `--cw-teal #0e7c86` facet at the right ~65% width) ships standalone as the icon mark and integrated as the keystone-`i` inside the wordmark. Shipped family: `brandbook/assets/logo/{chimeway-logotype,chimeway-logotype-mono,chimeway-logotype-inverse,chimeway-logotype-stacked,chimeway-mark,chimeway-mark-mono}.svg`, the simplified `brandbook/assets/favicon/favicon.svg` (+ `favicon.ico` 16/32/48 and `apple-touch-icon.png` 180×180), and the social card `brandbook/assets/social/chimeway-og.{svg,png}`.
- **Lineage:** selected in Phase 82 under **D-14** (see `82-01-SUMMARY.md`) — not re-explored here. This ratification satisfies ROADMAP Phase 83 SC #1 and closes **LOGO-03 / LOGO-04**.
- **Disposition:** SHIP. The favicon is a **deliberately-simplified** keystone tuned to read at 16px (a bolder, larger-in-box silhouette derived from `chimeway-mark.svg`), **not** the wordmark lockup naively resized (ROADMAP SC #4 / RESEARCH Anti-Pattern). The OG card is composed from the mark + re-cut wordmark on a `--cw-paper #fffdf8` field with no enclosing cage.

### Wordmark typeface — RE-CUT in Marcellus (Optima retired)

- **Shipped side:** the wordmark is RE-CUT in **Marcellus**, license **SIL Open Font License 1.1 (OFL-1.1)** (Brian J. Bonislawsky DBA Astigmatic / AOETI; from Google Fonts `ofl/marcellus/Marcellus-Regular.ttf`). Only the outlined `<path>` geometry ships in-repo; the `.ttf` was an ephemeral build input (scratchpad, never committed).
- **Brand rationale:** Marcellus is a flared humanist glyphic face whose tapered stroke terminals rhyme with the keystone wedge — the closest libre analog to Optima's category.
- **Disposition:** RE-CUT / Optima RETIRED. OFL-1.1 explicitly permits redistributing outlined glyph paths in a public OSS repo, resolving the Optima redistribution-licensing risk (RESEARCH Pitfall 5 / Q1) decisively. The Phase-82 macOS-Optima outlines were re-cut via fontTools, not shipped.

### Ship / defer / reject rationale — the other explored directions

- **Ship:** **Keystone** — the finalist (above).
- **Defer / documented:** the five other Phase-82 shortlisted directions — **Way/Threshold, Dispatch, Held Record, Aperture-`c` typemark, Cornerstone-`c`** — are coherent but not the shipped identity. They remain documented in `notes/logo-options.md` (with their 16px / Mono / Inverse / Clear-space / Min-size proofs) as the recorded alternative directions; no assets ship for them.
- **Reject:** the original route/signal/trace shortlist (rejected in full at the Phase 82 checkpoint under D-14) and the four instructive rejects recorded in `notes/logo-options.md` — each failed a distinct gate (legibility, metaphor, taste, or the no-bell/music exclusion). Their `Reason:` / `Failed:` lines stay in `notes/logo-options.md`.

### INTEG-03 boundary — assets ship here, wiring is Phase 85

**INTEG-03 boundary:** Phase 83 ships the favicon assets + the ready-to-paste wiring snippet **only**.
The actual `README` / `mix.exs` edits are **Phase 85** — do NOT edit `README.md` or `mix.exs` in this phase.

Ready-to-paste favicon `<link>` set (HTML `<head>`; adjust the href base to the docs asset root):

```html
<link rel="icon" href="/assets/favicon/favicon.ico" sizes="any">
<link rel="icon" href="/assets/favicon/favicon.svg" type="image/svg+xml">
<link rel="apple-touch-icon" href="/assets/favicon/apple-touch-icon.png">
<meta property="og:image" content="/assets/social/chimeway-og.png">
```

Ready-to-paste ExDoc `mix.exs` `docs()` note (Phase 85 wires this — shown here, not applied):

```elixir
# mix.exs — def project / docs: (Phase 85)
docs: [
  # ...
  logo: "brandbook/assets/logo/chimeway-mark.svg",
  # Favicon: copy brandbook/assets/favicon/* into the ExDoc output (doc/assets/)
  # and reference them via the <link> set above; wire the OG card similarly.
]
```

### Validation Commands

```bash
# The full asset-family gate: all seven SVGs + three rasters present and passing
# (presence / token-hex / hygiene / xmllint / viewBox / inverse-no-backdrop /
# raster-dims / binary-budget), and the scope-boundary allowlist.
bash scripts/logo-guards.sh --assets && bash scripts/logo-guards.sh --scope

# The ratification section is present in this log.
grep -q 'Logo Direction Ratification' notes/decision-log.md

# The OFL face + license are recorded here.
grep -q 'Marcellus' notes/decision-log.md && grep -q 'OFL-1.1' notes/decision-log.md
```
