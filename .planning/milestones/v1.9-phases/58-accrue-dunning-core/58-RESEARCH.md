# Phase 58: Accrue Dunning Core — Research

**Researched:** 2026-05-29  
**Phase:** 58-accrue-dunning-core  
**Requirement:** ECOS-06  
**Status:** Ready for planning

---

## 1. Executive Summary

Phase 58 closes the gap between Accrue’s **v1.40 email-only `:immediate` Chimeway adapter** and the **SEED-003 dunning blueprint**: `invoice.payment_failed` starts a multi-step Chimeway workflow; `invoice.paid` cancels escalation via the existing Signal + `cancel_signals` spine — **no `Chimeway.Adapter` seam and no host callback glue**.

The work is **cross-repo** (Accrue `DunningNotifier` + `cancel_campaign/3`; Chimeway optional dep + selective CI) but **Chimeway-core-minimal**: reuse `Chimeway.trigger/3`, `Workflows.create_initial_run/5`, `Progression.enter_waiting/6`, `Signal.track/4`, and `Workflows.route_signal/1` unchanged [VERIFIED: codebase grep].

**Planner takeaway:** Treat “terminate” as **READ/cancel semantics** (JOUR-06): `invoice.paid` resumes the run to `:active` on the first step, clears `pending_signals`, records `signal_received`, and **blocks the escalation email** — not necessarily `:stopped`/`:completed` unless Wave 58-03 acceptance proves insufficient [CITED: 58-CONTEXT.md deferred section].

**Three waves (ROADMAP):** harness (58-01) → start path (58-02) → termination proof (58-03).

---

## 2. Standard Stack

| Layer | Choice | Notes |
|-------|--------|-------|
| Language | Elixir ~> 1.17, OTP 26+ | Matches `mix.exs` + AGENTS.md [CITED: mix.exs] |
| Persistence | Ecto 3.x + PostgreSQL 15+ | Chimeway `Repo` + Accrue `TestRepo` in tests [CITED: config/test.exs] |
| Async | Oban 2.x (optional, recommended) | `SignalRouterWorker` queue `:chimeway_signals`; Accrue Fake processor [VERIFIED: codebase grep] |
| Billing | Accrue ~> 1.2 (optional dep) | `Accrue.Integrations.Chimeway` conditionally compiled when `Code.ensure_loaded?(Chimeway)` [CITED: accrue/lib/accrue/integrations/chimeway.ex] |
| Orchestration | Chimeway workflow + Signal engine | v1.7–v1.8 spine; no new DSL [CITED: ROADMAP Phase 58] |
| Email delivery (optional) | Mailglass / Logger adapter | Phase 58 does not require Mailglass; tests can use `Chimeway.Adapters.Logger` + `rendering/2` on `DunningNotifier` [CITED: 58-CONTEXT.md D-07] |
| Test events | `Accrue.Test.trigger_event/2` | Synthetic webhook through `Ingest` + `DefaultHandler` — not direct DB mutation [CITED: accrue/lib/accrue/test/webhooks.ex] |

**OTP patterns:**

- **Optional ecosystem dep:** `Code.ensure_loaded?/1` gate at compile time (Mailglass in Chimeway; Chimeway in Accrue) [VERIFIED: codebase grep].
- **Engine behaviour seam:** `Accrue.Dunning.Engine` — `start_campaign/3` and `cancel_campaign/3` only; Accrue owns anchor/idempotency [CITED: accrue/lib/accrue/dunning/engine.ex].
- **Durable signal bridge:** `Ecto.Multi` persist signal + Oban enqueue in one transaction [CITED: lib/chimeway/signal.ex].
- **Selective CI:** `@moduletag :accrue` excluded from default `ci.test`; dedicated `mix verify.accrue` (GATE-05 wiring deferred to Phase 60) [CITED: 58-CONTEXT.md D-11, mix.exs Mailglass pattern].

---

## 3. Architecture Patterns

### 3.1 Start path: Accrue billing → Chimeway workflow

