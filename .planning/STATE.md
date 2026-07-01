---
gsd_state_version: 1.0
milestone: v1.13
milestone_name: Storage Isolation and Upgrade Path
current_phase: 75
current_phase_name: Runtime Prefix Propagation
status: executing
stopped_at: Completed 75-05-PLAN.md
last_updated: "2026-07-01T19:46:23.684Z"
last_activity: 2026-07-01
last_activity_desc: Completed 75-05-PLAN.md
progress:
  total_phases: 4
  completed_phases: 2
  total_plans: 20
  completed_plans: 19
  percent: 95
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-06-30)

**Core value:** Every notification decision is explainable, so teams can reliably answer why a notification sent, failed, was deferred, or was suppressed.
**Current focus:** Phase 75 — Runtime Prefix Propagation

## Current Position

Phase: 75 (Runtime Prefix Propagation) — EXECUTING
Plan: 5 of 7
Status: Ready to execute
Last activity: 2026-07-01 — Completed 75-05-PLAN.md

## Accumulated Context

### Decisions

- [v1.6]: Adoption surface (v1.5) and adoption evidence (v1.6) are distinct milestones — journey CI is not optional polish
- [v1.6]: TeamPulse minimal B2B SaaS domain maps SEED-004 personas (Feature Developer, Support Operator, Product Manager)
- [v1.6]: `DemoHost.Seeds` is adopter-copyable public API — not internal test fixture inserts
- [v1.6]: Defer Playwright; host-mount ConnTest + LiveViewTest sufficient for JOUR-04 (INV-004)
- [v1.6]: `verify.journeys` separate CI job; not bundled into default `mix ci`
- [v1.7-assessment]: v1.6 satisfied adoption-evidence foundation — do not re-milestone Consumer Journey Proof
- [v1.7-assessment]: Staged seed choreography (`stage_escalation_webhook/1`) masks READ engine gap — fix in v1.7 READ + demo polish tail
- [48-01]: Omit `cancel_signals` from normalized wait_until output when absent or empty (D-06)
- [48-01]: Validate cancel_signals at notifier declaration time, not runtime in progression
- [48-02]: Do not mirror cancel_signals into status_context — pending_signals column is sole durable source
- [48-02]: route_signal/1 unchanged in Phase 48 — population only at enter_waiting/6
- [48-03]: Journey guide documents cancel_signals with canonical chimeway.notification.read/.seen; READ-02 deferral retained
- [48-03]: Doc contract forbids "Engine gap today" to prevent READ-01 gap regression
- [49-03]: READ-02 deferral removed from journey guide; inbox emission documented (D-09)
- [49-03]: Doc contract requires mark_read/mark_seen strings; forbids deferral phrases via @forbidden_phrases
- [49-01]: Inbox emits signals on first read/seen transition only; skip emission when tenant unresolved
- [49-01]: Lifecycle :ok independent of Signal.track/4 result — separate transactions per D-07
- [49-02]: E2E mark_read path uses public Chimeway.mark_read/3 — no host Signal.track glue (READ-02)
- [49-02]: signal_received transition context is event_name only — no payload/notification_id in trace (READ-03)
- [v1.8-assessment]: Adoption evidence prompt re-run confirms v1.6–v1.7 closed the demo/seeds/journey gap — do not re-milestone Consumer Journey Proof
- [v1.8-assessment]: Next wedge is v1.8 SEED-003 (ecosystem plugins), then v1.9 INBX — operator demo ≠ end-user bell UI
- [v1.8]: Mailglass-only v1.8 scope — Accrue/Threadline/Sigra deferred to v1.9+ (INV-003 resolved)
- [54-01]: Mailglass test config unconditional in config/test.exs — config loads before dep compile
- [54-01]: Shim Mailglass.TestRepo/DataCase in Chimeway test/support — not published on hex
- [54-02]: Recipient email precedence render_data to/email then user: actor_id prefix
- [54-02]: Hex mailglass needs test/support migration shim — priv wrappers not on hex artifact
- [54-02]: simulate_error supports :bounced/:suppressed for SuppressedError classifier tests
- [54-03]: ContractTest error shape passes simulate_error: true config when simulate_error?/0
- [54-03]: Permanent Mailglass errors tested via classify_error_for_test/1 on TemplateError
- [56-01]: Mailglass adapter registered only in :mailglass test setup — journey suite keeps Logger (D-10)
- [56-01]: adapter_module whitelisted in admin timeline redaction for operator inspectability
- [57-docs-release-gates]: Guide owns end-to-end Mailglass path; blueprint is focused recipe with reciprocal cross-links — D-02 separation prevents doc drift between introduction guide and blueprint recipe
- [57.1-01]: Section 6 webhook example mirrors DemoHostWeb.WebhooksController — adapter module first, conn.req_headers list, raw_body iolist flattening, generic 401/500 errors
- [v1.9]: Research skipped — reuse Mailglass vertical-slice pattern for Accrue; clone chimeway_admin for chimeway_inbox
- [v1.9]: Accrue-only SEED-003 slice; Threadline/Sigra deferred to v1.10
- [v1.9]: INBX via optional chimeway_inbox package (not core lib); recipient auth behaviour pluggable like ChimewayAdmin.Auth
- [60.1-01]: ci-gate aggregates 8 lanes; install_golden_contract stays outside needs
- [60.1-01]: Release Please manifest SSOT at 1.0.0; first automated bump targets 1.1.0
- [60.1-01]: Wave 1 manual merge of bootstrap Release PR; automerge deferred to 60.1-02
- [60.1-02]: Automerge requires ci-gate success + title `chore(main): release` + `autorelease: pending` label
- [60.1-02]: publish-hex recovery gates on ci-gate poll only — no lattice lint bypass (D-60.1-10)
- [60.1-02]: MAINTAINING Release Please default; recovery via publish-hex.yml dispatch only
- [58-01]: Accrue optional dep uses runtime: false — manual TestRepo bootstrap; avoid OTP app boot blocking default mix test
- [58-01]: Accrue test config unconditional in config/test.exs (Mailglass 54-01 precedent); dunning engine pinned in test_helper
- [58-01]: Runtime Code.compile_file for Accrue.Integrations.Chimeway — dep compile order elides integration module
- [58-02]: Keep orchestration/2 as {:ok, :immediate} — workflow runs via workflow/2 independently (OQ-2)
- [58-02]: CHIMEWAY_PATH override in Accrue mix.exs for cross-repo tests against cancel_signals spine
- [61-03]: Package LiveViewTests mount via test router `live/2` — `live_isolated` on_mount opts insufficient without live_session
- [61-03]: mark_seen not wired in BellDropdownLive v1.9 — LiveViewTest defers to API/host (D-08 discretion)
- [61-03]: verify.example includes chimeway_inbox; selective verify.inbox CI deferred Phase 62 GATE-05
- [62-01]: InboxAuth uses demo_user_email session key — distinct from demo:operator AdminActor (T-62-01)
- [62-01]: seed_inbox/0 standalone outside run/0; two idempotent InviteSent triggers for mark_read/seen targets
- [62-01]: DEMO-08 proof via @moduletag :inbox module — journey suite unchanged (D-06)
- [62-03]: verify.inbox = chimeway_inbox package + demo --only inbox; no ACCRUE_PATH sibling checkout (D-16/D-17)
- [62-03]: MAINTAINING pre-ship octet (eight verify gates); ci-gate aggregates nine lanes (D-18/D-19)
- [62-02]: Inbox guide uses public Chimeway.* delegates only — doc-contract forbids Chimeway.Inbox.* (D-14/T-62-05)
- [62-02]: No inbox blueprint recipe — guide owns end-to-end chimeway_inbox path (D-10)
- [63-01]: Threadline Test.Repo + migration shim in test/support (hex artifact gap — Mailglass 54-01/54-02 precedent)
- [63-01]: ActorRef.new/2 returns `{:ok, ref}` — fixtures unwrap before reporter config
- [63-01]: No verify.threadline alias in 63-01 — deferred Phase 66 GATE-07 (D-13)
- [63-02]: ThreadlineReporter fires :notification_dispatched on dispatch :stop without dedupe map (OQ-1)
- [63-02]: Action-only bridge audit rows proven via AuditAction query; timeline strict filter returns no capture changes
- [Phase ?]: Doc Contract Enforcement: added positive assertion and negative exclusions to enforce the valid shape of Chimeway.trigger/3 calls in guides to guarantee accurate copy-paste code snippets for adopters.
- [67-03]: Binding ECOS-09 proof is CI run 26925122158 / Sigra job 79433504716 with root 6 tests and demo 2 tests passing against szTheory/sigra@62ceb46a.
- [v1.11]: Operator console milestone includes SEED-004 and SEED-002; scope is embedded admin explainability, not generic CRUD or SaaS control plane.
- [v1.11]: UI polish ships with safety contracts because recovery is action-bearing; auth, tenancy, redaction, docs, and verification are milestone scope.
- [v1.11]: Keep `chimeway_admin` optional and host-mounted; core owns redacted DTO read models and recovery APIs.
- [v1.13]: New Chimeway installs default to a dedicated `chimeway` Postgres schema for Chimeway-owned tables.
- [v1.13]: Existing public-schema installs remain supported through explicit legacy mode and no silent migration.
- [v1.13]: Copied host migrations should generate explicit prefixes instead of requiring `mix ecto.migrate --prefix`.
- [v1.13]: Dynamic per-tenant database prefixes are out of scope for this storage-isolation milestone.
- [Phase 73-01]: Missing storage prefix config is invalid and represented as rejected value :missing — Runtime missing config must not silently default to either public or chimeway schema mode.
- [Phase 73-01]: Runtime storage prefix config accepts only "chimeway" and false — Dynamic prefixes and the string "public" are rejected to keep public-schema compatibility explicit via prefix: false.
- [Phase 73-01]: repo_opts/1 uses Keyword.put_new/3 to preserve explicit caller prefix probes — The helper centralizes static storage config without creating a public per-tenant database prefix API.
- [Phase 73-03]: Public docs show `prefix: "chimeway"` for new isolated Chimeway schema installs and `prefix: false` only for existing public-schema legacy installs.
- [Phase 73-03]: `prefix: false` keeps existing public/unprefixed Chimeway tables and does not move data; current public migration contract remains legacy compatibility proof.
- [Phase 73-02]: Application boot validates storage prefix config before constructing Repo or Oban child specs — invalid storage-prefix config now fails before supervised storage or job children are built.
- [Phase 73-02]: This repository's current public-schema runtime is explicit via prefix: false instead of missing config — missing prefix config remains invalid while existing public-schema behavior stays supported explicitly.
- [Phase 74-02]: Foundational migration templates carry the Plan 74-01 prefix sentinel and use local helper wrappers instead of migration-runner prefix flags. — Keeps generated host migrations reviewable and deterministic across prefixed and public modes.
- [Phase 74-02]: The first migration creates the selected Chimeway schema when prefixed, but rollback leaves schema cleanup manual by using a reversible no-op. — Follows Phase 74 D-12 by avoiding generated schema-drop SQL that could remove host-owned objects.
- [Phase 74-03]: ---

