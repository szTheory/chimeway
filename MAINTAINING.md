# Maintaining Chimeway

This document is for maintainers cutting releases.

## Release Runbook

### Default path (automated)

Release Please owns version and changelog SSOT on `main`. Do **not** manually edit `@version` or move CHANGELOG sections on `main` for routine releases.

1. **Merge conventional commits to `main`** — Release Please opens or updates a Release PR titled `chore(main): release X.Y.Z` on branch `release-please--branches--main`.
2. **Confirm ci-gate green on the Release PR head SHA** — Actions → CI workflow → verify the `ci-gate` job succeeded on the PR head commit.
3. **Automerge (Wave 2+)** — When ci-gate is green, `release-pr-automerge.yml` merges the Release PR automatically. For the bootstrap **1.1.0** release (first after Hex 1.0.0), manual merge is acceptable until automerge is proven.
4. **On merge** — `release.yml` creates the GitHub Release + `v*` tag, runs `gate-ci-green` on the release SHA, then `publish-hex` publishes to Hex with `HEX_API_KEY`.
5. **Post-publish verify trio (required locally):**

```bash
mix verify.clean
mix verify.parity
mix verify.published X.Y.Z
```

- `verify.clean` — confirms no uncommitted files remain after publish prep
- `verify.parity` — confirms the published file list matches the `files:` whitelist in `mix.exs`
- `verify.published X.Y.Z` — polls hex.pm to confirm the version is accessible

All three must pass before announcing the release.

### Recovery path (exception)

Use only when automation failed **after** ci-gate was green on the target SHA:

1. GitHub Actions → **Publish Hex Recovery** (`publish-hex.yml`)
2. Dispatch with `tag` (git tag or 40-char SHA) and `release_version` (expected `@version` string)
3. Optional `dry_run: true` to validate without publishing

Do **not** run `mix hex.publish` on a maintainer laptop as the default publish step.

### Secrets

| Secret | Required | Purpose |
|--------|----------|---------|
| `HEX_API_KEY` | Yes | Hex publish in `release.yml` and recovery workflow |
| `RELEASE_PLEASE_TOKEN` | Optional | Fine-grained PAT if Release PR native CI is flaky; `release.yml` falls back to `GITHUB_TOKEN` |

### Pre-ship local commands

Run all twelve before opening or merging release-related changes:

```bash
mix ci
mix ci.docs
mix ci.verify_gates
mix verify.admin
mix verify.example
mix verify.runtime_prefix
mix verify.journeys
mix verify.mailglass
mix verify.accrue
mix verify.inbox
mix verify.threadline
mix verify.sigra
```

- `mix ci` — lint + full test suite
- `mix ci.docs` — HexDocs build with warnings-as-errors
- `mix ci.verify_gates` — adoption-surface doc-contract and release gate parity (GATE-01 + GATE-06)
- `mix verify.admin` — admin integration gate for GATE-08 and SMOKE-01 covering root admin read-model tests, full chimeway_admin package tests, demo-host mounted admin coverage, and Playwright Chromium smoke against /admin/chimeway
- `mix verify.example` — demo host webhook E2E + chimeway_admin operator smoke
- `mix verify.runtime_prefix` — storage-prefix runtime gate (GATE-01): configured-schema runtime behavior and public-schema legacy compatibility through the focused repo/runtime prefix suites
- `mix verify.journeys` — TeamPulse consumer journey proof (JOUR-01..08, GATE-03) — 10 tests including READ read-cancel Sync + Oban due-worker paths and time-fallback (JOUR-06), Sam suppression admin (JOUR-07), Morgan escalation admin (JOUR-08)
- `mix verify.mailglass` — Mailglass integration gate (GATE-04): root adapter contract, webhook pipeline, executor routing, and demo host DEMO-06 delivery proof
- `mix verify.accrue` — Accrue dunning integration gate (GATE-05 Accrue): ECOS-06 lifecycle tests and DEMO-07 demo host proof; requires sibling Accrue checkout — set `ACCRUE_PATH=../accrue/accrue` locally or let CI job check out szTheory/accrue
- `mix verify.inbox` — Inbox integration gate (GATE-05 Inbox): chimeway_inbox package tests and DEMO-08 demo host :inbox proof; in-repo path deps only — no sibling checkout
- `mix verify.threadline` — Threadline telemetry integration gate (GATE-07): Threadline reporter lifecycle proof and demo host audit correlation; requires sibling Threadline checkout — set `THREADLINE_PATH=../threadline/threadline` locally or let CI job check out szTheory/threadline
- `mix verify.sigra` — Sigra auth integration gate (GATE-07): Sigra auth notification lifecycle proof and demo host auth flow; requires sibling Sigra checkout — set `SIGRA_PATH=../sigra/sigra` locally or let CI job check out szTheory/sigra

