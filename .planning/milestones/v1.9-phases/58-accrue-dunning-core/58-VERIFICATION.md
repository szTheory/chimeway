---
phase: 58
slug: accrue-dunning-core
status: passed
score: 38/38
requirements:
  ECOS-06: passed
verified_at: 2026-05-30
---

# Phase 58 Verification: Accrue Dunning Core (ECOS-06)

**Goal:** Accrue `invoice.payment_failed` starts a Chimeway dunning workflow; `invoice.paid` terminates it via Outcome Signal — no host glue.

**Status:** `passed` — all must-haves from plans 58-01, 58-02, and 58-03 verified against codebase and automated tests.

## Requirements Traceability

| Requirement | Description | Status | Evidence |
|-------------|-------------|--------|----------|
| **ECOS-06** | Billing failure starts dunning; payment success terminates via Outcome Signal without host callback glue | **passed** | `Accrue.Test.trigger_event(:invoice_payment_failed, …)` creates `WorkflowRun`; `Accrue.Test.trigger_event(:invoice_paid, …)` routes `invoice.paid` signal and blocks escalation — 11 accrue-tagged tests green |

## ROADMAP Success Criteria

| Criterion | Status | Evidence |
|-----------|--------|----------|
| SC #1: `invoice.payment_failed` starts dunning with explainable trace | **passed** | `accrue_dunning_lifecycle_test.exs` — WorkflowRun with `workflow_key: "accrue.dunning"`, non-empty `Workflows.explain/2` and `list_traces/2` |
| SC #2: `invoice.paid` terminates active dunning via Outcome Signal | **passed** | Terminate describe: run resumes `:active`, `pending_signals: []`, `status_reason: "signal_received"`, zero `escalation_email` deliveries |

## Plan 58-01 Must-Haves

| Truth / Artifact / Link | Status | Evidence |
|-------------------------|--------|----------|
| Optional `{:accrue, "~> 1.2", optional: true}` dep; compiles with/without Accrue (D-11) | **passed** | `mix.exs` `accrue_dep/0`; `mix compile --warnings-as-errors` exits 0 |
| `mix ci.test` excludes `:accrue`; `mix verify.accrue` runs `--only accrue` (D-11) | **passed** | `ci.test` alias line 62; `verify.accrue` lines 105–108 |
| Harness bootstraps TestRepo + `Config.dunning_engine/0` → `Accrue.Integrations.Chimeway` (D-12, D-13) | **passed** | `config/test.exs`, `test/test_helper.exs`, harness engine round-trip test |
| Accrue tests skip when dep absent — no compile-time coupling (D-02) | **passed** | Conditional `if Code.ensure_loaded?(Accrue)` wrappers; `mix ci.test` — 743 tests, 0 failures |
| `mix.exs` artifact: optional dep + `verify.accrue` alias | **passed** | `grep verify.accrue mix.exs` → line 105 |
| `test/support/accrue/data_case.ex` artifact: shared sandbox | **passed** | Dual `Sandbox.start_owner!` for `Accrue.TestRepo` + `Chimeway.Repo` |
| `test/support/accrue/fixtures.ex` artifact: `configure_chimeway_dunning_engine!/0` | **passed** | Customer/subscription/invoice helpers + progression helpers |
| `accrue_dunning_harness_test.exs` artifact: `@moduletag :accrue` | **passed** | 4 harness tests tagged `:accrue` |
| Key link: `verify.accrue` → accrue-tagged tests | **passed** | `mix verify.accrue` — 11 tests, 0 failures |
| Key link: `test_helper.exs` → `Accrue.TestRepo` bootstrap | **passed** | Conditional bootstrap + migrations in `test/test_helper.exs` |
| Key link: fixtures → `Accrue.Integrations.Chimeway` engine config | **passed** | `Application.put_env(:accrue, :dunning, engine: Accrue.Integrations.Chimeway, …)` |

## Plan 58-02 Must-Haves

