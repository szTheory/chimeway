if Code.ensure_loaded?(Mailglass) and Code.ensure_loaded?(Chimeway.Adapters.Mailglass) do
  defmodule Chimeway.Adapters.MailglassWebhookPipelineTest do
    @moduledoc """
    ECOS-04 Chimeway-level feedback pipeline proof (Phase 55 plan 03).

    Outbound Mailglass deliver → Postmark Delivery webhook → ProcessFeedbackWorker
    → signal → operator trace, without demo host routes (D-17).
    """
    use ExUnit.Case, async: false
    use Oban.Testing, repo: Chimeway.Repo

    alias Chimeway.Adapters.Mailglass, as: MailglassAdapter
    alias Chimeway.DeliveryAttempt
    alias Chimeway.Dispatch.Executor
    alias Chimeway.Repo
    alias Chimeway.Signals.Signal
    alias Chimeway.Test.DispatchHelpers
    alias Chimeway.TestSupport.MailglassFixtures
    alias Chimeway.Traces
    alias Chimeway.Webhooks
    alias Chimeway.Webhooks.Ingress

    @moduletag :mailglass

    setup do
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(Chimeway.Repo)
      Ecto.Adapters.SQL.Sandbox.mode(Chimeway.Repo, {:shared, self()})
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(Mailglass.TestRepo)
      Ecto.Adapters.SQL.Sandbox.mode(Mailglass.TestRepo, {:shared, self()})

      Mailglass.Adapters.Fake.checkout()
      Mailglass.Adapters.Fake.set_shared(self())
      Mailglass.Tenancy.put_current("test-tenant")

      previous_channel_adapters = Application.get_env(:chimeway, :channel_adapters)
      previous_channel_configs = Application.get_env(:chimeway, :channel_adapter_configs)

      Application.put_env(:chimeway, :channel_adapters, %{
        "email" => MailglassAdapter
      })

      Application.put_env(:chimeway, :channel_adapter_configs, %{
        "email" => [mailables: MailglassFixtures.mailables()]
      })

      on_exit(fn ->
        if previous_channel_adapters do
          Application.put_env(:chimeway, :channel_adapters, previous_channel_adapters)
        else
          Application.delete_env(:chimeway, :channel_adapters)
        end

        if previous_channel_configs do
          Application.put_env(:chimeway, :channel_adapter_configs, previous_channel_configs)
        else
          Application.delete_env(:chimeway, :channel_adapter_configs)
        end
      end)

      :ok
    end

    describe "ECOS-04 feedback pipeline" do
      @tag :webhook
      test "outbound deliver → webhook → worker → signal → trace without host glue" do
        %{delivery: delivery} =
          DispatchHelpers.create_pending_delivery(
            channel: :email,
            recipient_identity: "user:pipeline-#{System.unique_integer([:positive])}"
          )

        delivery =
          delivery
          |> Ecto.Changeset.change(%{
            tenant_id: "test-tenant",
            actor_id: "user:test@example.com",
            render_key: "chimeway.test.email",
            render_data: %{"to" => "test@example.com"}
          })
          |> Repo.update!()

        assert {:ok, %{delivery: _dispatched, attempt: outbound_attempt}} =
                 Executor.run_delivery(delivery)

        provider_message_id = outbound_attempt.provider_message_id
        assert is_binary(provider_message_id) and provider_message_id != ""

        body =
          MailglassFixtures.encode_postmark_payload(
            MailglassFixtures.postmark_delivery_payload_for_message_id(provider_message_id)
          )

        headers = MailglassFixtures.postmark_delivery_headers()
        config = MailglassFixtures.postmark_webhook_config_keyword()

        assert {:ok, %Ingress{} = ingress} =
                 Webhooks.process(MailglassAdapter, body, headers, config)

        assert ingress.normalized_status == "delivered"
        assert ingress.provider_message_id == provider_message_id

        result = Oban.drain_queue(queue: :chimeway_delivery, with_scheduled: true)

        total =
          Map.get(result, :success, 0) +
            Map.get(result, :failure, 0) +
            Map.get(result, :discard, 0)

        assert total >= 1, "expected ProcessFeedbackWorker to run; got #{inspect(result)}"

        attempts = Repo.all(DeliveryAttempt)
        assert length(attempts) >= 2

        feedback_attempt =
          Enum.find(attempts, fn attempt ->
            attempt.outcome == :succeeded and
              attempt.provider_message_id == provider_message_id and
              String.contains?(attempt.adapter_module, "Chimeway.Adapters.Mailglass")
          end)

        assert feedback_attempt

        signals = Repo.all(Signal)

        assert Enum.any?(signals, fn signal ->
                 signal.event_name == "chimeway.delivery.succeeded"
               end)

        {:ok, %{timeline: timeline}} = Traces.explain_delivery(delivery.id)
        event_atoms = Enum.map(timeline, & &1.event)
        assert :webhook_received in event_atoms

        webhook_entry =
          Enum.find(timeline, fn entry ->
            entry.event == :webhook_received and
              entry.detail.provider_message_id == provider_message_id
          end)

        assert webhook_entry

        assert String.contains?(
                 webhook_entry.detail.adapter_module,
                 "Chimeway.Adapters.Mailglass"
               )
      end
    end
  end
end
