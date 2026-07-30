---
phase: 88-cache-correctness-compile-once
plan: 01
subsystem: ci
tags: [ci, cache, compile-once, producer-consumer]
status: complete
requires: []
provides:
  - "build producer job (compile-once) publishing split deps + build-test caches"
  - "shared resolved-toolchain cache key schema for default-graph consumers"
  - "lint + install_golden_contract converted to restore-only consumers"
affects:
  - .github/workflows/ci.yml
  - test/chimeway/ci_observability_contract_test.exs
tech-stack:
  added: []
  patterns:
    - "GitHub Actions producer/consumer cache split (actions/cache producer + actions/cache/restore consumers with fail-on-cache-miss: true)"
key-files:
  created: []
  modified:
    - .github/workflows/ci.yml
    - test/chimeway/ci_observability_contract_test.exs
decisions:
  - "Producer build job kept OUT of both gate needs arrays (D-11); aggregate-gate.sh treats skipped consumers as failure"
  - "CACHE-03 warnings-as-errors compile lives only in install_golden_contract, never in shared obs-recompile.sh (D-13)"
  - "D-14 refute scoped to exempt install_golden_contract only; other 13 lanes still guarded"
metrics:
  duration: ~15m
  completed: 2026-07-29
requirements: [CACHE-01, CACHE-03, CACHE-04]
---

# Phase 88 Plan 01: Compile-Once Producer Tracer Summary

Stood up the `build` compile-once producer job and proved the producer→consumer cache architecture end-to-end on the two hardest colliding-critical-path lanes (`lint` + the 373s `install_golden_contract`), under both structural contract tests, with `build` deliberately outside every gate.

## What was built

**Task 1 (tracer) — `build` producer + `lint` consumer** (commit `0813b1e`):
- New `build:` job (first under `jobs:`): checkout → `setup-beam` (`id: beam`, 1.19/27) → full `actions/cache` for `deps` (path `deps`, `id: cache_deps`) and `_build` (path `_build`, `id: cache_build_test`), both keyed on the resolved-toolchain schema with narrow env-scoped `restore-keys:` → `mix deps.get` → `mix deps.compile` → `mix compile`, all in `MIX_ENV=test`. No postgres service, no `DATABASE_URL`. No `needs:`; not in any gate.
- `lint` converted to `MIX_ENV: test`, `needs: [build]`, two `actions/cache/restore` steps (`cache_deps` + `cache_main`) with `fail-on-cache-miss: true` and no `restore-keys:`. Kept `id: cache_main` on the `_build` restore so the obs-summary `CACHE_MAIN_*` wiring and the observability contract stay intact; added the optional `CACHE_DEPS_*` triple to the summary env.

**Task 2 — `install_golden_contract` consumer + CACHE-03 + D-14** (commit `e195bc1`):
- `install_golden_contract` converted the same way (`needs: [build]`, two guarded `actions/cache/restore` steps with `fail-on-cache-miss: true`, `id: beam` added). Kept the existing `if: steps.detect.outputs.run == 'true'` guard on both restore steps.
- Inserted `- run: mix compile --warnings-as-errors` (same detect guard) immediately after the `obs-recompile.sh` probe and before `mix ecto.create --quiet` (CACHE-03/D-13). Flag added only here, not in `obs-recompile.sh`.
- Relaxed the D-14 refute in `ci_observability_contract_test.exs` to iterate `@build_lanes -- ["install_golden_contract"]`, and added a paired positive assertion that install_golden runs `mix compile --warnings-as-errors` before `mix ecto.create`.

## Producer cache key strings (verbatim — Wave 2 consumers must match byte-for-byte)

```
deps-${{ runner.os }}-${{ steps.beam.outputs.elixir-version }}-${{ steps.beam.outputs.otp-version }}-${{ hashFiles('mix.lock') }}
build-test-${{ runner.os }}-${{ steps.beam.outputs.elixir-version }}-${{ steps.beam.outputs.otp-version }}-${{ hashFiles('mix.lock') }}
```

Root `mix.lock` glob (not `**/mix.lock`), per D-04.

## Verification results

- `mix test test/chimeway/release_gate_contract_test.exs` — green. ci-gate needs exactly 14 lanes, pr-gate exactly 4 (`[lint, test, verify_gates, verify_docs]`); `build` in neither.
- `mix test test/chimeway/ci_observability_contract_test.exs` — green. 110 tests (was 109; +1 new positive install_golden assertion). Compile-warnings refute exempts only install_golden; other 13 lanes still guarded.
- `awk` ordering check: `CACHE03_ORDER_OK` — `mix compile --warnings-as-errors` precedes `mix ecto.create` inside install_golden_contract.
- Every `actions/cache*` step keeps the pinned SHA `0057852bfaa89a56745cba8c7296529d2fc39830`; setup-beam and checkout keep their pinned SHAs.
- No `lib/` runtime files touched; only the two files in `files_modified`.

## Deviations from Plan

None — plan executed exactly as written. (The Task 1 `<verify>` grep chain reported a non-zero exit purely from shell escaping of the literal `${{ }}` inside a double-quoted grep pattern; re-running the same match with `grep -F` confirmed the key string is present. This is a verification-harness quoting artifact, not a content defect — no code change needed.)

## Self-Check: PASSED

- `.github/workflows/ci.yml` — FOUND, modified in both commits.
- `test/chimeway/ci_observability_contract_test.exs` — FOUND, modified in commit e195bc1.
- Commit `0813b1e` — FOUND.
- Commit `e195bc1` — FOUND.
