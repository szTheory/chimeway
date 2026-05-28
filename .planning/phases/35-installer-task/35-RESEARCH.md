# Phase 35: Installer Task — Research

**Researched:** 2026-05-28  
**Phase:** 35-installer-task  
**Requirements:** INST-01, INST-02  
**Status:** Ready for plan-phase

---

## 1. Executive Summary

Phase 35 closes the largest v1.5 adoption gap: **`mix chimeway.gen.migrations` is documented in `guides/introduction/installation.md` but does not exist**. The implementation is a **copy-based installer** — not a Mailglass-style programmatic `Chimeway.Migration.up/0` API — that ships **31 canonical migration templates** under `priv/chimeway_migrations/`, copies them into the host's `priv/repo/migrations/` with **namespace rewriting** and **fresh timestamps**, and is **idempotent by stable slug** (filename suffix after the timestamp).

Proof of INST-02 is a **golden-diff + idempotency contract test suite** exposed as `mix ci.install_golden`, path-gated in GitHub Actions when installer surfaces change. This is deliberately narrower than sigra's full `mix sigra.install` (no Phoenix scaffolding, no config injection, no supervisor wiring) and closer to mailglass's idempotent generation discipline — but copying **full migration bodies** rather than a single wrapper file.

**Primary planning risks to resolve before execution:**

1. **Installation guide step order vs D-05:** The guide runs `mix chimeway.gen.migrations` *before* `config :chimeway, repo: MyApp.Repo`, but D-05 requires repo detection from that config key. Plan must pick: fallback repo inference (mailglass `mix.exs` app → `MyApp.Repo`), minimal step reorder in installation.md, or a `--repo` CLI override.
2. **Template drift maintenance:** 31 templates must stay in sync with `priv/repo/migrations/` as schema evolves. Plan should define a refresh procedure (maintainer script or documented diff workflow).
3. **Large golden fixture:** 31 migration files make the committed fixture sizable; normalization and refresh ergonomics (`MIX_INSTALLER_ACCEPT_GOLDEN=1`) are essential.

---

## 2. Current State Analysis

### What exists

| Asset | Location | Relevance |
|-------|----------|-----------|
| Documented task name | `guides/introduction/installation.md:30` | `mix chimeway.gen.migrations` — must match exactly (D-01, D-14) |
| Canonical schema migrations | `priv/repo/migrations/*.exs` (32 files) | Source of truth for template extraction |
| Mix task conventions | `lib/mix/tasks/preview_rendering.ex`, `verify_published.ex` | `@shortdoc`, `Mix.Task`, `exit({:shutdown, 1})`, clear usage errors |
| CI aliases | `mix.exs` — `ci`, `ci.test`, `verify.example` | Pattern for adding `ci.install_golden` |
| Hex packaging | `mix.exs` `files: ~w(lib priv guides ...)` | `priv/chimeway_migrations/` ships automatically |
| Oban boundary docs | `guides/recipes/oban-integration.md` | Hosts install Oban separately (D-10) |
| Assessment evidence | `.planning/threads/2026-05-28-v1.5-milestone-assessment.md` | Doc references task that doesn't exist |

### What's missing

| Gap | Requirement |
|-----|-------------|
| `Mix.Tasks.Chimeway.Gen.Migrations` task module | INST-01 |
| `priv/chimeway_migrations/` template directory (31 files) | INST-01 |
| Core installer logic (template enumeration, rewrite, idempotency) | INST-01, INST-02 |
| Golden-diff contract test + committed fixture | INST-02 |
| Idempotent second-run contract test | INST-02 |
| `mix ci.install_golden` alias + path-gated CI job | INST-02, D-13 |

### Runtime repo config note (out of Phase 35 scope but affects host DX)

Chimeway runtime currently hardcodes `Chimeway.Repo` in `lib/chimeway/application.ex` and domain modules. The installation guide's `config :chimeway, repo: MyApp.Repo` is aspirational for host ownership — **Phase 35 only generates host-namespaced migration files**. Wiring runtime queries to the host repo is not in scope; do not conflate migration namespace rewriting with runtime repo delegation.

