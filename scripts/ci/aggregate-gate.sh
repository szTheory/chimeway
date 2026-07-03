#!/usr/bin/env bash
# Aggregate required-lane results for the CI gates (CI-04, D-09).
#
# Reproduces the ci.yml pr-gate / ci-gate required-lane loop so the same
# pass/fail decision is runnable locally with the identical command. Each
# argument names an environment variable holding a lane's result (the workflow
# binds them to `needs.<lane>.result`, e.g. LINT=success). Any lane whose value
# is not exactly `success` (covers failure / skipped / cancelled) is printed and
# forces a non-zero exit.
#
# Usage: LINT=success TEST=success scripts/ci/aggregate-gate.sh LINT TEST ...
set -euo pipefail

failed=0
for lane in "$@"; do
  result="${!lane}"
  if [[ "$result" != "success" ]]; then
    echo "Required lane $lane: $result"
    failed=1
  fi
done

if [[ "$failed" -ne 0 ]]; then
  echo "gate failed: one or more required lanes did not succeed."
  exit 1
fi

echo "gate passed: all required lanes succeeded."
