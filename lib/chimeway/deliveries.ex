defmodule Chimeway.Deliveries do
  @moduledoc """
  Context module for delivery planning, attempt recording, and status transitions.

  Delivery rows are idempotent per (notification_id, channel). Attempt rows are
  append-only — each adapter call produces a new attempt row.
  """

  import Ecto.Changeset, only: [change: 2]
  import Ecto.Query, only: [from: 2]

  alias Chimeway.{Delivery, DeliveryAttempt, Repo, Workflows}
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification
  alias Chimeway.Telemetry
  # NOTE: `Chimeway.Workflows.Progression` is referenced by its fully qualified
  # name in `maybe_progress_workflow/1` to avoid a compile-time circular alias
  # ordering between this module and the progression engine.
  alias Ecto.Multi

  @terminal_states [:succeeded, :suppressed, :cancelled, :digested]

  @doc """
  Lists persisted events that are older than the supplied threshold, have at
  least one notification, and still have zero delivery rows planned.
  """
  @spec list_recoverable_events(keyword()) :: [Event.t()]
  def list_recoverable_events(opts \\ []) when is_list(opts) do
    now =
      opts
      |> Keyword.get(:now, DateTime.utc_now())
      |> normalize_datetime!()

    cutoff = recoverable_cutoff!(now, Keyword.get(opts, :older_than, 60))

    Repo.all(
      from(e in Event,
        join: n in Notification,
        on: n.event_id == e.id,
        left_join: d in Delivery,
        on: d.notification_id == n.id,
        where: e.updated_at <= ^cutoff,
        group_by: e.id,
        having: count(d.id) == 0,
        order_by: [asc: e.updated_at, asc: e.inserted_at]
      )
    )
  end

  @doc """
  Lists delivery rows that are still pending, ready, older than the supplied
  threshold, and not already claimed for recovery.
  """
  @spec list_recoverable_deliveries(keyword()) :: [Delivery.t()]
  def list_recoverable_deliveries(opts \\ []) when is_list(opts) do
    now =
      opts
      |> Keyword.get(:now, DateTime.utc_now())
      |> normalize_datetime!()

    cutoff = recoverable_cutoff!(now, Keyword.get(opts, :older_than, 60))

    Repo.all(
      from(d in Delivery,
        where:
          d.status == :pending and d.orchestration_state == :ready and d.updated_at <= ^cutoff and
            fragment("?->>? IS NULL", d.metadata, ^"recovered_at"),
        order_by: [asc: d.updated_at, asc: d.inserted_at]
      )
    )
  end

  @doc """
  Claims a recoverable delivery row by stamping durable recovery metadata on the
  canonical row. Returns `{:noop, delivery}` if the row is no longer eligible.
  """
  @spec begin_recovery(binary() | Delivery.t(), keyword()) ::
          {:ok, Delivery.t()} | {:noop, Delivery.t()}
  def begin_recovery(delivery_or_id, opts \\ [])

  def begin_recovery(%Delivery{id: delivery_id}, opts) when is_list(opts) do
    begin_recovery(delivery_id, opts)
  end

  def begin_recovery(delivery_id, opts) when is_binary(delivery_id) and is_list(opts) do
    now =
      opts
      |> Keyword.get(:now, DateTime.utc_now())
      |> normalize_datetime!()

    cutoff = recoverable_cutoff!(now, Keyword.get(opts, :older_than, 60))
    source = normalize_recovery_value!("recovery source", Keyword.get(opts, :source, "operator"))
    reason = normalize_recovery_value!("recovery reason", Keyword.get(opts, :reason, "stuck"))
    recovered_at = iso8601_utc_usec(now)

    recovery_query =
      from(d in Delivery,
        where:
          d.id == ^delivery_id and d.status == :pending and d.orchestration_state == :ready and
            d.updated_at <= ^cutoff and fragment("?->>? IS NULL", d.metadata, ^"recovered_at"),
        update: [
          set: [
            metadata:
              fragment(
                """
                jsonb_set(
                  jsonb_set(
                    jsonb_set(COALESCE(?, '{}'::jsonb), '{recovery_source}', to_jsonb(?::text), true),
                    '{recovery_reason}',
                    to_jsonb(?::text),
                    true
                  ),
                  '{recovered_at}',
                  to_jsonb(?::text),
                  true
                )
                """,
                d.metadata,
                ^source,
                ^reason,
                ^recovered_at
              ),
            updated_at: ^now
          ]
        ]
      )

    {updated_count, _rows} = Repo.update_all(recovery_query, [])

    updated_delivery = get_delivery!(delivery_id)

    if updated_count == 1 do
      {:ok, updated_delivery}
    else
      {:noop, updated_delivery}
    end
  end

  @doc """
  Returns the list of terminal delivery states — used by the dispatcher (Plan 02-02)
  to short-circuit dispatch for already-terminal deliveries.
  """
  def terminal_states, do: @terminal_states

  @doc """
  Re-drives a recoverable delivery row through the configured dispatcher while
  preserving canonical delivery identity and durable recovery metadata.
  """
  @spec recover_delivery(binary() | Delivery.t(), keyword()) ::
          {:ok, map()} | {:noop, map()} | {:error, term()}
  def recover_delivery(delivery_or_id, opts \\ [])

  def recover_delivery(%Delivery{id: delivery_id}, opts) when is_list(opts) do
    recover_delivery(delivery_id, opts)
  end

  def recover_delivery(delivery_id, opts) when is_binary(delivery_id) and is_list(opts) do
    now =
      opts
      |> Keyword.get(:now, DateTime.utc_now())
      |> normalize_datetime!()

    source = normalize_recovery_value!("recovery source", Keyword.get(opts, :source, "operator"))
    reason = normalize_recovery_value!("recovery reason", Keyword.get(opts, :reason, "stuck"))
    dispatcher = configured_dispatcher()
    older_than = Keyword.get(opts, :older_than, 60)

    case begin_recovery(delivery_id, Keyword.put(opts, :now, now)) do
      {:ok, _claimed_delivery} ->
        case dispatcher.dispatch_delivery(delivery_id, pre_planned: true, post_commit: true) do
          {:ok, dispatched_delivery} ->
            {:ok, recovery_delivery_result(dispatched_delivery, source, reason, now, :dispatched)}

          {:skip, skipped_delivery} ->
            {:noop, recovery_delivery_result(skipped_delivery, source, reason, now, :skipped)}

          {:error, reason_term} ->
            compensate_failed_recovery_claim(delivery_id, now, older_than)
            {:error, reason_term}
        end

      {:noop, existing_delivery} ->
        {:noop, recovery_delivery_result(existing_delivery, source, reason, now, :noop)}
    end
  end

  @doc """
  Re-drives a persisted event whose notifications exist but deliveries were never
  planned, using persisted render declarations instead of notifier callbacks.
  """
  @spec recover_event(binary() | Event.t(), keyword()) ::
          {:ok, map()} | {:noop, map()} | {:error, term()}
  def recover_event(event_or_id, opts \\ [])

  def recover_event(%Event{id: event_id}, opts) when is_list(opts) do
    recover_event(event_id, opts)
  end

  def recover_event(event_id, opts) when is_binary(event_id) and is_list(opts) do
    now =
      opts
      |> Keyword.get(:now, DateTime.utc_now())
      |> normalize_datetime!()

    source = normalize_recovery_value!("recovery source", Keyword.get(opts, :source, "operator"))
    reason = normalize_recovery_value!("recovery reason", Keyword.get(opts, :reason, "stuck"))
    event = Repo.get!(Event, event_id)
    dispatcher = configured_dispatcher()

    recoverable_event_ids =
      opts |> Keyword.put(:now, now) |> list_recoverable_events() |> Enum.map(& &1.id)

    if event_id in recoverable_event_ids do
      notifications =
        Repo.all(
          from(n in Notification,
            where: n.event_id == ^event_id,
            order_by: [asc: n.inserted_at, asc: n.id]
          )
        )

      dispatch_opts = [
        event_id: event.id,
        notification_key: event.notification_key,
        correlation_id: event.correlation_id,
        post_commit: true,
        use_persisted_channels: true,
        use_persisted_orchestration: true,
        use_persisted_workflow: Keyword.get(opts, :use_persisted_workflow, false)
      ]

      with :ok <- maybe_validate_persisted_workflows(notifications, dispatch_opts),
           {:ok, deliveries_or_results} <- dispatcher.dispatch(notifications, dispatch_opts) do
        deliveries =
          deliveries_or_results
          |> dispatched_deliveries()
          |> stamp_recovery_metadata(source, reason, now)

        {:ok,
         %{
           event: event,
           deliveries: deliveries,
           recovery: recovery_metadata(source, reason, now)
         }}
      end
    else
      {:noop,
       %{
         event: event,
         deliveries: [],
         recovery: recovery_metadata(source, reason, now)
       }}
    end
  end

  # General-path transitions. Note: `failed -> :cancelled` is INTENTIONALLY OMITTED here
  # even though :cancelled is a valid status — that transition is reserved for
  # Deliveries.exhaust_delivery/1 (D-10), which performs an out-of-band update
  # bypassing this table. The general transition_status/2 path must NOT permit
  # arbitrary callers to drive failed -> cancelled.
  @allowed_transitions %{
    pending: [:dispatched, :suppressed, :cancelled],
    dispatched: [:succeeded, :failed, :suppressed],
    failed: [:dispatched]
  }

  @doc """
  Plans a delivery row for the given notification_id and channel.
  Idempotent: duplicate calls on the same (notification_id, channel) create exactly one row.
  """
  @spec plan_delivery(binary(), atom() | binary()) ::
          {:ok, Delivery.t()} | {:error, Ecto.Changeset.t() | term()}
  @spec plan_delivery(binary(), atom() | binary(), keyword()) ::
          {:ok, Delivery.t()} | {:error, Ecto.Changeset.t() | term()}
  def plan_delivery(notification_id, channel, opts \\ [])

  def plan_delivery(notification_id, channel, opts) when is_list(opts) do
    channel_str = if is_atom(channel), do: Atom.to_string(channel), else: channel

    with {:ok, tenant_id} <- normalize_tenant_id(Keyword.get(opts, :tenant_id)),
         {:ok, actor_id} <- normalize_actor_id(Keyword.get(opts, :actor_id)),
         {:ok, delay_fallback} <-
           normalize_delay_fallback(Keyword.get(opts, :delay_fallback, false)),
         {:ok, delayed_fallback_source} <-
           normalize_delayed_fallback_source(
             Keyword.get(opts, :delayed_fallback_source, :default)
           ),
         {:ok, render_key} <- normalize_optional_render_key(Keyword.get(opts, :render_key)),
         {:ok, render_version} <-
           normalize_optional_render_version(Keyword.get(opts, :render_version)),
         {:ok, render_data} <-
           normalize_optional_render_data(Keyword.get(opts, :render_data, %{})),
         {:ok, workflow_run_id} <-
           normalize_optional_binary_id(Keyword.get(opts, :workflow_run_id)),
         {:ok, workflow_step_id} <-
           normalize_optional_binary_id(Keyword.get(opts, :workflow_step_id)) do
      metadata =
        opts
        |> Keyword.get(:metadata, %{})
        |> ensure_metadata_map()
        |> Map.put("delayed_fallback_source", delayed_fallback_source)
        |> maybe_put("notification_key", opts[:notification_key])
        |> maybe_put("event_id", opts[:event_id])
        |> maybe_put("correlation_id", opts[:correlation_id])

      result =
        %Delivery{}
        |> Delivery.changeset(%{
          notification_id: notification_id,
          tenant_id: tenant_id,
          actor_id: actor_id,
          channel: channel_str,
          status: :pending,
          delay_fallback: delay_fallback,
          metadata: metadata,
          render_key: render_key,
          render_version: render_version,
          render_data: render_data,
          workflow_run_id: workflow_run_id,
          workflow_step_id: workflow_step_id
        })
        |> Repo.insert(on_conflict: :nothing, conflict_target: [:notification_id, :channel])

      case result do
        {:ok, _} ->
          # Reload from DB: on_conflict: :nothing returns a phantom struct on conflict.
          # Always return the authoritative row with current status.
          {:ok, Repo.get_by!(Delivery, notification_id: notification_id, channel: channel_str)}

        error ->
          error
      end
    end
  end

  def plan_delivery(_notification_id, _channel, opts) do
    {:error, {:invalid_plan_delivery_opts, opts}}
  end

  defp normalize_tenant_id(value) when is_binary(value) and byte_size(value) > 0, do: {:ok, value}
  defp normalize_tenant_id(value), do: {:error, {:invalid_tenant_id, value}}

  defp normalize_actor_id(value) when is_binary(value) and byte_size(value) > 0, do: {:ok, value}
  defp normalize_actor_id(value), do: {:error, {:invalid_actor_id, value}}

  defp normalize_delay_fallback(value) when is_boolean(value), do: {:ok, value}
  defp normalize_delay_fallback(value), do: {:error, {:invalid_delay_fallback, value}}

  defp normalize_orchestration_state(state)
       when state in [:ready, :deferred, :digest_held],
       do: {:ok, state}

  defp normalize_orchestration_state(state), do: {:error, {:invalid_orchestration_state, state}}

  defp normalize_optional_string(nil), do: {:ok, nil}

  defp normalize_optional_string(value) when is_binary(value) and byte_size(value) > 0,
    do: {:ok, value}

  defp normalize_optional_string(value), do: {:error, {:invalid_planning_reason, value}}

  defp normalize_optional_map(nil), do: {:ok, nil}
  defp normalize_optional_map(value) when is_map(value), do: {:ok, value}
  defp normalize_optional_map(value), do: {:error, {:invalid_planning_context, value}}

  defp normalize_optional_render_key(nil), do: {:ok, nil}

  defp normalize_optional_render_key(value) when is_binary(value) and byte_size(value) > 0,
    do: {:ok, value}

  defp normalize_optional_render_key(value), do: {:error, {:invalid_render_key, value}}

  defp normalize_optional_render_version(nil), do: {:ok, nil}

  defp normalize_optional_render_version(value) when is_integer(value) and value > 0,
    do: {:ok, value}

  defp normalize_optional_render_version(value), do: {:error, {:invalid_render_version, value}}

  defp normalize_optional_render_data(nil), do: {:ok, %{}}
  defp normalize_optional_render_data(value) when is_map(value), do: {:ok, value}
  defp normalize_optional_render_data(value), do: {:error, {:invalid_render_data, value}}

  defp normalize_optional_datetime(nil), do: {:ok, nil}

  defp normalize_optional_datetime(%DateTime{} = value) do
    {:ok, %{value | microsecond: normalize_microsecond(value.microsecond)}}
  end

  defp normalize_optional_datetime(value), do: {:error, {:invalid_next_eligible_at, value}}

  defp normalize_optional_binary_id(nil), do: {:ok, nil}

  defp normalize_optional_binary_id(value) when is_binary(value), do: Ecto.UUID.cast(value)

  defp normalize_optional_binary_id(value), do: {:error, {:invalid_binary_id, value}}

  defp normalize_microsecond({microsecond, _precision}), do: {microsecond, 6}

  defp maybe_validate_persisted_workflows(notifications, opts) do
    if Keyword.get(opts, :use_persisted_workflow, false) do
      notifications
      |> Enum.reduce_while(:ok, fn notification, :ok ->
        case Workflows.persisted_workflow(notification) do
          {:ok, _workflow} -> {:cont, :ok}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
    else
      :ok
    end
  end

  defp normalize_delayed_fallback_source(:default), do: {:ok, "default"}
  defp normalize_delayed_fallback_source(:notifier), do: {:ok, "notifier"}
  defp normalize_delayed_fallback_source(:policy), do: {:ok, "policy"}
  defp normalize_delayed_fallback_source("default"), do: {:ok, "default"}
  defp normalize_delayed_fallback_source("notifier"), do: {:ok, "notifier"}
  defp normalize_delayed_fallback_source("policy"), do: {:ok, "policy"}

  defp normalize_delayed_fallback_source(value),
    do: {:error, {:invalid_delayed_fallback_source, value}}

  @doc """
  Fetches a delivery by ID, raising if not found.
  """
  @spec get_delivery!(binary()) :: Delivery.t()
  def get_delivery!(id), do: Repo.get!(Delivery, id)

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

  @doc """
  Fetches a delivery by a provider message ID from its attempts.
  """
  @spec get_delivery_by_provider_message_id(String.t()) ::
          {:ok, Delivery.t()} | {:error, :not_found}
  def get_delivery_by_provider_message_id(provider_message_id)
      when is_binary(provider_message_id) do
    case Repo.one(
           from(a in DeliveryAttempt,
             where: a.provider_message_id == ^provider_message_id,
             preload: [:delivery],
             limit: 1
           )
         ) do
      %DeliveryAttempt{delivery: %Delivery{} = delivery} -> {:ok, delivery}
      _ -> {:error, :not_found}
    end
  end

  @doc """
  Transitions a delivery to a new status, respecting the allowed transition table.
  Returns {:error, {:invalid_transition, from: current, to: new}} for disallowed transitions.
  """
  @spec transition_status(Delivery.t(), atom()) :: {:ok, Delivery.t()} | {:error, term()}
  def transition_status(delivery, new_status) do
    if delivery.status == new_status do
      {:ok, delivery}
    else
      allowed = Map.get(@allowed_transitions, delivery.status, [])

      if new_status in allowed do
        delivery
        |> change(status: new_status)
        |> Repo.update()
      else
        {:error, {:invalid_transition, from: delivery.status, to: new_status}}
      end
    end
  end

  @doc """
  Transitions a delivery to :suppressed and persists the suppression_reason.
  """
  @spec suppress_delivery(Delivery.t(), atom()) :: {:ok, Delivery.t()} | {:error, term()}
  def suppress_delivery(%Delivery{} = delivery, reason) when is_atom(reason) do
    suppress_delivery(delivery, reason, [])
  end

  @doc """
  Transitions a delivery to :suppressed, persists suppression_reason, and records
  policy checkpoint metadata (`planning` or `perform`).
  """
  @spec suppress_delivery(Delivery.t(), atom(), keyword()) ::
          {:ok, Delivery.t()} | {:error, term()}
  def suppress_delivery(%Delivery{} = delivery, reason, opts)
      when is_atom(reason) and is_list(opts) do
    checkpoint =
      opts
      |> Keyword.get(:checkpoint, :perform)
      |> normalize_checkpoint()

    metadata =
      delivery.metadata
      |> ensure_metadata_map()
      |> Map.put("policy_checkpoint", checkpoint)

    delivery
    |> change(
      status: :suppressed,
      suppression_reason: Atom.to_string(reason),
      metadata: metadata
    )
    |> Repo.update()
    |> maybe_apply_progression()
  end

  @doc """
  Persists planning-time orchestration facts on the canonical delivery row.
  """
  @spec apply_planning_decision(Delivery.t(), map()) :: {:ok, Delivery.t()} | {:error, term()}
  def apply_planning_decision(%Delivery{} = delivery, decision) when is_map(decision) do
    with {:ok, state} <-
           normalize_orchestration_state(Map.get(decision, :orchestration_state, :ready)),
         {:ok, planning_reason} <- normalize_optional_string(Map.get(decision, :planning_reason)),
         {:ok, planning_context} <- normalize_optional_map(Map.get(decision, :planning_context)),
         {:ok, next_eligible_at} <-
           normalize_optional_datetime(Map.get(decision, :next_eligible_at)) do
      delivery
      |> change(%{
        orchestration_state: state,
        planning_reason: planning_reason,
        planning_context: planning_context,
        next_eligible_at: next_eligible_at
      })
      |> Repo.update()
    end
  end

  def apply_planning_decision(%Delivery{} = _delivery, decision),
    do: {:error, {:invalid_planning_decision, decision}}

  @doc """
  Persists render identity on the canonical delivery row for reused planning paths.
  """
  @spec apply_render_identity(Delivery.t(), map()) :: {:ok, Delivery.t()} | {:error, term()}
  def apply_render_identity(%Delivery{} = delivery, identity) when is_map(identity) do
    with {:ok, render_key} <- normalize_optional_render_key(Map.get(identity, :render_key)),
         {:ok, render_version} <-
           normalize_optional_render_version(Map.get(identity, :render_version)) do
      delivery
      |> change(%{render_key: render_key, render_version: render_version})
      |> Repo.update()
    end
  end

  def apply_render_identity(%Delivery{} = _delivery, identity),
    do: {:error, {:invalid_render_identity, identity}}

  @doc """
  Persists the validated render result on the canonical delivery row.
  """
  @spec apply_render_result(Delivery.t(), map()) :: {:ok, Delivery.t()} | {:error, term()}
  def apply_render_result(%Delivery{} = delivery, render_result) when is_map(render_result) do
    with {:ok, render_key} <- normalize_optional_render_key(Map.get(render_result, :render_key)),
         {:ok, render_version} <-
           normalize_optional_render_version(Map.get(render_result, :render_version)),
         {:ok, render_data} <-
           normalize_optional_render_data(Map.get(render_result, :render_data, %{})) do
      delivery
      |> change(%{
        render_key: render_key,
        render_version: render_version,
        render_data: render_data
      })
      |> Repo.update()
    end
  end

  def apply_render_result(%Delivery{} = _delivery, render_result),
    do: {:error, {:invalid_render_result, render_result}}

  @doc """
  Persists workflow run and active-step linkage on the canonical delivery row.
  """
  @spec apply_workflow_linkage(Delivery.t(), map()) :: {:ok, Delivery.t()} | {:error, term()}
  def apply_workflow_linkage(%Delivery{} = delivery, linkage) when is_map(linkage) do
    with {:ok, workflow_run_id} <-
           normalize_optional_binary_id(Map.get(linkage, :workflow_run_id)),
         {:ok, workflow_step_id} <-
           normalize_optional_binary_id(Map.get(linkage, :workflow_step_id)) do
      delivery
      |> change(%{
        workflow_run_id: workflow_run_id,
        workflow_step_id: workflow_step_id
      })
      |> Repo.update()
    end
  end

  def apply_workflow_linkage(%Delivery{} = _delivery, linkage),
    do: {:error, {:invalid_workflow_linkage, linkage}}

  @doc """
  Marks a digest-held source row as included in an emitted digest.
  """
  @spec mark_digested(Delivery.t(), binary(), String.t(), keyword()) ::
          {:ok, Delivery.t()} | {:noop, Delivery.t()}
  def mark_digested(%Delivery{id: delivery_id}, digest_delivery_id, reason, opts \\ [])
      when is_binary(digest_delivery_id) and is_binary(reason) and is_list(opts) do
    resolve_digest_outcome(
      delivery_id,
      :digested,
      :digested,
      digest_delivery_id,
      reason,
      opts
    )
  end

  @doc """
  Marks a digest-held source row as skipped at flush with an explicit reason.
  """
  @spec mark_digest_skipped(Delivery.t(), binary(), String.t(), keyword()) ::
          {:ok, Delivery.t()} | {:noop, Delivery.t()}
  def mark_digest_skipped(%Delivery{id: delivery_id}, digest_delivery_id, reason, opts \\ [])
      when is_binary(digest_delivery_id) and is_binary(reason) and is_list(opts) do
    resolve_digest_outcome(
      delivery_id,
      :suppressed,
      :skipped_by_policy,
      digest_delivery_id,
      reason,
      opts
    )
  end

  @doc """
  Releases a digest-held source row back to the normal ready lifecycle.
  """
  @spec mark_digest_immediate(Delivery.t(), binary(), String.t(), keyword()) ::
          {:ok, Delivery.t()} | {:noop, Delivery.t()}
  def mark_digest_immediate(%Delivery{id: delivery_id}, digest_delivery_id, reason, opts \\ [])
      when is_binary(digest_delivery_id) and is_binary(reason) and is_list(opts) do
    resolve_digest_outcome(
      delivery_id,
      :pending,
      :emitted_immediately,
      digest_delivery_id,
      reason,
      opts
    )
  end

  @doc """
  Lists deferred delivery rows that are still pending and due for resume.
  """
  @spec list_due_deferred_deliveries(keyword()) :: [Delivery.t()]
  def list_due_deferred_deliveries(opts \\ []) when is_list(opts) do
    now =
      opts
      |> Keyword.get(:now, DateTime.utc_now())
      |> normalize_datetime!()

    Repo.all(
      from(d in Delivery,
        where:
          d.status == :pending and d.orchestration_state == :deferred and
            not is_nil(d.next_eligible_at) and d.next_eligible_at <= ^now,
        order_by: [asc: d.next_eligible_at, asc: d.inserted_at]
      )
    )
  end

  @doc """
  Promotes a due deferred delivery row back to `:ready` without changing delivery identity.
  Returns `{:noop, delivery}` when the row is no longer pending, deferred, and due.
  """
  @spec resume_deferred_delivery(binary() | Delivery.t(), keyword()) ::
          {:ok, Delivery.t()} | {:noop, Delivery.t()}
  def resume_deferred_delivery(delivery_or_id, opts \\ [])

  def resume_deferred_delivery(%Delivery{id: delivery_id}, opts) when is_list(opts) do
    resume_deferred_delivery(delivery_id, opts)
  end

  def resume_deferred_delivery(delivery_id, opts) when is_binary(delivery_id) and is_list(opts) do
    now =
      opts
      |> Keyword.get(:now, DateTime.utc_now())
      |> normalize_datetime!()

    source = normalize_resume_source!(Keyword.get(opts, :source, "scheduled_resume"))

    delivery = get_delivery!(delivery_id)

    metadata =
      delivery.metadata
      |> ensure_metadata_map()
      |> Map.put("resume_source", source)
      |> Map.put("resume_scheduled_at", iso8601_utc_usec(delivery.next_eligible_at))
      |> Map.put("resumed_at", iso8601_utc_usec(now))

    {updated_count, _rows} =
      Repo.update_all(
        from(d in Delivery,
          where:
            d.id == ^delivery_id and d.status == :pending and d.orchestration_state == :deferred and
              not is_nil(d.next_eligible_at) and d.next_eligible_at <= ^now
        ),
        set: [orchestration_state: :ready, metadata: metadata, updated_at: now]
      )

    updated_delivery = get_delivery!(delivery_id)

    if updated_count == 1 do
      {:ok, updated_delivery}
    else
      {:noop, updated_delivery}
    end
  end

  @doc """
  Cancels a deferred delivery row in place, preserving the same delivery identity.
  Returns `{:noop, delivery}` when the row is no longer a pending deferred delivery.
  """
  @spec cancel_deferred_delivery(binary() | Delivery.t(), String.t(), keyword()) ::
          {:ok, Delivery.t()} | {:noop, Delivery.t()}
  def cancel_deferred_delivery(delivery_or_id, reason, opts \\ [])

  def cancel_deferred_delivery(%Delivery{id: delivery_id}, reason, opts)
      when is_binary(reason) and is_list(opts) do
    cancel_deferred_delivery(delivery_id, reason, opts)
  end

  def cancel_deferred_delivery(delivery_id, reason, opts)
      when is_binary(delivery_id) and is_binary(reason) and is_list(opts) do
    now =
      opts
      |> Keyword.get(:now, DateTime.utc_now())
      |> normalize_datetime!()

    reason = normalize_suppression_reason!(reason)
    delivery = get_delivery!(delivery_id)

    metadata =
      delivery.metadata
      |> ensure_metadata_map()
      |> Map.put("resume_cancelled_at", iso8601_utc_usec(now))

    {updated_count, _rows} =
      Repo.update_all(
        from(d in Delivery,
          where:
            d.id == ^delivery_id and d.status == :pending and d.orchestration_state == :deferred
        ),
        set: [status: :cancelled, suppression_reason: reason, metadata: metadata, updated_at: now]
      )

    updated_delivery = get_delivery!(delivery_id)

    if updated_count == 1 do
      {:ok, updated_delivery}
    else
      {:noop, updated_delivery}
    end
  end

  @doc """
  Transitions a `:failed` delivery to `:cancelled` with `suppression_reason: "retries_exhausted"`.

  This is the ONLY entry point for the `failed -> :cancelled` transition. The general
  `transition_status/2` path intentionally rejects `failed -> :cancelled` (the
  `@allowed_transitions` table has `failed: [:dispatched]` only). `exhaust_delivery/1`
  performs a direct `change/2 |> Repo.update()` that bypasses the transition table —
  exactly mirroring how `suppress_delivery/3` writes the `:suppressed` terminal state
  from any non-terminal status.

  Called from the Oban worker when
  `job.attempt == job.max_attempts` and the adapter classification was `:temporary`
  (REL-03 D-10/D-11). Records `policy_checkpoint: "perform"` in metadata so traces
  preserve the explanation that exhaustion happened at perform time.
  """
  @spec exhaust_delivery(Delivery.t()) :: {:ok, Delivery.t()} | {:error, term()}
  def exhaust_delivery(%Delivery{status: :failed} = delivery) do
    metadata =
      delivery.metadata
      |> ensure_metadata_map()
      |> Map.put("policy_checkpoint", "perform")

    delivery
    |> change(
      status: :cancelled,
      suppression_reason: "retries_exhausted",
      metadata: metadata
    )
    |> Repo.update()
    |> maybe_apply_progression()
  end

  def exhaust_delivery(%Delivery{status: status}),
    do: {:error, {:invalid_exhaust_from, status}}

  defp normalize_datetime!(%DateTime{} = value) do
    %{value | microsecond: normalize_microsecond(value.microsecond)}
  end

  defp normalize_datetime!(value),
    do: raise(ArgumentError, "expected DateTime, got: #{inspect(value)}")

  defp recoverable_cutoff!(%DateTime{} = now, older_than)
       when is_integer(older_than) and older_than >= 0 do
    now
    |> DateTime.add(-older_than, :second)
    |> normalize_datetime!()
  end

  defp recoverable_cutoff!(_now, older_than),
    do:
      raise(
        ArgumentError,
        "expected non-negative integer older_than, got: #{inspect(older_than)}"
      )

  defp normalize_resume_source!(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_resume_source!(value) when is_binary(value) and byte_size(value) > 0, do: value

  defp normalize_resume_source!(value),
    do: raise(ArgumentError, "expected non-empty resume source, got: #{inspect(value)}")

  defp normalize_suppression_reason!(value) when is_binary(value) and byte_size(value) > 0,
    do: value

  defp normalize_suppression_reason!(value),
    do: raise(ArgumentError, "expected non-empty suppression reason, got: #{inspect(value)}")

  defp normalize_recovery_value!(_label, value)
       when is_binary(value) and byte_size(value) > 0,
       do: value

  defp normalize_recovery_value!(label, value)
       when is_atom(value),
       do: normalize_recovery_value!(label, Atom.to_string(value))

  defp normalize_recovery_value!(label, value),
    do: raise(ArgumentError, "expected non-empty #{label}, got: #{inspect(value)}")

  defp configured_dispatcher do
    Application.get_env(:chimeway, :dispatcher, Chimeway.Dispatch.Sync)
  end

  defp recovery_delivery_result(%Delivery{} = delivery, source, reason, now, dispatch_state) do
    %{
      delivery: delivery,
      dispatch: dispatch_state,
      recovery: recovery_metadata(source, reason, now)
    }
  end

  defp recovery_metadata(source, reason, recovered_at) do
    %{
      source: source,
      reason: reason,
      recovered_at: recovered_at
    }
  end

  defp compensate_failed_recovery_claim(delivery_id, now, older_than) do
    recoverable_updated_at = recoverable_cutoff!(now, older_than)

    Repo.update_all(
      from(d in Delivery,
        where:
          d.id == ^delivery_id and d.status == :pending and d.orchestration_state == :ready and
            not fragment("?->>? IS NULL", d.metadata, ^"recovered_at"),
        update: [
          set: [
            metadata:
              fragment(
                "(COALESCE(?, '{}'::jsonb) - 'recovery_source' - 'recovery_reason' - 'recovered_at')",
                d.metadata
              ),
            updated_at: ^recoverable_updated_at
          ]
        ]
      ),
      []
    )

    get_delivery!(delivery_id)
  end

  defp dispatched_deliveries(deliveries_or_results) do
    Enum.map(deliveries_or_results, fn
      %Delivery{} = delivery -> delivery
      {:ok, %Delivery{} = delivery} -> delivery
      {:skip, %Delivery{} = delivery} -> delivery
    end)
  end

  defp stamp_recovery_metadata(deliveries, source, reason, now) do
    delivery_ids = Enum.map(deliveries, & &1.id)
    recovered_at = iso8601_utc_usec(now)

    if delivery_ids != [] do
      Repo.update_all(
        from(d in Delivery,
          where: d.id in ^delivery_ids and fragment("?->>? IS NULL", d.metadata, ^"recovered_at"),
          update: [
            set: [
              metadata:
                fragment(
                  """
                  jsonb_set(
                    jsonb_set(
                      jsonb_set(COALESCE(?, '{}'::jsonb), '{recovery_source}', to_jsonb(?::text), true),
                      '{recovery_reason}',
                      to_jsonb(?::text),
                      true
                    ),
                    '{recovered_at}',
                    to_jsonb(?::text),
                    true
                  )
                  """,
                  d.metadata,
                  ^source,
                  ^reason,
                  ^recovered_at
                ),
              updated_at: ^now
            ]
          ]
        ),
        []
      )
    end

    Repo.all(
      from(d in Delivery, where: d.id in ^delivery_ids, order_by: [asc: d.channel, asc: d.id])
    )
  end

  defp iso8601_utc_usec(nil), do: nil

  defp iso8601_utc_usec(%DateTime{} = value) do
    value
    |> DateTime.truncate(:microsecond)
    |> DateTime.to_naive()
    |> NaiveDateTime.to_iso8601()
    |> Kernel.<>("Z")
  end

  @doc """
  Atomically inserts an attempt row and transitions the delivery status.

  Returns `{:ok, %{delivery: updated_delivery, attempt: attempt}}` on success, or
  `{:error, step, reason, changes}` if any step fails (both operations roll back).

  ## Phase 14 contract additions

  - Acquires a `SELECT ... FOR UPDATE` row lock on the delivery via the
    `:lock_delivery` Multi step BEFORE computing `attempt_number` (W8 preemptive
    fix). This serializes concurrent `record_attempt/2` callers for the same
    delivery and makes `attempt_number` contiguity invariant under concurrent
    execution. The `pending -> dispatched` transition that
    `Executor.run_delivery/1` performs BEFORE calling this function is a secondary
    serialization layer.
  - Computes `attempt_number` inside the Multi via the `:next_attempt_number` step
    (RESEARCH Pattern 4).
  - Routes `error_class` permanent/bounced outcomes to `:cancelled` with the
    appropriate `suppression_reason` inside the same transaction (RESEARCH
    Pitfall 2). This makes sync and Oban paths converge on a terminal state
    without forking — sync gains REL-03 convergence automatically.
  - Telemetry stop metadata now includes `attempt_number` and `error_class`,
    preserving the Phase 10 correlation_id/notification_key keys.
  """
  @spec record_attempt(Delivery.t(), map()) ::
          {:ok, %{delivery: Delivery.t(), attempt: DeliveryAttempt.t()}}
          | {:error, atom(), term(), map()}
  def record_attempt(%Delivery{} = delivery, attrs) do
    Telemetry.span(
      [:attempts, :record],
      Telemetry.safe_meta(%{
        delivery_id: delivery.id,
        channel: delivery.channel,
        notification_key: Map.get(delivery.metadata || %{}, "notification_key")
      }),
      fn ->
        result = do_record_attempt(delivery, attrs)

        extra =
          case result do
            {:ok, %{attempt: attempt}} ->
              Telemetry.safe_meta(%{
                attempt_id: attempt.id,
                outcome: attempt.outcome,
                attempt_number: attempt.attempt_number,
                error_class: attempt.error_class
              })

            _ ->
              %{}
          end

        {result, extra}
      end
    )
  end

  defp do_record_attempt(%Delivery{} = delivery, attrs) do
    outcome = Map.get(attrs, :outcome) || Map.get(attrs, "outcome")
    error_class = Map.get(attrs, :error_class) || Map.get(attrs, "error_class")

    safe_attrs =
      attrs
      |> coerce_provider_response_to_atom_key()
      |> Map.update(:provider_response, nil, &sanitize_metadata/1)
      |> Map.put(:delivery_id, delivery.id)

    Multi.new()
    |> Multi.run(:lock_delivery, fn repo, _changes ->
      # W8 preemptive fix: SELECT FOR UPDATE serializes concurrent
      # record_attempt/2 callers for the same delivery_id. With this lock,
      # attempt_number contiguity is invariant under concurrent execution.
      case repo.one(from(d in Delivery, where: d.id == ^delivery.id, lock: "FOR UPDATE")) do
        nil -> {:error, :delivery_not_found}
        locked -> {:ok, locked}
      end
    end)
    |> Multi.run(:next_attempt_number, fn repo, %{lock_delivery: locked} ->
      next_n =
        from(a in DeliveryAttempt,
          where: a.delivery_id == ^locked.id,
          select: count(a.id)
        )
        |> repo.one()
        |> Kernel.+(1)

      {:ok, next_n}
    end)
    |> Multi.insert(:attempt, fn %{next_attempt_number: n, lock_delivery: locked} ->
      attempt_attrs =
        safe_attrs
        |> Map.put(:delivery_id, locked.id)
        |> Map.put(:attempt_number, n)

      DeliveryAttempt.changeset(%DeliveryAttempt{}, attempt_attrs)
    end)
    |> Multi.run(:delivery, fn _repo, %{lock_delivery: locked} ->
      terminal_or_failed_transition(locked, outcome, error_class)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{delivery: updated_delivery, attempt: attempt}} ->
        # Canonical convergence point — drive workflow progression once after
        # the durable transaction commits so the engine reads the final
        # delivery row and can take its own FOR UPDATE locks without nesting
        # SELECT FOR UPDATE inside the attempt-recording lock.
        maybe_progress_workflow(updated_delivery)
        {:ok, %{delivery: updated_delivery, attempt: attempt}}

      {:error, step, reason, changes} ->
        {:error, step, reason, changes}
    end
  end

  defp coerce_provider_response_to_atom_key(attrs) do
    case Map.pop(attrs, "provider_response") do
      {nil, attrs} -> attrs
      {val, attrs} -> Map.put_new(attrs, :provider_response, val)
    end
  end

  # Maps outcome + error_class to the next delivery status. Permanent/bounced go
  # straight to :cancelled (sync and Oban both converge here). Temporary stays at
  # :failed so Oban can retry. Succeeded transitions normally.
  defp terminal_or_failed_transition(delivery, :succeeded, _error_class),
    do: transition_status(delivery, :succeeded)

  defp terminal_or_failed_transition(delivery, "succeeded", _error_class),
    do: transition_status(delivery, :succeeded)

  defp terminal_or_failed_transition(delivery, _outcome, "permanent"),
    do: cancel_with_reason(delivery, "permanent_failure")

  defp terminal_or_failed_transition(delivery, _outcome, "bounced"),
    do: cancel_with_reason(delivery, "bounced")

  defp terminal_or_failed_transition(delivery, _outcome, _error_class),
    do: transition_status(delivery, :failed)

  # Direct cancel write for permanent/bounced terminal convergence.
  # Bypasses @allowed_transitions because dispatched -> :cancelled is not in the
  # table; mirrors the suppress_delivery/3 + exhaust_delivery/1 named-helper idiom.
  # The explicit suppression_reason ("permanent_failure" or "bounced") is the
  # durable explanation operators see in traces.
  defp cancel_with_reason(%Delivery{} = delivery, reason) when is_binary(reason) do
    # NOTE: progression is invoked by `record_attempt/2` after the wrapping
    # `Multi` commits, so this private direct-cancel helper does NOT call
    # `maybe_apply_progression/1` itself. That keeps the canonical convergence
    # path single-entry: one progression call per `record_attempt/2` call.
    metadata =
      delivery.metadata
      |> ensure_metadata_map()
      |> Map.put("policy_checkpoint", "perform")

    delivery
    |> change(
      status: :cancelled,
      suppression_reason: reason,
      metadata: metadata
    )
    |> Repo.update()
  end

  defp resolve_digest_outcome(
         delivery_id,
         status,
         digest_flush_outcome,
         digest_delivery_id,
         reason,
         opts
       ) do
    resolved_at =
      opts
      |> Keyword.get(:resolved_at, DateTime.utc_now())
      |> normalize_datetime!()

    {updated_count, _rows} =
      Repo.update_all(
        from(d in Delivery,
          where:
            d.id == ^delivery_id and d.status == :pending and
              d.orchestration_state == :digest_held
        ),
        set: [
          status: status,
          orchestration_state: :ready,
          digest_flush_outcome: digest_flush_outcome,
          digest_flush_reason: reason,
          digest_flush_resolved_at: resolved_at,
          digest_delivery_id: digest_delivery_id,
          updated_at: resolved_at
        ]
      )

    updated_delivery = get_delivery!(delivery_id)

    if updated_count == 1 do
      {:ok, updated_delivery}
    else
      {:noop, updated_delivery}
    end
  end

  @sensitive_keys ~w(password token secret)

  defp sanitize_metadata(map) when is_map(map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      if sensitive_key?(key), do: acc, else: Map.put(acc, key, value)
    end)
  end

  defp sanitize_metadata(_), do: %{}

  defp ensure_metadata_map(map) when is_map(map), do: map
  defp ensure_metadata_map(_), do: %{}

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp normalize_checkpoint(:planning), do: "planning"
  defp normalize_checkpoint(:perform), do: "perform"
  defp normalize_checkpoint("planning"), do: "planning"
  defp normalize_checkpoint("perform"), do: "perform"
  defp normalize_checkpoint(_), do: "perform"

  defp sensitive_key?(key) when is_atom(key), do: sensitive_key?(Atom.to_string(key))
  defp sensitive_key?(key) when is_binary(key), do: String.downcase(key) in @sensitive_keys
  defp sensitive_key?(_), do: false

  # ---- Workflow progression hook ---------------------------------------------
  # All canonical terminal-write paths converge through one of these helpers so
  # the workflow progression engine sees every relevant delivery state change
  # exactly once. The engine is itself noop-safe for non-workflow-linked rows,
  # non-active runs, and unmatched rules per ESC-03 / T-25-06.

  defp maybe_apply_progression({:ok, %Delivery{} = delivery} = ok) do
    maybe_progress_workflow(delivery)
    ok
  end

  defp maybe_apply_progression(other), do: other

  defp maybe_progress_workflow(%Delivery{workflow_run_id: nil}), do: :noop

  defp maybe_progress_workflow(%Delivery{workflow_run_id: workflow_run_id})
       when is_binary(workflow_run_id) do
    case Chimeway.Workflows.Progression.progress_run(workflow_run_id, []) do
      {:ok, _result} -> :ok
      {:error, _reason} -> :error
    end
  end

  defp maybe_progress_workflow(_other), do: :noop
end
