defmodule Chimeway.Test.ExecutorProviderMessageIdAdapter do
  @moduledoc false
  @behaviour Chimeway.Adapter

  @impl Chimeway.Adapter
  def deliver(_delivery, _config), do: {:ok, %{provider_message_id: "msg-abc-123"}}
end

defmodule Chimeway.Dispatch.ExecutorTest do
  @moduledoc """
  Plan 55-01 Task 1: persist provider_message_id from adapter success meta (D-05).
  """
  use Chimeway.DataCase, async: false

  alias Chimeway.DeliveryAttempt
  alias Chimeway.Dispatch.Executor
  alias Chimeway.Repo
  alias Chimeway.Test.DispatchHelpers

  setup do
    previous_adapter = Application.get_env(:chimeway, :adapter, Chimeway.Adapters.Logger)
    previous_channel_adapters = Application.get_env(:chimeway, :channel_adapters)

    Application.put_env(:chimeway, :adapter, Chimeway.Test.ExecutorProviderMessageIdAdapter)
    Application.delete_env(:chimeway, :channel_adapters)

    on_exit(fn ->
      Application.put_env(:chimeway, :adapter, previous_adapter)

      if is_nil(previous_channel_adapters) do
        Application.delete_env(:chimeway, :channel_adapters)
      else
        Application.put_env(:chimeway, :channel_adapters, previous_channel_adapters)
      end
    end)

    :ok
  end

  test "run_delivery persists provider_message_id from adapter success meta" do
    %{delivery: delivery} = DispatchHelpers.create_pending_delivery(channel: :email)

    assert {:ok, %{attempt: attempt}} = Executor.run_delivery(delivery)

    reloaded = Repo.get!(DeliveryAttempt, attempt.id)
    assert reloaded.provider_message_id == "msg-abc-123"
  end
end
