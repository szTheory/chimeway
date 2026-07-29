---
phase: 88-cache-correctness-compile-once
plan: 02
subsystem: ci-cache
tags: [ci, cache, compile-once, github-actions, contract-test]
requires: ["88-01"]
provides:
  - shared-cache-fanout
  - exception-lane-role-isolation
  - observability-schema-contract
affects:
  - .github/workflows/ci.yml
  - test/chimeway/ci_observability_contract_test.exs
tech-stack:
  added: []
  patterns:
    - "producer/consumer split cache: actions/cache/restore restore-only with fail-on-cache-miss: true"
    - "role-prefixed cache keys to prevent write-once collision across differing dep graphs"
key-files:
  created: []
  modified:
    - .github/workflows/ci.yml
    - test/chimeway/ci_observability_contract_test.exs
decisions:
  - "D-05/D-10: 7 remaining default-graph :test lanes converted to restore-only consumers of the single shared deps + build-test cache via needs: [build]."
  - "D-07: verify_docs stays MIX_ENV: dev on a distinct build-dev role, no needs: [build] (ex_doc is only: :dev)."
  - "D-12: test matrix self-caches test-matrix-<os>-<elixir>-<otp> so the OTP-27 leg cannot clobber the producer's build-test cache."
  - "D-08: partner lanes self-cache graph-scoped build-test-<partner> keys, keeping *_PATH injection and demo caches."
  - "D-04: every default-graph root key narrowed from **/mix.lock to root mix.lock; broad runner.os-mix- restore-keys removed from converted/reschemed root keys."
metrics:
  duration: ~15m
  completed: 2026-07-29
  tasks: 3
  files: 2
status: complete
---

# Phase 88 Plan 02: Cache Fan-Out & Exception-Lane Reschema Summary

Fanned the tracer-proven compile-once producer/consumer pattern across the whole default graph: seven remaining plain-hex `:test` lanes now restore the single shared `deps` + `build-test` cache restore-only, and the five genuinely-different lanes (docs `:dev`, the OTP matrix, three path-dep partners) were reschemed onto distinct self-cached roles that cannot collide with the shared key — all locked by extended contract assertions.

## What Was Built

**Task 1 — Shared restore-only consumers (commit `6b3af2f`)**
Converted `verify_gates`, `verify_example`, `verify_runtime_prefix`, `verify_journeys`, `verify_mailglass`, `verify_inbox`, `verify_admin`. Each gained `id: beam` on its `setup-beam` step, `needs: [build]`, and had its single root `actions/cache` (the `-mix-verify-<lane>-` `cache_main`) replaced by two `actions/cache/restore@0057852bfaa89a56745cba8c7296529d2fc39830` steps — `cache_deps` (`path: deps`) and `cache_main` (`path: _build`) — on the byte-identical shared keys:
- `deps-${{ runner.os }}-${{ steps.beam.outputs.elixir-version }}-${{ steps.beam.outputs.otp-version }}-${{ hashFiles('mix.lock') }}`
- `build-test-${{ runner.os }}-${{ steps.beam.outputs.elixir-version }}-${{ steps.beam.outputs.otp-version }}-${{ hashFiles('mix.lock') }}`

Both restore steps carry `fail-on-cache-miss: true` with no `restore-keys:`. All `cache_demo`, `cache_nested_inbox`, `cache_nested_admin`, `playwright-cache`, and the `verify_example` `:dev`-warm step were left untouched. `id: cache_main` was kept on the `build-test` restore so each lane's trailing obs-summary step still resolves `CACHE_MAIN_*`.

**Task 2 — Exception-lane role reschema (commit `7068288`)**
Kept these five lanes self-caching (full `actions/cache`, no `needs: [build]`) on roles distinct from the shared `build-test-`:
- `verify_docs` → `build-dev-…`, staying on `MIX_ENV: dev` (D-07).
- `test` matrix → `test-matrix-${{ runner.os }}-${{ matrix.elixir }}-${{ matrix.otp }}-${{ hashFiles('mix.lock') }}` (D-12).
- `verify_accrue`/`verify_threadline`/`verify_sigra` → `build-test-accrue-…` / `build-test-threadline-…` / `build-test-sigra-…`, keeping their `*_PATH` injection, extra checkouts, and `cache_demo` (D-08).

Each got `id: beam`, root-`mix.lock` globs, and a single role-scoped `restore-keys:` prefix (full key minus the `hashFiles` segment). The broad `${{ runner.os }}-mix-` fallback was removed from every reschemed root key.

**Task 3 — Contract lock (commit `ee50e5c`)**
Added the `"CACHE-01/02/04 shared cache schema (Phase 88)"` describe block to `ci_observability_contract_test.exs`, reusing `extract_ci_job_block/2` and the `setup` fixture. It asserts: the `build` producer publishes both shared keys; each of the 9 shared consumers carries `needs: [build]` + `actions/cache/restore` + `fail-on-cache-miss: true` + the exact shared `build-test-…` key; each of the 5 exception lanes refutes `needs: [build]` and carries its distinct role; and no `hashFiles('**/mix.lock')` recursive glob remains for any default-graph root key.

## Verification Results

- `mix test test/chimeway/release_gate_contract_test.exs test/chimeway/ci_observability_contract_test.exs` — **129 tests, 0 failures** (was 110 pre-Task-3; +19 new assertions). ci-gate 14 / pr-gate 4 lane counts and names unchanged.
- Per-lane awk check emits `FANOUT_CONSUMERS_OK` (all 7 converted lanes carry `needs: [build]` + `fail-on-cache-miss: true`).
- Exception roles present and distinct: `build-dev-`, `test-matrix-`, `build-test-accrue-`, `build-test-threadline-`, `build-test-sigra-`.
- No `hashFiles('**/mix.lock')` remains; surviving `${{ runner.os }}-mix-` prefixes are only the intentionally-untouched demo/nested caches (D-08).
- `build` is in neither gate's `needs:` (transitive-only, D-11); no `lib/` files touched; only the two `files_modified` changed.

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check: PASSED

- FOUND: `.github/workflows/ci.yml` (modified, both tasks)
- FOUND: `test/chimeway/ci_observability_contract_test.exs` (modified, Task 3)
- FOUND commit `6b3af2f` (Task 1), `7068288` (Task 2), `ee50e5c` (Task 3)
- Both contract suites green (129 tests, 0 failures).
