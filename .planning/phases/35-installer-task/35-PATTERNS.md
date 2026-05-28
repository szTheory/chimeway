# Phase 35: Installer Task — Pattern Map

**Mapped:** 2026-05-28  
**Phase:** 35-installer-task  
**Requirements:** INST-01, INST-02  
**Inputs:** `35-CONTEXT.md`, `35-RESEARCH.md`, in-repo Mix tasks, sibling libs (mailglass, sigra)

---

## 1. Pattern Summary Table

| Role | File(s) | Data flow | Closest analog | Key pattern |
|------|---------|-----------|----------------|-------------|
| **CLI entrypoint** | `lib/mix/tasks/chimeway.gen.migrations.ex` | `argv` → `Mix.Task.run("app.config")` → `Chimeway.Install.Migrations.run/1` → stdout / exit | `Mix.Tasks.Mailglass.Gen.Migration` | Thin Mix wrapper; business logic in library module |
| **Core installer** | `lib/chimeway/install/migrations.ex` | `priv/chimeway_migrations/*` → rewrite namespace → `priv/repo/migrations/{ts}_{slug}.exs` | Mailglass idempotent slug match + sigra tree normalization (different delivery model) | Copy templates; slug-based idempotency; batch timestamps |
| **Canonical templates** | `priv/chimeway_migrations/001_…031_*.exs` | Dev repo `priv/repo/migrations/` (minus Oban) → static Hex-shipped templates | `priv/repo/migrations/*.exs` (source) | Order prefix + stable slug; marker comment; `Chimeway.Repo.Migrations.*` in template |
| **Test harness** | `test/support/installer_fixture.ex` | Tmp host scaffold → subprocess `mix chimeway.gen.migrations` → normalize → diff/refresh | `Sigra.Test.InstallFixture`, `Mailglass.Test.InstallerFixtureHelpers` | Ephemeral tmp dir; path dep to in-tree chimeway; timestamp/path normalization |
| **Golden contract** | `test/chimeway/install/golden_diff_test.exs` | First run tree + stdout vs committed fixture | `Sigra.Install.GoldenDiffTest`, `Mailglass.Install.GoldenTest` | Committed `test/fixtures/installer_golden/` tree (sigra), not README embed (mailglass) |
| **Idempotency contract** | `test/chimeway/install/idempotency_test.exs` | Run twice → normalized tree unchanged; second stdout `unchanged` | `Mailglass.Install.IdempotencyTest`, `Sigra.Install.IdempotencyTest` | Snapshot before/after second run; no managed-block drift (Chimeway scope) |
| **Golden fixture** | `test/fixtures/installer_golden/STDOUT.txt`, `tree/priv/repo/migrations/*.exs` | Captured first-run output (31 files) | `sigra/test/fixtures/install_golden/` | `TIMESTAMP` placeholder in filenames; full migration bodies in tree |
| **CI alias** | `mix.exs` → `ci.install_golden` | Single `mix test` invocation for both contract files | `verify.example`, mailglass `verify.installer.golden` | **Not** in default `mix ci`; named entrypoint only |
| **CI path gate** | `.github/workflows/ci.yml` → `install_golden_contract` job | PR diff → conditional job; push to `main` always runs | `sigra/.github/workflows/ci.yml` `install_golden_contract` | No Postgres; no phx_new (unlike sigra) |
| **Docs touch** | `CONTRIBUTING.md` (optional) | Document `mix ci.install_golden` row | Existing CI table in CONTRIBUTING | Job name matches workflow `name:` for grep/act |

### End-to-end data flow

```
priv/repo/migrations/ (dev, 32 files)
        │ extract (exclude Oban)
        ▼
priv/chimeway_migrations/001_{slug}.exs … 031_{slug}.exs   ← shipped in Hex (mix.exs files: ~w(... priv ...))
        │
        │ mix chimeway.gen.migrations  (host app, after app.config)
        ▼
Chimeway.Install.Migrations.run/1
  • resolve host repo (config :chimeway, repo: or mix.exs fallback)
  • for each template: slug match → skip | rewrite namespace → write
        ▼
host/priv/repo/migrations/{14-digit}_{slug}.exs  (31 files)

Contract proof (test env):
  InstallerFixture → tmp host + path dep → subprocess mix task
        → normalize (TIMESTAMP, paths, CRLF)
        → diff vs test/fixtures/installer_golden/
        → second run → zero tree diff + unchanged stdout lines
```

