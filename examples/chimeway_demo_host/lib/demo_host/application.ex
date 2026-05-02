defmodule DemoHost.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: DemoHost.PubSub},
      DemoHostWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: DemoHost.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
