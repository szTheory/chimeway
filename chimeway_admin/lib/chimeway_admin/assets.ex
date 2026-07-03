defmodule ChimewayAdmin.Assets do
  @moduledoc """
  Asset helpers for the mountable admin package.
  """

  @css_path "/chimeway_admin/chimeway_admin.css"

  @doc "Default path for the packaged admin stylesheet."
  @spec css_path() :: String.t()
  def css_path, do: @css_path

  @doc "Returns the packaged CSS for demo/test inline use."
  @spec inline_css() :: String.t()
  def inline_css do
    :chimeway_admin
    |> :code.priv_dir()
    |> Path.join("static/chimeway_admin.css")
    |> File.read()
    |> case do
      {:ok, css} -> css
      {:error, _} -> ""
    end
  end
end