phase: 74-prefixed-migration-generator
plan: 03
subsystem: installer
tags: [elixir, ecto, migrations, postgres-prefix, raw-sql]

requires:

  - phase: 74-prefixed-migration-generator
    provides: 74-01 CLI/core generation-mode sentinel rendering

  - phase: 74-prefixed-migration-generator
    provides: 74-02 foundational local helper pattern
provides:

  - Prefix-helper based canonical templates for migrations 006-010
  - Fixed-helper raw SQL relation qualification for attempt-history backfill SQL
  - Public-mode helper branches that emit legacy unprefixed migration operations

affects:

  - phase-74-wave-2-template-helper-conversion
  - phase-74-dual-fixture-proof
  - phase-74-static-db-proof

tech-stack:
  added: []
  patterns:

    - Rendered `@chimeway_prefix __CHIMEWAY_PREFIX__` sentinel in canonical migration templates
    - Local migration helper wrappers for Chimeway-owned tables, indexes, unique indexes, and alters
    - Fixed accepted relation helper for raw SQL qualification

key-files:
  created:

    - .planning/phases/74-prefixed-migration-generator/74-03-SUMMARY.md
  modified:

    - priv/chimeway_migrations/006_add_correlation_id_to_chimeway_events.exs
    - priv/chimeway_migrations/007_create_chimeway_category_preferences.exs
    - priv/chimeway_migrations/008_create_chimeway_policy_settings.exs
    - priv/chimeway_migrations/009_add_attempt_history_columns.exs
    - priv/chimeway_migrations/010_add_delivery_orchestration_fields_to_chimeway_deliveries.exs

