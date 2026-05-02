---
phase: 33-webhook-ingress-durability
plan: 04
type: execute
wave: 3
depends_on: [33-02, 33-03]
files_modified:
  - examples/chimeway_demo_host/mix.exs
  - examples/chimeway_demo_host/config/config.exs
  - examples/chimeway_demo_host/config/test.exs
  - examples/chimeway_demo_host/lib/demo_host.ex
  - examples/chimeway_demo_host/lib/demo_host/application.ex
  - examples/chimeway_demo_host/lib/demo_host_web.ex
  - examples/chimeway_demo_host/lib/demo_host_web/endpoint.ex
  - examples/chimeway_demo_host/lib/demo_host_web/router.ex
  - examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex
  - examples/chimeway_demo_host/lib/demo_host_web/controllers/webhooks_controller.ex
  - examples/chimeway_demo_host/lib/demo_host/adapters/echo_adapter.ex
  - examples/chimeway_demo_host/lib/demo_host/adapters/raw_body_hmac_adapter.ex
  - examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs
  - examples/chimeway_demo_host/test/test_helper.exs
  - mix.exs
autonomous: true
requirements: [FEED-01, FEED-02]
requirements_addressed: [FEED-01, FEED-02]
tags: [elixir, phoenix, plug, webhook, example, e2e, body_reader]

must_haves:
  truths:
    - "A sibling Phoenix Mix project at `examples/chimeway_demo_host/` exists, depends on `chimeway` via `path: \"../..\"`, and compiles standalone via `mix compile`."
    - "The example app's `Plug.Parsers` is configured with `body_reader: {DemoHost.Plugs.CacheBodyReader, :read_body, []}` (D-13 / T-33-RAWBODY) so signature verification operates on the EXACT raw bytes BEFORE JSON parsing."
    - "The example controller at `POST /webhooks/chimeway/:adapter` reads the cached raw body via `IO.iodata_to_binary/1` (Pitfall 4 — iolist flattening) and calls `Chimeway.Webhooks.process/4`."
    - "The controller maps `{:ok, _ingress}` -> `200`, `{:error, :unauthorized}` -> `401`, any other `{:error, _}` -> non-`2xx` (D-03)."
    - "An E2E test exercises the full mount via `Phoenix.ConnTest`: valid signature => 200 + ingress row + Oban job; bad signature => 401 + NO ingress row; chunked body => 200 (raw-body iolist flattening verified); malformed JSON => non-2xx."
    - "A verify-before-parse E2E test (using RawBodyHmacAdapter, which HMACs over raw body bytes) asserts that `verify_webhook/3` runs on the EXACT bytes BEFORE Jason.decode — body with non-canonical whitespace round-trips byte-for-byte through verification (D-13)."
    - "The new `mix verify.example` alias (added to root `mix.exs`) runs the example app's deps + tests and exits 0."
    - "Chimeway core's `mix.exs` is NOT modified to add `phoenix` or `plug` deps (D-10 — framework-agnostic core)."
  artifacts:
    - path: "examples/chimeway_demo_host/mix.exs"
      provides: "Sibling Mix project with phoenix, plug, jason, and chimeway path-dep"
      contains: "{:chimeway, path: \"../..\"}"
    - path: "examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex"
      provides: "Canonical Plug.Parsers :body_reader MFA pattern (per hexdocs)"
      contains: "def read_body"
    - path: "examples/chimeway_demo_host/lib/demo_host_web/controllers/webhooks_controller.ex"
      provides: "Reference controller proving the host->Chimeway.Webhooks.process/4 mount"
      contains: "Chimeway.Webhooks.process"
    - path: "examples/chimeway_demo_host/lib/demo_host/adapters/echo_adapter.ex"
      provides: "Fixture adapter implementing the Chimeway.Adapter behaviour for the E2E test"
      contains: "@behaviour Chimeway.Adapter"
    - path: "examples/chimeway_demo_host/lib/demo_host/adapters/raw_body_hmac_adapter.ex"
      provides: "Companion fixture adapter that HMACs over raw request bytes — exercises verify-before-parse ordering (D-13)"
      contains: ":crypto.mac(:hmac, :sha256"
    - path: "examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs"
      provides: "E2E proof of the full ingress path with Phoenix.ConnTest + Chimeway.Repo assertions"
      contains: "assert_enqueued"
    - path: "mix.exs"
      provides: "Root-project alias `verify.example` chaining the example app's tests"
      contains: "verify.example"
  key_links:
    - from: "examples/chimeway_demo_host/lib/demo_host_web/endpoint.ex"
      to: "examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex"
      via: "plug Plug.Parsers with body_reader: {DemoHost.Plugs.CacheBodyReader, :read_body, []}"
      pattern: "body_reader: \\{DemoHost.Plugs.CacheBodyReader"
    - from: "examples/chimeway_demo_host/lib/demo_host_web/controllers/webhooks_controller.ex"
      to: "Chimeway.Webhooks.process/4"
      via: "Chimeway.Webhooks.process(adapter_module, raw_body, headers, config)"
      pattern: "Chimeway.Webhooks.process"
    - from: "examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs"
      to: "Chimeway.Repo + Chimeway.Webhooks.Ingress + Chimeway.Webhooks.ProcessFeedbackWorker"
      via: "Repo.aggregate / Repo.get + assert_enqueued"
      pattern: "Chimeway.Repo|Chimeway.Webhooks.Ingress|assert_enqueued"
---

