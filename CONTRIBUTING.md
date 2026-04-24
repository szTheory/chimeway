# Contributing to Chimeway

Thank you for your interest in contributing! Here's how to get started.

## Development Setup

1. Clone the repository and install dependencies:
   ```bash
   git clone https://github.com/jonlunsford/chimeway.git
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
