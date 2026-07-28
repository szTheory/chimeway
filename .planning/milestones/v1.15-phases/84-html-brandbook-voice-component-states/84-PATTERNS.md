# Phase 84: HTML Brandbook, Voice & Component States - Pattern Map

**Mapped:** 2026-07-18
**Files analyzed:** 3 new (`brandbook/index.html`, `brandbook/brandbook.css`, `scripts/brandbook-guards.sh`)
**Analogs found:** 1 exact (guard script) / 3 total; the two web files have no in-repo HTML/CSS analog (greenfield authoring — planner uses RESEARCH code examples + `tokens.css` as the read-only source).

> This is an authoring phase, not a refactor. The single strong code analog is `scripts/logo-guards.sh` → `scripts/brandbook-guards.sh`. The book HTML/CSS have no precedent file in the repo (this is the first HTML artifact under `brandbook/`), so their "patterns" come from three read-only sources: the RESEARCH code examples (§Code Examples / Patterns 1-3), the `tokens.css` SSOT (token names to render), and the shipped logo SVGs (which to inline vs `<img>`).

---

## File Classification

| New File | Role | Data Flow | Closest Analog | Match Quality |
|----------|------|-----------|----------------|---------------|
| `scripts/brandbook-guards.sh` | test / guard | batch (grep-over-files) | `scripts/logo-guards.sh` | **exact** (same house pattern, copy scaffolding + helpers + `--scope` mode verbatim) |
| `brandbook/brandbook.css` | config / stylesheet | transform (token → layout) | `brandbook/tokens/tokens.css` (structural sibling only) + RESEARCH Patterns 2/3 | **partial** — tokens.css shows the `:root`/`[data-theme]`/`@media` shape it *consumes*, but is not itself a scoped-layout file |
| `brandbook/index.html` | component / view | request-response (static render, inline JS) | none in repo | **no analog** — greenfield; use RESEARCH §Code Examples + UI-SPEC contract |

---

## CRITICAL FINDING — D-04 inline-set is factually wrong; planner must correct it

CONTEXT.md **D-04** and the mapping prompt both assert three `currentColor` variants to inline as `<svg>`: `chimeway-mark-mono.svg`, `chimeway-logotype-mono.svg`, **and `chimeway-logotype-inverse.svg`**.

Direct inspection of the shipped Phase-83 assets contradicts this for the inverse:

| Asset | Actual fill(s) | Carries `currentColor`? | Recolors with theme? |
|-------|----------------|--------------------------|----------------------|
| `chimeway-mark-mono.svg` | `fill="currentColor"` | **YES** | yes → inline `<svg>` |
| `chimeway-logotype-mono.svg` | `fill="currentColor"` | **YES** | yes → inline `<svg>` |
| `chimeway-logotype-inverse.svg` | `fill="#fffdf8"` (paper) + `fill="#0e7c86"` (teal) | **NO — fixed color** | no (pre-baked paper-white body) |
| `chimeway-logotype.svg` | `fill="#102027"` + `fill="#0e7c86"` | no | no → `<img src>` |
| `chimeway-logotype-stacked.svg` | `fill="#102027"` + `fill="#0e7c86"` | no | no → `<img src>` |
| `chimeway-mark.svg` | `fill="#102027"` + `fill="#0e7c86"` | no | no → `<img src>` |
| `favicon/favicon.svg` | `fill="#0e7c86"` | no | no → `<link rel=icon>` / `<img>` |

**Implication for the planner:** only **two** marks actually need inline `<svg>` for theming (`chimeway-mark-mono.svg`, `chimeway-logotype-mono.svg`). The inverse is a fixed paper-on-transparent lockup — it renders correctly via `<img src>` on any dark field (which is its purpose: "reads with no backdrop" per UI-SPEC). It does **not** recolor and inlining it buys nothing. D-04's stated rationale ("marks that must recolor with the theme") applies only to the two `currentColor` files. The D-05 parity check therefore covers **exactly those two** inlined marks, not three.

---

## Pattern Assignments

### `scripts/brandbook-guards.sh` (test/guard, batch) — analog: `scripts/logo-guards.sh`

Copy the scaffolding wholesale; swap the check bodies. Every excerpt below is copy-ready.

