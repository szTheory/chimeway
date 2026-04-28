defmodule Chimeway.Orchestration.PlanningDeclarationsTest do
  use Chimeway.DataCase, async: true

  alias Chimeway.{Delivery, DeliveryPlanning, Repo}
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification
  import Ecto.Query, only: [from: 2]

  defmodule DigestEmailNotifier do
    use Chimeway.Notifier

    @impl true
    def notification_key, do: "orchestration.digest"

    @impl true
    def version, do: 1

    @impl true
    def recipients(_params), do: {:ok, [%{recipient_identity: "user-digest"}]}

    @impl true
    def build(_params, recipient), do: {:ok, %{recipient: recipient}}

    @impl true
    def channels(_params, _recipient), do: {:ok, [:email]}

    @impl true
    def orchestration(_params, _recipient),
      do: {:ok, [email: {:digest, [digest_key: "thread:123"]}]}
  end

  defmodule ImmediateNotifier do
    use Chimeway.Notifier

    @impl true
    def notification_key, do: "orchestration.immediate"

    @impl true
    def version, do: 1

    @impl true
    def recipients(_params), do: {:ok, [%{recipient_identity: "user-immediate"}]}

    @impl true
    def build(_params, recipient), do: {:ok, %{recipient: recipient}}
  end

  test "declared digest participation persists digest_held on the canonical delivery row" do
    notification = insert_notification("user-digest")

    assert {:ok, [delivery]} =
             DeliveryPlanning.plan_notification(notification,
               notifier: DigestEmailNotifier,
               trigger_params: %{}
             )

    assert delivery.channel == "email"
    assert delivery.status == :pending
    assert delivery.orchestration_state == :digest_held
    assert delivery.planning_reason == "digest_rule"
    assert delivery.next_eligible_at == nil

    assert delivery.planning_context == %{
             "channel" => "email",
             "digest_key" => "thread:123",
             "source" => "notifier"
           }

    assert delivery_count_for(notification.id) == 1
  end

  test "repeated planning preserves one row per notification/channel and keeps digest state" do
    notification = insert_notification("user-repeat")

    assert {:ok, [first]} =
             DeliveryPlanning.plan_notification(notification,
               notifier: DigestEmailNotifier,
               trigger_params: %{}
             )

    assert {:ok, [second]} =
             DeliveryPlanning.plan_notification(notification,
               notifier: DigestEmailNotifier,
               trigger_params: %{}
             )

    assert first.id == second.id
    assert second.orchestration_state == :digest_held
    assert second.planning_reason == "digest_rule"
    assert delivery_count_for(notification.id) == 1
  end

  test "notifiers without orchestration declarations default to ready planning" do
    notification = insert_notification("user-immediate")

    assert {:ok, [delivery]} =
             DeliveryPlanning.plan_notification(notification,
               notifier: ImmediateNotifier,
               trigger_params: %{}
             )

    assert delivery.channel == "in_app"
    assert delivery.orchestration_state == :ready
    assert delivery.planning_reason == nil
    assert delivery.planning_context == nil
  end

  defp insert_notification(recipient_identity) do
    {:ok, event} =
      %Event{}
      |> Event.changeset(%{
        notification_key: "orchestration.test",
        notification_version: 1,
        idempotency_key: "planning-declarations-#{System.unique_integer()}",
        payload: %{}
      })
      |> Repo.insert()

    {:ok, notification} =
      %Notification{}
      |> Notification.changeset(%{
        event_id: event.id,
        recipient_identity: recipient_identity,
        recipient_type: "user",
        metadata: %{},
        render_assigns: %{
          "headline" => "test headline",
          "body" => "test body",
          "primary_action" => %{"label" => "test", "url" => "http://test.com"},
          "subject" => "test subject",
          "html_body" => "<p>test</p>",
          "text_body" => "test"
        },
        render_channels: %{
          "email" => %{"render_key" => "test", "render_version" => 1},
          "in_app" => %{"render_key" => "test", "render_version" => 1}
        }
      })
      |> Repo.insert()

    notification
  end

  defp delivery_count_for(notification_id) do
    Repo.aggregate(from(d in Delivery, where: d.notification_id == ^notification_id), :count, :id)
  end
end
