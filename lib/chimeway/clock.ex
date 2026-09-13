defmodule Chimeway.Clock do
  @moduledoc "Narrow clock seam with a system UTC default."

  @spec now(keyword()) :: DateTime.t()
  def now(opts \\ []) do
    case Keyword.get(opts, :now) do
      %DateTime{} = resolved ->
        DateTime.truncate(resolved, :microsecond)

      _ ->
        case Keyword.get(opts, :clock) do
          nil -> DateTime.utc_now() |> DateTime.truncate(:microsecond)
          provider when is_atom(provider) -> provider.now(opts)
          _ -> DateTime.utc_now() |> DateTime.truncate(:microsecond)
        end
    end
  rescue
    _ -> DateTime.utc_now() |> DateTime.truncate(:microsecond)
  end
end
