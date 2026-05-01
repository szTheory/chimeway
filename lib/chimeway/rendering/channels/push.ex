defmodule Chimeway.Rendering.Channels.Push do
  @moduledoc """
  Validates the durable push render contract.

  Only content fields are render concerns. APNs/FCM platform plumbing (apns_topic,
  priority, collapse_id, expiration, push_type, device_token) belongs in the adapter,
  not in render_data. Use the opaque `data` map for app-specific custom payloads.
  """

  use Chimeway.Rendering.Channel

  import Ecto.Changeset

  @types %{
    title: :string,
    body: :string,
    data: :map
  }

  @required_fields [:title, :body]

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
