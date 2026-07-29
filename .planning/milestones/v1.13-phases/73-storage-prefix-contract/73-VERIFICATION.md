---
phase: 73-storage-prefix-contract
verified: 2026-06-30T19:15:38Z
status: passed
score: 8/8 must-haves verified
behavior_unverified: 0
overrides_applied: 0
---

# Phase 73: Storage Prefix Contract Verification Report

**Phase Goal:** Establish the public and internal contract for static Chimeway storage prefixes before changing migrations or runtime paths.
**Verified:** 2026-06-30T19:15:38Z
**Status:** passed
**Re-verification:** No - initial verification; no prior `73-VERIFICATION.md` existed.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Runtime prefix config accepts only `prefix: "chimeway"` and `prefix: false`. | VERIFIED | `Chimeway.Storage.validate_prefix!/0` fetches `:prefix` without a default and only returns `"chimeway"` or `false`; all other values call `invalid_prefix!/1` in `lib/chimeway/storage.ex:8-22`. `test/chimeway/storage_test.exs:37-87` covers accepted values, missing config, `nil`, `"public"`, arbitrary strings, function values, MFA-like tuples, and tenant-looking values. |
| 2 | Invalid or missing prefix config fails early with actionable structured errors. | VERIFIED | `Chimeway.ConfigError` preserves `:type`, `:key`, and `:value` fields and names both accepted snippets plus dynamic prefix rejection in `lib/chimeway/config_error.ex:9-39`. `Chimeway.Application.start/2` calls `Chimeway.Storage.validate_prefix!/0` before `children =` in `lib/chimeway/application.ex:9-16`. Boot-path tests cover invalid `"public"` and missing config in `test/chimeway/application_validation_test.exs:16-59`. |
| 3 | Runtime code has one centralized prefix/repo-option helper and does not hand-roll prefix config logic. | VERIFIED | `Chimeway.Storage.repo_opts/1` is the internal contract in `lib/chimeway/storage.ex:25-30`. `rg` found no direct runtime `Application.get_env/fetch_env(:chimeway, :prefix)` usage outside `Chimeway.Storage` and tests. Existing `repo_opts` helpers in `Chimeway.Admin`/`Chimeway.Traces` only drop non-repo query options; they do not read or normalize prefix config. |
| 4 | Current public-schema behavior is explicit legacy compatibility via `prefix: false`. | VERIFIED | `config/config.exs:3-7` sets `prefix: false`. `Chimeway.Storage.repo_opts/1` returns opts unchanged for `false`, so no Ecto `:prefix` is sent in public legacy mode (`lib/chimeway/storage.ex:27-30`). `test/chimeway/storage_test.exs:106-110` verifies no `:prefix` option is emitted. |
| 5 | Public-schema compatibility is represented in tests and docs as legacy mode, not an accidental default. | VERIFIED | Migration contract tests are explicitly named as legacy public-schema compatibility in `test/chimeway/migration_contract_test.exs:6-39`, while still checking `public` objects at `test/chimeway/migration_contract_test.exs:41-63`. README, installation, and golden path all say `prefix: false` is only for an existing public-schema legacy install. |
| 6 | Docs distinguish new isolated schema installs from existing public-schema legacy mode and state no automatic data movement occurs. | VERIFIED | `README.md:28-42`, `guides/introduction/installation.md:52-65`, and `guides/introduction/golden-path.md:62-75` show `prefix: "chimeway"` for new isolated installs and `prefix: false` for existing public-schema legacy installs, with "unprefixed tables" and "does not move data" language. `test/chimeway/doc_contract_test.exs:1012-1028` locks those required and forbidden phrases. |
| 7 | No dynamic per-tenant prefix API is introduced. | VERIFIED | Runtime validation rejects functions, MFA-like tuples, tenant-looking strings, and arbitrary strings in `test/chimeway/storage_test.exs:63-87`. Search found no public dynamic prefix API or runtime config reader outside `Chimeway.Storage`; `lib/chimeway/config_error.ex:37` explicitly states dynamic per-tenant database prefixes are unsupported. |
| 8 | Migration/generator behavior remains unchanged in Phase 73. | VERIFIED | Phase 73 commit/file inspection shows only `test/chimeway/migration_contract_test.exs` changed for migration contracts; no `priv/chimeway_migrations`, `lib/chimeway/install/migrations.ex`, or `lib/mix/tasks/chimeway.gen.migrations.ex` changes appear in the Phase 73 implementation commits. Current generator still parses with `strict: []` and rejects unexpected args in `lib/mix/tasks/chimeway.gen.migrations.ex:32-39`. No `--prefix` documentation or generated prefix behavior was added. |

