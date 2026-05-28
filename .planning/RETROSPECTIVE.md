# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

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

### Cumulative Quality

| Milestone | Tests (at close) | Notes |
|-----------|------------------|-------|
| v1.4 | 549 | `mix ci.test` green at milestone re-audit |

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
