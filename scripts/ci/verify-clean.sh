#!/usr/bin/env bash
set -euo pipefail

repository_status=$(git status --porcelain=v1 --untracked-files=all)

if [ -z "$repository_status" ]; then
  echo "verify.clean: clean"
  exit 0
fi

echo "verify.clean: repository is dirty" >&2
printf '%s\n' "$repository_status" >&2
exit 1
