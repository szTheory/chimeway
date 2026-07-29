# CI Performance Baseline (v1.16, pre-optimization)

**Recorded:** 2026-07-28 · **Commit:** bc8ad4d90e3c29d4fc43a0aafdc95b67d9da6adb · **Run:** https://github.com/szTheory/chimeway/actions/runs/30410779443

These four numbers are the pre-optimization baseline for the v1.16 CI/CD Performance & Reliability milestone. They were measured before any Phase 87-92 change landed, and the run link above resolves to the exact `main` CI run at that pre-milestone commit (`8ce347e`, the head of `main` before Phase 87 began). Every later phase in this milestone cites its win as a delta against these rows, not a feeling.

| Metric | Baseline | Phase 88 after | Δ |
|--------|----------|----------------|---|
| ci-gate wall-clock | ~373–395s | | |
| install_golden job | 373s | | |
| hidden compile in ecto.create | ~135s | | |
| dep recompile, 3 identical-lock runs | dead-flat (cache never warms) | | |

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
