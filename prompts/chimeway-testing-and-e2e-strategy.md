# Chimeway — testing and E2E strategy (shift left)

> **Purpose:** Minimize human UAT by making **CI the default proof** for regressions, docs, and install paths. Aligns with `threadline-elixir-oss-dna.md`, `mailglass` Fake-adapter discipline, and `sigra` installer golden tests.

## Principles

1. **Named entrypoints** — `mix verify.*`, `mix ci.*` aliases documented in CONTRIBUTING; CI calls the same scripts as local (`scripts/ci/*.sh`, `set -euo pipefail`).
2. **Honest default `mix test`** — if heavy suites are excluded, `test_helper.exs` and README say so explicitly (sigra / threadline lesson).
3. **Fake in-memory dispatch** — merge gate for core dispatch, policy, and state transitions without Twilio/APNS (mailglass “Fake as release gate”).
4. **Integration tests** — real Postgres + Ecto Sandbox; tagged `:integration` with dedicated job and service containers when touching DB-heavy paths.
5. **Golden installer** — when `mix chimeway.install` (or equivalent) exists: fresh host app, run installer, normalize migration timestamps, diff tree + stdout to fixture (sigra pattern); idempotent second run test.

## Doc contracts (early)

- README quickstart block parses / compiles or matches public API names.
- NimbleOptions (or chosen config) keys match `guides/` snippets.
- CONTRIBUTING CI table rows match workflow **job `id:`** strings (stable for `act` and grep).

## E2E and browser

- **Defer Playwright** until a mountable admin router exists; then one smoke path: login stub → open trace → assert label (accrue / sigra daily demo patterns as reference).
- **Email in CI:** Swoosh test/local adapters; document Sandbox adapter for cross-process tests where applicable (research brief).

## Nested apps and caching

- Fixture or example host under `test/fixtures/` or `examples/`: **separate** CI cache keys from root `deps/` / `_build/` (threadline / sigra installer lesson).

## Property tests

- Use where invariants matter: idempotency keys, dedupe of deliveries, stable ordering guarantees—not everywhere day one.

## Anti-patterns

- Skipping installer tests when `priv/templates/` changes (path-gate installer job when cost is high).
- Assertions on error **message** strings instead of **`:type`** / struct tags.
