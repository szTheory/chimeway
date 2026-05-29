# Phase 56: Blueprint & Demo Proof — Research

**Researched:** 2026-05-29  
**Domain:** Mailglass + Chimeway adoption blueprint (ECOS-05) and demo host end-to-end proof (DEMO-06)  
**Confidence:** HIGH for existing adapter/recipe patterns; HIGH for demo host isolation strategy; MEDIUM for demo host Mailglass test harness duplication vs import

## Summary

Phase 56 makes the Phase 54–55 Mailglass integration **adoptable**: a published reference recipe with CI doc-contract coverage (ECOS-05), plus a demo host proof that outbound email delivers through `Chimeway.Adapters.Mailglass` with operator trace inspectability at `/admin/chimeway` (DEMO-06).

The hard constraint is **journey CI isolation**: 10 existing `:journey` tests use the default Logger adapter and must stay green without Mailglass in the global demo host test path (D-10). Mailglass registration belongs only in a dedicated `@moduletag :mailglass` test module with per-test `Application.put_env` for `:channel_adapters` and `:channel_adapter_configs`.

**Primary recommendation:** Two execution waves — (1) demo host Mailglass harness + `DemoHost.Mailers.InviteEmail` + proof test (DEMO-06), (2) blueprint recipe + doc-contract describe block (ECOS-05). Recipe should reference working demo modules after wave 1.

## Standard Stack

| Component | Version / location | Role |
|-----------|-------------------|------|
| mailglass | `~> 1.3` [VERIFIED: root mix.exs optional dep] | Host-owned dep in demo `mix.exs` (D-09) |
| Chimeway.Adapters.Mailglass | `lib/chimeway/adapters/mailglass.ex` | Outbound deliver + meta redaction |
| Mailglass.Adapters.Fake | test harness | Deterministic delivery without SMTP |
| Mailglass.TestRepo | `config/test.exs` | Sandbox DB for Mailglass deliveries |
| Recipe pattern | `guides/recipes/mention-escalation.md` | Persona sections + demo module pointers |
| Doc-contract | `test/chimeway/doc_contract_test.exs` | `@required_phrases` + `@recipe_forbidden_strings` |

## Architecture Patterns

### Pattern 1: Orchestration vs templating split (SEED-003, D-01)

**Chimeway owns:** when/why to notify, durable lifecycle, suppression, idempotency, operator traces.  
**Mailglass owns:** templating, MJML, Swoosh send, provider delivery IDs.

Recipe MUST state this split in prose with both product name `Chimeway.Adapter.Mailglass` and module `Chimeway.Adapters.Mailglass` (Phase 54 D-07).

### Pattern 2: Stable durable identity (D-03)

| Identifier | Value |
|------------|-------|
| notification_key | `teampulse.invite_sent` |
| email render_key | `teampulse.invite_sent.email` |
| mailable map key | `"teampulse.invite_sent.email"` |

No module names in durable identity — `DemoHost.Notifiers.InviteSent` is copy-paste reference only.

### Pattern 3: Demo host Mailglass test isolation (D-10, D-11)

Mirror root `config/test.exs` Mailglass block into `examples/chimeway_demo_host/config/test.exs`:

```elixir
config :mailglass, adapter: {Mailglass.Adapters.Fake, []}
config :mailglass, repo: Mailglass.TestRepo
# ... tenancy, suppression_store, TestRepo sandbox credentials
```

Proof test module:

```elixir
@moduletag :mailglass

setup do
  Mailglass.Adapters.Fake.checkout()
  Mailglass.Adapters.Fake.set_shared(self())
  Application.put_env(:chimeway, :channel_adapters, %{"email" => Chimeway.Adapters.Mailglass})
  Application.put_env(:chimeway, :channel_adapter_configs, %{
    "email" => [mailables: %{"teampulse.invite_sent.email" => {DemoHost.Mailers.InviteEmail, :invite_email}}]
  })
  on_exit(fn -> restore env ... end)
  :ok
end
```

**Do NOT** set Mailglass adapter in global demo `config/test.exs` default Chimeway channel config — breaks JOUR-01..08.

### Pattern 4: Host mailable (D-13, D-14)

`DemoHost.Mailers.InviteEmail` implements `Mailglass.Mailable` using assigns from notifier `rendering/2` (`subject`, `html_body`, `text_body`, `headline`, etc.). Chimeway adapter passes `delivery.render_data` through to Mailglass.

