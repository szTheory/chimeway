# Phase 73 Deferred Items

## Out-of-Scope Formatting Drift

- **Found during:** Plan 73-01 plan-level `mix format --check-formatted`
- **Issue:** Full-repo format check reports pre-existing formatting drift in files outside the 73-01 plan file list, including doc contract, adapter, inbox, Sigra, Threadline, and Mailglass test/support files.
- **Disposition:** Out of scope for 73-01. Plan-owned files pass targeted format check: `mix format --check-formatted lib/chimeway/config_error.ex lib/chimeway/storage.ex test/chimeway/storage_test.exs`.
