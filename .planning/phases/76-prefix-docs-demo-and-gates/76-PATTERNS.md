# Phase 76: Prefix Docs, Demo, and Gates - Pattern Map

**Mapped:** 2026-07-01
**Files analyzed:** 13
**Analogs found:** 13 / 13

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `README.md` | documentation | transform | `README.md` storage prefix install block | exact |
| `guides/introduction/installation.md` | documentation | transform | `guides/introduction/installation.md` storage prefix section | exact |
| `guides/introduction/golden-path.md` | documentation | transform | `guides/introduction/golden-path.md` storage prefix section | exact |
| `guides/introduction/storage-prefix-upgrade.md` | documentation | transform | `guides/introduction/installation.md` + `guides/recipes/oban-integration.md` | composite |
| `guides/recipes/oban-integration.md` | documentation | transform | `guides/recipes/oban-integration.md` config and queue sections | exact |
| `mix.exs` | config | batch | `mix.exs` verify aliases and HexDocs extras | exact |
| `.github/workflows/ci.yml` | config | batch | `.github/workflows/ci.yml` verify jobs and `ci-gate` | exact |
| `MAINTAINING.md` | documentation | batch | `MAINTAINING.md` pre-ship and installer gate sections | exact |
| `test/chimeway/doc_contract_test.exs` | test | file-I/O | `test/chimeway/doc_contract_test.exs` doc contract loops | exact |
| `test/chimeway/release_gate_contract_test.exs` | test | file-I/O | `test/chimeway/release_gate_contract_test.exs` parity contract | exact |
| `examples/chimeway_demo_host/config/dev.exs` | config | request-response | `examples/chimeway_demo_host/config/dev.exs` Chimeway config | exact |
| `examples/chimeway_demo_host/config/test.exs` | config | request-response | `examples/chimeway_demo_host/config/test.exs` Chimeway test config | exact |
| `examples/chimeway_demo_host/test/demo_host_web/admin_trace_live_test.exs` | test | request-response | `admin_trace_live_test.exs` + `PrefixedRuntimeCase` | composite |

## Pattern Assignments

### `README.md` (documentation, transform)

**Analog:** `README.md`

**Short first-run install truth** (lines 20-42):
````markdown
Then run:

```bash
mix deps.get
mix chimeway.gen.migrations
mix ecto.migrate
```

Choose the runtime storage prefix before starting Chimeway. New installs should
use the new isolated Chimeway schema:

```elixir
config :chimeway, prefix: "chimeway"
```

Use `prefix: false` only for an existing public-schema legacy install whose
Chimeway tables already live in public:

```elixir
config :chimeway, prefix: false
```

That legacy mode keeps using the existing unprefixed tables and does not move data.
````

**Pattern to copy:** Keep README copy short and beginner-safe. Add only a link to the new guide under documentation if needed. Do not add `--prefix public`, Oban prefix detail, `mix ecto.migrate --prefix chimeway`, or manual move runbook steps here.

---

### `guides/introduction/installation.md` (documentation, transform)

**Analog:** `guides/introduction/installation.md`

**Configuration section pattern** (lines 41-67):
````markdown
## 3. Configuration

You need to configure Chimeway to use your application's Ecto Repo. Add the following to your `config/config.exs` (or `config/dev.exs` / `config/prod.exs` as appropriate):

```elixir
config :chimeway,
  repo: MyApp.Repo
```

Replace `MyApp.Repo` with the actual name of your application's Repo module.

Choose the runtime storage prefix explicitly. New installs should use the new isolated Chimeway schema:

```elixir
config :chimeway, prefix: "chimeway"
```

Use `prefix: false` only for an existing public-schema legacy install whose
Chimeway tables already live in public:

```elixir
config :chimeway, prefix: false
```

That legacy mode keeps using the existing unprefixed tables and does not move data.

