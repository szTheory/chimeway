defmodule Chimeway.InboxChangePublisherTest do
  use ExUnit.Case, async: false

  alias Chimeway.Inbox.Change
  alias Chimeway.Inbox.ChangePublisher

  defmodule RecordingPublisher do
    @behaviour Chimeway.Inbox.ChangePublisher

    @impl true
    def publish(change) do
      send(Application.fetch_env!(:chimeway, :inbox_change_test_pid), {:change, change})
      :ok
    end
  end

  defmodule ErrorPublisher do
    @behaviour Chimeway.Inbox.ChangePublisher
    def publish(_change), do: {:error, {:unsafe_detail, "must-not-escape"}}
  end

  defmodule InvalidPublisher do
    @behaviour Chimeway.Inbox.ChangePublisher
    def publish(_change), do: {:unexpected, "must-not-escape"}
  end

  defmodule RaisingPublisher do
    @behaviour Chimeway.Inbox.ChangePublisher
    def publish(_change), do: raise("must-not-escape")
  end

  defmodule ExitPublisher do
    @behaviour Chimeway.Inbox.ChangePublisher
    def publish(_change), do: exit(:must_not_escape)
  end

  setup do
    previous = Application.get_env(:chimeway, :inbox_change_publisher)
    Application.put_env(:chimeway, :inbox_change_test_pid, self())

    on_exit(fn ->
      restore_env(:inbox_change_publisher, previous)
      Application.delete_env(:chimeway, :inbox_change_test_pid)
    end)

    :ok
  end

  test "constructs only the closed reload-hint vocabulary" do
    for event <- [:created, :seen, :read, :archived] do
      assert {:ok,
              %Change{
                version: 1,
                event: ^event,
                tenant_id: "tenant-a",
                recipient_ref: "cw_recipient_42"
              }} = Change.new("tenant-a", "cw_recipient_42", event)
    end

    assert {:error, :invalid_change} = Change.new("", "cw_recipient_42", :created)
    assert {:error, :invalid_change} = Change.new("tenant-a", "user@example.invalid", :created)
    assert {:error, :invalid_change} = Change.new("tenant-a", "cw_recipient_42", :deleted)

    assert Map.keys(Change.__struct__()) |> Enum.sort() ==
             [:__struct__, :event, :recipient_ref, :tenant_id, :version]
  end

  test "dispatches a valid hint to the configured publisher" do
    Application.put_env(:chimeway, :inbox_change_publisher, RecordingPublisher)

    assert :ok = ChangePublisher.publish("tenant-a", "cw_recipient_42", :created)
    assert_receive {:change, %Change{event: :created, recipient_ref: "cw_recipient_42"}}
  end

  test "default no-op keeps root operation Phoenix-free" do
    Application.delete_env(:chimeway, :inbox_change_publisher)
    assert :ok = ChangePublisher.publish("tenant-a", "cw_recipient_42", :seen)

    mix = File.read!("mix.exs")
    refute mix =~ "{:phoenix,"
    refute mix =~ "{:phoenix_pubsub,"

    root_sources = Path.wildcard("lib/**/*.ex") |> Enum.map_join(&File.read!/1)
    refute root_sources =~ "Phoenix.PubSub"
    refute root_sources =~ "ChimewayInbox."
  end

  test "contains every publisher failure and emits only stable telemetry" do
    handler = "inbox-change-test-#{System.unique_integer([:positive])}"

    :ok =
      :telemetry.attach(
        handler,
        [:chimeway, :inbox, :change_publish],
        fn event, measurements, metadata, pid -> send(pid, {event, measurements, metadata}) end,
        self()
      )

    on_exit(fn -> :telemetry.detach(handler) end)

    for publisher <- [ErrorPublisher, InvalidPublisher, RaisingPublisher, ExitPublisher] do
      Application.put_env(:chimeway, :inbox_change_publisher, publisher)
      assert :ok = ChangePublisher.publish("tenant-a", "cw_recipient_42", :read)

      assert_receive {[:chimeway, :inbox, :change_publish], %{count: 1}, %{outcome: :failed}}
    end

    Application.put_env(:chimeway, :inbox_change_publisher, RecordingPublisher)
    assert :ok = ChangePublisher.publish("tenant-a", "cw_recipient_42", :archived)
    assert_receive {:change, %Change{event: :archived}}

    assert_receive {[:chimeway, :inbox, :change_publish], %{count: 1}, %{outcome: :succeeded}}
  end

  defp restore_env(key, nil), do: Application.delete_env(:chimeway, key)
  defp restore_env(key, value), do: Application.put_env(:chimeway, key, value)
end
