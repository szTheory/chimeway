if Code.ensure_loaded?(Accrue) and Code.ensure_loaded?(Accrue.Integrations.Chimeway) do
  defmodule Chimeway.Integrations.AccrueDunningHarnessTest do
    @moduledoc false

    use Accrue.DataCase, async: false

    @moduletag :accrue

    alias Accrue.Billing.Subscription
    alias Accrue.Config
    alias Accrue.Integrations.Chimeway, as: ChimewayDunningEngine
    alias Accrue.TestRepo, as: Repo

    describe "accrue dunning harness (ECOS-06 wave 1)" do
      setup do
        configure_chimeway_dunning_engine!()
        configure_chimeway_logger_adapter!()
        :ok
      end

      test "engine config round-trip resolves Chimeway dunning adapter" do
        configure_chimeway_dunning_engine!()
        assert Config.dunning_engine() == ChimewayDunningEngine
      end

      test "Chimeway adapter module exports start_campaign/3" do
        assert function_exported?(ChimewayDunningEngine, :start_campaign, 3)
      end

      test "invoice.payment_failed trigger_event reaches DefaultHandler path" do
        customer = insert_customer!()
        subscription = insert_subscription!(customer)
        invoice = insert_failed_invoice!(customer, subscription)

        stub_invoice_payment_failed_fetch!(invoice, subscription, customer)

        payload = %{
          id: invoice.processor_id,
          customer: customer.processor_id,
          subscription: subscription.processor_id,
          amount_due: invoice.amount_due_minor,
          currency: invoice.currency
        }

        assert {:ok, _row} = Accrue.Test.trigger_event(:invoice_payment_failed, payload)

        reloaded = Repo.get!(Subscription, subscription.id)
        assert reloaded.status == :past_due
        assert %DateTime{} = reloaded.dunning_campaign_started_at
      end

      test "start_campaign smoke does not crash with UTC anchor" do
        customer = insert_customer!()
        subscription = insert_subscription!(customer)
        anchor = DateTime.utc_now() |> DateTime.truncate(:second)

        assert :ok = ChimewayDunningEngine.start_campaign(subscription, anchor, [])
      end
    end
  end
end
