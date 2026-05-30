# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v1.8 — Ecosystem Integration Blueprints

**Shipped:** 2026-05-30
**Phases:** 5 (54–57, 57.1) | **Plans:** 13 | **Requirements:** 9/9

### What Was Built

- Optional `mailglass ~> 1.3` packaging with conditional adapter stub and test harness (ECOS-01).
- Full `Chimeway.Adapters.Mailglass` outbound `deliver/2` with tenancy, error classification, contract tests (ECOS-02).
- `provider_message_id` spine + Mailglass webhook verify/resolve/normalize/dedup callbacks (ECOS-03).
- Chimeway-level feedback pipeline proof through worker signals and `webhook_received` traces (ECOS-04).
- ECOS-05 blueprint recipe + DEMO-06 TeamPulse invite delivery with admin trace proof.
- DOCS-06 golden-path guide, DOCS-07 doc-contract truth lock, GATE-04 `mix verify.mailglass` sextet.
- Phase 57.1 closed audit gap: Section 6 webhook example + WR-01/WR-02 doc-contract guards.

### What Worked

- Mailglass-only scope kept v1.8 shippable in one day — deep composition beat broad SEED-003 matrix.
- Existing webhook/Signal spine (v1.4) absorbed Mailglass inbound without new routing substrate.
- `@moduletag :mailglass` selective CI isolated Mailglass tests from journey suite cleanly.
- Post-audit Phase 57.1 closed DOCS-06/07 partials without feature rework — same pattern as v1.7 Phase 53.

### What Was Inefficient

- Nyquist VALIDATION.md metadata lag for Phases 54–57 — implementation complete but draft flags remain.
- ECOS-04 Mailglass-specific workflow run resume/stop not E2E asserted — signal + trace proven at lib level only.
- Audit found guide prose drift (demo webhook route vs actual controller wiring) — minor doc debt.

### Patterns Established

- Runtime config only in adapters — no compile-time secrets (Phase 54).
- Dual lifecycle: Chimeway attempts + Mailglass delivery ledger is intentional (Phase 54).
- Guide vs blueprint doc separation prevents introduction/recipe drift (Phase 57).
- Webhook doc-contract uses explicit string lists for multi-word forbidden patterns (Phase 57.1).

### Key Lessons

1. Prove one ecosystem library deeply before expanding the matrix — Mailglass composition is the template for Accrue/Threadline/Sigra.
2. Doc-contract webhook call-shape guards pay off immediately — audit caught WR-01/WR-02 before adopters copied bad examples.
3. Close-out decimal phases (57.1) are cheaper than shipping with partial doc requirements.

### Cost Observations

- Model mix: not instrumented for this milestone
- Sessions: Phases 54–57.1 shipped 2026-05-29 (same-day burst)
- Notable: 77 commits since v1.7; 9/9 requirements satisfied at audit

---

## Milestone: v1.7 — READ + Adoption Polish

**Shipped:** 2026-05-29
**Phases:** 6 (48–53) | **Plans:** 14 | **Requirements:** 11/11

### What Was Built

- `cancel_signals` DSL on `wait_until` with declaration-time validation; `enter_waiting/6` auto-populates `pending_signals` (READ-01).
- Inbox `mark_read`/`mark_seen` emit durable signals; signal-routed early resume with explainable `signal_received` transition (READ-02/03).
- TeamPulse payment escalation uses READ-driven progression — no staged webhook choreography (DEMO-03).
- Mention-escalation reference recipe with read-cancel plus time-based fallback (DEMO-04).
- JOUR-06 read-cancel on Sync and Oban paths; JOUR-07/08 admin persona traces (Sam, Morgan).
- Demo README + `mix demo.up` moduledoc aligned; GATE-03 expanded to 10 journey tests (JOUR-01..08).
- Nyquist retroactive sign-off for Phases 48–51; ConnCase deprecation fix in journey tests.

### What Worked

- READ spine (48 → 49 → 50 → 51) wired cleanly through existing SignalRouterWorker — no new routing substrate.
- Doc contract tests locked READ-01/02 gap language from regressing in journey guide.
- Post-audit Phase 53 closed Nyquist metadata and Oban due-worker coverage without feature rework.
- Milestone audit before close-out caught missing Oban path in JOUR-06 — fixed before ship.

### What Was Inefficient

