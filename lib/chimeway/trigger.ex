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
  phase. Operators investigating "why wasn't this delivered after a duplicate
  trigger?" should look at the original event's deliveries via
  `Chimeway.Traces.get_trace/1`, not at the duplicate.
  """

  require Logger

  import Ecto.Query, only: [from: 2]

  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification
  alias Chimeway.Notifier
  alias Chimeway.Repo
  alias Chimeway.Telemetry
  alias Ecto.Multi
  alias Ecto.UUID

  @sensitive_keys ~w(password token secret)

  @spec trigger(module(), map(), keyword()) ::
          {:ok, map()} | {:duplicate, struct()} | {:error, term()}
  def trigger(notifier, params, opts \\ []) do
    correlation_id =
      case Keyword.fetch(opts, :correlation_id) do
        {:ok, cid} when is_binary(cid) -> cid
        _ -> Logger.metadata()[:request_id]
      end

    with {:ok, idempotency_key} <- Keyword.fetch(opts, :idempotency_key),
         :ok <- validate_idempotency_key(idempotency_key),
         :ok <- Notifier.validate_module!(notifier),
         {:ok, recipients} <- notifier.recipients(params) do
      do_trigger(notifier, params, opts, idempotency_key, correlation_id, recipients)
    else
      :error -> {:error, :missing_idempotency_key}
      {:error, _reason} = error -> error
    end
  end

  defp do_trigger(notifier, params, opts, idempotency_key, correlation_id, recipients) do
    normalized_recipients = normalize_recipients(recipients)

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
            Event.changeset(%Event{}, %{
              notification_key: notifier.notification_key(),
              notification_version: notifier.version(),
              idempotency_key: idempotency_key,
              payload: sanitize_payload(params),
              correlation_id: correlation_id
            })
          )
          |> Multi.run(:notifications, fn repo, %{event: event} ->
            insert_notifications(repo, notifier, params, event, normalized_recipients)
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
    |> normalize_trigger_result(idempotency_key, normalized_recipients)
    |> then(&plan_deliveries_span(&1, notifier, params, opts))
  end

  @spec normalize_recipients([map()]) :: [map()]
  def normalize_recipients(recipients) when is_list(recipients) do
    recipients
    |> Enum.reduce(%{}, fn recipient, acc ->
      case recipient_identity(recipient) do
        identity when is_binary(identity) and byte_size(identity) > 0 ->
          Map.put_new(acc, identity, recipient)

        _identity ->
          acc
      end
    end)
    |> Enum.sort_by(fn {identity, _recipient} -> identity end)
    |> Enum.map(fn {_identity, recipient} -> recipient end)
  end

  defp validate_idempotency_key(idempotency_key) when is_binary(idempotency_key) do
    if String.trim(idempotency_key) == "" do
      {:error, :blank_idempotency_key}
    else
      :ok
    end
  end

  defp validate_idempotency_key(_idempotency_key), do: {:error, :invalid_idempotency_key}

  defp insert_notifications(repo, notifier, params, event, recipients) do
    with {:ok, notifications_attrs} <- notifications_attrs(notifier, params, event, recipients) do
      try do
        {count, _rows} = repo.insert_all("chimeway_notifications", notifications_attrs)
        {:ok, count}
      rescue
        error -> {:error, error}
      end
    end
  end

  defp notifications_attrs(notifier, params, event, recipients) do
    timestamp = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    recipients
    |> Enum.reduce_while({:ok, []}, fn recipient, {:ok, acc} ->
      with {:ok, rendering} <- Notifier.resolve_rendering(notifier, params, recipient) do
        render_assigns = sanitize_render_assigns(rendering.assigns)

        row = %{
          id: UUID.generate() |> UUID.dump!(),
          event_id: UUID.dump!(event.id),
          recipient_identity: recipient_identity(recipient),
          recipient_type: recipient_type(recipient),
          metadata: render_assigns,
          render_assigns: render_assigns,
          inserted_at: timestamp,
          updated_at: timestamp
        }

        {:cont, {:ok, [row | acc]}}
      end
    end)
    |> case do
      {:ok, rows} -> {:ok, Enum.reverse(rows)}
      {:error, _reason} = error -> error
    end
  end

  defp normalize_trigger_result(
         {:ok, %{event: event, notifications: notifications_inserted}},
         _idempotency_key,
         recipients
       ) do
    {:ok,
     %{
       event: event,
       notification_key: event.notification_key,
       notification_version: event.notification_version,
       idempotency_key: event.idempotency_key,
       recipients: recipients,
       notifications_inserted: notifications_inserted,
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
         _recipients
       ) do
    if idempotency_conflict?(changeset) do
      case Repo.get_by(Event, idempotency_key: idempotency_key) do
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
         _recipients
       ) do
    {:error, {:notifications_insert_failed, reason}}
  end

  defp idempotency_conflict?(changeset) do
    Enum.any?(changeset.errors, fn
      {:idempotency_key, {_message, opts}} ->
        opts[:constraint] == :unique and
          opts[:constraint_name] in [
            :chimeway_events_idempotency_key_index,
            "chimeway_events_idempotency_key_index"
          ]

      _ ->
        false
    end)
  end

  defp sanitize_payload(payload), do: sanitize_map(payload)

  defp sanitize_render_assigns(assigns), do: sanitize_map(assigns)

  defp sanitize_map(map) when is_map(map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      if sensitive_key?(key) do
        acc
      else
        Map.put(acc, key, value)
      end
    end)
  end

  defp sanitize_map(_not_map), do: %{}

  defp sensitive_key?(key) when is_atom(key), do: sensitive_key?(Atom.to_string(key))
  defp sensitive_key?(key) when is_binary(key), do: String.downcase(key) in @sensitive_keys
  defp sensitive_key?(_key), do: false

  defp recipient_identity(%{recipient_identity: identity}), do: identity
  defp recipient_identity(%{"recipient_identity" => identity}), do: identity
  defp recipient_identity(_recipient), do: nil

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

    case dispatcher.dispatch(notifications, dispatch_opts) do
      {:ok, deliveries} ->
        {:ok,
         merge_dispatch_outcome(trigger_result, :ok, dispatch_mode_for(dispatcher), deliveries)}

      {:error, reason} ->
        Logger.warning("Dispatch failed after trigger: #{inspect(reason)}")

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
  defp delivery_id_from_dispatch_result(_), do: nil
end
