defmodule Chimeway.Rendering.RenderIdentityIntegrationTest do
  use Chimeway.DataCase, async: false

  alias Chimeway.{Delivery, DeliveryPlanning, Repo, Trigger}
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification

  @moduletag :integration

  defmodule RenderIdentityNotifier do
    use Chimeway.Notifier

    @impl true
    def notification_key, do: "comment.created.rendering"

    @impl true
    def version, do: 2

    @impl true
    def recipients(_params) do
      {:ok, [%{recipient_identity: "user:render", recipient_type: "user"}]}
    end

    @impl true
    def build(_params, _recipient) do
      {:ok, %{"legacy_subject" => "stale compatibility data", "token" => "build-secret"}}
    end

    @impl true
    def channels(_params, _recipient), do: {:ok, [:email, :in_app]}

    @impl true
    def rendering(params, _recipient) do
      headline = Map.fetch!(params, "headline")
      body = Map.fetch!(params, "body")

      {:ok,
       %{
         assigns: %{
           "headline" => headline,
           "body" => body,
           "subject" => headline,
           "html_body" => "<p>#{body}</p>",
           "text_body" => body,
           "primary_action" => %{"label" => "Open", "url" => "https://example.test/render"},
           "token" => "render-secret"
         },
         channels: %{
           email: %{render_key: "comment.created.email", render_version: 4},
           in_app: %{render_key: "comment.created.in_app", render_version: 2}
         }
       }}
    end
  end

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

    test "trigger persists render assigns once and keeps metadata as a derived compatibility projection" do
      params = %{"headline" => "Welcome", "body" => "Ada commented"}

      assert {:ok, result} =
               Trigger.trigger(RenderIdentityNotifier, params,
                 idempotency_key: "render-trigger-001"
               )

      notification =
        Notification
        |> Repo.get_by!(event_id: result.event.id, recipient_identity: "user:render")

      expected_assigns = %{
        "headline" => "Welcome",
        "body" => "Ada commented",
        "subject" => "Welcome",
        "html_body" => "<p>Ada commented</p>",
        "text_body" => "Ada commented",
        "primary_action" => %{"label" => "Open", "url" => "https://example.test/render"}
      }

      assert notification.render_assigns == expected_assigns
      assert notification.metadata == expected_assigns
      refute Map.has_key?(notification.render_assigns, "token")
      refute Map.has_key?(notification.metadata, "token")
      refute notification.metadata["legacy_subject"] == "stale compatibility data"
    end

    test "planning stamps new canonical delivery rows with per-channel render identity" do
      event =
        %Event{}
        |> Event.changeset(%{
          notification_key: "comment.created.rendering",
          notification_version: 2,
          idempotency_key: "render-planning-001",
          payload: %{"headline" => "Welcome", "body" => "Ada commented"}
        })
        |> Repo.insert!()

      notification =
        %Notification{}
        |> Notification.changeset(%{
          event_id: event.id,
          recipient_identity: "user:render",
          recipient_type: "user",
          metadata: %{
            "headline" => "Welcome",
            "body" => "Ada commented",
            "subject" => "Welcome",
            "html_body" => "<p>Ada commented</p>",
            "text_body" => "Ada commented",
            "primary_action" => %{"label" => "Open", "url" => "https://example.test/render"}
          },
          render_assigns: %{
            "headline" => "Welcome",
            "body" => "Ada commented",
            "subject" => "Welcome",
            "html_body" => "<p>Ada commented</p>",
            "text_body" => "Ada commented",
            "primary_action" => %{"label" => "Open", "url" => "https://example.test/render"}
          }
        })
        |> Repo.insert!()

      assert {:ok, deliveries} =
               DeliveryPlanning.plan_notification(notification,
                 notifier: RenderIdentityNotifier,
                 trigger_params: %{"headline" => "Welcome", "body" => "Ada commented"}
               )

      persisted =
        deliveries
        |> Enum.map(&Repo.reload!/1)
        |> Enum.sort_by(& &1.channel)

      assert Enum.map(persisted, &{&1.channel, &1.render_key, &1.render_version}) == [
               {"email", "comment.created.email", 4},
               {"in_app", "comment.created.in_app", 2}
             ]
    end
  end
end
