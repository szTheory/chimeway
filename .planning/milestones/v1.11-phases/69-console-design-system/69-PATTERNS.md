# Phase 69: Console Design System - Pattern Map

**Mapped:** 2026-06-04
**Files analyzed:** 17 new/modified files
**Analogs found:** 17 / 17

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `chimeway_admin/priv/static/chimeway_admin.css` | config/design-system asset | transform | `chimeway_admin/priv/static/chimeway_admin.css` | exact |
| `chimeway_admin/assets/css/chimeway_admin.css` | config/source-copy asset | file-I/O | `chimeway_admin/assets/css/chimeway_admin.css` | exact |
| `chimeway_admin/lib/chimeway_admin/components/layout.ex` | component | request-response | `chimeway_admin/lib/chimeway_admin/components/layout.ex` | exact |
| `chimeway_admin/lib/chimeway_admin/components/core.ex` | component | request-response | `chimeway_admin/lib/chimeway_admin/components/core.ex` | exact |
| `chimeway_admin/lib/chimeway_admin/components/status.ex` | component | transform | `chimeway_admin/lib/chimeway_admin/components/status.ex` | exact |
| `chimeway_admin/lib/chimeway_admin/components/timeline_event.ex` | component | transform | `chimeway_admin/lib/chimeway_admin/components/timeline_event.ex` | role-match |
| `chimeway_admin/lib/chimeway_admin/live/dashboard_live.ex` | live_view/component consumer | request-response | `chimeway_admin/lib/chimeway_admin/live/dashboard_live.ex` | exact |
| `chimeway_admin/lib/chimeway_admin/live/trace_search_live.ex` | live_view/component consumer | event-driven | `chimeway_admin/lib/chimeway_admin/live/trace_search_live.ex` | exact |
| `chimeway_admin/lib/chimeway_admin/live/trace_detail_live.ex` | live_view/component consumer | request-response | `chimeway_admin/lib/chimeway_admin/live/dashboard_live.ex` | role-match |
| `chimeway_admin/lib/chimeway_admin/live/feed_live.ex` | live_view/component consumer | event-driven | `chimeway_admin/lib/chimeway_admin/live/trace_search_live.ex` | role-match |
| `chimeway_admin/lib/chimeway_admin/live/definitions_live.ex` | live_view/component consumer | request-response | `chimeway_admin/lib/chimeway_admin/live/dashboard_live.ex` | role-match |
| `chimeway_admin/lib/chimeway_admin/live/health_live.ex` | live_view/component consumer | request-response | `chimeway_admin/lib/chimeway_admin/live/dashboard_live.ex` | role-match |
| `chimeway_admin/lib/chimeway_admin/live/recovery_live.ex` | live_view/component consumer | event-driven | `chimeway_admin/lib/chimeway_admin/live/trace_search_live.ex` | role-match |
| `chimeway_admin/test/chimeway_admin/design_system_test.exs` | test | transform | `chimeway_admin/test/chimeway_admin/routes_test.exs` + `chimeway_admin/lib/chimeway_admin/assets.ex` | role-match |
| `chimeway_admin/test/chimeway_admin/live/design_system_live_test.exs` | test | request-response | `chimeway_admin/test/chimeway_admin/live/trace_search_live_test.exs` | exact |
| `examples/chimeway_demo_host/lib/demo_host_web/endpoint.ex` | config | file-I/O | `examples/chimeway_demo_host/lib/demo_host_web/endpoint.ex` | exact |
| `examples/chimeway_demo_host/lib/demo_host_web/layouts/root.html.heex` | component/template | request-response | `examples/chimeway_demo_host/lib/demo_host_web/layouts/root.html.heex` | exact |

## Pattern Assignments

### `chimeway_admin/priv/static/chimeway_admin.css` (config/design-system asset, transform)

**Analog:** `chimeway_admin/priv/static/chimeway_admin.css`

**Layer and token pattern** (lines 1-34):

