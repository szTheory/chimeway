# Phase 72: Admin Docs and Verification Gate - Pattern Map

**Mapped:** 2026-06-04
**Files analyzed:** 10
**Analogs found:** 7 / 10

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `guides/introduction/admin-console-integration.md` | documentation | request-response | `guides/introduction/inbox-integration.md` | role-match |
| `mix.exs` | config | batch | `mix.exs` existing `docs.extras`, `verify.*`, `ci.verify_gates` aliases | exact |
| `test/chimeway/doc_contract_test.exs` | test | file-I/O | existing guide contract blocks in `test/chimeway/doc_contract_test.exs` | exact |
| `test/chimeway/release_gate_contract_test.exs` | test | file-I/O | existing pre-ship verify lane contracts in `test/chimeway/release_gate_contract_test.exs` | exact |
| `MAINTAINING.md` | documentation | batch | existing pre-ship local commands block in `MAINTAINING.md` | exact |
| `.github/workflows/ci.yml` | config | batch | existing `verify_example` / `verify_inbox` jobs and `ci-gate` | exact |
| `package.json` | config | batch | none in root codebase | no-analog |
| `package-lock.json` | config | batch | none in root codebase | no-analog |
| `playwright.config.ts` | config | request-response | demo-host endpoint/test config | partial |
| `test/browser/admin_smoke.spec.ts` | test | request-response | `examples/chimeway_demo_host/test/demo_host_web/admin_trace_live_test.exs` | partial |

## Pattern Assignments

### `guides/introduction/admin-console-integration.md` (documentation, request-response)

**Analog:** `guides/introduction/inbox-integration.md`

**Guide structure pattern** (lines 1-15):
```markdown
# Inbox Integration

This guide is the canonical adoption path for composing Chimeway with the optional `chimeway_inbox` package. Follow it when you want one credible vertical slice: add Chimeway and the inbox package, configure recipient auth, mount the bell dropdown LiveView, and verify list -> mark_read -> badge updates.

## Responsibility split (SEED-003)

**Chimeway orchestrates the when and why:** durable notification lifecycle, suppression and preference gates, idempotency, scheduling, and operator traces you can search at `/admin/chimeway` via `chimeway_admin`.

**The host owns end-user identity and styling:** session -> recipient identity resolution through `ChimewayInbox.Auth`, CSS for `data-cw-inbox-*` hooks, and optional headless inbox calls via public `Chimeway.*` delegates.
```

**Router mount pattern** (lines 86-103):
~~~markdown
## 5. Router mount

Mount inbox routes in a browser scope, matching the package router moduledoc:

```elixir
# lib/my_app_web/router.ex
scope "/inbox" do
  pipe_through [:browser]

  import ChimewayInbox.Router
  chimeway_inbox_routes()
end
```

Runnable reference: `examples/chimeway_demo_host/lib/demo_host_web/router.ex` mounts under `/inbox` with `chimeway_inbox_routes/0`.
~~~

**Verification section pattern** (lines 147-167):
~~~markdown
## 8. Verification

After wiring dependencies, config, auth, and router mount, run the named proof command:

```bash
mix verify.inbox --warnings-as-errors
```

This exercises the `chimeway_inbox` package test suite and the DEMO-08 demo host proof lane (`--only inbox`). No sibling repo checkout is required.
~~~

**Admin-specific source snippets to copy into the new guide:**

From `chimeway_admin/lib/chimeway_admin/router.ex` lines 5-17:
```elixir
## Host integration

    # router.ex
    scope "/admin/chimeway" do
      pipe_through [:browser]

      import ChimewayAdmin.Router
      chimeway_admin_routes()
    end

    # config/config.exs
    config :chimeway_admin, auth_module: MyApp.AdminAuth
```

From `chimeway_admin/lib/chimeway_admin.ex` lines 21-33:
```elixir
## Stylesheet

Serve the packaged stylesheet from the host endpoint:

    plug Plug.Static,
      at: "/chimeway_admin",
      from: {:chimeway_admin, "priv/static"},
      gzip: false,
      only: ~w(chimeway_admin.css)

Then include:

    <link rel="stylesheet" href={ChimewayAdmin.Assets.css_path()} />
```

