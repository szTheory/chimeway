# Milestones

## v1.15 Brand Identity & Brand Book (Shipped: 2026-07-28)

**Phases completed:** 6 phases, 16 plans, 29 tasks

**Key accomplishments:**

- notes/decision-log.md divergence ledger recording DIV-1..DIV-7 sub-primitive divergences between the shipped chimeway_admin.css token layer and brand-book intent, each DOCUMENTED/DEFERRED with both-side line refs and a git-diff zero-drift invariant over both admin CSS files (TOKEN-04)
- Task 1 — Primitive + non-color scalar groups
- Extended logo-guards.sh with an `--assets` file-level gate and widened `--scope` allowlist, plus a pinned SVGO config and a Chrome-headless SVG→PNG render helper — the tooling Waves 2-3 need to produce and verify the brand-asset family.
- Six-mark chimeway logo lockup family shipped as SVGO-optimized SVGs, with the wordmark re-cut from Marcellus (SIL OFL 1.1) via fontTools and a two-tone keystone-i (ink body + teal facet at 65% width).
- Dual-theme favicon set (prefers-color-scheme dark) + 1200x630 mark-derived OG card, with the Keystone/Marcellus(OFL-1.1) direction formally ratified by a human at the blocking perceptual checkpoint — closing LOGO-03/04 and INTEG-03.
- A single file://-safe `brandbook/index.html` — relative-linked to the tokens SSOT and the scoped stylesheet — that stands up the `.cw-brandbook` scaffold, a tri-state theme toggle in one inline classic script, and the token-driven logo, color, typography, and spacing sections with zero hard-coded hex.
- 1. [Rule 3 - Blocking issue] Escaped `<script>` prose in a plan-02 comment so the plan's acceptance grep is honest
- Completes `brandbook/index.html` with the brand-voice content — voice/tone by context (docs/errors/marketing/CLI) with verbatim good/bad pairs, the named "what happened → why it matters → how to fix" error-message template, and the lowercase-`chimeway`-graphic vs title-case-`Chimeway`-prose naming/CTA rules — then closes the phase: the full seven-family guard suite is green, the book is `file://`-safe, and the render is human-verified on both light and dark after a checkpoint gap-closure that fixed theme resolution, nav/visual polish, and theme-adaptive logo rendering.
- Wired the shipped Chimeway brand assets into the two adopter-facing surfaces — a GitHub-native theme-swapping `<picture>` lockup in the README header and `:logo`/`:favicon` in ExDoc `docs()` — keeping all v1.14 contracts green via a deliberate narrative-order-gate evolution.
- The two genuinely-manual browser accessibility checks (A11Y-04 CVD emulation and A11Y-03 focus-not-obscured) were WAIVED by the project owner on 2026-07-28 — risk accepted, manual verification not performed — and recorded truthfully in `notes/accessibility-checks.md` §6.1/§6.2 as documented known gaps (accepted-risk, NOT a PASS), corroborated by pre-existing machine/CSS evidence that mitigates but does not substitute for the human attestation.
- Widened the existing `scripts/brandbook-guards.sh --scope` allowlist to the exact v1.15 milestone boundary (`brandbook/

---

## v1.14 Public Truth and Verification Architecture (Shipped: 2026-07-03)

**Delivered:** Every public adoption claim — package/release metadata, README/front-door docs, and CI/release verification — now agrees and is reproducible under executable contracts, while full release confidence is preserved.

**Phases completed:** 77-80 (4 phases, 10 plans, 25 tasks)

**Requirements:** 14/14 satisfied (TRUTH-01/02/03/04, DOCS-14/15/16/17, ADPT-01, CI-01/02/03/04/05)

**Closeout:** verified_closeout — all four phases verified passed; open-artifact audit clear. No milestone audit run (docs/CI/package-truth milestone, low cross-phase runtime coupling).

**Git tag:** v1.14

**Timeline:** 2026-07-02 → 2026-07-03

**Key accomplishments:**

- Recorded the root-only Hex package model and separated planning-milestone labels (`v1.14`) from package release SemVer, with a package/docs/CI truth owner map and evidence-backed drift baseline (Phase 77, TRUTH-04).
- Aligned root package metadata, release manifest, changelog, HexDocs source refs, README install constraint, canonical repository/source links, and sibling preview/path install-status copy, enforced by ExUnit release-gate + doc contracts (Phase 78, TRUTH-01/02/03).
- Proved a deterministic local Hex unpack of the root package; an env-scoped Sigra override keeps dev/test resolution while the `MIX_ENV=prod` package build stays Hex-legal (`mix verify.parity`).
- Rewrote the README as an additive-superset public decision page — local-first value prop, four decision sections, and a public-API trigger-to-explainability snippet chain — stub guides delinked, locked by byte-identical source-tree and packaged (unpacked-Hex) README contracts (Phase 79, DOCS-14/15/16/17, ADPT-01).
- Split CI into a fast always-on `pr-gate` for PRs plus a push/dispatch-only 14-lane `ci-gate` (incl. `install_golden_contract`) for release, with anti-pending event guards proven on a live PR (#3: pr-gate terminal, 11 heavy lanes SKIPPED, nothing stranded) (Phase 80, CI-01/02/03).
- Added npm/Playwright/nested-package/per-lane-demo caches keyed on lockfiles, extracted complex CI logic to `scripts/ci/*.sh`, aligned CONTRIBUTING/MAINTAINING gate docs, and set up the D-08 `pr-gate` branch-protection ruleset (id 18486746) (Phase 80, CI-04/05).

**Known fast-follow (out of scope):** `main` fails `mix ci.lint` from ~18 pre-existing unformatted files + vulnerable-dep audit flags (none touched by Phase 80). Because `pr-gate` now includes `Lint` as a required PR check, this drift blocks PR merges until a `mix format` + dependency-bump fast-follow lands.

---

## v1.13 Storage Isolation and Upgrade Path (Shipped: 2026-07-02)

**Delivered:** Chimeway-owned storage can now default to a dedicated `chimeway` Postgres schema, while existing public-schema installs remain explicitly supported.

**Phases completed:** 73-76.1 (5 phases, 25 plans, 46 tasks)

**Requirements:** 20/20 satisfied

**Audit:** [milestones/v1.13-MILESTONE-AUDIT.md](milestones/v1.13-MILESTONE-AUDIT.md) (`tech_debt` — no blockers)

**Git tag:** v1.13

**Key accomplishments:**

- Validated static storage-prefix config with early boot failure for unsupported values and one internal repo-options helper.
- Converted generated host migrations to schema-aware output by default, including deterministic prefixed/public fixtures, idempotency proof, static generated-output proof, and DB migration/rollback contracts.
- Threaded runtime prefix behavior through trigger fanout, idempotency, traces, inbox, admin, recovery, workflow, signals, digests, policies/preferences, webhooks, dispatch workers, and public legacy mode.
- Added a named `mix verify.runtime_prefix` gate and required CI lane for configured-storage and public legacy compatibility.
- Documented the default `chimeway` schema, explicit public legacy mode, manual move/rollback guidance, Oban-prefix separation, and demo-host trigger-to-trace proof.
- Closed GATE-01 with generated prefixed fixture migrations creating the schema used by a runtime trigger-to-trace proof.

**Known tech debt at close:**

- Phase 74 and Phase 76 validation artifacts still need metadata refresh from planned rows to completed evidence rows.
- Broad runtime-prefix harness coverage still uses clone-based schema setup beyond the generated-migration trigger-to-trace proof.
- See the milestone audit for non-failing verification noise and follow-up details.

---

## v1.11 Operator Console Polish & Hardening (Shipped: 2026-06-04)

**Phases completed:** 5 phases, 12 plans, 21 tasks

**Key accomplishments:**

- Demo-host admin copy now describes the shipped seven-page embedded operator console, backed by a root doc contract.
- Route, isolated LiveView, and demo-host mounted tests now lock the shipped admin route map and operator hierarchy.
- Shared admin context with tenant-scoped read DTOs and enriched host authorization context
- Recovery LiveView now requires deliberate confirmation, re-authorizes recovery submits, and renders scoped stale/noop UI
- Core recovery now persists allowlisted operator evidence, preserves duplicate noop evidence, and projects safe trace facts only
- Admin DTO and rendered LiveView privacy contracts now prove sensitive payload/render/provider/session values stay out of operator surfaces while masked facts remain useful.
- Admin lifecycle copy now distinguishes provider acceptance from delivered feedback, and Definitions copy is locked to persisted DB-inferred history.
- Canonical admin console integration guide with HexDocs registration and DOCS-12 contract coverage
- Playwright Chromium smoke proves the mounted admin console is nonblank, styled, navigable, form-usable, responsive, and redacted
- `mix verify.admin` is now the local and CI gate for the mounted admin console

---

## v1.10 Ecosystem Completions

- Status: shipped
- Date: 2026-06-04
- Phases: 63-67 (5 phases, 13 plans)
- Requirements: 8/8 satisfied
- Git tag: v1.10
- Git range: v1.9..v1.10 (107 commits, 245 files, +15,594 / -6,826 LOC)
- Audit: [milestones/v1.10-MILESTONE-AUDIT.md](milestones/v1.10-MILESTONE-AUDIT.md) (passed after Phase 67 closure)
- Key accomplishments:

- Threadline telemetry reporter bridges Chimeway lifecycle outcomes into Threadline `audit_actions` with redacted metadata and correlation IDs (ECOS-08)
- Sigra auth notification flows dispatch Chimeway notifiers for magic-link/auth events with sensitive-token redaction at the trace boundary (ECOS-09)
- Sigra auth reference blueprint plus demo host proofs cover Threadline audit correlation and Sigra auth notification trace inspectability (ECOS-10, DEMO-09/10)
- Threadline and Sigra golden-path guides are locked by doc-contract tests and published in HexDocs extras (DOCS-10/11)
- `mix verify.threadline` and `mix verify.sigra` are wired into CI, release-gate contracts, and the MAINTAINING pre-ship checklist (GATE-07)
- Phase 67 closed the ECOS-09 audit gap: Sigra CI repinned to `62ceb46a38c4e617f6c06d874ecb12e1ab19d97c`, vacuous-pass guards added, guide API shape fixed, and clean-CI proof captured in run `26925122158` / job `79433504716`

- Notes: SEED-003 ecosystem matrix is complete across v1.8-v1.10. Optional polish remains in SEED-004: INT-02/03, INBX-03, ADPT-01.

---

## v1.9 Adopter Complete

- Status: shipped
- Date: 2026-05-30
- Phases: 58–62, 60.1, 62.1 (7 phases, 19 plans)
- Requirements: 10/10 satisfied
- Git tag: v1.9
- Git range: v1.8..v1.9 (105 commits, 124 files, +13,279 / −188 LOC)
- Audit: [milestones/v1.9-MILESTONE-AUDIT.md](milestones/v1.9-MILESTONE-AUDIT.md) (passed)
- Known deferred items at close: 2 dormant seeds — SEED-003/004 remainder → v1.10 (see STATE.md Deferred Items)
- Key accomplishments:

- Accrue `invoice.payment_failed` → multi-step dunning workflow with `invoice.paid` Outcome Signal termination — no host glue (ECOS-06)
- Accrue dunning blueprint recipe with doc-contract truth lock and demo host proof at `/admin/chimeway` (ECOS-07, DEMO-07)
- Golden-path Accrue integration guide, doc-contract tests, and `mix verify.accrue` CI gate + MAINTAINING septet (DOCS-08/09, GATE-05 Accrue)
- Release Please + 9-lane ci-gate + automated Hex publish path gated on ci-gate green (GATE-06)
- Headless inbox API: `unread_count/1`, keyset-paginated `list_for_recipient/2`, stable DTO maps (INBX-01)
- Optional `chimeway_inbox` package: recipient auth behaviour, router macro, unstyled bell-dropdown LiveView (INBX-02)
- Demo host `/inbox` mount with `seed_inbox/0` and selective `:inbox` journey proof (DEMO-08)
- Inbox integration guide, doc-contract tests, and `mix verify.inbox` + MAINTAINING octet (DOCS-08/09 Inbox, GATE-05 Inbox)
- Phase 62.1 closed Nyquist validation + REQUIREMENTS traceability drift from pre-close audit

- Notes: Accrue-only SEED-003 slice + INBX SEED-004 slice; Threadline/Sigra deferred to v1.10; first automated Hex 1.1.0 publish pending push + bootstrap Release PR merge

---

## v1.8 Ecosystem Integration Blueprints

- Status: shipped
- Date: 2026-05-30
- Phases: 54–57, 57.1 (5 phases, 13 plans, 29 tasks)
- Requirements: 9/9 satisfied
- Git tag: v1.8
- Git range: v1.7..v1.8 (77 commits, 263 files, +10,244 / −84 LOC)
- Audit: [milestones/v1.8-MILESTONE-AUDIT.md](milestones/v1.8-MILESTONE-AUDIT.md) (tech_debt — no blockers)
- Known deferred items at close: 2 dormant seeds + Nyquist metadata lag (see STATE.md Deferred Items)
- Key accomplishments:

- Optional mailglass ~> 1.3 packaging with conditional adapter stub and Fake/TestRepo test infrastructure for downstream deliver/2 work
- Full Mailglass.Outbound deliver/2 with mailable resolution, tenancy stamp, error classification, and redacted success meta
- ECOS-02 proof: Mailglass adapter passes shared ContractTest with simulate_error, classification matrix for all three error classes, and executor email routing to Chimeway.Adapters.Mailglass
- Outbound attempt rows now store provider_message_id for webhook correlation, and the webhook ingest boundary supports optional adapter-native body parsing with raw_body/headers config threading
- Mailglass adapter webhook callbacks delegate Postmark verify/normalize to Mailglass.Webhook.Provider and map Anymail delivery events into Chimeway's :delivered/:bounced/:failed feedback vocabulary
- Webhook contract macros gate Mailglass verify/resolve/normalize/dedup tests, and a Chimeway-level integration test proves outbound provider_message_id correlation through worker signals and webhook_received trace entries
- TeamPulse invite email delivers through Chimeway.Adapters.Mailglass with operator trace proof at /admin/chimeway, without breaking the 10-test journey CI gate
- ECOS-05 reference blueprint with CI doc-contract truth lock — Chimeway orchestrates when/why, Mailglass handles templating, stable teampulse.invite_sent keys aligned with demo host
- DOCS-06 introduction guide publishing Chimeway+Mailglass adoption from dependencies through optional inbound feedback, with HexDocs and README discoverability
- DOCS-07 CI truth lock on the Mailglass integration guide with D-09 required phrases, recipe forbidden strings, and Mailglass adapter email-path guard
- GATE-04 named `mix verify.mailglass` entrypoint with fast ci.test exclusion, dedicated CI job, and MAINTAINING pre-ship sextet closing Phase 54 WR-03 deferral
- Section 6 Mailglass inbound webhook example now matches Chimeway.Webhooks.process/4 with adapter module, raw_body binary, header list, and safe error responses
- Doc-contract now forbids WR-01/WR-02 webhook regression patterns and requires adapter-module-first Webhooks.process/4 call shape

- Notes: Phase 57.1 inserted post-audit to close DOCS-06/07 webhook guide gap; Accrue/Threadline/Sigra deferred to v1.9+

---

## v1.7 READ + Adoption Polish

- Status: shipped
- Date: 2026-05-29
- Phases: 48–53 (6 phases, 14 plans, 39 tasks)
- Requirements: 11/11 satisfied
- Git tag: v1.7
- Git range: v1.6..v1.7 (79 commits, 78 files, +10,224 / −216 LOC)
- Audit: [milestones/v1.7-MILESTONE-AUDIT.md](milestones/v1.7-MILESTONE-AUDIT.md)
- Known deferred items at close: 2 dormant seeds (see STATE.md Deferred Items)
- Key accomplishments:

- Optional bounded `cancel_signals` string-list validation on `wait_until` progress rules with strict tagged errors at notifier declaration time
- `enter_waiting/6` atomically persists `pending_signals` from `wait_until` rule `cancel_signals`, with progression and SignalRouterWorker proofs that signal routing works without host glue
- Journey guide documents shipped `cancel_signals` DSL and canonical inbox event names; READ-01 engine-gap callout removed and locked by doc contract tests
- Inbox lifecycle APIs emit durable `chimeway.notification.read` / `.seen` signals on first transition via `Signal.track/4`, with tenant resolution and unit proof for READ-02
- Integration test proves `Chimeway.mark_read/3` emits a signal that `SignalRouterWorker` routes to resume a `:waiting` run, with `signal_received` transition context showing event name only (READ-02, READ-03)
- Journey guide documents shipped `mark_read`/`mark_seen` signal emission; doc contract forbids READ-02 deferral language (D-09)
- TeamPulse payment escalation demo now proves READ-driven workflow progression — no staged webhook choreography.
- Published mention-escalation recipe with CI doc contract and aligned journey guide intro.
- JOUR-06 journey tests prove email escalation fires only when unread: mark_read cancels before due_at; past-due progress_run creates exactly one email delivery.
- Admin LiveView journey tests prove Sam's suppressed password reset and Morgan's payment-escalation workflow are explainable via host-mounted trace search and detail pages.
- Demo host README and `mix demo.up` moduledoc now match shipped READ-driven TeamPulse escalation and actual `--check` smoke behavior
- Release-gate documentation aligned to expanded 9-test journey suite (JOUR-01..08, GATE-03)
- Retroactive Nyquist sign-off for v1.7 phases 48–51 by re-running automated validation commands and marking all VALIDATION.md files compliant
- ConnCase deprecation fix and JOUR-01..08 moduledoc alignment for clean `mix verify.journeys` output

- Notes: Phase 53 inserted post-audit for Nyquist sign-off and journey test hygiene; 2 dormant seeds deferred to v1.8+

---

## v1.6 Consumer Journey Proof

- Status: shipped
- Date: 2026-05-29
- Phases: 43–47 (5 phases, 5 plans)
- Requirements: 9/9 satisfied
- Git tag: v1.6
- Tests at close: 647 (`mix ci`) + 86 (`mix ci.verify_gates`) + 11 (`mix verify.example`) + 5 (`mix verify.journeys`)
- Audit: [milestones/v1.6-MILESTONE-AUDIT.md](milestones/v1.6-MILESTONE-AUDIT.md)
- Known deferred items at close: 2 dormant seeds + planning artifact debt (see STATE.md Deferred Items)
- Key accomplishments:
  - TeamPulse demo domain with invite, password reset, and payment escalation notifiers
  - Deterministic adopter-copyable `DemoHost.Seeds` + `mix demo.seed`
  - `mix demo.up` (root) and `mix demo.admin` one-command spin-up with admin URL banner
  - Journey E2E suite (JOUR-01..05): delivery, suppression, webhook progression, admin trace, demo.up smoke
  - GATE-02: `mix verify.journeys` CI job + MAINTAINING.md pre-ship quintet
- Notes: Phases 43–47 implemented outside standard GSD phase dirs; functional verification via journey suite

## v1.5 Adoption Surface

- Status: shipped
- Date: 2026-05-29 (formally closed after Phase 42 gap closure)
- Phases: 35-42 (8 phases, 25 plans, 59 tasks)
- Requirements: 11/11 satisfied
- Git tag: v1.5
- Tests at close: 647 (`mix ci`) + 86 (`mix ci.verify_gates`) + 20 (`mix verify.example`)
- Audit: [milestones/v1.5-MILESTONE-AUDIT.md](milestones/v1.5-MILESTONE-AUDIT.md)
- Known deferred items at close: 2 dormant seeds + nyquist tech debt (see STATE.md Deferred Items)
- Key accomplishments:
  - `mix chimeway.gen.migrations` installer with golden-diff CI contract
  - Golden-path integration guide with version alignment gates
  - Journey guide doc-truth rewrite and doc-contract tests
  - Password-reset and feedback escalation reference recipes
  - Demo host non-webhook IEx trace path
  - `chimeway_admin` operator trace MVP with host auth behaviour
  - GATE-01 release verification: `mix ci.verify_gates`, `verify.example` CI job, MAINTAINING.md quartet
  - Phase 42 gap closure: consumer docs `~> 1.0`, ex_doc links fixed, pre-ship quartet green
- Notes: Phase 42 inserted after re-audit found DOCS-02/GATE-01 regressions post-1.0.0 bump

## v1.4 Channel Feedback Loops

- Status: shipped
- Date: 2026-05-08 (formally closed 2026-05-28)
- Phases: 29-34 (6 phases, 21 plans)
- Requirements: 8/8 satisfied
- Git tag: v1.4
- Tests at close: 549 (`mix ci.test`)
- Known deferred items at close: 7 (see STATE.md Deferred Items; audit tech debt in `milestones/v1.4-MILESTONE-AUDIT.md`)
- Notes: Outbound channel contracts, inbound feedback normalization, feedback-driven progression, operator traces, webhook durability, E2E feedback proof host, and Three-Axis Vocabulary Contract.

## v1.3 Workflow Journeys

- Status: shipped
- Date: 2026-04-30
- Phases: 24-28
- Requirements: 11/11 satisfied
- Notes: Workflow engine, escalations, wait gates, host signal API, and tracing.

## v1.2 Delivery Orchestration

- Status: shipped
- Date: 2026-04-29
- Phases: 17-23
- Requirements: 11/11 satisfied
- Notes: Delivery orchestration (digest and deferred) completed.

## v1.1 Production Trust

- Status: shipped
- Date: 2026-04-27
- Phases: 13-16
- Requirements: 11/11 satisfied
- Git range: `v1.0..v1.1`
- Notes: Completed reliability hardening, explicit policy controls, observability surfaces, and integration paths.

## v1.0

- Status: shipped
- Date: 2026-04-25
- Phases: 1-12
- Requirements: 20/20 satisfied
- Notes: milestone audit passed with non-blocking tech debt only
