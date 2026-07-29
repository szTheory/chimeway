# Phase 76: Prefix Docs, Demo, and Gates - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md - this log preserves the analysis.

**Date:** 2026-07-01T23:19:58Z
**Phase:** 76-prefix-docs-demo-and-gates
**Mode:** assumptions with expanded subagent research
**Areas analyzed:** Canonical Storage Docs, Upgrade and Public Compatibility, Oban Separation, Demo and Gate Parity, UX/DX/Brand Lenses

## Assumptions Presented

### Canonical Storage Docs

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Phase 76 should treat `README.md`, `guides/introduction/installation.md`, and `guides/introduction/golden-path.md` as the core adopter path, with storage troubleshooting/upgrade guidance added to HexDocs guide surfaces rather than only demo-host copy. | Confident | Phase 72 context; `mix.exs` docs extras; existing README/install/golden-path prefix copy; no current storage upgrade/troubleshooting guide. |

### Upgrade and Public Compatibility

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Upgrade docs must present `prefix: false` as the no-silent-migration compatibility path and frame any public-to-`chimeway` move as a manual operator database procedure, not an automated Chimeway migration. | Confident | Phase 73 context; `lib/chimeway/storage.ex`; generator-only `--prefix public` shape; existing doc contracts requiring "does not move data" and forbidding automatic data-move language. |

### Oban Separation

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Oban prefix caveats belong in the Oban recipe and storage doc contracts as a separate concern from Chimeway's table prefix; happy-path README/install/golden-path docs should keep Chimeway storage prefix language focused. | Confident | Phase 73/75 contexts; installer/generator exclusion of Oban migrations; Oban guide lacks current prefix separation copy; existing README/install/golden-path contracts forbid Oban-prefix language. |

### Demo and Gate Parity

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Phase 76 should close gate parity by proving prefixed install/runtime behavior, public legacy compatibility, storage doc contracts, and demo-host trigger-to-trace under the default `chimeway` schema through named local aliases and matching CI/release-gate contracts. | Likely | `mix.exs` aliases; `.github/workflows/ci.yml` path-gated installer proof; release-gate contracts do not yet count runtime-prefix/install-golden as storage lanes; demo host currently proves trigger-to-trace/admin behavior but not schema placement. |

## Corrections Made

No explicit corrections were made. The user asked for deeper research using subagents and for a cohesive one-shot recommendation set rather than another option menu. The final CONTEXT.md captures those recommendations as decisions.

## Expanded Research Summary

### Canonical Docs and Upgrade Guidance

Options considered:

| Option | Pros | Cons | Tradeoff |
|--------|------|------|----------|
| Layered canonical path: README + Installation + Golden Path, with dedicated upgrade/troubleshooting guide and Oban section | Best first-run DX; keeps prefix choice near `mix chimeway.gen.migrations`; gives manual move and rollback room; matches existing doc-contract pattern. | Repeats short snippets across several docs; needs anti-drift contracts. | Recommended. Use duplication only for the small install-time truth, then centralize operational depth in one guide. |
| Single canonical storage-isolation guide linked from install docs | Centralizes manual move and rollback instructions. | Users following README/golden path may miss the critical first-install config. | Good support reference, insufficient as the only doc surface. |
| Inline-only README/install/golden path copy | Shortest implementation. | Not enough room for UPG-02/UPG-03, Oban separation, rollback, and failure modes. | Too thin for Phase 76 acceptance. |
| First-party automated public-to-`chimeway` migrator | Simple command for users in theory. | High blast radius; violates no-silent-migration posture if over-promoted; hard rollback and locking semantics. | Future milestone only after manual guidance proves stable. |

Recommendation: Layered canonical docs plus a dedicated HexDocs-included storage upgrade/troubleshooting guide.

Lessons applied:

- Phoenix/Ecto generators and Rails/Laravel package migrations succeed when generated host files are visible, reviewable, and committed.
- Django migration churn shows why migration history and compatibility docs must be clear.
- Noticed/Rails durable type rename issues reinforce Chimeway's stable `notification_key` + version posture.
- Chimeway's brand and testing prompts prefer clear, calm docs and executable doc contracts over folklore.

### Oban/Ecto/Phoenix Prefix Idioms

Options considered:

| Option | Pros | Cons | Tradeoff |
|--------|------|------|----------|
| Split core docs plus Oban recipe/troubleshooting | Clear first-run path; optional Oban remains optional; matches Chimeway's separate storage/Oban boundary. | Needs cross-links and tests across multiple docs. | Recommended. |
| Full Oban prefix guidance in README/install/golden path | One-stop for Oban-first users. | Makes Oban feel mandatory and increases Chimeway-vs-Oban prefix confusion. | Too much operational detail for first-run docs. |
| Recipe/troubleshooting only | Keeps core docs compact. | Users may miss the separate `oban_jobs` concern until runtime. | Acceptable only if linked prominently. |
| Dedicated prefix matrix | Centralizes use/avoid examples. | Abstract if not paired with concrete install docs. | Use as part of the new troubleshooting/upgrade guide. |

