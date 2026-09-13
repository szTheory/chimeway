---
phase: 260912-x9h
plan: 01
subsystem: documentation-release-tooling
tags: [documentation, release-please, mix-task, repository-hygiene, security]
requires:
  - phase: 260912-x9g
    provides: identity-first Release Please behavior and complete verify.clean semantics
provides:
  - runnable README notifier documentation aligned with executable integration proof
  - current inbox dependency, authorization, privacy, and reload guidance
  - canonical repository links and removal of three shipped placeholder guides
  - fail-fast source-checkout boundary for mix demo.up
  - maintainer and agent guidance aligned with executable release and planning truth
affects: [release, public-docs, demo-host, maintainer-workflow, agent-onboarding]
tech-stack:
  added: []
  patterns:
    - public documentation is locked to executable source and integration fixtures
    - repository-only Mix tasks validate their checkout boundary before side effects
    - changing project position is referenced from STATE and ROADMAP rather than duplicated
key-files:
  modified:
    - README.md
    - SECURITY.md
    - AGENTS.md
    - MAINTAINING.md
    - guides/introduction/inbox-integration.md
    - guides/flows/multi-step-journeys.md
    - guides/recipes/feedback-escalation-workflow.md
    - guides/recipes/password-reset-support-trace.md
    - test/chimeway/doc_contract_test.exs
    - lib/mix/tasks/demo.up.ex
    - examples/chimeway_demo_host/test/mix/tasks/demo_up_test.exs
  deleted:
    - GSD-CONTEXT.md
    - guides/flows/trigger-to-delivery.md
    - guides/flows/async-dispatch.md
    - guides/flows/policy-and-preferences.md
key-decisions:
  - "Delete empty shipped guides and route readers to complete existing material instead of authoring rushed replacements."
  - "Resolve demo.up from the active Mix project and reject missing source-checkout topology before database or subprocess work."
  - "Document exact Release Please identity, token-aware CI dispatch, and full Git-state cleanliness without duplicating implementation secrets."
patterns-established:
  - "Public Markdown owner, placeholder, and retired-guide topology is checked table-first across release-facing documentation."
  - "Repository-only helper paths are injectable for focused tests and validated once for runtime reuse."
requirements-completed: []
coverage:
  - id: D1
    description: Runnable and current public Markdown with canonical links and no shipped placeholder guides
    verification:
      - kind: integration
        ref: "scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/doc_contract_test.exs test/chimeway/integration/readme_snippet_test.exs --exclude adoption_paths_e2e --exclude accrue_packaged_cli --warnings-as-errors (501 tests, 0 failures)"
        status: pass
    human_judgment: false
  - id: D2
    description: Demo.Up validates and reuses its source-checkout path before side effects
    verification:
      - kind: unit
        ref: "cd examples/chimeway_demo_host && mix test test/mix/tasks/demo_up_test.exs --exclude journey --warnings-as-errors (2 tests, 0 failures; 1 excluded)"
        status: pass
      - kind: other
        ref: "mix format --check-formatted lib/mix/tasks/demo.up.ex examples/chimeway_demo_host/test/mix/tasks/demo_up_test.exs"
        status: pass
    human_judgment: false
  - id: D3
    description: Maintainer and agent entry points match hardened release, clean-tree, and planning-source behavior
    verification:
      - kind: integration
        ref: "scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/doc_contract_test.exs test/chimeway/release_gate_contract_test.exs test/chimeway/verify_clean_test.exs --exclude adoption_paths_e2e --exclude accrue_packaged_cli --warnings-as-errors (676 tests, 0 failures, 4 excluded; 370.6s)"
        status: pass
    human_judgment: false
duration: "multi-agent task handoffs; aggregate duration not recorded"
completed: 2026-09-13
status: complete
---

# Quick 260912-x9h: Public Documentation and Repository Truth Summary

**Runnable adopter documentation, guarded repository-only demo tooling, and maintainer guidance now agree with executable source and release behavior.**

## Performance

- **Completed:** 2026-09-13
- **Tasks:** 3
- **Authorized implementation paths:** 15 total — 11 modified, 4 deleted
- **Commits:** 4

## Accomplishments

- Completed the README notifier with the exact stable callbacks, opaque recipient fields, rendering assigns, render key, and version exercised by the unchanged trigger-to-explanation integration test.
- Updated inbox dependency and context-map guidance while retaining independent tenant/recipient authorization, opaque identity, topic-secret custody, connected reload, and reauthorization boundaries.
- Replaced legacy repository-owner links, removed three empty packaged guides, and redirected their stale password-reset references to complete guides.
- Made `mix demo.up` a clearly documented source-checkout helper that validates the exact demo-host child before Ecto, application, storage, or subprocess work and reuses that path for both nested commands.
- Aligned MAINTAINING with exact Release Please identity, fallback/stale exact-branch CI dispatch, PAT-native CI behavior, and staged/unstaged/untracked cleanliness; AGENTS now delegates changing state to STATE and ROADMAP, and the obsolete bootstrap file is gone.

