---
phase: 16-integration-hardening
nyquist_compliant: true
---

# Phase 16 Validation Strategy

## Goal Coverage

1. **INT-01: Host apps can install and configure Chimeway through a documented integration path.**
   - Verified by ensuring all introductory guides and recipes (Installation, Getting Started, Oban Integration, Tracing) provide functional, step-by-step setup and configurations, completely replacing placeholder stubs.
2. **INT-02: Adapter and job-dispatch seams remain contract-tested and safe for runtime configuration.**
   - Verified by explicitly documenting the `Chimeway.Adapter.ContractTest` macro usage to guarantee sensitive credential redaction, and documenting mandatory `Application.get_env/3` loading for runtime configuration safety in custom adapters.

## Assumptions Verified

- **Host-App Integration Path:** The assumption that core integration guides were stubbed out and would block host-app adoption is mitigated by fully expanding `installation.md` and `getting-started.md` to ensure a quick "Time to First Run".
- **Adapter Runtime Configuration Safety:** The assumption that adapters must dynamically resolve config is addressed by explicit warnings against compile-time `@config` module attributes in the custom adapter recipe, directing users to `Application.get_env/3`.
- **Adapter Contract Safety:** The assumption that outbound adapters are strictly protected by a shared ExUnit macro is enforced by clearly documenting the `Chimeway.Adapter.ContractTest` macro in the custom adapter recipe.

## Per-Task Verification Map

| Plan | Task | Action | Verification Step |
|------|------|--------|-------------------|
| 16-01 | 1. Expand Installation Guide | Replace stub content in `installation.md` with dependencies, config, and migration steps for durable notification schema. | `grep -q "def deps do" guides/introduction/installation.md` |
| 16-01 | 2. Expand Getting Started Guide | Walk the user through defining a notifier with `use Chimeway.Notifier`, triggering notifications, and checking inbox/deliveries. | `grep -q "use Chimeway.Notifier" guides/introduction/getting-started.md` |
| 16-02 | 1. Expand Oban Integration Recipe | Detail `Chimeway.Dispatch.Oban` configuration, Oban queues, and Ecto.Multi transactional dispatch guarantees. | `grep -q "Chimeway.Dispatch.Oban" guides/recipes/oban-integration.md` |
| 16-02 | 2. Expand Tracing Recipe | Document attaching to telemetry events and using safe correlation IDs instead of leaking sensitive payload data into metadata. | `grep -q "telemetry" guides/recipes/tracing-a-notification.md` |
| 16-03 | 1. Expand Custom Adapter Recipe | Document `Chimeway.Adapter` behaviour implementation, mandate runtime configuration, and enforce the `Chimeway.Adapter.ContractTest` macro. | `grep -q "Chimeway.Adapter.ContractTest" guides/recipes/custom-adapter.md` |
