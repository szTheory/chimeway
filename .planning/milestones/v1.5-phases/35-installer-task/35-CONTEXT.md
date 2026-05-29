# Phase 35: Installer Task - Context

**Gathered:** 2026-05-28 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Host developers can bootstrap Chimeway schema via a documented, idempotent Mix task. Delivers INST-01 and INST-02: `mix chimeway.gen.migrations` (or equivalent) copies canonical migration templates into the host repo, and CI verifies idempotent golden-diff behavior. Does not include golden-path doc rewrite, semver alignment, or full install scaffolding (config/supervisor remain manual steps in the installation guide).

</domain>

<decisions>
## Implementation Decisions

### Task name and scope
- **D-01:** Ship `mix chimeway.gen.migrations` as the sole installer entrypoint — module `Mix.Tasks.Chimeway.Gen.Migrations`. Match the task name already documented in `guides/introduction/installation.md`.
- **D-02:** Do not ship `mix chimeway.install` in this phase. Config (`config :chimeway, repo:`) and supervision tree steps stay in the installation guide as manual host steps.

### Migration delivery model
- **D-03:** Use copy-based generation from canonical templates under `priv/chimeway_migrations/` (new directory). Do not refactor to a Mailglass-style `Chimeway.Migration.up/0` programmatic API in this phase — that is a larger architectural change deferred unless a future phase explicitly scopes it.
- **D-04:** Source templates are derived from the 32 existing incremental migrations in `priv/repo/migrations/` (library dev repo), excluding the Oban wrapper migration (`20260424093000_create_oban_jobs_tables.exs`).

### Host repo wiring
- **D-05:** Detect the host Ecto repo from `Application.get_env(:chimeway, :repo)` at task runtime. Fail with a clear error if unset.
- **D-06:** Rewrite migration module namespaces from `Chimeway.Repo.Migrations.*` to `{HostApp}.Repo.Migrations.*` where `{HostApp}` is derived from the configured repo module (e.g., `MyApp.Repo` → `MyApp.Repo.Migrations.CreateChimewayEvents`).

### Idempotency contract
- **D-07:** Re-running the task is a no-op. Match existing generated files by stable migration slug (filename suffix after timestamp, e.g., `create_chimeway_events`), not by timestamp prefix.
- **D-08:** On re-run, print `unchanged <path>` for each already-present migration; create no new files and exit 0.
- **D-09:** Optionally embed a stable marker comment in each template (e.g., `# chimeway_migration: create_chimeway_events`) to support slug detection and future upgrade tooling.

### Oban boundary
- **D-10:** Exclude Oban migrations from the generated bundle. Hosts configure Oban separately via `guides/recipes/oban-integration.md` and Oban's own install/migration path.

### Verification (INST-02)
- **D-11:** Add golden-diff contract test: scaffold a minimal host fixture (tmp dir or `test/fixtures/installer_host/`), run the task, normalize timestamps in output, diff tree against committed fixture.
- **D-12:** Add idempotency contract test: run the task a second time; assert zero new files and stable stdout.
- **D-13:** Expose a named CI entrypoint (e.g., `mix ci.install_golden` alias) that runs installer contract tests; path-gate in GitHub Actions when `priv/chimeway_migrations/` or `lib/mix/tasks/chimeway.gen.migrations.ex` changes.

### Documentation boundary (Phase 35 vs 36)
- **D-14:** Phase 35 ensures the task exists and matches the task name in `guides/introduction/installation.md`. README/install semver alignment (currently `~> 0.1` vs `~> 1.0.0` drift) is deferred to Phase 36 (DOCS-02).