Reference implementation: `Chimeway.TestSupport.MailglassFixtures.TestMailer` — demo host owns its module, not core test support.

### Pattern 5: Proof test flow (D-15, D-16)

1. `DemoHost.Seeds.seed_invite/0` with Mailglass env active
2. Assert email delivery attempt has `adapter_module` containing `Chimeway.Adapters.Mailglass`
3. LiveViewTest: `/admin/chimeway` search by `DemoHost.Seeds.alex_identity()`, open delivery detail, assert `teampulse.invite_sent` and Mailglass adapter in timeline

Reuse JOUR-04 pattern from `admin_trace_live_test.exs` but in separate `mailglass_delivery_proof_test.exs` (or `mailglass_journey_test.exs`) with `:mailglass` tag only.

### Pattern 6: Doc-contract (D-05, D-06)

Add to `doc_contract_test.exs`:

```elixir
@mailglass_blueprint_recipe Path.expand("../../guides/recipes/mailglass-integration-blueprint.md", __DIR__)

describe "mailglass blueprint recipe doc contract (ECOS-05)" do
  @required_phrases ~w(
    Chimeway.Adapters.Mailglass
    channel_adapters
    render_key
    ...
  )
  # orchestration vs templating phrases — exact list at planner discretion
end
```

Reuse `@recipe_forbidden_strings` from RECP-01/02/03.

### Pattern 7: Recipe structure (RECP-03 alignment)

Sections: Who this is for (Adopter / Feature Developer), Prerequisites (golden-path, custom-adapter cross-link), responsibility split, notifier authoring, adapter registration, mailable mapping, trigger example, runnable demo pointers (`DemoHost.Notifiers.InviteSent`, `DemoHost.Mailers.InviteEmail`, `DemoHost.Seeds.seed_invite/0`), admin trace inspectability note.

Cross-link `guides/recipes/custom-adapter.md` Mailglass stub — blueprint is additive (D-18).

## File Targets

| File | Action |
|------|--------|
| `guides/recipes/mailglass-integration-blueprint.md` | Create (ECOS-05) |
| `test/chimeway/doc_contract_test.exs` | Add ECOS-05 describe |
| `examples/chimeway_demo_host/mix.exs` | Add `{:mailglass, "~> 1.3"}` |
| `examples/chimeway_demo_host/config/test.exs` | Mailglass harness (or new file imported) |
| `examples/chimeway_demo_host/lib/demo_host/mailers/invite_email.ex` | Create mailable |
| `examples/chimeway_demo_host/test/.../mailglass_delivery_proof_test.exs` | Create proof |
| `guides/recipes/custom-adapter.md` | Optional cross-link only |

## Anti-Patterns

- Global demo host Mailglass adapter in test config → breaks 10 journey tests
- Using `PasswordReset` or `PaymentReminder` for DEMO-06 → wrong JTBD paths (suppression / workflow)
- Recipe doc-contract without orchestration/templating language → ECOS-05 incomplete
- Duplicating Phase 57 golden-path guide scope in blueprint → boundary violation (D-17)

## Validation Architecture

Phase 56 verification is **Mix/ExUnit** with selective tags:

| Layer | Command | When |
|-------|---------|------|
| Doc-contract | `MIX_ENV=test mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` | After recipe + describe |
| Mailglass proof | `cd examples/chimeway_demo_host && mix test --only mailglass` | After demo wiring |
| Journey regression | `mix verify.journeys` | After any demo config change — MUST stay green |
| Root mailglass suite | `MIX_ENV=test mix test --only mailglass` (optional) | No regression to Phase 54–55 |

**Wave 0:** None — infrastructure exists from Phases 54–55; demo host adds harness only.

**Nyquist sampling:** After each plan commit, run the plan's `<verify>` command; before phase verify-work, run doc-contract + `--only mailglass` + `mix verify.journeys`.

## Open Questions (Claude's Discretion)

- Exact `@required_phrases` list beyond D-06 minimum
- `invite_email` vs `:email` function name on mailable
- Duplicate Mailglass config vs shared import from Chimeway test support
- `@moduletag :demo_06` in addition to `:mailglass`

## RESEARCH COMPLETE
