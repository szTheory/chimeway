defmodule DemoHostWeb.WebhooksController do
  @moduledoc """
  Reference controller proving the Phase 33 host-mount contract.

  Reads the cached raw body from `conn.assigns[:raw_body]` (populated by
  `DemoHost.Plugs.CacheBodyReader` via the endpoint's `Plug.Parsers`
  `:body_reader` MFA), flattens the iolist via `IO.iodata_to_binary/1`
  (Pitfall 4 / T-33-RAWBODY), and calls `Chimeway.Webhooks.process/4`.

  Status mapping per Phase 33 D-03:
    {:ok, _ingress}            -> 200 (host MAY return any 2xx)
    {:error, :unauthorized}    -> 401
    {:error, _other}           -> non-2xx (provider retries)

  Adapter config is read at request time per `Chimeway.Adapter` moduledoc
  discipline (lib/chimeway/adapter.ex:14-18) — never at compile time, never
  via module attributes.
  """

  use DemoHostWeb, :controller

  def create(conn, _params) do
    # Pitfall 4 / T-33-RAWBODY: the body_reader stores chunks as an iolist
    # `[chunk_n, ..., chunk_1, []]`. Flatten to a binary BEFORE passing to
    # adapter.verify_webhook/3 — HMAC compares require binary input.
    raw_body =
      conn.assigns
      |> Map.get(:raw_body, [])
      |> Enum.reverse()
      |> IO.iodata_to_binary()

    headers = conn.req_headers
    adapter_module = adapter_for(conn.path_params["adapter"])
    config = Application.get_env(:demo_host, :chimeway_adapter_config, [])

    case Chimeway.Webhooks.process(adapter_module, raw_body, headers, config) do
      {:ok, _ingress} ->
        send_resp(conn, 200, "OK")

      {:error, :unauthorized} ->
        send_resp(conn, 401, "Unauthorized")

      {:error, _other} ->
        # Any other library-level failure: non-2xx so the provider retries.
        # 500 is a reasonable default; hosts may pick 400 / 422 based on
        # their own observability conventions.
        send_resp(conn, 500, "Internal Server Error")
    end
  end

  # Adapter selection is host-app territory; the example wires two fixture adapters.
  defp adapter_for("echo"), do: DemoHost.Adapters.EchoAdapter
  defp adapter_for("rawbody"), do: DemoHost.Adapters.RawBodyHmacAdapter
  defp adapter_for(_unknown), do: DemoHost.Adapters.EchoAdapter
end
