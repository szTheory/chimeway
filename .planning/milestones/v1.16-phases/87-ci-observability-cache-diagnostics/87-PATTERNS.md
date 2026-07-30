# Phase 87: CI Observability & Cache Diagnostics - Pattern Map

**Mapped:** 2026-07-28
**Files analyzed:** 8 (2 new shell helpers, 1 new ExUnit contract test, 3 new fixtures, 1 new doc, 1 modified workflow)
**Analogs found:** 8 / 8 (all have strong in-repo analogs except the baseline doc, which is a pure doc artifact)

This is a CI/config-only phase. No runtime library code changes. The highest-leverage analogs are the `scripts/ci/*.sh` header/idiom style and `test/chimeway/release_gate_contract_test.exs` (its `System.cmd` + `ci.yml`-grep contract structure). Replicate those verbatim in style.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `scripts/ci/obs-recompile.sh` | ci-utility (shell helper) | transform (stdin logs → counts) | `scripts/ci/sigra-proof.sh` (mix-wrapping) + `scripts/ci/detect-installer-changes.sh` (stdout-verdict) | exact (role + data flow) |
| `scripts/ci/obs-summary.sh` | ci-utility (shell helper) | transform (env/logs/REST → `$GITHUB_STEP_SUMMARY` table) | `scripts/ci/aggregate-gate.sh` (env-var-input loop) + `detect-installer-changes.sh` (output-file idiom) | role-match |
| `test/chimeway/ci_observability_contract_test.exs` | test (ExUnit contract) | request-response (`System.cmd` + file grep) | `test/chimeway/release_gate_contract_test.exs` | exact |
| `test/fixtures/ci/compile_cold.log` | test fixture | file-I/O (captured stdout) | `test/fixtures/installer_golden_prefixed/STDOUT.txt` | role-match |
| `test/fixtures/ci/compile_warm.log` | test fixture | file-I/O | same | role-match |
| `test/fixtures/ci/jobs_api_sample.json` | test fixture | file-I/O (JSON) | `test/fixtures/` dir convention (no JSON precedent) | partial |
| `.planning/CI-PERF-BASELINE.md` | doc artifact | n/a | `.planning/CI-HARDENING-BACKLOG.md` (sibling CI ops doc) | doc-only (no code analog) |
| `.github/workflows/ci.yml` (modified) | config (workflow) | event-driven (GHA) | itself — the `lint` and `verify_example` lanes below | in-place modification |

## Pattern Assignments

### `scripts/ci/obs-recompile.sh` (ci-utility, transform)

**Analogs:** `scripts/ci/sigra-proof.sh` (mix-wrapping under a job env contract), `scripts/ci/detect-installer-changes.sh` (prints a machine verdict; CI appends to `$GITHUB_OUTPUT`).

**Header/comment/shebang idiom to replicate** — every `scripts/ci/*.sh` opens with `#!/usr/bin/env bash`, a multi-line comment naming the ci.yml origin and the requirement IDs, a `Usage:` line, then the `set` line. From `sigra-proof.sh` (lines 1-20):
```bash
#!/usr/bin/env bash
# Sigra auth integration proof lanes, extracted from ci.yml verify_sigra (CI-04, D-09).
#
# ...explains what it owns vs. what the job keeps...
#
# Usage: scripts/ci/sigra-proof.sh [root|demo|all]   (default: all)
set -euo pipefail
```

**IMPORTANT divergence — do NOT copy `set -euo pipefail` here.** The two existing helpers use `set -euo pipefail`, but RESEARCH.md Pitfall 1 (lines 172-184) requires `set -uo pipefail` (no `-e`) for the recompile parser so a warm-cache `grep` miss (exit 1) does not abort the step. Use the research's Code Example 2 body verbatim as the contract (lines 244-254): tee each `mix` command to a `$RUNNER_TEMP` log, capture `${PIPESTATUS[0]}`, count `Compiling N files` with a `grep … | grep -oE '[0-9]+' | paste -sd+ - | bc` pipeline guarded by `|| true`, write `"$deps_n $app_n"` to `$RUNNER_TEMP/obs-recompile.txt`, and end with `[ "$drc" -eq 0 ] && [ "$arc" -eq 0 ]` to preserve real compile pass/fail.

