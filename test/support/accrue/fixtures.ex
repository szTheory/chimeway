if Code.ensure_loaded?(Accrue) and not Code.ensure_loaded?(Chimeway.TestSupport.AccrueFixtures) do
  defmodule Chimeway.TestSupport.AccrueFixtures do
    @moduledoc false

    alias Accrue.Billing.{Customer, Invoice, Subscription}
    alias Accrue.TestRepo, as: Repo

    def configure_chimeway_dunning_engine! do
      unless Code.ensure_loaded?(Accrue.Integrations.Chimeway) do
        raise "Accrue.Integrations.Chimeway is not loaded — run `mix deps.compile accrue --force`"
      end

      Application.put_env(:accrue, :dunning,
        engine: Accrue.Integrations.Chimeway,
        campaign: [enabled: true]
      )

      :ok
    end

    def configure_chimeway_logger_adapter! do
      Application.put_env(:chimeway, :channel_adapter_configs, %{
        "email" => {Chimeway.Adapters.Logger, []}
      })

      :ok
    end

    def insert_customer!(attrs \\ %{}) do
      defaults = %{
        owner_type: "User",
        owner_id: Ecto.UUID.generate(),
        processor: "fake",
        processor_id: "cus_fake_" <> Integer.to_string(System.unique_integer([:positive])),
        email: "accrue-harness@example.com",
        name: "Accrue Harness Customer"
      }

      attrs = Map.merge(defaults, Map.new(attrs))

      %Customer{}
      |> Customer.changeset(attrs)
      |> Repo.insert!()
    end

    def insert_subscription!(customer, attrs \\ %{}) do
      processor_id =
        Map.get(attrs, :processor_id) ||
          "sub_fake_" <> Integer.to_string(System.unique_integer([:positive]))

      defaults = %{
        processor_id: processor_id,
        status: :past_due,
        past_due_since: Accrue.Clock.utc_now()
      }

      attrs = Map.merge(defaults, Map.new(attrs))

      %Subscription{customer_id: customer.id, processor: "fake"}
      |> Subscription.force_status_changeset(attrs)
      |> Repo.insert!()
    end

    def insert_failed_invoice!(customer, subscription, attrs \\ %{}) do
      processor_id =
        Map.get(attrs, :processor_id) ||
          "in_fake_" <> Integer.to_string(System.unique_integer([:positive]))

      defaults = %{
        processor_id: processor_id,
        status: :open,
        amount_due_minor: 2_000,
        total_minor: 2_000,
        currency: "usd"
      }

      attrs = Map.merge(defaults, Map.new(attrs))

      %Invoice{
        processor: "fake",
        customer_id: customer.id,
        subscription_id: subscription.id
      }
      |> Invoice.force_status_changeset(attrs)
      |> Repo.insert!()
    end

    def stub_invoice_payment_failed_fetch!(invoice, subscription, customer) do
      canonical = %{
        "id" => invoice.processor_id,
        "object" => "invoice",
        "status" => "open",
        "customer" => customer.processor_id,
        "subscription" => subscription.processor_id,
        "currency" => invoice.currency || "usd",
        "amount_due" => invoice.amount_due_minor || 2_000,
        "amount_paid" => 0,
        "amount_remaining" => invoice.amount_due_minor || 2_000,
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
               "status" => "past_due",
               "cancel_at_period_end" => false,
               "pause_collection" => nil,
               "items" => %{"object" => "list", "data" => []},
               "metadata" => %{}
             }}
          else
            {:error, :not_found}
          end
        end)

      canonical
    end
  end
end
