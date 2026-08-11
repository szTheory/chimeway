# Technology Stack: Chimeway v1.17 Adopter Proof Paths

**Project:** Chimeway
**Researched:** 2026-08-08
**Confidence:** MEDIUM — recommendations are verified against the current repository and official Hex, Phoenix, and GitHub Actions documentation. The exact public-package availability of the Accrue Chimeway engine still needs a release-time check.

## Recommendation

Add a small, committed **clean-room fixture host** plus a root-owned proof runner. Keep it separate from `examples/chimeway_demo_host`: that example intentionally uses `{:chimeway, path: "../.."}` and local package paths, which is right for development but cannot demonstrate what an adopter receives from a release artifact.

The runner should build the root package with `MIX_ENV=prod mix hex.build --unpack --output <temporary-package-root>`, copy a fixture host into a newly created temporary directory, point only that host's `:chimeway` dependency at the unpacked package root, then run `mix deps.get`, `mix compile`, `mix chimeway.gen.migrations`, `mix ecto.migrate`, and scenario-specific ExUnit assertions. This is the smallest reliable pre-publish proof: it exercises the package manifest and file list while keeping the host outside the source tree.

Hex documents `mix hex.build --unpack` specifically for checking a package's unpacked contents; it also documents that non-Hex dependencies are not included in published dependency resolution. An unpacked local package is therefore the correct pre-release artifact boundary. A normal root `path: "../.."` dependency is not.

## Recommended Stack

### Core Fixture and Artifact Tooling

| Technology | Version / constraint | Purpose | Why |
|---|---:|---|---|
| Elixir / Mix | Chimeway floor `~> 1.17`; CI's existing strict toolchain | Build the package and execute fixture proofs | Matches supported adopters and reuses the repository's floor coverage. Do not make the proof require a newer Elixir solely for fixture convenience. |
| Hex | Current version supplied by `mix local.hex --force` | `mix hex.build --unpack` local-release artifact | Validates the exact files and dependency metadata the release would publish, without publishing or using credentials. |
| Minimal Phoenix + Ecto host fixture | Phoenix `~> 1.7`/supported current Phoenix; PostgreSQL | Fresh adopter-shaped host with a repo, application supervision, config, migrations, and tests | Chimeway's documented path is Phoenix/Ecto/Postgres. Retain a tiny API/no-assets host, not a second full demo application. Phoenix supports generating a PostgreSQL project and `--no-assets`/`--no-html` for this purpose. |
| PostgreSQL service | `postgres:15` | Fixture database in CI | Already the project's supported CI database. A separate fresh database per fixture invocation proves migration/install behavior without sharing the root test schema. |
| ExUnit | built in | Assert durable outcomes | Directly asserts the promised adopter outcomes: trigger + `explain_delivery/1`; Mailglass attempt/render result; Accrue campaign start and invoice-paid termination. Avoid browser, sleep, or provider-network tests. |
| Bash root proof runner | POSIX shell; no new package | Assemble temp directories, inject local artifact dependency, run commands | Existing aliases and CI already use shell orchestration. A short checked-in script is more transparent than adding a task-runner dependency. It must use `mktemp -d`, have a cleanup trap, and print retained path on failure. |

### Partner Dependencies

| Library | Constraint | Use in fixture | Boundary |
|---|---:|---|---|
| `mailglass` | `~> 1.3` | Installed from Hex in the Mailglass scenario; host owns the mailable mapping | This is a true package consumer path. Use its non-network/local delivery setup already demonstrated by the repository; do not add a real provider SDK or credentials. |
| `accrue` | Production constraint documented as `~> 1.3`; integration ref pinned in CI | Billing-event scenario | Treat this separately from Chimeway's local artifact. The current `verify.accrue` uses a pinned external checkout because its integration module is conditionally compiled. A package-only fixture is credible only after verifying that the selected Accrue package release exports `Accrue.Integrations.Chimeway`. |
| `oban` | existing compatible `~> 2.x` | Add only if the tested Chimeway application path starts workers | Keep the fixture aligned with the documented optional worker surface. Do not introduce Oban Pro, queues, or separate worker infrastructure merely to make the proof look production-like. |

## Fixture Topology

