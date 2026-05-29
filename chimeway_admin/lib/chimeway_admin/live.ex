defmodule ChimewayAdmin.Live do
  @moduledoc false

  defmacro __using__(which) when which in [:live_view] do
    apply(__MODULE__, which, [])
  end

  def live_view do
    quote do
      use Phoenix.LiveView
      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      import Phoenix.Component
      alias Phoenix.LiveView.JS
    end
  end
end
