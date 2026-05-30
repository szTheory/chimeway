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
      {:mailglass, "~> 1.3", optional: true},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ] ++ accrue_deps() ++ threadline_deps()
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

      # Test lane (mailglass/accrue excluded — run mix verify.* separately, GATE-04/05)
      "ci.test": [
        "cmd env MIX_ENV=test mix test --exclude mailglass --exclude accrue --exclude threadline"
      ],

      # Docs gate: fails on undocumented public functions
      "ci.docs": ["docs --warnings-as-errors"],

      # Dependency audit
      "ci.audit": ["hex.audit"],

      # Post-publish verify trio (run locally by maintainer, not in pre-merge CI)
      "verify.clean": ["cmd git diff --exit-code"],
      "verify.parity": [
        "cmd mix hex.build --unpack --output /tmp/chimeway_verify && ls /tmp/chimeway_verify"
      ],
      # verify.published: invoked as `mix verify.published <version>` (Mix task)
      # Pre-ship GATE-01: canonical host-mount E2E + operator admin smoke (D-10, D-11).
      # Run separately from ci.test to preserve fast feedback on core lib tests (Phase 33 D-10).
      "verify.example": [
        "cmd --shell cd examples/chimeway_demo_host && mix deps.get && mix test",
        "cmd --shell cd chimeway_admin && mix deps.get && mix test",
        "cmd --shell cd chimeway_inbox && mix deps.get && mix test --warnings-as-errors"
      ],

      # Installer golden-diff + idempotency contract (path-gated in CI, not default ci)
      "ci.install_golden": [
        "cmd env MIX_ENV=test mix test test/chimeway/install/golden_diff_test.exs test/chimeway/install/idempotency_test.exs --warnings-as-errors"
      ],

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

  defp package do
    [
      files: ~w(lib priv guides CHANGELOG.md LICENSE.md README.md mix.exs .formatter.exs),
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/jonlunsford/chimeway"}
    ]
  end

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
        "guides/flows/trigger-to-delivery.md",
        "guides/flows/policy-and-preferences.md",
        "guides/flows/async-dispatch.md",
        "guides/flows/multi-step-journeys.md",
        "guides/recipes/oban-integration.md",
        "guides/recipes/custom-adapter.md",
        "guides/recipes/accrue-dunning-blueprint.md",
        "guides/recipes/mailglass-integration-blueprint.md",
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