**Header + strict mode + pass/fail/skip helpers** (`logo-guards.sh:18`, `32-35`):
```bash
set -euo pipefail

FAILED=0
pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1"; FAILED=1; }
skip() { printf 'SKIP  %s\n' "$1"; }
# ... at end:  exit "$FAILED"
```

**`--scope` git-boundary walk** (`logo-guards.sh:43-79`) — copy verbatim, change only the allow-list `case`. For Phase 84 the allowed paths are `brandbook/**` + `scripts/brandbook-guards.sh` (D-07):
```bash
if [ "${1:-}" = "--scope" ]; then
  echo "== scope-boundary check (git) =="
  stray=""
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    path="${line:3}"                              # strip 3-char porcelain prefix
    case "$path" in *" -> "*) path="${path##* -> }" ;; esac  # rename → dest
    path="${path%\"}"; path="${path#\"}"          # trim git's quotes
    case "$path" in
      brandbook/*)                        : ;;    # phase 84 book scope
      scripts/brandbook-guards.sh)        : ;;    # the guard itself
      .planning/*)                        : ;;    # bookkeeping, out of scope
      *) stray="${stray}${path}\n" ;;
    esac
  done <<EOF
$(git status --porcelain --untracked-files=all)
EOF
  if [ -n "$stray" ]; then
    fail "scope: unexpected path(s) outside brandbook/ + the guard:"
    printf '%b' "$stray" | sed 's/^/        /'
  else
    pass "scope: working tree carries only the allowed phase paths"
  fi
  exit "$FAILED"
fi
```
> Note the `<<EOF … $(git status --porcelain) … EOF` heredoc idiom and the `${line:3}` prefix-strip — reuse both exactly; they are the portable, NUL-free porcelain parse the house pattern relies on.

**Presence-gate (absent file = RED, proves the guard is wired)** (`logo-guards.sh:296-300`):
```bash
if [ ! -f "$DOC" ]; then
  fail "doc missing: '$DOC' does not exist yet (author it, then re-run)"
  exit 1
fi
```
Apply the same "missing = FAIL" posture to `brandbook/index.html` and `brandbook/brandbook.css` so the guard is RED in Wave 0 until the files exist.

**Optional-`xmllint` SKIP-when-absent** (`logo-guards.sh:186`, `204-206`, `428`, `453-455`):
```bash
if command -v xmllint >/dev/null 2>&1; then
  # ... run xmllint --noout over the file(s); fail on malformed ...
else
  skip "xmllint not on PATH — well-formedness check skipped"
fi
```

**Per-file grep helper pattern** (adapted from the `hygiene_check` / `asset_hygiene` closures, `logo-guards.sh:165-172`, `405-412`) — a reusable "assert this pattern is ABSENT" for the file://-safety negatives:
```bash
ban() {  # ban <desc> <regex> <file>  — FAIL if the pattern is present
  if grep -nEi "$2" "$3" >/dev/null 2>&1; then
    fail "file://-unsafe: $1 in $3"
    grep -nEi "$2" "$3" | sed 's/^/        /'
  fi
}
```

**The three grep families the guard must run** (D-07, RESEARCH Validation table, VALIDATION.md):

1. **file://-safety negatives over `brandbook/index.html`** — `ban` each of:
   - `fetch\(` · `XMLHttpRequest` · `type=["']module` · cross-file `<use[^>]+href=["']([^"'#]+)\.svg#` · `src=["']https?://` · `href=["']/[^>]` (root-absolute).
2. **scope-nonleak audit over `brandbook/brandbook.css`** — positive: `grep -q '@layer'` **and** `grep -q '@scope'`; then flag any bare element/`*` selector at column 0 that is not prefixed `.cwb-`/`.cw-brandbook` and not an at-rule (`@…`) or nested inside a block. D-07 explicitly upgrades VALIDATION's under-specified "custom awk" to this concrete audit — a loose audit makes BOOK-02 vacuous.
3. **section-presence positives over `brandbook/index.html`** — the nine `is-*` state tokens (`for s in hover focus active disabled loading error empty skeleton selected; do grep -q "is-$s" …; done`), `data-cwb-theme`, `luminance`, and voice/naming anchors (`docs`/`errors`/`marketing`/`cli`, `what happened`, and both `chimeway` lowercase + `Chimeway` title-case).

