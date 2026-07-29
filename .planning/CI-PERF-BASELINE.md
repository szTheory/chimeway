# CI Performance Baseline (v1.16, pre-optimization)

**Recorded:** 2026-07-28 · **Commit:** bc8ad4d90e3c29d4fc43a0aafdc95b67d9da6adb · **Run:** https://github.com/szTheory/chimeway/actions/runs/30410779443

These four numbers are the pre-optimization baseline for the v1.16 CI/CD Performance & Reliability milestone. They were measured before any Phase 87-92 change landed, and the run link above resolves to the exact `main` CI run at that pre-milestone commit (`8ce347e`, the head of `main` before Phase 87 began). Every later phase in this milestone cites its win as a delta against these rows, not a feeling.

| Metric | Baseline | Phase 88 after | Δ |
|--------|----------|----------------|---|
| ci-gate wall-clock | ~373–395s | **~648s** (warm run [30468904170](https://github.com/szTheory/chimeway/actions/runs/30468904170)) | **+253–275s — REGRESSED** |
| install_golden job | 373s | 341s | −32s |
| hidden compile in ecto.create | ~135s | ~0 (moved to an explicit `mix compile --warnings-as-errors` step) | −135s — attribution fixed (CACHE-03) |
| dep recompile, 3 identical-lock runs | dead-flat (cache never warms) | caches HIT, but ex_cldr rebuilds ~86s once per restore + 8 rebar deps every `mix` run; app recompiles in consumers | partial — warms but recompile not eliminated |

## Phase 88 outcome (recorded 2026-07-29)

Phase 88 delivered the **cache-correctness** half of its goal but **not** the compile-once / <3 min warm target (CACHE-05). Recorded honestly rather than green-washed:

- **Delivered:** the `MIX_ENV` write-once key collision is fixed; `deps`/`build-test` caches are correctly keyed on resolved toolchain + root `mix.lock` and **HIT** on warm runs (`CACHE_MAIN_HIT: true` on producer and every consumer); the ~11-way per-lane fragmentation is collapsed; and the ~135 s compile hidden inside `ecto.create` is now an explicit, attributed step (CACHE-03). Contract suites green (129 tests); gate lane set unchanged (14/4).
- **Not delivered:** warm `ci-gate` **regressed** (~373 s → ~648 s). Root cause, proven by an on-runner producer probe (build job of run [30474102629](https://github.com/szTheory/chimeway/actions/runs/30474102629)): the restored `_build` is complete, but (a) `ex_cldr`/`ex_cldr_numbers` (via `ex_money`→`mailglass`) rebuild ~86 s exactly once after every cache restore — the signature of splitting `deps` and `_build` into two independently-restored caches (D-01); (b) 8 rebar/Erlang deps (hackney, telemetry, idna, …) recompile on every `mix` invocation regardless of cache; (c) consumers additionally recompile the app (~93 files) while the producer does not. mtime was disproven as the cause (content-hash staleness ignores it, confirmed on CI and locally). Because the producer/consumer split adds a serial ~140 s stage in front of consumers that still recompile, net warm wall-clock went up.
- **Decision (owner, 2026-07-29):** bank the correctness win as Phase 88's delivered scope; defer true compile-once to a dedicated spike (see `CI-HARDENING-BACKLOG.md` #4). CACHE-05 remains open.

## How later phases use this delta ledger

When a later phase (starting with Phase 88's cache-correctness fix) lands a
change that plausibly moves one of these numbers, append an "after" value and
a `Δ` to the matching row above — sourced from the OBS-01/02/03 instrumentation
this phase (87) added to every build lane's job summary (cache hit/miss table,
recompile counts, and per-step timing table) — and cite the new run's
permalink in that phase's own SUMMARY.md. Do not overwrite this file's
`**Recorded:**` / `**Commit:**` / `**Run:**` header or the `Baseline` column;
those are the fixed pre-optimization reference point for the whole milestone.

Run-page durability: GitHub Actions run pages persist far longer than log or
artifact retention, so the URL above is the citable evidence; committing the
numbers themselves in git makes them permanent regardless of run retention.
