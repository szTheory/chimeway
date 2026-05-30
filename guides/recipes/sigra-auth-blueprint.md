# Sigra Auth Blueprint

## Who this is for

**Feature Developer (SigraAuthNotifier authoring):** Your JTBD is "author a `Chimeway.Notifier` with stable notification keys for Sigra auth events" — implement `build/2` returning rendered email params with `sigra.auth.magic_link` and `sigra.auth.confirmation_code` as stable `notification_key` constants while Sigra resolves auth domain models to recipients.

**Adopter (Sigra.Integrations.Chimeway wiring):** Your JTBD is "wire Sigra auth events into Chimeway without host callback glue" — configure `config :sigra, chimeway: [enabled: true]` and let `Sigra.Integrations.Chimeway` bridge auth events into the Chimeway trigger spine automatically.

## Prerequisites

- [Golden Path](../introduction/golden-path.md) — install, migrations, and your first `Chimeway.trigger/3`
- Sigra sibling checkout for local dev: set `SIGRA_PATH` to your Sigra repo (optional path dep in host `mix.exs`, mirroring Chimeway root and demo host)

## Responsibility split (SEED-003)

**Chimeway orchestrates the when and why:** durable notification lifecycle, suppression and preference gates, idempotency, and operator traces you can search at `/admin/chimeway`.

**Sigra owns auth state:** token generation, hashed persistence, rate limits, and magic link / confirmation code TTL. Sigra emits auth events; Chimeway does not mutate Sigra records.

This integration is **not** a `Chimeway.Adapter` seam — it is a Sigra auth event → `Chimeway.trigger/3` bridge only.

## Feature Developer: SigraAuthNotifier authoring

Runnable reference module: `Sigra.Integrations.Chimeway.SigraAuthNotifier` in the Sigra repo.

Stable string keys — not module names — are the durable identity:

```elixir
@impl true
def notification_key, do: "sigra.auth.magic_link"
```

For the confirmation code flow:

```elixir
@impl true
def notification_key, do: "sigra.auth.confirmation_code"
```

`build/2` returns rendered email params using identifier-only fields — never token values:

```elixir
@impl true
def build(%{user_id: user_id, email: email, correlation_id: correlation_id}, _recipient) do
  {:ok,
   %{
     to: email,
     subject: "Your magic link",
     text_body: "Click your magic link to sign in.",
     assigns: %{
       user_id: user_id,
       correlation_id: correlation_id
     }
   }}
end
```

**Auth event shape (SEED-003):** Sigra emits the auth event with identifier-only params (`user_id`, `email`, `correlation_id`). Raw tokens, confirmation codes, and magic-link URLs are Sigra's domain — they must not appear as `Chimeway.trigger/3` params.

**Trigger options:** When Sigra dispatches an auth event, `Sigra.Integrations.Chimeway` calls `Chimeway.trigger/3` with `idempotency_key` and `tenant_id` (user id) — both required for durable deduplication and tenant-scoped traces.

## Adopter: Sigra.Integrations.Chimeway registration

Configure Sigra to use the Chimeway integration at runtime:

```elixir
config :sigra,
  chimeway: [enabled: true]
```

**Sigra.Integrations.Chimeway** calls `Chimeway.trigger/3` internally when Sigra processes a magic link request or confirmation code generation. The trigger carries `idempotency_key` and `tenant_id` derived from the auth event — hosts do not call `Chimeway.trigger/3` directly for Sigra auth flows.

For the Chimeway runtime setup (repo, supervisor, migrations), see [Installation](../introduction/installation.md).

## Trigger example (local / test)

Use the named dispatch functions from `Sigra.Integrations.Chimeway` for local proof and integration testing:

```elixir
# Magic link flow
Sigra.Integrations.Chimeway.dispatch_magic_link_after_request(
  %{user_id: user.id, email: user.email},
  idempotency_key: "sigra-magic-#{user.id}-v1",
  tenant_id: user.tenant_id
)

# Confirmation code flow
Sigra.Integrations.Chimeway.dispatch_confirmation_after_generate(
  %{user_id: user.id, email: user.email, correlation_id: correlation_id},
  idempotency_key: "sigra-confirm-#{user.id}-v1",
  tenant_id: user.tenant_id
)
```

Both dispatch functions accept identifier-only params — `user_id`, `email`, `correlation_id`. Token values, token hashes, and confirmation code verbatim values must never appear as `Chimeway.trigger/3` call params — Sigra owns that domain.

## Runnable demo

- **Seeds:** `DemoHost.Seeds.seed_sigra_auth/0` — standalone API; not invoked from `DemoHost.Seeds.run/0`
- **Verification:** `SIGRA_PATH=../sigra mix verify.sigra --warnings-as-errors` (root ECOS-09 lifecycle + demo host DEMO-10 proof)
- **Operator trace:** Search `/admin/chimeway` by user email to inspect `sigra.auth.magic_link` and `sigra.auth.confirmation_code` delivery attempts and auth-event correlation

Demo host uses the Logger email adapter for Sigra lane isolation. For production email delivery, wire `Chimeway.Adapters.Mailglass` per the [Mailglass integration blueprint](mailglass-integration-blueprint.md).

## Out of scope

This blueprint covers notifier authoring, `Sigra.Integrations.Chimeway` config, auth-event trigger examples, and the orchestration vs auth-state split with demo pointers. The full golden-path Sigra auth integration guide, guide doc-contract, and formal `mix verify.sigra` CI job in MAINTAINING are documented in [Sigra auth integration](../introduction/sigra-auth-integration.md) (Phase 66 DOCS-10) — not duplicated here.

## Related guides

- [Sigra auth integration](../introduction/sigra-auth-integration.md) — canonical end-to-end adoption path (Phase 66 DOCS-10)
- [Accrue dunning blueprint](accrue-dunning-blueprint.md) — billing-event dunning workflow composition pattern
- [Mailglass integration blueprint](mailglass-integration-blueprint.md) — optional email delivery via `Chimeway.Adapters.Mailglass`
- [Golden Path](../introduction/golden-path.md) — first Chimeway integration
