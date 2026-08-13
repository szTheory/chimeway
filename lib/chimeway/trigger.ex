defmodule Chimeway.Trigger do
  @moduledoc """
  Orchestrates notifier triggering with deterministic recipient normalization.

  ## Duplicate-trigger contract (Phase 14 / D-03)

  When `trigger/3` returns `{:duplicate, event}`, `dispatch_after_trigger/4` is INERT
  — it does NOT re-drive dispatch for the existing event. This means:

  - No new Oban jobs are enqueued.
  - No additional `Chimeway.Delivery` rows are planned.
  - The pre-existing pending deliveries from the first trigger remain in their
    current state (whether already-dispatched, retrying, or terminal).

  If a host application crashes between event-insert commit and the dispatcher being
  called, deliveries from that aborted trigger ARE NOT recovered by a subsequent
  re-fire. Recovery for that scenario is explicitly deferred to a future operability
  phase.   Operators investigating "why wasn't this delivered after a duplicate
  trigger?" should look at the original event's deliveries via
  `Chimeway.Traces.get_trace/1`, not at the duplicate.

  ## Payload sanitization (D-08)

  `trigger/3` strips `@sensitive_keys` from persisted event `payload` and from
  notification `metadata` / `render_assigns`. Auth-flow keys `url`, `code`,
  `raw_token`, and `magic_link_url` are removed in addition to `password`,
  `token`, and `secret`. Identifier-only trigger params remain the primary
  contract for integration boundaries.
  """

  require Logger

  import Ecto.Query, only: [from: 2]

  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification
  alias Chimeway.Notifier
  alias Chimeway.Repo
  alias Chimeway.{Privacy, Rendering, SafeEvidence, Telemetry}
  alias Chimeway.Workflows
  alias Ecto.Multi
  alias Ecto.UUID

  @spec trigger(module(), map(), keyword()) ::
          {:ok, map()} | {:duplicate, struct()} | {:error, term()}
  def trigger(notifier, params, opts \\ []) do
    correlation_ref =
      case Keyword.fetch(opts, :correlation_id) do
        {:ok, cid} -> cid
        :error -> Keyword.get(opts, :correlation_ref)
      end

    with {:ok, idempotency_key} <- Keyword.fetch(opts, :idempotency_key),
         {:ok, tenant_id} <- fetch_and_normalize_tenant_id(opts),
         :ok <- validate_idempotency_key(idempotency_key),
         :ok <- Notifier.validate_module!(notifier),
         {:ok, correlation_ref} <- optional_correlation_ref(correlation_ref),
         {:ok, recipients} <- notifier.recipients(params),
         {:ok, normalized_recipients} <- normalize_recipients(recipients) do
      opts = Keyword.put(opts, :tenant_id, tenant_id)

      do_trigger(
        notifier,
        params,
        opts,
        idempotency_key,
        correlation_ref,
        normalized_recipients,
        tenant_id
      )
    else
      :error -> {:error, :missing_idempotency_key}
      {:error, _reason} = error -> error
    end
  end

  defp do_trigger(
         notifier,
         params,
         opts,
         idempotency_key,
         correlation_id,
         normalized_recipients,
         tenant_id
       ) do
    Telemetry.span(
      [:events, :create],
      Telemetry.safe_meta(%{
        notification_key: notifier.notification_key(),
        correlation_id: correlation_id
      }),
      fn ->
        result =
          Multi.new()
          |> Multi.insert(
            :event,
            event_changeset(
              notifier,
              idempotency_key,
              params,
              correlation_id,
              tenant_id
            )
          )
          |> Multi.run(:notifications, fn repo, %{event: event} ->
            insert_notifications(repo, notifier, params, event, normalized_recipients, tenant_id)
          end)
          |> Repo.transaction()

        extra =
          case result do
            {:ok, %{event: event}} ->
              Telemetry.safe_meta(%{
                event_id: event.id,
                notification_key: event.notification_key,
                correlation_id: event.correlation_id
              })

            _ ->
              %{}
          end

        {result, extra}
      end
    )
    |> normalize_trigger_result(idempotency_key, normalized_recipients, tenant_id)
    |> then(&plan_deliveries_span(&1, notifier, params, opts))
  end

  @spec normalize_recipients([map()]) :: {:ok, [map()]} | {:error, :unsafe_evidence}
  def normalize_recipients(recipients) when is_list(recipients) do
    recipients
    |> Enum.reduce_while({:ok, %{}}, fn recipient, {:ok, acc} ->
      case SafeEvidence.recipient_reference(
             recipient_ref(recipient) || recipient_identity(recipient)
           ) do
        {:ok, ref} ->
          {:cont, {:ok, Map.put_new(acc, ref, Map.put(recipient, :recipient_ref, ref))}}

        {:error, :unsafe_evidence} ->
          {:halt, {:error, :unsafe_evidence}}
      end
    end)
    |> case do
      {:ok, recipients_by_ref} ->
        {:ok,
         recipients_by_ref
         |> Map.values()
         |> Enum.sort_by(&(recipient_identity(&1) || recipient_ref(&1) || ""))}

      error ->
        error
    end
  end

  def normalize_recipients(_recipients), do: {:error, :unsafe_evidence}

  defp validate_idempotency_key(idempotency_key) when is_binary(idempotency_key) do
    if String.trim(idempotency_key) == "" do
      {:error, :blank_idempotency_key}
    else
      :ok
    end
  end

  defp validate_idempotency_key(_idempotency_key), do: {:error, :invalid_idempotency_key}

  defp fetch_and_normalize_tenant_id(opts) do
    case Keyword.fetch(opts, :tenant_id) do
      {:ok, tenant_id} -> normalize_tenant_id(tenant_id)
      :error -> {:error, :missing_tenant_id}
    end
  end

  defp normalize_tenant_id(tenant_id) when is_binary(tenant_id) do
    case String.trim(tenant_id) do
      "" -> {:error, :invalid_tenant_id}
      normalized_tenant_id -> {:ok, normalized_tenant_id}
    end
  end

  defp normalize_tenant_id(_tenant_id), do: {:error, :invalid_tenant_id}

  defp event_changeset(notifier, idempotency_key, params, correlation_id, tenant_id) do
    Event.changeset(%Event{}, %{
      notification_key: notifier.notification_key(),
      notification_version: notifier.version(),
      idempotency_key: idempotency_key,
      tenant_id: tenant_id,
      payload: params |> Privacy.redact() |> SafeEvidence.event_payload(),
      correlation_id: correlation_id
    })
    |> Ecto.Changeset.unique_constraint(:idempotency_key,
      name: :chimeway_events_tenant_id_idempotency_key_index
    )
  end

  defp insert_notifications(repo, notifier, params, event, recipients, tenant_id) do
    with {:ok, notifications} <-
           notifications_attrs(repo, notifier, params, event, recipients, tenant_id) do
      try do
        rows = Enum.map(notifications, & &1.row)
        {count, _rows} = repo.insert_all("chimeway_notifications", rows)

        with :ok <- insert_workflow_runs(repo, notifications, tenant_id) do
          {:ok, %{count: count, precomputed_rendering: precomputed_rendering(notifications)}}
        end
      rescue
        error -> {:error, error}
      end
    end
  end

  defp notifications_attrs(repo, notifier, params, event, recipients, tenant_id) do
    timestamp = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    recipients
    |> Enum.reduce_while({:ok, [], %{}}, fn recipient, {:ok, acc, workflow_cache} ->
      with {:ok, rendering} <- Notifier.resolve_rendering(notifier, params, recipient),
           {:ok, orchestration} <- Notifier.resolve_orchestration(notifier, params, recipient),
           {:ok, workflow_definition, workflow_cache} <-
             resolve_workflow_definition(repo, notifier, params, recipient, workflow_cache) do
        render_assigns =
          rendering.assigns |> Privacy.redact() |> SafeEvidence.notification_metadata()

        render_channels =
          rendering
          |> Map.get(:channels, %{})
          |> SafeEvidence.render_channels()

        orchestration = Notifier.serialize_orchestration(orchestration)

        notification_id = UUID.generate()

        row = %{
          id: notification_id |> UUID.dump!(),
          event_id: UUID.dump!(event.id),
          tenant_id: tenant_id,
          recipient_identity: recipient_ref(recipient),
          recipient_type: recipient_type(recipient),
          metadata: render_assigns,
          render_assigns: render_assigns,
          render_channels: render_channels,
          orchestration: orchestration,
          workflow_definition_id: workflow_definition_id(workflow_definition),
          inserted_at: timestamp,
          updated_at: timestamp
        }

        {:cont,
         {:ok,
          [
            %{
              row: row,
              workflow_definition: workflow_definition,
              precomputed_rendering: precompute_rendering(notification_id, rendering)
            }
            | acc
          ], workflow_cache}}
      end
    end)
    |> case do
      {:ok, rows, _workflow_cache} -> {:ok, Enum.reverse(rows)}
      {:error, _reason} = error -> error
    end
  end

  defp precompute_rendering(notification_id, %{assigns: assigns, channels: channels}) do
    assigns = Map.drop(assigns, [:recipient, "recipient"])

    channels
    |> Enum.reduce(%{}, fn {channel, declaration}, acc ->
      with {:ok, rendered} <-
             Rendering.render_delivery(
               channel,
               declaration.render_key,
               declaration.render_version,
               assigns
             ) do
        Map.put(acc, {notification_id, to_string(channel)}, rendered)
      else
        _ -> acc
      end
    end)
  end

  defp precompute_rendering(_notification_id, _rendering), do: %{}

  defp precomputed_rendering(notifications) do
    notifications
    |> Enum.map(& &1.precomputed_rendering)
    |> Enum.reduce(%{}, &Map.merge/2)
  end

  defp normalize_trigger_result(
         {:ok,
          %{
            event: event,
            notifications: %{
              count: notifications_inserted,
              precomputed_rendering: precomputed_rendering
            }
          }},
         _idempotency_key,
         recipients,
         _tenant_id
       ) do
    {:ok,
     %{
       event: event,
       notification_key: event.notification_key,
       notification_version: event.notification_version,
       idempotency_key: event.idempotency_key,
       recipients: recipients,
       notifications_inserted: notifications_inserted,
       precomputed_rendering: precomputed_rendering,
       dispatch_outcome: :pending,
       dispatch_mode: :unknown,
       trace: %{
         event_id: event.id,
         correlation_id: event.correlation_id,
         delivery_ids: []
       }
     }}
  end

  defp normalize_trigger_result(
         {:error, :event, %Ecto.Changeset{} = changeset, _changes},
         idempotency_key,
         _recipients,
         tenant_id
       ) do
    if idempotency_conflict?(changeset) do
      case Repo.get_by(Event, tenant_id: tenant_id, idempotency_key: idempotency_key) do
        nil -> {:error, :duplicate_event_not_found}
        existing_event -> {:duplicate, existing_event}
      end
    else
      {:error, {:event_insert_failed, changeset}}
    end
  end

  defp normalize_trigger_result(
         {:error, :notifications, reason, _changes},
         _idempotency_key,
         _recipients,
         _tenant_id
       ) do
    {:error, {:notifications_insert_failed, reason}}
  end

  defp idempotency_conflict?(changeset) do
    Enum.any?(changeset.errors, fn
      {:idempotency_key, {_message, opts}} ->
        opts[:constraint] == :unique and
          opts[:constraint_name] in [
            :chimeway_events_tenant_id_idempotency_key_index,
            "chimeway_events_tenant_id_idempotency_key_index",
            :chimeway_events_tenant_id_idempotency_key_idx,
            "chimeway_events_tenant_id_idempotency_key_idx"
          ]

      _ ->
        false
    end)
  end

  defp resolve_workflow_definition(repo, notifier, params, recipient, workflow_cache) do
    with {:ok, nil} <- Notifier.resolve_workflow(notifier, params, recipient) do
      {:ok, nil, workflow_cache}
    else
      {:ok, workflow} ->
        workflow_identity = {workflow.workflow_key, workflow.workflow_version}

        case Map.fetch(workflow_cache, workflow_identity) do
          {:ok, workflow_definition} ->
            {:ok, workflow_definition, workflow_cache}

          :error ->
            with {:ok, workflow_definition} <-
                   Workflows.ensure_definition(repo, notifier.notification_key(), workflow) do
              {:ok, workflow_definition,
               Map.put(workflow_cache, workflow_identity, workflow_definition)}
            end
        end

      {:error, _reason} = error ->
        error
    end
  end

  defp insert_workflow_runs(repo, notifications, tenant_id) do
    Enum.reduce_while(notifications, :ok, fn
      %{workflow_definition: nil}, :ok ->
        {:cont, :ok}

      %{
        row: %{id: notification_id, inserted_at: inserted_at},
        workflow_definition: workflow_definition
      },
      :ok ->
        case Workflows.create_initial_run(
               repo,
               UUID.load!(notification_id),
               workflow_definition,
               inserted_at,
               tenant_id
             ) do
          {:ok, _workflow_run} -> {:cont, :ok}
          {:error, reason} -> {:halt, {:error, reason}}
        end
    end)
  end

  defp workflow_definition_id(nil), do: nil
  defp workflow_definition_id(%{id: id}), do: UUID.dump!(id)

  defp recipient_ref(%{recipient_ref: ref}), do: ref
  defp recipient_ref(%{"recipient_ref" => ref}), do: ref
  defp recipient_ref(_recipient), do: nil

  defp recipient_identity(%{recipient_identity: value}), do: value
  defp recipient_identity(%{"recipient_identity" => value}), do: value
  defp recipient_identity(_recipient), do: nil

  defp optional_correlation_ref(nil), do: {:ok, nil}
  defp optional_correlation_ref(value), do: SafeEvidence.opaque_ref(:correlation, value)

  defp recipient_type(%{recipient_type: recipient_type}),
    do: normalize_recipient_type(recipient_type)

  defp recipient_type(%{"recipient_type" => recipient_type}),
    do: normalize_recipient_type(recipient_type)

  defp recipient_type(%{channel: recipient_type}), do: normalize_recipient_type(recipient_type)

  defp recipient_type(%{"channel" => recipient_type}),
    do: normalize_recipient_type(recipient_type)

  defp recipient_type(_recipient), do: nil

  defp normalize_recipient_type(type) when is_binary(type), do: type
  defp normalize_recipient_type(type) when is_atom(type), do: Atom.to_string(type)
  defp normalize_recipient_type(_type), do: nil

  defp plan_deliveries_span(result, notifier, params, opts) do
    Telemetry.span(
      [:deliveries, :plan],
      Telemetry.safe_meta(%{notification_key: notifier.notification_key()}),
      fn ->
        dispatched = dispatch_after_trigger(result, notifier, params, opts)

        extra =
          case dispatched do
            {:ok, %{event: event}} ->
              Telemetry.safe_meta(%{
                event_id: event.id,
                correlation_id: event.correlation_id,
                notification_key: event.notification_key
              })

            _ ->
              %{}
          end

        {dispatched, extra}
      end
    )
  end

  # Dispatch after the trigger transaction commits.
  #
  # D-03 contract: this function returns its input unchanged on `{:duplicate, event}`
  # via the catch-all clause below. The duplicate path is INTENTIONALLY inert — do
  # NOT add a "resume dispatch on duplicate" path here. That scenario (host crashed
  # between event-insert commit and dispatcher invocation) is deferred to a future
  # operability/recovery phase. See @moduledoc § "Duplicate-trigger contract" for
  # the rationale.
  defp dispatch_after_trigger({:ok, %{event: event} = trigger_result}, notifier, params, opts) do
    dispatcher = Application.get_env(:chimeway, :dispatcher, Chimeway.Dispatch.Sync)
    notifications = Repo.all(from(n in Notification, where: n.event_id == ^event.id))

    dispatch_opts =
      opts
      |> Keyword.put_new(:notifier, notifier)
      |> Keyword.put_new(:trigger_params, params)
      |> Keyword.put_new(:notification_key, event.notification_key)
      |> Keyword.put_new(:event_id, event.id)
      |> Keyword.put_new(:correlation_id, event.correlation_id)
      |> Keyword.put_new(:precomputed_rendering, trigger_result.precomputed_rendering)

    case dispatcher.dispatch(notifications, dispatch_opts) do
      {:ok, deliveries} ->
        {:ok,
         merge_dispatch_outcome(trigger_result, :ok, dispatch_mode_for(dispatcher), deliveries)}

      {:error, reason} ->
        Logger.warning("Dispatch failed after trigger")

        {:ok,
         merge_dispatch_outcome(
           trigger_result,
           {:error, reason},
           dispatch_mode_for(dispatcher),
           []
         )}
    end
  end

  # D-03 catch-all: returns {:duplicate, event} | {:error, _} unchanged. Inert by design.
  defp dispatch_after_trigger(result, _notifier, _params, _opts), do: result

  defp dispatch_mode_for(Chimeway.Dispatch.Sync), do: :sync
  defp dispatch_mode_for(Chimeway.Dispatch.Oban), do: :oban
  defp dispatch_mode_for(_dispatcher), do: :unknown

  defp trace_with_delivery_ids(trace, deliveries) when is_list(deliveries) do
    delivery_ids =
      deliveries
      |> Enum.map(&delivery_id_from_dispatch_result/1)
      |> Enum.reject(&is_nil/1)

    Map.put(trace, :delivery_ids, delivery_ids)
  end

  defp merge_dispatch_outcome(trigger_result, dispatch_outcome, dispatch_mode, deliveries) do
    trace =
      trigger_result
      |> Map.get(:trace, %{})
      |> trace_with_delivery_ids(deliveries)

    %{
      trigger_result
      | dispatch_outcome: dispatch_outcome,
        dispatch_mode: dispatch_mode,
        trace: trace
    }
  end

  defp delivery_id_from_dispatch_result(%{id: id}), do: id
  defp delivery_id_from_dispatch_result({:ok, %{id: id}}), do: id
  defp delivery_id_from_dispatch_result({:skip, %{id: id}}), do: id
  defp delivery_id_from_dispatch_result(_), do: nil
end