## Task Commits

1. **Task 1: Lock runnable public Markdown and remove dead shipped guides** — `6b1d4b3f`
2. **Task 2: Make Demo.Up fail fast outside the repository checkout** — `a0173832`, test-load repair `419297e6`
3. **Task 3: Align maintainer and agent entry-point truth** — `97cdb059`

The summary itself is intentionally uncommitted for the quick-batch orchestrator.

## Authorized Path Manifest

### Modified (11)

- `README.md`
- `SECURITY.md`
- `AGENTS.md`
- `MAINTAINING.md`
- `guides/introduction/inbox-integration.md`
- `guides/flows/multi-step-journeys.md`
- `guides/recipes/feedback-escalation-workflow.md`
- `guides/recipes/password-reset-support-trace.md`
- `test/chimeway/doc_contract_test.exs`
- `lib/mix/tasks/demo.up.ex`
- `examples/chimeway_demo_host/test/mix/tasks/demo_up_test.exs`

### Deleted (4)

- `GSD-CONTEXT.md`
- `guides/flows/trigger-to-delivery.md`
- `guides/flows/async-dispatch.md`
- `guides/flows/policy-and-preferences.md`

## TDD Evidence

### Task 1

- **RED:** 501 tests, 4 intended failures for missing README callbacks, stale inbox dependency/context wording, legacy repository links, and present placeholder guides.
- **GREEN:** 501 tests, 0 failures using the exact planned README/doc-contract command.
- **Static:** `git diff --check` passed; the legacy-owner, placeholder-marker, and retired-guide-reference scan was empty.

### Task 2

- **RED:** 2 tests, 2 intended failures because `demo_host_path!/1` did not yet expose the checkout boundary; the journey smoke was excluded.
- **GREEN:** 2 tests, 0 failures, 1 journey test excluded.
- **REPAIR:** Independent verification exposed a load-order-dependent `function_exported?/3` guard. Commit `419297e6` replaced it with direct public calls; a cold dependency compile plus the focused suite passes 2 tests with 0 failures.
- **JOURNEY:** The retained `JOUR-05` smoke passes independently (1 test, 0 failures, 33 excluded) through the canonical database wrapper.
- **Static:** Both touched Elixir files passed the exact focused format check; the existing journey tags, environment, sequencing, assertions, and 300-second timeout remain present.

### Task 3

- **RED:** 676 tests, 4 intended failures for missing identity-first release wording, token-aware CI bootstrap wording, complete clean-tree semantics, and durable agent-planning pointers; 4 tests were excluded as planned.
- **GREEN:** The exact planned focused command completed in 370.6 seconds with 676 tests, 0 failures, and 4 exclusions.
- **Static:** Formatting and `git diff --check` passed before commit.

## Decisions Made

- Kept this item within its strict 15-path implementation cap; broad source chronology, roadmap checkbox/count reconciliation, the stale bell comment, and nested formatter topology remain separate mechanical follow-up work.
- Deleted the three nine-line placeholder guides because existing complete guides already cover the useful adoption paths and the package included the empty files.
- Kept the Demo.Up command available as a repository convenience, with an actionable package-consumer error, instead of changing Hex package topology or shipping the full demo host.
- Documented token presence and branch behavior without exposing token values or broadening workflow authority.

## Deviations from Plan

One verification-driven repair stayed within the declared 15 implementation paths: the Demo.Up tests now call the public helper directly so module autoloading is deterministic.

## Issues Encountered

- Task 3 was interrupted while its long release-contract gate was still running. The orchestrator resumed the same bounded task, completed the exact planned command with 676 tests and no failures, confirmed the diff check, and committed the verified result as `97cdb059`.
- The repository-wide journey alias remains red in 7 of 11 older tenant-scoping/seed-isolation cases. Those failures are outside x9h's changed behavior; the retained `JOUR-05` smoke is green and the broader journey debt is carried explicitly rather than reported as passing.
- `mix ci.docs` is green after separate low-hanging public-type documentation cleanup in `2f3bd762`.

## Known Stubs

None.

## Threat Review

- Inbox authorization, opaque identity, secret custody, lossy-hint, and authoritative-reload language remains contract-locked.
- Current public repository and private-vulnerability links use the canonical owner.
- Demo.Up rejects unintended filesystem targets before database or subprocess side effects.
- Maintainer prose describes release authority and CI bootstrap without embedding credential values.
- No endpoint, schema, authentication implementation, dependency, or broader release authority was introduced.

## User Setup Required

None.

## Next Work Readiness

- The x9h implementation is complete and machine-verified.
- The quick-batch orchestrator can commit this summary and advance to the dependency/PR triage item.
- The explicitly deferred mechanical cleanup remains bounded outside this item.

## Self-Check: PASSED

- All four implementation/repair commits and their verification results are recorded.
- The manifest contains exactly 11 modified and 4 deleted implementation paths.
- Status is `complete`, deviations are zero, and the Task 3 interruption/resolution is documented.

---
*Quick: 260912-x9h*
*Completed: 2026-09-13*
