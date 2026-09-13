---
phase: 260912-x9i
plan: 01
subsystem: dependency-release-hygiene
tags: [dependencies, security, ci, github-triage, release-readiness]
requires:
  - phase: 260912-x9h
    provides: release-facing documentation and repository metadata truth
provides:
  - solver-generated advisory-safe root, admin, inbox, and demo dependency graphs
  - immutable Accrue 1.5.1 integration checkout contract
  - explicit Hackney and Cowlib residual-risk documentation
  - one idempotently marked upstream-risk tracker with evidence-gated PR disposition
affects: [release, ci, admin, inbox, demo-host, security]
key-files:
  modified:
    - mix.lock
    - chimeway_admin/mix.lock
    - chimeway_inbox/mix.lock
    - examples/chimeway_demo_host/mix.exs
    - examples/chimeway_demo_host/mix.lock
    - .github/workflows/ci.yml
    - test/chimeway/release_gate_contract_test.exs
    - SECURITY.md
    - chimeway_admin/lib/chimeway_admin/live_auth.ex
    - chimeway_admin/test/chimeway_admin/live_auth_test.exs
key-decisions:
  - "Accept only the four graph-constrained Hackney findings and the independently verified Cowlib scanner-feed mismatch; keep every ignore one-shot and explicit."
  - "Keep contributor PRs open until a replacement object publicly resolves to the exact local SHA and that SHA has a completed successful pr-gate."
  - "Treat the Playwright 1.60 to 1.63 availability as non-security upkeep outside this no-JavaScript-churn batch."
requirements-completed: []
completed: 2026-09-13
status: complete
---

# Quick 260912-x9i: Dependency and GitHub Inbox Stabilization Summary

**All safely remediable dependency findings are resolved, the remaining upstream constraints are explicit, and live GitHub triage is bound to public exact-SHA evidence.**

## Accomplishments

- Incorporated PR #28's exact one-file root lock resolution without merging its stale-base branch or changing the root manifest.
- Refreshed the admin and inbox locks within their existing constraints; both graphs now resolve current Phoenix, LiveView, Plug, Postgrex, and Hackney 4 lines and have clean Hex audits.
- Aligned the demo host with Accrue 1.5.1, Decimal 3, and Ecto SQL 3.14; pinned the Accrue CI checkout to immutable commit `d30fc25dbf6ba551792c66ff451b4b93c0af4bf1` and mutation-locked only that checkout step.
- Documented the four unavoidable Hackney 1.25.0 advisories and the Cowlib 2.20 scanner-feed exception with authoritative affected-range and fix-ancestry evidence.
- Filed the unique residual tracker at https://github.com/szTheory/chimeway/issues/29 with the stable marker, affected paths, exposure assessment, upstream floor, integration-gate closure condition, and all four CVEs.
- Fixed the LiveView 1.2.11 fail-closed redirect regression without logging unexpected secret-bearing callback returns.

## Task Commits

1. **Root lock / PR #28 incorporation** — `f85ff13c`
2. **Admin lock refresh** — `802e5ecc`
3. **Inbox lock refresh** — `77d0a462`
4. **Demo, Accrue checkout contract, and residual documentation** — `8f833ce4`
5. **LiveView 1.2.11 auth compatibility repair** — `7559b58b`

## Verification Evidence

- Root lock is byte-identical to PR #28 head `d03c7b88e51738083b3ab12575b10730f94d1592`; all four locks pass solver locked checks.
- Root raw audits report exactly four Hackney findings; root explicit-only Hex and GitHub advisory ignore commands pass.
- Admin: clean Hex audit and 61 warning-strict tests, 0 failures.
- Inbox: clean Hex audit and 29 warning-strict tests, 0 failures.
- Demo raw audit reports exactly four Hackney plus three cross-checked Cowlib feed findings; its explicit-only audit command passes.
- Accrue checkout release contract: 9 tests, 0 failures; the broader focused release contract completed 165 tests, 0 failures, 4 excluded.
- Final root `mix ci`: 1,603 tests, 0 failures, 41 excluded; formatting, warning-strict compilation, and strict Credo passed.
- JavaScript audit: 0 vulnerabilities. `npm outdated` reports only dev-only `@playwright/test` 1.60.0 -> 1.63.0; no JavaScript files changed.
- Independent verifier: 7/7 must-haves passed.

## Live GitHub Disposition

- PR #22 is still open and conflicting; PR #28 is still open and mergeable with its exact dependency lock already incorporated.
- Both PRs intentionally remain open because the current implementation SHA is not yet public and therefore cannot yet have a successful exact-SHA `pr-gate`.
- After publishing the stabilization branch and obtaining that gate, each PR receives one marker-bound provenance comment and is closed as superseded/incorporated.

## Explicit Non-Claims

- A reused local demo database makes `mix verify.example` fail six older seed/tenant-isolation tests; this summary does not call that alias green. Public CI's fresh database and the isolated release gates remain the release authority.
- `mix ci.verify_gates` and the ecosystem aliases are reserved for the final integrated candidate and are not claimed here.
- No Hackney override, package-major campaign, Elixir/OTP floor change, hand-edited lock tuple, checked-in advisory waiver, or JavaScript dependency churn was introduced.

## Self-Check: PASSED

- All implementation commits and residuals are recorded.
- Issue #29 is unique and contract-complete.
- PR closure is correctly deferred to public exact-SHA evidence.

---
*Quick: 260912-x9i*
*Completed: 2026-09-13*