- Phase 53 inserted after initial audit — close-out phase could have been planned upfront.
- `mark_seen` emission covered but not exercised in progression E2E (INT-03).
- Inbox-read `signal_received` may not surface on delivery timeline UI (INT-02) — transition row only.

### Patterns Established

- `cancel_signals` validated at notifier declaration time, not runtime in progression (D-06).
- `pending_signals` column is sole durable source — not mirrored into status_context.
- Inbox lifecycle `:ok` independent of `Signal.track/4` result — separate transactions (D-07).
- `signal_received` transition context is event_name only — no payload in traces (READ-03).

### Key Lessons

1. Staged seed choreography masks engine gaps — demo must exercise real public APIs (`Chimeway.mark_read/3`), not test fixtures.
2. Journey tests need both Sync and Oban paths for async escalation proof — single-path coverage is insufficient.
3. Milestone close-out phases pay off when audit finds process debt (Nyquist, test hygiene) separate from feature gaps.

### Cost Observations

- Model mix: not instrumented for this milestone
- Sessions: Phases 48–53 shipped 2026-05-29 (same-day burst)
- Notable: 10 journey tests green; 11/11 requirements satisfied at audit

---

## Milestone: v1.6 — Consumer Journey Proof

**Shipped:** 2026-05-29
**Phases:** 5 (43–47) | **Plans:** 5 | **Requirements:** 9/9

### What Was Built

- TeamPulse demo domain with three persona JTBD notifiers (invite, password reset, payment escalation).
- Deterministic adopter-copyable `DemoHost.Seeds` + `mix demo.seed` using `Chimeway.trigger/3`.
- `mix demo.up` (root) and `mix demo.admin` one-command spin-up with admin URL banner.
- Journey E2E suite (JOUR-01..05): delivery, suppression, webhook progression, admin trace, demo.up smoke.
- GATE-02: `mix verify.journeys` CI job + MAINTAINING.md pre-ship quintet.

### What Worked

- Journey tests tagged `:journey` gave a fast, focused CI gate without bloating default `mix ci`.
- `DemoHost.Seeds` as public API let journey tests and adopters share the same entrypoint.
- Host-mount ConnTest + LiveViewTest proved admin integration without Playwright overhead.
- Separate v1.6 milestone kept adoption evidence distinct from v1.5 adoption surface.

### What Was Inefficient

- Phases 43–47 shipped without GSD phase directories — no SUMMARY.md or VERIFICATION.md audit trail.
- Implementation landed in one burst; retroactive phase scaffolding would improve traceability.
- Minor doc debt: README webhook contradiction, `demo.up --check` moduledoc drift.

### Patterns Established

- MAINTAINING.md pre-ship **quintet** extends v1.5 quartet with `mix verify.journeys`.
- `:journey` test tag isolates consumer journey proof for shift-left CI.
- Root `mix demo.up` orchestrates demo host seed/migrate/start for adopter onboarding.

### Key Lessons

1. Consumer journey proof belongs in CI before READ/workflow glue milestones — closes pre-adopter confidence gap.
2. Adopter-copyable seeds must use real `Chimeway.trigger/3`, not test fixture inserts.
3. Milestone close with missing phase artifacts is acceptable when audit + journey tests provide functional evidence.

### Cost Observations

- Model mix: not instrumented for this milestone
- Sessions: v1.6 assessment + implementation on 2026-05-29
- Notable: 5 journey tests green; pre-ship quintet documented

---

## Milestone: v1.5 — Adoption Surface

**Shipped:** 2026-05-29 (Phase 42 gap closure completed same day)
**Phases:** 8 (35–42) | **Plans:** 25 | **Requirements:** 11/11

### What Was Built

- `mix chimeway.gen.migrations` installer with golden-diff CI and idempotency contracts.
- Golden-path integration guide with doc-contract version alignment gates.
- Journey guide doc-truth rewrite plus Oban integration recipe and doc-contract tests.
- Password-reset support trace and feedback escalation reference recipes.
- Demo host IEx trace path without provider webhooks.
- Optional `chimeway_admin` operator trace MVP with host auth behaviour.
- GATE-01 release gates: `mix ci.verify_gates`, `verify.example` CI job, MAINTAINING.md pre-ship quartet.
- Phase 42 gap closure: `~> 1.0` consumer alignment, major-aware drift patterns, ex_doc link fixes.