At runtime, Chimeway queries through `Chimeway.Repo`. Configure it to use the same database where your host migrations created the `chimeway_*` tables — see [Golden Path §3](golden-path.md#3-configure-chimeway) for the full shared-database setup.
````

**Pattern to copy:** Installation remains a first-run guide. Add a small "for upgrade/troubleshooting, see storage prefix guide" cross-link near this section, but keep operator move detail out of this file.

---

### `guides/introduction/golden-path.md` (documentation, transform)

**Analog:** `guides/introduction/golden-path.md`

**Golden path storage prefix pattern** (lines 25-77):
````markdown
## 2. Install database schema

Chimeway stores the durable lifecycle spine (`event` → `notification` → `delivery` → `attempt`) in your database. Generate and run migrations:

```bash
mix chimeway.gen.migrations
mix ecto.migrate
```

For more detail on migration generation, see [Installation §2](installation.md#2-generate-and-run-migrations).

## 3. Configure Chimeway

You need two configuration pieces: one for the **installer** task and one for **runtime queries**.
...
Also choose the runtime storage prefix explicitly. New installs should use the new isolated Chimeway schema:

```elixir
config :chimeway, prefix: "chimeway"
```

Use `prefix: false` only for an existing public-schema legacy install whose
Chimeway tables already live in public:

```elixir
config :chimeway, prefix: false
```

That legacy mode keeps using the existing unprefixed tables and does not move data.
````

**Explainability pattern** (lines 132-159):
````markdown
## 6. Prove explainability

Listing inbox messages shows *that* a notification exists; `explain_delivery/1` answers *why* it sent, failed, or was suppressed.

Using `result` from the trigger above:

```elixir
[delivery_id | _] = result.trace.delivery_ids

{:ok, explanation} = Chimeway.Traces.explain_delivery(delivery_id)
```
````

**Pattern to copy:** Keep the golden path as one credible vertical slice: install, configure, trigger, explain. If adding a link to the storage guide, make it a brief pointer after the prefix paragraph.

---

### `guides/introduction/storage-prefix-upgrade.md` (documentation, transform)

**Analog:** `guides/introduction/installation.md` for introduction style, `guides/recipes/oban-integration.md` for operational recipe style.

**Guide heading and prerequisite style** (from `guides/recipes/oban-integration.md` lines 1-17):
````markdown
# Integrating Oban for Reliable Async Dispatch

By default, Chimeway uses a synchronous dispatcher that attempts to deliver notifications immediately when they are triggered. For production environments, it is highly recommended to process these deliveries asynchronously in the background.

Chimeway provides native integration with [Oban](https://getoban.pro/), the leading background job system for Elixir.

## Prerequisites

1. Add Oban to your project if you haven't already:
   ```elixir
   defp deps do
     [
       {:oban, "~> 2.17"}
     ]
   end
   ```
2. Configure Oban in your application (see [Oban's installation guide](https://hexdocs.pm/oban/installation.html) for full details).
````

**First-run truth to reference, not duplicate as runbook** (from `guides/introduction/installation.md` lines 52-65):
````markdown
Choose the runtime storage prefix explicitly. New installs should use the new isolated Chimeway schema:

```elixir
config :chimeway, prefix: "chimeway"
```

Use `prefix: false` only for an existing public-schema legacy install whose
Chimeway tables already live in public:

```elixir
config :chimeway, prefix: false
```

That legacy mode keeps using the existing unprefixed tables and does not move data.
````

**Oban config style to mirror** (from `guides/recipes/oban-integration.md` lines 31-56):
````markdown
## Setting Up the Queues and Workers

Chimeway uses several queues to handle different background tasks. Update your Oban configuration to include these queues:

```elixir
# config/config.exs
config :my_app, Oban,
  repo: MyApp.Repo,
  plugins: [
    Oban.Plugins.Pruner
  ],
  queues: [
    default: 10,
    chimeway_delivery: [limit: 20],
    chimeway_signals: [limit: 10]
  ]
```
````

**Required content pattern:** The new guide should include the full prefix matrix, manual public-to-`chimeway` move procedure, preflight checks, backup expectation, transaction/lock caveats, verification queries, rollback and "stop and restore" language. It must explicitly state `prefix: false` does not move data and that Chimeway storage prefix does not create, move, or configure `oban_jobs`.

---

### `guides/recipes/oban-integration.md` (documentation, transform)

**Analog:** `guides/recipes/oban-integration.md`

**Chimeway dispatcher config pattern** (lines 19-29):
````markdown
## Configuring Chimeway for Oban

To tell Chimeway to use Oban for async dispatch, update your application configuration:

```elixir
# config/config.exs
config :chimeway,
  dispatcher: Chimeway.Dispatch.Oban
```

When you use the `Chimeway.Dispatch.Oban` dispatcher, Chimeway will automatically convert delivery plans into Oban jobs instead of executing them synchronously.
````

**Oban-owned config pattern** (lines 31-56):
````markdown
## Setting Up the Queues and Workers

Chimeway uses several queues to handle different background tasks. Update your Oban configuration to include these queues:

```elixir
# config/config.exs
config :my_app, Oban,
  repo: MyApp.Repo,
  plugins: [
    Oban.Plugins.Pruner
  ],
  queues: [
    default: 10,
    chimeway_delivery: [limit: 20],
    chimeway_signals: [limit: 10]
  ]
```
````

**Pattern to copy:** Add a subsection near setup explaining that Oban's database prefix is separate from Chimeway's storage prefix. Use `"jobs"` for Oban examples:

```elixir
def up, do: Oban.Migration.up(prefix: "jobs")
def down, do: Oban.Migration.down(prefix: "jobs")

config :my_app, Oban,
  repo: MyApp.Repo,
  prefix: "jobs"
```

Do not use `"chimeway"` as the Oban example prefix.

---

### `mix.exs` (config, batch)

**Analog:** `mix.exs`

**Verify alias pattern** (lines 99-110):
```elixir
# Installer golden-diff, idempotency, prefix, and DB migration contract (path-gated in CI, not default ci)
"verify.install_golden": [
  "cmd env CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/install/golden_diff_test.exs test/chimeway/install/idempotency_test.exs test/chimeway/install/prefix_contract_test.exs test/chimeway/migration_contract_test.exs --warnings-as-errors"
],
"verify.runtime_prefix": [
  "cmd env MIX_ENV=test mix test test/chimeway/repo_prefix_test.exs test/chimeway/runtime_prefix_integration_test.exs --warnings-as-errors"
],
"ci.install_golden": ["verify.install_golden"],

# GATE-01 doc-contract + version alignment gates (pre-ship; no Postgres required)
"ci.verify_gates": [
  "cmd env MIX_ENV=test mix test test/chimeway/doc_contract_test.exs test/chimeway/release_gate_contract_test.exs --warnings-as-errors"
],
```

**HexDocs extras pattern** (lines 211-245):
```elixir
defp docs do
  [
    main: "Chimeway",
    source_ref: "v#{@version}",
    source_url: "https://github.com/jonlunsford/chimeway",
    extras: [
      "guides/introduction/getting-started.md",
      "guides/introduction/installation.md",
      "guides/introduction/golden-path.md",
      "guides/introduction/mailglass-integration.md",
      ...
      "guides/recipes/oban-integration.md",
      ...
      "guides/cheatsheet.cheatmd"
    ],
    groups_extras: [
      Introduction: ~r/guides\/introduction\//,
      Flows: ~r/guides\/flows\//,
      Recipes: ~r/guides\/recipes\//
    ]
  ]
end
```

**Pattern to copy:** Add the new storage guide to `extras` near the other introduction guides. Do not create a new dependency or alias. `verify.runtime_prefix`, `verify.install_golden`, `ci.install_golden`, and `ci.verify_gates` already exist and should remain the source of truth for CI/release contracts.

---

### `.github/workflows/ci.yml` (config, batch)

**Analog:** `.github/workflows/ci.yml`

**Simple verify job pattern** (lines 40-61):
```yaml
verify_gates:
  name: Release gate contract
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5
    - uses: erlef/setup-beam@8251c48667b97e88a0a24ec512f5b72a039fcea7
      with:
        elixir-version: "1.17"
        otp-version: "27"
    - uses: actions/cache@0057852bfaa89a56745cba8c7296529d2fc39830
      with:
        path: |
          deps
          _build
        key: ${{ runner.os }}-mix-verify-gates-${{ hashFiles('**/mix.lock') }}
        restore-keys: |
          ${{ runner.os }}-mix-verify-gates-
    - run: |
        mix local.rebar --force
        mix local.hex --force
        mix deps.get
    - run: mix ci.verify_gates
```

**Postgres-backed verify job pattern** (lines 131-169):
```yaml
verify_example:
  name: Example host + admin smoke
  runs-on: ubuntu-latest
  services:
    postgres:
      image: postgres:15
      env:
        POSTGRES_PASSWORD: postgres
      options: >-
        --health-cmd pg_isready
        --health-interval 10s
        --health-timeout 5s
        --health-retries 5
      ports:
        - 5432:5432
  env:
    MIX_ENV: test
    DATABASE_URL: postgres://postgres:postgres@localhost/chimeway_test
  steps:
    ...
    - run: mix ecto.create --quiet
    - run: mix ecto.migrate --quiet
    - run: mix verify.example
```

**`ci-gate` aggregation pattern** (lines 570-604):
```yaml
ci-gate:
  name: ci-gate
  runs-on: ubuntu-latest
  needs: [lint, test, verify_gates, verify_docs, verify_example, verify_journeys, verify_mailglass, verify_accrue, verify_inbox, verify_threadline, verify_sigra, verify_admin]
  if: always()
  steps:
    - name: Verify required CI lanes
      env:
        LINT: ${{ needs.lint.result }}
        TEST: ${{ needs.test.result }}
        VERIFY_GATES: ${{ needs.verify_gates.result }}
        VERIFY_DOCS: ${{ needs.verify_docs.result }}
        VERIFY_EXAMPLE: ${{ needs.verify_example.result }}
        ...
      run: |
        set -euo pipefail
        failed=0
        for lane in LINT TEST VERIFY_GATES VERIFY_DOCS VERIFY_EXAMPLE VERIFY_JOURNEYS VERIFY_MAILGLASS VERIFY_ACCRUE VERIFY_INBOX VERIFY_THREADLINE VERIFY_SIGRA VERIFY_ADMIN; do
          result="${!lane}"
          if [[ "$result" != "success" ]]; then
            echo "Required lane $lane: $result"
            failed=1
          fi
        done
```

**Pattern to copy:** Add a `verify_runtime_prefix` Postgres-backed job that runs `mix verify.runtime_prefix`. Add it to `ci-gate.needs`, to the env block, and to the `for lane in ...` loop.

---

### `MAINTAINING.md` (documentation, batch)

**Analog:** `MAINTAINING.md`

**Pre-ship command block pattern** (lines 46-78):
````markdown
### Pre-ship local commands

Run all eleven before opening or merging release-related changes:

```bash
mix ci
mix ci.docs
mix ci.verify_gates
mix verify.admin
mix verify.example
mix verify.journeys
mix verify.mailglass
mix verify.accrue
mix verify.inbox
mix verify.threadline
mix verify.sigra
```

- `mix ci` — lint + full test suite
- `mix ci.docs` — HexDocs build with warnings-as-errors
- `mix ci.verify_gates` — adoption-surface doc-contract and release gate parity (GATE-01 + GATE-06)
...

All eleven must pass before publishing.

These eleven local commands map to ci-gate lanes plus publish replay — not eleven identical CI job names.
````

**Installer path-gate pattern** (lines 90-104):
```markdown
### Installer template changes

When modifying any of these paths, also run `mix verify.install_golden` locally before merging. `mix ci.install_golden` delegates to the same proof for CI parity.

- `priv/chimeway_migrations/`
- `lib/mix/tasks/chimeway.gen.migrations.ex`
- `lib/chimeway/install/`
- `test/chimeway/install/`
- `test/chimeway/migration_contract_test.exs`
- `test/fixtures/installer_golden_prefixed/`
- `test/fixtures/installer_golden_public/`

The installer proof covers committed golden fixtures, second-run idempotency, static prefix qualification, and database execution/rollback for generated prefixed and public migrations. It requires a reachable PostgreSQL test database; CI provisions PostgreSQL 15 for the path-gated `install_golden_contract` job.
```

**Pattern to copy:** Update counts and command list when adding `mix verify.runtime_prefix` to pre-ship. Keep `verify.install_golden` documented as path-gated, not part of `ci-gate`.

---

### `test/chimeway/doc_contract_test.exs` (test, file-I/O)

**Analog:** `test/chimeway/doc_contract_test.exs`

**Test module setup pattern** (lines 1-4):
```elixir
defmodule Chimeway.DocContractTest do
  use ExUnit.Case, async: true

  @moduledoc false
```

**Shared required/forbidden storage strings** (lines 1013-1029):
```elixir
@storage_prefix_required_strings [
  "prefix: \"chimeway\"",
  "prefix: false",
  "new isolated Chimeway schema",
  "existing public-schema legacy install",
  "unprefixed tables",
  "does not move data"
]

@storage_prefix_forbidden_phrases [
  "--prefix",
  "automatic data move",
  "automatically move",
  "automatic public-to-chimeway",
  "Oban prefix",
  "oban prefix"
]
```

**Required/forbidden loop pattern** (lines 1053-1099):
```elixir
for phrase <- @storage_prefix_forbidden_phrases do
  test "forbids storage prefix drift phrase #{phrase} in golden path guide", %{
    content: content
  } do
    refute String.contains?(content, unquote(phrase)),
           "golden path guide must not reference #{unquote(phrase)}"
  end
end

for required <- @storage_prefix_required_strings do
  test "requires storage prefix phrase #{required} in golden path guide", %{
    content: content
  } do
    assert String.contains?(content, unquote(required)),
           "golden path guide must reference #{unquote(required)}"
  end
end
```

**Oban recipe contract pattern** (lines 1247-1288):
```elixir
@oban_integration_recipe "guides/recipes/oban-integration.md"

describe "oban integration doc contract (IN-01 / GATE-01)" do
  setup do
    content = File.read!(@oban_integration_recipe)
    %{content: content}
  end

  @required ~w(
    Chimeway.Dispatch.WorkflowProgressionWorker
    Chimeway.Dispatch.SignalRouterWorker
    chimeway_delivery
    chimeway_signals
  )

  for required <- @required do
    test "requires #{required} in oban integration recipe", %{content: content} do
      assert String.contains?(content, unquote(required)),
             "oban integration recipe must reference #{unquote(required)}"
    end
  end
end
```

**HexDocs extras contract pattern** (lines 1290-1310):
```elixir
describe "hexdocs extras doc contract" do
  setup do
    content = File.read!("mix.exs")
    %{content: content}
  end

  @integration_guides ~w(
    guides/introduction/mailglass-integration.md
    guides/introduction/accrue-dunning-integration.md
    guides/introduction/admin-console-integration.md
    guides/introduction/inbox-integration.md
    guides/introduction/threadline-integration.md
    guides/introduction/sigra-auth-integration.md
  )

  for guide <- @integration_guides do
    test "requires #{guide} in HexDocs extras", %{content: content} do
      assert String.contains?(content, unquote(guide)),
             "mix.exs HexDocs extras must include #{unquote(guide)}"
    end
  end
end
```

**Pattern to copy:** Add a new storage guide contract with its own `@storage_prefix_upgrade_guide` path, required phrase list, forbidden footgun list, and HexDocs extras assertion. Keep first-run forbidden phrases strict for README/install/golden path.

---

### `test/chimeway/release_gate_contract_test.exs` (test, file-I/O)

**Analog:** `test/chimeway/release_gate_contract_test.exs`

**Gate metadata pattern** (lines 6-23):
```elixir
@maintaining "MAINTAINING.md"
@mix_exs "mix.exs"
@ci_yml ".github/workflows/ci.yml"
@release_yml ".github/workflows/release.yml"
@manifest ".release-please-manifest.json"
@publish_hex_yml ".github/workflows/publish-hex.yml"
@ci_gate_lanes ~w(lint test verify_gates verify_docs verify_example verify_journeys verify_mailglass verify_accrue verify_inbox verify_threadline verify_sigra verify_admin)

@pre_ship_verify_commands [
  {"verify.example", "verify_example", "mix verify.example"},
  {"verify.journeys", "verify_journeys", "mix verify.journeys"},
  {"verify.mailglass", "verify_mailglass", "mix verify.mailglass"},
  {"verify.accrue", "verify_accrue", "mix verify.accrue"},
  {"verify.inbox", "verify_inbox", "mix verify.inbox"},
  {"verify.threadline", "verify_threadline", "mix verify.threadline"},
  {"verify.sigra", "verify_sigra", "mix verify.sigra"},
  {"verify.admin", "verify_admin", "mix verify.admin"}
]
```

**Mix/CI parity loop** (lines 67-110):
```elixir
for {alias_name, slug, command} <- @pre_ship_verify_commands do
  test "mix.exs defines #{slug} alias for pre-ship gate", %{mix_exs: mix_exs} do
    assert Regex.match?(~r/"#{Regex.escape(unquote(alias_name))}":\s*\[/, mix_exs),
           "mix.exs must define \"#{unquote(alias_name)}\" alias matching #{unquote(command)}"
  end
end

for {_alias, job_id, command} <- @pre_ship_verify_commands do
  test "ci.yml #{job_id} job runs pre-ship gate command", %{ci_yml: ci_yml} do
    assert Regex.match?(~r/#{unquote(job_id)}:/, ci_yml),
           "ci.yml must define #{unquote(job_id)} job"

    job_block = extract_ci_job_block(ci_yml, unquote(job_id))
    assert String.contains?(job_block, unquote(command)),
           "#{unquote(job_id)} job must run #{unquote(command)}"
  end
end
```

**`ci-gate` lane contract** (lines 173-184):
```elixir
test "ci-gate aggregates 12 required lanes", %{ci_yml: ci_yml} do
  needs = extract_ci_gate_needs(ci_yml)

  for lane <- @ci_gate_lanes do
    assert lane in needs, "ci-gate must need #{lane}"
  end
end

test "install_golden_contract outside ci-gate needs", %{ci_yml: ci_yml} do
  needs = extract_ci_gate_needs(ci_yml)
  refute "install_golden_contract" in needs
end
```

**YAML extraction helpers** (lines 291-309):
```elixir
defp extract_ci_job_block(yml, job_id) do
  case Regex.run(~r/#{job_id}:(.*?)(?:\n  [a-z_]+:|\z)/s, yml) do
    [_, block] -> block
    _ -> flunk("Could not extract #{job_id} job block from #{yml}")
  end
end

defp extract_ci_gate_needs(ci_yml) do
  case Regex.run(~r/ci-gate:.*?needs:\s*\[(.*?)\]/s, ci_yml) do
    [_, needs_str] ->
      needs_str
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    _ ->
      flunk("Could not extract ci-gate needs from ci.yml")
  end
end
```

**Pattern to copy:** Add `verify_runtime_prefix` to `@ci_gate_lanes` and `@pre_ship_verify_commands`, update the lane count test name/count, and add explicit assertions that `install_golden_contract` stays outside `ci-gate`.

---

### `examples/chimeway_demo_host/config/dev.exs` (config, request-response)

**Analog:** `examples/chimeway_demo_host/config/dev.exs`

**Chimeway app config pattern** (lines 14-28):
```elixir
config :chimeway,
  ecto_repos: [Chimeway.Repo],
  time_zone_database: Tzdata.TimeZoneDatabase,
  dispatcher: Chimeway.Dispatch.Sync

config :chimeway, Chimeway.Repo,
  username: System.get_env("PGUSER") || System.get_env("USER") || "postgres",
  password: System.get_env("PGPASSWORD"),
  hostname: System.get_env("PGHOST") || "localhost",
  database: "chimeway_dev",
  pool_size: 10

config :chimeway, Oban,
  repo: Chimeway.Repo,
  queues: [chimeway_delivery: 10, chimeway_signals: 5]
```

**Pattern to copy:** Add `prefix: "chimeway"` to the `config :chimeway` block, not to `config :chimeway, Chimeway.Repo` and not to the Oban config.

---

### `examples/chimeway_demo_host/config/test.exs` (config, request-response)

**Analog:** `examples/chimeway_demo_host/config/test.exs`

**Chimeway test config pattern** (lines 8-28):
```elixir
# Chimeway core config required when running as a standalone example app.
# Mirrors the root project's config/config.exs + config/test.exs setup.
config :chimeway,
  ecto_repos: [Chimeway.Repo],
  time_zone_database: Tzdata.TimeZoneDatabase,
  dispatcher: Chimeway.Dispatch.Sync

# Full Chimeway.Repo config with SQL sandbox pool for tests.
# Uses the same env-var conventions as the root project's config/test.exs.
config :chimeway, Chimeway.Repo,
  username: System.get_env("PGUSER") || System.get_env("USER") || "postgres",
  password: System.get_env("PGPASSWORD"),
  hostname: System.get_env("PGHOST") || "localhost",
  database: "chimeway_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox

# Oban in manual testing mode for synchronous test assertions via assert_enqueued.
config :chimeway, Oban,
  repo: Chimeway.Repo,
  queues: [chimeway_delivery: 10, chimeway_signals: 5],
  testing: :manual
```

**Pattern to copy:** Add `prefix: "chimeway"` to the top-level `config :chimeway` block. Preserve SQL Sandbox and Oban manual testing config.

---

### `examples/chimeway_demo_host/test/demo_host_web/admin_trace_live_test.exs` (test, request-response)

**Analog:** `examples/chimeway_demo_host/test/demo_host_web/admin_trace_live_test.exs` plus `test/support/prefixed_runtime_case.ex`.

**LiveView test setup and imports** (from `admin_trace_live_test.exs` lines 1-14):
```elixir
defmodule DemoHostWeb.AdminTraceLiveTest do
  @moduledoc """
  Host-mount admin integration — part of the JOUR-01..08 journey suite.
  """
  use DemoHostWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Chimeway.{Delivery, Repo}
```

**Public seed path pattern** (from `admin_trace_live_test.exs` lines 35-64):
```elixir
@tag :journey
@tag :jour_04
test "JOUR-04 admin search finds seeded invite delivery", %{conn: conn} do
  assert {:ok, %{trace: %{delivery_ids: delivery_ids}}} = DemoHost.Seeds.seed_invite()

  conn = get(conn, "/admin/chimeway/traces")
  assert html_response(conn, 200) =~ "Trace Lookup"

  {:ok, view, _html} = live(conn)

  html =
    view
    |> form("#trace-search-form", %{
      "mode" => "recipient",
      "query" => DemoHost.Seeds.alex_identity(),
      "notification_key" => ""
    })
    |> render_submit()

  assert_redacted_recipient(html, DemoHost.Seeds.alex_identity())

  delivery_id =
    Enum.find(delivery_ids, &String.contains?(html, &1)) ||
      flunk("expected search results to include a seeded delivery id")

  {:ok, detail_view, detail_html} = live(conn, "/admin/chimeway/deliveries/#{delivery_id}")
  assert detail_html =~ "Trace Detail"
  assert render(detail_view) =~ "teampulse.invite_sent"
  assert render(detail_view) =~ "teampulse-seed-invite-corr"
end
```

**Seed implementation pattern** (from `examples/chimeway_demo_host/lib/demo_host/seeds.ex` lines 9-14 and 84-94):
```elixir
Adopter-copyable: uses `Chimeway.trigger/3` and public Chimeway contexts —
not internal test fixture inserts.

@doc "JOUR-01: successful team invite for Alex."
@spec seed_invite() :: {:ok, map()} | {:error, term()}
def seed_invite do
  trigger(
    DemoHost.Notifiers.InviteSent,
    %{email: @alex_email, team_name: "Engineering"},
    idempotency_key: @invite_idempotency,
    correlation_id: "teampulse-seed-invite-corr",
    tenant_id: @tenant_id
  )
end
```

**Schema count/assertion helper pattern** (from `test/support/prefixed_runtime_case.ex` lines 49-80):
```elixir
def prefixed_count(table_name) do
  table_count(@runtime_prefix, table_name)
end

def public_count(table_name) do
  table_count("public", table_name)
end

def table_count(schema, table_name) do
  schema = normalize_identifier!(schema)
  table_name = normalize_identifier!(table_name)

  if regclass?(schema, table_name) do
    sql = "SELECT count(*) FROM #{qualified_name(schema, table_name)}"

    Repo
    |> Ecto.Adapters.SQL.query!(sql, [])
    |> then(fn %{rows: [[count]]} -> count end)
  else
    0
  end
end

def assert_prefixed_only(table_name, expected_count) when is_integer(expected_count) do
  assert prefixed_count(table_name) == expected_count
  assert public_count(table_name) == 0
end
```

**Public API to placement proof pattern** (from `test/chimeway/runtime_prefix_integration_test.exs` lines 169-183):
```elixir
@tag :runtime_prefix_trigger
test "trigger pipeline writes event, notification, delivery, and attempt rows only under runtime prefix" do
  recipient_id = unique_recipient("trigger")

  assert {:ok, result} =
           Chimeway.trigger(
             ChimewayTest.Notifiers.RuntimePrefix,
             %{recipient_id: recipient_id, title: "Trigger proof"},
             trigger_opts("trigger")
           )

  assert_prefixed_only("chimeway_events", 1)
  assert_prefixed_only("chimeway_notifications", 1)
  assert_prefixed_only("chimeway_deliveries", 2)
  assert_prefixed_only("chimeway_delivery_attempts", 2)
```

**Oban separation assertion pattern** (from `test/chimeway/runtime_prefix_integration_test.exs` lines 374-391):
```elixir
@tag :runtime_prefix_oban_boundary
test "Oban enqueue boundaries keep Chimeway rows prefixed and Oban rows public" do
  Application.put_env(:chimeway, :dispatcher, Chimeway.Dispatch.Oban)
  recipient_id = unique_recipient("oban")

  assert {:ok, _result} =
           Chimeway.trigger(
             ChimewayTest.Notifiers.RuntimePrefix,
             %{recipient_id: recipient_id},
             trigger_opts("oban")
           )

  assert_prefixed_only("chimeway_events", 1)
  assert_prefixed_only("chimeway_notifications", 1)
  assert_prefixed_only("chimeway_deliveries", 2)

  assert public_count("oban_jobs") == 2
  assert prefixed_count("oban_jobs") == 0
```

**Pattern to copy:** Add the DEMO-01 proof either in this file or a focused sibling test. Use `DemoHost.Seeds.seed_invite/0` or another public seed, call `Chimeway.Traces.explain_delivery/1`, then assert Chimeway rows exist under `chimeway` and `public.chimeway_*` remains empty. Avoid direct fixture inserts as the primary proof.

## Shared Patterns

### First-Run Documentation Boundary

**Source:** `README.md` lines 28-42, `guides/introduction/installation.md` lines 52-67, `guides/introduction/golden-path.md` lines 62-77
**Apply to:** `README.md`, `guides/introduction/installation.md`, `guides/introduction/golden-path.md`

Keep only:
- `config :chimeway, prefix: "chimeway"` for new installs
- `config :chimeway, prefix: false` for public-schema legacy installs
- "does not move data" language
- A short link to the dedicated storage guide

Forbid first-run docs from including:
- `--prefix public`
- Oban prefix details
- `mix ecto.migrate --prefix chimeway`
- automated public-to-`chimeway` move claims

### Storage Guide Contract

**Source:** `test/chimeway/doc_contract_test.exs` lines 1013-1029 and 1053-1099
**Apply to:** `guides/introduction/storage-prefix-upgrade.md`, doc contract additions

Use the same shared-array plus generated-test style for required claims and forbidden footguns. Add guide-specific required strings for manual operation, backup, preflight, transaction/lock caveats, verification queries, rollback, "stop and restore", full prefix matrix, and Oban job-table separation.

### HexDocs Extras

**Source:** `mix.exs` lines 211-245 and `test/chimeway/doc_contract_test.exs` lines 1290-1310
**Apply to:** `mix.exs`, `test/chimeway/doc_contract_test.exs`

Add `guides/introduction/storage-prefix-upgrade.md` to the `extras` list under the Introduction group. Add a contract that fails if the guide is missing from `mix.exs`.

### Release Gate Parity

**Source:** `mix.exs` lines 99-110, `.github/workflows/ci.yml` lines 570-604, `test/chimeway/release_gate_contract_test.exs` lines 6-23 and 173-184, `MAINTAINING.md` lines 46-78
**Apply to:** `mix.exs`, `.github/workflows/ci.yml`, `MAINTAINING.md`, `test/chimeway/release_gate_contract_test.exs`

Every named gate must line up across local aliases, CI jobs, `ci-gate` needs/env/loop, MAINTAINING, and release-gate contracts. For Phase 76, add `verify.runtime_prefix` to the first-class CI/pre-ship set. Keep `install_golden_contract` path-gated and outside `ci-gate`.

### Demo Prefix Proof

**Source:** `examples/chimeway_demo_host/lib/demo_host/seeds.ex` lines 9-14 and 84-94, `test/support/prefixed_runtime_case.ex` lines 49-80, `test/chimeway/runtime_prefix_integration_test.exs` lines 169-183
**Apply to:** demo host config/tests

The acceptance proof should start from public demo APIs (`DemoHost.Seeds` or `Chimeway.trigger/3`), not direct storage inserts. Schema placement checks should use schema-qualified SQL and identifier normalization like `PrefixedRuntimeCase`, so the test does not rely on PostgreSQL `search_path`.

### Oban Prefix Separation

**Source:** `guides/recipes/oban-integration.md` lines 31-56 and `test/chimeway/runtime_prefix_integration_test.exs` lines 374-391
**Apply to:** storage guide, Oban recipe, demo/runtime docs contracts

Chimeway's storage prefix applies to Chimeway-owned `chimeway_*` tables. Oban's job table prefix is configured separately through Oban migration/config. Use `"jobs"` in docs examples and assert Chimeway rows and Oban rows separately where tests cover the boundary.

## No Analog Found

No files lacked a close analog. The new `guides/introduction/storage-prefix-upgrade.md` has no exact existing storage-upgrade guide, but it has strong composite analogs in the current first-run docs, Oban recipe, ExDoc extras, and doc-contract tests.

## Metadata

**Analog search scope:** `README.md`, `guides/`, `mix.exs`, `.github/workflows/ci.yml`, `MAINTAINING.md`, `test/chimeway/`, `test/support/`, `examples/chimeway_demo_host/`
**Files scanned:** 17 targeted files plus phase context and research
**Project guidance loaded:** `AGENTS.md`; no project-local `.codex/skills/` or `.agents/skills/` directories found
**Pattern extraction date:** 2026-07-01