---

## 2. Per-File Analog Mapping

### 2.1 `lib/mix/tasks/chimeway.gen.migrations.ex` — Mix task entrypoint

**Role:** CLI surface documented in `guides/introduction/installation.md` (`mix chimeway.gen.migrations`).  
**Analog:** `Mix.Tasks.Mailglass.Gen.Migration` (idempotent gen task) + Chimeway `Mix.Tasks.Preview.Rendering` (OptionParser / error style).

**Follow mailglass** for idempotent create/unchanged messaging and strict argv parsing:

```15:38:/Users/jon/projects/mailglass/lib/mix/tasks/mailglass.gen.migration.ex
  @impl Mix.Task
  def run(argv) do
    {opts, rest, invalid} = OptionParser.parse(argv, strict: [upgrade: :boolean])

    if rest != [] or invalid != [] do
      Mix.raise("Installation blocked: unexpected args for mailglass.gen.migration")
    end

    _upgrade? = opts[:upgrade] == true

    case existing_wrapper_migration() do
      nil ->
        path = Path.join(["priv", "repo", "migrations", "#{timestamp()}_mailglass_install.exs"])

        File.mkdir_p!(Path.dirname(path))
        File.write!(path, migration_body())

        Mix.shell().info("created #{path}")

      path ->
        Mix.shell().info("unchanged #{path}")
    end

    :ok
  end
```

**Follow Chimeway** for `@shortdoc`, `@moduledoc` usage block, and delegating to library API (research skeleton adds `Mix.Task.run("app.config")` before env read — not in mailglass because it reads `mix.exs` directly):

```19:64:/Users/jon/projects/chimeway/lib/mix/tasks/preview_rendering.ex
  use Mix.Task

  @shortdoc "Preview one channel rendering without dispatching provider traffic"

  @switches [
    notifier: :string,
    ...
  ]

  @impl Mix.Task
  def run(argv) do
    case OptionParser.parse(argv, strict: @switches) do
      ...
          {:error, reason} ->
            Mix.shell().error(format_error(reason))
            exit({:shutdown, 1})
```

**Chimeway-specific deltas:**
- Module: `Mix.Tasks.Chimeway.Gen.Migrations`; file name `chimeway.gen.migrations.ex` (dot-separated, matches `mix chimeway.gen.migrations`).
- Call `Mix.Task.run("app.config")` then `Chimeway.Install.Migrations.run(opts)` — keep Mix task thin (RESEARCH §3 D-01).
- Stdout contract: `created #{path}` on first run, `unchanged #{path}` on re-run (D-08) — same verbs as mailglass.
- Do **not** use `use Boundary` unless other Chimeway Mix tasks adopt it (they do not today).

---

### 2.2 `lib/chimeway/install/migrations.ex` — Core installer logic

**Role:** Template enumeration, repo resolution, namespace rewrite, slug idempotency, timestamp batching, `File.mkdir_p!`.  
**Analog:** Logic currently inline in `Mix.Tasks.Mailglass.Gen.Migration` (single file) — Chimeway extracts to testable module because **31 files** and golden contract need pure-function unit tests.

**Slug detection (primary idempotency)** — from mailglass wildcard + sort + first:

```41:47:/Users/jon/projects/mailglass/lib/mix/tasks/mailglass.gen.migration.ex
  defp existing_wrapper_migration do
    ["priv", "repo", "migrations", "*_mailglass_install.exs"]
    |> Path.join()
    |> Path.wildcard()
    |> Enum.sort()
    |> List.first()
  end
```

Chimeway generalizes to `*_{slug}.exs` per template (D-07).

**Host app module inference** — mailglass reads `mix.exs` when config absent (D-05 Option A fallback):