---

## 3. Technical Approach Recommendations (D-01 through D-14)

### D-01 — Task name and module

- **CLI:** `mix chimeway.gen.migrations`
- **File:** `lib/mix/tasks/chimeway.gen.migrations.ex`
- **Module:** `Mix.Tasks.Chimeway.Gen.Migrations`
- **Pattern:** Match mailglass `mailglass.gen.migration.ex` file naming (`lib/mix/tasks/mailglass.gen.migration.ex` → `Mix.Tasks.Mailglass.Gen.Migration`)

Suggested skeleton:

```elixir
defmodule Mix.Tasks.Chimeway.Gen.Migrations do
  use Mix.Task

  @shortdoc "Copy Chimeway migration templates into the host priv/repo/migrations"

  @impl Mix.Task
  def run(argv) do
    Mix.Task.run("app.config")

    {opts, rest, invalid} = OptionParser.parse(argv, strict: [force: :boolean])

    if rest != [] or invalid != [] do
      Mix.raise("Unexpected arguments. Usage: mix chimeway.gen.migrations [--force]")
    end

    case Chimeway.Install.Migrations.run(opts) do
      :ok -> :ok
      {:error, reason} -> Mix.raise(format_error(reason))
    end
  end
end
```

Keep business logic in **`Chimeway.Install.Migrations`** (new module under `lib/chimeway/install/migrations.ex`) so contract tests can invoke it without subprocess overhead, while golden tests still exercise the full Mix path.

### D-02 — No `mix chimeway.install`

Do not inject config blocks, supervisor children, or router mounts. Installation guide steps 3–4 remain manual until a future DX phase.

### D-03 — Copy-based delivery from `priv/chimeway_migrations/`

Templates are static `.exs` files shipped in Hex. At generation time the task:

1. Reads templates in deterministic order
2. Rewrites module namespace
3. Optionally injects marker comment
4. Writes to host `priv/repo/migrations/{timestamp}_{slug}.exs`

Do **not** introduce `Chimeway.Migration.up/0` in this phase.

### D-04 — Extract 31 migrations, exclude Oban

**Exclude:** `20260424093000_create_oban_jobs_tables.exs` (`Oban.Migrations.up/0` wrapper — D-10).

**Include:** All other 31 files from `priv/repo/migrations/` (see §4 for ordered slug list).

Template filenames should encode order independently of original timestamps:

```
priv/chimeway_migrations/
  001_create_chimeway_events.exs
  002_create_chimeway_notifications.exs
  ...
  031_create_chimeway_webhook_ingress.exs
```

Original `Chimeway.Repo.Migrations.*` module names stay in templates; rewriting happens at copy time.

### D-05 — Host repo detection

**Decision requirement:** Resolve guide ordering conflict (see §9).

Recommended implementation once resolved:

```elixir
defp host_repo! do
  case Application.get_env(:chimeway, :repo) do
    repo when is_atom(repo) -> repo
    nil -> Mix.raise(repo_missing_message())
  end
end

defp host_migrations_prefix(repo) do
  # MyApp.Repo -> "MyApp.Repo.Migrations"
  [app_prefix, "Repo", "Migrations"]
  |> Module.concat()
  where app_prefix = repo |> Module.split() |> Enum.drop(-1) |> Module.concat()
end
```

**Mix task must call `Mix.Task.run("app.config")`** before reading application env so host `config/config.exs` is loaded.

**Planning options for the ordering conflict:**

| Option | Pros | Cons |
|--------|------|------|
| A. Fallback: derive `{App}.Repo` from host `mix.exs` `app:` atom when `:repo` unset | Works with current guide order; mailglass precedent | Slightly diverges from strict D-05 wording |
| B. Reorder installation.md steps 2↔3 (minimal edit) | Strict D-05 compliance | D-14 defers doc work to Phase 36 — needs explicit exception |
| C. Add `--repo MyApp.Repo` switch | Explicit, testable | Extra CLI surface; guide must document flag |