key-decisions:

  - "[74-03]: Early alter, category preference, policy setting, and delivery orchestration templates reuse the local helper/sentinel pattern from Plan 74-02."
  - "[74-03]: Attempt-history raw SQL is built through a fixed `chimeway_relation/1` helper that only accepts `:chimeway_delivery_attempts`."
  - "[74-03]: Public generation stays legacy-unprefixed by rendering `@chimeway_prefix false` and returning bare Ecto opts and relation names."

patterns-established:

  - "Alter templates use `chimeway_table/2` and index helpers instead of bare Chimeway table/index calls."
  - "Raw SQL templates use fixed relation helpers for known Chimeway-owned relations instead of broad string rewriting."

requirements-completed: [MIG-02, MIG-03]

duration: 3 min
completed: 2026-06-30
status: complete
---

# Phase 74 Plan 03: Early Helper and Attempt-History SQL Conversion Summary

**Migrations 006-010 now render schema-aware alters, preference tables, delivery orchestration indexes, and fixed-helper attempt-history SQL.**

- [Phase 75-03]: Admin and trace context helpers strip domain/query options, then delegate storage prefix handling to Chimeway.Storage.repo_opts/1. — Keeps D-04 local filtering while preserving D-02 explicit prefix probe precedence.
- [Phase 75-03]: Trace explanation helper queries reuse caller repo opts so explicit diagnostic prefix probes stay coherent across nested timeline lookups. — Prevents nested workflow and digest explanation reads from drifting away from the caller-selected diagnostic prefix.
- [Phase 75-03]: Inbox and recovery public APIs required no prefix arguments or additional manual repo opts; Repo.default_options/1 covered the tested paths. — Maintains D-03/D-21 configure-once runtime behavior and avoids exposing Ecto prefix terms to ordinary APIs.
- [Phase 75-04]: Direct Oban.Job duplicate-collapse queries use Oban-derived repo opts, keeping Oban job-table routing separate from Chimeway storage prefix routing.
- [Phase 75-04]: Prefixed runtime Oban testing helpers explicitly target the public Oban job table, matching current Oban config and D-13.
- [Phase 75-04]: Workflow, signal, ObanWorker, and DeferredResumeWorker paths required no manual prefix opts or job-arg changes; durable ID reloads are covered by Repo defaults.
- [Phase 75-05]: Digest and webhook production paths required no operation-level Storage.repo_opts/1 exceptions; Repo.default_options/1 covers the audited operations.
- [Phase 75-05]: The digest runtime proof must transition the fixture delivery to :digest_held before accumulation, matching the production digest contract.
- [Phase 75-05]: The webhook runtime proof must enter through Webhooks.process/4 and assert ProcessFeedbackWorker args remain ingress_id-only.

