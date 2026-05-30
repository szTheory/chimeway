if Code.ensure_loaded?(Accrue) and Code.ensure_loaded?(Accrue.Integrations.Chimeway) do
  defmodule DemoHostWeb.AccrueDunningProofTest do
    @moduledoc """
    DEMO-07 proof: Accrue billing events drive Chimeway dunning with operator trace
    inspectability at `/admin/chimeway`.

    Tagged `:accrue` only — journey suite keeps default Logger adapter (D-03).
    """
    use DemoHostWeb.ConnCase, async: false
    use Oban.Testing, repo: Chimeway.Repo

    import Phoenix.LiveViewTest
    import Ecto.Query
    import DemoHost.AccrueFixtures

    alias Chimeway.{Delivery, Repo}
    alias Chimeway.Workflows.{WorkflowRun, WorkflowStep}

    @moduletag :accrue

    setup do
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(Accrue.TestRepo)
      Ecto.Adapters.SQL.Sandbox.mode(Accrue.TestRepo, {:shared, self()})

      start_fake_processor!()
      :ok = Accrue.Actor.put_operation_id("demo-accrue-" <> Ecto.UUID.generate())

      previous_accrue_env = Application.get_env(:accrue, :env)
      Application.put_env(:accrue, :env, :test)

      previous_dispatcher = Application.get_env(:chimeway, :dispatcher)

      on_exit(fn ->
        if previous_accrue_env do
          Application.put_env(:accrue, :env, previous_accrue_env)
        else
          Application.delete_env(:accrue, :env)
        end

        Application.put_env(:chimeway, :dispatcher, previous_dispatcher)
      end)

      Application.put_env(:chimeway, :dispatcher, Chimeway.Dispatch.Oban)
      configure_chimeway_dunning_engine!()
      configure_chimeway_logger_adapter!()

      :ok
    end

    test "DEMO-07 payment_failed starts dunning and delivers initial email" do
      assert {:ok, result} = DemoHost.Seeds.seed_accrue_dunning()

      run = Repo.get!(WorkflowRun, result.workflow_run_id)
      assert run.state == :waiting
      assert run.pending_signals == []
      assert result.workflow_key == "accrue.dunning"

      delivery = Repo.get!(Delivery, hd(result.trace.delivery_ids))
      assert delivery.status == :succeeded
      assert delivery.channel == "email"
    end

    test "DEMO-07 invoice.paid terminates before escalation" do
      customer = insert_customer!()
      subscription = insert_subscription!(customer)
      invoice = insert_failed_invoice!(customer, subscription)

      stub_invoice_payment_failed_fetch!(invoice, subscription, customer)
      stub_invoice_paid_fetch!(invoice, subscription, customer)

      %{workflow_run: waiting_run} = start_dunning_and_wait!(invoice, subscription, customer)

      assert waiting_run.state == :waiting
      assert waiting_run.pending_signals == []

      assert {:ok, _row} = trigger_invoice_paid_event!(invoice, subscription, customer)
      assert %{success: 1} = Oban.drain_queue(queue: :chimeway_signals, with_scheduled: true)

      updated_run = Repo.get!(WorkflowRun, waiting_run.id)
      assert updated_run.status_reason == "signal_received"

      escalation_deliveries =
        Repo.all(
          from(d in Delivery,
            join: ws in WorkflowStep,
            on: d.workflow_step_id == ws.id,
            where:
              d.workflow_run_id == ^waiting_run.id and ws.step_key == "escalation_email"
          )
        )

      assert escalation_deliveries == []
    end

    test "DEMO-07 admin trace shows dunning workflow", %{conn: conn} do
      assert {:ok, result} = DemoHost.Seeds.seed_accrue_dunning()

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

      {:ok, detail_view, detail_html} =
        live(conn, "/admin/chimeway/deliveries/#{delivery_id}")

      assert detail_html =~ "Trace detail"

      detail = render(detail_view)
      assert detail =~ "accrue.dunning" or detail =~ "waiting_for_step_progression"
    end

    defp start_fake_processor! do
      case Accrue.Processor.Fake.start_link([]) do
        {:ok, _} -> :ok
        {:error, {:already_started, _}} -> :ok
      end

      :ok = Accrue.Processor.Fake.reset_preserve_connect()
    end
  end
end
