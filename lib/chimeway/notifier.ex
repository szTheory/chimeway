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

  @optional_callbacks channels: 2
  @optional_callbacks delayed_fallback_channels: 2

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
end
