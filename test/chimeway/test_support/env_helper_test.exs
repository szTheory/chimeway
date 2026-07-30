defmodule Chimeway.TestSupport.EnvHelperTest do
  use ExUnit.Case, async: true

  alias Chimeway.TestSupport.EnvHelper

  describe "put_env_isolated/3" do
    test "restores the exact prior value on exit when the key was present" do
      Application.put_env(:chimeway, :some_probe_key, :orig)

      # Registered BEFORE the helper call so it runs AFTER the helper's
      # on_exit restore (ExUnit on_exit callbacks run LIFO — most recently
      # registered runs first).
      on_exit(fn ->
        assert Application.fetch_env(:chimeway, :some_probe_key) == {:ok, :orig}
        Application.delete_env(:chimeway, :some_probe_key)
      end)

      assert EnvHelper.put_env_isolated(:chimeway, :some_probe_key, :mutated) == :ok
      assert Application.get_env(:chimeway, :some_probe_key) == :mutated
    end

    test "deletes the key on exit when it was absent before the call" do
      Application.delete_env(:chimeway, :absent_probe_key)
      assert Application.fetch_env(:chimeway, :absent_probe_key) == :error

      on_exit(fn ->
        assert Application.fetch_env(:chimeway, :absent_probe_key) == :error
      end)

      assert EnvHelper.put_env_isolated(:chimeway, :absent_probe_key, :mutated) == :ok
      assert Application.get_env(:chimeway, :absent_probe_key) == :mutated
    end
  end
end
