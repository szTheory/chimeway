# CI Performance Baseline (v1.16, pre-optimization)

**Recorded:** 2026-07-28 · **Commit:** bc8ad4d90e3c29d4fc43a0aafdc95b67d9da6adb · **Run:** https://github.com/szTheory/chimeway/actions/runs/30410779443

These four numbers are the pre-optimization baseline for the v1.16 CI/CD Performance & Reliability milestone. They were measured before any Phase 87-92 change landed, and the run link above resolves to the exact `main` CI run at that pre-milestone commit (`8ce347e`, the head of `main` before Phase 87 began). Every later phase in this milestone cites its win as a delta against these rows, not a feeling.

| Metric | Baseline | Phase 88 after | Δ |
|--------|----------|----------------|---|
| ci-gate wall-clock | ~373–395s | **~362s** (warm run [30480960879](https://github.com/szTheory/chimeway/actions/runs/30480960879), after producer-removal fix) | **−11 to −33s** — at/below baseline (regressed to ~648s under the producer split, then recovered) |
| install_golden job | 373s | 341s | −32s |
| hidden compile in ecto.create | ~135s | ~0 (moved to an explicit `mix compile --warnings-as-errors` step) | −135s — attribution fixed (CACHE-03) |
| dep recompile, 3 identical-lock runs | dead-flat (cache never warms) | caches HIT, but ex_cldr rebuilds ~86s once per restore + 8 rebar deps every `mix` run; app recompiles in consumers | partial — warms but recompile not eliminated |

## Phase 88 outcome (recorded 2026-07-29)

Phase 88 delivered the **cache-correctness** half of its goal but **not** the compile-once / <3 min warm target (CACHE-05). Recorded honestly rather than green-washed:

- **Delivered:** the `MIX_ENV` write-once key collision is fixed; `deps`/`build-test` caches are correctly keyed on resolved toolchain + root `mix.lock` and **HIT** on warm runs (`CACHE_MAIN_HIT: true` on producer and every consumer); the ~11-way per-lane fragmentation is collapsed; and the ~135 s compile hidden inside `ecto.create` is now an explicit, attributed step (CACHE-03). Contract suites green (129 tests); gate lane set unchanged (14/4).
- **Not delivered:** warm `ci-gate` **regressed** (~373 s → ~648 s). Root cause, proven by an on-runner producer probe (build job of run [30474102629](https://github.com/szTheory/chimeway/actions/runs/30474102629)): the restored `_build` is complete, but (a) `ex_cldr`/`ex_cldr_numbers` (via `ex_money`→`mailglass`) rebuild ~86 s exactly once after every cache restore — the signature of splitting `deps` and `_build` into two independently-restored caches (D-01); (b) 8 rebar/Erlang deps (hackney, telemetry, idna, …) recompile on every `mix` invocation regardless of cache; (c) consumers additionally recompile the app (~93 files) while the producer does not. mtime was disproven as the cause (content-hash staleness ignores it, confirmed on CI and locally). Because the producer/consumer split adds a serial ~140 s stage in front of consumers that still recompile, net warm wall-clock went up.
- **Decision (owner, 2026-07-29):** bank the correctness win as Phase 88's delivered scope; defer true compile-once to a dedicated spike (see `CI-HARDENING-BACKLOG.md` #4). CACHE-05 remains open.

### Regression recovery (2026-07-29, follow-up to backlog #4)

Cost analysis of the warm run showed the critical-path lanes were dominated not by the test-env compile but by (a) the serial `build` producer (+140s, no warm benefit — consumers HIT its cache but recompile anyway) and (b) an **uncached `:dev` warm build** on `verify_example`/`verify_journeys` (236s/297s) that Phase 88 introduced by switching those lanes to restore the test-only cache. Fix: **deleted the producer and converted the 9 default lanes to per-lane self-caching** (`deps`+`_build`, corrected key schema, no `needs:`) — so the demo lanes self-cache their full `_build` incl `_build/dev` and warm it. Result on warm run [30480960879](https://github.com/szTheory/chimeway/actions/runs/30480960879): the `:dev` build dropped **236s/297s → 6s** (cache HIT confirmed), and warm `ci-gate` fell **648s → 362s** — at/below the pre-milestone baseline. All key-correctness retained; contract tests updated (131 tests). The new long poles (`install_golden` 344s, Accrue 344s, Test 321s) are **test execution**, so the <3 min target still requires Phase 89 async — it is not a caching problem. CACHE-05's warm-recompile sub-goal (ex_cldr rebuild-once-per-restore + rebar deps) remains open but is now low-value given execution dominates.

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
