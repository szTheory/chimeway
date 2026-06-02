# Sigra Auth Integration

This guide is the canonical adoption path for composing Chimeway with [Sigra](https://github.com/szTheory/sigra) authentication notifications — the end-to-end path from dependency to verification for magic link and confirmation code auth flows. For the focused copy-paste notifier and seam recipe, see the [Sigra auth blueprint](../recipes/sigra-auth-blueprint.md); this guide owns the full integration path while the blueprint owns the recipe.

## Responsibility split (SEED-003)

**Chimeway orchestrates the when and why:** durable notification lifecycle, suppression and preference gates, idempotency, and operator traces you can search at `/admin/chimeway`.

**Sigra owns auth state:** token generation, hashed persistence, rate limits, and magic link / confirmation code TTL. Sigra emits auth events; Chimeway does not mutate Sigra records.

This integration is **not** a `Chimeway.Adapter` delivery seam — it is a Sigra auth event → `Chimeway.trigger/3` bridge only.

## 1. Dependencies

Add Chimeway and Sigra to your host `mix.exs`:

```elixir
def deps do
  [
    {:chimeway, "~> 1.0"},
    sigra_dep()
  ]
end

defp sigra_dep do
  case System.get_env("SIGRA_PATH") do
    nil -> {:sigra, "~> 0.3", optional: true}
    path -> {:sigra, path: path, runtime: false}
  end
end
```

For local development and integration proof, check out the Sigra repo as a sibling and point `SIGRA_PATH` at it:

```bash
SIGRA_PATH=../sigra mix deps.get
```

Production adopters use `{:sigra, "~> 0.3", optional: true}` from Hex. Local proof and CI use a sibling checkout pinned to the integration ref documented in `MAINTAINING.md`.

## 2. Integration seam

`Sigra.Integrations.Chimeway` is the cross-repo seam: it lives in the Sigra package, is conditionally compiled when Chimeway is loaded, and bridges Sigra auth events into the Chimeway trigger spine. Hosts activate it through runtime config — no host callback glue is required:

```elixir
config :sigra,
  chimeway: [enabled: true]
```

Chimeway orchestrates the when and why of each auth notification: durable attempts, suppression and preference gates, idempotency, and explainable operator traces. Sigra owns auth state — token generation, hashed persistence, rate limits, and magic link / confirmation code TTL. When an auth event fires, `Sigra.Integrations.Chimeway` resolves the recipient from Sigra domain models and calls `Chimeway.trigger/3`; Chimeway never mutates Sigra records.

## 3. Notifier reference

The integration declares two stable notification keys — string identities, not module names:

- `sigra.auth.magic_link` — passwordless magic link sign-in
- `sigra.auth.confirmation_code` — email confirmation code dispatch

The notifier `build/2` callback resolves the magic link URL and the confirmation code at dispatch time, reading from the Sigra repo and host-supplied closures. Sensitive values are reconstructed only at render time — they are never carried in the Chimeway event payload and never persisted to `chimeway_events.payload`.

## 4. Auth event triggers

Sigra auth events drive the triggers. On a successful `Sigra.Auth.request_magic_link/3` (existing user, not rate-limited), the integration calls `Chimeway.trigger/3`; the same happens when a confirmation code is generated. Each call passes a stable `idempotency_key` (so retried auth events deduplicate) and `tenant_id` (the user id, for tenant-scoped operator search):

```elixir
Chimeway.trigger("sigra.auth.magic_link", recipient,
  idempotency_key: "sigra.magic_link:#{user_id}:#{token_inserted_at}",
  tenant_id: user_id,
  params: %{user_id: user_id, email: email}
)
```

> **Do not pass** `raw_token`, `magic_link_url`, or `confirmation_code` to `Chimeway.trigger/3`.
> Pass identifier-only params (`user_id`, `email`, opaque ref). Sensitive data resolves inside
> notifier `build/2` at dispatch time and is never written to `chimeway_events.payload`.

The trigger params carry only identifiers. The notifier reconstructs the raw token, the magic link URL, and the confirmation code from the Sigra repo at dispatch time, so they never enter Chimeway's durable trace, telemetry meta, or operator surfaces.

## 5. Verification

Seed the demo host Sigra auth scenario to exercise both flows end-to-end:

```elixir
DemoHost.Seeds.seed_sigra_auth/0
```

Then run the named proof command:

```bash
SIGRA_PATH=../sigra mix verify.sigra
```

This exercises the Chimeway-root auth lifecycle proof (including the payload-redaction assertions) and the demo host Sigra proof. After seeding, search `/admin/chimeway` for the auth notification's operator trace and confirm no raw token, magic link URL path segment, or confirmation code appears in the event payload.

## Related guides

- [Golden Path](golden-path.md) — Chimeway-only first integration
- [Sigra auth blueprint](../recipes/sigra-auth-blueprint.md) — focused notifier/seam recipe
- [Mailglass integration blueprint](../recipes/mailglass-integration-blueprint.md) — optional email delivery for auth notifications
- [Installation](installation.md) — Chimeway install and migration depth
