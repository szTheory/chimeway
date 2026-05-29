# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

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

### Cumulative Quality

| Milestone | Tests (at close) | Notes |
|-----------|------------------|-------|
| v1.4 | 549 | `mix ci.test` green at milestone re-audit |
| v1.5 | 647 | Full `mix ci` green; pre-ship quartet exit 0 |
| v1.6 | 647 + 5 journeys | Pre-ship quintet documented; journey CI separate job |

### Top Lessons (Verified Across Milestones)

1. Explainability stays central — every milestone adds operator-visible linkage for new behavior.
2. Gap-closure phases are cheaper than silent tech debt at milestone audit time.
3. Reference host examples pay off when integration seams are host-owned (webhooks, body readers, HMAC).

---

## Milestone-Next Assessment: v1.5 readiness (2026-05-28)

**Band:** ~82% (80–89%) — strong engine, adoption surfaces lag.

**Pick:** v1.5 Adoption Surface (SEED-002 + SEED-004). Defer channel matrix (3/10), full SEED-003 (follow v1.5), READ branching (6/10, after doc truth).

**Surprises:** `mix chimeway.gen.migrations` documented but no task exists; Phase 28 was v1.3 doc closure not adoption milestone; `enter_waiting` omits `pending_signals` while `route_signal` expects them.

**Graduation to v1.5 planning:** installer + golden path + optional `chimeway_admin` trace MVP; fix version/doc drift as gates.

Full thread: `.planning/threads/2026-05-28-v1.5-milestone-assessment.md`
