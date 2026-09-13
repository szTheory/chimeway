defmodule Chimeway.APNS.Payload do
  @moduledoc "Closed APNs alert payload encoder."

  alias Chimeway.APNS.OpaqueReference
  alias Chimeway.Privacy

  @max_bytes 4096
  @open_ref_key "chimeway_open_ref"

  @enforce_keys [:json, :encoded, :bytes]
  defstruct [:json, :encoded, :bytes]

  @type t :: %__MODULE__{json: map(), encoded: binary(), bytes: non_neg_integer()}

  @spec build(map(), String.t()) :: {:ok, t()} | {:error, :invalid_payload | :payload_too_large}
  def build(render_data, open_ref) when is_map(render_data) and is_binary(open_ref) do
    title = Map.get(render_data, :title) || Map.get(render_data, "title")
    body = Map.get(render_data, :body) || Map.get(render_data, "body")

    with true <- valid_render?(render_data, title, body),
         true <- OpaqueReference.valid?(open_ref) do
      json = %{
        "aps" => %{"alert" => %{"title" => title, "body" => body}},
        @open_ref_key => open_ref
      }

      encoded = Jason.encode!(json)

      if byte_size(encoded) <= @max_bytes do
        {:ok, %__MODULE__{json: json, encoded: encoded, bytes: byte_size(encoded)}}
      else
        {:error, :payload_too_large}
      end
    else
      _ -> {:error, :invalid_payload}
    end
  end

  def build(_, _), do: {:error, :invalid_payload}

  defp valid_render?(render_data, title, body) do
    data = Map.get(render_data, :data) || Map.get(render_data, "data", %{})

    (data == %{} or (is_map(data) and Privacy.redact(data) == data)) and is_binary(title) and
      is_binary(body) and not unsafe_string?(title) and not unsafe_string?(body)
  end

  defp unsafe_string?(value),
    do: String.contains?(String.downcase(value), ["token", "credential", "password", "secret"])
end