```
invoice.payment_failed (webhook)
  → DefaultHandler.maybe_start_dunning_campaign/2
  → Config.dunning_engine().start_campaign(sub, anchor, opts)
  → Accrue.Integrations.Chimeway.start_campaign/3
  → Chimeway.trigger(DunningNotifier, params, idempotency_key:, tenant_id: customer_id)
  → Trigger.insert_notifications → resolve_workflow → Workflows.ensure_definition
  → Workflows.create_initial_run (when workflow/2 present)
  → dispatch first-step delivery
```

[CITED: accrue/lib/accrue/webhook/default_handler.ex L1250–1264] [CITED: lib/chimeway/trigger.ex L150–348] [CITED: accrue/lib/accrue/integrations/chimeway.ex L75–91]

**Idempotency:** `accrue.dunning:{subscription_id}:{anchor_iso}` — duplicate `{:duplicate, _}` treated as `:ok` in adapter [CITED: accrue/lib/accrue/integrations/chimeway.ex L79–89].

**Tenancy:** `tenant_id` = `sub.customer_id` (Accrue customer UUID); `recipient_identity` = customer email from `DunningNotifier.recipients/1` [CITED: accrue/lib/accrue/integrations/chimeway.ex L133–144].

### 3.2 Mid-run: wait_until + pending_signals

After first email delivery reaches a **branchable terminal outcome**, `Progression.enter_waiting/6` sets:

- `state: :waiting`
- `status_reason: "waiting_for_step_progression"`
- `pending_signals` from rule’s `cancel_signals` (e.g. `["invoice.paid"]`)
- `status_context` with `due_at`, `to_step`, anchor metadata

[CITED: lib/chimeway/workflows/progression.ex L252–290] [CITED: lib/chimeway/notifier.ex L656–691]

### 3.3 Termination path: Outcome Signal (invoice.paid)

```
subscription recovery (invoice.paid / active transition)
  → DefaultHandler stashes {:accrue_dunning_cancel, {sub, iso_anchor}}
  → run_post_commit_dunning_cancel/1
  → Config.dunning_engine().cancel_campaign(sub, iso_anchor, [])
  → Chimeway.Signal.track(tenant_id, customer_email, "invoice.paid", payload)
  → SignalRouterWorker → Workflows.route_signal/1
  → matched :waiting runs: state :active, pending_signals [], reason "signal_received"
  → escalation blocked (no second-step delivery if signal before due_at)
```

[CITED: accrue/lib/accrue/webhook/default_handler.ex L948–990] [CITED: lib/chimeway/workflows.ex L393–450]

**Matching contract:** `find_runs_waiting_for_signal/3` requires `wr.tenant_id`, `n.recipient_identity == actor_id`, `wr.state == :waiting`, and `event_name in pending_signals` [VERIFIED: codebase grep — lib/chimeway/workflows.ex L437–450].

**Critical fix (D-09):** v1.40 uses `actor_id: "accrue.dunning"` and `"payment_recovered"` — matches **zero** runs because `recipient_identity` is customer email and `pending_signals` will list `"invoice.paid"` [CITED: accrue/lib/accrue/integrations/chimeway.ex L95–109].

### 3.4 Reference pattern: payment reminder (not Accrue-specific)

`DemoHost.Notifiers.PaymentReminder` — `wait_until` + `cancel_signals: ["chimeway.notification.read"]` + second email step [CITED: examples/chimeway_demo_host/lib/demo_host/notifiers/payment_reminder.ex L59–88].

JOUR-06 proves cancel semantics: after signal, run `:active`, **no email deliveries**, current step remains first step [CITED: examples/chimeway_demo_host/test/demo_host_web/journey_test.exs L135–144].

### 3.5 What this phase is NOT

- **Not** `Chimeway.Adapter` — ROADMAP + D-01 [CITED: 58-CONTEXT.md].
- **Not** duplicating Accrue anchor/idempotency inside Chimeway — `start_campaign/3` remains sole failed-payment entry [CITED: 58-CONTEXT.md D-04].
- **Not** demo host proof — Phase 59 DEMO-07 [CITED: ROADMAP Phase 59].

---

## 4. Accrue v1.40 Baseline vs Phase 58 Target

