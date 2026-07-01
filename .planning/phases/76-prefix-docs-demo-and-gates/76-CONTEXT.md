# Phase 76: Prefix Docs, Demo, and Gates - Context

**Gathered:** 2026-07-01 (assumptions mode, expanded subagent research)
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 76 makes v1.13 storage isolation adoptable and supportable. The scope is documentation,
demo proof, upgrade guidance, Oban caveats, and named verification gates for the already-built
storage-prefix contract, prefixed migration generator, and runtime prefix propagation.

In scope: UPG-02, UPG-03, DOCS-01, DOCS-02, DEMO-01, and GATE-01.

Out of scope: dynamic per-tenant database prefixes, first-party automated production data moves,
new storage runtime semantics, broad README/package truth cleanup beyond prefix-specific docs,
new admin UI design, and a new browser smoke suite unless an existing proof path cannot cover
DEMO-01.
</domain>

<decisions>
## Implementation Decisions

### Canonical Storage Docs

- **D-01:** Use a layered documentation model. Keep short install-time truth in `README.md`,
  `guides/introduction/installation.md`, and `guides/introduction/golden-path.md`: new installs use
  `config :chimeway, prefix: "chimeway"` and existing public-schema legacy installs use
  `config :chimeway, prefix: false`.
- **D-02:** Add a dedicated HexDocs-included storage prefix upgrade/troubleshooting guide for
  public-to-`chimeway` manual moves, rollback notes, failure modes, and the full prefix matrix.
  Do not bury UPG-02/UPG-03 only in README, demo-host copy, or MAINTAINING.
- **D-03:** Preserve the existing doc-contract posture that README/install/golden path remain
  beginner-safe: no `--prefix public`, no Oban prefix details, no `mix ecto.migrate --prefix
  chimeway`, and no automatic data-move language in those first-run docs.
- **D-04:** Include the new storage/upgrade guide in `mix.exs` HexDocs extras and add doc contracts
  that lock its required claims and forbidden footguns.

### Upgrade and Public Compatibility

- **D-05:** Treat `prefix: false` as the no-silent-migration compatibility path. It means "keep
  using existing unprefixed/public Chimeway tables" and does not move, copy, rewrite, or backfill
  existing data.
- **D-06:** Frame public-to-`chimeway` movement as a manual operator database procedure with
  preflight checks, backup expectations, transaction/lock caveats, verification queries, rollback
  guidance, and clear "stop and restore" failure notes.
- **D-07:** Do not introduce or imply a first-party automated move task in Phase 76. If the guide
  mentions automation, it must be future/out-of-scope language and must not become the recommended
  production path.
- **D-08:** Keep generator language precise: `mix chimeway.gen.migrations --prefix public` is
  generator-only compatibility sugar for legacy unprefixed migration output; runtime public mode is
  still `config :chimeway, prefix: false`.

### Oban and Ecto Prefix Separation

- **D-09:** Document Chimeway's storage prefix and Oban's job-table prefix as separate operational
  concerns. `config :chimeway, prefix: "chimeway"` routes Chimeway-owned `chimeway_*` tables; it
  does not create, move, or configure `oban_jobs`.
- **D-10:** Put full Oban prefix guidance in `guides/recipes/oban-integration.md` and the new
  storage troubleshooting/upgrade guide, not in the first-run README/install/golden path.
- **D-11:** Use official Oban-style examples for Oban-owned tables, such as
  `Oban.Migration.up(prefix: "jobs")` / `Oban.Migration.down(prefix: "jobs")` and
  `config :my_app, Oban, prefix: "jobs"`. Avoid using `"chimeway"` as the Oban example prefix
  because that implies coupling.
- **D-12:** Guard docs and examples against Ecto prefix footguns: no `@schema_prefix "chimeway"`,
  no public API examples like `Chimeway.trigger(..., prefix: ...)`, no `prefix: "public"` runtime
  config, no `prefix: false` passed into generated Ecto operations, and no reliance on
  `search_path` or `mix ecto.migrate --prefix chimeway`.

### Demo and Gate Parity

- **D-13:** Make `mix verify.runtime_prefix` a first-class CI lane required by `ci-gate` and counted
  by `test/chimeway/release_gate_contract_test.exs`.