**Recommendation:** Option A with clear error when both config and mix.exs inference fail. Update D-05 interpretation in PLAN.md to "resolve repo from `config :chimeway, repo:` or host app convention."

### D-06 — Namespace rewriting

Replace in file body:

```elixir
# Template:
defmodule Chimeway.Repo.Migrations.CreateChimewayEvents do

# Generated for MyApp.Repo:
defmodule MyApp.Repo.Migrations.CreateChimewayEvents do
```

Implementation:

```elixir
defp rewrite_namespace(content, host_prefix) do
  String.replace(content, "Chimeway.Repo.Migrations", host_prefix)
end
```

Where `host_prefix = Module.concat(host_migrations_prefix(repo))` as string (not atom) for `String.replace/3`.

**Do not** rewrite table names (`:chimeway_events`, etc.) — schema tables remain Chimeway-prefixed by design.

### D-07–D-09 — Idempotency contract

**Slug definition:** Filename suffix after the 14-digit timestamp and underscore.

```
20260424023200_create_chimeway_events.exs  →  slug: create_chimeway_events
```

**Detection:** Glob host `priv/repo/migrations/*_{slug}.exs`. If any match, treat as present.

**Re-run behavior (D-08):**

```
unchanged priv/repo/migrations/20260424023200_create_chimeway_events.exs
```

One line per existing migration; **no new files**; exit 0.

**Marker comment (D-09, optional but recommended):**

```elixir
# chimeway_migration: create_chimeway_events
```

Insert as first line of template (and thus generated file). Enables:

- Slug extraction fallback if filename pattern breaks
- Future upgrade tooling (Phase 36+ / programmatic migration API)

Idempotency matching should prefer filename slug; marker is secondary validation in tests.

### D-10 — Oban exclusion

Do not ship `create_oban_jobs_tables` template. Document in task `@moduledoc` pointing to `guides/recipes/oban-integration.md`. Golden fixture must contain exactly 31 files, never 32.

### D-11–D-13 — Verification and CI

See §§7–8.

### D-14 — Documentation boundary

Phase 35 ensures task exists and name matches installation.md. **Do not** fix README semver drift (`~> 0.1` vs `~> 1.0.0`) — Phase 36 (DOCS-02).

---

## 4. Migration Template Extraction Strategy

### Source inventory

32 files in `priv/repo/migrations/`; **31 templates** after excluding Oban.