```72:78:/Users/jon/projects/mailglass/lib/mix/tasks/mailglass.gen.migration.ex
  defp current_app_module do
    mix_exs = File.read!("mix.exs")

    case Regex.run(~r/app:\s*:(\w+)/, mix_exs) do
      [_, app] -> Macro.camelize(app)
      _ -> "Example"
    end
  end
```

**Namespace rewrite** — string replace `Chimeway.Repo.Migrations` → `{HostApp}.Repo.Migrations` (D-06); mailglass builds module at generation time:

```55:69:/Users/jon/projects/mailglass/lib/mix/tasks/mailglass.gen.migration.ex
  defp migration_body do
    app_module = current_app_module()

    """
    defmodule #{app_module}.Repo.Migrations.MailglassInstall do
      use Ecto.Migration
      ...
    """
  end
```

**Timestamp batch** — mailglass single `NaiveDateTime.utc_now()`; Chimeway needs sequential +1s offsets for 31-file ordering (RESEARCH §4):

```49:53:/Users/jon/projects/mailglass/lib/mix/tasks/mailglass.gen.migration.ex
  defp timestamp do
    NaiveDateTime.utc_now()
    |> NaiveDateTime.truncate(:second)
    |> Calendar.strftime("%Y%m%d%H%M%S")
  end
```

**Template source path:** `:code.priv_dir(:chimeway)` + `"chimeway_migrations"` (Hex-shipped via `mix.exs` `files: ~w(... priv ...)`).

**Public API surface for tests:** `list_templates/0`, `run/1`, and pure helpers (`rewrite_namespace/2`, `extract_slug/1`, `find_existing_by_slug/2`) — invoke directly in unit tests; golden tests use subprocess for full Mix path.

---

### 2.3 `priv/chimeway_migrations/001_…031_*.exs` — Canonical templates

**Role:** Static migration bodies copied into host repos; excluded from runtime dev migration path.  
**Analog:** Source = `priv/repo/migrations/*.exs`; delivery model ≠ mailglass single wrapper delegating to `Mailglass.Migration.up/0`.

**Source migration shape** (preserve verbatim body + module name in template):

```1:16:/Users/jon/projects/chimeway/priv/repo/migrations/20260424023200_create_chimeway_events.exs
defmodule Chimeway.Repo.Migrations.CreateChimewayEvents do
  use Ecto.Migration

  def change do
    create table(:chimeway_events, primary_key: false) do
      add :id, :uuid, primary_key: true
      ...
    end

    create unique_index(:chimeway_events, [:idempotency_key], name: :chimeway_events_idempotency_key_index)
  end
end
```

**Template conventions (D-04, D-09, D-10):**
- Filename: `{NNN}_{slug}.exs` where `NNN` is zero-padded order (`001`…`031`).
- First line: `# chimeway_migration: {slug}` marker comment.
- Keep `Chimeway.Repo.Migrations.*` in template; rewrite at copy time only.
- **Exclude** `create_oban_jobs_tables` (Oban wrapper) — 31 templates, not 32.
- Table/index names stay `:chimeway_*` — do not rewrite schema identifiers.

**Hex packaging** — already covered:

```81:86:/Users/jon/projects/chimeway/mix.exs
  defp package do
    [
      files: ~w(lib priv guides CHANGELOG.md LICENSE.md README.md mix.exs .formatter.exs),
      licenses: ["MIT"],
      ...
    ]
  end
```

---

### 2.4 `test/support/installer_fixture.ex` — Scaffold, run, normalize, refresh

**Role:** Build minimal tmp host, run installer via subprocess, normalize output for golden diff, optional `MIX_INSTALLER_ACCEPT_GOLDEN=1` refresh.  
**Analog:** `Sigra.Test.InstallFixture` (subprocess + tree/stdout normalization + committed fixture dir) + `Mailglass.Test.InstallerFixtureHelpers` (tmp root, snapshot, env-gated refresh).

**Tmp host scaffold** — mailglass copies example tree; Chimeway needs **minimal** host (no Phoenix):

```
installer_host_tmp/
  mix.exs          # app: :installer_host, path dep to chimeway
  config/config.exs # config :chimeway, repo: InstallerHost.Repo
  priv/repo/migrations/  # empty
```

