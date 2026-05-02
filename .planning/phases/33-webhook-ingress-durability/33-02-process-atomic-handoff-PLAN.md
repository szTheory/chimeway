---
phase: 33-webhook-ingress-durability
plan: 02
type: execute
wave: 2
depends_on: [33-01]
files_modified:
  - lib/chimeway/webhooks.ex
  - lib/chimeway/deliveries.ex
  - test/chimeway/webhooks_test.exs
autonomous: true
requirements: [FEED-01]
requirements_addressed: [FEED-01]
tags: [elixir, ecto, multi, oban, webhook, atomic, transaction]

must_haves:
  truths:
    - "`Chimeway.Webhooks.process/4` returns success ONLY when one `Ecto.Multi` transaction has committed BOTH the ingress row insert AND the `ProcessFeedbackWorker` Oban job (D-02)."
    - "If `Oban.insert/3` fails inside the Multi, the ingress row is rolled back and `process/4` returns `{:error, _reason}` — neither side effect persists (T-33-ATOMIC closed)."
    - "Every non-success failure mode returns a tagged tuple (`{:error, :unauthorized | :unparseable_body | :unresolvable_delivery | :unnormalizable_feedback | %Ecto.Changeset{} | term()}`); no bare `:error` returns remain (Pitfall 1)."
    - "Unauthorized signature failures and unparseable bodies leave the ingress table EMPTY (D-09 / T-33-AUTH-LEAK)."
    - "`Chimeway.Deliveries.fetch_delivery/1` exists as a non-raising sibling to `get_delivery!/1` (required by Plan 03; co-located here for Wave-2 parallelism)."
  artifacts:
    - path: "lib/chimeway/webhooks.ex"
      provides: "Atomic Multi+Oban handoff — Chimeway.Webhooks.process/4 rewritten per D-02"
      contains: "Ecto.Multi.new()"
    - path: "lib/chimeway/deliveries.ex"
      provides: "Non-raising fetch_delivery/1 helper"
      contains: "def fetch_delivery"
    - path: "test/chimeway/webhooks_test.exs"
      provides: "Atomic-handoff + rollback + tagged-error assertions"
      contains: "assert_enqueued"
  key_links:
    - from: "lib/chimeway/webhooks.ex"
      to: "lib/chimeway/webhooks/ingress.ex"
      via: "alias + Ingress.changeset/2 inside Multi.insert(:ingress, …)"
      pattern: "Multi.insert\\(:ingress"
    - from: "lib/chimeway/webhooks.ex"
      to: "lib/chimeway/webhooks/process_feedback_worker.ex"
      via: "Oban.insert(:job, fn …) building ProcessFeedbackWorker.new(%{\"ingress_id\" => …})"
      pattern: "ProcessFeedbackWorker.new\\(%\\{\"ingress_id\""
    - from: "test/chimeway/webhooks_test.exs"
      to: "lib/chimeway/webhooks.ex"
      via: "Webhooks.process/4 contract assertions"
      pattern: "Webhooks.process"
---

