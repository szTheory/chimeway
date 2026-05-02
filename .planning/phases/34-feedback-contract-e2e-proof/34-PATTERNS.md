# Phase 34: feedback-contract-e2e-proof — Pattern Map

**Mapped:** 2026-05-02
**Files analyzed:** 4 surface points
**Analogs found:** 4 / 4 (all exact)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `examples/chimeway_demo_host/test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs` (CREATE) | test (E2E controller) | request-response + event-driven Oban cascade | `examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs` | exact (same harness, same setup, same Endpoint.call shape) |
| `test/chimeway/traces_test.exs` lines 416, 523 (MODIFY — 2-line edit) | test (fixture) | data-fixture (transition.context["event_name"] string only) | `test/chimeway/webhooks/process_feedback_worker_test.exs:77,117` | exact (production-contract canonical strings the fixture must align with) |
| `.planning/phases/34-feedback-contract-e2e-proof/34-VERIFICATION.md` (CREATE) | verification artifact | doc / requirements table | `.planning/phases/33-webhook-ingress-durability/33-VERIFICATION.md` lines 111-118 (primary), `.planning/phases/32-operator-traces-audit/32-VERIFICATION.md` lines 99-104 (TRAC-01/02 table format reference) | exact (same milestone-audit-shaped requirements table) |
| Phase 34 plan SUMMARY frontmatter (`requirements-completed: [FLOW-01, FLOW-02]`) | doc (frontmatter) | metadata | `.planning/phases/33-webhook-ingress-durability/33-04-SUMMARY.md:75` | exact |

## Pattern Assignments

### `examples/chimeway_demo_host/test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs` (test, request-response + cascading Oban event-driven)

**Analog:** `examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs`
**Secondary reference (drain posture):** `test/chimeway/reliability/retry_exhaustion_test.exs:133`

**Module header pattern — copy verbatim, swap module name** (analog lines 1-8):
```elixir
defmodule DemoHostWeb.WebhooksControllerTest do
  use ExUnit.Case, async: false
  import Plug.Test
  import Plug.Conn
  use Oban.Testing, repo: Chimeway.Repo

  alias Chimeway.Repo
  alias Chimeway.Webhooks.{Ingress, ProcessFeedbackWorker}
```

For Phase 34 the alias list expands (per RESEARCH.md "use Oban.Testing boilerplate" block):
```elixir
alias Chimeway.{Deliveries, Repo, Traces}
alias Chimeway.Webhooks.{Ingress, ProcessFeedbackWorker}
alias Chimeway.Signals.Signal
alias Chimeway.Workflows.{WorkflowDefinition, WorkflowRun, WorkflowStep, WorkflowTransition}
alias Chimeway.Events.Event
alias Chimeway.Notifications.Notification
```

**Setup pattern — copy verbatim** (analog lines 10-15):
```elixir
setup do
  :ok = Ecto.Adapters.SQL.Sandbox.checkout(Chimeway.Repo)
  Ecto.Adapters.SQL.Sandbox.mode(Chimeway.Repo, {:shared, self()})
  Application.put_env(:demo_host, :chimeway_adapter_config, [])
  :ok
end
```
Lift this whole block from analog lines 10-15. Do NOT use `Chimeway.DataCase` (DataCase is bound to the root project test support; the example host has its own sandbox-shared posture).

**Endpoint invocation pattern — adapt analog lines 21-29** (the only substitution is the body payload):
```elixir
provider_msg_id = "msg-" <> Ecto.UUID.generate()
body = Jason.encode!(%{"id" => provider_msg_id, "status" => "ok"})
conn =
  conn(:post, "/webhooks/chimeway/echo", body)
  |> put_req_header("content-type", "application/json")
  |> put_req_header("signature", "valid")
  |> DemoHostWeb.Endpoint.call(DemoHostWeb.Endpoint.init([]))

assert conn.status == 200
```