| # | Slug | Source file |
|---|------|-------------|
| 1 | `create_chimeway_events` | `20260424023200_create_chimeway_events.exs` |
| 2 | `create_chimeway_notifications` | `20260424023201_create_chimeway_notifications.exs` |
| 3 | `create_chimeway_deliveries` | `20260424082833_create_chimeway_deliveries.exs` |
| 4 | `create_chimeway_delivery_attempts` | `20260424082834_create_chimeway_delivery_attempts.exs` |
| 5 | `create_chimeway_notification_preferences` | `20260424091726_create_chimeway_notification_preferences.exs` |
| 6 | `add_correlation_id_to_chimeway_events` | `20260424093908_add_correlation_id_to_chimeway_events.exs` |
| 7 | `create_chimeway_category_preferences` | `20260425000100_create_chimeway_category_preferences.exs` |
| 8 | `create_chimeway_policy_settings` | `20260425000200_create_chimeway_policy_settings.exs` |
| 9 | `add_attempt_history_columns` | `20260426150000_add_attempt_history_columns.exs` |
| 10 | `add_delivery_orchestration_fields_to_chimeway_deliveries` | `20260428093000_add_delivery_orchestration_fields_to_chimeway_deliveries.exs` |
| 11 | `add_time_zone_to_chimeway_policy_settings` | `20260428093100_add_time_zone_to_chimeway_policy_settings.exs` |
| 12 | `create_chimeway_digest_rules` | `20260428102000_create_chimeway_digest_rules.exs` |
| 13 | `create_chimeway_digest_buckets` | `20260428102100_create_chimeway_digest_buckets.exs` |
| 14 | `create_chimeway_digest_memberships` | `20260428102200_create_chimeway_digest_memberships.exs` |
| 15 | `alter_chimeway_digest_buckets_for_emission` | `20260428110000_alter_chimeway_digest_buckets_for_emission.exs` |
| 16 | `alter_chimeway_digest_memberships_for_resolution` | `20260428110100_alter_chimeway_digest_memberships_for_resolution.exs` |
| 17 | `alter_chimeway_deliveries_for_digest_outcome` | `20260428110200_alter_chimeway_deliveries_for_digest_outcome.exs` |
| 18 | `add_rendering_contract_fields` | `20260428123000_add_rendering_contract_fields.exs` |
| 19 | `add_render_channels_to_chimeway_notifications` | `20260428201500_add_render_channels_to_chimeway_notifications.exs` |
| 20 | `add_orchestration_snapshot_to_chimeway_notifications` | `20260428230000_add_orchestration_snapshot_to_chimeway_notifications.exs` |
| 21 | `create_chimeway_workflow_definitions` | `20260429160000_create_chimeway_workflow_definitions.exs` |
| 22 | `create_chimeway_workflow_steps` | `20260429160100_create_chimeway_workflow_steps.exs` |
| 23 | `add_workflow_definition_id_to_chimeway_notifications` | `20260429170000_add_workflow_definition_id_to_chimeway_notifications.exs` |
| 24 | `create_chimeway_workflow_runs` | `20260429170100_create_chimeway_workflow_runs.exs` |
| 25 | `create_chimeway_workflow_transitions` | `20260429170200_create_chimeway_workflow_transitions.exs` |
| 26 | `alter_chimeway_deliveries_for_workflow_linkage` | `20260429170300_alter_chimeway_deliveries_for_workflow_linkage.exs` |
| 27 | `create_chimeway_signals_and_spine` | `20260430013208_create_chimeway_signals_and_spine.exs` |
| 28 | `add_adapter_module_to_chimeway_delivery_attempts` | `20260430120000_add_adapter_module_to_chimeway_delivery_attempts.exs` |
| 29 | `add_provider_message_id_to_delivery_attempts` | `20260501145014_add_provider_message_id_to_delivery_attempts.exs` |
| 30 | `add_tenant_and_actor_to_chimeway_deliveries` | `20260501164021_add_tenant_and_actor_to_chimeway_deliveries.exs` |
| 31 | `create_chimeway_webhook_ingress` | `20260502120000_create_chimeway_webhook_ingress.exs` |

**Excluded:** `20260424093000_create_oban_jobs_tables.exs`

### Extraction procedure (maintainer one-shot + ongoing)

1. **Initial extract:** Copy each source migration body verbatim into `priv/chimeway_migrations/{NNN}_{slug}.exs`.
2. **Add marker:** Prepend `# chimeway_migration: {slug}\n` to each template.
3. **Preserve `Chimeway.Repo.Migrations.*` module names** in templates (rewrite at generation).
4. **Do not** include timestamp prefixes in template filenames beyond the order prefix (`001_`, `002_`, …).
5. **Ongoing sync:** When library dev migrations change, update corresponding template and refresh golden fixture. Consider a future maintainer alias `mix chimeway.sync.migration_templates` (optional; not required for Phase 35 MVP if documented manual procedure suffices).

### Ordering guarantee

Ecto runs migrations by timestamp prefix. Generated batch must preserve relative order:

```elixir
defp timestamp_for_index(base_ts, index) do
  base =
    base_ts
    |> NaiveDateTime.add(index, :second)
    |> NaiveDateTime.truncate(:second)

  Calendar.strftime(base, "%Y%m%d%H%M%S")
end

defp batch_base_timestamp do
  NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
end
```

Using sequential +1 second offsets from a single UTC base preserves FK dependency order across the 31-file batch. Alternative: preserve original inter-migration gaps from source timestamps (more complex, not necessary).

---

## 5. Namespace Rewriting Approach

### Algorithm

