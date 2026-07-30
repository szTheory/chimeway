---
phase: 90-pipeline-tiering-pr-main-nightly
reviewed: 2026-07-30T04:11:10Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - .github/workflows/ci.yml
  - test/chimeway/ci_observability_contract_test.exs
  - test/chimeway/release_gate_contract_test.exs
findings:
  critical: 0
  warning: 4
  info: 4
  total: 8
status: issues_found
---

# Phase 90: Code Review Report

**Reviewed:** 2026-07-30T04:11:10Z
**Depth:** standard
**Files Reviewed:** 3
**Status:** issues_found

## Summary

Phase 90 adds a `resolve_tiers` setup job that drives an event-conditional OTP
matrix through `fromJSON()`, relocates the heavy `verify_admin` Playwright lane
to a nightly-only tier, and adds `nightly_cold_build` / `test_floor_1_17` /
`nightly-gate`. The conditional/matrix wiring is fundamentally sound: I traced
every event path (pull_request, push-to-main, schedule, workflow_dispatch with
and without `run_nightly`) and the tier gating, the `fromJSON` matrix hand-off,
and the `pr-gate` / `ci-gate` / `nightly-gate` aggregation all resolve
correctly. There is **no script-injection vulnerability** in the new
`resolve_tiers` shell: the only interpolations are `github.event_name` (a fixed
event enum) and `github.event.inputs.run_nightly` (a typed `boolean`, so
constrained to `true`/`false`) — neither is attacker-controllable.

No BLOCKER-class defects were found. The findings below are coverage/robustness
tradeoffs introduced by the tiering and one test-scoping weakness that reduces
the precision of the very structural contract these tests exist to enforce.

## Narrative Findings (AI reviewer)

### Warnings

#### WR-01: Release/main path no longer verifies the admin integration lane

**File:** `.github/workflows/ci.yml:887-891`, `1161-1183`
**Issue:** `verify_admin` was moved from an "all non-PR events" guard to
`needs: [resolve_tiers]` + `if: needs.resolve_tiers.outputs.run_nightly == 'true'`,
and it was removed from `ci-gate`'s `needs` (14 → 13 lanes, asserted by
`release_gate_contract_test.exs:483-498`). Because `release.yml`/`publish-hex.yml`
poll **`ci-gate`** as the release-readiness signal, the admin Playwright lane now
runs *only* on the nightly tier (schedule / dispatch-with-`run_nightly`). A push
to `main` that breaks admin integration merges green, and a release cut from that
commit publishes green — the breakage surfaces only at the next 07:00 UTC nightly.
This is an intentional CI-speed tradeoff, but it is also a genuine
release-gate coverage regression that should be explicitly acknowledged as
accepted risk (e.g. in `SECURITY.md`/`MAINTAINING.md`) rather than left implicit.
**Fix:** Confirm the intent is to *release* without admin verification (not merely
to speed up PR feedback). If releases must still gate on admin, either keep
`verify_admin` in `ci-gate`'s `needs` for `push`/`workflow_dispatch` events, or
have `release.yml` additionally trigger/poll the nightly tier before publishing.
If the reduced coverage is accepted, record it as an accepted-risk item.

#### WR-02: A `resolve_tiers` failure silently drops the entire nightly tier's dedicated signal

**File:** `.github/workflows/ci.yml:1067-1071`, `1116-1120`, `1191-1195`
**Issue:** `nightly_cold_build`, `test_floor_1_17`, and `verify_admin` each gate on
`if: needs.resolve_tiers.outputs.run_nightly == 'true'`, and `nightly-gate` gates on
`if: always() && needs.resolve_tiers.outputs.run_nightly == 'true'`. If
`resolve_tiers` *fails* (its step runs under `set -euo pipefail`), the `run_nightly`
output is empty, so all three nightly jobs **and** the `nightly-gate` aggregator are
**skipped rather than failed** — the nightly tier vanishes with no dedicated red
signal. It is caught only indirectly: `test` (which `needs: [resolve_tiers]`) is
skipped, and `ci-gate` / `pr-gate` run `aggregate-gate.sh` which treats `skipped` as
a failure (`scripts/ci/aggregate-gate.sh:17`), so the overall run still goes red.
So this is a degraded-signal / partial fail-open, not a fully silent one, but a
maintainer scanning `nightly-gate` sees "skipped," not "failed."
**Fix:** Give `nightly-gate` an `always()`-based guard that fails when the nightly
tier was *expected* but did not resolve — e.g. drive it off `github.event_name` /
`inputs.run_nightly` (the same source `resolve_tiers` reads) instead of the
downstream output, or add `needs.resolve_tiers.result` to its aggregate inputs so a
`resolve_tiers` failure produces a red `nightly-gate` rather than a skip.

#### WR-03: `mix compile --warnings-as-errors` on the Elixir 1.17 floor can fail on version-specific warnings

