if Code.ensure_loaded?(Oban) do
  defmodule Chimeway.Dispatch.Oban do
    @moduledoc """
    Oban-backed dispatcher — satisfies `Chimeway.Dispatch` behaviour.

    Configure via:

        config :chimeway, :dispatcher, Chimeway.Dispatch.Oban

    Each notification produces one `Chimeway.Dispatch.ObanWorker` job per
    delivery row. The queue is `:chimeway_delivery`.

    ## Transactional enqueue

    Pass `multi: %Ecto.Multi{}` to `dispatch/2` to insert job rows inside the
    same database transaction as the delivery rows:

        dispatcher.dispatch(notifications, multi: existing_multi)

    When `:multi` is absent, jobs are inserted via direct `Oban.insert/2`.

    ## Runtime validation

    If `:dispatcher` is configured as `Chimeway.Dispatch.Oban` but Oban is not
    loaded, the dispatch call will fail at runtime with a clear error. Add Oban
    as a non-optional dependency in your host application to avoid this.
    """

    @behaviour Chimeway.Dispatch

    import Ecto.Query, only: [from: 2]

    alias Chimeway.{
      DeliveryPlanning,
      DeliveryTargets,
      Digests.DigestBucket,
      Dispatch.DeferredResumeWorker,
      Dispatch.DigestFlushWorker,
      Dispatch.ObanWorker,
      Repo
    }

    alias Chimeway.Telemetry
    alias Ecto.Multi
    alias Oban.Job

    @impl Chimeway.Dispatch
    def dispatch(notifications, opts) when is_list(notifications) do
      base_multi =
        case Keyword.get(opts, :multi, Multi.new()) do
          %Multi{} = multi -> multi
          _ -> Multi.new()
        end

      multi =
        base_multi
        |> Multi.run(:plan_notifications, &do_plan(notifications, opts, &1, &2))
        |> Multi.run(:enqueue_jobs, &do_enqueue(&1, &2))

      handle_transaction_result(Repo.transaction(multi))
    end

    @impl Chimeway.Dispatch
    def dispatch_delivery(%{id: _id} = delivery, _opts) do
      enqueue_delivery(delivery)
      |> normalize_dispatch_delivery_result(delivery)
    end

    def dispatch_delivery(delivery_id, _opts) when is_binary(delivery_id) do
      delivery = Chimeway.Deliveries.get_delivery!(delivery_id)
      dispatch_delivery(delivery, [])
    end

    def enqueue_digest_flush(%DigestBucket{window_ends_at: %DateTime{} = scheduled_at} = bucket) do
      bucket.id
      |> do_enqueue_digest_flush(scheduled_at)
      |> collapse_duplicate_digest_flush_jobs(bucket.id, scheduled_at)
    end

    defp do_plan(notifications, opts, _repo, _changes) do
      DeliveryPlanning.plan_notifications(notifications, opts)
    end

    defp do_enqueue(_repo, %{plan_notifications: deliveries}) do
      deliveries
      |> Enum.reduce_while({:ok, []}, fn delivery, {:ok, jobs} ->
        case enqueue_delivery(delivery) do
          {:skip, _delivery} -> {:cont, {:ok, jobs}}
          {:ok, new_jobs} -> {:cont, {:ok, Enum.reverse(List.wrap(new_jobs)) ++ jobs}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
      |> case do
        {:ok, jobs} -> {:ok, Enum.reverse(jobs)}
        {:error, reason} -> {:error, reason}
      end
    end

    defp handle_transaction_result({:ok, %{plan_notifications: deliveries}}),
      do: {:ok, deliveries}

    defp handle_transaction_result({:error, :plan_notifications, reason, _changes}) do
      {:error, {:planning_failed, reason}}
    end

    defp handle_transaction_result({:error, _step, reason, _changes}), do: {:error, reason}

    defp enqueue_delivery(
           %{channel: "push", status: :pending, orchestration_state: :ready} = delivery
         ) do
      case DeliveryTargets.actionable_targets(delivery) do
        [] ->
          with {:ok, %{status: :suppressed, suppression_reason: "no_eligible_targets"} = updated} <-
                 DeliveryTargets.recompute_delivery(delivery, delivery.tenant_id) do
            {:ok, {:authoritative_delivery, updated}}
          end

        targets ->
          Enum.reduce_while(targets, {:ok, []}, fn target, {:ok, jobs} ->
            case enqueue_job(
                   delivery,
                   ObanWorker.new(%{delivery_target_id: target.id, tenant_id: delivery.tenant_id})
                 ) do
              {:ok, job} -> {:cont, {:ok, [job | jobs]}}
              {:error, reason} -> {:halt, {:error, reason}}
            end
          end)
      end
    end

    defp enqueue_delivery(%{status: :pending, orchestration_state: :ready} = delivery) do
      case enqueue_job(delivery, ObanWorker.new(%{delivery_id: delivery.id})) do
        {:ok, job} -> {:ok, [job]}
        {:error, reason} -> {:error, reason}
      end
    end

    defp enqueue_delivery(
           %{
             status: :pending,
             orchestration_state: :deferred,
             next_eligible_at: %DateTime{}
           } = delivery
         ) do
      job =
        DeferredResumeWorker.new(
          %{delivery_id: delivery.id, tenant_id: delivery.tenant_id},
          scheduled_at: delivery.next_eligible_at
        )

      enqueue_job(delivery, job)
    end

    defp enqueue_delivery(delivery), do: {:skip, delivery}

    defp normalize_dispatch_delivery_result(
           {:ok, {:authoritative_delivery, delivery}},
           _original
         ),
         do: {:ok, delivery}

    defp normalize_dispatch_delivery_result({:ok, _jobs}, delivery), do: {:ok, delivery}
    defp normalize_dispatch_delivery_result({:skip, delivery}, _original), do: {:skip, delivery}
    defp normalize_dispatch_delivery_result({:error, reason}, _delivery), do: {:error, reason}

    defp enqueue_job(delivery, job) do
      Telemetry.span(
        [:dispatch, :enqueue],
        Telemetry.safe_meta(%{
          delivery_id: delivery.id,
          channel: delivery.channel,
          notification_key: Map.get(delivery.metadata || %{}, "notification_key")
        }),
        fn ->
          result = Oban.insert(job)
          {result, %{}}
        end
      )
    end

    defp build_digest_flush_job(bucket_id, scheduled_at) do
      DigestFlushWorker.new(%{bucket_id: bucket_id}, scheduled_at: scheduled_at)
    end

    defp do_enqueue_digest_flush(bucket_id, scheduled_at) do
      case existing_digest_flush_job(bucket_id, scheduled_at) do
        %Job{} = job ->
          {:ok, job}

        nil ->
          bucket_id
          |> build_digest_flush_job(scheduled_at)
          |> Oban.insert()
      end
    end

    defp existing_digest_flush_job(bucket_id, scheduled_at) do
      matching_digest_flush_jobs(bucket_id, scheduled_at)
      |> List.first()
    end

    defp collapse_duplicate_digest_flush_jobs({:ok, %Job{} = job}, bucket_id, scheduled_at) do
      case matching_digest_flush_jobs(bucket_id, scheduled_at) do
        [%Job{} = keep | duplicates] ->
          duplicate_ids = Enum.map(duplicates, & &1.id)

          if duplicate_ids != [] do
            from(enqueued in Job, where: enqueued.id in ^duplicate_ids)
            |> Repo.delete_all(oban_job_repo_opts())
          end

          {:ok, keep}

        [] ->
          {:ok, job}
      end
    end

    defp collapse_duplicate_digest_flush_jobs(other, _bucket_id, _scheduled_at), do: other

    defp matching_digest_flush_jobs(bucket_id, scheduled_at) do
      from(job in Job,
        where:
          job.worker == ^to_string(DigestFlushWorker) and
            fragment("?->>'bucket_id' = ?", job.args, ^bucket_id) and
            job.scheduled_at == ^scheduled_at and
            job.state in ["available", "scheduled", "executing", "retryable"],
        order_by: [asc: job.inserted_at, asc: job.id]
      )
      |> Repo.all(oban_job_repo_opts())
    end

    defp oban_job_repo_opts do
      Oban
      |> Oban.config()
      |> Oban.Repo.default_options()
    end
  end
end
