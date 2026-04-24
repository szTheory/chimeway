# NotifyKit Research Brief — Elixir/Ecto/Plug/Phoenix notification framework

**Product name:** **Chimeway** (this file is the domain research spine; body text may still say NotifyKit in places).  
**Repo:** `chimeway` — use `prompts/CHIMEWAY-GSD-IDEA.md` for GSD bootstrap.

Research snapshot: **2026-04-23**  
Working name in doc: **NotifyKit** (historical). This doc is meant to become `PROJECT.md` / `RESEARCH.md` context for a GSD-style build workflow: compact, decision-oriented, and optimized for AI coding assistance.

---

## 0. One-screen thesis

Build the missing embedded notification framework for Phoenix SaaS apps: **one notification definition -> many recipients -> many channels -> durable tracking -> great admin/debugging UI**.

The Elixir ecosystem already has good channel primitives:

- **Email:** Swoosh is mature, adapter-rich, and test-friendly.
- **Jobs:** Oban is the obvious production dispatch substrate: SQL-backed, transactional, inspectable, and observable.
- **Push:** Pigeon covers APNS/FCM; Web Push libraries now exist but remain younger and less standardized.
- **SMS/Twilio:** `ex_twilio` exists but is older; `twilio_elixir` appeared in 2026 as an OpenAPI-generated client, but Twilio still does not list Elixir as an official server-side SDK language.
- **Phoenix UI:** LiveView + PubSub + LiveDashboard patterns make a native admin/debug UI feasible.

The gap is not “how to send email” or “how to call Twilio.” The gap is **routing, preferences, durable fanout, idempotency, retries, read/seen state, audit, fallback, digests, and debugging** across channels.

Design target:

```text
Domain event
  -> Notifier definition
  -> Event row
  -> recipient resolution
  -> per-recipient Notification/InboxItem rows
  -> per-channel Delivery rows
  -> delivery jobs
  -> adapter/provider calls
  -> attempts, statuses, telemetry, admin trace
```

Core positioning:

- **Embedded library, not SaaS-first.** Users keep data in their app DB.
- **Ecto/Oban/Phoenix-first, not Rails cosplay.** Small explicit behaviours, plain structs, generators, optional macros.
- **Batteries included, dependency-light.** Core is small. Adapters are optional packages. Phoenix admin/inbox is optional.
- **Beginner path in 30 minutes; advanced path without rewrites.** Start with in-app + Swoosh. Grow into Oban, Slack, webhook, push, SMS, digests, quiet hours, multi-tenancy.
- **The killer feature is “why wasn’t this sent?”** Every notification should be explainable from trigger through policy through provider response.

---

## 1. Ecosystem reality check

### Elixir today

| Area | Current state | Product lesson |
|---|---|---|
| Email | Swoosh supports many transactional providers plus SMTP. It includes Local, Test, and Sandbox adapters; Sandbox is useful for browser/E2E tests across processes. | Do not compete with Swoosh. Wrap it. Copy its adapter/test ergonomics. |
| Jobs | Oban is SQL-backed and designed around reliability, consistency, observability, transactional enqueue, isolated queues, telemetry, retries, scheduling, uniqueness, and inspection. | Use Oban as the blessed production engine, but keep a minimal sync/test engine for onboarding. |
| Push | Pigeon provides APNS/FCM dispatchers. Web Push options exist (`ExNudge`, `WebPushEx`, `web_push_elixir`) but maturity/adoption is uneven. | Adapter should expose push semantics: TTL, priority, collapse keys, invalid token cleanup, platform-specific headers. |
| SMS/Twilio | Twilio official server-side SDKs list C#/.NET, Java, Node.js, PHP, Python, Ruby, and Go. `ex_twilio` is still available; `twilio_elixir` emerged in 2026 as a generated package from Twilio OpenAPI specs. | SMS adapter must be replaceable and provider-agnostic. Do not bet the framework on one unofficial SDK. |
| Unified notifications | `vcf_notifier` exists as a simple Oban-backed notification queuing library, but it is early and tiny. | There is room for a fuller framework if it nails DX, docs, adapters, admin, and reliability. |
| Admin UI | Backpex and Kaffy show Phoenix devs want admin panels, but customization/auth/LiveView integration matter. | Ship a purpose-built notification dashboard, not just generic CRUD. Make it easy to mount safely. |

### Community signal

Recurring Phoenix/Elixir feedback: Phoenix is powerful but often gives lower-level Lego bricks where Rails offers batteries-included gems. HN comments specifically call out notifications: unread icons, DB records, email/SNS, SMS/Twilio, Slack, and “nothing like this in Elixir.” The opportunity is to preserve Elixir’s explicitness while removing repetitive notification plumbing.

Counter-signal: some Elixir developers prefer small, app-specific implementations over big magical gems. Therefore the library must avoid opaque Rails-style magic. Every macro should expand into plain behaviours/data. Every default should be inspectable.

---

## 2. Competitive lessons

### Rails: Noticed

What Noticed gets right:

- Clear unit: **Notifier** models an **Event**.
- Supports individual deliveries and bulk deliveries.
- Built-in channels include ActionCable, email, APNS, FCM, Slack, Teams, Twilio, Vonage, webhook, and test delivery.
- One invocation creates an Event and recipient Notification records, then fans out jobs per bulk delivery and per recipient+channel.
- DB-only notifications are useful even without external delivery.
- Shared delivery options: `if`, `unless`, `wait`, `wait_until`, `queue`.
- Great fallback pattern: in-app/realtime now, delayed email only if unread.
- Custom delivery method generator with required options.

Footguns / lessons to avoid:

- Persisting class/module names as notification type makes renames painful. Noticed documents that renaming a Notifier can break existing data and requires backfills.
- URL generation and default host configuration are easy to forget.
- “Mark as read” semantics are app-specific. Library must not assume display == read.
- Rails autoload/generator naming issues can become confusing for beginners.

