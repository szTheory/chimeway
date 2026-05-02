---
phase: 33-webhook-ingress-durability
plan: 03
type: execute
wave: 2
depends_on: [33-01]
files_modified:
  - lib/chimeway/webhooks/process_feedback_worker.ex
  - test/chimeway/webhooks/process_feedback_worker_test.exs
autonomous: true
requirements: [FEED-01, FEED-02]
requirements_addressed: [FEED-01, FEED-02]
tags: [elixir, oban, worker, safe-noop, webhook, feedback]

must_haves:
  truths:
    - "`ProcessFeedbackWorker.perform/1` accepts `%{\"ingress_id\" => binary}` and reads all correlation/status data from the durable ingress row (D-01, durable-spine-over-queue-archaeology)."
    - "Stale `delivery_id` callbacks update the ingress row to `ingress_state: :ignored, ignored_reason: :delivery_not_found, processed_at: <utc_now>` and return `:ok` — NO Oban retry storm (D-06, D-07, T-33-RETRY)."
    - "Stale `provider_message_id` callbacks update the ingress row to `ingress_state: :ignored, ignored_reason: :provider_message_id_not_found, processed_at: <utc_now>` and return `:ok`."
    - "Hard-deleted ingress row between Multi commit and perform returns `:ok` (Pitfall 2)."
    - "Already-processed ingress row (`ingress_state: :processed | :ignored`) returns `:ok` idempotently on retry."
    - "The `ProcessFeedbackWorker.enqueue/1` antipattern helper is REMOVED — callers go through `Chimeway.Webhooks.process/4` exclusively."
    - "Pre-Phase-33 in-flight Oban jobs with `%{\"delivery_id\" => …}` or `%{\"provider_message_id\" => …}` arg shapes still process correctly via a backwards-compat shim clause (A6, deploy-safety)."
    - "Worker module is wrapped in `if Code.ensure_loaded?(Oban) do … end` (defect-fix from current line 1; Phase 33 atom-safety/Oban-optional discipline)."
  artifacts:
    - path: "lib/chimeway/webhooks/process_feedback_worker.ex"
      provides: "Ingress-driven worker with safe-noop semantics + backwards-compat shim"
      contains: "%Oban.Job{args: %{\"ingress_id\" => ingress_id}}"
    - path: "test/chimeway/webhooks/process_feedback_worker_test.exs"
      provides: "Tests for ingress-driven perform, safe-noop ignored paths, hard-delete race, idempotent re-perform, and backwards-compat shim"
      contains: ":delivery_not_found"
  key_links:
    - from: "lib/chimeway/webhooks/process_feedback_worker.ex"
      to: "lib/chimeway/webhooks/ingress.ex"
      via: "alias Chimeway.Webhooks.Ingress + Repo.get(Ingress, ingress_id)"
      pattern: "Repo.get\\(Ingress"
    - from: "lib/chimeway/webhooks/process_feedback_worker.ex"
      to: "lib/chimeway/deliveries.ex"
      via: "Deliveries.fetch_delivery/1 + Deliveries.get_delivery_by_provider_message_id/1"
      pattern: "Deliveries\\.fetch_delivery"
    - from: "lib/chimeway/webhooks/process_feedback_worker.ex"
      to: "lib/chimeway/dispatch/workflow_progression_worker.ex"
      via: "safe-noop normalize_perform_result mirrors normalize_progress_result"
      pattern: "normalize_perform_result"
---

<objective>
Pivot `Chimeway.Webhooks.ProcessFeedbackWorker` from the raising-lookup, args-carrying-payload model to the ingress-driven, safe-noop model. Remove the `enqueue/1` antipattern helper. Add a backwards-compat shim for in-flight pre-Phase-33 Oban job shapes. Wrap the module in `if Code.ensure_loaded?(Oban)` per project Oban-optional discipline.

Purpose: Closes audit gap T-33-RETRY ("Unknown `delivery_id` feedback crashes the worker instead of failing safely"). After this plan, the worker is fully durable-spine-driven (D-01) and unresolvable callbacks become explainable ignored audit rows on the ingress surface (D-08).

