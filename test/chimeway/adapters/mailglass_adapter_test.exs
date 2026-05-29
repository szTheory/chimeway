if Code.ensure_loaded?(Mailglass) and Code.ensure_loaded?(Chimeway.Adapters.Mailglass) do
  defmodule Chimeway.Adapters.MailglassAdapterTest do
    use Mailglass.DataCase, async: false

    alias Chimeway.Adapters.Mailglass, as: MailglassAdapter
    alias Chimeway.TestSupport.MailglassFixtures

    # ContractTest activates in plan 54-03 once deliver/2 is implemented.
    def adapter_module, do: MailglassAdapter
    def sample_delivery, do: MailglassFixtures.sample_delivery()

    setup do
      Mailglass.Adapters.Fake.checkout()
      :ok
    end

    test "stub compiles" do
      assert function_exported?(MailglassAdapter, :deliver, 2)
    end

    test "deliver/2 returns {:ok, meta} with mailglass adapter tag when mailables configured" do
      delivery = MailglassFixtures.sample_delivery()

      assert {:ok, meta} =
               MailglassAdapter.deliver(delivery, mailables: MailglassFixtures.mailables())

      assert meta[:adapter] == "mailglass" or meta["adapter"] == "mailglass"
      assert Map.has_key?(meta, :mailglass_delivery_id) or Map.has_key?(meta, "mailglass_delivery_id")
    end

    test "simulate_error config returns {:error, :temporary, _}" do
      delivery = MailglassFixtures.sample_delivery()

      assert {:error, :temporary, %{reason: :simulated}} =
               MailglassAdapter.deliver(delivery,
                 mailables: MailglassFixtures.mailables(),
                 simulate_error: true
               )
    end

    test "simulate_error :bounced classifies as :bounced via SuppressedError" do
      delivery = MailglassFixtures.sample_delivery()

      assert {:error, :bounced, detail} =
               MailglassAdapter.deliver(delivery,
                 mailables: MailglassFixtures.mailables(),
                 simulate_error: :bounced
               )

      assert detail[:type] == :address
      assert detail[:module] == "Elixir.Mailglass.SuppressedError"
    end
  end
end