```css
@layer cw.tokens, cw.base, cw.layout, cw.components, cw.utilities;

@layer cw.tokens {
  :where(.chimeway-admin) {
    --cw-ink: #102027;
    --cw-night: #07131a;
    --cw-paper: #fffdf8;
    --cw-porcelain: #f7f4ea;
    --cw-line: #d8d3c7;
    --cw-muted: #5e6b72;
    --cw-teal: #0e7c86;
    --cw-blue: #2d6cdf;
    --cw-brass: #d6a84f;
    --cw-mint: #9adbcf;
    --cw-violet: #6d5df6;
    --cw-success: #0b7a50;
    --cw-warning: #8a5a00;
    --cw-danger: #b83232;
    --cw-code: #0b1720;

    --cw-admin-bg: var(--cw-paper);
    --cw-admin-panel: #ffffff;
    --cw-admin-panel-soft: var(--cw-porcelain);
    --cw-admin-fg: var(--cw-ink);
    --cw-admin-muted: var(--cw-muted);
    --cw-admin-border: var(--cw-line);
    --cw-admin-accent: var(--cw-teal);
    --cw-admin-focus: var(--cw-blue);
    --cw-admin-shadow: 0 16px 42px rgb(16 32 39 / 0.08);
    --cw-admin-radius: 8px;
    --cw-admin-radius-sm: 5px;
    --cw-admin-transition: 140ms ease-out;
```

**Theme pattern** (lines 37-63):

```css
:where(.chimeway-admin[data-cw-theme="dark"]) {
  --cw-admin-bg: var(--cw-night);
  --cw-admin-panel: #10232c;
  --cw-admin-panel-soft: #0b1b23;
  --cw-admin-fg: #fffdf8;
  --cw-admin-muted: #b8c5c9;
  --cw-admin-border: #29414a;
  --cw-admin-accent: var(--cw-mint);
  --cw-admin-focus: var(--cw-brass);
  --cw-admin-shadow: 0 18px 50px rgb(0 0 0 / 0.35);
  color-scheme: dark;
}

@media (prefers-color-scheme: dark) {
  :where(.chimeway-admin[data-cw-theme="system"]) {
    --cw-admin-bg: var(--cw-night);
    --cw-admin-panel: #10232c;
    --cw-admin-panel-soft: #0b1b23;
```

**Responsive layout pattern** (lines 115-196):

```css
@layer cw.layout {
  .cw-shell {
    display: grid;
    grid-template-columns: minmax(14rem, 17rem) minmax(0, 1fr);
    gap: 0;
    min-height: 100vh;
  }

  .cw-main {
    display: grid;
    gap: 1rem;
    align-content: start;
    padding: clamp(1rem, 3vw, 2rem);
    max-width: 86rem;
    width: 100%;
  }

  .cw-page-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 1rem;
    margin-bottom: 0.5rem;
  }
```

**Shared primitive styling pattern** (lines 303-399):

```css
.cw-button {
  display: inline-flex;
  justify-content: center;
  align-items: center;
  min-height: 2.5rem;
  border: 1px solid transparent;
  border-radius: var(--cw-admin-radius-sm);
  padding: 0.55rem 0.8rem;
  font-weight: 650;
  text-decoration: none;
  transition: transform var(--cw-admin-transition), background var(--cw-admin-transition), border-color var(--cw-admin-transition);
}

.cw-search-form {
  display: grid;
  grid-template-columns: minmax(10rem, 14rem) minmax(14rem, 1fr) minmax(12rem, 18rem) auto;
  gap: 0.75rem;
  align-items: end;
}
```

**Long-content and reduced-motion pattern** (lines 493-645):

```css
.cw-table-wrap {
  overflow-x: auto;
}

.cw-table {
  width: 100%;
  border-collapse: collapse;
  min-width: 42rem;
}

.cw-summary-list dd,
.cw-timeline__details dd {
  margin: 0;
  min-width: 0;
  overflow-wrap: anywhere;
}

@layer cw.utilities {
  @media (prefers-reduced-motion: reduce) {
    :where(.chimeway-admin *) {
      animation-duration: 0.001ms !important;
      animation-iteration-count: 1 !important;
      scroll-behavior: auto !important;
      transition-duration: 0.001ms !important;
    }
```

