defmodule Chimeway.Notifier do
  @moduledoc """
  Behaviour contract for notification definitions.

  ## Delayed fallback channels

  `delayed_fallback_channels/2` lets notifiers mark outbound channels as delayed
  fallback candidates. Returned channels must be a subset of `channels/2` output
  and must never include `:in_app`.
  """

  defmacro __using__(_opts) do
    quote do
      @behaviour Chimeway.Notifier
    end
  end

  @callback notification_key() :: String.t()
  @callback version() :: pos_integer()
  @callback recipients(map()) :: {:ok, [map()]} | {:error, term()}
  @callback build(map(), map()) :: {:ok, map()} | {:error, term()}
  @callback channels(map(), map()) :: {:ok, [atom() | String.t()]} | {:error, term()}
  @callback delayed_fallback_channels(map(), map()) ::
              {:ok, [atom() | String.t()]} | {:error, term()}
  @callback orchestration(map(), map()) ::
              {:ok, :immediate | :digest | :digest_held | keyword(atom()) | map()} | {:error, term()}

  @optional_callbacks channels: 2
  @optional_callbacks delayed_fallback_channels: 2
  @optional_callbacks orchestration: 2

  @spec validate_module!(module()) :: :ok | {:error, term()}
  def validate_module!(module) when is_atom(module) do
    cond do
      not Code.ensure_loaded?(module) ->
        {:error, :notifier_not_loaded}

      not function_exported?(module, :notification_key, 0) ->
        {:error, :missing_notification_key_callback}

      not function_exported?(module, :version, 0) ->
        {:error, :missing_version_callback}

      not function_exported?(module, :recipients, 1) ->
        {:error, :missing_recipients_callback}

      not function_exported?(module, :build, 2) ->
        {:error, :missing_build_callback}

      true ->
        :ok
    end
  end

  def validate_module!(_module), do: {:error, :invalid_notifier_module}

  @type orchestration_mode :: :immediate | :digest_held
  @type orchestration_resolution :: %{
          default: orchestration_mode(),
          channels: %{String.t() => orchestration_mode()}
        }

  @spec resolve_orchestration(module() | nil, map(), map(), term()) ::
          {:ok, orchestration_resolution()} | {:error, term()}
  def resolve_orchestration(notifier, trigger_params, recipient, override \\ :unset)

  def resolve_orchestration(_notifier, _trigger_params, _recipient, override) when override != :unset do
    normalize_orchestration(override)
  end

  def resolve_orchestration(nil, _trigger_params, _recipient, _override) do
    {:ok, %{default: :immediate, channels: %{}}}
  end

  def resolve_orchestration(notifier, trigger_params, recipient, _override) when is_atom(notifier) do
    if function_exported?(notifier, :orchestration, 2) do
      notifier
      |> apply(:orchestration, [trigger_params, recipient])
      |> handle_orchestration_result()
    else
      {:ok, %{default: :immediate, channels: %{}}}
    end
  end

  defp handle_orchestration_result({:ok, declaration}), do: normalize_orchestration(declaration)
  defp handle_orchestration_result({:error, reason}), do: {:error, {:orchestration_resolution_failed, reason}}

  defp handle_orchestration_result(unexpected),
    do: {:error, {:orchestration_resolution_failed, {:unexpected_result, unexpected}}}

  defp normalize_orchestration(:immediate), do: {:ok, %{default: :immediate, channels: %{}}}
  defp normalize_orchestration(:digest), do: {:ok, %{default: :digest_held, channels: %{}}}
  defp normalize_orchestration(:digest_held), do: {:ok, %{default: :digest_held, channels: %{}}}

  defp normalize_orchestration(declaration) when is_list(declaration) do
    declaration
    |> Enum.into(%{})
    |> normalize_orchestration()
  end

  defp normalize_orchestration(%{} = declaration) do
    {default, channel_entries} =
      case Map.pop(declaration, :default) do
        {nil, rest} -> Map.pop(rest, "default", :immediate)
        result -> result
      end

    with {:ok, normalized_default} <- normalize_mode(default),
         {:ok, normalized_channels} <- normalize_channel_modes(channel_entries) do
      {:ok, %{default: normalized_default, channels: normalized_channels}}
    end
  end

  defp normalize_orchestration(other), do: {:error, {:invalid_orchestration_declaration, other}}

  defp normalize_channel_modes(entries) do
    Enum.reduce_while(entries, {:ok, %{}}, fn {channel, mode}, {:ok, acc} ->
      with {:ok, normalized_channel} <- normalize_channel(channel),
           {:ok, normalized_mode} <- normalize_mode(mode) do
        {:cont, {:ok, Map.put(acc, normalized_channel, normalized_mode)}}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp normalize_channel(channel) when is_atom(channel), do: {:ok, Atom.to_string(channel)}

  defp normalize_channel(channel) when is_binary(channel) do
    normalized_channel = String.trim(channel)

    if normalized_channel == "" do
      {:error, {:invalid_orchestration_channel, channel}}
    else
      {:ok, normalized_channel}
    end
  end

  defp normalize_channel(channel), do: {:error, {:invalid_orchestration_channel, channel}}

  defp normalize_mode(:immediate), do: {:ok, :immediate}
  defp normalize_mode(:digest), do: {:ok, :digest_held}
  defp normalize_mode(:digest_held), do: {:ok, :digest_held}
  defp normalize_mode("immediate"), do: {:ok, :immediate}
  defp normalize_mode("digest"), do: {:ok, :digest_held}
  defp normalize_mode("digest_held"), do: {:ok, :digest_held}
  defp normalize_mode(mode), do: {:error, {:invalid_orchestration_mode, mode}}
end
