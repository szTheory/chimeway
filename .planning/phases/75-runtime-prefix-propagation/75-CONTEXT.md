# Phase 75: Runtime Prefix Propagation - Context

**Gathered:** 2026-07-01 (assumptions mode with expanded research)
**Status:** Ready for planning

<domain>
## Phase Boundary

Thread the static Chimeway storage-prefix contract through runtime behavior so real notification flows read and write Chimeway-owned rows in the configured schema. This phase covers trigger fanout, idempotency, duplicate detection, lifecycle reads, traces, explainability, inbox, admin, recovery, workflows, signals, digests, policy/preferences, webhooks, dispatch workers, and string-source `insert_all` calls.

This phase does not introduce dynamic per-tenant database prefixes, automatic public-to-`chimeway` data moves, or broad prefix documentation/demo/release-gate composition beyond the runtime proof needed for RUN-01 through RUN-04.

</domain>

<decisions>
## Implementation Decisions

### Runtime Storage Contract

- **D-01:** Use `Chimeway.Repo.default_options/1` as the primary runtime prefix propagation mechanism, implemented by delegating to `Chimeway.Storage.repo_opts/1`.
- **D-02:** Keep `Chimeway.Storage.repo_opts/1` as the single storage-prefix mapping contract. It continues to map `prefix: "chimeway"` to `[prefix: "chimeway"]`, map `prefix: false` to unprefixed repo options, and preserve explicit caller `:prefix` probes through `Keyword.put_new/3`.
- **D-03:** Runtime prefix should be a property of `Chimeway.Repo`, not an option ordinary adopters pass through `Chimeway.trigger/3`, inbox APIs, admin APIs, recovery APIs, workflow APIs, or worker args.
- **D-04:** Keep local context `repo_opts(opts)` helpers only for stripping domain/query options such as `:limit`, `:tenant_id`, `:recipient_id`, `:older_than`, `:now`, cursors, or filters. Those helpers must not invent independent prefix logic.
- **D-05:** Preserve explicit `prefix:` override probes for tests, admin/debug reads, and maintenance diagnostics. This remains a controlled escape hatch, not a public per-request or per-tenant database-prefix API.

### Rejected Interface Shapes

- **D-06:** Do not use schema-level `@schema_prefix` for Chimeway-owned schemas. It is compile-time, fights `prefix: false`, weakens explicit probe overrides, and does not cover string-source bulk operations.
- **D-07:** Do not introduce a broad `Chimeway.Storage.Repo` wrapper, storage context struct, or partial Ecto facade in Phase 75. That adds arity/options drift, complicates `Ecto.Multi.run/3`, and looks like dynamic per-request prefix support.
- **D-08:** Do not make manual per-operation `Chimeway.Storage.repo_opts/1` calls the primary propagation strategy. It is correct when needed, but too easy to miss across the existing runtime surface.

### Transactional and Async Flow Semantics

- **D-09:** Do not rely on transaction options, worker context, process state, Postgres `search_path`, or Oban config to carry Chimeway's table prefix implicitly.
- **D-10:** Audit full transactional flows, not only top-level public APIs: `Ecto.Multi` operations, `Multi.run` callback repo calls, `Repo.transaction`/`Repo.transact` bodies, preloads, duplicate lookups, worker reloads, `update_all`, `delete_all`, and `insert_all`.
- **D-11:** Treat string-source `insert_all` as a named risk area. Trigger fanout currently inserts `"chimeway_notifications"` rows through the transaction repo; planners must prove that path lands in the configured prefix.
- **D-12:** Oban job args remain backend-neutral and durable-ID based. Jobs should carry IDs such as `delivery_id`, `workflow_run_id`, or `ingress_id`, not prefix values, copied payloads, tenant-scoped DB state, or rendered data. Workers rehydrate from Chimeway storage through configured repo behavior.
- **D-13:** Chimeway's storage prefix remains separate from Oban's job-table prefix. Tests and later docs must not conflate the two.

