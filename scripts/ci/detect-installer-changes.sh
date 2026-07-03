#!/usr/bin/env bash
# Detect installer-related changes for the install_golden_contract gate (CI-04, D-09).
#
# Reproduces the ci.yml `install_golden_contract` detect step: diffs the current
# HEAD against the base ref and prints a concrete conclusion to stdout —
# `run=true` when any installer surface changed, `run=false` otherwise. The CI
# step appends this line to $GITHUB_OUTPUT; locally it just prints the verdict.
#
# The grep -E pattern below is copied VERBATIM from ci.yml. Paraphrasing it
# would silently narrow what gates the installer contract, so the release-gate
# contract test asserts representative triggers live here unchanged.
#
# Usage: scripts/ci/detect-installer-changes.sh [base_ref]
#   base_ref defaults to $GITHUB_BASE_REF, then to "main".
set -euo pipefail

base_ref="${1:-${GITHUB_BASE_REF:-main}}"

git fetch origin "$base_ref" --depth=1

if git diff --name-only "origin/${base_ref}...HEAD" | grep -qE '^priv/chimeway_migrations/|^lib/mix/tasks/chimeway\.gen\.migrations\.ex|^lib/chimeway/install/|^test/chimeway/install/|^test/chimeway/migration_contract_test\.exs$|^test/fixtures/installer_golden_prefixed/|^test/fixtures/installer_golden_public/|^test/support/installer_fixture\.ex|^mix\.exs$|^\.github/workflows/ci\.yml$|^\.formatter\.exs$|^\.credo\.exs$'; then
  echo "run=true"
else
  echo "run=false"
fi