Output: Worker reads from `Chimeway.Webhooks.Ingress`, writes ignored-reason on stale lookups, returns `:ok` for all understood-but-ignored outcomes, mirrors the `WorkflowProgressionWorker.normalize_progress_result/1` shape verbatim.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/33-webhook-ingress-durability/33-CONTEXT.md
@.planning/phases/33-webhook-ingress-durability/33-RESEARCH.md
@.planning/phases/33-webhook-ingress-durability/33-PATTERNS.md
@.planning/phases/33-webhook-ingress-durability/33-01-SUMMARY.md
@lib/chimeway/dispatch/workflow_progression_worker.ex
@lib/chimeway/webhooks/process_feedback_worker.ex
@lib/chimeway/webhooks/ingress.ex
@lib/chimeway/deliveries.ex
@lib/chimeway/signal.ex
@test/chimeway/webhooks/process_feedback_worker_test.exs
</context>

<assumptions>
<!-- Per RESEARCH.md A6 — surfaced for user confirm/override. HIGH risk if wrong. -->

- **A6 (backwards-compat shim policy):** This plan KEEPS a backwards-compat clause in `perform/1` that handles legacy `%{"delivery_id" => …}` and `%{"provider_message_id" => …}` arg shapes for one release cycle. This protects in-flight pre-Phase-33 Oban jobs that may still be in the `oban_jobs` table at deploy time.
  - **Alternative (operator-driven):** Drop the shim, document a queue-drain step in the deploy runbook (`mix oban.drain` before deploying Phase 33). Simpler code, but a HARD operational requirement.
  - **Default recommendation (Research, fail-safe):** Include the shim. Mark for removal in a future cleanup phase (Phase 34 or v1.5).
  - **Override:** If you commit to draining the queue pre-deploy and prefer simpler code, override before Task 1 begins; the executor will SKIP the shim. Manual verification entry exists in `33-VALIDATION.md` for the deploy-runbook review.

  This plan PROCEEDS on the default recommendation (shim included).
