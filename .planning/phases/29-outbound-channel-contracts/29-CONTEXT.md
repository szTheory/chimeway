# Phase 29: Outbound Channel Contracts - Context

**Gathered:** 2026-04-30 (assumptions mode + parallel ecosystem research)
**Status:** Ready for planning

<domain>
## Phase Boundary

Extend Chimeway's existing channel-typed render contract and adapter seam to first-class
support for `:sms`, `:push`, and a generic `:chat` channel, plus open a host-extensible
channel-render-module registry — without coupling durable rendering identity, persisted
delivery rows, or trace surfaces to specific vendor SDKs. Phase 29 also introduces
per-channel adapter MODULE resolution at the executor (today's single global `:adapter`
cannot satisfy success criterion #3) and persists adapter identity per delivery attempt
for operator visibility.

Out of scope for Phase 29: inbound webhook ingestion (Phase 30), outcome-driven workflow
progression (Phase 31), trace expansion for asynchronous callbacks (Phase 32), bundled
vendor adapters in core (host-app territory forever), and runtime A/B / failover adapter
resolution (a v1.5+ concern; the static channel→module map is the natural future fallback
implementation for any per-delivery resolver behaviour).

</domain>

<decisions>
## Implementation Decisions

### SMS render contract
- **D-01:** Ship `Chimeway.Rendering.Channels.Sms` as a first-class compiled clause in
  `Chimeway.Rendering.channel_module/1` using the existing Ecto.Changeset skeleton
  (`cast / validate_required / apply_action / stringify_keys`) from
  `lib/chimeway/rendering/channels/email.ex` and `.../in_app.ex`.
  Field shape:
  ```elixir
  @types %{text_body: :string}
  @required_fields [:text_body]
  ```
- **D-02:** SMS render contract MUST NOT include `from`, `to`, `phone_number`, sender ID,
  Messaging Service SID, `unicode` flag, or any vendor-shaped routing field. `from` is
  per-region adapter config (lives in `:channel_adapter_configs["sms"]`); `to` is
  recipient resolution. This matches Symfony `SmsMessage`, Laravel `VonageMessage`,
  Noticed Twilio (`Body` is the only render concern — `From` from credentials, `To` from
  recipient), Knock, and Novu unanimously.
- **D-03:** No GSM-7 / UCS-2 length validation in the changeset. No major framework
  enforces it; segmentation is a vendor concern. Document the 160 / 70 character reality
  in `@moduledoc`; do not enforce.
- **D-04:** No `media_url` / MMS support in Phase 29. Defer until a second SMS adapter
  data point exists — adding it now would bake Twilio's `num_media`/`media_url` shape
  into the durable contract before any portability check.

### Push render contract
- **D-05:** Ship `Chimeway.Rendering.Channels.Push` as a first-class compiled clause with
  the same Ecto.Changeset skeleton.
  Field shape:
  ```elixir
  @types %{title: :string, body: :string, data: :map}
  @required_fields [:title, :body]
  ```
- **D-06:** Single `:push` channel — adapters platform-translate the validated payload to
  APNs / FCM shape at delivery time. Do NOT split into `:push_ios` / `:push_android` at
  the public-channel level (no major library does this). Per-platform divergence belongs
  in either the host adapter or the opaque `data` map, never in `render_data` keys.
- **D-07:** Push render contract MUST NOT include `image_url`, `badge`, `sound`,
  `category`, `apns_topic`, `priority`, `collapse_id`, `expiration`, `push_type`,
  `device_token`, or `to`. APNs/FCM/Expo each shape these differently — Pigeon explicitly
  classifies them as platform plumbing. Plumbing is adapter-config or `data`-map
  territory, not durable render contract.
- **D-08:** `data` is validated only as `:map`, not a strict sub-shape. APNs/FCM/Expo all
  treat custom payloads as opaque key-value bags; strict typing would force callers to
  pre-declare every payload variant and fight platform portability. Keep it free.

### Generic Chat (`:chat`) channel
- **D-09:** Ship `Chimeway.Rendering.Channels.Chat` as a first-class compiled clause —
  CHAN-01's third example (Chat) is satisfied in core, not pushed back to host apps.
  Field shape:
  ```elixir
  @types %{text: :string, rich_payload: :map}
  @required_fields [:text]
  ```
  `text` (not `text_body`) matches Slack's native API; `rich_payload` is opaque for
  Slack `blocks`, Discord `embeds`, Teams Adaptive Cards, etc.
- **D-10:** `Channels.Chat` is the discoverable starter validator, NOT the only path. Host
  apps with vendor-specific shapes (Slack-only, Discord-only, in-house chat) plug their
  own validators via the registry seam (D-11..D-14) without touching `Channels.Chat`.

### Channel render-module extensibility (public API commitment)
- **D-11:** Ship a public behaviour `Chimeway.Rendering.Channel` with a single callback:
  ```elixir
  @callback validate(attrs :: map()) :: {:ok, map()} | {:error, Ecto.Changeset.t()}
  ```
  Plus a `use Chimeway.Rendering.Channel` macro that injects `@behaviour` and helpful
  defaults — Oban.Worker convention. All four built-in channels (`Email`, `InApp`,
  `Sms`, `Push`, `Chat` — actually five with Chat) refactor to declare the behaviour so
  the contract is enforced consistently.
- **D-12:** Open a config-keyed registry seam:
  ```elixir
  config :chimeway, :channel_render_modules, %{
    "slack"   => MyApp.Channels.Slack,
    "discord" => MyApp.Channels.Discord
  }
  ```
  `Chimeway.Rendering.channel_module/1` resolution order:
  1. registry lookup (`Application.get_env(:chimeway, :channel_render_modules, %{})`)
  2. compiled clauses (`email | in_app | sms | push | chat`)
  3. existing graceful fallback at `lib/chimeway/orchestration/delivery_planning.ex:438-446`
     (`render_data: %{}`)
- **D-13:** Validate the registry at boot via `Chimeway.Application.start/2` —
  every value MUST `Code.ensure_loaded?/1` AND export `validate/1` (matching the
  behaviour). Boot fails loud on typo'd module names, mirroring Bamboo's
  `handle_config/1` discipline. Avoids Laravel's `toXyz()` magic-method silent typos and
  Noticed's late-binding class-name footgun.
- **D-14:** Emit `:telemetry` event `[:chimeway, :rendering, :channel_unregistered]`
  with `%{channel: channel_string}` measurements + a `Logger.warning/1` the first time
  an unknown channel hits the graceful fallback. Operators promote-to-error in their
  config if they want strictness. Avoids Symfony's "first transport wins by default"
  silent-misconfig footgun.

### Per-channel adapter module resolution
- **D-15:** Add a new compile-time config key `:channel_adapters` shaped as
  `%{String.t() => module()}`, mirroring the proven `:channel_adapter_configs` resolver
  pattern at `lib/chimeway/dispatch/channel_adapter_config.ex:17-22`:
  ```elixir
  config :chimeway, :channel_adapters, %{
    "email" => MyApp.SwooshChimewayAdapter,
    "sms"   => MyApp.TwilioChimewayAdapter,
    "push"  => MyApp.FcmChimewayAdapter
  }
  ```
- **D-16:** `Chimeway.Adapter` behaviour stays unchanged. Single `c:deliver/2` callback
  returning `{:ok, meta} | {:error, kind, detail}`. Do NOT introduce per-channel
  behaviours (`Adapter.Sms`, `Adapter.Push`) — that would invite per-channel callback
  divergence and contradict Phase 21 D-08 (adapters are dumb transport seams).
- **D-17:** Resolution lives at `Chimeway.Dispatch.Executor.run_delivery/1` (the only
  call site that today reads the global `:adapter`). Resolver:
  ```elixir
  defp resolve_adapter(channel) when is_binary(channel) do
    Map.get(Application.get_env(:chimeway, :channel_adapters, %{}), channel)
    || Application.get_env(:chimeway, :adapter, Chimeway.Adapters.Logger)
  end
  ```
  Atom-safe (atoms come from `config.exs`, never runtime channel strings — Phase 11
  discipline preserved).
- **D-18:** Backwards-compat: existing `:adapter` config keeps working unchanged as the
  fallback for any unmapped channel. NO deprecation in v1.4. `:adapter` is documented as
  "default for unmapped channels" — useful forever for single-channel hosts. Mirrors
  Symfony's `default_transport` after introducing per-type maps.
- **D-19:** Emit `:telemetry` event `[:chimeway, :dispatch, :adapter_fallback]` with
  `%{channel: channel, fallback: module}` ONLY when both `:channel_adapters` is set AND
  the lookup misses (signal of likely misconfiguration). Silent fallback when only the
  legacy `:adapter` is configured (no signal of misconfig in that case).

### Adapter visibility on attempts (operator trace surface)
- **D-20:** Add column `chimeway_delivery_attempts.adapter_module :string`. Stored as
  `inspect(module)` string (e.g. `"MyApp.TwilioChimewayAdapter"`), NEVER as an atom on
  the wire or in DB — Oban `from_string` discipline applied to write-side. Atoms exist
  only in code.
- **D-21:** Per-attempt, NOT per-delivery — adapter can change across retries (failover,
  mid-incident reconfig, host config reload). `Delivery.metadata` and
  `Delivery.planning_context` stay reserved for notifier-author and orchestration-
  reasoning territory respectively (Phase 21 D-10, D-11). Layer cleanliness is
  preserved.
- **D-22:** `Chimeway.Traces.explain/2` per-attempt rendering MUST include
  `via {adapter_module}` so success criterion #3 ("delivery engine correctly routes
  payloads to the specified non-email adapter") becomes directly assertable from a trace
  dump. Add `:adapter_module` to `[:chimeway, :dispatch, :delivery, :stop]` telemetry
  metadata so dashboards can break failure rate down by vendor.

### Test ergonomics for multi-adapter
- **D-23:** `Chimeway.Adapters.Test` tags messages with `delivery.channel` on send so
  per-channel assertions are trivial:
  ```elixir
  assert_receive {:chimeway_delivery, "sms", %Delivery{}}
  ```
  Existing tests that assert on the global mailbox update to the channel-tagged shape.
  Avoids Swoosh's mailer-tagging retrofit pain.

### Preview surface (no API changes)
- **D-24:** `Chimeway.Rendering.Preview.preview/3` and `Mix.Tasks.PreviewRendering`
  already accept arbitrary channel strings (preview.ex:55-67 normalizes any binary; the
  Mix task's `--channel` flag is already `:string`). No code changes to either surface.
  Phase 29 only EXTENDS `test/chimeway/rendering/channel_contract_test.exs` with
  round-trip cases for `Sms`, `Push`, `Chat`, plus one registry-overlay case proving
  host-defined channels resolve correctly. Reuses the existing in-app and email test
  shape verbatim.

### Style and contract enforcement
- **D-25:** All five built-in render-channel modules use `Ecto.Changeset` validators with
  the existing `cast / validate_required / apply_action / stringify_keys` skeleton. NO
  switch to `defstruct`+pattern matching. Swoosh uses `defstruct` because its struct is
  a runtime transport message; Chimeway's render contract is a persistence-boundary
  validator producing JSONB-shaped maps that round-trip across Oban worker boundaries.
  Changeset is the idiomatic Elixir fit for that role.

### Claude's Discretion
- Exact atom name for the `Chimeway.Rendering.Channel` macro callbacks in
  `__using__/1` (so long as it injects `@behaviour Chimeway.Rendering.Channel` and
  surfaces `@impl true` warnings on typo'd callback names — Oban.Worker convention).
- Whether the registry validation lives in `Chimeway.Application.start/2`,
  `Chimeway.Rendering.__after_compile__/2`, or a dedicated `Rendering.Registry.warmup/0`
  helper — pick the most testable seam.
- Exact telemetry event measurements/metadata maps for the two new events
  (`channel_unregistered`, `adapter_fallback`), so long as they include the channel
  string and (where applicable) the resolved module identity.
- Migration ordering for the new `chimeway_delivery_attempts.adapter_module` column —
  add nullable, backfill not required (existing attempts predate the feature; trace
  rendering SHOULD show `via (unknown adapter)` or skip the line for null rows).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone and phase scope
- `.planning/ROADMAP.md` — Phase 29 goal, dependency, success criteria, milestone v1.4
  context (`Channel Feedback Loops`).
- `.planning/REQUIREMENTS.md` — `CHAN-01` and `CHAN-02` (the only requirements in
  Phase 29 scope).
- `.planning/PROJECT.md` — local-first ownership, no-vendor-lock-in, durable identity,
  explainability as core value, milestone v1.4 direction.
- `.planning/METHODOLOGY.md` — `Cohesive Recommendation Default`,
  `One-Shot Recommendation Bias`, `Research-First Decision Ownership`,
  `Durable Explainability Bias`, `Least-Surprise DX Default` lenses applied throughout
  this CONTEXT.

### Project research baseline
- `.planning/research/ARCHITECTURE.md` — adapter-seam-not-vendor-SDK posture; render
  identity separated from notifier identity.
- `.planning/research/STACK.md` — Elixir vendor-library landscape (`twilio_elixir`,
  `pigeon`, `slack_elixir`); host-side dependencies, never core.
- `.planning/research/FEATURES.md` — channel breadth notes; `Unified Inbox / Chat UI`
  listed as anti-feature (we satisfy CHAN-01 without becoming a Chat product).
- `.planning/research/PITFALLS.md` — content/module coupling warnings; preview paths
  bypassing real rendering contracts.

### Prior phase carry-forward decisions (read these for the locked design constraints)
- `.planning/phases/21-template-versioning-rendering-contracts/21-CONTEXT.md` —
  D-06 (channels stay explicit and typed), D-08 (adapters are dumb transport seams,
  must NOT call back into renderers), D-11 (planning_context is orchestration-only),
  D-12 (preview output matches dispatch output via shared pipeline). All five
  built-in render-channel modules in Phase 29 inherit this posture.
- `.planning/phases/21-template-versioning-rendering-contracts/21-RESEARCH.md` — render
  identity research baseline.
- `.planning/STATE.md` — accumulated decisions across phases 10-28, including the
  Phase 11 string-safe adapter-lookup decision that constrains D-15..D-19.

### Existing source files (read these — they ARE the templates)
- `lib/chimeway/rendering.ex` — `channel_module/1` at lines 230-232 (extension point);
  `normalize_declaration/1` at lines 114-129 (already accepts arbitrary channel strings).
- `lib/chimeway/rendering/channels/email.ex` — exact template shape for the new SMS,
  Push, Chat validators (~40 LOC each).
- `lib/chimeway/rendering/channels/in_app.ex` — alternative template with nested
  validation (skip for the new flat-shape channels; keep the nested pattern reserved
  for InApp's `primary_action`).
- `lib/chimeway/rendering/preview.ex` — preview pipeline, already channel-agnostic.
- `lib/chimeway/notifier.ex` — `channels/2` and `rendering/2` callbacks, already
  accept arbitrary channel strings (notifier.ex:22).
- `lib/chimeway/adapter.ex` — adapter behaviour, stays unchanged.
- `lib/chimeway/adapters/logger.ex` and `lib/chimeway/adapters/test.ex` — existing
  bare-bones adapter implementations; `Test` gets the channel-tagging update per D-23.
- `lib/chimeway/dispatch/executor.ex` — line 31 is the single resolution site that
  Phase 29 extends per D-15..D-19.
- `lib/chimeway/dispatch/channel_adapter_config.ex` — sibling string-safe resolver
  pattern that `:channel_adapters` mirrors exactly.
- `lib/chimeway/orchestration/delivery_planning.ex` — graceful-fallback path at
  lines 438-446 that absorbs unknown channels with empty `render_data` (third
  layer in the channel_module/1 resolution chain per D-12).
- `lib/chimeway/delivery.ex` — `render_data` field on the canonical delivery row.
- `lib/chimeway/traces.ex` — explanation surface that gains
  `via {adapter_module}` per D-22.
- `lib/mix/tasks/preview_rendering.ex` — Mix task, no API changes (already accepts
  `--channel` as `:string`).

### Existing tests (read for the test posture to extend)
- `test/chimeway/rendering/channel_contract_test.exs` — round-trip test pattern for
  `Email` and `InApp`; Phase 29 extends with `Sms`, `Push`, `Chat`, plus one
  registry-overlay case.
- `test/chimeway/integration/delivery_lifecycle_test.exs` — line 182 already exercises
  `["webhook_partner"]` as a host-defined channel string; this confirms the seam
  Phase 29 formalizes via the registry.
- `test/chimeway/rendering/render_identity_integration_test.exs` — render identity
  end-to-end coverage; Phase 29 extends with the new channels.

### Ecosystem references for field-shape and pattern justification
- Symfony Notifier — `SmsMessage` and `PushMessage` field shapes (D-01..D-08, D-12).
- Laravel Notifications + `laravel-notification-channels/fcm` — `VonageMessage` and
  `FcmNotification` minimalism (D-01..D-08).
- Noticed (Rails) — Twilio + FCM delivery method message hashes; render-vs-resolve
  split (D-02, D-07).
- Pigeon (Elixir) — APNS/FCM `Notification` structs; explicit content-vs-plumbing
  classification (D-07).
- Knock + Novu — payload shape and recipient-resolution-vs-template-content
  separation (D-02, D-07).
- Swoosh + Bamboo — adapter behaviour pattern; backwards-compat lessons (D-15..D-18).
- Phoenix.PubSub + Tesla + Phoenix.Endpoint — Elixir-native config-keyed adapter
  resolution precedent (D-15..D-17).
- Oban.Worker — `Module.safe_concat/1` and `from_string/1` string-safe module
  resolution discipline (D-20).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Chimeway.Rendering.Channels.Email` and `Chimeway.Rendering.Channels.InApp`: the
  exact templates to copy. ~40-70 LOC each. New `Sms`, `Push`, `Chat` modules will
  reuse the `cast / validate_required / apply_action / stringify_keys` skeleton.
- `Chimeway.Rendering.normalize_declaration/1`: already accepts arbitrary channel
  strings — no change needed for the new channels.
- `Chimeway.Dispatch.ChannelAdapterConfig.resolve/2`: the sibling pattern that
  `:channel_adapters` resolution mirrors exactly. Atom-safe by construction.
- `Chimeway.Adapters.Test`: existing test mailbox; gets a one-line update to tag
  messages with `delivery.channel` per D-23.
- `Chimeway.Rendering.Preview.preview/3` and `Mix.Tasks.PreviewRendering`: zero API
  changes; already channel-string-agnostic.
- Existing graceful fallback at `delivery_planning.ex:438-446` (`render_data: %{}`):
  becomes the third layer of `channel_module/1` resolution after registry + compiled
  clauses (D-12).

### Established Patterns
- **Channel-typed render contracts** (Phase 21 D-06): one Ecto.Changeset validator per
  channel, producing a stringified map. Phase 29 adds three more channels in this
  shape.
- **Adapters are dumb transport seams** (Phase 21 D-08): consume pre-rendered
  `render_data`, never re-enter rendering. Per-channel adapter MODULE resolution
  (D-15..D-19) preserves this — adapters get the right validated payload because
  rendering happened upstream at planning time.
- **String-safe resolver pattern** (Phase 11): channel strings stay strings; module
  values come from `config.exs` so atoms are compile-time constants. Both new
  resolvers (`:channel_render_modules`, `:channel_adapters`) follow this pattern.
- **Durable identity over module names**: `render_module` per delivery is queryable
  via the registry/compiled-clause resolution; `adapter_module` per attempt is
  persisted as a string column (NOT an atom). Operator can answer "which validator
  ran?" / "which adapter ran?" from one query without loading host source.
- **Telemetry on misconfig** (`channel_unregistered`, `adapter_fallback`): silent
  fallback creates Symfony-style "first transport wins" footguns. Both new resolvers
  emit telemetry on the unhappy path so operators see drift.

### Integration Points
- `Chimeway.Rendering.channel_module/1` (rendering.ex:230-232) — gains registry-overlay
  resolution as the new layer 1 (compiled clauses become layer 2; graceful fallback
  remains layer 3).
- `Chimeway.Dispatch.Executor.run_delivery/1` (executor.ex:31) — gains
  `resolve_adapter/1` per D-17 and persists `adapter_module` on the attempt row per
  D-20.
- `Chimeway.Application.start/2` — gains a registry-validation pass per D-13 (boot
  fails loud on typo'd module names).
- `Chimeway.Traces.explain/2` — per-attempt rendering gains `via {adapter_module}`
  per D-22.
- `chimeway_delivery_attempts` schema migration — adds nullable `adapter_module`
  string column per D-20.
- `test/chimeway/rendering/channel_contract_test.exs` — extended with three new
  built-in channels plus one registry-overlay case.

</code_context>

<specifics>
## Specific Ideas

- Copy Symfony's separation: framework core defines content shape (`SmsMessage`,
  `PushMessage`); transports translate to vendor wire format. Chimeway's render
  contract = SmsMessage-equivalent (content only); adapters = transports.
- Copy Noticed's defaulting model: render concern = `Body`/`title`/`body`; credentials
  / sender = adapter config; recipient identity = recipient resolution. Three layers,
  not collapsed.
- Copy Pigeon's classification: APNs/FCM "plumbing" fields (`apns_topic`, `priority`,
  `collapse_id`, `expiration`, `push_type`) are adapter concerns. Pigeon got this
  right; Chimeway mirrors it.
- Copy Bamboo/Swoosh's adapter-behaviour-with-config-validation pattern, but at
  one-level-lower granularity (channel rather than mailer). Shared lineage,
  tighter fit for Chimeway's central dispatcher.
- Copy Oban.Worker's `use ... + @behaviour + @impl` macro convention for
  `Chimeway.Rendering.Channel` so host-author typos surface as compile-time warnings.
- Avoid Laravel's `toXyz()` magic-method dispatch — silent typos are a documented
  footgun. Explicit registry lookup + boot-time validation makes typos crash loud.
- Avoid Symfony's bridge-package ceiling — every new channel category requires a
  Symfony-published bridge. Chimeway's runtime registry sidesteps this for embedded
  use.
- Avoid Knock/Novu's SaaS control-plane assumption — embedded host apps must own
  their channel config. The registry is `config :chimeway, :channel_render_modules`,
  not a runtime mutation API.

</specifics>

<deferred>
## Deferred Ideas

- **Per-delivery adapter resolution behaviour** (`Chimeway.AdapterResolver` with
  `c:resolve(delivery) :: module()`) — needed if/when host apps want per-tenant,
  per-region, or A/B adapter routing. The static `:channel_adapters` map is the
  natural default implementation a future resolver behaviour would fall back to.
  Defer to v1.5 or later when there's real demand.
- **Adapter failover / round-robin operators** — Symfony composes these on top of
  its static transport map. Same future story for Chimeway.
- **MMS / `media_url` in SMS contract** — single-vendor (Twilio) data point today;
  add when a second SMS adapter exists to validate the shape.
- **Push `image_url`, action buttons, `category`** — APNs needs Notification Service
  Extension on-device; FCM has `notification.image`; Expo has `richContent`. Three
  shapes, no portable contract yet. Either keep in `data` or revisit when the
  ecosystem converges.
- **Per-platform push channels** (`:push_ios` / `:push_android`) — only worth doing
  if host apps need per-platform render-version divergence. Workaround for now: host
  app defines its own channel strings via the registry.
- **Bundled vendor adapters in core** (`Chimeway.Adapters.Twilio`,
  `Chimeway.Adapters.Pigeon`) — out of scope FOREVER per PROJECT.md no-vendor-lock-in
  constraint. Host-app territory.
- **Inbound webhook ingestion**, **outcome-driven workflow progression**, **trace
  expansion for asynchronous callbacks** — Phases 30, 31, 32 respectively (this
  milestone).

</deferred>

---

*Phase: 29-outbound-channel-contracts*
*Context gathered: 2026-04-30*
