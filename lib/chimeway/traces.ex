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
  alias Chimeway.Traces.Explanation

  @doc """
  Returns the full event trace for the given event_id with all associations preloaded.

  Preloads: `[notifications: [deliveries: :attempts]]`

  Returns `{:ok, event}` or `{:error, :not_found}`.
  """
  @spec get_trace(String.t()) :: {:ok, Event.t()} | {:error, :not_found}
  def get_trace(event_id) do
    case Repo.get(Event, event_id) do
      nil ->
        {:error, :not_found}

      event ->
        loaded = Repo.preload(event, notifications: [deliveries: :attempts])
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

    Repo.all(query)
  end

  @doc """
  Returns all events with the given correlation_id, each with associations preloaded.

  Returns `[]` when no events match — never returns an error tuple since
  correlation IDs are user-supplied and may not be unique or present.
  """
  @spec find_traces_by_correlation_id(String.t()) :: [Event.t()]
  def find_traces_by_correlation_id(correlation_id) do
    events =
      Repo.all(from(e in Event, where: e.correlation_id == ^correlation_id))

    Repo.preload(events, notifications: [deliveries: :attempts])
  end

  @doc """
  Returns a structured explanation for the given delivery_id.

  The explanation includes the full timeline derived from row timestamps,
  the final status, suppression reason, and last attempt outcome.

  Returns `{:ok, %Chimeway.Traces.Explanation{}}` or `{:error, :not_found}`.
  """
  @spec explain_delivery(String.t()) :: {:ok, Explanation.t()} | {:error, :not_found}
  def explain_delivery(delivery_id) do
    delivery =
      Repo.one(
        from(d in Delivery,
          where: d.id == ^delivery_id,
          preload: [notification: :event, attempts: []]
        )
      )

    case delivery do
      nil ->
        {:error, :not_found}

      %Delivery{notification: notification, attempts: attempts} ->
        event = notification.event
        last_attempt = last_attempt_summary(attempts)
        timeline = build_timeline(event, notification, delivery, attempts)

        explanation = %Explanation{
          delivery_id: delivery.id,
          event_id: event.id,
          correlation_id: event.correlation_id,
          notification_key: event.notification_key,
          recipient_id: notification.recipient_identity,
          channel: String.to_existing_atom(delivery.channel),
          status: delivery.status,
          suppression_reason: delivery.suppression_reason,
          last_attempt: last_attempt,
          timeline: timeline
        }

        {:ok, explanation}
    end
  end

  # --- Private helpers ---

  defp last_attempt_summary([]), do: nil

  defp last_attempt_summary(attempts) do
    last = Enum.max_by(attempts, & &1.inserted_at, DateTime)
    %{outcome: last.outcome, inserted_at: last.inserted_at}
  end

  defp build_timeline(event, notification, delivery, attempts) do
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

    suppression_entries =
      if delivery.status == :suppressed and delivery.suppression_reason do
        [
          %{
            at: delivery.updated_at,
            event: :suppressed,
            detail: %{reason: delivery.suppression_reason}
          }
        ]
      else
        []
      end

    attempt_entries =
      Enum.map(attempts, fn attempt ->
        %{at: attempt.inserted_at, event: :attempt_recorded, detail: %{outcome: attempt.outcome}}
      end)

    (base ++ suppression_entries ++ attempt_entries)
    |> Enum.sort_by(& &1.at, DateTime)
  end
end
