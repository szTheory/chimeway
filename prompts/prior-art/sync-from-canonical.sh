#!/usr/bin/env bash
# Copy the seven shared OSS deep-research files from rulestead into oss-deep-research/.
# Usage: RULESTEAD_ROOT=/path/to/rulestead ./sync-from-canonical.sh
# Default RULESTEAD_ROOT: sibling ../rulestead next to chimeway (both under ~/projects).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST_DIR="${SCRIPT_DIR}/oss-deep-research"
ROOT_DEFAULT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
RULESTEAD_ROOT="${RULESTEAD_ROOT:-${ROOT_DEFAULT}/rulestead}"
SRC_DIR="${RULESTEAD_ROOT}/prompts"

FILES=(
  "elixir-best-practices-deep-research.md"
  "elixir-opensource-libs-best-practices-deep-research.md"
  "elixir-oss-lib-ci-cd-best-practices-deep-research.md"
  "phoenix-best-practices-deep-research.md"
  "ecto-best-practices-deep-research.md"
  "phoenix-live-view-best-practices-deep-research.md"
  "elixir-plug-ecto-phoenix-system-design-best-practices-deep-research.md"
)

if [[ ! -d "${SRC_DIR}" ]]; then
  echo "error: canonical prompts dir not found: ${SRC_DIR}" >&2
  echo "Set RULESTEAD_ROOT to your rulestead repo root." >&2
  exit 1
fi

mkdir -p "${DEST_DIR}"
for f in "${FILES[@]}"; do
  if [[ ! -f "${SRC_DIR}/${f}" ]]; then
    echo "error: missing source file: ${SRC_DIR}/${f}" >&2
    exit 1
  fi
  cp -f "${SRC_DIR}/${f}" "${DEST_DIR}/${f}"
  echo "copied ${f}"
done

echo "done -> ${DEST_DIR}"
