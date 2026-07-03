---
phase: 80-verification-architecture-and-ci-dx
verified: 2026-07-03T16:58:14Z
status: human_needed
score: 8/8 must-haves verified
behavior_unverified: 0
overrides_applied: 0
human_verification:
  - test: "Open a real pull request to `main` that touches only non-installer files and watch the checks tab."
    expected: "`pr-gate` runs and reports a success/failure conclusion; the PR is NOT stuck in 'Expected — Waiting for status to be reported'; `ci-gate` and the nine heavy lanes plus `install_golden_contract` are skipped (not pending) on the PR event. Ruleset 18486746 gates merge on `pr-gate` only."
    why_human: "The anti-pending property (CI-03) is a GitHub Actions + branch-protection RUNTIME behavior on external infrastructure. Every static precondition is verified in-repo (pr-gate has no event guard, heavy lanes/ci-gate are event-guarded off pull_request, no paths filters, ruleset requires only pr-gate and is enforcement=active), but a live PR reporting a conclusion without stranding cannot be observed from the repo tree. The plan's own Task 3 checkpoint (80-04) specified this test; the SUMMARY confirmed the ruleset exists but did not confirm a live PR was run through the new topology."
---

# Phase 80: Verification Architecture and CI/DX Verification Report

**Phase Goal:** Add an always-running fast `pr-gate` while preserving full `ci-gate` release confidence, avoid required-check pending traps, improve cache coverage, make complex CI behavior locally reproducible, and align contributor/maintainer gate docs.
**Verified:** 2026-07-03T16:58:14Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | CI-01: A fast, always-running `pr-gate` gives PR feedback without the full matrix | ✓ VERIFIED | `ci.yml:131-144` — `name: pr-gate`, `needs: [lint, test, verify_gates, verify_docs]` (inline), `if: always()`, NO event guard, NO paths filter; step calls `scripts/ci/aggregate-gate.sh LINT TEST VERIFY_GATES VERIFY_DOCS`. Behaviorally exercised: script exits 1 on `failure`/`skipped`, exits 0 when all `success`. |
| 2 | CI-02: `ci-gate` remains release/publish/automerge/recovery source of truth, at least as strict | ✓ VERIFIED | `ci.yml:705-728` — `name: ci-gate` (literal, unchanged), `if: always() && github.event_name != 'pull_request'`, inline `needs:` = 14 lanes including `install_golden_contract` (strictness increase vs. 13). `INSTALL_GOLDEN` in env block + aggregate args. release.yml/publish-hex.yml/release-pr-automerge.yml still poll `job.name === 'ci-gate'` (unmodified). |
| 3 | CI-03: required-check topology cannot leave checks permanently pending | ✓ VERIFIED (static) | No `paths:`/`paths-ignore:` anywhere in `ci.yml` (grep: NONE). 10 job-level `if: github.event_name != 'pull_request'` guards on the nine heavy lanes + `install_golden_contract`. `pr-gate` always runs on PR. Ruleset 18486746 (active) requires only `pr-gate`. Runtime end-to-end confirmation → human item. |
| 4 | CI-04: complex CI behavior reproducible locally via scripts, not inline fragments | ✓ VERIFIED | `scripts/ci/{aggregate-gate,detect-installer-changes,sigra-proof}.sh` exist (+x), substantive (29/25/61 lines of real logic), and wired: `ci.yml` calls each (aggregate in pr-gate+ci-gate, detect in install_golden detect step, sigra-proof in verify_sigra root+demo). Installer regex copied verbatim; Sigra env contract preserved. |
| 5 | CI-05: nested/demo/npm/Playwright caches reduce cost without hiding failures | ✓ VERIFIED | `ci.yml`: npm via setup-node `cache: 'npm'` (602-603); Playwright `~/.cache/ms-playwright` keyed on `package-lock.json` (612-618); nested `chimeway_admin/mix.lock` (619-626), `chimeway_inbox/mix.lock` (422-429); per-lane demo-host caches on all 8 demo-host lanes keyed `-mix-demo-<slug>-` + `examples/chimeway_demo_host/mix.lock`. All keys lockfile-only (contract D-12 guard). |
| 6 | D-08: branch protection requires `pr-gate` for PR merge | ✓ VERIFIED | GitHub API `repos/szTheory/chimeway/rulesets` → ruleset id **18486746** "main: require pr-gate", `enforcement: active`. Out-of-repo settings change (per phase note); ruleset is the evidence, confirmed live. |
| 7 | Contributor/maintainer gate docs aligned with new topology | ✓ VERIFIED | CONTRIBUTING.md: `pr-gate` story, `scripts/ci/` pointer, canonical `github.com/szTheory/chimeway` URL, no `jonlunsford`. MAINTAINING.md: pr-gate/ci-gate split, explicit operator swap step + pending-trap hazard, corrected Sigra ref `62ceb46a…` (stale `b186f03…` gone), "All twelve must pass" + `path-gated`/`mix verify.install_golden`/`mix ci.install_golden` preserved. |
| 8 | Contract test locks the new topology and `mix ci.verify_gates` stays green | ✓ VERIFIED | `release_gate_contract_test.exs`: `@ci_gate_lanes` = 14 (incl. install_golden), `@pr_gate_lanes` = 4, asserts pr-gate needs, no paths-ignore on fast lanes, ci-gate guard+name, install_golden PR-exemption+detect pattern, cache keying (D-12), script extraction+Sigra-in-script. `mix ci.verify_gates` → **529 tests, 0 failures**. |

