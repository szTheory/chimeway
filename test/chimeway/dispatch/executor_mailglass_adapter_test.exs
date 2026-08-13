if Code.ensure_loaded?(Mailglass) and Code.ensure_loaded?(Chimeway.Adapters.Mailglass) do
  defmodule Chimeway.Dispatch.AsyncMailglassNotifier do
    @behaviour Chimeway.Notifier

    def notification_key, do: "mailglass.async.execution"
    def version, do: 1
    def recipients(_params), do: {:ok, []}
    def build(_params, _recipient), do: {:ok, %{}}
    def channels(_params, _recipient), do: {:ok, [:email]}

    def rendering(_params, _recipient) do
      {:ok,
       %{
         assigns: %{
           "subject" => "async private subject",
           "html_body" => "<p>async private body</p>",
           "text_body" => "async private body"
         },
         channels: %{email: %{render_key: "chimeway.test.email", render_version: 1}}
       }}
    end
  end

  defmodule Chimeway.Dispatch.AsyncMailglassResolver do
    @behaviour Chimeway.RenderContextResolver

    @impl true
    def resolve("mailglass.async.execution", 1, recipient_ref) do
      {:ok,
       %{
         notifier: Chimeway.Dispatch.AsyncMailglassNotifier,
         params: %{},
         recipient: %{recipient_ref: recipient_ref, recipient_identity: "user:async@example.test"}
       }}
    end

    def resolve(_, _, _), do: {:error, :render_context_unavailable}
  end

  defmodule Chimeway.Dispatch.ExecutorMailglassAdapterTest do
    @moduledoc """
    Proves `Chimeway.Dispatch.Executor.run_delivery/1` routes email channel
    deliveries to `Chimeway.Adapters.Mailglass` when configured (D-08, ECOS-02).
    """
    use Chimeway.DataCase, async: false
    use Oban.Testing, repo: Chimeway.Repo

    alias Chimeway.{Deliveries, Dispatch.ObanWorker, Repo}
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

    test "Oban worker routes execution-time email context to Mailglass and records a succeeded attempt" do
      previous_resolvers = Application.get_env(:chimeway, :render_context_resolvers)

      on_exit(fn ->
        Application.put_env(:chimeway, :render_context_resolvers, previous_resolvers)
      end)

      Application.put_env(:chimeway, :render_context_resolvers, %{
        {"mailglass.async.execution", 1} => Chimeway.Dispatch.AsyncMailglassResolver
      })

      %{notification: notification, delivery: delivery} =
        DispatchHelpers.create_pending_delivery(
          channel: :email,
          notification_key: "mailglass.async.execution",
          recipient_identity: "opaque-mailglass-recipient",
          tenant_id: "test-tenant"
        )

      {:ok, _notification} =
        notification
        |> Ecto.Changeset.change(
          render_channels: %{
            "email" => %{"render_key" => "chimeway.test.email", "render_version" => 1}
          }
        )
        |> Repo.update()

      {:ok, _delivery} =
        delivery
        |> Ecto.Changeset.change(%{
          tenant_id: "test-tenant",
          actor_id: "system",
          render_key: "chimeway.test.email",
          render_version: 1,
          render_data: %{}
        })
        |> Repo.update()

      count_before = length(Mailglass.Adapters.Fake.deliveries())
      assert :ok = perform_job(ObanWorker, %{delivery_id: delivery.id})

      updated = delivery.id |> Deliveries.get_delivery!() |> Repo.preload(:attempts)
      [attempt] = updated.attempts
      assert updated.status == :succeeded
      assert attempt.outcome == :succeeded
      assert attempt.adapter_module == "Chimeway.Adapters.Mailglass"
      assert attempt.provider_response == %{}
      assert is_binary(attempt.provider_message_id)
      assert String.starts_with?(attempt.provider_message_id, "cw_provider_message_id_")
      assert length(Mailglass.Adapters.Fake.deliveries()) == count_before + 1

      assert inspect(Mailglass.Adapters.Fake.deliveries()) =~ "async@example.test"
      assert Deliveries.get_delivery!(delivery.id).render_data == %{}
    end
  end
end
