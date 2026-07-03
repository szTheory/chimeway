#!/usr/bin/env bash
# Sigra auth integration proof lanes, extracted from ci.yml verify_sigra (CI-04, D-09).
#
# Reproduces the two proof invocations the verify_sigra job used to run inline so
# they are runnable locally with the identical commands, timeouts, and env-var
# contract. The release-gate contract test asserts every load-bearing string here.
#
# The verify_sigra job keeps its own job-level env (SIGRA_PATH, PG* vars,
# CHIMEWAY_SKIP_ACCRUE_DEP, CHIMEWAY_SKIP_THREADLINE_DEP) and its checkout /
# setup-beam / cache / "Prepare root test database" steps; this script owns only
# the proof-runner env and commands. Env vars default to the CI contract but can
# be overridden by the caller so the script behaves identically locally.
#
# Usage: scripts/ci/sigra-proof.sh [root|demo|all]   (default: all)
#   root  - run the root Sigra proof lane (ci_proof_runner.exs)
#   demo  - run the demo-host Sigra proof lane (sigra_auth_proof_test.exs)
#   all   - run root then demo
set -euo pipefail

lane="${1:-all}"

# Job-level Sigra dependency contract (mirrors verify_sigra job env in ci.yml).
export CHIMEWAY_SKIP_ACCRUE_DEP="${CHIMEWAY_SKIP_ACCRUE_DEP:-1}"
export CHIMEWAY_SKIP_THREADLINE_DEP="${CHIMEWAY_SKIP_THREADLINE_DEP:-1}"

run_root() {
  (
    export CHIMEWAY_FORCE_SIGRA_TEST_REPO_SETUP=1
    export CHIMEWAY_MANUAL_REPO_START=1
    export CHIMEWAY_SKIP_OBAN=1
    timeout 300s elixir $(find _build/test/lib -type d -name ebin -print | sed 's/^/-pa /') test/support/sigra/ci_proof_runner.exs
  )
}

run_demo() {
  (
    cd examples/chimeway_demo_host
    export CHIMEWAY_SKIP_THREADLINE_DEP=1
    export CHIMEWAY_SKIP_MAILGLASS_DEP=1
    export CHIMEWAY_SKIP_SIGRA_TRANSITIVE_DEP=1
    export CHIMEWAY_PATH=../..
    export SIGRA_PATH="${SIGRA_PATH:?SIGRA_PATH must point at the sigra checkout}"
    mix deps.get
    timeout 600s mix deps.compile
    timeout 300s mix compile
    timeout 300s mix test --no-compile test/demo_host_web/sigra_auth_proof_test.exs --only sigra --warnings-as-errors --trace
  )
}

case "$lane" in
  root) run_root ;;
  demo) run_demo ;;
  all)
    run_root
    run_demo
    ;;
  *)
    echo "usage: scripts/ci/sigra-proof.sh [root|demo|all]" >&2
    exit 2
    ;;
esac