```
INPUT:  template_content, host_repo (atom)
OUTPUT: generated_content, slug, target_path

1. host_prefix = Module.concat(host_migrations_prefix(host_repo))  # "MyApp.Repo.Migrations"
2. content = String.replace(template, "Chimeway.Repo.Migrations", host_prefix)
3. slug = extract_slug_from_template_filename(template_path)
4. ts = next_timestamp(index)
5. path = "priv/repo/migrations/#{ts}_#{slug}.exs"
```

### Module name derivation examples

| Host repo | Generated module |
|-----------|------------------|
| `MyApp.Repo` | `MyApp.Repo.Migrations.CreateChimewayEvents` |
| `InstallerHost.Repo` | `InstallerHost.Repo.Migrations.CreateChimewayEvents` |
| `DemoHost.Repo` | `DemoHost.Repo.Migrations.CreateChimewayEvents` |

### Validation checks (unit-testable)

- Generated content must not contain `Chimeway.Repo.Migrations`
- Generated content must contain `{host_prefix}.{MigrationName}`
- `use Ecto.Migration` preserved
- Table/index names unchanged (`:chimeway_events`, etc.)

---

## 6. Idempotency Implementation

### Slug matching (primary)

```elixir
defp find_existing_by_slug(slug) do
  "priv/repo/migrations/*_#{slug}.exs"
  |> Path.wildcard()
  |> Enum.sort()
  |> List.first()
end
```

If found → print `unchanged #{path}`, skip write.

### Marker comments (secondary, D-09)

Templates include:

```elixir
# chimeway_migration: create_chimeway_events
```

Contract test can assert every generated file contains its marker. Future upgrade path can scan by marker if host renamed files (edge case — out of scope for MVP).

### `--force` flag (Claude discretion)

**Defer unless golden refresh needs it.** Mailglass uses `--force` for managed-block repair; Chimeway copy-only installer has no managed blocks. Golden refresh should use `MIX_INSTALLER_ACCEPT_GOLDEN=1` env gate (mailglass pattern), not `--force`.

If added later: `--force` would overwrite content of matched slug files (dangerous for hosts who edited migrations) — avoid in Phase 35.

### Idempotency test assertions (INST-02)

1. Run task twice in same fixture root
2. Assert file count unchanged (31 files)
3. Assert normalized tree snapshot identical before/after second run (mailglass `install_idempotency_test.exs` pattern)
4. Assert second-run stdout contains 31× `unchanged` lines (or `unchanged` count == existing migration count)
5. Assert exit code 0 both runs

---

## 7. Golden-Diff Test Architecture

### Recommended layout (sigra-inspired, Chimeway-scoped)

```
test/fixtures/installer_golden/
  STDOUT.txt                          # normalized first-run stdout
  tree/
    priv/repo/migrations/
      TIMESTAMP_create_chimeway_events.exs
      TIMESTAMP_create_chimeway_notifications.exs
      ... (31 files)
```

Use committed fixture tree (not mailglass README-embedded snapshots) because 31 full migration bodies are too large for inline markers.

### Test modules

| File | Purpose |
|------|---------|
| `test/chimeway/install/golden_diff_test.exs` | First run output matches fixture (tree + stdout) |
| `test/chimeway/install/idempotency_test.exs` | Second run produces zero diff |
| `test/support/installer_fixture.ex` | Scaffold host, run task, normalize, refresh helper |

### Host fixture scaffold (minimal)

Ephemeral tmp dir per test (mailglass pattern) seeded with:

```
installer_host_tmp/
  mix.exs                    # app: :installer_host, path dep to chimeway
  config/config.exs          # config :chimeway, repo: InstallerHost.Repo
  lib/installer_host/repo.ex # optional stub — migrations don't compile-run in golden test
  priv/repo/migrations/      # empty
```

**No Postgres required** for golden/idempotency tests — they verify file generation only, not `mix ecto.migrate`.

### Running the task in tests

**Subprocess (recommended for golden):**

```elixir
System.cmd("mix", ["chimeway.gen.migrations"],
  cd: fixture_root,
  stderr_to_stdout: true,
  env: [{"MIX_ENV", "dev"}]
)
```