**D-05 parity check** (new, no direct analog — model on the token-hex loop at `logo-guards.sh:129-149`): for each of the **two** inlined marks, grep the inline `<path d="…">` out of `index.html` and assert the same `d=` string appears in the corresponding `brandbook/assets/logo/*.svg`. Concrete `d=` payloads to match live at:
- `chimeway-mark-mono.svg` — `<path fill="currentColor" d="M6 5h12l-2.5 14h-7Z"/>` (24×24 viewBox, tiny — full-string match is trivial).
- `chimeway-logotype-mono.svg` — one long `d="m27.24 39.84…"` path (~2.5 KB). Per CONTEXT D-05 discretion, match a normalized subset (e.g. first ~40 chars `m27.24 39.84-1.45 3.48q-.52.23-1.2.43`) rather than the full string, provided it fails on real drift.

**Token-hex allow-list** (`logo-guards.sh:26`) — if the guard checks any hex in the book HTML/CSS, reuse the frozen set (but note the book should contain **no** hard-coded `--cw-*` hexes at all — it reads tokens via `<link>`; a hex literal in `brandbook.css` is itself a drift smell worth a negative grep):
```bash
ALLOWED_HEX="102027 07131a fffdf8 0e7c86 d6a84f 9adbcf"
```

---

### `brandbook/brandbook.css` (config/stylesheet, transform) — analog: RESEARCH Pattern 2/3 + `tokens.css` shape

No scoped-layout CSS exists in the repo yet; this file is authored from the RESEARCH skeletons. It **consumes** `tokens.css` and must never redefine `--cw-*`.

**What `tokens.css` publishes (the read-only contract `brandbook.css` reads from)** — `brandbook/tokens/tokens.css:10-111` declares all `--cw-*` on a **bare `:root`**; `:114-140` `[data-theme="light"]`; `:144-186` `[data-theme="dark"]`; `:190-234` `@media (prefers-color-scheme: dark)`. The book CSS references these names; it does not re-declare them. Token families available to render swatches / drive states / feed the contrast matrix:
- **Primitives** (`tokens.css:12-26`): `--cw-ink #102027`, `--cw-night #07131a`, `--cw-paper #fffdf8`, `--cw-porcelain`, `--cw-line`, `--cw-muted`, `--cw-teal #0e7c86`, `--cw-blue`, `--cw-brass`, `--cw-mint`, `--cw-violet #6d5df6`, `--cw-success`, `--cw-warning`, `--cw-danger #b83232`, `--cw-code`.
- **Spacing** (`:29-35`): `--cw-space-{xs,sm,md,lg,xl,2xl,3xl}` = 4/8/16/24/32/48/64px.
- **Type** (`:36-47`): `--cw-font-family-{sans,mono}`, `--cw-font-size-{label,body,heading,display}` = 14/16/20/28px, matching line-heights, `--cw-font-weight-{regular 400,semibold 600}`.
- **Semantic aliases** (`:80-89`): `--cw-surface-bg`, `--cw-surface-panel`, `--cw-fg`, `--cw-fg-muted`, `--cw-border`, `--cw-accent` (→teal light / →mint dark), `--cw-focus` (→blue light / →brass dark), `--cw-info`.
- **Control/state layer** (`:91-108`): `--cw-surface-hover`, `--cw-surface-active`, `--cw-control-{hover,active}`, `--cw-control-disabled-{bg,fg}`, `--cw-button-primary-{bg,fg}`, `--cw-button-danger-{bg,fg}`, `--cw-link-fg`.
- **Status triads** (`:63-77` light, remapped `:170-184` dark): `--cw-status-{success,warning,danger,info,neutral}-{text,surface,border}`.

**`@layer` + `@scope` skeleton** (RESEARCH.md:159-176) — the BOOK-02 scoping shape to author:
```css
/* brandbook.css */
@layer cwb.reset, cwb.book, cwb.demo;   /* explicit order — book styles lose to nothing accidental */

@layer cwb.book {
  @scope (.cw-brandbook) {
    :scope { color: var(--cw-fg); background: var(--cw-surface-bg); font-family: var(--cw-font-family-sans); }
    .cwb-section { padding: var(--cw-space-xl); }
    .cwb-swatch  { border: var(--cw-border-width) solid var(--cw-border); border-radius: var(--cw-radius-md); }
  }
}
/* older-browser tail: plain descendant fallback under the same root class */
@layer cwb.book { .cw-brandbook .cwb-section { padding: var(--cw-space-xl); } }
```

