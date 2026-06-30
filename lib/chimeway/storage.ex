defmodule Chimeway.Storage do
  @moduledoc false

  alias Chimeway.ConfigError

  @storage_prefix "chimeway"

  @spec validate_prefix!() :: String.t() | false
  def validate_prefix! do
    case Application.fetch_env(:chimeway, :prefix) do
      {:ok, @storage_prefix} ->
        @storage_prefix

      {:ok, false} ->
        false

      {:ok, value} ->
        invalid_prefix!(value)

      :error ->
        invalid_prefix!(:missing)
    end
  end

  @spec repo_opts(keyword()) :: keyword()
  def repo_opts(opts \\ []) do
    case validate_prefix!() do
      @storage_prefix -> Keyword.put_new(opts, :prefix, @storage_prefix)
      false -> opts
    end
  end

  defp invalid_prefix!(value) do
    raise ConfigError,
      type: :invalid_prefix,
      key: :prefix,
      value: value
  end
end
