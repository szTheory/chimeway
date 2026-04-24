defmodule Chimeway.TelemetryIntegrationTest do
  @moduledoc """
  Confirms all mandatory Chimeway telemetry spans fire during a full trigger cycle
  and that no PII keys appear in any stop event's metadata.
  """

  use Chimeway.DataCase, async: false

  alias Chimeway.Telemetry

  @mandatory_stop_events [
    [:chimeway, :events, :create, :stop],
    [:chimeway, :deliveries, :plan, :stop],
    [:chimeway, :policy, :evaluate, :stop],
    [:chimeway, :dispatch, :sync, :stop],
    [:chimeway, :attempts, :record, :stop]
  ]

  @pii_keys [:email, :phone, :body, :payload, :content, :template, :url]

  setup do
    test_pid = self()
    handler_id = :"chimeway_test_handler_#{System.unique_integer()}"

    :telemetry.attach_many(
      handler_id,
      @mandatory_stop_events,
      fn event, _measurements, metadata, _config ->
        send(test_pid, {:telemetry_event, event, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    :ok
  end

  defp run_trigger do
    notifier = Chimeway.Test.SupportNotifier
    params = %{user_id: "#{System.unique_integer()}"}
    opts = [idempotency_key: "telem-key-#{System.unique_integer()}"]
    Chimeway.Trigger.trigger(notifier, params, opts)
  end

  describe "mandatory span emission" do
    test "all 5 mandatory :stop spans fire during a trigger cycle" do
      {:ok, _result} = run_trigger()

      results =
        Enum.map(@mandatory_stop_events, fn expected ->
          receive do
            {:telemetry_event, ^expected, _meta} -> {expected, :ok}
          after
            500 -> {expected, :missing}
          end
        end)

      missing = for {event, :missing} <- results, do: event

      assert missing == [],
             "Expected telemetry events did not fire: #{inspect(missing)}"
    end

    test "no stop event metadata contains PII keys" do
      {:ok, _result} = run_trigger()

      Enum.each(@mandatory_stop_events, fn expected ->
        receive do
          {:telemetry_event, ^expected, metadata} ->
            pii_found = Enum.filter(@pii_keys, &Map.has_key?(metadata, &1))

            assert pii_found == [],
                   "PII keys #{inspect(pii_found)} found in #{inspect(expected)} metadata: #{inspect(metadata)}"
        after
          500 -> flunk("Event #{inspect(expected)} not received within 500ms")
        end
      end)
    end

    test "events:create stop event metadata contains notification_key" do
      {:ok, _result} = run_trigger()

      receive do
        {:telemetry_event, [:chimeway, :events, :create, :stop], metadata} ->
          assert Map.has_key?(metadata, :notification_key),
                 "events:create :stop missing :notification_key. Got: #{inspect(Map.keys(metadata))}"
      after
        500 -> flunk("[:chimeway, :events, :create, :stop] not received")
      end
    end
  end

  describe "safe_meta/1 unit tests" do
    test "drops disallowed atom keys" do
      raw = %{
        notification_key: "order_shipped",
        event_id: "uuid-abc",
        email: "user@example.com",
        phone: "+15551234567",
        payload: %{ssn: "123-45-6789"},
        body: "Dear Customer"
      }

      result = Telemetry.safe_meta(raw)

      assert result == %{notification_key: "order_shipped", event_id: "uuid-abc"}
      refute Map.has_key?(result, :email)
      refute Map.has_key?(result, :phone)
      refute Map.has_key?(result, :payload)
      refute Map.has_key?(result, :body)
    end

    test "drops disallowed string keys" do
      raw = %{
        "notification_key" => "order_shipped",
        "email" => "secret@example.com",
        "delivery_id" => "delivery-uuid-123"
      }

      result = Telemetry.safe_meta(raw)

      assert result == %{notification_key: "order_shipped", delivery_id: "delivery-uuid-123"}
      refute Map.has_key?(result, :email)
      refute Map.has_key?(result, "email")
    end

    test "returns empty map when all keys are disallowed" do
      raw = %{email: "a@b.com", phone: "555", payload: %{}}
      assert Telemetry.safe_meta(raw) == %{}
    end

    test "preserves all allowed keys" do
      allowed = %{
        notification_key: "k",
        event_id: "eid",
        recipient_id: "rid",
        channel: :email,
        delivery_id: "did",
        attempt_id: "aid",
        outcome: :succeeded,
        suppression_reason: "disabled",
        correlation_id: "req-1"
      }

      assert Telemetry.safe_meta(allowed) == allowed
    end
  end

  describe "attach_default_handlers/0" do
    test "is idempotent — calling twice does not raise" do
      assert :ok = Telemetry.attach_default_handlers()
      assert :ok = Telemetry.attach_default_handlers()
    end
  end
end