| Area | v1.40 baseline (sibling repo) | Phase 58 target | Gap |
|------|------------------------------|-----------------|-----|
| `DunningNotifier.workflow/2` | **Omitted** — `:immediate` only, no `WorkflowRun` [CITED: accrue/lib/accrue/integrations/chimeway.ex L26–32, L120–121] | Multi-step: Email 1 → wait 48h → Email 2 [CITED: SEED-003] | Add `workflow/2` |
| `DunningNotifier.rendering/2` | **Omitted** — only `build/2` [CITED: accrue/lib/accrue/integrations/chimeway.ex L147–156] | Email steps need `render_key` / assigns for delivery planning [CITED: lib/chimeway/trigger.ex L170–175] | Add `rendering/2` (or test adapter keys) |
| `DunningNotifier.orchestration/2` | `{:ok, :immediate}` [CITED: accrue L155–156] | Likely unchanged default `:immediate` for email-only workflow | Planner discretion (see §11) |
| `cancel_campaign/3` | `Signal.track(customer_id, "accrue.dunning", "payment_recovered", ...)` [CITED: accrue L101–105] | `Signal.track(customer_id, customer.email, "invoice.paid", ...)` [CITED: 58-CONTEXT.md D-08/D-09] | Fix actor + event name; lookup customer email |
| Accrue dunning guide | Documents `"payment_recovered"` [CITED: accrue/guides/dunning.md L187] | Align with `invoice.paid` when Chimeway workflow enabled | Doc update (Phase 59/60 or minimal note in 58) |
| Chimeway `mix.exs` | No `accrue` dep [VERIFIED: codebase grep] | `{:accrue, "~> 1.2", optional: true}` + `verify.accrue` | Add dep + aliases |
| Chimeway tests | Zero `@moduletag :accrue` files [VERIFIED: codebase grep] | Integration tests via `Accrue.Test.trigger_event/2` | New test/support + test module |
| CI | `ci.test` excludes `:mailglass` only [CITED: mix.exs L59–60] | Also exclude `:accrue`; `verify.accrue` alias (CI job = Phase 60) | mix.exs + test tags |

**Accrue Oban engine unchanged:** When host uses default `Accrue.Dunning.Engine.Oban`, behaviour unchanged; Chimeway engine is opt-in via config [CITED: accrue/guides/dunning.md L128–178].

---

## 5. Cross-Repo Change Map

### Accrue repo (`../accrue/accrue/`)

| File | Change |
|------|--------|
| `lib/accrue/integrations/chimeway.ex` | **`DunningNotifier`:** add `workflow/2` (48h escalation), `rendering/2`; **`cancel_campaign/3`:** emit `invoice.paid` with `actor_id = customer.email`; update moduledoc (remove v1.40 immediate-only scope) |
| `guides/dunning.md` | Update “What changes” cancel signal naming (`payment_recovered` → `invoice.paid`) — at minimum cross-linked in plan; full doc gate Phase 60 |
| `test/accrue/integrations/chimeway_test.exs` | Extend behaviour tests for `workflow/2` export when Chimeway loaded [ASSUMED: mirror existing conditional-compile tests] |

**Do not change:** `DefaultHandler` campaign elector, anchor column, `Accrue.Dunning.Engine` behaviour module, Oban engine [CITED: 58-CONTEXT.md D-04].

### Chimeway repo

| File | Change |
|------|--------|
| `mix.exs` | Optional `{:accrue, "~> 1.2", optional: true}`; `"ci.test"` `--exclude accrue`; `"verify.accrue"` alias |
| `config/test.exs` | Accrue test config when dep loaded (`:repo`, `:dunning`, Fake processor) [ASSUMED: follow Mailglass conditional block pattern] |
| `test/test_helper.exs` | Bootstrap `Accrue.TestRepo` + migrations when `Code.ensure_loaded?(Accrue)` [CITED: test/test_helper.exs Mailglass block] |
| `test/support/accrue/` (new) | `data_case.ex`, fixtures, sandbox helpers — **Mailglass precedent** [CITED: test/support/mailglass/data_case.ex] |
| `test/chimeway/integrations/accrue_dunning_*_test.exs` (new) | `@moduletag :accrue` — start + terminate paths |
| `mix.lock` | Accrue + transitive deps when optional dep fetched |

