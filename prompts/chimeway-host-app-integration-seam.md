# Chimeway — host application integration seam

> **Purpose:** Boundaries so Chimeway stays **embedded** and **composable**: the host owns auth, tenancy, and URLs; the library owns notification lifecycle and storage conventions. Pattern analogue: `rulestead-host-app-integration-seam.md` / lockspire host seam docs — **notification** domain only.

## Host owns

- **Authentication and authorization** for admin UI and any mutating APIs.
- **Repo and prefix** (if using multiple prefixes or dynamic repos): pass explicit `Ecto.Repo` and optional schema prefix into context functions or config.
- **URL generation** — `Endpoint` config, static vs dynamic host; Chimeway surfaces **missing config** as structured errors in dev/test.
- **Actor and correlation** — assign `current_user`, request id, and Oban args from Plug / Phoenix / Bandit; document one blessed way to copy into delivery metadata (no PII in telemetry).

## Chimeway owns

- **Migrations** for its tables (namespaced `chimeway_*` or configurable prefix).
- **Dispatch and adapter contracts** — behaviours for channels; default Oban workers living under `Chimeway.Workers` (names TBD).
- **Stable `notification_key` contract** between code and persisted rows.

## Multi-tenancy

Prefer a **`Chimeway.Tenancy`** behaviour (mailglass / rulestead pattern): default single-tenant no-op; optional callback that scopes queries and enforces tenant id on writes. Never query tenant tables without scope in library code — enforce with Credo check when stable.

## Plug / Phoenix integration

- Optional **`Plug`** that attaches correlation ids or actor to process dictionary **only if** documented and test-friendly.
- **LiveView** admin: mount under host router scope; host supplies `live_session` auth.

## Upgrade and rollback

- Migrations versioned; breaking schema changes tied to major bumps and changelog entries.
- Document how to **disable** dispatch (feature flag or kill switch) without losing read access to historical deliveries.

## Testing the seam

- Example host under `examples/` or `test/fixtures/` proves wiring; CI runs the same `mix verify.example` (or equivalent) as documented.