Elixir translation:

- Use **stable notification keys** like `"comment.created"`, not module names, as DB identity.
- Still allow modules for code organization: `MyApp.Notifiers.CommentCreated`.
- Add compile-time/runtime validation: missing `key`, missing channel renderer, missing URL config, missing adapter config.
- Make read/seen explicit: `seen_at`, `read_at`, `archived_at`.

### Laravel Notifications

What Laravel gets right:

- One-line user-facing API: `$user->notify(new InvoicePaid($invoice))`.
- A `via($notifiable)` method chooses channels per recipient, so preferences/routing are naturally recipient-aware.
- Queue integration is first-class; queued notifications create one job per recipient+channel.
- Per-channel queue connections and queue names exist (`viaConnections`, `viaQueues`).
- `shouldSend` runs after queue processing begins, enabling late suppression.
- `afterSending` receives recipient, channel, and response.
- On-demand routing supports recipients not stored as users.

Footguns / lessons:

- Earlier community pain around “queue email but make DB notification immediate” shows that per-channel timing/queue behavior matters.
- Default email subject from class name is convenient but can hide bad UX.
- Queue/database-transaction timing must be explicit.

Elixir translation:

- Provide `NotifyKit.notify(recipient, Notifier, params)` and `NotifyKit.trigger(Notifier, params, recipients: ...)`.
- Every channel spec should declare `mode: :sync | :job | :inline_db`, `queue`, `wait`, `priority`, `max_attempts`.
- Policy must run twice: once before enqueue, once before perform.
- Support ad-hoc routes: email address, phone number, Slack channel, webhook URL.

### Symfony Notifier

What Symfony gets right:

- Strong abstraction around channels and transports.
- Channels integrate with providers: SMS, chat, email, browser, push.
- Transports can support failover/round-robin patterns.

Footguns / lessons:

- Naming confusion: “Chatters” vs “Texters” caused community confusion.
- DSN configuration is compact but brittle; special characters in credentials must be URL-encoded, and bugs/issues around `+` in Twilio phone numbers show this is a real footgun.

Elixir translation:

- Avoid clever DSN strings as the main config interface. Prefer validated keyword/config structs.
- Use plain domain terms: `Channel`, `Provider`, `Route`, `Delivery`.
- If DSNs are supported, provide parser validation and clear errors.

### Django notification packages

What they get right:

- Simple in-app notification model: unread/read/deleted/sent scopes and template tags.
- Useful distinction between GitHub-style notifications and activity feeds.

Footguns / lessons:

- Tight coupling to framework model/migration churn causes maintenance drag. Recent Django notification package issues mention Django version compatibility, `index_together`, `jsonfield`, `distutils`, and broken migrations.
- Read/unread UI behavior is deceptively hard; users still ask how to live-update unread state correctly.

Elixir translation:

- Keep migrations simple and stable. Do not overfit to one Phoenix version.
- Publish upgrade guides for every migration change.
- Model `Notification` separately from activity feed. Do not become a social feed/event-stream framework by accident.

### Novu and notification-infrastructure products

What Novu gets right:

- Unified API across Inbox/In-App, Push, Email, SMS, and Chat.
- Real-time Inbox, embeddable preferences, digest engine, workflow engine, provider catalog, admin surface.
- Environments and workflow versions are first-class.
- Execution logs make failures inspectable.

Tradeoff:

- Novu is infrastructure/platform/open-core. NotifyKit should be embedded by default. The admin UI should feel native to Phoenix, not like a separate product unless the user opts into that.

Elixir translation:

- Copy the product concepts: workflow steps, digest, preferences UI, provider catalog, execution logs.
- Do not copy the architecture wholesale. Phoenix apps want simple local install, local DB, and code-first control.

---

## 3. Non-negotiable design principles

1. **Stable identity beats module identity.** Persist `key: "invoice.paid"`, `version: 1`; never depend on `MyApp.Notifiers.InvoicePaid` as the DB type.
2. **Every external send has a Delivery row and at least one Attempt row.** No invisible provider calls.
3. **Idempotency is a product feature, not an adapter detail.** Every event, notification, and delivery gets a deterministic idempotency key.
4. **In-app is not just another external channel.** It is the durable canonical recipient record and should work without Oban/provider setup.
5. **Preference checks happen late.** Check before enqueue and again before delivery job performs.
6. **Admin/debug UI is not optional for a “best” framework.** The framework should explain trigger -> route -> policy -> render -> queue -> provider -> result.
7. **Adapters are behaviours with contract tests.** No adapter should be accepted without a fake/sandbox and shared behavior test suite.
8. **No hard Phoenix dependency in core.** Core + Ecto are usable from any Elixir app; Phoenix adds routes, LiveView components, and admin UI.
9. **Use macros for ergonomics, not hidden behavior.** Provide plain data APIs and generated introspection.
10. **Respect BEAM/OTP.** Supervisors, telemetry, explicit config, hot code upgrade friendliness where feasible, and no global mutable registry surprises.

---

## 4. Footguns and countermeasures

