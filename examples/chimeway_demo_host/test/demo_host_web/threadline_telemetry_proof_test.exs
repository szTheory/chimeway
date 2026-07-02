if Code.ensure_loaded?(Threadline) and
     Code.ensure_loaded?(Chimeway.Telemetry.ThreadlineReporter) do
  defmodule DemoHostWeb.ThreadlineTelemetryProofTest do
    @moduledoc """
    DEMO-09 proof: Chimeway notification lifecycle event → Threadline audit_actions row
    with correlation_id, and operator trace inspectability at `/admin/chimeway`.

    Tagged `:threadline` only — journey suite keeps default Logger adapter (D-03).
    """
    use DemoHostWeb.ConnCase, async: false
    use Oban.Testing, repo: Chimeway.Repo, prefix: "public"

    import Phoenix.LiveViewTest
    import Ecto.Query

    @moduletag :threadline

    alias Threadline.Semantics.AuditAction
    alias Threadline.Test.Repo, as: ThreadlineRepo

    setup do
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(ThreadlineRepo)
      Ecto.Adapters.SQL.Sandbox.mode(ThreadlineRepo, {:shared, self()})

      # Clear audit rows so assertions are clean (bounded by this test's trigger)
      ThreadlineRepo.delete_all(AuditAction)

      # Inline attach_threadline_reporter! from Chimeway.TestSupport.ThreadlineFixtures
      # (root test/support not available in demo host elixirc_paths)
      {:ok, actor} = Threadline.Semantics.ActorRef.new(:system, "chimeway")

      Application.put_env(:chimeway, :threadline_reporter,
        repo: ThreadlineRepo,
        actor: actor
      )

      Chimeway.Telemetry.ThreadlineReporter.attach()

      # Inline configure_chimeway_logger_adapter!
      Application.put_env(:chimeway, :channel_adapter_configs, %{
        "email" => {Chimeway.Adapters.Logger, []},
        "in_app" => {Chimeway.Adapters.Logger, []}
      })

      on_exit(fn ->
        # Inline detach_threadline_reporter!
        try do
          :telemetry.detach(:chimeway_threadline_reporter)
        catch
          :error, {:not_found, :chimeway_threadline_reporter} -> :ok
        end
      end)

      :ok
    end

    test "DEMO-09 threadline audit row created for notification lifecycle event" do
      assert {:ok, result} = DemoHost.Seeds.seed_threadline_notification()

      rows =
        ThreadlineRepo.all(
          from(a in AuditAction,
            where: a.correlation_id == ^result.trace.correlation_id
          )
        )

      assert length(rows) >= 1
    end

    test "DEMO-09 admin trace shows threadline notification", %{conn: conn} do
      assert {:ok, result} = DemoHost.Seeds.seed_threadline_notification()

      conn = get(conn, "/admin/chimeway/traces")
      assert html_response(conn, 200) =~ "Trace Lookup"

      {:ok, view, _html} = live(conn)

      html =
        view
        |> form("#trace-search-form", %{
          "mode" => "recipient",
          "query" => result.recipient_identity,
          "notification_key" => ""
        })
        |> render_submit()

      assert html =~ ChimewayAdmin.Redaction.redact_recipient(result.recipient_identity)
      refute html =~ result.recipient_identity

      delivery_id = hd(result.trace.delivery_ids)
      assert String.contains?(html, delivery_id)

      {:ok, _detail_view, detail_html} =
        live(conn, "/admin/chimeway/deliveries/#{delivery_id}")

      assert detail_html =~ "Trace Detail"
    end
  end
end
