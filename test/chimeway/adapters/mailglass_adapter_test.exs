if Code.ensure_loaded?(Mailglass) and Code.ensure_loaded?(Chimeway.Adapters.Mailglass) do
  defmodule Chimeway.Adapters.MailglassAdapterTest do
    use Mailglass.DataCase, async: false

    alias Chimeway.TestSupport.MailglassFixtures

    # ContractTest activates in plan 54-03 once deliver/2 is implemented.
    def adapter_module, do: Chimeway.Adapters.Mailglass
    def sample_delivery, do: MailglassFixtures.sample_delivery()

    setup do
      Mailglass.Adapters.Fake.checkout()
      :ok
    end

    test "stub compiles" do
      assert function_exported?(Chimeway.Adapters.Mailglass, :deliver, 2)
    end
  end
end
