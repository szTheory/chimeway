defmodule Chimeway.MixProject do
  use Mix.Project

  @version "1.0.0"

  def project do
    [
      app: :chimeway,
      version: @version,
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      description: "Explainable, durable notification library for Elixir.",
      package: package(),
      docs: docs()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Chimeway.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto_sql, "~> 3.11"},
      {:postgrex, ">= 0.0.0"},
      {:nimble_options, "~> 1.1"},
      {:jason, "~> 1.4"},
      {:tzdata, "~> 1.1"},
      {:oban, "~> 2.17", optional: true},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ] ++ mailglass_deps() ++ accrue_deps() ++ threadline_deps() ++ sigra_deps()
  end

  defp mailglass_deps do
    if System.get_env("CHIMEWAY_SKIP_MAILGLASS_DEP") in ["1", "true"] do
      []
    else
      [{:mailglass, "~> 1.3", optional: true}]
    end
  end

  defp accrue_deps do
    if System.get_env("CHIMEWAY_SKIP_ACCRUE_DEP") in ["1", "true"] do
      []
    else
      [accrue_dep()]
    end
  end

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

      # Dependency audit
      "ci.audit": ["hex.audit"],

      # Post-publish verify trio (run locally by maintainer, not in pre-merge CI)
      "verify.clean": ["cmd git diff --exit-code"],
      # D-08: local artifact proof — build + unpack the default root package under
      # MIX_ENV=prod (so the override is absent and Hex accepts the build), with no
      # Sigra skip envs, and fail unless the unpacked root carries every package
      # whitelist entry. No live Hex API calls (release-time/manual evidence only).
      "verify.parity": [
        "cmd --shell rm -rf /tmp/chimeway_verify && env MIX_ENV=prod mix hex.build --unpack --output /tmp/chimeway_verify && root=/tmp/chimeway_verify && if [ ! -f \"$root/mix.exs\" ]; then root=$(dirname \"$(find /tmp/chimeway_verify -maxdepth 2 -name mix.exs | head -1)\"); fi && for f in mix.exs lib priv guides README.md CHANGELOG.md LICENSE.md .formatter.exs; do test -e \"$root/$f\" || { echo \"verify.parity: missing package whitelist entry $f under $root\" >&2; exit 1; }; done && echo \"verify.parity OK: unpacked package root $root contains all whitelist entries\""
      ],
      # verify.published: invoked as `mix verify.published <version>` (Mix task)
      # Pre-ship GATE-01: canonical host-mount E2E + operator admin smoke (D-10, D-11).
      # Run separately from ci.test to preserve fast feedback on core lib tests (Phase 33 D-10).
      "verify.example": [
        "cmd --shell cd examples/chimeway_demo_host && mix deps.get && mix test",
        "cmd --shell cd chimeway_admin && mix deps.get && mix test",
        "cmd --shell cd chimeway_inbox && mix deps.get && mix test --warnings-as-errors"
      ],

      # Installer golden-diff, idempotency, prefix, and DB migration contract (path-gated in CI, not default ci)
      "verify.install_golden": [
        "cmd env CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/install/golden_diff_test.exs test/chimeway/install/idempotency_test.exs test/chimeway/install/prefix_contract_test.exs test/chimeway/migration_contract_test.exs --warnings-as-errors"
      ],
      "verify.runtime_prefix": [
        "cmd env MIX_ENV=test mix test test/chimeway/repo_prefix_test.exs test/chimeway/runtime_prefix_integration_test.exs test/chimeway/generated_prefixed_runtime_proof_test.exs --warnings-as-errors"
      ],
      "ci.install_golden": ["verify.install_golden"],

      # GATE-01 doc-contract + version alignment gates (pre-ship; no Postgres required)
      "ci.verify_gates": [
        "cmd env MIX_ENV=test mix test test/chimeway/doc_contract_test.exs test/chimeway/release_gate_contract_test.exs --warnings-as-errors"
      ],

      # v1.7 GATE-03: TeamPulse consumer journey proof JOUR-01..08 (10 tests)
      "verify.journeys": [
        "cmd --shell cd examples/chimeway_demo_host && mix deps.get && mix test --only journey"
      ],

      # v1.8 GATE-04: Mailglass adapter + webhook pipeline + demo host DEMO-06 proof
      "verify.mailglass": [
        "cmd env MIX_ENV=test mix test --only mailglass --warnings-as-errors",
        "cmd --shell cd examples/chimeway_demo_host && mix deps.get && mix test --only mailglass --warnings-as-errors"
      ],

      # v1.9 GATE-05 prep: Accrue dunning integration harness (root + demo host :accrue lane)
      "verify.accrue": [
        "deps.compile accrue --force",
        "cmd env MIX_ENV=test mix test --only accrue --warnings-as-errors",
        "cmd --shell cd examples/chimeway_demo_host && env CHIMEWAY_SKIP_ACCRUE_DEP=1 ACCRUE_PATH=../../../accrue/accrue CHIMEWAY_PATH=../.. mix deps.get && env CHIMEWAY_SKIP_ACCRUE_DEP=1 ACCRUE_PATH=../../../accrue/accrue CHIMEWAY_PATH=../.. mix deps.compile accrue --force && env CHIMEWAY_SKIP_ACCRUE_DEP=1 ACCRUE_PATH=../../../accrue/accrue CHIMEWAY_PATH=../.. mix test --only accrue --warnings-as-errors"
      ],

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

      # v1.10 GATE-07 Sigra: auth notification proof (root + demo host :sigra lane)
      "verify.sigra": [
        "cmd env MIX_ENV=test mix test --only sigra --warnings-as-errors",
        "cmd --shell sigra_path=${SIGRA_PATH:-../sigra/sigra}; sigra_path=$(cd \"$sigra_path\" && pwd); cd examples/chimeway_demo_host && env CHIMEWAY_SKIP_THREADLINE_DEP=1 CHIMEWAY_SKIP_MAILGLASS_DEP=1 CHIMEWAY_SKIP_SIGRA_TRANSITIVE_DEP=1 SIGRA_PATH=\"$sigra_path\" CHIMEWAY_PATH=../.. mix deps.get && env CHIMEWAY_SKIP_THREADLINE_DEP=1 CHIMEWAY_SKIP_MAILGLASS_DEP=1 CHIMEWAY_SKIP_SIGRA_TRANSITIVE_DEP=1 SIGRA_PATH=\"$sigra_path\" CHIMEWAY_PATH=../.. mix deps.compile && env CHIMEWAY_SKIP_THREADLINE_DEP=1 CHIMEWAY_SKIP_MAILGLASS_DEP=1 CHIMEWAY_SKIP_SIGRA_TRANSITIVE_DEP=1 SIGRA_PATH=\"$sigra_path\" CHIMEWAY_PATH=../.. mix compile && env CHIMEWAY_SKIP_THREADLINE_DEP=1 CHIMEWAY_SKIP_MAILGLASS_DEP=1 CHIMEWAY_SKIP_SIGRA_TRANSITIVE_DEP=1 SIGRA_PATH=\"$sigra_path\" CHIMEWAY_PATH=../.. mix test --only sigra --warnings-as-errors"
      ],

      # Phase 72 GATE-08: mounted admin package, demo-host, and browser smoke gate.
      "verify.admin": [
        "cmd env MIX_ENV=test mix test test/chimeway/admin_test.exs --warnings-as-errors",
        "cmd --shell cd chimeway_admin && mix deps.get && mix test --warnings-as-errors",
        "cmd --shell cd examples/chimeway_demo_host && env CHIMEWAY_SKIP_THREADLINE_DEP=1 CHIMEWAY_SKIP_SIGRA_DEP=1 MIX_ENV=test mix deps.get && env CHIMEWAY_SKIP_THREADLINE_DEP=1 CHIMEWAY_SKIP_SIGRA_DEP=1 MIX_ENV=test mix test test/demo_host_web/admin_trace_live_test.exs --warnings-as-errors",
        "cmd npm ci",
        "cmd npx playwright install --with-deps chromium",
        "cmd npx playwright test test/browser/admin_smoke.spec.ts"
      ]
    ]
  end

  defp accrue_dep do
    # Local dev: ACCRUE_PATH=../accrue/accrue mix deps.get
    case System.get_env("ACCRUE_PATH") do
      nil -> {:accrue, "~> 1.3", optional: true, runtime: false}
      path -> {:accrue, path: path, optional: true, runtime: false}
    end
  end

  defp threadline_deps do
    if System.get_env("CHIMEWAY_SKIP_THREADLINE_DEP") in ["1", "true"] do
      []
    else
      [threadline_dep()]
    end
  end

  defp threadline_dep do
    # Local dev: THREADLINE_PATH=../threadline mix deps.get
    case System.get_env("THREADLINE_PATH") do
      nil -> {:threadline, "~> 0.7", optional: true, runtime: false}
      path -> {:threadline, path: path, optional: true, runtime: false}
    end
  end

  defp sigra_deps do
    if System.get_env("CHIMEWAY_SKIP_SIGRA_DEP") in ["1", "true"] or
         System.get_env("CHIMEWAY_SKIP_SIGRA_TRANSITIVE_DEP") in ["1", "true"] do
      []
    else
      [sigra_dep()]
    end
  end

  defp sigra_dep do
    # Local dev: SIGRA_PATH=../sigra mix deps.get
    #
    # Hex package builds (run under MIX_ENV=prod) reject overridden dependencies
    # ("Can't build package with overridden dependency sigra"), so `override: true`
    # is scoped to non-prod resolution only. In dev/test, chimeway fetches its own
    # optional deps, where root's `sigra ~> 0.3` must coexist with mailglass's
    # `sigra ~> 1.0` (non-overlapping ranges); the override picks root's requirement.
    # Adopters never pull these optional transitives, and the prod package carries
    # no override. Optional Sigra integration stays covered by `mix verify.sigra`.
    base = [optional: true, runtime: false]
    opts = if Mix.env() == :prod, do: base, else: [override: true] ++ base

    case System.get_env("SIGRA_PATH") do
      nil -> {:sigra, "~> 0.3", opts}
      path -> {:sigra, [{:path, path} | opts]}
    end
  end

  defp package do
    [
      files: ~w(lib priv guides CHANGELOG.md LICENSE.md README.md mix.exs .formatter.exs),
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/szTheory/chimeway"}
    ]
  end

  defp docs do
    [
      main: "Chimeway",
      source_ref: "v#{@version}",
      source_url: "https://github.com/szTheory/chimeway",
      extras: [
        "guides/introduction/getting-started.md",
        "guides/introduction/installation.md",
        "guides/introduction/golden-path.md",
        "guides/introduction/storage-prefix-upgrade.md",
        "guides/introduction/mailglass-integration.md",
        "guides/introduction/accrue-dunning-integration.md",
        "guides/introduction/admin-console-integration.md",
        "guides/introduction/inbox-integration.md",
        "guides/introduction/threadline-integration.md",
        "guides/introduction/sigra-auth-integration.md",
        "guides/flows/trigger-to-delivery.md",
        "guides/flows/policy-and-preferences.md",
        "guides/flows/async-dispatch.md",
        "guides/flows/multi-step-journeys.md",
        "guides/recipes/oban-integration.md",
        "guides/recipes/custom-adapter.md",
        "guides/recipes/accrue-dunning-blueprint.md",
        "guides/recipes/mailglass-integration-blueprint.md",
        "guides/recipes/sigra-auth-blueprint.md",
        "guides/recipes/tracing-a-notification.md",
        "guides/recipes/password-reset-support-trace.md",
        "guides/recipes/feedback-escalation-workflow.md",
        "guides/recipes/mention-escalation.md",
        "guides/cheatsheet.cheatmd"
      ],
      groups_extras: [
        Introduction: ~r/guides\/introduction\//,
        Flows: ~r/guides\/flows\//,
        Recipes: ~r/guides\/recipes\//
      ]
    ]
  end
end