| Footgun | Why it happens | Build countermeasure |
|---|---|---|
| Renaming notifier breaks old records | Framework stores class/module name as type. | Persist stable `key` + `version`; module is only current renderer. Add `mix notify_kit.audit_keys`. |
| Duplicate sends on retry | Jobs retry after provider success but before local state update; requests retried without idempotency. | Local idempotency key on event/recipient/channel; provider idempotency headers when supported; unique DB indexes; attempt state machine. |
| Oban uniqueness misunderstood | Oban unique jobs prevent duplicate insertion; they do not control runtime concurrency. | Docs + generator comments; use uniqueness only for enqueue dedupe; use queue concurrency/rate limiter separately. |
| Transaction commits event but loses job | Event insert and job enqueue not atomic. | Use `Ecto.Multi`; with Oban, insert event/deliveries/jobs in one transaction. |
| Preference checked too early | User changes preference after job queued. | `policy_check_at: [:enqueue, :perform]`; late `should_send?` default. |
| Read/seen semantics wrong | UI viewing, dropdown opening, and intentional read are different. | Separate `seen_at`, `read_at`, `archived_at`; components call explicit APIs. |
| Notification fatigue | Easy to blast every channel. | Built-in quiet hours, frequency caps, priority, digest, fallback/escalation policies. |
| “Email if unread” sends after user read | Delay job does not recheck DB. | Delayed channel always reloads Notification and policy at perform time. |
| Push messages silently collapse/drop | FCM/APNS TTL/collapse semantics are non-obvious; devices offline/inactive. | Channel config exposes `ttl`, `collapse_key`, `priority`, `apns_expiration`; docs explain guarantees. |
| Invalid device tokens pile up | Providers return invalid/expired token statuses. | Adapter callbacks mark tokens invalid with reason/time; admin token health page. |
| Provider rate limit / retry storm | Many notifications fan out at once; 429s retried aggressively. | Per-provider queues, backoff+jitter, rate-limit buckets, circuit breaker, dead-letter. |
| Secrets leak in logs/admin | Provider config and payloads include PII/secrets. | Runtime config; redaction callbacks; payload field classification; no raw tokens in admin. |
| DSN special characters break provider config | URL-style config needs escaping. | Prefer structured config. If DSN supported, validate and warn. |
| Admin route exposed | Dashboard mounted without auth. | Router macro requires explicit `on_mount`/plug/auth callback in prod; fail closed. |
| Multi-tenancy bolted on late | Notification rows lack tenant scoping. | `tenant_id` or `scope` column from v1; Ecto prefix support; tenant-aware unique indexes. |
| Tests flaky across processes | Email/job/push occurs outside ExUnit process. | Swoosh Sandbox model; NotifyKit Sandbox adapter; Mox behaviours; Bypass provider simulator. |
| Stored payload becomes stale | Rendering later after record changed/deleted produces wrong content. | Offer render strategy: `:snapshot`, `:lazy`, `:hybrid`. Default: store minimal snapshot + record ref. |
| Large payloads/attachments bloat DB | JSON payload stores huge blobs. | Payload size limits; attachment references; object storage hooks. |
| Internationalization forgotten | Templates hardcode strings. | `key`-based template rendering; locale on recipient; preview matrix by locale. |
| Unsubscribe/legal requirements ignored | Email/SMS/push need opt-outs. | Preference schema, unsubscribe tokens, channel-level suppression, audit trail. |
| Provider webhooks unauthenticated | Status callbacks can be spoofed. | Adapter-specific Plug with signature verification and replay protection. |
| Library tries to be a marketing platform | Transactional notifications and campaigns diverge. | Non-goal: marketing automation. Support transactional/digest/fallback; not journeys/campaigns v1. |

---

## 5. Domain language

### Nouns

| Term | Meaning |
|---|---|
| **Notifier** | Code module/definition for a notification type. Example: `CommentCreated`. |
| **Notification Key** | Stable persisted identity: `"comment.created"`. |
| **Event** | One occurrence of a notifier being triggered. Immutable-ish root record. |
| **Actor** | Person/system that caused the event. Optional. |
| **Subject / Record** | Domain object the notification is about: invoice, comment, deployment, etc. |
| **Recipient** | User/team/account/external route to notify. |
| **Notification / InboxItem** | Per-recipient persisted in-app record. Canonical read/seen state. |
| **Channel** | Medium: in-app, email, SMS, push, Slack, webhook, Teams, etc. |
| **Provider** | Vendor/client behind a channel: Swoosh/Postmark, Twilio, Pigeon/FCM, Slack. |
| **Route** | Recipient-specific address for a channel: email, phone, token, Slack ID, webhook endpoint. |
| **Delivery** | Planned or completed send for one event/recipient/channel or a bulk channel. |
| **DeliveryAttempt** | One provider call attempt with request/response/error metadata. |
| **Preference** | User/org rule enabling/disabling or delaying notification by key/topic/channel. |
| **Policy** | Code/config that decides whether, when, and how to send. |
| **Template / Renderer** | Code or stored template that turns event context into channel payload. |
| **Digest** | Batched delivery window combining events into one message. |
| **Escalation / Fallback** | Conditional later delivery, e.g. email if in-app unread after 15 minutes. |
| **Suppression** | Explicit decision not to send: preference disabled, quiet hours, duplicate, invalid route. |
| **Environment** | Dev/test/prod or provider config namespace. |
| **Tenant** | Account/org/app scope for multi-tenant SaaS. |
| **Trace** | Explainable log of routing/policy/render/enqueue/provider decisions. |

### Verbs

`define`, `trigger`, `resolve_recipients`, `route`, `render`, `persist`, `enqueue`, `deliver`, `attempt`, `retry`, `suppress`, `cancel`, `mark_seen`, `mark_read`, `archive`, `digest`, `escalate`, `fanout`, `requeue`, `simulate`, `inspect`, `redact`, `verify`, `backfill`.

### Events / telemetry names

Use consistent telemetry names and DB audit event names:

```text
[:notify_kit, :event, :created]
[:notify_kit, :recipient, :resolved]
[:notify_kit, :preference, :checked]
[:notify_kit, :notification, :persisted]
[:notify_kit, :delivery, :planned]
[:notify_kit, :delivery, :enqueued]
[:notify_kit, :delivery, :started]
[:notify_kit, :provider, :request, :started]
[:notify_kit, :provider, :request, :stopped]
[:notify_kit, :delivery, :succeeded]
[:notify_kit, :delivery, :failed]
[:notify_kit, :delivery, :suppressed]
[:notify_kit, :delivery, :retried]
[:notify_kit, :inbox, :seen]
[:notify_kit, :inbox, :read]
[:notify_kit, :token, :invalidated]
[:notify_kit, :digest, :flushed]
[:notify_kit, :admin, :requeued]
```

