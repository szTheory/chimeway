---
gsd_state_version: 1.0
milestone: v1.18
milestone_name: Adopter Alpha Mobile Delivery Readiness
current_phase: 101
current_phase_name: CrossWake Registration & Protected Open
status: planning
stopped_at: Completed 100-10-PLAN.md
last_updated: "2026-08-22T17:54:08.082Z"
last_activity: 2026-08-22
last_activity_desc: Phase 100 complete, transitioned to Phase 101
progress:
  total_phases: 7
  completed_phases: 4
  total_plans: 52
  completed_plans: 52
  percent: 57
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-12 after completing Phase 97)

**Core value:** Every notification decision is explainable, so teams can reliably answer why a notification sent, failed, was deferred, or was suppressed.
**Current focus:** Phase 100 — optional-apns-adapter

## Current Position

Phase: 101 — CrossWake Registration & Protected Open
Plan: Not started
Status: Ready to plan
Last activity: 2026-08-22 — Phase 100 complete, transitioned to Phase 101

## Deferred Items

Items acknowledged and deferred at v1.16 milestone close on 2026-07-30 (override_closeout — accepted-risk):

| Category | Item | Status |
|----------|------|--------|
| requirement | CACHE-05 (near-zero warm-run recompile + sub-3-min warm `ci-gate`) — cache correctness (CACHE-01..04) shipped & proven, but warm `ci-gate` regressed ~373s→~648s; deferred to compile-once spike (`CI-HARDENING-BACKLOG.md` #4) | owner-deferred 2026-07-29 (accepted-risk) |
| verification | Phase 88 (no 88-VERIFICATION.md) — completion proof in `88-03-SUMMARY.md` (CACHE-01..04 delivered, CACHE-05 deferred); downstream 90–92 verified-green | proof-in-summary (accepted) |
| verification | Phase 89 (no 89-VERIFICATION.md) — completion proof in `89-06-SUMMARY.md` (full CONC-04 proof: 3 green CI runs + `--seed 0`) | proof-in-summary (accepted) |

**v1.16 note:** 25/26 requirements delivered; CACHE-05 is the sole deferral. ROADMAP/REQUIREMENTS had shown Phases 88/89 as "Not started 0/TBD" despite completion — corrected at close. The headline sub-3-min wall-clock was **not** achieved (documented honestly in `88-03`/`89-06` summaries); the compile-once spike (backlog #4) is the top carried-forward item.

---

Items acknowledged and deferred at v1.15 milestone close on 2026-07-28 (override_closeout):

| Category | Item | Status |
|----------|------|--------|
| verification | Phase 84 (84-VERIFICATION.md) — optional in-browser visual/responsive confirmation; 8/8 must-haves structurally verified | human_needed (accepted) |
| verification | Phase 86 (86-VERIFICATION.md) — A11Y-03 focus-not-obscured + A11Y-04 CVD emulation manual checks owner-waived | human_needed (accepted-risk) |

**Note:** Phase 82 has no VERIFICATION.md (exploration/shortlist phase) but all its requirements are Complete in the archived REQUIREMENTS.md. The two A11Y items above remain the only Pending requirements (30/32 complete); they carry forward as accepted-risk for a future manual browser pass.

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
- [v1.11]: Keep `chimeway_admin` as optional and host-mounted; core owns redacted DTO read models and recovery APIs.
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
- [Phase 75-08]: Admin and recovery prefixed proof uses ordinary API arguments and relies on Repo.default_options/1 rather than passing prefix options.
- [Phase 75-08]: Signal and workflow worker proof uses durable ID args only: signal_id and workflow_run_id.
- [Phase 75-08]: RuntimePrefixWorkflow fixture includes email render fields so due wait progression can create the next-step email delivery.
- [Phase 75-08]: Worker runtime-prefix proof asserts exact queued args and performs from queued args for SignalRouterWorker and WorkflowProgressionWorker.
- [Phase 76.1]: [76.1-01]: Generated prefixed runtime proof runs fixture migrations in an isolated temporary database used by Chimeway.Repo.
- [Phase 76.1]: [76.1-01]: Runtime proof remains synchronous with Chimeway.Dispatch.Sync and does not add public prefix arguments or migration-runner prefix flags.
- [Phase 76.1]: [76.1-01]: GATE-01-GAP is covered by extending verify.runtime_prefix; installer golden remains path-gated and CI topology is unchanged.
- [Phase 77]: [77-01]: chimeway is the only Hex-published package for v1.14 planning work; sibling packages remain in-repo preview/path packages. — Prevents public package confusion and routes sibling install-status copy to Phase 78.
- [Phase 77]: [77-01]: Planning milestone labels such as v1.14 are planning identifiers only and are not package release refs. — Keeps root package SemVer tags, HexDocs source refs, publish refs, changelog anchors, and GitHub release names tied to actual package releases.
- [Phase 77]: [77-01]: Phase 78 owns package/release truth, Phase 79 owns front-door docs truth, and Phase 80 owns CI truth while full ci-gate remains the release confidence source. — Preserves Phase 77 as a planning artifact and hands public edits to downstream owner phases.
- [Phase 77]: [77-02]: Baseline drift rows assign package/release truth to Phase 78, front-door docs truth to Phase 79, and CI/DX truth to Phase 80. — Gives downstream phases an evidence-backed owner map before broad public edits.
- [Phase 77]: [77-02]: CONTRIBUTING.md canonical repo URL drift is Phase 80 contributor DX/gate documentation. — Phase 79 may reference public-doc implications only if later needed.
- [Phase 77]: [77-02]: Existing release_gate_contract_test.exs and doc_contract_test.exs remain the downstream truth anchors. — Avoids adding a parallel shell checker for package/docs/CI truth.
- [Phase 78]: [78-01]: Package/source truth is enforced by extending release_gate_contract_test.exs (no parallel shell checker) per D-07.
- [Phase 78]: [78-01]: Canonical package-facing repository/source URL is https://github.com/szTheory/chimeway; release-gate contracts reject the legacy jonlunsford URL.
- [Phase 78]: [78-01]: HEX_API_KEY scoping is contracted by asserting absence from the release-please job body, avoiding secret-value assertions (T-78-04).
- [Phase ?]: [78-02]: Sibling install-status truth enforced by extending doc_contract_test.exs (no parallel shell checker) per D-07.
- [Phase ?]: [78-02]: Guides omit any Hex install snippet for chimeway_admin/chimeway_inbox until a package-promotion milestone publishes them (D-05/D-06).
- [Phase ?]: [78-02]: Sibling mix.exs files are evidence-only; contracts assert app/version/path-dep and absence of package:/docs: metadata (D-05).
- [Phase ?]: [78-03]: Env-conditional Sigra override (dev/test only); Hex package builds run under MIX_ENV=prod so the build is Hex-legal.
- [Phase 79]: Docs truth locked as executable ExUnit string contracts with README<->packaged-README marker lockstep
- [Phase ?]: [80-01]: Two-aggregate CI topology — fast always-on pr-gate for PRs, push/dispatch-only ci-gate for release
- [Phase ?]: [80-01]: install_golden_contract is PR-exempt (D-04) yet folded into ci-gate needs (D-05); detect-step pattern kept for pending-safety (D-07)
- [Phase ?]: [80-01]: Heavy lanes use event guards, never paths filters, to avoid the required-check pending trap (CI-03)
- [Phase ?]: [80-02]: CI caches (npm/Playwright/nested/demo-host) keyed on lockfiles only; per-lane demo-host key slug prevents cross-lane optional-dep contamination
- [Phase ?]: [80-03]: Extracted the three complex inline ci.yml verification fragments into committed scripts/ci/*.sh invoked verbatim by the workflow (CI-04)
- [Phase ?]: [80-03]: Added checkout to pr-gate/ci-gate so the aggregate script is present in the runner (Rule 3 fix)
- [Phase ?]: [80-04]: D-08 realized as new GitHub ruleset (id 18486746) requiring pr-gate on main; main had no prior protection so it was a set-up, not a swap from ci-gate
- [Phase ?]: [80-04]: Gate docs (CONTRIBUTING/MAINTAINING) aligned with two-aggregate topology; Sigra ref corrected b186f03->62ceb46a; installer-gating reconciled to push+dispatch-only
- [Phase ?]: 81-03: tokens.json is a hand-synced DTCG mirror (no build tool, D-09); semantic hex-equal-to-primitive values are alias refs (D-10); light/dark are sibling groups, no system node (D-11)
- [Phase ?]: [84-01]: D-04 corrected — only two currentColor marks (mark-mono, logotype-mono) are inlined and D-05 parity-checked; the inverse lockup is fixed-color <img>, not inlined
- [Phase ?]: [84-01]: brandbook-guards.sh presence-gate keeps the Phase-84 gate RED until brandbook/index.html + brandbook.css both exist (proves wiring, not a defect)
- [Phase ?]: [84-01]: brandbook.css consumes --cw-* by name only — zero #hex literals, zero token redefinitions; scope-nonleak audit makes BOOK-02 non-vacuous
- [Phase ?]: [84-03]: Live WCAG contrast matrix uses painted-probe getComputedStyle to resolve tokens under the active data-theme; recomputes on theme flip + prefers-color-scheme change
- [Phase ?]: [84-03]: Every do/don't 'don't' is CSS-only misuse (.cwb-dont cage/brass-body/cramped) around the correct shipped asset/token — no broken SVG, zero hard-coded hex
- [Phase ?]: [84-04]: Voice/error/naming copy is verbatim from prompts/chimeway-brand-book.md; the sole exception is the 'install chimeway' CTA label, authoritative in UI-SPEC line 106 + 84-CONTEXT (not the prompt file)
- [Phase ?]: [84-04]: Theme-resolution fix lives in tokens.css — dark @media gated on :root:not([data-theme]) so an explicit data-theme outranks OS prefers-color-scheme (the 'light does nothing under a dark OS' bug); toggle script untouched
- [Phase ?]: [84-04]: Fixed-color lockups swap light/inverse <img> by theme (.cwb-logo--light/.cwb-logo--dark), not pinned color tiles; OG social preview reframed as a self-contained bordered .cwb-preview thumbnail (light-only by design)
- [Phase ?]: [84-04]: Checkpoint gap-closure touched brandbook.css / tokens.css / brandbook-guards.sh + two derived inverse assets beyond the plan's declared files_modified — in-scope (brandbook/ + guard-script), recorded as a deviation; guard families 5/6/7 added to lock the fixes
- [Phase ?]: [86-01]: offline contrast-audit.sh (dependency-free shell+awk) is the A11Y-05 evidence of record; in-page 8-cell matrix is corroborating proof only.
- [Phase ?]: [86-01]: sub-threshold pairings recorded as DOCUMENTED WCAG exemptions (disabled SC 1.4.3 Incidental; borders SC 1.4.11 required-to-identify), never patched (TOKEN-01).
- [Phase ?]: [86-03]: A11Y-04 CVD emulation + A11Y-03 focus-not-obscured manual checks WAIVED by owner 2026-07-28 (accepted risk); recorded as documented known gaps, NOT PASS; requirements left partially satisfied.
- [Phase ?]: [86-04]: Widened the existing brandbook-guards.sh --scope default allowlist (single source of truth) to the exact milestone boundary rather than adding a new mode; deny-by-default *) retained, no broad glob.
- [Phase ?]: [86-04]: NOTES-03 red-team recorded in notes/red-team.md closing with captured --scope audit + logo-guards --assets binary budget (3 rasters, 38,579B <= 204,800B PASS); boundary machine-enforced, not asserted.
- [Phase ?]: [86-04]: Red-team record honestly carries owner-waived A11Y-03/A11Y-04 manual attestation forward as an accepted-risk gap, NOT a pass.
- [v1.16]: Requirements categories map 1:1 to phases (OBS/CACHE/CONC/TIER/QUAL/REL -> Phases 87-92); dependency chain is 87 -> 88 -> {89, 90} -> 91 -> 92, with 91 leaning on 90's nightly tier for its 1.17 CI leg.
- [v1.16]: Milestone-wide invariant: doc/config/CI-only — no runtime library behavior changes across any of the six phases.
- [v1.16]: Phase 87 (observability) must land first as a low-risk enabler so every later cache/tiering win is provable by a run-link delta rather than asserted.
- [Phase ?]: [87-01]: obs-recompile.sh uses set -uo pipefail (no -e) with PIPESTATUS capture so a warm-cache grep miss never aborts the step, while the real mix compile exit code is preserved
- [Phase ?]: [87-01]: obs-summary.sh discovers caches generically via compgen -e + indirect ${!name} expansion (2 scripts total, not 3 — cache classification stays inlined)
- [Phase ?]: [87-01]: Added scoped .gitignore exception (!test/fixtures/ci/*.log) since the repo-wide *.log rule silently blocked committing the plan-required compile fixtures (Rule 3 auto-fix)
- [Phase ?]: [87-02]: verify_accrue's obs-recompile.sh step replaces (not supplements) the prior mix deps.compile step
- [Phase ?]: [87-02]: @build_lanes mirrors release_gate_contract_test.exs's @ci_gate_lanes exactly (14 lanes incl. lint)
- [Phase ?]: [87-03]: Baseline run permalink is the pre-Phase-87 main run at commit 8ce347e (actions/runs/30410779443), resolved via gh run list — never a placeholder
- [Phase ?]: [87-03]: Task 2's live-render confirmation run (30416472070, post-instrumentation) is deliberately NOT written into CI-PERF-BASELINE.md's Run: field — that field stays fixed at the pre-optimization reference point for the whole v1.16 milestone
- [Phase ?]: [90-01]: resolve_tiers is a bare setup job (no checkout) emitting run_nightly + otp_matrix JSON outputs; test's OTP matrix consumes it via fromJSON — PR runs OTP 27 only, push/schedule/dispatch run 26+27.
- [Phase ?]: [90-01]: concurrency group keyed on github.event_name with cancel-in-progress scoped to pull_request only, so a push can never cancel an in-flight nightly run (Pitfall 2 / T-90-04).
- [Phase ?]: [90-02]: verify_admin relocated to nightly tier (needs.resolve_tiers.outputs.run_nightly=='true'); ci-gate needs-list + @ci_gate_lanes reduced 14->13 in one atomic commit (Pitfall 1). Proven live: skipped on plain dispatch run 30510922206, success on run_nightly=true dispatch run 30511329087, ci-gate green in both.
- [Phase ?]: [90-03]: nightly_cold_build (no cache step, elixir 1.19/otp 27) + test_floor_1_17 (elixir 1.17/otp 27, test-floor- cache key) complete TIER-01's cold-build + 1.17-floor legs; nightly-gate aggregates nightly_cold_build/test/test_floor_1_17/verify_admin via aggregate-gate.sh (TIER-04), kept LAST in ci.yml, ci-gate untouched at 13 lanes.
- [Phase ?]: [90-03]: Proven live — run_nightly=true dispatch run 30512184143 GREEN (Resolve tier flags, Test OTP 26+27, Nightly cold build, Test 1.17 floor, Admin integration gate, nightly-gate, ci-gate all success, 0 cancelled/failure); PR-path run 30512220386 ran exactly ONE executed Test( leg (OTP 27), no OTP 26 (TIER-03).
- [Phase ?]: [90-03]: extract_ci_job_block boundary regex widened from [a-z_]+ to [a-z0-9_]+ in both contract-test files so digit-bearing job ids (test_floor_1_17) are recognized as block boundaries and don't over-capture (Rule 1 latent-bug fix).
- [Phase ?]: [91-01]: erlang pin is 27.3.4.15, not research's 27.3.4 — setup-beam strict lookup is an exact-key match against erlef's precompiled build tag (verified via source + builds.hex.pm + two live green main run logs)
- [Phase ?]: [91-01]: Task 1 tracer's live-CI checkpoint deferred per orchestrator override for this run; backstop recorded as pending in WINDOWS.md ledger
- [Phase ?]: [91-02]: mix_audit ~> 2.1 confirmed current (resolves 2.1.5); Dependabot cosmetics left at defaults per Claude's Discretion
- [Phase ?]: [91-02]: CI advisory-audit step (continue-on-error: true) verified read-only, untouched — D-12 advisory-only posture preserved
- [Phase ?]: [91-03]: run_floor mirrors ci-gate's own run condition (event != pull_request) so the 1.17 floor is never skipped when ci-gate evaluates TEST_FLOOR_1_17 — structural PR-skip-as-pass, not a softened aggregate-gate.sh (D-15)
- [Phase ?]: [91-03]: job-level permissions blocks always re-declare contents: read alongside actions: read since job-level permissions replaces (not merges with) the top-level default (D-08, Pitfall 3)
- [Phase ?]: [91-03]: updated release_gate_contract_test.exs's stale Phase-90 assertions (13->14 ci-gate lanes, floor if: run_nightly->run_floor) as a Rule-1 deviation — the plan's own change made those assertions wrong
- [Phase ?]: [92-01]: Helper body is the verbatim capture/restore pattern from test/support/accrue/data_case.ex:38-47, generalized to (app, key, value).
- [Phase ?]: [92-01]: Adoption scoped to policy_test.exs only — the sole async: true module with a bare Application.put_env/3 call; no async: false module flipped to async: true.
- [Phase ?]: [92-01]: Tracer feedback gate auto-verified via its deterministic mix test command and logged rather than paused as an interactive checkpoint, consistent with Phase 91-01 precedent.
- [Phase ?]: [92-02]: Classification is strictly the ci-gate JOB conclusion (not run-level) on event=push, branch=main runs; live measurement surfaced a run-level cancelled/job-level failure counting nuance (run 30502247481), documented in CI-RELIABILITY-REPORT.md.
- [Phase ?]: [92-03]: test_seed_zero mirrors test_floor_1_17 structurally (own postgres service, own cache namespace, no obs-summary, exempt from @build_lanes) and uses standard .tool-versions toolchain rather than a pinned floor
- [Phase ?]: [92-03]: Live-CI proof for REL-03 nightly dispatch and REL-02 phase-HEAD push run deferred this session (push out of scope for executor); documented via CI-HARDENING-BACKLOG.md quarantine, GitHub issue #4 comment, and WINDOWS.md ledger entries #4/#5 rather than silently gapped
- [Phase ?]: [92-03]: Reused existing open tracking issue #4 for the REL-02 quarantine link instead of creating a duplicate issue; demo_up_test.exs timeout tighten deferred to the same future push-verification pass
- [Phase ?]: ArtifactConsumer.Repo is the sole configured, migrated, supervised, and active repository for the generated Mailglass proof.
- [Phase ?]: Chimeway is loaded as an included application and its facade is dynamically bound only around the synchronous proof path.
- [Phase ?]: Phase 96-01: adoption proofs build one SHA-validated archive and dispatch Core, Mailglass, and Accrue serially.
- [Phase ?]: Phase 96-01: invalid adoption selectors fail before runner loading or proof output.
- [Phase ?]: The selector compares only Core, Mailglass, and Accrue in progressive-complexity order and routes detailed setup to the existing guides.
- [Phase 96]: The aggregate artifact proof runs once in a serial PostgreSQL 15 job on every workflow event and is required by both pr-gate and ci-gate through their needs and aggregate arguments.
- [Phase ?]: Adoption archive members are fully classified before materialization; only regular files and directories are written from memory.
- [Phase ?]: [96-04]: Adoption archive validation hashes and extracts one bounded immutable binary, with explicit outer/compressed/expanded/member budgets before materialization.
- [Phase ?]: [96.1-01]: Archive metadata is parsed in-memory with a bounded binary-only canonical Hex grammar; no source-term parser or input-derived atom conversion is permitted.
- [Phase ?]: [96.1-01]: Caller-supplied SHA-256 remains an immutable-byte integrity check, while callback execution remains gated after metadata, archive-root, and version validation.
- [Phase ?]: [97-01] Tenant identity is immutable on new events and notifications; legacy ownership remains NULL until reconciliation.
- [Phase ?]: [97-01] Trace entrypoints resolve one explicit or configured compatibility tenant before every lifecycle query.
- [Phase ?]: [97-02]: Inbox keyword options carry tenant_id and optional at; DateTime third arguments remain compatibility-only.
- [Phase ?]: [97-02]: Inbox lifecycle signals use the scoped notification tenant directly; Admin reads fail closed before querying.
- [Phase ?]: [97-04]: Reconciliation reports only IDs, NULL ownership, counts, status, schema version, and an explicit assignment instruction.
- [Phase ?]: [97-04]: Assignment locks the named Event and its Notifications, rejects any existing ownership, and writes only a validated host-supplied tenant ID.
- [Phase ?]: [97-04]: The Mix task accepts exactly report mode or explicit event-and-tenant assignment mode and emits one JSON object.
- [Phase ?]: [97-03]: Inbox events revalidate and retain the exact recipient/tenant pair assigned at mount.
- [Phase ?]: [97-03]: Admin host authorization runs before tenant validation; successful authorization without a concrete tenant still halts.
- [Phase ?]: [97-03]: Tenant identity remains an explicit core API option, never an Ecto or Oban prefix.
- [Phase ?]: [97-06]: Event changesets recognize canonical and PostgreSQL-shortened composite idempotency index names.
- [Phase ?]: [97-07] Recovery resolves tenant scope before discovery and retains it through atomic claims, reloads, and persisted replanning.
- [Phase ?]: [97-07] Wrong-tenant, absent, and unresolved recovery claims share the established noop outcome without row disclosure or dispatch.
- [Phase ?]: [97-05]: Admin LiveViews retrieve core query options only from the mounted validated context.
- [Phase ?]: [97-05]: Definitions tenant isolation is proven through /definitions so the production LiveAuth hook is exercised.
- [Phase ?]: [97-08]: Trace search and detail pass only Context.read_opts/2 output to core APIs; invalid context maps to the established empty/not-found states.
- [Phase ?]: [97-08]: Admin verification fixtures and demo trace proof provide an explicit tenant instead of relying on compatibility scope.
- [Phase ?]: [97-09]: Trigger trims only surrounding whitespace and overwrites downstream opts with the canonical tenant before persistence and dispatch.
- [Phase ?]: [97-10]: Migration 032 refuses rollback before DDL because valid cross-tenant duplicate idempotency keys cannot losslessly return to global uniqueness.
- [Phase ?]: [97-11] Runtime-prefix recovery evidence passes the fixture tenant explicitly to every recovery API and never uses tenant identity as a storage prefix.
- [Phase ?]: [97-12]: Optional delivery joins retain tenant filtering in ON clauses so foreign rows cannot contribute counts or summaries.
- [Phase ?]: [97-12]: Feed searches invoke LiveAuth.ensure_authorized/3 with only the normalized recipient identifier before database reads.
- [Phase ?]: [97-13]: Delivery tenant ownership is legacy-nullable; reconciliation locks the full lifecycle tree and updates only explicit host-owned NULL rows.
- [Phase ?]: [97-14]: Successful host identity mismatches redirect without rebinding mounted authority.
- [Phase ?]: [97-14]: Machine-testable Inbox acceptance is a required PR lane, not conversational UAT.
- [Phase ?]: [98-01]: Provider diagnostics persist only the provider_code, retry_after_ms, and accepted_at fact vocabulary.
- [Phase ?]: [98-01]: Opaque provider references must be caller-supplied cw_-prefixed bounded identifiers; raw provider IDs are not retained.
- [Phase ?]: [98-01]: Recursive comparison canonicalizes case and separators while retaining allowed original keys and list order.
- [Phase ?]: [98-02]: Trigger persists only validated host-supplied cw_ recipient and correlation references; raw recipient maps remain callback-only.
- [Phase ?]: [98-02]: Inbox resolves tenant scope then validates the opaque recipient reference for every read, transition, reload, and signal.
- [Phase ?]: [98-03]: Unknown adapter terms collapse to rejected/unknown_classification with empty attempt facts.
- [Phase ?]: [98-03]: Telemetry emits only validated lifecycle fields and reprojects merged stop metadata before emission.
- [Phase ?]: [98-03]: Failure logs are literal messages with selected safe identifiers only.
- [Phase ?]: [98-04]: Operator projections derive stable cw_* opaque references instead of exposing raw recipient or correlation identity.
- [Phase ?]: [98-04]: Adapter module names and provider-controlled detail are omitted from trace timelines and attempt summaries.
- [Phase ?]: [98-04]: Optional Admin rendering recursively redacts before applying its display allowlist.
- [Phase ?]: [98-05]: Proof acceptance is expressed as provider_handoff=accepted only; it never claims device display, open, seen, read, or engagement.
- [Phase ?]: [98-05]: Core proof uses provider_handoff=not_applicable, while Mailglass proof records only successful provider handoff.
- [Phase ?]: [98-07]: Approved evidence keys use field-specific grammars and ambiguous atom/string duplicates are omitted.
- [Phase ?]: [98-07]: Unsafe digest reasons are stored as nil; trace digest maps are rebuilt from closed fields.
- [Phase ?]: [98-08]: Trigger returns an explicit safe projection and keeps precomputed rendering plus recipient handoffs in a private dispatch context.
- [Phase ?]: [98-08]: Delivery rows retain render key/version only; full rendered maps are attached exclusively to immediate in-memory dispatch deliveries.
- [Phase ?]: [98-09]: Atom/string aliases and repeated tuple-list entries are ambiguous even when their values match.
- [Phase ?]: [98-09]: Provider codes use the same closed grammar as other categorical safe evidence.
- [Phase ?]: [98-10]: Oban hydrates allowed email deliveries from host-owned resolver context only after terminal and policy gates, passing private values solely in memory to the adapter.
- [Phase ?]: [98-11]: Hydration failure records the literal render_context_unavailable attempt before mapping through the existing Oban retry and exhaustion contract.
- [Phase ?]: [98-12]: recipient_reference/1 accepts only documented cw_ values and exact lowercase UUID user: compatibility values; it does not derive replacements.
- [Phase ?]: [98-12]: equal atom/string recipient aliases are ambiguous and rejected before Trigger opens its lifecycle transaction.
- [Phase ?]: [98-12]: Workflow routing uses explicit opaque actor references; raw signal identities never query waiting runs.
- [Phase ?]: [98-13]: Lifecycle fixture references use documented deterministic cw_lifecycle_user_<id> values, including all dependent queries and policy fixtures.
- [Phase ?]: [98-14]: Public trace APIs now return SafeEvidence-built nested maps; the event root retains tenant identity and recipient evidence is opaque.
- [Phase ?]: [98-15]: Only Date, Time, NaiveDateTime, and DateTime bypass recursive redaction; other structs are projected into ordinary maps.
- [Phase ?]: [98-15]: Trace evidence rebuilds attempts and timeline entries from fixed validated vocabularies, omitting malformed nested input.
- [Phase ?]: [99-01]: Delivery remains canonical; opaque binding revisions persist as tenant-scoped DeliveryTarget children.
- [Phase ?]: [99-01]: Target attempt_started evidence commits before provider adapter handoff, and provider acceptance claims no device receipt.
- [Phase ?]: [99-02]: Generated target identity and attempt-order constraints are proven in both static PostgreSQL storage modes.
- [Phase ?]: [99-02]: Runtime target planning routes through configured Repo storage and never accepts tenant-derived prefixes.
- [Phase ?]: [99-03]: Exact opaque binding-revision equality is the only target identity rule; normalized refs sort before durable planning.
- [Phase ?]: [99-03]: Parent success means one or more provider acceptances and retains terminal sibling failures as partial_failure evidence.
- [Phase ?]: [99-04]: Target-ID plus explicit tenant ID are the only target-worker job facts; durable target claims authorize provider I/O.
- [Phase ?]: [99-04]: Expired started target attempts close as ambiguous_handoff; only policy_authorized redrive creates duplicate-risk linked work.
- [Phase ?]: [99-05]: Recovery requires explicit tenant IDs, bounded durable-ID cursors, and closed result evidence.
- [Phase ?]: [99-05]: Lease expiry is not resend permission; expired attempt_started work is closed as ambiguous_handoff before any I/O.
- [Phase ?]: [99-06]: Only explicit pre-handoff adapter evidence returns a target to pending; all other callback outcomes close as possible handoff ambiguity.
- [Phase ?]: [99-06]: Target failure finalization locks the exact tenant-qualified claimed target and started attempt while persisting closed provider-code evidence only.
- [Phase ?]: [99-07]: Recovery summaries emit only closed counts, reason atoms, and independent typed continuations; no tenant or target material enters telemetry.
- [Phase ?]: [99-07]: Event, pending-target, and stale-attempt recovery scans use separate durable-ID cursors and validated batch bounds.
- [Phase ?]: [99-08]: Common trace loaders share tenant-qualified target history preloads, and explanations reuse SafeEvidence.trace_delivery/1.
- [Phase ?]: [99-09]: Sync snapshots ordered actionable target IDs and claims each through Executor.run_target/2.
- [Phase ?]: [99-09]: Sync continues after target errors and returns the recomputed canonical delivery aggregate.
- [Phase ?]: [99-10]: Parent status pending and orchestration_state ready are locked prerequisites for every target claim.
- [Phase ?]: [99-10]: Provider success may finalize only its exact tenant-qualified claimed target and attempt_started row; ambiguity wins permanently.
- [Phase ?]: [99-10]: Final pre-handoff target retries write retry_exhausted evidence before Oban completes, excluding ordinary recovery.
- [Phase ?]: [99-11]: Empty push snapshots return the recomputed authoritative parent, never the stale caller struct.
- [Phase ?]: [99-11]: Stale closeout uses the canonical tenant-qualified parent -> target -> attempt lock hierarchy.
- [Phase ?]: [99-12]: Ordinary retry authorizes only failed targets; expiry and invalidation authorize only pending targets under lock.
- [Phase ?]: [99-12]: Composite PostgreSQL foreign keys enforce tenant ownership and same-target prior-attempt lineage in repository and generated storage modes.
- [Phase ?]: [100-01]: APNs request intent is a nullable, immutable delivery-target variant; tokens and dispatcher references resolve only at the host-owned runtime boundary.
- [Phase ?]: [100-02]: Copied migration 037 uses a nullable intent map on existing delivery targets and removes only that column on rollback.
- [Phase ?]: [100-03]: APNs payloads are fixed APS alert plus opaque open-reference; generic push data never crosses to APNs.
- [Phase ?]: [100-03]: Pigeon remains host-selected and optional; absent Pigeon is a stable pre-handoff outcome.
- [Phase ?]: [100-04]: Typed adapter outcomes are the only retry authority; ambiguous handoff is durable and terminal.
- [Phase ?]: [100-04]: Provider invalidation requires complete 410/recognized-reason/timestamp facts and confirmed host exact CAS.
- [Phase ?]: [100-05]: APNs optionality is proven by fresh packaged consumers; Pigeon 2.0.1 remains an explicit host-only dependency.
- [Phase ?]: [100-06]: Pigeon raw 410 streams are converted only after queue correlation and a bounded complete response triple.
- [Phase ?]: [100-07] Absent APNs transport configuration must enter the optional Pigeon path; only non-nil atom overrides are adapter modules.
- [Phase ?]: [100-07] Pigeon-free package builds retain runtime-only dispatcher callbacks that close malformed provider streams safely.
- [Phase ?]: [100-08]: Disabled APNs consumer isolation permits only the root tzdata -> hackney baseline and rejects all APNs-introduced Pigeon, HTTPoison, or extra Hackney edges.
- [Phase ?]: [100-09]: APNS ambiguity begins only at Transport.push/2; lookup and payload-builder exceptions are bounded pre-handoff outcomes.
- [Phase ?]: [100-09]: Enabled package verification force-compiles unpacked Chimeway under warnings-as-errors before consumer compilation.
- [Phase ?]: [100-11]: Enabled APNs package proof prepares dependencies normally, then warning-strictly compiles only unpacked Chimeway source.
- [Phase ?]: [100-10]: Open references use one shared closed ASCII grammar at durable, reload, and direct payload boundaries; explicit collapse IDs use a separate APNs-header-safe allowlist.

### Roadmap Evolution

- v1.18 Adopter Alpha Mobile Delivery Readiness roadmap created 2026-08-11 — Phases 97–103 (7 phases, coarse granularity); 26/26 requirements mapped. Dependency chain: 97 → 98 → 99 → {100, 101} → 102 → 103. The host retains raw tokens, binding authority, identity, eligibility, expiry, and one-time open intents; CrossWake owns native acquisition, offline queue, manifest, and RouteGate; Chimeway owns logical delivery, opaque target revisions, attempts, recovery, and explanation. Phase 103 extends CrossWake Phase 162 and is externally blocked pending genuine Apple signing/provisioning evidence.
- Phase 96.1 inserted after Phase 96: Close gap: ARCHIVE-ATOM-01 — atom-safe archive metadata parsing (URGENT)

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
- [76-01]: Keep README, installation, and golden path beginner-safe; put manual public-to-chimeway move guidance in the dedicated storage prefix guide.
- [76-01]: mix chimeway.gen.migrations --prefix public is generator-only compatibility sugar; runtime public compatibility remains prefix: false.
- [76-01]: Oban job-table prefixing uses Oban-owned jobs examples and remains separate from Chimeway storage prefixing.
- [76-02]: Demo-host prefix proof prepares a `chimeway` schema by cloning Chimeway-owned public table shapes for test/demo setup, without copying data or relying on search_path.
- [76-02]: Example verification keeps Oban job-table queries on the public Oban prefix; Chimeway storage prefixing is not reused for `oban_jobs`.
- [76-03]: `verify_runtime_prefix` is a required ci-gate lane; installer golden remains path-gated and outside ci-gate.
- [76-03]: MAINTAINING has twelve local pre-ship commands while ci-gate has thirteen lanes because `mix ci` maps to lint plus test.

### Pending Todos

None.

### Blockers/Concerns

(87-03 Task 2 checkpoint:human-verify was approved 2026-07-29 — Phase 87 push 8ce347e..2d9af89, CI run 30416472070, all 16 jobs green, observability tables confirmed rendering. See 87-03-SUMMARY.md.)

- Phase 92 commits (14+) are not yet pushed to origin/main — before milestone close, push history and complete the two deferred live-CI proofs (REL-03 nightly dispatch, REL-02 phase-HEAD push run); see WINDOWS.md ledger entries #4/#5 and GitHub issue #4.

### Open Investigations

| ID | Question | When |
|----|----------|------|
| INV-003 | Mailglass-first vs full SEED-003 matrix in v1.8 scope | **Resolved** — Mailglass-only v1.8 |
| INV-004 | Playwright vs LiveView ConnTest for admin smoke | Defer until ConnTest flaky |

### Roadmap Evolution

- v1.16 CI/CD Performance & Reliability roadmap created 2026-07-29 — Phases 87-92 (6 phases, coarse granularity, continued numbering from Phase 86); 26/26 requirements mapped (OBS/CACHE/CONC/TIER/QUAL/REL). Doc/config/CI-only invariant (no runtime library behavior changes). Dependency chain: 87 -> 88 -> {89, 90} -> 91 -> 92; 91 leans on 90's nightly tier. Next: /gsd-plan-phase 87.
- v1.15 Brand Identity & Brand Book started 2026-07-09 — Phases 81-86 (6 phases, coarse granularity, continued numbering from Phase 80); 32/32 requirements mapped (LOGO/TOKEN/BOOK/VOICE/STATE/A11Y/INTEG/NOTES). Doc/asset-only. Consolidated the research's 8-phase steer to 6: voice + component states folded into the HTML brandbook (Phase 84); favicon/social derivatives folded into the selection checkpoint (Phase 83). Preserved invariants: tokens-first, logo-selection user-checkpoint before derivatives, HTML-book after inputs stable, accessibility verified at end.
- Phase 53 added: Milestone close-out — Nyquist validation + journey test hygiene (post-audit)
- v1.10 Ecosystem Completions started 2026-05-30 — Phases 63–66; 8/8 requirements (Threadline + Sigra SEED-003 remainder)
- v1.9 Adopter Complete shipped 2026-05-30 — Phases 58–62, 60.1, 62.1; 10/10 requirements (Accrue dunning + INBX inbox UI + Hex automation)
- v1.7 READ + Adoption Polish shipped 2026-05-29 (Phases 48–53, 11 requirements)
- v1.6 Consumer Journey Proof shipped 2026-05-29 (Phases 43–47)
- v1.5 formally closed 2026-05-29 (Phases 35–42)
- 57.1 inserted after 57: Close gap: DOCS-06/07 — fix Mailglass inbound webhook guide example (URGENT)
- Phase 62.1 inserted after Phase 62: Address v1.9 tech debt: Nyquist validation + REQUIREMENTS traceability (URGENT)
- Phase 67 added: Close ECOS-09: repin Sigra CI SHA, harden verify lanes against vacuous pass, fix guide, verify Phase 64 (from v1.10 milestone audit)
- Phase 76.1 inserted after Phase 76: Close gap: GATE-01 - generated prefixed migration runtime proof (URGENT)

### Deferred Items

Items acknowledged and deferred at v1.13 milestone close on 2026-07-02:

| Category | Item | Status |
|----------|------|--------|
| validation | Phase 74 validation metadata still shows planned rows despite passing verification | refresh with `/gsd:validate-phase 74` or manual metadata update |
| validation | Phase 76 validation metadata still shows planned/TBD rows despite passing verification | refresh with `/gsd:validate-phase 76` or manual metadata update |
| test-support | Broad runtime-prefix coverage still uses clone-based schema setup beyond generated-migration trigger-to-trace proof | extend generated runtime case when future schema-sensitive paths change |
| verification-noise | Threadline SQL Sandbox cleanup logs and optional dependency warnings remain non-failing gate noise | monitor during future release-gate work |

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

Last session: 2026-08-22T16:58:35.274Z
Stopped at: Completed 100-10-PLAN.md
Resume file: None

## Operator Next Steps

- Plan Phase 97 with /gsd-plan-phase 97

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
| Phase 75-runtime-prefix-propagation P07 | 5 min | 2 tasks | 2 files |
| Phase 75 P08 | 14 min | 2 tasks | 2 files |
| Phase 76 P01 | 35 min | 3 tasks | 7 files |
| Phase 76 P02 | 16 min | 3 tasks | 20 files |
| Phase 76 P03 | 20 min | 3 tasks | 4 files |
| Phase 76.1 P01 | 7 min | 3 tasks | 4 files |
| Phase 77 P01 | 4 min | 2 tasks | 2 files |
| Phase 77 P02 | 9 min | 2 tasks | 2 files |
| Phase 78 P01 | 4 min | 2 tasks | 3 files |
| Phase 78 P02 | 5 min | 2 tasks tasks | 3 files files |
| Phase 78 P03 | 30 min | 2 tasks | 4 files |
| Phase 79 P01 | 12min | 3 tasks | 5 files |
| Phase 80 P01 | 4 min | 3 tasks | 2 files |
| Phase 80 P02 | 6 min | 3 tasks | 2 files |
| Phase 80 P03 | 5 min | 3 tasks | 5 files |
| Phase 80 P04 | 12 min | 3 tasks | 2 files |
| Phase 81 P01 | 2 min | 2 tasks | 1 files |
| Phase 81 P02 | 6min | 1 tasks | 1 files |
| Phase 81 P03 | ~10m | 2 tasks | 1 files |
| Phase 84 P01 | 12min | 2 tasks | 2 files |
| Phase 84 P02 | 5min | 3 tasks | 1 files |
| Phase 84 P03 | 8min | 3 tasks | 1 files |
| Phase 84 P04 | 53min | 3 tasks | 4 files + 2 assets |
**Per-Plan Metrics:**

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 86 P01 | 6min | 2 tasks | 2 files |
| Phase 86 P02 | 10m | 2 tasks | 1 files |
| Phase 86 P03 | 4min | 1 tasks | 1 files |
| Phase 86 P04 | 8min | 2 tasks | 2 files |
| Phase 87 P01 | 12min | 2 tasks | 8 files |
| Phase 87 P02 | 9min | 3 tasks | 2 files |
| Phase 87 P03 | 6min | 2 tasks | 2 files |
| Phase 90 P01 | 18 min | 2 tasks | 2 files |
| Phase 90 P02 | 22 min | 2 tasks | 2 files |
| Phase 90 P03 | 30 min | 3 tasks | 3 files |
| Phase 91 P01 | 3 min | 2 tasks | 2 files |
| Phase 91 P02 | 8min | 2 tasks | 3 files |
| Phase 91 P03 | ~10 min | 2 tasks | 2 files |
| Phase 92 P01 | 12 min | 2 tasks | 4 files |
| Phase 92 P02 | 15 min | 2 tasks | 4 files |
| Phase 92 P03 | 15 min | 3 tasks | 4 files |
| Phase 94-mailglass-transactional-email-proof P03 | 6 min | 2 tasks | 4 files |
| Phase 96-adoption-front-door-proof-gate P01 | 46m | 2 tasks | 7 files |
| Phase 96 P02 | 20m | 2 tasks | 6 files |
| Phase 96 P03 | ~45 minutes | 2 tasks | 2 files |
| Phase 96-adoption-front-door-proof-gate P04 | 18 min | 2 tasks | 2 files |
| Phase 96-adoption-front-door-proof-gate P05 | 25m | 2 tasks | 3 files |
| Phase 96.1-close-gap-archive-atom-01-atom-safe-archive-metadata-parsing P01 | 8 min | 3 tasks | 2 files |
| Phase 97-tenant-identity-compatible-upgrade P01 | 24 min | 2 tasks | 11 files |
| Phase 97 P02 | 3 min | 2 tasks | 7 files |
| Phase 97-tenant-identity-compatible-upgrade P04 | 12 min | 2 tasks | 4 files |
| Phase 97-tenant-identity-compatible-upgrade P03 | 22 min | 2 tasks | 13 files |
| Phase 97-tenant-identity-compatible-upgrade P06 | 15 min | 2 tasks | 12 files |
| Phase 97-tenant-identity-compatible-upgrade P07 | 5 min | 1 tasks | 4 files |
| Phase 97-tenant-identity-compatible-upgrade P05 | 2 min | 1 tasks | 5 files |
| Phase 97-tenant-identity-compatible-upgrade P08 | 10 min | 1 tasks | 8 files |
| Phase 97 P09 | 4 min | 1 tasks | 2 files |
| Phase 97-tenant-identity-compatible-upgrade P10 | 2 min | 1 tasks | 5 files |
| Phase 97 P11 | 8 min | 1 tasks | 1 files |
| Phase 97-tenant-identity-compatible-upgrade P12 | 15 min | 3 tasks | 4 files |
| Phase 97-tenant-identity-compatible-upgrade P13 | 18 min | 2 tasks | 14 files |
| Phase 97-tenant-identity-compatible-upgrade P14 | 16 min | 2 tasks | 5 files |
| Phase 98 P01 | 8 min | 2 tasks | 6 files |
| Phase 98-privacy-safe-delivery-evidence P02 | 12 min | 2 tasks | 9 files |
| Phase 98 P03 | 18min | 2 tasks | 7 files |
| Phase 98 P04 | 30 min | 2 tasks | 7 files |
| Phase 98 P05 | 16 min | 1 tasks | 2 files |
| Phase 98-privacy-safe-delivery-evidence P07 | 14 min | 1 tasks | 5 files |
| Phase 98-privacy-safe-delivery-evidence P08 | 8 min | 2 tasks | 7 files |
| Phase 98 P09 | 3 min | 1 tasks | 3 files |
| Phase 98-privacy-safe-delivery-evidence P10 | ~55 min | 2 tasks | 6 files |
| Phase 98-privacy-safe-delivery-evidence P11 | 10min | 1 tasks | 4 files |
| Phase 98-privacy-safe-delivery-evidence P12 | 12min | 2 tasks | 6 files |
| Phase 98-privacy-safe-delivery-evidence P13 | 6min | 1 tasks | 1 files |
| Phase 98-privacy-safe-delivery-evidence P14 | 8 min | 3 tasks | 8 files |
| Phase 98-privacy-safe-delivery-evidence P15 | 18 min | 2 tasks | 4 files |
| Phase 99-multi-installation-delivery-recovery P01 | 9 min | 2 tasks | 13 files |
| Phase 99-multi-installation-delivery-recovery P02 | 15 min | 2 tasks | 5 files |
| Phase 99-multi-installation-delivery-recovery P03 | 14m | 2 tasks | 9 files |
| Phase 99-multi-installation-delivery-recovery P04 | 8 min | 2 tasks | 5 files |
| Phase 99-multi-installation-delivery-recovery P05 | 29m | 1 tasks | 10 files |
| Phase 99 P06 | 8 min | 1 tasks | 4 files |
| Phase 99 P07 | 24m | 2 tasks | 5 files |
| Phase 99-multi-installation-delivery-recovery P08 | 12m | 1 tasks | 4 files |
| Phase 99 P09 | 3m | 1 tasks | 2 files |
| Phase 99-multi-installation-delivery-recovery P10 | 4m | 2 tasks | 4 files |
| Phase 99-multi-installation-delivery-recovery P11 | 18 min | 2 tasks | 4 files |
| Phase 99-multi-installation-delivery-recovery P12 | 14min | 3 tasks | 12 files |
| Phase 100-optional-apns-adapter P01 | 8 min | 1 tasks | 8 files |
| Phase 100-optional-apns-adapter P02 | 18 min | 2 tasks | 12 files |
| Phase 100-optional-apns-adapter P03 | 18 min | 2 tasks | 9 files |
| Phase 100-optional-apns-adapter P04 | 12 min | 2 tasks | 10 files |
| Phase 100-optional-apns-adapter P05 | 18 min | 2 tasks | 9 files |
| Phase 100-optional-apns-adapter P06 | 18 min | 2 tasks | 5 files |
| Phase 100 P07 | 24 min | 1 tasks | 7 files |
| Phase 100 P08 | 30 min | 2 tasks | 6 files |
| Phase 100-optional-apns-adapter P09 | 18 min | 2 tasks | 5 files |
| Phase 100 P11 | 14 min | 1 tasks | 2 files |
| Phase 100-optional-apns-adapter P10 | 7 min | 1 tasks | 5 files |
