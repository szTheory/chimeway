defmodule Chimeway.InboxQueryTest do
  use Chimeway.DataCase, async: true

  # Requirements: INBX-02, INBX-03
  alias Chimeway.Events.Event
  alias Chimeway.Inbox
  alias Chimeway.Notifications.Notification
  alias Chimeway.Repo

  test "list_for_recipient/2 returns newest-first rows and unread-only filtering" do
    oldest_event = insert_event!("inbox-query-event-1")
    middle_event = insert_event!("inbox-query-event-2")
    newest_event = insert_event!("inbox-query-event-3")
    other_event = insert_event!("inbox-query-event-4")

    oldest =
      insert_notification!(oldest_event, %{
        recipient_identity: "user:42",
        recipient_type: "member",
        metadata: %{"subject" => "oldest"},
        read_at: nil
      })

    middle =
      insert_notification!(middle_event, %{
        recipient_identity: "user:42",
        recipient_type: "member",
        metadata: %{"subject" => "middle"},
        read_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)
      })

    newest =
      insert_notification!(newest_event, %{
        recipient_identity: "user:42",
        recipient_type: "member",
        metadata: %{"subject" => "newest"},
        read_at: nil
      })

    _other_recipient =
      insert_notification!(other_event, %{
        recipient_identity: "user:99",
        recipient_type: "member",
        metadata: %{"subject" => "other"},
        read_at: nil
      })

    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)
    oldest_at = DateTime.add(now, -120, :second)
    middle_at = DateTime.add(now, -60, :second)
    newest_at = DateTime.add(now, -10, :second)

    set_inserted_at!(oldest.id, oldest_at)
    set_inserted_at!(middle.id, middle_at)
    set_inserted_at!(newest.id, newest_at)

    all_rows = Inbox.list_for_recipient("user:42")
    unread_rows = Inbox.list_for_recipient("user:42", unread_only: true)

    assert Enum.map(all_rows, & &1.id) == [newest.id, middle.id, oldest.id]
    assert Enum.map(unread_rows, & &1.id) == [newest.id, oldest.id]
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

  defp set_inserted_at!(notification_id, inserted_at) do
    {1, _rows} =
      Notification
      |> where([notification], notification.id == ^notification_id)
      |> Repo.update_all(set: [inserted_at: inserted_at, updated_at: inserted_at])

    :ok
  end
end