**Planner notes:** Extend the scoped `--cw-*` token inventory in `@layer cw.tokens`, then migrate repeated values in layout/components to semantic tokens in the same file. Preserve `.chimeway-admin` scoping and `data-cw-theme="light|dark|system"` behavior.

---

### `chimeway_admin/assets/css/chimeway_admin.css` (config/source-copy asset, file-I/O)

**Analog:** `chimeway_admin/assets/css/chimeway_admin.css`

**Source-copy import pattern** (lines 1-3):

```css
/* Source copy for the packaged stylesheet.
   The shipped asset lives at priv/static/chimeway_admin.css. */
@import "../../priv/static/chimeway_admin.css";
```

**Planner notes:** Keep this as an import mirror. Do not introduce a build step or framework stylesheet.

---

### `chimeway_admin/lib/chimeway_admin/components/layout.ex` (component, request-response)

**Analog:** `chimeway_admin/lib/chimeway_admin/components/layout.ex`

**Imports/component setup pattern** (lines 1-14):

```elixir
defmodule ChimewayAdmin.Components.Layout do
  @moduledoc false

  use Phoenix.Component

  alias ChimewayAdmin.Routes

  attr(:title, :string, required: true)
  attr(:eyebrow, :string, default: "Chimeway Admin")
  attr(:active, :atom, default: :home)
  attr(:theme, :string, default: "system")
  attr(:description, :string, default: nil)
  slot(:actions)
  slot(:inner_block, required: true)
```

**Theme shell and navigation pattern** (lines 16-47):

```elixir
def admin_shell(assigns) do
  ~H"""
  <main class="chimeway-admin" data-cw-theme={@theme}>
    <div class="cw-shell">
      <aside class="cw-sidebar" aria-label="Chimeway admin">
        <.brand />
        <nav class="cw-nav" aria-label="Admin sections">
          <.nav_item active={@active == :home} path={Routes.search_path()} label="Command Center" />
          <.nav_item active={@active == :traces} path={Routes.traces_path()} label="Trace Lookup" />
          <.nav_item active={@active == :feed} path={Routes.feed_path()} label="Feed Debug" />
          <.nav_item active={@active == :definitions} path={Routes.definitions_path()} label="Definitions" />
          <.nav_item active={@active == :health} path={Routes.health_path()} label="Health" />
          <.nav_item active={@active == :recovery} path={Routes.recovery_path()} label="Recovery" />
        </nav>
      </aside>
```

**Active nav state pattern** (lines 63-72):

```elixir
attr(:active, :boolean, required: true)
attr(:path, :string, required: true)
attr(:label, :string, required: true)

defp nav_item(assigns) do
  ~H"""
  <.link navigate={@path} class={["cw-nav__item", @active && "cw-nav__item--active"]} aria-current={if @active, do: "page", else: nil}>
    <span>{@label}</span>
  </.link>
  """
end
```

**Planner notes:** If modifying layout hooks, preserve `main.chimeway-admin`, the `data-cw-theme` attribute, landmark labels, and `aria-current` behavior.

---

### `chimeway_admin/lib/chimeway_admin/components/core.ex` (component, request-response)

**Analog:** `chimeway_admin/lib/chimeway_admin/components/core.ex`

**Component attr/global pattern** (lines 17-41):

```elixir
attr(:variant, :atom, default: :secondary, values: [:primary, :secondary, :ghost, :danger])
attr(:type, :string, default: "button")
attr(:rest, :global)
slot(:inner_block, required: true)

def button(assigns) do
  ~H"""
  <button type={@type} class={["cw-button", "cw-button--#{@variant}"]} {@rest}>
    {render_slot(@inner_block)}
  </button>
  """
end

attr(:navigate, :string, default: nil)
attr(:href, :string, default: nil)
attr(:variant, :atom, default: :secondary, values: [:primary, :secondary, :ghost, :danger])
attr(:rest, :global)
```

