---
phase: 66-docs-release-gates
plan: 01
subsystem: documentation
tags: [docs, integration-guides, seed-003, threadline, sigra]
requires:
  - "Phase 63: Chimeway.Telemetry.ThreadlineReporter shipped"
  - "Phase 64: Sigra.Integrations.Chimeway seam shipped"
  - "Phase 65: sigra-auth-blueprint.md recipe + demo seeds shipped"
provides:
  - "guides/introduction/threadline-integration.md — 4-section Threadline golden-path guide"
  - "guides/introduction/sigra-auth-integration.md — 5-section Sigra auth golden-path guide"
affects:
  - "Plan 03 doc-contract describe blocks read these two files"
tech-stack:
  added: []
  patterns:
    - "accrue-dunning-integration.md golden-path guide template (responsibility split, numbered sections, Related guides footer)"
key-files:
  created:
    - guides/introduction/threadline-integration.md
    - guides/introduction/sigra-auth-integration.md
  modified: []
decisions:
  - "Omitted Threadline blueprint cross-link — no threadline recipe exists in guides/recipes/ (per plan: omit if absent)"
  - "Anti-pattern note uses prose form raw_token/magic_link_url/confirmation_code WITHOUT colon prefix to avoid tripping @sigra_forbidden atom-form substring check (RESEARCH pitfall 4 / open question 2)"
metrics:
  duration: ~6m
  completed: 2026-06-02
requirements: [DOCS-10]
---

# Phase 66 Plan 01: SEED-003 Integration Guides Summary

Wrote the two new SEED-003 golden-path integration guides — Threadline telemetry bridge (attach-only, 4 sections) and Sigra auth notification flows (5 sections) — following the accrue-dunning-integration.md template with responsibility-split headers and guide-specific content from Phase 63/64 context decisions.

## What was built

### Task 1: Threadline integration guide (D-01)
`guides/introduction/threadline-integration.md` — 4-section attach-only guide:
1. **Dependencies** — `{:threadline, "~> 0.7", optional: true}` with `threadline_dep/0` THREADLINE_PATH env-override pattern.
2. **Attach reporter** — `Application.start/2` one-liner calling `Chimeway.Telemetry.ThreadlineReporter.attach/0` + `config :chimeway, :threadline_reporter` block with `:repo` and `:actor` only.
3. **What gets recorded** — 4-row outcome table (suppressed/deferred/dispatched/failed → action atoms) plus the `correlation_id` callout for `Threadline.Query.timeline/2` strict filter.
4. **Verification** — `DemoHost.Seeds.seed_threadline_notification/0`, `mix verify.threadline`, `/admin/chimeway` trace inspection.

Responsibility split: Chimeway orchestrates the when and why; Threadline owns the immutable audit ledger.

Commit: `8c9e1c8`

### Task 2: Sigra auth integration guide (D-02, D-03)
`guides/introduction/sigra-auth-integration.md` — 5-section guide:
1. **Dependencies** — `{:sigra, "~> 0.3", optional: true}` with `sigra_dep/0` SIGRA_PATH env-override pattern.
2. **Integration seam** — `Sigra.Integrations.Chimeway` runtime config + conditional compile, responsibility split.
3. **Notifier reference** — `sigra.auth.magic_link` and `sigra.auth.confirmation_code` stable keys; `build/2` resolves sensitive values at dispatch time.
4. **Auth event triggers** — `Chimeway.trigger/3` with `idempotency_key` + `tenant_id`; inline anti-pattern blockquote leading with "Do not pass".
5. **Verification** — `DemoHost.Seeds.seed_sigra_auth/0`, `SIGRA_PATH=../sigra mix verify.sigra`, `/admin/chimeway`.

Responsibility split uses the exact locked language: "Chimeway orchestrates the when and why" / "Sigra owns auth state".

Commit: `c4fa884`

## Verification

Plan-level verification block — all pass:
1. `grep -l "Chimeway.Telemetry.ThreadlineReporter" threadline-integration.md` — exits 0
2. `grep -l "Sigra.Integrations.Chimeway" sigra-auth-integration.md` — exits 0
3. `grep -c ":raw_token\|:magic_link_url" sigra-auth-integration.md` — 0 (atom-form forbidden strings absent)
4. `grep -c "stop_conditions\|Workflows.Workers\|Chimeway.Trigger.trigger"` both guides — 0
5. Neither guide matches `/Chimeway\.Workflow(?![s])/`.

Both task-level automated checks pass: all `@required` strings present, `@recipe_forbidden_strings` and `@sigra_forbidden` absent, correct numbered section structure (4 / 5), outcome table with 4 rows, anti-pattern blockquote leading with "Do not pass".

## Deviations from Plan

### Auto-fixed Issues

None — plan executed as written.

### Notes (non-deviation)

- **PATTERNS.md / 66-RESEARCH.md availability:** The plan's `<read_first>` referenced `66-PATTERNS.md`, which is untracked in the worktree base. The plan's own `<interfaces>` section plus `66-CONTEXT.md` and the present `66-RESEARCH.md` carried all required content (responsibility-split language, outcome atoms, anti-pattern note text, required/forbidden string lists), so no information was missing.
- **Threadline blueprint link omitted:** Per Task 1 action ("if absent, omit the blueprint link") — no threadline recipe exists in `guides/recipes/`. The Related guides footer links golden-path, mailglass blueprint, and installation only.
- **Anti-pattern colon-prefix care (RESEARCH pitfall 4):** The Sigra section 4 blockquote uses prose form `raw_token`, `magic_link_url`, `confirmation_code` (no colon prefix). The doc-contract `@sigra_forbidden` uses `String.contains?` on the atom-syntax substrings `:raw_token` / `:magic_link_url`; using the colon form even inside backticks would fail the test. Verified `grep -c ":raw_token\|:magic_link_url"` returns 0.

## Known Stubs

None — both guides are complete prose documents with all required content wired. No placeholder text, TODOs, or empty data sources.

## Threat Flags

None — both files are markdown documentation. The Sigra guide section 4 implements the T-66-01 mitigation (information-disclosure anti-pattern note forbidding sensitive params in `Chimeway.trigger/3`) called for in the plan threat model; no new security surface introduced.

## Self-Check: PASSED

- FOUND: guides/introduction/threadline-integration.md
- FOUND: guides/introduction/sigra-auth-integration.md
- FOUND commit: 8c9e1c8 (Threadline guide)
- FOUND commit: c4fa884 (Sigra guide)
