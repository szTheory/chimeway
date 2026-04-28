defmodule Chimeway.Orchestration.WindowMath do
  @moduledoc """
  Pure time-window calculations for recipient-local orchestration decisions.
  """

  @type option ::
          {:time_zone, String.t()}
          | {:quiet_hours_start_minute, non_neg_integer()}
          | {:quiet_hours_end_minute, non_neg_integer()}

  @spec next_eligible_at(DateTime.t(), [option()]) :: {:ok, DateTime.t()} | {:error, term()}
  def next_eligible_at(%DateTime{} = evaluation_time, opts) when is_list(opts) do
    with {:ok, time_zone} <- fetch_string_option(opts, :time_zone),
         {:ok, start_minute} <- fetch_minute_option(opts, :quiet_hours_start_minute),
         {:ok, end_minute} <- fetch_minute_option(opts, :quiet_hours_end_minute),
         {:ok, local_time} <-
           DateTime.shift_zone(evaluation_time, time_zone, time_zone_database()) do
      if quiet_hours_now?(minute_of_day(local_time), start_minute, end_minute) do
        local_time
        |> next_eligible_date(start_minute, end_minute)
        |> local_end_of_quiet_hours(end_minute, time_zone)
      else
        shift_to_utc(evaluation_time)
      end
    end
  end

  defp fetch_string_option(opts, key) do
    case Keyword.fetch(opts, key) do
      {:ok, value} when is_binary(value) and byte_size(value) > 0 -> {:ok, value}
      {:ok, value} -> {:error, {:invalid_option, key, value}}
      :error -> {:error, {:missing_option, key}}
    end
  end

  defp fetch_minute_option(opts, key) do
    case Keyword.fetch(opts, key) do
      {:ok, value} when is_integer(value) and value >= 0 and value < 1440 -> {:ok, value}
      {:ok, value} -> {:error, {:invalid_option, key, value}}
      :error -> {:error, {:missing_option, key}}
    end
  end

  defp minute_of_day(%DateTime{hour: hour, minute: minute}), do: hour * 60 + minute

  defp quiet_hours_now?(minute_of_day, start_minute, end_minute)
       when start_minute <= end_minute do
    minute_of_day >= start_minute and minute_of_day <= end_minute
  end

  defp quiet_hours_now?(minute_of_day, start_minute, end_minute) do
    minute_of_day >= start_minute or minute_of_day <= end_minute
  end

  defp next_eligible_date(local_time, start_minute, end_minute) when start_minute <= end_minute do
    local_time.year
    |> Date.new!(local_time.month, local_time.day)
  end

  defp next_eligible_date(local_time, start_minute, end_minute) do
    date = Date.new!(local_time.year, local_time.month, local_time.day)

    if minute_of_day(local_time) >= start_minute and minute_of_day(local_time) > end_minute do
      Date.add(date, 1)
    else
      date
    end
  end

  defp local_end_of_quiet_hours(date, end_minute, time_zone) do
    hour = div(end_minute, 60)
    minute = rem(end_minute, 60)
    naive_datetime = NaiveDateTime.new!(date, Time.new!(hour, minute, 0))

    case DateTime.from_naive(naive_datetime, time_zone, time_zone_database()) do
      {:ok, local_datetime} ->
        shift_to_utc(local_datetime)

      {:ambiguous, _first, second} ->
        shift_to_utc(second)

      {:gap, _before, first_after_gap} ->
        shift_to_utc(first_after_gap)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp shift_to_utc(%DateTime{} = datetime) do
    DateTime.shift_zone(datetime, "Etc/UTC", time_zone_database())
  end

  defp time_zone_database, do: Calendar.get_time_zone_database()
end