Recommendation: Keep Oban details in the Oban recipe and new troubleshooting guide. Include a prefix matrix there.

Official sources applied:

- Ecto migration prefixes: `https://hexdocs.pm/ecto_sql/Ecto.Migration.html#module-prefixes`
- Ecto query prefixes: `https://hexdocs.pm/ecto/multi-tenancy-with-query-prefixes.html`
- Ecto repo defaults: `https://hexdocs.pm/ecto/Ecto.Repo.html#c:default_options/1`
- Ecto migration generator: `https://hexdocs.pm/ecto_sql/Mix.Tasks.Ecto.Gen.Migration.html`
- Phoenix generator precedent: `https://hexdocs.pm/phoenix/Mix.Tasks.Phx.Gen.Schema.html`
- Oban database prefixes: `https://hexdocs.pm/oban/isolation.html#database-prefixes`
- Oban migration syntax: `https://hexdocs.pm/oban/Oban.Migration.html`
- Oban installation: `https://hexdocs.pm/oban/installation.html`
- Oban testing: `https://hexdocs.pm/oban/Oban.Testing.html`

Concrete Oban syntax verified:

```elixir
def up, do: Oban.Migration.up(prefix: "jobs")
def down, do: Oban.Migration.down(prefix: "jobs")

config :my_app, Oban,
  repo: MyApp.Repo,
  prefix: "jobs",
  queues: [default: 10]
```

Footguns to guard:

- `config :chimeway, prefix: "public"`
- `mix ecto.migrate --prefix chimeway`
- `@schema_prefix "chimeway"`
- `Chimeway.trigger(..., prefix: ...)`
- Reusing `"chimeway"` as the Oban example prefix.

### Demo and Gate Parity

Options considered:

| Option | Pros | Cons | Tradeoff |
|--------|------|------|----------|
| Always-on runtime/demo gates, path-gated installer | Best balance: storage runtime proof is release-critical; installer proof remains scoped to heavy/generated surfaces. | Adds one required Postgres CI lane and gate-count maintenance. | Recommended. |
| Make install, runtime, and demo proof always-on | Maximum confidence. | Slower CI and more churn on unrelated changes. | Too heavy for current CI shape. |
| Path-gate runtime/demo/install proof | Fast PRs. | Runtime prefix can regress from broad code changes; skipped required checks are fragile. | Bad fit for release-critical runtime behavior. |
| Release-only/manual heavy gates | Lean normal CI. | Finds failures late; weak local/CI parity. | Not suitable for Phase 76. |

Recommendation: Promote `verify.runtime_prefix` to a required CI lane and release-gate contract. Keep `install_golden_contract` path-gated but contract-counted. Put DEMO-01 in the existing demo/example proof path using public APIs.

Footguns to guard:

- CI passes while demo host remains in public/unconfigured storage mode.
- Runtime prefix proof is only local and never required by CI.
- Release contracts count old ecosystem gates but omit storage prefix gates.
- Demo proof uses fixture inserts instead of adopter-copyable public APIs.

## Methodology Lenses Applied

- Cohesive Recommendation Default: collapse options into one aligned recommendation set.
- High-Impact Escalation Gate: avoid pushing reversible implementation-local choices back to the user.
- Research-First Decision Ownership: use codebase evidence and official docs before deciding.
- One-Shot Recommendation Bias: make a coherent recommendation rather than leaving a menu.
- Durable Explainability Bias: keep storage behavior and demo proof durable, queryable, and auditable.
- Least-Surprise DX Default: preserve a short first-run path and move complex operations to troubleshooting/upgrade docs.
- Low-Escalation Recommendation Default: record decisions directly after the user's one-shot request.

## External Research

- Ecto/Phoenix official docs support generated, host-owned migration files and explicit prefix semantics:
  `https://hexdocs.pm/ecto_sql/Ecto.Migration.html#module-prefixes`,
  `https://hexdocs.pm/ecto/multi-tenancy-with-query-prefixes.html`,
  `https://hexdocs.pm/ecto/Ecto.Repo.html#c:default_options/1`,
  `https://hexdocs.pm/ecto_sql/Mix.Tasks.Ecto.Gen.Migration.html`,
  `https://hexdocs.pm/phoenix/Mix.Tasks.Phx.Gen.Schema.html`
- Oban official docs confirm Oban has its own migration/config/testing prefix surface:
  `https://hexdocs.pm/oban/isolation.html#database-prefixes`,
  `https://hexdocs.pm/oban/Oban.Migration.html`,
  `https://hexdocs.pm/oban/installation.html`,
  `https://hexdocs.pm/oban/Oban.Testing.html`
- Rails engines and Laravel package docs reinforce visible copied/published migrations as an ecosystem pattern:
  `https://guides.rubyonrails.org/engines.html#engine-setup`,
  `https://laravel.com/docs/13.x/packages#migrations`
