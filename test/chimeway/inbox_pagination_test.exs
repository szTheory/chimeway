defmodule Chimeway.InboxPaginationTest do
  use Chimeway.DataCase, async: true

  import Ecto.Query

  alias Chimeway
  alias Chimeway.Events.Event
  alias Chimeway.Inbox
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

  test "paginated list items include DTO keys" do
    notification =
      insert_notification!(insert_event!("inbox-pagination-dto"), %{
        recipient_identity: "user:dto",
        recipient_type: "member",
        metadata: %{"subject" => "Hello", "body" => "Preview body"},
        read_at: nil,
        seen_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)
      })

    %{items: [item]} = Inbox.list_for_recipient("user:dto", limit: 1)

    assert Map.has_key?(item, "id")
    assert Map.has_key?(item, "title")
    assert Map.has_key?(item, "body_preview")
    assert Map.has_key?(item, "inserted_at")
    assert Map.has_key?(item, "read_at")
    assert Map.has_key?(item, "seen_at")
    assert item["id"] == to_string(notification.id)
    assert is_binary(item["inserted_at"])
    assert is_binary(item["seen_at"])
    refute Map.has_key?(item, "href")
  end

  test "paginated list returns has_more and cursor fetches next page" do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    newest =
      insert_notification!(insert_event!("inbox-pagination-page-1"), %{
        recipient_identity: "user:page",
        recipient_type: "member",
        metadata: %{"subject" => "newest"},
        read_at: nil
      })

    middle =
      insert_notification!(insert_event!("inbox-pagination-page-2"), %{
        recipient_identity: "user:page",
        recipient_type: "member",
        metadata: %{"subject" => "middle"},
        read_at: nil
      })

    oldest =
      insert_notification!(insert_event!("inbox-pagination-page-3"), %{
        recipient_identity: "user:page",
        recipient_type: "member",
        metadata: %{"subject" => "oldest"},
        read_at: nil
      })

    set_inserted_at!(newest.id, DateTime.add(now, -10, :second))
    set_inserted_at!(middle.id, DateTime.add(now, -60, :second))
    set_inserted_at!(oldest.id, DateTime.add(now, -120, :second))

    first_page = Inbox.list_for_recipient("user:page", limit: 2)

    assert first_page.has_more
    assert length(first_page.items) == 2
    assert Enum.at(first_page.items, 0)["id"] == to_string(newest.id)
    assert Enum.at(first_page.items, 1)["id"] == to_string(middle.id)

    cursor_item = Enum.at(first_page.items, 1)
    {:ok, cursor_ts, _offset} = DateTime.from_iso8601(cursor_item["inserted_at"])

    second_page =
      Inbox.list_for_recipient("user:page",
        limit: 2,
        before_inserted_at: cursor_ts,
        before_id: cursor_item["id"]
      )

    refute second_page.has_more
    assert length(second_page.items) == 1
    assert Enum.at(second_page.items, 0)["id"] == to_string(oldest.id)
  end

  test "paginated list excludes archived notifications by default" do
    visible =
      insert_notification!(insert_event!("inbox-pagination-visible"), %{
        recipient_identity: "user:archive",
        recipient_type: "member",
        metadata: %{"subject" => "visible"},
        read_at: nil
      })

    _archived =
      insert_notification!(insert_event!("inbox-pagination-archived-row"), %{
        recipient_identity: "user:archive",
        recipient_type: "member",
        metadata: %{"subject" => "archived"},
        read_at: nil,
        archived_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)
      })

    %{items: items} = Inbox.list_for_recipient("user:archive", limit: 10)

    assert length(items) == 1
    assert Enum.at(items, 0)["id"] == to_string(visible.id)
  end

  test "paginated list maps title from metadata subject" do
    insert_notification!(insert_event!("inbox-pagination-title"), %{
      recipient_identity: "user:title",
      recipient_type: "member",
      metadata: %{"subject" => "Hello"},
      read_at: nil
    })

    %{items: [item]} = Inbox.list_for_recipient("user:title", limit: 1)

    assert item["title"] == "Hello"
  end

  defp insert_event!(idempotency_key) do
    %Event{}
    |> Event.changeset(%{
      notification_key: "comment.created",
      notification_version: 1,
      idempotency_key: idempotency_key,
      tenant_id: "default",
      payload: %{}
    })
    |> Repo.insert!()
  end

  defp insert_notification!(event, attrs) do
    %Notification{}
    |> Notification.changeset(Map.merge(attrs, %{event_id: event.id, tenant_id: event.tenant_id}))
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
