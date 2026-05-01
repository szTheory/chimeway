defmodule Chimeway.Rendering.ChannelBehaviourTest do
  @moduledoc """
  Asserts the public `Chimeway.Rendering.Channel` behaviour exists and exposes
  the formal `validate/1` contract that channel render modules must implement.

  These tests document the must_haves listed in the 29-01 plan:

    1. The module is loadable and exposes a single `@callback validate/1`.
    2. `use Chimeway.Rendering.Channel` injects `@behaviour Chimeway.Rendering.Channel`.
    3. Host-defined channel modules that implement `validate/1` with `@impl` satisfy the contract.
  """

  use ExUnit.Case, async: true

  describe "behaviour module" do
    test "Chimeway.Rendering.Channel is loadable" do
      assert Code.ensure_loaded?(Chimeway.Rendering.Channel)
    end

    test "exposes validate/1 as the single callback" do
      callbacks = Chimeway.Rendering.Channel.behaviour_info(:callbacks)

      assert callbacks == [validate: 1]
    end

    test "defines a __using__/1 macro" do
      assert macro_exported?(Chimeway.Rendering.Channel, :__using__, 1)
    end
  end

  describe "use Chimeway.Rendering.Channel" do
    defmodule HostChannel do
      use Chimeway.Rendering.Channel

      @impl Chimeway.Rendering.Channel
      def validate(attrs) when is_map(attrs), do: {:ok, attrs}
      def validate(_other), do: {:error, :invalid}
    end

    test "injects @behaviour Chimeway.Rendering.Channel" do
      assert {:behaviour, [Chimeway.Rendering.Channel]} in HostChannel.module_info(:attributes)
    end

    test "host-defined validate/1 satisfies the contract" do
      assert {:ok, %{"foo" => "bar"}} = HostChannel.validate(%{"foo" => "bar"})
      assert {:error, :invalid} = HostChannel.validate(:not_a_map)
    end
  end

  describe "existing built-in channels" do
    # These modules already implement validate/1 with the contract shape
    # ahead of Plan 03 wiring up `use Chimeway.Rendering.Channel`. The
    # behaviour module exists so that compile-time @impl checking can be
    # added to them in the next plan without changing this contract.
    test "Email module exports validate/1" do
      Code.ensure_loaded!(Chimeway.Rendering.Channels.Email)
      assert function_exported?(Chimeway.Rendering.Channels.Email, :validate, 1)
    end

    test "InApp module exports validate/1" do
      Code.ensure_loaded!(Chimeway.Rendering.Channels.InApp)
      assert function_exported?(Chimeway.Rendering.Channels.InApp, :validate, 1)
    end
  end
end
