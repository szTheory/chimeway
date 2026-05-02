defmodule DemoHostWeb.Router do
  use DemoHostWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/webhooks/chimeway", DemoHostWeb do
    pipe_through :api
    post "/:adapter", WebhooksController, :create
  end
end