### Verification Strategy

- **D-14:** Keep the default/root test config in explicit public-schema legacy mode (`prefix: false`). That baseline is valuable compatibility proof, not debt to remove.
- **D-15:** Add focused prefixed runtime integration proof using real Postgres and generated prefixed migrations or an equivalent normal migrate path. Migration-contract-only proof is insufficient for Phase 75 because runtime code can still leak to `public`.
- **D-16:** Required prefixed proof should cover trigger-to-trace, duplicate idempotency, inbox list/unread/mark_read/mark_seen plus signal emission, workflow progression, digest accumulation/emission, webhook ingress plus `ProcessFeedbackWorker`, admin/trace/recovery reads and writes, and worker reloads by durable IDs.
- **D-17:** Prefer a separate non-async prefixed runtime integration suite over flipping the entire test config to prefixed mode. Use dual-run selected tests only where the duplication is clearly worth the maintenance cost.
- **D-18:** Add unit/static guardrails around `Repo.default_options/1`, `Chimeway.Storage.repo_opts/1`, explicit override behavior, and string-source `insert_all` coverage, but do not treat those as acceptance evidence by themselves.
- **D-19:** If Phase 75 adds a named local alias such as `mix verify.runtime_prefix`, keep it focused on runtime proof. Phase 76 still owns final docs/demo/release-gate parity and broader ecosystem `verify.*` composition.

### DX, Persona, and Operator Lens

- **D-20:** Runtime prefix propagation is backend-only. There is no end-user UI change in this phase.
- **D-21:** The developer experience should be "configure once, use ordinary Chimeway APIs." Feature developers should not learn or pass Ecto prefix options during normal notification work.
- **D-22:** Staff/backend engineers should get deterministic evidence that Chimeway-owned rows land in the intended schema and that public legacy mode remains supported.
- **D-23:** Support operators should keep using traces, admin read models, and recovery surfaces without seeing backend storage implementation details. Diagnostics may say "isolated Chimeway schema" or "public-schema legacy mode"; reserve "Ecto prefix/repo opts" for maintainer docs and troubleshooting.
- **D-24:** Preserve Chimeway's durable explainability bias: every storage-routing decision should keep trigger, notification, delivery, attempt, signal, workflow, digest, webhook, admin, and recovery facts queryable from durable rows.

### Lessons Applied

- **D-25:** Learn from Rails engines: visible namespace ownership and collision resistance are good, but connection-level `schema_search_path`-style ambient state is a footgun for explainable storage routing.
- **D-26:** Learn from Laravel package migrations: generated/published host migrations should be inspectable and deterministic; runtime should not hide storage behavior behind unreviewable magic.
- **D-27:** Learn from Laravel Notifications and Noticed: persisting class/module names as durable identity creates rename footguns. Chimeway must keep stable `notification_key` plus version as the durable identity while prefix routing stays storage plumbing.
- **D-28:** Learn from Symfony Notifier DSNs: compact overloaded strings create escaping/configuration footguns. Chimeway should keep boring typed config, structured errors, and explicit adapter/storage contracts.
- **D-29:** Learn from Ecto and Oban: prefixes are powerful but operationally expensive when dynamic. Phase 75 stays static per install and does not introduce prefix-per-tenant runtime tenancy.

### Claude's Discretion

Downstream agents may choose the narrowest implementation that satisfies these decisions. If `Repo.default_options/1` cannot cover a specific Ecto operation in the project's pinned version, planners should add explicit `Chimeway.Storage.repo_opts/1` only at that operation while keeping repo defaults as the primary contract.

### Folded Todos

None.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Planning and Requirements