---

## 6. Proposed architecture

### Package strategy

Prefer a monorepo with multiple Hex packages:

| Package | Purpose |
|---|---|
| `notify_kit` | Core behaviours, structs, policy, routing, rendering contracts. No Phoenix. Minimal deps. |
| `notify_kit_ecto` | Schemas, migrations, Repo callbacks, query API. |
| `notify_kit_oban` | Worker modules, transactional enqueue helpers, retry/backoff, queues. |
| `notify_kit_phoenix` | Plug/router helpers, JSON APIs, LiveView components, PubSub integration. |
| `notify_kit_admin` | LiveView dashboard/admin UI. Could merge with Phoenix package early. |
| `notify_kit_swoosh` | Email adapter. |
| `notify_kit_pigeon` | APNS/FCM adapter. |
| `notify_kit_web_push` | Browser push adapter. |
| `notify_kit_twilio` | SMS/WhatsApp adapter. |
| `notify_kit_slack` | Slack chat/bulk adapter. |
| `notify_kit_webhook` | Outbound webhook adapter + inbound status callback helpers. |
| `notify_kit_batteries` | Optional meta-package that pulls common Phoenix/Ecto/Oban/Swoosh pieces. |

Rationale: batteries included without forcing every app to depend on Twilio, Pigeon, LiveView, etc.

### Core behaviours

```elixir
defmodule NotifyKit.Notifier do
  @callback key() :: String.t()
  @callback version() :: pos_integer()
  @callback recipients(NotifyKit.Context.t()) :: {:ok, [NotifyKit.Recipient.t()]} | {:error, term()}
  @callback channels(NotifyKit.Context.t(), NotifyKit.Recipient.t()) :: [NotifyKit.ChannelSpec.t()]
  @callback render(NotifyKit.Channel.t(), NotifyKit.Context.t(), NotifyKit.Recipient.t()) ::
              {:ok, NotifyKit.Payload.t()} | {:error, term()}
  @callback policy(NotifyKit.Context.t(), NotifyKit.Recipient.t(), NotifyKit.Channel.t()) ::
              NotifyKit.Policy.decision()
end
```

Macro API should generate this behaviour implementation, not hide it.

### Beginner DSL

```elixir
defmodule MyApp.Notifiers.CommentCreated do
  use NotifyKit.Notifier,
    key: "comment.created",
    version: 1

  param :comment_id, Ecto.UUID
  param :post_id, Ecto.UUID

  recipients :post_watchers

  deliver :in_app

  deliver :email,
    adapter: MyApp.Notify.Email,
    wait: [minutes: 15],
    unless: :read?,
    queue: :notifications_email

  def post_watchers(ctx) do
    MyApp.Posts.watchers(ctx.params.post_id)
  end

  def render(:in_app, ctx, recipient) do
    {:ok,
     %{title: "New comment",
       body: "Someone commented on a post you watch",
       url: ~p"/posts/#{ctx.params.post_id}#comment-#{ctx.params.comment_id}"}}
  end

  def render(:email, ctx, recipient) do
    MyApp.Emails.comment_created(recipient, ctx.params)
  end
end
```

Trigger:

```elixir
NotifyKit.trigger(MyApp.Notifiers.CommentCreated,
  %{post_id: post.id, comment_id: comment.id},
  actor: current_user,
  record: comment,
  idempotency_key: "comment:#{comment.id}:created"
)
```

### Plain-data API for advanced users

```elixir
%NotifyKit.EventSpec{
  key: "comment.created",
  version: 1,
  params: %{post_id: post.id, comment_id: comment.id},
  actor: NotifyKit.Ref.from(current_user),
  record: NotifyKit.Ref.from(comment),
  idempotency_key: "comment:#{comment.id}:created"
}
|> NotifyKit.plan(MyApp.NotifyConfig)
|> NotifyKit.persist_and_enqueue(MyApp.Repo)
```

This keeps the framework testable and prevents macro lock-in.

---

## 7. Data model

Suggested tables, all prefixable and tenant-scopeable.

### `notify_events`

Root occurrence.

```text
id uuid/bigint
key string not null
version int not null
tenant_id nullable
actor_type string nullable
actor_id string nullable
record_type string nullable
record_id string nullable
params map not null default {}
snapshot map not null default {}
idempotency_key string nullable
state enum: created, planned, partial, completed, cancelled
trace map/jsonb
inserted_at, updated_at
unique(tenant_id, idempotency_key) where idempotency_key is not null
index(tenant_id, key, inserted_at)
index(record_type, record_id)
```

### `notify_notifications`

Per-recipient in-app item.

```text
id uuid/bigint
event_id fk notify_events
recipient_type string not null
recipient_id string not null
tenant_id nullable
priority enum/int default normal
data map not null default {}
rendered map nullable
seen_at utc_datetime nullable
read_at utc_datetime nullable
archived_at utc_datetime nullable
deleted_at utc_datetime nullable
inserted_at, updated_at
unique(event_id, recipient_type, recipient_id)
index(tenant_id, recipient_type, recipient_id, read_at, inserted_at)
```

### `notify_deliveries`

One channel delivery, individual or bulk.

```text
id uuid/bigint
event_id fk notify_events
notification_id fk notify_notifications nullable for bulk
recipient_type/id nullable for individual denormalized
channel string not null
provider string nullable
mode enum: individual, bulk
state enum: planned, enqueued, sending, succeeded, failed, suppressed, cancelled, expired
suppression_reason string nullable
scheduled_at utc_datetime nullable
started_at utc_datetime nullable
completed_at utc_datetime nullable
queue string nullable
priority int nullable
max_attempts int default 3
attempts_count int default 0
idempotency_key string not null
route map nullable redacted
payload_hash string nullable
payload_snapshot map nullable redacted
last_error map nullable redacted
ttl_seconds int nullable
collapse_key string nullable
trace map/jsonb
inserted_at, updated_at
unique(idempotency_key)
index(state, scheduled_at)
index(channel, provider, state)
```