**Form control pattern** (lines 52-82):

```elixir
def text_input(assigns) do
  assigns = assign_new(assigns, :id, fn -> "cw-input-#{assigns.name}" end)

  ~H"""
  <label class="cw-field" for={@id}>
    <span class="cw-field__label">{@label}</span>
    <span :if={@hint} class="cw-field__hint">{@hint}</span>
    <input id={@id} class="cw-input" type={@type} name={@name} value={@value} required={@required} {@rest} />
  </label>
  """
end
```

**Long ID hook pattern** (lines 98-112):

```elixir
attr(:label, :string, required: true)
attr(:value, :any, required: true)

def copyable_id(assigns) do
  ~H"""
  <span class="cw-copy-id" title={to_string(@value)}>
    <span class="cw-copy-id__label">{@label}</span>
    <code>{format_value(@value)}</code>
  </span>
  """
end
```

**Planner notes:** Add or refine CSS hooks here only when shared primitive markup is needed for responsive or state contracts. Keep `attr/3`, `slot/3`, and `:global` conventions.

---

### `chimeway_admin/lib/chimeway_admin/components/status.ex` (component, transform)

**Analog:** `chimeway_admin/lib/chimeway_admin/components/status.ex`

**Status and metric class pattern** (lines 6-31):

```elixir
attr(:status, :any, required: true)
attr(:label, :string, default: nil)

def status_badge(assigns) do
  normalized = normalize(assigns.status)
  assigns = assign(assigns, :normalized, normalized)

  ~H"""
  <span class={["cw-status", "cw-status--#{@normalized}"]}>
    <span class="cw-status__dot" aria-hidden="true"></span>
    <span>{@label || humanize(@normalized)}</span>
  </span>
  """
end

attr(:value, :integer, default: 0)
attr(:label, :string, required: true)
attr(:tone, :atom, default: :neutral, values: [:neutral, :success, :warning, :danger, :info])
```

**Planner notes:** Keep semantic status classes (`cw-status--...`) as the styling anchor. Expand CSS status tokens rather than adding raw colors to component markup.

---

### `chimeway_admin/lib/chimeway_admin/components/timeline_event.ex` (component, transform)

**Analog:** `chimeway_admin/lib/chimeway_admin/components/timeline_event.ex`

**Safe detail rendering pattern** (lines 10-32):

```elixir
use Phoenix.Component

alias ChimewayAdmin.Redaction

attr(:timeline, :list, required: true)

def timeline(assigns) do
  ~H"""
  <section class="chimeway-admin-timeline">
    <h2>Timeline</h2>
    <ol class="cw-timeline">
      <%= for entry <- @timeline do %>
        <li class="cw-timeline__item">
          <time datetime={DateTime.to_iso8601(entry.at)}>
            {format_at(entry.at)}
          </time>
          <strong>{humanize_event(entry.event)}</strong>
          <dl class="cw-timeline__details">
            <%= for {key, value} <- Redaction.safe_timeline_detail(entry.detail) do %>
```

**Planner notes:** Preserve redacted detail rendering. Phase 69 can adjust CSS classes/layout hooks but must not expand sensitive payload display.

---

### LiveView page files (live_view/component consumer, request-response or event-driven)

**Applies to:**

- `chimeway_admin/lib/chimeway_admin/live/dashboard_live.ex`
- `chimeway_admin/lib/chimeway_admin/live/trace_search_live.ex`
- `chimeway_admin/lib/chimeway_admin/live/trace_detail_live.ex`
- `chimeway_admin/lib/chimeway_admin/live/feed_live.ex`
- `chimeway_admin/lib/chimeway_admin/live/definitions_live.ex`
- `chimeway_admin/lib/chimeway_admin/live/health_live.ex`
- `chimeway_admin/lib/chimeway_admin/live/recovery_live.ex`

**Analogs:** `chimeway_admin/lib/chimeway_admin/live/dashboard_live.ex`, `chimeway_admin/lib/chimeway_admin/live/trace_search_live.ex`