## Performance

- **Duration:** 3 min
- **Started:** 2026-07-01T00:02:14Z
- **Completed:** 2026-07-01T00:05:33Z
- **Tasks:** 1
- **Files modified:** 6

## Accomplishments

- Added the rendered `@chimeway_prefix __CHIMEWAY_PREFIX__` sentinel to migrations 006-010.
- Converted early alter, category preference, policy setting, attempt-history, and delivery orchestration operations to local helper wrappers.
- Qualified attempt-history raw SQL through a fixed `chimeway_relation/1` helper that only supports `:chimeway_delivery_attempts`.
- Preserved public generation semantics by returning bare Ecto opts and bare relation names when the sentinel renders to `false`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Convert early alter and attempt-history templates** - `6f92068` (feat)

## Files Created/Modified

- `priv/chimeway_migrations/006_add_correlation_id_to_chimeway_events.exs` - Adds prefixed event alter and correlation index helpers.
- `priv/chimeway_migrations/007_create_chimeway_category_preferences.exs` - Adds prefixed category preference table and unique index helpers.
- `priv/chimeway_migrations/008_create_chimeway_policy_settings.exs` - Adds prefixed policy setting table and unique index helpers.
- `priv/chimeway_migrations/009_add_attempt_history_columns.exs` - Adds prefixed attempt alter/index helpers and fixed-helper raw SQL relation qualification.
- `priv/chimeway_migrations/010_add_delivery_orchestration_fields_to_chimeway_deliveries.exs` - Adds prefixed delivery alter and orchestration index helpers.
- `.planning/phases/74-prefixed-migration-generator/74-03-SUMMARY.md` - Records execution evidence and plan metadata.

