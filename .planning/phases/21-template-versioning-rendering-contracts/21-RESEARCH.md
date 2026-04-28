# Phase 21: Template Versioning & Rendering Contracts - Research

**Researched:** 2026-04-28
**Domain:** Durable notification rendering contracts for Elixir/Ecto notification pipelines
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Chimeway should persist a stable, per-channel rendering identity on the canonical
  `chimeway_deliveries` row using `render_key` plus `render_version`, separate from
  `notification_key` plus notifier version and never derived from notifier module names.
- **D-02:** `render_key` should be string-based and channel-scoped, for example
  `comment.created.email` or `comment.created.in_app`, so channel copy/layout can evolve without
  forcing unrelated channel version bumps.
- **D-03:** Chimeway should not introduce a full template registry or hosted-style template
  publication lifecycle in Phase 21. That would overbuild the milestone and pull the library
  toward a SaaS-shaped product model too early.
- **D-04:** Chimeway should keep trigger-time durable input capture, but `Notifier.build/2` should
  become a compatibility seam rather than the long-term rendering contract.
- **D-05:** The durable input contract should shift to explicit structured assigns plus
  notifier-declared rendering identity, while channel-specific renderer behaviours produce validated
  output payloads before delivery.
- **D-06:** Channel renderers should stay explicit and typed by channel responsibility rather than
  collapsing all channels into one generic metadata map. At minimum, `:in_app` and `:email` should
  have distinct validated output contracts in this phase.
- **D-07:** Phoenix-oriented rendering tools such as HEEx, `Phoenix.Template`, and
  `Phoenix.Swoosh` are good host-app implementation details, especially for email, but they should
  sit behind Chimeway renderer behaviours instead of becoming the core public API of the library.
- **D-08:** Outbound adapters must remain dumb transport seams. They should continue to receive
  pre-rendered delivery content and must not call back into notifiers or renderer modules at
  delivery time.
- **D-09:** Structured render inputs should persist once on the durable notification record, while
  channel-specific rendered outputs should materialize onto the delivery row before dispatch so the
  canonical delivery remains the explainable per-channel execution artifact.
- **D-10:** `Notification.metadata` may remain as a compatibility projection for existing in-app
  behavior during migration, but Phase 21 should treat it as a derived storage shape, not the
  primary rendering contract.
- **D-11:** `Delivery.planning_context` must not become the rendering contract. It remains reserved
  for orchestration reasoning, not content identity or rendered payload storage.
- **D-12:** Rendering must not recompute from mutable host data inside adapters or queue workers.
  The render artifact used for preview, tests, and dispatch should be the same validated production
  path output.
- **D-13:** The canonical developer surface for TMPL-03 should be a pure library preview/render API
  that returns stable preview structs and reuses the same render pipeline that dispatch uses.
- **D-14:** A Mix task should exist only as a convenience wrapper over that library API. It should
  not define different semantics or construct a fake rendering path of its own.
- **D-15:** Phoenix LiveDashboard or browser-based preview UI should not be the primary Phase 21
  surface. If added later, it should live in an optional Phoenix integration package and call the
  same core preview API.
- **D-16:** Snapshot and file-based verification are useful secondary techniques for CI and review,
  but they should complement the canonical preview/test API rather than replace it.
- **D-17:** Phase 21 should add shared contract tests for renderer behaviours and notifier content
  declarations, plus integration tests that prove preview output matches the rendered delivery
  payload used for dispatch.
- **D-18:** Validation must happen on explicit runtime payload shapes, not only through
  compile-time Phoenix component attribute warnings. Chimeway should use changesets or equivalent
  explicit validators for channel render outputs.
- **D-19:** Preview and render surfaces must remain inspectable and developer-friendly without
  leaking sensitive payload fields. Render artifacts should favor stable semantic fields over
  opaque or transport-specific blobs.

### Claude's Discretion
- Exact field/module names for render identity and renderer behaviours.
- Whether structured render inputs live in new dedicated notification columns or a validated map on
  the notification row, as long as the durable contract remains explicit and testable.
- Whether email renderer output is normalized into dedicated delivery columns, a validated
  `render_data` map, or a hybrid, as long as the adapter contract stays explicit and explainable.
- Exact Mix task flags and preview output formats, provided they are thin wrappers over the same
  production render pipeline.