### What Worked

- Doc-contract gates caught semver drift immediately after the 1.0.0 bump — Phase 42 was a narrow, fast closure.
- Reference recipes and demo host IEx path gave adopters multiple proof depths without webhook setup.
- `verify.example` additive chain proved both demo host E2E and chimeway_admin smoke in one pre-ship command.

### What Was Inefficient

- Initial v1.5 close (Phases 35–41) shipped before Phase 42 caught DOCS-02/GATE-01 regressions — required re-close and tag update.
- Nyquist validation artifacts still lag on phases 35 and 39 (non-blocking but noisy).
- MILESTONES.md listed 12 requirements while traceability table had 11 — count mismatch caused confusion at close.

### Patterns Established

- MAINTAINING.md pre-ship quartet (`mix ci`, `mix ci.docs`, `mix ci.verify_gates`, `mix verify.example`) is the release bar.
- Out-of-package guide links use GitHub absolute URLs, not `../../` paths in Hex docs.
- Major-aware `stale_drift_patterns/2` keeps doc-contract gates valid across semver bumps.

### Key Lessons

1. Run the full pre-ship quartet before tagging — scoped `ci.verify_gates` alone is insufficient for GATE-01.
2. Gap-closure phases after audit are cheaper than retro-editing shipped VERIFICATION artifacts.
3. Milestone close checklist must include Phase 42-style regressions when semver bumps land mid-milestone.

### Cost Observations

- Model mix: not instrumented for this milestone
- Sessions: Phases 35–41 plus Phase 42 gap closure on 2026-05-29
- Notable: 647 tests green at final close; pre-ship quartet all exit 0

---

## Milestone: v1.4 — Channel Feedback Loops

**Shipped:** 2026-05-08 (formally closed 2026-05-28 after re-audit)
**Phases:** 6 (29–34) | **Plans:** 21 | **Requirements:** 8/8

### What Was Built

- Generic outbound channel contracts (SMS, Push, Chat) with per-channel render and adapter resolution.
- Inbound webhook ingestion with canonical delivery outcome normalization and durable `Multi+Oban` handoff.
- Feedback-driven workflow progression via `Chimeway.Signal.track/4` and sync `Progression.progress_run/2`.
- Operator traces linking `:webhook_received` and workflow transition rows to journey steps.
- `examples/chimeway_demo_host` reference host proving host-mounted HTTP ingress and E2E feedback pipeline.
- Three-Axis Vocabulary Contract aligning `chimeway.delivery.{succeeded,bounced,failed}` across code and tests.

### What Worked

- Gap-closure phases (33–34) after milestone audit kept requirements traceable without reopening shipped phases.
- Atomic `Webhooks.process/4` + ingress schema prevented orphaned async work under failure.
- Teaching-example host (`chimeway_demo_host`) made D-12 body-reader patterns copy-safe for adopters.

### What Was Inefficient

- Phase 30 shipped without `VERIFICATION.md`, forcing FEED closure evidence to live in Phase 33.
- Nyquist validation artifacts lagged implementation on phases 29 and 31 (non-blocking but noisy at close).
- Milestone close was started 2026-05-08 but `v1.4` git tag was not created until formal completion.

### Patterns Established

- Canonical feedback vocabulary: provider status → ingress → signal `event_name` → trace projection must agree.
- Host webhook integration: `CacheBodyReader` must handle `:ok`, `:more`, and `:error` from `Plug.Conn.read_body/2`.
- E2E proof on real Oban queues in a sibling Phoenix app, not only library unit tests.

### Key Lessons

1. Close audit gaps with dedicated decimal/gap phases rather than retro-editing prior VERIFICATION artifacts.
2. When a phase is absorbed by a later phase, record that absorption in verification docs to avoid orphan requirements.
3. Milestone completion checklist must include git tag creation, not only planning file archival.

### Cost Observations

- Model mix: not instrumented for this milestone
- Sessions: multiple waves across phases 29–34 plus gap closure 33–34
- Notable: Re-audit on 2026-05-28 confirmed 549 tests green before formal tag

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Phases | Key Change |
|-----------|--------|------------|
| v1.0 | 1–12 | Durable spine + single channel slice |
| v1.1 | 13–16 | Production trust (policy, reliability, observability) |
| v1.2 | 17–23 | Delivery orchestration (defer, digest, render, recovery) |
| v1.3 | 24–28 | Workflow journeys + host signal API |
| v1.4 | 29–34 | Channel feedback loops + E2E proof host |
| v1.5 | 35–42 | Adoption surface + doc-contract release gates |
| v1.6 | 43–47 | Consumer journey proof + shift-left CI |
| v1.7 | 48–53 | READ workflow glue + adoption-evidence tail |