- `.planning/ROADMAP.md` - Phase 75 boundary, dependencies, and success criteria.
- `.planning/REQUIREMENTS.md` - RUN-01 through RUN-04 and v1.13 out-of-scope constraints.
- `.planning/PROJECT.md` - Current milestone goal, local-first storage posture, and project principles.
- `.planning/STATE.md` - Current phase position and accumulated decisions.
- `.planning/METHODOLOGY.md` - Recommendation and escalation lenses applied to this context.
- `.planning/phases/73-storage-prefix-contract/73-CONTEXT.md` - Locked runtime prefix contract, `Chimeway.Storage.repo_opts/1`, strict valid values, and rejected dynamic prefix/API shapes.
- `.planning/phases/74-prefixed-migration-generator/74-CONTEXT.md` - Generated migration semantics, public generation compatibility, and migration proof expectations.
- `.planning/research/v1.12-quality-readiness/PG-SCHEMA-ISOLATION-DECISION.md` - Source decision for the storage-isolation milestone.
- `.planning/research/v1.12-quality-readiness/SYNTHESIS-ROADMAP.md` - Quality-readiness roadmap source.

### Project Prompts and Prior Research

- `prompts/chimeway-engineering-dna-from-prior-libs.md` - OSS library DNA, stable identity, explainability, verification-as-product.
- `prompts/chimeway-host-app-integration-seam.md` - Host ownership boundaries for auth, tenancy, Repo/prefix, URL generation, actor/correlation.
- `prompts/chimeway-testing-and-e2e-strategy.md` - Real Postgres integration tests, named verify entrypoints, and golden installer proof.
- `prompts/chimeway-release-engineering-and-ci.md` - Local/CI parity expectations and release-gate posture.
- `prompts/chimeway-admin-ui-and-operator-ia.md` - Operator trace/debug persona lens; relevant only as API/admin-read-model DX, not UI scope.
- `prompts/chimeway-brand-book.md` - Calm, developer-native, no-hidden-magic copy and explainability tone.
- `prompts/elixir_notifykit_research_brief.md` - Notification domain nouns, lifecycle spine, footguns, personas, and prior-art references.
- `prompts/prior-art/SOURCE-CANONICAL.md` - Canonical shared Elixir/Ecto/Phoenix/OSS research index.
- `/Users/jon/projects/rulestead/prompts/ecto-best-practices-deep-research.md` - Ecto contexts, transactions, prefixes, testing, and anti-footguns.
- `/Users/jon/projects/rulestead/prompts/elixir-opensource-libs-best-practices-deep-research.md` - OSS library API/DX guidance.
- `/Users/jon/projects/rulestead/prompts/elixir-plug-ecto-phoenix-system-design-best-practices-deep-research.md` - Production Phoenix/Ecto system design, migrations, telemetry, and operational footguns.
- `/Users/jon/projects/rulestead/prompts/elixir-oss-lib-ci-cd-best-practices-deep-research.md` - Library CI/CD and verification guidance.
- `/Users/jon/projects/rulestead/prompts/phoenix-best-practices-deep-research.md` - Phoenix context/API boundary guidance.

### Runtime Code Hotspots

