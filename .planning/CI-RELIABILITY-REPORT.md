# CI Reliability Report (REL-01)

**Recorded:** 2026-08-27 · **Implementation commit:** fca4245d7d1d901601d6fca7d11c04717df527d8 · **Measured via:** `scripts/ci/reliability-report.sh`

**Re-run:** `scripts/ci/reliability-report.sh` (requires `gh auth status` with `actions:read`/`repo` scope on `szTheory/chimeway`).

## Population definition

This report classifies the **`ci-gate` job conclusion** on **`event=push`, `branch=main`** runs only — never the run-level conclusion, and never `workflow_dispatch`, `release-please--branches--main`, or scheduled nightly-tier runs. The run-level conclusion is contaminated by those other trigger types; the `ci-gate` job's own conclusion on a push-to-`main` run is the trustworthy release-confidence signal.

- **success** → GREEN
- **failure** → REAL FAILURE (counts against the rate)
- **cancelled** / **skipped** → EXCLUDED from the denominator (infra supersession is not a reliability defect)

`denominator = completed − excluded`; `failure_rate = real_failures / denominator` (strict integer comparison: `real_failures * 10 >= denominator` fails the bar); `streak` = consecutive `success` scanning most-recent-first, skipping excluded runs, stopping at the first real failure.

## Measured result (last 30 push-on-main runs)

**`failures=3 excluded=0 rate=10% streak=7`** — **RELIABILITY BAR MISSED** (`scripts/ci/reliability-report.sh` exits 1): the seven-run consecutive-green streak clears the `>= 5` bar, but the 10% historical failure rate does not satisfy the strict `< 10%` bar.

| Run ID | ci-gate | Permalink |
|--------|---------|-----------|
| 31521321013 | success | https://github.com/szTheory/chimeway/actions/runs/31521321013 |
| 30578892744 | success | https://github.com/szTheory/chimeway/actions/runs/30578892744 |
| 30578612967 | success | https://github.com/szTheory/chimeway/actions/runs/30578612967 |
| 30575692636 | success | https://github.com/szTheory/chimeway/actions/runs/30575692636 |
| 30575589192 | success | https://github.com/szTheory/chimeway/actions/runs/30575589192 |
| 30574933923 | success | https://github.com/szTheory/chimeway/actions/runs/30574933923 |
| 30573877353 | success | https://github.com/szTheory/chimeway/actions/runs/30573877353 |
| 30572883891 | failure | https://github.com/szTheory/chimeway/actions/runs/30572883891 |
| 30571853256 | failure | https://github.com/szTheory/chimeway/actions/runs/30571853256 |
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

## Notes on the three historical failures

- **`30571853256`** (`docs(92-03): complete nightly seed-0 guard plan`) — `mix format --check-formatted` rejected `test/chimeway/release_gate_contract_test.exs`; the next push corrected the formatting.
- **`30572883891`** (`fix(92-03): mix format release_gate_contract_test signature`) — formatting passed, but strict Credo rejected a chained pair of `Enum.filter/2` calls in `test/chimeway/ci_observability_contract_test.exs`; a later push corrected the lint finding.
- **`30502247481`** (`chore(89-05): add --warnings-as-errors to ci.test alias`) — the workflow run was cancelled by a superseding push, but GitHub recorded the dependent `ci-gate` job as `failure`. REL-01 deliberately classifies the job conclusion, so this remains in the strict historical count.

## Scheduled-run stabilization context

Scheduled full-tier runs are intentionally outside the REL-01 population. On the current `main` SHA, runs `32005544485` (2026-08-17) and `32559022522` (2026-08-22) failed when the packaged Accrue archive proof exceeded the old 10-minute test budget; run `31933324722` (2026-08-16) failed on a transient Hex registry/package-resolution error. Five subsequent scheduled runs through `33062458005` are green.

Implementation commit `fca4245d7d1d901601d6fca7d11c04717df527d8` isolates the packaged Accrue proof into its own required CI job, raises that proof's test budget to 20 minutes, and gives the job a 30-minute ceiling while preserving `mix ci.verify_gates` as the canonical combined local/release entrypoint.

## Bar status

**MISSED (historical window).** The green streak (7) clears its bar, while the failure rate (10%) must age below the strict `< 10%` threshold through ordinary successful `main` pushes. No synthetic pushes or exclusions will be used to manipulate the window.
