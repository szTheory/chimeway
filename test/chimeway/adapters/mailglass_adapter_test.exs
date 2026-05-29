if Code.ensure_loaded?(Mailglass) and Code.ensure_loaded?(Chimeway.Adapters.Mailglass) do
  defmodule Chimeway.Adapters.MailglassAdapterTest do
    @moduledoc """
    Contract and classification tests for `Chimeway.Adapters.Mailglass`.

    ## Error classification (D-15)

    | Mailglass error | Chimeway class |
    |-----------------|----------------|
    | `%Mailglass.SuppressedError{}` | `:bounced` |
    | `%Mailglass.RateLimitError{}` | `:temporary` |
    | `%Mailglass.SendError{}` (retryable) | `:temporary` |
    | `%Mailglass.SendError{}` (non-retryable) | `:permanent` |
    | `%Mailglass.TemplateError{}` | `:permanent` |
    | `%Mailglass.ConfigError{}` | `:permanent` |
    | `%Mailglass.TenancyError{}` | `:permanent` |
    | `simulate_error: true` config | `:temporary` |
    """

    use Mailglass.DataCase, async: false
    use Chimeway.Adapter.ContractTest

    @moduletag :mailglass

    alias Chimeway.Adapters.Mailglass, as: MailglassAdapter
    alias Chimeway.TestSupport.MailglassFixtures

    def adapter_module, do: MailglassAdapter
    def sample_delivery, do: MailglassFixtures.sample_delivery()
    def simulate_error?, do: true

    setup do
      Mailglass.Adapters.Fake.checkout()
      Mailglass.Adapters.Fake.set_shared(self())

      previous_configs = Application.get_env(:chimeway, :channel_adapter_configs)

      Application.put_env(:chimeway, :channel_adapter_configs, %{
        "email" => [mailables: MailglassFixtures.mailables()]
      })

      on_exit(fn ->
        if previous_configs do
          Application.put_env(:chimeway, :channel_adapter_configs, previous_configs)
        else
          Application.delete_env(:chimeway, :channel_adapter_configs)
        end
      end)

      :ok
    end

    describe "Mailglass integration" do
      test "happy path uses Mailglass.Fake" do
        count_before = length(Mailglass.Adapters.Fake.deliveries())

        assert {:ok, meta} =
                 MailglassAdapter.deliver(
                   MailglassFixtures.sample_delivery(),
                   mailables: MailglassFixtures.mailables(),
                   outbound_opts: []
                 )

        assert length(Mailglass.Adapters.Fake.deliveries()) == count_before + 1
        assert meta[:adapter] == "mailglass"
      end
    end

    describe "error classification (D-14, D-15)" do
      test "classifies simulate_error config as :temporary" do
        delivery = MailglassFixtures.sample_delivery()

        assert {:error, :temporary, detail} =
                 MailglassAdapter.deliver(delivery,
                   mailables: MailglassFixtures.mailables(),
                   simulate_error: true
                 )

        assert is_map(detail)
        refute Map.has_key?(detail, :token)
        refute Map.has_key?(detail, :api_key)
      end

      test "classifies Mailglass.SuppressedError as :bounced" do
        delivery = MailglassFixtures.sample_delivery()

        assert {:error, :bounced, detail} =
                 MailglassAdapter.deliver(delivery,
                   mailables: MailglassFixtures.mailables(),
                   simulate_error: :bounced
                 )

        assert detail[:type] == :address
        assert detail[:module] == "Elixir.Mailglass.SuppressedError"
        refute Map.has_key?(detail, :token)
      end

      test "classifies Mailglass.TemplateError as :permanent" do
        err = Mailglass.TemplateError.new(:missing_assign, context: %{assign: :name})

        assert {:error, :permanent, detail} = MailglassAdapter.classify_error_for_test(err)
        assert is_map(detail)
        refute Map.has_key?(detail, :token)
        refute Map.has_key?(detail, :api_key)
      end
    end
  end
end