**`.is-*` static state-forcing pattern** (RESEARCH.md:181-193, STATE-01) — each pseudo-class rule duplicated by an `.is-*` class so states render without interaction:
```css
@layer cwb.demo {
  @scope (.cw-brandbook) {
    .cwb-btn { background: var(--cw-button-primary-bg); color: var(--cw-button-primary-fg);
               border-radius: var(--cw-radius-md); transition: var(--cw-motion-fast); }
    .cwb-btn:hover,         .cwb-btn.is-hover    { background: var(--cw-control-hover); }
    .cwb-btn:active,        .cwb-btn.is-active   { background: var(--cw-control-active); }
    .cwb-btn:focus-visible, .cwb-btn.is-focus    { outline: var(--cw-focus-offset) solid var(--cw-focus);
                                                   outline-offset: var(--cw-focus-offset); }
    .cwb-btn:disabled,      .cwb-btn.is-disabled { background: var(--cw-control-disabled-bg);
                                                   color: var(--cw-control-disabled-fg); cursor: not-allowed; }
    .cwb-btn.is-selected  { background: var(--cw-surface-active); box-shadow: inset 0 0 0 2px var(--cw-accent); }
  }
}
```

**Pure-CSS skeleton shimmer** (RESEARCH.md:301-311, STATE-01) with the required reduced-motion guard:
```css
@scope (.cw-brandbook) {
  .cwb-skeleton {
    background: linear-gradient(90deg,
      var(--cw-control-disabled-bg) 25%, var(--cw-surface-hover) 37%, var(--cw-control-disabled-bg) 63%);
    background-size: 400% 100%; border-radius: var(--cw-radius-sm);
    animation: cwb-shimmer 1.4s ease-in-out infinite;
  }
  @keyframes cwb-shimmer { 0%{background-position:100% 0} 100%{background-position:-100% 0} }
  @media (prefers-reduced-motion: reduce){ .cwb-skeleton{ animation: none } }
}
```

**D-06 CSS-only "don't" wrapper** (STATE-02) — misuse rendered via a scoped `.cwb-dont` treatment around the *correct* shipped asset/token; never author a broken SVG. Author the offending treatment (background cage, cramped gaps, brass-on-paper body) purely in `brandbook.css` under `.cwb-dont`.

---

### `brandbook/index.html` (component/view, static + inline JS) — no in-repo analog

Greenfield. Author from the UI-SPEC contract + these RESEARCH excerpts.

