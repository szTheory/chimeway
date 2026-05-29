# Maintaining Chimeway

This document is for maintainers cutting releases.

## Release Runbook

Follow these steps in order for every release:

### 1. Bump version

Edit `mix.exs` and update `@version "X.Y.Z"` to the new version.

### 2. Update CHANGELOG.md

Move items from `## [Unreleased]` to a new dated header:

```
## [X.Y.Z] - YYYY-MM-DD
```

### 3. Run the full local gate

Run all pre-ship verification commands before tagging or publishing:

```bash
mix ci
mix ci.docs
mix ci.verify_gates
mix verify.example
mix verify.journeys
```

- `mix ci` — lint + full test suite
- `mix ci.docs` — HexDocs build with warnings-as-errors
- `mix ci.verify_gates` — adoption-surface doc-contract and version-alignment gates (GATE-01)
- `mix verify.example` — demo host webhook E2E + chimeway_admin operator smoke
- `mix verify.journeys` — TeamPulse consumer journey proof (JOUR-01..08, GATE-03) — 10 tests including READ read-cancel Sync + Oban due-worker paths and time-fallback (JOUR-06), Sam suppression admin (JOUR-07), Morgan escalation admin (JOUR-08)

All five must pass before publishing.

### Installer template changes

When modifying any of these paths, also run `mix ci.install_golden` locally before merging:

- `priv/chimeway_migrations/`
- `lib/mix/tasks/chimeway.gen.migrations.ex`
- `lib/chimeway/install/`
- `test/chimeway/install/`
- `test/fixtures/installer_golden/`

CI runs `install_golden_contract` on every push to `main` and on PRs that touch installer surfaces (path-gated). Do not change that gating behavior.

### 4. Commit the release

```bash
git add mix.exs CHANGELOG.md
git commit -m "chore: release vX.Y.Z"
```

### 5. Tag the release

```bash
git tag vX.Y.Z
git push origin main --tags
```

### 6. Publish to Hex

```bash
mix hex.publish
```

Follow the prompts. Confirm the package name and version are correct before confirming.

### 7. Verify the release (required)

Run the verify trio after publishing:

```bash
mix verify.clean
mix verify.parity
mix verify.published X.Y.Z
```

- `verify.clean` — confirms no uncommitted files remain after publish prep
- `verify.parity` — confirms the published file list matches the `files:` whitelist in `mix.exs`
- `verify.published X.Y.Z` — polls hex.pm to confirm the version is accessible

All three must pass before announcing the release.

### 8. Create GitHub Release

Go to the GitHub releases page, create a release from the tag `vX.Y.Z`, and paste the relevant CHANGELOG section as the release notes.

## Refreshing GitHub Actions SHAs

When updating dependencies, also refresh the SHA-pinned actions in `.github/workflows/`:

```bash
gh api /repos/actions/checkout/git/ref/tags/v4 --jq '.object.sha'
gh api /repos/erlef/setup-beam/git/ref/tags/v1 --jq '.object.sha'
gh api /repos/actions/cache/git/ref/tags/v4 --jq '.object.sha'
```

Update each `uses:` reference in `ci.yml` and `docs.yml` with the new SHAs.
