---
phase: 74
slug: prefixed-migration-generator
status: planned
nyquist_compliant: true
wave_0_complete: true
created: 2026-06-30
updated: 2026-06-30
---

# Phase 74 - Validation Strategy

> Planning-time validation contract for feedback sampling during execution. This file maps every Phase 74 requirement and every revised task to automated verification. It does not claim implementation tests have already passed.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit bundled with Elixir 1.17+ |
| **Config file** | `config/test.exs` configures `Chimeway.Repo` with `Ecto.Adapters.SQL.Sandbox` |
| **Focused installer command** | `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/install/migrations_test.exs --warnings-as-errors` |
| **Fixture command** | `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/install/golden_diff_test.exs test/chimeway/install/idempotency_test.exs --warnings-as-errors` |
| **Static and DB command** | `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/install/prefix_contract_test.exs test/chimeway/migration_contract_test.exs --warnings-as-errors` |
| **Local verify gate** | `mix verify.install_golden` planned in 74-10 |
| **CI parity gate** | `mix ci.install_golden` and `.github/workflows/ci.yml` `install_golden_contract` planned in 74-10 |
| **Estimated runtime** | focused commands: < 60 seconds each; fixture/DB gates: ~1-3 minutes depending on subprocess and database setup |

---

## Sampling Rate

- **After Plan 74-01:** run focused installer tests, targeted format, and runtime-config negative grep from 74-01.
- **After each wave-2 template plan:** run the plan-specific template format command plus focused installer tests.
- **After Plan 74-09:** run fixture refresh once, then run non-refresh golden and idempotency comparison.
- **After Plan 74-10:** run static/DB proof, `mix verify.install_golden`, and `mix ci.install_golden`.
- **Before `/gsd:verify-work`:** run the final phase gate:
  `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/install/migrations_test.exs test/chimeway/install/golden_diff_test.exs test/chimeway/install/idempotency_test.exs test/chimeway/install/prefix_contract_test.exs test/chimeway/migration_contract_test.exs --warnings-as-errors`
- **Max feedback latency:** keep focused commands under 3 minutes; use CI PostgreSQL 15 as authoritative for final DB contract proof if local PostgreSQL is below the project baseline.

---

## Requirement Coverage Map

