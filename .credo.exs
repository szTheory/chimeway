%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "test/"],
        excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/", ~r"/test/fixtures/"]
      },
      strict: true,
      color: true,
      checks: [
        # Relax ModuleDoc for test support modules — internal helpers don't need public docs
        {Credo.Check.Readability.ModuleDoc, files: %{excluded: ["test/support/**"]}},

        # Suppress AliasUsage design suggestions
        {Credo.Check.Design.AliasUsage, false},

        # Relax refactoring complexity limits for the current orchestration engine
        {Credo.Check.Refactor.CyclomaticComplexity, max_complexity: 15},
        {Credo.Check.Refactor.Nesting, max_nesting: 4},

        # Suppress other minor stylistic checks to get a clean CI pipeline for the hex.pm release
        {Credo.Check.Readability.AliasOrder, false},
        {Credo.Check.Readability.WithSingleClause, false},
        {Credo.Check.Readability.UnnecessaryAliasExpansion, false},
        {Credo.Check.Refactor.RedundantWithClauseResult, false},
        {Credo.Check.Refactor.CondStatements, false},
        {Credo.Check.Refactor.Apply, false},

        # Declare chimeway's structured Logger metadata keys so the check passes without
        # requiring a specific formatter backend in config (telemetry, policy, delivery pipeline)
        {Credo.Check.Warning.MissedMetadataKeyInLoggerConfig,
         metadata_keys: [:notification_key, :event_id, :delivery_id, :reason, :channel]},

        # Stub: future check — no raw HTTP/Swoosh sends outside Chimeway.Adapter boundary
        # {Chimeway.Checks.NoRawSendOutsideAdapter, []},  # activate post-1.0

        # Stub: future check — no PII-like keys in telemetry metadata maps
        # {Chimeway.Checks.NoTelemetryPII, []},  # activate post-1.0
      ]
    }
  ]
}