**Score:** 8/8 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `lib/chimeway/config_error.ex` | Branded structured config error | VERIFIED | Exists and substantive. Exports `Chimeway.ConfigError.exception/1`; fields and message verified in code and tests. |
| `lib/chimeway/storage.ex` | Internal prefix validator and repo option contract | VERIFIED | Exists and substantive. Contains `validate_prefix!/0` and `repo_opts/1`; no schema-existence query, process state, or compile-time schema prefix. |
| `lib/chimeway/application.ex` | Early boot validation before child construction | VERIFIED | `Chimeway.Storage.validate_prefix!/0` is called before `children =`. No database schema checks were added. |
| `config/config.exs` | Explicit current public-schema config | VERIFIED | Contains top-level `config :chimeway, prefix: false`. |
| `test/chimeway/storage_test.exs` | Unit contract for accepted/invalid values and repo opts | VERIFIED | Covers accepted values, invalid matrix, missing config, and repo option mapping. |
| `test/chimeway/application_validation_test.exs` | Boot-path validation coverage | VERIFIED | Covers invalid/missing prefix failure through `Chimeway.Application.start/2` and normal public config acceptance. |
| `README.md` | Runtime prefix install copy | VERIFIED | Shows both accepted snippets and public legacy no-move copy. |
| `guides/introduction/installation.md` | Installation prefix choice copy | VERIFIED | Shows both accepted snippets and public legacy no-move copy. |
| `guides/introduction/golden-path.md` | Golden-path prefix choice copy | VERIFIED | Shows both accepted snippets and public legacy no-move copy. |
| `test/chimeway/doc_contract_test.exs` | Doc contract assertions | VERIFIED | Locks storage-prefix required snippets and forbidden drift phrases. |
| `test/chimeway/migration_contract_test.exs` | Legacy public-schema compatibility contract naming | VERIFIED | Labels current public-schema checks as legacy compatibility and still asserts public objects. |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `lib/chimeway/storage.ex` | `lib/chimeway/config_error.ex` | Invalid prefix raises `Chimeway.ConfigError` | WIRED | `lib/chimeway/storage.ex:4` aliases `Chimeway.ConfigError`; `lib/chimeway/storage.ex:33-38` raises that alias with structured fields. |
| `lib/chimeway/storage.ex` | Later Ecto repo call sites | `repo_opts/1` returns keyword options suitable for future Repo use | WIRED | `lib/chimeway/storage.ex:25-30` returns `[prefix: "chimeway"]` via `Keyword.put_new/3` or unchanged opts for `false`; tests exercise both branches. |
| `lib/chimeway/application.ex` | `lib/chimeway/storage.ex` | Boot path calls `validate_prefix!/0` before children | WIRED | `lib/chimeway/application.ex:9-16` validates before the child list containing `Chimeway.Repo` and optional Oban is constructed. |
| `config/config.exs` | `lib/chimeway/storage.ex` | Explicit env value consumed by validator | WIRED | `config/config.exs:3-7` sets `prefix: false`; `lib/chimeway/storage.ex:10` fetches that key. |
| `test/chimeway/doc_contract_test.exs` | README and guides | Required strings for accepted snippets and no-move copy | WIRED | `test/chimeway/doc_contract_test.exs:1012-1028` locks required and forbidden phrases across README, installation, and golden path sections. |
| `test/chimeway/migration_contract_test.exs` | Current public migrations | Public schema checks named as legacy compatibility | WIRED | Test names and assertion message include legacy/public-schema compatibility while the SQL still checks `public` objects. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|---|---|---|---|---|
| `Chimeway.Storage.validate_prefix!/0` | `Application.fetch_env(:chimeway, :prefix)` | Application environment | Yes - explicit config only; missing config is rejected | VERIFIED |
| `Chimeway.Storage.repo_opts/1` | Validated prefix result | `validate_prefix!/0` | Yes - maps `"chimeway"` to Ecto prefix opts and `false` to unprefixed opts | VERIFIED |
| Docs/tests | Static contract text | README/guides and contract tests | N/A - static documentation contract | VERIFIED |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Phase 73 focused storage/docs/migration/application contracts pass | `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/storage_test.exs test/chimeway/application_validation_test.exs test/chimeway/doc_contract_test.exs test/chimeway/migration_contract_test.exs --warnings-as-errors` | 416 tests, 0 failures | PASS |
| Compile with warnings as errors | `MIX_ENV=test mix compile --warnings-as-errors` | Exit 0 | PASS |
| Orchestrator focused contract run | `MIX_ENV=test mix test ... --warnings-as-errors` | Reported 416 tests, 0 failures | PASS |
| Orchestrator compile gate | `mix compile --warnings-as-errors` | Reported passed | PASS |
| Orchestrator suite gate | `mix ci.test` | Reported 1057 tests, 0 failures, 41 excluded | PASS |