**File:** `.github/workflows/ci.yml:1156`, `1159` (and `1104` cold build)
**Issue:** `test_floor_1_17` runs `mix compile --warnings-as-errors` under Elixir
**1.17** (and again implicitly via `mix ci.test`, which carries
`--warnings-as-errors` per Phase 89/CONC-03). The compiler emits different
deprecation/warning sets across Elixir versions; code that is warning-clean on the
1.19 primary can emit 1.17-only deprecation warnings that have nothing to do with a
real defect. Because the floor lane escalates warnings to errors, such a
version-specific warning will fail the nightly floor lane (and, through
`nightly-gate`, the whole nightly tier) as a false positive.
**Fix:** On the floor lane, compile *without* `--warnings-as-errors` (plain
`mix compile`) and rely on the primary 1.19 lane for the warnings-as-errors gate,
or explicitly document that 1.17-specific warnings are in-scope and expected to be
fixed. Keep the strict flag on the version the project actually optimizes against.

#### WR-04: Structural `test`-job assertions over-capture into `pr-gate`/`verify_example`, weakening the contract

**File:** `test/chimeway/ci_observability_contract_test.exs:516-525` (used at :426);
`test/chimeway/release_gate_contract_test.exs:1029-1038` (used at :410-416)
**Issue:** `extract_ci_job_block/2` bounds a job block at the next
`\n  [a-z0-9_]+:` line — a char class that deliberately excludes hyphens. The `test`
job (`ci.yml:205`) is immediately followed by `pr-gate:` (`:266`, hyphenated → **not**
a boundary), then `verify_example:` (`:281`). So `extract_ci_job_block(ci_yml, "test")`
captures the `test` job **plus the entire `pr-gate` job** up to `verify_example`. Every
`test`-scoped assertion (`needs: [resolve_tiers]`, `fromJSON(...)`,
`test-matrix-${{ runner.os }}`, and the `refute "needs: [build]"` self-cache check)
therefore runs against a haystack that also contains `pr-gate`. They pass today only
because the matched strings happen to be unique to `test`, but a future regression in
the `test` job could be masked if the same substring exists in `pr-gate`, and the
`refute` checks are correspondingly weakened. This directly undermines the reliability
of the structural contract these tests are meant to enforce.
**Fix:** Make the block extractor hyphen-aware for boundaries (e.g. accept `-` in the
next-job char class: `\n  [a-z0-9_-]+:`) while keeping any intended
whole-file-tail behavior for the genuinely-hyphenated gate jobs, or scope the `test`
extraction with an explicit end anchor (`\n  pr-gate:`). Then re-run to confirm the
`test`-job assertions still hold against the correctly-bounded block.

### Info

#### IN-01: `resolve_tiers` interpolates context directly into the shell (not injectable today)

**File:** `.github/workflows/ci.yml:48`, `54-56`
**Issue:** The tier-resolution script inlines `${{ github.event_name }}` and
`${{ github.event.inputs.run_nightly }}` into a `bash` `run:` block. Both are
non-attacker-controllable (fixed event enum; typed `boolean`), so there is no
injection today. Flagged only for defense-in-depth consistency.
**Fix:** Optionally pass them via `env:` and reference `"$EVENT_NAME"` / `"$RUN_NIGHTLY"`
so the pattern is uniformly injection-safe regardless of future input-type changes.

#### IN-02: `install_golden_contract` inlines `github.base_ref` into a shell argument (pre-existing)

**File:** `.github/workflows/ci.yml:1018`
**Issue:** `scripts/ci/detect-installer-changes.sh "${{ github.base_ref }}"` interpolates
the PR base ref into a `run:` argument. `base_ref` is the *target* branch of the PR
(a branch in the base repo), not attacker-controllable, and it is double-quoted, so
risk is low. Pre-existing (not a Phase 90 change).
**Fix:** For consistency, pass `github.base_ref` via `env:` and reference the env var
inside the script invocation rather than templating it into the command line.

#### IN-03: `test_floor_1_17` has no `obs-summary` step (observability fan-out gap)

**File:** `.github/workflows/ci.yml:1116-1159`
**Issue:** Unlike the cold-build lane (which keeps an `obs-summary` step) and the
14 `@build_lanes`, `test_floor_1_17` emits no CI observability summary. The contract
test explicitly exempts it (`ci_observability_contract_test.exs:26,342-343`), so this
is deliberate, but it leaves the floor lane without the fleet-wide OBS parity the rest
of the pipeline maintains.
**Fix:** If OBS parity is desired for nightly lanes, add the standard trailing
`if: always()` `obs-summary.sh` step; otherwise leave the documented exemption as-is.

#### IN-04: Workflow declares no top-level `permissions:` block (pre-existing)

**File:** `.github/workflows/ci.yml:1-35`
**Issue:** The workflow relies on the repository/organization default `GITHUB_TOKEN`
permissions. `obs-summary.sh` only needs read access to the jobs API. Not a Phase 90
change.
**Fix:** Add a least-privilege top-level `permissions:` block (e.g. `contents: read`)
so token scope is explicit and independent of repo defaults.

---

_Reviewed: 2026-07-30T04:11:10Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