**Subprocess runner** — sigra pattern (RESEARCH §7); mailglass calls `Apply.run/2` in-process — Chimeway golden should use subprocess to prove Mix task + `app.config` loading:

```elixir
System.cmd("mix", ["chimeway.gen.migrations"],
  cd: fixture_root,
  stderr_to_stdout: true,
  env: [{"MIX_ENV", "dev"}]
)
```

**Path dep patch** — sigra `patch_mix_exs_with_path_dep!/1` precedent in `Sigra.Test.InstallFixture.setup_tmp_app/1`.

**Normalization helpers** — combine sigra path/content rules with mailglass migration timestamp regex:

Sigra migration filename normalization:

```500:502:/Users/jon/projects/sigra/test/support/install_fixture.ex
  defp normalize_path(rel) do
    rel
    |> String.replace(~r|priv/repo/migrations/\d{14}_|, "priv/repo/migrations/TIMESTAMP_")
```

Mailglass snapshot timestamp normalization:

```101:106:/Users/jon/projects/mailglass/test/support/installer_fixture_helpers.ex
  defp normalize_migration_ts(snapshot) do
    snapshot =
      Regex.replace(~r/\b\d{14}(?=_mailglass_install\.exs)/, snapshot, "<MIGRATION_TS>")

    Regex.replace(~r/(migration_ts = ")\d{14}(")/, snapshot, "\\1<MIGRATION_TS>\\2")
  end
```

Chimeway should normalize **all** `*_create_chimeway_*.exs` slugs: `~r/\b\d{14}(?=_[a-z0-9_]+\.exs)/` → `TIMESTAMP` (RESEARCH §7).

**Golden refresh env gate** — mailglass:

```99:101:/Users/jon/projects/mailglass/test/mailglass/install/install_golden_test.exs
  defp accept_golden_refresh? do
    System.get_env(@accept_golden_env) == "1"
  end
```

Use `MIX_INSTALLER_ACCEPT_GOLDEN=1` with **committed tree fixture** (sigra layout), not README markers (mailglass) — 31 full migration bodies are too large for inline snapshots.

**Module naming:** `Chimeway.Test.InstallerFixture` under `test/support/` (compiled via `elixirc_paths(:test)` in `mix.exs`).

---

### 2.5 `test/chimeway/install/golden_diff_test.exs` — INST-02 golden tree + stdout

**Role:** First run output matches `test/fixtures/installer_golden/`.  
**Analog:** `Sigra.Install.GoldenDiffTest` (primary — tree dir + STDOUT.txt) over mailglass README-embedded snapshots.

**Fixture layout** — sigra:

```15:21:/Users/jon/projects/sigra/test/sigra/install/golden_diff_test.exs
  `test/fixtures/install_golden/`
    ├── STDOUT.txt                        # normalized captured stdout
    └── tree/                             # normalized file tree
        ├── lib/...
        ├── priv/repo/migrations/TIMESTAMP_*.exs
        ├── config/...
        └── test/support/...
```

Chimeway scope is narrower — fixture tree likely **only** `tree/priv/repo/migrations/` (31 files) + `STDOUT.txt`.

**Test tags and async:**

```34:36:/Users/jon/projects/sigra/test/sigra/install/golden_diff_test.exs
  use ExUnit.Case, async: false

  alias Sigra.Test.InstallFixture
```

```50:51:/Users/jon/projects/sigra/test/sigra/install/golden_diff_test.exs
  describe "golden diff" do
    @describetag :integration
```

**Tree equality with actionable diff** — reuse sigra `assert_tree_equal/2` pattern (missing/extra paths + per-file Myers diff).

**Additional Chimeway assertions:**
- Exactly 31 migration files in output.
- No slug `create_oban_jobs_tables` (D-10).
- Generated content must not contain `Chimeway.Repo.Migrations` (D-06).
- Each file contains `# chimeway_migration: {slug}` marker (D-09).

---

### 2.6 `test/chimeway/install/idempotency_test.exs` — INST-02 second-run proof

