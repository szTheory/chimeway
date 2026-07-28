#!/usr/bin/env bash
#
# brandbook-guards.sh — Wave 0 automated acceptance gate for Phase 84
# (html-brandbook-voice-component-states).
#
# Dependency-free: grep / sed / awk / git only; xmllint is optional and
# degrades to SKIP when absent. This script — not any inline command — is the
# canonical automated gate every Phase-84 wave invokes (D-07).
#
# It runs SEVEN check families plus a git scope-boundary mode:
#   1. file://-safety negatives over brandbook/index.html — no fetch/XHR,
#      no type="module", no cross-file <use href>, no remote/root-absolute refs.
#   2. scope-nonleak audit over brandbook/brandbook.css — @layer + @scope
#      present, no bare column-0 element/`*` selector, no non-token #hex
#      literal (BOOK-02 non-leak made non-vacuous per D-07).
#   3. section-presence positives over brandbook/index.html — the eight `.is-*`
#      state tokens plus `.cwb-skeleton`, theme toggle + live contrast matrix
#      anchors, voice-context anchors, error-template phrase, brand casing.
#   4. D-05 logo-parity — the TWO inlined marks' `d=` paths are bound to the
#      brandbook/assets/logo/*.svg SSOT.
#   5. selector-coverage — every `cwb-*` class used in brandbook/index.html has
#      a matching selector in brandbook.css (catches the Wave-1/Wave-2 class
#      mismatch that shipped an unstyled nav past presence-only checks).
#   6. theme-resolution — brandbook/tokens/tokens.css gates its
#      prefers-color-scheme block on `:root:not([data-theme])` and qualifies its
#      `[data-theme]` overrides as `:root[data-theme]`, so an explicit toggle
#      choice outranks the OS preference (the "light does nothing under a dark
#      OS" bug). Presence-only checks could never catch this.
#   7. adaptive-logo coverage — each fixed-color lockup renders NATIVELY in both
#      themes via a light (ink) + inverse (paper) <img> pair that swaps on the
#      toggle: the derived inverse assets exist and carry zero ink, every lockup
#      ships both .cwb-logo--light and .cwb-logo--dark, and brandbook.css swaps
#      them on the same theme-resolution the tokens use. Catches "a fixed-color
#      lockup with no dark variant" (the dark-mode logo breakage) without pinning
#      a light tile in the dark UI.
#
# D-04 RECONCILIATION (factual correction): CONTEXT D-04 asserts THREE
# currentColor marks are inlined. Direct asset inspection shows only TWO carry
# `fill="currentColor"` and recolor with theme — chimeway-mark-mono.svg and
# chimeway-logotype-mono.svg. chimeway-logotype-inverse.svg is a FIXED-color
# paper-on-transparent lockup (fill="#fffdf8"/#0e7c86), rendered via <img> and
# NOT parity-checked. Family 4 therefore covers exactly two marks.
#
# Presence-gate: an absent brandbook/index.html or brandbook/brandbook.css is
# RED ("author it, then re-run"). This is intended — it keeps the gate RED
# through Waves 1-3 and proves the gate is wired, not a defect.
#
# Usage:
#   scripts/brandbook-guards.sh            # run the four check families
#   scripts/brandbook-guards.sh --scope    # git scope-boundary check
#
# Exit status: 0 if every check passes, non-zero if ANY check fails.
#
set -euo pipefail

# ----------------------------------------------------------------------------
# Allowed token-hex set (the --cw-* primitive values). This is the ONLY place a
# color literal is permitted to appear in this script:
#   ink #102027 · night #07131a · paper #fffdf8 · teal #0e7c86
#   brass #d6a84f · mint #9adbcf
# A #hex in brandbook.css outside this set is a token-drift smell (family 2).
# ----------------------------------------------------------------------------
ALLOWED_HEX="102027 07131a fffdf8 0e7c86 d6a84f 9adbcf"

