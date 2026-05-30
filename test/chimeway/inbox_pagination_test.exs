defmodule Chimeway.InboxPaginationTest do
  use Chimeway.DataCase, async: false

  alias Chimeway
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification
  alias Chimeway.Repo

  @tag :unread_count
  test "unread_count/2 excludes read and archived unread by default" do
    _unread_a =
      insert_notification!(insert_event!("inbox-pagination-unread-a"), %{
        recipient_identity: "user:1",
        recipient_type: "member",
        metadata: %{"subject" => "unread-a"},
        read_at: nil
      })

    _unread_b =
      insert_notification!(insert_event!("inbox-pagination-unread-b"), %{
        recipient_identity: "user:1",
        recipient_type: "member",
        metadata: %{"subject" => "unread-b"},
        read_at: nil
      })

    _read =
      insert_notification!(insert_event!("inbox-pagination-read"), %{
        recipient_identity: "user:1",
        recipient_type: "member",
        metadata: %{"subject" => "read"},
        read_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)
      })

    _archived_unread =
      insert_notification!(insert_event!("inbox-pagination-archived"), %{
        recipient_identity: "user:1",
        recipient_type: "member",
        metadata: %{"subject" => "archived-unread"},
        read_at: nil,
        archived_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)
      })

    assert Chimeway.unread_count("user:1") == 2
    assert Chimeway.unread_count("user:1", exclude_archived: false) == 3
  end

  defp insert_event!(idempotency_key) do
    %Event{}
    |> Event.changeset(%{
      notification_key: "comment.created",
      notification_version: 1,
      idempotency_key: idempotency_key,
      payload: %{}
    })
    |> Repo.insert!()
  end

  defp insert_notification!(event, attrs) do
    %Notification{}
    |> Notification.changeset(Map.merge(attrs, %{event_id: event.id}))
    |> Repo.insert!()
  end
end