**No changes expected:** `lib/chimeway/signal.ex`, `workflows.ex`, `progression.ex`, `trigger.ex` core logic [CITED: 58-CONTEXT.md cross-cutting constraints].

### Version / dependency coordination

- Accrue declares `{:chimeway, "~> 1.0", optional: true}` [CITED: accrue/mix.exs].
- Chimeway Phase 58 adds reverse optional dep `~> 1.2` [CITED: 58-CONTEXT.md D-11].
- Local dev likely uses **path dep** to sibling `../accrue/accrue` until Accrue hex release contains `workflow/2` changes [ASSUMED: cross-repo dev norm].
- Accrue docs reference “v1.40+” for engine behaviour; local `@version` in accrue `mix.exs` is `1.2.0` [CITED: accrue/mix.exs L4] — planner should pin **minimum hex version** that ships Phase 58 Accrue changes.

---

## 6. Workflow Authoring (DunningNotifier.workflow/2)

Per SEED-003 and D-06/D-08, recommend **email-only two-step** workflow (mirror `PaymentReminder` mechanics, swap READ signal for billing Outcome Signal):

```elixir
def workflow(_params, _recipient) do
  {:ok,
   %{
     workflow_key: "accrue.dunning",
     workflow_version: 1,
     steps: [
       %{
         step_key: "initial_email",
         step_order: 1,
         channel: :email,
         config: %{
           "progress" => [
             %{
               "kind" => "wait_until",
               "anchor" => "prior_delivery_terminal_at",
               "delay_seconds" => 172_800,  # 48h — SEED-003
               "to_step" => "escalation_email",
               "cancel_signals" => ["invoice.paid"]
             }
           ]
         }
       },
       %{
         step_key: "escalation_email",
         step_order: 2,
         channel: :email,
         config: %{}
       }
     ]
   }}
end
```

[CITED: SEED-003] [CITED: payment_reminder.ex L59–88] [CITED: lib/chimeway/notifier.ex wait_until normalization]

**Step keys / delay / render keys (planner discretion — D-46):**

| Knob | Recommendation | Rationale |
|------|----------------|-----------|
| `step_key` | `"initial_email"`, `"escalation_email"` | Clear operator traces; align with SEED-003 “Email 1 / Email 2” |
| `delay_seconds` | `172_800` (48h) | SEED-003 explicit [CITED: SEED-003 L16] |
| `workflow_key` | `"accrue.dunning"` | Matches `notification_key/0` [CITED: accrue DunningNotifier L128] |
| `render_key` (email) | e.g. `"accrue.dunning.initial_email"` / `"accrue.dunning.escalation_email"` | Stable keys; map to test Logger adapter or future Mailglass in host |
| `cancel_signals` | `["invoice.paid"]` only | ECOS-06 canonical string [CITED: REQUIREMENTS.md ECOS-06] |

**`rendering/2` sketch (required for trigger):**

```elixir
def rendering(params, _recipient) do
  sub_id = params[:subscription_id] || params["subscription_id"]

  {:ok,
   %{
     assigns: %{
       "subscription_id" => sub_id,
       "subject" => "Payment reminder",
       "html_body" => "<p>Please update your payment method.</p>",
       "text_body" => "Please update your payment method."
     },
     channels: %{
       email: %{
         render_key: "accrue.dunning.initial_email",
         render_version: 1
       }
     }
   }}
end
```

[CITED: lib/chimeway/trigger.ex L170] — `resolve_rendering` is mandatory on trigger path.

**Progression after first email:** Tests must drive first delivery to terminal (`Deliveries.record_attempt/2` with `:succeeded`) then call `Progression.progress_run/2` — same as `workflow_progression_test.exs` [CITED: test/chimeway/orchestration/workflow_progression_test.exs L340–355].

---

## 7. Signal Termination Path (invoice.paid + recipient_identity matching)

### 7.1 Accrue-side emission (cancel_campaign)

**Target implementation shape:**

```elixir
def cancel_campaign(%Subscription{} = sub, _iso_anchor, _opts) do
  customer = Accrue.Repo.repo().get!(Accrue.Billing.Customer, sub.customer_id)

  Chimeway.Signal.track(
    sub.customer_id,           # tenant_id — matches start_campaign / WorkflowRun.tenant_id
    customer.email,            # actor_id — MUST match notification.recipient_identity
    "invoice.paid",
    %{subscription_id: sub.id}
  )
end
```

