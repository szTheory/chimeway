if Code.ensure_loaded?(Sigra) do
  defmodule DemoHostWeb.SigraAuthProofTest do
    @moduledoc """
    DEMO-10 proof: Sigra auth event → Chimeway trigger → durable Chimeway.Delivery row
    with operator trace inspectability at `/admin/chimeway`.

    Tagged `:sigra` only — journey suite keeps default Logger adapter (D-03).
    """
    use DemoHostWeb.ConnCase, async: false
    use Oban.Testing, repo: Chimeway.Repo

    import Phoenix.LiveViewTest

    @moduletag :sigra

    alias Chimeway.{Delivery, Repo}

    setup do
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(Sigra.TestRepo)
      Ecto.Adapters.SQL.Sandbox.mode(Sigra.TestRepo, {:shared, self()})

      # Inline configure_sigra_chimeway_integration! from Chimeway.TestSupport.SigraFixtures
      # (root test/support not available in demo host elixirc_paths — Pitfall 6)
      previous_dispatcher = Application.get_env(:chimeway, :dispatcher)

      Application.put_env(:sigra, :chimeway, enabled: true)
      Application.put_env(:sigra, :repo, Sigra.TestRepo)
      Application.put_env(:chimeway, :dispatcher, Chimeway.Dispatch.Sync)

      # Inline configure_chimeway_logger_adapter!
      Application.put_env(:chimeway, :channel_adapter_configs, %{
        "email" => {Chimeway.Adapters.Logger, []}
      })

      on_exit(fn ->
        Application.put_env(:chimeway, :dispatcher, previous_dispatcher)
        Application.delete_env(:sigra, :chimeway)
        Application.delete_env(:sigra, :repo)
      end)

      :ok
    end

    test "DEMO-10 sigra auth creates durable delivery" do
      assert {:ok, result} = DemoHost.Seeds.seed_sigra_auth()

      delivery_id = hd(result.trace.delivery_ids)
      delivery = Repo.get!(Delivery, delivery_id)
      assert delivery.status in [:succeeded, :dispatched]
    end

    test "DEMO-10 admin trace shows sigra auth notification", %{conn: conn} do
      assert {:ok, result} = DemoHost.Seeds.seed_sigra_auth()

      conn = get(conn, "/admin/chimeway")
      assert html_response(conn, 200) =~ "Trace search"

      {:ok, view, _html} = live(conn)

      html =
        view
        |> form("#trace-search-form", %{
          "mode" => "recipient",
          "query" => result.recipient_identity,
          "notification_key" => ""
        })
        |> render_submit()

      assert html =~ result.recipient_identity

      delivery_id = hd(result.trace.delivery_ids)
      assert String.contains?(html, delivery_id)

      {:ok, _detail_view, detail_html} =
        live(conn, "/admin/chimeway/deliveries/#{delivery_id}")

      assert detail_html =~ "Trace detail"
    end
  end
end
