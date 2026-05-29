# Phase 57: Docs & Release Gates — Research

**Researched:** 2026-05-29
**Status:** Complete

## User Constraints

Copied from `57-CONTEXT.md` — planner MUST honor.

### Locked decisions (summary)
- **DOCS-06:** `guides/introduction/mailglass-integration.md` — full golden path (deps → migrations → config → mailable → trigger → optional inbound via `Chimeway.Webhooks.process/4`)
- **DOCS-07:** New `describe` in `doc_contract_test.exs` with required phrases + `@recipe_forbidden_strings`
- **GATE-04:** `verify.mailglass` alias (root + demo host `--only mailglass`), `ci.test` adds `--exclude mailglass`, dedicated CI job, MAINTAINING sextet
- **D-14/D-15:** Do NOT add verify.mailglass to default `mix ci`; exclude mailglass from default test lane
- **D-22:** Existing quintet behavior unchanged — sextet is additive

### Deferred (out of scope)
- Accrue/Threadline/Sigra blueprints, INBX UI, all TeamPulse notifiers via Mailglass, global demo Mailglass in default test path, Playwright admin smoke

---

## Standard Stack

| Layer | Choice | Notes |
|-------|--------|-------|
| Docs | ExDoc extras in `mix.exs` | Blueprint recipe exists on disk but is **not** in extras list yet (D-20) |
| Doc truth | `test/chimeway/doc_contract_test.exs` | Pattern: setup reads guide path, `@required` for-loop, forbidden strings |
| CI gates | Mix aliases + `.github/workflows/ci.yml` jobs | Mirror `verify_journeys` job (Postgres 15, ecto create/migrate) |
| Mailglass tests | `@moduletag :mailglass` | Root: 3 test modules; demo: `mailglass_delivery_proof_test.exs` |

---

## Architecture Patterns

### Introduction guide shape [VERIFIED: codebase]
`guides/introduction/golden-path.md` uses numbered sections, copy-paste config blocks, "Related guides" footer, links to installation.md for depth. New guide follows same structure with Mailglass-specific sections per D-03.

### Doc-contract describe block [VERIFIED: codebase]
`mailglass blueprint recipe doc contract (ECOS-05)` at line 247: `@mailglass_blueprint_recipe` path expand, setup reads file, forbidden loop, Workflow regex, `@required` list. New describe mirrors this for `@mailglass_integration_guide`.

### Named verify entrypoint [VERIFIED: codebase]
`verify.journeys` runs demo host only with `--only journey`. GATE-04 adds dual subprocess: root `--only mailglass` + demo `--only mailglass` per D-12.

### CI job pattern [VERIFIED: codebase]
`verify_journeys` job: checkout, setup-beam 1.17/OTP 27, cache key per job, deps.get, ecto create/migrate, `mix verify.journeys`. New `verify_mailglass` job clones structure with distinct cache key.

---

## Current State Audit

| Artifact | State | Phase 57 action |
|----------|-------|-----------------|
| `guides/introduction/mailglass-integration.md` | Missing | Create (DOCS-06) |
| `guides/recipes/mailglass-integration-blueprint.md` | Exists, doc-contract covered | Cross-link to guide; update out-of-scope paragraph (D-02) |
| `mix.exs` `verify.mailglass` | Missing | Add alias (D-12) |
| `mix.exs` `ci.test` | `mix test` (no exclude) | Add `--exclude mailglass` (D-15, WR-03) |
| `mix.exs` docs extras | No mailglass paths | Add guide + blueprint (D-19, D-20) |
| `MAINTAINING.md` step 3 | Quintet (5 commands) | Sextet + descriptions (D-18) |
| `.github/workflows/ci.yml` | `verify_journeys`, no mailglass job | Add `verify_mailglass` (D-16) |
| `doc_contract_test.exs` | ECOS-05 blueprint only | Add DOCS-06/07 describe (D-08) |
| `README.md` | No Mailglass mention | Add link to integration guide (D-21) |
| `custom-adapter.md` | Links blueprint only | Link integration guide (D-21) |

---

## Don't Hand-Roll

- **Do not** duplicate blueprint notifier sections in the guide — link to blueprint for copy-paste recipe blocks (D-02)
- **Do not** document `Mailglass.Webhook.Plug` for inbound — use `Chimeway.Webhooks.process/4` (Phase 55 D-02, D-04)
- **Do not** register Mailglass globally in demo `config/test.exs` — journey isolation (D-10, Phase 56)
- **Do not** bundle `verify.mailglass` into `mix ci` (Phase 41 D-09)

---

## Common Pitfalls

1. **Doc-contract path drift** — use `Path.expand("../../guides/introduction/mailglass-integration.md", __DIR__)` like other describes
2. **ci.test exclude without mailglass dep fetched** — root tests still compile; mailglass tests need dep + test_helper bootstrap (existing `config/test.exs`)
3. **MAINTAINING "five" vs six** — update prose "All five must pass" → six (D-18)
4. **Guide implies Logger-only email** — forbidden strings must catch pre-Mailglass-only paths (D-10)
5. **Blueprint extras omission** — recipe on disk since Phase 56 but missing from HexDocs extras (D-20)

---

## Validation Architecture

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Mix) |
| **Config file** | `mix.exs` aliases, `config/test.exs` |
| **Quick run command** | `mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` |
| **Full suite command** | `mix verify.mailglass` |
| **Gate regression** | `mix ci.verify_gates` + `mix verify.journeys` (must stay green) |

### Per-deliverable verification

| Deliverable | Automated command | Manual |
|-------------|-------------------|--------|
| DOCS-06 guide | Doc-contract describe (after 57-02) | HexDocs `mix docs` spot-check |
| DOCS-07 doc-contract | `mix ci.verify_gates` | — |
| GATE-04 alias | `mix verify.mailglass` | — |
| GATE-04 CI | GitHub Actions `verify_mailglass` job | — |
| Fast CI preserved | `mix ci.test` excludes mailglass; count unchanged for non-mailglass tests | — |

---

## Code Examples

### verify.mailglass alias (from CONTEXT D-12)
```elixir
"verify.mailglass": [
  "cmd env MIX_ENV=test mix test --only mailglass --warnings-as-errors",
  "cmd --shell cd examples/chimeway_demo_host && mix deps.get && mix test --only mailglass --warnings-as-errors"
]
```

### ci.test exclude (D-15)
```elixir
"ci.test": ["cmd env MIX_ENV=test mix test --exclude mailglass"],
```

### Doc-contract describe skeleton
```elixir
@mailglass_integration_guide Path.expand("../../guides/introduction/mailglass-integration.md", __DIR__)

describe "mailglass integration guide doc contract (DOCS-06 / DOCS-07)" do
  setup do
    content = File.read!(@mailglass_integration_guide)
    %{content: content}
  end
  # forbidden + required loops
end
```

---

## RESEARCH COMPLETE