[CITED: 58-CONTEXT.md D-09] [CITED: lib/chimeway/signal.ex L22] [CITED: lib/chimeway/workflows.ex L443–444]

### 7.2 Chimeway-side routing

1. `Signal.track/4` inserts `chimeway_signals` row + enqueues `SignalRouterWorker` [CITED: lib/chimeway/signal.ex L30–39].
2. Worker calls `Workflows.route_signal/1` [CITED: lib/chimeway/dispatch/signal_router_worker.ex L28–31].
3. Matching runs transition `:waiting` → `:active`, `pending_signals: []`, `status_reason: "signal_received"` [CITED: lib/chimeway/workflows.ex L404–418].
4. Transition context contains **`event_name` only** (no raw payload) [CITED: lib/chimeway/workflows.ex L418].

### 7.3 Product semantics of “terminate”

| Interpretation | Mechanism | Phase 58 stance |
|----------------|-----------|-----------------|
| Block escalation | Signal before `due_at` → no second-step delivery; step cursor stays on first step | **Primary** — JOUR-06 parity [CITED: journey_test.exs L135–144] |
| Terminal run state | `:stopped` / `:completed` via `stop` rule or new API | **Deferred** unless ECOS-06 UAT fails [CITED: 58-CONTEXT.md deferred] |
| Accrue anchor clear | Prevents duplicate `start_campaign` | **Backstop** — still required [CITED: 58-CONTEXT.md D-10] |

**Test assertions (Wave 58-03):**

