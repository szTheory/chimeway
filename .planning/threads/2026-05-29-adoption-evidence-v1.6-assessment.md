# Thread: v1.6 adoption evidence assessment

**Opened:** 2026-05-29  
**Status:** open — handoff to v1.6 Consumer Journey Proof implementation  
**Trigger:** Adoption evidence prompt at post-v1.5 milestone boundary

## Executive verdict

**Done band: ~88–90%** — engine and v1.5 adoption surface (installer, docs, gates, admin MVP) are credible; consumer journey proof (realistic demo domain, seeds, host-mount admin E2E, journey CI) is the remaining wedge.

**Next milestone (single pick): v1.6 Consumer Journey Proof** — not READ-first, not SEED-003, not INBX.

## Residual gaps after v1.5 (repo evidence)

| Gap | v1.5 audit / inspection |
|-----|-------------------------|
| No runtime seeds | No `priv/repo/seeds.exs` in demo host |
| Demo host narrow | IEx trace + webhook E2E only; no TeamPulse persona domain |
| No host-mount admin test | Phase 40 tech debt — isolated `chimeway_admin` tests only |
| No journey CI matrix | `verify.example` subprocess smoke, not persona JTBD journeys |
| No one-command admin spin-up | Manual `mix phx.server` after `mix demo.trace` |

## v1.6 journey requirements (JOUR-01..05)

| ID | Journey | Proof |
|----|---------|-------|
| JOUR-01 | Seed → invite trigger → delivery succeeded | ExUnit + Sandbox |
| JOUR-02 | Seed → suppressed password reset explainability | `Chimeway.Traces` suppression_reason |
| JOUR-03 | Seed → webhook → workflow progression | Oban.Testing, public Seeds API |
| JOUR-04 | Host-mount admin search → delivery detail | ConnTest + LiveViewTest via demo host router |
| JOUR-05 | `mix demo.up --check` orchestration smoke | Mix task exits 0 |

## Graduation candidates

- Adoption surface (v1.5) ≠ adoption evidence (v1.6) — separate milestones in future assessments
- Internal E2E fixture inserts are anti-patterns for adopter copy-paste — `DemoHost.Seeds` must be public
- Host-mount admin test was deferred tech debt, not optional polish

## Investigations

| ID | Question | When |
|----|----------|------|
| INV-004 | Playwright vs LiveView ConnTest for admin smoke | Defer Playwright until ConnTest proves flaky (testing strategy) |

## Maintainer takeaway

Ship TeamPulse demo domain + `mix demo.up` + `mix verify.journeys` before READ or SEED-003. That closes pre-adopter confidence gap.