For Phase 34 substitute the payload to use the EchoAdapter `delivery_id` clause at `examples/chimeway_demo_host/lib/demo_host/adapters/echo_adapter.ex:37`:
```elixir
def resolve_delivery(%{"delivery_id" => did}) when is_binary(did), do: {:ok, %{delivery_id: did}}
```
Body becomes `Jason.encode!(%{"delivery_id" => delivery.id, "status" => "ok"})` (progress) or `... "status" => "bounce"})` (stop). Per `EchoAdapter.normalize_feedback/1` lines 40-42: `"ok"` → `:delivered` → canonicalized to `"chimeway.delivery.succeeded"`; `"bounce"` → `:bounced`. Header `put_req_header("signature", "valid")` unchanged (EchoAdapter line 25 matches that literal).

**Drain posture — analog: `test/chimeway/reliability/retry_exhaustion_test.exs:133`** (NOT the demo_host analog, which uses `assert_enqueued`/manual paths only):
```elixir
result =
  Oban.drain_queue(queue: :chimeway_delivery, with_scheduled: true, with_recursion: true)

# Verify the queue made progress AND the delivery converged terminally AND
# attempt history accumulated. Do NOT hard-code drain_queue success vs failure
# counts — drain_queue retryable-job semantics are version-dependent. Assert
# observable outcome state, not drain result shape.
total_executed =
  Map.get(result, :success, 0) + Map.get(result, :failure, 0) + Map.get(result, :discard, 0)

assert total_executed >= 1, "drain_queue must execute at least one job"
```
For Phase 34: drop `with_recursion: true` (no scheduled retries on success path), keep `with_scheduled: true`. Apply the **observable-state, not drain-shape** robustness rule to both drain calls.

**Per-fixture insertion pattern — analog `test/chimeway/traces_test.exs` (`insert_event` / `insert_notification` / `insert_workflow_run_for` helpers near line 50-127, used throughout):** model for the new test's `insert_progress_path_fixture/0` and `insert_stop_path_fixture/0` defps. Note: `traces_test.exs` private helpers cannot be imported here — redefine inline. RESEARCH.md § Pattern 3 provides the full helper body, paste-ready.

**Boundary assertion pattern (post-drain) — derived from analog's E2E posture at lines 32-38:**
```elixir
assert [%Ingress{} = ingress] = Repo.all(Ingress)
assert ingress.adapter_module == to_string(DemoHost.Adapters.EchoAdapter)
```
Phase 34 extends with `ingress.delivery_id == delivery.id` and `ingress.ingress_state == :processed` (worker advanced lifecycle); plus `Signal`/`WorkflowRun`/`WorkflowTransition` queries; plus `Traces.explain_delivery/1` timeline assertion (Phase 32 read-side).

**Signal event-name comparison posture — analog `test/chimeway/webhooks/process_feedback_worker_test.exs:77,117`:**
```elixir
# analog line 77 (bounced path):
assert hd(signals).event_name == "chimeway.delivery.bounced"
# analog line 117 (succeeded path):
assert hd(signals).event_name == "chimeway.delivery.succeeded"
```
Compare event names as **strings** — never `String.to_atom`. Canonical posture and the production contract Phase 34's E2E asserts at the milestone level.

**WorkflowTransition `signal_received` query pattern — analog `test/chimeway/traces_test.exs:415-416, 522-523` and the Phase 32 P01-T1 test pattern at `test/chimeway/workflows_test.exs:291-353`:**
```elixir
import Ecto.Query, only: [from: 2]

[signal_received_transition] =
  Repo.all(
    from(wt in WorkflowTransition,
      where: wt.workflow_run_id == ^run.id and wt.reason == "signal_received"
    )
  )

assert signal_received_transition.delivery_id == delivery.id
```

---

### `test/chimeway/traces_test.exs` lines 416, 523 (test fixture, data-fixture)

**Analog (canonical contract source):** `test/chimeway/webhooks/process_feedback_worker_test.exs:77,117` — production-aligned event-name strings.

