defmodule Chimeway.Test.SyncCustomChannelNotifier do
  def channels(_trigger_params, _recipient), do: {:ok, ["sms_custom"]}
end

defmodule Chimeway.Test.SyncCaptureConfigAdapter do
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

defmodule Chimeway.Dispatch.SyncTest do
  use Chimeway.DataCase, async: false

  alias Chimeway.DeliveryAttempt
  alias Chimeway.Dispatch.Sync
  alias Chimeway.Repo
  alias Chimeway.Test.DispatchHelpers

  setup do
    previous_adapter = Application.get_env(:chimeway, :adapter, Chimeway.Adapters.Logger)

    on_exit(fn ->
      Application.put_env(:chimeway, :adapter, previous_adapter)
    end)

    :ok
  end

  # ---- dispatch/2 ----

  describe "dispatch/2 with {:ok, meta} adapter response" do
    test "creates attempt with outcome :succeeded and transitions delivery to :succeeded" do
      %{notification: notification} = DispatchHelpers.create_notification()
      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
      Chimeway.Adapters.Test.clear()

      assert {:ok, results} = Sync.dispatch([notification], [])
      assert [{:ok, delivery}] = results

      assert delivery.status == :succeeded

      attempt =
        Repo.one!(
          from(a in DeliveryAttempt,
            where: a.delivery_id == ^delivery.id
          )
        )

      assert attempt.outcome == :succeeded
    end

    test "stores delivery in test adapter" do
      %{notification: notification} = DispatchHelpers.create_notification()
      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
      Chimeway.Adapters.Test.clear()

      Sync.dispatch([notification], [])

      assert [_] = Chimeway.Adapters.Test.delivered_messages()
    end
  end

  describe "dispatch/2 with {:error, :temporary, detail} adapter response" do
    test "creates attempt with outcome :failed and transitions delivery to :failed" do
      %{notification: notification} = DispatchHelpers.create_notification()

      defmodule TemporaryErrorAdapter do
        @behaviour Chimeway.Adapter
        def deliver(_delivery, _config), do: {:error, :temporary, %{reason: "timeout"}}
      end

      Application.put_env(:chimeway, :adapter, TemporaryErrorAdapter)

      assert {:ok, results} = Sync.dispatch([notification], [])
      assert [{:ok, delivery}] = results

      assert delivery.status == :failed

      attempt = Repo.one!(from(a in DeliveryAttempt, where: a.delivery_id == ^delivery.id))
      assert attempt.outcome == :failed
    end
  end

  describe "dispatch/2 with {:error, :permanent, detail} adapter response" do
    test "creates attempt with outcome :rejected and transitions delivery to :failed" do
      %{notification: notification} = DispatchHelpers.create_notification()

      defmodule PermanentErrorAdapter do
        @behaviour Chimeway.Adapter
        def deliver(_delivery, _config), do: {:error, :permanent, %{reason: "invalid_address"}}
      end

      Application.put_env(:chimeway, :adapter, PermanentErrorAdapter)

      assert {:ok, results} = Sync.dispatch([notification], [])
      assert [{:ok, delivery}] = results

      assert delivery.status == :failed

      attempt = Repo.one!(from(a in DeliveryAttempt, where: a.delivery_id == ^delivery.id))
      assert attempt.outcome == :rejected
    end
  end

  describe "dispatch/2 with {:error, :bounced, detail} adapter response" do
    test "creates attempt with outcome :bounced and transitions delivery to :failed" do
      %{notification: notification} = DispatchHelpers.create_notification()

      defmodule BouncedErrorAdapter do
        @behaviour Chimeway.Adapter
        def deliver(_delivery, _config), do: {:error, :bounced, %{reason: "hard_bounce"}}
      end

      Application.put_env(:chimeway, :adapter, BouncedErrorAdapter)

      assert {:ok, results} = Sync.dispatch([notification], [])
      assert [{:ok, delivery}] = results

      assert delivery.status == :failed

      attempt = Repo.one!(from(a in DeliveryAttempt, where: a.delivery_id == ^delivery.id))
      assert attempt.outcome == :bounced
    end
  end

  describe "terminal state guard" do
    test "dispatch on :succeeded delivery returns {:ok, delivery} without creating a new attempt" do
      %{notification: notification} = DispatchHelpers.create_notification()
      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
      Chimeway.Adapters.Test.clear()

      # First dispatch succeeds the delivery
      assert {:ok, [{:ok, delivery}]} = Sync.dispatch([notification], [])
      assert delivery.status == :succeeded

      attempt_count_before = Repo.aggregate(DeliveryAttempt, :count, :id)

      # Second dispatch: plan_delivery returns the existing :succeeded delivery
      assert {:ok, [{:ok, returned_delivery}]} = Sync.dispatch([notification], [])
      assert returned_delivery.status == :succeeded

      attempt_count_after = Repo.aggregate(DeliveryAttempt, :count, :id)

      # No new attempt row was created
      assert attempt_count_before == attempt_count_after
    end
  end

  describe "planning-time policy suppression parity" do
    # POLC-01 / POLC-02: planning checkpoint suppression happens before adapter execution.
    test "disabled channel preference suppresses during planning before adapter execution" do
      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
      Chimeway.Adapters.Test.clear()

      fixture = DispatchHelpers.create_notification(notification_key: "sync.planning.suppression")
      DispatchHelpers.disable_channel_preference(fixture, :in_app)

      assert {:ok, [{:ok, delivery}]} = Sync.dispatch([fixture.notification], [])
      assert DispatchHelpers.delivery_signature(delivery) == %{
               status: :suppressed,
               suppression_reason: "channel_disabled",
               policy_checkpoint: "planning",
               attempt_count: 0
             }

      assert Chimeway.Adapters.Test.delivered_messages() == []
    end
  end

  describe "dispatch contract parity for trigger consumers" do
    test "DLVR-04: sync dispatch preserves planning_failed error tagging" do
      # DLVR-04: trigger outcome normalization depends on tagged planning failures.
      %{notification: notification} = DispatchHelpers.create_notification()

      defmodule SyncPlanningFailureNotifier do
        def channels(_trigger_params, _recipient), do: {:error, :forced_planning_failure}
      end

      assert {:error, {:planning_failed, {:channels_resolution_failed, reason}}} =
               Sync.dispatch(
                 [notification],
                 notifier: SyncPlanningFailureNotifier,
                 trigger_params: %{}
               )

      assert reason == :forced_planning_failure
    end
  end

  describe "perform-time suppression parity" do
    # POLC-03: delayed fallback checks read state at perform checkpoint.
    test "POLC-03: already-read delayed fallback delivery is suppressed with no attempt" do
      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
      Chimeway.Adapters.Test.clear()

      fixture =
        DispatchHelpers.create_pending_delivery(
          notification_key: "sync.perform.suppression",
          delay_fallback: true
        )

      DispatchHelpers.mark_notification_read(fixture)

      assert {:ok, [{:ok, delivery}]} = Sync.dispatch([fixture.notification], [])
      assert DispatchHelpers.delivery_signature(delivery) ==
               DispatchHelpers.already_read_suppression_signature()

      assert Chimeway.Adapters.Test.delivered_messages() == []
    end
  end

  describe "custom channel adapter config resolution" do
    test "INTG-02: sync dispatch uses channel_adapter_configs for sms_custom" do
      # INTG-02: custom channel adapter config remains deterministic in shared executor seam.
      previous_channel_configs = Application.get_env(:chimeway, :channel_adapter_configs)
      previous_legacy_config = Application.get_env(:chimeway, :adapter_sms_custom)
      previous_capture_pid = Application.get_env(:chimeway, :adapter_capture_pid)

      on_exit(fn ->
        restore_env(:channel_adapter_configs, previous_channel_configs)
        restore_env(:adapter_sms_custom, previous_legacy_config)
        restore_env(:adapter_capture_pid, previous_capture_pid)
      end)

      Application.put_env(:chimeway, :adapter, Chimeway.Test.SyncCaptureConfigAdapter)
      Application.put_env(:chimeway, :adapter_capture_pid, self())

      Application.put_env(:chimeway, :channel_adapter_configs, %{
        "sms_custom" => [provider: "acme_sms", timeout_ms: 1500]
      })

      Application.delete_env(:chimeway, :adapter_sms_custom)

      fixture = DispatchHelpers.create_notification(notification_key: "sync.custom.sms")

      assert {:ok, [{:ok, _delivery}]} =
               Sync.dispatch(
                 [fixture.notification],
                 notifier: Chimeway.Test.SyncCustomChannelNotifier
               )

      assert_receive {:adapter_config, [provider: "acme_sms", timeout_ms: 1500]}
    end

    test "INTG-02: sync dispatch supports legacy adapter_sms_custom fallback" do
      # INTG-02: legacy host-app adapter_<channel> env keys remain compatible.
      previous_channel_configs = Application.get_env(:chimeway, :channel_adapter_configs)
      previous_legacy_config = Application.get_env(:chimeway, :adapter_sms_custom)
      previous_capture_pid = Application.get_env(:chimeway, :adapter_capture_pid)

      on_exit(fn ->
        restore_env(:channel_adapter_configs, previous_channel_configs)
        restore_env(:adapter_sms_custom, previous_legacy_config)
        restore_env(:adapter_capture_pid, previous_capture_pid)
      end)

      Application.put_env(:chimeway, :adapter, Chimeway.Test.SyncCaptureConfigAdapter)
      Application.put_env(:chimeway, :adapter_capture_pid, self())
      Application.delete_env(:chimeway, :channel_adapter_configs)
      Application.put_env(:chimeway, :adapter_sms_custom, provider: "legacy_sms")

      fixture = DispatchHelpers.create_notification(notification_key: "sync.legacy.sms")

      assert {:ok, [{:ok, _delivery}]} =
               Sync.dispatch(
                 [fixture.notification],
                 notifier: Chimeway.Test.SyncCustomChannelNotifier
               )

      assert_receive {:adapter_config, [provider: "legacy_sms"]}
    end
  end

  defp restore_env(key, nil), do: Application.delete_env(:chimeway, key)
  defp restore_env(key, value), do: Application.put_env(:chimeway, key, value)
end
