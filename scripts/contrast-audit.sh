#!/usr/bin/env bash
#
# contrast-audit.sh — dependency-free offline WCAG 2.x contrast calc (Phase 86,
# A11Y-01/02/05, D-01). NO node, NO npm, NO network: POSIX shell + one awk pass.
#
# It reads the frozen --cw-* hex values straight from brandbook/tokens/tokens.css
# (the token SSOT — READ-ONLY here; TOKEN-01 zero-drift) and reproduces VERBATIM
# the relative-luminance + contrast-ratio formula already inlined in
# brandbook/index.html:824-835 (verified against the W3C definition):
#
#   per sRGB channel C:  c = C/255 ;  lin = c<=0.03928 ? c/12.92 : ((c+0.055)/1.055)^2.4
#   luminance L = 0.2126*R + 0.7152*G + 0.0722*B
#   contrast    = (Lhi + 0.05) / (Llo + 0.05)
#
# For EVERY pairing enumerated in D-01, across BOTH light and dark themes, it
# prints the ratio (2 decimals, ROUNDED HALF-UP: int(r*100+0.5)/100) plus an AA
# verdict — text pairs vs 4.5:1, non-text/UI pairs vs 3:1 — using a `>=`
# comparison so a ratio exactly on the threshold scores PASS. Output rows are
# grouped by pair class, then light-before-dark (a stable, re-runnable order).
#
# The verdict column is the raw WCAG AA test only. Sub-threshold pairings that
# are DOCUMENTED WCAG EXEMPTIONS (disabled text SC 1.4.3 Incidental; decorative
# borders SC 1.4.11 "required to identify") are dispositioned in
# notes/accessibility-checks.md, NOT here — this script only computes and prints.
#
# Hex is parsed by awk field/substring extraction (never shell-eval / sourcing of
# file contents). If any referenced --cw-* token is absent or unparseable, the
# calc FAILS LOUD: a message on stderr and a non-zero exit (3), never a silent
# or bogus ratio (T-86-01 mitigation).
#
# Usage:   scripts/contrast-audit.sh        # prints the per-pairing table, exits 0
# Exit:    0 all pairings resolved & computed · 2 tokens.css missing · 3 token unresolvable
#
set -euo pipefail

TOKENS_CSS="brandbook/tokens/tokens.css"

if [ ! -f "$TOKENS_CSS" ]; then
  printf 'FAIL  contrast-audit: token file not found: %s\n' "$TOKENS_CSS" >&2
  exit 2
fi

