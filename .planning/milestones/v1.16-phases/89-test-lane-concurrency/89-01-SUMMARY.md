# 89-01 Summary — Tracer: pool sizing + first async flip

**Status:** COMPLETE (commit `897d836`) · **Requirements:** CONC-01, CONC-02

## What landed
- `config/test.exs`: explicit `pool_size = min(System.schedulers_online() * 2 + 10, 24)` on `Chimeway.Repo` (both `repo_config` branches).
- `test/chimeway/signal_test.exs`: `use Chimeway.DataCase, async: true`.

## Tracer deviation (why tracer-first exists)
The plan specified the uncapped formula `System.schedulers_online() * 2 + 10`. The tracer's full-suite run surfaced a real defect the research had not modelled: **`test_helper.exs` starts five repos against one Postgres** (Chimeway + Mailglass/Accrue/Threadline/Sigra), and the prefix suite creates throwaway databases mid-run — all sharing the server's default `max_connections` (100). On an 18-core dev box the uncapped formula resolved to **46**, and:

| Config | Result |
|--------|--------|
| baseline (implicit pool 10) | 1229 tests, **0 failures, 0 invalid**, 0 too_many_connections |
| uncapped 46 / cap 40 | **too_many_connections** + `GeneratedPrefixedRuntimeProofTest` invalidated (throwaway-DB create starved) |
| **cap 24 (shipped)** | 1229 tests, **0 failures, 0 invalid**, 0 too_many_connections |

Root-caused by comparison against a stashed baseline run (both with identical orphaned connections present, so apples-to-apples). The `Threadline.Export.CleanupTask` OwnershipErrors are pre-existing partner noise (12 in baseline, unchanged).

**Resolution:** cap at 24. CI's `max_cases` is only 8 (4-core), so CI never needs more than ~18 — `min` picks 18 there, leaving CI unchanged. The cap stays ≥ `max_cases` for machines up to 12 cores; higher-core boxes get mild, harmless client-side queueing on short sandbox tests instead of server-side connection exhaustion. Fully documented in the config comment.

## Verification
- `signal_test.exs` green standalone under `--seed 0` and inside the full suite.
- Full suite (cap 24): 1229 tests, 0 failures, 0 invalid; no `too_many_connections`, no non-Threadline ownership errors.
- `mix ci.lint` clean (format + `compile --warnings-as-errors` + credo 0 issues).