**Shell composition pattern** (`dashboard_live.ex` lines 15-36):

```elixir
def render(assigns) do
  ~H"""
  <.admin_shell
    title="Command Center"
    active={:home}
    description="Find notification traces, spot delivery problems, and recover eligible stuck work without exposing raw payloads."
  >
    <section class="cw-hero-panel">
      <div>
        <p class="cw-hero-panel__kicker">Headline job</p>
        <h2>Why did this notification happen?</h2>
        <p>Search by recipient or correlation ID, then follow the trace from event to delivery attempt.</p>
      </div>
      <.link_button navigate={Routes.traces_path()} variant={:primary}>Open Trace Lookup</.link_button>
    </section>

    <section class="cw-metric-grid" aria-label="Delivery status overview">
```

**Rows, cards, metrics pattern** (`dashboard_live.ex` lines 38-53, 97-119):

```elixir
<section class="cw-grid cw-grid--two">
  <.card>
    <div class="cw-section-heading">
      <div>
        <h2>Recent problem traces</h2>
        <p>Failed, cancelled, or suppressed deliveries that deserve operator attention.</p>
      </div>
      <.link_button navigate={Routes.health_path()} variant={:ghost}>Health</.link_button>
    </div>
    <div class="cw-list">
      <.empty_state
        :if={@snapshot.recent_problems == []}
```

```elixir
defp problem_row(assigns) do
  ~H"""
  <.link navigate={Routes.delivery_path(@row.delivery_id)} class="cw-row-link">
    <div>
      <strong>{@row.notification_key}</strong>
      <span>{Redaction.redact_recipient(@row.recipient_id)} · {@row.channel}</span>
    </div>
    <.status_badge status={@row.status} />
  </.link>
  """
end
```

**Event and auth pattern** (`trace_search_live.ex` lines 26-41):

```elixir
@impl true
def handle_event("search", params, socket) do
  with {:ok, socket} <- LiveAuth.ensure_authorized(socket, :search_traces) do
    do_search(params, socket)
  else
    {:error, socket} -> {:noreply, socket}
  end
end

def handle_event("open_delivery", %{"delivery_id" => delivery_id}, socket) do
  with {:ok, socket} <- LiveAuth.ensure_authorized(socket, :search_traces) do
    {:noreply, push_navigate(socket, to: Routes.delivery_path(delivery_id))}
```

**Search form and row hook pattern** (`trace_search_live.ex` lines 85-130):

```elixir
<.admin_shell
  title="Trace Lookup"
  active={:traces}
  description="Search by recipient or correlation ID, then open the delivery timeline that explains the outcome."
>
  <.card>
    <form phx-submit="search" id="trace-search-form" class="cw-search-form">
      <.select
        label="Mode"
        name="mode"
        value={@mode}
        options={[{"Recipient ID", "recipient"}, {"Correlation ID", "correlation"}]}
      />
      <.text_input label="Query" name="query" value={@query} required />
```

**Planner notes:** Prefer fixing shared CSS/component hooks first. Touch individual LiveViews only to add stable shared hooks, `min-width: 0` wrappers, accessible labels, or markup contracts that the stylesheet needs across the seven pages.

---

### `chimeway_admin/test/chimeway_admin/design_system_test.exs` (test, transform)

**Analogs:** `chimeway_admin/test/chimeway_admin/routes_test.exs`, `chimeway_admin/lib/chimeway_admin/assets.ex`

**ExUnit module/setup style** (`routes_test.exs` lines 1-10):

```elixir
defmodule ChimewayAdmin.RoutesTest do
  use ExUnit.Case, async: true

  alias ChimewayAdmin.Routes

  setup do
    previous = Application.get_env(:chimeway_admin, :path_prefix)
    on_exit(fn -> Application.put_env(:chimeway_admin, :path_prefix, previous) end)
    :ok
  end
```

**Packaged CSS read pattern** (`assets.ex` lines 12-23):

