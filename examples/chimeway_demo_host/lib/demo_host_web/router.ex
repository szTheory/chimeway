defmodule DemoHostWeb.Router do
  use DemoHostWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {DemoHostWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug DemoHostWeb.Plugs.AdminActor
  end

  scope "/webhooks/chimeway", DemoHostWeb do
    pipe_through :api
    post "/:adapter", WebhooksController, :create
  end

  scope "/admin/chimeway" do
    pipe_through :browser

    import ChimewayAdmin.Router
    chimeway_admin_routes()
  end
end
