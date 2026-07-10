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
