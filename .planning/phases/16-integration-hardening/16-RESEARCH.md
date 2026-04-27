# Phase 16: Assumptions Analysis

## Host-App Integration Path
- **Assumption:** The core integration guides are currently stubbed out pending full expansion.
  - **Why this way:** `guides/introduction/installation.md` and `guides/introduction/getting-started.md` both contain `> **Note:** This guide is a stub. Full content coming in v1.0 docs.` along with `<!-- TODO: expand with full content -->` comments. The `README.md` only provides a brief summary.
  - **If wrong:** We might mark Phase 16 as complete based only on the `README.md` instructions, leaving out crucial end-to-end setup and debugging guidance required for successful host-app adoption.

## Adapter Runtime Configuration Safety
- **Assumption:** Adapter configuration for custom channels and legacy fallbacks must be dynamically resolved by the dispatcher at execution time to ensure safe multi-environment usage.
  - **Why this way:** `lib/chimeway/adapter.ex` mandates that config is read at call time via `Application.get_env/3`. Both `test/chimeway/dispatch/sync_test.exs` and `test/chimeway/dispatch/oban_test.exs` actively test dynamic resolution of `Application.get_env(:chimeway, :channel_adapter_configs)`, falling back to the legacy `adapter_<channel>` setup at dispatch/perform time.
  - **If wrong:** Adapters might read configuration via module attributes (`@config`), locking credentials in at compile time. This would break Elixir releases that require runtime environment switching without a rebuild.

## Adapter Contract Safety
- **Assumption:** All outbound adapters (including custom host-app adapters) are strictly protected by a shared ExUnit macro that asserts standardized behavior and explicitly redacts sensitive credentials.
  - **Why this way:** `test/support/chimeway/adapter/contract_test.ex` provides a `use Chimeway.Adapter.ContractTest` macro enforcing a `__contract_check_no_sensitive_keys!` redaction gate. This explicitly raises an error if an adapter attempts to return keys like `:token`, `:password`, `:auth`, or `:api_key`.
  - **If wrong:** An adapter could silently leak provider auth credentials in its return metadata, which would then be written unencrypted to the `chimeway_delivery_attempts` table, leading to severe host-app security incidents.

## Dispatch Seam Testing Strategy
- **Assumption:** The synchronous and Oban dispatcher implementations maintain core lifecycle parity (policy suppression, delay-fallback logic, config resolution) through duplicated tests rather than a shared ExUnit contract macro.
  - **Why this way:** While adapter seams share `Chimeway.Adapter.ContractTest`, the dispatcher files (`test/chimeway/dispatch/sync_test.exs` and `oban_test.exs`) independently declare identical test scenarios for `planning-time policy suppression parity` and `custom channel adapter config resolution`.
  - **Alternatives:**
    1. Extract a unified `Chimeway.Dispatch.ContractTest` ExUnit macro to enforce strict parity across any current or future dispatcher implementations.
    2. Retain the current duplicated tests to accommodate areas where background queuing requires structurally different assertions than synchronous evaluation.
  - **If wrong:** As the dispatcher boundary grows more complex, maintaining separate mirrored test files will inevitably lead to logic drift, causing unexpected bugs when users switch from `Sync` to `ObanWorker` in production.