**Relative `<link>` head (file://-safe token + book CSS reuse)** (RESEARCH.md:150-152, D-02):
```html
<link rel="stylesheet" href="tokens/tokens.css">   <!-- Phase-81 SSOT — read, never redefine -->
<link rel="stylesheet" href="brandbook.css">
```
Root element carries the scope class: `<body class="cw-brandbook">`.

**Logo embedding split (D-04, corrected per CRITICAL FINDING above):**
- Inline `<svg>` (theming, `currentColor` inherits `color: var(--cw-fg)`/`--cw-accent`): **only** `chimeway-mark-mono.svg` and `chimeway-logotype-mono.svg`.
- `<img src="assets/logo/…">`: `chimeway-logotype.svg`, `chimeway-logotype-stacked.svg`, `chimeway-mark.svg`, `chimeway-logotype-inverse.svg` (fixed paper-white lockup — renders correctly on a dark field via `<img>`), plus favicon/OG raster previews.

**Tri-state theme toggle, single inline classic `<script>`** (RESEARCH.md:262-273, D-03) — the only JS that runs under `file://`:
```html
<script>
  (function () {
    const root = document.documentElement;                 // tokens target :root
    function apply(mode) {
      if (mode === 'system') root.removeAttribute('data-theme');  // defer to @media
      else root.setAttribute('data-theme', mode);          // 'light' | 'dark'
    }
    document.querySelectorAll('[data-cwb-theme]').forEach(btn =>
      btn.addEventListener('click', () => apply(btn.dataset.cwbTheme)));
    apply('system');
  })();
</script>
```

**Live WCAG contrast matrix, inline (no library)** (RESEARCH.md:281-294, D-03) — read tokens via a painted probe so `var()` aliases + active `[data-theme]` resolve; re-run on theme flip and on `matchMedia('(prefers-color-scheme: dark)')` change:
```js
function _lin(c){ c/=255; return c <= 0.03928 ? c/12.92 : Math.pow((c+0.055)/1.055, 2.4); }
function luminance([r,g,b]){ return 0.2126*_lin(r) + 0.7152*_lin(g) + 0.0722*_lin(b); }
function ratio(fg, bg){ const L1=luminance(fg), L2=luminance(bg);
  const hi=Math.max(L1,L2), lo=Math.min(L1,L2); return (hi+0.05)/(lo+0.05); }
function tokenRGB(varName){
  const probe = document.createElement('span');
  probe.style.color = `var(${varName})`; probe.style.display='none';
  document.querySelector('.cw-brandbook').appendChild(probe);
  const m = getComputedStyle(probe).color.match(/\d+/g).map(Number);
  probe.remove(); return [m[0], m[1], m[2]];
}   // AA: >=4.5 normal, >=3 large/UI. Cross-check: ink-on-paper very high; brass-on-paper FAILs body.
```

**Content sourcing:** all voice/microcopy/do-don't copy lifts verbatim from `prompts/chimeway-brand-book.md` (cited line refs enumerated in UI-SPEC §Copywriting Contract). Section order = RESEARCH.md:134-144 (10 sections).

---

## Shared Patterns

### Dependency-free shell-guard discipline
**Source:** `scripts/logo-guards.sh` (whole file — Phases 82/83 house pattern)
**Apply to:** `scripts/brandbook-guards.sh`
`set -euo pipefail` + `pass`/`fail`/`skip` + `FAILED` accumulator + `exit "$FAILED"`; grep/sed/awk/git only; `xmllint` optional→SKIP. Missing target file = RED (proves the gate is wired).

### Zero-drift token consumption (SSOT, read-only)
**Source:** `brandbook/tokens/tokens.css` (bare `:root`/`[data-theme]`/`@media`)
**Apply to:** `brandbook.css` **and** `index.html` (and the guard's negative-grep for stray hex)
Reference `--cw-*` names; never re-declare a token value. A `#hex` literal (outside the frozen 6-value set) or a `var(` redefinition in the book is drift — guard against it. The house hard gate `git diff --exit-code chimeway_admin/priv/static/chimeway_admin.css` must stay clean.

### file://-safety as a security property (V14)
**Source:** RESEARCH §Security Domain + §1 file:// matrix; VALIDATION.md
**Apply to:** `index.html` (enforced by guard family 1)
No `fetch`/XHR/`type="module"`/cross-file `<use href>`/CDN `<script src>`/root-absolute or `https?://` asset refs. This is the milestone's primary security posture, not a preference.

### Scoped-CSS non-leak (BOOK-02)
**Source:** RESEARCH Pattern 2 (`@layer cwb.*` + `@scope (.cw-brandbook)` + `.cwb-*` + descendant fallback)
**Apply to:** `brandbook.css` (enforced by guard family 2)
Every rule lives under a layer/scope or is prefixed `.cwb-`/`.cw-brandbook`; a loose audit makes the non-leak guarantee vacuous (D-07).

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `brandbook/index.html` | component/view | request-response | First HTML artifact in the repo; no existing page to copy. Author from RESEARCH §Code Examples + UI-SPEC. |
| `brandbook/brandbook.css` | stylesheet | transform | No scoped-layout CSS exists; `tokens.css` is a token-declaration sibling (shows the shape consumed, not a layout precedent). Author from RESEARCH Patterns 2/3. |

---

## Metadata

**Analog search scope:** `scripts/`, `brandbook/` (tokens + assets), `prompts/`
**Files scanned:** `scripts/logo-guards.sh` (459 lines, full), `brandbook/tokens/tokens.css` (234 lines, full), 7 logo/favicon SVGs (fill inspection), directory listings of `assets/{logo,favicon,social}`
**No CLAUDE.md / skills dirs** present at working root — no additional project-convention overrides to fold.
**Pattern extraction date:** 2026-07-18
</content>
</invoke>