**Env-contract idiom** (from `sigra-proof.sh` lines 22-24): read job-provided env with `${VAR:-default}` defaults so the script runs identically locally — apply to `RUNNER_TEMP` (`"${RUNNER_TEMP:-/tmp}"`).

---

### `scripts/ci/obs-summary.sh` (ci-utility, transform)

**Analogs:** `scripts/ci/aggregate-gate.sh` (iterates over env-var names passed by the workflow), `detect-installer-changes.sh` (writes a machine-consumable output; here `$GITHUB_STEP_SUMMARY`).

**Env-var-name iteration idiom** — `aggregate-gate.sh` (lines 12-21) shows the repo's pattern for consuming workflow-injected env by indirect expansion:
```bash
set -euo pipefail
failed=0
for lane in "$@"; do
  result="${!lane}"        # indirect expansion of an env var whose NAME was passed
  ...
done
```
`obs-summary.sh` uses the same indirect-expansion move to discover caches generically, per RESEARCH.md line 283: `compgen -e | grep -E '^CACHE_.*_HIT$'`, then for each `CACHE_<id>_HIT` read the sibling `CACHE_<id>_MATCHED` / `CACHE_<id>_PRIMARY` via `${!name}`.

**Cache classification** — inline the Code Example 1 logic (RESEARCH.md lines 222-228): `hit == "true"` → EXACT HIT; else non-empty matched-key → PARTIAL; else MISS. Emit one markdown table row per cache.

**Single-write-to-summary idiom** — accumulate the three tables into `$RUNNER_TEMP/obs-*.md` scratch files, then append ONCE to `$GITHUB_STEP_SUMMARY` (Anti-Pattern, RESEARCH.md line 148; the repo already uses the `>> "$FILE"` append idiom, cf. `detect-installer-changes.sh` `echo "run=true"` → `$GITHUB_OUTPUT`).

**REST timing block** — use Code Example 3 verbatim (RESEARCH.md lines 258-266): `gh api --paginate` the `/runs/$GITHUB_RUN_ID/attempts/$GITHUB_RUN_ATTEMPT/jobs` endpoint, `jq` filter on `runner_name==$RUNNER_NAME and status=="in_progress"`, `|| echo "| _timing unavailable_ | — |"` graceful fallback so the lane never fails on a 403.

**Security constraint (RESEARCH.md Pitfall 5 / Security Domain):** emit ONLY cache keys, counts, durations, run URL — never `env`, `DATABASE_URL`, or `GITHUB_TOKEN`.

---

### `test/chimeway/ci_observability_contract_test.exs` (test, ExUnit contract)

**Analog:** `test/chimeway/release_gate_contract_test.exs` — copy its structure wholesale.

**Module + read-the-file setup idiom** (lines 1-9, 47-60): `use ExUnit.Case, async: true`, `@moduledoc false`, module attributes for each path (`@ci_yml ".github/workflows/ci.yml"`), and a `setup` that does `File.read!(@ci_yml)` into the test context.

**Shelling out to a script with fixtures** — the phase needs `System.cmd` feeding fixture logs to the obs scripts. The analog's `System.cmd` usage is at lines 818-822 (`build_unpacked_package!`):
```elixir
{out, status} =
  System.cmd("mix", ["hex.build", "--unpack", "--output", output],
    stderr_to_stdout: true,
    env: [{"MIX_ENV", "prod"}]
  )
assert status == 0, "...#{out}"
```
Replicate this shape to run `obs-recompile.sh` / a `jq` render path with `env: [{"RUNNER_TEMP", tmp}]`, feeding `test/fixtures/ci/compile_cold.log` etc., and asserting the parsed `deps_n`/`app_n` (cold → nonzero, warm → `0 0`).

**Load-bearing-string contract idiom** — the analog asserts a list of markers exist in a script/yml (lines 139-157, 472-486). Replicate the `for marker <- [...] do assert String.contains?(...)` pattern to assert each build-lane cache step in `ci.yml` has a stable `id:` and each lane has an obs-summary step.