</assumptions>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Rewrite ProcessFeedbackWorker for ingress-driven perform + safe-noop</name>
  <files>lib/chimeway/webhooks/process_feedback_worker.ex</files>
  <read_first>
    - lib/chimeway/dispatch/workflow_progression_worker.ex (full — Oban-guard wrapper, queue config, safe-noop normalizer)
    - lib/chimeway/webhooks/process_feedback_worker.ex (current — preserve `record_attempt` + `Signal.track` chain semantics)
    - lib/chimeway/webhooks/ingress.ex (Plan 01 output — schema being read from and updated)
    - lib/chimeway/deliveries.ex (`fetch_delivery/1` from Plan 02; `get_delivery_by_provider_message_id/1`; `record_attempt/2`)
    - lib/chimeway/signal.ex (Signal.track preserved unchanged)
    - .planning/phases/33-webhook-ingress-durability/33-RESEARCH.md (§ Code Examples > `ProcessFeedbackWorker.perform/1` rewrite — copy verbatim)
    - .planning/phases/33-webhook-ingress-durability/33-PATTERNS.md (§ lib/chimeway/webhooks/process_feedback_worker.ex)
    - config/test.exs (line 21 — confirms `:chimeway_delivery` queue exists)
  </read_first>
  <action>
    Replace the entire body of `lib/chimeway/webhooks/process_feedback_worker.ex` with the implementation specified verbatim in `33-RESEARCH.md` § "Code Examples > `ProcessFeedbackWorker.perform/1` rewrite" (lines 720-839). Key invariants the new file MUST satisfy (these are also acceptance criteria):

    1. **Module wrapped in `if Code.ensure_loaded?(Oban) do … end`** (matches `WorkflowProgressionWorker:1`; the current file is NOT wrapped — defect-fix).
    2. **`use Oban.Worker, queue: :chimeway_delivery, max_attempts: 5`** (replaces current `queue: :default`; aligns with `config/test.exs:21`).
    3. **`perform/1` head 1:** `def perform(%Oban.Job{args: %{"ingress_id" => ingress_id}}) when is_binary(ingress_id) do` — reads ingress row via `Repo.get(Ingress, ingress_id)`. Branches:
       - `nil` → return `:ok` (Pitfall 2: hard-delete race; mirrors `WorkflowProgressionWorker` `:workflow_run_not_found`).
       - `%Ingress{ingress_state: :ignored}` → return `:ok` (idempotent dedup convergence).
       - `%Ingress{ingress_state: :processed}` → return `:ok` (idempotent re-run on retry).
       - `%Ingress{} = ingress` → `apply_feedback(ingress) |> normalize_perform_result()`.
    4. **`perform/1` head 2 (legacy shim, A6):** `def perform(%Oban.Job{args: %{"delivery_id" => _} = legacy_args})` → `perform_legacy_args(legacy_args)`.
    5. **`perform/1` head 3 (legacy shim, A6):** `def perform(%Oban.Job{args: %{"provider_message_id" => _} = legacy_args})` → `perform_legacy_args(legacy_args)`.
    6. **`apply_feedback/1` ingress-driven dispatch:** `delivery_id` binary → `Deliveries.fetch_delivery/1`; `provider_message_id` binary → `Deliveries.get_delivery_by_provider_message_id/1`. `{:ok, delivery}` → `run_feedback_pipeline/2`. `{:error, :not_found}` → `mark_ignored(ingress, :delivery_not_found | :provider_message_id_not_found)`.
    7. **`mark_ignored/2`:** updates the ingress row with `%{ingress_state: :ignored, ignored_reason: reason, processed_at: DateTime.utc_now()}` via `Ingress.changeset/2 |> Repo.update()`. Returns `{:ignored, reason}` on success, `{:error, changeset}` on failure.
    8. **`mark_processed/1`:** updates the ingress row with `%{ingress_state: :processed, processed_at: DateTime.utc_now()}`. Returns `Repo.update/1`'s tuple directly.
    9. **`run_feedback_pipeline/2`:** preserves the existing semantic from current line 14-60 — `Deliveries.record_attempt/2` then `Chimeway.Signal.track/4`. Wraps both with `with` and ALSO calls `mark_processed(ingress)` so the ingress row's lifecycle reflects success.
    10. **`normalize_perform_result/1`** — mirrors `WorkflowProgressionWorker.normalize_progress_result/1` (Pattern 2): `:ok -> :ok`, `{:ignored, _} -> :ok`, `{:error, %Ecto.Changeset{}} -> {:error, cs}`, `{:error, reason} -> {:error, reason}`.
    11. **`canonicalize_status/1`** — `"delivered" -> "succeeded"`, anything else passthrough. Preserves the existing semantic from current line 17 (Phase 34 owns the broader vocabulary unification per D-14).
    12. **`build_attempt_params/2`** — same shape as current lines 23-34: `%{outcome: outcome, adapter_module: ingress.adapter_module}`, conditionally `:error_class` for bounced/failed, conditionally `:provider_message_id`.
    13. **`emit_signal/2`** — same signal payload shape as current lines 45-58: event_name `"chimeway.delivery.#{outcome}"`, payload `%{"delivery_id" => delivery.id, "status" => to_string(outcome)}` plus `"error"` for bounced/failed. Calls `Chimeway.Signal.track/4`.
    14. **`perform_legacy_args/1`** (private, A6 shim path) — same feedback pipeline as the new path but driven by old args directly (no ingress row write). Uses `fetch_delivery/1` (NOT `get_delivery!/1`) so legacy stale-id paths are also safe-noop.
    15. **`enqueue/1` is DELETED.** No `def enqueue` remains in the file. Callers go through `Chimeway.Webhooks.process/4` exclusively.
    16. **NO `Deliveries.get_delivery!/1` references.** The bang form is forbidden in this file (T-33-RETRY closure).
    17. **NO `String.to_atom/1` references.** Only `String.to_existing_atom/1` operating on the bounded `~w(succeeded bounced failed)` set after `canonicalize_status/1`.
  </action>
  <verify>
    <automated>grep -q "if Code.ensure_loaded?(Oban) do" lib/chimeway/webhooks/process_feedback_worker.ex && grep -q "queue: :chimeway_delivery" lib/chimeway/webhooks/process_feedback_worker.ex && grep -q "ingress_id" lib/chimeway/webhooks/process_feedback_worker.ex && grep -q "Deliveries.fetch_delivery" lib/chimeway/webhooks/process_feedback_worker.ex && ! grep -q "Deliveries.get_delivery!" lib/chimeway/webhooks/process_feedback_worker.ex && ! grep -q "def enqueue" lib/chimeway/webhooks/process_feedback_worker.ex && grep -q "normalize_perform_result" lib/chimeway/webhooks/process_feedback_worker.ex && grep -q ":delivery_not_found" lib/chimeway/webhooks/process_feedback_worker.ex && grep -q ":provider_message_id_not_found" lib/chimeway/webhooks/process_feedback_worker.ex && grep -q "perform_legacy_args" lib/chimeway/webhooks/process_feedback_worker.ex && ! grep -F "String.to_atom(" lib/chimeway/webhooks/process_feedback_worker.ex && mix compile --warnings-as-errors</automated>
  </verify>
  <acceptance_criteria>
    - File `lib/chimeway/webhooks/process_feedback_worker.ex` first non-blank line is `if Code.ensure_loaded?(Oban) do`.
    - File contains `use Oban.Worker, queue: :chimeway_delivery, max_attempts: 5`.
    - File contains `def perform(%Oban.Job{args: %{"ingress_id" => ingress_id}}) when is_binary(ingress_id) do`.
    - File contains `case Repo.get(Ingress, ingress_id) do`.
    - File contains all four ingress-state branches: `nil ->`, `%Ingress{ingress_state: :ignored}`, `%Ingress{ingress_state: :processed}`, and a fall-through `%Ingress{} = ingress`.
    - File contains `def perform(%Oban.Job{args: %{"delivery_id" => _} = legacy_args})` (A6 shim head 1).
    - File contains `def perform(%Oban.Job{args: %{"provider_message_id" => _} = legacy_args})` (A6 shim head 2).
    - File contains `defp perform_legacy_args(args)`.
    - File contains `Deliveries.fetch_delivery(`.
    - File contains `Deliveries.get_delivery_by_provider_message_id(`.
    - File contains `mark_ignored` and `mark_processed` private functions.
    - File contains `ingress_state: :ignored, ignored_reason: :delivery_not_found` (or equivalent in the changeset call).
    - File contains `ingress_state: :ignored, ignored_reason: :provider_message_id_not_found` (or equivalent).
    - File contains `ingress_state: :processed, processed_at: DateTime.utc_now()` (or equivalent in the changeset call).
    - File contains `defp normalize_perform_result(:ok), do: :ok`.
    - File contains `defp normalize_perform_result({:ignored, _reason}), do: :ok`.
    - File contains `defp normalize_perform_result({:error, reason})` (the retry-eligible passthrough clause).
    - File contains `defp canonicalize_status("delivered"), do: "succeeded"` (preserves Phase 32 trace consistency).
    - File contains `Chimeway.Signal.track(` (preserves existing signal-emission semantic).
    - File does NOT contain `def enqueue` (T-33-ATOMIC closure — antipattern removed).
    - File does NOT contain `Deliveries.get_delivery!` (T-33-RETRY closure — raising lookup removed).
    - File does NOT contain `String.to_atom(` as a function call (atom-safety; only `String.to_existing_atom/1` is allowed). The check uses `grep -F "String.to_atom("` for POSIX/BSD-portable fixed-string matching of the function-call shape.
    - File does NOT contain `queue: :default` (queue config corrected to `:chimeway_delivery`).
    - `mix compile --warnings-as-errors` exits 0.
  </acceptance_criteria>
  <done>The worker is ingress-driven, safe-noop, queue-aligned, Oban-guarded, and the antipattern `enqueue/1` is gone. Backwards-compat shim is in place per A6.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Rewrite test/chimeway/webhooks/process_feedback_worker_test.exs for ingress-driven contract</name>
  <files>test/chimeway/webhooks/process_feedback_worker_test.exs</files>
  <read_first>
    - test/chimeway/webhooks/process_feedback_worker_test.exs (current 157 lines — preserve `setup`, `insert_event/1`, `insert_notification/2` helpers)
    - lib/chimeway/webhooks/process_feedback_worker.ex (Task 1 output — the contract being tested)
    - lib/chimeway/webhooks/ingress.ex (Plan 01 output — to insert ingress rows for tests)
    - .planning/phases/33-webhook-ingress-durability/33-PATTERNS.md (§ test/chimeway/webhooks/process_feedback_worker_test.exs)
    - .planning/phases/33-webhook-ingress-durability/33-RESEARCH.md (§ Validation Architecture > Phase Requirements → Test Map; § Pitfall 2)
  </read_first>
  <action>
    Modify `test/chimeway/webhooks/process_feedback_worker_test.exs` per these steps:

    1. **PRESERVE verbatim:** lines 1-19 (the `setup` block with `event`, `notification`, `delivery`) and lines 21-47 (`insert_event/1` and `insert_notification/2` helpers). They are still the right shape for the success-path tests.

    2. **Add `alias Chimeway.Webhooks.Ingress`** to the alias list at line 5 area.

    3. **REPLACE the existing `describe "perform/1"` block** with the new ingress-driven contract.

       - **Existing test "processes feedback for a given delivery_id" (lines 50-87)** — REWRITE to insert an ingress row first, then perform with `%{"ingress_id" => ingress.id}`:

         ```elixir
         test "processes feedback for a delivery_id-correlated ingress row", %{delivery: delivery} do
           {:ok, ingress} =
             %Ingress{}
             |> Ingress.changeset(%{
               adapter_module: "SomeAdapter",
               delivery_id: delivery.id,
               normalized_status: "bounced",
               ingress_state: :queued
             })
             |> Repo.insert()

           assert :ok = ProcessFeedbackWorker.perform(%Oban.Job{args: %{"ingress_id" => ingress.id}})

           # Delivery attempt persisted (preserved from old test)
           updated_delivery = Deliveries.get_delivery!(delivery.id)
           assert updated_delivery.status == :cancelled
           assert updated_delivery.suppression_reason == "bounced"

           attempts = Repo.all(Chimeway.DeliveryAttempt)
           assert length(attempts) == 1
           assert hd(attempts).outcome == :bounced
           assert hd(attempts).adapter_module == "SomeAdapter"

           # Signal emitted (preserved)
           signals = Repo.all(Signal)
           assert length(signals) == 1
           assert hd(signals).event_name == "chimeway.delivery.bounced"
           assert_enqueued(worker: SignalRouterWorker, args: %{"signal_id" => hd(signals).id})

           # NEW: ingress row's lifecycle advanced to :processed
           reloaded = Repo.get!(Ingress, ingress.id)
           assert reloaded.ingress_state == :processed
           assert reloaded.processed_at
         end
         ```

       - **Existing test "processes feedback for a given provider_message_id" (lines 89-133)** — REWRITE same way using ingress row with `provider_message_id` set, `delivery_id: nil`. Preserves the prior delivery-with-prior-attempt setup.

       - **Existing test "returns error if delivery cannot be found by delivery_id" (lines 135-145)** — REWRITE to the safe-noop contract (T-33-RETRY closure):

         ```elixir
         test "marks ingress :ignored with :delivery_not_found and returns :ok on stale delivery_id" do
           {:ok, ingress} =
             %Ingress{}
             |> Ingress.changeset(%{
               adapter_module: "SomeAdapter",
               delivery_id: Ecto.UUID.generate(),  # never persisted as a real delivery
               normalized_status: "delivered",
               ingress_state: :queued
             })
             |> Repo.insert()

           assert :ok = ProcessFeedbackWorker.perform(%Oban.Job{args: %{"ingress_id" => ingress.id}})

           reloaded = Repo.get!(Ingress, ingress.id)
           assert reloaded.ingress_state == :ignored
           assert reloaded.ignored_reason == :delivery_not_found
           assert reloaded.processed_at

           # No delivery attempt, no signal emitted (delivery wasn't found)
           assert Repo.aggregate(Chimeway.DeliveryAttempt, :count) == 0
           assert Repo.aggregate(Signal, :count) == 0
         end
         ```

       - **Existing test "returns error if delivery cannot be found by provider_message_id" (lines 147-155)** — REWRITE same way for `:provider_message_id_not_found` reason:

         ```elixir
         test "marks ingress :ignored with :provider_message_id_not_found and returns :ok on stale provider_message_id" do
           {:ok, ingress} =
             %Ingress{}
             |> Ingress.changeset(%{
               adapter_module: "SomeAdapter",
               provider_message_id: "unknown_msg",
               normalized_status: "delivered",
               ingress_state: :queued
             })
             |> Repo.insert()

           assert :ok = ProcessFeedbackWorker.perform(%Oban.Job{args: %{"ingress_id" => ingress.id}})

           reloaded = Repo.get!(Ingress, ingress.id)
           assert reloaded.ingress_state == :ignored
           assert reloaded.ignored_reason == :provider_message_id_not_found
         end
         ```

    4. **Add a new `describe "perform/1 — safe-noop edge cases (Pitfall 2 + idempotency)"` block:**

       ```elixir
       describe "perform/1 — safe-noop edge cases (Pitfall 2 + idempotency)" do
         test "returns :ok when ingress row was hard-deleted between commit and perform" do
           # Pitfall 2: race against Repo.delete by test cleanup or operator action
           assert :ok = ProcessFeedbackWorker.perform(%Oban.Job{args: %{"ingress_id" => Ecto.UUID.generate()}})
         end

         test "returns :ok when ingress is already :ignored (idempotent dedup convergence)" do
           {:ok, ingress} =
             %Ingress{}
             |> Ingress.changeset(%{
               adapter_module: "SomeAdapter",
               delivery_id: Ecto.UUID.generate(),
               normalized_status: "delivered",
               ingress_state: :ignored,
               ignored_reason: :delivery_not_found,
               processed_at: DateTime.utc_now()
             })
             |> Repo.insert()

           assert :ok = ProcessFeedbackWorker.perform(%Oban.Job{args: %{"ingress_id" => ingress.id}})
         end

         test "returns :ok when ingress is already :processed (idempotent re-run)", %{delivery: delivery} do
           {:ok, ingress} =
             %Ingress{}
             |> Ingress.changeset(%{
               adapter_module: "SomeAdapter",
               delivery_id: delivery.id,
               normalized_status: "delivered",
               ingress_state: :processed,
               processed_at: DateTime.utc_now()
             })
             |> Repo.insert()

           assert :ok = ProcessFeedbackWorker.perform(%Oban.Job{args: %{"ingress_id" => ingress.id}})

           # No new delivery attempts — already processed, no double-run
           assert Repo.aggregate(Chimeway.DeliveryAttempt, :count) == 0
         end
       end
       ```

    5. **Add a new `describe "perform/1 — backwards-compat shim (A6, in-flight pre-Phase-33 jobs)"` block:**

       ```elixir
       describe "perform/1 — backwards-compat shim (A6, in-flight pre-Phase-33 jobs)" do
         test "processes legacy delivery_id args without an ingress row", %{delivery: delivery} do
           legacy_args = %{
             "delivery_id" => delivery.id,
             "status" => "bounced",
             "provider_response" => %{"x" => 1},
             "adapter_module" => "LegacyAdapter"
           }

           assert :ok = ProcessFeedbackWorker.perform(%Oban.Job{args: legacy_args})

           # Delivery attempt recorded, signal emitted — same lifecycle as new path
           assert Repo.aggregate(Chimeway.DeliveryAttempt, :count) == 1
           assert Repo.aggregate(Signal, :count) == 1

           # Crucially: NO ingress row created (legacy path doesn't write to ingress)
           assert Repo.aggregate(Ingress, :count) == 0
         end

         test "returns :ok safely on stale legacy delivery_id (T-33-RETRY for legacy path)" do
           legacy_args = %{
             "delivery_id" => Ecto.UUID.generate(),
             "status" => "delivered",
             "provider_response" => %{}
           }
           # Old behavior raised Ecto.NoResultsError — new shim returns :ok safely.
           assert :ok = ProcessFeedbackWorker.perform(%Oban.Job{args: legacy_args})
         end

         test "processes legacy provider_message_id args", %{delivery: delivery} do
           delivery = Ecto.Changeset.change(delivery, status: :dispatched) |> Repo.update!()
           {:ok, _} = Deliveries.record_attempt(delivery, %{
             outcome: :succeeded,
             adapter_module: "InitialAdapter",
             provider_message_id: "msg_legacy"
           })

           legacy_args = %{
             "provider_message_id" => "msg_legacy",
             "status" => "delivered",
             "provider_response" => %{},
             "adapter_module" => "LegacyAdapter"
           }

           assert :ok = ProcessFeedbackWorker.perform(%Oban.Job{args: legacy_args})
         end
       end
       ```

    6. **REMOVE `assert_raise Ecto.NoResultsError`** entirely from this file (T-33-RETRY closure).
  </action>
  <verify>
    <automated>grep -q "alias Chimeway.Webhooks.Ingress" test/chimeway/webhooks/process_feedback_worker_test.exs && grep -q ":delivery_not_found" test/chimeway/webhooks/process_feedback_worker_test.exs && grep -q ":provider_message_id_not_found" test/chimeway/webhooks/process_feedback_worker_test.exs && grep -q "ingress_state == :ignored" test/chimeway/webhooks/process_feedback_worker_test.exs && grep -q "ingress_state == :processed" test/chimeway/webhooks/process_feedback_worker_test.exs && grep -q "Pitfall 2" test/chimeway/webhooks/process_feedback_worker_test.exs && grep -q "backwards-compat shim" test/chimeway/webhooks/process_feedback_worker_test.exs && grep -q '%{"ingress_id"' test/chimeway/webhooks/process_feedback_worker_test.exs && ! grep -q "assert_raise Ecto.NoResultsError" test/chimeway/webhooks/process_feedback_worker_test.exs && mix test test/chimeway/webhooks/process_feedback_worker_test.exs</automated>
  </verify>
  <acceptance_criteria>
    - File contains `alias Chimeway.Webhooks.Ingress`.
    - File contains `describe "perform/1 — safe-noop edge cases (Pitfall 2 + idempotency)"`.
    - File contains `describe "perform/1 — backwards-compat shim (A6, in-flight pre-Phase-33 jobs)"`.
    - File contains `:delivery_not_found` (the ignored_reason atom).
    - File contains `:provider_message_id_not_found`.
    - File contains `reloaded.ingress_state == :ignored`.
    - File contains `reloaded.ingress_state == :processed`.
    - File contains `%{"ingress_id" => ingress.id}` (the new arg shape).
    - File contains a test for legacy `%{"delivery_id" => …}` args (the A6 shim).
    - File contains a test for legacy `%{"provider_message_id" => …}` args (the A6 shim).
    - File contains a test for hard-deleted ingress (Pitfall 2 — `Ecto.UUID.generate()` ingress_id, asserts `:ok`).
    - File does NOT contain `assert_raise Ecto.NoResultsError` (T-33-RETRY closure).
    - File does NOT contain `String.to_atom(` as a function call (atom-safety; check via `grep -F "String.to_atom("`).
    - `mix test test/chimeway/webhooks/process_feedback_worker_test.exs` exits 0 (all tests GREEN, including new safe-noop and shim tests).
  </acceptance_criteria>
  <done>The worker test file enforces ingress-driven contract, safe-noop ignored paths, idempotent re-perform, hard-delete-race, and backwards-compat shim. All tests green. T-33-RETRY closed: no `assert_raise Ecto.NoResultsError` remains anywhere in the file.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Queue → DB | Async Oban job pulls a verified ingress_id and reads the durable row before any state change. |
