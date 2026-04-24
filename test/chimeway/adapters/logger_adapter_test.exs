defmodule Chimeway.Adapters.LoggerAdapterTest do
  # async: false because capture_log with level override changes global Logger state
  use ExUnit.Case, async: false
  use Chimeway.Adapter.ContractTest

  import ExUnit.CaptureLog

  alias Chimeway.Adapters.Logger, as: LoggerAdapter

  def adapter_module, do: Chimeway.Adapters.Logger

  def sample_delivery do
    %Chimeway.Delivery{
      id: Ecto.UUID.generate(),
      channel: "email",
      notification_id: Ecto.UUID.generate(),
      status: :pending,
      metadata: %{}
    }
  end

  def simulate_error?, do: false

  setup do
    Logger.configure(level: :info)
    on_exit(fn -> Logger.configure(level: :warning) end)
    :ok
  end

  defp build_delivery(opts \\ []) do
    %Chimeway.Delivery{
      id: Keyword.get(opts, :id, Ecto.UUID.generate()),
      channel: Keyword.get(opts, :channel, "email"),
      notification_id: Keyword.get(opts, :notification_id, Ecto.UUID.generate()),
      status: :pending,
      metadata: %{"subject" => "Hello", "body" => "World", "secret" => "do-not-log"}
    }
  end

  describe "deliver/2" do
    test "returns {:ok, %{adapter: 'logger', logged: true}}" do
      delivery = build_delivery()
      capture_log(fn -> LoggerAdapter.deliver(delivery, []) end)
      assert {:ok, %{adapter: "logger", logged: true}} = LoggerAdapter.deliver(delivery, [])
    end

    test "emits a Logger.info message containing [chimeway_delivery]" do
      delivery = build_delivery()
      log = capture_log(fn -> LoggerAdapter.deliver(delivery, []) end)
      assert log =~ "[chimeway_delivery]"
    end

    test "log line contains the channel name" do
      delivery = build_delivery(channel: "email")
      log = capture_log(fn -> LoggerAdapter.deliver(delivery, []) end)
      assert log =~ "email"
    end

    test "log line does not contain the metadata blob" do
      delivery = build_delivery()
      log = capture_log(fn -> LoggerAdapter.deliver(delivery, []) end)
      refute log =~ ~s("metadata")
      refute log =~ "do-not-log"
    end
  end
end
