defmodule ChimewayInbox.TestSupport.Endpoint do
  @moduledoc false
  use Phoenix.Endpoint, otp_app: :chimeway_inbox

  socket "/live", Phoenix.LiveView.Socket

  plug Plug.Session, store: :cookie, key: "_chimeway_inbox_test", signing_salt: "test-salt"
  plug ChimewayInbox.TestSupport.Router
end