From `examples/chimeway_demo_host/lib/demo_host/admin_auth.ex` lines 1-13:
```elixir
defmodule DemoHost.AdminAuth do
  @moduledoc """
  Permissive dev/test auth for `chimeway_admin` in the demo host.

  Production always returns `{:error, :unauthorized}` — replace with a host
  `ChimewayAdmin.Auth` implementation before shipping to production.
  """
  @behaviour ChimewayAdmin.Auth

  @impl true
  def authorize(_actor, _action, _context) do
    if authorized?(), do: :ok, else: {:error, :unauthorized}
  end
end
```

### `mix.exs` (config, batch)

**Analog:** existing root aliases and docs extras in `mix.exs`

**Alias shape** (lines 62-107):
```elixir
defp aliases do
  [
    # Full local gate: run before pushing
    ci: ["ci.lint", "ci.test"],

    # Lint lane
    "ci.lint": [
      "format --check-formatted",
      "compile --warnings-as-errors",
      "credo --strict"
    ],

    # Test lane (mailglass/accrue/threadline/sigra excluded — run mix verify.* separately, GATE-04/05/07)
    "ci.test": [
      "cmd env MIX_ENV=test mix test --exclude mailglass --exclude accrue --exclude threadline --exclude sigra"
    ],

    # Docs gate: fails on undocumented public functions
    "ci.docs": ["docs --warnings-as-errors"],

    # GATE-01 doc-contract + version alignment gates (pre-ship; no Postgres required)
    "ci.verify_gates": [
      "cmd env MIX_ENV=test mix test test/chimeway/doc_contract_test.exs test/chimeway/release_gate_contract_test.exs --warnings-as-errors"
    ],
```

**Composed verify alias pattern** (lines 127-143):
```elixir
# v1.9 GATE-05 Inbox: chimeway_inbox package + demo host DEMO-08 :inbox proof
"verify.inbox": [
  "cmd --shell cd chimeway_inbox && mix deps.get && mix test --warnings-as-errors",
  "cmd --shell cd examples/chimeway_demo_host && mix deps.get && mix test --only inbox --warnings-as-errors"
],

# v1.10 GATE-07 Threadline: telemetry reporter proof (root + demo host :threadline lane)
"verify.threadline": [
  "cmd env MIX_ENV=test mix test --only threadline --warnings-as-errors",
  "cmd --shell threadline_path=${THREADLINE_PATH:-../threadline/threadline}; threadline_path=$(cd \"$threadline_path\" && pwd); cd examples/chimeway_demo_host && env CHIMEWAY_SKIP_SIGRA_DEP=1 THREADLINE_PATH=\"$threadline_path\" CHIMEWAY_PATH=../.. mix deps.get && env CHIMEWAY_SKIP_SIGRA_DEP=1 THREADLINE_PATH=\"$threadline_path\" CHIMEWAY_PATH=../.. mix deps.compile && env CHIMEWAY_SKIP_SIGRA_DEP=1 THREADLINE_PATH=\"$threadline_path\" CHIMEWAY_PATH=../.. mix test --only threadline --warnings-as-errors"
],
```

**Docs extras pattern** (lines 197-230):
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
      "guides/introduction/accrue-dunning-integration.md",
      "guides/introduction/inbox-integration.md",
      "guides/introduction/threadline-integration.md",
      "guides/introduction/sigra-auth-integration.md",
      "guides/flows/trigger-to-delivery.md"
    ],
    groups_extras: [
      Introduction: ~r/guides\/introduction\//,
      Flows: ~r/guides\/flows\//,
      Recipes: ~r/guides\/recipes\//
    ]
  ]
end
```

### `test/chimeway/doc_contract_test.exs` (test, file-I/O)

**Analog:** existing doc contract blocks in `test/chimeway/doc_contract_test.exs`

**Admin README contract pattern** (lines 245-286):
```elixir
@demo_host_readme "examples/chimeway_demo_host/README.md"

describe "demo-host admin console doc contract (ADMIN-03)" do
  setup do
    content = File.read!(@demo_host_readme)
    %{content: content}
  end

  @admin_required_strings [
    "Command Center",
    "Trace Lookup",
    "Trace Detail",
    "Feed Debug",
    "Definitions",
    "Health",
    "Recovery",
    "/admin/chimeway"
  ]

  for required <- @admin_required_strings do
    test "requires #{required} in demo-host admin copy", %{content: content} do
      assert String.contains?(content, unquote(required)),
             "examples/chimeway_demo_host/README.md must reference #{unquote(required)}"
    end
  end
