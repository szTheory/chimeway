defmodule Chimeway.TelemetryCorrelationTest do
  use Chimeway.DataCase, async: false

  alias Chimeway.{Delivery, Repo, Trigger}

  defmodule CorrelationNotifier do
    @behaviour Chimeway.Notifier

    @impl true
    def notification_key, do: "telemetry.correlation.test"

    @impl true
    def version, do: 1

    @impl true
    def recipients(_params) do
      {:ok, [%{recipient_identity: "user-1", channel: :in_app}]}
    end

    @impl true
    def build(_params, recipient),
      do:
        {:ok,
         %{
           "headline" => "test",
           "body" => "test",
           "primary_action" => %{"label" => "test", "url" => "http://test"},
           recipient: recipient
         }}
  end

  test "delivery records persist correlation identifiers in metadata" do
    correlation_id = "corr-#{Ecto.UUID.generate()}"
    idempotency_key = "idem-#{Ecto.UUID.generate()}"

    assert {:ok, result} =
             Trigger.trigger(
               CorrelationNotifier,
               %{"foo" => "bar"},
               idempotency_key: idempotency_key,
               correlation_id: correlation_id,
               tenant_id: "acme"
             )

    event = result.event
    assert event.correlation_id == correlation_id

    # Check delivery records
    deliveries = Repo.all(Delivery)
    assert deliveries != []

    # Find deliveries for this event
    event_deliveries =
      Repo.all(
        from(d in Delivery,
          join: n in Chimeway.Notifications.Notification,
          on: d.notification_id == n.id,
          where: n.event_id == ^event.id
        )
      )

    assert length(event_deliveries) == 1
    delivery = List.first(event_deliveries)

    assert delivery.metadata["notification_key"] == "telemetry.correlation.test"
    assert delivery.metadata["event_id"] == event.id
    assert delivery.metadata["correlation_id"] == correlation_id
  end

  test "[:deliveries, :plan] telemetry span is enriched with correlation identifiers" do
    test_pid = self()
    handler_id = :telemetry_enrichment_test

    :telemetry.attach(
      handler_id,
      [:chimeway, :deliveries, :plan, :stop],
      fn _name, _measurements, meta, _config ->
        send(test_pid, {:telemetry_event, meta})
      end,
      nil
    )

    on_exit(fn ->
      :telemetry.detach(handler_id)
    end)

    correlation_id = "corr-#{Ecto.UUID.generate()}"
    idempotency_key = "enrich-#{Ecto.UUID.generate()}"

    Trigger.trigger(
      CorrelationNotifier,
      %{},
      idempotency_key: idempotency_key,
      correlation_id: correlation_id,
      tenant_id: "acme"
    )

    assert_receive {:telemetry_event, meta}
    assert meta.notification_key == "telemetry.correlation.test"
    assert meta.correlation_id == correlation_id
    assert is_binary(meta.event_id)
  end
end
