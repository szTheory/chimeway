---
plan: 05-02
phase: 5
title: Finalize Release/Checklist Docs, Doc-Contract Tests, and Maintenance Runbook
status: not_started
requirements: [OPS-03]
depends_on: [05-01]
---

# Plan 05-02: Finalize Release/Checklist Docs, Doc-Contract Tests, and Maintenance Runbook

## Goal
Deliver the doc-contract test, the full guides folder structure (stub content), the `guides/cheatsheet.cheatmd`, and all root hygiene documents. After this plan, `mix ci.docs` passes, `mix test` includes the doc-contract assertions, and the repository ships with complete contributor/release documentation.

## Context
Plan 05-01 wired the `docs/0` ExDoc config and all CI aliases. This plan populates the content those aliases operate on. The `extras:` list in `docs/0` already references specific guide file paths — this plan creates each of those files. The doc-contract test guards against regressions where a public module loses its `@moduledoc` accidentally. Root hygiene docs (README, CHANGELOG, LICENSE, CONTRIBUTING, MAINTAINING, SECURITY, CODE_OF_CONDUCT) make the repository shippable as an OSS Hex package.

No runtime code changes. No schema migrations.

## Tasks

### Task 1: Add Doc-Contract Test
**What**: Create `test/chimeway/doc_contract_test.exs` that asserts every public-facing Chimeway module has a non-absent, non-hidden `@moduledoc`. Per CONTEXT.md D-13 and RESEARCH.md §6.

The test iterates a fixed list of public modules at compile time using a `for` comprehension, calls `Code.fetch_docs/1`, and asserts the module_doc is neither `:none` nor `:hidden`:

```elixir
defmodule Chimeway.DocContractTest do
  use ExUnit.Case, async: true

  @public_modules [
    Chimeway,
    Chimeway.Notifier,
    Chimeway.Traces,
    Chimeway.Telemetry
  ]

  for mod <- @public_modules do
    test "#{inspect(mod)} has a moduledoc" do
      case Code.fetch_docs(unquote(mod)) do
        {:docs_v1, _, _, _, module_doc, _, _} ->
          refute module_doc == :none,
            "#{inspect(unquote(mod))} is missing @moduledoc"
          refute module_doc == :hidden,
            "#{inspect(unquote(mod))} has @moduledoc false — public modules must be documented"

        {:error, reason} ->
          flunk("Could not fetch docs for #{inspect(unquote(mod))}: #{inspect(reason)}")
      end
    end
  end
end
```

No `:integration` tag — this is a fast compile-time reflection check.

**Where**:
- `test/chimeway/doc_contract_test.exs` — new file

**Acceptance criteria**:
- [ ] `mix test test/chimeway/doc_contract_test.exs` passes with all four public modules present and documented
- [ ] If any module in `@public_modules` has `@moduledoc false`, the corresponding test fails with a clear message
- [ ] If any module in `@public_modules` does not exist or fails to load, the test fails with `flunk/1` — not a cryptic pattern match error
- [ ] Test is `async: true` and does not require database access

**Done when**: The doc-contract test runs in `mix test` and all four public module assertions pass.

---

### Task 2: Create Guides Folder Structure and Cheatsheet
**What**: Create all guide stub files referenced in the `extras:` list from Plan 05-01's `docs/0`. Each stub must have a correct H1 title and a one-paragraph placeholder body — enough for ExDoc to render without errors but explicitly marked as "work in progress."

**Files to create**:
- `guides/introduction/getting-started.md` — "Getting Started" — covers: what Chimeway is, prerequisites, two-step install (add dep, add Ecto schema)
- `guides/introduction/installation.md` — "Installation" — covers: `mix.exs` dep addition, `mix deps.get`, config setup
- `guides/flows/trigger-to-delivery.md` — "Trigger to Delivery" — covers: the full lifecycle from `Chimeway.trigger/3` call to delivery row
- `guides/flows/policy-and-preferences.md` — "Policy and Preferences" — covers: preference model, dual evaluation checkpoints
- `guides/flows/async-dispatch.md` — "Async Dispatch" — covers: sync vs Oban path, documented seam
- `guides/recipes/oban-integration.md` — "Oban Integration Recipe" — covers: transactional enqueue, worker setup
- `guides/recipes/custom-adapter.md` — "Custom Adapter Recipe" — covers: adapter behaviour callbacks, implementing a channel
- `guides/recipes/tracing-a-notification.md` — "Tracing a Notification" — covers: `Chimeway.Traces.explain_delivery/1`, `get_trace/1` IEx walkthrough

Each stub follows this pattern:
```markdown
# <Title>

> **Note:** This guide is a stub. Full content coming in v1.0 docs.

<One paragraph explaining what this guide will cover and why it matters.>

## Overview

<!-- TODO: expand with full content -->
```

**`guides/cheatsheet.cheatmd`** — per CONTEXT.md D-16 and RESEARCH.md §5, ExDoc renders `.cheatmd` as a two-column cheat sheet. Create with these sections:
- `## Trigger a Notification` — `Chimeway.trigger/3` example with idempotency key
- `## Query Recipient Inbox` — `Chimeway.inbox_for/2` with `unread_only: true`
- `## Explain a Delivery` — `Chimeway.Traces.explain_delivery/1` IEx example
- `## Delivery States` — table of `:succeeded`, `:failed`, `:suppressed`, `:pending` with one-line descriptions
- `## Policy Evaluation` — inline code showing how to pass preferences