### Cumulative Quality

| Milestone | Tests (at close) | Notes |
|-----------|------------------|-------|
| v1.4 | 549 | `mix ci.test` green at milestone re-audit |
| v1.5 | 647 | Full `mix ci` green; pre-ship quartet exit 0 |
| v1.6 | 647 + 5 journeys | Pre-ship quintet documented; journey CI separate job |
| v1.7 | 695+ + 10 journeys | READ spine + expanded persona admin traces |

### Top Lessons (Verified Across Milestones)

1. Explainability stays central — every milestone adds operator-visible linkage for new behavior.
2. Gap-closure phases are cheaper than silent tech debt at milestone audit time.
3. Reference host examples pay off when integration seams are host-owned (webhooks, body readers, HMAC).

---

## Milestone-Next Assessment: v1.7 boundary (2026-05-29)

**Band:** ~88–92% (80–89% strong, upper edge) — engine + adoption surface + adoption evidence credible.

**Pick:** v1.7 READ (`pending_signals` on `wait_until` + inbox read→signal). Do **not** re-milestone Consumer Journey Proof — v1.6 shipped TeamPulse demo, seeds, journey CI, and one-command spin-up.

**Adoption evidence clarification:** The realistic demo + seeds + shift-left journey CI wedge is closed. Remaining gaps are narrow polish (README webhook contradiction, admin journeys for all personas, natural escalation demo without seed choreography) — fold into v1.7 close-out.

**Ordering after READ:** v1.8 SEED-003 ecosystem integrations → v1.9 INBX bell UI → maintenance.

**Surprises:** User concern about missing adoption evidence was already addressed by v1.6; staged `DemoHost.Seeds` escalation masks READ engine gap.

**Graduation candidates:** Adoption surface ≠ adoption evidence (permanent); consumer journey proof before READ (validated); staged seed choreography masks engine gaps (fix in v1.7).

Full thread: `.planning/threads/2026-05-29-v1.7-milestone-assessment.md`

---

## Milestone-Next Assessment: v1.8 boundary (2026-05-29)

**Band:** ~92–95% (90–95% near-done) — adoption evidence + READ polish complete for embedded-notification scope.

**Pick:** v1.8 SEED-003 ecosystem integration blueprints (Mailglass-first per INV-003). Do **not** re-milestone Consumer Journey Proof — TeamPulse demo, `DemoHost.Seeds`, and `mix verify.journeys` (10 tests) already satisfy the adoption-evidence prompt.

**Adoption evidence clarification:** Re-pasting the adoption-evidence prompt after v1.7 means **INBX / SEED-003**, not a new demo milestone. Operator admin UI (`/admin/chimeway`) ≠ end-user bell UI (v1.9).

**Ordering after v1.8:** v1.9 INBX bell UI → narrow adoption-evidence v2 (greenfield install CI) → external adopter outreach.

**Graduation candidates:** Three-layer pattern permanent (v1.5 surface ≠ v1.6 evidence ≠ v1.7 READ); operator demo ≠ end-user product demo.

Full thread: `.planning/threads/2026-05-29-v1.8-milestone-assessment.md`

---

## Milestone-Next Assessment: v1.5 readiness (2026-05-28)

**Band:** ~82% (80–89%) — strong engine, adoption surfaces lag.

**Pick:** v1.5 Adoption Surface (SEED-002 + SEED-004). Defer channel matrix (3/10), full SEED-003 (follow v1.5), READ branching (6/10, after doc truth).

**Surprises:** `mix chimeway.gen.migrations` documented but no task exists; Phase 28 was v1.3 doc closure not adoption milestone; `enter_waiting` omits `pending_signals` while `route_signal` expects them.

**Graduation to v1.5 planning:** installer + golden path + optional `chimeway_admin` trace MVP; fix version/doc drift as gates.

Full thread: `.planning/threads/2026-05-28-v1.5-milestone-assessment.md`
