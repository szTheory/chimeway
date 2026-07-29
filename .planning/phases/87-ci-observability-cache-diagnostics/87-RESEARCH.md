# Phase 87: CI Observability & Cache Diagnostics - Research

**Researched:** 2026-07-28
**Domain:** GitHub Actions workflow instrumentation (cache diagnostics, Mix recompile counting, per-step timing, baseline recording) for an Elixir/Mix Hex library CI pipeline
**Confidence:** HIGH (mechanics verified against official sources; Mix stdout format and REST-API field names tagged where assumed)

## Summary

Phase 87 is purely **additive CI instrumentation**. The pipeline in `.github/workflows/ci.yml` has ~14 build lanes (plus 2 gate-aggregator jobs with no build) that each run `setup-beam` → `actions/cache@0057852…` (v4) → `mix deps.get` → an implicit compile hidden inside `mix ecto.create` → a `verify.*` task. The goal is to make three things visible in every build lane's job summary — cache hit/miss per cache, recompiled-file counts (deps vs. app), and per-step durations — and to commit the already-measured pre-optimization baseline with a durable run link so Phase 88+ can prove wins by delta.

The four requirements decompose into four independent, low-risk mechanisms, all buildable from **shared `scripts/ci/*.sh` helpers** (the repo's existing convention) plus small per-lane wiring. No new external action is needed — everything runs on tools already present on `ubuntu-latest` (`bash`, `gh`, `jq`, coreutils) and the already-SHA-pinned `actions/cache@v4`, whose step outputs (`cache-hit`, `cache-primary-key`, `cache-matched-key`) are exactly what OBS-01 needs. A **composite action is the wrong tool** here because a composite action can only observe steps declared *inside itself* — it cannot read the parent job's `actions/cache` step outputs or time sibling steps, which OBS-01 and OBS-03 both require.

**Primary recommendation:** Ship three focused `scripts/ci/obs-*.sh` helpers plus one **trailing `if: always()` "render observability summary" step per build lane** that consolidates all three tables (cache / recompile / timing) into a single write to `$GITHUB_STEP_SUMMARY`. Add stable `id:`s to the cache steps, replace the hidden compile with an explicit **behavior-neutral** `mix deps.compile` + `mix compile` (no `--warnings-as-errors` — that upgrade belongs to Phase 88 / CACHE-03), and commit the baseline to `.planning/CI-PERF-BASELINE.md` with a `github.run_id` permalink. Validate via the repo's established ExUnit CI-script contract pattern (`System.cmd` fed fixture logs) plus a live run-link.

## Phase Constraints (Milestone Invariant — treat as locked)

Sourced from `.planning/ROADMAP.md` and `.planning/REQUIREMENTS.md` (no CLAUDE.md or CONTEXT.md exists for this phase). These bind the planner exactly like locked decisions:

- **doc/config/CI-only. NO runtime library behavior change.** Phase 87 may only touch `.github/workflows/*`, `.github/actions/*` (if a composite action were introduced — it is NOT recommended here), `scripts/ci/*.sh`, and a committed baseline doc. `[CITED: ROADMAP.md L28]`
- **Observability is purely additive** — it must not change *what any lane builds or tests*, and must not *materially slow* lanes. `[CITED: additional_context]`
- **Every action reference must be SHA-pinned.** The repo pins every `uses:` by SHA (`actions/cache@0057852bfaa89a56745cba8c7296529d2fc39830`, `setup-beam@8251c48…`, `checkout@34e1148…`). Any new action would need a SHA — so prefer shell helpers, which need none. `[VERIFIED: ci.yml]`
- **Baseline is ALREADY measured — do NOT re-measure.** OBS-04 is about the *recording mechanism + durable run link*, not re-deriving numbers. `[CITED: additional_context]`
- **Avoid over-engineering / standard tools** (milestone "Out of Scope" fence rejects self-hosted runners, bespoke cache servers, mtime hacks). `[CITED: REQUIREMENTS.md L63-73]`
- Runner ≈ 4 cores, `ubuntu-latest`, Elixir 1.19 / OTP 26+27, Postgres 15 service. `[VERIFIED: ci.yml]`

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| OBS-01 | Per-lane cache hit/miss in job summary for every build lane's `_build`/`deps` caches, via `$GITHUB_STEP_SUMMARY` | Pattern 1 (cache-outputs classification via `id:` + `cache-hit`/`cache-matched-key`); Code Example 1 |
| OBS-02 | Recompiled-file count (deps vs. app, split) on each build lane, after `deps.get`/`mix compile`, correct 0 on warm cache | Pattern 2 (instrumented `deps.compile`+`compile`, `Compiling N files` parse); Code Example 2; Pitfall 1 (pipefail/`set -e`) |
| OBS-03 | Per-step timing table (step name + duration) to `$GITHUB_STEP_SUMMARY` for each lane | Pattern 3 (REST `…/jobs` query correlated by `runner_name`, single trailing step); Code Example 3; Alternatives table |
| OBS-04 | Pre-optimization baseline recorded WITH a run link so later wins are provable by delta | Pattern 4 (`github.run_id` permalink + committed `.planning/CI-PERF-BASELINE.md`); Code Example 4 |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Cache hit/miss classification | CI workflow step outputs (`actions/cache` → `steps.<id>.outputs`) | Shell helper (formatting) | Only the parent job's `steps` context exposes cache outputs; a shell script formats them. Composite actions cannot read sibling-step outputs. |
| Recompile counting | Shell helper wrapping `mix` | Mix compiler stdout | Mix has no counter API; the compiler's `Compiling N files` stdout is the only robust signal. Shell owns capture+parse. |
| Per-step timing | GitHub Actions REST API (`/runs/{id}/jobs`) | Shell/`gh`+`jq` in one trailing step | The Actions control plane already records `started_at`/`completed_at` per step; querying it needs zero per-step boilerplate. |
| Summary rendering | Single trailing `$GITHUB_STEP_SUMMARY` write per job | Scratch files under `$RUNNER_TEMP` | Consolidating one write per job stays well under the 20-summaries/job cap and keeps tables clean. |
| Baseline record | Git-committed markdown doc | Run permalink (`github.run_id`) + optional uploaded artifact | Git is the durable store; the run URL is the citable evidence. |

## Standard Stack

No libraries or packages are installed by this phase. The "stack" is GitHub Actions primitives + tools preinstalled on `ubuntu-latest`.

### Core
| Tool / Primitive | Version | Purpose | Why Standard |
|------------------|---------|---------|--------------|
| `actions/cache` | v4 (pinned `0057852…`) | Emits `cache-hit`/`cache-primary-key`/`cache-matched-key` step outputs consumed by OBS-01 | Already pinned repo-wide; official cache action `[VERIFIED: ci.yml + actions/cache README]` |
| `$GITHUB_STEP_SUMMARY` | GHA built-in | Markdown sink rendered on the job page | Native job-summary mechanism `[CITED: github.blog job-summaries]` |
| `gh` CLI + `jq` | preinstalled on `ubuntu-latest` | REST query for per-step timings (OBS-03) | Both ship on GitHub-hosted runners `[ASSUMED — confirm on first run]` |
| GitHub REST `GET /repos/{o}/{r}/actions/runs/{id}/attempts/{n}/jobs` | v3 | Returns each step's `name`/`started_at`/`completed_at`/`runner_name` | Official Actions REST API `[ASSUMED — field names from training; verify first run]` |
| `bash` + coreutils (`grep`, `awk`, `paste`, `date`) | runner default | Parse compile output, compute durations, format tables | Present everywhere; matches existing `scripts/ci/*.sh` `[VERIFIED: existing scripts]` |

### Supporting
| Tool | Purpose | When to Use |
|------|---------|-------------|
| `actions/upload-artifact` (would need SHA pin) | Persist rendered summaries as a downloadable artifact | OPTIONAL for OBS-04 richer evidence — the run permalink alone satisfies the requirement; only add if the planner wants a downloadable copy |
| `bash SECONDS` / `date +%s` wrapping helper | Sub-second precise per-step timing | FALLBACK for OBS-03 if the REST approach proves flaky/permission-blocked |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Shared `scripts/ci/*.sh` helpers | Local composite action `.github/actions/ci-observability/` | Composite action **cannot** read the parent job's cache-step outputs or time sibling steps → cannot satisfy OBS-01/OBS-03. Rejected. |
| REST `/jobs` timing (one trailing step) | Wrap every `run:` with a `SECONDS` timer helper | Wrapping is precise but O(steps×lanes) boilerplate (~110 edits) and rewrites every step — violates "don't turn every step into boilerplate." Kept as fallback only. |
| Committed baseline doc + permalink | Job-summary artifact only | Artifacts expire; git + run URL are durable. Use artifact only as a supplement. |

## Package Legitimacy Audit

**N/A — this phase installs no packages and introduces no new `uses:` action.** It reuses the already-SHA-pinned `actions/cache@0057852bfaa89a56745cba8c7296529d2fc39830`, `erlef/setup-beam@8251c48…`, and `actions/checkout@34e1148…`, and shell tooling preinstalled on the runner. If the planner opts into the optional summary artifact, `actions/upload-artifact` must be added **pinned by SHA** (resolve the current v4 SHA at plan time) — the only package-legitimacy action item, and it is optional.

## Architecture Patterns

### System Architecture Diagram

```
                         ┌──────────────────────── one build lane (× ~14) ─────────────────────────┐
 checkout ─▶ setup-beam ─▶ cache(main _build)  id: cache_main   ─┐
                          cache(demo _build)   id: cache_demo   ─┼─▶ steps.*.outputs.cache-hit
                          cache(nested _build) id: cache_nested ─┘        cache-matched-key
                                   │                                      cache-primary-key
                                   ▼
                          mix deps.get
                                   │
                                   ▼
             scripts/ci/obs-recompile.sh  ──▶ mix deps.compile │ tee ─▶ $RUNNER_TEMP/obs-deps.log
             (explicit, behavior-neutral)     mix compile      │ tee ─▶ $RUNNER_TEMP/obs-app.log
                                   │                                   ▲ parse "Compiling N files"
                                   ▼                                   └─▶ deps_count / app_count
             mix ecto.create/migrate ─▶ verify.* (real work, UNCHANGED)
                                   │
                                   ▼
   [if: always()]  scripts/ci/obs-summary.sh
        ├─ read CACHE_*_HIT/MATCHED/PRIMARY env (from steps.*.outputs) ─▶ Cache table
        ├─ read $RUNNER_TEMP/obs-*.log counts                          ─▶ Recompile table
        ├─ gh api /runs/$RUN_ID/attempts/$ATTEMPT/jobs                 ─▶ Timing table
        │     └─ jq select(.runner_name==$RUNNER_NAME, in_progress)
        └─ append run permalink ──▶ single write to $GITHUB_STEP_SUMMARY

 Baseline (OBS-04): one push run of main ─▶ record run URL + numbers ─▶ commit .planning/CI-PERF-BASELINE.md
```

### Recommended Project Structure
```
scripts/ci/
├── obs-cache-row.sh     # classify one cache: (hit, matched, primary) -> HIT|PARTIAL|MISS + md row
├── obs-recompile.sh     # explicit deps.compile + compile; tee+parse; emit deps/app counts
├── obs-summary.sh       # trailing step: assemble 3 tables + run link -> $GITHUB_STEP_SUMMARY
.planning/
└── CI-PERF-BASELINE.md  # OBS-04 committed baseline + run permalink + delta ledger
```
(Optionally fold cache-row logic into `obs-summary.sh` to keep the surface to two scripts; the research keeps them separate for unit-testability.)

### Pattern 1: Cache hit/miss classification from `actions/cache` outputs (OBS-01)
**What:** Give each `actions/cache` step a stable `id:`, then classify its outputs.
**When to use:** Every build lane; one row per cache step (lanes have 1–4 caches).
**Classification logic** `[VERIFIED: actions/cache README]`:
- `cache-hit == 'true'` → **EXACT HIT** (primary key matched).
- `cache-hit != 'true'` **AND** `cache-matched-key` non-empty → **PARTIAL** (a `restore-keys` prefix matched; `cache-matched-key` ≠ `cache-primary-key`).
- `cache-matched-key` empty → **MISS** (nothing restored).

The repo's cache steps currently have **no `id:`** — the plan MUST add stable ids (e.g. `cache_main`, `cache_demo`, `cache_nested_inbox`, `cache_playwright`). Outputs are only reachable via the `steps` context in YAML, so they are passed into the shell helper via `env:` (a script cannot read `steps.*`).

### Pattern 2: Recompile counting via explicit instrumented compile (OBS-02)
**What:** Replace the compile hidden inside `mix ecto.create` with an explicit, behavior-neutral `mix deps.compile` then `mix compile`, teeing each to a log, and count `Compiling N files` lines.
**Why this split cleanly separates deps vs. app:** `mix deps.compile` compiles only dependencies (prints `==> dep` + `Compiling N files` per dep); a subsequent `mix compile` then compiles only the **app** (deps already built). Sum the counts from each log separately. On a fully warm cache both commands print nothing → both counts correctly report **0**. `[ASSUMED — Mix stdout format "Compiling N files (.ex)"; verify on first run]`
**Behavior-neutrality argument (invariant compliance):** the same artifacts are built (deps + app were already compiled implicitly by `ecto.create`); this only makes the existing compile *explicit and measurable* and makes `ecto.create` a fast DB op. **Do NOT add `--warnings-as-errors`** in Phase 87 — that would change lane pass/fail semantics and is explicitly Phase 88's CACHE-03 change. Use plain `mix compile`.
**Warm-cache cost:** near-zero (both commands are manifest-timestamp no-ops when nothing changed).
**Partner lanes (accrue/threadline/sigra):** the probe must run under the same job env (including `CHIMEWAY_SKIP_*` and `*_PATH`) so counts reflect the real path-dep graph. accrue/sigra lanes already run `mix deps.compile`; there the probe simply instruments the existing command.

### Pattern 3: Per-step timing via REST API in a single trailing step (OBS-03)
**What:** In the trailing `obs-summary.sh` step, query `GET /repos/{owner}/{repo}/actions/runs/{run_id}/attempts/{attempt}/jobs`, correlate the current job by `runner_name == $RUNNER_NAME` (unique per concurrently-running job, incl. each matrix leg) with `status == in_progress`, and compute `completed_at − started_at` per step.
**Why this over wrapping every step:** zero per-step boilerplate — one step per lane covers *all* steps. We are already adding a trailing summary step, so timing is free there.
**Caveats to encode:** (a) timestamps are **1-second resolution** — fine for a 135s compile; (b) needs `actions: read` on `GITHUB_TOKEN` (default token has it unless the repo restricts; a `permissions:` block is Phase 91/QUAL-03, so Phase 87 relies on the default and **degrades gracefully**); (c) the API can lag a second for just-completed steps — the summary step's own row may be absent/partial, which is acceptable. Wrap the `gh api` call so failure prints "timing unavailable" rather than failing the lane.
**Fallback:** a `SECONDS`-based wrap helper if the REST path is blocked — precise but invasive.

### Pattern 4: Baseline recording with durable run link (OBS-04)
**What:** Commit `.planning/CI-PERF-BASELINE.md` containing the already-measured numbers, the commit SHA, and a **run permalink** built from `${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}` (append `/attempts/${{ github.run_attempt }}` for the exact attempt). Include a delta ledger table Phase 88+ appends "after" rows to.
**Where:** `.planning/CI-PERF-BASELINE.md` — sits beside the existing `.planning/CI-HARDENING-BACKLOG.md`, matching where this repo already keeps CI operational docs. `[VERIFIED: REQUIREMENTS.md references .planning/CI-HARDENING-BACKLOG.md]`
**Run link durability:** Actions *run pages* persist far longer than log/artifact retention, so the URL in git is the citable evidence; committing the numbers in git makes them permanent regardless of run retention. Optionally also `upload-artifact` the rendered summaries for richer evidence (not required).

### Anti-Patterns to Avoid
- **One `$GITHUB_STEP_SUMMARY` write per instrumented step.** Only 20 step-summaries render per job `[CITED: actions/runner#4337]`; with many steps you'd blow the cap and fragment the tables. **Consolidate into one trailing write per job** using `$RUNNER_TEMP` scratch files.
- **Composite action to "DRY up" observability.** It can't see sibling cache-step outputs or time sibling steps. Wrong tool.
- **`mix compile --warnings-as-errors` in Phase 87.** Changes lane pass/fail → violates the additive-only invariant and preempts Phase 88.
- **Printing raw env / `DATABASE_URL` / secrets into the summary.** On a public repo the job summary is world-readable — emit only cache keys, counts, and durations.
- **`paths:` filters or gating the real work on the probe.** Instrumentation steps must be `if: always()` and never a `needs:`/gate dependency of the verify work.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Cache hit/miss detection | Manual key hashing / `ls` of cache dir | `actions/cache` `cache-hit`/`cache-matched-key` outputs | The action already computes exact vs. partial vs. miss `[VERIFIED]` |
| Per-step timing | Bespoke `date` wrapper on every step | REST `/jobs` `started_at`/`completed_at` | Control plane already records it; no per-step edits |
| Recompile counting | A custom Mix compiler tracer / `.beam` mtime diffing | Parse `Compiling N files` from `deps.compile`/`compile` stdout | mtime diffing is the exact "touch-based hack" the milestone bans `[CITED: REQUIREMENTS.md L70]`; stdout is robust and reports 0 when warm |
| Markdown job summary | HTML/JS report | `$GITHUB_STEP_SUMMARY` markdown | Native, renders inline on the run page |
| Run permalink | Hard-coded URL | `github.server_url`/`github.repository`/`github.run_id` contexts | Correct across forks/attempts |

**Key insight:** every OBS-01..03 signal already exists somewhere the platform exposes (cache step outputs, compiler stdout, REST step timestamps). Phase 87 is *surfacing*, not *computing* — resist building measurement machinery.

## Runtime State Inventory

Not a rename/refactor/migration phase — no stored data, service config, OS-registered state, secrets, or build artifacts carry a renamed string. **None — verified: this phase only adds CI instrumentation files and one committed doc; it renames nothing and migrates no data.**

## Common Pitfalls

### Pitfall 1: `set -e` / `pipefail` aborts on the parse, or swallows compile failure
**What goes wrong:** `grep` finds no `Compiling N files` on a warm cache and exits 1; under `set -e` the step aborts. Conversely, `mix compile 2>&1 | tee log` under `pipefail` correctly fails on a compile error — but then the count never prints.
**Why:** bash error-handling interacts badly with both "no matches" and pipeline exit codes.
**How to avoid:** capture the pipe status explicitly and guard the parse:
```bash
set -uo pipefail                 # NOT -e around the parse
mix compile 2>&1 | tee "$app_log"; rc=${PIPESTATUS[0]}
app_count=$(grep -oE 'Compiling [0-9]+ files' "$app_log" | grep -oE '[0-9]+' | paste -sd+ - | bc 2>/dev/null || echo 0)
app_count=${app_count:-0}
# ... emit count to scratch ...
exit "$rc"                       # preserve real compile pass/fail
```
**Warning signs:** lane goes green but summary shows no recompile row; or a warm run fails at the grep step.

### Pitfall 2: Only 20 step-summaries render per job; 1 MiB per-step cap
**What goes wrong:** many instrumented steps each writing to `$GITHUB_STEP_SUMMARY` → summaries beyond the 20th are dropped; a huge dump exceeds 1 MiB (1,048,576 bytes) and the summary upload fails with an error annotation. `[CITED: github.blog job-summaries; actions/runner#4337]`
**How to avoid:** accumulate into `$RUNNER_TEMP` scratch files; write **once** in the trailing step. Tables here are tiny (tens of rows) — nowhere near 1 MiB.

### Pitfall 3: Matrix legs and job self-correlation
**What goes wrong:** the `test` job matrix (OTP 26, 27) is **two separate jobs**, each with its own `$GITHUB_STEP_SUMMARY` — they do NOT collide. But correlating "which job am I?" via REST for timing is fiddly: `github.job` is the YAML key (`test`), while the API returns display names (`Test (Elixir 1.19 / OTP 27)`).
**How to avoid:** correlate on `runner_name == $RUNNER_NAME` (unique per running job incl. each matrix leg) filtered to `status == in_progress`. Do not match on job name.
**Warning signs:** timing table shows another leg's steps, or is empty.

### Pitfall 4: `install_golden_contract` conditional steps
**What goes wrong:** that lane gates every step on `steps.detect.outputs.run == 'true'`. On push (`github.event_name != 'pull_request'`) detect forces `run=true`; on PRs it may skip. Instrumentation steps must carry the **same** `if:` guard, else they run when the lane body was skipped.
**How to avoid:** mirror the `if: steps.detect.outputs.run == 'true'` guard on the probe/summary steps (the trailing summary can be `if: always() && steps.detect.outputs.run == 'true'`).

### Pitfall 5: Public-repo summary leaks
**What goes wrong:** dumping `env` or `DATABASE_URL` into the summary exposes it publicly.
**How to avoid:** emit only cache keys, counts, durations, and the run URL — never raw env.

## Code Examples

> Snippets are illustrative contracts for the planner, not drop-in final code. Mix stdout format and REST field names are `[ASSUMED]` pending first-run confirmation.

### Code Example 1: OBS-01 — cache table (per-lane wiring + helper)
```yaml
# In each build lane — add id: to every cache step:
- uses: actions/cache@0057852bfaa89a56745cba8c7296529d2fc39830
  id: cache_main
  with:
    path: |
      deps
      _build
    key: ${{ runner.os }}-mix-${{ hashFiles('**/mix.lock') }}
    restore-keys: ${{ runner.os }}-mix-
# ...additional cache steps get id: cache_demo, cache_nested_inbox, etc.
```
```bash
# scripts/ci/obs-cache-row.sh  — classify one cache
# usage: obs-cache-row.sh "<label>" "<cache-hit>" "<matched-key>" "<primary-key>"
label="$1"; hit="$2"; matched="$3"; primary="$4"
if [ "$hit" = "true" ]; then state="✅ EXACT HIT"
elif [ -n "$matched" ]; then state="🟡 PARTIAL (restore-key)"
else state="❌ MISS"; fi
printf '| %s | %s | `%s` | `%s` |\n' "$label" "$state" "${matched:-—}" "$primary" \
  >> "$RUNNER_TEMP/obs-cache.md"
```
Rendered table header (written by `obs-summary.sh`):
```
### Cache
| Cache | State | Matched key | Primary key |
|-------|-------|-------------|-------------|
```

### Code Example 2: OBS-02 — recompile probe (replaces hidden compile)
```yaml
- name: Compile (instrumented — deps then app)
  shell: bash
  run: scripts/ci/obs-recompile.sh
```
```bash
#!/usr/bin/env bash
# scripts/ci/obs-recompile.sh — explicit, behavior-neutral compile + recompile counts.
set -uo pipefail
deps_log="$RUNNER_TEMP/obs-deps.log"; app_log="$RUNNER_TEMP/obs-app.log"
mix deps.compile 2>&1 | tee "$deps_log"; drc=${PIPESTATUS[0]}
mix compile      2>&1 | tee "$app_log"; arc=${PIPESTATUS[0]}
count() { grep -oE 'Compiling [0-9]+ files' "$1" 2>/dev/null | grep -oE '[0-9]+' \
          | paste -sd+ - | bc 2>/dev/null || true; }
deps_n=$(count "$deps_log"); app_n=$(count "$app_log")
printf '%s\n' "${deps_n:-0} ${app_n:-0}" > "$RUNNER_TEMP/obs-recompile.txt"
[ "$drc" -eq 0 ] && [ "$arc" -eq 0 ]   # preserve real compile failure
```

### Code Example 3: OBS-03 — timing via REST, correlated by runner_name
```bash
# inside scripts/ci/obs-summary.sh (needs GH_TOKEN=${{ github.token }})
api="/repos/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID/attempts/$GITHUB_RUN_ATTEMPT/jobs"
gh api --paginate "$api" 2>/dev/null | jq -r --arg rn "$RUNNER_NAME" '
  .jobs[] | select(.runner_name==$rn and .status=="in_progress") | .steps[]
  | select(.started_at != null and .completed_at != null)
  | [.name, ((.completed_at|fromdateiso8601) - (.started_at|fromdateiso8601))] | @tsv' \
  | awk -F'\t' '{printf "| %s | %ds |\n", $1, $2}' \
  >> "$RUNNER_TEMP/obs-timing.md" || echo "| _timing unavailable_ | — |" >> "$RUNNER_TEMP/obs-timing.md"
```

### Code Example 4: OBS-04 — run permalink + trailing summary write
```yaml
- name: CI observability summary
  if: always()          # render even when the lane fails
  shell: bash
  env:
    GH_TOKEN: ${{ github.token }}
    RUN_URL: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}/attempts/${{ github.run_attempt }}
    CACHE_MAIN_HIT: ${{ steps.cache_main.outputs.cache-hit }}
    CACHE_MAIN_MATCHED: ${{ steps.cache_main.outputs.cache-matched-key }}
    CACHE_MAIN_PRIMARY: ${{ steps.cache_main.outputs.cache-primary-key }}
    # ...one HIT/MATCHED/PRIMARY triple per cache id in this lane...
  run: scripts/ci/obs-summary.sh
```
`obs-summary.sh` discovers caches generically (`compgen -e | grep -E '^CACHE_.*_HIT$'`), writes the three tables + `Run: $RUN_URL` in one append to `$GITHUB_STEP_SUMMARY`. Baseline doc skeleton:
```markdown
# CI Performance Baseline (v1.16, pre-optimization)
**Recorded:** 2026-07-28 · **Commit:** <sha> · **Run:** <RUN_URL from a push-to-main run>
| Metric | Baseline | Phase 88 after | Δ |
|--------|----------|----------------|---|
| ci-gate wall-clock | ~373–395s | | |
| install_golden job | 373s | | |
| hidden compile in ecto.create | ~135s | | |
| dep recompile, 3 identical-lock runs | dead-flat (cache never warms) | | |
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| CI perf "by feeling" / reading raw logs | Job-summary tables + committed baseline + run-link deltas | This phase | Every later optimization becomes provable |
| `set-output` workflow command | `$GITHUB_OUTPUT` / `$GITHUB_STEP_SUMMARY` env files | GHA 2022–2023 | Repo already uses `$GITHUB_OUTPUT` (detect step) — same idiom |
| Marketplace timing actions | Native REST `/jobs` step timestamps | — | No new pinned action; stays inside the SHA-pin fence |

**Deprecated/outdated:** `::set-output::` command (removed) — use `$GITHUB_OUTPUT`, which the repo already does.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Mix prints `Compiling N files (.ex)` to captured stdout for both `deps.compile` and `compile`, and prints nothing when warm | Pattern 2, Ex 2 | Recompile counts wrong/zero; mitigated — first run visibly confirms, parse falls back to 0 |
| A2 | REST `/jobs` returns per-step `started_at`/`completed_at` and job `runner_name`; `runner_name` uniquely identifies the running job | Pattern 3, Ex 3 | Timing table empty/misattributed; graceful "unavailable" fallback prevents lane failure |
| A3 | Default `GITHUB_TOKEN` has `actions: read` (no `permissions:` block today) | Pattern 3 | Timing call 403s → falls back to "unavailable"; planner can add `permissions: actions: read` (mind QUAL-03 overlap) |
| A4 | `gh` and `jq` are preinstalled on `ubuntu-latest` | Standard Stack | If absent, add a setup step; both are standard on GitHub-hosted runners |
| A5 | Adding explicit `mix deps.compile`+`compile` before `ecto.create` is behavior-neutral (same artifacts) | Pattern 2 | If it perturbed a lane, revert to parsing existing compile output; but this is the standard warm-up idiom already used in verify_example/journeys `[VERIFIED: ci.yml L231-237]` |

## Open Questions (RESOLVED)

*All three settled at planning time and consumed by the Phase 87 plans (87-01/02/03).*

1. **Two scripts vs. three?** — **RESOLVED: 2 scripts.**
   - Known: `obs-cache-row.sh` is separable for unit-testing but its logic is ~6 lines.
   - Unclear: whether the planner prefers folding it into `obs-summary.sh`.
   - Recommendation: keep `obs-recompile.sh` + `obs-summary.sh` (2 scripts); inline cache classification into the summary script and unit-test it via `System.cmd`. **Adopted in 87-01.**
2. **Add `permissions: actions: read` now, or rely on default token?** — **RESOLVED: default token now; defer explicit block to Phase 91/QUAL-03.**
   - Known: no top-level `permissions:` block exists; QUAL-03 (Phase 91) will add least-privilege.
   - Recommendation: rely on the default token in Phase 87 with graceful degradation; leave the explicit `permissions:` block to Phase 91 to avoid double-editing. Flag the coupling in the plan. **Coupling flagged in 87-01/87-02.**
3. **Scope: which jobs count as "build lanes"?** — **RESOLVED: the 14 setup-beam+cache+compile lanes; aggregators excluded.**
   - The 2 aggregator jobs (`pr-gate`, `ci-gate`) run no build → no cache/recompile tables (a trivial timing table is optional). Instrument the ~14 lanes that run `setup-beam` + cache + compile. **87-01 does `lint`; 87-02 fans out to the other 13.**

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `bash` + coreutils | all obs scripts | ✓ (ubuntu-latest) | — | — |
| `gh` CLI | OBS-03 REST timing | ✓ (ubuntu-latest, preinstalled) `[ASSUMED]` | — | `curl` + token |
| `jq` | OBS-03 parse | ✓ (ubuntu-latest, preinstalled) `[ASSUMED]` | — | `awk` parse |
| `bc` | OBS-02 sum | ✓ | — | `awk '{s+=$1} END{print s}'` |
| `actions/cache@v4` outputs | OBS-01 | ✓ (already pinned) | v4 `0057852…` | — |
| `GITHUB_TOKEN` w/ `actions:read` | OBS-03 | ✓ default (unconfirmed under org policy) | — | graceful "timing unavailable" |

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** `gh`/`jq`/`GITHUB_TOKEN` scope — all degrade to a non-fatal "timing unavailable" row.

## Validation Architecture

Nyquist validation is **enabled** (`workflow.nyquist_validation: true`). This phase's "behaviors" are shell parsing + workflow wiring, not library code. The repo's established pattern is **ExUnit CI-script contract tests** (`test/chimeway/release_gate_contract_test.exs` already asserts load-bearing strings in `scripts/ci/*.sh` and that `ci.yml` invokes them verbatim). Extend that pattern rather than adding a new framework.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir 1.19 / OTP 27) — already present |
| Config file | `test/test_helper.exs` (existing) |
| Quick run command | `mix test test/chimeway/ci_observability_contract_test.exs --warnings-as-errors` (new file, Wave 0) |
| Full suite command | `mix ci.verify_gates` (contract lane) + a live CI run for run-link evidence |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| OBS-01 | cache classifier maps (hit/matched/primary) → HIT/PARTIAL/MISS; ci.yml gives each cache an `id:` and a summary step | unit + contract | `System.cmd` feeds 3 synthetic input triples to the classifier and asserts the 3 states; grep asserts every build-lane cache step has `id:` and each lane has an obs-summary step | ❌ Wave 0 |
| OBS-02 | recompile parser sums `Compiling N files`, splits deps/app, returns 0 on empty log | unit | `System.cmd` pipes a captured fixture compile log → asserts `deps_n`/`app_n`; empty log → `0 0` | ❌ Wave 0 |
| OBS-03 | timing renderer turns a fixture `/jobs` JSON into `| step | Ns |` rows; missing data → "unavailable" not failure | unit | `System.cmd` feeds fixture jobs-API JSON to a `jq` render path; assert rows + graceful fallback | ❌ Wave 0 |
| OBS-04 | baseline doc exists, contains a `actions/runs/` permalink and the 4 baseline facts | contract + human | ExUnit asserts `.planning/CI-PERF-BASELINE.md` exists and contains the run-URL pattern + the four numbers; human opens the linked run and confirms tables render | ❌ Wave 0 + live run |

### Sampling Rate
- **Per task commit:** `mix test test/chimeway/ci_observability_contract_test.exs`
- **Per wave merge:** `mix ci.verify_gates` (full contract lane)
- **Phase gate:** one live push-to-main run whose build-lane summaries visibly show all three tables; capture that run URL into the baseline doc; full `ci-gate` green.

### Wave 0 Gaps
- [ ] `test/chimeway/ci_observability_contract_test.exs` — covers OBS-01..04 (classifier/parser/timing via `System.cmd` + fixtures; ci.yml wiring grep; baseline-doc existence + run-link assertion)
- [ ] `test/fixtures/ci/compile_cold.log`, `compile_warm.log`, `jobs_api_sample.json` — parser fixtures
- [ ] `.planning/CI-PERF-BASELINE.md` — created + populated from a real push run (OBS-04 evidence of record)
- [ ] Optional: `shellcheck` invocation on new `scripts/ci/obs-*.sh` (matches repo's shell-hygiene posture; add as an advisory step)

## Security Domain

`security_enforcement` is not disabled in config (absent = enabled), but this is a CI/config-only phase with no auth/crypto/persistence/user-input surface. Applicable concerns are narrow:

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V5 Input Validation | minor | Parse only trusted first-party compiler stdout / own-run REST JSON; no untrusted input reaches the shell |
| V6 Cryptography | no | none |
| V7 Secrets / Data Exposure | **yes** | Job summaries are world-readable on a public repo — emit only cache keys, counts, durations, run URL; **never** echo `env`, `DATABASE_URL`, or `GITHUB_TOKEN` |
| Least privilege | yes | OBS-03 needs only `actions: read`; rely on default token now, formalize a `permissions:` block in Phase 91/QUAL-03 |

| Threat Pattern | STRIDE | Mitigation |
|----------------|--------|------------|
| Secret leak into public summary | Information Disclosure | Whitelist what the summary prints; code-review the obs scripts for `env`/secret echoes |
| Script injection via crafted branch/step names into `$GITHUB_STEP_SUMMARY` | Tampering | Values come from first-party mix/cache/REST outputs; render as markdown table cells, not eval'd |

## Sources

### Primary (HIGH confidence)
- `actions/cache` README — `cache-hit` (exact-match only), `cache-primary-key`, `cache-matched-key` semantics and `restore-keys` partial matching. `[CITED]`
- GitHub Blog "Supercharging GitHub Actions with Job Summaries" + `actions/runner#4337` — `$GITHUB_STEP_SUMMARY` 1 MiB/step cap and 20-summaries/job render limit. `[CITED]`
- Repo files: `.github/workflows/ci.yml`, `scripts/ci/*.sh`, `mix.exs`, `config/test.exs`, `.planning/{REQUIREMENTS,ROADMAP,STATE}.md`. `[VERIFIED]`

### Secondary (MEDIUM confidence)
- GitHub REST API for Actions (`/runs/{id}/jobs` step timing fields, `runner_name`) — from training; `[ASSUMED]`, first-run-confirmable.

### Tertiary (LOW confidence)
- Mix compiler stdout format `Compiling N files (.ex)` and `gh`/`jq` preinstall on `ubuntu-latest` — `[ASSUMED]`, confirmed cheaply on the first instrumented run.

## Metadata

**Confidence breakdown:**
- Cache diagnostics (OBS-01): HIGH — verified `actions/cache` outputs.
- Summary limits / DRY design: HIGH — verified size/step caps; composite-action limitation is structural.
- Recompile counting (OBS-02): MEDIUM — mechanism sound, exact stdout strings assumed.
- Timing (OBS-03): MEDIUM — REST approach standard but field names/permissions assumed; graceful fallback de-risks.
- Baseline (OBS-04): HIGH — pure recording; contexts verified.

**Research date:** 2026-07-28
**Valid until:** 2026-08-27 (GitHub Actions primitives are stable; re-check `actions/cache` output names and runner toolset only if a major GHA change lands).
