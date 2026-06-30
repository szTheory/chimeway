defmodule Chimeway.ConfigError do
  @moduledoc """
  Raised when Chimeway application configuration is invalid.

  The structured fields are stable so callers and tests can identify the rejected
  configuration shape without parsing the human-facing message.
  """

  defexception [:message, :type, :key, :value]

  @impl true
  def exception(opts) do
    type = Keyword.fetch!(opts, :type)
    key = Keyword.fetch!(opts, :key)
    value = Keyword.fetch!(opts, :value)

    %__MODULE__{
      message: message(type, key, value),
      type: type,
      key: key,
      value: value
    }
  end

  defp message(:invalid_prefix, :prefix, value) do
    """
    [chimeway] invalid :prefix config, got: #{inspect(value)}.

    Use prefix: "chimeway" for new schema-isolated installs:

        config :chimeway, prefix: "chimeway"

    Use prefix: false only for an existing public-schema legacy install:

        config :chimeway, prefix: false

    Dynamic per-tenant database prefixes are not supported.
    """
    |> String.trim()
  end

  defp message(type, key, value) do
    "[chimeway] invalid config #{inspect(key)} for #{inspect(type)}, got: #{inspect(value)}"
  end
end
