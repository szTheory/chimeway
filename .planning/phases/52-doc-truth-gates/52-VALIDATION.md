---
phase: 52
slug: doc-truth-gates
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-29
---

# Phase 52 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (journey regression); grep/manual for doc truth |
| **Config file** | Root `mix.exs` alias `verify.journeys` |
| **Quick run command** | `mix verify.journeys` |
| **Doc drift command** | `rg` forbidden strings (see Per-Task map) |
| **Full suite command** | Pre-ship quintet in `MAINTAINING.md` lines 25–31 |
| **Estimated runtime** | ~2–5s (`verify.journeys`); ~3–5 min (full quintet) |

---

## Sampling Rate

- **After every task commit:** Run `mix verify.journeys` + relevant grep gates
- **After every plan wave:** Run grep gates for that plan's requirements
- **Before `/gsd-verify-work`:** Full quintet recommended for GATE-03 sign-off
- **Max feedback latency:** 10 seconds (journey suite)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 52-01-01 | 01 | 1 | DOCS-04 | — | README Morgan row READ-driven; no webhook drift | grep + manual | `rg "awaiting webhook" examples/chimeway_demo_host/README.md` → empty | ✅ | ⬜ pending |
| 52-01-02 | 01 | 1 | DOCS-04 | — | Webhook section reframed; TraceDemo supplementary | manual | Read-through checklist in 52-RESEARCH.md §5 | ✅ | ⬜ pending |
| 52-01-03 | 01 | 1 | DOCS-05 | — | `--check` docs match migrate+seed behavior | grep | `rg "seed only" examples/chimeway_demo_host/README.md lib/mix/tasks/demo.up.ex` → empty | ✅ | ⬜ pending |
| 52-02-01 | 02 | 1 | GATE-03 | — | MAINTAINING.md JOUR-01..08 / GATE-03 | grep | `rg "JOUR-01..08|GATE-03" MAINTAINING.md` | ✅ | ⬜ pending |
| 52-02-02 | 02 | 1 | GATE-03 | — | mix.exs comment GATE-03 | grep | `rg "GATE-03" mix.exs` | ✅ | ⬜ pending |
| 52-02-03 | 02 | 1 | GATE-03 | — | PROJECT.md 9 journey tests | grep | `rg "9 journey" .planning/PROJECT.md` | ✅ | ⬜ pending |
| 52-*-regression | 01,02 | 1 | GATE-03 | — | Journey suite unchanged | journey | `mix verify.journeys` (9 tests, 0 failures) | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No new tests, fixtures, or CI jobs.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| README narrative coherence | DOCS-04 | Demo README not in doc_contract_test.exs | Adopter read-through: Morgan READ-driven; TraceDemo supplementary; webhook separate path |
| RETROSPECTIVE.md counts | — | Deferred per CONTEXT discretion | Skip unless milestone close |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (none — prose-only phase)
- [x] No watch-mode flags
- [x] Feedback latency < 10s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