| DB → DB | Worker updates ingress_state and inserts delivery_attempt + signal in the same logical action. |

## STRIDE Threat Register (Plan 03 scope)

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-33-RETRY | DoS (queue retry storm) | `ProcessFeedbackWorker.perform/1` | mitigate | Replace `Deliveries.get_delivery!/1` (raises) with `Deliveries.fetch_delivery/1` (returns `{:error, :not_found}`). On stale id, write `ingress_state: :ignored, ignored_reason: :delivery_not_found | :provider_message_id_not_found, processed_at: <utc_now>` and return `:ok` from the worker. The `normalize_perform_result/1` table mirrors `WorkflowProgressionWorker.normalize_progress_result/1` so all understood-but-ignored outcomes collapse to `:ok` (no Oban retry). Verified by Tests "marks ingress :ignored with :delivery_not_found" and "marks ingress :ignored with :provider_message_id_not_found" in Task 2. |
| T-33-PII (worker-side) | Information Disclosure | persisted ingress row updates | mitigate | Worker only sets `ingress_state`, `ignored_reason`, and `processed_at` via `Ingress.changeset/2`. No raw `Oban.Job.args` content (which contains arbitrary fields in legacy shim path) is ever written to the ingress row. The schema has no `provider_response` field (Plan 01 enforcement); it is structurally impossible to leak payload onto the ingress row. |
| T-33-AUTH-LEAK (worker-side) | Information Disclosure / Tampering | atom table | mitigate | Worker uses `String.to_existing_atom/1` only on the bounded set after `canonicalize_status/1`. `:ignored_reason` values are passed as atoms from the worker code (not from untrusted input). Acceptance criterion forbids `String.to_atom/1`. |
| T-33-IDEMPOTENT | Tampering / Repudiation | re-perform of same job | mitigate | `:ignored` and `:processed` ingress_state branches return `:ok` without re-applying side effects. Verified by Tests "returns :ok when ingress is already :ignored" and "returns :ok when ingress is already :processed" in Task 2. Prevents double-attempt rows or double-signal emission on Oban retries. |
</threat_model>

