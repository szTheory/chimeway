defmodule Chimeway.Rendering.Channels.InApp do
  @moduledoc """
  Validates the durable in-app render contract.
  """

  import Ecto.Changeset

  @types %{
    headline: :string,
    body: :string,
    primary_action: :map
  }

  @required_fields [:headline, :body, :primary_action]

  @spec validate(map()) :: {:ok, map()} | {:error, Ecto.Changeset.t()}
  def validate(attrs) when is_map(attrs) do
    {%{}, @types}
    |> cast(attrs, Map.keys(@types))
    |> validate_required(@required_fields)
    |> validate_primary_action()
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

  defp validate_primary_action(changeset) do
    case get_field(changeset, :primary_action) do
      %{} = action ->
        action
        |> validate_action_map()
        |> case do
          {:ok, normalized_action} -> put_change(changeset, :primary_action, normalized_action)
          {:error, reason} -> add_error(changeset, :primary_action, reason)
        end

      _ ->
        changeset
    end
  end

  defp validate_action_map(action) do
    types = %{label: :string, url: :string}

    {%{}, types}
    |> cast(action, [:label, :url])
    |> validate_required([:label, :url])
    |> apply_action(:insert)
    |> case do
      {:ok, validated} -> {:ok, stringify_keys(validated)}
      {:error, _changeset} -> {:error, "must include label and url"}
    end
  end

  defp stringify_keys(map) do
    Enum.into(map, %{}, fn {key, value} ->
      {Atom.to_string(key), value}
    end)
  end
end