### `notify_delivery_attempts`

Provider call attempts.

```text
id uuid/bigint
delivery_id fk notify_deliveries
attempt_no int not null
state enum: started, succeeded, failed
provider_message_id string nullable
request_id string nullable
request_hash string nullable
response_status int nullable
response_headers map redacted
error map redacted
duration_ms int nullable
started_at, completed_at
unique(delivery_id, attempt_no)
```

### `notify_preferences`

User/org notification settings.

```text
id uuid/bigint
subject_type string not null
subject_id string not null
tenant_id nullable
key string nullable          # notification key or topic; null can mean global/channel default
channel string nullable      # null can mean all channels
enabled boolean not null default true
frequency enum: instant, digest, never
quiet_hours map nullable     # timezone, start, end, weekdays
rules map not null default {}
inserted_at, updated_at
unique(tenant_id, subject_type, subject_id, key, channel)
```

### `notify_device_tokens`

Push route state.

```text
id uuid/bigint
recipient_type/id
tenant_id nullable
platform enum: ios, android, web
provider string
raw_token encrypted or external secret reference
token_hash string not null
last_success_at nullable
last_failure_at nullable
invalidated_at nullable
invalid_reason string nullable
metadata map
inserted_at, updated_at
unique(provider, token_hash)
```

### `notify_webhook_endpoints` / `notify_webhook_subscriptions`

For outbound webhooks and provider callbacks.

### `notify_audit_logs`

Admin actions: requeue, cancel, suppress, config change, preference override.

---

## 8. Policy and preferences

Policy should be composable and explainable.

Decision shape:

```elixir
{:send, opts}
{:delay, DateTime.t(), reason}
{:digest, digest_key, reason}
{:suppress, reason}
{:escalate, next_channel, reason}
```

Policy inputs:

- notification key/version/topic
- recipient and tenant
- channel/provider
- priority/urgency
- user/org preferences
- quiet hours/timezone
- frequency caps
- digest settings
- route availability
- prior deliveries/read state
- legal unsubscribe/suppression state

Default policy sequence:

1. Validate recipient route exists for channel.
2. Check hard suppressions: unsubscribed, invalid token, missing consent, bounced email, stopped SMS.
3. Check notification/channel preferences.
4. Check quiet hours. If low priority, delay or digest; if critical, send.
5. Check frequency cap/digest grouping.
6. Check channel-specific fallback/escalation rules.
7. Return decision with trace.

Important: store both the decision and the reason. Admin UI should show: “Email suppressed because user disabled `comment.created` email on 2026-04-22.”

---

## 9. Channel/adapters strategy

### Adapter behaviour

```elixir
defmodule NotifyKit.Adapter do
  @callback channel() :: atom()
  @callback provider() :: atom()
  @callback validate_config(keyword()) :: :ok | {:error, [String.t()]}
  @callback validate_payload(NotifyKit.Payload.t()) :: :ok | {:error, term()}
  @callback deliver(NotifyKit.Delivery.t(), keyword()) ::
              {:ok, NotifyKit.ProviderResponse.t()}
              | {:error, NotifyKit.ProviderError.t()}
end
```

ProviderError must classify:

```text
:retryable
:rate_limited
:invalid_route
:auth_error
:payload_invalid
:provider_unavailable
:permanent_failure
:unknown
```

### Email / Swoosh

- Use Swoosh `Email` structs or functions returning `%Swoosh.Email{}`.
- Provide Local/Test/Sandbox integration like Swoosh.
- Validate mailer module and URL host config.
- Store provider options in redacted payload snapshot.
- Support attachments by reference, not by dumping into notification payload.

### Push / Pigeon + Web Push

Expose platform fields explicitly:

```elixir
deliver :push,
  ttl: [hours: 4],
  collapse_key: "post:#{post.id}:comments",
  priority: :normal,
  apns: [interruption_level: :active],
  fcm: [analytics_label: "comment_created"]
```

Defaults:

- Critical/chat-like messages: non-collapsible, shorter TTL, high priority only when justified.
- Sync/update pings: collapsible, normal priority.
- Always handle invalid/expired tokens.
- Never promise “delivered to user,” only “accepted by provider” unless provider/device delivery receipts exist.

### SMS / WhatsApp

- Treat SMS as expensive and legally sensitive.
- Require explicit channel consent/preference by default.
- Add STOP/unsubscribe callback handling.
- Rate-limit per tenant and per recipient.
- Use `twilio_elixir` or direct Req adapter behind a behaviour; keep replaceable.

### Slack/Teams/Discord/chat

- Support individual and bulk modes.
- Bulk route often belongs to team/org, not user.
- Include threading keys and dedupe keys.
- Use simple Block Kit or plain message renderer first; avoid owning a full chat templating DSL early.

### Webhooks

- Must include signing, idempotency key, retry policy, replay protection guidance.
- Log request/response redacted.
- Support endpoint-level subscriptions and per-event filters.

---

## 10. Admin UI / Phoenix UX

Goal: native Phoenix control plane for notifications. Think LiveDashboard/Oban Web for notification traces, not generic CRUD.

Mount:

```elixir
# router.ex
scope "/admin" do
  pipe_through [:browser, :require_admin]
  live_notify_kit "/notifications",
    otp_app: :my_app,
    repo: MyApp.Repo,
    auth: {MyAppWeb.AdminAuth, :authorize_notify_kit}
end
```

Fail closed in prod if no auth configured.

### Pages

