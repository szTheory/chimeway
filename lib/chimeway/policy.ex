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
  alias Chimeway.{Preferences, Repo}
  alias Chimeway.Telemetry

  @doc """
  Evaluates delivery policy and returns a proceed or suppress decision.

  Options:
  - `check_read_state:` (boolean, default false) — when true, checks if the associated
    in-app notification has been read (read_at is not nil). Used for delayed fallback paths.
  """
  @spec evaluate(Chimeway.Delivery.t(), keyword()) :: {:ok, :proceed} | {:suppress, atom()}
  def evaluate(%Delivery{} = delivery, opts \\ []) do
    Telemetry.span(
      [:policy, :evaluate],
      Telemetry.safe_meta(%{
        delivery_id: delivery.id,
        channel: delivery.channel,
        notification_key: Map.get(delivery.metadata || %{}, "notification_key")
      }),
      fn ->
        check_read_state = Keyword.get(opts, :check_read_state, false)

        result =
          with {:ok, :proceed} <- check_preferences(delivery) do
            maybe_check_read_state(delivery, check_read_state)
          end

        extra =
          case result do
            {:suppress, reason} ->
              Telemetry.safe_meta(%{suppression_reason: Atom.to_string(reason)})

            _ ->
              %{}
          end

        {result, extra}
      end
    )
  end

  # --- Private ---

  defp check_preferences(%Delivery{} = delivery) do
    notification = Repo.get!(Notification, delivery.notification_id)
    event = Repo.get!(Event, notification.event_id)

    if Preferences.channel_enabled?(
         notification.recipient_identity,
         event.notification_key,
         delivery.channel
       ) do
      {:ok, :proceed}
    else
      Logger.debug("[chimeway] suppressing delivery",
        delivery_id: delivery.id,
        reason: :channel_disabled,
        channel: delivery.channel
      )

      {:suppress, :channel_disabled}
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
end