**Where**:
- `guides/introduction/getting-started.md` — new
- `guides/introduction/installation.md` — new
- `guides/flows/trigger-to-delivery.md` — new
- `guides/flows/policy-and-preferences.md` — new
- `guides/flows/async-dispatch.md` — new
- `guides/recipes/oban-integration.md` — new
- `guides/recipes/custom-adapter.md` — new
- `guides/recipes/tracing-a-notification.md` — new
- `guides/cheatsheet.cheatmd` — new

**Acceptance criteria**:
- [ ] All 9 files exist at the correct paths (matching `extras:` list in `docs/0`)
- [ ] `mix docs` runs without fatal path errors (warnings about stub content are acceptable)
- [ ] `mix ci.docs` (`mix docs --warnings-as-errors`) passes — stub content must not introduce ExDoc warnings for missing or malformed references
- [ ] `guides/cheatsheet.cheatmd` has at least 4 section headers with runnable code examples
- [ ] All stub files have H1 titles matching the guide name

**Done when**: `mix ci.docs` exits 0 and all 9 guide files are present.

---

### Task 3: Create Root Hygiene Documents
**What**: Create all root-level OSS hygiene files per CONTEXT.md D-18/D-19 and RESEARCH.md §7.

**Files to create or update**:

1. **`README.md`** — Polish the existing stub (or create if absent). Must include:
   - One-line description: "Chimeway is an explainable, durable notification library for Elixir."
   - Install snippet (`mix.exs` dep + `mix deps.get`)
   - Minimal quick-start: `Chimeway.trigger/3` call with output comment
   - Link to hex docs and guides
   - Badges: hex.pm version, CI status

2. **`CHANGELOG.md`** — Create with `## [Unreleased]` header and conventional commit format note:
   ```markdown
   # Changelog

   All notable changes to this project will be documented in this file.
   Format: [Conventional Commits](https://www.conventionalcommits.org/).

   ## [Unreleased]

   *(no entries yet)*
   ```

3. **`LICENSE.md`** — Full MIT license text with year `2026` and author `Jon Lunsford`.

4. **`CONTRIBUTING.md`** — Covers:
   - Development setup (`mix deps.get`, `mix ecto.setup`, `mix ci`)
   - PR title requirement: semantic commit prefix (`feat:`, `fix:`, `docs:`, `chore:`, etc.)
   - Running tests: `mix ci.test`
   - Running the full gate: `mix ci`
   - Link to guides for architecture context

5. **`MAINTAINING.md`** — Concrete release runbook (per RESEARCH.md §7 outline):
   1. Bump `@version` in `mix.exs`
   2. Update `CHANGELOG.md` (move Unreleased → `## [X.Y.Z] - YYYY-MM-DD`)
   3. Run `mix ci` locally
   4. Run `mix ci.docs` locally
   5. Commit: `git commit -am "chore: release vX.Y.Z"`
   6. Tag: `git tag vX.Y.Z && git push --tags`
   7. Publish: `mix hex.publish`
   8. Verify: `mix verify.clean && mix verify.parity && mix verify.published X.Y.Z`
   9. Create GitHub Release from tag with CHANGELOG excerpt
   - Section on refreshing GitHub Actions SHAs during dep updates

6. **`SECURITY.md`** — One paragraph:
   - Where to report: email `security@<maintainer-contact>` or use GitHub private vulnerability reporting
   - No public CVE disclosure until coordinated fix is ready
   - Response time target: acknowledgement within 72 hours

7. **`CODE_OF_CONDUCT.md`** — Contributor Covenant v2.1 boilerplate verbatim. No customization.

**Where**: All files at project root.

**Acceptance criteria**:
- [ ] `README.md` includes install snippet, `trigger/3` quick-start, and links to docs
- [ ] `CHANGELOG.md` has `## [Unreleased]` header
- [ ] `LICENSE.md` is valid MIT text with correct year
- [ ] `CONTRIBUTING.md` explains `mix ci` and PR title convention
- [ ] `MAINTAINING.md` runbook has all 9 steps listed and is concrete enough for a second maintainer to follow without asking questions
- [ ] `SECURITY.md` exists with contact and disclosure policy
- [ ] `CODE_OF_CONDUCT.md` is Contributor Covenant v2.1 boilerplate
- [ ] `mix hex.build` lists `CHANGELOG.md`, `LICENSE.md`, `README.md` in its output (confirms `files:` whitelist from 05-01 is correct)

**Done when**: All 7 files exist at project root with correct content, and `mix hex.build` output confirms they are included in the package file list.

## Verification
**This plan is complete when**:
- [ ] `mix test test/chimeway/doc_contract_test.exs` passes — all four public modules have non-absent, non-hidden moduledocs
- [ ] `mix docs` renders without fatal errors
- [ ] `mix ci.docs` (`mix docs --warnings-as-errors`) exits 0
- [ ] All 9 guide stub files exist at the exact paths listed in `docs/0` `extras:`
- [ ] `guides/cheatsheet.cheatmd` renders in ExDoc with at least 4 sections
- [ ] `README.md` has install and quick-start content
- [ ] `CHANGELOG.md`, `LICENSE.md`, `CONTRIBUTING.md`, `MAINTAINING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md` all exist at project root
- [ ] `MAINTAINING.md` release runbook covers all steps including `mix verify.*` trio
- [ ] `mix hex.build` output confirms package includes `guides/`, `CHANGELOG.md`, `LICENSE.md`, `README.md`
- [ ] `mix test` passes for this plan's scope
- [ ] All tasks done conditions are met