Fixture `mix.exs` must include:

```elixir
{:chimeway, path: Path.expand("../../..", __DIR__)}
```

### Timestamp normalization

Replace 14-digit migration timestamp prefixes before diff:

```elixir
def normalize_migration_ts(text) do
  Regex.replace(~r/\b\d{14}(?=_[a-z0-9_]+\.exs)/, text, "TIMESTAMP")
end
```

Also normalize:
- Absolute tmp paths → `<TMP_PATH>`
- CRLF → LF

Sigra reference: `Sigra.Test.InstallFixture.normalize_path_for_golden/1`, `normalize_tree/2`.

### Golden refresh mechanism

```bash
MIX_INSTALLER_ACCEPT_GOLDEN=1 mix test test/chimeway/install/golden_diff_test.exs --warnings-as-errors
```

When env var set, test writes updated `test/fixtures/installer_golden/` instead of failing. Document in test moduledoc and MAINTAINING.md (Phase 35 or 36).

### `@moduletag` suggestions

```elixir
@moduletag :installer
@moduletag :integration  # optional — no DB, but cross-process
```

Keep `async: false` (filesystem side effects).

---

## 8. CI Integration

### mix.exs alias (D-13)

```elixir
"ci.install_golden": [
  "test test/chimeway/install/golden_diff_test.exs test/chimeway/install/idempotency_test.exs --warnings-as-errors"
]
```

Mailglass precedent: `"verify.installer.golden"` runs a scoped test path. Chimeway CONTEXT specifies `ci.install_golden` — use that name for consistency with `ci.test`, `ci.lint`.

**Do not** add to default `mix ci` initially — keeps fast feedback on core 549 tests (same rationale as `verify.example` separation in Phase 33).

### GitHub Actions path gate

Add job to `.github/workflows/ci.yml`:

```yaml
install_golden_contract:
  name: Installer golden + idempotency contract
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@...
      with:
        fetch-depth: 0
    - name: Detect installer-related changes (PRs only)
      id: detect
      shell: bash
      run: |
        set -euo pipefail
        if [ "${{ github.event_name }}" != "pull_request" ]; then
          echo "run=true" >> "$GITHUB_OUTPUT"
          exit 0
        fi
        git fetch origin "${{ github.base_ref }}" --depth=1
        if git diff --name-only "origin/${{ github.base_ref }}...HEAD" | grep -qE '^priv/chimeway_migrations/|^lib/mix/tasks/chimeway\.gen\.migrations\.ex|^lib/chimeway/install/|^test/chimeway/install/|^test/fixtures/installer_golden/|^test/support/installer_fixture\.ex'; then
          echo "run=true" >> "$GITHUB_OUTPUT"
        else
          echo "run=false" >> "$GITHUB_OUTPUT"
        fi
    - uses: erlef/setup-beam@...
      if: steps.detect.outputs.run == 'true'
    - run: mix deps.get
      if: steps.detect.outputs.run == 'true'
    - run: mix ci.install_golden
      if: steps.detect.outputs.run == 'true'
      env:
        MIX_ENV: test
```

**No Postgres service** needed (unlike main `ci.test` job). **No `phx_new` archive** needed (unlike sigra).

Push to `main` runs job unconditionally (`run=true`); PRs path-gated per D-13.

### CONTRIBUTING.md update (minimal)

Add row to CI table: `mix ci.install_golden` — installer template + idempotency contract.

---

## 9. Risks and Edge Cases

