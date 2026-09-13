defmodule Chimeway.InboxStateTransitionTest do
  use Chimeway.DataCase, async: false
  use Oban.Testing, repo: Chimeway.Repo

  # Requirements: INBX-02, INBX-03, READ-02
  alias Chimeway.Dispatch.SignalRouterWorker
  alias Chimeway.Events.Event
  alias Chimeway.Inbox
  alias Chimeway.Notifications.Notification
  alias Chimeway.Repo
  alias Chimeway.Signals.Signal

  defmodule RecordingPublisher do
    @behaviour Chimeway.Inbox.ChangePublisher

    def publish(change) do
      send(Application.fetch_env!(:chimeway, :inbox_change_test_pid), {:inbox_change, change})
      :ok
    end
  end

  defmodule FailingPublisher do
    @behaviour Chimeway.Inbox.ChangePublisher
    def publish(_change), do: raise("private lifecycle publisher failure")
  end

  test "mark_seen/3 sets seen_at without mutating read_at or archived_at" do
    notification = insert_notification!("seen-case")
    seen_at = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    assert :ok = Inbox.mark_seen(notification.id, "cw_user_42", tenant_id: "acme", at: seen_at)

    persisted = Repo.get!(Notification, notification.id)
    assert persisted.seen_at == seen_at
    assert is_nil(persisted.read_at)
    assert is_nil(persisted.archived_at)
  end

  test "mark_read/3 sets read_at without auto-archiving" do
    notification = insert_notification!("read-case")
    read_at = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    assert :ok = Inbox.mark_read(notification.id, "cw_user_42", tenant_id: "acme", at: read_at)

    persisted = Repo.get!(Notification, notification.id)
    assert persisted.read_at == read_at
    assert is_nil(persisted.seen_at)
    assert is_nil(persisted.archived_at)
  end

  test "archive/3 sets archived_at independently from read state" do
    notification = insert_notification!("archive-case")
    archived_at = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    assert :ok = Inbox.archive(notification.id, "cw_user_42", tenant_id: "acme", at: archived_at)

    persisted = Repo.get!(Notification, notification.id)
    assert persisted.archived_at == archived_at
    assert is_nil(persisted.seen_at)
    assert is_nil(persisted.read_at)
  end

  test "state transitions are scoped by notification id and recipient identity" do
    notification = insert_notification!("scope-case")

    assert {:error, :not_found} =
             Inbox.mark_read(notification.id, "cw_user_404", tenant_id: "acme")

    persisted = Repo.get!(Notification, notification.id)
    assert is_nil(persisted.seen_at)
    assert is_nil(persisted.read_at)
    assert is_nil(persisted.archived_at)
  end

  describe "inbox signal emission (READ-02)" do
    test "first mark_read emits signal and enqueues SignalRouterWorker" do
      notification = insert_notification!("read-signal-case")
      assert :ok = Inbox.mark_read(notification.id, "cw_user_42", tenant_id: "acme")

      assert [%Signal{id: signal_id} = signal] =
               Repo.all(from(s in Signal, where: s.event_name == "chimeway.notification.read"))

      assert signal.tenant_id == "acme"
      assert signal.actor_id == "cw_user_42"
      assert signal.payload["notification_id"] == notification.id

      assert_enqueued(worker: SignalRouterWorker, args: %{"signal_id" => signal_id})
    end

    test "re-mark read is idempotent — no duplicate signal" do
      notification = insert_notification!("read-idempotent-case")
      assert :ok = Inbox.mark_read(notification.id, "cw_user_42", tenant_id: "acme")
      assert :ok = Inbox.mark_read(notification.id, "cw_user_42", tenant_id: "acme")

      assert Repo.aggregate(
               from(s in Signal, where: s.event_name == "chimeway.notification.read"),
               :count
             ) == 1
    end

    test "first mark_seen emits distinct chimeway.notification.seen event" do
      notification = insert_notification!("seen-signal-case")
      assert :ok = Inbox.mark_seen(notification.id, "cw_user_42", tenant_id: "acme")

      assert [%Signal{event_name: "chimeway.notification.seen"}] =
               Repo.all(from(s in Signal, where: s.event_name == "chimeway.notification.seen"))

      persisted = Repo.get!(Notification, notification.id)
      assert is_nil(persisted.read_at)
    end

    test "mark_read does not emit seen signal" do
      notification = insert_notification!("read-no-seen-case")
      assert :ok = Inbox.mark_read(notification.id, "cw_user_42", tenant_id: "acme")

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
               Inbox.mark_read(notification.id, "cw_user_wrong", tenant_id: "acme")

      assert Repo.aggregate(Signal, :count) == 0
    end

    test "wrong tenant does not transition or emit a signal" do
      notification = insert_notification!("tenant-skip-case")

      assert {:error, :not_found} =
               Inbox.mark_read(notification.id, "cw_user_42", tenant_id: "other")

      persisted = Repo.get!(Notification, notification.id)
      assert is_nil(persisted.read_at)
      assert Repo.aggregate(Signal, :count) == 0
    end
  end

  describe "inbox change publication (INBX-03)" do
    setup do
      previous = Application.get_env(:chimeway, :inbox_change_publisher)
      Application.put_env(:chimeway, :inbox_change_publisher, RecordingPublisher)
      Application.put_env(:chimeway, :inbox_change_test_pid, self())

      on_exit(fn ->
        restore_env(:inbox_change_publisher, previous)
        Application.delete_env(:chimeway, :inbox_change_test_pid)
      end)
    end

    for {api, event} <- [mark_seen: :seen, mark_read: :read, archive: :archived] do
      test "#{api} publishes #{event} exactly once" do
        notification = insert_notification!("#{unquote(api)}-change")

        assert :ok =
                 apply(Inbox, unquote(api), [notification.id, "cw_user_42", [tenant_id: "acme"]])

        assert_receive {:inbox_change,
                        %Chimeway.Inbox.Change{
                          event: unquote(event),
                          tenant_id: "acme",
                          recipient_ref: "cw_user_42"
                        }}

        first =
          Repo.get!(Notification, notification.id) |> Map.fetch!(timestamp_field(unquote(api)))

        assert :ok =
                 apply(Inbox, unquote(api), [notification.id, "cw_user_42", [tenant_id: "acme"]])

        refute_receive {:inbox_change, _}

        assert Repo.get!(Notification, notification.id)
               |> Map.fetch!(timestamp_field(unquote(api))) == first
      end
    end

    test "wrong scope publishes nothing" do
      notification = insert_notification!("wrong-scope-change")

      assert {:error, :not_found} =
               Inbox.archive(notification.id, "cw_user_42", tenant_id: "other")

      refute_receive {:inbox_change, _}
    end

    test "publisher failure leaves the first durable transition successful" do
      Application.put_env(:chimeway, :inbox_change_publisher, FailingPublisher)
      notification = insert_notification!("publisher-failure-change")

      assert :ok = Inbox.archive(notification.id, "cw_user_42", tenant_id: "acme")
      assert Repo.get!(Notification, notification.id).archived_at
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
      recipient_identity: "cw_user_42",
      recipient_type: "member",
      metadata: %{"source" => "test"}
    })
    |> Repo.insert!()
  end

  defp timestamp_field(:mark_seen), do: :seen_at
  defp timestamp_field(:mark_read), do: :read_at
  defp timestamp_field(:archive), do: :archived_at

  defp restore_env(key, nil), do: Application.delete_env(:chimeway, key)
  defp restore_env(key, value), do: Application.put_env(:chimeway, key, value)
end