| Truth / Artifact / Link | Status | Evidence |
|-------------------------|--------|----------|
| `DunningNotifier.workflow/2`: Email 1 → 48h `wait_until` → Email 2 + `cancel_signals: ["invoice.paid"]` (D-06) | **passed** | `../accrue/accrue/lib/accrue/integrations/chimeway.ex` lines 179–210; `delay_seconds: 172_800` |
| `DunningNotifier.rendering/2` enables `Chimeway.trigger/3` email path | **passed** | `rendering/2` returns `render_key: "accrue.dunning.initial_email"` |
| `trigger_event(:invoice_payment_failed, …)` creates explainable `WorkflowRun` — no direct `Chimeway.trigger/3` in primary proof (D-04, D-05, D-12) | **passed** | Lifecycle start describe uses `trigger_invoice_payment_failed_event!/4` |
| Duplicate `payment_failed` idempotent via `accrue.dunning:{subscription_id}:{anchor_iso}` (D-05) | **passed** | Idempotency test + `start_campaign/3` `{:duplicate, _}` → `:ok` |
| After first email terminal + progression, run `:waiting` with `pending_signals == ["invoice.paid"]` (D-08) | **passed** | `wait_until sets pending_signals after initial email delivery` test |
| Accrue `chimeway.ex` artifact: `workflow/2`, `rendering/2`, `cancel_signals` | **passed** | `grep cancel_signals` / `172_800` in sibling repo |
| `accrue_dunning_lifecycle_test.exs` start describe artifact | **passed** | 3 start-path tests with `@moduletag :accrue` |
| Key link: `start_campaign/3` → `Chimeway.trigger/3` → `DunningNotifier` | **passed** | `chimeway.ex` lines 83–88 |
| Key link: lifecycle test → `Accrue.Test.trigger_event/2` | **passed** | `trigger_invoice_payment_failed_event!/4` |
| Key link: `workflow/2` wait_until → `pending_signals` via `invoice.paid` cancel_signals | **passed** | Progression test asserts `pending_signals == ["invoice.paid"]` |
| No `Chimeway.Adapter` seam added | **passed** | No new adapter module; workflow + Signal bridge only (D-01) |

## Plan 58-03 Must-Haves

| Truth / Artifact / Link | Status | Evidence |
|-------------------------|--------|----------|
| `cancel_campaign/3` emits `Chimeway.Signal.track/4` with `event_name: "invoice.paid"`, `actor_id` = customer email (D-09) | **passed** | `chimeway.ex` lines 97–111; zero `payment_recovered` matches |
| `trigger_event(:invoice_paid, …)` terminates via Outcome Signal — no host glue (D-08, D-10, D-12) | **passed** | Terminate describe primary entry via `trigger_invoice_paid_event!/4` |
| Matched `:waiting` run → `:active`, `pending_signals: []`, `status_reason: "signal_received"`, context `%{"event_name" => "invoice.paid"}` only | **passed** | `invoice_paid via Accrue webhook path resumes waiting run` test |
| No `escalation_email` delivery after signal before `due_at` | **passed** | `no escalation email delivery after invoice_paid termination` + `signal before due_at` tests |
| Accrue `cancel_campaign/3` artifact | **passed** | `grep invoice.paid` in `cancel_campaign/3` body |
| Lifecycle terminate describe artifact | **passed** | 4 terminate-path tests in `accrue_dunning_lifecycle_test.exs` |
| Key link: `cancel_campaign/3` → `Chimeway.Signal.track/4` | **passed** | Accrue unit test inserts signal row with correct shape |
| Key link: `route_signal/1` matches `pending_signals` on `invoice.paid` | **passed** | Oban drain + run state transition after signal |
| Key link: terminate test → `SignalRouterWorker` via Oban drain | **passed** | `Oban.drain_queue(queue: :chimeway_signals)` in terminate tests |

## Automated Gates

| Gate | Result |
|------|--------|
| `ACCRUE_PATH=/Users/jon/projects/accrue/accrue mix verify.accrue` | PASS (11 tests, 0 failures) |
| `mix ci.test` | PASS (743 tests, 0 failures; accrue excluded) |
| `mix compile --warnings-as-errors` | PASS |
| `CHIMEWAY_PATH=/Users/jon/projects/chimeway mix test test/accrue/integrations/chimeway_test.exs --warnings-as-errors` (Accrue repo) | PASS (4 tests, 0 failures) |
| `mix test test/chimeway/workflows_test.exs --warnings-as-errors` (T-27-03 regression) | PASS (13 tests, 0 failures) |
| `grep verify.accrue mix.exs` | PASS (line 105) |
| `grep @moduletag :accrue test/` | PASS (harness + lifecycle files) |
| `grep payment_recovered ../accrue/accrue/lib/accrue/integrations/chimeway.ex` | PASS (0 matches) |

## Human Verification

None required — all ECOS-06 library-level acceptance criteria are automated via `mix verify.accrue`.

## Notes

- Cross-repo dev requires path deps: `ACCRUE_PATH=…/accrue/accrue mix deps.get` (Chimeway) and `CHIMEWAY_PATH=…/chimeway mix deps.get` (Accrue).
- Accrue-side changes live in sibling repo `../accrue/accrue` — verified via path dep during `mix verify.accrue`.
- ECOS-06 checkbox in `.planning/REQUIREMENTS.md` remains at planning-doc level; functional closure verified here. Phases 59–60 (demo proof, docs, GATE-05 CI wiring) are out of scope for Phase 58.
- `DefaultHandler` invoice.paid recovery hook (`maybe_recover_dunning_on_invoice_paid/2`) added in 58-03 — enables primary webhook-path terminate proof per D-12.
