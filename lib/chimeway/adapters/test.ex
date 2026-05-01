defmodule Chimeway.Adapters.Test do
  @moduledoc """
  In-memory test adapter using process dictionary storage.

  Stores delivered messages in the calling process's dictionary, providing
  per-test isolation without shared state between test processes. This mirrors
  the Swoosh.Adapters.Test pattern.

  ## Usage in tests

      setup do
        Chimeway.Adapters.Test.clear()
        :ok
      end

      test "delivery was sent" do
        # ... trigger delivery ...
        Chimeway.Adapters.Test.assert_delivered(delivery)
      end
  """

  @behaviour Chimeway.Adapter

  @impl Chimeway.Adapter
  def deliver(%Chimeway.Delivery{} = delivery, _config) do
    existing = Process.get(:chimeway_test_deliveries, [])
    Process.put(:chimeway_test_deliveries, [delivery | existing])
    # D-23: channel-tagged mailbox send so per-channel assertions can use assert_receive.
    # Process dictionary store above is unchanged; this only ADDS a per-test mailbox event.
    send(self(), {:chimeway_delivery, delivery.channel, delivery})
    {:ok, %{adapter: "test", delivered_at: DateTime.utc_now()}}
  end

  @doc """
  Returns all deliveries stored in the current process's test adapter.
  """
  def delivered_messages do
    Process.get(:chimeway_test_deliveries, [])
  end

  @doc """
  Asserts that a delivery with the given ID was stored in the test adapter.

  Raises `ExUnit.AssertionError` with a readable message if the delivery is
  not found.
  """
  def assert_delivered(%Chimeway.Delivery{} = expected) do
    delivered = delivered_messages()

    unless Enum.any?(delivered, fn d -> d.id == expected.id end) do
      raise ExUnit.AssertionError,
        message:
          "Expected delivery #{expected.id} not found in test adapter store.\nDelivered: #{inspect(delivered)}"
    end

    :ok
  end

  @doc """
  Clears all deliveries from the current process's test adapter store.
  Call in test setup/teardown.
  """
  def clear do
    Process.delete(:chimeway_test_deliveries)
  end
end