```
root source
  └─ mix hex.build --unpack ──> temporary/chimeway-<version>/  (artifact boundary)

committed fixtures/adopter_proof_host/ ──copy──> temporary/host/
  ├─ core:      {:chimeway, path: temporary/chimeway-<version>}
  ├─ mailglass: same Chimeway artifact + {:mailglass, "~> 1.3"}
  └─ accrue:    same Chimeway artifact + selected Accrue package/ref
                              │
                              └─ PostgreSQL 15 service, unique database/schema
```

Use one fixture application with three tagged test files or three explicit scenario commands, not three generated Phoenix applications. The host must contain only the configuration and notifier/mailable/billing scaffolding needed for the tracer bullets. It should not mount `chimeway_admin`, build assets, run a web server, or use the repository's demo-host seed suite.

The fixture's `mix.exs` should accept only an explicit `CHIMEWAY_PACKAGE_PATH` supplied by the runner and fail if it is missing. This makes accidental fallback to the checked-out root impossible. The runner should also assert that the resolved `:chimeway` dependency path is under its temporary unpacked directory, and that no fixture dependency path resolves beneath the Chimeway checkout.

## CI Integration

| Capability | Recommendation | Integration point |
|---|---|---|
| Local command | Add `mix verify.adopter_proofs` delegating to the root runner | Parallel to existing named `verify.*` aliases; documentation uses exactly this command. |
| CI lane | One `verify_adopter_proofs` Ubuntu job with `postgres:15`, health checks, `DATABASE_URL`, `mix local.hex`, `mix local.rebar`, and the strict `.tool-versions` setup | Mirror `verify_mailglass` / `verify_accrue`, but run the artifact producer before entering the fixture. Gate on push/main first; include in PR gate only if the project explicitly accepts its dependency-install cost. |
| Scenario separation | Run core and Mailglass from Hex in the normal job; run Accrue as a distinct named scenario/sub-step | Its extra compatibility boundary must be visible in logs and cannot make the core installation proof look source-coupled. |
| Diagnostics | On failure, upload the unpacked package file list, fixture `mix.lock`, `mix deps.tree`, migration output, and scenario log as one failure-only artifact | GitHub Actions artifacts are meant to persist/share test output. Do not upload databases, secrets, or telemetry payloads. |
| Cache | Cache only downloaded Hex deps for the runner/fixture keyed by fixture `mix.exs`/`mix.lock`, BEAM versions, and scenario | Never cache the generated package directory, fixture `_build`, or copied host directory; those are the clean-room boundary. |
| Contract protection | Extend existing doc/release contract tests to require every canonical guide command to map to `verify.adopter_proofs` and a CI job | Prevents the new front-door guidance from drifting back to source-only `verify.example`/`verify.accrue` commands. |

## Alternatives Considered

| Category | Recommended | Alternative | Why not |
|---|---|---|---|
| Pre-release package proof | `mix hex.build --unpack` then external copied host | Host path dependency to repository root | It bypasses package contents and can pass when generated migrations/guides/priv files are absent from the release. |
| Fresh-host construction | Commit one small, reviewable Phoenix/Ecto fixture | Run `mix phx.new` during every CI job | Generator output/version drift turns the proof into a Phoenix-installer test and makes failures less attributable. Use generated-host creation only for a periodic compatibility smoke if later justified. |
| Core/Mailglass proof | Unpacked Chimeway artifact + Hex Mailglass | Full demo host | The demo host also links local Chimeway admin/inbox code and has broader UI/journey obligations outside this milestone. |
| Accrue proof today | Explicit external compatibility fixture at the pinned ref, labelled as such | Claim current path-checkout test is a package-only adopter proof | The current root and demo-host flows set `ACCRUE_PATH`; that is useful integration evidence but not a clean packaged proof. |
| Accrue proof when released | Resolve `{:accrue, "~> 1.3"}` from Hex and assert the engine module is present | Add a local registry, package mirror, or publish prereleases | New distribution infrastructure is disproportionate. The release check supplies the needed artifact boundary. |
| Orchestration | Existing Mix aliases + one shell runner | New CI/test orchestration framework or Docker Compose | Adds another runtime and obscures the copyable Mix commands adopters need. GitHub Actions service containers already cover Postgres. |

## Compatibility Risks and Required Guards

