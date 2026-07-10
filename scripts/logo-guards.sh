#!/usr/bin/env bash
#
# logo-guards.sh — Wave 0 automated acceptance gate for Phase 82
# (logo-exploration-shortlist).
#
# Samples notes/logo-options.md (the single committed deliverable) on every
# commit. Dependency-free: grep / sed / awk / git only; xmllint is optional and
# degrades to SKIP when absent. This script — not any inline command — is the
# canonical automated gate the doc tasks invoke.
#
# Usage:
#   scripts/logo-guards.sh [path-to-doc]     # default: notes/logo-options.md
#   scripts/logo-guards.sh --scope           # git scope-boundary check
#
# Exit status: 0 if every check passes, non-zero if ANY check fails.
#
set -euo pipefail

# ----------------------------------------------------------------------------
# Allowed token-hex set (D-11). This is the ONLY place a color literal is
# permitted to appear in this script. Values are the --cw-* token hexes:
#   ink #102027 · night #07131a · paper #fffdf8 · teal #0e7c86
#   brass #d6a84f · mint #9adbcf
# ----------------------------------------------------------------------------
ALLOWED_HEX="102027 07131a fffdf8 0e7c86 d6a84f 9adbcf"

# Files this phase is allowed to commit (repo discipline / NOTES-03 precursor).
ALLOWED_DOC="notes/logo-options.md"
ALLOWED_GUARD="scripts/logo-guards.sh"

FAILED=0
pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1"; FAILED=1; }
skip() { printf 'SKIP  %s\n' "$1"; }