**Role:** Second `mix chimeway.gen.migrations` produces zero file changes and stable stdout.  
**Analog:** `Mailglass.Install.IdempotencyTest` (simple tree snapshot) — **not** mailglass managed-block drift tests (out of Chimeway scope).

**Core idempotency test** — mailglass:

```9:25:/Users/jon/projects/mailglass/test/mailglass/install/install_idempotency_test.exs
  test "second install run produces no fixture diff" do
    fixture_root = new_fixture_root!("idempotency-no-diff")
    run_install!(fixture_root, [])

    before_second_run =
      fixture_root
      |> snapshot_tree!()
      |> normalize_snapshot()

    run_install!(fixture_root, [])

    after_second_run =
      fixture_root
      |> snapshot_tree!()
      |> normalize_snapshot()

    assert before_second_run == after_second_run
  end
```

**Chimeway-specific assertions (D-08):**
- File count remains 31 after second run.
- Second-run stdout: 31× `unchanged priv/repo/migrations/...` (capture and normalize paths).
- Exit code 0 on both runs.

**Skip** mailglass `managed-snippet drift detection` describe blocks — Chimeway copy-only installer has no managed config blocks (RESEARCH §6).

Sigra idempotency adds mtime checks — optional for Chimeway; normalized tree equality is sufficient for INST-02.

---

### 2.7 `test/fixtures/installer_golden/` — Committed expected output

**Role:** Regression barrier for template + task changes.  
**Analog:** `sigra/test/fixtures/install_golden/` (committed directory tree).

| Path | Content |
|------|---------|
| `STDOUT.txt` | Normalized first-run stdout (`created ...` lines × 31) |
| `tree/priv/repo/migrations/TIMESTAMP_{slug}.exs` | 31 expected files with `InstallerHost.Repo.Migrations.*` modules |

Capture via `MIX_INSTALLER_ACCEPT_GOLDEN=1 mix test test/chimeway/install/golden_diff_test.exs --warnings-as-errors`.

---

### 2.8 `mix.exs` — Add `ci.install_golden` alias

**Role:** Named CI entrypoint; not part of default `mix ci`.  
**Analog:** `verify.example` separation + mailglass scoped test aliases.

**Existing Chimeway pattern** — post-merge verify kept out of `ci`:

```46:78:/Users/jon/projects/chimeway/mix.exs
  defp aliases do
    [
      ci: ["ci.lint", "ci.test"],
      ...
      "verify.example": [
        "cmd cd examples/chimeway_demo_host && mix deps.get && mix test"
      ]
    ]
  end
```

**Add (D-13):**

```elixir
"ci.install_golden": [
  "test test/chimeway/install/golden_diff_test.exs test/chimeway/install/idempotency_test.exs --warnings-as-errors"
]
```

**Critical:** Single alias runs **both** test files in one `mix test` invocation — mailglass documents Mix task deduplication footgun when chaining aliases that each call `mix test`:

```215:219:/Users/jon/projects/mailglass/mix.exs
      # Phase 7: installer — runs the installer and docs test suites in a
      # single `mix test` invocation. Chaining individual aliases would trip
      # Mix's task-deduplication (each `verify.installer.*` calls `mix test`,
      # but `mix test` only runs once per invocation, so a chain would execute
      # only the first file).
```

Do **not** add `ci.install_golden` to default `ci:` list (same rationale as `verify.example` / RESEARCH §8).

---

### 2.9 `.github/workflows/ci.yml` — Path-gated `install_golden_contract` job

**Role:** Run `mix ci.install_golden` when installer surfaces change (PRs); always on push to `main`.  
**Analog:** `sigra/.github/workflows/ci.yml` `install_golden_contract` job.

**Sigra path-gate pattern:**

```73:88:/Users/jon/projects/sigra/.github/workflows/ci.yml
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
          if git diff --name-only "origin/${{ github.base_ref }}...HEAD" | grep -qE '^priv/templates/sigra\.install/|^lib/sigra/install/|...'; then
            echo "run=true" >> "$GITHUB_OUTPUT"
          else
            echo "run=false" >> "$GITHUB_OUTPUT"
          fi
```

**Chimeway grep paths (D-13):**

