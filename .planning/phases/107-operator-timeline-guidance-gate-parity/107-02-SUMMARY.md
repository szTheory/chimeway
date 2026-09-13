---
phase: 107-operator-timeline-guidance-gate-parity
plan: "02"
subsystem: documentation-and-release-gates
tags: [elixir, phoenix-pubsub, inbox-lifecycle, documentation-contracts, ci-gates, filesystem-safety]
requires:
  - phase: 105-tenant-safe-inbox-change-stream
    provides: durable post-commit inbox change publication and authorized reload
  - phase: 106-idempotent-seen-lifecycle-workflow-proof
    provides: idempotent visible-seen transitions and once-only workflow progression
  - phase: 107-operator-timeline-guidance-gate-parity
    plan: "01"
    provides: lifecycle facts, optional-admin rendering, and the mounted inbox-to-Trace-Detail proof
provides:
  - Source-valid canonical inbox configuration, authorization, isolation, and lifecycle guidance
  - Fail-closed recursive cleanup for release-contract owned temporary directories
  - One five-layer verify.inbox alias with mutation-locked CI and aggregate parity
affects: [inbox-adoption, release-contracts, verify-inbox, pr-gate, ci-gate]
actuals:
  tokens: 12089
  tasks: 3
  commits: 6
plan_head_before: c506a57dac2f6ab98ca4c0fd8b4325b3a483eb71
tech-stack:
  added: []
  patterns:
    - Lossy PubSub messages are reload hints; authorized durable state remains authoritative
    - Recursive test cleanup validates an existing immediate temp child against a closed ownership prefix list
    - One local Mix alias owns the ordered evidence composition consumed unchanged by CI aggregates
key-files:
  created: []
  modified:
    - guides/introduction/inbox-integration.md
    - test/chimeway/doc_contract_test.exs
    - test/chimeway/release_gate_contract_test.exs
    - mix.exs
    - MAINTAINING.md
key-decisions:
  - "Keep inbox lifecycle facts independent: durable arrival, seen, read, archive, provider handoff, visible presentation, protected activation, and engagement never imply one another."
  - "Permit recursive cleanup only for existing, non-symlink immediate children of the expanded system temp root whose basename carries one of four closed Chimeway ownership prefixes."
  - "Retain the existing verify_inbox CI job as the sole hosted owner and make both release aggregates consume its identical result without adding nightly admin or browser work."
patterns-established:
  - "Authoritative reload: reauthorize tenant and recipient access, then reload durable rows after reconnect or any closed PubSub hint."
  - "Owned temp teardown: create and delete the owned directory itself, never a parent derived from a caller-controlled fixture path."
  - "Gate parity: mutation tests lock exact alias command order, sole CI invocation, needs membership, result environment wiring, and aggregate arguments."
requirements-completed: [DOCS-03, GATE-03]
coverage:
  - id: D1
    description: "The canonical inbox guide provides copy-valid configuration and authorization while assigning privacy, ownership, isolation, and lifecycle boundaries explicitly."
    requirement: DOCS-03
    verification:
      - kind: integration
        ref: "test/chimeway/doc_contract_test.exs --only inbox_gate_parity"
        status: pass
    human_judgment: false
  - id: D2
    description: "Every recursive release-contract cleanup passes through a fail-closed owned-temp guard that refuses root, nested, outside, unowned, and symbolic-link targets."
    requirement: GATE-03
    verification:
      - kind: unit
        ref: "test/chimeway/release_gate_contract_test.exs --only release_cleanup_safety"
        status: pass
      - kind: integration
        ref: "mix ci.verify_gates"
        status: pass
    human_judgment: false
  - id: D3
    description: "The five ordered inbox evidence layers run through one warning-strict alias whose single CI owner feeds identical fail-closed PR and CI aggregate edges."
    requirement: GATE-03
    verification:
      - kind: integration
        ref: "test/chimeway/release_gate_contract_test.exs --only inbox_gate_parity"
        status: pass
      - kind: integration
        ref: "mix verify.inbox"
        status: pass
      - kind: integration
        ref: "mix ci.verify_gates"
        status: pass
    human_judgment: false
duration: 42min
completed: 2026-09-13
status: complete
---

# Phase 107 Plan 02: Canonical Inbox Guidance and Gate Parity Summary

**A privacy-accurate inbox ownership guide, ownership-validated release cleanup, and one mutation-locked five-layer inbox gate now carry the lifecycle contract from local verification into both release aggregates.**

## Performance

- **Duration:** 42 min
- **Started:** 2026-09-13T01:02:41Z
- **Completed:** 2026-09-13T01:43:55Z
- **Tasks:** 3
- **Files modified:** 5

## Accomplishments

- Replaced the canonical inbox guide's stale lifecycle copy with source-valid publisher, PubSub, secret, and authorization configuration; explicit core/package/host ownership; opaque recipient mapping; tenant isolation; and authoritative reconnect/reload semantics.
- Centralized every recursive release-contract teardown behind a closed-prefix, expanded-path, immediate-temp-child guard, with mutation tests proving refusal before broad gates ran.
- Expanded `mix verify.inbox` to five cheapest-to-broadest evidence layers and mutation-locked its exact order, single hosted owner, and identical `pr-gate`/`ci-gate` result edges without editing CI topology.