### Probe Execution

| Probe | Command | Result | Status |
|---|---|---|---|
| N/A | Probe discovery found no `scripts/*/tests/probe-*.sh`, and Phase 73 plans/summaries do not declare probes. | No probe entry points | SKIPPED |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|---|---|---|---|---|
| PFX-01 | 73-01, 73-02, 73-03 | Host apps can configure `prefix: "chimeway"` for default new installs or `prefix: false` for explicit public-schema legacy mode. | SATISFIED | Runtime validator accepts only those values; repo config is explicit `prefix: false`; docs show both snippets. |
| PFX-02 | 73-01, 73-02 | Validate prefix config early and fail with actionable errors for unsupported values. | SATISFIED | Structured `Chimeway.ConfigError`; invalid matrix; boot-path tests; application validates before child construction. |
| PFX-03 | 73-01 | One internal repo-option helper/equivalent contract; runtime code does not hand-roll prefix logic. | SATISFIED | `Chimeway.Storage.repo_opts/1`; search found no other runtime prefix config reads. |
| PFX-04 | 73-01, 73-03 | Public-schema installs remain supported without silent migration or changed runtime behavior when configured for legacy mode. | SATISFIED | `prefix: false` emits unprefixed repo opts; current public migration contract remains and is labeled legacy compatibility. |
| UPG-01 | 73-03 | Existing public-schema installs have an explicit compatibility path that does not move data automatically. | SATISFIED | README, installation, and golden path say `prefix: false` keeps using existing public/unprefixed tables and does not move data. |

No Phase 73 requirements are orphaned in `.planning/REQUIREMENTS.md`; the traceability table maps PFX-01, PFX-02, PFX-03, PFX-04, and UPG-01 to Phase 73.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---|---|---|---|
| N/A | N/A | No unreferenced `TBD`, `FIXME`, or `XXX` debt markers in Phase 73 files. | None | No blocker. |
| `test/chimeway/doc_contract_test.exs` | 491-498 | `placeholder` appears only in tests forbidding old placeholder language. | Info | Not a stub or incomplete implementation. |
| `guides/introduction/golden-path.md` | 177-178 | `JTBD` matched a naive `TBD` scan. | Info | False positive; not a debt marker. |

### Human Verification Required

None. This phase is a code/docs contract slice; all behavior-dependent truths have automated tests.

### Gaps Summary

No gaps found. Phase 73 achieved the storage-prefix contract goal: strict accepted runtime values, early structured failure, centralized helper, explicit public legacy compatibility, no silent data movement claims, no dynamic per-tenant prefix API, and no Phase 73 migration/generator behavior changes.

---

_Verified: 2026-06-30T19:15:38Z_
_Verifier: the agent (gsd-verifier)_
