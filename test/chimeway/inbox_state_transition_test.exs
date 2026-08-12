defmodule Chimeway.InboxStateTransitionTest do
  use Chimeway.DataCase, async: true
  use Oban.Testing, repo: Chimeway.Repo

  # Requirements: INBX-02, INBX-03, READ-02
  alias Chimeway.Dispatch.SignalRouterWorker
  alias Chimeway.Events.Event
  alias Chimeway.Inbox
  alias Chimeway.Notifications.Notification
  alias Chimeway.Repo
  alias Chimeway.Signals.Signal

  test "mark_seen/3 sets seen_at without mutating read_at or archived_at" do
    notification = insert_notification!("seen-case")
    seen_at = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    assert :ok = Inbox.mark_seen(notification.id, "user:42", tenant_id: "acme", at: seen_at)

    persisted = Repo.get!(Notification, notification.id)
    assert persisted.seen_at == seen_at
    assert is_nil(persisted.read_at)
    assert is_nil(persisted.archived_at)
  end

  test "mark_read/3 sets read_at without auto-archiving" do
    notification = insert_notification!("read-case")
    read_at = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    assert :ok = Inbox.mark_read(notification.id, "user:42", tenant_id: "acme", at: read_at)

    persisted = Repo.get!(Notification, notification.id)
    assert persisted.read_at == read_at
    assert is_nil(persisted.seen_at)
    assert is_nil(persisted.archived_at)
  end

  test "archive/3 sets archived_at independently from read state" do
    notification = insert_notification!("archive-case")
    archived_at = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    assert :ok = Inbox.archive(notification.id, "user:42", tenant_id: "acme", at: archived_at)

    persisted = Repo.get!(Notification, notification.id)
    assert persisted.archived_at == archived_at
    assert is_nil(persisted.seen_at)
    assert is_nil(persisted.read_at)
  end

  test "state transitions are scoped by notification id and recipient identity" do
    notification = insert_notification!("scope-case")

    assert {:error, :not_found} = Inbox.mark_read(notification.id, "user:404", tenant_id: "acme")

    persisted = Repo.get!(Notification, notification.id)
    assert is_nil(persisted.seen_at)
    assert is_nil(persisted.read_at)
    assert is_nil(persisted.archived_at)
  end

  describe "inbox signal emission (READ-02)" do
    test "first mark_read emits signal and enqueues SignalRouterWorker" do
      notification = insert_notification!("read-signal-case")
      assert :ok = Inbox.mark_read(notification.id, "user:42", tenant_id: "acme")

      assert [%Signal{id: signal_id} = signal] =
               Repo.all(from(s in Signal, where: s.event_name == "chimeway.notification.read"))

      assert signal.tenant_id == "acme"
      assert signal.actor_id == "user:42"
      assert signal.payload["notification_id"] == notification.id

      assert_enqueued(worker: SignalRouterWorker, args: %{"signal_id" => signal_id})
    end

    test "re-mark read is idempotent — no duplicate signal" do
      notification = insert_notification!("read-idempotent-case")
      assert :ok = Inbox.mark_read(notification.id, "user:42", tenant_id: "acme")
      assert :ok = Inbox.mark_read(notification.id, "user:42", tenant_id: "acme")

      assert Repo.aggregate(
               from(s in Signal, where: s.event_name == "chimeway.notification.read"),
               :count
             ) == 1
    end

    test "first mark_seen emits distinct chimeway.notification.seen event" do
      notification = insert_notification!("seen-signal-case")
      assert :ok = Inbox.mark_seen(notification.id, "user:42", tenant_id: "acme")

      assert [%Signal{event_name: "chimeway.notification.seen"}] =
               Repo.all(from(s in Signal, where: s.event_name == "chimeway.notification.seen"))

      persisted = Repo.get!(Notification, notification.id)
      assert is_nil(persisted.read_at)
    end

    test "mark_read does not emit seen signal" do
      notification = insert_notification!("read-no-seen-case")
      assert :ok = Inbox.mark_read(notification.id, "user:42", tenant_id: "acme")

      assert Repo.aggregate(
               from(s in Signal, where: s.event_name == "chimeway.notification.seen"),
               :count
             ) == 0

      persisted = Repo.get!(Notification, notification.id)
      assert is_nil(persisted.seen_at)
    end

    test "wrong recipient returns not_found without emitting signal" do
      notification = insert_notification!("wrong-recipient-case")

      assert {:error, :not_found} =
               Inbox.mark_read(notification.id, "user:wrong", tenant_id: "acme")

      assert Repo.aggregate(Signal, :count) == 0
    end

    test "wrong tenant does not transition or emit a signal" do
      notification = insert_notification!("tenant-skip-case")

      assert {:error, :not_found} =
               Inbox.mark_read(notification.id, "user:42", tenant_id: "other")

      persisted = Repo.get!(Notification, notification.id)
      assert is_nil(persisted.read_at)
      assert Repo.aggregate(Signal, :count) == 0
    end
  end

  defp insert_notification!(idempotency_key) do
    event =
      %Event{}
      |> Event.changeset(%{
        notification_key: "comment.created",
        notification_version: 1,
        idempotency_key: idempotency_key,
        tenant_id: "acme",
        payload: %{}
      })
      |> Repo.insert!()

    %Notification{}
    |> Notification.changeset(%{
      event_id: event.id,
      tenant_id: "acme",
      recipient_identity: "user:42",
      recipient_type: "member",
      metadata: %{"source" => "test"}
    })
    |> Repo.insert!()
  end
end
