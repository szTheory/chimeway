defmodule Chimeway.Orchestration.DispatchGatingTest do
  use Chimeway.DataCase, async: false
  use Oban.Testing, repo: Chimeway.Repo

  alias Chimeway.{Deliveries, DeliveryAttempt, Dispatch.Oban, Dispatch.ObanWorker, Dispatch.Sync, Repo}
  alias Chimeway.Policy.Settings
  alias Chimeway.Test.DispatchHelpers

  defmodule DigestHeldNotifier do
    use Chimeway.Notifier

    @impl true
    def notification_key, do: "dispatch-gating.digest-held"

    @impl true
    def version, do: 1

    @impl true
    def recipients(_params), do: {:ok, [%{recipient_identity: "user:digest-held"}]}

    @impl true
    def build(_params, recipient), do: {:ok, %{recipient: recipient}}

    @impl true
    def channels(_params, _recipient), do: {:ok, [:email]}

    @impl true
    def orchestration(_params, _recipient), do: {:ok, :digest_held}
  end

  setup do
    previous_adapter = Application.get_env(:chimeway, :adapter, Chimeway.Adapters.Logger)
    previous_dispatcher = Application.get_env(:chimeway, :dispatcher, Chimeway.Dispatch.Sync)

    Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
    Application.put_env(:chimeway, :dispatcher, Chimeway.Dispatch.Oban)
    Chimeway.Adapters.Test.clear()

    on_exit(fn ->
      Application.put_env(:chimeway, :adapter, previous_adapter)
      Application.put_env(:chimeway, :dispatcher, previous_dispatcher)
      Chimeway.Adapters.Test.clear()
    end)

    :ok
  end

  test "sync dispatch only executes deliveries whose orchestration_state is ready" do
    ready_fixture = DispatchHelpers.create_notification(notification_key: "dispatch-gating.ready")

    deferred_fixture =
      DispatchHelpers.create_notification(
        notification_key: "dispatch-gating.deferred",
        recipient_identity: "user:dispatch-gating-deferred"
      )

    assert {:ok, _settings} =
             Settings.upsert_settings(%{
               recipient_id: "user:dispatch-gating-deferred",
               quiet_hours_start_minute: 22 * 60,
               quiet_hours_end_minute: 8 * 60,
               time_zone: "America/New_York"
             })

    digest_fixture =
      DispatchHelpers.create_notification(notification_key: "dispatch-gating.digest-held")

    assert {:ok, [{:ok, ready_delivery}]} = Sync.dispatch([ready_fixture.notification], [])

    assert {:ok, [{:ok, deferred_delivery}]} =
             Sync.dispatch(
               [deferred_fixture.notification],
               evaluation_time: ~U[2026-01-15 03:30:00Z]
             )

    assert {:ok, [{:ok, digest_delivery}]} =
             Sync.dispatch(
               [digest_fixture.notification],
               notifier: DigestHeldNotifier,
               trigger_params: %{}
             )

    assert ready_delivery.orchestration_state == :ready
    assert ready_delivery.status == :succeeded

    assert deferred_delivery.orchestration_state == :deferred
    assert deferred_delivery.status == :pending
    assert attempt_count(deferred_delivery.id) == 0

    assert digest_delivery.orchestration_state == :digest_held
    assert digest_delivery.status == :pending
    assert attempt_count(digest_delivery.id) == 0
  end

  test "oban enqueue and worker perform paths short-circuit deferred and digest-held deliveries" do
    deferred_fixture =
      DispatchHelpers.create_notification(
        notification_key: "dispatch-gating.oban.deferred",
        recipient_identity: "user:dispatch-gating-oban-deferred"
      )

    assert {:ok, _settings} =
             Settings.upsert_settings(%{
               recipient_id: "user:dispatch-gating-oban-deferred",
               quiet_hours_start_minute: 22 * 60,
               quiet_hours_end_minute: 8 * 60,
               time_zone: "America/New_York"
             })

    digest_fixture =
      DispatchHelpers.create_notification(notification_key: "dispatch-gating.oban.digest-held")

    assert {:ok, [deferred_delivery]} =
             Oban.dispatch(
               [deferred_fixture.notification],
               evaluation_time: ~U[2026-01-15 03:30:00Z]
             )

    assert {:ok, [digest_delivery]} =
             Oban.dispatch(
               [digest_fixture.notification],
               notifier: DigestHeldNotifier,
               trigger_params: %{}
             )

    refute_enqueued(worker: ObanWorker, args: %{delivery_id: deferred_delivery.id})
    refute_enqueued(worker: ObanWorker, args: %{delivery_id: digest_delivery.id})

    assert :ok = perform_job(ObanWorker, %{delivery_id: deferred_delivery.id})
    assert :ok = perform_job(ObanWorker, %{delivery_id: digest_delivery.id})

    assert Deliveries.get_delivery!(deferred_delivery.id).status == :pending
    assert Deliveries.get_delivery!(deferred_delivery.id).orchestration_state == :deferred
    assert attempt_count(deferred_delivery.id) == 0

    assert Deliveries.get_delivery!(digest_delivery.id).status == :pending
    assert Deliveries.get_delivery!(digest_delivery.id).orchestration_state == :digest_held
    assert attempt_count(digest_delivery.id) == 0
  end

  defp attempt_count(delivery_id) do
    Repo.aggregate(from(a in DeliveryAttempt, where: a.delivery_id == ^delivery_id), :count, :id)
  end
end