INDEX_HTML="brandbook/index.html"
BOOK_CSS="brandbook/brandbook.css"
TOKENS_CSS="brandbook/tokens/tokens.css"
MARK_MONO="brandbook/assets/logo/chimeway-mark-mono.svg"
LOGOTYPE_MONO="brandbook/assets/logo/chimeway-logotype-mono.svg"

FAILED=0
pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1"; FAILED=1; }
skip() { printf 'SKIP  %s\n' "$1"; }

# ----------------------------------------------------------------------------
# --scope : assert the working tree carries no stray phase edits beyond the
# v1.15 Brand Identity & Brand Book milestone boundary (NOTES-03 / Phase 86 D-03).
# The allowlist is EXACTLY:
#   brandbook/**                    the brandbook package (all phases)
#   README.md                       Phase 85 D-01 header lockup integration edit
#   mix.exs                         Phase 85 D-02 ExDoc :logo/:favicon integration edit
#   notes/**                        the milestone record set (options/checks/research/red-team)
#   scripts/brandbook-guards.sh     this guard
#   scripts/logo-guards.sh          the sibling guard + NOTES-03 binary budget
#   scripts/render-svg-png.sh       the Phase 83 raster render helper
#   scripts/contrast-audit.sh       the Phase 86-01 offline WCAG contrast calc
#   .planning/**                    bookkeeping, out of phase scope
# Any other path is stray and FAILs (deny-by-default `*)` branch). No broad glob
# (no bare scripts/*, no top-level *): an over-broad allowlist silently defeats
# the audit. Copies the logo-guards.sh porcelain walk verbatim, changing only
# the allow-list `case` (D-07).
# ----------------------------------------------------------------------------
if [ "${1:-}" = "--scope" ]; then
  echo "== scope-boundary check (git) =="
  git diff --stat || true
  stray=""
  # --porcelain covers staged + unstaged + untracked; keep it line-based for
  # portability (no NUL parsing).
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    # Strip the 3-char porcelain status prefix (XY + space).
    path="${line:3}"
    # Handle rename "old -> new" by taking the destination.
    case "$path" in
      *" -> "*) path="${path##* -> }" ;;
    esac
    # Trim surrounding quotes git adds for unusual paths.
    path="${path%\"}"; path="${path#\"}"
    case "$path" in
      brandbook/*)                  : ;;  # brandbook package scope
      README.md)                    : ;;  # Phase 85 D-01 header lockup integration edit
      mix.exs)                      : ;;  # Phase 85 D-02 ExDoc :logo/:favicon integration edit
      notes/*)                      : ;;  # milestone record set (incl. this red-team pass)
      scripts/brandbook-guards.sh)  : ;;  # this guard
      scripts/logo-guards.sh)       : ;;  # sibling guard + NOTES-03 binary budget
      scripts/render-svg-png.sh)    : ;;  # Phase 83 raster render helper
      scripts/contrast-audit.sh)    : ;;  # Phase 86-01 offline WCAG contrast calc
      .planning/*)                  : ;;  # bookkeeping, out of phase scope
      *) stray="${stray}${path}\n" ;;
    esac
  done <<EOF
$(git status --porcelain --untracked-files=all)
EOF
  if [ -n "$stray" ]; then
    fail "scope: unexpected path(s) outside the milestone allowlist:"
    printf '%b' "$stray" | sed 's/^/        /'
  else
    pass "scope: working tree carries only the allowed phase paths"
  fi
  [ "$FAILED" -eq 0 ] && echo "== scope OK ==" || echo "== scope FAILED =="
  exit "$FAILED"
fi

# ----------------------------------------------------------------------------
# ban <desc> <regex> <file> — FAIL if the pattern is PRESENT in the file.
# (The literal unsafe regexes live only inside this guard, which never greps
# itself, so authoring them here is safe.)
# ----------------------------------------------------------------------------
ban() {
  local desc="$1" pat="$2" file="$3"
  [ -f "$file" ] || return 0
  if grep -nEi "$pat" "$file" >/dev/null 2>&1; then
    fail "file://-unsafe: $desc in $file"
    grep -nEi "$pat" "$file" | sed 's/^/        /'
  fi
}

# ----------------------------------------------------------------------------
# need <desc> <regex> <file> — FAIL if the pattern is ABSENT from the file.
# ----------------------------------------------------------------------------
need() {
  local desc="$1" pat="$2" file="$3"
  [ -f "$file" ] || return 0
  if grep -qE "$pat" "$file"; then
    pass "present: $desc"
  else
    fail "missing: $desc (expected /$pat/ in $file)"
  fi
}

echo "== brandbook-guards =="

# ----------------------------------------------------------------------------
# Presence-gate: absent book files are RED (proves the gate is wired). Keeps
# the guard RED through Waves 1-3 until index.html + brandbook.css both exist.
# ----------------------------------------------------------------------------
if [ ! -f "$INDEX_HTML" ]; then
  fail "missing: '$INDEX_HTML' does not exist yet (author it, then re-run)"
fi
if [ ! -f "$BOOK_CSS" ]; then
  fail "missing: '$BOOK_CSS' does not exist yet (author it, then re-run)"
fi

# ============================================================================
# Family 1: file://-safety negatives over brandbook/index.html
# No cross-origin/opaque-origin load can succeed under file://, so any such ref
# is dead code AND a supply-chain seam (T-84-01). Ban them outright.
# ============================================================================
if [ -f "$INDEX_HTML" ]; then
  echo "-- family 1: file://-safety negatives ($INDEX_HTML) --"
  before=$FAILED
  ban "network fetch() call"           'fetch[[:space:]]*\('                              "$INDEX_HTML"
  ban "XMLHttpRequest constructor"     'XMLHttpRequest'                                   "$INDEX_HTML"
  ban 'type="module" script'           'type[[:space:]]*=[[:space:]]*["'"'"']module'      "$INDEX_HTML"
  ban "cross-file <use href> sprite"   '<use[^>]+href[[:space:]]*=[[:space:]]*["'"'"'][^"'"'"'#]+\.svg#' "$INDEX_HTML"
  ban "remote https?:// src"           'src[[:space:]]*=[[:space:]]*["'"'"']https?://'     "$INDEX_HTML"
  ban "remote https?:// href"          'href[[:space:]]*=[[:space:]]*["'"'"']https?://'    "$INDEX_HTML"
  ban "root-absolute /-leading ref"    '(src|href)[[:space:]]*=[[:space:]]*["'"'"']/'      "$INDEX_HTML"
  [ "$FAILED" -eq "$before" ] && pass "file://-safety: no unsafe fetch/XHR/module/sprite/remote/root-absolute refs"
fi

# ============================================================================
# Family 2: scope-nonleak audit over brandbook/brandbook.css (BOOK-02, D-07)
# ============================================================================
if [ -f "$BOOK_CSS" ]; then
  echo "-- family 2: scope-nonleak audit ($BOOK_CSS) --"
  # positive: the scoping machinery must be present
  need "@layer declared" '@layer'  "$BOOK_CSS"
  need "@scope declared" '@scope'  "$BOOK_CSS"

  # negative: any bare element-name or `*` selector at column 0 is a leak risk.
  # Every real rule lives indented under @layer/@scope (or one-line @layer
  # fallbacks starting with `@`). A column-0 line that begins with a letter or
  # `*` and opens a block `{` is an unscoped selector — FAIL it.
  bare="$(grep -nE '^[A-Za-z*][^{}]*\{' "$BOOK_CSS" || true)"
  if [ -n "$bare" ]; then
    fail "scope-leak: bare column-0 element/'*' selector(s) not prefixed .cwb-/.cw-brandbook:"
    printf '%s\n' "$bare" | sed 's/^/        /'
  else
    pass "scope-nonleak: every rule is layer/scope-nested or .cwb-/.cw-brandbook prefixed"
  fi

  # negative: no non-token #hex literal (token drift smell). The book reads
  # --cw-* by name; it should carry ZERO hard-coded hex.
  hex_offenders=""
  while IFS= read -r hx; do
    [ -z "$hx" ] && continue
    low="$(printf '%s' "$hx" | tr '[:upper:]' '[:lower:]')"
    case " $ALLOWED_HEX " in
      *" $low "*) : ;;
      *) hex_offenders="${hex_offenders}#${low}\n" ;;
    esac
  done <<EOF
$(grep -oE '#[0-9a-fA-F]{6}' "$BOOK_CSS" | sed 's/#//' | sort -u)
EOF
  if [ -n "$hex_offenders" ]; then
    fail "token-drift: non-token #hex literal(s) in $BOOK_CSS (read --cw-* by name):"
    printf '%b' "$hex_offenders" | sed 's/^/        /'
  else
    pass "token-drift: no non-token #hex literal in $BOOK_CSS"
  fi
fi

# ============================================================================
# Family 3: section-presence positives over brandbook/index.html
# The design emits EIGHT `.is-*` classes plus `.cwb-skeleton` (never a literal
# `is-skeleton`). Plus theme toggle + contrast matrix + voice/naming anchors.
# ============================================================================
if [ -f "$INDEX_HTML" ]; then
  echo "-- family 3: section-presence positives ($INDEX_HTML) --"
  for s in hover focus active disabled loading error empty selected; do
    need "state class .is-$s" "is-$s" "$INDEX_HTML"
  done
  # skeleton is realized as .cwb-skeleton (special-case; NOT a literal is-skeleton)
  need "skeleton state (.cwb-skeleton)" 'is-skeleton|cwb-skeleton' "$INDEX_HTML"
  # theme toggle + live WCAG contrast matrix (BOOK-03)
  need "theme toggle hook (data-cwb-theme)" 'data-cwb-theme' "$INDEX_HTML"
  need "contrast matrix (luminance)"        'luminance'       "$INDEX_HTML"
  # voice-context anchors (VOICE-01)
  for anchor in docs errors marketing cli; do
    need "voice-context anchor '$anchor'" "$anchor" "$INDEX_HTML"
  done
  # error-template phrase (VOICE-02)
  need "error-template phrase 'what happened'" 'what happened' "$INDEX_HTML"
  # brand naming casing (VOICE-03)
  need "lowercase brand token 'chimeway'"  'chimeway'  "$INDEX_HTML"
  need "title-case brand token 'Chimeway'" 'Chimeway'  "$INDEX_HTML"
fi

# ============================================================================
# Family 4: D-05 logo-parity for the TWO inlined marks ONLY.
# Assert each mark's `d=` payload appears in BOTH the SSOT asset AND the inline
# <svg> in index.html. Drift in either side breaks parity. The inverse lockup
# is fixed-color and NOT inlined, so it is NOT parity-checked (see header).
# ============================================================================
echo "-- family 4: D-05 logo-parity (two inlined marks) --"

# chimeway-mark-mono.svg — 24x24 viewBox, tiny path: full-string match.
MARK_MONO_D='M6 5h12l-2.5 14h-7Z'
if [ -f "$MARK_MONO" ] && grep -qF "$MARK_MONO_D" "$MARK_MONO"; then
  pass "parity: mark-mono d= present in SSOT asset ($MARK_MONO)"
  if [ -f "$INDEX_HTML" ]; then
    if grep -qF "$MARK_MONO_D" "$INDEX_HTML"; then
      pass "parity: mark-mono inline d= matches SSOT asset"
    else
      fail "parity: mark-mono inline path drifted from $MARK_MONO (expected '$MARK_MONO_D')"
    fi
  fi
else
  fail "parity: SSOT asset $MARK_MONO missing or lacks expected d= '$MARK_MONO_D'"
fi

# chimeway-logotype-mono.svg — long ~2.5KB path: normalized leading-subset match
# (D-05 discretion; fails on real drift of the mark's opening glyph geometry).
LOGOTYPE_MONO_D='m27.24 39.84-1.45 3.48q-.52.23-1.2.43'
if [ -f "$LOGOTYPE_MONO" ] && grep -qF "$LOGOTYPE_MONO_D" "$LOGOTYPE_MONO"; then
  pass "parity: logotype-mono d= subset present in SSOT asset ($LOGOTYPE_MONO)"
  if [ -f "$INDEX_HTML" ]; then
    if grep -qF "$LOGOTYPE_MONO_D" "$INDEX_HTML"; then
      pass "parity: logotype-mono inline d= subset matches SSOT asset"
    else
      fail "parity: logotype-mono inline path drifted from $LOGOTYPE_MONO (expected leading '$LOGOTYPE_MONO_D')"
    fi
  fi
else
  fail "parity: SSOT asset $LOGOTYPE_MONO missing or lacks expected d= subset '$LOGOTYPE_MONO_D'"
fi

# ----------------------------------------------------------------------------
# Optional: xmllint well-formedness over index.html. SKIP when absent.
# ----------------------------------------------------------------------------
if [ -f "$INDEX_HTML" ]; then
  if command -v xmllint >/dev/null 2>&1; then
    if xmllint --noout --html "$INDEX_HTML" 2>/dev/null; then
      pass "xmllint: $INDEX_HTML parses"
    else
      # HTML is not required to be XML-well-formed; treat parse failure as a
      # soft note, not a hard fail (html5 void elements etc.). Keep informational.
      skip "xmllint: $INDEX_HTML has non-fatal HTML parse notes (html5 tolerated)"
    fi
  else
    skip "xmllint not on PATH — index.html well-formedness check skipped"
  fi
fi

# ============================================================================
# Family 5: selector-coverage — every cwb-* class USED in index.html must have a
# matching selector in brandbook.css. Presence-only checks (families 1-4) passed
# while `.cwb-anchors`/`.cwb-brandmark`/`.cwb-theme-toggle` had NO rule, shipping
# a default-bulleted, blue-underlined nav. This closes that vacuous-pass seam.
# ============================================================================
if [ -f "$INDEX_HTML" ] && [ -f "$BOOK_CSS" ]; then
  echo "-- family 5: selector-coverage ($INDEX_HTML classes vs $BOOK_CSS) --"
  orphans=""
  while IFS= read -r cls; do
    [ -z "$cls" ] && continue
    # Match `.<cls>` followed by any non-class char (space, {, ,, :, ., [, EOL)
    # so `.cwb-do` does not spuriously satisfy a missing `.cwb-dont`, etc.
    if ! grep -qE "\.${cls}([^A-Za-z0-9_-]|$)" "$BOOK_CSS"; then
      orphans="${orphans}.${cls}\n"
    fi
  done <<EOF
$(grep -oE 'class="[^"]*"' "$INDEX_HTML" | grep -oE 'cwb-[A-Za-z0-9_-]+' | sort -u)
EOF
  if [ -n "$orphans" ]; then
    fail "selector-coverage: cwb-* class(es) used in $INDEX_HTML with NO rule in $BOOK_CSS:"
    printf '%b' "$orphans" | sed 's/^/        /'
  else
    pass "selector-coverage: every cwb-* class in $INDEX_HTML has a matching selector"
  fi
fi

# ============================================================================
# Family 6: theme-resolution — an explicit data-theme choice must outrank the OS
# prefers-color-scheme. The media block must be gated on :root:not([data-theme])
# and the attribute overrides must be :root-qualified (specificity), else the
# toggle silently does nothing under a dark OS.
# ============================================================================
if [ -f "$TOKENS_CSS" ]; then
  echo "-- family 6: theme-resolution ($TOKENS_CSS) --"
  before=$FAILED
  need "media dark gated on :root:not([data-theme])" ':root:not\(\[data-theme\]\)' "$TOKENS_CSS"
  # Any column-0 [data-theme=...] selector is unqualified — it ties the media
  # :root on specificity and loses on source order. Require :root[data-theme=...].
  if grep -nE '^[[:space:]]*\[data-theme=' "$TOKENS_CSS" >/dev/null 2>&1; then
    fail "theme-resolution: unqualified [data-theme=...] selector (use :root[data-theme=...] so it outranks the media block):"
    grep -nE '^[[:space:]]*\[data-theme=' "$TOKENS_CSS" | sed 's/^/        /'
  fi
  [ "$FAILED" -eq "$before" ] && pass "theme-resolution: explicit data-theme selectors outrank prefers-color-scheme"
fi

# ============================================================================
# Family 7: adaptive-logo coverage — the fixed-color lockups must render
# NATIVELY in both themes, not on a pinned tile. Each ships a light (ink) and an
# inverse (paper) asset that swap by theme. Enforce: (a) the derived inverse
# assets exist and are truly paper-based (ink fully removed); (b) each lockup
# card carries BOTH a .cwb-logo--light and a .cwb-logo--dark <img> for the
# matching SSOT files; (c) brandbook.css swaps them on the SAME theme-resolution
# the tokens use (explicit data-theme wins; system dark gated on
# :not([data-theme])). Catches "a fixed-color lockup with no dark variant" (the
# dark-mode breakage) and "a dark asset that still carries ink".
# ============================================================================
LOGO_DIR="brandbook/assets/logo"
if [ -f "$INDEX_HTML" ]; then
  echo "-- family 7: adaptive-logo coverage ($INDEX_HTML) --"
  before=$FAILED
  # (a) inverse assets exist and are paper-based (no ink left).
  for inv in chimeway-logotype-inverse.svg chimeway-logotype-stacked-inverse.svg chimeway-mark-inverse.svg; do
    f="$LOGO_DIR/$inv"
    if [ ! -f "$f" ]; then
      fail "adaptive-logo: inverse asset $f missing"
    elif grep -q '#102027' "$f"; then
      fail "adaptive-logo: $f still carries ink #102027 (not a true paper inverse)"
    elif ! grep -q '#fffdf8' "$f"; then
      fail "adaptive-logo: $f has no paper #fffdf8 fill (not an inverse)"
    else
      pass "adaptive-logo: $inv is a paper-based inverse"
    fi
  done
  # (b) each lockup ships a matched light + inverse <img> pair.
  light_imgs="$(grep -E 'cwb-logo--light' "$INDEX_HTML" || true)"
  dark_imgs="$(grep -E 'cwb-logo--dark' "$INDEX_HTML" || true)"
  for pair in \
    'chimeway-logotype.svg|chimeway-logotype-inverse.svg' \
    'chimeway-logotype-stacked.svg|chimeway-logotype-stacked-inverse.svg' \
    'chimeway-mark.svg|chimeway-mark-inverse.svg'; do
    l="${pair%%|*}"; d="${pair##*|}"
    if printf '%s\n' "$light_imgs" | grep -qF "assets/logo/$l" \
       && printf '%s\n' "$dark_imgs" | grep -qF "assets/logo/$d"; then
      pass "adaptive-logo: $l has a theme-swapped inverse ($d)"
    else
      fail "adaptive-logo: $l is not paired as .cwb-logo--light + .cwb-logo--dark ($d) — it would not render in the opposite theme"
    fi
  done
  # (c) the swap honors the toggle (same resolution as tokens family 6).
  need "logo swap gated on explicit dark" ':root\[data-theme="dark"\][^{]*\.cwb-logo--light' "$BOOK_CSS"
  need "logo swap gated on system dark"   ':root:not\(\[data-theme\]\)[^{]*\.cwb-logo--dark'  "$BOOK_CSS"
  # The pinned-tile workaround must not be reintroduced.
  if grep -qE 'cwb-panel--field-' "$INDEX_HTML"; then
    fail "adaptive-logo: pinned-tile modifier cwb-panel--field-* still in $INDEX_HTML (superseded by the theme-swap)"
  fi
  [ "$FAILED" -eq "$before" ] && pass "adaptive-logo coverage: fixed-color lockups swap light/inverse by theme"
fi

# ----------------------------------------------------------------------------
echo "== $( [ "$FAILED" -eq 0 ] && echo 'ALL GUARDS PASSED' || echo 'GUARDS FAILED (RED until book files authored)' ) =="
exit "$FAILED"
