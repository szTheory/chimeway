# Phase 72: Admin Docs and Verification Gate - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md - this log preserves the analysis.

**Date:** 2026-06-04T20:43:19Z
**Phase:** 72-admin-docs-and-verification-gate
**Mode:** assumptions
**Areas analyzed:** Admin Integration Guide, Doc Contracts, Verify Gate And CI Parity, Browser Smoke

## Assumptions Presented

### Admin Integration Guide

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Phase 72 should add a dedicated admin integration guide, likely under `guides/introduction/`, and include it in HexDocs extras rather than relying on the demo-host README. | Likely | `mix.exs`; `examples/chimeway_demo_host/README.md`; `chimeway_admin/lib/chimeway_admin.ex`; `chimeway_admin/lib/chimeway_admin/router.ex` |

### Doc Contracts

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Admin doc-contract coverage should extend `test/chimeway/doc_contract_test.exs`, not live only inside `chimeway_admin` tests. | Confident | `test/chimeway/doc_contract_test.exs`; `test/chimeway/release_gate_contract_test.exs`; `mix.exs` |

### Verify Gate And CI Parity

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| `mix verify.admin` should be a root `mix.exs` alias that composes targeted root admin tests, the full `chimeway_admin` package test suite, and demo-host mounted admin coverage, then CI should invoke that same alias. | Confident | `mix.exs`; `.github/workflows/ci.yml`; `test/chimeway/admin_test.exs`; `chimeway_admin/test/chimeway_admin/*`; `examples/chimeway_demo_host/test/demo_host_web/admin_trace_live_test.exs` |

### Browser Smoke

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Browser smoke should exercise the demo-host mounted console at `/admin/chimeway` with an actual browser/headless browser path, not only `Phoenix.LiveViewTest`. | Likely | `examples/chimeway_demo_host/lib/demo_host_web/endpoint.ex`; `examples/chimeway_demo_host/lib/demo_host_web/layouts/root.html.heex`; existing LiveView/Floki tests; absence of project-owned Playwright/Wallaby/Hound smoke harness |

## Corrections Made

No corrections - all assumptions confirmed by the user.

## External Research

- Browser smoke tooling choice: Playwright is the recommended smallest fit because official docs show CLI-managed browser binary and CI dependency installation, including Chromium-only installation.
  Source: `https://playwright.dev/docs/next/browsers`
- PhoenixTest is useful for feature-style Phoenix/LiveView tests but does not handle JavaScript; its docs point to Wallaby or a Playwright driver for JavaScript/browser support.
  Source: `https://phoenix-test.hexdocs.pm/PhoenixTest.html`
- Wallaby is browser-capable, but its LiveView guidance requires sandbox wiring through `mount/3` or `on_mount`, making it a heavier fit for this phase's narrow smoke requirement.
  Source: `https://github.com/elixir-wallaby/wallaby`