| Page | Purpose |
|---|---|
| Overview | counts by state/channel/provider; recent failures; queue health; suppressions. |
| Events | search by key, recipient, record, actor, tenant, idempotency key. |
| Event trace | timeline: trigger -> recipients -> policy -> notifications -> deliveries -> attempts. |
| Deliveries | filter by failed/suppressed/scheduled/provider/channel. Bulk requeue/cancel. |
| Attempts | provider response details, redacted request/response, latency. |
| Inbox items | read/seen state for a recipient; manually mark read/unread if authorized. |
| Preferences | inspect/edit user/org preferences if app allows. |
| Device tokens | health, invalid tokens, last success/failure. |
| Templates/previews | render notification by channel/locale/recipient fixture. |
| Simulator | “What would happen if I triggered X for Y?” no-send dry run. |
| Provider config | validation status, missing env vars, sandbox/live mode. |
| Audit log | admin actions and security-sensitive changes. |

### “Why wasn’t this sent?”

This must be a first-class debug view.

Answer categories:

- Not triggered: no Event row.
- Triggered but no recipient: recipient resolver returned none.
- Recipient but no route: no email/phone/token/webhook route.
- Route but suppressed: preference, quiet hours, cap, invalid token, legal opt-out.
- Planned but not enqueued: transaction/config/Oban issue.
- Enqueued but not performed: queue paused, worker missing, schedule not due.
- Performed but failed: provider/auth/payload/rate limit.
- Provider accepted but user didn’t see it: push/email deliverability/OS/client issue.

---

## 11. Docs strategy

Docs should be path-based, not just API reference.

1. **Quickstart: Phoenix + Ecto + in-app only**
2. **Quickstart: add Swoosh email**
3. **Concepts: Event vs Notification vs Delivery vs Attempt**
4. **Concepts: channel vs provider vs route**
5. **Recipes**
   - in-app + delayed email if unread
   - per-channel preferences
   - Slack bulk alert
   - outbound webhook with signing
   - FCM/APNS push
   - Web Push
   - SMS with STOP handling
   - quiet hours
   - frequency caps
   - digests
   - multi-tenant app
   - Oban transactional enqueue
   - provider callback Plug
6. **Testing guide**
   - core unit tests
   - adapter contract tests
   - Mox behaviours
   - Bypass provider simulators
   - Swoosh Test/Sandbox
   - Oban testing modes
   - Phoenix LiveView/admin tests
7. **Security/compliance guide**
   - PII redaction
   - token storage
   - unsubscribe
   - audit/retention
8. **Troubleshooting guide**
   - “why wasn’t this sent?” matrix
   - common config errors
   - provider status callback issues
9. **Upgrade guides**
   - migrations
   - key/version changes
   - adapter breaking changes
10. **LLM-friendly docs**
   - every guide has a “Copy as Markdown” style page
   - machine-readable examples
   - canonical module/file layout

---

## 12. Testing, CI/CD, and release discipline

### Test stack

- `mix format --check-formatted`
- `mix credo --strict`
- `mix dialyzer`
- `mix test --warnings-as-errors`
- ExUnit async where possible
- Mox for behaviours and explicit contracts
- Bypass for fake HTTP providers
- Swoosh Test/Sandbox for email
- Oban test mode and real Postgres integration tests
- Phoenix LiveView tests for admin/inbox
- Property tests for idempotency/state machine where useful

### Shared adapter contract tests

Every adapter must pass:

- validates config
- validates payload
- classifies errors correctly
- records attempt on success
- records attempt on failure
- redacts secrets
- respects idempotency key
- handles retryable vs permanent failures
- sandbox/fake mode works without internet

### E2E examples

Maintain example apps under `/examples`:

- `basic_phoenix_in_app`
- `phoenix_swoosh_email`
- `phoenix_oban_postgres`
- `phoenix_live_admin`
- `umbrella_app`
- `multi_tenant_prefixes`

Run at least smoke E2E in CI. Full provider E2E behind nightly/manual with sandbox credentials only.

### Compatibility policy

For v1, explicitly support:

- Elixir latest 2-3 minors, OTP 26+
- Ecto 3.x
- Phoenix 1.7/1.8 initially if feasible
- Oban 2.x
- PostgreSQL first; SQLite/MySQL only if Ecto/Oban support is clean

### Release process

- Semantic versioning.
- Changelog required.
- Release candidates for migration changes.
- Generated migrations never silently mutate existing tables.
- Adapter packages can version independently.
- Deprecate for at least one minor before removal.
- Publish HexDocs for every package.
- Include migration diff and rollback notes in release.

---

## 13. Personas and JTBD

### Personas

| Persona | Wants | Fears | Killer experience |
|---|---|---|---|
| Indie Phoenix SaaS builder | Add notifications fast without SaaS dependency. | Spending weeks wiring preferences/jobs/providers. | `mix notify_kit.install`, define notifier, see in-app + email preview same day. |
| Backend/staff engineer | Reliability, auditability, multi-tenancy, idempotency. | Duplicate sends, missing jobs, untraceable failures. | Delivery graph with DB constraints, Oban transactions, telemetry, requeue tools. |
| Product/customer success/admin | Understand and fix user notification issues. | “Customer says they never got it” with no evidence. | Admin trace answers exactly where it failed or why it was suppressed. |
| Frontend/LiveView/mobile dev | In-app feed, realtime badge, push token lifecycle. | Ambiguous read state and token bugs. | Drop-in LiveView components + token APIs + explicit read/seen semantics. |
| OSS maintainer/contributor | Small core, clear contracts, easy adapter contributions. | Dependency bloat and untestable provider integrations. | Adapter behaviour + contract tests + sandbox providers. |
| Compliance/security reviewer | Consent, unsubscribe, PII controls, audit. | Secrets/PII in logs or uncontrolled SMS/email. | Redaction, retention, opt-out, signed webhooks, audit log. |

### Jobs to be done

- When a domain event happens, notify the right people on the right channels without duplicating routing logic.
- When a notification fails, know why and retry safely without double-sending.
- When users change preferences, enforce them consistently across email/SMS/push/in-app.
- When a recipient has not read an in-app notification, escalate to another channel after a delay.
- When building locally, preview notifications without sending real messages.
- When writing tests, assert notification intent without hitting providers.
- When operating production, inspect queues, failures, suppressed deliveries, and provider responses.
- When migrating notification code, preserve old data and avoid breaking historical records.
- When adding a new provider, implement one behaviour and run shared adapter tests.

