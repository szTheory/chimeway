---
phase: 96
slug: adoption-front-door-proof-gate
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-08-10
updated: 2026-08-11
---

# Phase 96 — Validation Strategy

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit plus GitHub Actions exact-SHA assertion |
| **Quick run command** | `mix ci.verify_gates` |
| **Behavioral command** | `mix verify.adoption_paths` |
| **Hosted evidence command** | `scripts/ci/assert-adoption-run.sh <40-character-sha>` |
| **Required PR gate** | `pr-gate` requires `Adoption proof paths` on every pull request |

## Per-Task Verification Map

| Task | Requirement | Automated evidence | Status |
|------|-------------|--------------------|--------|
| Strict task parsing and serial runner | GATE-01 | Release-gate contracts plus focused proof commands | ✅ green |
| Redacted, allowlisted proof output | GATE-01 | Parser/framing mutation contracts | ✅ green |
| Three-path selector and ownership boundaries | ADPT-01, ADPT-02, DOCS-01 | Documentation contracts in `mix ci.verify_gates` | ✅ green |
| Immutable archive bytes under pathname replacement | GATE-01 | Deterministic open/replace/resume regression test | ✅ green |
| PostgreSQL-backed adoption lane on every PR | GATE-02, DOCS-01 | Workflow topology contracts plus exact-SHA live assertion | ✅ green |

## Lane Ownership

- `mix ci.verify_gates` owns structural, mutation, security, and documentation contracts.
- `Adoption proof paths` owns the expensive packaged Core → Mailglass → Accrue E2E exactly once per PR.
- `pr-gate` consumes the adoption job result, so a skipped, failed, duplicated, or wrong-SHA proof cannot sign UAT.
- `scripts/ci/assert-adoption-run.sh` accepts only a completed successful pull-request run for the exact supplied SHA with one successful adoption job and one successful `pr-gate`.

## Evidence

- Local canonical gate: 612 tests, 0 failures, 1 dedicated E2E excluded.
- Direct adoption E2E: Core, Mailglass, and Accrue passed in order.
- Hosted run: `31449129603` on `c13bae7c92c537f3e758330703168119703a301b`.
- Hosted result: `Adoption proof paths`, `Release gate contract`, general `Test`, and `pr-gate` all succeeded.
- Run URL: https://github.com/szTheory/chimeway/actions/runs/31449129603

## Manual-Only Verifications

None. Human review is reserved for subjective behavior; Phase 96 acceptance is fully machine-readable.

## Validation Sign-Off

- [x] All tasks have automated verification.
- [x] Runtime E2E is executed exactly once per PR.
- [x] Every machine-testable UAT item has executable evidence.
- [x] Hosted evidence is pinned to an exact commit SHA.
- [x] No watch-mode flags.
- [x] `nyquist_compliant: true` set in frontmatter.

**Approval:** automated evidence complete
