defmodule Chimeway.Rendering.RenderIdentityIntegrationTest do
  use Chimeway.DataCase, async: false

  alias Chimeway.{Delivery, Repo}
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification

  @moduletag :integration

  describe "notification render assigns" do
    test "changeset accepts render_assigns while keeping existing required fields" do
      attrs = %{
        event_id: Ecto.UUID.generate(),
        recipient_identity: "user:render",
        recipient_type: "user",
        metadata: %{"subject" => "Hello"},
        render_assigns: %{"headline" => "Welcome"}
      }

      changeset = Notification.changeset(%Notification{}, attrs)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :render_assigns) == %{"headline" => "Welcome"}
      assert :render_assigns in Map.keys(changeset.types)
    end
  end

  describe "delivery render identity fields" do
    test "changeset accepts render_key, render_version, and render_data separately from planning_context" do
      attrs = %{
        notification_id: Ecto.UUID.generate(),
        channel: "email",
        status: :pending,
        planning_context: %{"orchestration" => "digest"},
        render_key: "comment.created.email",
        render_version: 3,
        render_data: %{"subject" => "Comment created"}
      }

      changeset = Delivery.changeset(%Delivery{}, attrs)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :planning_context) == %{"orchestration" => "digest"}
      assert Ecto.Changeset.get_change(changeset, :render_key) == "comment.created.email"
      assert Ecto.Changeset.get_change(changeset, :render_version) == 3
      assert Ecto.Changeset.get_change(changeset, :render_data) == %{"subject" => "Comment created"}
    end
  end

  describe "durable delivery render identity" do
    test "delivery rows persist render identity independently from notifier module names" do
      event =
        %Event{}
        |> Event.changeset(%{
          notification_key: "comment.created",
          notification_version: 1,
          idempotency_key: "render_identity_001",
          payload: %{"comment_id" => 123}
        })
        |> Repo.insert!()

      notification =
        %Notification{}
        |> Notification.changeset(%{
          event_id: event.id,
          recipient_identity: "user:1",
          recipient_type: "user",
          metadata: %{"legacy_subject" => "Comment created"},
          render_assigns: %{"comment_id" => 123, "actor_name" => "Ada"}
        })
        |> Repo.insert!()

      delivery =
        %Delivery{}
        |> Delivery.changeset(%{
          notification_id: notification.id,
          channel: "email",
          status: :pending,
          planning_context: %{"digest_bucket_id" => "bucket-1"},
          render_key: "comment.created.email",
          render_version: 2,
          render_data: %{"subject" => "Ada commented", "body" => "New comment"}
        })
        |> Repo.insert!()
        |> Repo.preload(notification: :event)

      assert delivery.notification.event.notification_key == "comment.created"
      assert delivery.render_key == "comment.created.email"
      assert delivery.render_version == 2
      assert delivery.render_data == %{"subject" => "Ada commented", "body" => "New comment"}
      assert delivery.planning_context == %{"digest_bucket_id" => "bucket-1"}
      refute delivery.render_key == delivery.notification.event.notification_key
    end
  end
end