## Decisions Made

- Followed the Plan 74-02 per-template helper pattern instead of adding shared runtime/template abstractions.
- Kept raw SQL qualification intentionally narrow: `chimeway_relation/1` only accepts the known attempt-history table relation.
- Left golden fixture, static generated-output, and DB migration proof to later Phase 74 plans as specified by the validation map.

## Verification

- PASS: `mix format --check-formatted priv/chimeway_migrations/006_add_correlation_id_to_chimeway_events.exs priv/chimeway_migrations/007_create_chimeway_category_preferences.exs priv/chimeway_migrations/008_create_chimeway_policy_settings.exs priv/chimeway_migrations/009_add_attempt_history_columns.exs priv/chimeway_migrations/010_add_delivery_orchestration_fields_to_chimeway_deliveries.exs`
- PASS: `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/install/migrations_test.exs --warnings-as-errors` (16 tests, 0 failures)
- PASS: rendered-template spot check confirmed file 009 renders `@chimeway_prefix "chimeway"` for prefixed mode, `@chimeway_prefix false` for public mode, includes the fixed `chimeway_relation(:chimeway_delivery_attempts)` helper, emits the quoted prefixed SQL expression branch, and keeps the bare relation branch for public mode.

## TDD Gate Compliance

- The plan task was marked `tdd="true"`, but this sequential run was restricted to templates 006-010 plus summary/tracking artifacts.
- Existing focused installer tests were used as the behavioral gate; adding a RED test commit would have required editing files outside the allowed plan-owned set.
- GREEN implementation commit `6f92068` exists and passed the required verification commands.

## Deviations from Plan

None - implementation stayed within the plan-owned template files and preserved the specified migration semantics.

**Total deviations:** 0 auto-fixed.
**Impact on plan:** No scope change. The TDD RED gate limitation is documented separately above because it was caused by the allowed file boundary, not by an implementation change.

## Issues Encountered

The focused installer test command emitted known non-failing Threadline sandbox cleanup logs during subprocess-heavy tests. The suite completed green with 16 tests and 0 failures.

## Known Stubs

None. Stub-pattern scan found no placeholder/TODO/FIXME or runtime/UI stub content in plan-owned template files.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for 74-04. The next wave-2 template batch can continue applying the same helper pattern to files 011-015.

## Self-Check: PASSED

- Found plan-owned template files 006-010.
- Found summary file: `.planning/phases/74-prefixed-migration-generator/74-03-SUMMARY.md`.
- Found task commit: `6f92068`.
- Stub scan found no placeholder/TODO/FIXME or runtime/UI stub content in plan-owned template files.
- No tracked file deletions were introduced by the 74-03 task commit.

---
*Phase: 74-prefixed-migration-generator*
*Completed: 2026-06-30* — ---
phase: 74-prefixed-migration-generator
plan: 03
subsystem: installer
tags: [elixir, ecto, migrations, postgres-prefix, raw-sql]

requires:

  - phase: 74-prefixed-migration-generator
    provides: 74-01 CLI/core generation-mode sentinel rendering

  - phase: 74-prefixed-migration-generator
    provides: 74-02 foundational local helper pattern
provides:

  - Prefix-helper based canonical templates for migrations 006-010
  - Fixed-helper raw SQL relation qualification for attempt-history backfill SQL
  - Public-mode helper branches that emit legacy unprefixed migration operations

affects:

  - phase-74-wave-2-template-helper-conversion
  - phase-74-dual-fixture-proof
  - phase-74-static-db-proof

tech-stack:
  added: []
  patterns:

    - Rendered `@chimeway_prefix __CHIMEWAY_PREFIX__` sentinel in canonical migration templates
    - Local migration helper wrappers for Chimeway-owned tables, indexes, unique indexes, and alters
    - Fixed accepted relation helper for raw SQL qualification

key-files:
  created:

    - .planning/phases/74-prefixed-migration-generator/74-03-SUMMARY.md
  modified:

    - priv/chimeway_migrations/006_add_correlation_id_to_chimeway_events.exs
    - priv/chimeway_migrations/007_create_chimeway_category_preferences.exs
    - priv/chimeway_migrations/008_create_chimeway_policy_settings.exs
    - priv/chimeway_migrations/009_add_attempt_history_columns.exs
    - priv/chimeway_migrations/010_add_delivery_orchestration_fields_to_chimeway_deliveries.exs

