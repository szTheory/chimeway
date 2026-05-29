if Code.ensure_loaded?(Mailglass) and Code.ensure_loaded?(Chimeway.Adapters.Mailglass) do
  defmodule Chimeway.Dispatch.ExecutorMailglassAdapterTest do
    @moduledoc """
    Proves `Chimeway.Dispatch.Executor.run_delivery/1` routes email channel
    deliveries to `Chimeway.Adapters.Mailglass` when configured (D-08, ECOS-02).
    """
    use Chimeway.DataCase, async: false

    alias Chimeway.Dispatch.Executor
    alias Chimeway.Repo
    alias Chimeway.Test.DispatchHelpers
    alias Chimeway.TestSupport.MailglassFixtures

    @moduletag :mailglass

    setup do
      mailglass_sandbox =
        Ecto.Adapters.SQL.Sandbox.start_owner!(Mailglass.TestRepo, shared: true)

      Mailglass.Adapters.Fake.checkout()
      Mailglass.Adapters.Fake.set_shared(self())
      Mailglass.Tenancy.put_current("test-tenant")

      previous_adapter = Application.get_env(:chimeway, :adapter, Chimeway.Adapters.Logger)
      previous_channel_adapters = Application.get_env(:chimeway, :channel_adapters)
      previous_channel_configs = Application.get_env(:chimeway, :channel_adapter_configs)

      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Logger)

      Application.put_env(:chimeway, :channel_adapters, %{
        "email" => Chimeway.Adapters.Mailglass
      })

      Application.put_env(:chimeway, :channel_adapter_configs, %{
        "email" => [mailables: MailglassFixtures.mailables()]
      })

      on_exit(fn ->
        Ecto.Adapters.SQL.Sandbox.stop_owner(mailglass_sandbox)
        Application.put_env(:chimeway, :adapter, previous_adapter)

        if is_nil(previous_channel_adapters) do
          Application.delete_env(:chimeway, :channel_adapters)
        else
          Application.put_env(:chimeway, :channel_adapters, previous_channel_adapters)
        end

        if is_nil(previous_channel_configs) do
          Application.delete_env(:chimeway, :channel_adapter_configs)
        else
          Application.put_env(:chimeway, :channel_adapter_configs, previous_channel_configs)
        end
      end)

      :ok
    end

    test "run_delivery routes email channel to Mailglass adapter and records succeeded attempt" do
      %{delivery: delivery} =
        DispatchHelpers.create_pending_delivery(
          channel: :email,
          recipient_identity: "user:test@example.com"
        )

      {:ok, delivery} =
        delivery
        |> Ecto.Changeset.change(%{
          tenant_id: "test-tenant",
          actor_id: "user:test@example.com",
          render_key: "chimeway.test.email",
          render_data: %{"to" => "test@example.com"}
        })
        |> Repo.update()

      assert {:ok, %{delivery: updated, attempt: attempt}} = Executor.run_delivery(delivery)
      assert updated.status == :succeeded
      assert attempt.outcome == :succeeded
      assert attempt.adapter_module == "Chimeway.Adapters.Mailglass"

      provider_response = attempt.provider_response || %{}

      assert provider_response["adapter"] == "mailglass" or provider_response[:adapter] == "mailglass"
    end
  end
end