**Score:** 8/8 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `.github/workflows/ci.yml` | pr-gate + guarded ci-gate + event-guarded heavy lanes + caches + script wiring | ✓ VERIFIED | All present and consistent; YAML well-formed; 10 event guards; 0 path filters |
| `scripts/ci/aggregate-gate.sh` | required-lane pass/fail loop, shared by both gates | ✓ VERIFIED | Fails on any non-`success`; exercised locally |
| `scripts/ci/detect-installer-changes.sh` | verbatim installer detect regex, prints `run=true|false` | ✓ VERIFIED | Regex verbatim; called by install_golden detect step |
| `scripts/ci/sigra-proof.sh` | root + demo proof lanes, full env contract | ✓ VERIFIED | Both lanes + env names preserved; called by verify_sigra |
| `test/chimeway/release_gate_contract_test.exs` | topology + cache + extraction lock | ✓ VERIFIED | 529 tests green; no prior assertion weakened |
| `CONTRIBUTING.md` | pr-gate story + scripts/ci + canonical URL | ✓ VERIFIED | All markers present; legacy URL removed |
| `MAINTAINING.md` | split + operator swap + Sigra ref + preserved copy | ✓ VERIFIED | All markers present; stale ref + false claim removed |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `ci.yml` pr-gate/ci-gate | `scripts/ci/aggregate-gate.sh` | `run:` step | ✓ WIRED | Both gates call it with correct lane lists; checkout added so script is present |
| `ci.yml` install_golden detect | `scripts/ci/detect-installer-changes.sh` | detect step | ✓ WIRED | Appends `run=…` to `$GITHUB_OUTPUT`; non-PR early `run=true` preserved |
| `ci.yml` verify_sigra | `scripts/ci/sigra-proof.sh` | root + demo steps | ✓ WIRED | Two steps call `sigra-proof.sh root` / `demo` |
| release/publish/automerge | `ci-gate` job name | github-script poll | ✓ WIRED | Name literal `ci-gate` unchanged; polling JS untouched (D-10) |
| branch protection | `pr-gate` context | ruleset 18486746 | ✓ WIRED | Ruleset active, requires `pr-gate` |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Gate fails on non-success lane | `FOO=failure aggregate-gate.sh FOO` | exit 1, "Required lane FOO: failure" | ✓ PASS |
| Gate fails on skipped lane | `FOO=skipped aggregate-gate.sh FOO` | exit 1 | ✓ PASS |
| Gate passes when all success | `FOO=success BAR=success aggregate-gate.sh FOO BAR` | exit 0 | ✓ PASS |
| Self-verifying gate suite | `mix ci.verify_gates` | 529 tests, 0 failures | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| CI-01 | 80-01, 80-04 | Fast always-running pr-gate | ✓ SATISFIED | Truth 1 |
| CI-02 | 80-01, 80-04 | ci-gate release source of truth, ≥ as strict | ✓ SATISFIED | Truth 2 |
| CI-03 | 80-01, 80-04 | No permanent-pending required checks | ✓ SATISFIED | Truth 3 (+ live confirmation human item) |
| CI-04 | 80-03, 80-04 | Complex CI reproducible via scripts | ✓ SATISFIED | Truth 4 |
| CI-05 | 80-02 | Nested/demo/npm/Playwright caches | ✓ SATISFIED | Truth 5 |

No orphaned requirements — REQUIREMENTS.md maps CI-01..CI-05 to Phase 80, all claimed by plan frontmatter.

### Anti-Patterns Found

None. No `TBD`/`FIXME`/`XXX`/`TODO`/`HACK`/`PLACEHOLDER` in the modified ci.yml, scripts, or docs. No stub returns; scripts are complete bash reproductions of the inline logic. Prohibitions upheld: ci-gate not renamed, `needs` inline (not multi-line), release/publish/automerge workflows unmodified, no paths filters on required-feeding lanes, no source-keyed caches.

### Human Verification Required

**1. Live PR anti-pending confirmation (CI-03)**

**Test:** Open a real PR to `main` touching only non-installer files; observe the checks tab.
**Expected:** `pr-gate` reports a conclusion (not "Waiting for status to be reported"); `ci-gate`, the nine heavy lanes, and `install_golden_contract` are skipped (not pending) on the PR event; merge is gated on `pr-gate` via active ruleset 18486746.
**Why human:** The anti-pending property is a GitHub Actions + branch-protection runtime behavior on external infrastructure. All static preconditions are verified in-repo and the ruleset is confirmed active via API, but a live PR reporting without stranding is not observable from the repo tree. The plan's own 80-04 Task 3 checkpoint specified this test; the SUMMARY confirmed the ruleset but not a live PR run.

### Gaps Summary

No gaps. Every phase artifact exists, is substantive, and is wired. The two-aggregate topology, cache coverage, script extraction, docs alignment, and D-08 ruleset are all present and consistent with the plans, and the self-verifying contract suite is green (529/0). SUMMARY claims (14 lanes, 529 tests, ruleset id 18486746, corrected Sigra ref, verbatim regex) were independently confirmed against the codebase and GitHub API — no divergence found. The single open item is a live-PR confirmation of the anti-pending runtime behavior on GitHub's infrastructure, which cannot be observed statically.

---

_Verified: 2026-07-03T16:58:14Z_
_Verifier: Claude (gsd-verifier)_
