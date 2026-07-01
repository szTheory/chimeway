---
phase: 75
slug: runtime-prefix-propagation
status: verified
threats_open: 0
asvs_level: 1
block_on: open
created: 2026-07-01
verified: 2026-07-01
---

# Phase 75 - Security

Per-phase security contract: verify Phase 75 plan-time threat mitigations against implementation/test code. This audit did not create a new threat register beyond explicit plan threats because every Phase 75 plan contains a parseable `<threat_model>` block and every summary `## Threat Flags` section reports none.

## Scope

- Phase directory: `.planning/phases/75-runtime-prefix-propagation`
- Plans read: `75-01-PLAN.md` through `75-08-PLAN.md`
- Summaries read: `75-01-SUMMARY.md` through `75-08-SUMMARY.md`
- Output file: `.planning/phases/75-runtime-prefix-propagation/75-SECURITY.md`
- Register rows reviewed: 33 plan rows, coalesced to 26 unique threat IDs because `T-75-SC` is repeated in all eight plans with the same accepted disposition
- Threat flags reviewed: 8 summary sections, all `None`

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Application config -> Repo options | Static `:chimeway, :prefix` config becomes Ecto repo operation defaults. | Storage prefix, repo opts |
| Public Chimeway APIs -> storage | Trigger, inbox, recovery, policy, preference, digest, and webhook paths persist Chimeway-owned rows without caller-supplied DB prefix. | Notification params, IDs, lifecycle facts |
| Worker args -> Chimeway storage | Durable IDs cross Oban boundaries and workers reload canonical rows from Chimeway storage. | `delivery_id`, `signal_id`, `workflow_run_id`, `bucket_id`, `ingress_id` |
| Chimeway runtime -> Oban job table | Direct `Oban.Job` reads/deletes must use Oban's job-table configuration, not Chimeway table prefix. | Oban job rows and args |
| Operator/admin reads -> DTOs | Persisted lifecycle rows become admin, trace, inbox, and recovery read models. | Tenant-scoped DTO fields, redacted operator facts |
| Provider/policy facts -> diagnostics | Webhook, provider, policy, and suppression facts may cross into telemetry/logs/tests. | Normalized status, IDs, reason atoms, no raw payloads |
| Maintainer CLI -> test database | `mix verify.runtime_prefix` runs DB-backed prefix proof. | Focused runtime-prefix test output |

## Threat Register