| Requirement | Covered By | Required Automated Proof |
|-------------|------------|--------------------------|
| MIG-01 | 74-01-01, 74-02-01, 74-09-01, 74-09-02, 74-10-01 | CLI mode tests, prefixed fixture, prefixed DB migration proof |
| MIG-02 | 74-02-01 through 74-08-01, 74-09-02, 74-10-01 | Template format, prefixed fixture, static generated-output contract, prefixed DB migration proof |
| MIG-03 | 74-01-01, 74-02-01 through 74-09-02, 74-10-01 | CLI public mode tests, public fixture, generated public DB migration proof |
| MIG-04 | 74-09-01, 74-09-02, 74-10-01 | Dual-mode golden/idempotency tests, static proof, DB proof, verify/CI parity |

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 74-01-01 | 74-01 | 1 | MIG-01, MIG-03 | T-74-01..03 | CLI mode is closed-set and independent of runtime prefix config | unit + subprocess + source gate | `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/install/migrations_test.exs --warnings-as-errors`; `mix format --check-formatted lib/mix/tasks/chimeway.gen.migrations.ex lib/chimeway/install/migrations.ex test/chimeway/install/migrations_test.exs`; runtime-config negative grep from plan | existing files | planned, not run |
| 74-02-01 | 74-02 | 2 | MIG-01, MIG-02, MIG-03 | T-74-04..06 | Files 001-005 create schema and helper-qualify foundational operations without schema-drop SQL | format + focused installer | `mix format --check-formatted priv/chimeway_migrations/001_create_chimeway_events.exs priv/chimeway_migrations/002_create_chimeway_notifications.exs priv/chimeway_migrations/003_create_chimeway_deliveries.exs priv/chimeway_migrations/004_create_chimeway_delivery_attempts.exs priv/chimeway_migrations/005_create_chimeway_notification_preferences.exs`; focused installer command | existing templates | planned, not run |
| 74-03-01 | 74-03 | 2 | MIG-02, MIG-03 | T-74-07..09 | Files 006-010 helper-qualify early operations and fixed-helper attempt-history SQL | format + focused installer | `mix format --check-formatted priv/chimeway_migrations/006_add_correlation_id_to_chimeway_events.exs priv/chimeway_migrations/007_create_chimeway_category_preferences.exs priv/chimeway_migrations/008_create_chimeway_policy_settings.exs priv/chimeway_migrations/009_add_attempt_history_columns.exs priv/chimeway_migrations/010_add_delivery_orchestration_fields_to_chimeway_deliveries.exs`; focused installer command | existing templates | planned, not run |
| 74-04-01 | 74-04 | 2 | MIG-02, MIG-03 | T-74-10..11 | Files 011-015 helper-qualify time-zone and digest operations | format + focused installer | `mix format --check-formatted priv/chimeway_migrations/011_add_time_zone_to_chimeway_policy_settings.exs priv/chimeway_migrations/012_create_chimeway_digest_rules.exs priv/chimeway_migrations/013_create_chimeway_digest_buckets.exs priv/chimeway_migrations/014_create_chimeway_digest_memberships.exs priv/chimeway_migrations/015_alter_chimeway_digest_buckets_for_emission.exs`; focused installer command | existing templates | planned, not run |
| 74-05-01 | 74-05 | 2 | MIG-02, MIG-03 | T-74-12..13 | Files 016-020 helper-qualify digest resolution and rendering alters | format + focused installer | `mix format --check-formatted priv/chimeway_migrations/016_alter_chimeway_digest_memberships_for_resolution.exs priv/chimeway_migrations/017_alter_chimeway_deliveries_for_digest_outcome.exs priv/chimeway_migrations/018_add_rendering_contract_fields.exs priv/chimeway_migrations/019_add_render_channels_to_chimeway_notifications.exs priv/chimeway_migrations/020_add_orchestration_snapshot_to_chimeway_notifications.exs`; focused installer command | existing templates | planned, not run |
| 74-06-01 | 74-06 | 2 | MIG-02, MIG-03 | T-74-14..15 | Files 021-025 helper-qualify workflow operations | format + focused installer | `mix format --check-formatted priv/chimeway_migrations/021_create_chimeway_workflow_definitions.exs priv/chimeway_migrations/022_create_chimeway_workflow_steps.exs priv/chimeway_migrations/023_add_workflow_definition_id_to_chimeway_notifications.exs priv/chimeway_migrations/024_create_chimeway_workflow_runs.exs priv/chimeway_migrations/025_create_chimeway_workflow_transitions.exs`; focused installer command | existing templates | planned, not run |
| 74-07-01 | 74-07 | 2 | MIG-02, MIG-03 | T-74-16..18 | Files 026-030 helper-qualify operations and fixed-helper raw SQL | format + focused installer | `mix format --check-formatted priv/chimeway_migrations/026_alter_chimeway_deliveries_for_workflow_linkage.exs priv/chimeway_migrations/027_create_chimeway_signals_and_spine.exs priv/chimeway_migrations/028_add_adapter_module_to_chimeway_delivery_attempts.exs priv/chimeway_migrations/029_add_provider_message_id_to_delivery_attempts.exs priv/chimeway_migrations/030_add_tenant_and_actor_to_chimeway_deliveries.exs`; focused installer command | existing templates | planned, not run |
| 74-08-01 | 74-08 | 2 | MIG-02, MIG-03 | T-74-19..21 | File 031 helper-qualifies webhook ingress operations | format + focused installer | `mix format --check-formatted priv/chimeway_migrations/031_create_chimeway_webhook_ingress.exs`; focused installer command | existing template | planned, not run |
| 74-09-01 | 74-09 | 3 | MIG-01, MIG-03, MIG-04 | T-74-22..24 | Fixture helper and installer tests cover real subprocess modes and idempotency | golden + idempotency + format | `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/install/golden_diff_test.exs test/chimeway/install/idempotency_test.exs --warnings-as-errors`; `mix format --check-formatted test/support/installer_fixture.ex test/chimeway/install/golden_diff_test.exs test/chimeway/install/idempotency_test.exs` | existing tests need expansion | planned, not run |
| 74-09-02 | 74-09 | 3 | MIG-01, MIG-02, MIG-03, MIG-04 | T-74-22..24 | Mode-named fixtures prove prefixed and public output shapes | golden refresh + golden compare | `MIX_INSTALLER_ACCEPT_GOLDEN=1 CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/install/golden_diff_test.exs --warnings-as-errors`; fixture command | fixture roots created by task | planned, not run |
| 74-10-01 | 74-10 | 4 | MIG-01, MIG-02, MIG-03, MIG-04 | T-74-25..29 | Static, prefixed DB, public DB, verify alias, and CI parity contracts are executable | static + DB + verify/CI aliases | static and DB command; `mix verify.install_golden`; `mix ci.install_golden`; `mix format --check-formatted test/chimeway/install/prefix_contract_test.exs test/chimeway/migration_contract_test.exs mix.exs` | `prefix_contract_test.exs` created by task; others existing | planned, not run |

---

## Wave 0 Status

Planning Wave 0 is complete: every missing validation artifact from research is assigned to an executable plan and every plan task has automated verification.

| Artifact | Creating Plan/Task | Follow-on Proof |
|----------|--------------------|-----------------|
| `test/chimeway/install/prefix_contract_test.exs` | 74-10-01 | static generated-output command and `verify.install_golden` |
| `test/fixtures/installer_golden_prefixed/` | 74-09-02 | golden compare, static contract, prefixed DB proof |
| `test/fixtures/installer_golden_public/` | 74-09-02 | golden compare, generated public DB proof |
| `test/support/installer_fixture.ex` option support | 74-09-01 | golden/idempotency command and `verify.install_golden` |
| Prefixed migration contract setup | 74-10-01 | generated prefixed Ecto.Migrator DB proof |
| Generated public migration contract setup | 74-10-01 | generated public Ecto.Migrator DB proof |
| `mix verify.install_golden` local parity alias | 74-10-01 | `mix verify.install_golden` and `mix ci.install_golden` |

---

## Manual-Only Verifications

All phase behaviors have automated verification planned. The only non-automated judgment is final CI confirmation on PostgreSQL 15 when local PostgreSQL is below the project baseline.

---

## Validation Sign-Off

- [x] All tasks have automated verification or explicit dependency coverage.
- [x] Every Phase 74 requirement maps to at least one automated command.
- [x] Wave 0 validation gaps are assigned to concrete plan/task IDs.
- [x] No watch-mode flags are used.
- [x] Public-mode generated migrations are covered by DB proof, not only static or golden proof.
- [x] Planning-time Nyquist strategy is compliant.

**Approval:** planning strategy compliant; implementation execution not yet run.
