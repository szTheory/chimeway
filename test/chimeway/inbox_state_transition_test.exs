defmodule Chimeway.InboxStateTransitionTest do
  use Chimeway.DataCase, async: false

  # Requirements: INBX-02, INBX-03
  alias Chimeway.Events.Event
  alias Chimeway.Inbox
  alias Chimeway.Notifications.Notification
  alias Chimeway.Repo

  test "mark_seen/3 sets seen_at without mutating read_at or archived_at" do
    notification = insert_notification!("seen-case")
    seen_at = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    assert :ok = Inbox.mark_seen(notification.id, "user:42", seen_at)

    persisted = Repo.get!(Notification, notification.id)
    assert persisted.seen_at == seen_at
    assert is_nil(persisted.read_at)
    assert is_nil(persisted.archived_at)
  end

  test "mark_read/3 sets read_at without auto-archiving" do
    notification = insert_notification!("read-case")
    read_at = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    assert :ok = Inbox.mark_read(notification.id, "user:42", read_at)

    persisted = Repo.get!(Notification, notification.id)
    assert persisted.read_at == read_at
    assert is_nil(persisted.seen_at)
    assert is_nil(persisted.archived_at)
  end

  test "archive/3 sets archived_at independently from read state" do
    notification = insert_notification!("archive-case")
    archived_at = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    assert :ok = Inbox.archive(notification.id, "user:42", archived_at)

    persisted = Repo.get!(Notification, notification.id)
    assert persisted.archived_at == archived_at
    assert is_nil(persisted.seen_at)
    assert is_nil(persisted.read_at)
  end

  test "state transitions are scoped by notification id and recipient identity" do
    notification = insert_notification!("scope-case")

    assert {:error, :not_found} = Inbox.mark_read(notification.id, "user:404")

    persisted = Repo.get!(Notification, notification.id)
    assert is_nil(persisted.seen_at)
    assert is_nil(persisted.read_at)
    assert is_nil(persisted.archived_at)
  end

  defp insert_notification!(idempotency_key) do
    event =
      %Event{}
      |> Event.changeset(%{
        notification_key: "comment.created",
        notification_version: 1,
        idempotency_key: idempotency_key,
        payload: %{}
      })
      |> Repo.insert!()

    %Notification{}
    |> Notification.changeset(%{
      event_id: event.id,
      recipient_identity: "user:42",
      recipient_type: "member",
      metadata: %{"source" => "test"}
    })
    |> Repo.insert!()
  end
end
