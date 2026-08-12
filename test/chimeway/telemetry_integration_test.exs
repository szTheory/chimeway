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

    opts = [
      idempotency_key: "telem-key-#{System.unique_integer()}",
      correlation_id: "test-corr-#{System.unique_integer()}",
      tenant_id: "acme"
    ]

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
        planning_reason: "quiet_hours",
        correlation_id: "req-1"
      }

      assert Telemetry.safe_meta(allowed) == allowed
    end

    test "retains planning_reason while stripping PII (D-08)" do
      assert %{planning_reason: "digest_rule"} =
               Telemetry.safe_meta(%{
                 planning_reason: "digest_rule",
                 email: "secret@example.com"
               })
    end
  end

  describe "planning_reason redaction (D-08)" do
    alias Chimeway.{Delivery, Events.Event, Notifications.Notification, Policy, Repo}
    alias Chimeway.Policy.Settings

    setup do
      test_pid = self()
      handler_id = :"chimeway_planning_reason_#{System.unique_integer()}"

      :telemetry.attach(
        handler_id,
        [:chimeway, :policy, :evaluate, :stop],
        fn _event, _measurements, metadata, _config ->
          send(test_pid, {:policy_evaluate_stop, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      {:ok, event} =
        %Event{}
        |> Event.changeset(%{
          notification_key: "policy.quiet_hours",
          notification_version: 1,
          idempotency_key: "planning-reason-#{System.unique_integer()}",
          tenant_id: "default",
          payload: %{}
        })
        |> Repo.insert()

      {:ok, notification} =
        %Notification{}
        |> Notification.changeset(%{
          event_id: event.id,
          tenant_id: event.tenant_id,
          recipient_identity: "user-policy-quiet-hours-telem",
          recipient_type: "user",
          metadata: %{"correlation_id" => "test-corr-planning-reason"}
        })
        |> Repo.insert()

      {:ok, delivery} =
        %Delivery{}
        |> Delivery.changeset(%{
          notification_id: notification.id,
          channel: "in_app",
          status: :pending,
          tenant_id: "default",
          actor_id: "system",
          metadata: %{
            "notification_key" => "policy.quiet_hours",
            "correlation_id" => "test-corr-planning-reason"
          }
        })
        |> Repo.insert()

      assert {:ok, _} =
               Settings.upsert_settings(%{
                 recipient_id: "user-policy-quiet-hours-telem",
                 quiet_hours_start_minute: 22 * 60,
                 quiet_hours_end_minute: 8 * 60,
                 time_zone: "America/New_York"
               })

      %{delivery: delivery}
    end

    test "defer policy span stop meta includes planning_reason without PII", %{delivery: delivery} do
      assert {:defer, _decision} =
               Policy.evaluate(delivery, evaluation_time: ~U[2026-01-15 03:30:00Z])

      assert_receive {:policy_evaluate_stop, meta}, 500
      assert meta.planning_reason == "quiet_hours"
      refute Map.has_key?(meta, :email)
      refute Map.has_key?(meta, :body)
    end
  end

  describe "attach_default_handlers/0" do
    test "is idempotent — calling twice does not raise" do
      assert :ok = Telemetry.attach_default_handlers()
      assert :ok = Telemetry.attach_default_handlers()
    end
  end

  describe "Phase 29 D-14 channel_unregistered telemetry" do
    test "emits [:chimeway, :rendering, :channel_unregistered] on first hit and is silent on subsequent hits" do
      # Each test owns a unique channel string so the :persistent_term once-flag
      # does not collide with sibling tests. We still erase the flag both before
      # the test (defensive) and on_exit (deterministic for re-runs).
      channel_string = "telem_unknown_xyz_#{System.unique_integer([:positive])}"
      :persistent_term.erase({:chimeway_channel_unregistered_logged, channel_string})

      on_exit(fn ->
        :persistent_term.erase({:chimeway_channel_unregistered_logged, channel_string})
      end)

      handler_id = :"chimeway_test_channel_unregistered_#{System.unique_integer([:positive])}"
      test_pid = self()

      :telemetry.attach(
        handler_id,
        [:chimeway, :rendering, :channel_unregistered],
        fn _event, measurements, metadata, _config ->
          send(test_pid, {:channel_unregistered_event, measurements, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      # First call: telemetry MUST fire.
      Chimeway.Rendering.render_delivery(channel_string, "x.x.unknown", 1, %{})

      assert_receive {:channel_unregistered_event, %{count: 1}, %{channel: ^channel_string}}, 500

      # D-14 once-flag: a second call with the same channel does NOT re-emit.
      Chimeway.Rendering.render_delivery(channel_string, "x.x.unknown", 1, %{})

      refute_receive {:channel_unregistered_event, _, %{channel: ^channel_string}}, 100
    end
  end

  describe "Phase 29 D-19 adapter_fallback telemetry" do
    setup do
      original_channel_adapters = Application.get_env(:chimeway, :channel_adapters)
      original_adapter = Application.get_env(:chimeway, :adapter)

      on_exit(fn ->
        case original_channel_adapters do
          nil -> Application.delete_env(:chimeway, :channel_adapters)
          val -> Application.put_env(:chimeway, :channel_adapters, val)
        end

        case original_adapter do
          nil -> Application.delete_env(:chimeway, :adapter)
          mod -> Application.put_env(:chimeway, :adapter, mod)
        end
      end)

      :ok
    end

    test "emits [:chimeway, :dispatch, :adapter_fallback] when :channel_adapters is set and lookup misses" do
      handler_id = :"chimeway_test_adapter_fallback_#{System.unique_integer([:positive])}"
      test_pid = self()

      :telemetry.attach(
        handler_id,
        [:chimeway, :dispatch, :adapter_fallback],
        fn _event, measurements, metadata, _config ->
          send(test_pid, {:adapter_fallback_event, measurements, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      # :channel_adapters explicitly set for "sms" only; an in_app delivery will miss
      # the per-channel map and fall back to :adapter, firing the telemetry.
      Application.put_env(:chimeway, :channel_adapters, %{"sms" => Chimeway.Adapters.Logger})
      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)

      ctx =
        Chimeway.Test.DispatchHelpers.create_pending_delivery(
          notification_key: "test.adapter_fallback_hit",
          channel: :in_app
        )

      assert {:ok, _} = Chimeway.Dispatch.Sync.dispatch_delivery(ctx.delivery, [])

      assert_receive {:adapter_fallback_event, %{count: 1}, metadata}, 500
      assert metadata.channel == "in_app"
      assert is_binary(metadata.fallback_module)
    end

    test "does NOT emit adapter_fallback when only :adapter is configured (no :channel_adapters)" do
      handler_id = :"chimeway_test_no_adapter_fallback_#{System.unique_integer([:positive])}"
      counter = :counters.new(1, [])

      :telemetry.attach(
        handler_id,
        [:chimeway, :dispatch, :adapter_fallback],
        fn _event, _measurements, _metadata, _config ->
          :counters.add(counter, 1, 1)
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      # Ensure :channel_adapters is NOT set; only :adapter exists.
      Application.delete_env(:chimeway, :channel_adapters)
      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)

      ctx =
        Chimeway.Test.DispatchHelpers.create_pending_delivery(
          notification_key: "test.adapter_no_fallback",
          channel: :in_app
        )

      assert {:ok, _} = Chimeway.Dispatch.Sync.dispatch_delivery(ctx.delivery, [])

      # Give any async telemetry callback a moment to fire if it would.
      Process.sleep(50)
      assert :counters.get(counter, 1) == 0
    end
  end

  describe "correlation metadata enrichment" do
    test "all enriched spans include notification_key and appropriate IDs" do
      {:ok, _result} = run_trigger()

      # 1. events:create
      assert_receive {:telemetry_event, [:chimeway, :events, :create, :stop], meta}, 500
      assert meta.notification_key == "test_support_notifier"
      assert meta.event_id != nil

      # 2. deliveries:plan
      assert_receive {:telemetry_event, [:chimeway, :deliveries, :plan, :stop], meta}, 500
      assert meta.notification_key == "test_support_notifier"
      assert meta.event_id != nil
      assert String.starts_with?(meta.correlation_id, "test-corr-")

      # 3. policy:evaluate
      assert_receive {:telemetry_event, [:chimeway, :policy, :evaluate, :stop], meta}, 500
      assert meta.notification_key == "test_support_notifier"
      assert meta.delivery_id != nil
      assert meta.channel == "in_app"
      assert String.starts_with?(meta.correlation_id, "test-corr-")

      # 4. dispatch:sync
      assert_receive {:telemetry_event, [:chimeway, :dispatch, :sync, :stop], meta}, 500
      assert meta.notification_key == "test_support_notifier"
      assert meta.delivery_id != nil
      assert meta.channel == "in_app"
      assert String.starts_with?(meta.correlation_id, "test-corr-")

      # 5. attempts:record
      assert_receive {:telemetry_event, [:chimeway, :attempts, :record, :stop], meta}, 500
      assert meta.notification_key == "test_support_notifier"
      assert meta.delivery_id != nil
      assert meta.channel == "in_app"
      assert meta.attempt_id != nil
      assert meta.outcome == :succeeded
      assert String.starts_with?(meta.correlation_id, "test-corr-")
    end
  end
end
