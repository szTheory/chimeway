# Phase 93: Hermetic Artifact Harness & Core Trace Proof - Pattern Map

**Mapped:** 2026-08-08  
**Files analyzed:** 2 committed files (+ temporary consumer scaffold rendered by its fixture)  
**Analogs found:** 2 / 2

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `test/support/artifact_consumer_fixture.ex` | test fixture / utility | file-I/O + batch subprocess lifecycle | `test/support/installer_fixture.ex`; `test/support/generated_prefixed_runtime_case.ex` | role-match |
| `test/chimeway/release_gate_contract_test.exs` | integration contract test | request-response + file-I/O + batch | its existing unpacked-artifact block; `test/chimeway/install/golden_diff_test.exs` | exact |

The fixture renders these uncommitted temporary-consumer files: `mix.exs`, `config/config.exs`, `lib/artifact_consumer/repo.ex`, `lib/artifact_consumer/application.ex`, `lib/artifact_consumer/notifiers/core_trace.ex`, and `priv/prove_core.exs`. They are fixture output, not repository source files.

## Pattern Assignments

### `test/support/artifact_consumer_fixture.ex` (test fixture / utility, file-I/O + batch subprocess lifecycle)

**Analogs:** `test/support/installer_fixture.ex` and `test/support/generated_prefixed_runtime_case.ex`.

**Module, unique temporary root, and rendered scaffold pattern** — `test/support/installer_fixture.ex:1-31`:

```elixir
defmodule Chimeway.Test.InstallerFixture do
  @moduledoc false

  def new_fixture_root!(name) when is_binary(name) do
    unique = Integer.to_string(System.unique_integer([:positive]))
    root = Path.join(System.tmp_dir!(), "chimeway_installer_#{name}_#{unique}")
    File.rm_rf!(root)
    File.mkdir_p!(root)
    root
  end

  def scaffold_host!(root) when is_binary(root) do
    File.mkdir_p!(Path.join(root, "priv/repo/migrations"))
    File.mkdir_p!(Path.join(root, "config"))

    File.write!(Path.join(root, "mix.exs"), host_mix_exs())
    File.write!(Path.join(root, "config/config.exs"), host_config_exs())
    root
  end
end
```

Extend this shape rather than reuse its `chimeway_repo_root()` path dependency. The new renderer must accept the unpacked-artifact root and make that the *only* `{:chimeway, path: ...}` source in its generated `mix.exs`.

**Subprocess and actionable failure pattern** — `test/support/installer_fixture.ex:207-237`:

```elixir
{output, status} =
  System.cmd("mix", ["deps.get"],
    cd: root,
    stderr_to_stdout: true,
    env: [{"MIX_ENV", "dev"}]
  )

if status != 0 do
  raise "mix deps.get failed in #{root}:\n#{output}"
end
```

Use one focused runner for `deps.get`, `chimeway.gen.migrations`, `ecto.create`, `ecto.migrate`, and `run priv/prove_core.exs`; always retain `stderr_to_stdout: true`, command name, exit status, and captured output. Do not emit passwords, URLs, params, or full explanation structs in diagnostics.

**Unique real database, cleanup, and connection guard** — `test/support/generated_prefixed_runtime_case.ex:29-68, 94-134`:

```elixir
unique = System.unique_integer([:positive])
database = "chimeway_generated_prefixed_runtime_#{unique}"
tmp_root = Path.join(System.tmp_dir!(), "chimeway_generated_prefixed_runtime_#{unique}")
config = generated_repo_config(database)

cleanup = fn repo_pid ->
  if repo_pid && Process.alive?(repo_pid), do: GenServer.stop(repo_pid)
  _ = Ecto.Adapters.Postgres.storage_down(config)
  File.rm_rf!(tmp_root)
end

%{rows: [[current_db]]} =
  Ecto.Adapters.SQL.query!(repo_pid, "SELECT current_database()", [])

unless current_db == database do
  cleanup.(repo_pid)
  flunk("generated runtime repo connected to #{current_db}, expected throwaway #{database}")
end

on_exit(fn -> cleanup.(repo_pid) end)
```

For this fixture, preserve the failure-path cleanup (`rescue` and `catch`) before installing `on_exit`; only drop the exact generated database. The consumer itself owns ordinary Ecto commands, while the fixture owns resource naming and teardown.

**DATABASE_URL override pattern** — `test/support/generated_prefixed_runtime_case.ex:227-265`:

```elixir
base_database_config()
|> Keyword.merge(
  url: nil,
  database: database,
  pool_size: 2,
  queue_target: 5_000,
  queue_interval: 10_000
)
```

Follow the existing URI credential parser and force `url: nil` in the generated consumer configuration. This prevents CI's `DATABASE_URL` from silently selecting the root `chimeway_test` database.

**Temporary notifier and public proof-script pattern** — `test/chimeway/integration/readme_snippet_test.exs:25-82`:

