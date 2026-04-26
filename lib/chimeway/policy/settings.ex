defmodule Chimeway.Policy.Settings do
  @moduledoc "Per-recipient policy settings for quiet hours and delivery caps."

  import Ecto.Query, only: [from: 2]

  alias Chimeway.{Delivery, Notifications.Notification, Repo}
  alias Chimeway.Policy.Settings.Setting

  @doc """
  Upserts policy settings for one recipient.
  """
  @spec upsert_settings(map()) :: {:ok, Setting.t()} | {:error, Ecto.Changeset.t()}
  def upsert_settings(attrs) do
    %Setting{}
    |> Setting.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:quiet_hours_start_minute, :quiet_hours_end_minute, :delivery_cap_count, :delivery_cap_window_minutes, :updated_at]},
      conflict_target: [:recipient_id]
    )
  end

  @doc """
  Fetches the policy settings row for a recipient, or nil.
  """
  @spec get_settings(String.t()) :: Setting.t() | nil
  def get_settings(recipient_id) do
    Repo.get_by(Setting, recipient_id: recipient_id)
  end

  @doc """
  Evaluates quiet-hours and delivery-cap suppression for a delivery.
  """
  @spec evaluate(Delivery.t()) :: {:ok, :proceed} | {:suppress, atom()}
  def evaluate(%Delivery{} = delivery) do
    case recipient_identity_for(delivery) do
      nil ->
        {:ok, :proceed}

      recipient_id ->
        case get_settings(recipient_id) do
          nil ->
            {:ok, :proceed}

          %Setting{} = settings ->
            with :ok <- maybe_suppress_quiet_hours(settings),
                 :ok <- maybe_suppress_delivery_cap(delivery, settings, recipient_id) do
              {:ok, :proceed}
            end
        end
    end
  end

  defp maybe_suppress_quiet_hours(%Setting{} = settings) do
    case {settings.quiet_hours_start_minute, settings.quiet_hours_end_minute} do
      {nil, nil} ->
        :ok

      {start_minute, end_minute} ->
        now_minute = DateTime.utc_now().hour * 60 + DateTime.utc_now().minute

        if quiet_hours_now?(now_minute, start_minute, end_minute) do
          {:suppress, :quiet_hours}
        else
          :ok
        end
    end
  end

  defp maybe_suppress_delivery_cap(%Delivery{} = delivery, %Setting{} = settings, recipient_id) do
    case {settings.delivery_cap_count, settings.delivery_cap_window_minutes} do
      {nil, nil} ->
        :ok

      {cap_count, window_minutes} ->
        cutoff = DateTime.add(DateTime.utc_now(), -window_minutes * 60, :second)

        recent_count =
          from(d in Delivery,
            join: n in assoc(d, :notification),
            where:
              n.recipient_identity == ^recipient_id and
                d.inserted_at >= ^cutoff and
                d.id != ^delivery.id,
            select: count(d.id)
          )
          |> Repo.one()

        if recent_count >= cap_count do
          {:suppress, :delivery_cap_reached}
        else
          :ok
        end
    end
  end

  defp recipient_identity_for(%Delivery{notification_id: notification_id}) do
    case Repo.get(Notification, notification_id) do
      nil -> nil
      %Notification{recipient_identity: recipient_identity} -> recipient_identity
    end
  end

  defp quiet_hours_now?(minute_of_day, start_minute, end_minute)
       when is_integer(minute_of_day) and is_integer(start_minute) and is_integer(end_minute) do
    if start_minute <= end_minute do
      minute_of_day >= start_minute and minute_of_day <= end_minute
    else
      minute_of_day >= start_minute or minute_of_day <= end_minute
    end
  end

  defp quiet_hours_now?(_, _, _), do: false
end