**ci.yml job-block extraction helper** — reuse the analog's private helpers verbatim: `extract_ci_job_block/2` (lines 885-890) scopes a grep to one job's block; `@ci_gate_lanes` / `@demo_host_cache_lanes` (lines 19, 24-33) enumerate the lanes to iterate. Copy these into the new test (or the assertions can read the same list).

**Fixture-driven parametrized tests** — the analog's `for {job_id, slug} <- @demo_host_cache_lanes do test "..." do` (lines 402-418) is the exact idiom for "assert every build lane has an obs `id:`/summary step."

---

### `test/fixtures/ci/compile_cold.log`, `compile_warm.log`, `jobs_api_sample.json` (fixtures, file-I/O)

**Analog:** `test/fixtures/installer_golden_prefixed/STDOUT.txt` — captured tool stdout committed as a fixture the contract test reads with `File.read!`. Convention: fixtures live under `test/fixtures/<domain>/`; create a new `test/fixtures/ci/` subdir. No JSON fixture precedent exists in the tree, so `jobs_api_sample.json` sets the convention — keep it a minimal, hand-trimmed real `/jobs` API response (a `.jobs[].steps[]` array with `name`/`started_at`/`completed_at`/`runner_name`/`status`) sufficient to exercise the `jq` render path. `compile_cold.log` must contain `Compiling N files` lines (deps + app); `compile_warm.log` must contain none (asserts the `0 0` path, RESEARCH.md line 357).

---

### `.planning/CI-PERF-BASELINE.md` (doc artifact — no code analog)

Sibling to `.planning/CI-HARDENING-BACKLOG.md` (RESEARCH.md line 144 — repo keeps CI ops docs in `.planning/`). Populate from the Code Example 4 skeleton (RESEARCH.md lines 285-293): a header with `**Recorded:**`/`**Commit:**`/`**Run:**` and a delta-ledger table Phase 88+ appends to. The run link MUST match the pattern `…/actions/runs/…` so the contract test can assert it (RESEARCH.md line 359). Filled from a real push-to-main run URL — the OBS-04 evidence of record.

---

### `.github/workflows/ci.yml` (modified, config) — the modification analog

**Current shape of one representative cache step (the `lint` lane, lines 35-42) — has NO `id:` today:**
```yaml
      - uses: actions/cache@0057852bfaa89a56745cba8c7296529d2fc39830
        with:
          path: |
            deps
            _build
          key: ${{ runner.os }}-mix-${{ hashFiles('**/mix.lock') }}
          restore-keys: |
            ${{ runner.os }}-mix-
```
**Modification:** add a stable `id:` line (e.g. `id: cache_main`) immediately under the `uses:` line — outputs are only reachable via the `steps.<id>.outputs` context, so the `id:` is mandatory (RESEARCH.md Pattern 1, line 127).

**Multi-cache lane example (`verify_example`, lines 207-222) — two cache steps, each needs a distinct id** (`cache_main`, `cache_demo`):
```yaml
      - uses: actions/cache@0057852bfaa89a56745cba8c7296529d2fc39830
        with:
          path: |
            deps
            _build
          key: ${{ runner.os }}-mix-verify-example-${{ hashFiles('**/mix.lock') }}
          restore-keys: |
            ${{ runner.os }}-mix-verify-example-
      - uses: actions/cache@0057852bfaa89a56745cba8c7296529d2fc39830
        with:
          path: |
            examples/chimeway_demo_host/deps
            examples/chimeway_demo_host/_build
          key: ${{ runner.os }}-mix-demo-example-${{ hashFiles('examples/chimeway_demo_host/mix.lock') }}
          restore-keys: |
            ${{ runner.os }}-mix-demo-example-
```