| Threat ID | Category | Component | Disposition | Status | Evidence |
|-----------|----------|-----------|-------------|--------|----------|
| T-75-01 | Information Disclosure | PrefixedRuntimeCase and runtime integration tests | mitigate | closed | `test/support/prefixed_runtime_case.ex:49` defines schema-qualified prefixed counts; `test/support/prefixed_runtime_case.ex:72` asserts public count is zero; `test/chimeway/runtime_prefix_integration_test.exs:180` applies the assertion to runtime rows. |
| T-75-02 | Tampering | Prefix test setup | mitigate | closed | `test/support/prefixed_runtime_case.ex:31` sets and restores prefix with `on_exit`; `test/support/prefixed_runtime_case.ex:224` restores temporary prefix in `after`; `test/chimeway/repo_prefix_test.exs:60` rejects schema prefix/wrapper repo shapes. |
| T-75-03 | Information Disclosure | Operator-surface test assertions | mitigate | closed | `test/chimeway/runtime_prefix_integration_test.exs:147` defines forbidden operator keys; `test/chimeway/runtime_prefix_integration_test.exs:358` checks admin/recovery DTOs; `test/chimeway/runtime_prefix_integration_test.exs:818` recursively rejects forbidden keys. |
| T-75-04 | Information Disclosure | `Chimeway.Repo.default_options/1` | mitigate | closed | `lib/chimeway/repo.ex:7` leaves transactions unprefixed; `lib/chimeway/repo.ex:8` delegates ordinary ops to `Chimeway.Storage.repo_opts/1`; `test/chimeway/repo_prefix_test.exs:24` and `:32` verify prefixed and public fallback modes. |
| T-75-05 | Tampering | `Chimeway.trigger/3` opts | mitigate | closed | `lib/chimeway/trigger.ex:48` accepts ordinary opts; `lib/chimeway/trigger.ex:55` fetches idempotency/tenant opts only; source scan found no `prefix` token in `lib/chimeway/trigger.ex`. |
| T-75-06 | Repudiation | Duplicate idempotency lookup | mitigate | closed | `lib/chimeway/trigger.ex:250` classifies duplicate idempotency conflicts and `:251` reloads the event through `Repo.get_by/2`; `test/chimeway/runtime_prefix_integration_test.exs:185` asserts duplicate returns the same prefixed event. |
| T-75-07 | Information Disclosure | Admin and traces | mitigate | closed | `lib/chimeway/admin.ex:5` documents DTO redaction; `lib/chimeway/admin.ex:42` applies tenant filtering; `lib/chimeway/admin.ex:318` filters domain opts before `Chimeway.Storage.repo_opts/1`; `lib/chimeway/traces.ex:943` does the same for traces. |
| T-75-08 | Elevation of Privilege | Inbox and recovery recipient/tenant predicates | mitigate | closed | `lib/chimeway/inbox.ex:111` predicates by `recipient_identity`; `lib/chimeway/inbox.ex:144` enforces recipient identity on lifecycle updates; `lib/chimeway/deliveries.ex:341` and `:358` scope recovery queries by tenant. |
| T-75-09 | Information Disclosure | Recovery/operator metadata | mitigate | closed | `lib/chimeway/deliveries.ex:893` returns allowlisted recovery metadata; `lib/chimeway/deliveries.ex:968` stamps only source, reason, recovered_at, actor_ref, and confirmation_marker. |
| T-75-10 | Tampering | Direct `Oban.Job` queries | mitigate | closed | `lib/chimeway/dispatch/oban.ex:174` passes `oban_job_repo_opts()` to direct `Repo.delete_all/2`; `lib/chimeway/dispatch/oban.ex:188` passes it to direct `Repo.all/2`; `lib/chimeway/dispatch/oban.ex:200` sources opts from `Oban.config/0` and `Oban.Repo.default_options/1`. |
| T-75-11 | Information Disclosure | Worker reloads | mitigate | closed | `lib/chimeway/dispatch/oban_worker.ex:113` accepts only `delivery_id` args and `:118` reloads delivery; `lib/chimeway/dispatch/deferred_resume_worker.ex:23` accepts only `delivery_id`; `test/chimeway/runtime_prefix_integration_test.exs:539` exercises the reload. |
| T-75-13 | Repudiation | `mix verify.runtime_prefix` | mitigate | closed | `mix.exs:103` defines the alias and `mix.exs:104` limits it to `repo_prefix_test.exs` and `runtime_prefix_integration_test.exs`; current audit run passed with 16 tests, 0 failures. |
| T-75-14 | Information Disclosure | Final test output | mitigate | closed | `mix.exs:103` runs only the focused runtime-prefix proof; `test/chimeway/runtime_prefix_integration_test.exs:147` forbids payload/provider/render/session/token keys in operator assertions; source scan found no `IO.inspect`, `dbg`, logger, or telemetry calls in that test file. |
| T-75-15 | Tampering | Existing verify aliases | mitigate | closed | `mix.exs:75` preserves `ci.test`; `mix.exs:100` preserves `verify.install_golden`; `mix.exs:119`, `:125`, `:132`, `:138`, `:144`, and `:150` preserve ecosystem `verify.*` aliases. |
| T-75-16 | Information Disclosure | Digest accumulation/emission | mitigate | closed | `test/chimeway/runtime_prefix_integration_test.exs:582` asserts digest source/bucket/member rows are prefixed-only; `test/chimeway/runtime_prefix_integration_test.exs:588` performs the digest worker with only `bucket_id`; `lib/chimeway/dispatch/oban.ex:148` builds digest flush jobs with only `bucket_id`. |
| T-75-17 | Information Disclosure | Webhook feedback processing | mitigate | closed | `lib/chimeway/webhooks.ex:36` stores normalized ingress attrs only; `lib/chimeway/webhooks.ex:53` queues `ProcessFeedbackWorker` with only `ingress_id`; `test/chimeway/runtime_prefix_integration_test.exs:620` asserts webhook ingress rows are prefixed-only. |
| T-75-18 | Tampering | Bulk digest operations | mitigate | closed | `lib/chimeway/digests/accumulation.ex:270` uses `Repo.insert_all/3` for memberships and `lib/chimeway/digests/accumulation.ex:296` uses `Repo.update_all/2`; these inherit the repo default hook at `lib/chimeway/repo.ex:8`. |
| T-75-19 | Information Disclosure | Policy/preference reads | mitigate | closed | `lib/chimeway/preferences.ex:31` reads preference rows by recipient/key/channel; `lib/chimeway/preferences.ex:69` reads category prefs by recipient/category; `test/chimeway/runtime_prefix_integration_test.exs:654` asserts preference rows are prefixed-only. |
| T-75-20 | Repudiation | Suppression decisions | mitigate | closed | `lib/chimeway/policy.ex:109` returns stable `:channel_disabled`; `lib/chimeway/policy.ex:152` preserves policy-setting suppression reason atoms; `test/chimeway/runtime_prefix_integration_test.exs:702` asserts `{:suppress, :channel_disabled}`. |
| T-75-21 | Information Disclosure | Policy telemetry/logs | mitigate | closed | `lib/chimeway/policy.ex:44` telemetry metadata contains IDs/key/category/correlation only; logger calls at `lib/chimeway/policy.ex:116`, `:135`, `:153`, and `:173` include only delivery ID and reason/category facts. |
| T-75-22 | Information Disclosure | Admin prefixed assertions | mitigate | closed | `test/chimeway/runtime_prefix_integration_test.exs:339` calls all admin read models under prefixed mode; `test/chimeway/runtime_prefix_integration_test.exs:358` checks returned DTOs; `test/chimeway/runtime_prefix_integration_test.exs:818` rejects sensitive keys recursively. |
| T-75-23 | Elevation of Privilege | Admin/recovery tenant predicates | mitigate | closed | `test/chimeway/runtime_prefix_integration_test.exs:337` uses tenant-scoped admin opts; `lib/chimeway/admin.ex:293` implements tenant filtering; `lib/chimeway/deliveries.ex:356` scopes recovery delivery queries by tenant. |
| T-75-24 | Repudiation | Recovery execution | mitigate | closed | `test/chimeway/runtime_prefix_integration_test.exs:269` executes `begin_recovery`; `:296` executes `recover_delivery`; `:321` executes `recover_event`; `lib/chimeway/deliveries.ex:968` persists recovery source/reason/recovered_at/actor evidence. |
| T-75-25 | Tampering | Worker durable IDs | mitigate | closed | `test/chimeway/runtime_prefix_integration_test.exs:445` asserts exact `signal_id` args; `:490` asserts exact `workflow_run_id` args; `:813` requires the arg map contain only the durable ID key. |
| T-75-26 | Information Disclosure | Test diagnostics and output | mitigate | closed | `test/chimeway/runtime_prefix_integration_test.exs:147` forbids raw payload/render/provider/session/token keys; source scan found no logging, telemetry, `IO.inspect`, or `dbg` diagnostics in the expanded runtime-prefix test file. |
| T-75-SC | Tampering | Package installs | accept | documented accepted risk | Phase 75 commit file lists contain no package manifest/lockfile changes; `git status --short mix.exs mix.lock package.json package-lock.json pnpm-lock.yaml yarn.lock` returned empty for those paths; accepted risk `AR-75-SC` is logged below. |

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-75-SC | T-75-SC | The repeated package-install threat is accepted as not applicable to Phase 75 implementation scope. The phase added runtime prefix code/tests and a Mix alias, with no package manager install activity and no package manifest/lockfile changes in the Phase 75 commit file lists. | GSD security audit | 2026-07-01 |

