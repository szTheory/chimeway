#!/usr/bin/env bash
# REL-01: measures push-on-main ci-gate reliability (failure rate + consecutive
# green streak) by classifying the `ci-gate` JOB conclusion on `event=push,
# branch=main` runs — NOT the run-level conclusion, which is contaminated by
# workflow_dispatch / release-please-branch / nightly-dispatch runs (see
# 92-RESEARCH.md Pitfall 1).
#
# Population/collection seam:
#   RELIABILITY_RUNS_JSON - test hook: path to a fixture JSON array of
#     {"databaseId": <id>, "gate_conclusion": "<success|failure|cancelled|skipped>"}
#     objects, ordered most-recent-first. Short-circuits the live gh calls.
#   Live mode (RELIABILITY_RUNS_JSON unset):
#     gh run list --workflow=ci.yml --branch main --event push --limit 30
#       --json databaseId  (most-recent-first)
#     then, per run:
#       gh run view <id> --json jobs -q '.jobs[]|select(.name=="ci-gate")|.conclusion'
#
# Classification:
#   success            -> GREEN
#   failure            -> REAL FAILURE (counts against the rate)
#   cancelled|skipped  -> EXCLUDED (infra supersession, not a reliability defect)
#
# Bar (strict, integer arithmetic — no float rounding shifts the boundary):
#   denominator   = completed - excluded
#   failure_rate  < 10%  <=>  real_failures * 10 < denominator  (exactly 10% FAILS)
#   streak        >= 5   (consecutive `success` scanning most-recent-first,
#                          SKIPPING excluded runs, STOPPING at the first
#                          `failure`; a streak of exactly 4 FAILS)
#
# Emits a markdown table (run id, ci-gate conclusion, permalink) plus a summary
# line to stdout and $GITHUB_STEP_SUMMARY. Whitelist-emit only: run ids,
# conclusions, counts, and permalinks — never raw env, GH_TOKEN, or
# DATABASE_URL. All gh --json output is parsed with jq/-q — never interpolated
# into a shell eval or unquoted expansion.
#
# Usage: scripts/ci/reliability-report.sh
set -euo pipefail

runner_temp="${RUNNER_TEMP:-/tmp}"
step_summary="${GITHUB_STEP_SUMMARY:-$runner_temp/reliability-step-summary.md}"
repo="${GITHUB_REPOSITORY:-szTheory/chimeway}"

# --- Collect rows: "databaseId<TAB>conclusion", most-recent-first -----------
if [ -n "${RELIABILITY_RUNS_JSON:-}" ]; then
  rows=$(jq -r '.[] | [.databaseId, .gate_conclusion] | @tsv' "$RELIABILITY_RUNS_JSON")
else
  run_ids=$(gh run list --workflow=ci.yml --branch main --event push --limit 30 \
    --json databaseId -q '.[].databaseId')

  rows=""
  while IFS= read -r rid; do
    [ -z "$rid" ] && continue
    conclusion=$(gh run view "$rid" --json jobs -q '.jobs[]|select(.name=="ci-gate")|.conclusion')
    rows="${rows}${rid}	${conclusion}
"
  done <<<"$run_ids"
fi

# --- Render table + classify --------------------------------------------------
table_md="$runner_temp/reliability-table.md"
{
  echo "### CI Reliability (push-on-main ci-gate)"
  echo "| Run ID | ci-gate | Permalink |"
  echo "|--------|---------|-----------|"
} >"$table_md"

completed=0
real_failures=0
excluded=0
streak=0
streak_open=1

while IFS=$'\t' read -r rid conclusion; do
  [ -z "$rid" ] && continue
  completed=$((completed + 1))

  printf '| %s | %s | https://github.com/%s/actions/runs/%s |\n' \
    "$rid" "$conclusion" "$repo" "$rid" >>"$table_md"

  excluded_this=0
  case "$conclusion" in
    success)
      : # counts toward denominator + streak eligibility
      ;;
    cancelled | skipped)
      excluded=$((excluded + 1))
      excluded_this=1
      ;;
    failure)
      real_failures=$((real_failures + 1))
      ;;
    *)
      # Unknown/unresolved conclusion (e.g. null) — treat as excluded rather
      # than silently counting it as either a pass or a real failure.
      excluded=$((excluded + 1))
      excluded_this=1
      ;;
  esac

  if [ "$streak_open" -eq 1 ]; then
    if [ "$conclusion" = "success" ]; then
      streak=$((streak + 1))
    elif [ "$excluded_this" -eq 1 ]; then
      : # excluded run — skip without breaking or extending the streak
    else
      streak_open=0 # first real failure — stop counting
    fi
  fi
done <<<"$rows"

denominator=$((completed - excluded))

if [ "$denominator" -gt 0 ]; then
  # Rounded percent for display only; the pass/fail decision below always uses
  # the exact integer comparison (real_failures*10 vs denominator), never this
  # rounded value, so no float rounding can shift the boundary.
  rate_pct=$(((real_failures * 100) / denominator))
else
  rate_pct=0
fi

summary_line="failures=${real_failures} excluded=${excluded} rate=${rate_pct}% streak=${streak}"

{
  cat "$table_md"
  echo
  echo "$summary_line"
} >>"$step_summary"

cat "$table_md"
echo
echo "$summary_line"

# --- Pass/fail bar (strict, integer arithmetic) ------------------------------
bar_failed=0

if [ "$denominator" -gt 0 ]; then
  if [ $((real_failures * 10)) -ge "$denominator" ]; then
    bar_failed=1
  fi
else
  # No classifiable (non-excluded) runs at all — the bar cannot be proven met.
  bar_failed=1
fi

if [ "$streak" -lt 5 ]; then
  bar_failed=1
fi

if [ "$bar_failed" -eq 1 ]; then
  echo "RELIABILITY BAR MISSED: rate must be < 10% AND streak >= 5" >&2
  exit 1
fi

echo "RELIABILITY BAR MET: rate < 10% and streak >= 5"
exit 0
