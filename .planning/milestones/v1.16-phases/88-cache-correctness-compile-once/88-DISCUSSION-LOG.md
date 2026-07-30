# Phase 88: Cache Correctness & Compile-Once - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-07-28
**Phase:** 88-cache-correctness-compile-once
**Mode:** assumptions
**Calibration:** minimal_decisive (config `preferences.vendor_philosophy: opinionated`)
**Areas analyzed:** Cache-key schema & env split, Producer job + needs wiring, Warnings-as-errors placement

## Assumptions Presented

### Cache-key schema, env split, lane de-fragmentation (CACHE-01, CACHE-02)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Two `actions/cache` steps (`deps` + `build-test`), key `<role>-<os>-<elixir>-<otp>-hashFiles('mix.lock')`, versions from `id:`'d setup-beam, root `mix.lock` not `**/mix.lock` | Confident | `ci.yml:41`/`:978` dev-vs-test write-once collision; ~11 fragmented per-lane keys; `**/mix.lock` globs partner/nested locks (`:278`/`:633`/`:888`); `test` key proves interpolation (`:199`) |
| Move `lint`→`:test`; keep `verify_docs` on `:dev`/`build-dev`; partner lanes graph-scoped; mailglass/inbox/admin/example/journeys join `build-test` root | Likely → resolved | `ex_doc only: :dev` (`mix.exs:41`) breaks `ci.docs` in `:test`; `credo only: [:dev,:test]` (`:42`); partner path-deps (`:534`/`:691`/`:769`) change the graph |

### Producer `build` job & consumer wiring (CACHE-04, CACHE-05)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| One `build` producer (test env) saves `deps`+`build-test`; consumers `needs: [build]` + `actions/cache/restore` + `fail-on-cache-miss: true`; `build` NOT in pr-gate/ci-gate needs | Confident | `release_gate_contract_test.exs:236`/`:256` exact-count assertions + ruleset 18486746; `aggregate-gate.sh:17` treats skipped as fail |
| Warm `ci-gate` < ~3 min | Likely | Depends on GitHub multi-GB `_build` restore speed on ~4-core runner — empirical, not a codebase fact |

### Warnings-as-errors placement (CACHE-03)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Explicit `mix compile --warnings-as-errors` before `ecto.create` in `install_golden` (`ci.yml:990`); relax `ci_observability_contract_test.exs:248-256` refute | Confident | `obs-recompile.sh:8-9` defers to CACHE-03; contract test names CACHE-03 as revisiting phase |

## Corrections Made

### Docs lane cache (Area 1 flagged divergence)
- **Original assumption:** `verify_docs` stays on `:dev` with its own `build-dev` key (Claude's recommendation, diverging from CACHE-02's literal "docs shares build-test" wording).
- **User decision:** Confirmed — **Separate `build-dev` key** (recommended option). Do NOT add `:test` to ex_doc's `only:`.
- **Reason:** Respects `ex_doc only: :dev`; keeps the docs gate working; avoids touching `mix.exs`/dep graph.

All other assumptions confirmed without change ("Yes, proceed").

## External Research

- **setup-beam resolved-version outputs:** outputs are `elixir-version` / `otp-version` (confirmed against `erlef/setup-beam` `action.yml`). README's `erlang-version` is a documentation typo and does not exist. → Upgraded D-03 to Confident. Source: https://github.com/erlef/setup-beam/blob/main/action.yml
- **actions/cache producer/consumer pattern:** consumers should use `actions/cache/restore` (restore-only) with `fail-on-cache-miss: true`; the full `actions/cache` post-step emits "Unable to reserve cache / Cache already exists" warnings + a reservation race when ~10 jobs share one key. Producer uses full `actions/cache`/`save`. → Upgraded D-10 to Confident. Source: https://github.com/actions/cache#using-a-combination-of-restore-and-save-actions