---

## 14. MVP -> advanced roadmap

### M0 — Project skeleton and spec

Deliverables:

- repo + umbrella/monorepo structure
- `PROJECT.md`, `REQUIREMENTS.md`, `ROADMAP.md`
- architecture decision records
- package naming finalization
- CI skeleton

### M1 — Core + Ecto + in-app

Deliverables:

- `NotifyKit.Notifier` behaviour
- stable keys/versions
- event + notification schemas/migrations
- `trigger/3`
- recipient resolution
- in-app channel
- read/seen/archive APIs
- telemetry basics
- generator: install + notifier
- tests + docs quickstart

Acceptance:

- Fresh Phoenix app can install, define one notifier, trigger it, query recipient inbox, mark read.

### M2 — Swoosh email + preview/testing

Deliverables:

- Swoosh adapter
- email render contract
- delayed email if unread
- Local/Test/Sandbox integration
- mailbox/admin preview
- URL config validation

Acceptance:

- In-app notification appears immediately; email sends after delay only if unread.

### M3 — Oban durable dispatch

Deliverables:

- Oban workers
- transactional enqueue
- delivery + attempt schemas
- retries/backoff
- idempotency constraints
- queue config
- failed/requeue APIs

Acceptance:

- Event + notification + delivery jobs commit atomically; failed provider call records attempt and can be retried.

### M4 — Phoenix LiveView inbox + admin

Deliverables:

- `live_notify_kit` router macro
- recipient inbox component
- unread badge via PubSub
- admin event/delivery trace
- simulator/dry-run
- auth-required mount

Acceptance:

- Admin can answer “why wasn’t this sent?” for a failed/suppressed notification.

### M5 — Slack + webhook

Deliverables:

- Slack adapter, individual/bulk
- webhook adapter with signing/idempotency
- inbound provider callback Plug pattern
- rate limiting/backoff basics

### M6 — Push

Deliverables:

- Pigeon APNS/FCM adapter
- Web Push adapter
- device token schema/API
- invalid token cleanup
- TTL/collapse/priority config

### M7 — SMS/WhatsApp

Deliverables:

- Twilio adapter behind behaviour
- direct Req fallback option if desired
- STOP/unsubscribe callback
- per-recipient/channel consent
- SMS cost/rate-limit controls

### M8 — Preferences, digests, quiet hours, frequency caps

Deliverables:

- preference schema/API/UI
- digest scheduler
- quiet hours/timezone support
- frequency caps
- escalation policies

### M9 — Enterprise-grade polish

Deliverables:

- multi-tenant guides/prefixes
- retention/anonymization
- richer templates/previews
- OpenTelemetry integration
- provider health dashboard
- migration/version management tools

---

## 15. Recommended first vertical slice

Build the smallest vertical slice that proves the architecture:

```text
Phoenix app
  -> trigger CommentCreated
  -> Event row
  -> two recipient Notification rows
  -> in-app feed query
  -> PubSub/LiveView badge update
  -> delayed Swoosh email delivery via Oban
  -> user reads one notification before delay
  -> policy suppresses that email
  -> admin trace shows: suppressed because read_at present
```

Why this slice:

- Exercises Event vs Notification vs Delivery.
- Exercises idempotency and Oban scheduling.
- Exercises read-state fallback.
- Exercises Swoosh testing.
- Exercises Phoenix UI and admin trace.
- Avoids Twilio/push complexity until the core is proven.

---

## 16. Open decisions

| Decision | Recommendation |
|---|---|
| Single package or multi-package? | Monorepo with core + adapters. Provide `notify_kit_batteries` for easy install. |
| Oban required? | Not in core. Strongly recommended/default for production dispatch. |
| Phoenix required? | No. Phoenix package provides UI/router/inbox. |
| Ecto required? | For durable features, yes. Core can remain storage-agnostic enough for tests. |
| Stored templates vs code-first? | Start code-first. Add external/stored templates later behind renderer behaviour. |
| Persist rendered payload? | Hybrid default: store render snapshot/hash for audit; allow lazy render for dynamic content. |
| Polymorphic recipients? | Use `recipient_type/id` refs; allow apps to provide resolver modules. |
| Multi-tenancy style? | `tenant_id` columns from v1 plus Ecto prefix hooks. |
| Provider config style? | Structured config with validation. DSN optional, not primary. |
| Admin framework dependency? | Purpose-built LiveView dashboard first. Borrow Backpex-style extensibility but avoid generic CRUD dependency initially. |
| Name? | Avoid `Notifier` package name conflict with Oban.Notifier. Use something like `NotifyKit`, `SignalBox`, `NoticeKit`, `DispatchKit`, or `Bellwether`. |

---

## 17. GSD kickoff packet

GSD’s workflow emphasizes context engineering, requirements, research, phase plans, fresh execution contexts, atomic commits, and verification. Use this brief as seed context.

### Suggested project files

```text
PROJECT.md       <- vision, principles, domain model
RESEARCH.md      <- ecosystem scan + footguns
REQUIREMENTS.md  <- MVP/v1/v2 requirements
ROADMAP.md       <- phases M1-M9
STATE.md         <- current decisions and open questions
```

### Initial GSD phase

**Phase 1: Core + Ecto in-app notifications**

Scope:

- core behaviours
- stable key/version
- Ecto schemas/migrations for events and notifications
- trigger API
- recipient refs
- in-app renderer
- read/seen/archive APIs
- basic telemetry
- generator
- tests/docs

Out of scope:

- Oban
- Swoosh/email
- admin UI
- push/SMS/webhooks
- preferences UI
- digests

Acceptance criteria:

