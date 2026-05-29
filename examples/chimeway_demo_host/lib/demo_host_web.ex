defmodule DemoHostWeb do
  def controller do
    quote do
      use Phoenix.Controller, formats: [:json]
      import Plug.Conn
    end
  end

  def router do
    quote do
      use Phoenix.Router
      import Phoenix.LiveView.Router
    end
  end

  def html do
    quote do
      use Phoenix.Component
      import Phoenix.Component
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView, layout: {DemoHostWeb.Layouts, :root}
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
