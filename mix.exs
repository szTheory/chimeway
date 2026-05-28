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
    ]
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

      # Test lane
      "ci.test": ["cmd env MIX_ENV=test mix test"],

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
      # Post-publish verify: proves the canonical host-mount E2E path (D-11, D-12, D-13).
      # Run separately from ci.test to preserve fast feedback on core lib tests (Phase 33 D-10).
      "verify.example": [
        "cmd cd examples/chimeway_demo_host && mix deps.get && mix test"
      ],

      # Installer golden-diff + idempotency contract (path-gated in CI, not default ci)
      "ci.install_golden": [
        "cmd env MIX_ENV=test mix test test/chimeway/install/golden_diff_test.exs test/chimeway/install/idempotency_test.exs --warnings-as-errors"
      ]
    ]
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
        "guides/flows/trigger-to-delivery.md",
        "guides/flows/policy-and-preferences.md",
        "guides/flows/async-dispatch.md",
        "guides/flows/multi-step-journeys.md",
        "guides/recipes/oban-integration.md",
        "guides/recipes/custom-adapter.md",
        "guides/recipes/tracing-a-notification.md",
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
