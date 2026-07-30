---
phase: 88-cache-correctness-compile-once
plan: 03
type: summary
status: completed-partial
requirements: [CACHE-05]
outcome: correctness-delivered / compile-once-deferred
---

# 88-03 Summary — Prove the compile-once win (run-link delta)

## Result: CACHE-05 NOT met — deferred to a spike (owner decision 2026-07-29)

Plan 88-03 set out to fill the `Phase 88 after` / Δ cells of `CI-PERF-BASELINE.md`
from a warm `main` run and human-verify near-zero recompile + warm `ci-gate`
under ~3 min. The warm runs were produced and measured; the target was **not**
met, so the delta was recorded honestly (regression, not a win) instead of
green-washing the checkpoint.

### What the live warm runs showed

- Cold seed run (30464950340/…563), warm run 1 (30467757897), **warm run 2
  (30468904170 — the fully-warm reference)**. All green; gate lane set unchanged.
- Caches are correct and **HIT** on warm runs (`CACHE_MAIN_HIT: true`,
  `CACHE_DEPS_HIT: true`) on the producer and every consumer — the original
  `MIX_ENV` write-once collision is fixed.
- **But** warm `ci-gate` wall-clock **regressed** ~373 s → ~648 s: the serial
  `build` producer (~140 s) runs ahead of consumers that still recompile.

### On-runner diagnosis (producer probe, run 30474102629)

Restored `_build` is complete (app manifest + 98 beams + ex_cldr present). The
cost comes from, proven, not guessed:
1. `ex_cldr`/`ex_cldr_numbers` rebuild ~86 s once per cache restore (D-01
   deps/`_build` split signature).
2. 8 rebar/Erlang deps recompile on every `mix` run (rebar-in-mix quirk).
3. Consumers recompile the app (~93 files); the producer does not.

mtime was disproven as the cause (content-hash staleness ignores it — confirmed
on CI and locally; a `restore-mtimes.sh` experiment changed nothing and was
reverted).

### Delivered vs deferred

- **Delivered (Phase 88 scope):** CACHE-01/02/03/04 — collision fixed, split
  `deps`/`build-test` keys on resolved toolchain + root `mix.lock`, shared warm
  cache with de-fragmented lanes, restore-only consumers with
  `fail-on-cache-miss: true`, explicit attributed compile before `ecto.create`.
  Contract suites green (129 tests, 0 failures); 14/4 gate set intact.
- **Deferred:** CACHE-05 (near-zero recompile + <3 min warm) → compile-once
  spike, `CI-HARDENING-BACKLOG.md` #4 (first hypothesis: re-unify deps+`_build`
  cache). Delta ledger updated in `CI-PERF-BASELINE.md` ("Phase 88 outcome").

### Human checkpoint

The 88-03 blocking checkpoint was resolved by the owner's explicit decision to
**bank the correctness win and spike compile-once separately** rather than keep
iterating live CI runs against a deep, dep-specific recompile problem.