```elixir
@doc "Returns the packaged CSS for demo/test inline use."
@spec inline_css() :: String.t()
def inline_css do
  :chimeway_admin
  |> :code.priv_dir()
  |> Path.join("static/chimeway_admin.css")
  |> File.read()
  |> case do
    {:ok, css} -> css
    {:error, _} -> ""
  end
end
```

**Dependency availability for structural parsing** (`mix.exs` lines 22-34):

```elixir
defp deps do
  [
    {:oban, "~> 2.17"},
    {:chimeway, path: ".."},
    {:phoenix, "~> 1.7"},
    {:phoenix_html, "~> 4.0"},
    {:phoenix_live_view, "~> 1.0"},
    {:jason, "~> 1.4"},
    {:ecto_sql, "~> 3.11"},
    {:floki, ">= 0.30.0", only: :test},
```

**Planner notes:** Create CSS contract tests around `ChimewayAdmin.Assets.inline_css/0`. Assert required token families, theme branches, state hooks, and `@media (prefers-reduced-motion: reduce)` text. Use plain ExUnit string assertions unless selectors are needed.

---

### `chimeway_admin/test/chimeway_admin/live/design_system_live_test.exs` (test, request-response)

**Analog:** `chimeway_admin/test/chimeway_admin/live/trace_search_live_test.exs`

**LiveView test imports and isolated mount pattern** (lines 1-15):

```elixir
defmodule ChimewayAdmin.Live.TraceSearchLiveTest do
  use ChimewayAdmin.LiveViewCase, async: true

  import Phoenix.LiveViewTest

  test "mounts search form with empty results", %{conn: conn} do
    {:ok, _view, html} =
      live_isolated(conn, ChimewayAdmin.Live.TraceSearchLive,
        session: %{"current_actor" => "ops:1"},
        on_mount: [{ChimewayAdmin.LiveAuth, :search_traces}]
      )

    assert html =~ "Trace Lookup"
    assert html =~ "trace-search-form"
  end
```

**Multi-page contract pattern** (lines 33-60):

```elixir
test "pillar pages mount", %{conn: conn} do
  pages = [
    {ChimewayAdmin.Live.FeedLive, :view_feed, "Feed Debug"},
    {ChimewayAdmin.Live.DefinitionsLive, :view_definitions, "Definitions"},
    {ChimewayAdmin.Live.HealthLive, :view_health, "Health"},
    {ChimewayAdmin.Live.RecoveryLive, :list_recovery_candidates, "Recovery"}
  ]

  for {live_view, action, text} <- pages do
    {:ok, _view, html} =
      live_isolated(conn, live_view,
        session: %{"current_actor" => "ops:1"},
        on_mount: [{ChimewayAdmin.LiveAuth, action}]
      )
```

**LiveView case setup pattern** (`test/support/live_view_case.ex` lines 1-26):

```elixir
defmodule ChimewayAdmin.LiveViewCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  using do
    quote do
      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest

      @endpoint ChimewayAdmin.TestSupport.Endpoint
    end
  end
```

**Planner notes:** New rendered contract tests should mount all seven core pages and assert `.chimeway-admin`, `data-cw-theme`, nav hooks, page headers, search form/table/list/copy-ID hooks where present. Floki is available if selector assertions are preferable.

---

### Demo host asset serving files (config/template, file-I/O and request-response)

**Applies to:**

- `examples/chimeway_demo_host/lib/demo_host_web/endpoint.ex`
- `examples/chimeway_demo_host/lib/demo_host_web/layouts/root.html.heex`

**Analogs:** same files plus `chimeway_admin/lib/chimeway_admin.ex`

**Documented host-serving pattern** (`chimeway_admin.ex` lines 21-33):

```elixir
## Stylesheet

Serve the packaged stylesheet from the host endpoint:

    plug Plug.Static,
      at: "/chimeway_admin",
      from: {:chimeway_admin, "priv/static"},
      gzip: false,
      only: ~w(chimeway_admin.css)

Then include:

    <link rel="stylesheet" href={ChimewayAdmin.Assets.css_path()} />
```

