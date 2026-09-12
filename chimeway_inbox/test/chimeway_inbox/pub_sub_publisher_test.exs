defmodule ChimewayInbox.PubSubPublisherTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Chimeway.Inbox.Change
  alias ChimewayInbox.{ChangeStream, PubSubPublisher}

  @tenant "tenant-stream-a"
  @recipient "cw_recipient_stream_a"
  @reload {:chimeway_inbox, :reload, 1}

  setup do
    previous_server = Application.get_env(:chimeway_inbox, :pubsub_server)
    previous_secret = Application.get_env(:chimeway_inbox, :topic_secret)

    on_exit(fn ->
      restore_env(:pubsub_server, previous_server)
      restore_env(:topic_secret, previous_secret)
    end)

    :ok
  end

  test "same scope exchanges only the closed reload tuple on an opaque topic" do
    assert {:ok, topic} = ChangeStream.topic(@tenant, @recipient)
    refute topic =~ @tenant
    refute topic =~ @recipient

    assert :ok = ChangeStream.subscribe(@tenant, @recipient)
    assert {:ok, change} = Change.new(@tenant, @recipient, :created)
    assert :ok = PubSubPublisher.publish(change)
    assert_receive @reload
    refute_receive _other
  end

  test "tenant and recipient changes derive different topics and do not cross streams" do
    assert {:ok, expected} = ChangeStream.topic(@tenant, @recipient)
    assert {:ok, other_tenant} = ChangeStream.topic("tenant-stream-b", @recipient)
    assert {:ok, other_recipient} = ChangeStream.topic(@tenant, "cw_recipient_stream_b")

    assert expected != other_tenant
    assert expected != other_recipient
    assert :ok = ChangeStream.subscribe(@tenant, @recipient)

    assert {:ok, change} = Change.new("tenant-stream-b", @recipient, :read)
    assert :ok = PubSubPublisher.publish(change)
    assert {:ok, change} = Change.new(@tenant, "cw_recipient_stream_b", :archived)
    assert :ok = PubSubPublisher.publish(change)
    refute_receive @reload
  end

  test "unsafe scope and invalid stream configuration fail closed without logging inputs" do
    unsafe_recipient = "unsafe recipient value"
    weak_secret = "too-short"

    log =
      capture_log(fn ->
        assert {:error, :invalid_stream} = ChangeStream.topic(@tenant, unsafe_recipient)
        assert {:error, :invalid_stream} = ChangeStream.subscribe(@tenant, unsafe_recipient)

        Application.put_env(:chimeway_inbox, :topic_secret, weak_secret)
        assert {:error, :invalid_stream} = ChangeStream.topic(@tenant, @recipient)

        Application.put_env(:chimeway_inbox, :topic_secret, String.duplicate("s", 32))
        Application.put_env(:chimeway_inbox, :pubsub_server, "not-an-atom")
        assert {:ok, change} = Change.new(@tenant, @recipient, :seen)
        assert {:error, :invalid_stream} = PubSubPublisher.publish(change)
      end)

    refute log =~ @tenant
    refute log =~ @recipient
    refute log =~ unsafe_recipient
    refute log =~ weak_secret
  end

  test "topic input is domain-separated and length-delimited" do
    assert {:ok, first} = ChangeStream.topic("tenant-a", "cw_recipient_bc")
    assert {:ok, second} = ChangeStream.topic("tenant-ab", "cw_recipient_c")
    assert first != second
    assert String.starts_with?(first, "chimeway:inbox:v1:")
  end

  defp restore_env(key, nil), do: Application.delete_env(:chimeway_inbox, key)
  defp restore_env(key, value), do: Application.put_env(:chimeway_inbox, key, value)
end
