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

  Returns `[]` when no events match — never returns an error tuple since
  correlation IDs are user-supplied and may not be unique or present.
  """
  @spec find_traces_by_correlation_id(String.t(), keyword()) :: [Event.t()]
  def find_traces_by_correlation_id(correlation_id, opts \\ []) do
    events =
      Repo.all(from(e in Event, where: e.correlation_id == ^correlation_id), opts)

    Repo.preload(events, [notifications: [deliveries: :attempts]], opts)
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
        timeline = build_timeline(event, notification, delivery, attempts)

        explanation = %Explanation{
          delivery_id: delivery.id,
          event_id: event.id,
          correlation_id: event.correlation_id,
          notification_key: event.notification_key,
          recipient_id: notification.recipient_identity,
          channel: delivery.channel,
          status: delivery.status,
          planning_reason: delivery.planning_reason,
          planning_context: explanation_planning_context(delivery),
          next_eligible_at: delivery.next_eligible_at,
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
      error_class: attempt.error_class
    }
  end

  defp build_timeline(event, notification, delivery, attempts) do
    planning_context = explanation_planning_context(delivery)

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
      if delivery.orchestration_state == :deferred and delivery.planning_reason do
        [
          %{
            at: delivery.updated_at,
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
            error_class: attempt.error_class
          }
        }
      end)

    (base ++ deferred_entries ++ suppression_entries ++ cancellation_entries ++ attempt_entries)
    |> Enum.sort_by(& &1.at, DateTime)
  end

  defp explanation_planning_context(%Delivery{} = delivery) do
    delivery
    |> safe_planning_context()
    |> maybe_put_rule_identity(delivery)
  end

  defp safe_planning_context(%Delivery{planning_context: nil}), do: nil

  defp safe_planning_context(%Delivery{planning_context: planning_context}) when is_map(planning_context) do
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

  defp normalized_rule_identity(%Delivery{planning_context: planning_context, planning_reason: planning_reason}) do
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
end