All twelve must pass before publishing.

These twelve local commands map to ci-gate lanes plus publish replay — not twelve identical CI job names.

#### Sibling repo checkouts

Maintainers clone the integration sibling repos adjacent to chimeway and point the matching `*_PATH` env var at each before running its verify gate:

- [szTheory/accrue](https://github.com/szTheory/accrue) — convention `../accrue/accrue` from repo root (`ACCRUE_PATH`). CI pins ref `236fa2f1649e771f3b515603495436badeed3c7b` (`accrue-v1.3.0`).
- [szTheory/threadline](https://github.com/szTheory/threadline) — convention `../threadline/threadline` from repo root (`THREADLINE_PATH`). CI pins ref `46375fafc4df30fc916244ee4a21b7cae01f1ddc`.
- [szTheory/sigra](https://github.com/szTheory/sigra) — convention `../sigra/sigra` from repo root (`SIGRA_PATH`). CI pins ref `62ceb46a38c4e617f6c06d874ecb12e1ab19d97c`.

Update the pinned refs when bumping an integration.

### Installer template changes

When modifying any of these paths, also run `mix verify.install_golden` locally before merging. `mix ci.install_golden` delegates to the same proof for CI parity.

- `priv/chimeway_migrations/`
- `lib/mix/tasks/chimeway.gen.migrations.ex`
- `lib/chimeway/install/`
- `test/chimeway/install/`
- `test/chimeway/migration_contract_test.exs`
- `test/fixtures/installer_golden_prefixed/`
- `test/fixtures/installer_golden_public/`

The installer proof covers committed golden fixtures, second-run idempotency, static prefix qualification, and database execution/rollback for generated prefixed and public migrations. It requires a reachable PostgreSQL test database; CI provisions PostgreSQL 15 for the path-gated `install_golden_contract` job.

CI runs `install_golden_contract` on push to `main` and on `workflow_dispatch` only — it is event-guarded off `pull_request` under the two-aggregate topology (see "CI gate topology" below), so it does not run on ordinary PRs. Within those events the detect step keeps the proof path-gated: it diffs the installer surfaces listed above and only runs the full proof when one changed, otherwise reporting `success` so the `ci-gate` fold stays pending-safe. `scripts/ci/detect-installer-changes.sh` reproduces that detection locally.

### Bootstrap note

First automated release after Hex **1.0.0** targets **1.1.0**. Push all unpushed `main` commits before the first Release Please run so the bootstrap PR includes v1.5–v1.9 surface.

## CI gate topology (pr-gate / ci-gate)

Chimeway's CI fans into two aggregate checks:

- **`pr-gate`** — the fast required check on contributor pull requests. It aggregates a fast subset (`lint`, `test`, `mix ci.verify_gates`, `mix ci.docs`), always reports a conclusion, mirrors what local `mix ci` covers, and carries no `paths:` filter so it never strands a required PR check.
- **`ci-gate`** — the source of truth for **release, publish, automerge, and recovery**. It aggregates all lanes (the ecosystem-integration gates and `install_golden_contract` included) and runs on push-to-`main` plus `workflow_dispatch` only; release PRs receive it via dispatch. It is event-guarded off `pull_request`, so it does not run on ordinary PRs.

Complex CI behavior is reproducible locally via the committed helpers in `scripts/ci/` — `detect-installer-changes.sh` (installer path-gating), `aggregate-gate.sh` (the required-lane pass/fail loop shared by both gates), and `sigra-proof.sh` (the root + demo-host Sigra proof lanes).

### Operator action: swap the PR required check (`ci-gate` → `pr-gate`)

**This is a GitHub repository settings change — code cannot enforce branch protection, so it must be performed by an operator.** When the two-aggregate topology lands, update branch protection for `main`:

1. GitHub → repo **Settings → Branches → the branch protection rule for `main`**.
2. Under **Require status checks to pass before merging**, REMOVE `ci-gate` from the required checks and ADD `pr-gate`.

**Hazard (pending trap):** because `ci-gate` is now skipped on `pull_request` events, if branch protection still requires `ci-gate` every PR strands in "Expected — Waiting for status to be reported" and can never merge. This swap **must** accompany the topology change. Release/publish/automerge/recovery flows are unaffected — they poll `ci-gate` on push/dispatch, not as a PR required check.

## Refreshing GitHub Actions SHAs

When updating dependencies, also refresh the SHA-pinned actions in `.github/workflows/`:

```bash
gh api /repos/actions/checkout/git/ref/tags/v4 --jq '.object.sha'
gh api /repos/erlef/setup-beam/git/ref/tags/v1 --jq '.object.sha'
gh api /repos/actions/cache/git/ref/tags/v4 --jq '.object.sha'
```

Update each `uses:` reference in `ci.yml` and `release.yml` with the new SHAs.