- **D-14:** Keep `mix verify.install_golden` / `mix ci.install_golden` as the path-gated installer
  proof. It is heavy and generator-specific, but release contracts should still ensure the alias
  and CI job exist.
- **D-15:** Put DEMO-01 in the existing demo/example proof path instead of creating a new browser
  smoke suite. Configure the demo host for `prefix: "chimeway"` and prove a public
  `Chimeway.trigger/3` or `DemoHost.Seeds` trigger-to-trace flow writes Chimeway rows under
  `chimeway.*` while `public.chimeway_*` remains empty.
- **D-16:** Demo proof must use public APIs and existing adopter-copyable seed paths. Avoid fixture
  inserts or storage internals as the primary acceptance path.
- **D-17:** Update local/CI/release documentation together: `mix.exs` aliases, `.github/workflows/ci.yml`,
  `MAINTAINING.md`, and release-gate contracts must agree on the storage prefix gates.

### User Experience and Voice

- **D-18:** Keep user-facing language calm, literal, and operator-safe: "isolated Chimeway schema",
  "public-schema legacy mode", "does not move data", "manual database operation", and "Oban's
  job table is separate" are preferred over Ecto-internal phrasing in first-run docs.
- **D-19:** Preserve the Chimeway brand posture from prompts: local-first ownership, explainable
  delivery, Elixir-native explicitness, and "no hidden magic." Documentation should help adopters
  make the safe choice without exposing backend internals unless the operational constraint
  requires it.

### Claude's Discretion

The user explicitly requested deep subagent research and a one-shot cohesive recommendation set
so they do not have to choose among medium-stakes options. Downstream agents should implement the
recommended set above unless fresh code evidence makes a decision impossible. If a conflict appears,
preserve the architecture: layered docs, manual upgrade guidance, split Oban guidance, runtime-prefix
CI parity, path-gated installer proof, and demo-host prefix proof through public APIs.

### Folded Todos

None.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Planning and Prior Context

- `.planning/ROADMAP.md`
- `.planning/REQUIREMENTS.md`
- `.planning/PROJECT.md`
- `.planning/STATE.md`
- `.planning/phases/72-admin-docs-and-verification-gate/72-CONTEXT.md`
- `.planning/phases/73-storage-prefix-contract/73-CONTEXT.md`
- `.planning/phases/74-prefixed-migration-generator/74-CONTEXT.md`
- `.planning/phases/75-runtime-prefix-propagation/75-CONTEXT.md`

### Project Prompts and Lenses

- `prompts/chimeway-brand-book.md`
- `prompts/chimeway-engineering-dna-from-prior-libs.md`
- `prompts/chimeway-release-engineering-and-ci.md`
- `prompts/chimeway-testing-and-e2e-strategy.md`
- `prompts/chimeway-host-app-integration-seam.md`
- `prompts/elixir_notifykit_research_brief.md`

### Docs, Gates, and Demo Surfaces

- `README.md`
- `guides/introduction/installation.md`
- `guides/introduction/golden-path.md`
- `guides/recipes/oban-integration.md`
- `mix.exs`
- `.github/workflows/ci.yml`
- `MAINTAINING.md`
- `test/chimeway/doc_contract_test.exs`
- `test/chimeway/release_gate_contract_test.exs`
- `test/chimeway/repo_prefix_test.exs`
- `test/chimeway/runtime_prefix_integration_test.exs`
- `test/chimeway/install/golden_diff_test.exs`
- `test/chimeway/install/idempotency_test.exs`
- `test/chimeway/install/prefix_contract_test.exs`
- `test/chimeway/migration_contract_test.exs`
- `examples/chimeway_demo_host/config/dev.exs`
- `examples/chimeway_demo_host/config/test.exs`
- `examples/chimeway_demo_host/README.md`
- `examples/chimeway_demo_host/test/demo_host_web/admin_trace_live_test.exs`

### External References Applied

