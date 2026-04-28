defmodule Chimeway.Orchestration.DeliveryPlanningTest do
  use Chimeway.DataCase, async: false

  alias Chimeway.{Delivery, DeliveryPlanning, Digests, Preferences, Repo}
  alias Chimeway.Digests.{DigestBucket, DigestMembership}
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification
  alias Chimeway.Policy.Settings
  import Ecto.Query, only: [from: 2]

  setup do
    Repo.delete_all(DigestMembership)
    Repo.delete_all(DigestBucket)
    Repo.delete_all(Chimeway.Digests.DigestRule)
    :ok
  end

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
    def orchestration(_params, _recipient),
      do: {:ok, [email: {:digest, [digest_key: "thread:123"]}]}
  end

  defmodule ImmediateEmailNotifier do
    use Chimeway.Notifier

    @impl true
    def notification_key, do: "delivery-planning.immediate"

    @impl true
    def version, do: 1

    @impl true
    def recipients(_params), do: {:ok, [%{recipient_identity: "user-immediate"}]}

    @impl true
    def build(_params, recipient), do: {:ok, %{recipient: recipient}}

    @impl true
    def channels(_params, _recipient), do: {:ok, [:email]}

    @impl true
    def orchestration(_params, _recipient), do: {:ok, [email: :immediate]}
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
    assert delivery_count_for(notification.id) == 1
  end

  test "repeated planning creates one canonical delivery row and one digest membership" do
    insert_notification_key_rule("delivery-planning.test")
    notification = insert_notification("user-planning")

    assert {:ok, [delivery]} =
             DeliveryPlanning.plan_notification(notification,
               notifier: DigestEmailNotifier,
               trigger_params: %{}
             )

    assert {:ok, [replanned]} =
             DeliveryPlanning.plan_notification(notification,
               notifier: DigestEmailNotifier,
               trigger_params: %{}
             )

    assert replanned.id == delivery.id
    assert replanned.orchestration_state == :digest_held
    assert replanned.planning_context["digest_key"] == "thread:123"
    assert delivery_count_for(notification.id) == 1
    assert Repo.aggregate(DigestMembership, :count, :id) == 1

    membership = Repo.one!(DigestMembership)
    bucket = Repo.get!(DigestBucket, membership.digest_bucket_id)

    assert membership.delivery_id == delivery.id
    assert membership.notification_id == notification.id
    assert bucket.member_count == 1
    assert bucket.grouping_mode == :notification_key
    assert bucket.grouping_value == "delivery-planning.test"
  end

  test "category grouping snapshots the resolved event payload category string at planning time" do
    insert_category_rule("support")
    notification = insert_notification("user-category", %{"category" => "support"})

    assert {:ok, [delivery]} =
             DeliveryPlanning.plan_notification(notification,
               notifier: DigestEmailNotifier,
               trigger_params: %{}
             )

    membership = Repo.one!(DigestMembership)
    bucket = Repo.get!(DigestBucket, membership.digest_bucket_id)
    event = Repo.get!(Event, notification.event_id)

    assert delivery.orchestration_state == :digest_held
    assert bucket.grouping_mode == :category
    assert bucket.grouping_value == "support"

    event
    |> Ecto.Changeset.change(payload: %{"category" => "billing"})
    |> Repo.update!()

    assert Repo.get!(DigestBucket, bucket.id).grouping_value == "support"
  end

  test "suppressed or immediate deliveries do not create digest memberships" do
    insert_notification_key_rule("delivery-planning.test")

    assert {:ok, _pref} =
             Preferences.upsert_category_preference(%{
               recipient_id: "user-suppressed",
               notification_category: "support",
               enabled: false
             })

    suppressed_notification = insert_notification("user-suppressed", %{"category" => "support"})

    assert {:ok, [suppressed_delivery]} =
             DeliveryPlanning.plan_notification(suppressed_notification,
               notifier: DigestEmailNotifier,
               trigger_params: %{}
             )

    immediate_notification = insert_notification("user-immediate")

    assert {:ok, [immediate_delivery]} =
             DeliveryPlanning.plan_notification(immediate_notification,
               notifier: ImmediateEmailNotifier,
               trigger_params: %{}
             )

    assert suppressed_delivery.status == :suppressed
    assert suppressed_delivery.orchestration_state == :digest_held
    assert immediate_delivery.status == :pending
    assert immediate_delivery.orchestration_state == :ready
    assert Repo.aggregate(DigestMembership, :count, :id) == 0
    assert Repo.aggregate(DigestBucket, :count, :id) == 0
  end

  test "planner override records planner_override as the orchestration source" do
    notification = insert_notification("user-override")

    assert {:ok, [delivery]} =
             DeliveryPlanning.plan_notification(notification,
               notifier: DigestEmailNotifier,
               trigger_params: %{},
               orchestration: [email: :digest]
             )

    assert delivery.orchestration_state == :digest_held
    assert delivery.planning_context["source"] == "planner_override"
  end

  test "planner persists deferred planning facts during quiet hours without duplicate rows" do
    notification = insert_notification("user-deferred")

    assert {:ok, _} =
             Settings.upsert_settings(%{
               recipient_id: "user-deferred",
               quiet_hours_start_minute: 22 * 60,
               quiet_hours_end_minute: 8 * 60,
               time_zone: "America/New_York"
             })

    assert {:ok, [delivery]} =
             DeliveryPlanning.plan_notification(notification,
               evaluation_time: ~U[2026-01-15 03:30:00Z]
             )

    assert delivery.orchestration_state == :deferred
    assert delivery.planning_reason == "quiet_hours"
    assert DateTime.compare(delivery.next_eligible_at, ~U[2026-01-15 13:00:00Z]) == :eq

    assert {:ok, [replanned]} =
             DeliveryPlanning.plan_notification(notification,
               evaluation_time: ~U[2026-01-15 03:30:00Z]
             )

    assert replanned.id == delivery.id
    assert replanned.orchestration_state == :deferred
    assert delivery_count_for(notification.id) == 1
  end

  defp insert_notification(recipient_identity, payload \\ %{}) do
    {:ok, event} =
      %Event{}
      |> Event.changeset(%{
        notification_key: "delivery-planning.test",
        notification_version: 1,
        idempotency_key: "delivery-planning-#{System.unique_integer()}",
        payload: payload
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

  defp delivery_count_for(notification_id) do
    Repo.aggregate(from(d in Delivery, where: d.notification_id == ^notification_id), :count, :id)
  end

  defp insert_notification_key_rule(notification_key) do
    assert {:ok, _rule} =
             Digests.upsert_rule(%{
               rule_key: "digest.#{notification_key}",
               rule_version: 1,
               channel: "email",
               match_notification_key: notification_key,
               match_category: nil,
               group_by: :notification_key,
               window_kind: :fixed,
               window_minutes: 30
             })
  end

  defp insert_category_rule(category) do
    assert {:ok, _rule} =
             Digests.upsert_rule(%{
               rule_key: "digest.category.#{category}",
               rule_version: 1,
               channel: "email",
               match_notification_key: nil,
               match_category: category,
               group_by: :category,
               window_kind: :fixed,
               window_minutes: 30
             })
  end
end