1. After `Accrue.Test.trigger_event(:invoice_payment_failed, invoice)` + progression to `:waiting` with `pending_signals == ["invoice.paid"]`.
2. After `Accrue.Test.trigger_event(:invoice_paid, invoice)` (or recovery webhook path) + drain `:chimeway_signals`.
3. Assert: run `state == :active`, `pending_signals == []`, `signal_received` transition with `%{"event_name" => "invoice.paid"}`.
4. Assert: **no** delivery row for `escalation_email` step (JOUR-06 pattern).
5. Optional: `Workflows.explain/2` shows explainable waiting → signal_received chain [CITED: ROADMAP SC #1].

### 7.4 Event atom vs string

`Accrue.Test.Webhooks` maps `:invoice_paid` → `"invoice.paid"` and `:invoice_payment_failed` → `"invoice.payment_failed"` [CITED: accrue/lib/accrue/test/webhooks.ex L13–18]. Tests should use **atoms** in `trigger_event/2`; Chimeway `cancel_signals` and `event_name` use **string** `"invoice.paid"`.

---

## 8. Test Harness Design (Mailglass CI Pattern Replication)

### 8.1 Mailglass template (copy)

| Mailglass | Accrue (Phase 58) |
|-----------|-------------------|
| `{:mailglass, "~> 1.3", optional: true}` [CITED: mix.exs L41] | `{:accrue, "~> 1.2", optional: true}` [CITED: 58-CONTEXT.md D-11] |
| `@moduletag :mailglass` [CITED: mailglass_adapter_test.exs L24] | `@moduletag :accrue` |
| `ci.test` `--exclude mailglass` [CITED: mix.exs L60] | `--exclude mailglass --exclude accrue` |
| `verify.mailglass` [CITED: mix.exs L97–100] | `verify.accrue` (root tests only in Phase 58; demo host Phase 59) |
| `test/support/mailglass/` + `test_helper` bootstrap [CITED: test/test_helper.exs L4–33] | `test/support/accrue/` + conditional bootstrap |
| `if Code.ensure_loaded?(Mailglass)` test module guard [CITED: mailglass_adapter_test.exs L1] | Same for Accrue |

### 8.2 Recommended harness layout

```
test/support/accrue/
  data_case.ex          # Sandbox Accrue.TestRepo + Chimeway.Repo (shared mode for webhook path)
  fixtures.ex           # customer/subscription/invoice inserts; dunning engine config helper
  migrations/           # [ASSUMED] symlink or copy Accrue test migrations if not auto-run
test/chimeway/integrations/
  accrue_dunning_lifecycle_test.exs   @moduletag :accrue
```

**Setup checklist per test:**

1. `Application.put_env(:accrue, :repo, Accrue.TestRepo)`
2. `Application.put_env(:accrue, :dunning, engine: Accrue.Integrations.Chimeway, campaign: [enabled: true])`
3. `Accrue.Processor.Fake` + `Accrue.Test.setup_fake_processor/0` [CITED: accrue BillingCase]
4. `Application.put_env(:chimeway, :dispatcher, Chimeway.Dispatch.Oban)` for signal worker tests [CITED: journey_test.exs Oban path]
5. Shared SQL sandbox between repos when `DefaultHandler` and Chimeway share process [CITED: accrue dunning_campaign_keying_test shared sandbox pattern]

### 8.3 Wave 58-01 “event subscription stub”

Minimum harness proof before full E2E:

- Conditional compile: tests skip cleanly when Accrue not in deps (`Code.ensure_loaded?(Accrue)`).
- `Accrue.Integrations.Chimeway` loaded when both deps present.
- Config round-trip: `Config.dunning_engine/0` resolves to Chimeway adapter.
- Optional smoke: direct `start_campaign/3` → assert `WorkflowRun` row exists [ASSUMED: isolates Accrue→Chimeway before full webhook test].

### 8.4 Full E2E path (58-02 / 58-03)

```elixir
# Start
{:ok, _} = Accrue.Test.trigger_event(:invoice_payment_failed, invoice)
# ... drain deliveries, progress_run → assert :waiting, pending_signals

# Terminate
{:ok, _} = Accrue.Test.trigger_event(:invoice_paid, invoice)
# drain_oban!(:chimeway_signals)
# assert signal_received + no escalation delivery
```

[CITED: 58-CONTEXT.md D-12] [CITED: accrue/guides/testing.md trigger_event example]

**Do not** call `Chimeway.trigger/3` directly in the primary ECOS-06 proof — that bypasses Accrue engine/idempotency story [CITED: 58-CONTEXT.md D-04/D-12]. Direct trigger tests are acceptable as **unit** supplements only.

---

## 9. Validation Architecture (Nyquist Dimension 8)

Nyquist dimension 8 = every success criterion maps to an **automated** verify command; no conversational-only gates for engine behaviour [CITED: 49-RESEARCH.md Validation Architecture] [CITED: 48-RESEARCH.md Validation Architecture].

### 9.1 Test framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir 1.17+) |
| Config | `mix.exs` aliases |
| Quick run (Wave 1) | `mix test test/chimeway/integrations/accrue_dunning_harness_test.exs --only accrue --warnings-as-errors` [ASSUMED: path] |
| Phase gate | `mix verify.accrue` |
| Default CI | `mix ci.test` (excludes `:accrue`) |
| Regression | `mix test test/chimeway/orchestration/workflow_progression_test.exs --warnings-as-errors` |

### 9.2 ROADMAP success criteria → verification map

| # | Success criterion (ROADMAP) | Requirement | Test type | Automated command | Wave |
|---|----------------------------|-------------|-----------|-------------------|------|
| 1 | `invoice.payment_failed` → new dunning workflow run + explainable trace | ECOS-06 | integration | `mix verify.accrue` (start describe) | 58-02 |
| 2 | `invoice.paid` Outcome Signal terminates active dunning (no host glue) | ECOS-06 | integration | `mix verify.accrue` (terminate describe) | 58-03 |
| 3 | `@moduletag :accrue` selective CI | ECOS-06 / GATE-05 prep | config | `mix ci.test` excludes accrue; `mix verify.accrue --only accrue` passes | 58-01 |

### 9.3 Per-behaviour verification map

| Behavior | Threat / note | Test type | Command | File exists? |
|----------|---------------|-----------|---------|--------------|
| Optional accrue dep compiles without Accrue | — | compile | `mix compile --warnings-as-errors` | ✅ default |
| Accrue tests skip when dep absent | — | unit | `mix test --exclude accrue` | ❌ Wave 58-01 |
| `start_campaign` creates `WorkflowRun` | T-58-01 idempotency | integration | `verify.accrue` | ❌ Wave 58-02 |
| Idempotent duplicate `payment_failed` | duplicate trigger | integration | same | ❌ Wave 58-02 |
| `wait_until` sets `pending_signals: ["invoice.paid"]` | READ-01 spine | integration | same | ❌ Wave 58-02 |
| `cancel_campaign` emits correct signal shape | actor/tenant match | unit/integration | same | ❌ Wave 58-03 |
| `route_signal` resumes run; no escalation email | JOUR-06 parity | integration | same | ❌ Wave 58-03 |
| `signal_received` context event_name only | READ-03 | integration | assert transition context | ❌ Wave 58-03 |
| Cross-tenant isolation unchanged | T-27-03 | regression | `mix test test/chimeway/workflows_test.exs` | ✅ |
| Accrue conditional compile intact | DUN-03 | accrue-side | `mix test accrue/test/accrue/integrations/chimeway_test.exs` | ✅ accrue repo |

### 9.4 Sampling rate

- **After each task commit:** targeted `mix test .../accrue_* --only accrue`
- **After Wave 58-01:** `mix verify.accrue` (may be partial until 58-02/03 land)
- **Before phase sign-off:** full `mix verify.accrue` + `mix ci.test` green
- **Phase 60 adds:** CI job + MAINTAINING.md entry [CITED: ROADMAP Phase 60 GATE-05]

### 9.5 Wave 0 gaps (for planner VALIDATION.md)

- [ ] `mix.exs` accrue dep + excludes + `verify.accrue`
- [ ] `test/support/accrue/*` + `test_helper` bootstrap
- [ ] `accrue_dunning_harness_test.exs` (58-01)
- [ ] `accrue_dunning_start_test.exs` or combined lifecycle (58-02)
- [ ] Termination describe (58-03)
- [ ] Accrue repo: `workflow/2` + `cancel_campaign` fix + accrue integration test updates

---

## 10. Pitfalls & Risks

| Pitfall | Impact | Mitigation |
|---------|--------|------------|
| **Wrong `actor_id` in `cancel_campaign`** | Signal never matches; silent no-op (today’s v1.40 behaviour) | Use `customer.email`; assert in test [CITED: accrue L97–104] |
| **Wrong event name (`payment_recovered`)** | `pending_signals` lists `invoice.paid` — no match | Canonical `"invoice.paid"` only [CITED: 58-CONTEXT.md D-09] |
| **`tenant_id` mismatch** | Cross-tenant routing failure | Keep `sub.customer_id` consistent start + cancel [CITED: accrue start_campaign L85] |
| **Missing `rendering/2` on DunningNotifier** | `trigger/3` fails at notification insert | Add rendering before workflow E2E [CITED: trigger.ex L170] |
| **Expecting `:stopped` state** | Over-scoping; READ pattern uses `:active` | Assert no escalation delivery + `signal_received` [CITED: JOUR-06] |
| **Direct `Chimeway.trigger` in ECOS-06 proof** | Bypasses Accrue engine contract | Use `Accrue.Test.trigger_event/2` [CITED: 58-CONTEXT.md D-12] |
| **Dual-repo sandbox** | Flaky webhook + Chimeway tests | Shared sandbox mode; `Oban.Testing` manual drain [CITED: accrue dunning_campaign_keying_test] |
| **Accrue/Chimeway version skew** | CI pulls hex Accrue without `workflow/2` | Path dep in dev; pin minimum hex version at release [ASSUMED] |
| **48h wait in tests** | Slow CI | Drive `Progression.progress_run/2, now: ...` or trigger signal before due_at; use `WorkflowProgressionWorker` drain only for Oban due-path spot check [CITED: progression.ex `:now` opt] |
| **Oban job ordering** | Signal processed before run enters `:waiting` | Assert waiting state before `invoice_paid`; drain queues in order [ASSUMED] |
| **Mailglass coupling** | Scope creep | Email via Logger/test render keys; Mailglass optional per D-07 |

---

## 11. Open Questions for Planner

*Only items from Claude's Discretion in 58-CONTEXT.md.*

### OQ-1: Exact step keys, delay_seconds, render keys

**Recommendation:** Use §6 table — `initial_email` / `escalation_email`, `172_800`, render keys under `accrue.dunning.*`. Escalation step can reuse assigns with different `render_key` for version traceability.

### OQ-2: `orchestration/2` after `workflow/2`

**What we know:** `orchestration/2` and `workflow/2` resolve independently in `Trigger` [CITED: trigger.ex L170–173]. Workflow runs created regardless of `:immediate` orchestration default.

**Recommendation:** Keep `orchestration/2` → `{:ok, :immediate}` for email-only dunning. Per-channel map adds no value until multi-channel dunning exists [ASSUMED].

### OQ-3: Test-support shim location

**Options:**

| Option | Pros | Cons |
|--------|------|------|
| `test/support/accrue/*` (Mailglass precedent) | Isolated, conditional compile, matches D-11 | Must bootstrap Accrue migrations |
| Path-dep demo host | Full host realism | Deferred to Phase 59 DEMO-07 [CITED: 58-CONTEXT.md D-13] |

**Recommendation:** `test/support/accrue/*` in Chimeway repo for Phase 58; demo host proof Phase 59.

### OQ-4 (from discussion log, planner may resolve): Does ECOS-06 require `:stopped`/`:completed`?

**Recommendation:** Ship READ/cancel semantics first; add `stop` rule on signal only if UAT rejects `:active` + no escalation as “terminated” [CITED: 58-DISCUSSION-LOG.md L47–48] [CITED: 58-CONTEXT.md deferred].

---

## 12. Canonical Code References

| Ref | Path | Relevance |
|-----|------|-----------|
| Phase decisions | `.planning/phases/58-accrue-dunning-core/58-CONTEXT.md` | D-01–D-13 locked |
| ROADMAP SC + waves | `.planning/ROADMAP.md` (Phase 58) | 58-01..03 scope |
| ECOS-06 | `.planning/REQUIREMENTS.md` | Acceptance wording |
| SEED-003 Accrue slice | `.planning/seeds/SEED-003-ecosystem-integrations.md` | 48h escalation intent |
| Accrue Chimeway adapter (baseline) | `../accrue/accrue/lib/accrue/integrations/chimeway.ex` | start/cancel + DunningNotifier |
| Accrue webhook campaign start | `../accrue/accrue/lib/accrue/webhook/default_handler.ex` | `maybe_start_dunning_campaign`, `run_post_commit_dunning_cancel` |
| Accrue test webhooks | `../accrue/accrue/lib/accrue/test/webhooks.ex` | `trigger_event/2` event type map |
| Accrue dunning guide | `../accrue/accrue/guides/dunning.md` | v1.40 immediate-only docs (stale post-58) |
| Signal API | `lib/chimeway/signal.ex` | `track/4` |
| Signal routing | `lib/chimeway/workflows.ex` | `route_signal/1`, `find_runs_waiting_for_signal/3` |
| Wait + cancel_signals | `lib/chimeway/workflows/progression.ex` | `enter_waiting/6` |
| Trigger + workflow run creation | `lib/chimeway/trigger.ex` | `insert_workflow_runs/3` |
| Notifier workflow validation | `lib/chimeway/notifier.ex` | `workflow/2`, `cancel_signals` normalization |
| Payment reminder reference | `examples/chimeway_demo_host/lib/demo_host/notifiers/payment_reminder.ex` | Authoring pattern |
| JOUR-06 cancel proof | `examples/chimeway_demo_host/test/demo_host_web/journey_test.exs` | Termination semantics model |
| Workflow progression tests | `test/chimeway/orchestration/workflow_progression_test.exs` | READ/cancel test fixtures |
| Signal router worker | `lib/chimeway/dispatch/signal_router_worker.ex` | Async routing |
| Mailglass CI pattern | `mix.exs` | `verify.mailglass`, `ci.test` exclude |
| Mailglass test bootstrap | `test/test_helper.exs`, `test/support/mailglass/data_case.ex` | Harness template |
| Chimeway test config | `config/test.exs` | Oban manual, Repo sandbox |

---

*Research complete for Phase 58 planning. Downstream planner should produce `58-VALIDATION.md` from §9 and wave-scoped PLAN.md files aligned to ROADMAP 58-01..03.*
