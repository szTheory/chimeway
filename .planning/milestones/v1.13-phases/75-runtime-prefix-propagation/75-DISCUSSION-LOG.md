# Phase 75: Runtime Prefix Propagation - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md. This log preserves the analysis.

**Date:** 2026-07-01T15:28:46Z
**Phase:** 75-runtime-prefix-propagation
**Mode:** assumptions with expanded subagent research
**Areas analyzed:** runtime storage contract, transactional flow propagation, verification strategy, cross-ecosystem DX lessons

## Assumptions Presented

### Runtime Storage Contract

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Runtime prefix propagation should be applied through `Chimeway.Storage.repo_opts/1` at every Chimeway-owned Repo boundary, with local option cleanup only for non-Repo domain opts. | Confident | `lib/chimeway/storage.ex`, `lib/chimeway/traces.ex`, `lib/chimeway/admin.ex`, Phase 73 context |

### Transactional Flow Propagation

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Prefix handling must cover full transactional flows, including `Ecto.Multi`, transaction callbacks, worker reloads, duplicate lookups, and `insert_all` calls, not just top-level public read APIs. | Confident | `lib/chimeway/trigger.ex`, `lib/chimeway/deliveries.ex`, `lib/chimeway/digests/accumulation.ex`, `lib/chimeway/digests/emission.ex`, `lib/chimeway/webhooks.ex`, `lib/chimeway/workflows/progression.ex` |

### Verification Shape

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Phase 75 should add focused prefixed runtime integration proof while keeping the existing public-mode test baseline intact. | Confident | `config/config.exs`, `test/support/data_case.ex`, `test/chimeway/migration_contract_test.exs`, existing runtime integration tests |

## Expanded Research Requested

After the initial assumption pass, the user requested deeper one-shot research with subagents on:

- Pros, cons, and tradeoffs for each viable approach.
- Idiomatic Elixir, Plug, Ecto, and Phoenix design for this type of embedded library.
- Lessons from popular/successful libraries and frameworks in Elixir and other ecosystems.
- DX, principle of least surprise, software architecture, SRE/devops, testability, and maintainability.
- UI/UX, persona, JTBD, brand, and microcopy considerations where applicable.
- Project prompt material under `prompts/`, with newer Chimeway brand guidance preferred.

## Research Performed

### Assumptions Analyzer

The `gsd-assumptions-analyzer` subagent inspected Phase 75 code hotspots and returned three confident assumptions:

- Use the Phase 73 storage contract instead of ad hoc prefix logic.
- Audit full transactional and worker flows, including `Ecto.Multi`, callback repos, duplicate lookups, and string-source `insert_all`.
- Add prefixed runtime integration proof while preserving public legacy tests.

### Ecto Research

A research subagent checked official Ecto documentation and found:

- `:prefix` is a repo operation option, not an ambient transaction setting.
- `Repo.transaction/2` and `Repo.transact/2` options are transaction options; they should not be used as the primary prefix propagation mechanism.
- `Ecto.Multi.run/3` callbacks receive a transaction repo, but callback repo use still needs operation-level prefix behavior.
- `Ecto.Multi` operations use their own operation options.
- `Repo.insert_all/3` supports schema modules, string sources, or `{source, schema}` tuples, and supports `prefix:` for string-source inserts.

Sources:

- `https://hexdocs.pm/ecto/3.14.0/Ecto.Query.html#module-query-prefix`
- `https://hexdocs.pm/ecto/3.14.0/Ecto.Repo.html#c:default_options/1`
- `https://hexdocs.pm/ecto/3.14.0/Ecto.Repo.html#c:transact/2`
- `https://hexdocs.pm/ecto/3.14.0/Ecto.Repo.html#c:transaction/2`
- `https://hexdocs.pm/ecto/3.14.0/Ecto.Multi.html#run/3`
- `https://hexdocs.pm/ecto/3.14.0/Ecto.Multi.html#insert_all/5`
- `https://hexdocs.pm/ecto/3.14.0/Ecto.Repo.html#c:insert_all/3`

### Interface Shape Research

A design subagent compared four approaches:

- Manual per-operation `Chimeway.Storage.repo_opts/1`.
- `Chimeway.Repo.default_options/1` delegating to `Chimeway.Storage.repo_opts/1`.
- Schema-level `@schema_prefix`.
- Wrapper/port such as `Chimeway.Storage.Repo` or a storage context struct.