- `lib/chimeway/storage.ex` - Existing `validate_prefix!/0` and `repo_opts/1` storage-prefix contract.
- `lib/chimeway/repo.ex` - Target for `Repo.default_options/1`.
- `lib/chimeway/trigger.ex` - Trigger transaction, event insert, string-source notification `insert_all`, workflow-run creation, duplicate idempotency lookup, and dispatch handoff.
- `lib/chimeway/deliveries.ex` - Delivery planning, attempts, recovery, terminal transitions, and provider-message lookup.
- `lib/chimeway/traces.ex` - Trace/explainability reads and explicit prefix probe tests.
- `lib/chimeway/admin.ex` - Admin DTO reads and existing local domain-option filtering pattern.
- `lib/chimeway/inbox.ex` - Inbox reads, lifecycle updates, and read/seen signal emission.
- `lib/chimeway/preferences.ex` - Notification preference reads/writes.
- `lib/chimeway/policy.ex` and `lib/chimeway/policy/settings.ex` - Policy and settings reads/writes.
- `lib/chimeway/workflows.ex` - Workflow definitions, runs, steps, and lock helpers.
- `lib/chimeway/workflows/progression.ex` - Workflow progression transaction and due-run path.
- `lib/chimeway/signal.ex` - Durable signal tracking and routing entrypoint.
- `lib/chimeway/digests.ex` and `lib/chimeway/digests/*.ex` - Digest rules, buckets, memberships, accumulation, and emission.
- `lib/chimeway/webhooks.ex` - Webhook ingress transaction plus Oban insert.
- `lib/chimeway/webhooks/process_feedback_worker.ex` - Ingress worker reloads and feedback application.
- `lib/chimeway/dispatch/oban_worker.ex` - Delivery worker reloads.
- `lib/chimeway/dispatch/signal_router_worker.ex` - Signal routing worker reloads.
- `lib/chimeway/dispatch/workflow_progression_worker.ex` - Workflow progression worker reloads.
- `lib/chimeway/dispatch/digest_flush_worker.ex` - Digest flush worker reloads.

### Test and Gate Hotspots

- `config/config.exs` - Current explicit public legacy test/runtime config.
- `test/support/data_case.ex` - SQL Sandbox setup and potential prefixed-suite isolation point.
- `test/chimeway/storage_test.exs` - Existing storage-prefix contract tests.
- `test/chimeway/traces_test.exs` - Existing explicit prefix probe coverage.
- `test/chimeway/migration_contract_test.exs` - Generated prefixed/public migration DB proof from Phase 74.
- `test/chimeway/trigger_pipeline_test.exs` - Trigger, dispatch, and workflow examples to reuse.
- `test/chimeway/inbox_integration_test.exs` and `test/chimeway/inbox_state_transition_test.exs` - Inbox mark/read/seen behavior.
- `test/chimeway/orchestration/workflow_progression_test.exs` - Workflow progression behavior.
- `test/chimeway/digests/*.exs` - Digest accumulation/emission proof patterns.
- `test/chimeway/webhooks/*.exs` - Webhook ingress and feedback worker proof.
- `test/chimeway/orchestration/recovery_test.exs` - Recovery proof patterns.
- `mix.exs` - Verify aliases and eventual focused runtime-prefix gate.
- `.github/workflows/ci.yml` - CI parity, likely finalized in Phase 76.

### External Primary and Ecosystem Sources

- `https://hexdocs.pm/ecto/Ecto.Repo.html` - Repo operation options and `default_options/1`.
- `https://hexdocs.pm/ecto/Ecto.Multi.html` - Multi operations and callback repo semantics.
- `https://hexdocs.pm/ecto/multi-tenancy-with-query-prefixes.html` - Ecto query prefix semantics.
- `https://hexdocs.pm/ecto/Ecto.Schema.html` - Schema prefix behavior and why `@schema_prefix` is not the right Phase 75 mechanism.
- `https://hexdocs.pm/ecto_sql/Ecto.Adapters.SQL.Sandbox.html` - SQL Sandbox setup for real DB tests.
- `https://hexdocs.pm/oban/testing.html` - Oban testing and prefix-related testing details.
- `https://hexdocs.pm/oban/Oban.Migration.html` - Oban table prefix is separate from Chimeway storage prefix.
- `https://guides.rubyonrails.org/engines.html` - Engine namespacing lessons.
- `https://laravel.com/docs/notifications` - Notification ergonomics and class-name durable identity footgun.
- `https://laravel.com/docs/packages` - Published package migration lessons.
- `https://symfony.com/doc/current/notifier.html` - Adapter/transport abstraction lessons and DSN footguns.
- `https://github.com/excid3/noticed` - Modular delivery and rename/class-name persistence footgun.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `Chimeway.Storage.repo_opts/1`: Already centralizes validated runtime prefix mapping and preserves explicit caller prefix probes.
- `Chimeway.Repo`: The narrowest target for repo-wide runtime defaults through `default_options/1`.
- `Chimeway.Admin.repo_opts/1` and `Chimeway.Traces` option filtering: Existing pattern for stripping domain/query options before calling Repo. This should be standardized to delegate prefix behavior instead of becoming parallel prefix logic.
- Phase 74 generated migration fixtures and `MigrationContractTest`: Reusable proof that prefixed migrations create the `chimeway` schema through normal generated migrations, not `mix ecto.migrate --prefix`.
- Existing integration tests for trigger, inbox, workflow, digest, webhooks, and recovery: Reusable scenario material for prefixed runtime proof.

