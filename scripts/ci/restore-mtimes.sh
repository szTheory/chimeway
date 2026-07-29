#!/usr/bin/env bash
# Make a warm `_build` cache trustworthy to `mix` after an actions/cache restore,
# WITHOUT hiding real source changes.
#
# Problem (Phase-88 warm-recompile regression): actions/checkout + tar
# cache-restore reset file mtimes, so `mix` treats every source as newer than the
# restored `_build` compile manifest and recompiles the whole app+deps despite a
# cache HIT. That defeats the compile-once producer/consumer split.
#
# Fix (correctness-preserving — never suppresses a genuine change):
#   1. Tracked sources -> their newest git commit time. A file changed in a recent
#      commit carries a recent mtime, so it stays newer than any older cached
#      artifact and STILL recompiles. Unchanged files get old, stable mtimes, so
#      the restored `_build` is correctly seen as up-to-date.
#        (Requires full history: the caller's checkout must use fetch-depth: 0.
#         With a shallow depth-1 clone every file collapses to HEAD's timestamp
#         and this fix does nothing useful.)
#   2. deps/ -> a fixed old date. deps are pinned by the mix.lock hash that is part
#      of every Phase-88 cache key, so a lock change busts the cache entirely;
#      within one key the dep sources are immutable and safe to age.
set -euo pipefail

python3 -c '
import subprocess, os
p = subprocess.run(
    ["git", "-c", "core.quotePath=false", "log", "--format=@%ct", "--name-only", "HEAD"],
    capture_output=True, text=True, check=True,
)
ts = None
seen = set()
n = 0
for line in p.stdout.splitlines():
    if line.startswith("@"):
        ts = int(line[1:])
    elif line and ts is not None and line not in seen:
        seen.add(line)
        if os.path.lexists(line):
            os.utime(line, (ts, ts))
            n += 1
print(f"restore-mtimes: set {n} tracked source files to their git commit mtime")
'

if [ -d deps ]; then
  find deps -exec touch -d '2000-01-01T00:00:00' {} + 2>/dev/null || true
  echo "restore-mtimes: aged deps/ to 2000-01-01 (lock-pinned by cache key, safe)"
fi