It recommended `Chimeway.Repo.default_options/1` as the primary mechanism because it is the most idiomatic Ecto seam, minimizes missed call-site risk, keeps call sites normal, and still allows explicit override probes.

### Verification Research

A verification subagent recommended:

- Keep root/default tests in explicit public legacy mode.
- Add a separate required prefixed runtime integration suite.
- Do not flip the whole test config to prefixed mode.
- Do not accept migration-contract-only proof for Phase 75.
- Use unit/static checks as guardrails, not acceptance evidence.

Suggested runtime proof covered trigger-to-trace, duplicate idempotency, inbox lifecycle, workflow progression, digest emission, webhook feedback, recovery, worker reloads, Oban prefix separation, and public legacy compatibility.

### Cross-Ecosystem Research

A cross-framework subagent synthesized lessons from Rails engines, Laravel packages/notifications, Symfony Notifier, Noticed, Ecto, and Oban:

- Borrow namespace ownership, deterministic published migrations, concise notification APIs, adapter seams, and DB-backed notification records.
- Avoid `schema_search_path` ambient state, class-name durable identity, overloaded DSN strings, queue payload archaeology, and coupling Chimeway storage prefix to Oban job-table prefix.
- Hide backend storage details from happy-path APIs while making storage mode visible enough in diagnostics.

Sources included:

- `https://guides.rubyonrails.org/engines.html`
- `https://api.rubyonrails.org/classes/ActiveRecord/ConnectionAdapters/PostgreSQLAdapter.html`
- `https://laravel.com/docs/notifications`
- `https://laravel.com/docs/packages`
- `https://symfony.com/doc/current/notifier.html`
- `https://github.com/excid3/noticed`
- `https://hexdocs.pm/oban/Oban.Migration.html`

## Corrections Made

### Runtime Storage Contract

- **Original assumption:** Manually apply `Chimeway.Storage.repo_opts/1` at every Chimeway-owned Repo boundary.
- **Correction after expanded research:** Use `Chimeway.Repo.default_options/1` as the primary runtime propagation mechanism, implemented by delegating to `Chimeway.Storage.repo_opts/1`. Keep per-context `repo_opts(opts)` helpers only for stripping domain/query options and preserving explicit prefix probes.
- **Reason:** This keeps ordinary Chimeway APIs clean for adopters, aligns with Ecto's official repo callback seam, reduces missed-call-site risk, and preserves Phase 73's storage helper as the single source of prefix truth.

### Transactional Flow Propagation

- **Original assumption:** Transactional and worker flows need operation-level prefix behavior.
- **Final decision:** Keep this assumption, but express it through repo defaults plus focused audits/tests for `Ecto.Multi`, `Multi.run`, string-source `insert_all`, duplicate lookups, worker reloads, and preloads.
- **Reason:** Ecto prefix is not ambient transaction state, and runtime correctness depends on nested operations landing in the configured Chimeway schema.

### Verification Shape

- **Original assumption:** Add focused prefixed runtime proof while keeping public legacy tests intact.
- **Final decision:** Keep this assumption. Prefer a separate prefixed integration suite over flipping the whole test config. Migration-contract-only proof is insufficient.
- **Reason:** Phase 74 proved generated migrations; Phase 75 must prove runtime paths. The current `prefix: false` baseline remains compatibility evidence.

## UI/UX Applicability

Phase 75 is backend runtime storage plumbing, so there is no direct screen, layout, graphic-design, or interactive UI deliverable.

The UI/UX and persona translation is API/docs/test DX:

- Feature developers configure once and keep using ordinary Chimeway APIs.
- Staff/backend engineers get deterministic storage placement proof.
- Support operators keep trace/debug workflows without seeing Ecto internals.
- Maintainer diagnostics can say "isolated Chimeway schema" or "public-schema legacy mode"; Ecto terms belong in maintainer/troubleshooting context.

## Deferred Ideas

- Dynamic per-tenant database prefixes.
- Automated public-to-`chimeway` data move.
- Full storage docs, Oban caveats, demo proof, and release-gate/doc-contract parity in Phase 76.
- Broader tenant spine redesign.

## Auto-Resolved

Not applicable.

## External Research

External research was performed through official/library documentation and ecosystem references listed above. The key confidence impact was upgrading the storage contract recommendation from manual per-operation propagation to `Chimeway.Repo.default_options/1` plus targeted audits and integration proof.
