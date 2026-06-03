---
phase: 66-docs-release-gates
plan: 02
subsystem: build-tooling
tags: [release-gates, ci, mix-aliases, verify, threadline, sigra]
requires:
  - "verify.accrue alias + verify_accrue CI job (existing template)"
  - "threadline_deps/0 and sigra_deps/0 in mix.exs (Phases 63/64)"
provides:
  - "mix verify.threadline alias"
  - "mix verify.sigra alias"
  - "verify_threadline + verify_sigra CI jobs"
  - "11-lane ci-gate"
  - "10-command MAINTAINING pre-ship checklist"
  - "release gate contract reflecting 11 lanes / 7 pre-ship verify commands"
affects:
  - mix.exs
  - .github/workflows/ci.yml
  - MAINTAINING.md
  - test/chimeway/release_gate_contract_test.exs
tech-stack:
  added: []
  patterns:
    - "verify.accrue alias copy-adapt for verify.threadline / verify.sigra"
    - "verify_accrue CI job copy-adapt with pinned sibling-repo SHA"
    - "release_gate_contract_test as authoritative parity gate"
key-files:
  created: []
  modified:
    - mix.exs
    - .github/workflows/ci.yml
    - MAINTAINING.md
    - test/chimeway/release_gate_contract_test.exs
decisions:
  - "Pinned szTheory/threadline ref 46375fafc4df30fc916244ee4a21b7cae01f1ddc and szTheory/sigra ref b186f03ccc5bbc9416f495df3e5dd0bec2f814a4 (resolved live via git ls-remote HEAD)"
  - "Consolidated MAINTAINING sibling-checkout subsection into a single 'Sibling repo checkouts' list covering accrue + threadline + sigra"
metrics:
  duration: ~12min
  completed: 2026-06-02
---

# Phase 66 Plan 02: Verify Gates Wiring (Threadline + Sigra) Summary

Wired `mix verify.threadline` and `mix verify.sigra` into mix.exs aliases, two CI jobs with sibling-repo checkout, the MAINTAINING pre-ship checklist, and the release gate contract test — completing GATE-07 tooling so the Phase 63/64 integrations are named, CI-gated entrypoints.

## What Was Built

**Task 1 — mix.exs aliases + docs extras (commit f4bb79e)**
- Added `verify.threadline` alias: `deps.compile threadline --force` + root `--only threadline` lane + demo host lane with `CHIMEWAY_SKIP_THREADLINE_DEP=1 THREADLINE_PATH=../../../threadline/threadline CHIMEWAY_PATH=../..`.
- Added `verify.sigra` alias mirroring `verify.accrue` with `CHIMEWAY_SKIP_SIGRA_DEP=1 SIGRA_PATH=../../../sigra/sigra CHIMEWAY_PATH=../..`.
- Registered `guides/introduction/threadline-integration.md` and `guides/introduction/sigra-auth-integration.md` in `docs/0` extras (Introduction group, after inbox-integration.md).

**Task 2 — CI jobs + ci-gate expansion (commit aa013e9)**
- Added `verify_threadline` job ("Threadline telemetry gate"): postgres service, `THREADLINE_PATH` env, `szTheory/threadline` sibling checkout at `path: threadline/threadline` pinned to `46375fafc4df30fc916244ee4a21b7cae01f1ddc`, ending in `mix verify.threadline`.
- Added `verify_sigra` job ("Sigra auth integration gate"): postgres service, `SIGRA_PATH` env, `szTheory/sigra` sibling checkout at `path: sigra/sigra` pinned to `b186f03ccc5bbc9416f495df3e5dd0bec2f814a4`, ending in `mix verify.sigra`.
- Expanded `ci-gate` `needs` from 9 to 11 entries; added `VERIFY_THREADLINE` / `VERIFY_SIGRA` env vars and extended the lane for-loop.

**Task 3 — MAINTAINING + release gate contract (commit 2d3c98f)**
- MAINTAINING.md: bash block now 10 commands; "Run all ten"; "All ten must pass before publishing."; "These ten local commands"; new bullets for verify.threadline and verify.sigra; consolidated "Sibling repo checkouts" subsection documenting accrue, threadline, sigra `*_PATH` conventions + pinned refs.
- release_gate_contract_test.exs: `@ci_gate_lanes` now 11 entries; `@pre_ship_verify_commands` now 7 tuples; renamed test to "ten-gate" with `~r/All ten must pass/i`; renamed "9 required lanes" → "11 required lanes"; added THREADLINE_PATH/SIGRA_PATH MAINTAINING tests and verify_threadline/verify_sigra sibling-checkout tests.

## Sibling Repo SHAs Pinned

| Repo | Pinned ref | Source |
|------|-----------|--------|
| szTheory/threadline | `46375fafc4df30fc916244ee4a21b7cae01f1ddc` | `git ls-remote https://github.com/szTheory/threadline HEAD` |
| szTheory/sigra | `b186f03ccc5bbc9416f495df3e5dd0bec2f814a4` | `git ls-remote https://github.com/szTheory/sigra HEAD` |

This satisfies threat-model mitigations T-66-03 and T-66-04 (pin sibling checkout to a specific SHA to prevent unexpected upstream changes).

## Verification Results

- `Code.string_to_quoted!(mix.exs)` → PARSE_OK
- `grep -c '"verify.threadline"' mix.exs` = 1; `'"verify.sigra"'` = 1
- `grep -c "verify_threadline:" ci.yml` = 1; `"verify_sigra:"` = 1
- ci.yml validates as YAML; `ci-gate.needs` has 11 entries; both jobs present
- `grep "All ten must pass" MAINTAINING.md` → present
- `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs` → **39 tests, 0 failures**

(The `:threadline`/`:sigra` application-not-available warnings during the test run are expected — the optional deps were skipped via `CHIMEWAY_SKIP_THREADLINE_DEP=1` / `CHIMEWAY_SKIP_SIGRA_DEP=1` and do not affect the contract test, which only inspects file contents.)

## Deviations from Plan

None functional. Two minor notes:
- The plan's automated verify estimated `grep -c VERIFY_THREADLINE ci.yml` = 3; the correct count for the uppercase env token is 2 (env declaration + for-loop). The lowercase job id `verify_threadline:` is counted separately and equals 1. All acceptance criteria are met.
- MAINTAINING.md `mix verify.threadline` appears twice (bash block + bullet), so the plan's `grep -c ... | grep -q "^1$"` estimate was imprecise; content matches the required spec exactly.

## Notes for Next Plan

- This plan touched tooling only — no guide content. The two guide files registered in `mix.exs` docs extras (`threadline-integration.md`, `sigra-auth-integration.md`) are authored in plan 66-01; the docs build (`mix ci.docs`) will fail until those files exist, which is expected within-wave ordering.
- The new doc-contract describe blocks (DOCS-11) for those guides are also a 66-01 concern, not this plan.

## Self-Check: PASSED

- mix.exs verify.threadline / verify.sigra present (grep = 1 each)
- ci.yml verify_threadline / verify_sigra jobs present; ci-gate needs = 11
- MAINTAINING "All ten must pass" present
- release_gate_contract_test.exs: 39 tests, 0 failures
- Commits f4bb79e, aa013e9, 2d3c98f all in git log
