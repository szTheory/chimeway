---
phase: 67
slug: close-ecos-09-repin-sigra-ci-sha-harden-verify-lanes-against
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-02
---

# Phase 67 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source: 67-RESEARCH.md `## Validation Architecture` (ExUnit, verified against live HEAD).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.17 / OTP 26+27 matrix) |
| **Config file** | `mix.exs` aliases (`ci.test`, `verify.sigra` at `mix.exs:134-137`) |
| **Quick run command** | `SIGRA_PATH=../sigra/sigra mix test --only sigra --warnings-as-errors` (root lane, ~5 tests) |
| **Full suite command** | `SIGRA_PATH=<sibling> mix verify.sigra` (root + demo-host lanes) |
| **Estimated runtime** | ~90 seconds (root lane); full `verify.sigra` longer (two mix projects) |

---

## Sampling Rate

- **After every task commit:** Run `SIGRA_PATH=<sibling> mix test --only sigra --warnings-as-errors`
- **After every plan wave:** Run `mix verify.sigra` + `mix test test/chimeway/release_gate_contract_test.exs test/chimeway/doc_contract_test.exs`
- **Before `/gsd:verify-work`:** full `mix verify.sigra` green in clean-CI conditions (the D-05 reproduction)
- **Max feedback latency:** ~90 seconds (quick lane)

---

## Per-Task Verification Map

> Plan/task IDs are assigned by the planner; rows below are keyed to the locked decisions (D-01..D-06) and will be mapped to concrete task IDs during execution.

| Decision | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command / Evidence | File Exists | Status |
|----------|------|-------------|------------|-----------------|-----------|------------------------------|-------------|--------|
| D-01 (repin CI SHA) | 1 | ECOS-09 | T-67-supply-chain (pinned partner SHA) | sibling checkout non-empty; lifecycle compiles real tests | integration | `verify_sigra` job `ci.yml:427` → root lane runs harness(3)+lifecycle(2) | ✅ (repin makes real) | ⬜ pending |
| D-02a (raise-loud missing file) | 1 | ECOS-09 | T-67-vacuous-gate | missing integration file raises, not skips | guard | `test_helper.exs` sigra+accrue `else`-raise | ❌ W0 | ⬜ pending |
| D-02b (harness hard-assert) | 1 | ECOS-09 / GATE-07 | T-67-vacuous-gate | absent integration → RED not green/skip | integration | sigra/accrue/threadline harness module-load + verified-export assert | ❌ W0 | ⬜ pending |
| D-02c (test-count floor) | 1 | GATE-07 | T-67-vacuous-gate | lane degraded to 0 tests fails | contract | `release_gate_contract_test.exs` floor (sigra ≥5 root/≥2 demo, accrue ≥11, threadline ≥7) | ❌ W0 | ⬜ pending |
| D-03 (fix guide) | 1 | DOCS-10 | — | guide shows valid `trigger(Notifier, params, opts)` | contract | `doc_contract_test.exs` after fix | ❌ W0 | ⬜ pending |
| D-04 (strengthen doc-contract) | 1 | DOCS-11/DOCS-10 | — | wrong trigger shape caught | contract | `doc_contract_test.exs` forbidden `Chimeway.trigger("`, `params:`; require `*Notifier`; full `seed_sigra_auth` | ❌ W0 | ⬜ pending |
| D-05 (verify Phase 64 + reconcile) | 2 | ECOS-09 | — | ECOS-09 proven E2E in clean CI | e2e / doc | `mix verify.sigra` green + `64-VERIFICATION.md`; `sigra_auth_proof_test.exs:44,52` (demo) | ❌ W0 (produce) | ⬜ pending |
| D-06 (Nyquist closeout + hygiene) | 2 | — | — | 64-VALIDATION.md closed; override comment accurate | doc | frontmatter `nyquist_compliant: true`; `mix.exs:177-178` comment | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/test_helper.exs` — add `else`-raise to sigra block (≈line 160-166) and accrue block (≈line 43-49) — raise-loud-on-missing-file (D-02a)
- [ ] `test/chimeway/integrations/sigra_auth_harness_test.exs` — hard-assert `Code.ensure_loaded?(Sigra.Integrations.Chimeway)` + a VERIFIED exported function (confirm `:trigger/3` vs `dispatch_magic_link_after_request/3` first — Assumption A1)
- [ ] `test/chimeway/integrations/accrue_dunning_harness_test.exs` — move integration-module check out of outer guard; assert `Accrue.Integrations.Chimeway.start_campaign/3` loud
- [ ] `test/chimeway/integrations/threadline_telemetry_harness_test.exs` — assert `Chimeway.Telemetry.ThreadlineReporter` + `attach/0` (OUT direction) + `Threadline.record_action/2`
- [ ] `test/chimeway/release_gate_contract_test.exs` — new floor `describe` (sigra/accrue/threadline counts, `≥` not `==`)
- [ ] `test/chimeway/doc_contract_test.exs` — extend sigra describe (forbidden `Chimeway.trigger("`, `params:`; require `*Notifier`; full `seed_sigra_auth` pin)
- [ ] `.planning/phases/64-sigra-auth-flows-core/64-VERIFICATION.md` — produce (D-05)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `szTheory/sigra@62ceb46a` actually contains `lib/sigra/integrations/chimeway.ex` on the remote | ECOS-09 / D-01 | Remote SHA content not network-fetchable in the planning session (Assumption A3); the gitignored local `deps/sigra` corroborates | Before merging D-01, confirm the pinned SHA contains the integration file (e.g. `git ls-tree szTheory/sigra 62ceb46a -- lib/sigra/integrations/chimeway.ex`, or push a branch and let `verify_sigra` run) |
| Final clean-CI green for `verify_sigra` | ECOS-09 / GATE-07 | True clean-CI behavior only observable in the CI runner (sibling checkout, no local `deps/sigra`) | Push branch; confirm `verify_sigra` job runs >0 sigra integration tests and passes |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 90s
- [ ] `nyquist_compliant: true` set in frontmatter (closed out under D-06 after execution)

**Approval:** pending
