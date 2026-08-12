defmodule Chimeway.Privacy do
  @moduledoc """
  Atom-safe recursive removal of privacy-sensitive keys from untrusted terms.

  This module intentionally preserves allowed keys in their original form. It
  only normalizes a temporary comparison string and never creates atoms from
  caller-controlled input.
  """

  @forbidden_keys MapSet.new(~w(
    authorization auth credential credentials password secret apikey accesstoken
    token devicetoken endpoint recipient recipientid adopter adopterid identity
    email phone url uri link deeplink trustedlink payload content body renderedbody
    renderedcontent providerbody providerresponse
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
    do: MapSet.member?(@forbidden_keys, canonical_key(key))

  def forbidden_key?(_key), do: false

  defp canonical_key(key), do: key |> String.downcase() |> String.replace(~r/[_\-\s]/, "")
end
