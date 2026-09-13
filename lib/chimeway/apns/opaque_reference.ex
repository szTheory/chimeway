defmodule Chimeway.APNS.OpaqueReference do
  @moduledoc false

  @max_bytes 256
  @grammar ~r/\A(?:cw_)?open[-_][A-Za-z0-9_-]+\z/

  @spec valid?(term()) :: boolean()
  def valid?(value) when is_binary(value) and byte_size(value) in 1..@max_bytes,
    do: Regex.match?(@grammar, value)

  def valid?(_), do: false
end
