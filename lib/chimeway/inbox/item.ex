defmodule Chimeway.Inbox.Item do
  @moduledoc """
  Serializable inbox item maps for UI consumption.
  """

  alias Chimeway.Notifications.Notification

  @preview_max_graphemes 120

  @spec to_map(Notification.t()) :: map()
  def to_map(%Notification{} = notification) do
    metadata = notification.metadata || %{}

    %{
      "id" => to_string(notification.id),
      "title" => title_from(metadata),
      "body_preview" => body_preview_from(metadata),
      "inserted_at" => datetime_to_iso8601(notification.inserted_at),
      "read_at" => datetime_to_iso8601(notification.read_at),
      "seen_at" => datetime_to_iso8601(notification.seen_at)
    }
  end

  defp title_from(metadata) do
    metadata["subject"] || metadata["title"] || ""
  end

  defp body_preview_from(metadata) do
    metadata
    |> preview_text()
    |> case do
      nil -> ""
      text -> String.slice(text, 0, @preview_max_graphemes)
    end
  end

  defp preview_text(metadata) do
    metadata["body_preview"] || metadata["preview"] || metadata["body"]
  end

  defp datetime_to_iso8601(nil), do: nil
  defp datetime_to_iso8601(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
end
