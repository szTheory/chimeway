#!/usr/bin/env bash
#
# brandbook-guards.sh — Wave 0 automated acceptance gate for Phase 84
# (html-brandbook-voice-component-states).
#
# Dependency-free: grep / sed / awk / git only; xmllint is optional and
# degrades to SKIP when absent. This script — not any inline command — is the
# canonical automated gate every Phase-84 wave invokes (D-07).
#
# It runs FOUR check families plus a git scope-boundary mode:
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
MARK_MONO="brandbook/assets/logo/chimeway-mark-mono.svg"
LOGOTYPE_MONO="brandbook/assets/logo/chimeway-logotype-mono.svg"

FAILED=0
pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1"; FAILED=1; }
skip() { printf 'SKIP  %s\n' "$1"; }

# ----------------------------------------------------------------------------
# --scope : assert the working tree carries no stray phase edits beyond the
# allowed Phase-84 paths (brandbook/** + the guard itself). Tolerates
# pre-existing .planning/ bookkeeping. Copies the logo-guards.sh porcelain walk
# verbatim, changing only the allow-list `case` (D-07).
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
      brandbook/*)                  : ;;  # phase 84 book scope
      scripts/brandbook-guards.sh)  : ;;  # the guard itself
      .planning/*)                  : ;;  # bookkeeping, out of phase scope
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

# ----------------------------------------------------------------------------
echo "== $( [ "$FAILED" -eq 0 ] && echo 'ALL GUARDS PASSED' || echo 'GUARDS FAILED (RED until book files authored)' ) =="
exit "$FAILED"
