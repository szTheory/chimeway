defmodule ChimewayAdmin.TestSupport.Endpoint do
  @moduledoc false
  use Phoenix.Endpoint, otp_app: :chimeway_admin

  socket "/live", Phoenix.LiveView.Socket
end