### Deferred Ideas (OUT OF SCOPE)
- Hosted-style template registry tables, publish/promote lifecycle, and UI-managed template editing.
- A first-party LiveDashboard or browser preview UI in the core library.
- Broad cross-channel editor UX or workflow-builder surfaces similar to Knock or Novu.
- Provider breadth expansion beyond the current outbound seam; orchestration and rendering contracts
  remain the higher-leverage work.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TMPL-01 | Notification content can be versioned independently from notifier module names so rendering changes remain durable and traceable. | Persist `render_key` + `render_version` on `chimeway_deliveries`, keep `notification_key` separate, and avoid deriving durable identity from module names. [VERIFIED: 21-CONTEXT.md] |
| TMPL-02 | Channel-specific rendering contracts are explicit and testable, including structured assigns for in-app and outbound channels. | Use validated structured assigns on notifications plus channel-specific renderer behaviours with Ecto/NimbleOptions-backed runtime validation. [VERIFIED: 21-CONTEXT.md] [CITED: https://hexdocs.pm/ecto/Ecto.Changeset.html] [CITED: https://hexdocs.pm/nimble_options/NimbleOptions.html] |
| TMPL-03 | Developers can preview or verify rendered notification content before provider delivery. | Add a library preview API that runs the same production renderer path and expose a Mix task as a thin wrapper. [VERIFIED: 21-CONTEXT.md] [VERIFIED: codebase grep] |
</phase_requirements>

## Summary

Phase 21 should extend Chimeway's existing durable lifecycle rather than bolt on a template system. The current code persists `Notification.metadata` at trigger time through `Notifier.build/2`, copies that map onto `Delivery.metadata` during planning, and expects adapters to consume already-populated delivery content. That means the clean insertion points are already present: capture structured render inputs in `Chimeway.Trigger`, materialize validated channel output in `Chimeway.DeliveryPlanning`, and keep adapters renderer-agnostic. [VERIFIED: codebase grep]

The most plan-worthy architectural decision is to separate the rendering contract into three durable layers: notification-level `render_assigns`, delivery-level `render_key` plus `render_version`, and delivery-level validated `render_data`. Ecto embedded or schemaless changesets are the right runtime validation tool for both assigns and per-channel output; Phoenix component attrs are useful inside host-app rendering code, but Phoenix docs explicitly note those validations are compile-time warnings and not runtime enforcement. [CITED: https://hexdocs.pm/ecto/Ecto.Schema.html] [CITED: https://hexdocs.pm/ecto/embedded-schemas.html] [CITED: https://hexdocs.pm/ecto/Ecto.Changeset.html] [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html]

For email-like rendering, keep Phoenix/Swoosh as an optional host-app implementation detail behind Chimeway behaviours. `Phoenix.Swoosh.render_body/3` renders HTML and text bodies onto a `Swoosh.Email`, and `Swoosh.Email` remains the standard Elixir struct for subject plus body composition, but the current Chimeway repo has no Phoenix or Swoosh dependency, so the core phase plan should keep those integrations optional and testable through pure Elixir renderer contracts. [CITED: https://hexdocs.pm/phoenix_swoosh/Phoenix.Swoosh.html] [CITED: https://hexdocs.pm/swoosh/Swoosh.Email.html] [VERIFIED: mix.exs]

**Primary recommendation:** Implement a core render pipeline that persists notification `render_assigns`, writes delivery `render_key`/`render_version`/validated `render_data`, and exposes a preview API that reuses the exact same rendering path as dispatch. [VERIFIED: 21-CONTEXT.md] [VERIFIED: codebase grep]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Structured render input capture at trigger time | API / Backend | Database / Storage | `Chimeway.Trigger` already inserts notifications once per recipient, so render inputs should be normalized there and persisted on the notification row. [VERIFIED: codebase grep] |
| Durable per-channel render identity | API / Backend | Database / Storage | The library decides identity, but the canonical persisted artifact must live on `chimeway_deliveries` per D-01/D-09. [VERIFIED: 21-CONTEXT.md] [VERIFIED: codebase grep] |
| Channel-specific output validation and materialization | API / Backend | Database / Storage | `Chimeway.DeliveryPlanning` is already the fanout choke point before dispatch and is the right place to turn assigns into validated `render_data`. [VERIFIED: codebase grep] |
| Adapter transport delivery | API / Backend | — | The adapter behaviour explicitly requires pre-rendered delivery content and forbids rendering inside adapters. [VERIFIED: codebase grep] |
| Preview and verification API | API / Backend | — | The phase context requires a pure library API and the current public API has no preview surface yet, so Phase 21 should add one here. [VERIFIED: 21-CONTEXT.md] [VERIFIED: codebase grep] |
| Optional HEEx / Phoenix mail rendering | Frontend Server (SSR) | API / Backend | Phoenix rendering belongs in host-app or optional integration code, not in the Chimeway core contract. [VERIFIED: 21-CONTEXT.md] [CITED: https://hexdocs.pm/phoenix_swoosh/Phoenix.Swoosh.html] |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Ecto / Ecto.Changeset | `3.13.5` published 2025-11-09 / `3.13.5` published 2026-03-03 [VERIFIED: hex.pm api] | Validate structured assigns and per-channel render payloads with embedded or schemaless changesets. [CITED: https://hexdocs.pm/ecto/Ecto.Schema.html] [CITED: https://hexdocs.pm/ecto/Ecto.Changeset.html] | Chimeway already uses Ecto pervasively, and Ecto docs support embedded schemas plus schemaless changesets with `apply_action/2` for runtime validation without forcing new dependencies. [VERIFIED: mix.exs] [CITED: https://hexdocs.pm/ecto/embedded-schemas.html] [CITED: https://hexdocs.pm/ecto/Ecto.Changeset.html] |
| NimbleOptions | `1.1.1` published 2024-05-25 [VERIFIED: hex.pm api] | Validate renderer options and preview command options with explicit error messages and generated docs/typespecs. [CITED: https://hexdocs.pm/nimble_options/NimbleOptions.html] | The project already depends on NimbleOptions, so renderer option contracts can stay explicit without inventing custom option validators. [VERIFIED: mix.exs] [CITED: https://hexdocs.pm/nimble_options/NimbleOptions.html] |
| PostgreSQL JSON/map columns via Ecto | Existing project storage [VERIFIED: codebase grep] | Store `render_assigns` on notifications and `render_data` on deliveries without creating template-registry tables. [VERIFIED: 21-CONTEXT.md] | Existing notification and delivery schemas already persist `:map` fields, which makes validated map-backed contracts a lower-risk fit than new registry tables or channel-specific relational sprawl. [VERIFIED: codebase grep] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Swoosh | `1.25.0` published 2026-04-02 [VERIFIED: hex.pm api] | Standard Elixir email struct for `subject`, `html_body`, and `text_body`. [CITED: https://hexdocs.pm/swoosh/Swoosh.Email.html] | Use in host apps or an optional Chimeway Phoenix integration package for `:email` renderer output; do not add it as a hard Phase 21 core dependency unless the repo intentionally expands core scope. [VERIFIED: mix.exs] [CITED: https://hexdocs.pm/swoosh/Swoosh.Email.html] |
| Phoenix.Swoosh | `1.2.1` published 2025-05-13 [VERIFIED: hex.pm api] | Render email templates into `html_body` and `text_body` from explicit templates and assigns. [CITED: https://hexdocs.pm/phoenix_swoosh/Phoenix.Swoosh.html] | Use only behind Chimeway renderer behaviours for host-app email rendering and preview; keep it optional because the current core repo has no Phoenix dependency. [VERIFIED: mix.exs] [CITED: https://hexdocs.pm/phoenix_swoosh/Phoenix.Swoosh.html] |
| Phoenix.Component attrs | LiveView docs current, runtime note verified [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html] | Compile-time documentation and warnings for HEEx-facing component assigns. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html] | Use inside optional Phoenix renderers, but never treat attr declarations as the only render contract validation because Phoenix docs say they do not validate at runtime. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Ecto embedded/schemaless changesets for payload validation | Ad hoc map validation helpers | Faster initially, but weaker error reporting, weaker composition, and less alignment with the project's existing validation style. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/ecto/Ecto.Changeset.html] |
| Channel-specific renderer behaviours | One generic `metadata` map contract | Simpler to sketch, but it directly conflicts with D-06 and weakens explainability, adapter clarity, and contract tests. [VERIFIED: 21-CONTEXT.md] |
| Optional Phoenix/Swoosh integration | Hard Phoenix dependency in core | Easier email demos, but it violates the local core-lib boundary already established by project constraints and mix dependencies. [VERIFIED: AGENTS.md] [VERIFIED: mix.exs] |

**Installation:** No new core dependency is required for the recommended Phase 21 contract. [VERIFIED: mix.exs]

Optional Phoenix email integration surface:

```elixir
{:swoosh, "~> 1.25"}
{:phoenix_swoosh, "~> 1.2"}
```

These should live in a host app or optional integration package, not in the core phase plan by default. [VERIFIED: mix.exs] [CITED: https://hexdocs.pm/phoenix_swoosh/Phoenix.Swoosh.html]

## Architecture Patterns

### System Architecture Diagram

Recommended data flow for Phase 21. The diagram reflects the current lifecycle seams plus the new render contract boundaries. [VERIFIED: codebase grep] [VERIFIED: 21-CONTEXT.md]

```text
Trigger params + recipient
        |
        v
Notifier content declaration
  - notification_key / version
  - render identity declaration per channel
  - structured render_assigns
        |
        v
Chimeway.Trigger
  persist Notification.render_assigns once
  keep Notification.metadata as compatibility projection only
        |
        v
Chimeway.DeliveryPlanning
  create per-channel Delivery rows
  -> pick renderer by channel
  -> validate output contract
  -> persist render_key / render_version / render_data on delivery
        |
        +------------------------------+
        |                              |
        v                              v
Preview API                      Dispatch path
same renderer call               Adapter.deliver/2
same validated output            consumes pre-rendered delivery only
        |                              |
        v                              v
Preview struct                    DeliveryAttempt + Traces
```

### Recommended Project Structure
```text
lib/
├── chimeway/rendering/                 # Core render pipeline, preview API, behaviour contracts
├── chimeway/rendering/channels/        # Channel-specific validated output structs/changesets
├── chimeway/rendering/preview.ex       # Pure preview API and result structs
├── chimeway/notifier.ex                # New rendering declaration callbacks + build/2 compatibility
├── chimeway/trigger.ex                 # Persist structured render inputs once
└── chimeway/delivery_planning.ex       # Materialize validated render output before dispatch
```

### Pattern 1: Persist Structured Assigns Once Per Notification
**What:** Add a dedicated notification-level render input field such as `render_assigns` and validate it with an embedded or schemaless changeset before persistence. Keep `Notification.metadata` as a derived compatibility projection only during migration. [VERIFIED: 21-CONTEXT.md] [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/ecto/embedded-schemas.html]
**When to use:** For all notifiers, regardless of channel count, because the phase context explicitly wants one durable input capture and per-channel output materialization later. [VERIFIED: 21-CONTEXT.md]
**Example:**
```elixir
# Source: https://hexdocs.pm/ecto/Ecto.Changeset.html
types = %{
  title: :string,
  body: :string,
  actor_name: :string
}

def validate_assigns(params) do
  {%{}, types}
  |> Ecto.Changeset.cast(params, Map.keys(types))
  |> Ecto.Changeset.validate_required([:title, :body])
  |> Ecto.Changeset.apply_action(:insert)
end
```

### Pattern 2: Use One Renderer Behaviour Per Channel Contract
**What:** Define channel-specific renderer behaviours that receive durable inputs plus render identity and return validated output structs or maps, for example an in-app contract and an email contract. [VERIFIED: 21-CONTEXT.md]
**When to use:** Always for `:in_app` and `:email` in this phase; custom channels can follow the same contract later. [VERIFIED: 21-CONTEXT.md]
**Example:**
```elixir
# Source: https://hexdocs.pm/ecto/Ecto.Changeset.html
defmodule EmailOutput do
  import Ecto.Changeset

  @types %{subject: :string, html_body: :string, text_body: :string}

  def validate(attrs) do
    {%{}, @types}
    |> cast(attrs, Map.keys(@types))
    |> validate_required([:subject])
    |> apply_action(:insert)
  end
end
```

### Pattern 3: Preview Through the Production Renderer Path
**What:** Expose a preview function that invokes the same channel renderer and returns a stable preview struct containing render identity plus validated output. The Mix task should call only this API. [VERIFIED: 21-CONTEXT.md]
**When to use:** For local development, contract tests, snapshot tests, and regression checks for changed copy or layouts. [VERIFIED: 21-CONTEXT.md]
**Example:**
```elixir
# Source: https://hexdocs.pm/ecto/Ecto.Changeset.html
with {:ok, assigns} <- validate_assigns(raw_assigns),
     {:ok, render_data} <- EmailOutput.validate(renderer.(assigns)) do
  {:ok, %{render_key: render_key, render_version: version, render_data: render_data}}
end
```

### Anti-Patterns to Avoid
- **Rendering from adapters or workers:** The adapter contract explicitly says content must already be on the delivery, and D-08/D-12 reject mutable late rendering. [VERIFIED: codebase grep] [VERIFIED: 21-CONTEXT.md]
- **Using `planning_context` for content:** `planning_context` is already reserved for orchestration reasoning and trace explanation, not template identity or payload storage. [VERIFIED: 21-CONTEXT.md] [VERIFIED: codebase grep]
- **Treating Phoenix component attrs as runtime validation:** Phoenix docs say attrs provide compile-time warnings and no runtime validation. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html]
- **Introducing a registry/publish lifecycle now:** D-03 and the deferred list explicitly keep hosted-style template management out of scope. [VERIFIED: 21-CONTEXT.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Runtime payload validation | Custom nested map walkers | Ecto embedded or schemaless changesets | Ecto already supports embedded schemas, schemaless casts, and `apply_action/2`, which keeps errors uniform with the rest of the codebase. [CITED: https://hexdocs.pm/ecto/embedded-schemas.html] [CITED: https://hexdocs.pm/ecto/Ecto.Changeset.html] |
| Renderer option validation | Manual keyword parsing | NimbleOptions schemas | NimbleOptions already exists in the repo and provides validated options, generated docs, and typespec support. [VERIFIED: mix.exs] [CITED: https://hexdocs.pm/nimble_options/NimbleOptions.html] |
| Email composition struct | Bespoke `%Email{}` format | `Swoosh.Email` behind an optional renderer seam | Swoosh is the ecosystem-standard email struct and already models `subject`, `html_body`, and `text_body`. [CITED: https://hexdocs.pm/swoosh/Swoosh.Email.html] |
| Preview-only rendering path | Separate fake preview renderer | Preview API that calls the production render pipeline | Reusing the render pipeline is a locked phase decision and avoids preview/dispatch drift. [VERIFIED: 21-CONTEXT.md] |

**Key insight:** This phase is mostly about better contract boundaries, not more rendering technology. The project already has the right lifecycle seams; the work is to validate and persist the right artifacts at those seams. [VERIFIED: codebase grep]

## Common Pitfalls

### Pitfall 1: Leaving durable input capture inside `Notifier.build/2`
**What goes wrong:** Render inputs stay opaque and coupled to legacy `metadata`, making channel-specific validation and preview harder. [VERIFIED: codebase grep]
**Why it happens:** `Trigger.notifications_attrs/4` currently persists only the result of `notifier.build/2` into `Notification.metadata`. [VERIFIED: codebase grep]
**How to avoid:** Introduce a dedicated render-input contract and keep `build/2` as a migration bridge only. [VERIFIED: 21-CONTEXT.md]
**Warning signs:** New code keeps branching on raw `metadata` keys inside planning or adapters. [VERIFIED: codebase grep]

### Pitfall 2: Materializing render output too late
**What goes wrong:** Dispatch, preview, and trace surfaces can diverge because workers or adapters reconstruct content from mutable host state. [VERIFIED: 21-CONTEXT.md]
**Why it happens:** Late rendering feels convenient when adapters already see the delivery, but it breaks explainability and replay guarantees. [VERIFIED: 21-CONTEXT.md]
**How to avoid:** Render and validate inside `DeliveryPlanning` before adapter dispatch. [VERIFIED: codebase grep] [VERIFIED: 21-CONTEXT.md]
**Warning signs:** Adapter code starts depending on notifier modules, view modules, or request-scoped host data. [VERIFIED: codebase grep]

### Pitfall 3: Replacing explicit channel contracts with one generic blob
**What goes wrong:** `:in_app` and `:email` payloads become harder to validate, test, evolve, and explain. [VERIFIED: 21-CONTEXT.md]
**Why it happens:** A single `map()` looks flexible, especially during migration. [VERIFIED: codebase grep]
**How to avoid:** Keep distinct renderer output validators for each channel, even if both persist into a shared `render_data` column. [VERIFIED: 21-CONTEXT.md] [CITED: https://hexdocs.pm/ecto/Ecto.Changeset.html]
**Warning signs:** Contract tests can only assert presence of generic keys like `"body"` or `"content"`. [ASSUMED]

### Pitfall 4: Leaking rendered content into telemetry or operator logs
**What goes wrong:** Sensitive or high-volume body content appears in logs or telemetry metadata. [VERIFIED: AGENTS.md] [VERIFIED: codebase grep]
**Why it happens:** Preview and rendering work naturally introduces fields like `body`, `template`, and URLs that are easy to over-log. [VERIFIED: codebase grep]
**How to avoid:** Keep render artifacts off telemetry metadata and preserve the current safe logging posture that logs identity fields, not payload blobs. [VERIFIED: codebase grep]
**Warning signs:** New telemetry stop metadata includes keys similar to `body`, `content`, `template`, or `url`, which existing tests already treat as PII-risk indicators. [VERIFIED: codebase grep]

## Code Examples

Verified patterns from official sources:

### Schemaless Runtime Validation
```elixir
# Source: https://hexdocs.pm/ecto/Ecto.Changeset.html
types = %{
  name: :string,
  role: Ecto.ParameterizedType.init(Ecto.Enum, values: [:reader, :editor, :admin])
}

changeset =
  {%{}, types}
  |> Ecto.Changeset.cast(%{name: "Callum", role: "reader"}, Map.keys(types))
  |> Ecto.Changeset.validate_required([:name, :role])

{:ok, validated} = Ecto.Changeset.apply_action(changeset, :insert)
```

### Embedded Schema Validation
```elixir
# Source: https://hexdocs.pm/ecto/embedded-schemas.html
schema "users" do
  embeds_one :profile, Profile do
    field :online, :boolean
    field :visibility, Ecto.Enum, values: [:public, :private, :friends_only]
  end
end
```

### Optional Email Rendering with Phoenix.Swoosh
```elixir
# Source: https://hexdocs.pm/phoenix_swoosh/Phoenix.Swoosh.html
new()
|> subject("Hello, Avengers!")
|> render_body("welcome.html", %{username: user.email})
```

### Email Composition with Swoosh.Email
```elixir
# Source: https://hexdocs.pm/swoosh/Swoosh.Email.html
new()
|> subject("Hello, Avengers!")
|> html_body("<h1>Hello</h1>")
|> text_body("Hello")
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `Notifier.build/2` returns a free-form metadata map that is persisted on notifications and copied to deliveries. [VERIFIED: codebase grep] | Persist structured notification assigns once, then materialize channel-specific validated output plus render identity on deliveries. [VERIFIED: 21-CONTEXT.md] | Project recommendation solidified for Phase 21 on 2026-04-28. [VERIFIED: 21-CONTEXT.md] | Rendering changes become durable, previewable, and channel-explicit without tying history to notifier module names. [VERIFIED: 21-CONTEXT.md] |
| Preview would have to inspect metadata or call ad hoc renderer code because no preview API exists yet. [VERIFIED: codebase grep] | Add a pure preview API that reuses the production render path and return stable preview structs. [VERIFIED: 21-CONTEXT.md] | Phase 21 planning target as of 2026-04-28. [VERIFIED: 21-CONTEXT.md] | TMPL-03 can be tested directly and safely without browser-only tooling. [VERIFIED: 21-CONTEXT.md] |
| Phoenix template helpers could be mistaken for the render contract itself. [ASSUMED] | Keep Phoenix/HEEx as host implementation details behind Chimeway behaviours. [VERIFIED: 21-CONTEXT.md] | Project-level rendering guidance documented before Phase 21. [VERIFIED: .planning/research/STACK.md] | Core stays framework-light while remaining Phoenix-compatible. [VERIFIED: .planning/research/STACK.md] |

**Deprecated/outdated:**
- Using `Notification.metadata` as the primary render contract is outdated for this phase, though it remains a migration compatibility projection. [VERIFIED: 21-CONTEXT.md] [VERIFIED: codebase grep]
- Relying on compile-time component attr warnings as the only validation layer is outdated for Chimeway's runtime contract needs. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Contract tests will become too generic if output validation stops at presence-only map keys. | Common Pitfalls | Low; it affects test sharpness more than architecture. |
| A2 | Phoenix template helpers are the most likely host-side implementation detail for email rendering. | State of the Art | Low; the core contract still stays behaviour-based either way. |

## Open Questions (RESOLVED)

1. **Should `render_assigns` be a dedicated notification column or remain inside a validated map field name chosen for Phase 21?**
   Resolution: Phase 21 will add one dedicated `render_assigns` map column on `chimeway_notifications` and treat it as the explicit durable render-input contract. Do not add extra normalized notification content columns in this phase; keep additional normalization for a later phase only if query pressure emerges. This is the least surprising fit for D-05, D-09, and the current notification schema shape. [VERIFIED: 21-CONTEXT.md] [VERIFIED: codebase grep]

2. **Should `:email` render output live entirely inside `render_data`, or split key fields into first-class columns later?**
   Resolution: Phase 21 will keep `:email` output inside validated delivery-level `render_data`, with semantic keys such as `subject`, `html_body`, and `text_body`, and will not add dedicated delivery body columns now. If a later analytics or operator phase needs direct SQL filtering on rendered output facts, that phase can add derived columns without changing the Phase 21 contract. This aligns with D-08, D-09, D-12, and the milestone focus on durable contracts plus preview parity rather than analytics. [VERIFIED: 21-CONTEXT.md]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | Core phase implementation | ✓ | `1.19.5` [VERIFIED: environment probe] | — |
| Mix | Migrations, tests, Mix preview task | ✓ | `1.19.5` [VERIFIED: environment probe] | — |
| PostgreSQL server | Ecto-backed contract and migration testing | ✓ | `14.17` local server responds on `localhost:5432` [VERIFIED: environment probe] | Use Docker `postgres:15` to match CI/project baseline. [VERIFIED: CI workflow grep] [VERIFIED: environment probe] |
| Docker | Matching PostgreSQL 15 locally when needed | ✓ | `29.4.0` client [VERIFIED: environment probe] | — |
| Phoenix / Swoosh deps in this repo | Optional email renderer integration | ✗ in current core repo [VERIFIED: mix.exs] | — | Keep core tests on pure Elixir renderers; add Phoenix/Swoosh only in a host app or optional integration package. [VERIFIED: mix.exs] [VERIFIED: 21-CONTEXT.md] |

**Missing dependencies with no fallback:**
- None for the core Phase 21 contract. The phase can be implemented and tested without Phoenix/Swoosh in the library repo. [VERIFIED: mix.exs] [VERIFIED: 21-CONTEXT.md]

**Missing dependencies with fallback:**
- Phoenix/Swoosh are absent from the repo, but the fallback is intentional: validate the core renderer behaviour with pure maps/changesets and keep Phoenix rendering optional. [VERIFIED: mix.exs] [VERIFIED: 21-CONTEXT.md]

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit with `Chimeway.DataCase` sandbox helpers and optional `Oban.Testing`. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/oban/Oban.Testing.html] |
| Config file | `test/test_helper.exs` and `test/support/data_case.ex` (no separate `pytest`-style config file). [VERIFIED: codebase grep] |
| Quick run command | `mix test test/chimeway/notifier_contract_test.exs` |
| Full suite command | `mix ci.test` [VERIFIED: mix.exs] [VERIFIED: CI workflow grep] |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TMPL-01 | Delivery persists `render_key` and `render_version` independently from notifier module/version identity. [VERIFIED: 21-CONTEXT.md] | integration | `mix test test/chimeway/rendering/render_identity_integration_test.exs` | ❌ Wave 0 |
| TMPL-02 | `:in_app` and `:email` renderers validate explicit input/output contracts and reject invalid payload shapes. [VERIFIED: 21-CONTEXT.md] | unit | `mix test test/chimeway/rendering/channel_contract_test.exs` | ❌ Wave 0 |
| TMPL-03 | Preview API returns the same render artifact used for dispatch materialization. [VERIFIED: 21-CONTEXT.md] | integration | `mix test test/chimeway/rendering/preview_pipeline_test.exs` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `mix test test/chimeway/rendering/channel_contract_test.exs`
- **Per wave merge:** `mix test test/chimeway/notifier_contract_test.exs test/chimeway/rendering/preview_pipeline_test.exs`
- **Phase gate:** `mix ci.test`

### Wave 0 Gaps
- [ ] `test/chimeway/rendering/channel_contract_test.exs` — covers TMPL-02 renderer behaviour validation.
- [ ] `test/chimeway/rendering/render_identity_integration_test.exs` — covers TMPL-01 persistence contract.
- [ ] `test/chimeway/rendering/preview_pipeline_test.exs` — covers TMPL-03 preview/dispatch equivalence.
- [ ] Extend `test/chimeway/notifier_contract_test.exs` to cover the new notifier rendering declaration seam. [VERIFIED: codebase grep]

## Security Domain

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Host app owns auth boundaries; Chimeway core preview/render API is library code, not an auth surface. [VERIFIED: AGENTS.md] |
| V3 Session Management | no | No session layer is introduced by this phase. [VERIFIED: codebase grep] |
| V4 Access Control | no in core | If a future Phoenix preview UI is added, it must live outside core in host-authenticated integration code per D-15. [VERIFIED: 21-CONTEXT.md] |
| V5 Input Validation | yes | Use Ecto changesets for render inputs/outputs and NimbleOptions for renderer/task options. [CITED: https://hexdocs.pm/ecto/Ecto.Changeset.html] [CITED: https://hexdocs.pm/nimble_options/NimbleOptions.html] |
| V6 Cryptography | no | This phase does not introduce cryptographic requirements; it should continue using existing platform primitives if encryption-at-rest is later needed. [VERIFIED: codebase grep] |

### Known Threat Patterns for this stack
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Rendered body leakage into telemetry or logs | Information Disclosure | Preserve `Telemetry.safe_meta/1`, keep logger adapters identity-only, and avoid emitting `render_data` on telemetry spans. [VERIFIED: codebase grep] |
| Late re-render from mutable host state | Tampering | Materialize render output before dispatch and pass adapters only canonical delivery content. [VERIFIED: 21-CONTEXT.md] [VERIFIED: codebase grep] |
| Channel payload shape drift across preview and dispatch | Tampering | Reuse one render pipeline and validate both preview and dispatch outputs through the same changesets. [VERIFIED: 21-CONTEXT.md] [CITED: https://hexdocs.pm/ecto/Ecto.Changeset.html] |

## Sources

### Primary (HIGH confidence)
- `21-CONTEXT.md` - locked decisions, discretion, deferred scope, and canonical Phase 21 contract. [VERIFIED: 21-CONTEXT.md]
- Local code inspection across `lib/chimeway/notifier.ex`, `trigger.ex`, `delivery.ex`, `delivery_planning.ex`, `adapter.ex`, `dispatch/executor.ex`, `traces.ex`, and existing tests. [VERIFIED: codebase grep]
- Ecto docs - embedded schemas and changesets for runtime validation: https://hexdocs.pm/ecto/Ecto.Schema.html, https://hexdocs.pm/ecto/embedded-schemas.html, https://hexdocs.pm/ecto/Ecto.Changeset.html [CITED]
- NimbleOptions docs - option schema validation and docs/typespec generation: https://hexdocs.pm/nimble_options/NimbleOptions.html [CITED]
- Phoenix docs - component attrs are compile-time oriented and not runtime validation: https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html [CITED]
- Phoenix.Swoosh docs - `render_body/3` renders email templates into HTML/text bodies: https://hexdocs.pm/phoenix_swoosh/Phoenix.Swoosh.html [CITED]
- Swoosh docs - `Swoosh.Email` composition for subject/html/text bodies: https://hexdocs.pm/swoosh/Swoosh.Email.html [CITED]
- Hex.pm package API - current package versions and publish dates for `ecto`, `ecto_sql`, `nimble_options`, `oban`, `phoenix_swoosh`, and `swoosh`. [VERIFIED: hex.pm api]

### Secondary (MEDIUM confidence)
- Existing project research docs in `.planning/research/STACK.md`, `ARCHITECTURE.md`, and `PITFALLS.md` confirming pre-Phase-21 direction. [VERIFIED: .planning/research/*.md]

### Tertiary (LOW confidence)
- None beyond items explicitly listed in the Assumptions Log.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - core recommendations rely on existing project deps plus current official docs for Ecto, NimbleOptions, and optional Phoenix/Swoosh integration. [VERIFIED: mix.exs] [CITED: https://hexdocs.pm/ecto/Ecto.Changeset.html]
- Architecture: HIGH - the recommended pipeline aligns tightly with locked phase decisions and already-existing lifecycle seams in the codebase. [VERIFIED: 21-CONTEXT.md] [VERIFIED: codebase grep]
- Pitfalls: HIGH - the major failure modes are directly evidenced by the current metadata/planning split and the repo's existing payload-redaction posture. [VERIFIED: codebase grep] [VERIFIED: AGENTS.md]

**Research date:** 2026-04-28
**Valid until:** 2026-05-28
