defmodule ChimewayAdmin.Routes do
  @moduledoc """
  Path helpers for admin LiveViews mounted under a host scope prefix.

  Configure when mounting under a non-root path:

      config :chimeway_admin, path_prefix: "/admin/chimeway"
  """

  @doc """
  Builds a path under the configured `path_prefix`.
  """
  @spec path(String.t()) :: String.t()
  def path(suffix) when is_binary(suffix) do
    prefix =
      :chimeway_admin
      |> Application.get_env(:path_prefix, "")
      |> to_string()
      |> String.trim_trailing("/")

    suffix = if String.starts_with?(suffix, "/"), do: suffix, else: "/" <> suffix

    case prefix do
      "" -> suffix
      p -> p <> suffix
    end
  end

  @doc false
  @spec search_path() :: String.t()
  def search_path, do: path("/")

  @doc false
  @spec delivery_path(String.t()) :: String.t()
  def delivery_path(delivery_id), do: path("/deliveries/#{delivery_id}")
end