| Risk | Impact | Mitigation |
|------|--------|------------|
| Guide runs task before `:repo` config | Task fails on fresh host | Fallback repo inference or step reorder (§3 D-05) |
| Template drift from dev migrations | Hosts get stale schema | Document sync procedure; golden test fails on template change |
| Host already has partial Chimeway migrations | Slug match skips missing ones | Idempotent: only generates missing slugs; document manual cleanup if half-installed |
| Host edited generated migration, re-runs task | Unchanged (good) | By design — no overwrite without `--force` |
| Duplicate slugs from manual copies | Multiple `*_create_chimeway_events.exs` | Match first sorted; document; optional warning if count > 1 |
| Non-standard repo module name (`MyApp.Repo` vs `MyApp.Repo.Postgres`) | Wrong namespace | Require standard `{App}.Repo` convention; validate via `String.ends_with?(Atom.to_string(repo), ".Repo")` |
| Windows line endings | Golden diff flakiness | Normalize `\r\n` → `\n` in test helpers |
| Large 31-file golden PR noise | Review burden | Order templates logically; single commit for initial fixture |
| Timestamp collision if host has migrations at same second | Ecto ordering ambiguity | Use +1 second index offset; unlikely collision with 31-file batch |
| Hex package missing templates | Task fails at runtime | Contract test + `mix verify.parity` already checks `priv/` in files list |

### Edge case: missing `priv/repo/migrations/`

Task should `File.mkdir_p!("priv/repo/migrations")` before writing.

### Edge case: chimeway not in deps

Mix task won't exist — outside Phase 35 scope (host must `mix deps.get` first per guide).

---

## 10. Validation Architecture

*Nyquist sampling strategy for plan-phase verification loop.*

### What contract tests prove

| Contract | Test | Proves |
|----------|------|--------|
| INST-01 generation | `golden_diff_test.exs` — tree diff | 31 files emitted with correct content (namespace, markers, schema ops) |
| INST-01 stdout | `golden_diff_test.exs` — STDOUT.txt | User-visible progress messages stable (`created` lines on first run) |
| INST-02 idempotency | `idempotency_test.exs` | Second run: zero new files, identical normalized tree, `unchanged` stdout |
| D-10 Oban boundary | Golden fixture file count + slug set assertion | Exactly 31 slugs; no `create_oban_jobs_tables` |
| D-06 namespace | Golden content inspection | No `Chimeway.Repo.Migrations` in output |
| D-05 repo detection | Fixture with `config :chimeway, repo:` | Generates `InstallerHost.Repo.Migrations.*` |
| Hex ship | Manual / `mix hex.build --unpack` | `priv/chimeway_migrations/` present in tarball |

### Sampling strategy

**No statistical sampling** — installer output is finite and safety-critical:

- **Full enumeration:** All 31 slugs must appear in golden fixture
- **Full content diff:** Every migration file byte-compared after normalization
- **Full stdout diff:** Complete first-run output compared
- **Idempotency:** Whole-tree hash before/after second run

Supplementary unit tests (fast, no subprocess):

- `Chimeway.Install.Migrations.list_templates/0` returns 31 ordered entries
- `extract_slug/1`, `rewrite_namespace/2`, `find_existing_by_slug/2` pure functions
- Error when repo unset (if no fallback)

### Verification commands

```bash
# Primary Phase 35 gate
mix ci.install_golden

# Full library gate (should remain green; installer tests excluded from default ci.test unless added)
mix ci

# Refresh golden after intentional template change
MIX_INSTALLER_ACCEPT_GOLDEN=1 mix test test/chimeway/install/golden_diff_test.exs --warnings-as-errors

# Confirm templates ship on Hex
mix hex.build --unpack --output /tmp/chimeway_verify
ls /tmp/chimeway_verify/priv/chimeway_migrations/ | wc -l  # expect 31

# Manual smoke in tmp host (developer ad-hoc)
cd /tmp && mix new chimeway_install_smoke && cd chimeway_install_smoke
# add path dep + config :chimeway, repo: ChimewayInstallSmoke.Repo
mix chimeway.gen.migrations
ls priv/repo/migrations | wc -l  # expect 31
mix chimeway.gen.migrations      # expect unchanged lines only
```

### Nyquist "human UAT" deferral

No manual host UAT required if golden + idempotency + path-gated CI pass. Phase 36 golden-path guide will add end-to-end `mix ecto.migrate` proof on a Phoenix host.

---

## 11. File Inventory

### Files to create

