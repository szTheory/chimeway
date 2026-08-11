#!/usr/bin/env bash
# Assert the Phase 96 adoption proof on a completed pull-request run for one
# exact commit. Live mode queries GitHub through gh; tests provide a captured
# run payload through ADOPTION_RUN_JSON and never touch the network.
#
# Usage: scripts/ci/assert-adoption-run.sh <40-character-head-sha>
set -euo pipefail

expected_sha="${1:-}"
repo="${GITHUB_REPOSITORY:-szTheory/chimeway}"

fail() {
  echo "adoption run proof failed: $1" >&2
  exit 1
}

if [[ ! "$expected_sha" =~ ^[0-9a-f]{40}$ ]]; then
  fail "expected a lowercase 40-character commit SHA"
fi

if [[ -n "${ADOPTION_RUN_JSON:-}" ]]; then
  run_json=$(jq -c '.' "$ADOPTION_RUN_JSON")
else
  command -v gh >/dev/null 2>&1 || fail "gh is required in live mode"
  command -v jq >/dev/null 2>&1 || fail "jq is required"

  runs_json=$(gh run list -R "$repo" --workflow=ci.yml --commit "$expected_sha" \
    --event pull_request --status completed --limit 20 \
    --json databaseId,headSha,status,conclusion,event,url)

  run_id=$(printf '%s' "$runs_json" | jq -r --arg sha "$expected_sha" \
    '[.[] | select(.headSha == $sha)] | first | .databaseId // empty')

  [[ -n "$run_id" ]] || fail "no completed pull-request run found for the exact SHA"

  run_json=$(gh run view "$run_id" -R "$repo" \
    --json databaseId,event,headSha,status,conclusion,url,jobs)
fi

actual_sha=$(printf '%s' "$run_json" | jq -r '.headSha // empty')
event=$(printf '%s' "$run_json" | jq -r '.event // empty')
status=$(printf '%s' "$run_json" | jq -r '.status // empty')
conclusion=$(printf '%s' "$run_json" | jq -r '.conclusion // empty')
run_id=$(printf '%s' "$run_json" | jq -r '.databaseId // empty')
run_url=$(printf '%s' "$run_json" | jq -r '.url // empty')

[[ "$actual_sha" == "$expected_sha" ]] || fail "run SHA does not match the requested SHA"
[[ "$event" == "pull_request" ]] || fail "run is not a pull-request run"
[[ "$status" == "completed" ]] || fail "run is not completed"
[[ "$conclusion" == "success" ]] || fail "workflow did not succeed"
[[ "$run_id" =~ ^[0-9]+$ ]] || fail "run id is invalid"
[[ "$run_url" == "https://github.com/${repo}/actions/runs/${run_id}" ]] || fail "run URL is invalid"

adoption_count=$(printf '%s' "$run_json" | jq '[.jobs[]? | select(.name == "Adoption proof paths")] | length')
pr_gate_count=$(printf '%s' "$run_json" | jq '[.jobs[]? | select(.name == "pr-gate")] | length')
[[ "$adoption_count" == "1" ]] || fail "expected exactly one adoption proof job"
[[ "$pr_gate_count" == "1" ]] || fail "expected exactly one pr-gate job"

adoption_result=$(printf '%s' "$run_json" | jq -r \
  '.jobs[] | select(.name == "Adoption proof paths") | [.status, .conclusion] | @tsv')
pr_gate_result=$(printf '%s' "$run_json" | jq -r \
  '.jobs[] | select(.name == "pr-gate") | [.status, .conclusion] | @tsv')
proof_step_result=$(printf '%s' "$run_json" | jq -r \
  '.jobs[] | select(.name == "Adoption proof paths") | [.steps[]? | select(.name == "Run adoption proof paths")] | if length == 1 then [.[0].status, .[0].conclusion] | @tsv else "" end')

[[ "$adoption_result" == $'completed\tsuccess' ]] || fail "adoption proof job did not succeed"
[[ "$proof_step_result" == $'completed\tsuccess' ]] || fail "adoption proof step did not succeed"
[[ "$pr_gate_result" == $'completed\tsuccess' ]] || fail "pr-gate did not succeed"

printf 'ADOPTION_RUN_PROOF sha=%s run_id=%s adoption=success pr_gate=success url=%s\n' \
  "$actual_sha" "$run_id" "$run_url"
