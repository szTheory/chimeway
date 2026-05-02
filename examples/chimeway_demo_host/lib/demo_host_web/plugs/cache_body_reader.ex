defmodule DemoHost.Plugs.CacheBodyReader do
  @moduledoc """
  Reads the request body and caches it into `conn.assigns[:raw_body]` so
  webhook signature verification can run on the exact bytes the provider
  signed. `Plug.Parsers` consumes the body during JSON parsing; without a
  :body_reader the raw bytes are unrecoverable.

  Canonical pattern from hexdocs.pm/plug/Plug.Parsers.html — mirrored here
  because Chimeway core deliberately does not couple to Plug (Phase 33 D-10).

  Pitfall (Phase 33 D-13 / T-33-RAWBODY): the cached body is an iolist
  (chunk-list accumulator). Controllers MUST flatten via IO.iodata_to_binary/1
  before passing to verify_webhook/3 — adapters compute HMAC over binaries,
  and an iolist input silently fails verification. The reference controller
  at lib/demo_host_web/controllers/webhooks_controller.ex does this; copy
  that pattern in your own host app.
  """

  def read_body(conn, opts) do
    with {:ok, body, conn} <- Plug.Conn.read_body(conn, opts) do
      conn = update_in(conn.assigns[:raw_body], &[body | &1 || []])
      {:ok, body, conn}
    end
  end
end
