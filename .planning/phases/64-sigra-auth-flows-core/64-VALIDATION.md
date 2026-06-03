---
phase: 64
slug: sigra-auth-flows-core
status: closed
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-30
---

# Phase 64 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.17+) |
| **Config file** | `mix.exs` aliases (`ci.test`, future `verify.sigra`) |
| **Quick run command** | `mix test test/chimeway/integrations/sigra_auth_harness_test.exs --only sigra --warnings-as-errors` |
| **Full suite command** | `mix test --only sigra --warnings-as-errors` |
| **Estimated runtime** | ~30–90 seconds (depends on Sigra bootstrap) |

---

## Sampling Rate

- **After every task commit:** Run targeted `mix test .../sigra_* --only sigra --warnings-as-errors`
- **After every plan wave:** Run `mix test --only sigra --warnings-as-errors`
- **Before `/gsd-verify-work`:** Full `mix test --only sigra` + `mix ci.test` must be green
- **Max feedback latency:** 90 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 64-01-01 | 01 | 1 | ECOS-09 | T-64-01 | Optional sigra dep compiles without Sigra | compile | `mix compile --warnings-as-errors` | ✅ | ✅ green |
| 64-01-02 | 01 | 1 | ECOS-09 | T-64-02 | Sigra tests excluded from default CI | unit | `mix ci.test --warnings-as-errors` | ✅ | ✅ green |
| 64-01-03 | 01 | 1 | ECOS-09 | T-64-03 | Harness bootstrap + config round-trip | integration | `mix test test/chimeway/integrations/sigra_auth_harness_test.exs --only sigra` | ✅ | ✅ green |
| 64-01-04 | 01 | 1 | ECOS-09 | T-64-04 | `@sensitive_keys` strips url/code/raw_token | unit | `mix test test/chimeway/trigger_test.exs --warnings-as-errors` | ✅ | ✅ green |
| 64-02-01 | 02 | 2 | ECOS-09 | T-64-05 | Magic link trigger → delivery attempt + trace | integration | `mix test test/chimeway/integrations/sigra_auth_lifecycle_test.exs --only sigra` | ✅ | ✅ green |
| 64-02-02 | 02 | 2 | ECOS-09 | T-64-06 | Confirmation code trigger → delivery + trace | integration | same | ✅ | ✅ green |
| 64-02-03 | 02 | 2 | ECOS-09 | T-64-07 | No raw token/code/URL in trace surfaces | integration | same + telemetry PII refute | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `mix.exs` — optional `{:sigra, "~> 0.3", optional: true}`, `ci.test` exclude `:sigra`
- [x] `config/test.exs` — Sigra.TestRepo + schema config
- [x] `test/test_helper.exs` — conditional Sigra bootstrap
- [x] `test/support/sigra/*` — repo, schemas, migrations, fixtures, data_case
- [x] `test/chimeway/integrations/sigra_auth_harness_test.exs` — Wave 64-01 stub
- [x] `lib/chimeway/trigger.ex` — extend `@sensitive_keys`
- [x] `../sigra/lib/sigra/integrations/chimeway.ex` — integration + notifiers
- [x] `test/chimeway/integrations/sigra_auth_lifecycle_test.exs` — Wave 64-02 E2E

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Sigra hex release with optional `:chimeway` | ECOS-09 | Cross-repo release coordination | Verify Sigra release includes `Sigra.Integrations.Chimeway` before path-dep removal |
| `mix verify.sigra` CI job | GATE-07 | Deferred to Phase 66 | N/A for Phase 64 |

*All Phase 64 engine behaviour paths have automated verification via `--only sigra` once Wave 0 lands.*

---

## Validation Sign-Off

- [x] All Wave 0 files exist
- [x] `mix test --only sigra --warnings-as-errors` green
- [x] `mix ci.test` green (sigra excluded)
- [x] Redaction assertions pass for both flows
