---
phase: 36
slug: golden-path-version-alignment
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-05-28
---

# Phase 36 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution (docs-only phase).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + manual grep/checklist (no doc-contract CI until Phase 41) |
| **Config file** | `mix.exs` aliases — `ci.docs` for HexDocs build |
| **Quick run command** | `mix ci.docs` |
| **Full suite command** | `mix ci` |
| **Estimated runtime** | ~20 seconds (docs build + full CI) |

---

## Sampling Rate

- **After every task commit:** Run manual grep gates (version + API) on edited doc files
- **After every plan wave:** Run `mix ci.docs`
- **Before `/gsd-verify-work`:** Full suite must be green; one fresh-host golden-path walkthrough recommended
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 36-01-01 | 01 | 1 | DOCS-01 | — | Golden-path covers D-01 vertical slice | manual | Section checklist vs D-01 steps | ✅ | ⬜ pending |
| 36-01-02 | 01 | 1 | DOCS-01 | — | `explain_delivery/1` proof step present | grep | `rg 'explain_delivery' guides/introduction/golden-path.md` | ❌ W0 | ⬜ pending |
| 36-01-03 | 01 | 1 | DOCS-01 | — | Notifier uses `recipients/1` with correct keys | grep | `rg 'resolve_recipients|identity:' guides/introduction/golden-path.md` expect 0 | ❌ W0 | ⬜ pending |
| 36-01-04 | 01 | 1 | DOCS-01 | D-11 | golden-path registered in mix.exs extras | grep | `rg 'golden-path' mix.exs` | ✅ | ⬜ pending |
| 36-02-01 | 02 | 2 | DOCS-02 | — | No `~> 1.0` drift in consumer docs | grep | `rg '~> 1\.0|1\.0\.0' README.md guides/introduction/` expect 0 | ✅ | ⬜ pending |
| 36-02-02 | 02 | 2 | DOCS-02 | D-08 | README links golden-path; API fixed | manual | Visual diff README.md Quick Start | ✅ | ⬜ pending |
| 36-02-03 | 02 | 2 | DOCS-02 | D-12 | installation Next Steps → golden-path | grep | `rg 'golden-path' guides/introduction/installation.md` | ✅ | ⬜ pending |
| 36-03-01 | 03 | 3 | DOCS-01 | D-09 | Webhook appendix cross-link exists | grep | `rg 'feedback_pipeline_e2e_test' guides/introduction/golden-path.md` | ❌ W0 | ⬜ pending |
| 36-03-02 | 03 | 3 | DOCS-02 | D-12 | getting-started Next Steps updated | grep | `rg 'golden-path' guides/introduction/getting-started.md` | ✅ | ⬜ pending |
| 36-03-03 | 03 | 3 | DOCS-01 | — | Trigger examples include `tenant_id` + `idempotency_key` | grep | `rg 'Chimeway\.trigger' guides/introduction/golden-path.md` + manual | ❌ W0 | ⬜ pending |
| 36-03-04 | 03 | 3 | DOCS-01 | — | HexDocs build passes | integration | `mix ci.docs` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements — no new test files required.

- [x] `mix ci.docs` — HexDocs build with warnings-as-errors
- [x] `mix ci` — full CI suite
- [x] Manual grep gates defined in `36-RESEARCH.md` Validation Architecture

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Fresh Phoenix host walkthrough | DOCS-01 | No automated doc-contract CI until Phase 41 | Create/use Phoenix app; follow golden-path verbatim; `iex -S mix` → trigger → `explain_delivery/1` returns `status: :succeeded` |
| Shared-database config clarity | DOCS-01 | Runtime uses `Chimeway.Repo`; host must configure same DB | Verify golden-path documents `config :chimeway, Chimeway.Repo, ...` pointing at host database |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
