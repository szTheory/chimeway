defmodule Chimeway.Privacy do
  @moduledoc """
  Atom-safe recursive removal of privacy-sensitive keys from untrusted terms.

  This module intentionally preserves allowed keys in their original form. It
  only normalizes a temporary comparison string and never creates atoms from
  caller-controlled input.
  """

  @forbidden_keys MapSet.new(~w(
    authorization auth credential credentials password secret api_key access_token
    token device_token endpoint recipient recipient_id adopter adopter_id identity
    email phone url uri link deep_link trusted_link payload content body rendered_body
    rendered_content provider_body provider_response
  ))

  @spec redact(term()) :: term()
  def redact(value) when is_struct(value), do: value

  def redact(value) when is_map(value) do
    Enum.reduce(value, %{}, fn {key, child}, acc ->
      if forbidden_key?(key), do: acc, else: Map.put(acc, key, redact(child))
    end)
  end

  def redact(value) when is_list(value) do
    if Keyword.keyword?(value) do
      Enum.reduce(value, [], fn {key, child}, acc ->
        if forbidden_key?(key), do: acc, else: [{key, redact(child)} | acc]
      end)
      |> Enum.reverse()
    else
      Enum.map(value, &redact/1)
    end
  end

  def redact(value), do: value

  @spec forbidden_key?(term()) :: boolean()
  def forbidden_key?(key) when is_atom(key), do: key |> Atom.to_string() |> forbidden_key?()

  def forbidden_key?(key) when is_binary(key),
    do: MapSet.member?(@forbidden_keys, String.downcase(key))

  def forbidden_key?(_key), do: false
end
