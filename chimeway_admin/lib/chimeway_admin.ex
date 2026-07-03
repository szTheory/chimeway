defmodule ChimewayAdmin do
  @moduledoc """
  Optional operator command center for Chimeway.

  Host applications mount `ChimewayAdmin.Router` under an authenticated scope
  and configure `config :chimeway_admin, auth_module: MyApp.AdminAuth`.
  The core `chimeway` package stays free of required Phoenix dependencies.

  ## Routes

  The mounted router provides:

    * `/` — command center
    * `/traces` — trace lookup
    * `/deliveries/:delivery_id` — trace detail
    * `/feed` — operator feed debug
    * `/definitions` — persisted notification definitions
    * `/health` — lifecycle outcome health
    * `/recovery` — safe recovery queue

  ## Stylesheet

  Serve the packaged stylesheet from the host endpoint:

      plug Plug.Static,
        at: "/chimeway_admin",
        from: {:chimeway_admin, "priv/static"},
        gzip: false,
        only: ~w(chimeway_admin.css)

  Then include:

      <link rel="stylesheet" href={ChimewayAdmin.Assets.css_path()} />
  """
end
