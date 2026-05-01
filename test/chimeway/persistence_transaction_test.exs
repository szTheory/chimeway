defmodule Chimeway.PersistenceTransactionTest do
  use Chimeway.DataCase, async: false

  import Ecto.Query, only: [from: 2]

  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification
  alias Chimeway.Repo
  alias Chimeway.Trigger

  defmodule FailingNotificationNotifier do
    @behaviour Chimeway.Notifier

    @impl true
    def notification_key, do: "comment.created"

    @impl true
    def version, do: 1

    @impl true
    def recipients(_params) do
      # Intentionally missing recipient_type/channel to trigger a DB insert error.
      {:ok, [%{recipient_identity: "user-1"}]}
    end

    @impl true
    def build(_params, _recipient) do
      {:ok, %{"topic" => "mentions"}}
    end
  end

  test "event and notification rows roll back together when notification insertion fails" do
    assert {:error, {:notifications_insert_failed, _reason}} =
             Trigger.trigger(
               FailingNotificationNotifier,
               %{"password" => "redact-me", "body" => "hello"},
               idempotency_key: "rollback-case-1",
               tenant_id: "acme"
             )

    assert Repo.aggregate(
             from(e in Event, where: e.idempotency_key == "rollback-case-1"),
             :count,
             :id
           ) ==
             0

    assert Repo.aggregate(
             from(n in Notification,
               join: e in Event,
               on: n.event_id == e.id,
               where: e.idempotency_key == "rollback-case-1"
             ),
             :count,
             :id
           ) == 0
  end
end
