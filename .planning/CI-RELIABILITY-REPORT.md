# CI Reliability Report (REL-01)

**Recorded:** 2026-07-30 · **Commit:** 596361f6387dab75f0107478ff04348fd10d1706 · **Measured via:** `scripts/ci/reliability-report.sh`

**Re-run:** `scripts/ci/reliability-report.sh` (requires `gh auth status` with `actions:read`/`repo` scope on `szTheory/chimeway`).

## Population definition

This report classifies the **`ci-gate` JOB conclusion** on **`event=push`, `branch=main`** runs only — never the run-level conclusion, and never `workflow_dispatch`, `release-please--branches--main`, or nightly-tier dispatch runs. The run-level conclusion is contaminated by those other trigger types; the `ci-gate` job's own conclusion on a push-to-`main` run is the trustworthy release-confidence signal.

- **success** → GREEN
- **failure** → REAL FAILURE (counts against the rate)
- **cancelled** / **skipped** → EXCLUDED from the denominator (infra supersession is not a reliability defect)

`denominator = completed − excluded`; `failure_rate = real_failures / denominator` (strict integer comparison: `real_failures * 10 >= denominator` fails the bar); `streak` = consecutive `success` scanning most-recent-first, skipping excluded runs, stopping at the first real failure.

## Measured result (last 30 push-on-main runs)

**`failures=2 excluded=0 rate=6% streak=10`** — **RELIABILITY BAR MET** (`scripts/ci/reliability-report.sh` exits 0): failure rate 6% is under the 10% bar, and the 10-run consecutive-green streak clears the `>= 5` bar.

| Run ID | ci-gate | Permalink |
|--------|---------|-----------|
| 30558617430 | success | https://github.com/szTheory/chimeway/actions/runs/30558617430 |
| 30556372077 | success | https://github.com/szTheory/chimeway/actions/runs/30556372077 |
| 30512806893 | success | https://github.com/szTheory/chimeway/actions/runs/30512806893 |
| 30512178311 | success | https://github.com/szTheory/chimeway/actions/runs/30512178311 |
| 30511779227 | success | https://github.com/szTheory/chimeway/actions/runs/30511779227 |
| 30510914071 | success | https://github.com/szTheory/chimeway/actions/runs/30510914071 |
| 30510770544 | success | https://github.com/szTheory/chimeway/actions/runs/30510770544 |
| 30510300562 | success | https://github.com/szTheory/chimeway/actions/runs/30510300562 |
| 30507139130 | success | https://github.com/szTheory/chimeway/actions/runs/30507139130 |
| 30503771650 | success | https://github.com/szTheory/chimeway/actions/runs/30503771650 |
| 30502247481 | failure | https://github.com/szTheory/chimeway/actions/runs/30502247481 |
| 30481562275 | success | https://github.com/szTheory/chimeway/actions/runs/30481562275 |
| 30480960879 | success | https://github.com/szTheory/chimeway/actions/runs/30480960879 |
| 30479964112 | success | https://github.com/szTheory/chimeway/actions/runs/30479964112 |
| 30476161425 | success | https://github.com/szTheory/chimeway/actions/runs/30476161425 |
| 30474102629 | success | https://github.com/szTheory/chimeway/actions/runs/30474102629 |
| 30472425765 | success | https://github.com/szTheory/chimeway/actions/runs/30472425765 |
| 30468904170 | success | https://github.com/szTheory/chimeway/actions/runs/30468904170 |
| 30467757897 | success | https://github.com/szTheory/chimeway/actions/runs/30467757897 |
| 30464950563 | success | https://github.com/szTheory/chimeway/actions/runs/30464950563 |
| 30416472070 | success | https://github.com/szTheory/chimeway/actions/runs/30416472070 |
| 30410779443 | success | https://github.com/szTheory/chimeway/actions/runs/30410779443 |
| 30408121735 | success | https://github.com/szTheory/chimeway/actions/runs/30408121735 |
| 30403831638 | success | https://github.com/szTheory/chimeway/actions/runs/30403831638 |
| 30403256578 | failure | https://github.com/szTheory/chimeway/actions/runs/30403256578 |
| 30401525463 | success | https://github.com/szTheory/chimeway/actions/runs/30401525463 |
| 30398520317 | success | https://github.com/szTheory/chimeway/actions/runs/30398520317 |
| 30397211848 | success | https://github.com/szTheory/chimeway/actions/runs/30397211848 |
| 30396178500 | success | https://github.com/szTheory/chimeway/actions/runs/30396178500 |
| 30391464361 | success | https://github.com/szTheory/chimeway/actions/runs/30391464361 |

## Notes on the two real failures

- **`30403256578`** (`fix(release): publish in :dev (drop obsolete sigra override) so hex d…`) — the workflow run's own conclusion is `failure` (not superseded/cancelled); the `ci-gate` job genuinely failed on this push. A real, since-fixed failure — correctly counted against the rate.
- **`30502247481`** (`chore(89-05): add --warnings-as-errors to ci.test alias`) — the **overall workflow run's** conclusion is `cancelled` (superseded by a subsequent push under the `pull_request`/push concurrency group), but the **`ci-gate` job's own conclusion** resolves to `failure` — GitHub reports a dependent aggregate job as `failure`, not `cancelled`, when its upstream `needs` were cancelled. Per REL-01's population definition (classify the **JOB** conclusion, not the run conclusion), this counts as a real failure in the strict, literal classification the script implements. This is a known counting nuance: a run-level `cancelled` supersession can still surface as a JOB-level `failure` on `ci-gate`. It does not change the outcome here (6% rate still clears the <10% bar) — documented so a future re-run doesn't misread genuine supersession noise as unexplained script behavior.

## Bar status

**MET.** `failure_rate` (6%) is strictly under 10%, and the consecutive-green streak (10) clears the `>= 5` bar. Re-running `scripts/ci/reliability-report.sh` re-measures this on demand against live `main` push history.