### Claude's Discretion
- Exact timestamp generation strategy (UTC, monotonic ordering across batch)
- Fixture location (`test/fixtures/installer_host/` vs ephemeral tmp scaffold)
- Whether to add `--force` flag for maintainer re-bless workflows
- Golden fixture refresh mechanism (env var gate like mailglass `MIX_INSTALLER_ACCEPT_GOLDEN=1`)
- Minor stdout formatting and progress messaging

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements and scope
- `.planning/ROADMAP.md` — Phase 35 goal, success criteria, INST-01/INST-02 mapping
- `.planning/REQUIREMENTS.md` — INST-01, INST-02 acceptance criteria
- `.planning/PROJECT.md` — Adoption Surface milestone intent, quality bar (`mix verify.*`, `mix ci.*`)
- `.planning/threads/2026-05-28-v1.5-milestone-assessment.md` — Doc drift evidence (task documented but absent)

### Installation and DX
- `guides/introduction/installation.md` — Documented install steps and task name to implement
- `guides/recipes/oban-integration.md` — Oban setup boundary (separate from Chimeway migrations)

### Testing and engineering DNA
- `prompts/chimeway-testing-and-e2e-strategy.md` — Golden installer pattern, idempotent second-run test, path-gated CI
- `prompts/chimeway-engineering-dna-from-prior-libs.md` — sigra golden-diff installer reference, sibling library patterns
- `.planning/METHODOLOGY.md` — Least-Surprise DX Default, One-Shot Recommendation Bias, Research-First Decision Ownership

### Existing Mix task patterns (in-repo)
- `lib/mix/tasks/preview_rendering.ex` — Mix task conventions (OptionParser, exit codes, `@shortdoc`)
- `lib/mix/tasks/verify_published.ex` — Named verify task pattern

### Sibling library reference (external to repo, pattern only)
- `/Users/jon/projects/mailglass/lib/mix/tasks/mailglass.gen.migration.ex` — Idempotent wrapper generation pattern
- `/Users/jon/projects/mailglass/test/mailglass/install/install_golden_test.exs` — Golden snapshot test pattern
- `/Users/jon/projects/sigra/test/sigra/install/golden_diff_test.exs` — sigra installer golden-diff CI pattern (via sigra doc/maintaining.md)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `priv/repo/migrations/*.exs` (32 files): Canonical schema evolution source — extract to `priv/chimeway_migrations/` templates for host copy
- `lib/mix/tasks/preview_rendering.ex`, `lib/mix/tasks/verify_published.ex`: Established Mix task structure, error handling, and `@shortdoc` conventions
- `mix.exs` aliases (`ci`, `ci.test`, `verify.example`): Pattern for adding `ci.install_golden` entrypoint

### Established Patterns
- Mix tasks live under `lib/mix/tasks/` with dot-separated module names mapping to `mix task.name`
- Package ships `priv/` in Hex files list — templates must live under `priv/` to be available to host apps
- Contract tests preferred over string-matching error messages (engineering DNA)
- Idempotency is first-class product behavior across Chimeway (aligns with INST-02)

### Integration Points
- Host `config :chimeway, repo: MyApp.Repo` — repo detection seam for namespace rewriting
- Host `priv/repo/migrations/` — target directory for generated files
- `guides/introduction/installation.md` — must reference the implemented task name (already does)
- Future Phase 41 (GATE-01) doc-contract checks will validate installer task name against repo reality

</code_context>

<specifics>
## Specific Ideas

- Follow sigra/mailglass golden-diff discipline: normalize migration timestamps before diffing; idempotent second run is mandatory CI proof
- User confirmed all assumptions without corrections — copy-based approach over programmatic `Chimeway.Migration` API for this phase

</specifics>

<deferred>
## Deferred Ideas

- **`mix chimeway.install` full scaffold** — config injection, supervisor snippet, optional Oban wiring — out of scope; could be a future DX phase if copy-only migrations prove insufficient
- **`Chimeway.Migration.up/0` programmatic API** — Mailglass-style versioned migrations in library code — better long-term upgrade story but larger refactor than Phase 35 scope
- **README/install semver alignment** — Phase 36 (DOCS-02)
- **Doc-contract gates for installer** — Phase 41 (GATE-01); Phase 35 ships the task and its contract tests, GATE-01 wires release checklist

</deferred>

---

*Phase: 35-installer-task*
*Context gathered: 2026-05-28*
