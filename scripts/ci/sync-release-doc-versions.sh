#!/usr/bin/env bash
set -euo pipefail

version=${1:-}

if [[ ! "$version" =~ ^([0-9]+)\.([0-9]+)\.[0-9]+([+-][0-9A-Za-z.-]+)?$ ]]; then
  echo "usage: $0 MAJOR.MINOR.PATCH" >&2
  exit 64
fi

constraint="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"
files=(
  README.md
  guides/introduction/installation.md
  guides/introduction/golden-path.md
  guides/introduction/inbox-integration.md
)

for file in "${files[@]}"; do
  before=$(grep -Ec '\{:chimeway, "~> [0-9]+\.[0-9]+"\}' "$file" || true)

  if [ "$before" -ne 1 ]; then
    echo "release docs: expected exactly one Chimeway constraint in $file, found $before" >&2
    exit 1
  fi

  CW_RELEASE_CONSTRAINT="$constraint" perl -0pi -e \
    's/\{:chimeway, "~> \d+\.\d+"\}/{:chimeway, "~> $ENV{CW_RELEASE_CONSTRAINT}"}/g' \
    "$file"

  grep -Fq "{:chimeway, \"~> $constraint\"}" "$file"
done

echo "release docs: aligned Chimeway constraints to ~> $constraint"