1. **Chimeway package vs source tree:** Hex excludes non-Hex dependencies from published resolution. Build under the same release environment used for package creation, and assert the unpacked fixture's `mix deps.tree` has no root path dependency.
2. **Phoenix version drift:** the existing demo host declares Phoenix `~> 1.7` while current Phoenix documentation is 1.8. Pin the fixture to the project's documented supported Phoenix band; do not silently upgrade the fixture as part of the proof milestone. Add a later compatibility matrix only after a supported-version policy exists.
3. **Accrue's conditional integration module:** package-only proof is blocked unless the exact Hex release exposes `Accrue.Integrations.Chimeway`. Until verified, retain the pinned-ref compatibility scenario and state its source boundary in both logs and docs. Do not use an unpinned branch checkout.
4. **Dependency resolver conflicts:** the current demo host pins `decimal ~> 2.0` and `ecto_sql ~> 3.13.0` for the Accrue checkout. Keep those constraints scoped to the Accrue scenario; do not leak overrides into the core/Mailglass fixture where they could hide normal Hex resolution issues.
5. **False clean-room cache hits:** copied fixture directories must start without `deps`, `_build`, or `mix.lock` unless the fixture intentionally commits a lockfile. The runner must not reuse root `_build` or demo-host caches.
6. **Unexplainable async flakes:** the tracer bullets should assert persisted terminal/transition states deterministically, using test configuration or existing synchronous seams. Do not poll provider callbacks or sleep for workers.

## What Not to Add

- Do not add a second web UI, Playwright/browser lane, inbox live badges, or UI assets.
- Do not publish to Hex or require a Hex API key during CI.
- Do not add Docker Compose, Testcontainers, a local Hex registry, or a general-purpose task runner.
- Do not make external email provider calls, webhook credentials, or real billing accounts part of the proof.
- Do not replace existing broad `verify.example`, `verify.mailglass`, or `verify.accrue` lanes; the new lane complements them by proving the artifact boundary.

## Installation / Runner Shape

```bash
# root-owned, local and CI entry point (illustrative command sequence)
mix hex.build --unpack --output "$proof_tmp/chimeway-package"
cp -R fixtures/adopter_proof_host "$proof_tmp/host"
cd "$proof_tmp/host"
CHIMEWAY_PACKAGE_PATH="$proof_tmp/chimeway-package" mix deps.get
CHIMEWAY_PACKAGE_PATH="$proof_tmp/chimeway-package" mix ecto.create
CHIMEWAY_PACKAGE_PATH="$proof_tmp/chimeway-package" mix ecto.migrate
CHIMEWAY_PACKAGE_PATH="$proof_tmp/chimeway-package" mix test test/core_proof_test.exs
```

The implementation may use a copied fixture `mix.exs` template or a narrowly scoped config import, but the generated host dependency must always resolve to the unpacked directory and never to `../..`.

## Sources

- [Hex: `mix hex.build`](https://hex.hexdocs.pm/Mix.Tasks.Hex.Build.html) — `--unpack` package-content verification and non-Hex dependency behavior (MEDIUM, official).
- [Hex: `mix hex.publish`](https://hex.hexdocs.pm/Mix.Tasks.Hex.Publish.html) — package dependency resolution limits for non-Hex dependencies (MEDIUM, official).
- [Phoenix: `mix phx.new`](https://phoenix.hexdocs.pm/Mix.Tasks.Phx.New.html) — generated project, PostgreSQL, and no-assets/no-html options (MEDIUM, official).
- [Phoenix installation](https://phoenix.hexdocs.pm/installation.html) — Phoenix/Elixir compatibility baseline (MEDIUM, official).
- [GitHub Actions: PostgreSQL service containers](https://docs.github.com/en/actions/tutorials/use-containerized-services/create-postgresql-service-containers) — Linux runner, health checks, and host access (MEDIUM, official).
- [GitHub Actions: workflow artifacts](https://docs.github.com/en/actions/concepts/workflows-and-actions/workflow-artifacts) — failure diagnostics retention (MEDIUM, official).
- Repository evidence: `mix.exs`, `examples/chimeway_demo_host/mix.exs`, `.github/workflows/ci.yml`, and the three canonical adopter guides (HIGH for current project state).