end
```

**HexDocs extras contract pattern** (lines 1102-1121):
```elixir
describe "hexdocs extras doc contract" do
  setup do
    content = File.read!("mix.exs")
    %{content: content}
  end

  @integration_guides ~w(
    guides/introduction/mailglass-integration.md
    guides/introduction/accrue-dunning-integration.md
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

**Apply to Phase 72:** Add `@admin_integration_guide "guides/introduction/admin-console-integration.md"` and a `describe "admin integration guide doc contract (DOCS-12)"` block in this root file. Required strings should lock route labels, `/admin/chimeway`, `chimeway_admin_routes`, `Plug.Static`, `ChimewayAdmin.Assets.css_path()`, `config :chimeway_admin, auth_module:`, `ChimewayAdmin.Auth`, `authorize/3`, `current_actor`, `chimeway_admin_tenant_id`, redaction language, recovery permission language, Definitions/Feed Debug honest claims, and `mix verify.admin`.

### `test/chimeway/release_gate_contract_test.exs` (test, file-I/O)

**Analog:** existing release gate parity contract

**Lane inventory pattern** (lines 6-22):
```elixir
@maintaining "MAINTAINING.md"
@mix_exs "mix.exs"
@ci_yml ".github/workflows/ci.yml"
@release_yml ".github/workflows/release.yml"
@manifest ".release-please-manifest.json"
@publish_hex_yml ".github/workflows/publish-hex.yml"
@ci_gate_lanes ~w(lint test verify_gates verify_docs verify_example verify_journeys verify_mailglass verify_accrue verify_inbox verify_threadline verify_sigra)

@pre_ship_verify_commands [
  {"verify.example", "verify_example", "mix verify.example"},
  {"verify.journeys", "verify_journeys", "mix verify.journeys"},
  {"verify.mailglass", "verify_mailglass", "mix verify.mailglass"},
  {"verify.accrue", "verify_accrue", "mix verify.accrue"},
  {"verify.inbox", "verify_inbox", "mix verify.inbox"},
  {"verify.threadline", "verify_threadline", "mix verify.threadline"},
  {"verify.sigra", "verify_sigra", "mix verify.sigra"}
]
```

**Pre-ship assertions pattern** (lines 39-49, 66-109):
```elixir
for {_alias, slug, command} <- @pre_ship_verify_commands do
  test "MAINTAINING pre-ship block lists #{slug} gate", %{pre_ship_block: pre_ship_block} do
    assert String.contains?(pre_ship_block, unquote(command)),
           "MAINTAINING.md pre-ship block must list #{unquote(command)}"
  end
end

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

**CI gate aggregate pattern** (lines 172-178, 297-308):
```elixir
test "ci-gate aggregates 11 required lanes", %{ci_yml: ci_yml} do
  needs = extract_ci_gate_needs(ci_yml)

  for lane <- @ci_gate_lanes do
    assert lane in needs, "ci-gate must need #{lane}"
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

**Apply to Phase 72:** Add `{"verify.admin", "verify_admin", "mix verify.admin"}` to `@pre_ship_verify_commands`, add `verify_admin` to `@ci_gate_lanes`, update the count assertions/text from ten/eleven to include the new lane, and avoid adding a special-case branch unless the CI job does not directly run `mix verify.admin`.

### `MAINTAINING.md` (documentation, batch)

**Analog:** existing release pre-ship block

**Pre-ship command pattern** (lines 46-76):
~~~markdown
### Pre-ship local commands

Run all ten before opening or merging release-related changes:

```bash
mix ci
mix ci.docs
mix ci.verify_gates
mix verify.example
mix verify.journeys
mix verify.mailglass
mix verify.accrue
mix verify.inbox
mix verify.threadline
mix verify.sigra
```

- `mix ci.verify_gates` — adoption-surface doc-contract and release gate parity (GATE-01 + GATE-06)
- `mix verify.example` — demo host webhook E2E + chimeway_admin operator smoke
- `mix verify.inbox` — Inbox integration gate (GATE-05 Inbox): chimeway_inbox package tests and DEMO-08 demo host :inbox proof; in-repo path deps only — no sibling checkout

All ten must pass before publishing.
~~~

**Apply to Phase 72:** Insert `mix verify.admin`, document that it covers root admin/read-model tests, the `chimeway_admin` package tests, demo-host mounted admin coverage, and Playwright Chromium browser smoke. Update "ten" wording consistently to the new count.

### `.github/workflows/ci.yml` (config, batch)

**Analog:** existing verify jobs and `ci-gate`

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
        key: ${{ runner.os }}-mix-verify-example-${{ hashFiles('**/mix.lock') }}
        restore-keys: |
          ${{ runner.os }}-mix-verify-example-
    - run: |
        mix local.rebar --force
        mix local.hex --force
        mix deps.get
    - run: mix ecto.create --quiet
    - run: mix ecto.migrate --quiet
    - run: mix verify.example
```

**CI gate pattern** (lines 507-540):
```yaml
ci-gate:
  name: ci-gate
  runs-on: ubuntu-latest
  needs: [lint, test, verify_gates, verify_docs, verify_example, verify_journeys, verify_mailglass, verify_accrue, verify_inbox, verify_threadline, verify_sigra]
  if: always()
  steps:
    - name: Verify required CI lanes
      env:
        LINT: ${{ needs.lint.result }}
        TEST: ${{ needs.test.result }}
        VERIFY_GATES: ${{ needs.verify_gates.result }}
        VERIFY_DOCS: ${{ needs.verify_docs.result }}
        VERIFY_EXAMPLE: ${{ needs.verify_example.result }}
        VERIFY_JOURNEYS: ${{ needs.verify_journeys.result }}
        VERIFY_MAILGLASS: ${{ needs.verify_mailglass.result }}
        VERIFY_ACCRUE: ${{ needs.verify_accrue.result }}
        VERIFY_INBOX: ${{ needs.verify_inbox.result }}
        VERIFY_THREADLINE: ${{ needs.verify_threadline.result }}
        VERIFY_SIGRA: ${{ needs.verify_sigra.result }}
      run: |
        set -euo pipefail
        failed=0
        for lane in LINT TEST VERIFY_GATES VERIFY_DOCS VERIFY_EXAMPLE VERIFY_JOURNEYS VERIFY_MAILGLASS VERIFY_ACCRUE VERIFY_INBOX VERIFY_THREADLINE VERIFY_SIGRA; do
          result="${!lane}"
          if [[ "$result" != "success" ]]; then
            echo "Required lane $lane: $result"
            failed=1
          fi
        done
```

**Apply to Phase 72:** Add `verify_admin` with the same Postgres service and Beam setup, add Node setup for Playwright, then run `mix verify.admin`. Add `verify_admin` to `ci-gate.needs`, env, and lane loop. Keep existing SHA-pinned action style; if adding `actions/setup-node`, pin it like the other actions.

### `package.json` (config, batch)

**Analog:** no root codebase analog.

**Use research pattern:** Root `package.json` should be minimal and only support the Playwright smoke. Add `@playwright/test` as a dev dependency and scripts only if they reduce alias/CI duplication. Keep npm files at repo root because `mix verify.admin` will run from repo root.

### `package-lock.json` (config, batch)

**Analog:** no root codebase analog.

**Use generated pattern:** Create via `npm install --save-dev @playwright/test` so the lockfile is registry-generated, not hand-written. Planner should not ask implementer to manually craft this file.

### `playwright.config.ts` (config, request-response)

**Analog:** partial from demo host endpoint/test config.

From `examples/chimeway_demo_host/config/test.exs` lines 3-6:
```elixir
config :demo_host, DemoHostWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  server: false
```

From `examples/chimeway_demo_host/lib/demo_host_web/endpoint.ex` lines 15-20:
```elixir
plug(Plug.Static,
  at: "/chimeway_admin",
  from: {:chimeway_admin, "priv/static"},
  gzip: false,
  only: ~w(chimeway_admin.css)
)
```

**Apply to Phase 72:** Configure Playwright with Chromium, base URL `http://127.0.0.1:4002`, and a `webServer` command that starts the demo host with `PHX_SERVER=true` or equivalent. Ensure the command prepares/uses the test database before the browser opens, or make `mix verify.admin` run database setup before invoking Playwright.

### `test/browser/admin_smoke.spec.ts` (test, request-response)

**Analog:** partial from demo-host mounted admin tests.

From `examples/chimeway_demo_host/test/demo_host_web/admin_trace_live_test.exs` lines 15-33:
```elixir
@tag :journey
@tag :admin_truth
test "admin command center exposes shipped operator paths", %{conn: conn} do
  conn = get(conn, "/admin/chimeway")
  assert html_response(conn, 200) =~ "Command Center"

  {:ok, view, html} = live(conn)

  assert html =~ "Open Trace Lookup"
  assert html =~ "Trace Lookup"
  assert html =~ "Feed Debug"
  assert html =~ "Definitions"
  assert html =~ "Health"
  assert html =~ "Recovery"

  rendered = render(view)
  assert rendered =~ "Command Center"
  assert rendered =~ "Open Trace Lookup"
end
```

From `examples/chimeway_demo_host/test/demo_host_web/admin_trace_live_test.exs` lines 37-64:
```elixir
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

  assert html =~ DemoHost.Seeds.alex_identity()

  delivery_id =
    Enum.find(delivery_ids, &String.contains?(html, &1)) ||
      flunk("expected search results to include a seeded delivery id")

  {:ok, detail_view, detail_html} = live(conn, "/admin/chimeway/deliveries/#{delivery_id}")
  assert detail_html =~ "Trace Detail"
end
```

From `chimeway_admin/test/chimeway_admin/design_system_test.exs` lines 8-15:
```elixir
test "packaged stylesheet stays scoped and framework-free" do
  assert @css =~ "@layer cw.tokens"
  assert @css =~ ":where(.chimeway-admin)"
  refute @css =~ "@tailwind"
  refute @css =~ "bootstrap"
  refute @css =~ "shadcn"
  refute @css =~ "radix"
end
```

**Apply to Phase 72:** In Playwright, visit `/admin/chimeway`, assert a visible `Command Center`, assert the packaged CSS link or CSS-applied computed style, navigate `/traces`, `/feed`, `/definitions`, `/health`, `/recovery`, and use the trace search form enough to catch blank-page, asset-serving, and LiveView navigation regressions. Keep domain semantics in ExUnit; this smoke should stay narrow.

## Shared Patterns

### Admin Mount And Static Assets

**Source:** `examples/chimeway_demo_host/lib/demo_host_web/router.ex`, `endpoint.ex`, `root.html.heex`
**Apply to:** admin guide, browser smoke, doc contracts

`router.ex` lines 23-28:
```elixir
scope "/admin/chimeway" do
  pipe_through :browser

  import ChimewayAdmin.Router
  chimeway_admin_routes()
end
```

`endpoint.ex` lines 15-20:
```elixir
plug(Plug.Static,
  at: "/chimeway_admin",
  from: {:chimeway_admin, "priv/static"},
  gzip: false,
  only: ~w(chimeway_admin.css)
)
```

`root.html.heex` lines 3-8:
```heex
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Chimeway Demo Host</title>
  <link rel="stylesheet" href={ChimewayAdmin.Assets.css_path()} />
</head>
```

### Fail-Closed Admin Auth

**Source:** `chimeway_admin/lib/chimeway_admin/live_auth.ex`, `examples/chimeway_demo_host/lib/demo_host/admin_auth.ex`
**Apply to:** admin guide, doc contracts, smoke assumptions

`live_auth.ex` lines 1-9:
```elixir
defmodule ChimewayAdmin.LiveAuth do
  @moduledoc """
  LiveView `on_mount` hook — fail-closed authorization via `ChimewayAdmin.Auth`.

  Host must set `current_actor` on the socket assign or in the session under
  `"current_actor"` before the admin LiveView mounts.

  Allowed `authorize/3` return values: `:ok` or `{:error, :unauthorized}`.
  Any other return is logged and treated as unauthorized.
  """
```

`live_auth.ex` lines 64-87:
```elixir
defp authorize(action, admin_context, extra_context) do
  auth_module = Auth.auth_module()
  actor = admin_context.actor
  context = Context.authorize_context(admin_context, action, extra_context)

  case auth_module.authorize(actor, action, context) do
    :ok ->
      :ok

    {:error, :unauthorized} ->
      {:error, :unauthorized}

    other ->
      require Logger

      Logger.warning(
        "ChimewayAdmin.Auth.authorize/3 returned an unexpected value; treating as unauthorized",
        action: action,
        auth_module: inspect(auth_module),
        return_type: unexpected_return_type(other)
      )

      {:error, :unauthorized}
  end
end
```

### Host Context And Tenant Boundary

**Source:** `chimeway_admin/lib/chimeway_admin/context.ex`
**Apply to:** admin guide, doc contracts

Lines 1-8:
```elixir
defmodule ChimewayAdmin.Context do
  @moduledoc """
  Shared host-provided context for Chimeway admin LiveViews.

  The context normalizes actor and tenant scope for reads and authorization.
  It does not validate tenant membership or host policy; that remains owned by
  the configured `ChimewayAdmin.Auth` implementation.
  """
```

Lines 33-41:
```elixir
@spec from(map(), map(), Phoenix.LiveView.Socket.t()) :: t()
def from(params, session, socket) do
  %{
    actor: socket.assigns[:current_actor] || session["current_actor"],
    tenant_id: tenant_id(params, session),
    params: params || %{},
    session: session || %{},
    live_view: Map.get(socket, :view)
  }
end
```

### Redaction Contracts

**Source:** `test/chimeway/admin_test.exs`, `chimeway_admin/test/chimeway_admin/live/privacy_leak_live_test.exs`
**Apply to:** admin guide, doc contracts, verify.admin alias

`test/chimeway/admin_test.exs` lines 26-42:
```elixir
@forbidden_keys ~w(
  payload render_assigns render_data provider_response provider_body metadata session params
  token secret auth_code authorization
)a

@sensitive_values [
  "raw-payload-secret-71",
  "render-assign-secret-71",
  "render-data-secret-71",
  "provider-body-secret-71",
  "metadata-secret-71",
  "bearer-token-71",
  "api-key-secret-71",
  "params-auth-code-71",
  "alex.full-pii@example.test",
  "+15551234567"
]
```

`test/chimeway/admin_test.exs` lines 151-168:
```elixir
assert_exact_keys(command_center, @command_center_keys)
assert_exact_keys(problem, @recent_problem_keys)
assert Enum.count(definitions) == 2
Enum.each(definitions, &assert_exact_keys(&1, @definition_keys))
assert Enum.count(feed_rows) == 2
Enum.each(feed_rows, &assert_exact_keys(&1, @feed_keys))
assert_exact_keys(recovery, @recovery_keys)
assert map_size(outcomes) > 0
assert Enum.all?(Map.keys(outcomes), &is_binary/1)

assert problem.recipient_id == "user:privacy-71"
assert Enum.all?(feed_rows, &(&1.recipient_id == "user:privacy-71"))
assert recovery.recipient_id == "user:privacy-71"

all_dtos = [command_center, problem, definitions, feed_rows, recovery, outcomes]

assert_no_forbidden_keys(all_dtos)
assert_no_sensitive_values(all_dtos)
```

### Route Prefix Contract

**Source:** `chimeway_admin/test/chimeway_admin/routes_test.exs`
**Apply to:** admin guide, doc contracts, browser smoke path expectations

Lines 24-34:
```elixir
test "path/1 prepends configured mount prefix" do
  Application.put_env(:chimeway_admin, :path_prefix, "/admin/chimeway")

  assert Routes.search_path() == "/admin/chimeway/"
  assert Routes.traces_path() == "/admin/chimeway/traces"
  assert Routes.feed_path() == "/admin/chimeway/feed"
  assert Routes.definitions_path() == "/admin/chimeway/definitions"
  assert Routes.health_path() == "/admin/chimeway/health"
  assert Routes.recovery_path() == "/admin/chimeway/recovery"
  assert Routes.delivery_path("abc") == "/admin/chimeway/deliveries/abc"
end
```

## No Analog Found

Files with no close match in the codebase:

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `package.json` | config | batch | No root Node/npm harness exists; only dependency package JSON files under deps. |
| `package-lock.json` | config | batch | Must be generated by npm, not copied from repo code. |
| `playwright.config.ts` | config | request-response | No Playwright config exists; use Playwright docs plus demo-host endpoint config. |

## Metadata

**Analog search scope:** root `mix.exs`, `.github/workflows/ci.yml`, `MAINTAINING.md`, `guides/introduction/`, `test/chimeway/`, `chimeway_admin/lib/`, `chimeway_admin/test/`, `examples/chimeway_demo_host/`
**Files scanned:** 28
**Pattern extraction date:** 2026-06-04
**Project skills:** no project-local `.codex/skills/` or `.agents/skills/` skill files found.
**Worktree note:** existing unrelated modifications were present before writing this file; they were not reverted or edited.
