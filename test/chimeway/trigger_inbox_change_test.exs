defmodule Chimeway.TriggerInboxChangeTest do
  use Chimeway.DataCase, async: false

  import Ecto.Query

  alias Chimeway.Inbox.Change
  alias Chimeway.Notifications.Notification
  alias Chimeway.Repo
  alias Chimeway.Trigger

  defmodule Notifier do
    @behaviour Chimeway.Notifier

    def notification_key, do: "inbox.change.created"
    def version, do: 1

    def recipients(_params) do
      {:ok,
       [
         %{recipient_ref: "cw_created_a", channel: :in_app},
         %{recipient_ref: "cw_created_b", channel: :in_app}
       ]}
    end

    def build(_params, recipient), do: {:ok, %{recipient: recipient, title: "Synthetic"}}
    def channels(_params, _recipient), do: {:ok, [:in_app]}
  end

  defmodule RecordingPublisher do
    @behaviour Chimeway.Inbox.ChangePublisher

    def publish(%Change{} = change) do
      committed =
        Repo.aggregate(
          from(n in Notification,
            where:
              n.tenant_id == ^change.tenant_id and
                n.recipient_identity == ^change.recipient_ref
          ),
          :count
        )

      send(
        Application.fetch_env!(:chimeway, :inbox_change_test_pid),
        {:change, change, committed}
      )

      :ok
    end
  end

  defmodule FailingPublisher do
    @behaviour Chimeway.Inbox.ChangePublisher
    def publish(_change), do: raise("private publisher failure")
  end

  setup do
    previous = Application.get_env(:chimeway, :inbox_change_publisher)
    Application.put_env(:chimeway, :inbox_change_publisher, RecordingPublisher)
    Application.put_env(:chimeway, :inbox_change_test_pid, self())

    on_exit(fn ->
      restore_env(:inbox_change_publisher, previous)
      Application.delete_env(:chimeway, :inbox_change_test_pid)
    end)
  end

  test "publishes one post-commit creation hint per inserted recipient" do
    assert {:ok, result} = trigger("created-once")
    assert result.notifications_inserted == 2

    assert_receive {:change,
                    %Change{event: :created, tenant_id: "tenant-a", recipient_ref: first}, 1}

    assert_receive {:change,
                    %Change{event: :created, tenant_id: "tenant-a", recipient_ref: second}, 1}

    assert MapSet.new([first, second]) == MapSet.new(["cw_created_a", "cw_created_b"])
    refute_receive {:change, _, _}
  end

  test "a duplicate trigger publishes no additional creation hint" do
    assert {:ok, _} = trigger("duplicate")
    assert_receive {:change, _, _}
    assert_receive {:change, _, _}

    assert {:duplicate, _event} = trigger("duplicate")
    refute_receive {:change, _, _}
  end

  test "publisher failure cannot falsify committed trigger success" do
    Application.put_env(:chimeway, :inbox_change_publisher, FailingPublisher)

    assert {:ok, result} = trigger("publisher-failure")
    assert result.notifications_inserted == 2

    assert Repo.aggregate(
             from(n in Notification, where: n.tenant_id == "tenant-a"),
             :count
           ) == 2
  end

  defp trigger(idempotency_key) do
    Trigger.trigger(Notifier, %{},
      idempotency_key: idempotency_key,
      tenant_id: "tenant-a"
    )
  end

  defp restore_env(key, nil), do: Application.delete_env(:chimeway, key)
  defp restore_env(key, value), do: Application.put_env(:chimeway, key, value)
end
