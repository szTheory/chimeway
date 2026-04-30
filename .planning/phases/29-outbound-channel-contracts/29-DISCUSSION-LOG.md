# Phase 29: Outbound Channel Contracts - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in 29-CONTEXT.md — this log preserves the analysis.

**Date:** 2026-04-30
**Phase:** 29-outbound-channel-contracts
**Mode:** assumptions + parallel deep-research synthesis
**Areas analyzed:** SMS render contract, Push render contract, Generic Chat extensibility,
Per-channel adapter routing, Adapter visibility, Test ergonomics, Preview surface, Style

## Assumptions Presented (initial)

### SMS / Push render contract
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Ship `Channels.Sms` and `Channels.Push` as Ecto.Changeset validators mirroring `Email`/`InApp` | Confident | `lib/chimeway/rendering/channels/email.ex`, `in_app.ex`; Phase 21 D-06 |
| SMS: `text_body` only; no `from`/`to`/length-validation | Confident | Symfony `SmsMessage`, Laravel `VonageMessage`, Noticed Twilio (pending research) |
| Push: `title`+`body`+optional opaque `data`; one `:push` channel | Confident | Pigeon, Laravel-FCM, Noticed FCM (pending research) |

### Adapter shape and routing
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `Chimeway.Adapter.deliver/2` stays unchanged | Confident | `lib/chimeway/adapter.ex:50-51`; Phase 21 D-08 locks dumb-transport posture |
| Per-channel adapter MODULE map mirrors `:channel_adapter_configs` | Confident | `lib/chimeway/dispatch/channel_adapter_config.ex:17-22` (sibling pattern); executor.ex:31 (single-adapter blocker) |

### Generic Chat extensibility
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Initial: do NOT ship `Channels.Chat`; document host-string seam | Likely | `delivery_planning.ex:438-446` graceful fallback; ROADMAP scope |
| Alternative A: minimal `Channels.Chat` with `text` + `rich_payload` | (alternative) | CHAN-01 names "Chat" as third example |
| Alternative B: runtime channel-module registry | (alternative) | Future-proof but higher blast radius |

### Preview surface
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Zero API changes to `Preview.preview/3` and Mix task | Confident | `preview.ex:55-67`, `preview_rendering.ex:23-33` already channel-string-agnostic |

## User Direction

User asked for **deep parallel ecosystem research** instead of accepting the initial menu.
Specifically: "research using subagents, what is pros/cons/tradeoffs of each considering the
example for each approach, what is idiomatic for elixir/plug/ecto/phoenix for this type of
lib/app and in this ecosystem, lessons learned from other libs/apps in same space even from
other languages/frameworks if they are popular successful, what did they do right that we
should learn from, what did they do wrong/footguns we can learn from, great developer
ergonomics/dx emphasized... user friendly... think deeply one-shot a perfect set of
recommendations so I don't have to think, all recommendations are coherent/cohesive with
each other and move us toward the goals/vision of this project."

This preference was saved as a feedback memory at
`~/.claude/projects/-Users-jon-projects-chimeway/memory/feedback_research_first.md` so
future sessions default to research-first one-shot recommendations rather than option
menus.

## Research Performed

Three parallel `general-purpose` subagents, all returning decisive single-recommendation
outputs:

### Agent 1: SMS / Push render contract field shape
Researched Symfony Notifier (`SmsMessage`, `PushMessage`), Laravel Notifications +
`laravel-notification-channels/fcm` (`VonageMessage`, `FcmNotification`), Noticed (Rails)
Twilio + FCM delivery methods, Pigeon (Elixir) APNS/FCM `Notification` structs, ex_twilio,
Knock, Novu, and Swoosh.

**Findings:**
- SMS: every framework converges on a single content field. `from` is environment
  config, `to` is recipient resolution. No length validation in any major framework.