awk '
  function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }

  # value of one hex nibble via position in the ordered hex alphabet (no
  # strtonum — that is a gawk extension absent from the macOS one-true-awk).
  function nib(c) { return index("0123456789abcdef", tolower(c)) - 1 }
  function chan(h, i) { return nib(substr(h, i, 1)) * 16 + nib(substr(h, i + 1, 1)) }

  # Resolve a --cw-* token to a lowercase #rrggbb for the given theme, following
  # var(--cw-*) references (light block holds the primitives; dark inherits from
  # light for anything it does not override). Fails loud on missing/unparseable.
  function resolve(theme, name, depth,   v) {
    if (depth > 12) { fatal("var() reference cycle at " name); }
    v = ""
    if (theme == "dark" && (name in dark)) v = dark[name]
    else if (name in light)                v = light[name]
    else { fatal("token not defined: " name " (theme " theme ")"); }
    if (v ~ /^var\(/) {
      sub(/^var\(/, "", v); sub(/\).*$/, "", v); gsub(/[ \t]/, "", v)
      return resolve(theme, v, depth + 1)
    }
    v = tolower(trim(v))
    if (v ~ /^#[0-9a-f]{6}$/) return v
    fatal("token " name " (theme " theme ") is not a 6-digit hex: \"" v "\"")
  }

  function lin(C,   c) { c = C / 255; return (c <= 0.03928) ? c / 12.92 : ((c + 0.055) / 1.055) ^ 2.4 }
  function lum(h) { return 0.2126 * lin(chan(h, 2)) + 0.7152 * lin(chan(h, 4)) + 0.0722 * lin(chan(h, 6)) }
  function ratio(fg, bg,   l1, l2, hi, lo) {
    l1 = lum(fg); l2 = lum(bg); hi = (l1 > l2) ? l1 : l2; lo = (l1 > l2) ? l2 : l1
    return (hi + 0.05) / (lo + 0.05)
  }
  function round2(x) { return int(x * 100 + 0.5) / 100 }

  function fatal(msg) {
    printf "FAIL  contrast-audit: %s\n", msg > "/dev/stderr"
    ERR = 1
    exit 3
  }

  function addpair(cls, label, fg, bg, kind) {
    N++; P_cls[N] = cls; P_lbl[N] = label; P_fg[N] = fg; P_bg[N] = bg; P_kind[N] = kind
  }

  BEGIN {
    ERR = 0
    # Pairing inventory (D-01), grouped by class. Each is computed light+dark.
    # kind: "text" -> AA 4.5:1 ; "ui" -> AA non-text 3:1.
    addpair("text",          "body text (fg/surface)",   "--cw-fg",                    "--cw-surface-bg",              "text")
    addpair("text",          "muted caption",            "--cw-fg-muted",              "--cw-surface-bg",              "text")
    addpair("text",          "link",                     "--cw-link-fg",               "--cw-surface-bg",              "text")

    addpair("status-text",   "success text/surface",     "--cw-status-success-text",   "--cw-status-success-surface",  "text")
    addpair("status-text",   "warning text/surface",     "--cw-status-warning-text",   "--cw-status-warning-surface",  "text")
    addpair("status-text",   "danger text/surface",      "--cw-status-danger-text",    "--cw-status-danger-surface",   "text")
    addpair("status-text",   "info text/surface",        "--cw-status-info-text",      "--cw-status-info-surface",     "text")
    addpair("status-text",   "neutral text/surface",     "--cw-status-neutral-text",   "--cw-status-neutral-surface",  "text")

    addpair("status-border", "success border/surface",   "--cw-status-success-border", "--cw-status-success-surface",  "ui")
    addpair("status-border", "warning border/surface",   "--cw-status-warning-border", "--cw-status-warning-surface",  "ui")
    addpair("status-border", "danger border/surface",    "--cw-status-danger-border",  "--cw-status-danger-surface",   "ui")
    addpair("status-border", "info border/surface",      "--cw-status-info-border",    "--cw-status-info-surface",     "ui")
    addpair("status-border", "neutral border/surface",   "--cw-status-neutral-border", "--cw-status-neutral-surface",  "ui")

    addpair("panel-border",  "panel border (line/paper)","--cw-border",                "--cw-surface-bg",              "ui")
    addpair("panel-border",  "border-strong/surface",    "--cw-border-strong",         "--cw-surface-bg",              "ui")

    addpair("focus-ring",    "focus ring / surface",     "--cw-focus",                 "--cw-surface-bg",              "ui")
    addpair("focus-ring",    "focus ring / panel",       "--cw-focus",                 "--cw-surface-panel",           "ui")

    addpair("button",        "primary button fg/bg",     "--cw-button-primary-fg",     "--cw-button-primary-bg",       "text")

    addpair("disabled",      "disabled text fg/bg",      "--cw-control-disabled-fg",   "--cw-control-disabled-bg",     "text")
  }

  # ---- parse tokens.css into per-theme token maps -------------------------
  # Context is set by top-level selectors; the @media(prefers-color-scheme)
  # block is skipped (it mirrors [data-theme=dark] under :root:not([data-theme])
  # and would only duplicate the dark map).
  /^:root\[data-theme="dark"\]/  { ctx = "dark";  next }
  /^:root\[data-theme="light"\]/ { ctx = "light"; next }
  /^:root[ \t]*\{/               { ctx = "light"; next }
  /^@media/                      { ctx = "skip";  next }
  /^\}/                          { ctx = "";      next }
  {
    if (ctx != "light" && ctx != "dark") next
    if ($0 !~ /--cw-[a-zA-Z0-9-]+[ \t]*:/) next
    line = trim($0)
    colon = index(line, ":")
    name = trim(substr(line, 1, colon - 1))
    val = substr(line, colon + 1)
    sub(/;.*$/, "", val)          # drop the semicolon and any trailing comment
    val = trim(val)
    if (ctx == "light") light[name] = val
    else                dark[name]  = val
  }

  END {
    if (ERR) exit 3
    printf "== WCAG 2.x offline contrast audit (brandbook/tokens/tokens.css) ==\n"
    printf "formula: brandbook/index.html:824-835 · rounding: 2dp half-up · text>=4.5:1 ui>=3:1 (>= = PASS)\n\n"
    printf "%-14s %-6s %-26s %-9s %-9s %6s  %-4s  %s\n", \
           "class", "theme", "pairing", "fg", "bg", "ratio", "thr", "AA"
    printf "%-14s %-6s %-26s %-9s %-9s %6s  %-4s  %s\n", \
           "-----", "-----", "-------", "--", "--", "-----", "---", "--"
    for (i = 1; i <= N; i++) {
      split("light dark", themes, " ")
      for (t = 1; t <= 2; t++) {
        theme = themes[t]
        fg = resolve(theme, P_fg[i], 0)
        bg = resolve(theme, P_bg[i], 0)
        r = ratio(fg, bg)
        thr = (P_kind[i] == "text") ? 4.5 : 3.0
        verdict = (r >= thr) ? "PASS" : "FAIL"
        printf "%-14s %-6s %-26s %-9s %-9s %6.2f  %-4s  %s\n", \
               P_cls[i], theme, P_lbl[i], fg, bg, round2(r), \
               ((P_kind[i] == "text") ? "4.5" : "3.0"), verdict
      }
    }
  }
' "$TOKENS_CSS"
