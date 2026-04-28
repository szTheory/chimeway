defmodule Chimeway.Orchestration.DeliveryPlanningTest do
  use Chimeway.DataCase, async: true

  alias Chimeway.{Delivery, DeliveryPlanning, Repo}
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification

  defmodule DigestEmailNotifier do
    use Chimeway.Notifier

    @impl true
    def notification_key, do: "delivery-planning.digest"

    @impl true
    def version, do: 1

    @impl true
    def recipients(_params), do: {:ok, [%{recipient_identity: "user-planning"}]}

    @impl true
    def build(_params, recipient), do: {:ok, %{recipient: recipient}}

    @impl true
    def channels(_params, _recipient), do: {:ok, [:email]}

    @impl true
    def orchestration(_params, _recipient), do: {:ok, [email: :digest]}
  end

  test "planner keeps one canonical row when a channel is declared as digest-held" do
    notification = insert_notification("user-planning")

    assert {:ok, [delivery]} =
             DeliveryPlanning.plan_notification(notification,
               notifier: DigestEmailNotifier,
               trigger_params: %{}
             )

    assert delivery.orchestration_state == :digest_held
    assert delivery.planning_reason == "digest_rule"

    assert {:ok, [replanned]} =
             DeliveryPlanning.plan_notification(notification,
               notifier: DigestEmailNotifier,
               trigger_params: %{}
             )

    assert replanned.id == delivery.id
    assert replanned.orchestration_state == :digest_held
    assert Repo.aggregate(Delivery, :count, :id) == 1
  end

  defp insert_notification(recipient_identity) do
    {:ok, event} =
      %Event{}
      |> Event.changeset(%{
        notification_key: "delivery-planning.test",
        notification_version: 1,
        idempotency_key: "delivery-planning-#{System.unique_integer()}",
        payload: %{}
      })
      |> Repo.insert()

    {:ok, notification} =
      %Notification{}
      |> Notification.changeset(%{
        event_id: event.id,
        recipient_identity: recipient_identity,
        recipient_type: "user",
        metadata: %{}
      })
      |> Repo.insert()

    notification
  end
end
