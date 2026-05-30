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

Run all eight before opening or merging release-related changes:

```bash
mix ci
mix ci.docs
mix ci.verify_gates
mix verify.example
mix verify.journeys
mix verify.mailglass
mix verify.accrue
mix verify.inbox
```

- `mix ci` — lint + full test suite
- `mix ci.docs` — HexDocs build with warnings-as-errors
- `mix ci.verify_gates` — adoption-surface doc-contract and release gate parity (GATE-01 + GATE-06)
- `mix verify.example` — demo host webhook E2E + chimeway_admin operator smoke
- `mix verify.journeys` — TeamPulse consumer journey proof (JOUR-01..08, GATE-03) — 10 tests including READ read-cancel Sync + Oban due-worker paths and time-fallback (JOUR-06), Sam suppression admin (JOUR-07), Morgan escalation admin (JOUR-08)
- `mix verify.mailglass` — Mailglass integration gate (GATE-04): root adapter contract, webhook pipeline, executor routing, and demo host DEMO-06 delivery proof
- `mix verify.accrue` — Accrue dunning integration gate (GATE-05 Accrue): ECOS-06 lifecycle tests and DEMO-07 demo host proof; requires sibling Accrue checkout — set `ACCRUE_PATH=../accrue/accrue` locally or let CI job check out szTheory/accrue
- `mix verify.inbox` — Inbox integration gate (GATE-05 Inbox): chimeway_inbox package tests and DEMO-08 demo host :inbox proof; in-repo path deps only — no sibling checkout

All eight must pass before publishing.

These eight local commands map to ci-gate lanes plus publish replay — not eight identical CI job names.

#### Accrue sibling checkout

Maintainers clone [szTheory/accrue](https://github.com/szTheory/accrue) adjacent to chimeway (convention: `../accrue/accrue` from repo root). CI pins ref `236fa2f1649e771f3b515603495436badeed3c7b` (`accrue-v1.3.0`) — update when bumping the integration.

### Installer template changes

When modifying any of these paths, also run `mix ci.install_golden` locally before merging:

- `priv/chimeway_migrations/`
- `lib/mix/tasks/chimeway.gen.migrations.ex`
- `lib/chimeway/install/`
- `test/chimeway/install/`
- `test/fixtures/installer_golden/`

CI runs `install_golden_contract` on every push to `main` and on PRs that touch installer surfaces (path-gated). Do not change that gating behavior.

### Bootstrap note

First automated release after Hex **1.0.0** targets **1.1.0**. Push all unpushed `main` commits before the first Release Please run so the bootstrap PR includes v1.5–v1.9 surface.

## Refreshing GitHub Actions SHAs

When updating dependencies, also refresh the SHA-pinned actions in `.github/workflows/`:

```bash
gh api /repos/actions/checkout/git/ref/tags/v4 --jq '.object.sha'
gh api /repos/erlef/setup-beam/git/ref/tags/v1 --jq '.object.sha'
gh api /repos/actions/cache/git/ref/tags/v4 --jq '.object.sha'
```

Update each `uses:` reference in `ci.yml` and `release.yml` with the new SHAs.