```regex
^priv/chimeway_migrations/|
^lib/mix/tasks/chimeway\.gen\.migrations\.ex|
^lib/chimeway/install/|
^test/chimeway/install/|
^test/fixtures/installer_golden/|
^test/support/installer_fixture\.ex
```

**Chimeway simplifications vs sigra:**
- No Postgres service (file-generation only — RESEARCH §8).
- No `mix archive.install hex phx_new` (no Phoenix scaffold).
- Reuse existing `actions/checkout`, `setup-beam`, cache patterns from current `ci.yml`:

```13:36:/Users/jon/projects/chimeway/.github/workflows/ci.yml
jobs:
  lint:
    name: Lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5
      - uses: erlef/setup-beam@8251c48667b97e88a0a24ec512f5b72a039fcea7
        ...
      - run: mix ci.lint
```

Job step: `mix ci.install_golden` with `MIX_ENV: test`.

---

### 2.10 `CONTRIBUTING.md` (optional modify)

**Role:** Document `mix ci.install_golden` in CI table (`prompts/chimeway-testing-and-e2e-strategy.md` — named entrypoints).  
**Analog:** CONTRIBUTING CI rows matching workflow job names.

---

## 3. Conventions to Follow

### Mix task structure

| Convention | Source | Apply to Phase 35 |
|------------|--------|-------------------|
| File under `lib/mix/tasks/` with dots → CLI segments | Chimeway existing tasks | `chimeway.gen.migrations.ex` → `mix chimeway.gen.migrations` |
| `@shortdoc` + `@moduledoc` with usage | `preview_rendering.ex` | Document Oban exclusion + link to oban-integration guide |
| `use Mix.Task` + `@impl Mix.Task` | All tasks | Required |
| Strict `OptionParser` — reject unknown args | mailglass | Optional `[force: :boolean]` deferred; reject positional args |
| `Mix.Task.run("app.config")` before `Application.get_env` | RESEARCH D-05 | Load host config for `:repo` |
| Delegate to `Chimeway.Install.Migrations` | RESEARCH D-01 | Enables unit tests without subprocess |
| User-visible lines: `created path` / `unchanged path` | mailglass D-08 | Stable stdout for golden fixture |
| Fail fast with `Mix.raise/1` or `exit({:shutdown, 1})` | Chimeway tasks | Clear message when repo cannot be resolved |

### Test fixture layout

| Convention | Detail |
|------------|--------|
| **Location** | `test/fixtures/installer_golden/` (committed tree + STDOUT) |
| **Harness** | `test/support/installer_fixture.ex` — tmp dir under `System.tmp_dir!()` with unique suffix |
| **Async** | `async: false` on install tests (filesystem side effects) |
| **Tags** | `@moduletag :installer`; optional `@moduletag :integration` |
| **Normalization** | 14-digit migration prefixes → `TIMESTAMP`; tmp paths → `<TMP_PATH>`; `\r\n` → `\n` |
| **Refresh** | `MIX_INSTALLER_ACCEPT_GOLDEN=1` env gate; document in test `@moduledoc` |
| **No DB** | Do not require Postgres for installer contract tests |
| **Subprocess** | Golden test runs full Mix CLI; unit tests call `Chimeway.Install.Migrations` directly |
| **Assertions** | Prefer structural checks (`{:error, :repo_missing}`) over error message strings (engineering DNA) |

### CI path gates

| Convention | Detail |
|------------|--------|
| **Alias name** | `mix ci.install_golden` (matches `ci.test`, `ci.lint` — not `verify.installer.*`) |
| **Default CI** | Excluded from `mix ci` — run on demand / path-gated job |
| **PR behavior** | Job skipped unless diff touches installer paths |
| **Push to main** | Job always runs (`run=true`) |
| **checkout** | `fetch-depth: 0` for PR diff |
| **Dependencies** | `mix deps.get` only — no ecto.create/migrate |
| **Single test invocation** | One alias, both test files — avoid Mix dedup trap |

### Installation guide alignment

Documented task already exists — implementation must match name only (D-14):

```27:31:/Users/jon/projects/chimeway/guides/introduction/installation.md
Generate the migrations:

```bash
mix chimeway.gen.migrations
```
```