```elixir
defmodule WelcomeUser do
  use Chimeway.Notifier

  @impl true
  def notification_key, do: "welcome_user"

  @impl true
  def version, do: 1

  @impl true
  def recipients(%{user_id: user_id}),
    do: {:ok, [%{recipient_identity: "user:#{user_id}", recipient_type: "user"}]}
end

{:ok, result} =
  Chimeway.trigger(WelcomeUser, %{user_id: "user_12345"},
    idempotency_key: "signup_user_12345",
    tenant_id: "default"
  )

[delivery_id | _] = result.trace.delivery_ids
{:ok, explanation} = Traces.explain_delivery(delivery_id)
assert explanation.notification_key == "welcome_user"
assert :delivery_planned in Enum.map(explanation.timeline, & &1.event)
```

Render an adopter-owned notifier with a distinct fixed key/version and non-sensitive stable inputs. The script must derive lifecycle evidence only from `Chimeway.Traces.explain_delivery/1`, assert terminal `:succeeded`, public `last_attempt`, and required public timeline atoms, then print only an allowlisted evidence map.

### `test/chimeway/release_gate_contract_test.exs` (integration contract test, request-response + file-I/O + batch)

**Analog:** existing unpacked-package contract in the same file (`test/chimeway/release_gate_contract_test.exs:887-1015`).

**Artifact build + cleanup pattern**:

```elixir
describe "unpacked Hex package artifact truth ..." do
  setup do
    output = build_unpacked_package!()
    on_exit(fn -> File.rm_rf(output) end)
    %{output: output, root: unpacked_package_root!(output)}
  end
end

{out, status} =
  System.cmd("mix", ["hex.build", "--unpack", "--output", output],
    stderr_to_stdout: true,
    env: [{"MIX_ENV", "prod"}]
  )

assert status == 0, "mix hex.build --unpack must succeed ...: #{out}"
```

Add the Core proof as a new `async: false` describe/test in this anchor and pass its `root` to `ArtifactConsumerFixture`; preserve the existing prod artifact build rather than creating a shell checker or separately building source. Test-level serialization follows the existing external-host contract convention in `test/chimeway/install/golden_diff_test.exs:17-65` (`async: false`, long timeout tag, `try ... after` cleanup).

**Unpacked-root compatibility pattern** — `test/chimeway/release_gate_contract_test.exs:997-1015`:

```elixir
if File.exists?(Path.join(output, @mix_exs)) do
  output
else
  case Path.wildcard(Path.join(output, "chimeway-*")) do
    [child] ->
      if File.exists?(Path.join(child, @mix_exs)),
        do: child,
        else: flunk("unpacked package child #{child} does not contain #{@mix_exs}")

    candidates ->
      flunk("could not locate unpacked package root under #{output} (candidates: #{inspect(candidates)})")
  end
end
```

Consume the root returned by this helper; do not reproduce an assumed Hex layout. The test must also reject a generated dependency string that includes the repository root, proving provenance before consumer commands run.

## Shared Patterns

### Artifact provenance

**Source:** `test/chimeway/release_gate_contract_test.exs:975-1015`  
**Apply to:** release-gate test and temporary consumer fixture.

Build exactly once with `MIX_ENV=prod mix hex.build --unpack --output <unique-dir>`, locate the real unpack root defensively, and clean it through `on_exit`. The rendered consumer dependency must point solely at that root.

### External resources and cleanup

**Source:** `test/support/generated_prefixed_runtime_case.ex:38-77, 94-134`  
**Apply to:** temporary consumer fixture.

Use a unique database and temp directory; clean both in successful and exceptional paths; explicitly verify `SELECT current_database()` before migration; and defeat ambient `DATABASE_URL` with `url: nil` plus an explicit `database`.

### Public explainability and safe evidence

**Sources:** `test/chimeway/integration/readme_snippet_test.exs:55-82`; `lib/chimeway/traces.ex:128-177`; `test/chimeway/traces_test.exs:521-590`  
**Apply to:** generated `priv/prove_core.exs`.

`explain_delivery/1` is the sole lifecycle evidence read. It returns a public `Explanation` with status, last-attempt summary, and timeline. Preserve the safety boundary: never query the consumer Repo for lifecycle assertions and do not print payload, recipient, email, phone, or provider response fields.

### Deterministic terminal delivery

**Sources:** `lib/chimeway/dispatch/sync.ex:1-80`; `lib/chimeway/adapters/logger.ex:1-23`  
**Apply to:** generated consumer config.

Configure `Chimeway.Dispatch.Sync` and `Chimeway.Adapters.Logger`: Sync executes the full delivery pipeline in the caller process and Logger returns success without external credentials. This allows the proof to require `explanation.status == :succeeded` and a recorded attempt.

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `test/support/artifact_consumer_fixture.ex` | fixture utility | file-I/O + batch subprocess lifecycle | No existing fixture combines an unpacked Hex artifact, independent Mix app, real host DB, and public trace script; compose the two assigned analogs. |

## Metadata

**Analog search scope:** `test/support`, `test/chimeway`, `lib/chimeway`, `mix.exs`, `.github/workflows`  
**Files scanned:** 10  
**Pattern extraction date:** 2026-08-08