**Endpoint static asset pattern** (`endpoint.ex` lines 15-20):

```elixir
plug(Plug.Static,
  at: "/chimeway_admin",
  from: {:chimeway_admin, "priv/static"},
  gzip: false,
  only: ~w(chimeway_admin.css)
)
```

**Root layout link pattern** (`root.html.heex` lines 1-12):

```heex
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Chimeway Demo Host</title>
    <link rel="stylesheet" href={ChimewayAdmin.Assets.css_path()} />
  </head>
  <body>
    {@inner_content}
  </body>
</html>
```

**Planner notes:** These should usually remain unchanged in Phase 69. If screenshot evidence or demo verification exposes an asset-link issue, preserve the packaged `/chimeway_admin/chimeway_admin.css` path.

## Shared Patterns

### Scoped Admin CSS

**Source:** `chimeway_admin/priv/static/chimeway_admin.css`
**Apply to:** CSS asset, component class hooks, all rendered LiveViews.

```css
@layer cw.tokens, cw.base, cw.layout, cw.components, cw.utilities;

@layer cw.tokens {
  :where(.chimeway-admin) {
```

Keep selectors scoped under `.chimeway-admin`; prefer low-specificity `:where()` for global admin base rules.

### Theme Selection

**Source:** `chimeway_admin/lib/chimeway_admin/components/layout.ex` and `chimeway_admin/priv/static/chimeway_admin.css`
**Apply to:** shell component, CSS theme tokens, design-system tests.

```elixir
<main class="chimeway-admin" data-cw-theme={@theme}>
```

```css
:where(.chimeway-admin[data-cw-theme="dark"]) {
  --cw-admin-bg: var(--cw-night);
  color-scheme: dark;
}

@media (prefers-color-scheme: dark) {
  :where(.chimeway-admin[data-cw-theme="system"]) {
```

### Authorization Boundary for Eventful LiveViews

**Source:** `chimeway_admin/lib/chimeway_admin/live/trace_search_live.ex`
**Apply to:** Any Phase 69 LiveView touch that changes forms/buttons with `phx-*` events.

```elixir
with {:ok, socket} <- LiveAuth.ensure_authorized(socket, :search_traces) do
  do_search(params, socket)
else
  {:error, socket} -> {:noreply, socket}
end
```

Do not weaken or bypass `LiveAuth` while adjusting markup or classes.

### Sensitive Data Boundary

**Source:** `dashboard_live.ex` and `timeline_event.ex`
**Apply to:** Rows, trace details, timeline, copyable IDs, tests.

```elixir
<span>{Redaction.redact_recipient(@row.recipient_id)} · {@row.channel}</span>
```

```elixir
<%= for {key, value} <- Redaction.safe_timeline_detail(entry.detail) do %>
```

Design-system work must not expand raw payload or recipient exposure.

### Contract Test Style

**Source:** `chimeway_admin/test/chimeway_admin/live/trace_search_live_test.exs`
**Apply to:** New design-system CSS and LiveView tests.

```elixir
{:ok, _view, html} =
  live_isolated(conn, ChimewayAdmin.Live.TraceSearchLive,
    session: %{"current_actor" => "ops:1"},
    on_mount: [{ChimewayAdmin.LiveAuth, :search_traces}]
  )

assert html =~ "Trace Lookup"
assert html =~ "trace-search-form"
```

Use this for rendered hook checks; use `ChimewayAdmin.Assets.inline_css/0` for CSS text contracts.

## No Analog Found

None. All likely Phase 69 files have exact or role-match analogs in the existing admin package.

## Metadata

**Analog search scope:** `chimeway_admin/lib`, `chimeway_admin/test`, `chimeway_admin/priv`, `chimeway_admin/assets`, `examples/chimeway_demo_host/lib`
**Files scanned:** 45 paths from `rg --files` plus targeted `rg` searches for CSS hooks and LiveView contracts
**Pattern extraction date:** 2026-06-04