### Established Patterns

- Public APIs stay context-oriented and user/JTBD focused; callers should not compose raw Repo operations or storage options.
- Durable IDs, stable `notification_key`, and version remain the persisted identity model. Module/class names are not durable identity.
- Job args carry durable IDs and workers rehydrate from storage; queue payloads are not the source of truth.
- Public legacy mode is explicit with `prefix: false` and must remain green.
- Named verification entrypoints are product surface, but release-gate parity and docs composition are Phase 76 concerns.
- Admin/operator surfaces return redacted DTOs and useful explainability facts, not raw storage internals.

### Integration Points

- `Chimeway.Repo.default_options/1` should delegate to `Chimeway.Storage.repo_opts/1` for normal operations while avoiding invalid transaction-option leakage.
- Trigger fanout must prove `Event` insert, string-source notification `insert_all`, workflow-run inserts, duplicate event lookup, and dispatch planning all use configured storage.
- Inbox lifecycle must prove list/count/update/read/seen/archive and follow-on signal routing use configured storage.
- Trace/admin/recovery reads must keep explicit `prefix:` probes while defaulting to configured storage.
- Workflow, digest, webhook, and dispatch workers must prove reload-by-ID behavior uses configured storage.
- Test setup must isolate prefixed runtime proof from the default public legacy suite.
</code_context>

<specifics>
## Specific Ideas

Recommended implementation sketch:

```elixir
defmodule Chimeway.Repo do
  use Ecto.Repo,
    otp_app: :chimeway,
    adapter: Ecto.Adapters.Postgres

  @impl true
  def default_options(:transaction), do: []
  def default_options(_operation), do: Chimeway.Storage.repo_opts()
end
```

Recommended option-filtering shape:

```elixir
defp repo_opts(opts) do
  opts
  |> Keyword.drop([:limit, :tenant_id, :recipient_id, :older_than, :now])
  |> Chimeway.Storage.repo_opts()
end
```

Recommended prefixed integration suite shape:

```elixir
setup_all do
  original = Application.fetch_env(:chimeway, :prefix)
  Application.put_env(:chimeway, :prefix, "chimeway")

  on_exit(fn -> restore_prefix(original) end)
  :ok
end
```

The suite should assert both positive placement in `chimeway` and absence of accidental public-row reads/writes where practical.

Do not expose "Ecto prefix" in happy-path adopter APIs or operator UI copy. Use user-facing language such as "isolated Chimeway schema" and "public-schema legacy mode"; reserve Ecto terms for maintainer/troubleshooting docs.

UI/UX and graphic design are not directly applicable because Phase 75 is backend runtime plumbing. The relevant design translation is calm, literal, developer-native API/docs microcopy and support-operator trace continuity.
</specifics>

<deferred>
## Deferred Ideas

- Dynamic per-tenant database prefixes remain out of scope for v1.13.
- First-party automated public-to-`chimeway` data move remains deferred.
- Full prefix documentation, manual move guide, demo-host proof, Oban-prefix docs, and release-gate/doc-contract parity belong to Phase 76.
- Broader tenant spine redesign remains deferred beyond this storage-isolation milestone.
</deferred>

---

*Phase: 75-runtime-prefix-propagation*
*Context gathered: 2026-07-01*
