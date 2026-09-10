# Contributing to Chimeway

Thank you for your interest in contributing! Here's how to get started.

## Development Setup

1. Clone the repository and install dependencies:
   ```bash
   git clone https://github.com/szTheory/chimeway.git
   cd chimeway
   mix deps.get
   ```

2. Set up the database:
   ```bash
   mix ecto.setup
   ```

3. Run the full quality gate:
   ```bash
   mix ci
   ```

## Running Tests

```bash
mix ci.test
# or
mix test
```

## Code Quality

Before submitting a PR, run:

```bash
mix ci
```

This runs `mix ci.lint` (format check + compile + credo strict) followed by `mix ci.test`.

## CI Entrypoints

| Command | Purpose |
|---------|---------|
| `mix ci` | Default pre-merge gate (lint + test) |
| `mix ci.install_golden` | Installer golden-diff + idempotency contract (path-gated in CI) |

## What runs on your PR

On a pull request the required status check is the fast **`pr-gate`** aggregate. It fans in a
small subset of lanes — lint, the full test suite, the ordinary release contracts
(`mix ci.verify_contracts`), the independently bounded packaged-Accrue contract
(`mix ci.verify_accrue_package`), and the HexDocs build (`mix ci.docs`). The canonical
`mix ci.verify_gates` command runs both contract aliases for local and release parity. A green
local `mix ci` plus `mix ci.docs` and `mix ci.verify_gates` is therefore a good predictor of a
green `pr-gate`; the aggregate always reports a conclusion so required checks never strand.

The full **`ci-gate`** aggregate (all lanes, including the ecosystem-integration gates for Accrue,
Threadline, Sigra, Mailglass, Inbox, and the installer golden contract) runs on push-to-`main` and on
release dispatch — not on every PR. `ci-gate` is the release/publish source of truth; `pr-gate` is
your fast contributor feedback loop.

To reproduce the more complex CI fragments locally, run the committed helpers in `scripts/ci/`:

| Script | Reproduces |
|--------|------------|
| `scripts/ci/detect-installer-changes.sh` | The installer-change git-diff detection that path-gates the installer golden lane |
| `scripts/ci/aggregate-gate.sh` | The required-lane pass/fail loop shared by `pr-gate` and `ci-gate` |
| `scripts/ci/sigra-proof.sh` | The root + demo-host Sigra auth proof lanes (needs a sibling Sigra checkout via `SIGRA_PATH`) |

## Pull Request Convention

PR titles must use a semantic commit prefix:

- `feat:` — new feature
- `fix:` — bug fix
- `docs:` — documentation only
- `chore:` — maintenance, deps, tooling
- `refactor:` — code change with no feature/fix
- `test:` — test additions or fixes

Example: `feat: add Slack adapter`

## Architecture

See the [Getting Started guide](guides/introduction/getting-started.md) and [Trigger to Delivery flow](guides/flows/trigger-to-delivery.md) for architecture context.
