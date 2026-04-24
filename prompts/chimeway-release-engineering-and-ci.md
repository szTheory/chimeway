# Chimeway — release engineering and CI (thin pointer doc)

> **Purpose:** One-page **lane map** and pointers. **Do not** maintain a second full copy of YAML recipes here — copy from sibling repos when implementing the first workflows.

## Lane map (merge-blocking unless noted)

| Lane | Typical contents | Blocks merge? |
|------|------------------|---------------|
| Lint | `mix format --check-formatted`, `mix compile --warnings-as-errors`, `mix credo --strict`, `mix docs --warnings-as-errors`, `mix hex.audit`, optional `mix compile --no-optional-deps --warnings-as-errors` | yes |
| Test | `mix test --warnings-as-errors` across Elixir/OTP matrix; Postgres service | yes |
| Integration / golden | Installer golden diff, nested host smoke, adapter integration — when those exist | yes for touched paths |
| Release Please | Opens version PR on `main` | no |
| Publish Hex | Tag-driven publish with secrets from GitHub | release only |
| Post-publish verify | `mix verify.workspace_clean`, `mix verify.release_publish`, `mix verify.release_parity` + optional daily cron | post-merge / scheduled |

## Canonical prose and examples

Read and copy patterns from:

- **`/Users/jon/projects/rulestead/prompts/rulestead-release-engineering-and-ci.md`**
- Rulestead DNA §2.2–2.3 for concurrency groups, path filters, permissions, SHA-pinned actions, **immutable job `id:`** comments, Dependabot patch auto-merge, semantic PR title lint.

## Chimeway-specific notes

- First tag strategy: **single package** vs monorepo affects `release-please-config.json` — decide in planning before generating workflows.
- Do not publish `prompts/` or `.planning/` on Hex; enforce via `files:` in `mix.exs`.

## Local reproducibility

Every non-trivial CI step should be a **script** invokable from a clean checkout, not a long inline `run:` block (accrue / sigra pattern).