- Push: every framework converges on `title`+`body`+opaque `data`. Platform-divergence
  fields (`apns_topic`, `priority`, `badge`, `sound`, `category`) are universally
  classified as transport plumbing. NOBODY splits push into per-platform channels at
  the public API level.
- Style: `Ecto.Changeset` is the idiomatic Elixir fit for persistence-boundary
  validators producing JSONB-shaped maps. Swoosh's `defstruct` is for runtime transport
  messages — different role.

### Agent 2: Channel extensibility model
Researched Symfony chatter/texter, Laravel `Notification::extend` + `toXyz()`, Noticed
DeliveryMethods, Knock/Novu channel SDKs, Phoenix.PubSub, Swoosh.Adapter, Bamboo.Adapter,
Oban.Worker, Tesla, Plug.Adapter.

**Findings:**
- Option D (combo: ship `Channels.Chat` starter + open registry seam) wins on every
  axis: CHAN-01 fully satisfied in core, host apps extend without forking, traces stay
  durable, behaviour + boot-time validation prevent magic-method silent typos
  (Laravel) and late-binding class-name footguns (Noticed).
- Pure host-string seam (Option A) violates Phase 21 D-08 — pushes rendering into
  adapters.
- Validator-only (Option B) forces a PR-and-release cycle for every new channel —
  Symfony's bridge-package ceiling.
- Registry-only (Option C) leaves CHAN-01's third example un-served and forces every
  host to re-implement the same `text + rich_payload` schema.
- Per-notifier callback module (Option E) makes traces ambiguous (same channel name
  could be validated by different modules across notifiers).

### Agent 3: Per-channel adapter routing
Researched Swoosh.Mailer, Bamboo.Mailer, Oban.Worker, Symfony Notifier `texter_transports`,
Laravel notification drivers, Noticed delivery method configs, Knock integrations, Tesla,
Phoenix.Endpoint, Phoenix.PubSub.

**Findings:**
- Strawman 1 (`:channel_adapters` map mirroring `:channel_adapter_configs`) wins on
  every axis: smallest change, atom-safe, backwards-compatible, declarative, traceable.
- Router-adapter (Strawman 2): forces every host to write a router; obscures trace
  identity. Bamboo and Swoosh rejected this.
- Resolver behaviour (Strawman 3): per-delivery routing is a v1.5+ failover/A/B
  concern; the static map is the natural default implementation a future resolver
  would fall back to.
- Notifier-side tuples (Strawman 4): re-introduces compile-time vendor coupling;
  contradicts Phase 11.
- New decision surface: persist `adapter_module` per ATTEMPT (not per delivery)
  because adapter can change across retries (failover, mid-incident reconfig).
  Operator visibility for "which adapter ran" becomes a one-row trace query.