**Trailing obs-summary step to slot in per lane** (from Code Example 4, lines 271-281) — goes AFTER the verify step, carries `if: always()`, passes each cache's outputs via `env:`:
```yaml
      - name: CI observability summary
        if: always()
        shell: bash
        env:
          GH_TOKEN: ${{ github.token }}
          RUN_URL: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}/attempts/${{ github.run_attempt }}
          CACHE_MAIN_HIT: ${{ steps.cache_main.outputs.cache-hit }}
          CACHE_MAIN_MATCHED: ${{ steps.cache_main.outputs.cache-matched-key }}
          CACHE_MAIN_PRIMARY: ${{ steps.cache_main.outputs.cache-primary-key }}
        run: scripts/ci/obs-summary.sh
```

**Existing `$GITHUB_OUTPUT` precedent in-repo** — the `install_golden_contract` detect step already uses the env-file idiom (`echo "run=…" >> $GITHUB_OUTPUT`), so `$GITHUB_STEP_SUMMARY` appends match established repo convention (RESEARCH.md line 300). **Conditional-lane caveat (Pitfall 4):** the `install_golden_contract` lane gates every step on `steps.detect.outputs.run == 'true'`; its obs step must be `if: always() && steps.detect.outputs.run == 'true'`.

**Recompile-probe insertion (OBS-02):** replace the implicit compile hidden in `- run: mix ecto.create --quiet` (e.g. lines 95, 163, 227) with an explicit behavior-neutral step calling `scripts/ci/obs-recompile.sh` BEFORE `ecto.create`. Do NOT add `--warnings-as-errors` (that is Phase 88 / CACHE-03).

## Shared Patterns

### Shell helper header + `set` discipline
**Source:** `scripts/ci/sigra-proof.sh` lines 1-18, `aggregate-gate.sh` lines 1-12.
**Apply to:** both `obs-*.sh`. Shebang `#!/usr/bin/env bash`, a comment naming the ci.yml origin + requirement IDs (OBS-0x), a `Usage:` line. Use `set -euo pipefail` in `obs-summary.sh`, but `set -uo pipefail` (no `-e`) in `obs-recompile.sh` per Pitfall 1.

### Workflow-injected env consumed by indirect expansion
**Source:** `scripts/ci/aggregate-gate.sh` lines 15-18 (`result="${!lane}"`).
**Apply to:** `obs-summary.sh` cache discovery (`compgen -e | grep '^CACHE_.*_HIT$'` then `${!name}`).

### Machine output appended to a GHA env-file
**Source:** `detect-installer-changes.sh` (`echo "run=true"` → step appends to `$GITHUB_OUTPUT`).
**Apply to:** `obs-summary.sh` single append to `$GITHUB_STEP_SUMMARY`; `obs-recompile.sh` write to `$RUNNER_TEMP/obs-recompile.txt`.

### ExUnit CI-contract test structure
**Source:** `test/chimeway/release_gate_contract_test.exs` — path module attrs, `setup` reads `ci.yml`, `extract_ci_job_block/2` (lines 885-890), marker-list `for … assert String.contains?` (lines 139-157), `System.cmd` shell-out (lines 818-825), parametrized `for {…} <- @lanes do test`.
**Apply to:** `test/chimeway/ci_observability_contract_test.exs` — reuse `extract_ci_job_block/2` verbatim; iterate build lanes asserting each cache step's `id:` and each lane's obs-summary step; `System.cmd` the obs scripts against fixtures.

### `.planning/` as the CI-ops doc home
**Source:** `.planning/CI-HARDENING-BACKLOG.md` (existing sibling).
**Apply to:** `.planning/CI-PERF-BASELINE.md`.

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `test/fixtures/ci/jobs_api_sample.json` | fixture | file-I/O | No committed JSON fixture exists in `test/fixtures/`; this sets the convention (a trimmed real GHA `/jobs` REST response). |
| `.planning/CI-PERF-BASELINE.md` | doc | n/a | Doc artifact, not code; modeled on the `.planning/CI-HARDENING-BACKLOG.md` sibling and Code Example 4 skeleton. |

## Metadata

**Analog search scope:** `scripts/ci/`, `test/chimeway/`, `test/fixtures/`, `.github/workflows/ci.yml`, `.planning/`
**Files scanned:** 3 shell helpers, 1 ExUnit contract test (~918 lines), 2 ci.yml lane blocks, fixtures tree
**Pattern extraction date:** 2026-07-28