1. `mix notify_kit.install` adds config and migration.
2. `mix notify_kit.gen.notifier CommentCreated --key comment.created` creates a notifier skeleton and test.
3. App can trigger a notification with stable idempotency key.
4. Recipient inbox query returns newest-first items.
5. Mark seen/read/archive works.
6. Duplicate trigger with same idempotency key does not create duplicate notifications.
7. Telemetry emits event created and notification persisted.
8. Docs quickstart works in a generated Phoenix app.

### First AI coding prompt

```text
Use PROJECT.md and RESEARCH.md as authoritative context.
Create an implementation plan for Phase 1: Core + Ecto in-app notifications.
Output:
- assumptions
- module/file tree
- schemas and migrations
- public API
- generator behavior
- tests
- acceptance checklist
Do not implement yet. Keep the plan small enough for one fresh execution context.
```

---

## 18. Source map

Use these for citations, verification, and deeper reading.

### Elixir/Phoenix substrate

- Swoosh HexDocs: https://hexdocs.pm/swoosh/Swoosh.html  
  Notes: adapters, Local/Test/Sandbox, Recipient protocol, async/job guidance.
- Oban HexDocs: https://hexdocs.pm/oban/Oban.html  
  Notes: SQL-backed reliability, transactional enqueue, queues, observability.
- Oban unique jobs: https://hexdocs.pm/oban/unique_jobs.html  
  Notes: uniqueness only at insertion; not concurrency; race caveats.
- Pigeon HexDocs: https://hexdocs.pm/pigeon/  
  Notes: APNS/FCM/ADM push dispatch.
- Pigeon FCM: https://hexdocs.pm/pigeon/Pigeon.FCM.html  
  Notes: dispatcher setup and response/error fields.
- ExNudge: https://hexdocs.pm/ex_nudge/readme.html  
  Notes: Web Push RFC 8291/8292 and VAPID.
- WebPushEx: https://hexdocs.pm/web_push_ex/  
  Notes: RFC 8291 encryption, bring your own HTTP POST.
- web_push_elixir: https://github.com/midarrlabs/web-push-elixir  
  Notes: Web Push package, prerequisites, HTTP status handling.
- ex_twilio: https://hex.pm/packages/ex_twilio  
  Notes: older Twilio API library for Elixir.
- twilio_elixir: https://hex.pm/packages/twilio_elixir  
  Notes: 2026 OpenAPI-generated Twilio SDK for Elixir; community package.
- Twilio SDKs: https://www.twilio.com/docs/libraries  
  Notes: official server-side SDK languages and OpenAPI spec.
- vcf_notifier: https://hex.pm/packages/vcf_notifier/0.2.1  
  Notes: simple Oban notification queuing library.
- Phoenix LiveDashboard: https://hexdocs.pm/phoenix_live_dashboard/Phoenix.LiveDashboard.html  
  Notes: real-time monitoring/debugging pattern.
- Backpex: https://hexdocs.pm/backpex/  
  Notes: Phoenix LiveView admin panel, customizable CRUD.
- Kaffy: https://elixirforum.com/t/kaffy-a-quick-and-flexible-admin-interface-for-phoenix-applications/31355  
  Notes: out-of-box Phoenix admin interface goals.
- Mox: https://github.com/dashbitco/mox  
  Notes: explicit contracts and concurrent mocks.
- Req API client testing: https://dashbit.co/blog/req-api-client-testing  
  Notes: explicit contracts and HTTP client test patterns.

### Cross-framework notification references

- Noticed README: https://github.com/excid3/noticed/blob/main/README.md  
  Notes: Rails notification framework, delivery methods, fallback, DB records, rename footgun.
- Laravel notifications: https://laravel.com/docs/13.x/notifications  
  Notes: `via`, queues, per-channel queues, `shouldSend`, `afterSending`, on-demand routing.
- Symfony Notifier: https://symfony.com/doc/current/notifier.html  
  Notes: channels/transports abstraction.
- Symfony Chatters/Texters issue: https://github.com/symfony/symfony/issues/34544  
  Notes: naming confusion.
- Symfony DSN special characters: https://aksymfony.readthedocs.io/en/5.4/notifier.html  
  Notes: DSN escaping footgun.
- django-notifications-hq PyPI: https://pypi.org/project/django-notifications-hq/  
  Notes: read/unread/sent/deleted in-app model methods.
- django-notifications issues: https://github.com/django-notifications/django-notifications/issues  
  Notes: compatibility/migration maintenance issues.
- Novu GitHub: https://github.com/novuhq/novu  
  Notes: open-source notification infrastructure, inbox, preferences, digest, providers.

### Provider semantics / delivery footguns

- FCM collapsible/non-collapsible: https://firebase.google.com/docs/cloud-messaging/customize-messages/collapsible-message-types  
  Notes: no ordering guarantee, 100 non-collapsible limit, four collapse keys.
- FCM TTL: https://firebase.google.com/docs/cloud-messaging/customize-messages/setting-message-lifespan  
  Notes: TTL 0 to 2,419,200 seconds; default four weeks.
- FCM priority: https://firebase.google.com/docs/cloud-messaging/customize-messages/setting-message-priority  
  Notes: normal vs high priority.
- APNs notification requests: https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns  
  Notes: APNs storage/expiration behavior.
- APNs broadcast expiration: https://developer.apple.com/documentation/usernotifications/sending-broadcast-push-notification-requests-to-apns  
  Notes: expiration zero attempts once and does not store.

### Community signal / GSD

- HN Phoenix/Elixir gap comment: https://news.ycombinator.com/item?id=26153321  
  Notes: Rails has notification gems; Elixir lacks equivalent batteries.
- GSD GitHub: https://github.com/gsd-build/get-shit-done  
  Notes: context engineering, research/plan/execute/verify workflow, fresh contexts, atomic commits.
- GSD docs: https://gsd-build-get-shit-done.mintlify.app/introduction  
  Notes: discuss -> plan -> execute -> verify; structured planning files.
