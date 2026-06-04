---
phase: 65
slug: ecosystem-blueprints-demo
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-30
---

# Phase 65 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir built-in) |
| **Config file** | `test/test_helper.exs`, demo host: `examples/chimeway_demo_host/test/test_helper.exs` |
| **Quick run command** | `mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` |
| **Full suite command** | `mix ci.test` (core) + `cd examples/chimeway_demo_host && mix test` (demo host) |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/chimeway/doc_contract_test.exs --warnings-as-errors`
- **After every plan wave:** Run `mix ci.verify_gates` + `cd examples/chimeway_demo_host && mix test --only threadline --only sigra`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** ~30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| blueprint-doc | 01 | 1 | ECOS-10 | — | No raw tokens in code examples | doc-contract | `mix test test/chimeway/doc_contract_test.exs -k "ECOS-10"` | ❌ W0 | ⬜ pending |
| doc-contract-block | 01 | 1 | ECOS-10 | — | Required strings enforced in CI | doc-contract | `mix test test/chimeway/doc_contract_test.exs -k "ECOS-10"` | ❌ W0 | ⬜ pending |
| hexdocs-extras | 01 | 1 | ECOS-10 | — | Blueprint published to HexDocs | doc-contract | `mix test test/chimeway/doc_contract_test.exs -k "hexdocs"` | ❌ W0 | ⬜ pending |
| threadline-proof | 02 | 1 | DEMO-09 | — | audit_actions row with correlation_id | integration | `cd examples/chimeway_demo_host && mix test --only threadline` | ❌ W0 | ⬜ pending |
| sigra-proof | 03 | 1 | DEMO-10 | — | Chimeway delivery created + traced | integration | `cd examples/chimeway_demo_host && mix test --only sigra` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `guides/recipes/sigra-auth-blueprint.md` — blueprint content for ECOS-10
- [ ] `test/chimeway/doc_contract_test.exs` ECOS-10 describe block — doc-contract CI gate for ECOS-10
- [ ] `examples/chimeway_demo_host/test/demo_host_web/threadline_telemetry_proof_test.exs` — DEMO-09 proof
- [ ] `examples/chimeway_demo_host/test/demo_host_web/sigra_auth_proof_test.exs` — DEMO-10 proof
- [ ] `examples/chimeway_demo_host/lib/demo_host/seeds.ex` — `seed_threadline_notification/0` and `seed_sigra_auth/0` helpers
- [ ] `mix.exs` HexDocs extras entry for `guides/recipes/sigra-auth-blueprint.md`
- [ ] `examples/chimeway_demo_host/test/test_helper.exs` — Threadline + Sigra TestRepo bootstrap blocks (gap confirmed by research)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Blueprint renders correctly in HexDocs | ECOS-10 | HexDoc build requires `mix docs` + browser review | Run `mix docs && open doc/index.html`, navigate to Recipes section |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
