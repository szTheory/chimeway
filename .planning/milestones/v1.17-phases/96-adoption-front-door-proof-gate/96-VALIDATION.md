---
phase: 96
slug: adoption-front-door-proof-gate
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-08-10
validated: 2026-08-11
updated: 2026-08-11
---

# Phase 96 — Validation Strategy

> Retroactively reconciled Nyquist contract for the completed adoption front door, package proof, archive boundary, documentation contracts, and CI gate.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit plus GitHub Actions exact-SHA assertion |
| **Canonical local gate** | `mix ci.verify_gates` |
| **Behavioral command** | `mix verify.adoption_paths` |
| **Hosted evidence command** | `scripts/ci/assert-adoption-run.sh <40-character-sha>` |
| **Focused contract file** | `test/chimeway/release_gate_contract_test.exs` |
| **Documentation contract file** | `test/chimeway/doc_contract_test.exs` |
| **Current local evidence** | `mix ci.verify_gates`: 618 tests, 0 failures, 1 dedicated E2E excluded on 2026-08-11 |
| **Current hosted evidence** | Run `31509666185` at `8371af59b1dbe7ac3b24decaae538a53da28b987`: adoption success, `pr-gate` success |

---

## Sampling Rate

- **After every task commit:** Run the task-specific command in the verification map.
- **After every plan wave:** Run the relevant focused tags and formatting checks.
- **Before phase or milestone acceptance:** Run `mix ci.verify_gates` and programmatically assert the hosted adoption lane against the implementation SHA.
- **Behavioral ownership:** The dedicated PostgreSQL lane executes the expensive packaged Core → Mailglass → Accrue E2E; the local canonical gate owns structural, mutation, archive-security, and documentation contracts.
- **Max feedback latency:** Focused tags provide bounded feedback; full artifact and hosted lanes are intentionally slower.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 96-01-01 | 01 | 1 | GATE-01, DOCS-01 | T-96-01, T-96-02, T-96-03, T-96-04 | Strict focused Core task validates one package artifact, rejects invalid selectors before proof work, and emits fixed redacted framing. | tracer + behavioral E2E | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --only adoption_paths_tracer --warnings-as-errors && scripts/test-db env MIX_ENV=test mix verify.adoption_paths --only core` | ✅ | ✅ green |
| 96-01-02 | 01 | 1 | GATE-01, DOCS-01 | T-96-03, T-96-04, T-96-05 | One build/unpack dispatches Core, Mailglass, and Accrue exactly once in serial order with strict fixture-owned evidence. | contract + behavioral E2E | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --only adoption_paths_contract --warnings-as-errors && scripts/test-db env MIX_ENV=test mix verify.adoption_paths` | ✅ | ✅ green |
| 96-02-01 | 02 | 2 | ADPT-01, ADPT-02, DOCS-01 | T-96-06, T-96-07 | The canonical selector locks exact path order, responsibilities, commands, safe evidence, exclusions, and guide links. | documentation + mutation contract | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/doc_contract_test.exs test/chimeway/release_gate_contract_test.exs --only adoption_paths_docs_contract --warnings-as-errors` | ✅ | ✅ green |
| 96-02-02 | 02 | 2 | GATE-02, DOCS-01 | T-96-08, T-96-09, T-96-10 | One PostgreSQL adoption job is coupled through all required gate edges and verified by an exact-SHA hosted assertion. | CI topology + hosted E2E | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --only adoption_paths_ci_contract --warnings-as-errors && mix ci.verify_gates` | ✅ | ✅ green |
| 96-03-01 | 03 | 3 | ADPT-01, ADPT-02, GATE-01, GATE-02, DOCS-01 | T-96-11, T-96-12, T-96-13 | Valid-digest symbolic-link escapes are rejected before writes, reads, code loading, or callback execution. | archive-security regression | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --only adoption_archive_security --warnings-as-errors` | ✅ | ✅ green |
| 96-03-02 | 03 | 3 | ADPT-01, ADPT-02, GATE-01, GATE-02, DOCS-01 | T-96-11, T-96-12, T-96-13, T-96-14, T-96-15 | Every link/special tar type, malformed header, conflicting path, and outside side effect fails before materialization while valid archives remain functional. | adversarial archive matrix | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --only adoption_archive_security --warnings-as-errors && mix format --check-formatted priv/adoption_proof/artifact_archive.ex test/chimeway/release_gate_contract_test.exs && mix ci.verify_gates` | ✅ | ✅ green |
| 96-04-01 | 04 | 4 | GATE-01, DOCS-01 | T-96-16, T-96-20 | Digest verification and extraction consume one immutable bounded archive read despite deterministic pathname replacement. | TOCTOU regression | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --only adoption_archive_toctou --warnings-as-errors` | ✅ | ✅ green |
| 96-04-02 | 04 | 4 | GATE-01, DOCS-01 | T-96-17, T-96-18, T-96-19, T-96-20 | Outer, compressed, expanded, member-count, and member-size budgets fail closed before archive-controlled writes. | resource-boundary matrix | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --only adoption_archive_limits --only adoption_archive_toctou --only adoption_archive_security --warnings-as-errors && mix format --check-formatted priv/adoption_proof/artifact_archive.ex test/chimeway/release_gate_contract_test.exs` | ✅ | ✅ green |
| 96-05-01 | 05 | 5 | GATE-01, DOCS-01 | T-96-21 | Every standalone Accrue archive-validator error collapses to one fixed diagnostic and status with no stacktrace, internal reason, or proof record. | packaged CLI regression | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --only accrue_packaged_cli --warnings-as-errors` | ✅ | ✅ green |
| 96-05-02 | 05 | 5 | GATE-01, DOCS-01 | T-96-22, T-96-23, T-96-24, T-96-25 | Current package fixture source is compiler-tracked, source contracts distinguish safe controls from proof fabrication, and the canonical release gate is green. | release-contract parity | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs:1228 test/chimeway/release_gate_contract_test.exs:1622 --warnings-as-errors && scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors && mix format --check-formatted scripts/prove-accrue-consumer.exs test/support/artifact_consumer_fixture.ex test/chimeway/release_gate_contract_test.exs && mix ci.verify_gates` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Requirement Coverage

