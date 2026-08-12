defmodule Chimeway.InboxIntegrationTest do
  use Chimeway.DataCase, async: true

  # Requirements: INBX-02, INBX-03
  alias Chimeway.Notifications.Notification
  alias Chimeway.Repo

  defmodule IntegrationNotifier do
    @behaviour Chimeway.Notifier

    @impl true
    def notification_key, do: "comment.created"

    @impl true
    def version, do: 1

    @impl true
    def recipients(_params) do
      {:ok,
       [
         %{recipient_identity: "user:42", channel: :in_app},
         %{recipient_identity: "user:77", channel: :in_app}
       ]}
    end

    @impl true
    def build(params, _recipient) do
      {:ok, %{"body" => params["body"]}}
    end
  end

  test "trigger fanout rows are listed and transitioned explicitly for user:42" do
    assert {:ok, _result} =
             Chimeway.trigger(
               IntegrationNotifier,
               %{"body" => "hello inbox", "password" => "redact"},
               idempotency_key: "inbox-integration-1",
               tenant_id: "acme"
             )

    notifications_before = Chimeway.list_for_recipient("user:42", tenant_id: "acme")
    assert length(notifications_before) == 1
    [notification] = notifications_before
    assert is_nil(notification.read_at)

    persisted_before = Repo.get!(Notification, notification.id)

    unread_notifications =
      Chimeway.list_for_recipient("user:42", tenant_id: "acme", unread_only: true)

    assert Enum.map(unread_notifications, & &1.id) == [notification.id]

    persisted_after = Repo.get!(Notification, notification.id)
    assert persisted_after.read_at == persisted_before.read_at

    seen_at = DateTime.utc_now() |> DateTime.truncate(:microsecond)
    read_at = DateTime.add(seen_at, 5, :second)
    archived_at = DateTime.add(read_at, 5, :second)

    assert :ok = Chimeway.mark_seen(notification.id, "user:42", seen_at, tenant_id: "acme")
    assert :ok = Chimeway.mark_read(notification.id, "user:42", read_at, tenant_id: "acme")
    assert :ok = Chimeway.archive(notification.id, "user:42", archived_at, tenant_id: "acme")

    persisted_final = Repo.get!(Notification, notification.id)
    assert persisted_final.seen_at == seen_at
    assert persisted_final.read_at == read_at
    assert persisted_final.archived_at == archived_at
    assert length(Chimeway.list_for_recipient("user:77", tenant_id: "acme")) == 1
  end
end