**Known ordering tension:** guide runs migrations before `config :chimeway, repo:` (step 2 before step 3). Implement repo fallback from host `mix.exs` `app:` → `{App}.Repo` when config unset (mailglass precedent) — do not fail fresh hosts following current guide order.

---

## 4. Anti-Patterns to Avoid

| Anti-pattern | Why | Do instead |
|--------------|-----|------------|
| **Programmatic `Chimeway.Migration.up/0` API** | Deferred by D-03; larger architectural change | Copy full template bodies from `priv/chimeway_migrations/` |
| **Shipping Oban migration template** | D-10; hosts use Oban's own install path | Exclude `create_oban_jobs_tables`; assert 31 files in tests |
| **Matching idempotency by timestamp prefix** | Host timestamps differ per run | Match by stable slug `*_{slug}.exs` (D-07) |
| **Overwriting existing slug files on re-run** | Host may have edited migrations | Skip with `unchanged`; no `--force` in Phase 35 |
| **Inlining 31-file logic only in Mix task** | Golden + unit tests need direct invocation | `Chimeway.Install.Migrations` module |
| **README-embedded golden snapshots** | 31 full migrations too large | Committed tree under `test/fixtures/installer_golden/` (sigra) |
| **Chaining two `mix test` aliases for golden + idempotency** | Mix deduplicates `test` task | Single `ci.install_golden` alias with both paths |
| **Adding installer tests to default `mix ci`** | Slows every PR; RESEARCH §8 | Path-gated dedicated job |
| **Skipping installer CI when templates change** | `prompts/chimeway-testing-and-e2e-strategy.md` anti-pattern | Path-gate includes `priv/chimeway_migrations/` |
| **Asserting error message strings** | Brittle; engineering DNA | Assert error tags / exit behavior / file counts |
| **Rewriting `:chimeway_*` table names** | Schema identity is library-owned | Only rewrite `Chimeway.Repo.Migrations` module prefix |
| **Requiring Postgres in golden tests** | INST-02 proves file generation, not migrate | No DB service in `install_golden_contract` job |
| **Phoenix scaffold for test host** | Phase 35 is migrations-only | Minimal `mix.exs` + `config/config.exs` tmp host |
| **Mailglass managed-block drift machinery** | Copy-only installer has no config injection | Simple second-run tree diff only |
| **Fixing README semver / guide reorder in Phase 35** | D-14 defers to Phase 36 | Task name match only; repo fallback handles guide order |
| **Using dev repo migrations directly at runtime** | Host must own namespaced files | Templates in `priv/chimeway_migrations/`, not `priv/repo/migrations/` |
| **Module name as durable migration identity** | AGENTS.md — use stable slugs/keys | Filename slug + `# chimeway_migration:` marker |

---

## Canonical Reference Index

| Pattern source | Path |
|----------------|------|
| Chimeway Mix tasks | `lib/mix/tasks/preview_rendering.ex`, `lib/mix/tasks/verify_published.ex` |
| Chimeway CI aliases | `mix.exs` |
| Chimeway CI workflow | `.github/workflows/ci.yml` |
| Mailglass gen migration | `/Users/jon/projects/mailglass/lib/mix/tasks/mailglass.gen.migration.ex` |
| Mailglass golden test | `/Users/jon/projects/mailglass/test/mailglass/install/install_golden_test.exs` |
| Mailglass idempotency | `/Users/jon/projects/mailglass/test/mailglass/install/install_idempotency_test.exs` |
| Mailglass fixture helpers | `/Users/jon/projects/mailglass/test/support/installer_fixture_helpers.ex` |
| Sigra golden diff | `/Users/jon/projects/sigra/test/sigra/install/golden_diff_test.exs` |
| Sigra install fixture | `/Users/jon/projects/sigra/test/support/install_fixture.ex` |
| Sigra CI path gate | `/Users/jon/projects/sigra/.github/workflows/ci.yml` |
| Testing strategy | `prompts/chimeway-testing-and-e2e-strategy.md` |

---

*Phase: 35-installer-task*  
*Pattern mapping completed: 2026-05-28*
