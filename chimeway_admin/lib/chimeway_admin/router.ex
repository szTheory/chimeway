defmodule ChimewayAdmin.Router do
  @moduledoc """
  Mountable LiveView routes for operator trace lookup.

  ## Host integration

      # router.ex
      scope "/admin/chimeway" do
        pipe_through [:browser]

        import ChimewayAdmin.Router
        chimeway_admin_routes()
      end

      # config/config.exs
      config :chimeway_admin, auth_module: MyApp.AdminAuth
  """

  defmacro chimeway_admin_routes(_opts \\ []) do
    quote do
      import Phoenix.LiveView.Router

      live_session :chimeway_admin_search,
        on_mount: [{ChimewayAdmin.LiveAuth, :search_traces}] do
        live("/", ChimewayAdmin.Live.DashboardLive, :index)
        live("/traces", ChimewayAdmin.Live.TraceSearchLive, :index)
      end

      live_session :chimeway_admin_detail,
        on_mount: [{ChimewayAdmin.LiveAuth, :view_trace}] do
        live("/deliveries/:delivery_id", ChimewayAdmin.Live.TraceDetailLive, :show)
      end

      live_session :chimeway_admin_feed,
        on_mount: [{ChimewayAdmin.LiveAuth, :view_feed}] do
        live("/feed", ChimewayAdmin.Live.FeedLive, :index)
      end

      live_session :chimeway_admin_definitions,
        on_mount: [{ChimewayAdmin.LiveAuth, :view_definitions}] do
        live("/definitions", ChimewayAdmin.Live.DefinitionsLive, :index)
      end

      live_session :chimeway_admin_health,
        on_mount: [{ChimewayAdmin.LiveAuth, :view_health}] do
        live("/health", ChimewayAdmin.Live.HealthLive, :index)
      end

      live_session :chimeway_admin_recovery,
        on_mount: [{ChimewayAdmin.LiveAuth, :list_recovery_candidates}] do
        live("/recovery", ChimewayAdmin.Live.RecoveryLive, :index)
      end
    end
  end
end
