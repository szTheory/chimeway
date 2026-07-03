defmodule ChimewayAdmin.TestSupport.Endpoint do
  @moduledoc false
  use Phoenix.Endpoint, otp_app: :chimeway_admin

  socket("/live", Phoenix.LiveView.Socket)

  plug(Plug.Session, store: :cookie, key: "_chimeway_admin_test", signing_salt: "test-salt")
  plug(ChimewayAdmin.TestSupport.Router)
end
