defmodule Chimeway.Adapter.ContractTest do
  @moduledoc """
  Shared ExUnit contract assertions for Chimeway adapters.

  Any adapter in `lib/chimeway/adapters/` MUST have a corresponding test module
  that uses this contract test suite and passes all non-conditional contract tests
  before the adapter is added to the adapters directory.

  See `Chimeway.Adapter` behaviour for the full delivery contract. Add
  `use Chimeway.Adapter.ContractTest` to your adapter test module.

  ## Usage

      defmodule MyApp.Adapters.MyAdapterTest do
        use ExUnit.Case, async: true
        use Chimeway.Adapter.ContractTest

        def adapter_module, do: MyApp.Adapters.MyAdapter

        def sample_delivery do
          %Chimeway.Delivery{
            id: Ecto.UUID.generate(),
            channel: "email",
            notification_id: Ecto.UUID.generate(),
            status: :pending,
            metadata: %{}
          }
        end

        # Override to true if your adapter can simulate failure via deliver_with_error/2
        def simulate_error?, do: false
      end

  ## Required callbacks

  - `adapter_module/0` — returns the adapter module atom
  - `sample_delivery/0` — returns a `%Chimeway.Delivery{}` suitable for `deliver/2`

  ## Optional callbacks

  - `simulate_error?/0` — if `true`, activates the error return shape contract test
    (default: `false`; Logger adapter and similar always-succeed adapters should
    leave this false)
  """

  defmacro __using__(_opts) do
    quote do
      @before_compile Chimeway.Adapter.ContractTest

      # Default simulate_error? — override in the using module to activate error shape test
      def simulate_error?, do: false
      defoverridable simulate_error?: 0

      @doc false
      def __contract_check_no_sensitive_keys!(meta) when is_map(meta) do
        sensitive_keys =
          [:password, :token, :secret, :api_key, :auth] ++
            ["password", "token", "secret", "api_key", "auth"]

        found = Enum.filter(sensitive_keys, &Map.has_key?(meta, &1))

        if found != [] do
          raise ExUnit.AssertionError,
            message:
              "Adapter meta map contains sensitive keys: #{inspect(found)}. " <>
                "Adapters MUST redact password, token, secret, api_key, and auth before returning."
        end

        :ok
      end

      describe "Chimeway.Adapter contract" do
        test "behaviour: adapter_module exports deliver/2" do
          Code.ensure_loaded!(adapter_module())

          assert :erlang.function_exported(adapter_module(), :deliver, 2),
                 "#{inspect(adapter_module())} must export deliver/2 to satisfy Chimeway.Adapter behaviour"
        end

        test "success shape: deliver/2 returns {:ok, meta} with no sensitive keys" do
          assert {:ok, meta} = adapter_module().deliver(sample_delivery(), [])
          assert is_map(meta), "Expected meta to be a map, got: #{inspect(meta)}"
          __contract_check_no_sensitive_keys!(meta)
        end

        test "redaction gate: sensitive key check catches %{token: ...} in meta" do
          assert_raise ExUnit.AssertionError, fn ->
            __contract_check_no_sensitive_keys!(%{token: "abc"})
          end
        end

        test "error shape (conditional): deliver/2 returns {:error, class, map} on failure" do
          if simulate_error?() do
            assert {:error, reason_class, detail} =
                     adapter_module().deliver(sample_delivery(), [])

            assert reason_class in [:temporary, :permanent, :bounced],
                   "Expected reason_class in [:temporary, :permanent, :bounced], got: #{inspect(reason_class)}"

            assert is_map(detail), "Expected detail to be a map, got: #{inspect(detail)}"
          end
        end
      end
    end
  end

  defmacro __before_compile__(env) do
    for callback <- [:adapter_module, :sample_delivery] do
      unless Module.defines?(env.module, {callback, 0}) do
        raise CompileError,
          file: env.file,
          line: env.line,
          description:
            "#{inspect(env.module)} must define #{callback}/0 to use Chimeway.Adapter.ContractTest"
      end
    end

    quote do
    end
  end
end
