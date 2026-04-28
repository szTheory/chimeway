defmodule Chimeway.Policy do
  @moduledoc """
  Dual-checkpoint policy engine for delivery suppression decisions.

  Call `evaluate/2` at two points in the dispatch pipeline:

  1. **Planning time** (before dispatch): pass `opts: []` — checks channel preference only.
  2. **Perform time** (inside dispatcher, after delivery loaded): pass `check_read_state: delivery.delay_fallback`.

  Returns:
  - `{:ok, :proceed}` — delivery should proceed to the adapter.
  - `{:suppress, reason_atom}` — delivery should be suppressed. `reason_atom` is a plain atom
    (`:channel_disabled`, `:already_read`). Persist as `Atom.to_string(reason_atom)` on the delivery row.

  ## Policy extensibility

  A `policy_module` config key is reserved for custom host-app policy (quiet hours, rate limits):

      config :chimeway, :policy_module, MyApp.NotificationPolicy

  This hook is not dispatched to in Phase 3 — it is the documented extension point for future phases.
  Custom policy is additive; Chimeway's built-in preference and read-state checks always run first.
  """

  require Logger

  alias Chimeway.Delivery
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification
  alias Chimeway.Policy.Settings
  alias Chimeway.{Preferences, Repo}
  alias Chimeway.Telemetry

  @doc """
  Evaluates delivery policy and returns a proceed or suppress decision.

  Options:
  - `check_read_state:` (boolean, default false) — when true, checks if the associated
    in-app notification has been read (read_at is not nil). Used for delayed fallback paths.
  """
  @spec evaluate(Chimeway.Delivery.t(), keyword()) ::
          {:ok, :proceed} | {:suppress, atom()} | {:defer, map()}
  def evaluate(%Delivery{} = delivery, opts \\ []) do
    Telemetry.span(
      [:policy, :evaluate],
      Telemetry.safe_meta(%{
        delivery_id: delivery.id,
        channel: delivery.channel,
        notification_key: Map.get(delivery.metadata || %{}, "notification_key"),
        category: delivery_category(delivery)
      }),
      fn ->
        check_read_state = Keyword.get(opts, :check_read_state, false)

        result = evaluate_delivery_policy(delivery, check_read_state, opts)

        extra =
          case result do
            {:suppress, reason} ->
              Telemetry.safe_meta(%{suppression_reason: Atom.to_string(reason)})

            {:defer, decision} ->
              Telemetry.safe_meta(%{planning_reason: Map.get(decision, :planning_reason)})

            _ ->
              %{}
          end

        {result, extra}
      end
    )
  end

  @spec delivery_category(Delivery.t()) :: String.t() | nil
  def delivery_category(%Delivery{} = delivery) do
    notification = Repo.get!(Notification, delivery.notification_id)
    event = Repo.get!(Event, notification.event_id)
    delivery_category_from_event(event)
  end

  # --- Private ---

  defp evaluate_delivery_policy(%Delivery{} = delivery, check_read_state, opts) do
    context = load_policy_context(delivery)

    with :ok <- check_channel_preferences(delivery, context),
         :ok <- check_category_preferences(delivery, context) do
      case check_policy_settings(delivery, opts_with_checkpoint(check_read_state, opts)) do
        :ok -> maybe_check_read_state(delivery, check_read_state)
        {:defer, _decision} = deferred -> deferred
        {:suppress, _reason} = suppressed -> suppressed
      end
    end
  end

  defp load_policy_context(%Delivery{} = delivery) do
    notification = Repo.get!(Notification, delivery.notification_id)
    event = Repo.get!(Event, notification.event_id)

    %{
      notification: notification,
      event: event,
      recipient_id: notification.recipient_identity,
      category: delivery_category_from_event(event)
    }
  end

  defp check_channel_preferences(%Delivery{} = delivery, %{
         event: event,
         recipient_id: recipient_id
       }) do
    if Preferences.channel_enabled?(recipient_id, event.notification_key, delivery.channel) do
      :ok
    else
      Logger.debug("[chimeway] suppressing delivery",
        delivery_id: delivery.id,
        reason: :channel_disabled,
        channel: delivery.channel
      )

      {:suppress, :channel_disabled}
    end
  end

  defp check_category_preferences(_delivery, %{category: nil}), do: :ok

  defp check_category_preferences(%Delivery{} = delivery, %{
         recipient_id: recipient_id,
         category: category
       }) do
    if Preferences.category_enabled?(recipient_id, category) do
      :ok
    else
      Logger.debug("[chimeway] suppressing delivery category=#{category}",
        delivery_id: delivery.id,
        reason: :category_disabled
      )

      {:suppress, :category_disabled}
    end
  end

  defp check_policy_settings(%Delivery{} = delivery, opts) do
    case Settings.evaluate(delivery, opts) do
      {:ok, :proceed} ->
        :ok

      {:defer, decision} ->
        {:defer, decision}

      {:suppress, reason} ->
        Logger.debug("[chimeway] suppressing delivery (policy settings)",
          delivery_id: delivery.id,
          reason: reason
        )

        {:suppress, reason}
    end
  end

  defp maybe_check_read_state(_delivery, false), do: {:ok, :proceed}

  defp maybe_check_read_state(%Delivery{notification_id: notification_id} = delivery, true) do
    case Repo.get(Notification, notification_id) do
      nil ->
        {:ok, :proceed}

      %{read_at: nil} ->
        {:ok, :proceed}

      %{read_at: _read_at} ->
        Logger.debug("[chimeway] suppressing delivery (read fallback)",
          delivery_id: delivery.id,
          reason: :already_read
        )

        {:suppress, :already_read}
    end
  end

  defp delivery_category_from_event(%Event{payload: payload}) when is_map(payload) do
    case Map.get(payload, "category") do
      category when is_binary(category) and category != "" -> category
      _ -> nil
    end
  end

  defp delivery_category_from_event(_event), do: nil

  defp opts_with_checkpoint(check_read_state, opts) do
    checkpoint =
      if Keyword.has_key?(opts, :checkpoint) do
        Keyword.fetch!(opts, :checkpoint)
      else
        if check_read_state, do: :perform, else: :planning
      end

    Keyword.put(opts, :checkpoint, checkpoint)
  end
end
