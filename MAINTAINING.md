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

```bash
mix ci
```

All lint and test steps must pass before publishing.

### 4. Run the docs gate

```bash
mix ci.docs
```

Docs must build without warnings-as-errors failures.

### 5. Commit the release

```bash
git add mix.exs CHANGELOG.md
git commit -m "chore: release vX.Y.Z"
```

### 6. Tag the release

```bash
git tag vX.Y.Z
git push origin main --tags
```

### 7. Publish to Hex

```bash
mix hex.publish
```

Follow the prompts. Confirm the package name and version are correct before confirming.

### 8. Verify the release (required)

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

### 9. Create GitHub Release

Go to the GitHub releases page, create a release from the tag `vX.Y.Z`, and paste the relevant CHANGELOG section as the release notes.

## Refreshing GitHub Actions SHAs

When updating dependencies, also refresh the SHA-pinned actions in `.github/workflows/`:

```bash
gh api /repos/actions/checkout/git/ref/tags/v4 --jq '.object.sha'
gh api /repos/erlef/setup-beam/git/ref/tags/v1 --jq '.object.sha'
gh api /repos/actions/cache/git/ref/tags/v4 --jq '.object.sha'
```

Update each `uses:` reference in `ci.yml` and `docs.yml` with the new SHAs.