| Path | Purpose |
|------|---------|
| `lib/mix/tasks/chimeway.gen.migrations.ex` | Mix task entrypoint (D-01) |
| `lib/chimeway/install/migrations.ex` | Core installer logic |
| `priv/chimeway_migrations/001_*.exs` … `031_*.exs` | 31 canonical templates (D-04) |
| `test/support/installer_fixture.ex` | Scaffold, run, normalize, golden refresh |
| `test/chimeway/install/golden_diff_test.exs` | INST-02 golden tree + stdout |
| `test/chimeway/install/idempotency_test.exs` | INST-02 second-run proof |
| `test/fixtures/installer_golden/STDOUT.txt` | Committed normalized stdout |
| `test/fixtures/installer_golden/tree/priv/repo/migrations/*.exs` | 31 committed expected files |

### Files to modify

| Path | Change |
|------|--------|
| `mix.exs` | Add `ci.install_golden` alias |
| `.github/workflows/ci.yml` | Add `install_golden_contract` job with path gate |
| `CONTRIBUTING.md` | Document `mix ci.install_golden` (optional but aligned with AGENTS.md) |

### Files explicitly not modified (Phase 35 boundary)

| Path | Reason |
|------|--------|
| `guides/introduction/installation.md` | Task name already correct; semver/step reorder → Phase 36 |
| `README.md` | DOCS-02 |
| `lib/chimeway/application.ex` | Runtime repo wiring out of scope |
| `priv/repo/migrations/*` | Dev repo migrations stay source; templates are copy |

---

## 12. Implementation Sequence Recommendation

Execute in this order to keep verification green at each step:

1. **Extract templates** — Create `priv/chimeway_migrations/` with 31 ordered files + marker comments. Verify manually: count = 31, Oban excluded.

2. **Core module** — Implement `Chimeway.Install.Migrations` with:
   - `list_templates/0`
   - `run/1` (or `generate/2`)
   - `rewrite_namespace/2`, `find_existing_by_slug/2`, timestamp batch logic
   - Unit tests for pure functions

3. **Mix task** — Thin wrapper `Mix.Tasks.Chimeway.Gen.Migrations` calling core module; resolve repo detection (including ordering conflict decision).

4. **Test support** — `Chimeway.Test.InstallerFixture` (or `Chimeway.Test.InstallerFixture`) with tmp host scaffold, subprocess runner, normalizers.

5. **Capture golden fixture** — Run task once against fixture host; commit `test/fixtures/installer_golden/` with `MIX_INSTALLER_ACCEPT_GOLDEN=1`.

6. **Contract tests** — `golden_diff_test.exs` + `idempotency_test.exs`; confirm `mix ci.install_golden` green.

7. **CI wiring** — Add alias + path-gated GitHub Actions job.

8. **Parity check** — `mix hex.build --unpack` confirms templates in package; `mix ci` still green.

### Suggested commit granularity (for execute-phase)

1. `feat: add chimeway migration templates (31 files, exclude Oban)`
2. `feat: add mix chimeway.gen.migrations installer task`
3. `test: add installer golden-diff and idempotency contracts`
4. `chore: wire ci.install_golden alias and path-gated CI job`

---

## Canonical References

- `.planning/phases/35-installer-task/35-CONTEXT.md` — D-01 through D-14 decisions
- `.planning/REQUIREMENTS.md` — INST-01, INST-02
- `guides/introduction/installation.md` — documented task name
- `prompts/chimeway-testing-and-e2e-strategy.md` — golden installer pattern
- `/Users/jon/projects/mailglass/lib/mix/tasks/mailglass.gen.migration.ex` — idempotent generation
- `/Users/jon/projects/mailglass/test/mailglass/install/install_golden_test.exs` — golden snapshot
- `/Users/jon/projects/mailglass/test/mailglass/install/install_idempotency_test.exs` — second-run proof
- `/Users/jon/projects/sigra/test/sigra/install/golden_diff_test.exs` — tree + stdout fixture layout

---

*Phase: 35-installer-task*  
*Research completed: 2026-05-28*
