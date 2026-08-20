defmodule Chimeway.TargetRecovery do
  @moduledoc """
  Bounded, tenant-qualified recovery for interrupted planning and push targets.

  Recovery only exposes durable IDs and closed reason tokens. Target execution is
  still authorized by `DeliveryTargets.begin_target_attempt/2`; discovery is never
  provider-call authority.
  """

  import Ecto.Query

  alias Chimeway.{Deliveries, Delivery, DeliveryTarget, DeliveryTargets, Repo, SafeEvidence}
  alias Chimeway.Dispatch.Executor
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification

  @default_batch_size 50
  @max_batch_size 100

  @spec recover_tenant(term(), keyword()) :: map()
  def recover_tenant(tenant_id, opts \\ []) when is_list(opts) do
    with {:ok, tenant_id} <- tenant_id(tenant_id) do
      events = discover_stranded_events(tenant_id, opts)
      {event_ids, planning_count} = recover_events(tenant_id, events.event_ids)
      stale = discover_stale_attempts(tenant_id, opts)
      {stale_count, stale_reasons} = close_stale_attempts(tenant_id, stale.target_ids)
      targets = discover_target_work(tenant_id, opts)
      target_results = execute_targets(tenant_id, targets.target_ids)

      SafeEvidence.recovery_summary(%{
        event_ids: event_ids,
        target_ids: targets.target_ids,
        continuations: %{
          event: events.cursor,
          target: targets.cursor,
          stale_attempt: stale.cursor
        },
        reason: recovery_reason(planning_count, target_results, stale_count),
        reasons: stale_reasons ++ target_results.reasons,
        counts: %{
          resumed_planning: planning_count,
          resumed_target: target_results.resumed,
          left_ambiguous: stale_count,
          retryable_pre_handoff: target_results.retryable_pre_handoff,
          skipped_claimed: target_results.skipped_claimed,
          skipped_invalidated: target_results.skipped_invalidated
        }
      })
    else
      _ -> empty_result(:skipped_terminal)
    end
  end

  @spec discover_stranded_events(term(), keyword()) :: map()
  def discover_stranded_events(tenant_id, opts \\ []) when is_list(opts) do
    with {:ok, tenant_id} <- tenant_id(tenant_id) do
      %{limit: limit, cursor: cursor, cutoff: cutoff} = paging(opts, :event_cursor)

      event_query =
        from(e in Event,
          left_join: n in Notification,
          on: n.event_id == e.id and n.tenant_id == ^tenant_id,
          left_join: d in Delivery,
          on: d.notification_id == n.id and d.tenant_id == ^tenant_id,
          where:
            e.tenant_id == ^tenant_id and e.updated_at <= ^cutoff and
              (is_nil(n.id) or is_nil(d.id)),
          distinct: e.id,
          order_by: [asc: e.id],
          limit: ^limit,
          select: e.id
        )

      ids = Repo.all(maybe_after_cursor(event_query, :event, cursor))

      discovery_result(:resumed_planning, :event_ids, ids)
    else
      _ -> empty_discovery(:event_ids, :skipped_invalidated)
    end
  end

  @spec discover_target_work(term(), keyword()) :: map()
  def discover_target_work(tenant_id, opts \\ []) when is_list(opts) do
    with {:ok, tenant_id} <- tenant_id(tenant_id) do
      %{limit: limit, cursor: cursor} = paging(opts, :target_cursor)

      target_query =
        from(t in DeliveryTarget,
          join: d in Delivery,
          on: d.id == t.delivery_id and d.tenant_id == ^tenant_id,
          where:
            t.tenant_id == ^tenant_id and t.status == :pending and d.channel == "push" and
              d.status == :pending and d.orchestration_state == :ready,
          order_by: [asc: t.id],
          limit: ^limit,
          select: t.id
        )

      ids = Repo.all(maybe_after_cursor(target_query, :target, cursor))

      discovery_result(:resumed_target, :target_ids, ids)
    else
      _ -> empty_discovery(:target_ids, :skipped_invalidated)
    end
  end

  defp recover_events(tenant_id, opts) do
    opts
    |> Enum.reduce({[], 0}, fn event_id, {ids, count} ->
      case Deliveries.recover_event(event_id,
             tenant_id: tenant_id,
             source: "target_recovery",
             reason: "resumed_planning"
           ) do
        {:ok, _result} -> {[event_id | ids], count + 1}
        _ -> {[event_id | ids], count}
      end
    end)
    |> then(fn {ids, count} -> {Enum.reverse(ids), count} end)
  end

  defp discover_stale_attempts(tenant_id, opts) do
    %{limit: limit, cursor: cursor, now: now} = paging(opts, :stale_attempt_cursor)

    stale_query =
      from(t in DeliveryTarget,
        join: d in Delivery,
        on: d.id == t.delivery_id and d.tenant_id == ^tenant_id,
        join: a in assoc(t, :attempts),
        where:
          t.tenant_id == ^tenant_id and a.tenant_id == ^tenant_id and t.status == :claimed and
            t.lease_expires_at < ^now and a.outcome == :attempt_started,
        order_by: [asc: t.id],
        limit: ^limit,
        select: t.id,
        distinct: true
      )

    ids = Repo.all(maybe_after_cursor(stale_query, :stale_attempt, cursor))
    discovery_result(:left_ambiguous, :target_ids, ids)
  end

  defp close_stale_attempts(tenant_id, stale_ids) do
    Enum.reduce(stale_ids, {0, []}, fn target_id, {count, reasons} ->
      case DeliveryTargets.close_stale_started_attempt(target_id, tenant_id) do
        {:ok, _} -> {count + 1, [:left_ambiguous | reasons]}
        _ -> {count, reasons}
      end
    end)
  end

  defp execute_targets(tenant_id, target_ids) do
    Enum.reduce(
      target_ids,
      %{
        resumed: 0,
        retryable_pre_handoff: 0,
        skipped_claimed: 0,
        skipped_invalidated: 0,
        reasons: []
      },
      fn target_id, acc ->
        case DeliveryTargets.fetch_target_delivery(target_id, tenant_id) do
          {:ok, delivery} ->
            case Executor.run_target(delivery, target_id: target_id, source: "recovery") do
              {:ok, _} ->
                %{acc | resumed: acc.resumed + 1, reasons: [:resumed_target | acc.reasons]}

              {:noop, _} ->
                %{
                  acc
                  | skipped_claimed: acc.skipped_claimed + 1,
                    reasons: [:skipped_claimed | acc.reasons]
                }

              {:error, :pre_handoff_retryable} ->
                %{
                  acc
                  | retryable_pre_handoff: acc.retryable_pre_handoff + 1,
                    reasons: [:retryable_pre_handoff | acc.reasons]
                }

              {:error, :ambiguous_handoff} ->
                %{acc | reasons: [:left_ambiguous | acc.reasons]}

              {:error, _} ->
                %{
                  acc
                  | skipped_invalidated: acc.skipped_invalidated + 1,
                    reasons: [:skipped_invalidated | acc.reasons]
                }
            end

          {:noop, _} ->
            %{
              acc
              | skipped_invalidated: acc.skipped_invalidated + 1,
                reasons: [:skipped_invalidated | acc.reasons]
            }
        end
      end
    )
  end

  defp paging(opts, cursor_key) do
    batch_size = Keyword.get(opts, :batch_size, @default_batch_size)

    limit =
      if is_integer(batch_size) and batch_size in 1..@max_batch_size,
        do: batch_size,
        else: @default_batch_size

    older_than = Keyword.get(opts, :older_than, 60)
    now = Keyword.get(opts, :now, DateTime.utc_now())

    %{
      limit: limit,
      cursor: opaque_cursor(Keyword.get(opts, cursor_key)),
      cutoff: DateTime.add(now, -max(older_than, 0), :second),
      now: now
    }
  end

  defp tenant_id(value) when is_binary(value) do
    case String.trim(value) do
      "" -> {:error, :tenant_scope_required}
      tenant_id -> {:ok, tenant_id}
    end
  end

  defp tenant_id(_), do: {:error, :tenant_scope_required}
  defp opaque_cursor(value) when is_binary(value) and byte_size(value) > 0, do: value
  defp opaque_cursor(_), do: nil

  defp maybe_after_cursor(query, _kind, nil), do: query
  defp maybe_after_cursor(query, :event, cursor), do: from(e in query, where: e.id > ^cursor)
  defp maybe_after_cursor(query, :target, cursor), do: from(t in query, where: t.id > ^cursor)

  defp maybe_after_cursor(query, :stale_attempt, cursor),
    do: from(t in query, where: t.id > ^cursor)

  defp discovery_result(reason, key, ids) do
    %{
      key => ids,
      cursor: List.last(ids),
      reason: if(ids == [], do: :skipped_terminal, else: reason)
    }
  end

  defp empty_discovery(key, reason), do: %{key => [], cursor: nil, reason: reason}

  defp empty_result(reason),
    do:
      SafeEvidence.recovery_summary(%{
        event_ids: [],
        target_ids: [],
        continuations: %{event: nil, target: nil, stale_attempt: nil},
        reason: reason,
        reasons: [],
        counts: %{}
      })

  defp recovery_reason(planning, targets, stale) do
    cond do
      stale > 0 -> :left_ambiguous
      planning > 0 -> :resumed_planning
      targets.resumed > 0 -> :resumed_target
      targets.retryable_pre_handoff > 0 -> :retryable_pre_handoff
      true -> :skipped_terminal
    end
  end
end
