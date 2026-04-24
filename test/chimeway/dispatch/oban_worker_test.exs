defmodule Chimeway.Test.ObanWorkerFailingAdapter do
  @behaviour Chimeway.Adapter

  @impl Chimeway.Adapter
  def deliver(_delivery, _config), do: {:error, :temporary, %{reason: "test_failure"}}
end

defmodule Chimeway.Test.ObanWorkerCaptureConfigAdapter do
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

defmodule Chimeway.Dispatch.ObanWorkerTest do
  use Chimeway.DataCase, async: false
  use Oban.Testing, repo: Chimeway.Repo

  @moduletag :oban

  import Chimeway.Test.DispatchHelpers

  alias Chimeway.{Deliveries, DeliveryAttempt, Dispatch.ObanWorker, Repo}

  setup do
    Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
    Chimeway.Adapters.Test.clear()

    on_exit(fn ->
      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Logger)
    end)

    :ok
  end

  describe "perform/1 success path" do
    test "records one attempt and transitions delivery to :succeeded" do
      %{delivery: delivery} = create_pending_delivery()

      assert :ok = perform_job(ObanWorker, %{delivery_id: delivery.id})

      updated = Deliveries.get_delivery!(delivery.id)
      assert updated.status == :succeeded

      attempts =
        Repo.all(from(attempt in DeliveryAttempt, where: attempt.delivery_id == ^delivery.id))

      assert length(attempts) == 1
      assert hd(attempts).outcome == :succeeded
    end
  end

  describe "perform/1 idempotency" do
    test "running perform twice creates exactly one attempt row" do
      %{delivery: delivery} = create_pending_delivery()

      assert :ok = perform_job(ObanWorker, %{delivery_id: delivery.id})
      assert :ok = perform_job(ObanWorker, %{delivery_id: delivery.id})

      attempts =
        Repo.all(from(attempt in DeliveryAttempt, where: attempt.delivery_id == ^delivery.id))

      assert length(attempts) == 1
    end
  end

  describe "terminal state short-circuit" do
    test "returns :ok for :succeeded delivery without adapter call" do
      %{delivery: delivery} = create_pending_delivery()
      {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)

      {:ok, _result} =
        Deliveries.record_attempt(dispatched, %{outcome: :succeeded, provider_response: %{}})

      Chimeway.Adapters.Test.clear()

      assert :ok = perform_job(ObanWorker, %{delivery_id: delivery.id})
      assert Chimeway.Adapters.Test.delivered_messages() == []
    end

    test "returns :ok for :suppressed delivery without adapter call" do
      %{delivery: delivery} = create_pending_delivery()
      {:ok, _suppressed} = Deliveries.suppress_delivery(delivery, :channel_disabled)
      Chimeway.Adapters.Test.clear()

      assert :ok = perform_job(ObanWorker, %{delivery_id: delivery.id})
      assert Chimeway.Adapters.Test.delivered_messages() == []
    end

    test "returns :ok for :cancelled delivery without adapter call" do
      %{delivery: delivery} = create_pending_delivery()
      {:ok, _cancelled} = Deliveries.transition_status(delivery, :cancelled)
      Chimeway.Adapters.Test.clear()

      assert :ok = perform_job(ObanWorker, %{delivery_id: delivery.id})
      assert Chimeway.Adapters.Test.delivered_messages() == []
    end
  end

  describe "adapter error path and retry" do
    test "transitions delivery to :failed when adapter returns temporary error" do
      Application.put_env(:chimeway, :adapter, Chimeway.Test.ObanWorkerFailingAdapter)
      %{delivery: delivery} = create_pending_delivery()

      assert :ok = perform_job(ObanWorker, %{delivery_id: delivery.id})

      updated = Deliveries.get_delivery!(delivery.id)
      assert updated.status == :failed

      attempts =
        Repo.all(from(attempt in DeliveryAttempt, where: attempt.delivery_id == ^delivery.id))

      assert length(attempts) == 1
      assert hd(attempts).outcome == :failed
    after
      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
    end

    test "retries failed delivery and succeeds with two attempts" do
      Application.put_env(:chimeway, :adapter, Chimeway.Test.ObanWorkerFailingAdapter)
      %{delivery: delivery} = create_pending_delivery()

      assert :ok = perform_job(ObanWorker, %{delivery_id: delivery.id})
      assert Deliveries.get_delivery!(delivery.id).status == :failed

      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
      assert :ok = perform_job(ObanWorker, %{delivery_id: delivery.id})

      updated = Deliveries.get_delivery!(delivery.id)
      assert updated.status == :succeeded

      attempt_count =
        Repo.aggregate(
          from(attempt in DeliveryAttempt, where: attempt.delivery_id == ^delivery.id),
          :count
        )

      assert attempt_count == 2
    after
      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
    end
  end

  describe "perform-time delayed fallback suppression" do
    test "already-read delayed fallback delivery records no attempts (POLC-03)" do
      fixture =
        create_pending_delivery(
          notification_key: "oban.worker.delayed.fallback",
          delay_fallback: true
        )

      mark_notification_read(fixture)
      Chimeway.Adapters.Test.clear()

      assert :ok = perform_job(ObanWorker, %{delivery_id: fixture.delivery.id})

      updated = Deliveries.get_delivery!(fixture.delivery.id)
      assert delivery_signature(updated) == already_read_suppression_signature()
      assert Chimeway.Adapters.Test.delivered_messages() == []

      attempt_count =
        Repo.aggregate(
          from(attempt in DeliveryAttempt, where: attempt.delivery_id == ^fixture.delivery.id),
          :count
        )

      assert attempt_count == 0
    end
  end

  describe "custom channel adapter config resolution" do
    test "INTG-02: oban worker uses channel_adapter_configs for sms_custom" do
      # INTG-02: shared executor resolves preferred string-keyed custom channel config.
      previous_channel_configs = Application.get_env(:chimeway, :channel_adapter_configs)
      previous_legacy_config = Application.get_env(:chimeway, :adapter_sms_custom)
      previous_capture_pid = Application.get_env(:chimeway, :adapter_capture_pid)

      on_exit(fn ->
        restore_env(:channel_adapter_configs, previous_channel_configs)
        restore_env(:adapter_sms_custom, previous_legacy_config)
        restore_env(:adapter_capture_pid, previous_capture_pid)
      end)

      Application.put_env(:chimeway, :adapter, Chimeway.Test.ObanWorkerCaptureConfigAdapter)
      Application.put_env(:chimeway, :adapter_capture_pid, self())

      Application.put_env(:chimeway, :channel_adapter_configs, %{
        "sms_custom" => [provider: "acme_sms", timeout_ms: 1500]
      })

      Application.delete_env(:chimeway, :adapter_sms_custom)

      fixture = create_pending_delivery(channel: "sms_custom")
      assert :ok = perform_job(ObanWorker, %{delivery_id: fixture.delivery.id})
      assert_receive {:adapter_config, [provider: "acme_sms", timeout_ms: 1500]}
    end

    test "INTG-02: oban worker supports legacy adapter_sms_custom fallback" do
      # INTG-02: legacy adapter_<channel> key lookup remains backward compatible.
      previous_channel_configs = Application.get_env(:chimeway, :channel_adapter_configs)
      previous_legacy_config = Application.get_env(:chimeway, :adapter_sms_custom)
      previous_capture_pid = Application.get_env(:chimeway, :adapter_capture_pid)

      on_exit(fn ->
        restore_env(:channel_adapter_configs, previous_channel_configs)
        restore_env(:adapter_sms_custom, previous_legacy_config)
        restore_env(:adapter_capture_pid, previous_capture_pid)
      end)

      Application.put_env(:chimeway, :adapter, Chimeway.Test.ObanWorkerCaptureConfigAdapter)
      Application.put_env(:chimeway, :adapter_capture_pid, self())
      Application.delete_env(:chimeway, :channel_adapter_configs)
      Application.put_env(:chimeway, :adapter_sms_custom, provider: "legacy_sms")

      fixture = create_pending_delivery(channel: "sms_custom")
      assert :ok = perform_job(ObanWorker, %{delivery_id: fixture.delivery.id})
      assert_receive {:adapter_config, [provider: "legacy_sms"]}
    end
  end

  defp restore_env(key, nil), do: Application.delete_env(:chimeway, key)
  defp restore_env(key, value), do: Application.put_env(:chimeway, key, value)
end
