---
phase: "104"
slug: "crosswake-provider-feedback-recipe-truth"
status: validated
nyquist_compliant: true
wave_0_complete: true
created: "2026-09-13"
validated: "2026-09-13T03:45:00Z"
---

# Phase 104 — Validation Strategy

> Retroactive executable-evidence audit of the selected CrossWake provider-feedback recipe and its required release gate.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit on Elixir 1.19.5 / OTP 27; SQLite-backed CrossWake example-host integration tests |
| **Config files** | `test/test_helper.exs`; `../crosswake/examples/phoenix_host/test/test_helper.exs` |
| **Quick run command** | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/crosswake_provider_feedback_docs_contract_test.exs --warnings-as-errors` |
| **CrossWake behavior command** | `cd ../crosswake/examples/phoenix_host && DATABASE_PATH=<isolated-db> MIX_ENV=test mix test test/crosswake_example/chimeway/registry_test.exs test/crosswake_example/chimeway/provider_feedback_recipe_test.exs --warnings-as-errors` |
| **Fresh-remote command** | `mix verify.crosswake_provider_feedback_docs` |
| **Aggregate command** | `mix ci.verify_gates` |
| **Observed runtime** | Under 1 second focused; about 18 seconds fresh-remote; about 6 minutes documentation/release contracts |

## Sampling Rate

- **After verifier changes:** Run the 16 focused mutation and positive contract tests.
- **After recipe/registry changes:** Run the exact README recipe and registry suites against an isolated SQLite database.
- **After selector or workflow changes:** Run the live fresh-remote verifier, SHA equality proof, and workflow lint.
- **Before release:** Run `mix ci.verify_gates`; its named alias includes the same fresh-remote verifier required by hosted CI.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------------|-----------|-------------------|-------------|--------|
| 104-01-01 | 01 | 1 | DOCS-02 | The exact fenced README worker compiles and executes real redaction and registry boundaries; advisory feedback is audit-only; invalidation is exact; stale/mismatched scope fails closed; recursive unsafe metadata is absent. | Cross-repository DB integration | `cd ../crosswake/examples/phoenix_host && DATABASE_PATH=<isolated-db> MIX_ENV=test mix test test/crosswake_example/chimeway/registry_test.exs test/crosswake_example/chimeway/provider_feedback_recipe_test.exs --warnings-as-errors` | ✅ | ✅ green |
| 104-01-02 | 01 | 1 | DOCS-02 | The separately selected docs SHA and frozen physical SHA exactly equal their independently advertised canonical refs. | Remote integration | Exact `git ls-remote` equality command from 104-01 Plan Task 2 | ✅ | ✅ green |
| 104-02-01 | 02 | 2 | GATE-02 | Canonical selector bytes, exact clean detached HEAD, real AST calls, focused execution, stable non-echoing errors, and cleanup all fail closed under mutation. | Unit/integration mutation contract | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/crosswake_provider_feedback_docs_contract_test.exs --warnings-as-errors` | ✅ | ✅ green |
| 104-02-02 | 02 | 2 | GATE-02 | Local alias, named PR/push jobs, publish/release replay, and both aggregate gates require the same verifier while the physical lane remains separate. | Workflow/release contract | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/doc_contract_test.exs test/chimeway/release_gate_contract_test.exs --exclude adoption_paths_e2e --exclude accrue_packaged_cli --warnings-as-errors` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ warning*

## Acceptance and Decision Coverage

| Contract | Executable evidence |
|----------|---------------------|
| DOCS-02; D-01/D-02/D-04/D-05 | `provider_feedback_recipe_test.exs` extracts and compiles the exact README block, invokes the worker, reaches `Redaction.feedback_from_provider_attrs/1` and `Registry.apply_provider_feedback/2`, supplies both authority shapes, returns `:ok` only for `{:ok, _}`, and preserves error tuples. |
| DOCS-02; D-03/D-06/D-08 | Recipe and registry tests prove advisory audit-only behavior, exact session and installation invalidation, wrong binding/installation/application/session/context denial without mutation, and allowlist-only recursive evidence. All fixtures use synthetic opaque values. |
| DOCS-02; D-09/D-10/D-11/D-12 | The selected docs file equals canonical `phase-104-provider-feedback-recipe-truth` at `36841e065ad4a71b58b80bd599d111c8ee178390`; the physical selector and canonical physical ref independently remain `3165ab6938fa673f8a289c27699658bb78650ef3`. |
| GATE-02; D-05/D-07 | Sixteen verifier tests now cover positive execution plus fictional API, each missing mandatory authority key, missing session guidance, absent proof, string-only proof, either missing executable boundary, malformed/substituted authorities, unexpected CLI arguments, wrong detached HEAD, dirty checkout, and cleanup after failed focused execution. |
| GATE-02; D-09/D-10 | `mix verify.crosswake_provider_feedback_docs` cloned the canonical remote, detached the exact selected SHA, checked a clean tree, executed the focused proof, and emitted `crosswake_provider_feedback_docs_verified`. |
| GATE-02; local/hosted parity | Documentation/release contracts inspect the Mix aliases and fail-closed `pr-gate`/`ci-gate` dependencies. `actionlint` accepted CI, publish, and release workflow files. |

## Wave 0 Requirements

- [x] Existing CrossWake recipe and registry suites cover real conversion, exact authority, both scope shapes, mismatched denial, and evidence sanitization.
- [x] Existing Chimeway mutations reject fictional/incomplete/vacuous remote source.
- [x] Added canonical selector-byte mutations (missing newline, extra newline, uppercase).
- [x] Added wrong-revision and dirty-checkout mutations.
- [x] Added unexpected-argument/non-echo behavior and cleanup-after-failure coverage.

## Manual-Only Verifications

None. Recipe behavior, remote reachability, immutable authority, workflow parity, and privacy boundaries are machine-observable.

## Validation Audit 2026-09-13

| Metric | Count |
|--------|-------|
| Gaps found | 4 |
| Resolved | 4 |
| Escalated | 0 |

### Tests Added

| Gap | Behavioral proof | File | Result |
|-----|------------------|------|--------|
| Strict one-line lowercase selector format had only broad malformed/substitution coverage. | Missing newline, extra newline, and uppercase selector bytes are rejected before focused execution. | `test/chimeway/crosswake_provider_feedback_docs_contract_test.exs` | ✅ green |
| Exact detached/clean checkout requirements were exercised positively but not mutation-negative. | Wrong HEAD and tracked-change status each stop before focused execution. | `test/chimeway/crosswake_provider_feedback_docs_contract_test.exs` | ✅ green |
| The public Mix task's wrong-argument and non-echo contract lacked a direct test. | A seeded recipient-like argument exits 64 and emits no output. | `test/chimeway/crosswake_provider_feedback_docs_contract_test.exs` | ✅ green |
| Temporary checkout cleanup after a downstream execution failure was unasserted. | A failed focused proof still invokes cleanup exactly through the checked-out root. | `test/chimeway/crosswake_provider_feedback_docs_contract_test.exs` | ✅ green |

### Commands Executed

| Command | Observed Result |
|---------|-----------------|
| Focused Chimeway verifier contract | 16 tests, 0 failures |
| Focused docs/release contract set | 670 tests, 0 failures, 4 excluded |
| CrossWake registry plus exact README recipe with isolated `DATABASE_PATH` | 14 tests, 0 failures |
| `mix verify.crosswake_provider_feedback_docs` | Exit 0; `crosswake_provider_feedback_docs_verified` |
| Exact docs/physical `git ls-remote` equality check | Exit 0; both advertised heads equal their selectors |
| `actionlint` on CI, release, and publish workflows | Exit 0 |

### Warning

A first diagnostic run of the CrossWake tests against the long-lived sibling checkout's reused SQLite file failed because the process-local `unique_integer/1` correlation value collided with a row left by an earlier BEAM invocation. The same 14 behavioral tests passed against a fresh isolated database, and the required Chimeway verifier always uses a fresh checkout/database and passed repeatedly. This is a local CrossWake test-fixture hermeticity caveat, not a product or selected-revision failure; no immutable remote selector was moved during validation.

## Validation Sign-Off

- [x] Every task has an executable automated command.
- [x] Every roadmap success criterion maps to behavioral evidence.
- [x] All four identified Chimeway verifier gaps were filled by tests that ran green.
- [x] No implementation files were modified during the audit.
- [x] No watch-mode commands are present.
- [x] The selected documentation and physical-proof authorities remain independent and exact.
- [x] `nyquist_compliant: true` is set in frontmatter.

**Approval:** validated 2026-09-13
