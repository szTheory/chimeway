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

  describe "perform-time suppression parity" do
    # POLC-02: delayed fallback checks read state at perform checkpoint.
    test "already-read delayed fallback delivery is suppressed with no attempt" do
      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
      Chimeway.Adapters.Test.clear()

      fixture =
        DispatchHelpers.create_pending_delivery(
          notification_key: "sync.perform.suppression",
          delay_fallback: true
        )

      DispatchHelpers.mark_notification_read(fixture)

      assert {:ok, [{:ok, delivery}]} = Sync.dispatch([fixture.notification], [])
      assert DispatchHelpers.delivery_signature(delivery) == %{
               status: :suppressed,
               suppression_reason: "already_read",
               policy_checkpoint: "perform",
               attempt_count: 0
             }

      assert Chimeway.Adapters.Test.delivered_messages() == []
    end
  end
end
