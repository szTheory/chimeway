defmodule Chimeway.Rendering.Channels.Sms do
  @moduledoc """
  Validates the durable SMS render contract.

  Only the message body is a render concern. Sender ID, Messaging Service SID,
  and recipient phone number are adapter-config territory — never in render_data.

  GSM-7 encoding supports up to 160 characters per segment; UCS-2 (unicode) supports
  up to 70 characters per segment. Multi-segment messages are billed per segment.
  Segmentation and encoding are vendor concerns handled in the adapter, not validated here.
  """

  use Chimeway.Rendering.Channel

  import Ecto.Changeset

  @types %{
    text_body: :string
  }

  @required_fields [:text_body]

  @impl Chimeway.Rendering.Channel
  @spec validate(map()) :: {:ok, map()} | {:error, Ecto.Changeset.t()}
  def validate(attrs) when is_map(attrs) do
    {%{}, @types}
    |> cast(attrs, Map.keys(@types))
    |> validate_required(@required_fields)
    |> apply_action(:insert)
    |> case do
      {:ok, validated} -> {:ok, stringify_keys(validated)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def validate(other) do
    types = %{payload: :map}

    {%{}, types}
    |> cast(%{payload: other}, [:payload])
    |> add_error(:payload, "must be a map")
    |> apply_action(:insert)
  end

  defp stringify_keys(map) do
    Enum.into(map, %{}, fn {key, value} ->
      {Atom.to_string(key), value}
    end)
  end
end
