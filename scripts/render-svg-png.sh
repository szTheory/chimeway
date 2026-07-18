#!/usr/bin/env bash
#
# render-svg-png.sh — Phase 83 Wave-0 deterministic SVG→PNG raster helper.
#
# Rasterizes a committed brand SVG to a PNG at an EXACT pixel box via Chrome
# headless. This is the raster stage for the favicon set / OG card and the
# 16px non-blank perceptual check in later plans.
#
# Chrome ONLY — never ImageMagick's internal MSVG renderer (low fidelity on
# outlined paths). Feed the resulting PNGs to ImageMagick for .ico / resize.
#
# Usage:
#   scripts/render-svg-png.sh <input.svg> <size> <output.png>
#   scripts/render-svg-png.sh <input.svg> <width> <height> <output.png>
#
# Examples:
#   scripts/render-svg-png.sh favicon.svg 16 fav16.png          # 16x16
#   scripts/render-svg-png.sh chimeway-og.svg 1200 630 og.png   # 1200x630
#
# Exit: 0 on a written non-empty PNG, non-zero otherwise.
#
set -euo pipefail

usage() {
  echo "usage: $0 <input.svg> <size> <output.png>" >&2
  echo "       $0 <input.svg> <width> <height> <output.png>" >&2
  exit 2
}

[ "$#" -eq 3 ] || [ "$#" -eq 4 ] || usage

IN="$1"
if [ "$#" -eq 3 ]; then
  WIDTH="$2"; HEIGHT="$2"; OUT="$3"
else
  WIDTH="$2"; HEIGHT="$3"; OUT="$4"
fi

[ -f "$IN" ] || { echo "error: input SVG not found: $IN" >&2; exit 1; }
case "$WIDTH$HEIGHT" in *[!0-9]*) echo "error: width/height must be integers" >&2; exit 1 ;; esac

# --- resolve the Chrome binary: macOS app path, then chromium homebrew path ---
CHROME=""
for cand in \
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  "/opt/homebrew/bin/chromium" \
  "$(command -v chromium 2>/dev/null || true)" \
  "$(command -v google-chrome 2>/dev/null || true)"; do
  if [ -n "$cand" ] && [ -x "$cand" ]; then CHROME="$cand"; break; fi
done
[ -n "$CHROME" ] || { echo "error: no Chrome/Chromium binary found" >&2; exit 1; }

# Absolute path to the input so the file:// URL resolves regardless of cwd.
case "$IN" in
  /*) IN_ABS="$IN" ;;
  *)  IN_ABS="$PWD/$IN" ;;
esac

# --- write an HTML wrapper pinning the exact pixel box ---
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
HTML="$WORK/wrap.html"
{
  printf '<!doctype html><meta charset="utf-8">'
  printf '<style>html,body{margin:0;padding:0;background:transparent}'
  printf 'img{display:block;width:%spx;height:%spx}</style>' "$WIDTH" "$HEIGHT"
  printf '<img src="file://%s" width="%s" height="%s">' "$IN_ABS" "$WIDTH" "$HEIGHT"
} > "$HTML"

# --- screenshot via Chrome headless at the exact window size ---
"$CHROME" --headless --disable-gpu --hide-scrollbars \
  --force-device-scale-factor=1 \
  --default-background-color=00000000 \
  --window-size="${WIDTH},${HEIGHT}" \
  --screenshot="$OUT" "file://$HTML" >/dev/null 2>&1 || true

if [ ! -s "$OUT" ]; then
  echo "error: render produced no PNG at $OUT" >&2
  exit 1
fi

echo "rendered $IN -> $OUT (${WIDTH}x${HEIGHT}) via $CHROME"
