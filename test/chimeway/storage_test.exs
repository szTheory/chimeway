defmodule Chimeway.StorageTest do
  use ExUnit.Case, async: false

  describe "Chimeway.ConfigError" do
    test "preserves invalid prefix fields and actionable message copy" do
      error =
        assert_raise Chimeway.ConfigError, fn ->
          raise Chimeway.ConfigError,
            type: :invalid_prefix,
            key: :prefix,
            value: :missing
        end

      assert error.type == :invalid_prefix
      assert error.key == :prefix
      assert error.value == :missing

      assert error.message =~ "[chimeway] invalid :prefix config"
      assert error.message =~ ~s(prefix: "chimeway")
      assert error.message =~ "prefix: false"
      assert error.message =~ "Dynamic per-tenant database prefixes are not supported"
    end
  end
end
