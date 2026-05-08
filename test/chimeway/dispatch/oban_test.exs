defmodule Chimeway.FailingTestAdapter do
  @moduledoc false
  @behaviour Chimeway.Adapter

  @impl Chimeway.Adapter
  def deliver(%Chimeway.Delivery{}, _config), do: {:error, :temporary, %{reason: "test_failure"}}
end

defmodule Chimeway.Test.ObanCaptureConfigAdapter do
  @moduledoc false
  @behaviour Chimeway.Adapter

  @impl Chimeway.Adapter
  def deliver(_delivery, config) do
    capture_pid = Application.get_env(:chimeway, :adapter_capture_pid)

    if is_pid(capture_pid) do
      send(capture_pid, {:adapter_config, config})
    end

    {:ok, %{adapter: "capture"}}
  end
end

defmodule Chimeway.Dispatch.ObanTest do
  use Chimeway.DataCase, async: false
  use Oban.Testing, repo: Chimeway.Repo

  @moduletag :oban

  alias Chimeway.{Deliveries, Dispatch.Oban, Dispatch.ObanWorker}
  alias Chimeway.Test.DispatchHelpers

  setup do
    Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
    Application.put_env(:chimeway, :dispatcher, Chimeway.Dispatch.Oban)
    Chimeway.Adapters.Test.clear()

    on_exit(fn ->
      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Logger)
      Application.put_env(:chimeway, :dispatcher, Chimeway.Dispatch.Sync)
      Chimeway.Adapters.Test.clear()
    end)

    :ok
  end

  describe "Chimeway.Dispatch.Oban.dispatch/2" do
    test "enqueues one ObanWorker job per delivery" do
      %{notification: notification} = DispatchHelpers.create_notification()
      {:ok, _deliveries} = Oban.dispatch([notification], [])
      assert_enqueued(worker: ObanWorker)
    end

    test "returns {:ok, deliveries} with the planned delivery structs" do
      %{notification: notification} = DispatchHelpers.create_notification()
      {:ok, deliveries} = Oban.dispatch([notification], [])
      assert length(deliveries) == 1
      assert hd(deliveries).status == :pending
    end

    test "transactional rollback prevents job from being enqueued" do
      %{notification: notification} = DispatchHelpers.create_notification()

      {:ok, delivery} =
        Deliveries.plan_delivery(notification.id, :in_app,
          tenant_id: "default",
          actor_id: "system"
        )

      failing_multi =
        Ecto.Multi.new()
        |> Ecto.Multi.run(:fail, fn _repo, _changes -> {:error, :forced_failure} end)

      Oban.dispatch([notification], multi: failing_multi)

      refute_enqueued(worker: ObanWorker, args: %{delivery_id: delivery.id})
    end

    test "disabled channel preference suppresses at planning and does not enqueue a job" do
      # POLC-01 / POLC-02: enqueue path must suppress and skip scheduling at planning checkpoint.
      fixture = DispatchHelpers.create_notification(notification_key: "oban.planning.suppression")
      DispatchHelpers.disable_channel_preference(fixture, :in_app)

      assert {:ok, [delivery]} = Oban.dispatch([fixture.notification], [])

      assert DispatchHelpers.delivery_signature(delivery) == %{
               status: :suppressed,
               suppression_reason: "channel_disabled",
               policy_checkpoint: "planning",
               attempt_count: 0
             }

      refute_enqueued(worker: ObanWorker, args: %{delivery_id: delivery.id})
    end

    test "disabled category preference suppresses at planning and does not enqueue a job" do
      fixture =
        DispatchHelpers.create_notification(
          notification_key: "oban.category.suppression",
          payload: %{"category" => "marketing"}
        )

      Chimeway.Preferences.upsert_category_preference(%{
        recipient_id: fixture.notification.recipient_identity,
        notification_category: "marketing",
        enabled: false
      })

      assert {:ok, [delivery]} = Oban.dispatch([fixture.notification], [])

      assert DispatchHelpers.delivery_signature(delivery) == %{
               status: :suppressed,
               suppression_reason: "category_disabled",
               policy_checkpoint: "planning",
               attempt_count: 0
             }

      refute_enqueued(worker: ObanWorker, args: %{delivery_id: delivery.id})
    end

    test "DLVR-04: oban dispatch preserves planning_failed error tagging" do
      # DLVR-04: trigger outcome normalization depends on tagged planning failures.
      %{notification: notification} = DispatchHelpers.create_notification()

      defmodule ObanPlanningFailureNotifier do
        def channels(_trigger_params, _recipient), do: {:error, :forced_planning_failure}
      end

      assert {:error, {:planning_failed, {:channels_resolution_failed, reason}}} =
               Oban.dispatch(
                 [notification],
                 notifier: ObanPlanningFailureNotifier,
                 trigger_params: %{}
               )

      assert reason == :forced_planning_failure
    end
  end

  describe "Chimeway.Dispatch.ObanWorker.perform/1" do
    test "calls adapter and records attempt on success" do
      %{notification: notification} = DispatchHelpers.create_notification()

      {:ok, delivery} =
        Deliveries.plan_delivery(notification.id, :in_app,
          tenant_id: "default",
          actor_id: "system"
        )

      assert :ok = perform_job(ObanWorker, %{delivery_id: delivery.id})

      updated = Deliveries.get_delivery!(delivery.id)
      assert updated.status == :succeeded

      attempts =
        Chimeway.Repo.all(
          from(a in Chimeway.DeliveryAttempt, where: a.delivery_id == ^delivery.id)
        )

      assert length(attempts) == 1
    end

    test "returns :ok immediately for terminal delivery without adapter call" do
      Chimeway.Adapters.Test.clear()
      %{notification: notification} = DispatchHelpers.create_notification()

      {:ok, delivery} =
        Deliveries.plan_delivery(notification.id, :in_app,
          tenant_id: "default",
          actor_id: "system"
        )

      {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)
      Deliveries.record_attempt(dispatched, %{outcome: :succeeded, provider_response: %{}})

      assert :ok = perform_job(ObanWorker, %{delivery_id: delivery.id})
      assert Chimeway.Adapters.Test.delivered_messages() == []
    end

    test "records :failed attempt when adapter returns temporary error" do
      Application.put_env(:chimeway, :adapter, Chimeway.FailingTestAdapter)
      %{notification: notification} = DispatchHelpers.create_notification()

      {:ok, delivery} =
        Deliveries.plan_delivery(notification.id, :in_app,
          tenant_id: "default",
          actor_id: "system"
        )

      perform_job(ObanWorker, %{delivery_id: delivery.id})

      updated = Deliveries.get_delivery!(delivery.id)
      assert updated.status == :failed
    after
      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
    end

    test "POLC-03: suppresses delayed fallback deliveries as already_read at perform time" do
      # POLC-03: worker perform checkpoint suppresses already-read fallback deliveries.
      Chimeway.Adapters.Test.clear()

      fixture =
        DispatchHelpers.create_pending_delivery(
          notification_key: "oban.delayed.fallback.perform",
          delay_fallback: true
        )

      DispatchHelpers.mark_notification_read(fixture)

      assert :ok = perform_job(ObanWorker, %{delivery_id: fixture.delivery.id})

      updated = Deliveries.get_delivery!(fixture.delivery.id)

      assert DispatchHelpers.delivery_signature(updated) ==
               DispatchHelpers.already_read_suppression_signature()

      assert Chimeway.Adapters.Test.delivered_messages() == []
    end

    test "INTG-02: uses preferred channel_adapter_configs for sms_custom delivery" do
      # INTG-02: Oban worker path resolves preferred string-keyed custom channel config.
      previous_channel_configs = Application.get_env(:chimeway, :channel_adapter_configs)
      previous_legacy_config = Application.get_env(:chimeway, :adapter_sms_custom)
      previous_capture_pid = Application.get_env(:chimeway, :adapter_capture_pid)

      on_exit(fn ->
        restore_env(:channel_adapter_configs, previous_channel_configs)
        restore_env(:adapter_sms_custom, previous_legacy_config)
        restore_env(:adapter_capture_pid, previous_capture_pid)
      end)

      Application.put_env(:chimeway, :adapter, Chimeway.Test.ObanCaptureConfigAdapter)
      Application.put_env(:chimeway, :adapter_capture_pid, self())

      Application.put_env(:chimeway, :channel_adapter_configs, %{
        "sms_custom" => [provider: "acme_sms", timeout_ms: 1500]
      })

      Application.delete_env(:chimeway, :adapter_sms_custom)

      fixture = DispatchHelpers.create_pending_delivery(channel: "sms_custom")
      assert :ok = perform_job(ObanWorker, %{delivery_id: fixture.delivery.id})
      assert_receive {:adapter_config, [provider: "acme_sms", timeout_ms: 1500]}
      assert Deliveries.get_delivery!(fixture.delivery.id).status == :succeeded
    end

    test "INTG-02: supports legacy adapter_sms_custom fallback for sms_custom delivery" do
      # INTG-02: Oban worker path keeps legacy adapter_<channel> compatibility.
      previous_channel_configs = Application.get_env(:chimeway, :channel_adapter_configs)
      previous_legacy_config = Application.get_env(:chimeway, :adapter_sms_custom)
      previous_capture_pid = Application.get_env(:chimeway, :adapter_capture_pid)

      on_exit(fn ->
        restore_env(:channel_adapter_configs, previous_channel_configs)
        restore_env(:adapter_sms_custom, previous_legacy_config)
        restore_env(:adapter_capture_pid, previous_capture_pid)
      end)

      Application.put_env(:chimeway, :adapter, Chimeway.Test.ObanCaptureConfigAdapter)
      Application.put_env(:chimeway, :adapter_capture_pid, self())
      Application.delete_env(:chimeway, :channel_adapter_configs)
      Application.put_env(:chimeway, :adapter_sms_custom, provider: "legacy_sms")

      fixture = DispatchHelpers.create_pending_delivery(channel: "sms_custom")
      assert :ok = perform_job(ObanWorker, %{delivery_id: fixture.delivery.id})
      assert_receive {:adapter_config, [provider: "legacy_sms"]}
      assert Deliveries.get_delivery!(fixture.delivery.id).status == :succeeded
    end
  end

  defp restore_env(key, nil), do: Application.delete_env(:chimeway, key)
  defp restore_env(key, value), do: Application.put_env(:chimeway, key, value)
end
