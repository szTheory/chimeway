---
phase: 66-docs-release-gates
plan: 03
subsystem: docs-release-gates
tags: [doc-contract, ci-gates, threadline, sigra, hexdocs]
requires:
  - "guides/introduction/threadline-integration.md (66-01)"
  - "guides/introduction/sigra-auth-integration.md (66-01)"
  - "mix.exs docs extras entries for threadline + sigra guides (66-01)"
provides:
  - "Doc-contract describe block locking threadline integration guide (DOCS-10)"
  - "Doc-contract describe block locking sigra auth integration guide (DOCS-10)"
  - "Hexdocs extras ordering tests covering inbox < threadline < sigra"
affects:
  - "mix ci.verify_gates lane (now enforces 5 integration guides)"
tech-stack:
  added: []
  patterns:
    - "describe-block doc contract: setup reads guide via Path.expand + File.read!, @required ~w() substring assertions, :binary.match heading-order test"
    - "@sigra_forbidden ~w(:raw_token :magic_link_url) — atom-form (leading colon) refute assertions avoid false positives on prose"
key-files:
  created: []
  modified:
    - "test/chimeway/doc_contract_test.exs"
decisions:
  - "Used multi-line setup (content = File.read!(...); %{content: content}) to match existing accrue/inbox block convention"
  - "Backslash-escaped spaces in ~w() (config\\ :chimeway, mix\\ verify.threadline, mix\\ verify.sigra) keep multi-word substrings as single tokens"
metrics:
  duration: ~12m
  completed: 2026-06-02
  tasks: 1
  files: 1
---

# Phase 66 Plan 03: Threadline + Sigra Doc-Contract Gates Summary

Locked the Threadline and Sigra integration guides as CI truth by adding two doc-contract describe blocks (DOCS-10) to `doc_contract_test.exs` and extending the hexdocs extras block to validate all five integration guides appear in correct order.

## What Was Built

- **Threadline describe block** (`threadline integration guide doc contract (DOCS-10)`): inherits `@recipe_forbidden_strings` refute loop, the `Chimeway.Workflow` (not Workflows) regex guard, an `@required ~w()` of all 8 strings from D-04 (`Chimeway.Telemetry.ThreadlineReporter`, `attach/0`, `config :chimeway`, `correlation_id`, `notification_suppressed`, `DemoHost.Seeds.seed_threadline_notification`, `/admin/chimeway`, `mix verify.threadline`), and a golden-path heading-order test (`## 1. Dependencies` → `## 2. Attach reporter` → `## 3. What gets recorded` → `## 4. Verification`).
- **Sigra describe block** (`sigra auth integration guide doc contract (DOCS-10)`): forbidden-string loops, the `Chimeway.Workflow` regex guard, a new `@sigra_forbidden ~w(:raw_token :magic_link_url)` refute loop (atom-form only, so prose `raw_token`/`magic_link_url` in the guide's redaction warning correctly does NOT trip the assertion), an `@required ~w()` of all 11 strings from D-05, and a golden-path heading-order test across the guide's five sections.
- **Hexdocs extras block update**: appended `threadline-integration.md` and `sigra-auth-integration.md` to `@integration_guides`, and added two `:binary.match` ordering tests asserting `inbox_index < threadline_index` and `threadline_index < sigra_index`.

## Verification Results

- `MIX_ENV=test mix test test/chimeway/doc_contract_test.exs` → 291 tests, 0 failures
- `MIX_ENV=test mix ci.verify_gates` → 330 tests, 0 failures, exit 0
- `grep -c "threadline integration guide doc contract"` = 1
- `grep -c "sigra auth integration guide doc contract"` = 1
- `grep -c ":raw_token"` = 1
- `grep -c "threadline-integration.md"` = 4 (attribute path + @integration_guides + 2 ordering tests)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fetched project dependencies in worktree**
- **Found during:** Task 1 verification
- **Issue:** The worktree had no `deps/` or `_build/` — `mix test` aborted with "the dependency is not available". This is a fresh-worktree state issue, not a new package.
- **Fix:** Ran `mix deps.get` (deps already declared in the shared `mix.lock`; no new/substitute packages installed — excluded-install rule does not apply since nothing was added to mix.exs).
- **Files modified:** none (build artifacts only, gitignored)
- **Commit:** n/a (no source change)

## Authentication Gates

None.

## Known Stubs

None — all assertions reference real strings present in the prior-wave guides.

## Self-Check: PASSED

- FOUND: test/chimeway/doc_contract_test.exs (modified, contains both new describe blocks)
- FOUND: commit 0d86889 (test(66-03): lock threadline and sigra integration guides via doc contract)
- FOUND: .planning/phases/66-docs-release-gates/66-03-SUMMARY.md
