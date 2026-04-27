# Phase 16: Integration Hardening - Pattern Map

**Mapped:** 2024-05-24
**Files analyzed:** 4
**Analogs found:** 2 / 4

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `test/support/chimeway/dispatch/contract_test.ex` | test support | N/A | `test/support/chimeway/adapter/contract_test.ex` | role-match |
| `test/chimeway/dispatch/sync_test.exs` | test | N/A | `test/chimeway/adapters/logger_adapter_test.exs` | role-match |
| `test/chimeway/dispatch/oban_test.exs` | test | N/A | `test/chimeway/adapters/logger_adapter_test.exs` | role-match |
| `guides/introduction/installation.md` | documentation | N/A | None | N/A |
| `guides/introduction/getting-started.md` | documentation | N/A | None | N/A |

## Pattern Assignments

### `test/support/chimeway/dispatch/contract_test.ex` (test support, N/A)

**Analog:** `test/support/chimeway/adapter/contract_test.ex`

**ExUnit Macro definition pattern** (lines 35-43):
```elixir
  defmacro __using__(_opts) do
    quote do
      @before_compile Chimeway.Adapter.ContractTest

      # Default simulate_error? — override in the using module to activate error shape test
      def simulate_error?, do: false
      defoverridable simulate_error?: 0
```

**Contract test assertions generation pattern** (lines 59-65):
```elixir
      describe "Chimeway.Adapter contract" do
        test "behaviour: adapter_module exports deliver/2" do
          Code.ensure_loaded!(adapter_module())

          assert :erlang.function_exported(adapter_module(), :deliver, 2),
                 "#{inspect(adapter_module())} must export deliver/2 to satisfy Chimeway.Adapter behaviour"
        end
```

**Macro Before Compile check pattern** (lines 88-100):
```elixir
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
```

---

### `test/chimeway/dispatch/sync_test.exs` and `test/chimeway/dispatch/oban_test.exs` (test, N/A)

**Analog:** `test/chimeway/adapters/logger_adapter_test.exs`

**Macro usage pattern** (lines 1-7):
```elixir
defmodule Chimeway.Adapters.LoggerAdapterTest do
  # async: false because capture_log with level override changes global Logger state
  use ExUnit.Case, async: false
  use Chimeway.Adapter.ContractTest

  import ExUnit.CaptureLog
```

**Required callbacks implementation pattern** (lines 11-21):
```elixir
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
```

## No Analog Found

Files with no close match in the codebase (planner should use RESEARCH.md patterns instead):

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `guides/introduction/installation.md` | documentation | N/A | Markdown guide expansion, no direct analog. |
| `guides/introduction/getting-started.md` | documentation | N/A | Markdown guide expansion, no direct analog. |

## Metadata

**Analog search scope:** `test/support/**/*.ex`, `test/chimeway/adapters/**/*_test.exs`
**Files scanned:** 6
**Pattern extraction date:** 2024-05-24