- `https://hexdocs.pm/ecto_sql/Ecto.Migration.html#module-prefixes`
- `https://hexdocs.pm/ecto/multi-tenancy-with-query-prefixes.html`
- `https://hexdocs.pm/ecto/Ecto.Repo.html#c:default_options/1`
- `https://hexdocs.pm/ecto_sql/Mix.Tasks.Ecto.Gen.Migration.html`
- `https://hexdocs.pm/phoenix/Mix.Tasks.Phx.Gen.Schema.html`
- `https://hexdocs.pm/oban/isolation.html#database-prefixes`
- `https://hexdocs.pm/oban/Oban.Migration.html`
- `https://hexdocs.pm/oban/installation.html`
- `https://hexdocs.pm/oban/Oban.Testing.html`
- `https://guides.rubyonrails.org/engines.html#engine-setup`
- `https://laravel.com/docs/13.x/packages#migrations`
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- Existing first-run docs already include the minimal storage prefix truth:
  `README.md`, `guides/introduction/installation.md`, and
  `guides/introduction/golden-path.md`.
- `test/chimeway/doc_contract_test.exs` already has storage prefix contracts for
  README/install/golden path and an Oban recipe contract that can be extended.
- `mix.exs` already defines `verify.install_golden`, `verify.runtime_prefix`,
  `ci.install_golden`, and `ci.verify_gates`.
- `.github/workflows/ci.yml` already has a path-gated `install_golden_contract`
  job and required `ci-gate` aggregation.
- `test/chimeway/runtime_prefix_integration_test.exs` already proves broad runtime prefix behavior,
  including Oban job-table separation in tests.
- `examples/chimeway_demo_host/test/demo_host_web/admin_trace_live_test.exs` already proves
  trigger-to-admin-trace behavior through public demo seed paths; it can be extended or mirrored
  for schema placement proof.

### Established Patterns

- Canonical adopter docs live in `guides/introduction/` and are included in HexDocs extras.
- Deep operational recipes live under `guides/recipes/`; Oban already has a dedicated recipe.
- Doc contracts lock positive and negative phrases to prevent copy-paste drift.
- Verify gates are named `mix verify.*` aliases and CI calls the same local command where practical.
- Heavy installer golden/DB proof is path-gated rather than part of default `mix ci`.
- Demo proof should reuse public APIs and seed helpers rather than storage internals.

### Integration Points

- Add the new storage upgrade/troubleshooting guide to `mix.exs` docs extras and grouped extras.
- Extend `test/chimeway/doc_contract_test.exs` for the new guide, Oban prefix caveat, and storage
  footgun forbiddance.
- Extend `test/chimeway/release_gate_contract_test.exs` for runtime-prefix CI parity and storage
  gate expectations.
- Add or update `.github/workflows/ci.yml` so `verify_runtime_prefix` runs `mix verify.runtime_prefix`
  and is required by `ci-gate`.
- Update `MAINTAINING.md` to list the storage-prefix gates and distinguish always-on runtime proof
  from path-gated installer proof.
- Update demo-host config/tests so the demo host runs under `prefix: "chimeway"` and proves
  trigger-to-trace placement in that schema.
</code_context>

<specifics>
## Specific Ideas

- New guide name: `guides/introduction/storage-prefix-upgrade.md` or
  `guides/introduction/storage-isolation-upgrade.md`.
- Include a small prefix matrix in the new guide:
  - Chimeway generator default: `mix chimeway.gen.migrations`
  - Chimeway generator legacy output: `mix chimeway.gen.migrations --prefix public`
  - Chimeway runtime default: `config :chimeway, prefix: "chimeway"`
  - Chimeway runtime legacy public mode: `config :chimeway, prefix: false`
  - Oban migration/config example: `Oban.Migration.up(prefix: "jobs")` and
    `config :my_app, Oban, prefix: "jobs"`
- Add explicit "do not" examples for `config :chimeway, prefix: "public"`,
  `mix ecto.migrate --prefix chimeway`, and `Chimeway.trigger(..., prefix: ...)`.
- Prefer Oban example prefix `"jobs"` over `"chimeway"` to avoid implying shared ownership.
- Demo proof can assert schema placement with direct SQL/count helpers after a public seed trigger,
  while the user-visible proof still goes through `Chimeway.Traces.explain_delivery/1`.
</specifics>

<deferred>
## Deferred Ideas

- First-party automated public-to-`chimeway` production move task.
- Dynamic per-tenant database prefixes.
- Broader README/package/release truth cleanup beyond storage-prefix documentation.
- New browser smoke or UI work for Phase 76 unless implementation discovers that existing demo
  proof cannot satisfy DEMO-01.

### Reviewed Todos (not folded)

None.
</deferred>