**Drift fix — line 416 context (delivered/progress fixture, already inside an `:succeeded` outcome scenario):**
Existing line 415-416:
```elixir
insert_workflow_transition!(run, delivery.id, "signal_received",
  %{"event_name" => "chimeway.delivery.delivered"})
```
The companion attempt at lines 405-411 has `outcome: :succeeded`. Per the canonical worker contract (analog line 117), the matching event_name is `"chimeway.delivery.succeeded"`. **Replace `chimeway.delivery.delivered` → `chimeway.delivery.succeeded`.**

**Drift fix — line 523 context (PII-boundary fixture):**
Existing line 522-523:
```elixir
insert_workflow_transition!(run, delivery.id, "signal_received",
  %{"event_name" => "chimeway.delivery.delivered"})
```
The companion attempt at lines 511-518 has `outcome: :succeeded` (line 513). **Replace `chimeway.delivery.delivered` → `chimeway.delivery.succeeded`.** No `.bounced` substitution needed at line 523 — the surrounding `outcome` is `:succeeded`.

**Pitfall coverage:** the projection logic in `lib/chimeway/traces.ex:570-575` dispatches on `transition.reason == "signal_received"`, NOT on `context["event_name"]`. The `event_name` value is read by `lookup_signal_received_event_name/1` (`traces.ex:608-627`) only to enrich a `:webhook_received` entry's `signal_event_name` field. No existing assertion in `traces_test.exs` checks `signal_event_name == "chimeway.delivery.delivered"` (Scenario A at line 347-397 already uses `chimeway.delivery.bounced`, which is canonical and unchanged). The edit is mechanical; no other lines move. Confirm by `grep "chimeway.delivery.delivered" test/` after edit returns nothing.

---

### `.planning/phases/34-feedback-contract-e2e-proof/34-VERIFICATION.md` (verification artifact, doc)

**Analog (table format and tone):** `.planning/phases/33-webhook-ingress-durability/33-VERIFICATION.md` lines 111-118.

**Requirements Coverage table — copy column structure verbatim** (analog lines 113-118):
```markdown
### Requirements Coverage

| Requirement | Source Plan(s) | Description | Status | Evidence |
|-------------|---------------|-------------|--------|----------|
| FLOW-01 | 34-01, 34-02 | Webhook normalization, signal emission, and trace projection agree on one canonical outcome/event vocabulary. | SATISFIED | … |
| FLOW-02 | 34-01 | An end-to-end test proves a real webhook callback updates delivery state, emits the workflow signal, and progresses or stops a workflow as configured. | SATISFIED | … |
```

For Phase 34 the table cells cite **3 evidence sources** per CONTEXT.md D-10:
1. Phase 31 emission code: `lib/chimeway/webhooks/process_feedback_worker.ex:139` (`canonicalize_status/1`) + lines 158-168 (`Chimeway.Signal.track/4` emission).
2. Phase 32 trace projection code: `lib/chimeway/workflows.ex:419` (`delivery_id` populated on `signal_received` transitions) + `lib/chimeway/traces.ex:506-575` (timeline projection of `:webhook_received` and `:workflow_*` atoms).
3. Phase 34 new E2E test as the milestone-level closing proof.

**Secondary reference for table tone — `.planning/phases/32-operator-traces-audit/32-VERIFICATION.md:99-104` (TRAC-01/02 cells):** clean precedent for citing multiple plans (write-side + read-side) in `Source Plan(s)` and threading evidence through both, which Phase 34 mirrors when citing Phase 31 + Phase 32 + Phase 34.

**YAML frontmatter pattern — analog `33-VERIFICATION.md:1-25`:** Adapt `phase: 34-feedback-contract-e2e-proof`, `score: N/N must-haves verified`, `re_verification: null`, etc. (Initial verification, not re-verification — `32-VERIFICATION.md:7` shows `re_verification: null` is the canonical shape for the first pass.)

