defmodule Chimeway.Policy.Settings do
  @moduledoc "Per-recipient policy settings for quiet hours and delivery caps."

  import Ecto.Query, only: [from: 2]

  alias Chimeway.{Delivery, Notifications.Notification, Repo}
  alias Chimeway.Orchestration.WindowMath
  alias Chimeway.Policy.Settings.Setting

  @doc """
  Upserts policy settings for one recipient.
  """
  @spec upsert_settings(map()) :: {:ok, Setting.t()} | {:error, Ecto.Changeset.t()}
  def upsert_settings(attrs) do
    %Setting{}
    |> Setting.changeset(attrs)
    |> Repo.insert(
      on_conflict:
        {:replace,
         [
           :quiet_hours_start_minute,
           :quiet_hours_end_minute,
           :delivery_cap_count,
           :delivery_cap_window_minutes,
           :time_zone,
           :updated_at
         ]},
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
  @spec evaluate(Delivery.t()) :: {:ok, :proceed} | {:suppress, atom()} | {:defer, map()}
  @spec evaluate(Delivery.t(), keyword()) :: {:ok, :proceed} | {:suppress, atom()} | {:defer, map()}
  def evaluate(%Delivery{} = delivery, opts \\ []) do
    with recipient_id when not is_nil(recipient_id) <- recipient_identity_for(delivery),
         %Setting{} = settings <- get_settings(recipient_id),
         :ok <- maybe_suppress_delivery_cap(delivery, settings, recipient_id, opts),
         :ok <- maybe_defer_quiet_hours(delivery, settings, opts) do
      {:ok, :proceed}
    else
      nil -> {:ok, :proceed}
      {:defer, _decision} = deferred -> deferred
      {:suppress, reason} -> {:suppress, reason}
    end
  end

  defp maybe_suppress_delivery_cap(%Delivery{} = delivery, %Setting{} = settings, recipient_id, opts) do
    case {settings.delivery_cap_count, settings.delivery_cap_window_minutes} do
      {nil, nil} ->
        :ok

      {cap_count, window_minutes} ->
        cutoff = DateTime.add(evaluation_time(opts), -window_minutes * 60, :second)

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

  defp maybe_defer_quiet_hours(%Delivery{orchestration_state: :digest_held}, _settings, _opts), do: :ok

  defp maybe_defer_quiet_hours(%Delivery{} = delivery, %Setting{} = settings, opts) do
    if checkpoint(opts) == :perform do
      :ok
    else
      case {settings.quiet_hours_start_minute, settings.quiet_hours_end_minute} do
        {nil, nil} ->
          :ok

        {start_minute, end_minute} ->
          build_quiet_hours_decision(delivery, settings, start_minute, end_minute, opts)
      end
    end
  end

  defp build_quiet_hours_decision(_delivery, %Setting{} = settings, start_minute, end_minute, opts) do
    current_time = evaluation_time(opts)
    time_zone = settings.time_zone || "Etc/UTC"

    with {:ok, next_eligible_at} <-
           WindowMath.next_eligible_at(current_time,
             time_zone: time_zone,
             quiet_hours_start_minute: start_minute,
             quiet_hours_end_minute: end_minute
           ) do
      normalized_next_eligible_at = DateTime.truncate(next_eligible_at, :microsecond)

      if DateTime.compare(normalized_next_eligible_at, current_time) == :gt do
        {:defer,
         %{
           orchestration_state: :deferred,
           planning_reason: "quiet_hours",
           planning_context: %{
             "rule" => "quiet_hours",
             "time_zone" => time_zone,
             "quiet_hours_start_minute" => start_minute,
             "quiet_hours_end_minute" => end_minute
           },
           next_eligible_at: normalized_next_eligible_at
         }}
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

  defp checkpoint(opts) do
    cond do
      Keyword.get(opts, :checkpoint) in [:planning, :perform] ->
        Keyword.fetch!(opts, :checkpoint)

      Keyword.has_key?(opts, :check_read_state) ->
        :perform

      true ->
        :planning
    end
  end

  defp evaluation_time(opts) do
    case Keyword.get(opts, :evaluation_time, DateTime.utc_now()) do
      %DateTime{} = datetime -> DateTime.truncate(datetime, :second)
      _ -> DateTime.utc_now() |> DateTime.truncate(:second)
    end
  end
end