| Requirement | Automated evidence | Classification |
|-------------|--------------------|----------------|
| ADPT-01 | Selector ownership/order contracts plus unchanged proof-path integration | COVERED |
| ADPT-02 | Exact command, sanitized record, exclusion, and guide-link contracts | COVERED |
| GATE-01 | Focused and aggregate package proofs, archive security/TOCTOU/resource tests, and redacted CLI failures | COVERED |
| GATE-02 | CI topology mutation contracts plus exact-SHA successful Adoption proof paths and `pr-gate` jobs | COVERED |
| DOCS-01 | Documentation, package-surface, task/runner, archive, source-parity, and CI-entrypoint contracts in the canonical gate | COVERED |

No missing or partial requirement coverage was found. All five requirements have current executable evidence, and no objectively machine-testable item remains conversational or manual-only.

---

## Lane Ownership

- `mix ci.verify_gates` owns structural, mutation, archive-security, redaction, source-parity, and documentation contracts.
- `Adoption proof paths` owns the expensive packaged Core → Mailglass → Accrue E2E exactly once per pull request.
- `pr-gate` consumes the adoption job result, so skipped, failed, duplicated, or wrong-SHA proof evidence cannot sign acceptance.
- `scripts/ci/assert-adoption-run.sh` accepts only a completed successful pull-request run for the exact supplied SHA with one successful adoption job and one successful `pr-gate`.

---

## Evidence

- Current canonical local gate: `mix ci.verify_gates` — 618 tests, 0 failures, 1 dedicated E2E excluded.
- Direct adoption behavior is covered locally in the Plan 96-01 evidence and on the hosted PostgreSQL lane.
- Current hosted implementation backstop: `scripts/ci/assert-adoption-run.sh 8371af59b1dbe7ac3b24decaae538a53da28b987`.
- Hosted result: `ADOPTION_RUN_PROOF ... run_id=31509666185 adoption=success pr_gate=success`.
- Run URL: https://github.com/szTheory/chimeway/actions/runs/31509666185
- All commits after the asserted implementation SHA are Phase 96.1/95 planning, review, verification, or validation artifacts; no later implementation change invalidates the hosted result.

---

## Manual-Only Verifications

None. Human review is reserved for subjective behavior; Phase 96 acceptance is fully machine-readable.

---

## Validation Audit 2026-08-11

| Metric | Count |
|--------|-------|
| Planned tasks audited | 10 |
| Requirements audited | 5 |
| Gaps found | 0 |
| Resolved by new tests | 0 |
| Escalated | 0 |

The legacy validation map collapsed ten planned tasks into five coarse behaviors and used `status: complete`, which the current Nyquist discovery contract classifies as NOT-VALIDATED. This audit expanded the task map across all five waves, reran the exact canonical local gate, asserted the post-closure hosted implementation SHA, and found no missing or partial coverage. No Nyquist auditor spawn or generated test file was required.

---

## Validation Sign-Off

- [x] All 10 tasks have exact automated verification commands.
- [x] ADPT-01, ADPT-02, GATE-01, GATE-02, and DOCS-01 are COVERED.
- [x] Sampling continuity has no three consecutive tasks without automated verification.
- [x] Structural contracts and behavioral E2E remain explicitly separated and jointly green.
- [x] Hosted evidence is pinned to the implementation SHA and asserted programmatically.
- [x] No watch-mode flags are used.
- [x] No manual-only acceptance remains.
- [x] `status: validated`, `nyquist_compliant: true`, and `wave_0_complete: true` are set in frontmatter.

**Approval:** automated evidence complete