**Audit Notes section (CONTEXT.md D-13 / D-04 — short audit-stale callout):** No exact analog. Closest precedent is the "Note on Supersession" section at `33-VERIFICATION.md:34-38` (similar role: explains audit-context to the next reader). For Phase 34, follow CONTEXT.md "Claude's Discretion": clear and dated, ≤6 lines, points at `33-VERIFICATION.md:115-118` for FEED-01/02 closure.

---

### Phase 34 plan SUMMARY frontmatter (doc, metadata)

**Analog:** `.planning/phases/33-webhook-ingress-durability/33-04-SUMMARY.md:75`.

**Frontmatter pattern — `requirements-completed:` line shape (analog line 75):**
```yaml
requirements-completed: [FEED-01, FEED-02]
```

For Phase 34 plan SUMMARYs:
```yaml
requirements-completed: [FLOW-01, FLOW-02]
```

This frontmatter is written by `gsd-execute-phase`. The planner only needs to ensure the plan PLAN.md declares `requirements_addressed: [FLOW-01, FLOW-02]` so the execute-phase agent carries it through to SUMMARY frontmatter. Phase 32 P01/P02 plans both declared via `requirements_addressed`, per `32-VERIFICATION.md:101-102`.

---

## Shared Patterns

### Sandbox + Oban.Testing harness
**Source:** `examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs:1-15`
**Apply to:** the new `feedback_pipeline_e2e_test.exs`

### Two-stage drain order (mandatory)
**Source:** `test/chimeway/reliability/retry_exhaustion_test.exs:133` for posture; CONTEXT.md D-06.4 for order.
**Apply to:** every E2E scenario in `feedback_pipeline_e2e_test.exs` (both progress and stop).
Drain `:chimeway_delivery` first (worker side-effects: attempt + signal + synchronous progression via `record_attempt/2`), then `:chimeway_signals` (router-driven `signal_received` transition). Reverse order leaves the test in a half state.
**Drain shape robustness:** assert `total_executed >= 1` over success+failure+discard, not on a hard-coded `%{success: N}` shape.

### String comparison of signal event names (atom-safety)
**Source:** `test/chimeway/webhooks/process_feedback_worker_test.exs:77,117`
**Apply to:** every signal-name assertion in the new E2E test, plus the modified `traces_test.exs` fixtures.
Compare event names as **strings**: `assert hd(signals).event_name == "chimeway.delivery.succeeded"`. Never derive an event-name atom from a runtime string.

### Tenancy invariant for `route_signal/1` to match
**Source:** `lib/chimeway/workflows.ex:437-451`; emission at `lib/chimeway/webhooks/process_feedback_worker.ex:167`.
**Apply to:** the progress-path fixture in the new E2E test.
ONE shared `actor_id` across `notification.recipient_identity` AND `delivery.actor_id`; ONE shared `tenant_id` across `run.tenant_id` AND `delivery.tenant_id`.

### Real `Repo.insert!` for fixture rows; let production write transitions
**Source:** `test/chimeway/traces_test.exs:69-127`, `test/chimeway/dispatch/signal_router_worker_test.exs:27-88`.
**Apply to:** `insert_progress_path_fixture/0` and `insert_stop_path_fixture/0` in the new E2E test.
Insert `Event` / `Notification` / `WorkflowDefinition` / `WorkflowStep` / `WorkflowRun` directly via `Repo.insert!`. Insert `Delivery` via `Deliveries.plan_delivery/3` (with `workflow_run_id:` + `workflow_step_id:`). Then transition delivery off `:pending` via `Deliveries.transition_status(delivery, :dispatched)` so `record_attempt/2` has a valid transition target. NEVER hand-insert `signal_received` or `workflow_*` transitions — let the production code paths write them so assertions prove the contract.

## No Analog Found

None. All 4 surface points have exact analogs already in the codebase or planning tree.

---

## PATTERN MAPPING COMPLETE

**Phase:** 34 — feedback-contract-e2e-proof
**Files classified:** 4
**Analogs found:** 4 / 4 (all exact)
