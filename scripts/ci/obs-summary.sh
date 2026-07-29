#!/usr/bin/env bash
# CI observability summary renderer, extracted for ci.yml build lanes (OBS-01, OBS-03).
#
# Assembles cache hit/miss classification, deps/app recompile counts, and
# per-step timing into ONE consolidated write to $GITHUB_STEP_SUMMARY per job,
# staying well under the 1 MiB/step and ~20-summaries/job render caps. Emits
# ONLY cache keys, counts, durations, and the run URL — never the job's raw
# environment or secret values (job summaries are world-readable on a public
# repo).
#
# Env contract:
#   GH_TOKEN            - token for `gh api` (the timing query); optional,
#                          falls back to "timing unavailable" on any failure.
#   RUN_URL              - run permalink appended as the final summary line.
#   RUNNER_TEMP           - scratch dir (default /tmp) for the recompile file
#                          this script reads and the intermediate table files.
#   RUNNER_NAME           - correlates this job among concurrently running
#                          jobs/matrix legs when querying the REST /jobs API.
#   GITHUB_REPOSITORY, GITHUB_RUN_ID, GITHUB_RUN_ATTEMPT - REST endpoint parts.
#   CACHE_<id>_HIT / CACHE_<id>_MATCHED / CACHE_<id>_PRIMARY - one triple per
#     cache step in the lane, injected via `env:` from `steps.<id>.outputs.*`
#     (a shell script cannot read the `steps` context directly).
#   OBS_JOBS_JSON        - test hook: path to a fixture `/jobs` REST response,
#                          short-circuits the live `gh api` call.
#
# Usage: scripts/ci/obs-summary.sh
set -euo pipefail

runner_temp="${RUNNER_TEMP:-/tmp}"
cache_md="$runner_temp/obs-cache.md"
recompile_md="$runner_temp/obs-recompile.md"
timing_md="$runner_temp/obs-timing.md"
step_summary="${GITHUB_STEP_SUMMARY:-$runner_temp/obs-step-summary.md}"

: > "$cache_md"
: > "$recompile_md"
: > "$timing_md"

# --- Cache table (OBS-01) ---------------------------------------------------
{
  echo "### Cache"
  echo "| Cache | State | Matched key | Primary key |"
  echo "|-------|-------|-------------|-------------|"
} >>"$cache_md"

cache_ids=$(compgen -e | grep -E '^CACHE_.*_HIT$' | sed -E 's/^CACHE_(.*)_HIT$/\1/' || true)

if [ -n "$cache_ids" ]; then
  while IFS= read -r id; do
    [ -z "$id" ] && continue
    hit_var="CACHE_${id}_HIT"
    matched_var="CACHE_${id}_MATCHED"
    primary_var="CACHE_${id}_PRIMARY"
    hit="${!hit_var:-}"
    matched="${!matched_var:-}"
    primary="${!primary_var:-}"

    if [ "$hit" = "true" ]; then
      state="EXACT HIT"
    elif [ -n "$matched" ]; then
      state="PARTIAL"
    else
      state="MISS"
    fi

    printf '| %s | %s | `%s` | `%s` |\n' "$id" "$state" "${matched:-—}" "${primary:-—}" >>"$cache_md"
  done <<<"$cache_ids"
fi

# --- Recompile table (OBS-02 consumer) --------------------------------------
{
  echo "### Recompile"
  echo "| deps | app |"
  echo "|------|-----|"
} >>"$recompile_md"

recompile_file="$runner_temp/obs-recompile.txt"
deps_n=0
app_n=0
if [ -f "$recompile_file" ]; then
  read -r deps_n app_n <"$recompile_file"
fi
printf '| %s | %s |\n' "${deps_n:-0}" "${app_n:-0}" >>"$recompile_md"

# --- Step timing table (OBS-03) ---------------------------------------------
{
  echo "### Step timing"
  echo "| Step | Duration |"
  echo "|------|----------|"
} >>"$timing_md"

render_timing_rows() {
  jq -r --arg rn "${RUNNER_NAME:-}" '
    .jobs[] | select(.runner_name==$rn and .status=="in_progress") | .steps[]
    | select(.started_at != null and .completed_at != null)
    | [.name, ((.completed_at|fromdateiso8601) - (.started_at|fromdateiso8601))] | @tsv' \
    | awk -F'\t' '{printf "| %s | %ds |\n", $1, $2}'
}

timing_rendered=0
if [ -n "${OBS_JOBS_JSON:-}" ]; then
  if [ -f "$OBS_JOBS_JSON" ]; then
    if rows=$(render_timing_rows <"$OBS_JOBS_JSON" 2>/dev/null) && [ -n "$rows" ]; then
      printf '%s\n' "$rows" >>"$timing_md"
      timing_rendered=1
    fi
  fi
else
  api="/repos/${GITHUB_REPOSITORY:-}/actions/runs/${GITHUB_RUN_ID:-}/attempts/${GITHUB_RUN_ATTEMPT:-1}/jobs"
  if rows=$(gh api --paginate "$api" 2>/dev/null | render_timing_rows 2>/dev/null) && [ -n "$rows" ]; then
    printf '%s\n' "$rows" >>"$timing_md"
    timing_rendered=1
  fi
fi

if [ "$timing_rendered" -eq 0 ]; then
  echo "| _timing unavailable_ | — |" >>"$timing_md"
fi

# --- Single consolidated write (Pitfall 2: 20-summaries/job, 1 MiB/step) ---
{
  cat "$cache_md"
  echo
  cat "$recompile_md"
  echo
  cat "$timing_md"
  echo
  echo "Run: ${RUN_URL:-unknown}"
} >>"$step_summary"
