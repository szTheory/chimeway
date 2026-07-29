#!/usr/bin/env bash
# CI compile-recompile observability probe, extracted for ci.yml build lanes (OBS-02).
#
# Replaces the compile hidden inside `mix ecto.create` with an explicit,
# behavior-neutral `mix deps.compile` then `mix compile`, teeing each to a log
# and counting `Compiling N files` lines so every build lane can report a
# deps/app recompile count that is correctly `0 0` on a fully warm cache. Uses
# plain `mix compile` — no `--warnings-as-errors` (that upgrade is Phase 88 /
# CACHE-03, out of scope for this additive-only observability phase).
#
# Env contract: RUNNER_TEMP (default /tmp) for log/output scratch files;
# OBS_DEPS_LOG/OBS_APP_LOG override the default log paths (used by
# OBS_SKIP_COMPILE=1 test mode to point at pre-placed fixture logs).
#
# Usage: scripts/ci/obs-recompile.sh
#   OBS_SKIP_COMPILE=1 — skip the `mix` invocations and parse whatever logs
#     already exist at OBS_DEPS_LOG/OBS_APP_LOG. Makes the parser
#     unit-testable offline against committed fixtures.
#
# NOTE: intentionally `set -uo pipefail` (NO `-e`) — a warm-cache grep miss on
# the recompile parse returns 1 and must not abort the step (Pitfall 1).
set -uo pipefail

runner_temp="${RUNNER_TEMP:-/tmp}"
deps_log="${OBS_DEPS_LOG:-$runner_temp/obs-deps.log}"
app_log="${OBS_APP_LOG:-$runner_temp/obs-app.log}"

if [ "${OBS_SKIP_COMPILE:-0}" = "1" ]; then
  drc=0
  arc=0
else
  mix deps.compile 2>&1 | tee "$deps_log"
  drc=${PIPESTATUS[0]}
  mix compile 2>&1 | tee "$app_log"
  arc=${PIPESTATUS[0]}
fi

count() {
  grep -oE 'Compiling [0-9]+ files' "$1" 2>/dev/null \
    | grep -oE '[0-9]+' \
    | paste -sd+ - \
    | bc 2>/dev/null || true
}

deps_n=$(count "$deps_log")
app_n=$(count "$app_log")

printf '%s\n' "${deps_n:-0} ${app_n:-0}" > "$runner_temp/obs-recompile.txt"

[ "$drc" -eq 0 ] && [ "$arc" -eq 0 ]
