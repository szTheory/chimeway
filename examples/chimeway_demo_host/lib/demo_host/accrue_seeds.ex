if Code.ensure_loaded?(Accrue) and Code.ensure_loaded?(Accrue.Integrations.Chimeway) do
  defmodule DemoHost.AccrueSeeds do
    @moduledoc false

    import Ecto.Query

    alias Accrue.Billing.{Customer, Invoice, Subscription}
    alias Accrue.TestRepo, as: AccrueRepo
    alias Chimeway.{Deliveries, Delivery, Repo}
    alias Chimeway.Notifications.Notification
    alias Chimeway.Workflows.{Progression, WorkflowDefinition, WorkflowRun}

    @demo_email "accrue.demo@teampulse.test"

    def demo_email, do: @demo_email

    def demo_identity, do: DemoHost.Seeds.recipient_identity(@demo_email)

    @spec seed_accrue_dunning() :: {:ok, map()}
    def seed_accrue_dunning do
      Application.put_env(:accrue, :dunning,
        engine: Accrue.Integrations.Chimeway,
        campaign: [enabled: true]
      )

      Application.put_env(:chimeway, :channel_adapter_configs, %{
        "email" => {Chimeway.Adapters.Logger, []}
      })

      customer =
        %Customer{
          owner_type: "User",
          owner_id: Ecto.UUID.generate(),
          processor: "fake",
          processor_id: "cus_demo_" <> Integer.to_string(System.unique_integer([:positive])),
          email: @demo_email,
          name: "Accrue Demo Customer"
        }
        |> Customer.changeset(%{})
        |> AccrueRepo.insert!()

      subscription =
        %Subscription{customer_id: customer.id, processor: "fake"}
        |> Subscription.force_status_changeset(%{
          processor_id: "sub_demo_" <> Integer.to_string(System.unique_integer([:positive])),
          status: :past_due,
          past_due_since: Accrue.Clock.utc_now()
        })
        |> AccrueRepo.insert!()

      invoice =
        %Invoice{
          processor: "fake",
          customer_id: customer.id,
          subscription_id: subscription.id
        }
        |> Invoice.force_status_changeset(%{
          processor_id: "in_demo_" <> Integer.to_string(System.unique_integer([:positive])),
          status: :open,
          amount_due_minor: 2_000,
          total_minor: 2_000,
          currency: "usd"
        })
        |> AccrueRepo.insert!()

      stub_invoice_fetch!(invoice, subscription, customer, status: "open")

      payload = %{
        id: invoice.processor_id,
        customer: customer.processor_id,
        subscription: subscription.processor_id,
        amount_due: invoice.amount_due_minor,
        currency: invoice.currency
      }

      case Accrue.Test.trigger_event(:invoice_payment_failed, payload) do
        {:ok, _row} -> :ok
        other -> raise "expected payment_failed trigger to succeed, got: #{inspect(other)}"
      end

      [run] =
        Repo.all(
          from(wr in WorkflowRun,
            join: wd in WorkflowDefinition,
            on: wr.workflow_definition_id == wd.id,
            where: wr.tenant_id == ^customer.id and wd.workflow_key == "accrue.dunning",
            order_by: [asc: wr.inserted_at]
          )
        )

      notification = Repo.get!(Notification, run.notification_id)

      delivery =
        Repo.one!(
          from(d in Delivery,
            where: d.notification_id == ^notification.id and d.channel == "email"
          )
        )

      delivery = drain_email_delivery!(delivery)

      waiting_run =
        case Progression.progress_run(run.id, []) do
          {:ok, {:noop, progressed_run, :wait_not_due}} -> progressed_run
          other -> raise "expected wait_not_due progression, got: #{inspect(other)}"
        end

      {:ok,
       %{
         customer_id: customer.id,
         workflow_run_id: waiting_run.id,
         recipient_identity: demo_identity(),
         workflow_key: "accrue.dunning",
         trace: %{delivery_ids: [delivery.id]}
       }}
    end

    defp drain_email_delivery!(delivery) do
      case delivery.status do
        status when status in [:succeeded, :suppressed, :cancelled, :digested] ->
          delivery

        :dispatched ->
          {:ok, %{delivery: terminal_delivery}} =
            Deliveries.record_attempt(delivery, %{outcome: :succeeded})

          terminal_delivery

        _ ->
          {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)

          {:ok, %{delivery: terminal_delivery}} =
            Deliveries.record_attempt(dispatched, %{outcome: :succeeded})

          terminal_delivery
      end
    end

    defp stub_invoice_fetch!(invoice, subscription, customer, opts) do
      status = Keyword.fetch!(opts, :status)

      canonical = %{
        "id" => invoice.processor_id,
        "object" => "invoice",
        "status" => status,
        "customer" => customer.processor_id,
        "subscription" => subscription.processor_id,
        "currency" => invoice.currency || "usd",
        "amount_due" => if(status == "paid", do: 0, else: invoice.amount_due_minor || 2_000),
        "amount_paid" => if(status == "paid", do: invoice.total_minor || 2_000, else: 0),
        "amount_remaining" => if(status == "paid", do: 0, else: invoice.amount_due_minor || 2_000),
        "next_payment_attempt" =>
          DateTime.utc_now() |> DateTime.add(2 * 86_400, :second) |> DateTime.to_unix(),
        "lines" => %{"object" => "list", "data" => []},
        "metadata" => %{}
      }

      :ok =
        Accrue.Processor.Fake.stub(:retrieve_invoice, fn id, _opts ->
          if id == invoice.processor_id, do: {:ok, canonical}, else: {:error, :not_found}
        end)

      :ok =
        Accrue.Processor.Fake.stub(:retrieve_subscription, fn id, _opts ->
          if id == subscription.processor_id do
            {:ok,
             %{
               "id" => subscription.processor_id,
               "object" => "subscription",
               "customer" => customer.processor_id,
               "status" => if(status == "paid", do: "active", else: "past_due"),
               "cancel_at_period_end" => false,
               "pause_collection" => nil,
               "items" => %{"object" => "list", "data" => []},
               "metadata" => %{}
             }}
          else
            {:error, :not_found}
          end
        end)

      :ok
    end
  end
end