# ----------------------------------------------------------------------------
# --scope : assert the working tree carries no stray phase edits beyond the two
# allowed committed paths. Tolerates the ephemeral gallery (lives OUTSIDE the
# repo) and pre-existing .planning/ bookkeeping. Catches accidental
# brandbook/logo/*.svg, base64 blobs, or any file smuggled outside scope.
# ----------------------------------------------------------------------------
if [ "${1:-}" = "--scope" ]; then
  echo "== scope-boundary check (git) =="
  git diff --stat || true
  stray=""
  # --porcelain covers staged + unstaged + untracked; -z would need NUL parsing,
  # keep it line-based for portability.
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
      "$ALLOWED_DOC"|"$ALLOWED_GUARD") : ;;   # allowed committed deliverables
      .planning/*) : ;;                        # bookkeeping, out of phase scope
      *) stray="${stray}${path}\n" ;;
    esac
  done <<EOF
$(git status --porcelain --untracked-files=all)
EOF
  if [ -n "$stray" ]; then
    fail "scope: unexpected path(s) outside the two allowed files:"
    printf '%b' "$stray" | sed 's/^/        /'
  else
    pass "scope: working tree carries only the allowed phase paths"
  fi
  [ "$FAILED" -eq 0 ] && echo "== scope OK ==" || echo "== scope FAILED =="
  exit "$FAILED"
fi

DOC="${1:-$ALLOWED_DOC}"

# ----------------------------------------------------------------------------
# Doc-presence gate: an absent doc is RED (proves the guard is wired).
# ----------------------------------------------------------------------------
if [ ! -f "$DOC" ]; then
  fail "doc missing: '$DOC' does not exist yet (author it, then re-run)"
  echo "== guards FAILED (doc not found) =="
  exit 1
fi

echo "== logo-guards against: $DOC =="

# Extract ONLY the content inside <svg> ... </svg> regions to a temp file.
# All SVG-scoped checks (hex, var(), hygiene, xmllint) read this, so the doc's
# prose (token legend, rationale) never trips a color/hygiene check.
SVG_ONLY="$(mktemp)"
trap 'rm -f "$SVG_ONLY"' EXIT
awk '/<svg/{insvg=1} insvg{print} /<\/svg>/{insvg=0}' "$DOC" > "$SVG_ONLY"

# ----------------------------------------------------------------------------
# Check 1: Verdict count — 'Verdict: <Ship|Defer|Reject>' anchored at EOL, >=5.
# ----------------------------------------------------------------------------
verdicts="$(grep -cE '^Verdict: (Ship|Defer|Reject)[[:space:]]*$' "$DOC" || true)"
if [ "$verdicts" -ge 5 ]; then
  pass "verdict lines: $verdicts (>= 5)"
else
  fail "verdict lines: $verdicts (need >= 5, pattern '^Verdict: Ship|Defer|Reject$')"
fi

# ----------------------------------------------------------------------------
# Check 2: Confidence count — 'Confidence: <High|Medium|Low>', >=5.
# ----------------------------------------------------------------------------
confid="$(grep -cE '^Confidence: (High|Medium|Low)[[:space:]]*$' "$DOC" || true)"
if [ "$confid" -ge 5 ]; then
  pass "confidence lines: $confid (>= 5)"
else
  fail "confidence lines: $confid (need >= 5, pattern '^Confidence: High|Medium|Low$')"
fi

# ----------------------------------------------------------------------------
# Check 3: Proof-label presence — each of the five labels appears >=5 times.
# ----------------------------------------------------------------------------
for label in "16px" "Mono" "Inverse" "Clear-space" "Min-size"; do
  n="$(grep -oE "$label" "$DOC" | wc -l | tr -d ' ')"
  if [ "$n" -ge 5 ]; then
    pass "proof label '$label': $n (>= 5)"
  else
    fail "proof label '$label': $n (need >= 5, one per shortlisted direction)"
  fi
done

# ----------------------------------------------------------------------------
# Check 4: Rejected section present + >=2 reason lines beneath it.
# ----------------------------------------------------------------------------
if grep -qE '^#{1,4}[[:space:]].*Rejected' "$DOC"; then
  reasons="$(grep -cE '^(Reason|Failed):' "$DOC" || true)"
  if [ "$reasons" -ge 2 ]; then
    pass "rejected section present with $reasons reason line(s) (>= 2)"
  else
    fail "rejected section present but only $reasons 'Reason:'/'Failed:' line(s) (need >= 2)"
  fi
else
  fail "rejected section missing (no heading matching 'Rejected')"
fi

# ----------------------------------------------------------------------------
# Check 5: Token-hex subset (D-11) — every 6-digit #hex inside SVG blocks must
# be a member of the allowed set. Offenders are printed.
# ----------------------------------------------------------------------------
offenders=""
if [ -s "$SVG_ONLY" ]; then
  while IFS= read -r hx; do
    [ -z "$hx" ] && continue
    low="$(printf '%s' "$hx" | tr '[:upper:]' '[:lower:]')"
    case " $ALLOWED_HEX " in
      *" $low "*) : ;;
      *) offenders="${offenders}#${low}\n" ;;
    esac
  done <<EOF
$(grep -oE '#[0-9a-fA-F]{6}' "$SVG_ONLY" | sed 's/#//' | sort -u)
EOF
fi
if [ -n "$offenders" ]; then
  fail "non-token hex inside SVG blocks:"
  printf '%b' "$offenders" | sed 's/^/        /'
else
  pass "token-hex subset: every SVG hex is a --cw-* token value"
fi

# ----------------------------------------------------------------------------
# Check 6: No var( inside SVG blocks (RESEARCH Pitfall 2 — var() does not
# resolve in committed/standalone SVG).
# ----------------------------------------------------------------------------
if grep -qE 'var\(' "$SVG_ONLY"; then
  fail "var( found inside SVG blocks (use literal token hex, not var())"
  grep -nE 'var\(' "$SVG_ONLY" | sed 's/^/        /'
else
  pass "no var( inside SVG blocks"
fi

# ----------------------------------------------------------------------------
# Check 7: SVG-hygiene scan (T-82-01) — presentation elements only. Zero
# matches for active/remote content inside SVG regions.
#   - <script> open tag
#   - <foreignObject> element
#   - <image> element
#   - on*= event-handler attribute (space-anchored attribute name)
#   - javascript: scheme
#   - data: URI
#   - off-document http(s) reference inside href / xlink:href (xmlns namespace
#     declarations are intentionally NOT matched)
# ----------------------------------------------------------------------------
hygiene_hit=0
hygiene_check() {
  local desc="$1" pat="$2"
  if grep -nEi "$pat" "$SVG_ONLY" >/dev/null 2>&1; then
    fail "hygiene: $desc found inside SVG blocks"
    grep -nEi "$pat" "$SVG_ONLY" | sed 's/^/        /'
    hygiene_hit=1
  fi
}
hygiene_check "<script> element"      '<script[[:space:]>]'
hygiene_check "<foreignObject>"       '<foreignObject[[:space:]>]'
hygiene_check "<image> element"       '<image[[:space:]>]'
hygiene_check "on*= event handler"    '[[:space:]]on[a-z]+[[:space:]]*='
hygiene_check "javascript: scheme"    'javascript:'
hygiene_check "data: URI"             'data:'
hygiene_check "remote href/xlink:href" '(xlink:)?href[[:space:]]*=[[:space:]]*["'"'"']https?:'
if [ "$hygiene_hit" -eq 0 ]; then
  pass "SVG-hygiene: presentation elements only (no active/remote content)"
fi

# ----------------------------------------------------------------------------
# Check 8: Optional well-formedness — extract each <svg>..</svg> block and run
# xmllint --noout. SKIP (do not fail) when xmllint is absent.
# ----------------------------------------------------------------------------
if command -v xmllint >/dev/null 2>&1; then
  wf_fail=0
  block_dir="$(mktemp -d)"
  # Split SVG_ONLY into one file per <svg>..</svg> block.
  awk -v dir="$block_dir" '
    /<svg/{insvg=1; n++; f=sprintf("%s/block_%03d.svg", dir, n)}
    insvg{print > f}
    /<\/svg>/{insvg=0}
  ' "$SVG_ONLY"
  shopt -s nullglob 2>/dev/null || true
  blocks=("$block_dir"/block_*.svg)
  if [ "${#blocks[@]}" -eq 0 ]; then
    skip "xmllint: no <svg> blocks extracted to validate"
  else
    for b in "${blocks[@]}"; do
      if ! xmllint --noout "$b" 2>/tmp/xmllint_err.$$; then
        wf_fail=1
        fail "xmllint: malformed SVG block $(basename "$b")"
        sed 's/^/        /' "/tmp/xmllint_err.$$" 2>/dev/null || true
      fi
    done
    rm -f "/tmp/xmllint_err.$$"
    [ "$wf_fail" -eq 0 ] && pass "xmllint: all ${#blocks[@]} SVG block(s) well-formed"
  fi
  rm -rf "$block_dir"
else
  skip "xmllint not on PATH — SVG well-formedness check skipped"
fi

# ----------------------------------------------------------------------------
echo "== $( [ "$FAILED" -eq 0 ] && echo 'ALL GUARDS PASSED' || echo 'GUARDS FAILED' ) =="
exit "$FAILED"
