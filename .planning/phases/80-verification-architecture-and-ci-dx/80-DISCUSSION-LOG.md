# Phase 80: Verification Architecture and CI/DX - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-07-03
**Phase:** 80-verification-architecture-and-ci-dx
**Mode:** assumptions
**Areas analyzed:** pr-gate/ci-gate topology, anti-pending-trap structure, CI-04 extraction scope,
cache coverage, docs & contract alignment

## Assumptions Presented

### Topology: pr-gate / ci-gate split (CI-01, CI-02)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Single `ci.yml`, two aggregate jobs (not a second workflow) | Likely | `ci.yml:610-645` aggregate pattern exists |
| `pr-gate` needs only `{lint, test, verify_gates, verify_docs}`, required on PRs | Likely | fast lanes = no siblings/npm/Playwright |
| `ci-gate` needs all lanes, main+`workflow_dispatch` only, stays release source of truth | Likely | release/publish/automerge poll `ci-gate` by name; `ci.yml:9` |
| Heavy lanes gated off `pull_request` event (main/dispatch only) | Likely | ecosystem lanes are the expensive matrix |
| Fold `install_golden_contract` into `ci-gate` needs (strictness gap today) | Confident | `ci.yml:544`/`613` — floats outside aggregate |

### Anti-pending-trap structure (CI-03)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Exactly one always-running required aggregate per context; lanes never independently required | Confident | standard GitHub Actions required-check semantics |
| Reuse detect-then-conditional-steps pattern; no job-level `paths:` filters on required-feeding lanes | Confident | `ci.yml:569-608` install_golden pattern |
| Branch-protection required-check swap is an external operator action | Confident | branch protection lives in GitHub settings, not repo |

### Local reproducibility (CI-04)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Extract detect/aggregate/sigra-proof fragments to `scripts/ci/*.sh` + Mix tasks | Likely | `ci.yml:572-583`, `631-645`, `478-499`; no `scripts/` dir |
| Do NOT rewrite release/publish/automerge `github-script` JS (release-path risk) | Likely | CI-02 preserve release surface |

### Cache coverage (CI-05)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Add nested-mix, npm, and Playwright-browser caches keyed on real lockfiles/version | Confident | `verify.admin`/`inbox`/`example` aliases + `ci.yml:525-542` uncached |
| Don't cache results/artifacts that could mask failures; keep `_build` keyed on lockfiles | Confident | pre-existing cache design |

### Docs & contract alignment
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Update CONTRIBUTING/MAINTAINING for pr-gate/ci-gate + branch-protection swap | Likely | `MAINTAINING.md:12-13,29-33`; `CONTRIBUTING.md:46` |
| Lock topology via extended doc-contract test, not a new file | Likely | Phase 79 `D-09` precedent |

## Corrections Made

No corrections applied. Two clarifying questions (PR lane scope; CI-04 extraction scope) were posed
via AskUserQuestion; the user was away from keyboard (60s timeout, no response). Per project
METHODOLOGY (decisive one-shot recommendation, low escalation for reversible CI-internal choices),
the recommended defaults were locked and flagged in CONTEXT.md (D-04, D-09) as revisitable before
execution:
- **PR lane scope:** recommended "main/release only" (heavy lanes off the `pull_request` event).
- **CI-04 extraction:** recommended "scripts + Mix tasks, verify fragments only" (release JS untouched).

## Auto-Resolved

Not applicable (not `--auto`; defaults locked due to user-away timeout, recorded above).

## External Research

None performed — codebase evidence (ci.yml, mix.exs aliases, release/publish/automerge workflows,
CONTRIBUTING/MAINTAINING) was sufficient; GitHub Actions topology is within model knowledge.
</content>
