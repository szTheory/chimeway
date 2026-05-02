defmodule DemoHost.Plugs.CacheBodyReader do
  @moduledoc """
  Reads the request body and caches it into `conn.assigns[:raw_body]` so
  webhook signature verification can run on the exact bytes the provider
  signed. `Plug.Parsers` consumes the body during JSON parsing; without a
  :body_reader the raw bytes are unrecoverable.

  Canonical pattern from hexdocs.pm/plug/Plug.Parsers.html — mirrored here
  because Chimeway core deliberately does not couple to Plug (Phase 33 D-10).

  ## Chunked delivery (production Cowboy)

  `Plug.Conn.read_body/2` returns `{:more, chunk, conn}` when the provider
  body exceeds Cowboy's `:read_length` (default 1 MB). `Plug.Parsers` calls
  `read_body/2` in a loop until it receives `:ok`. This implementation caches
  EVERY chunk — both `:ok` and `:more` branches prepend to the accumulator —
  so the full body is available in `conn.assigns[:raw_body]` regardless of
  how many TCP reads the provider request required.

  Pitfall (Phase 33 D-13 / T-33-RAWBODY): the cached body is an iolist
  (chunk-list accumulator, reverse arrival order). Controllers MUST flatten via
  `Enum.reverse/1 |> IO.iodata_to_binary/1` before passing to verify_webhook/3
  — adapters compute HMAC over binaries, and an iolist input silently fails
  verification. The reference controller at
  lib/demo_host_web/controllers/webhooks_controller.ex does this; copy that
  pattern in your own host app.
  """

  def read_body(conn, opts) do
    case Plug.Conn.read_body(conn, opts) do
      {:ok, body, conn} ->
        {:ok, body, update_in(conn.assigns[:raw_body], &[body | &1 || []])}

      {:more, body, conn} ->
        {:more, body, update_in(conn.assigns[:raw_body], &[body | &1 || []])}

      {:error, _} = err ->
        err
    end
  end
end