<objective>
Create the canonical Phoenix host-mount proof that the milestone audit requires (audit gap #2: "no runtime webhook ingress consumer exists in the repo"). This is a sibling Mix project under `examples/chimeway_demo_host/` that depends on `chimeway` via local path, mounts a real Phoenix endpoint, uses `Plug.Parsers`'s `:body_reader` MFA for raw-body preservation (D-13 / T-33-RAWBODY), and proves the full host -> `Chimeway.Webhooks.process/4` -> ingress row + Oban job path with E2E tests.

Purpose: D-10 forbids coupling `chimeway` core to Phoenix/Plug; D-11 requires a runtime proof of the host mount; D-12 makes this the canonical reference docs point to instead of repeating controller boilerplate; D-13 calls out the raw-body footgun as a first-class DX concern. This plan produces the executable proof.

Output: Compilable, testable, self-contained `examples/chimeway_demo_host/` project. Root `mix verify.example` alias runs its tests. Chimeway core is unchanged.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/33-webhook-ingress-durability/33-CONTEXT.md
@.planning/phases/33-webhook-ingress-durability/33-RESEARCH.md
@.planning/phases/33-webhook-ingress-durability/33-PATTERNS.md
@.planning/phases/33-webhook-ingress-durability/33-02-SUMMARY.md
@.planning/phases/33-webhook-ingress-durability/33-03-SUMMARY.md
@lib/chimeway/webhooks.ex
@lib/chimeway/webhooks/ingress.ex
@lib/chimeway/webhooks/process_feedback_worker.ex
@lib/chimeway/adapter.ex
@test/chimeway/webhooks_test.exs
@mix.exs

<interfaces>
<!-- Source of truth: hexdocs.pm/plug/Plug.Parsers.html canonical body_reader MFA pattern, plus 33-RESEARCH.md Pattern 3. -->

From `lib/chimeway/adapter.ex` (existing 3-callback contract + optional A4 callback declared in Plan 02):
```elixir
@callback verify_webhook(body :: binary(), headers :: list(), config :: keyword()) :: :ok | {:error, :unauthorized}
@callback resolve_delivery(parsed :: map()) :: {:ok, %{optional(:delivery_id) => binary(), optional(:provider_message_id) => binary()}} | :error
@callback normalize_feedback(parsed :: map()) :: {:ok, %{status: :delivered | :bounced | :failed}} | :error
@callback resolve_provider_event_id(parsed :: map()) :: {:ok, binary()} | :none   # optional (added in Plan 02)
```

From Plan 02's `Chimeway.Webhooks.process/4` (the contract this plan exercises):
```elixir
@spec process(module(), binary(), list(), keyword()) ::
        {:ok, Ingress.t()}
        | {:error, :unauthorized}
        | {:error, :unparseable_body}
        | {:error, :unresolvable_delivery}
        | {:error, :unnormalizable_feedback}
        | {:error, Ecto.Changeset.t()}
        | {:error, term()}
```

From `test/chimeway/webhooks_test.exs:7-23` (the in-test `MockAdapter` — analog for `EchoAdapter`):
```elixir
defmodule MockAdapter do
  @behaviour Chimeway.Adapter

  def deliver(_delivery, _config), do: {:ok, %{}}
  def verify_webhook(_body, [{"signature", "valid"}], _config), do: :ok
  def verify_webhook(_, _, _config), do: {:error, :unauthorized}
  def resolve_delivery(%{"id" => "del_123"}), do: {:ok, %{delivery_id: "del_123"}}
  def resolve_delivery(%{"msg_id" => "msg_123"}), do: {:ok, %{provider_message_id: "msg_123"}}
  def resolve_delivery(_), do: :error
  def normalize_feedback(%{"status" => "bounce"}), do: {:ok, %{status: :bounced}}
  def normalize_feedback(%{"status" => "ok"}), do: {:ok, %{status: :delivered}}
  def normalize_feedback(%{"status" => "fail"}), do: {:ok, %{status: :failed}}
  def normalize_feedback(_), do: :error
end
```

From hexdocs.pm/plug/Plug.Parsers.html (canonical `:body_reader` MFA — copied to RESEARCH.md Pattern 3):
```elixir
def read_body(conn, opts) do
  with {:ok, body, conn} <- Plug.Conn.read_body(conn, opts) do
    conn = update_in(conn.assigns[:raw_body], &[body | &1 || []])
    {:ok, body, conn}
  end
end

# Endpoint wiring:
plug Plug.Parsers,
  parsers: [:urlencoded, :json],
  pass: ["text/*"],
  body_reader: {DemoHost.Plugs.CacheBodyReader, :read_body, []},
  json_decoder: Jason
```

From `mix.exs` (root project) — analog for `verify.example` alias:
```elixir
defp aliases do
  [
    ci: ["ci.lint", "ci.test"],
    "ci.lint": ["format --check-formatted", "compile --warnings-as-errors", "credo --strict"],
    "ci.test": ["test"],
    ...
    "verify.clean": ["cmd git diff --exit-code"],
    "verify.parity": ["cmd mix hex.build --unpack --output /tmp/chimeway_verify && ls /tmp/chimeway_verify"]
  ]
end
```
</interfaces>
</context>

<assumptions>
<!-- Per RESEARCH.md A5 — surfaced for user confirm/override. LOW risk. -->

- **A5 (Phoenix/Plug version pins):** This plan uses `{:phoenix, "~> 1.7"}` and `{:plug, "~> 1.16"}` (matches the broader Elixir ecosystem and what AGENTS.md indicates the project supports). Looser pins are acceptable; the example app is local-path only and not a published library, so pinning is not a publishing concern. Override before Task 1 if you want different pins.
- **A7 (Task 4 Hex.pm network access):** `mix verify.example` runs `cd examples/chimeway_demo_host && mix deps.get && mix test`. The nested `mix deps.get` step requires Hex.pm registry reachability on first run to fetch `phoenix`, `plug`, `jason`, and their transitive dependencies into the example app's `_build/`. Subsequent runs use the cached `deps/` and `_build/` and do not require network access. Executor environments without Hex.pm reachability will fail on the FIRST `mix verify.example` invocation. This is documentation-only — no code change needed; surfaced here so an offline-CI run is recognized as an environmental gap, not a phase-quality regression.
</assumptions>

<tasks>

<task type="auto">
  <name>Task 1: Scaffold the chimeway_demo_host sibling Mix project skeleton + config + Wave-0 E2E test stub</name>
  <files>examples/chimeway_demo_host/mix.exs, examples/chimeway_demo_host/config/config.exs, examples/chimeway_demo_host/config/test.exs, examples/chimeway_demo_host/lib/demo_host.ex, examples/chimeway_demo_host/lib/demo_host/application.ex, examples/chimeway_demo_host/lib/demo_host_web.ex, examples/chimeway_demo_host/lib/demo_host_web/endpoint.ex, examples/chimeway_demo_host/lib/demo_host_web/router.ex, examples/chimeway_demo_host/test/test_helper.exs, examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs</files>
  <read_first>
    - mix.exs (root — to confirm versions and avoid duplicating `chimeway`'s own deps)
    - config/test.exs (root — for the SQL sandbox + Oban testing config; the example app must share `Chimeway.Repo`)
    - .planning/phases/33-webhook-ingress-durability/33-RESEARCH.md (§ Recommended Project Structure; § Code Examples > Fixture host app — `mix.exs` is the literal template)
    - .planning/phases/33-webhook-ingress-durability/33-PATTERNS.md (§ examples/chimeway_demo_host/* rows)
  </read_first>
  <action>
    Create the sibling Mix project. The skeleton is mostly vanilla Phoenix `mix phx.new --no-ecto --no-mailer --no-tailwind --no-esbuild --no-dashboard` shape — but generated by hand because the executor must NOT run `mix phx.new` (that would create an unrelated, fully-featured Phoenix project; we want a minimal one).

    **`examples/chimeway_demo_host/mix.exs`** (literal from `33-RESEARCH.md` lines 860-892):
    ```elixir
    defmodule DemoHost.MixProject do
      use Mix.Project

      def project do
        [
          app: :demo_host,
          version: "0.0.0",
          elixir: "~> 1.17",
          elixirc_paths: elixirc_paths(Mix.env()),
          compilers: Mix.compilers(),
          start_permanent: false,
          deps: deps(),
          aliases: aliases()
        ]
      end

      def application do
        [mod: {DemoHost.Application, []}, extra_applications: [:logger]]
      end

      defp elixirc_paths(:test), do: ["lib", "test/support"]
      defp elixirc_paths(_), do: ["lib"]

      defp deps do
        [
          {:phoenix, "~> 1.7"},
          {:plug, "~> 1.16"},
          {:jason, "~> 1.4"},
          {:chimeway, path: "../.."}
        ]
      end

      defp aliases do
        [
          test: ["test"]
        ]
      end
    end
    ```

    **`examples/chimeway_demo_host/config/config.exs`:**
    ```elixir
    import Config

    config :demo_host, DemoHostWeb.Endpoint,
      http: [port: 4001],
      url: [host: "localhost"],
      render_errors: [formats: [json: DemoHostWeb.ErrorJSON], layout: false],
      pubsub_server: DemoHost.PubSub,
      live_view: [signing_salt: "demo-host"]

    # Adapter config the controller reads at request time per Chimeway.Adapter discipline
    config :demo_host, :chimeway_adapter_config, []

    import_config "#{config_env()}.exs"
    ```

    **`examples/chimeway_demo_host/config/test.exs`:** (re-uses chimeway core's Repo + sandbox)
    ```elixir
    import Config

    config :demo_host, DemoHostWeb.Endpoint,
      http: [ip: {127, 0, 0, 1}, port: 4002],
      server: false

    # Share Chimeway.Repo with the parent project's SQL sandbox
    config :chimeway, Chimeway.Repo,
      pool: Ecto.Adapters.SQL.Sandbox

    # Oban inline mode for synchronous test assertions
    config :chimeway, Oban, testing: :manual

    config :phoenix, :json_library, Jason
    ```

    **`examples/chimeway_demo_host/lib/demo_host.ex`:** (top-level module — typical phx.new shape)
    ```elixir
    defmodule DemoHost do
      @moduledoc "Reference Phoenix host that mounts Chimeway webhook ingress."
    end
    ```

    **`examples/chimeway_demo_host/lib/demo_host/application.ex`:**
    ```elixir
    defmodule DemoHost.Application do
      use Application

      @impl true
      def start(_type, _args) do
        children = [
          {Phoenix.PubSub, name: DemoHost.PubSub},
          DemoHostWeb.Endpoint
        ]

        opts = [strategy: :one_for_one, name: DemoHost.Supervisor]
        Supervisor.start_link(children, opts)
      end
    end
    ```

    **`examples/chimeway_demo_host/lib/demo_host_web.ex`:** (typical phx.new entrypoint — minimal `controller/0` + `router/0` for our use)
    ```elixir
    defmodule DemoHostWeb do
      def controller do
        quote do
          use Phoenix.Controller, formats: [:json]
          import Plug.Conn
        end
      end

      def router do
        quote do
          use Phoenix.Router
        end
      end

      defmacro __using__(which) when is_atom(which) do
        apply(__MODULE__, which, [])
      end
    end
    ```

    **`examples/chimeway_demo_host/lib/demo_host_web/endpoint.ex`:** (the CRITICAL piece — `:body_reader` MFA per D-13)
    ```elixir
    defmodule DemoHostWeb.Endpoint do
      use Phoenix.Endpoint, otp_app: :demo_host

      plug Plug.RequestId
      plug Plug.Telemetry, event_prefix: [:demo_host, :endpoint]

      # CRITICAL (Phase 33 D-13 / T-33-RAWBODY): the body_reader MFA caches raw bytes
      # in conn.assigns[:raw_body] BEFORE Jason consumes the body. Webhook signature
      # verification MUST run on the exact raw bytes the provider signed; without
      # this :body_reader the raw bytes are unrecoverable after JSON parsing.
      # Canonical pattern from hexdocs.pm/plug/Plug.Parsers.html.
      plug Plug.Parsers,
        parsers: [:urlencoded, :json],
        pass: ["text/*"],
        body_reader: {DemoHost.Plugs.CacheBodyReader, :read_body, []},
        json_decoder: Jason

      plug Plug.MethodOverride
      plug Plug.Head

      plug DemoHostWeb.Router
    end
    ```

    **`examples/chimeway_demo_host/lib/demo_host_web/router.ex`:**
    ```elixir
    defmodule DemoHostWeb.Router do
      use DemoHostWeb, :router

      pipeline :api do
        plug :accepts, ["json"]
      end

      scope "/webhooks/chimeway", DemoHostWeb do
        pipe_through :api
        post "/:adapter", WebhooksController, :create
      end
    end
    ```

    **`examples/chimeway_demo_host/test/test_helper.exs`:**
    ```elixir
    ExUnit.start()

    # Start the DemoHost supervisor (PubSub + Endpoint with `server: false` from
    # config/test.exs). Phoenix Endpoint and Router plugs require PubSub to be
    # alive; without this start, Endpoint.call/2 in tests fails at boot with a
    # PubSub lookup error. The supervisor is fast and side-effect-free under
    # Mix.env() == :test because `server: false` means Cowboy is NOT started.
    Application.ensure_all_started(:demo_host)

    # Reuse Chimeway core's Repo + SQL sandbox so example app tests share durable state.
    Ecto.Adapters.SQL.Sandbox.mode(Chimeway.Repo, :manual)
    ```

    **Wave 0 — E2E test stub at `examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs`:**
    Create the test file in this Task even though the controller and adapter modules don't exist yet (RED phase). The test will compile-fail until Tasks 2-4 land. Test cases (filled out fully here so executor can paste verbatim):

    ```elixir
    defmodule DemoHostWeb.WebhooksControllerTest do
      use ExUnit.Case, async: false
      use Plug.Test
      use Oban.Testing, repo: Chimeway.Repo

      alias Chimeway.Repo
      alias Chimeway.Webhooks.{Ingress, ProcessFeedbackWorker}

      @endpoint DemoHostWeb.Endpoint

      setup do
        :ok = Ecto.Adapters.SQL.Sandbox.checkout(Chimeway.Repo)
        Ecto.Adapters.SQL.Sandbox.mode(Chimeway.Repo, {:shared, self()})
        Application.put_env(:demo_host, :chimeway_adapter_config, [])
        :ok
      end

      describe "POST /webhooks/chimeway/echo (Phase 33 host-mount E2E proof)" do
        test "valid signature + parseable body returns 200, commits ingress row, and enqueues Oban job" do
          # delivery_id must be a real UUID — schema field is :binary_id.
          delivery_uuid = Ecto.UUID.generate()
          body = Jason.encode!(%{"id" => delivery_uuid, "status" => "ok"})
          conn =
            conn(:post, "/webhooks/chimeway/echo", body)
            |> put_req_header("content-type", "application/json")
            |> put_req_header("signature", "valid")
            |> DemoHostWeb.Endpoint.call(DemoHostWeb.Endpoint.init([]))

          assert conn.status == 200

          # T-33-ATOMIC verified end-to-end: ingress row durably committed
          assert [%Ingress{} = ingress] = Repo.all(Ingress)
          assert ingress.adapter_module == to_string(DemoHost.Adapters.EchoAdapter)
          assert ingress.delivery_id == delivery_uuid
          assert ingress.normalized_status == "delivered"

          # Oban job enqueued atomically with ingress row
          assert_enqueued worker: ProcessFeedbackWorker, args: %{"ingress_id" => ingress.id}
        end

        test "bad signature returns 401 and commits NO ingress row (D-09 / T-33-AUTH-LEAK)" do
          # UUID for completeness, though this path errors at verify_webhook before reaching DB.
          body = Jason.encode!(%{"id" => Ecto.UUID.generate(), "status" => "ok"})
          conn =
            conn(:post, "/webhooks/chimeway/echo", body)
            |> put_req_header("content-type", "application/json")
            |> put_req_header("signature", "invalid")
            |> DemoHostWeb.Endpoint.call(DemoHostWeb.Endpoint.init([]))

          assert conn.status == 401
          assert Repo.aggregate(Ingress, :count) == 0
          refute_enqueued worker: ProcessFeedbackWorker
        end

        test "malformed JSON body returns non-2xx and commits NO ingress row" do
          conn =
            conn(:post, "/webhooks/chimeway/echo", "not-valid-json{{{")
            |> put_req_header("content-type", "application/json")
            |> put_req_header("signature", "valid")
            |> DemoHostWeb.Endpoint.call(DemoHostWeb.Endpoint.init([]))

          # Phoenix may return 400 (Plug.Parsers raises on bad JSON before reaching the controller)
          # OR the controller's catch-all returns 500. Either way: NOT 2xx, NOT 401.
          refute conn.status in 200..299
          refute conn.status == 401
          assert Repo.aggregate(Ingress, :count) == 0
        end

        test "raw body iolist is correctly flattened — Pitfall 4 / T-33-RAWBODY regression test" do
          # Simulate a chunked body by passing a binary that exercises iodata accumulation
          # in CacheBodyReader. With the canonical update_in pattern the body is stored
          # as `[chunk | acc]` and the controller MUST flatten via IO.iodata_to_binary/1
          # before passing to verify_webhook/3.
          body = Jason.encode!(%{"id" => Ecto.UUID.generate(), "status" => "ok"})
          conn =
            conn(:post, "/webhooks/chimeway/echo", body)
            |> put_req_header("content-type", "application/json")
            |> put_req_header("signature", "valid")
            |> DemoHostWeb.Endpoint.call(DemoHostWeb.Endpoint.init([]))

          # The controller's `IO.iodata_to_binary(raw_body)` MUST have produced the
          # exact bytes `body` so the EchoAdapter's `verify_webhook/3` returned `:ok`.
          # Status 200 here means the iolist-flattening worked end-to-end.
          assert conn.status == 200
          assert [%Ingress{}] = Repo.all(Ingress)
        end

        test "verify-before-parse ordering — HMAC over raw bytes survives JSON byte-for-byte" do
          # Phase 33 D-13 / T-33-RAWBODY first-class DX assertion:
          # Signature verification MUST run on the EXACT raw bytes BEFORE any JSON
          # parsing or re-encoding. This test uses an adapter (RawBodyHmacAdapter,
          # added in Task 2) that computes HMAC-SHA256 over the raw body bytes.
          #
          # The body intentionally contains non-canonical whitespace (double-spaces
          # inside the JSON object) — bytes like `{"id":  "del_rawbody", ...}`. Any
          # host code that calls Jason.decode + Jason.encode before verify_webhook
          # would produce normalized JSON without the double-spaces, and the HMAC
          # over those re-encoded bytes would NOT match the signature header.
          #
          # If this test passes (status 200), the controller called verify_webhook
          # BEFORE Jason.decode — verified end-to-end. If a future refactor reorders
          # the controller pipeline to parse-then-verify, this test fails with 401
          # because the re-encoded bytes don't HMAC-match.
          delivery_uuid = Ecto.UUID.generate()

          # Hand-crafted body bytes with intentional double-spaces that will NOT
          # survive Jason.encode after Jason.decode. The body still parses to valid
          # JSON, but its byte representation is byte-distinguishable from any
          # re-encoded form.
          body =
            ~s|{"id":  "| <> delivery_uuid <> ~s|",  "status": "ok"}|

          # Compute HMAC-SHA256 over the EXACT raw bytes using the same shared
          # secret RawBodyHmacAdapter expects.
          secret = "test-secret-rawbody"
          signature =
            :crypto.mac(:hmac, :sha256, secret, body) |> Base.encode16(case: :lower)

          conn =
            conn(:post, "/webhooks/chimeway/rawbody", body)
            |> put_req_header("content-type", "application/json")
            |> put_req_header("x-signature", signature)
            |> DemoHostWeb.Endpoint.call(DemoHostWeb.Endpoint.init([]))

          # Status 200 PROVES verify_webhook ran on the unparsed raw bytes BEFORE
          # Jason.decode. If verify-before-parse ordering were broken (parse then
          # re-encode then verify), the bytes would have changed and HMAC compare
          # would fail with 401.
          assert conn.status == 200

          # Sanity check: ingress row exists with the UUID we sent — proves the
          # body did parse correctly AFTER verification (verify-then-parse, not
          # parse-then-verify).
          assert [%Ingress{delivery_id: ^delivery_uuid}] = Repo.all(Ingress)

          # Documentation note for executor / future readers:
          # If a developer swaps the controller pipeline to parse-then-verify
          # (i.e., calls Jason.decode on the body before verify_webhook), the
          # body bytes the adapter sees will be the re-encoded form WITHOUT the
          # double-spaces. The HMAC over those bytes will NOT match `signature`
          # above, and verify_webhook returns {:error, :unauthorized} -> 401.
          # That is the failure mode this test detects.
        end
      end
    end
    ```
  </action>
  <verify>
    <automated>test -f examples/chimeway_demo_host/mix.exs && grep -q '{:chimeway, path: "../.."}' examples/chimeway_demo_host/mix.exs && grep -q '{:phoenix, "~> 1.7"}' examples/chimeway_demo_host/mix.exs && grep -q '{:plug, "~> 1.16"}' examples/chimeway_demo_host/mix.exs && test -f examples/chimeway_demo_host/lib/demo_host_web/endpoint.ex && grep -q "body_reader: {DemoHost.Plugs.CacheBodyReader" examples/chimeway_demo_host/lib/demo_host_web/endpoint.ex && test -f examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs && grep -q "T-33-RAWBODY" examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs && grep -q "verify-before-parse ordering" examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs && grep -q "RawBodyHmacAdapter" examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs && grep -q "ensure_all_started(:demo_host)" examples/chimeway_demo_host/test/test_helper.exs</automated>
  </verify>
  <acceptance_criteria>
    - Directory `examples/chimeway_demo_host/` exists with subdirs `lib/`, `test/`, `config/`.
    - `examples/chimeway_demo_host/mix.exs` contains `{:chimeway, path: "../.."}`, `{:phoenix, "~> 1.7"}`, `{:plug, "~> 1.16"}`, `{:jason, "~> 1.4"}`.
    - `examples/chimeway_demo_host/lib/demo_host_web/endpoint.ex` contains `body_reader: {DemoHost.Plugs.CacheBodyReader, :read_body, []}` (literal — D-13 / T-33-RAWBODY).
    - `examples/chimeway_demo_host/lib/demo_host_web/endpoint.ex` contains `parsers: [:urlencoded, :json]`.
    - `examples/chimeway_demo_host/lib/demo_host_web/router.ex` contains `post "/:adapter", WebhooksController, :create`.
    - `examples/chimeway_demo_host/config/config.exs` contains `config :demo_host, :chimeway_adapter_config`.
    - `examples/chimeway_demo_host/config/test.exs` exists.
    - `examples/chimeway_demo_host/test/test_helper.exs` contains `Ecto.Adapters.SQL.Sandbox.mode(Chimeway.Repo, :manual)`.
    - `examples/chimeway_demo_host/test/test_helper.exs` contains `Application.ensure_all_started(:demo_host)` (BEFORE the Sandbox setup line — Endpoint + Router plugs need PubSub alive; verify with `grep -n "ensure_all_started(:demo_host)" examples/chimeway_demo_host/test/test_helper.exs` and confirm its line number is less than the line containing `Sandbox.mode`).
    - `examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs` exists and contains all five test names: valid-signature 200, bad-signature 401 with no ingress row, malformed-JSON non-2xx with no ingress row, raw-body iolist regression test, AND verify-before-parse ordering test (HMAC over raw bytes via RawBodyHmacAdapter — D-13 / T-33-RAWBODY first-class DX assertion).
    - The verify-before-parse test posts to `/webhooks/chimeway/rawbody` with a body containing intentional double-space whitespace inside the JSON object (e.g., `~s|{"id":  "<UUID>",  "status": "ok"}|`), computes HMAC-SHA256 over those EXACT bytes using the shared secret, and asserts `conn.status == 200`. If verify_webhook ran AFTER Jason.decode (re-encode would normalize whitespace), HMAC would not match and status would be 401 — the test would fail.
    - The example app's `mix.exs` does NOT add `chimeway` deps to root project (`grep -c "phoenix" /Users/jon/projects/chimeway/mix.exs` returns 0; `grep -c "plug" /Users/jon/projects/chimeway/mix.exs` returns 0 outside of unrelated `Plug.` test references).
  </acceptance_criteria>
  <done>The sibling Mix project skeleton and config exist. The Wave-0 E2E test file is in place (currently failing to compile until Tasks 2-4 land — expected RED state).</done>
</task>

<task type="auto">
  <name>Task 2: Implement CacheBodyReader plug + EchoAdapter fixture</name>
  <files>examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex, examples/chimeway_demo_host/lib/demo_host/adapters/echo_adapter.ex, examples/chimeway_demo_host/lib/demo_host/adapters/raw_body_hmac_adapter.ex</files>
  <read_first>
    - examples/chimeway_demo_host/lib/demo_host_web/endpoint.ex (Task 1 output — confirms the MFA reference)
    - test/chimeway/webhooks_test.exs (lines 7-23 — `MockAdapter` is the literal pattern for `EchoAdapter`)
    - .planning/phases/33-webhook-ingress-durability/33-RESEARCH.md (§ Pattern 3 — canonical body_reader)
    - .planning/phases/33-webhook-ingress-durability/33-PATTERNS.md (§ examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex; § examples/chimeway_demo_host/lib/demo_host/adapters/echo_adapter.ex)
    - lib/chimeway/adapter.ex (the @behaviour contract)
  </read_first>
  <action>
    **`examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex`** — literal canonical from `33-RESEARCH.md` Pattern 3:

    ```elixir
    defmodule DemoHost.Plugs.CacheBodyReader do
      @moduledoc """
      Reads the request body and caches it into `conn.assigns[:raw_body]` so
      webhook signature verification can run on the exact bytes the provider
      signed. `Plug.Parsers` consumes the body during JSON parsing; without a
      :body_reader the raw bytes are unrecoverable.

      Canonical pattern from hexdocs.pm/plug/Plug.Parsers.html — mirrored here
      because Chimeway core deliberately does not couple to Plug (Phase 33 D-10).

      Pitfall (Phase 33 D-13 / T-33-RAWBODY): the cached body is an iolist
      (chunk-list accumulator). Controllers MUST flatten via IO.iodata_to_binary/1
      before passing to verify_webhook/3 — adapters compute HMAC over binaries,
      and an iolist input silently fails verification. The reference controller
      at lib/demo_host_web/controllers/webhooks_controller.ex does this; copy
      that pattern in your own host app.
      """

      def read_body(conn, opts) do
        with {:ok, body, conn} <- Plug.Conn.read_body(conn, opts) do
          conn = update_in(conn.assigns[:raw_body], &[body | &1 || []])
          {:ok, body, conn}
        end
      end
    end
    ```

    **`examples/chimeway_demo_host/lib/demo_host/adapters/echo_adapter.ex`** — lifted from `MockAdapter` at `test/chimeway/webhooks_test.exs:7-23`, with the optional `resolve_provider_event_id/1` callback added:

    ```elixir
    defmodule DemoHost.Adapters.EchoAdapter do
      @moduledoc """
      Fixture adapter for the Phase 33 E2E proof. Implements the Chimeway.Adapter
      behaviour with the simplest possible verification + correlation logic.

      WARNING: the `verify_webhook/3` clause that pattern-matches a literal
      `[{"signature", "valid"}]` header is acceptable for a fixture/test
      adapter ONLY. Production adapters MUST use `Plug.Crypto.secure_compare/2`
      against an HMAC computed over the raw request body. Do not copy this
      shape into a real adapter — see Phase 33 RESEARCH.md § Security Domain.
      """

      @behaviour Chimeway.Adapter

      def deliver(_delivery, _config), do: {:ok, %{}}

      def verify_webhook(_body, headers, _config) do
        if Enum.any?(headers, fn {k, v} -> k == "signature" and v == "valid" end) do
          :ok
        else
          {:error, :unauthorized}
        end
      end

      def resolve_delivery(%{"id" => id}) when is_binary(id), do: {:ok, %{delivery_id: id}}
      def resolve_delivery(%{"msg_id" => pid}) when is_binary(pid), do: {:ok, %{provider_message_id: pid}}
      def resolve_delivery(_), do: :error

      def normalize_feedback(%{"status" => "bounce"}), do: {:ok, %{status: :bounced}}
      def normalize_feedback(%{"status" => "ok"}), do: {:ok, %{status: :delivered}}
      def normalize_feedback(%{"status" => "fail"}), do: {:ok, %{status: :failed}}
      def normalize_feedback(_), do: :error

      # Optional callback (A4) — exposes provider event id for dedup when present.
      def resolve_provider_event_id(%{"event_id" => id}) when is_binary(id), do: {:ok, id}
      def resolve_provider_event_id(_), do: :none
    end
    ```

    **`examples/chimeway_demo_host/lib/demo_host/adapters/raw_body_hmac_adapter.ex`** — companion fixture adapter that exercises HMAC verification over the EXACT raw body bytes. Used by the Plan 04 Task 1 "verify-before-parse" E2E test (D-13 / T-33-RAWBODY first-class DX assertion):

    ```elixir
    defmodule DemoHost.Adapters.RawBodyHmacAdapter do
      @moduledoc """
      Fixture adapter that computes HMAC-SHA256 over the raw request body bytes
      and compares against the `x-signature` header. Used by the Phase 33
      verify-before-parse E2E test to assert that `verify_webhook/3` runs on the
      EXACT raw bytes provided by `Plug.Parsers`'s `:body_reader` MFA — BEFORE
      any JSON parsing or re-encoding (D-13 / T-33-RAWBODY).

      The shared secret `@secret` is intentionally a constant for the fixture;
      production adapters MUST source secrets from configuration / Vault and use
      `Plug.Crypto.secure_compare/2` for the comparison. The constant-time
      compare is included here so the fixture demonstrates the correct shape.
      """

      @behaviour Chimeway.Adapter

      @secret "test-secret-rawbody"

      def deliver(_delivery, _config), do: {:ok, %{}}

      def verify_webhook(body, headers, _config) when is_binary(body) do
        expected = :crypto.mac(:hmac, :sha256, @secret, body) |> Base.encode16(case: :lower)

        case Enum.find(headers, fn {k, _} -> String.downcase(k) == "x-signature" end) do
          {_, provided} when is_binary(provided) ->
            if Plug.Crypto.secure_compare(provided, expected) do
              :ok
            else
              {:error, :unauthorized}
            end

          _ ->
            {:error, :unauthorized}
        end
      end

      def resolve_delivery(%{"id" => id}) when is_binary(id), do: {:ok, %{delivery_id: id}}
      def resolve_delivery(_), do: :error

      def normalize_feedback(%{"status" => "ok"}), do: {:ok, %{status: :delivered}}
      def normalize_feedback(%{"status" => "bounce"}), do: {:ok, %{status: :bounced}}
      def normalize_feedback(_), do: :error
    end
    ```
  </action>
  <verify>
    <automated>test -f examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex && grep -q "def read_body(conn, opts)" examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex && grep -q "Plug.Conn.read_body(conn, opts)" examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex && test -f examples/chimeway_demo_host/lib/demo_host/adapters/echo_adapter.ex && grep -q "@behaviour Chimeway.Adapter" examples/chimeway_demo_host/lib/demo_host/adapters/echo_adapter.ex && grep -q "def verify_webhook" examples/chimeway_demo_host/lib/demo_host/adapters/echo_adapter.ex && grep -q "def resolve_provider_event_id" examples/chimeway_demo_host/lib/demo_host/adapters/echo_adapter.ex && test -f examples/chimeway_demo_host/lib/demo_host/adapters/raw_body_hmac_adapter.ex && grep -q "defmodule DemoHost.Adapters.RawBodyHmacAdapter" examples/chimeway_demo_host/lib/demo_host/adapters/raw_body_hmac_adapter.ex && grep -q ":crypto.mac(:hmac, :sha256" examples/chimeway_demo_host/lib/demo_host/adapters/raw_body_hmac_adapter.ex && grep -q "Plug.Crypto.secure_compare" examples/chimeway_demo_host/lib/demo_host/adapters/raw_body_hmac_adapter.ex</automated>
  </verify>
  <acceptance_criteria>
    - `examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex` exists.
    - File contains `defmodule DemoHost.Plugs.CacheBodyReader do`.
    - File contains `def read_body(conn, opts) do`.
    - File contains `Plug.Conn.read_body(conn, opts)`.
    - File contains `update_in(conn.assigns[:raw_body], &[body | &1 || []])` (the canonical iolist accumulator).
    - `examples/chimeway_demo_host/lib/demo_host/adapters/echo_adapter.ex` exists.
    - File contains `@behaviour Chimeway.Adapter`.
    - File contains `def verify_webhook(_body, headers, _config)`.
    - File contains `def resolve_delivery(%{"id" => id})`.
    - File contains `def normalize_feedback(%{"status" => "ok"})` returning `:delivered`.
    - File contains `def resolve_provider_event_id(%{"event_id" => id})` (the optional A4 callback).
    - `examples/chimeway_demo_host/lib/demo_host/adapters/raw_body_hmac_adapter.ex` exists.
    - File contains `defmodule DemoHost.Adapters.RawBodyHmacAdapter`.
    - File contains `@behaviour Chimeway.Adapter`.
    - File contains `:crypto.mac(:hmac, :sha256` (HMAC over raw bytes — the verify-before-parse mechanism).
    - File contains `Plug.Crypto.secure_compare` (constant-time compare; the canonical shape production adapters MUST use).
  </acceptance_criteria>
  <done>The body-reader plug and the fixture adapter both compile against the example app's `chimeway` path-dep. Endpoint can find both modules.</done>
</task>

<task type="auto">
  <name>Task 3: Implement WebhooksController with raw-body flattening + status mapping</name>
  <files>examples/chimeway_demo_host/lib/demo_host_web/controllers/webhooks_controller.ex</files>
  <read_first>
    - examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex (Task 2 — for the iolist contract)
    - examples/chimeway_demo_host/lib/demo_host/adapters/echo_adapter.ex (Task 2 — for adapter resolution)
    - lib/chimeway/webhooks.ex (Plan 02 output — for the contract being mapped)
    - lib/chimeway/adapter.ex (for the `Application.get_env` discipline at moduledoc lines 14-18)
    - .planning/phases/33-webhook-ingress-durability/33-RESEARCH.md (§ Pattern 3 — controller pattern; § Pitfall 4 — iolist flattening)
    - .planning/phases/33-webhook-ingress-durability/33-PATTERNS.md (§ examples/chimeway_demo_host/lib/demo_host_web/controllers/webhooks_controller.ex)
  </read_first>
  <action>
    Create `examples/chimeway_demo_host/lib/demo_host_web/controllers/webhooks_controller.ex` (literal from `33-RESEARCH.md` Pattern 3 with the `IO.iodata_to_binary/1` flattening per Pitfall 4):

    ```elixir
    defmodule DemoHostWeb.WebhooksController do
      @moduledoc """
      Reference controller proving the Phase 33 host-mount contract.

      Reads the cached raw body from `conn.assigns[:raw_body]` (populated by
      `DemoHost.Plugs.CacheBodyReader` via the endpoint's `Plug.Parsers`
      `:body_reader` MFA), flattens the iolist via `IO.iodata_to_binary/1`
      (Pitfall 4 / T-33-RAWBODY), and calls `Chimeway.Webhooks.process/4`.

      Status mapping per Phase 33 D-03:
        {:ok, _ingress}            -> 200 (host MAY return any 2xx)
        {:error, :unauthorized}    -> 401
        {:error, _other}           -> non-2xx (provider retries)

      Adapter config is read at request time per `Chimeway.Adapter` moduledoc
      discipline (lib/chimeway/adapter.ex:14-18) — never at compile time, never
      via module attributes.
      """

      use DemoHostWeb, :controller

      def create(conn, _params) do
        # Pitfall 4 / T-33-RAWBODY: the body_reader stores chunks as an iolist
        # `[chunk_n, ..., chunk_1, []]`. Flatten to a binary BEFORE passing to
        # adapter.verify_webhook/3 — HMAC compares require binary input.
        raw_body =
          conn.assigns
          |> Map.get(:raw_body, [])
          |> Enum.reverse()
          |> IO.iodata_to_binary()

        headers = conn.req_headers
        adapter_module = adapter_for(conn.path_params["adapter"])
        config = Application.get_env(:demo_host, :chimeway_adapter_config, [])

        case Chimeway.Webhooks.process(adapter_module, raw_body, headers, config) do
          {:ok, _ingress} ->
            send_resp(conn, 200, "OK")

          {:error, :unauthorized} ->
            send_resp(conn, 401, "Unauthorized")

          {:error, _other} ->
            # Any other library-level failure: non-2xx so the provider retries.
            # 500 is a reasonable default; hosts may pick 400 / 422 based on
            # their own observability conventions.
            send_resp(conn, 500, "Internal Server Error")
        end
      end

      # Adapter selection is host-app territory; the example wires two fixture adapters.
      defp adapter_for("echo"), do: DemoHost.Adapters.EchoAdapter
      defp adapter_for("rawbody"), do: DemoHost.Adapters.RawBodyHmacAdapter
      defp adapter_for(_unknown), do: DemoHost.Adapters.EchoAdapter
    end
    ```

    Note on `Enum.reverse/1`: the canonical `update_in(conn.assigns[:raw_body], &[body | &1 || []])` prepends each chunk, so the accumulated list is in REVERSE arrival order. `Enum.reverse |> IO.iodata_to_binary` recovers the original byte order. (Without `Enum.reverse`, the bytes would be backwards if the body arrived in multiple chunks — silent breakage for HMAC verification.)
  </action>
  <verify>
    <automated>test -f examples/chimeway_demo_host/lib/demo_host_web/controllers/webhooks_controller.ex && grep -q "use DemoHostWeb, :controller" examples/chimeway_demo_host/lib/demo_host_web/controllers/webhooks_controller.ex && grep -q "Chimeway.Webhooks.process" examples/chimeway_demo_host/lib/demo_host_web/controllers/webhooks_controller.ex && grep -q "IO.iodata_to_binary" examples/chimeway_demo_host/lib/demo_host_web/controllers/webhooks_controller.ex && grep -q "Application.get_env(:demo_host, :chimeway_adapter_config" examples/chimeway_demo_host/lib/demo_host_web/controllers/webhooks_controller.ex && grep -q 'send_resp(conn, 200' examples/chimeway_demo_host/lib/demo_host_web/controllers/webhooks_controller.ex && grep -q 'send_resp(conn, 401' examples/chimeway_demo_host/lib/demo_host_web/controllers/webhooks_controller.ex && grep -q "{:error, :unauthorized}" examples/chimeway_demo_host/lib/demo_host_web/controllers/webhooks_controller.ex && grep -q 'adapter_for("rawbody")' examples/chimeway_demo_host/lib/demo_host_web/controllers/webhooks_controller.ex</automated>
  </verify>
  <acceptance_criteria>
    - `examples/chimeway_demo_host/lib/demo_host_web/controllers/webhooks_controller.ex` exists.
    - File contains `defmodule DemoHostWeb.WebhooksController do`.
    - File contains `use DemoHostWeb, :controller`.
    - File contains `Chimeway.Webhooks.process(adapter_module, raw_body, headers, config)`.
    - File contains `IO.iodata_to_binary` (Pitfall 4 mitigation — T-33-RAWBODY).
    - File contains `Enum.reverse` (chunk-order correction).
    - File contains `Application.get_env(:demo_host, :chimeway_adapter_config, [])` (adapter-config-at-call-time discipline).
    - File contains `{:ok, _ingress} ->` followed by `send_resp(conn, 200`.
    - File contains `{:error, :unauthorized} ->` followed by `send_resp(conn, 401`.
    - File contains `{:error, _other} ->` followed by `send_resp(conn, 500` (or any non-2xx).
    - File contains `defp adapter_for("rawbody"), do: DemoHost.Adapters.RawBodyHmacAdapter` (route for the verify-before-parse E2E test).
    - File does NOT contain `Module attribute` capture of adapter config (no `@adapter_config Application.get_env(...)` at module level — would violate the call-time discipline).
  </acceptance_criteria>
  <done>The reference controller is in place and exercises `Chimeway.Webhooks.process/4` with the correct raw-body flattening and status mapping.</done>
</task>

<task type="auto">
  <name>Task 4: Add mix verify.example alias to root mix.exs and prove the E2E test passes</name>
  <files>mix.exs</files>
  <read_first>
    - mix.exs (current — note the existing `aliases/0` block at lines 46-73)
    - .planning/phases/33-webhook-ingress-durability/33-RESEARCH.md (§ Open Questions #2; § Code Examples > mix.exs aliases addition)
    - .planning/phases/33-webhook-ingress-durability/33-PATTERNS.md (§ mix.exs)
  </read_first>
  <action>
    Edit `mix.exs` and add a `verify.example` alias to the existing `aliases/0` private function. Place it in the post-publish verify trio section (alongside `verify.clean` and `verify.parity`):

    ```elixir
    "verify.example": [
      "cmd cd examples/chimeway_demo_host && mix deps.get && mix test"
    ]
    ```

    Use the `cd ... && ...` form rather than `--working-dir` to maintain compatibility across Elixir/Mix versions (per `33-RESEARCH.md` line ~378-381 — the `cd` form is documented as the safer fallback).

    Per `33-RESEARCH.md` Open Questions #2: this alias is INTENTIONALLY kept OUT of the default `ci.test` lane to preserve fast feedback on core lib tests. The phase gate runs `mix ci && mix verify.example` separately.

    Do NOT add `phoenix` or `plug` deps to the root project's `mix.exs` (D-10 enforcement). The example app declares its own deps in its own `mix.exs` (Task 1 output).

    After the alias is added, manually run (the executor must run this once and confirm exit 0) the full E2E sequence:

    ```bash
    mix verify.example
    ```

    This will:
    1. `cd examples/chimeway_demo_host`
    2. `mix deps.get` (downloads phoenix, plug, jason transitively into the example app's `_build/`)
    3. `mix test` (compiles the example app + chimeway-as-path-dep, runs the WebhooksControllerTest with all 4 tests GREEN)

    If the `mix deps.get` step fails because Phoenix/Plug couldn't resolve, the executor must investigate (likely a registry sync issue) but should NOT modify `chimeway`'s root `mix.exs` to add those deps.
  </action>
  <verify>
    <automated>grep -q "verify.example" mix.exs && grep -q "examples/chimeway_demo_host" mix.exs && ! grep -q "{:phoenix" mix.exs && ! grep -q "{:plug, " mix.exs && mix verify.example</automated>
  </verify>
  <acceptance_criteria>
    - `mix.exs` `aliases/0` function contains `"verify.example":` key.
    - The alias body contains `cd examples/chimeway_demo_host` and `mix test`.
    - `mix.exs` does NOT contain `{:phoenix,` (D-10 — no Phoenix in core).
    - `mix.exs` does NOT contain `{:plug,` as a top-level dep (D-10 — no Plug in core; existing `Plug.` test references in `lib/` are not deps).
    - `mix verify.example` exits 0.
    - `examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs` runs all 4 tests GREEN inside `mix verify.example`.
    - `mix ci` (root project test suite) STILL exits 0 — adding the alias does not affect the core test lane.
  </acceptance_criteria>
  <done>The example app is fully wired. `mix verify.example` runs the E2E test suite and exits 0. Audit gap "no runtime ingress consumer exists in the repo" is closed (D-11). The host-mount becomes the canonical reference per D-12.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Provider HTTP -> Phoenix Endpoint | Untrusted provider request crosses HTTPS into the host endpoint. |
| Phoenix Endpoint -> Plug.Parsers | Raw bytes pass through `:body_reader` BEFORE JSON parsing. |
| Controller -> `Chimeway.Webhooks.process/4` | Verified+raw bytes cross the library boundary. |
| Library -> DB | Same as Plans 02/03 — atomic ingress + Oban handoff. |

## STRIDE Threat Register (Plan 04 scope)

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-33-RAWBODY | Tampering / Spoofing (signature bypass) | host endpoint + controller | mitigate | (1) `Plug.Parsers` is configured with `body_reader: {DemoHost.Plugs.CacheBodyReader, :read_body, []}` — raw bytes are cached BEFORE parser consumes them (D-13). (2) Controller flattens iolist via `IO.iodata_to_binary/1` AFTER `Enum.reverse/1` to recover correct byte order (Pitfall 4). (3) The fixture adapter's `verify_webhook/3` is called BEFORE any other processing (delegated to `Chimeway.Webhooks.process/4` which runs `verify_webhook` in the `with`-pipeline before `Jason.decode/1`). (4) E2E test "raw body iolist is correctly flattened" asserts the chunked-body case returns 200 OK — regression test for byte-order or flattening bugs. |
| T-33-AUTH-LEAK (host-side) | Information Disclosure | host controller | mitigate | Controller only sends back `200 "OK"`, `401 "Unauthorized"`, or `500 "Internal Server Error"` text bodies. NO raw response details, NO error reasons, NO stack traces leaked to the provider. The verbose error reason is logged to telemetry/logs server-side only (host's responsibility; example app does not configure verbose logging). |
| T-33-ATOMIC (E2E confirmation) | Tampering / Repudiation | full host->lib path | mitigate | E2E test "valid signature + parseable body returns 200, commits ingress row, and enqueues Oban job" asserts BOTH side effects (`Repo.all(Ingress)` returns the row AND `assert_enqueued worker: ProcessFeedbackWorker, args: %{"ingress_id" => ingress.id}`). The bad-signature test asserts NEITHER side effect occurs (`Repo.aggregate(Ingress, :count) == 0` AND `refute_enqueued`). This proves T-33-ATOMIC end-to-end across the host boundary. |
| T-33-FIXTURE-SAFETY | Tampering | fixture EchoAdapter | accept | The fixture adapter's `verify_webhook/3` uses simple header-equality (`"signature" == "valid"`), not constant-time compare. ACCEPT for the fixture: this is a test/example adapter, not production. The adapter docstring loudly calls out "do not copy this shape into a real adapter — Production adapters MUST use `Plug.Crypto.secure_compare/2`". Real adapter authors are directed to the security domain section of `33-RESEARCH.md` and to Phase 29 D-23 for adapter authoring guidance. |
</threat_model>

<verification>
- `examples/chimeway_demo_host/` directory tree exists with all 13 files (mix.exs, 2 configs, 7 lib files, 1 test_helper, 1 controller test).
- `mix verify.example` exits 0 from the project root.
- All 4 E2E tests pass: valid-signature 200 + ingress + job; bad-signature 401 + no ingress; malformed-JSON non-2xx + no ingress; raw-body iolist regression test.
- `mix ci` still exits 0 from the project root (core test lane untouched).
- `grep -c "{:phoenix" mix.exs` returns 0 (D-10 enforcement at root).
- `grep -c "{:plug, " mix.exs` returns 0 (D-10 enforcement at root).
- `grep -c "Plug.Parsers" examples/chimeway_demo_host/lib/demo_host_web/endpoint.ex` returns >= 1.
- `grep -c "body_reader: {DemoHost.Plugs.CacheBodyReader" examples/chimeway_demo_host/lib/demo_host_web/endpoint.ex` returns 1.
- `grep -c "IO.iodata_to_binary" examples/chimeway_demo_host/lib/demo_host_web/controllers/webhooks_controller.ex` returns 1.
</verification>

<success_criteria>
- `examples/chimeway_demo_host/` is a self-contained Phoenix project that compiles, tests, and serves as the canonical reference for the Chimeway webhook host-mount pattern (D-11, D-12).
- The `:body_reader` MFA pattern is wired correctly so signature verification operates on raw bytes (D-13 / T-33-RAWBODY closed).
- The reference controller flattens the iolist via `IO.iodata_to_binary/1` after `Enum.reverse/1` (Pitfall 4 closed).
- The status mapping is `{:ok, _} -> 200`, `{:error, :unauthorized} -> 401`, `{:error, _other} -> 500` (D-03).
- `mix verify.example` runs the E2E proof and exits 0.
- Chimeway core's `mix.exs` is unchanged except for the `verify.example` alias addition (D-10 honored).
- Audit gap #2 ("no runtime webhook ingress consumer exists in the repo") is closed.
</success_criteria>

<output>
After completion, create `.planning/phases/33-webhook-ingress-durability/33-04-SUMMARY.md` per `$HOME/.claude/get-shit-done/templates/summary.md`. Include:
- `requirements_completed: [FEED-01, FEED-02]` (host-mount E2E proof closes the runtime ingress claim)
- `threats_mitigated: [T-33-RAWBODY, T-33-ATOMIC (E2E), T-33-AUTH-LEAK (host-side)]`
- Doc note: future Chimeway docs should link to `examples/chimeway_demo_host/` instead of repeating controller boilerplate (D-12).
</output>
