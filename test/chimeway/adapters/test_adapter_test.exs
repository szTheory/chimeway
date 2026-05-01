defmodule Chimeway.Adapters.TestAdapterTest do
  use ExUnit.Case, async: true
  use Chimeway.Adapter.ContractTest

  alias Chimeway.Adapters.Test, as: TestAdapter

  def adapter_module, do: Chimeway.Adapters.Test

  def sample_delivery do
    %Chimeway.Delivery{
      id: Ecto.UUID.generate(),
      channel: "in_app",
      notification_id: Ecto.UUID.generate(),
      status: :pending,
      metadata: %{}
    }
  end

  def simulate_error?, do: false

  # Build a minimal Delivery struct without DB — adapter only inspects id,
  # channel, recipient_identity, notification_id.
  defp build_delivery(opts \\ []) do
    %Chimeway.Delivery{
      id: Keyword.get(opts, :id, Ecto.UUID.generate()),
      channel: Keyword.get(opts, :channel, "in_app"),
      notification_id: Keyword.get(opts, :notification_id, Ecto.UUID.generate()),
      status: :pending,
      metadata: %{}
    }
  end

  setup do
    TestAdapter.clear()
    :ok
  end

  describe "deliver/2" do
    test "returns {:ok, meta} where meta is a map" do
      delivery = build_delivery()
      assert {:ok, meta} = TestAdapter.deliver(delivery, [])
      assert is_map(meta)
      assert meta[:adapter] == "test" or meta["adapter"] == "test"
    end

    test "stores delivery in process dictionary" do
      delivery = build_delivery()
      TestAdapter.deliver(delivery, [])
      assert [stored] = TestAdapter.delivered_messages()
      assert stored.id == delivery.id
    end
  end

  describe "delivered_messages/0" do
    test "returns empty list when nothing has been delivered" do
      assert TestAdapter.delivered_messages() == []
    end

    test "returns all deliveries in the current process" do
      d1 = build_delivery()
      d2 = build_delivery()
      TestAdapter.deliver(d1, [])
      TestAdapter.deliver(d2, [])
      messages = TestAdapter.delivered_messages()
      assert length(messages) == 2
      ids = Enum.map(messages, & &1.id)
      assert d1.id in ids
      assert d2.id in ids
    end
  end

  describe "assert_delivered/1" do
    test "passes when delivery was stored" do
      delivery = build_delivery()
      TestAdapter.deliver(delivery, [])
      assert :ok = TestAdapter.assert_delivered(delivery)
    end

    test "raises ExUnit.AssertionError when delivery not found" do
      delivery = build_delivery()

      assert_raise ExUnit.AssertionError, fn ->
        TestAdapter.assert_delivered(delivery)
      end
    end

    test "error message includes the missing delivery id" do
      delivery = build_delivery()

      error =
        try do
          TestAdapter.assert_delivered(delivery)
          nil
        rescue
          e in ExUnit.AssertionError -> e
        end

      assert error != nil
      assert String.contains?(error.message, delivery.id)
    end
  end

  describe "clear/0" do
    test "empties delivered messages" do
      delivery = build_delivery()
      TestAdapter.deliver(delivery, [])
      assert [_] = TestAdapter.delivered_messages()
      TestAdapter.clear()
      assert TestAdapter.delivered_messages() == []
    end
  end

  describe "process isolation" do
    test "deliveries in one process are not visible in another" do
      delivery = build_delivery()
      TestAdapter.deliver(delivery, [])

      parent = self()

      task =
        Task.async(fn ->
          # Tag the message so we can selectively receive it past the D-23
          # {:chimeway_delivery, _, _} mailbox event that the parent's deliver/2
          # call enqueued in its own mailbox.
          send(parent, {:isolation_probe, TestAdapter.delivered_messages()})
        end)

      Task.await(task)

      received =
        receive do
          {:isolation_probe, msgs} -> msgs
        after
          100 -> :timeout
        end

      assert received == []
    end
  end
end
