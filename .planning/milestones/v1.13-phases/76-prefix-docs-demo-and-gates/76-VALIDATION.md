---
phase: 76
slug: prefix-docs-demo-and-gates
status: planned
nyquist_compliant: true
wave_0_complete: true
created: 2026-07-01
---

# Phase 76 - Validation Strategy

> Planning-time validation contract for feedback sampling during execution. This file maps Phase 76 docs, demo, and gate requirements to automated verification. It does not claim implementation tests have already passed.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit via Mix; docs built by ExDoc |
| **Config files** | `mix.exs`, `config/test.exs`, `examples/chimeway_demo_host/config/test.exs`, `.github/workflows/ci.yml` |
| **Quick run command** | `mix ci.verify_gates` |
| **Docs command** | `mix ci.docs` |
| **Demo command** | `cd examples/chimeway_demo_host && MIX_ENV=test mix test test/demo_host_web/admin_trace_live_test.exs --warnings-as-errors` or the focused sibling proof created by this phase |
| **Full suite command** | `mix verify.runtime_prefix && mix verify.install_golden && mix verify.example && mix ci.verify_gates` |
| **Estimated runtime** | ~60 seconds for focused doc/release contracts; broader storage/demo gates can take several minutes |

---

## Sampling Rate

- **After every task commit:** Run the task-owned focused command listed below.
- **After every plan wave:** Run `mix ci.verify_gates` plus any new focused demo/docs command created in that wave.
- **Before phase verification:** Run `mix ci.verify_gates`, `mix ci.docs`, `mix verify.runtime_prefix`, `mix verify.install_golden`, and `mix verify.example`.
- **CI target-version note:** Treat GitHub Actions PostgreSQL 15 as the authoritative release-gate proof if local PostgreSQL is below the project baseline.
- **Max feedback latency:** Keep focused doc/release contract checks under 60 seconds; reserve full storage/demo gate runs for wave and final checks.

---

## Requirement Coverage Map

| Requirement | Covered By | Required Automated Proof |
|-------------|------------|--------------------------|
| UPG-02 | Storage prefix upgrade/troubleshooting guide | `MIX_ENV=test mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` |
| UPG-03 | Rollback/failure-mode guide copy and forbidden automatic-move claims | `MIX_ENV=test mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` |
| DOCS-01 | README, install, golden path, troubleshooting, and HexDocs extras | `mix ci.verify_gates` and `mix ci.docs` |
| DOCS-02 | Oban prefix separation guide and forbidden first-run copy | `MIX_ENV=test mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` |
| DEMO-01 | Demo host default `prefix: "chimeway"` public API trigger-to-trace proof | Focused demo-host ExUnit proof under `examples/chimeway_demo_host/test/` |
| GATE-01 | Local verify aliases, CI jobs, ci-gate parity, and release contract coverage | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors` and `mix ci.verify_gates` |

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 76-docs-01 | TBD | TBD | UPG-02, UPG-03, DOCS-01 | T-76-01 / T-76-02 | Storage guide explains manual public-to-`chimeway` move, backup/preflight/rollback, and no silent migration | doc contract + docs build | `MIX_ENV=test mix test test/chimeway/doc_contract_test.exs --warnings-as-errors`; `mix ci.docs` | guide missing; contract file exists | planned, not run |
| 76-oban-01 | TBD | TBD | DOCS-02 | T-76-03 | Oban job-table prefix is documented separately from Chimeway storage prefix with `"jobs"` examples | doc contract | `MIX_ENV=test mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` | Oban guide exists; new assertions missing | planned, not run |
| 76-demo-01 | TBD | TBD | DEMO-01 | T-76-04 / T-76-05 | Demo host uses public APIs and proves rows land in `chimeway.*` while public Chimeway tables remain empty | demo-host integration | `cd examples/chimeway_demo_host && MIX_ENV=test mix test test/demo_host_web/admin_trace_live_test.exs --warnings-as-errors` or focused sibling command | demo test exists; prefix assertions missing | planned, not run |
| 76-gate-01 | TBD | TBD | GATE-01 | T-76-06 | Named verify/CI gates agree across Mix aliases, GitHub Actions, MAINTAINING, and release-gate contracts | release contract + CI parity | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors`; `mix ci.verify_gates` | release contract exists; runtime-prefix CI lane missing | planned, not run |
| 76-final-01 | TBD | TBD | UPG-02, UPG-03, DOCS-01, DOCS-02, DEMO-01, GATE-01 | T-76-01..06 | Final gate proves docs contracts, release parity, runtime prefix, install golden, and demo/example behavior | final gate | `mix ci.verify_gates`; `mix ci.docs`; `mix verify.runtime_prefix`; `mix verify.install_golden`; `mix verify.example` | existing aliases mostly present; CI parity missing | planned, not run |

*Status values: planned, green, red, flaky*

---

## Wave 0 Requirements

- [x] `test/chimeway/doc_contract_test.exs` exists and is the planned contract surface for storage guide and Oban prefix copy.
- [x] `test/chimeway/release_gate_contract_test.exs` exists and is the planned contract surface for local/CI/release gate parity.
- [x] `mix verify.runtime_prefix` exists and Phase 76 owns CI/release parity, not the runtime behavior itself.
- [ ] `guides/introduction/storage-prefix-upgrade.md` must be created and added to HexDocs extras.
- [ ] Demo-host prefixed schema proof must be added or extended under `examples/chimeway_demo_host/test/`.
- [ ] `.github/workflows/ci.yml` must add the required runtime-prefix lane and ci-gate parity.
- [ ] `MAINTAINING.md` must list the storage-prefix gates consistently with Mix aliases and CI jobs.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| PostgreSQL 15 exactness | DEMO-01, GATE-01 | Local development may use a PostgreSQL version below the project baseline | Treat green GitHub Actions PostgreSQL 15 runs, or a local PostgreSQL 15 run of the same commands, as final release-gate proof |

---

## Validation Sign-Off

- [x] All phase requirements have an automated verification path.
- [x] No task relies on browser smoke tests for DEMO-01 unless the existing demo-host proof cannot satisfy it.
- [x] Storage-prefix docs are contract-tested for required claims and forbidden footguns.
- [x] Release-gate parity is contract-tested across Mix aliases, CI jobs, ci-gate, and MAINTAINING.
- [x] No watch-mode flags are used.
- [x] Sampling continuity target documented.
- [x] `nyquist_compliant: true` set in frontmatter.

**Approval:** planning strategy compliant; implementation execution not yet run.
