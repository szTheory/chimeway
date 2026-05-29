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
  - `webhook_contract?/0` — if `true`, documents webhook contract activation (pair with
    `@webhook_contract true` module attribute to compile webhook tests)
  - `webhook_fixtures/0` — returns fixture map when `@webhook_contract true`
    (`valid_body`, `valid_headers`, `config`, `provider_message_id`, `provider_event_id`)
  """

  defmacro __using__(_opts) do
    quote do
      @before_compile Chimeway.Adapter.ContractTest

      # Default simulate_error? — override in the using module to activate error shape test
      def simulate_error?, do: false
      defoverridable simulate_error?: 0

      # Default webhook_contract? — override to activate webhook callback contract tests
      def webhook_contract?, do: false
      defoverridable webhook_contract?: 0

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

      @doc false
      def __contract_parse_webhook_body!(adapter, body, headers, config)
          when is_atom(adapter) and is_binary(body) and is_list(headers) and is_list(config) do
        cond do
          function_exported?(adapter, :parse_webhook_body, 3) ->
            case adapter.parse_webhook_body(body, headers, config) do
              {:ok, parsed} ->
                parsed

              {:error, reason} ->
                flunk("parse_webhook_body/3 returned #{inspect(reason)} for #{inspect(adapter)}")
            end

          true ->
            case Jason.decode(body) do
              {:ok, parsed} -> parsed
              {:error, _} -> flunk("Jason.decode/1 failed for webhook body on #{inspect(adapter)}")
            end
        end
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
                     adapter_module().deliver(sample_delivery(), simulate_error: true)

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

    webhook_contract? = Module.get_attribute(env.module, :webhook_contract, false)

    webhook_tests =
      if webhook_contract? do
        unless Module.defines?(env.module, {:webhook_fixtures, 0}) do
          raise CompileError,
            file: env.file,
            line: env.line,
            description:
              "#{inspect(env.module)} sets @webhook_contract true but must define webhook_fixtures/0"
        end

        quote do
          describe "Chimeway.Adapter webhook contract" do
            test "verify_webhook accepts valid fixture credentials" do
              fixtures = webhook_fixtures()
              adapter = adapter_module()

              assert :ok =
                       adapter.verify_webhook(
                         fixtures.valid_body,
                         fixtures.valid_headers,
                         fixtures.config
                       )
            end

            test "verify_webhook rejects invalid credentials" do
              fixtures = webhook_fixtures()
              adapter = adapter_module()
              invalid_headers = [{"authorization", "Basic #{Base.encode64("wrong:creds")}"}]

              assert {:error, :unauthorized} =
                       adapter.verify_webhook(fixtures.valid_body, invalid_headers, fixtures.config)
            end

            test "resolve_delivery extracts provider_message_id from parsed fixture" do
              fixtures = webhook_fixtures()
              adapter = adapter_module()

              parsed =
                __contract_parse_webhook_body!(
                  adapter,
                  fixtures.valid_body,
                  fixtures.valid_headers,
                  fixtures.config
                )

              assert {:ok, %{provider_message_id: id}} = adapter.resolve_delivery(parsed)
              assert is_binary(id) and id != ""
              assert id == fixtures.provider_message_id
            end

            test "normalize_feedback maps fixture to canonical delivery outcome" do
              fixtures = webhook_fixtures()
              adapter = adapter_module()

              parsed =
                __contract_parse_webhook_body!(
                  adapter,
                  fixtures.valid_body,
                  fixtures.valid_headers,
                  fixtures.config
                )

              assert {:ok, %{status: status}} = adapter.normalize_feedback(parsed)
              assert status in [:delivered, :bounced, :failed]
            end

            test "resolve_provider_event_id returns stable id when fixture supplies event id" do
              fixtures = webhook_fixtures()
              adapter = adapter_module()

              parsed =
                __contract_parse_webhook_body!(
                  adapter,
                  fixtures.valid_body,
                  fixtures.valid_headers,
                  fixtures.config
                )

              assert {:ok, id} = adapter.resolve_provider_event_id(parsed)
              assert is_binary(id) and id != ""
              assert id == fixtures.provider_event_id
            end
          end
        end
      else
        quote do
        end
      end

    quote do
      unquote(webhook_tests)
    end
  end
end