## Task Commits

1. **Task 1 RED: inbox guidance contracts** — `bcb5ae7c` (`test`)
2. **Task 1 GREEN: canonical ownership guidance** — `c96e9729` (`feat`)
3. **Task 2 RED: cleanup safety contracts** — `29df4eb8` (`test`)
4. **Task 2 GREEN: owned-temp cleanup guard** — `6e2ae93d` (`feat`)
5. **Task 3 RED: inbox gate parity contracts** — `a6827b1b` (`test`)
6. **Task 3 GREEN: complete inbox verification lane** — `0b13aafc` (`feat`)

## Files Created/Modified

- `guides/introduction/inbox-integration.md` — Canonical configuration, auth, ownership, isolation, authoritative reload, and non-implication lifecycle guidance.
- `test/chimeway/doc_contract_test.exs` — Tagged positive, ordered, stale-semantics, and unsafe-identity documentation contracts.
- `test/chimeway/release_gate_contract_test.exs` — Owned-temp cleanup implementation and refusal tests plus exact alias/job/aggregate mutation contracts.
- `mix.exs` — Existing `verify.inbox` alias expanded to the five ordered warning-strict evidence layers.
- `MAINTAINING.md` — Complete pre-ship inbox evidence inventory and equal aggregate-consumer statement.

## Decisions Made

- Used tracked demo configuration and both host authorization callbacks as the copy-valid documentation source, while making production secret custody, tenant membership, recipient mapping, and authorization explicitly host-owned.
- Treated PubSub delivery and reconnect as lossy reasons to reauthorize and reload durable state, never as lifecycle truth or engagement evidence.
- Used `File.lstat/1` at the destructive boundary so a name-valid symbolic link cannot satisfy the owned-directory contract.
- Kept `.github/workflows/ci.yml` unchanged: the existing `verify_inbox` job remains the single invocation owner, and exact structural contracts prove both aggregates consume the same result.

## TDD Gate Compliance

- Task 1 recorded valid RED evidence from 3 intended documentation-contract failures before implementation; the final tagged guide contract passed 28 tests with 0 failures.
- Task 2 recorded valid RED evidence from 3 intended missing-guard/refusal failures before implementation. Its focused safety contract passed and commit `6e2ae93d` landed before any broad release or aggregate command was run.
- Task 3 recorded valid RED evidence from 2 intended alias/maintainer parity failures before implementation; the final focused release contract passed 4 tests with 0 failures.
- All RED evidence records passed `gsd-tools check tdd-red-evidence`; RED and GREEN changes were committed separately for every task.

## Verification

- `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/doc_contract_test.exs --only inbox_gate_parity --warnings-as-errors` — 28 tests, 0 failures.
- `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --only release_cleanup_safety --warnings-as-errors` — 3 tests, 0 failures.
- `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --only inbox_gate_parity --warnings-as-errors` — 4 tests, 0 failures.
- `mix verify.inbox` — 74 root tests, 24 package tests, 9 admin tests, 32 tagged documentation/release tests, and 5 demo-host tests; 0 failures.
- `mix ci.verify_gates` — 647 release-contract tests, 3 packaged-CLI tests, and CrossWake provider-feedback documentation verification; 0 failures.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The first Task 3 removal mutation targeted a duplicate command elsewhere in `mix.exs`, leaving the intended alias unchanged. Scoping mutations to the extracted `verify.inbox` source block made every deletion and reorder check deterministic before the GREEN commit.
- Nested `mix deps.get` commands reported an expired optional Hex authentication session and advisories for already-locked dependencies; resolution remained unchanged and every required warning-strict test command passed. No dependency changes were authorized or made.
- Demo-host startup emitted existing configured-but-optional application notices for `:ex_cldr`, `:ex_money`, and `:accrue`; the scoped test suite passed with 0 failures.

## Known Stubs

None. The plan-owned changes add no TODO/FIXME/placeholder, hardcoded empty UI data source, skipped test, or unrun verification.

## Threat Flags

None. The documentation trust boundary, gate topology, and destructive filesystem boundary were all declared in the plan threat model and covered by executable positive and mutation-negative contracts; no new endpoint, auth path, schema, or runtime file-access surface was introduced.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- DOCS-03 and GATE-03 are ready to close with source-valid guidance and complete local/CI evidence.
- Phase 107's two plans are implemented; milestone verification can consume the explicit coverage metadata without a manual behavior check.

## Self-Check: PASSED

- Found all five plan-owned production/test/documentation files and this summary.
- Found task commits `bcb5ae7c`, `c96e9729`, `29df4eb8`, `6e2ae93d`, `a6827b1b`, and `0b13aafc` from measured base `c506a57dac2f6ab98ca4c0fd8b4325b3a483eb71`.
- All five plan-level verification commands exited successfully; no verification was skipped.
- Confirmed the release contract contains exactly one recursive removal call, inside the validated guard.
- Confirmed `.github/workflows/ci.yml` is unchanged and the six task commits contain no tracked deletions or files outside the five plan-owned paths.

---
*Phase: 107-operator-timeline-guidance-gate-parity*
*Completed: 2026-09-13*