<verification>
- `mix compile --warnings-as-errors` exits 0.
- `mix test test/chimeway/webhooks/process_feedback_worker_test.exs` exits 0 (all tests GREEN — original 4 rewritten, 3 new safe-noop edge cases, 3 new A6 shim tests, no `assert_raise Ecto.NoResultsError` remains).
- `mix test test/chimeway/webhooks_test.exs` STILL exits 0 (Plan 02 tests remain green — `enqueue/1` removal does not break Plan 02 because Plan 02 already does NOT call `enqueue/1`).
- `grep -c "def enqueue" lib/chimeway/webhooks/process_feedback_worker.ex` returns 0.
- `grep -c "Deliveries.get_delivery!" lib/chimeway/webhooks/process_feedback_worker.ex` returns 0.
- `grep -c "queue: :default" lib/chimeway/webhooks/process_feedback_worker.ex` returns 0.
- `grep -q "if Code.ensure_loaded?(Oban) do" lib/chimeway/webhooks/process_feedback_worker.ex` succeeds.
</verification>

<success_criteria>
- `Chimeway.Webhooks.ProcessFeedbackWorker` reads `%{"ingress_id" => binary}`, looks up the ingress row, and drives the feedback pipeline from durable state alone (D-01, D-02).
- Stale `delivery_id` and `provider_message_id` callbacks become `ingress_state: :ignored` audit rows with explicit `ignored_reason`, returning `:ok` to Oban (D-06, D-07, D-08; T-33-RETRY closed).
- The `enqueue/1` antipattern helper is gone — callers go through `Chimeway.Webhooks.process/4` exclusively (T-33-ATOMIC closure consolidated with Plan 02).
- Hard-deleted ingress rows and already-processed rows return `:ok` idempotently (Pitfall 2; T-33-IDEMPOTENT).
- Backwards-compat shim handles in-flight pre-Phase-33 args shapes (`%{"delivery_id"\|"provider_message_id" => …}`) without raising — A6 deploy-safety honored.
- The module is wrapped in `if Code.ensure_loaded?(Oban) do … end` and uses `queue: :chimeway_delivery` (Phase 33 alignment).
</success_criteria>

<output>
After completion, create `.planning/phases/33-webhook-ingress-durability/33-03-SUMMARY.md` per `$HOME/.claude/get-shit-done/templates/summary.md`. Include:
- `requirements_completed: [FEED-01, FEED-02]` (worker-side closure of FEED-01 safe-handling and FEED-02 normalized-outcome consumption)
- `threats_mitigated: [T-33-RETRY, T-33-PII (worker-side), T-33-AUTH-LEAK (worker-side), T-33-IDEMPOTENT]`
- Deploy note: A6 shim is in place; remove in Phase 34 or v1.5 cleanup phase after one production release cycle.
</output>
