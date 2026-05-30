if Code.ensure_loaded?(Accrue) and Code.ensure_loaded?(Accrue.Integrations.Chimeway) do
  defmodule Chimeway.Integrations.AccrueDunningLifecycleTest do
    @moduledoc false

    use Accrue.DataCase, async: false
    use Oban.Testing, repo: Chimeway.Repo

    @moduletag :accrue

    import Ecto.Query

    alias Accrue.Billing.Subscription
    alias Accrue.Integrations.Chimeway, as: ChimewayDunningEngine
    alias Accrue.TestRepo, as: Repo
    alias Chimeway.Delivery
    alias Chimeway.Notifications.Notification
    alias Chimeway.Repo, as: ChimewayRepo
    alias Chimeway.Workflows
    alias Chimeway.Workflows.{WorkflowDefinition, WorkflowRun, WorkflowStep, WorkflowTransition}

    describe "invoice.payment_failed starts dunning workflow (ECOS-06 start)" do
      setup do
        configure_chimeway_dunning_engine!()
        configure_chimeway_logger_adapter!()

        customer = insert_customer!()
        subscription = insert_subscription!(customer)
        invoice = insert_failed_invoice!(customer, subscription)

        stub_invoice_payment_failed_fetch!(invoice, subscription, customer)

        %{
          customer: customer,
          subscription: subscription,
          invoice: invoice
        }
      end

      test "payment_failed creates WorkflowRun with explainable trace", %{
        customer: customer,
        subscription: subscription,
        invoice: invoice
      } do
        assert {:ok, _row} =
                 trigger_invoice_payment_failed_event!(invoice, subscription, customer)

        runs = list_dunning_runs!(customer.id)
        assert length(runs) == 1

        [run] = runs
        assert run.workflow_key == "accrue.dunning"
        assert run.state in [:active, :waiting]
        assert run.tenant_id == customer.id

        assert {:ok, explain} = Workflows.explain(customer.id, run.id)
        assert explain.id == run.id
        assert explain.tenant_id == customer.id

        assert {:ok, traces} = Workflows.list_traces(customer.id, run.id)
        assert traces != []

        reloaded = Repo.get!(Subscription, subscription.id)
        assert %DateTime{} = reloaded.dunning_campaign_started_at
      end

      test "idempotent duplicate payment_failed keeps a single WorkflowRun", %{
        customer: customer,
        subscription: subscription,
        invoice: invoice
      } do
        assert {:ok, _row} =
                 trigger_invoice_payment_failed_event!(invoice, subscription, customer)

        reloaded = Repo.get!(Subscription, subscription.id)
        anchor = reloaded.dunning_campaign_started_at

        assert :ok = ChimewayDunningEngine.start_campaign(reloaded, anchor, [])

        assert length(list_dunning_runs!(customer.id)) == 1
      end

      test "wait_until sets pending_signals after initial email delivery", %{
        customer: customer,
        subscription: subscription,
        invoice: invoice
      } do
        assert {:ok, _row} =
                 trigger_invoice_payment_failed_event!(invoice, subscription, customer)

        [run] = list_dunning_runs!(customer.id)
        notification = fetch_notification_for_run!(run)

        drain_initial_email_delivery!(notification.id)

        waiting_run = progress_to_waiting!(run.id)

        assert waiting_run.state == :waiting
        assert waiting_run.status_reason == "waiting_for_step_progression"
        assert waiting_run.pending_signals == ["invoice.paid"]
      end
    end

    describe "invoice.paid terminates dunning via Outcome Signal (ECOS-06 terminate)" do
      setup do
        previous_dispatcher = Application.get_env(:chimeway, :dispatcher)

        on_exit(fn ->
          Application.put_env(:chimeway, :dispatcher, previous_dispatcher)
        end)

        Application.put_env(:chimeway, :dispatcher, Chimeway.Dispatch.Oban)
        configure_chimeway_dunning_engine!()
        configure_chimeway_logger_adapter!()

        customer = insert_customer!()
        subscription = insert_subscription!(customer)
        invoice = insert_failed_invoice!(customer, subscription)

        stub_invoice_payment_failed_fetch!(invoice, subscription, customer)
        stub_invoice_paid_fetch!(invoice, subscription, customer)

        %{
          customer: customer,
          subscription: subscription,
          invoice: invoice
        }
      end

      test "invoice_paid via Accrue webhook path resumes waiting run", %{
        customer: customer,
        subscription: subscription,
        invoice: invoice
      } do
        %{workflow_run: waiting_run} =
          start_dunning_and_wait!(invoice, subscription, customer)

        assert waiting_run.state == :waiting
        assert waiting_run.pending_signals == ["invoice.paid"]
        assert waiting_run.status_reason == "waiting_for_step_progression"

        due_at = parse_iso8601!(waiting_run.status_context["due_at"])
        assert DateTime.compare(due_at, DateTime.utc_now()) == :gt

        assert {:ok, _row} = trigger_invoice_paid_event!(invoice, subscription, customer)

        assert %{success: 1} =
                 Oban.drain_queue(queue: :chimeway_signals, with_scheduled: true)

        updated_run = ChimewayRepo.get!(WorkflowRun, waiting_run.id)
        assert updated_run.state == :active
        assert updated_run.pending_signals == []
        assert updated_run.status_reason == "signal_received"

        [signal_received_transition] =
          ChimewayRepo.all(
            from(wt in WorkflowTransition,
              where: wt.workflow_run_id == ^waiting_run.id and wt.reason == "signal_received"
            )
          )

        assert signal_received_transition.context == %{"event_name" => "invoice.paid"}
      end

      test "no escalation email delivery after invoice_paid termination", %{
        customer: customer,
        subscription: subscription,
        invoice: invoice
      } do
        %{workflow_run: waiting_run} =
          start_dunning_and_wait!(invoice, subscription, customer)

        assert {:ok, _row} = trigger_invoice_paid_event!(invoice, subscription, customer)
        assert %{success: 1} = Oban.drain_queue(queue: :chimeway_signals, with_scheduled: true)

        updated_run = ChimewayRepo.get!(WorkflowRun, waiting_run.id)

        escalation_deliveries =
          ChimewayRepo.all(
            from(d in Delivery,
              join: ws in WorkflowStep,
              on: d.workflow_step_id == ws.id,
              where:
                d.workflow_run_id == ^waiting_run.id and ws.step_key == "escalation_email"
            )
          )

        assert escalation_deliveries == []

        current_step = Workflows.get_current_step!(updated_run)
        assert current_step.step_key == "initial_email"
      end

      test "signal before due_at cancels wait without advancing 48h", %{
        customer: customer,
        subscription: subscription,
        invoice: invoice
      } do
        %{workflow_run: waiting_run} =
          start_dunning_and_wait!(invoice, subscription, customer)

        due_at = parse_iso8601!(waiting_run.status_context["due_at"])
        assert DateTime.compare(due_at, DateTime.utc_now()) == :gt

        assert {:ok, _row} = trigger_invoice_paid_event!(invoice, subscription, customer)
        assert %{success: 1} = Oban.drain_queue(queue: :chimeway_signals, with_scheduled: true)

        updated_run = ChimewayRepo.get!(WorkflowRun, waiting_run.id)
        assert updated_run.state == :active
        assert updated_run.pending_signals == []
      end

      test "explain trace includes waiting to signal_received chain", %{
        customer: customer,
        subscription: subscription,
        invoice: invoice
      } do
        %{workflow_run: waiting_run} =
          start_dunning_and_wait!(invoice, subscription, customer)

        assert {:ok, _row} = trigger_invoice_paid_event!(invoice, subscription, customer)
        assert %{success: 1} = Oban.drain_queue(queue: :chimeway_signals, with_scheduled: true)

        assert {:ok, explain} = Workflows.explain(customer.id, waiting_run.id)
        assert explain.id == waiting_run.id

        assert {:ok, traces} = Workflows.list_traces(customer.id, waiting_run.id)

        reasons = Enum.map(traces, & &1.reason)
        assert "waiting_for_step_progression" in reasons
        assert "signal_received" in reasons
      end
    end

    defp parse_iso8601!(value) when is_binary(value) do
      case DateTime.from_iso8601(value) do
        {:ok, datetime, _offset} -> datetime
        other -> raise "invalid iso8601: #{inspect(other)}"
      end
    end

    defp list_dunning_runs!(tenant_id) do
      ChimewayRepo.all(
        from(wr in WorkflowRun,
          join: wd in WorkflowDefinition,
          on: wr.workflow_definition_id == wd.id,
          where: wr.tenant_id == ^tenant_id and wd.workflow_key == "accrue.dunning",
          order_by: [asc: wr.inserted_at],
          select: %{
            id: wr.id,
            tenant_id: wr.tenant_id,
            state: wr.state,
            status_reason: wr.status_reason,
            pending_signals: wr.pending_signals,
            workflow_key: wd.workflow_key,
            notification_id: wr.notification_id
          }
        )
      )
    end

    defp fetch_notification_for_run!(%{notification_id: notification_id}) do
      ChimewayRepo.get!(Notification, notification_id)
    end
  end
end
