defmodule Chimeway.Traces do
  @moduledoc """
  Public query context for operator trace surfaces.

  Provides four query shapes over the durable lifecycle chain
  (event → notification → delivery → attempt):

  ## Functions

  - `get_trace/1` — load full trace for a single event by event_id
  - `find_traces_for_recipient/2` — load recent traces for a recipient
  - `find_traces_by_correlation_id/1` — load events by correlation_id string
  - `explain_delivery/1` — structured explanation for a single delivery
  - `aggregate_outcomes/1` — grouped lifecycle counts by notification key, channel, and outcome

  ## Usage in IEx

      # Full trace for one event
      {:ok, event} = Chimeway.Traces.get_trace("event-uuid-here")
      event.notifications |> Enum.flat_map(& &1.deliveries)

      # Why was this delivery suppressed?
      {:ok, explanation} = Chimeway.Traces.explain_delivery("delivery-uuid-here")
      explanation.suppression_reason  #=> "channel_disabled"
      explanation.timeline            #=> [%{at: ~U[...], event: :event_created, detail: %{}}, ...]

      # All traces for a recipient
      traces = Chimeway.Traces.find_traces_for_recipient("user:123", notification_key: "order_shipped")
  """

  import Ecto.Query

  alias Chimeway.{Delivery, Events.Event, Notifications.Notification, Repo}
  alias Chimeway.Digests.DigestMembership
  alias Chimeway.Traces.Explanation
  alias Chimeway.Workflows.{WorkflowRun, WorkflowStep, WorkflowTransition}

  @doc """
  Returns the full event trace for the given event_id with all associations preloaded.

  Preloads: `[notifications: [deliveries: :attempts]]`

  Returns `{:ok, event}` or `{:error, :not_found}`.
  """
  @spec get_trace(String.t(), keyword()) :: {:ok, Event.t()} | {:error, :not_found}
  def get_trace(event_id, opts \\ []) do
    case Repo.get(Event, event_id, opts) do
      nil ->
        {:error, :not_found}

      event ->
        loaded = Repo.preload(event, [notifications: [deliveries: :attempts]], opts)
        {:ok, loaded}
    end
  end

  @doc """
  Returns recent notification traces for the given recipient.

  Options:
  - `notification_key:` (string) — filter to a specific notification type
  - `limit:` (integer, default 50) — maximum number of notifications returned

  Uses explicit joins to avoid N+1 queries.
  """
  @spec find_traces_for_recipient(String.t(), keyword()) :: [Notification.t()]
  def find_traces_for_recipient(recipient_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    notification_key = Keyword.get(opts, :notification_key)
    repo_opts = Keyword.drop(opts, [:limit, :notification_key])

    query =
      from(n in Notification,
        join: e in Event,
        on: e.id == n.event_id,
        where: n.recipient_identity == ^recipient_id,
        order_by: [desc: n.inserted_at],
        limit: ^limit,
        preload: [deliveries: :attempts, event: []]
      )

    query =
      if notification_key do
        from([n, e] in query, where: e.notification_key == ^notification_key)
      else
        query
      end

    Repo.all(query, repo_opts)
  end

  @doc """
  Returns all events with the given correlation_id, each with associations preloaded.

  Options:
  - `limit:` (integer, optional) — maximum number of events returned

  Returns `[]` when no events match — never returns an error tuple since
  correlation IDs are user-supplied and may not be unique or present.
  """
  @spec find_traces_by_correlation_id(String.t(), keyword()) :: [Event.t()]
  def find_traces_by_correlation_id(correlation_id, opts \\ []) do
    limit = Keyword.get(opts, :limit)
    repo_opts = Keyword.drop(opts, [:limit])

    query =
      from(e in Event,
        where: e.correlation_id == ^correlation_id,
        order_by: [desc: e.inserted_at]
      )

    query =
      if limit do
        from(e in query, limit: ^limit)
      else
        query
      end

    events = Repo.all(query, repo_opts)

    Repo.preload(events, [notifications: [deliveries: :attempts]], repo_opts)
  end

  @doc """
  Returns a structured explanation for the given delivery_id.

  The explanation includes the full timeline derived from row timestamps,
  the final status, suppression reason, and last attempt outcome.

  Returns `{:ok, %Chimeway.Traces.Explanation{}}` or `{:error, :not_found}`.
  """
  @spec explain_delivery(String.t(), keyword()) :: {:ok, Explanation.t()} | {:error, :not_found}
  def explain_delivery(delivery_id, opts \\ []) do
    delivery =
      Repo.one(
        from(d in Delivery,
          where: d.id == ^delivery_id,
          preload: [notification: :event, attempts: []]
        ),
        opts
      )

    case delivery do
      nil ->
        {:error, :not_found}

      %Delivery{notification: notification, attempts: attempts} ->
        event = notification.event
        last_attempt = last_attempt_summary(attempts)
        resume_fields = explanation_resume_fields(delivery)
        digest_context = digest_context(delivery)
        timeline = build_timeline(event, notification, delivery, attempts, digest_context)

        explanation = %Explanation{
          delivery_id: delivery.id,
          event_id: event.id,
          correlation_id: event.correlation_id,
          notification_key: event.notification_key,
          recipient_id: notification.recipient_identity,
          channel: delivery.channel,
          render_key: delivery.render_key,
          render_version: delivery.render_version,
          status: delivery.status,
          planning_reason: delivery.planning_reason,
          planning_context: explanation_planning_context(delivery),
          next_eligible_at: delivery.next_eligible_at,
          resume_source: resume_fields.resume_source,
          resume_scheduled_at: resume_fields.resume_scheduled_at,
          resumed_at: resume_fields.resumed_at,
          suppression_reason: delivery.suppression_reason,
          digest: digest_context,
          last_attempt: last_attempt,
          timeline: timeline
        }

        {:ok, explanation}
    end
  end

  @doc """
  Returns grouped lifecycle outcome counts from durable delivery state only.

  Supported filters:
  - `:notification_key` — restricts results to one stable notification key
  - `:channel` — restricts results to one delivery channel
  - `:outcomes` — list of explicit lifecycle buckets to keep
  - `:inserted_after` / `:inserted_before` — filter by delivery insert timestamps
  - `:updated_after` / `:updated_before` — filter by delivery update timestamps

  Result rows contain safe identifiers and counts only:

      %{notification_key: "comment.created", channel: "email", outcome: "sent", count: 42}
  """
  @spec aggregate_outcomes(keyword()) :: [map()]
  def aggregate_outcomes(opts \\ []) do
    repo_opts =
      Keyword.drop(opts, [
        :notification_key,
        :channel,
        :outcomes,
        :inserted_after,
        :inserted_before,
        :updated_after,
        :updated_before
      ])

    base_query =
      from(d in Delivery,
        join: n in Notification,
        on: n.id == d.notification_id,
        join: e in Event,
        on: e.id == n.event_id,
        select: %{
          notification_key: e.notification_key,
          channel: d.channel,
          outcome:
            fragment(
              """
              CASE
                WHEN ? = 'succeeded' THEN 'sent'
                WHEN ? = 'suppressed' THEN 'suppressed'
                WHEN ? = 'pending' AND ? = 'deferred' THEN 'delayed'
                WHEN ? = 'digested' THEN 'digested'
                WHEN ? = 'failed' THEN 'failed'
                WHEN ? = 'cancelled' AND ? = 'retries_exhausted' THEN 'exhausted'
                ELSE NULL
              END
              """,
              d.status,
              d.status,
              d.status,
              d.orchestration_state,
              d.status,
              d.status,
              d.status,
              d.suppression_reason
            )
        }
      )
      |> maybe_filter_notification_key(Keyword.get(opts, :notification_key))
      |> maybe_filter_channel(Keyword.get(opts, :channel))
      |> maybe_filter_delivery_inserted_after(Keyword.get(opts, :inserted_after))
      |> maybe_filter_delivery_inserted_before(Keyword.get(opts, :inserted_before))
      |> maybe_filter_delivery_updated_after(Keyword.get(opts, :updated_after))
      |> maybe_filter_delivery_updated_before(Keyword.get(opts, :updated_before))

    aggregate_query =
      from(row in subquery(base_query),
        where: not is_nil(row.outcome),
        group_by: [row.notification_key, row.channel, row.outcome],
        order_by: [asc: row.notification_key, asc: row.channel, asc: row.outcome],
        select: %{
          notification_key: row.notification_key,
          channel: row.channel,
          outcome: row.outcome,
          count: count(row.outcome)
        }
      )
      |> maybe_filter_aggregate_outcomes(Keyword.get(opts, :outcomes))

    Repo.all(aggregate_query, repo_opts)
  end

  @doc """
  Convenience wrapper for grouped lifecycle outcome counts for one notification key.
  """
  @spec aggregate_outcomes_for_notification(String.t(), keyword()) :: [map()]
  def aggregate_outcomes_for_notification(notification_key, opts \\ [])
      when is_binary(notification_key) and is_list(opts) do
    aggregate_outcomes(Keyword.put(opts, :notification_key, notification_key))
  end

  # --- Private helpers ---

  defp last_attempt_summary([]), do: nil

  defp last_attempt_summary(attempts) do
    # nil > integer is true in Elixir's term ordering (atoms > numbers),
    # so Enum.max_by on attempt_number would erroneously pick a nil row
    # over attempt_number=5. Partition numbered rows first.
    case Enum.filter(attempts, &is_integer(&1.attempt_number)) do
      [] ->
        # All rows are pre-migration with nil attempt_number; fall back to
        # inserted_at ordering (best available approximation).
        last = Enum.max_by(attempts, & &1.inserted_at, DateTime)
        build_last_attempt_map(last)

      numbered ->
        last = Enum.max_by(numbered, & &1.attempt_number)
        build_last_attempt_map(last)
    end
  end

  defp build_last_attempt_map(attempt) do
    %{
      outcome: attempt.outcome,
      inserted_at: attempt.inserted_at,
      attempt_number: attempt.attempt_number,
      error_class: attempt.error_class,
      adapter_module: attempt.adapter_module
      # Phase 29 D-22 — nil for pre-Phase-29 rows
    }
  end

  defp build_timeline(event, notification, delivery, attempts, digest_context) do
    planning_context = explanation_planning_context(delivery)
    resume_fields = explanation_resume_fields(delivery)
    recovery_fields = explanation_recovery_fields(delivery)

    base = [
      %{
        at: event.inserted_at,
        event: :event_created,
        detail: %{notification_key: event.notification_key}
      },
      %{
        at: notification.inserted_at,
        event: :notification_created,
        detail: %{recipient_id: notification.recipient_identity}
      },
      %{at: delivery.inserted_at, event: :delivery_planned, detail: %{channel: delivery.channel}}
    ]

    deferred_entries =
      if deferred_timeline?(delivery) do
        [
          %{
            at: deferred_at(delivery),
            event: :deferred,
            detail: %{
              reason: delivery.planning_reason,
              time_zone: planning_context && planning_context["time_zone"],
              rule_identity: planning_context && planning_context["rule_identity"],
              next_eligible_at: delivery.next_eligible_at,
              planning_context: planning_context
            }
          }
        ]
      else
        []
      end

    resumed_entries =
      if resume_fields.resumed_at do
        [
          %{
            at: resume_fields.resumed_at,
            event: :resumed,
            detail: %{
              resume_source: resume_fields.resume_source,
              resume_scheduled_at: resume_fields.resume_scheduled_at
            }
          }
        ]
      else
        []
      end

    recovery_entries =
      if recovery_fields.recovered_at do
        [
          %{
            at: recovery_fields.recovered_at,
            event: :recovered,
            detail: %{
              recovery_source: recovery_fields.recovery_source,
              recovery_reason: recovery_fields.recovery_reason,
              recovered_at: recovery_fields.recovered_at
            }
          }
        ]
      else
        []
      end

    suppression_entries =
      if delivery.status == :suppressed and delivery.suppression_reason do
        [
          %{
            at: delivery.updated_at,
            event: :suppressed,
            detail: %{
              reason: delivery.suppression_reason,
              policy_checkpoint:
                Map.get(delivery.metadata || %{}, "policy_checkpoint", "unknown"),
              delayed_fallback_source:
                Map.get(delivery.metadata || %{}, "delayed_fallback_source", "unknown")
            }
          }
        ]
      else
        []
      end

    cancellation_entries =
      if delivery.status == :cancelled do
        reason = delivery.suppression_reason || "manual"

        [
          %{
            at: delivery.updated_at,
            event: :cancelled,
            detail: %{
              reason: reason,
              policy_checkpoint: Map.get(delivery.metadata || %{}, "policy_checkpoint", "unknown")
            }
          }
        ]
      else
        []
      end

    attempt_entries =
      Enum.map(attempts, fn attempt ->
        %{
          at: attempt.inserted_at,
          event: :attempt_recorded,
          detail: %{
            outcome: attempt.outcome,
            attempt_number: attempt.attempt_number,
            error_class: attempt.error_class,
            adapter_module: attempt.adapter_module
            # Phase 29 D-22 — nil for pre-Phase-29 rows
          }
        }
      end)

    digest_entries = digest_timeline_entries(delivery, digest_context)

    signal_event_name = lookup_signal_received_event_name(delivery)
    webhook_received_entries = webhook_received_entries(attempts, signal_event_name)
    workflow_transition_entries = workflow_transition_entries(delivery)

    (base ++
       deferred_entries ++
       resumed_entries ++
       recovery_entries ++
       suppression_entries ++
       cancellation_entries ++
       digest_entries ++
       attempt_entries ++
       webhook_received_entries ++
       workflow_transition_entries)
    |> Enum.sort_by(&timeline_sort_key/1)
  end

  defp explanation_resume_fields(%Delivery{} = delivery) do
    metadata = delivery.metadata || %{}

    %{
      resume_source: metadata_string(metadata, "resume_source"),
      resume_scheduled_at: metadata_datetime(metadata, "resume_scheduled_at"),
      resumed_at: metadata_datetime(metadata, "resumed_at")
    }
  end

  defp explanation_recovery_fields(%Delivery{} = delivery) do
    metadata = delivery.metadata || %{}

    %{
      recovery_source: metadata_string(metadata, "recovery_source"),
      recovery_reason: metadata_string(metadata, "recovery_reason"),
      recovered_at: metadata_datetime(metadata, "recovered_at")
    }
  end

  defp deferred_timeline?(%Delivery{
         planning_reason: planning_reason,
         next_eligible_at: next_eligible_at
       })
       when is_binary(planning_reason) and not is_nil(next_eligible_at),
       do: true

  defp deferred_timeline?(_delivery), do: false

  defp deferred_at(%Delivery{} = delivery) do
    metadata_datetime(delivery.metadata || %{}, "resume_cancelled_at") || delivery.updated_at
  end

  defp metadata_string(metadata, key) when is_map(metadata) do
    case Map.get(metadata, key) do
      value when is_binary(value) and byte_size(value) > 0 -> value
      _ -> nil
    end
  end

  defp metadata_datetime(metadata, key) when is_map(metadata) do
    case Map.get(metadata, key) do
      value when is_binary(value) ->
        parse_metadata_datetime(value)

      %DateTime{} = value ->
        value

      _ ->
        nil
    end
  end

  defp parse_metadata_datetime(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, 0} -> datetime
      _ -> nil
    end
  end

  defp timeline_sort_key(%{event: event, at: at}) do
    {timeline_rank(event), at}
  end

  defp timeline_rank(:event_created), do: 0
  defp timeline_rank(:notification_created), do: 1
  defp timeline_rank(:delivery_planned), do: 2
  defp timeline_rank(:deferred), do: 3
  defp timeline_rank(:resumed), do: 4
  defp timeline_rank(:recovered), do: 5
  defp timeline_rank(:suppressed), do: 6
  defp timeline_rank(:cancelled), do: 7
  defp timeline_rank(:digested), do: 8
  defp timeline_rank(:digest_skipped), do: 9
  defp timeline_rank(:emitted_immediately), do: 10
  defp timeline_rank(:digest_emitted), do: 11
  defp timeline_rank(:attempt_recorded), do: 12
  defp timeline_rank(:webhook_received), do: 13
  defp timeline_rank(:workflow_progressed), do: 14
  defp timeline_rank(:workflow_waiting), do: 15
  defp timeline_rank(:workflow_stopped), do: 16
  defp timeline_rank(:workflow_completed), do: 17
  defp timeline_rank(_event), do: 99

  # ---------------------------------------------------------------------
  # Phase 32 — webhook + workflow timeline projection (TRAC-01, TRAC-02)
  # ---------------------------------------------------------------------

  @spec webhook_received_entries([map()], String.t() | nil) :: [map()]
  defp webhook_received_entries(attempts, signal_event_name) do
    Enum.map(attempts, fn attempt ->
      %{
        at: attempt.inserted_at,
        event: :webhook_received,
        detail: %{
          outcome: attempt.outcome,
          provider_message_id: attempt.provider_message_id,
          adapter_module: attempt.adapter_module,
          signal_event_name: signal_event_name
        }
      }
    end)
  end

  @spec workflow_transition_entries(Delivery.t()) :: [map()]
  defp workflow_transition_entries(%Delivery{id: delivery_id, tenant_id: tenant_id}) do
    query =
      from(wt in WorkflowTransition,
        join: wr in WorkflowRun,
        on: wt.workflow_run_id == wr.id,
        left_join: ws in WorkflowStep,
        on: wt.workflow_step_id == ws.id,
        where: wt.delivery_id == ^delivery_id and wr.tenant_id == ^tenant_id,
        select: %{
          at: wt.inserted_at,
          reason: wt.reason,
          context: wt.context,
          workflow_run_id: wt.workflow_run_id,
          workflow_step_id: wt.workflow_step_id,
          workflow_step_key: ws.step_key
        }
      )

    query
    |> Repo.all()
    |> Enum.flat_map(&project_workflow_transition/1)
  end

  @spec project_workflow_transition(map()) :: [map()]
  defp project_workflow_transition(%{reason: reason} = row) do
    case project_workflow_reason(reason) do
      nil -> []
      atom -> [%{at: row.at, event: atom, detail: build_workflow_detail(atom, row)}]
    end
  end

  # Literal-string -> atom dispatch (D-07). The five new event atoms are
  # compile-time literals; runtime atom-table allocation from untrusted strings
  # is forbidden per atom-safety gate (T-32-T2 — D-16).
  # Suppresses the three internal cursor reasons (D-08) and any unknown
  # reason via the nil fallback.
  @spec project_workflow_reason(String.t()) :: atom() | nil
  defp project_workflow_reason("progressed_on_delivery_outcome"), do: :workflow_progressed
  defp project_workflow_reason("waiting_for_step_progression"), do: :workflow_waiting
  defp project_workflow_reason("workflow_stopped"), do: :workflow_stopped
  defp project_workflow_reason("workflow_completed"), do: :workflow_completed
  defp project_workflow_reason(_other), do: nil

  @spec build_workflow_detail(atom(), map()) :: map()
  defp build_workflow_detail(:workflow_waiting, row) do
    ctx = row.context || %{}

    %{
      workflow_run_id: row.workflow_run_id,
      workflow_step_id: row.workflow_step_id,
      workflow_step_key: row.workflow_step_key,
      due_at: Map.get(ctx, "due_at"),
      rule_kind: Map.get(ctx, "rule_kind", "wait_until")
    }
  end

  # The three progression-row atoms (:workflow_progressed,
  # :workflow_stopped, :workflow_completed) share the same seven-field
  # detail shape per D-12. `reason` is a verbatim copy of `transition.reason`
  # for operator readability (UI-SPEC §A example at line 273).
  defp build_workflow_detail(_atom, row) do
    ctx = row.context || %{}

    %{
      workflow_run_id: row.workflow_run_id,
      workflow_step_id: row.workflow_step_id,
      workflow_step_key: row.workflow_step_key,
      workflow_outcome: Map.get(ctx, "workflow_outcome"),
      from_step: Map.get(ctx, "from_step"),
      to_step: Map.get(ctx, "to_step"),
      reason: row.reason
    }
  end

  @spec lookup_signal_received_event_name(Delivery.t()) :: String.t() | nil
  defp lookup_signal_received_event_name(%Delivery{id: delivery_id, tenant_id: tenant_id}) do
    query =
      from(wt in WorkflowTransition,
        join: wr in WorkflowRun,
        on: wt.workflow_run_id == wr.id,
        where:
          wt.delivery_id == ^delivery_id and
            wr.tenant_id == ^tenant_id and
            wt.reason == "signal_received",
        order_by: [asc: wt.inserted_at],
        limit: 1,
        select: wt.context
      )

    case Repo.one(query) do
      nil -> nil
      ctx when is_map(ctx) -> Map.get(ctx, "event_name")
    end
  end

  defp maybe_filter_notification_key(query, nil), do: query

  defp maybe_filter_notification_key(query, notification_key) when is_binary(notification_key) do
    from([d, n, e] in query, where: e.notification_key == ^notification_key)
  end

  defp maybe_filter_channel(query, nil), do: query

  defp maybe_filter_channel(query, channel) when is_binary(channel) do
    from([d, n, e] in query, where: d.channel == ^channel)
  end

  defp maybe_filter_aggregate_outcomes(query, nil), do: query
  defp maybe_filter_aggregate_outcomes(query, []), do: query

  defp maybe_filter_aggregate_outcomes(query, outcomes) when is_list(outcomes) do
    from(row in query, where: row.outcome in ^outcomes)
  end

  defp maybe_filter_delivery_inserted_after(query, nil), do: query

  defp maybe_filter_delivery_inserted_after(query, %DateTime{} = inserted_after) do
    from([d, n, e] in query, where: d.inserted_at >= ^inserted_after)
  end

  defp maybe_filter_delivery_inserted_before(query, nil), do: query

  defp maybe_filter_delivery_inserted_before(query, %DateTime{} = inserted_before) do
    from([d, n, e] in query, where: d.inserted_at <= ^inserted_before)
  end

  defp maybe_filter_delivery_updated_after(query, nil), do: query

  defp maybe_filter_delivery_updated_after(query, %DateTime{} = updated_after) do
    from([d, n, e] in query, where: d.updated_at >= ^updated_after)
  end

  defp maybe_filter_delivery_updated_before(query, nil), do: query

  defp maybe_filter_delivery_updated_before(query, %DateTime{} = updated_before) do
    from([d, n, e] in query, where: d.updated_at <= ^updated_before)
  end

  defp explanation_planning_context(%Delivery{} = delivery) do
    delivery
    |> safe_planning_context()
    |> maybe_put_rule_identity(delivery)
  end

  defp safe_planning_context(%Delivery{planning_context: nil}), do: nil

  defp safe_planning_context(%Delivery{planning_context: planning_context})
       when is_map(planning_context) do
    planning_context
    |> Map.take([
      "rule",
      "rule_identity",
      "time_zone",
      "quiet_hours_start_minute",
      "quiet_hours_end_minute",
      "channel",
      "source"
    ])
    |> case do
      map when map_size(map) == 0 -> nil
      map -> map
    end
  end

  defp safe_planning_context(_delivery), do: nil

  defp maybe_put_rule_identity(nil, %Delivery{} = delivery) do
    case normalized_rule_identity(delivery) do
      nil -> nil
      rule_identity -> %{"rule_identity" => rule_identity}
    end
  end

  defp maybe_put_rule_identity(planning_context, %Delivery{} = delivery) do
    Map.put_new(planning_context, "rule_identity", normalized_rule_identity(delivery))
  end

  defp normalized_rule_identity(%Delivery{
         planning_context: planning_context,
         planning_reason: planning_reason
       }) do
    cond do
      is_map(planning_context) and is_binary(planning_context["rule_identity"]) ->
        planning_context["rule_identity"]

      is_map(planning_context) and is_binary(planning_context["rule"]) ->
        planning_context["rule"]

      is_binary(planning_reason) ->
        planning_reason

      true ->
        nil
    end
  end

  defp digest_context(%Delivery{} = delivery) do
    cond do
      source_digest_delivery?(delivery) ->
        source_digest_context(delivery)

      emitted_digest_delivery?(delivery) ->
        emitted_digest_context(delivery)

      delivery.planning_reason == "digest_rule" ->
        %{
          "outcome" => "deferred",
          "rule_identity" => normalized_rule_identity(delivery)
        }

      true ->
        nil
    end
  end

  defp source_digest_delivery?(%Delivery{digest_flush_outcome: outcome}) when not is_nil(outcome),
    do: true

  defp source_digest_delivery?(_delivery), do: false

  defp emitted_digest_delivery?(%Delivery{metadata: metadata}) when is_map(metadata) do
    is_map(Map.get(metadata, "digest"))
  end

  defp emitted_digest_delivery?(_delivery), do: false

  defp source_digest_context(%Delivery{} = delivery) do
    membership =
      Repo.one(
        from(m in DigestMembership,
          where: m.delivery_id == ^delivery.id,
          limit: 1
        )
      )

    base =
      %{
        "outcome" => delivery.digest_flush_outcome |> to_string(),
        "digest_delivery_id" => delivery.digest_delivery_id,
        "resolution_reason" => delivery.digest_flush_reason
      }
      |> maybe_put_digest_value("rule_identity", membership_rule_identity(membership, delivery))
      |> maybe_put_digest_value(
        "window_starts_at",
        membership && membership.resolved_window_starts_at
      )
      |> maybe_put_digest_value(
        "window_ends_at",
        membership && membership.resolved_window_ends_at
      )

    case delivery.digest_flush_outcome do
      :digested -> Map.put(base, "included", true)
      :skipped_by_policy -> Map.put(base, "excluded", true)
      :emitted_immediately -> Map.put(base, "emitted_immediately", true)
      _ -> base
    end
  end

  defp emitted_digest_context(%Delivery{} = delivery) do
    memberships =
      Repo.all(
        from(m in DigestMembership,
          where: m.digest_delivery_id == ^delivery.id,
          preload: [delivery: [notification: :event]]
        )
      )

    digest_metadata = Map.get(delivery.metadata || %{}, "digest", %{})

    %{
      "kind" => "emitted_digest",
      "rule_identity" =>
        digest_metadata["rule_key"] &&
          "#{digest_metadata["rule_key"]}:v#{digest_metadata["rule_version"]}",
      "included" => resolution_entries(memberships, :included),
      "excluded" => resolution_entries(memberships, :skipped_by_policy),
      "deferred" => [],
      "emitted_immediately" => resolution_entries(memberships, :emitted_immediately)
    }
  end

  defp resolution_entries(memberships, resolution) do
    memberships
    |> Enum.filter(&(&1.resolution == resolution))
    |> Enum.map(fn membership ->
      %{
        "delivery_id" => membership.delivery_id,
        "notification_id" => membership.notification_id,
        "notification_key" => membership.delivery.notification.event.notification_key,
        "reason" => membership.resolution_reason
      }
    end)
  end

  defp digest_timeline_entries(%Delivery{} = delivery, digest_context)
       when is_map(digest_context) do
    case delivery.digest_flush_outcome do
      :digested ->
        [
          %{
            at: delivery.digest_flush_resolved_at || delivery.updated_at,
            event: :digested,
            detail: %{
              digest_delivery_id: delivery.digest_delivery_id,
              resolution_reason: delivery.digest_flush_reason,
              rule_identity: digest_context["rule_identity"]
            }
          }
        ]

      :skipped_by_policy ->
        [
          %{
            at: delivery.digest_flush_resolved_at || delivery.updated_at,
            event: :digest_skipped,
            detail: %{
              digest_delivery_id: delivery.digest_delivery_id,
              resolution_reason: delivery.digest_flush_reason,
              rule_identity: digest_context["rule_identity"]
            }
          }
        ]

      :emitted_immediately ->
        [
          %{
            at: delivery.digest_flush_resolved_at || delivery.updated_at,
            event: :emitted_immediately,
            detail: %{
              digest_delivery_id: delivery.digest_delivery_id,
              resolution_reason: delivery.digest_flush_reason,
              rule_identity: digest_context["rule_identity"]
            }
          }
        ]

      _ ->
        if emitted_digest_delivery?(delivery) do
          [
            %{
              at: delivery.updated_at,
              event: :digest_emitted,
              detail: %{
                rule_identity: digest_context["rule_identity"],
                included: length(digest_context["included"] || []),
                excluded: length(digest_context["excluded"] || []),
                deferred: length(digest_context["deferred"] || [])
              }
            }
          ]
        else
          []
        end
    end
  end

  defp digest_timeline_entries(_delivery, _digest_context), do: []

  defp membership_rule_identity(nil, %Delivery{} = delivery),
    do: normalized_rule_identity(delivery)

  defp membership_rule_identity(membership, _delivery) do
    cond do
      is_binary(membership.resolved_rule_key) and is_integer(membership.resolved_rule_version) ->
        "#{membership.resolved_rule_key}:v#{membership.resolved_rule_version}"

      true ->
        nil
    end
  end

  defp maybe_put_digest_value(map, _key, nil), do: map
  defp maybe_put_digest_value(map, key, %DateTime{} = value), do: Map.put(map, key, value)
  defp maybe_put_digest_value(map, key, value), do: Map.put(map, key, value)
end
