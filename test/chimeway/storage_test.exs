defmodule Chimeway.StorageTest do
  use ExUnit.Case, async: false

  alias Chimeway.{ConfigError, Storage}

  setup do
    original = Application.fetch_env(:chimeway, :prefix)

    on_exit(fn ->
      restore_prefix(original)
    end)

    :ok
  end

  describe "Chimeway.ConfigError" do
    test "preserves invalid prefix fields and actionable message copy" do
      error =
        assert_raise ConfigError, fn ->
          raise ConfigError,
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

  describe "validate_prefix!/0" do
    test "accepts the schema-isolated chimeway prefix" do
      Application.put_env(:chimeway, :prefix, "chimeway")

      assert Storage.validate_prefix!() == "chimeway"
    end

    test "accepts explicit public-schema legacy mode" do
      Application.put_env(:chimeway, :prefix, false)

      assert Storage.validate_prefix!() == false
    end

    test "raises structured error for missing prefix config" do
      Application.delete_env(:chimeway, :prefix)

      error =
        assert_raise ConfigError, fn ->
          Storage.validate_prefix!()
        end

      assert error.type == :invalid_prefix
      assert error.key == :prefix
      assert error.value == :missing
    end

    test "rejects unsupported static and dynamic-looking prefix values" do
      dynamic_fun = fn -> "tenant_schema" end

      invalid_values = [
        nil,
        "public",
        "custom",
        "tenant:acme",
        dynamic_fun,
        {MyApp.StoragePrefixes, :for_tenant, [:tenant_id]}
      ]

      for value <- invalid_values do
        Application.put_env(:chimeway, :prefix, value)

        error =
          assert_raise ConfigError, fn ->
            Storage.validate_prefix!()
          end

        assert error.type == :invalid_prefix
        assert error.key == :prefix
        assert error.value == value
      end
    end
  end

  describe "repo_opts/1" do
    test "adds the configured chimeway prefix when no caller prefix exists" do
      Application.put_env(:chimeway, :prefix, "chimeway")

      assert Storage.repo_opts([]) == [prefix: "chimeway"]
    end

    test "preserves a caller-supplied prefix for probes" do
      Application.put_env(:chimeway, :prefix, "chimeway")

      assert Storage.repo_opts(prefix: "custom_probe", timeout: 1) == [
               prefix: "custom_probe",
               timeout: 1
             ]
    end

    test "returns unprefixed repo options in public-schema legacy mode" do
      Application.put_env(:chimeway, :prefix, false)

      refute Keyword.has_key?(Storage.repo_opts([]), :prefix)
      assert Storage.repo_opts(timeout: 1) == [timeout: 1]
    end
  end

  defp restore_prefix({:ok, value}) do
    Application.put_env(:chimeway, :prefix, value)
  end

  defp restore_prefix(:error) do
    Application.delete_env(:chimeway, :prefix)
  end
end
