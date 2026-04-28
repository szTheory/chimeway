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
              {:ok, :immediate | :digest | :digest_held | keyword(atom()) | map()}
              | {:error, term()}

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
          channels: %{String.t() => orchestration_mode()},
          default_digest_key: String.t() | nil,
          digest_keys: %{String.t() => String.t()},
          source: :default | :notifier | :planner_override
        }

  @spec resolve_orchestration(module() | nil, map(), map(), term()) ::
          {:ok, orchestration_resolution()} | {:error, term()}
  def resolve_orchestration(notifier, trigger_params, recipient, override \\ :unset)

  def resolve_orchestration(_notifier, _trigger_params, _recipient, override)
      when override != :unset do
    normalize_orchestration(override, :planner_override)
  end

  def resolve_orchestration(nil, _trigger_params, _recipient, _override) do
    {:ok,
     %{
       default: :immediate,
       channels: %{},
       default_digest_key: nil,
       digest_keys: %{},
       source: :default
     }}
  end

  def resolve_orchestration(notifier, trigger_params, recipient, _override)
      when is_atom(notifier) do
    if function_exported?(notifier, :orchestration, 2) do
      notifier
      |> apply(:orchestration, [trigger_params, recipient])
      |> handle_orchestration_result(:notifier)
    else
      {:ok,
       %{
         default: :immediate,
         channels: %{},
         default_digest_key: nil,
         digest_keys: %{},
         source: :default
       }}
    end
  end

  defp handle_orchestration_result({:ok, declaration}, source),
    do: normalize_orchestration(declaration, source)

  defp handle_orchestration_result({:error, reason}, _source),
    do: {:error, {:orchestration_resolution_failed, reason}}

  defp handle_orchestration_result(unexpected, _source),
    do: {:error, {:orchestration_resolution_failed, {:unexpected_result, unexpected}}}

  defp normalize_orchestration(:immediate, source),
    do:
      {:ok,
       %{
         default: :immediate,
         channels: %{},
         default_digest_key: nil,
         digest_keys: %{},
         source: source
       }}

  defp normalize_orchestration(:digest, source),
    do:
      {:ok,
       %{
         default: :digest_held,
         channels: %{},
         default_digest_key: nil,
         digest_keys: %{},
         source: source
       }}

  defp normalize_orchestration(:digest_held, source),
    do:
      {:ok,
       %{
         default: :digest_held,
         channels: %{},
         default_digest_key: nil,
         digest_keys: %{},
         source: source
       }}

  defp normalize_orchestration(declaration, source) when is_list(declaration) do
    declaration
    |> Enum.into(%{})
    |> normalize_orchestration(source)
  end

  defp normalize_orchestration(%{} = declaration, source) do
    {default, channel_entries} =
      case Map.pop(declaration, :default) do
        {nil, rest} -> Map.pop(rest, "default", :immediate)
        result -> result
      end

    with {:ok, {normalized_default, default_digest_key}} <- normalize_mode(default),
         {:ok, {normalized_channels, digest_keys}} <- normalize_channel_modes(channel_entries) do
      {:ok,
       %{
         default: normalized_default,
         channels: normalized_channels,
         default_digest_key: default_digest_key,
         digest_keys: digest_keys,
         source: source
       }}
    end
  end

  defp normalize_orchestration(other, _source),
    do: {:error, {:invalid_orchestration_declaration, other}}

  defp normalize_channel_modes(entries) do
    Enum.reduce_while(entries, {:ok, {%{}, %{}}}, fn {channel, mode}, {:ok, acc} ->
      with {:ok, normalized_channel} <- normalize_channel(channel),
           {:ok, {normalized_mode, digest_key}} <- normalize_mode(mode) do
        {channels, digest_keys} = acc

        {:cont,
         {:ok,
          {Map.put(channels, normalized_channel, normalized_mode), digest_keys}
          |> maybe_put_digest_key(normalized_channel, digest_key)}}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp maybe_put_digest_key({channels, digest_keys}, _channel, nil), do: {channels, digest_keys}

  defp maybe_put_digest_key({channels, digest_keys}, channel, digest_key) do
    {channels, Map.put(digest_keys, channel, digest_key)}
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

  defp normalize_mode({mode, opts}) when mode in [:digest, :digest_held] and is_list(opts) do
    with {:ok, digest_key} <- normalize_digest_key(Keyword.get(opts, :digest_key)) do
      {:ok, {:digest_held, digest_key}}
    end
  end

  defp normalize_mode(:immediate), do: {:ok, {:immediate, nil}}
  defp normalize_mode(:digest), do: {:ok, {:digest_held, nil}}
  defp normalize_mode(:digest_held), do: {:ok, {:digest_held, nil}}
  defp normalize_mode("immediate"), do: {:ok, {:immediate, nil}}
  defp normalize_mode("digest"), do: {:ok, {:digest_held, nil}}
  defp normalize_mode("digest_held"), do: {:ok, {:digest_held, nil}}
  defp normalize_mode(mode), do: {:error, {:invalid_orchestration_mode, mode}}

  defp normalize_digest_key(nil), do: {:ok, nil}

  defp normalize_digest_key(digest_key) when is_binary(digest_key) do
    normalized_digest_key = String.trim(digest_key)

    if normalized_digest_key == "" do
      {:error, {:invalid_digest_key, digest_key}}
    else
      {:ok, normalized_digest_key}
    end
  end

  defp normalize_digest_key(digest_key), do: {:error, {:invalid_digest_key, digest_key}}
end