## Unregistered Flags

None. All eight `## Threat Flags` summary sections state no new security attack surface or explicit security issue.

## Verification Evidence

| Check | Result | Evidence |
|-------|--------|----------|
| Required artifacts loaded | pass | Read all eight Phase 75 PLAN files, all eight Phase 75 SUMMARY files, secure-phase workflow, and SECURITY template before writing this report. |
| Plan-time threat register extracted | pass | 33 register rows across eight `<threat_model>` blocks; 26 unique threat IDs after coalescing repeated `T-75-SC`. |
| Summary threat flags incorporated | pass | `rg` over Phase 75 summaries found all `## Threat Flags` sections report `None`. |
| Runtime prefix gate | pass | `mix verify.runtime_prefix` passed: 16 tests, 0 failures. Existing non-failing Threadline SQL Sandbox cleanup logs and one `sms_custom` fallback warning were observed. |
| Forbidden routing patterns | pass | `rg -n "@schema_prefix|schema_prefix|search_path" lib/chimeway mix.exs` returned no matches. |
| Public prefix API scan | pass | `rg -n "prefix:" lib/chimeway test/chimeway/runtime_prefix_integration_test.exs test/chimeway/repo_prefix_test.exs` found only config docs, explicit diagnostic tests, `Oban.Testing` public job-table prefix, and runtime-prefix label strings. |
| Package install/change scan | pass | Phase 75 commit file lists show no `mix.lock`, package manifest, or JS lockfile changes; package-manager threat is documented as accepted/not applicable. |

## Security Audit Trail

| Audit Date | Planned Rows | Unique Threats | Closed | Open | Unregistered Flags | Run By |
|------------|--------------|----------------|--------|------|--------------------|--------|
| 2026-07-01 | 33 | 26 | 26 | 0 | 0 | Codex security audit |

## Sign-Off

- [x] All planned threats have a disposition (`mitigate` or `accept`)
- [x] Mitigations verified against code/tests, not summary intent
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-07-01