<objective>
Rewrite `Chimeway.Webhooks.process/4` from the optimistic-enqueue antipattern (current line 21: `ProcessFeedbackWorker.enqueue(args)` which discards `Oban.insert/1`'s return) to the atomic Multi+Oban handoff template from `Chimeway.Signal.track/4`. Add the `Chimeway.Deliveries.fetch_delivery/1` non-raising sibling helper that Plan 03 needs. Tighten all failure modes to tagged tuples per D-03 / Pitfall 1.

Purpose: Closes audit gap T-33-ATOMIC ("Webhook ingest can report success even if async processing was never queued"). After this plan, host controllers (and `assert_enqueued` tests) can finally trust `{:ok, _ingress}` as "durably handed off."

Output: `process/4` returns `{:ok, %Ingress{}}` only after Multi commit; all error paths return tagged tuples; rollback is testable; `fetch_delivery/1` is exported.
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
@lib/chimeway/signal.ex
@lib/chimeway/webhooks.ex
@lib/chimeway/webhooks/ingress.ex
@lib/chimeway/deliveries.ex
@lib/chimeway/adapter.ex
@test/chimeway/signal_test.exs
@test/chimeway/webhooks_test.exs

<interfaces>
<!-- Source of truth: lib/chimeway/signal.ex (read 2026-05-01) is the literal template. -->

From `lib/chimeway/signal.ex` (lines 30-40 — copy this shape verbatim, swap signal->ingress):
```elixir
Multi.new()
|> Multi.insert(:signal, Signal.changeset(%Signal{}, attrs))
|> Oban.insert(:job, fn %{signal: signal} ->
  SignalRouterWorker.new(%{"signal_id" => signal.id})
end)
|> Repo.transaction()
|> case do
  {:ok, %{signal: signal}} -> {:ok, signal}
  {:error, _step, reason, _changes} -> {:error, reason}
end
```

From `lib/chimeway/webhooks/ingress.ex` (Plan 01 output):
```elixir
defmodule Chimeway.Webhooks.Ingress do
  @type t :: %__MODULE__{}
  schema "chimeway_webhook_ingress" do ... end
  def changeset(ingress, attrs) ...   # fields: adapter_module, delivery_id,
                                       # provider_message_id, provider_event_id,
                                       # normalized_status, ingress_state, ignored_reason
end
```

From `lib/chimeway/deliveries.ex` (sibling to add — analog at lines 434-445):
```elixir
@spec get_delivery_by_provider_message_id(String.t()) :: {:ok, Delivery.t()} | {:error, :not_found}
def get_delivery_by_provider_message_id(provider_message_id) when is_binary(provider_message_id) do
  case Repo.one( ... ) do
    %DeliveryAttempt{delivery: %Delivery{} = delivery} -> {:ok, delivery}
    _ -> {:error, :not_found}
  end
end
```

From `test/chimeway/signal_test.exs` (atomic-handoff assertion shape):
```elixir
assert {:ok, %Signal{} = signal} = Chimeway.Signal.track(...)
assert Repo.get(Signal, signal.id)
assert_enqueued(worker: SignalRouterWorker, args: %{"signal_id" => signal.id})
```
</interfaces>
</context>

<assumptions>
<!-- Per RESEARCH.md A4 — surfaced for user confirm/override. MEDIUM risk. -->

- **A4 (provider_event_id extraction mechanism):** This plan implements D-05's "stable provider event id" extraction by checking `function_exported?(adapter_module, :resolve_provider_event_id, 1)` and calling that optional callback if present. Adapters that do NOT define `resolve_provider_event_id/1` get `provider_event_id = nil` (no dedup for that adapter — partial unique index ignores NULLs). This adds an OPTIONAL fourth callback to the `Chimeway.Adapter` behaviour.
  - **Alternative:** Config-driven extraction via `Application.get_env(:chimeway, :provider_event_id_paths, %{...})` — host configures a JSON path per adapter. More flexible but adds config sprawl and indirection.
  - **Default recommendation (Research):** Optional callback. Lower indirection, more explicit, no config required for adapters that don't need dedup.
  - **Override:** If you prefer config-driven extraction, override before Task 2 begins and the executor will substitute that mechanism. Either way, T-33-DEDUP is satisfied because the partial unique index ignores NULLs.
</assumptions>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Add Deliveries.fetch_delivery/1 non-raising helper</name>
  <files>lib/chimeway/deliveries.ex</files>
  <read_first>
    - lib/chimeway/deliveries.ex (lines 420-460 — find `get_delivery!/1` and `get_delivery_by_provider_message_id/1`)
    - .planning/phases/33-webhook-ingress-durability/33-RESEARCH.md (lines ~840-855 — the literal `fetch_delivery/1` body)
    - .planning/phases/33-webhook-ingress-durability/33-PATTERNS.md (§ lib/chimeway/deliveries.ex)
  </read_first>
  <behavior>
    - Test 1: `Deliveries.fetch_delivery(id)` returns `{:ok, %Delivery{}}` when `id` matches an existing row.
    - Test 2: `Deliveries.fetch_delivery(id)` returns `{:error, :not_found}` when `id` does NOT match (unlike `get_delivery!/1` which raises).
    - Test 3: `Deliveries.fetch_delivery/1` is `is_binary/1`-guarded — non-binary input does NOT match the function clause.
  </behavior>
  <action>
    Add this function to `lib/chimeway/deliveries.ex` immediately AFTER `get_delivery!/1` (around line 428-429, before `get_delivery_by_provider_message_id/1`). Body is byte-identical to `33-RESEARCH.md` lines 843-855:

    ```elixir
    @doc """
    Fetches a delivery by ID without raising. Pairs with `get_delivery!/1` for
    queue-boundary callers that prefer explicit `{:error, :not_found}`.

    Added in Phase 33 to satisfy D-06 (worker must stop using raising lookup
    paths at the queue boundary). Used by `Chimeway.Webhooks.ProcessFeedbackWorker`.
    """
    @spec fetch_delivery(binary()) :: {:ok, Delivery.t()} | {:error, :not_found}
    def fetch_delivery(id) when is_binary(id) do
      case Repo.get(Delivery, id) do
        %Delivery{} = delivery -> {:ok, delivery}
        nil -> {:error, :not_found}
      end
    end
    ```

    Add a corresponding `describe` block to `test/chimeway/deliveries_test.exs` (or wherever the existing `get_delivery!/1` tests live — discover via `grep -rn "get_delivery!" test/` and add tests in the same file). Three tests covering: success, not-found returns `{:error, :not_found}` (NOT raise), and `is_binary/1` guard (calling with `nil` or an integer should `FunctionClauseError`).

    Note: do NOT modify the existing `get_delivery!/1` (callers depend on the raising behavior elsewhere). `fetch_delivery/1` is a NEW SIBLING — additive only.
  </action>
  <verify>
    <automated>grep -q "def fetch_delivery(id) when is_binary(id)" lib/chimeway/deliveries.ex &amp;&amp; grep -q "@spec fetch_delivery" lib/chimeway/deliveries.ex &amp;&amp; mix compile --warnings-as-errors</automated>
  </verify>
  <acceptance_criteria>
    - File `lib/chimeway/deliveries.ex` contains `def fetch_delivery(id) when is_binary(id) do`.
    - File contains `@spec fetch_delivery(binary()) :: {:ok, Delivery.t()} | {:error, :not_found}`.
    - File contains `case Repo.get(Delivery, id) do` inside the function body.
    - The existing `get_delivery!/1` is UNCHANGED (`grep -A1 "def get_delivery!" lib/chimeway/deliveries.ex` still shows the bang form).
    - `mix compile --warnings-as-errors` exits 0.
    - `mix test test/chimeway/deliveries_test.exs` exits 0 (or whichever test file was extended; new tests pass).
  </acceptance_criteria>
  <done>`Chimeway.Deliveries.fetch_delivery/1` is exported and tested; available for Plan 03 worker pivot.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Rewrite Chimeway.Webhooks.process/4 to atomic Multi+Oban handoff</name>
  <files>lib/chimeway/webhooks.ex</files>
  <read_first>
    - lib/chimeway/signal.ex (full file — the canonical template; lines 30-40 are copy-target)
    - lib/chimeway/webhooks.ex (current 31-line file — the antipattern being replaced)
    - lib/chimeway/webhooks/ingress.ex (Plan 01 output — fields and changeset contract)
    - lib/chimeway/adapter.ex (full — confirms callback contract: `verify_webhook/3`, `resolve_delivery/1`, `normalize_feedback/1`; check `@optional_callbacks` declaration if A4 callback is added)
    - .planning/phases/33-webhook-ingress-durability/33-RESEARCH.md (§ Code Examples > `Chimeway.Webhooks.process/4` rewrite — lines ~607-704; copy verbatim)
    - .planning/phases/33-webhook-ingress-durability/33-PATTERNS.md (§ lib/chimeway/webhooks.ex)
  </read_first>
  <behavior>
    - Test 1: `process/4` with valid signature, parseable body, and resolvable delivery returns `{:ok, %Chimeway.Webhooks.Ingress{}}` AND `Repo.get!(Ingress, ingress.id)` succeeds AND `assert_enqueued worker: ProcessFeedbackWorker, args: %{"ingress_id" => ingress.id}`.
    - Test 2: `process/4` with bad signature returns `{:error, :unauthorized}` AND `Repo.aggregate(Ingress, :count) == 0` (D-09 / T-33-AUTH-LEAK).
    - Test 3: `process/4` with malformed JSON body returns `{:error, :unparseable_body}` AND `Repo.aggregate(Ingress, :count) == 0`.
    - Test 4: `process/4` with adapter `resolve_delivery/1` returning `:error` returns `{:error, :unresolvable_delivery}` AND `Repo.aggregate(Ingress, :count) == 0`.
    - Test 5: `process/4` with adapter `normalize_feedback/1` returning `:error` returns `{:error, :unnormalizable_feedback}` AND `Repo.aggregate(Ingress, :count) == 0`.
    - Test 6: When the Oban job insert fails (mock via a sentinel adapter or by inserting a duplicate `provider_event_id` that triggers an Oban-side conflict), `process/4` returns `{:error, _}` AND `Repo.aggregate(Ingress, :count) == 0` (Multi rollback verified — T-33-ATOMIC). NOTE: The simplest mechanism is to start with a sandboxed setup that guarantees Oban operates inline; failure injection can use a test-only adapter that returns a malformed `feedback_info` triggering a changeset error AT the `:ingress` step (forcing rollback). If that path is awkward, use `Oban.Testing` `with_testing_mode :manual` or override the worker via an Oban config; document the mechanism chosen in the test docstring.
  </behavior>
  <action>
    Replace the entire body of `lib/chimeway/webhooks.ex` with this implementation (copied from `33-RESEARCH.md` § Code Examples > `Chimeway.Webhooks.process/4` rewrite — lines 610-705):

    ```elixir
    defmodule Chimeway.Webhooks do
      @moduledoc """
      Pure function boundary for synchronously ingesting and verifying inbound webhooks.

      Success returns ONLY when the ingress row and the ProcessFeedbackWorker job
      have both committed in a single transaction. Returning `{:ok, ingress}` is
      the host's acknowledgment cue — the host MAY return 2xx to the provider
      (Phase 33 D-03). Any error tuple means the host MUST return non-2xx so the
      provider retries.

      Unauthorized signature failures and unparseable bodies do NOT create a
      durable ingress row (Phase 33 D-09). Only verified, parsed, normalized
      callbacks enter the durable inbound lifecycle.
      """

      alias Chimeway.Repo
      alias Chimeway.Webhooks.{Ingress, ProcessFeedbackWorker}
      alias Ecto.Multi

      @spec process(module(), binary(), list(), keyword()) ::
              {:ok, Ingress.t()}
              | {:error, :unauthorized}
              | {:error, :unparseable_body}
              | {:error, :unresolvable_delivery}
              | {:error, :unnormalizable_feedback}
              | {:error, Ecto.Changeset.t()}
              | {:error, term()}
      def process(adapter_module, raw_body, headers, config) do
        with :ok <- adapter_module.verify_webhook(raw_body, headers, config),
             {:ok, parsed} <- decode_body(raw_body),
             {:ok, delivery_info} <- resolve_delivery(adapter_module, parsed),
             {:ok, feedback_info} <- normalize_feedback(adapter_module, parsed),
             {:ok, provider_event_id} <- extract_provider_event_id(adapter_module, parsed) do

          attrs = %{
            adapter_module: to_string(adapter_module),
            delivery_id: delivery_info[:delivery_id],
            provider_message_id: delivery_info[:provider_message_id],
            provider_event_id: provider_event_id,
            normalized_status: to_string(feedback_info.status),
            ingress_state: :queued
          }

          Multi.new()
          |> Multi.insert(:ingress, Ingress.changeset(%Ingress{}, attrs),
               on_conflict: :nothing,
               conflict_target: {:unsafe_fragment, ~s|("adapter_module", "provider_event_id") WHERE "provider_event_id" IS NOT NULL|},
               returning: true
             )
          |> Oban.insert(:job, fn %{ingress: ingress} ->
            ProcessFeedbackWorker.new(%{"ingress_id" => ingress.id})
          end)
          |> Repo.transaction()
          |> case do
            {:ok, %{ingress: ingress}} -> {:ok, ingress}
            {:error, _step, reason, _changes} -> {:error, reason}
          end
        end
      end

      defp decode_body(raw_body) do
        case Jason.decode(raw_body) do
          {:ok, parsed} -> {:ok, parsed}
          {:error, _} -> {:error, :unparseable_body}
        end
      end

      defp resolve_delivery(adapter_module, parsed) do
        case adapter_module.resolve_delivery(parsed) do
          {:ok, info} -> {:ok, info}
          _ -> {:error, :unresolvable_delivery}
        end
      end

      defp normalize_feedback(adapter_module, parsed) do
        case adapter_module.normalize_feedback(parsed) do
          {:ok, info} -> {:ok, info}
          _ -> {:error, :unnormalizable_feedback}
        end
      end

      # Optional adapter callback (A4) — adapters that don't expose stable provider
      # event ids return :none / are not function_exported and the row stores nil
      # (no dedup for that adapter — the partial unique index ignores NULLs).
      defp extract_provider_event_id(adapter_module, parsed) do
        if function_exported?(adapter_module, :resolve_provider_event_id, 1) do
          case adapter_module.resolve_provider_event_id(parsed) do
            {:ok, id} when is_binary(id) -> {:ok, id}
            :none -> {:ok, nil}
            _ -> {:ok, nil}
          end
        else
          {:ok, nil}
        end
      end
    end
    ```

    REMOVED from the previous version: the bare `_ -> :error` catch-all (Pitfall 1), the `stringify_keys/1` helper (no longer needed — the Multi pipeline takes a map directly), the indirect `ProcessFeedbackWorker.enqueue/1` call (T-33-ATOMIC fix — that helper is being deleted in Plan 03 Task 1).

    Also update `lib/chimeway/adapter.ex` to declare `resolve_provider_event_id/1` as an OPTIONAL callback (per A4):

    ```elixir
    @callback resolve_provider_event_id(parsed :: map()) :: {:ok, binary()} | :none

    @optional_callbacks [resolve_provider_event_id: 1]
    ```

    (Add to existing `@optional_callbacks` list if one exists; otherwise create the line. Confirm via `grep "@optional_callbacks" lib/chimeway/adapter.ex` whether the attribute exists.)

    Per T-33-ATOMIC: the `Repo.transaction/1` `case` clause is the ONLY success path — `{:ok, %{ingress: ingress}}` is the ONLY pattern returning `{:ok, _}`. Any Multi step failure (`{:error, _step, reason, _changes}`) returns `{:error, reason}`. The previous bug (always-return-success) is structurally impossible after this rewrite.

    Per D-09 / T-33-AUTH-LEAK: the `with` happy-path is the ONLY path that reaches `Multi.new()`. Any short-circuit in the `with` (verify failure, JSON parse failure, resolve failure, normalize failure) returns the tagged-tuple BEFORE any DB write. There is no `else` clause needed — the `with` propagates `{:error, _}` shapes verbatim.
  </action>
  <verify>
    <automated>grep -q "Ecto.Multi" lib/chimeway/webhooks.ex &amp;&amp; grep -q "Multi.insert(:ingress" lib/chimeway/webhooks.ex &amp;&amp; grep -q 'Oban.insert(:job, fn %{ingress: ingress}' lib/chimeway/webhooks.ex &amp;&amp; grep -q "ProcessFeedbackWorker.new(%{\"ingress_id\"" lib/chimeway/webhooks.ex &amp;&amp; ! grep -q "ProcessFeedbackWorker.enqueue" lib/chimeway/webhooks.ex &amp;&amp; ! grep -E "_\s*->\s*:error(\s|$)" lib/chimeway/webhooks.ex &amp;&amp; mix compile --warnings-as-errors</automated>
  </verify>
  <acceptance_criteria>
    - File `lib/chimeway/webhooks.ex` contains `alias Ecto.Multi`.
    - File contains `Multi.new()`.
    - File contains `Multi.insert(:ingress, Ingress.changeset(%Ingress{}, attrs)`.
    - File contains `on_conflict: :nothing`.
    - File contains `conflict_target: {:unsafe_fragment,` and `provider_event_id IS NOT NULL`.
    - File contains `Oban.insert(:job, fn %{ingress: ingress}`.
    - File contains `ProcessFeedbackWorker.new(%{"ingress_id" => ingress.id})`.
    - File contains `|> Repo.transaction()`.
    - File contains `{:ok, %{ingress: ingress}} -> {:ok, ingress}`.
    - File contains `{:error, _step, reason, _changes} -> {:error, reason}`.
    - File contains `{:error, :unparseable_body}`.
    - File contains `{:error, :unresolvable_delivery}`.
    - File contains `{:error, :unnormalizable_feedback}`.
    - File contains `function_exported?(adapter_module, :resolve_provider_event_id, 1)` (A4 mechanism).
    - File does NOT contain `ProcessFeedbackWorker.enqueue` (the antipattern being deleted).
    - File does NOT contain a bare `_ -> :error` catch-all (Pitfall 1). Verify command uses `! grep -E "_\s*->\s*:error(\s|$)"` so the antipattern is matched even when followed by newline or end-of-file (POSIX-portable extended regex; the previous `[^_]` form silently passed at line/file end).
    - `lib/chimeway/adapter.ex` contains `:resolve_provider_event_id` (the optional callback).
    - `mix compile --warnings-as-errors` exits 0.
    - `@spec process/4` declares the union type with at least 5 distinct `{:error, _}` variants.
  </acceptance_criteria>
  <done>`process/4` is the atomic Multi+Oban handoff; `enqueue/1` indirection is gone; tagged tuples replace bare `:error`; the optional `resolve_provider_event_id/1` adapter callback is declared.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Rewrite test/chimeway/webhooks_test.exs for atomic-handoff contract</name>
  <files>test/chimeway/webhooks_test.exs</files>
  <read_first>
    - test/chimeway/signal_test.exs (full — the canonical Multi+Oban assertion shape; copy describe-block patterns)
    - test/chimeway/webhooks_test.exs (current — the existing `MockAdapter` and 4 tests being rewritten)
    - lib/chimeway/webhooks.ex (Task 2 output — the contract being tested)
    - lib/chimeway/webhooks/ingress.ex (Plan 01 output — for `assert %Ingress{} = ...` matches)
    - .planning/phases/33-webhook-ingress-durability/33-PATTERNS.md (§ test/chimeway/webhooks_test.exs)
    - .planning/phases/33-webhook-ingress-durability/33-RESEARCH.md (§ Validation Architecture > Phase Requirements → Test Map)
  </read_first>
  <action>
    Modify `test/chimeway/webhooks_test.exs` per these steps:

    1. **Preserve the existing `defmodule MockAdapter`** at the top (lines 7-23 — its 4 callbacks are already correct and used elsewhere).

    2. **Extend `MockAdapter`** with an optional `resolve_provider_event_id/1` callback to support dedup tests AND loosen `resolve_delivery/1` so any binary `delivery_id` is accepted (the existing literal-`"del_123"` clauses force a binary_id-cast/Postgres rejection because the schema's `:delivery_id` field is `:binary_id`; only real UUIDs pass DB insertion):

       ```elixir
       # Loosen the existing literal-id pattern so any UUID-shaped binary works.
       # Replace the existing `def resolve_delivery(%{"id" => "del_123"})` clause
       # (and the `def resolve_delivery(%{"msg_id" => "msg_123"})` clause) with:
       def resolve_delivery(%{"id" => id}) when is_binary(id), do: {:ok, %{delivery_id: id}}
       def resolve_delivery(%{"msg_id" => pid}) when is_binary(pid), do: {:ok, %{provider_message_id: pid}}
       # Keep the catch-all:
       def resolve_delivery(_), do: :error

       # Optional A4 callback for dedup tests:
       def resolve_provider_event_id(%{"event_id" => id}) when is_binary(id), do: {:ok, id}
       def resolve_provider_event_id(_), do: :none
       ```

       Place these clauses inside the existing `defmodule MockAdapter do … end` after the existing callbacks. Tests then pass UUIDs via `Ecto.UUID.generate()` so the schema's `:binary_id` cast accepts the value (the previous literal `"del_123"` would have failed at DB insert as a Postgrex.Error, not surfaced as `%Ecto.Changeset{}`).

    3. **Add a second `defmodule FailingOnInsertAdapter`** for the rollback test (T-33-ATOMIC). The mechanism MUST produce an `Ecto.Changeset` error inside the `:ingress` Multi step (the previous "not-a-uuid" `delivery_id` mechanism does NOT — `:binary_id` casts accept any string at the changeset level and fail only at the Postgres layer as a `Postgrex.Error`, which the test cannot match against `%Ecto.Changeset{}`).

       Use this mechanism instead: have `FailingOnInsertAdapter.normalize_feedback/1` return `{:ok, %{status: :unknown_status}}`. The `with`-pipeline accepts the `{:ok, _}` shape, so it reaches `Multi.new()`. The schema's `validate_inclusion(:normalized_status, ~w(delivered bounced failed))` then fails the `:ingress` step changeset cleanly, yielding `{:error, :ingress, %Ecto.Changeset{}, _}` from `Repo.transaction/1` and `{:error, %Ecto.Changeset{}}` from `process/4` — exactly what the rollback test asserts against.

       ```elixir
       defmodule FailingOnInsertAdapter do
         @behaviour Chimeway.Adapter

         def deliver(_, _), do: {:ok, %{}}
         def verify_webhook(_body, [{"signature", "valid"}], _config), do: :ok
         def verify_webhook(_, _, _), do: {:error, :unauthorized}

         # Returns a real UUID so the :delivery_id field passes binary_id cast.
         # The changeset failure mechanism is normalize_feedback below — NOT delivery_id.
         def resolve_delivery(%{"id" => id}) when is_binary(id), do: {:ok, %{delivery_id: id}}
         def resolve_delivery(_), do: :error

         # FAILURE MECHANISM: returns a status atom NOT in ~w(delivered bounced failed).
         # validate_inclusion(:normalized_status, ...) fails the changeset at the :ingress
         # Multi step, which is exactly the rollback path we need to exercise.
         def normalize_feedback(_), do: {:ok, %{status: :unknown_status}}
       end
       ```

       Place this after `MockAdapter`. The rollback Test 6 in step 5 below uses `Ecto.UUID.generate()` to produce a valid binary_id-shaped delivery id, so the success-path-step-of-the-with-chain reaches `Multi.new()` and the changeset failure happens at `validate_inclusion`, NOT at the binary_id cast.

    4. **REWRITE the existing `describe "process/4"` block** to assert the new contract. Replace each existing test:

       - Line 27 `assert {:error, :unauthorized}` — keep as-is (the unauthorized contract is unchanged).
       - Line 30-32 `assert :error = …` (bad delivery) — change to `assert {:error, :unresolvable_delivery} = Webhooks.process(...)` AND `assert Repo.aggregate(Chimeway.Webhooks.Ingress, :count) == 0`.
       - Line 35-37 `assert :error = …` (bad feedback) — change to `assert {:error, :unnormalizable_feedback} = …` AND `assert Repo.aggregate(Chimeway.Webhooks.Ingress, :count) == 0`.
       - Line 40-53 (`{:ok, :enqueued}` with `delivery_id`) — change to:

         ```elixir
         delivery_uuid = Ecto.UUID.generate()
         body = Jason.encode!(%{"id" => delivery_uuid, "status" => "bounce"})
         assert {:ok, %Chimeway.Webhooks.Ingress{} = ingress} =
                  Webhooks.process(MockAdapter, body, [{"signature", "valid"}], [])

         # Ingress row durably committed
         assert persisted = Repo.get!(Chimeway.Webhooks.Ingress, ingress.id)
         assert persisted.adapter_module == to_string(MockAdapter)
         assert persisted.delivery_id == delivery_uuid
         assert persisted.normalized_status == "bounced"
         assert persisted.ingress_state == :queued
         # T-33-PII: persisted ingress row has NO raw payload column
         refute Map.has_key?(persisted, :provider_response)
         refute Map.has_key?(persisted, :headers)

         # Atomic Oban handoff
         assert_enqueued worker: Chimeway.Webhooks.ProcessFeedbackWorker,
                         args: %{"ingress_id" => ingress.id}
         ```

       - Line 55-66 (provider_message_id success) — same shape, asserting `persisted.provider_message_id == "msg_123"` and `persisted.delivery_id == nil`.

    5. **Add a new `describe "process/4 — atomic handoff (T-33-ATOMIC)"` block** mirroring `signal_test.exs:9-46`:

       ```elixir
       describe "process/4 — atomic handoff (T-33-ATOMIC)" do
         test "rolls back the ingress row when the :ingress Multi step changeset fails" do
           # Use FailingOnInsertAdapter — its normalize_feedback/1 returns
           # {:ok, %{status: :unknown_status}}, which fails the schema's
           # validate_inclusion(:normalized_status, ~w(delivered bounced failed))
           # AT THE CHANGESET LEVEL inside the :ingress Multi step. This produces
           # an Ecto.Changeset error (the assertion target), unlike a raw
           # binary_id-cast/Postgres failure which would surface as Postgrex.Error.
           # delivery_id uses Ecto.UUID.generate() so it passes the :binary_id cast
           # cleanly; the failure is isolated to validate_inclusion.
           delivery_uuid = Ecto.UUID.generate()
           body = Jason.encode!(%{"id" => delivery_uuid, "status" => "ok"})
           assert {:error, %Ecto.Changeset{} = cs} =
                    Webhooks.process(FailingOnInsertAdapter, body, [{"signature", "valid"}], [])
           # The changeset error is on :normalized_status (validate_inclusion failure).
           assert cs.errors[:normalized_status]

           # T-33-ATOMIC: NO ingress row, NO Oban job — both side effects rolled back atomically
           assert Repo.aggregate(Chimeway.Webhooks.Ingress, :count) == 0
           refute_enqueued worker: Chimeway.Webhooks.ProcessFeedbackWorker
         end

         test "unauthorized signature creates NO ingress row (D-09 / T-33-AUTH-LEAK)" do
           assert {:error, :unauthorized} =
                    Webhooks.process(MockAdapter, "any", [{"signature", "invalid"}], [])
           assert Repo.aggregate(Chimeway.Webhooks.Ingress, :count) == 0
           refute_enqueued worker: Chimeway.Webhooks.ProcessFeedbackWorker
         end

         test "unparseable body creates NO ingress row (D-09)" do
           # Note: body is sent BEFORE Jason.decode happens because verify_webhook
           # runs first; valid signature header lets us reach Jason.decode
           assert {:error, :unparseable_body} =
                    Webhooks.process(MockAdapter, "not-json", [{"signature", "valid"}], [])
           assert Repo.aggregate(Chimeway.Webhooks.Ingress, :count) == 0
           refute_enqueued worker: Chimeway.Webhooks.ProcessFeedbackWorker
         end
       end
       ```

       Use `refute_enqueued/1` from `Oban.Testing`. If the test setup needs `Oban.Testing.with_testing_mode/2`, document and add it.

    Do NOT add a dedup convergence test in this plan — that lives in Plan 05 to keep the wave dependency edges clean.

    Per the test header (already present): `use Chimeway.DataCase, async: true` and `use Oban.Testing, repo: Chimeway.Repo` are kept verbatim.
  </action>
  <verify>
    <automated>grep -q "atomic handoff" test/chimeway/webhooks_test.exs &amp;&amp; grep -q "{:error, :unresolvable_delivery}" test/chimeway/webhooks_test.exs &amp;&amp; grep -q "{:error, :unnormalizable_feedback}" test/chimeway/webhooks_test.exs &amp;&amp; grep -q "{:error, :unparseable_body}" test/chimeway/webhooks_test.exs &amp;&amp; grep -q '%Chimeway.Webhooks.Ingress{} = ingress' test/chimeway/webhooks_test.exs &amp;&amp; grep -q 'args: %{"ingress_id"' test/chimeway/webhooks_test.exs &amp;&amp; grep -q "refute_enqueued" test/chimeway/webhooks_test.exs &amp;&amp; ! grep -q "{:ok, :enqueued}" test/chimeway/webhooks_test.exs &amp;&amp; mix test test/chimeway/webhooks_test.exs</automated>
  </verify>
  <acceptance_criteria>
    - File `test/chimeway/webhooks_test.exs` contains `describe "process/4 — atomic handoff (T-33-ATOMIC)"`.
    - File contains `assert {:error, :unresolvable_delivery}`.
    - File contains `assert {:error, :unnormalizable_feedback}`.
    - File contains `assert {:error, :unparseable_body}`.
    - File contains `%Chimeway.Webhooks.Ingress{} = ingress`.
    - File contains `assert_enqueued worker: Chimeway.Webhooks.ProcessFeedbackWorker, args: %{"ingress_id"`.
    - File contains `refute_enqueued worker: Chimeway.Webhooks.ProcessFeedbackWorker`.
    - File contains `Repo.aggregate(Chimeway.Webhooks.Ingress, :count) == 0`.
    - File contains a second adapter module (e.g., `FailingOnInsertAdapter`) for the rollback test whose `normalize_feedback/1` returns `{:ok, %{status: :unknown_status}}` (failure mechanism documented in step 3 above; produces an `Ecto.Changeset` error at the `:ingress` Multi step's `validate_inclusion(:normalized_status, ...)`).
    - File contains `assert {:error, %Ecto.Changeset{} = cs}` matching the rollback test return shape.
    - File contains `assert cs.errors[:normalized_status]` (validates the failure is at the expected validate_inclusion step, not at a binary_id cast).
    - File contains `Ecto.UUID.generate()` (success-path tests use real UUIDs so the `:delivery_id` `:binary_id` cast accepts them; literal strings like `"del_123"` would Postgrex-error at insert).
    - File contains `def resolve_provider_event_id` (A4 callback).
    - File does NOT contain `{:ok, :enqueued}` (the old contract).
    - File does NOT contain `assert :error =` (bare-error antipattern).
    - `mix test test/chimeway/webhooks_test.exs` exits 0 (all tests GREEN, including the 3 new atomic-handoff tests).
  </acceptance_criteria>
  <done>The webhooks test file enforces the new `{:ok, %Ingress{}}` contract, the rollback invariant (T-33-ATOMIC), and the no-ingress-on-rejected-input invariant (T-33-AUTH-LEAK). All tests green.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| client → API | Untrusted provider HTTP request crosses into `Chimeway.Webhooks.process/4`. |
| API → DB | Verified+parsed callback crosses into durable Chimeway state via the Multi `:ingress` step. |
| API → Queue | Atomically with the ingress insert, an Oban job is enqueued via the Multi `:job` step. |

## STRIDE Threat Register (Plan 02 scope)

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-33-ATOMIC | Tampering / Repudiation | `Chimeway.Webhooks.process/4` | mitigate | Replace the `enqueue/1` antipattern (which discards `Oban.insert/1`'s return) with `Ecto.Multi` + `Oban.insert(:job, fn changes -> … end)` + `Repo.transaction/1`. The case-clause `{:ok, %{ingress: ingress}} -> {:ok, ingress}` is the ONLY success return path; `{:error, _step, reason, _changes} -> {:error, reason}` rolls back BOTH the ingress row and the Oban job atomically. Verified by Test 6 in Task 3 (rollback invariant). |
| T-33-AUTH-LEAK | Information Disclosure | `Chimeway.Webhooks.process/4` | mitigate | The `with` chain short-circuits BEFORE `Multi.new()` on any failure path: `verify_webhook/3` failure, `Jason.decode/1` failure, `resolve_delivery/1` failure, `normalize_feedback/1` failure all return tagged tuples before any DB write. D-09 — unauthorized + unparseable do NOT create ingress rows — verified by Tests 2/3 in Task 3 (`Repo.aggregate(Ingress, :count) == 0`). |
| T-33-PII | Information Disclosure | persisted ingress row | mitigate | The `attrs` map passed to `Ingress.changeset/2` contains ONLY normalized facts (adapter_module, delivery_id, provider_message_id, provider_event_id, normalized_status, ingress_state). Raw `parsed` JSON and `headers` are NOT persisted (D-04). Verified by Test 1 in Task 3 (`refute Map.has_key?(persisted, :provider_response)`) and Plan 01's schema-column absence enforcement. |
| T-33-DEDUP (write-side) | Spoofing (replay) | Multi `:ingress` step | mitigate | `on_conflict: :nothing` with `conflict_target: {:unsafe_fragment, ~s|("adapter_module", "provider_event_id") WHERE "provider_event_id" IS NOT NULL|}` collapses provider replays to the existing row at the DB level. Read-side dedup verification (idempotent perform on duplicate row) is Plan 05's responsibility. |
</threat_model>

<verification>
- `mix compile --warnings-as-errors` exits 0.
- `mix test test/chimeway/webhooks_test.exs` exits 0 (all tests pass, including the 3 new atomic-handoff/D-09 tests).
- `mix test test/chimeway/deliveries_test.exs` exits 0 (or whichever test file holds the new `fetch_delivery/1` tests).
- `grep -c "ProcessFeedbackWorker.enqueue" lib/` returns 0 (the antipattern is fully removed from `lib/`; remaining mentions allowed only in legacy test fixtures or summary docs).
- `grep -c "{:ok, :enqueued}" test/chimeway/webhooks_test.exs` returns 0.
</verification>

<success_criteria>
- `Chimeway.Webhooks.process/4` returns `{:ok, %Ingress{}}` on success and a tagged `{:error, atom_or_changeset}` for every failure mode (D-02, D-03, Pitfall 1).
- Both the ingress row insert and the Oban job insert commit in one `Ecto.Multi` transaction, or NEITHER commits (T-33-ATOMIC closed; verified by rollback test).
- Unauthorized and unparseable inputs leave the ingress table empty (D-09 / T-33-AUTH-LEAK closed; verified by `Repo.aggregate` assertions).
- `Chimeway.Deliveries.fetch_delivery/1` is exported and tested; available for Plan 03.
- The `Chimeway.Adapter` behaviour declares `resolve_provider_event_id/1` as an optional callback (A4 mechanism).
- The audit-gap claim "Webhook ingest can report success even if async processing was never queued" is now structurally impossible.
</success_criteria>

<output>
After completion, create `.planning/phases/33-webhook-ingress-durability/33-02-SUMMARY.md` per `$HOME/.claude/get-shit-done/templates/summary.md`. Include:
- `requirements_completed: [FEED-01]` (atomic-handoff acknowledgment boundary now closed)
- `threats_mitigated: [T-33-ATOMIC, T-33-AUTH-LEAK (write-side), T-33-PII (write-side), T-33-DEDUP (write-side)]`
- Note that Plan 05 owns the dedup-convergence read-side test and Plan 03 owns worker-side T-33-RETRY.
</output>
