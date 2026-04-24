defmodule Chimeway.Dispatch.ChannelAdapterConfig do
  @moduledoc """
  Resolves per-channel adapter config without creating atoms from runtime channel data.
  """

  @spec resolve(String.t(), keyword()) :: keyword()
  def resolve(channel, default) when is_binary(channel) and is_list(default) do
    case preferred_config(channel) do
      config when is_list(config) ->
        config

      _ ->
        legacy_fallback_config(channel, default)
    end
  end

  defp preferred_config(channel) do
    case Application.get_env(:chimeway, :channel_adapter_configs, %{}) do
      configs when is_map(configs) -> Map.get(configs, channel)
      _ -> nil
    end
  end

  defp legacy_fallback_config(channel, default) do
    legacy_key = "adapter_" <> channel

    Application.get_all_env(:chimeway)
    |> Enum.find_value(default, fn
      {key, value} when is_atom(key) and is_list(value) ->
        if Atom.to_string(key) == legacy_key, do: value

      _ ->
        nil
    end)
  end
end
