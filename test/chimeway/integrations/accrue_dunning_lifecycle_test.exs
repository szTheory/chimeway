if Code.ensure_loaded?(Accrue) and Code.ensure_loaded?(Accrue.Integrations.Chimeway) do
  defmodule Chimeway.Integrations.AccrueDunningLifecycleTest do
    @moduledoc false

    use Accrue.DataCase, async: false

    @moduletag :accrue

    import Ecto.Query

    alias Accrue.Billing.Subscription
    alias Accrue.Integrations.Chimeway, as: ChimewayDunningEngine
    alias Accrue.TestRepo, as: Repo
    alias Chimeway.Notifications.Notification
    alias Chimeway.Repo, as: ChimewayRepo
    alias Chimeway.Workflows
    alias Chimeway.Workflows.{WorkflowDefinition, WorkflowRun}

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
