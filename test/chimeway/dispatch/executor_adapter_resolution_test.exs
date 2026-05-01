defmodule Chimeway.Test.ExecutorResolutionSmsAdapter do
  @moduledoc false
  @behaviour Chimeway.Adapter

  @impl Chimeway.Adapter
  def deliver(_delivery, _config), do: {:ok, %{adapter: "sms_resolution"}}
end

defmodule Chimeway.Test.ExecutorResolutionEmailAdapter do
  @moduledoc false
  @behaviour Chimeway.Adapter

  @impl Chimeway.Adapter
  def deliver(_delivery, _config), do: {:ok, %{adapter: "email_resolution"}}
end

defmodule Chimeway.Dispatch.ExecutorAdapterResolutionTest do
  @moduledoc """
  Plan 29-05 Task 1: per-channel adapter resolution + adapter_module persistence.

  Verifies the D-15..D-21 contract:
    * resolve_adapter("email") with only :adapter set returns the legacy adapter (D-18).
    * resolve_adapter("sms") with :channel_adapters %{"sms" => Mod} routes to Mod.
    * Channel miss with :channel_adapters set fires [:chimeway, :dispatch, :adapter_fallback]
      telemetry and falls back to :adapter (D-19).
    * No adapter_fallback telemetry fires when only :adapter is set (D-19 silent legacy).
    * adapter_module is persisted on the attempt row as an inspect/1 string (D-20).
  """
  use Chimeway.DataCase, async: false

  alias Chimeway.DeliveryAttempt
  alias Chimeway.Dispatch.Executor
  alias Chimeway.Repo
  alias Chimeway.Test.DispatchHelpers

  setup do
    previous_adapter = Application.get_env(:chimeway, :adapter, Chimeway.Adapters.Logger)
    previous_channel_adapters = Application.get_env(:chimeway, :channel_adapters)

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

  describe "per-channel adapter resolution (D-17)" do
    test "channel hit in :channel_adapters routes delivery to the configured adapter" do
      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Logger)

      Application.put_env(:chimeway, :channel_adapters, %{
        "sms_custom" => Chimeway.Test.ExecutorResolutionSmsAdapter
      })

      %{delivery: delivery} = DispatchHelpers.create_pending_delivery(channel: :sms_custom)

      assert {:ok, %{delivery: updated, attempt: attempt}} = Executor.run_delivery(delivery)
      assert updated.status == :succeeded
      assert attempt.outcome == :succeeded

      # D-20: adapter_module persisted as inspect/1 string (no "Elixir." prefix)
      assert attempt.adapter_module == "Chimeway.Test.ExecutorResolutionSmsAdapter"
    end

    test "legacy :adapter still works when :channel_adapters is absent (D-18 backwards-compat)" do
      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
      Application.delete_env(:chimeway, :channel_adapters)
      Chimeway.Adapters.Test.clear()

      %{delivery: delivery} = DispatchHelpers.create_pending_delivery(channel: :email)

      assert {:ok, %{delivery: updated, attempt: attempt}} = Executor.run_delivery(delivery)
      assert updated.status == :succeeded
      assert attempt.outcome == :succeeded
      assert attempt.adapter_module == "Chimeway.Adapters.Test"
    end

    test "channel miss with :channel_adapters set falls back to :adapter and emits telemetry (D-19)" do
      Application.put_env(:chimeway, :adapter, Chimeway.Test.ExecutorResolutionEmailAdapter)

      Application.put_env(:chimeway, :channel_adapters, %{
        "sms_custom" => Chimeway.Test.ExecutorResolutionSmsAdapter
      })

      handler_id = "executor-adapter-fallback-#{System.unique_integer([:positive])}"

      :telemetry.attach(
        handler_id,
        [:chimeway, :dispatch, :adapter_fallback],
        fn _event, measurements, meta, {pid, ref} ->
          send(pid, {:adapter_fallback, ref, measurements, meta})
        end,
        {self(), make_ref()}
      )

      try do
        %{delivery: delivery} = DispatchHelpers.create_pending_delivery(channel: :email)

        assert {:ok, %{attempt: attempt}} = Executor.run_delivery(delivery)
        assert attempt.adapter_module == "Chimeway.Test.ExecutorResolutionEmailAdapter"

        assert_receive {:adapter_fallback, _ref, %{count: 1}, meta}, 500
        assert meta.channel == "email"
        assert meta.fallback_module == "Chimeway.Test.ExecutorResolutionEmailAdapter"
      after
        :telemetry.detach(handler_id)
      end
    end

    test "no :channel_adapters configured = no adapter_fallback telemetry (D-19 silent legacy)" do
      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
      Application.delete_env(:chimeway, :channel_adapters)
      Chimeway.Adapters.Test.clear()

      handler_id = "executor-adapter-fallback-silent-#{System.unique_integer([:positive])}"

      :telemetry.attach(
        handler_id,
        [:chimeway, :dispatch, :adapter_fallback],
        fn _event, measurements, meta, {pid, ref} ->
          send(pid, {:adapter_fallback, ref, measurements, meta})
        end,
        {self(), make_ref()}
      )

      try do
        %{delivery: delivery} = DispatchHelpers.create_pending_delivery(channel: :email)
        assert {:ok, %{}} = Executor.run_delivery(delivery)

        # D-19: legacy-only configuration must NOT emit adapter_fallback telemetry
        refute_receive {:adapter_fallback, _ref, _, _}, 100
      after
        :telemetry.detach(handler_id)
      end
    end
  end

  describe "adapter_module persistence (D-20)" do
    test "inspect(adapter) string is persisted on the attempt row (no \"Elixir.\" prefix)" do
      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
      Application.delete_env(:chimeway, :channel_adapters)
      Chimeway.Adapters.Test.clear()

      %{delivery: delivery} = DispatchHelpers.create_pending_delivery(channel: :email)

      assert {:ok, %{attempt: attempt}} = Executor.run_delivery(delivery)

      # Re-read from DB to confirm persistence (not just struct field).
      reloaded = Repo.get!(DeliveryAttempt, attempt.id)
      assert reloaded.adapter_module == "Chimeway.Adapters.Test"
      refute String.starts_with?(reloaded.adapter_module, "Elixir.")
    end
  end
end
