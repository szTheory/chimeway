defmodule Chimeway.Rendering.Channels.Chat do
  @moduledoc """
  Validates the durable chat render contract.

  This is the discoverable starter validator for generic chat. Host apps with
  vendor-specific shapes (Slack-only, Discord-only, in-house chat) should define
  their own validators via the :channel_render_modules registry without modifying this module.
  """

  use Chimeway.Rendering.Channel

  import Ecto.Changeset

  @types %{
    text: :string,
    rich_payload: :map
  }

  @required_fields [:text]

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
