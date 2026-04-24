%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "test/"],
        excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/"]
      },
      strict: true,
      color: true,
      checks: [
        # Relax ModuleDoc for test support modules — internal helpers don't need public docs
        {Credo.Check.Readability.ModuleDoc, files: %{excluded: ["test/support/**"]}},

        # Suppress AliasUsage design suggestions in test files — inline module definitions
        # and full module references are idiomatic in ExUnit tests
        {Credo.Check.Design.AliasUsage, files: %{excluded: ["test/**"]}},

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