key-decisions:

  - "[74-03]: Early alter, category preference, policy setting, and delivery orchestration templates reuse the local helper/sentinel pattern from Plan 74-02."
  - "[74-03]: Attempt-history raw SQL is built through a fixed `chimeway_relation/1` helper that only accepts `:chimeway_delivery_attempts`."
  - "[74-03]: Public generation stays legacy-unprefixed by rendering `@chimeway_prefix false` and returning bare Ecto opts and relation names."

patterns-established:

  - "Alter templates use `chimeway_table/2` and index helpers instead of bare Chimeway table/index calls."
  - "Raw SQL templates use fixed relation helpers for known Chimeway-owned relations instead of broad string rewriting."

requirements-completed: [MIG-02, MIG-03]

duration: 3 min
completed: 2026-06-30
status: complete
---

# Phase 74 Plan 03: Early Helper and Attempt-History SQL Conversion Summary

**Migrations 006-010 now render schema-aware alters, preference tables, delivery orchestration indexes, and fixed-helper attempt-history SQL.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-07-01T00:02:14Z
- **Completed:** 2026-07-01T00:05:33Z
- **Tasks:** 1
- **Files modified:** 6

## Accomplishments

- Added the rendered `@chimeway_prefix __CHIMEWAY_PREFIX__` sentinel to migrations 006-010.
- Converted early alter, category preference, policy setting, attempt-history, and delivery orchestration operations to local helper wrappers.
- Qualified attempt-history raw SQL through a fixed `chimeway_relation/1` helper that only supports `:chimeway_delivery_attempts`.
- Preserved public generation semantics by returning bare Ecto opts and bare relation names when the sentinel renders to `false`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Convert early alter and attempt-history templates** - `6f92068` (feat)

## Files Created/Modified

- `priv/chimeway_migrations/006_add_correlation_id_to_chimeway_events.exs` - Adds prefixed event alter and correlation index helpers.
- `priv/chimeway_migrations/007_create_chimeway_category_preferences.exs` - Adds prefixed category preference table and unique index helpers.
- `priv/chimeway_migrations/008_create_chimeway_policy_settings.exs` - Adds prefixed policy setting table and unique index helpers.
- `priv/chimeway_migrations/009_add_attempt_history_columns.exs` - Adds prefixed attempt alter/index helpers and fixed-helper raw SQL relation qualification.
- `priv/chimeway_migrations/010_add_delivery_orchestration_fields_to_chimeway_deliveries.exs` - Adds prefixed delivery alter and orchestration index helpers.
- `.planning/phases/74-prefixed-migration-generator/74-03-SUMMARY.md` - Records execution evidence and plan metadata.

## Decisions Made

- Followed the Plan 74-02 per-template helper pattern instead of adding shared runtime/template abstractions.
- Kept raw SQL qualification intentionally narrow: `chimeway_relation/1` only accepts the known attempt-history table relation.
- Left golden fixture, static generated-output, and DB migration proof to later Phase 74 plans as specified by the validation map.

## Verification

- PASS: `mix format --check-formatted priv/chimeway_migrations/006_add_correlation_id_to_chimeway_events.exs priv/chimeway_migrations/007_create_chimeway_category_preferences.exs priv/chimeway_migrations/008_create_chimeway_policy_settings.exs priv/chimeway_migrations/009_add_attempt_history_columns.exs priv/chimeway_migrations/010_add_delivery_orchestration_fields_to_chimeway_deliveries.exs`
- PASS: `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/install/migrations_test.exs --warnings-as-errors` (16 tests, 0 failures)
- PASS: rendered-template spot check confirmed file 009 renders `@chimeway_prefix "chimeway"` for prefixed mode, `@chimeway_prefix false` for public mode, includes the fixed `chimeway_relation(:chimeway_delivery_attempts)` helper, emits the quoted prefixed SQL expression branch, and keeps the bare relation branch for public mode.

## TDD Gate Compliance

- The plan task was marked `tdd="true"`, but this sequential run was restricted to templates 006-010 plus summary/tracking artifacts.
- Existing focused installer tests were used as the behavioral gate; adding a RED test commit would have required editing files outside the allowed plan-owned set.
- GREEN implementation commit `6f92068` exists and passed the required verification commands.

