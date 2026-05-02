if Code.ensure_loaded?(Oban) do
  defmodule Chimeway.Webhooks.ProcessFeedbackWorker do
    @moduledoc """
    Oban worker that processes inbound webhook feedback from a durable ingress row.

    Job args contain only `ingress_id` per Phase 33 D-01 (durable-spine-over-queue-archaeology).
    All correlation data — adapter identity, delivery_id, provider_message_id, normalized_status —
    is read from the persisted `Chimeway.Webhooks.Ingress` row rather than carried through
    Oban job args.

    Safe-noop semantics:
    - Hard-deleted ingress rows → `:ok` (Pitfall 2: race against operator/test cleanup).
    - Already-ignored rows → `:ok` (idempotent dedup convergence).
    - Already-processed rows → `:ok` (idempotent re-run on Oban retry).
    - Stale delivery_id → write `ingress_state: :ignored, ignored_reason: :delivery_not_found`, return `:ok`.
    - Stale provider_message_id → write `ingress_state: :ignored, ignored_reason: :provider_message_id_not_found`, return `:ok`.

    The `normalize_perform_result/1` table mirrors `WorkflowProgressionWorker.normalize_progress_result/1`
    so all understood-but-ignored outcomes collapse to `:ok` at the Oban queue boundary.

    Threats covered:
    - T-33-RETRY (DoS retry storm): stale lookups return `:ok` rather than raising.
    - T-33-PII (worker-side): only `ingress_state`, `ignored_reason`, `processed_at` are written;
      no raw job args or provider payload is persisted on the ingress row.
    - T-33-AUTH-LEAK (worker-side): `String.to_existing_atom/1` used only on the bounded
      `~w(succeeded bounced failed)` set after `canonicalize_status/1`. No `String.to_atom/1`.
    - T-33-IDEMPOTENT: `:ignored` and `:processed` branches return `:ok` without re-applying
      side effects, preventing double-attempt rows or double-signal emission on retries.

    Backwards-compat shim (A6, deploy-safety):
    Two extra `perform/1` heads handle the legacy `%{"delivery_id" => …}` and
    `%{"provider_message_id" => …}` arg shapes for one release cycle, protecting in-flight
    pre-Phase-33 Oban jobs. Drain the queue and remove these clauses in Phase 34 or v1.5.
    """

    use Oban.Worker, queue: :chimeway_delivery, max_attempts: 5

    alias Chimeway.{Deliveries, Repo}
    alias Chimeway.Webhooks.Ingress

    # === Primary ingress-driven perform ===

    @impl Oban.Worker
    def perform(%Oban.Job{args: %{"ingress_id" => ingress_id}}) when is_binary(ingress_id) do
      case Repo.get(Ingress, ingress_id) do
        nil ->
          # Ingress row hard-deleted between Multi commit and perform (Pitfall 2).
          # Nothing to retry — safe noop mirrors WorkflowProgressionWorker's
          # {:error, :workflow_run_not_found} -> :ok path.
          :ok

        %Ingress{ingress_state: :ignored} ->
          # Already handled by a prior duplicate that converged through the
          # partial unique index. Idempotent dedup convergence — no double write.
          :ok

        %Ingress{ingress_state: :processed} ->
          # Already handled by a prior successful run. Idempotent re-run on
          # Oban retries — no double attempt or signal emission.
          :ok

        %Ingress{} = ingress ->
          ingress
          |> apply_feedback()
          |> normalize_perform_result()
      end
    end

    # === Backwards-compat shim for in-flight pre-Phase-33 jobs (A6) ===
    # Drain runbook: keep for one release cycle, then remove in Phase 34 / v1.5.

    def perform(%Oban.Job{args: %{"delivery_id" => _} = legacy_args}),
      do: perform_legacy_args(legacy_args)

    def perform(%Oban.Job{args: %{"provider_message_id" => _} = legacy_args}),
      do: perform_legacy_args(legacy_args)

    # === Main pipeline ===

    # Dispatch by correlation key present on the ingress row.
    defp apply_feedback(%Ingress{delivery_id: id} = ingress) when is_binary(id) do
      case Deliveries.fetch_delivery(id) do
        {:ok, delivery} -> run_feedback_pipeline(delivery, ingress)
        {:error, :not_found} -> mark_ignored(ingress, :delivery_not_found)
      end
    end

    defp apply_feedback(%Ingress{provider_message_id: pmid} = ingress) when is_binary(pmid) do
      case Deliveries.get_delivery_by_provider_message_id(pmid) do
        {:ok, delivery} -> run_feedback_pipeline(delivery, ingress)
        {:error, :not_found} -> mark_ignored(ingress, :provider_message_id_not_found)
      end
    end

    defp run_feedback_pipeline(delivery, %Ingress{} = ingress) do
      outcome = String.to_existing_atom(canonicalize_status(ingress.normalized_status))
      attempt_params = build_attempt_params(outcome, ingress)

      with {:ok, _} <- Deliveries.record_attempt(delivery, attempt_params),
           {:ok, _} <- emit_signal(delivery, outcome),
           {:ok, _} <- mark_processed(ingress) do
        :ok
      end
    end

    defp mark_ignored(%Ingress{} = ingress, reason)
         when reason in [:delivery_not_found, :provider_message_id_not_found] do
      ingress
      |> Ingress.changeset(%{
        ingress_state: :ignored,
        ignored_reason: reason,
        processed_at: DateTime.utc_now()
      })
      |> Repo.update()
      |> case do
        {:ok, _} -> {:ignored, reason}
        {:error, changeset} -> {:error, changeset}
      end
    end

    defp mark_processed(%Ingress{} = ingress) do
      ingress
      |> Ingress.changeset(%{
        ingress_state: :processed,
        processed_at: DateTime.utc_now()
      })
      |> Repo.update()
    end

    # Mirror WorkflowProgressionWorker.normalize_progress_result/1: every
    # understood-but-ignored outcome is :ok at the queue boundary; only genuine
    # "should retry" failures return {:error, _} to trigger Oban retry.
    defp normalize_perform_result(:ok), do: :ok
    defp normalize_perform_result({:ignored, _reason}), do: :ok
    defp normalize_perform_result({:error, %Ecto.Changeset{} = cs}), do: {:error, cs}
    defp normalize_perform_result({:error, reason}), do: {:error, reason}

    # Status canonicalization stays minimal — Phase 34 owns broader vocabulary unification (D-14).
    defp canonicalize_status("delivered"), do: "succeeded"
    defp canonicalize_status(other), do: other

    defp build_attempt_params(outcome, %Ingress{} = ingress) do
      base = %{
        outcome: outcome,
        adapter_module: ingress.adapter_module
      }

      base =
        if outcome in [:bounced, :failed],
          do: Map.put(base, :error_class, to_string(outcome)),
          else: base

      if ingress.provider_message_id,
        do: Map.put(base, :provider_message_id, ingress.provider_message_id),
        else: base
    end

    defp emit_signal(delivery, outcome) do
      event_name = "chimeway.delivery.#{outcome}"
      payload = %{"delivery_id" => delivery.id, "status" => to_string(outcome)}

      payload =
        if outcome in [:bounced, :failed],
          do: Map.put(payload, "error", to_string(outcome)),
          else: payload

      Chimeway.Signal.track(delivery.tenant_id, delivery.actor_id, event_name, payload)
    end

    # === Legacy shim path (A6) — no ingress row write ===
    # Drives the same feedback pipeline as the new path but reads correlation keys
    # directly from legacy job args. Uses fetch_delivery/1 (NOT get_delivery!/1) so
    # stale-id legacy paths are also safe-noop (T-33-RETRY for legacy path).
    defp perform_legacy_args(%{"delivery_id" => delivery_id} = args) do
      case Deliveries.fetch_delivery(delivery_id) do
        {:ok, delivery} ->
          run_legacy_pipeline(delivery, args)

        {:error, :not_found} ->
          :ok
      end
    end

    defp perform_legacy_args(%{"provider_message_id" => pmid} = args) do
      case Deliveries.get_delivery_by_provider_message_id(pmid) do
        {:ok, delivery} ->
          run_legacy_pipeline(delivery, args)

        {:error, :not_found} ->
          :ok
      end
    end

    defp run_legacy_pipeline(delivery, args) do
      status = Map.get(args, "status", "")
      outcome = String.to_existing_atom(canonicalize_status(status))
      adapter_module = Map.get(args, "adapter_module", "")

      attempt_params = %{
        outcome: outcome,
        adapter_module: adapter_module
      }

      attempt_params =
        if outcome in [:bounced, :failed],
          do: Map.put(attempt_params, :error_class, to_string(outcome)),
          else: attempt_params

      attempt_params =
        if args["provider_message_id"],
          do: Map.put(attempt_params, :provider_message_id, args["provider_message_id"]),
          else: attempt_params

      with {:ok, _} <- Deliveries.record_attempt(delivery, attempt_params),
           {:ok, _} <- emit_signal(delivery, outcome) do
        :ok
      end
    end
  end
end
