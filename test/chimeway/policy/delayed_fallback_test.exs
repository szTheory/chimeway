defmodule ChimewayTest.Notifiers.InvalidDelayedFallbackSubset do
  @behaviour Chimeway.Notifier

  def notification_key, do: "test.policy.invalid_delayed_fallback_subset"
  def version, do: 1

  def recipients(_params),
    do: {:ok, [%{recipient_identity: "user:guardrail", recipient_type: "user"}]}

  def build(_params, _recipient), do: {:ok, %{title: "Invalid delayed fallback subset"}}
  def channels(_params, _recipient), do: {:ok, [:in_app, :email]}
  def delayed_fallback_channels(_params, _recipient), do: {:ok, [:sms]}
end

defmodule ChimewayTest.Notifiers.InvalidDelayedFallbackInApp do
  @behaviour Chimeway.Notifier

  def notification_key, do: "test.policy.invalid_delayed_fallback_in_app"
  def version, do: 1

  def recipients(_params),
    do: {:ok, [%{recipient_identity: "user:guardrail", recipient_type: "user"}]}

  def build(_params, _recipient), do: {:ok, %{title: "Invalid delayed fallback in_app"}}
  def channels(_params, _recipient), do: {:ok, [:in_app, :email]}
  def delayed_fallback_channels(_params, _recipient), do: {:ok, [:in_app]}
end

defmodule ChimewayTest.Notifiers.ValidDelayedFallbackSubset do
  @behaviour Chimeway.Notifier

  def notification_key, do: "test.policy.valid_delayed_fallback_subset"
  def version, do: 1

  def recipients(_params),
    do: {:ok, [%{recipient_identity: "user:guardrail", recipient_type: "user"}]}

  def build(_params, _recipient), do: {:ok, %{"headline" => "test", "body" => "test", "primary_action" => %{"label" => "test", "url" => "http://test"}, "subject" => "test", "html_body" => "test", "text_body" => "test"}}
  def channels(_params, _recipient), do: {:ok, [:in_app, :email]}
  def delayed_fallback_channels(_params, _recipient), do: {:ok, [:email]}
end

defmodule Chimeway.Policy.DelayedFallbackTest do
  use Chimeway.DataCase, async: false
  use Oban.Testing, repo: Chimeway.Repo

  @moduletag :oban
  @moduletag :policy

  import Chimeway.Test.DispatchHelpers

  alias Chimeway.{Deliveries, Dispatch.ObanWorker, Dispatch.Sync, Preferences, Repo}
  alias Chimeway.DeliveryAttempt

  setup do
    Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
    Chimeway.Adapters.Test.clear()

    on_exit(fn ->
      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Logger)
    end)

    :ok
  end

  describe "delay_fallback enabled with unread notification" do
    test "proceeds to adapter and marks delivery succeeded" do
      %{delivery: delivery} = create_pending_delivery(delay_fallback: true)

      assert :ok = perform_job(ObanWorker, %{delivery_id: delivery.id})

      updated = Deliveries.get_delivery!(delivery.id)
      assert updated.status == :succeeded
      assert is_nil(updated.suppression_reason)
      assert Chimeway.Adapters.Test.delivered_messages() != []
    end
  end

  describe "delay_fallback enabled with read notification" do
    test "suppresses with already_read and skips adapter call" do
      ctx = create_pending_delivery(delay_fallback: true)
      mark_notification_read(ctx)
      Chimeway.Adapters.Test.clear()

      assert :ok = perform_job(ObanWorker, %{delivery_id: ctx.delivery.id})

      updated = Deliveries.get_delivery!(ctx.delivery.id)
      assert updated.status == :suppressed
      assert updated.suppression_reason == "already_read"
      assert Chimeway.Adapters.Test.delivered_messages() == []
    end

    test "does not record delivery attempts when suppressed before dispatch" do
      ctx = create_pending_delivery(delay_fallback: true)
      mark_notification_read(ctx)

      assert :ok = perform_job(ObanWorker, %{delivery_id: ctx.delivery.id})

      attempt_count =
        Repo.aggregate(
          from(attempt in DeliveryAttempt, where: attempt.delivery_id == ^ctx.delivery.id),
          :count
        )

      assert attempt_count == 0
    end
  end

  describe "preference disabled after enqueue" do
    test "suppresses at perform time with channel_disabled reason" do
      ctx = create_pending_delivery(delay_fallback: true, notification_key: "delay.pref.disabled")

      assert {:ok, _pref} =
               Preferences.upsert_preference(%{
                 recipient_id: ctx.notification.recipient_identity,
                 notification_key: ctx.event.notification_key,
                 channel: ctx.delivery.channel,
                 enabled: false
               })

      Chimeway.Adapters.Test.clear()
      assert :ok = perform_job(ObanWorker, %{delivery_id: ctx.delivery.id})

      updated = Deliveries.get_delivery!(ctx.delivery.id)
      assert updated.status == :suppressed
      assert updated.suppression_reason == "channel_disabled"
      assert Chimeway.Adapters.Test.delivered_messages() == []
    end
  end

  describe "sync dispatcher delayed fallback parity" do
    test "sync path suppresses read notifications with already_read reason" do
      ctx = create_pending_delivery(delay_fallback: true)
      mark_notification_read(ctx)
      Chimeway.Adapters.Test.clear()

      assert {:ok, results} = Sync.dispatch([ctx.notification], [])
      assert [{:ok, _delivery}] = results

      updated = Deliveries.get_delivery!(ctx.delivery.id)
      assert updated.status == :suppressed
      assert updated.suppression_reason == "already_read"
      assert Chimeway.Adapters.Test.delivered_messages() == []
    end
  end

  describe "planner guardrails for delayed_fallback_channels" do
    test "rejects delayed_fallback channels outside notifier channels subset" do
      fixture = create_notification(notification_key: "delay.guardrail.invalid_subset")

      assert {:error, {:planning_failed, {:invalid_delayed_fallback_channels, invalid_channels}}} =
               Sync.dispatch([fixture.notification],
                 notifier: ChimewayTest.Notifiers.InvalidDelayedFallbackSubset,
                 trigger_params: %{}
               )

      assert invalid_channels == ["sms"]
      assert Chimeway.Adapters.Test.delivered_messages() == []
    end

    test "rejects delayed_fallback declaration for in_app channel" do
      fixture = create_notification(notification_key: "delay.guardrail.invalid_in_app")

      assert {:error, {:planning_failed, {:invalid_delayed_fallback_channels, invalid_channels}}} =
               Sync.dispatch([fixture.notification],
                 notifier: ChimewayTest.Notifiers.InvalidDelayedFallbackInApp,
                 trigger_params: %{}
               )

      assert invalid_channels == ["in_app"]
      assert Chimeway.Adapters.Test.delivered_messages() == []
    end

    test "accepts valid delayed_fallback subset declarations" do
      fixture = create_notification(notification_key: "delay.guardrail.valid_subset")

      assert {:ok, results} =
               Sync.dispatch([fixture.notification],
                 notifier: ChimewayTest.Notifiers.ValidDelayedFallbackSubset,
                 trigger_params: %{}
               )

      deliveries =
        results
        |> Enum.map(fn {:ok, delivery} -> delivery end)
        |> Map.new(fn delivery -> {delivery.channel, delivery} end)

      assert Map.fetch!(deliveries, "email").delay_fallback
      refute Map.fetch!(deliveries, "in_app").delay_fallback
    end
  end
end