- Test ergonomics: `Chimeway.Adapters.Test` should tag messages with `delivery.channel`
  on send (avoids Swoosh's mailer-tagging retrofit pain).

## Synthesis

All three research outputs converged on a coherent set with no internal conflicts.
Channel-extensibility's "registry overlay" pattern composes cleanly with
SMS/Push/Chat's "first-class compiled clauses" — registry layer 1, compiled layer 2,
graceful fallback layer 3. Per-channel adapter routing's `:channel_adapters` mirrors
the existing `:channel_adapter_configs` exactly (Phase 11 string-safe discipline). The
new public `Chimeway.Rendering.Channel` behaviour is the only forever-API commitment.

## Decisions Locked

All 25 decisions (D-01..D-25) locked per user confirmation. See `29-CONTEXT.md`
`<decisions>` section. The single forever-API surface is D-11..D-14 (the public
`Chimeway.Rendering.Channel` behaviour + `:channel_render_modules` registry); user
explicitly approved this commitment.

## Corrections Made

No corrections — all assumptions confirmed after research synthesis.

## Auto-Resolved

Not applicable (interactive mode, not `--auto`).

## External Research

Three parallel `general-purpose` subagents (`ae7eb2d7aba4d83bc`, `adf7910f6388886d2`,
`a8f3493111557573d`) running concurrently, total ~6 minutes wall-clock. Sources cited:

### SMS / Push contract sources
- Symfony Notifier (`SmsMessage`, `PushMessage`): https://symfony.com/doc/current/notifier.html
- Symfony Push Channels: https://symfony.com/doc/current/notifier/chatters.html
- Laravel Notifications: https://laravel.com/docs/notifications
- Laravel FCM channel: https://github.com/laravel-notification-channels/fcm
- Noticed (Rails): https://github.com/excid3/noticed
- Noticed Twilio Messaging: https://github.com/excid3/noticed/blob/main/docs/delivery_methods/twilio_messaging.md
- Noticed FCM: https://github.com/excid3/noticed/blob/main/docs/delivery_methods/fcm.md
- Pigeon (Elixir): https://github.com/codedge-llc/pigeon
- Pigeon.APNS.Notification: https://hexdocs.pm/pigeon/Pigeon.APNS.Notification.html
- Pigeon.FCM.Notification: https://hexdocs.pm/pigeon/Pigeon.FCM.Notification.html
- ExTwilio.Message: https://hexdocs.pm/ex_twilio/ExTwilio.Message.html
- Knock SMS overview: https://docs.knock.app/integrations/sms/overview
- Knock SMS settings/overrides: https://docs.knock.app/integrations/sms/settings-and-overrides
- Knock push overview: https://docs.knock.app/integrations/push/overview
- Novu payload: https://docs.novu.co/framework/payload
- Swoosh.Email: https://hexdocs.pm/swoosh/Swoosh.Email.html

### Channel extensibility sources
- Symfony Notifier: https://symfony.com/doc/current/notifier.html
- Laravel Custom Notification Channels: https://laravel.com/docs/notifications#custom-channels
- Noticed README: https://github.com/excid3/noticed
- Swoosh.Adapter behaviour: https://hexdocs.pm/swoosh/Swoosh.Adapter.html
- Bamboo.Adapter behaviour: https://hexdocs.pm/bamboo/Bamboo.Adapter.html
- Phoenix.PubSub: https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html
- Oban.Worker: https://hexdocs.pm/oban/Oban.Worker.html
- Knock Channels: https://docs.knock.app/concepts/channels

### Per-channel adapter routing sources
- Swoosh.Mailer: https://hexdocs.pm/swoosh/Swoosh.Mailer.html
- Bamboo.Mailer: https://hexdocs.pm/bamboo/Bamboo.Mailer.html
- Oban.Worker source: https://github.com/oban-bg/oban/blob/main/lib/oban/worker.ex
- Symfony Notifier (texter_transports): https://symfony.com/doc/current/notifier.html
- Tesla: https://hexdocs.pm/tesla/readme.html
- Phoenix.Endpoint: https://hexdocs.pm/phoenix/Phoenix.Endpoint.html
- Phoenix.PubSub: https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html

## Methodology Lenses Applied

- `Cohesive Recommendation Default` — converged on one internally consistent
  recommendation set rather than a menu.
- `Research-First Decision Ownership` — three parallel ecosystem-research agents
  before presenting to the user.
- `One-Shot Recommendation Bias` — single decisive recommendation per area, alternatives
  cited only to justify the recommendation.
- `Durable Explainability Bias` — adapter identity persisted per attempt as a string
  (D-20..D-22); registry validation at boot (D-13); telemetry on misconfig
  (D-14, D-19).
- `Least-Surprise DX Default` — Ecto.Changeset preserves the existing channel-validator
  shape (D-25); `:channel_adapters` mirrors `:channel_adapter_configs` exactly
  (D-15..D-17); legacy `:adapter` keeps working unchanged (D-18); zero API changes to
  preview surfaces (D-24).
- `High-Impact Escalation Gate` — escalated only the public-API commitment
  (`Chimeway.Rendering.Channel` behaviour + registry) to the user; locked the rest as
  recommendations without per-decision approval gates.
