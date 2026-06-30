defmodule Chimeway.ApplicationValidationTest do
  @moduledoc """
  Tests D-13: validate_channel_render_modules!/0 raises at boot for invalid modules.

  The validate_channel_render_modules!/0 function is private. Tests reach it via
  :erlang.apply/3 which bypasses Elixir compile-time visibility checks but invokes
  the BEAM-level function dispatch — the function is fully exported at the BEAM
  level for any private/public Elixir function.

  These tests mutate global :channel_render_modules application env, so async: false
  is required.
  """

  use ExUnit.Case, async: false

  describe "start/2 storage prefix validation" do
    test "raises ConfigError for unsupported storage prefix values" do
      original_prefix = Application.fetch_env(:chimeway, :prefix)
      original_channels = Application.fetch_env(:chimeway, :channel_render_modules)

      Application.put_env(:chimeway, :prefix, "public")
      Application.put_env(:chimeway, :channel_render_modules, %{})

      on_exit(fn ->
        restore_env(:prefix, original_prefix)
        restore_env(:channel_render_modules, original_channels)
      end)

      error =
        assert_raise Chimeway.ConfigError, fn ->
          Chimeway.Application.start(:normal, [])
        end

      assert error.type == :invalid_prefix
      assert error.key == :prefix
      assert error.value == "public"
    end

    test "raises ConfigError when storage prefix config is missing" do
      original_prefix = Application.fetch_env(:chimeway, :prefix)
      original_channels = Application.fetch_env(:chimeway, :channel_render_modules)

      Application.delete_env(:chimeway, :prefix)
      Application.put_env(:chimeway, :channel_render_modules, %{})

      on_exit(fn ->
        restore_env(:prefix, original_prefix)
        restore_env(:channel_render_modules, original_channels)
      end)

      error =
        assert_raise Chimeway.ConfigError, fn ->
          Chimeway.Application.start(:normal, [])
        end

      assert error.type == :invalid_prefix
      assert error.key == :prefix
      assert error.value == :missing
    end
  end

  describe "validate_channel_render_modules!/0" do
    test "raises ArgumentError for non-existent module (D-13)" do
      original = Application.get_env(:chimeway, :channel_render_modules)

      Application.put_env(
        :chimeway,
        :channel_render_modules,
        %{"custom" => Chimeway.NonExistent.Channel}
      )

      on_exit(fn ->
        case original do
          nil -> Application.delete_env(:chimeway, :channel_render_modules)
          val -> Application.put_env(:chimeway, :channel_render_modules, val)
        end
      end)

      assert_raise ArgumentError, ~r/could not be loaded/, fn ->
        :erlang.apply(Chimeway.Application, :validate_channel_render_modules!, [])
      end
    end

    test "raises ArgumentError when module exists but lacks validate/1 (D-13)" do
      original = Application.get_env(:chimeway, :channel_render_modules)

      # Use a real loaded module that does NOT export validate/1 — the Delivery
      # schema module is a stable choice.
      Application.put_env(
        :chimeway,
        :channel_render_modules,
        %{"custom" => Chimeway.Delivery}
      )

      on_exit(fn ->
        case original do
          nil -> Application.delete_env(:chimeway, :channel_render_modules)
          val -> Application.put_env(:chimeway, :channel_render_modules, val)
        end
      end)

      assert_raise ArgumentError, ~r/does not export validate\/1/, fn ->
        :erlang.apply(Chimeway.Application, :validate_channel_render_modules!, [])
      end
    end

    test "passes silently when :channel_render_modules is empty (D-13)" do
      original = Application.get_env(:chimeway, :channel_render_modules)
      Application.put_env(:chimeway, :channel_render_modules, %{})

      on_exit(fn ->
        case original do
          nil -> Application.delete_env(:chimeway, :channel_render_modules)
          val -> Application.put_env(:chimeway, :channel_render_modules, val)
        end
      end)

      # Empty registry must not raise — call returns :ok-equivalent (Enum.each returns :ok)
      assert :ok =
               :erlang.apply(Chimeway.Application, :validate_channel_render_modules!, [])
    end

    test "raises ArgumentError when value is not an atom (D-13)" do
      original = Application.get_env(:chimeway, :channel_render_modules)

      Application.put_env(
        :chimeway,
        :channel_render_modules,
        %{"custom" => "not_a_module"}
      )

      on_exit(fn ->
        case original do
          nil -> Application.delete_env(:chimeway, :channel_render_modules)
          val -> Application.put_env(:chimeway, :channel_render_modules, val)
        end
      end)

      assert_raise ArgumentError, ~r/must be a module atom/, fn ->
        :erlang.apply(Chimeway.Application, :validate_channel_render_modules!, [])
      end
    end
  end

  defp restore_env(key, {:ok, value}) do
    Application.put_env(:chimeway, key, value)
  end

  defp restore_env(key, :error) do
    Application.delete_env(:chimeway, key)
  end
end
