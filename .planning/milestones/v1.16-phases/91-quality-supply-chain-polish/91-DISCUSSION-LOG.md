# Phase 91: Quality & Supply-Chain Polish - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-07-30
**Phase:** 91-quality-supply-chain-polish
**Mode:** assumptions
**Areas analyzed:** Toolchain source of truth (QUAL-01), Dependabot (QUAL-02), Least-privilege permissions (QUAL-03), mix_audit advisory scan (QUAL-04), CI↔release Elixir skew (QUAL-05)

## Method note

This phase is entirely CI/release-config scoped. The orchestrator scouted the actual target
files inline (`ci.yml`, `release.yml`, `mix.exs`, `scripts/ci/*`) via targeted greps rather than
spawning a separate gsd-assumptions-analyzer pass — evidence was complete and the
decisive-recommendation / escalation-gate lenses in METHODOLOGY.md favored converging directly.

## Assumptions Presented

### QUAL-01 — Toolchain source of truth
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| New `.tool-versions` (erlang 27 / elixir 1.19-otp-27) as single source; convert ~10 single-pinned setup-beam jobs to `version-file:`; matrix + 1.17-floor legs keep explicit pins; cache keys unchanged (already derive from steps.beam.outputs.*) | Confident | ci.yml repeats `elixir-version:"1.19"`/`otp-version:"27"` in 10+ blocks; cache keys at lines 80/141/242/…; no `.tool-versions` present |

### QUAL-02 — Dependabot
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| New `.github/dependabot.yml`, weekly, ecosystems `mix` + `github-actions`, grouped minor/patch | Confident | No dependabot.yml exists; actions SHA-pinned (`erlef/setup-beam@8251…`) |

### QUAL-03 — Least-privilege permissions
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Top-level `permissions: contents: read`; obs-summary jobs escalate `actions: read`; no other escalation | Confident | Grep found zero GITHUB_TOKEN write usage; only token consumer is `gh api` timing in obs-summary.sh:110 |

### QUAL-04 — mix_audit advisory scan
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Add `:mix_audit` dep; `ci.audit` → `["hex.audit", "deps.audit"]`; keep `continue-on-error: true` advisory-only | Confident | mix.exs:83 `"ci.audit": ["hex.audit"]`; CI step already advisory-only with comment (ci.yml:91-97) |

### QUAL-05 — CI↔release Elixir skew
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| release.yml stays 1.17 (no change); broaden `test_floor_1_17` from nightly-only to push+nightly via a resolve_tiers flag; wire TEST_FLOOR_1_17 into ci-gate so it gates on push (PR-skip = pass) | Likely | release.yml:259 pins 1.17; test_floor_1_17 gated `run_nightly=='true'` (ci.yml:1116-1141) and is a needs: of nightly-gate only (line 1194) |

## Corrections Made

No corrections — user selected "Yes, proceed"; all five assumptions confirmed as presented.

## Decision-point flagged

QUAL-05 gate wiring (gate the floor on push vs. run advisory-only) was surfaced explicitly. The
orchestrator recommended **gating** — "closing the skew" requires enforcing release's 1.17 pin, and a
non-gating leg would reproduce the vacuous-pass footgun in project memory. Confirmed by user.

## External Research

None performed — codebase provided sufficient evidence for all five areas.