## Deviations from Plan

None - implementation stayed within the plan-owned template files and preserved the specified migration semantics.

**Total deviations:** 0 auto-fixed.
**Impact on plan:** No scope change. The TDD RED gate limitation is documented separately above because it was caused by the allowed file boundary, not by an implementation change.

## Issues Encountered

The focused installer test command emitted known non-failing Threadline sandbox cleanup logs during subprocess-heavy tests. The suite completed green with 16 tests and 0 failures.

## Known Stubs

None. Stub-pattern scan found no placeholder/TODO/FIXME or runtime/UI stub content in plan-owned template files.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for 74-04. The next wave-2 template batch can continue applying the same helper pattern to files 011-015.

## Self-Check: PASSED

- Found plan-owned template files 006-010.
- Found summary file: `.planning/phases/74-prefixed-migration-generator/74-03-SUMMARY.md`.
- Found task commit: `6f92068`.
- Stub scan found no placeholder/TODO/FIXME or runtime/UI stub content in plan-owned template files.
- No tracked file deletions were introduced by the 74-03 task commit.

---
*Phase: 74-prefixed-migration-generator*
*Completed: 2026-06-30*

- [75-02]: Chimeway.Repo.default_options(:transaction) stays [] while normal operations delegate to Chimeway.Storage.repo_opts/1.
- [75-02]: Trigger fanout required no public prefix opts or job-arg prefix propagation; Ecto repo defaults cover event, string-source notification insert_all, delivery planning, and attempts.
- [75-02]: Trigger duplicate idempotency accepts both chimeway_events_idempotency_key_index and PostgreSQL cloned-table chimeway_events_idempotency_key_idx constraint names.

### Pending Todos

None.

### Blockers/Concerns

None.

### Open Investigations

| ID | Question | When |
|----|----------|------|
| INV-003 | Mailglass-first vs full SEED-003 matrix in v1.8 scope | **Resolved** — Mailglass-only v1.8 |
| INV-004 | Playwright vs LiveView ConnTest for admin smoke | Defer until ConnTest flaky |

### Roadmap Evolution

- Phase 53 added: Milestone close-out — Nyquist validation + journey test hygiene (post-audit)
- v1.10 Ecosystem Completions started 2026-05-30 — Phases 63–66; 8/8 requirements (Threadline + Sigra SEED-003 remainder)
- v1.9 Adopter Complete shipped 2026-05-30 — Phases 58–62, 60.1, 62.1; 10/10 requirements (Accrue dunning + INBX inbox UI + Hex automation)
- v1.7 READ + Adoption Polish shipped 2026-05-29 (Phases 48–53, 11 requirements)
- v1.6 Consumer Journey Proof shipped 2026-05-29 (Phases 43–47)
- v1.5 formally closed 2026-05-29 (Phases 35–42)
- 57.1 inserted after 57: Close gap: DOCS-06/07 — fix Mailglass inbound webhook guide example (URGENT)
- Phase 62.1 inserted after Phase 62: Address v1.9 tech debt: Nyquist validation + REQUIREMENTS traceability (URGENT)
- Phase 67 added: Close ECOS-09: repin Sigra CI SHA, harden verify lanes against vacuous pass, fix guide, verify Phase 64 (from v1.10 milestone audit)

### Deferred Items

Items acknowledged and deferred at v1.9 milestone close on 2026-05-30:

| Category | Item | Status |
|----------|------|--------|
| seed | SEED-003-ecosystem-integrations (Threadline, Sigra remainder) | v1.10 |
| seed | SEED-004-personas-and-dx-roadmap (INBX-03 PubSub bell, optional polish) | v1.10+ |
| integration | Inbox-read signal may not project onto delivery timeline UI (INT-02) | optional polish |
| integration | `mark_seen` progression E2E not covered (INT-03) | optional polish |
| integration | mark_seen not wired in BellDropdownLive v1.9 — API proof only | v1.10+ |
| release | First automated Hex 1.1.0 publish pending push + bootstrap Release PR merge | operational |

<details>
<summary>v1.8 deferred items (superseded)</summary>

Items acknowledged and deferred at v1.7 milestone close on 2026-05-29:

| Category | Item | Status |
|----------|------|--------|
| seed | SEED-003 Mailglass slice | **shipped v1.8** |
| seed | SEED-003 remainder (Accrue, Threadline, Sigra) | v1.9+ |
| seed | SEED-004 inbox / bell UI remainder (INBX) | v1.9+ |
| planning | Phases 43–47 GSD artifacts (SUMMARY/VERIFICATION) | optional retroactive |
| integration | Inbox-read signal may not project onto delivery timeline UI (INT-02) | optional polish |
| integration | `mark_seen` progression E2E not covered (INT-03) | optional polish |

</details>

### Session Continuity

Last session: 2026-07-01T19:46:23.555Z
Stopped at: Completed 75-05-PLAN.md
Resume file: None

## Operator Next Steps

- Plan Phase 75.

## Performance Metrics

| Phase | Plan | Duration | Notes |
|-------|------|----------|-------|
| Phase 53 P01 | 12min | 4 tasks | 4 files |
| Phase 53 P02 | 8 min | 3 tasks | 3 files |
| 54-mailglass-adapter-core P01 | 15min | 3 tasks | 8 files |
| 54-mailglass-adapter-core P02 | 25min | 3 tasks | 8 files |
| 54-mailglass-adapter-core P03 | 12min | 3 tasks | 5 files |
| 55-inbound-feedback-bridge P02 | 8 | 2 tasks | 3 files |
| 55-inbound-feedback-bridge P03 | 12min | 2 tasks | 4 files |
| 56-blueprint-demo-proof P01 | 20min | 3 tasks | 8 files |
| 56-blueprint-demo-proof P02 | 12min | 2 tasks | 3 files |
| 57-docs-release-gates P01 | 8min | 2 tasks | 5 files |
| 57-docs-release-gates P03 | 12min | 3 tasks | 3 files |
| 57-docs-release-gates P02 | 6min | 1 tasks | 1 files |
| Phase 58-accrue-dunning-core P01 | 45min | 3 tasks | 9 files |
| Phase 60.1 hex-release-pipeline P01 | 15min | 4 tasks | 5 files |
| Phase 61 inbox-headless-package P03 | 20min | 3 tasks | 4 files |
| Phase 62 inbox-demo-docs-gate P01 | 18min | 3 tasks | 6 files |
| Phase 62 inbox-demo-docs-gate P02 | 8min | 3 tasks | 4 files |
| Phase 62 inbox-demo-docs-gate P03 | 3min | 3 tasks | 4 files |
| Phase 63 threadline-telemetry-bridge P01 | 25min | 5 tasks | 18 files |
| Phase 63 threadline-telemetry-bridge P02 | 18min | 3 tasks | 3 files |

| 67-01 close-ecos-09 P01 | 8min | 3 tasks | 6 files |
| Phase 67 P02 | 2m | 2 tasks | 3 files |
| Phase 67 P03 | 45m | 3 tasks | 11 files |
| Phase 68 P01 | 5 min | 2 tasks | 2 files |
| Phase 68 P02 | 4 min | 3 tasks | 5 files |
| Phase 70 P03 | 2 min | 2 tasks | 6 files |
| Phase 73 P01 | 5 min | 2 tasks | 4 files |
| Phase 73 P03 | 6 min | 2 tasks | 5 files |
| Phase 73 P02 | 10 min | 2 tasks | 3 files |
| Phase 74 P01 | 4 min | 1 tasks | 4 files |
| Phase 74 P02 | 6 min | 1 tasks | 6 files |
| Phase 74 P03 | 3 min | 1 tasks | 6 files |
| Phase 74 P06 | 3 min | 1 tasks | 6 files |
| Phase 74 P07 | 3 min | 1 tasks | 6 files |
| Phase 74 P08 | 15 min | 1 tasks | 2 files |
| Phase 74 P09 | 35 min | 2 tasks | 6 logical paths plus generated fixtures |
| Phase 74 P10 | 25 min | 1 tasks | 6 files |
| Phase 75 P02 | 5 min | 2 tasks | 3 files |
| Phase 75 P03 | 4 min | 2 tasks | 3 files |
| Phase 75 P04 | 5 min | 2 tasks | 3 files |
| Phase 75-runtime-prefix-propagation P05 | 6 min | 2 tasks | 1 files |
