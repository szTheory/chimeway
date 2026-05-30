# Phase 62: Inbox Demo, Docs & Gate — Research

**Researched:** 2026-05-30  
**Phase:** 62-inbox-demo-docs-gate  
**Requirements:** DEMO-08, DOCS-08 (Inbox), DOCS-09 (Inbox), GATE-05 (Inbox)  
**Status:** Ready for planning

---

## 1. Executive Summary

Phase 62 closes the **adopter documentation and CI gate** loop for end-user inbox UI — the mirror of Phase 60 Accrue (`accrue-dunning-integration.md` + DOCS-09 doc-contract + `verify.accrue`) and Phase 56/57 Mailglass, applied to the Phase 61 `chimeway_inbox` package. Phases 61 shipped INBX-01/02 (headless API + mountable bell LiveView); Phase 62 adds **no new package API** — only demo host mount, golden-path guide, doc-contract truth lock, and formal `mix verify.inbox` release gate.

**Planner takeaway:** Three plans in two waves — **62-01** (demo mount + `:inbox` proof) and **62-03** (CI + MAINTAINING + release_gate_contract) parallel in Wave 1; **62-02** (guide + doc-contract) blocked on 62-01 so verification section cites runnable demo artifacts. Clone Phase 60 vertical slice verbatim; Accrue-specific twist (**sibling checkout, billing events**) is absent — inbox uses in-repo path deps only.

**Key simplification vs Accrue gate:** `verify.inbox` = `chimeway_inbox` package tests + demo host `--only inbox` — **no** root `mix test --only inbox`, **no** `ACCRUE_PATH`, **no** sibling repo checkout.

---

## 2. Phase Boundary & Dependencies

### In scope

| Deliverable | Requirement | Artifact |
|-------------|-------------|----------|
| Demo host mount + proof | DEMO-08 | `examples/chimeway_demo_host` router, `DemoHost.InboxAuth`, `DemoHost.Seeds.seed_inbox/0`, `inbox_bell_proof_test.exs` |
| Golden-path guide | DOCS-08 (Inbox) | `guides/introduction/inbox-integration.md` |
| Doc-contract | DOCS-09 (Inbox) | `test/chimeway/doc_contract_test.exs` inbox describe |
| Release gate | GATE-05 (Inbox) | `mix verify.inbox`, `verify_inbox` CI job, MAINTAINING octet, `release_gate_contract_test.exs` |

### Out of scope (locked in 62-CONTEXT)

- Real-time PubSub bell refresh (INBX-03 / v1.10)
- `mark_seen` wired in `BellDropdownLive` UI (Phase 61 D-08 deferred)
- Inbox-read signal on delivery timeline UI (INT-02)
- Inbox blueprint recipe (package mount is the seam — no ECOS-style adapter recipe)
- New headless API surface (Phase 61 shipped INBX-01)

### Depends on

- **Phase 61 complete** — `chimeway_inbox/` package with `ChimewayInbox.Auth`, `ChimewayInbox.Router`, `BellDropdownLive`, 6 package tests green
- **Core inbox API** — `Chimeway.unread_count/1`, paginated `list_for_recipient/2`, `mark_read/3`, `mark_seen/3` on public `Chimeway` module

### Wave dependency graph

```
Wave 1 (parallel)
├── 62-01 DEMO-08 ──┐
└── 62-03 GATE-05   │
                    ▼
Wave 2 (blocked on 62-01)
└── 62-02 DOCS-08/09
```

---

## 3. Demo Host Integration Pattern

Clone the **`chimeway_admin` mount** already in the demo host — swap package, auth behaviour, and scope path.

### 3.1 Admin mount template (existing)

```23:28:examples/chimeway_demo_host/lib/demo_host_web/router.ex
  scope "/admin/chimeway" do
    pipe_through :browser

    import ChimewayAdmin.Router
    chimeway_admin_routes()
  end
```

Browser pipeline includes session + `DemoHostWeb.Plugs.AdminActor` (sets `"current_actor" => "demo:operator"` for operator context):

```8:16:examples/chimeway_demo_host/lib/demo_host_web/router.ex
  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {DemoHostWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug DemoHostWeb.Plugs.AdminActor
  end
```

Admin auth config (permissive dev/test `ChimewayAdmin.Auth`):

```14:15:examples/chimeway_demo_host/config/config.exs
config :chimeway_admin, auth_module: DemoHost.AdminAuth
config :chimeway_admin, path_prefix: "/admin/chimeway"
```

```1:13:examples/chimeway_demo_host/lib/demo_host/admin_auth.ex
defmodule DemoHost.AdminAuth do
  @moduledoc """
  Permissive dev/test auth for `chimeway_admin` in the demo host.
  ...
  """
  @behaviour ChimewayAdmin.Auth

  @impl true
  def authorize(_actor, _action, _context) do
    if authorized?(), do: :ok, else: {:error, :unauthorized}
  end
```

### 3.2 Inbox mount target (62-01)

**Package router macro** — host scopes path; LiveView lives at `/` inside scope:

```19:28:chimeway_inbox/lib/chimeway_inbox/router.ex
  defmacro chimeway_inbox_routes(_opts \\ []) do
    quote do
      import Phoenix.LiveView.Router

      live_session :chimeway_inbox_bell,
        on_mount: [{ChimewayInbox.LiveAuth, :inbox_bell}] do
        live "/", ChimewayInbox.Live.BellDropdownLive, :index
      end
    end
  end
```

Moduledoc shows canonical mount at `/inbox`:

```7:13:chimeway_inbox/lib/chimeway_inbox/router.ex
      # router.ex
      scope "/inbox" do
        pipe_through [:browser]

        import ChimewayInbox.Router
        chimeway_inbox_routes()
      end
```

**Recommended demo host changes:**

| File | Action |
|------|--------|
| `examples/chimeway_demo_host/mix.exs` | Add `{:chimeway_inbox, path: "../../chimeway_inbox"}` alongside `chimeway_admin` path dep |
| `examples/chimeway_demo_host/config/config.exs` | `config :chimeway_inbox, auth_module: DemoHost.InboxAuth` |
| `examples/chimeway_demo_host/lib/demo_host/inbox_auth.ex` | **New** — `@behaviour ChimewayInbox.Auth`, `current_recipient/2` |
| `examples/chimeway_demo_host/lib/demo_host_web/router.ex` | New scope `/inbox` with `chimeway_inbox_routes/0` |
| `examples/chimeway_demo_host/lib/demo_host/seeds.ex` | **New** `seed_inbox/0` — adopter-copyable, not in `run/0` bundle |

### 3.3 Auth behaviour contract

Package expects host-implemented recipient resolution:

```1:18:chimeway_inbox/lib/chimeway_inbox/auth.ex
defmodule ChimewayInbox.Auth do
  ...
  @callback current_recipient(session :: map(), context :: map()) ::
              {:ok, String.t()} | {:error, :unauthorized}
  ...
  def auth_module, do: Application.fetch_env!(:chimeway_inbox, :auth_module)
end
```

`LiveAuth` resolves on mount and re-checks on events; fail-closed redirect on `{:error, :unauthorized}`:

```13:24:chimeway_inbox/lib/chimeway_inbox/live_auth.ex
  def on_mount(:inbox_bell, _params, session, socket) do
    case resolve_recipient(session, socket) do
      {:ok, recipient_identity} ->
        {:cont,
         assign(socket,
           recipient_identity: recipient_identity,
           chimeway_inbox_session: session
         )}

      {:error, _} ->
        {:halt, redirect(socket, to: unauthorized_redirect())}
    end
  end
```

**Session design gotcha:** `AdminActor` sets `"current_actor" => "demo:operator"` on every browser request — that identity is for **operator admin**, not end-user inbox. `DemoHost.InboxAuth` must resolve **recipient** identity (e.g. `"user:#{email}"` via `DemoHost.Seeds.recipient_identity/1`), not reuse `demo:operator`. Options (planner discretion per D-04):

1. Read a dedicated session key (e.g. `"inbox_recipient"` or `"demo_user_email"`) set by a future plug or test `init_test_session/2`
2. Default dev/test mapping: if session contains demo user email, return `recipient_identity(email)`; deny in `:prod`

Package test pattern uses session + AllowAuth:

```10:14:chimeway_inbox/test/chimeway_inbox/live/bell_dropdown_live_test.exs
  defp mount_bell(conn, session \\ %{"current_actor" => "user:42"}) do
    conn
    |> Phoenix.ConnTest.init_test_session(session)
    |> live("/")
  end
```

Demo proof test should **`init_test_session`** with the seeded user's identity before `live(conn, "/inbox")`.

### 3.4 Seeds pattern

Existing seeds use public `Chimeway.trigger/3` and stable recipient helpers:

```40:41:examples/chimeway_demo_host/lib/demo_host/seeds.ex
  @doc "Recipient identity string for a TeamPulse user email."
  def recipient_identity(email) when is_binary(email), do: "user:#{email}"
```

`seed_accrue_dunning/0` is standalone (not in `run/0`) — mirror for inbox:

```131:144:examples/chimeway_demo_host/lib/demo_host/seeds.ex
  @doc """
  DEMO-07: Accrue billing-event dunning through Chimeway with Logger email delivery.
  ...
  Standalone API; not invoked from `run/0`.
  """
  @spec seed_accrue_dunning() :: {:ok, map()} | {:error, term()}
  def seed_accrue_dunning do
```

**`seed_inbox/0` recommendation:**

- Trigger via `Chimeway.trigger/3` with an **in_app** channel notifier (reuse `DemoHost.Notifiers.InviteSent` — already multi-channel with `subject` in metadata, or add a thin inbox-specific notifier)
- Target `DemoHost.Seeds.alex_identity()` (`user:alex@teampulse.test`) for consistency with invite journey
- Return `{:ok, %{notification_ids: [...], recipient_identity: ..., trace: ...}}` for proof assertions
- Seed **two unread** notifications if proof needs separate `mark_read` (LiveView) and `mark_seen` (API) targets
- Idempotency key like `"teampulse-seed-inbox-v1"` for safe re-runs

Invite notifier already declares `in_app` channel + metadata `subject`:

```30:48:examples/chimeway_demo_host/lib/demo_host/notifiers/invite_sent.ex
  def channels(_params, _recipient), do: {:ok, [:email, :in_app]}
  ...
       channels: %{
         in_app: %{render_key: "teampulse.invite_sent.in_app", render_version: 1},
         email: %{render_key: "teampulse.invite_sent.email", render_version: 1}
       }
```

---

## 4. Proof Test Pattern (`:inbox` selective tag)

### 4.1 Established selective-proof modules

Mailglass (DEMO-06):

```1:15:examples/chimeway_demo_host/test/demo_host_web/mailglass_delivery_proof_test.exs
defmodule DemoHostWeb.MailglassDeliveryProofTest do
  @moduledoc """
  DEMO-06 proof: TeamPulse invite email delivers through `Chimeway.Adapters.Mailglass`
  ...
  Tagged `:mailglass` only — journey suite keeps default Logger adapter (D-10).
  """
  use DemoHostWeb.ConnCase, async: false
  ...
  @moduletag :mailglass
```

Accrue (DEMO-07):

```1:19:examples/chimeway_demo_host/test/demo_host_web/accrue_dunning_proof_test.exs
    @moduledoc """
    DEMO-07 proof: Accrue billing events drive Chimeway dunning with operator trace
    ...
    Tagged `:accrue` only — journey suite keeps default Logger adapter (D-03).
    """
    ...
    @moduletag :accrue
```

**DEMO-08 must follow same isolation** — dedicated module e.g. `DemoHostWeb.InboxBellProofTest` with `@moduletag :inbox`, **not** `@tag :journey` in `journey_test.exs`. Journey suite keeps Logger adapter defaults (Mailglass D-10 / Accrue D-03 precedent).

### 4.2 Proof flow (D-07)

| Step | Mechanism | Assertion |
|------|-----------|-----------|
| Seed | `DemoHost.Seeds.seed_inbox/0` | Unread notifications exist for demo recipient |
| List | `live(conn, "/inbox")` → open panel (`phx-click="toggle_panel"`) | Items render; badge shows unread count |
| mark_read | `phx-click="mark_read"` on row button | Badge decrements; `data-cw-inbox-badge` hidden at 0 |
| mark_seen | `Chimeway.mark_seen/3` via API (not bell UI) | `seen_at` persisted; satisfies REQUIREMENTS without reopening Phase 61 LiveView scope |

Package LiveViewTest baseline for mark_read + badge:

```34:56:chimeway_inbox/test/chimeway_inbox/live/bell_dropdown_live_test.exs
  test "mark_read updates badge count after row click", %{conn: conn} do
    notification =
      insert_inbox_notification!("user:42", %{metadata: %{"subject" => "Unread item"}})
    ...
    updated_html =
      view
      |> element("button[phx-click=\"mark_read\"][phx-value-id=\"#{notification.id}\"]")
      |> render_click()

    assert updated_html =~ ~s(data-cw-inbox-badge)
    assert updated_html =~ ~s(hidden="")
    ...
    persisted = Repo.get!(Notification, notification.id)
    assert persisted.read_at
  end
```

Bell UI events wired in package:

```40:47:chimeway_inbox/lib/chimeway_inbox/live/bell_dropdown_live.ex
  def handle_event("mark_read", %{"id" => id}, socket) do
    with {:ok, socket} <- LiveAuth.ensure_authorized(socket, :inbox_bell) do
      recipient_identity = socket.assigns.recipient_identity
      _ = Chimeway.mark_read(id, recipient_identity)
      {:noreply, load_inbox(socket, recipient_identity)}
```

**Note:** `unread_count` keys off `read_at` nil — `mark_seen` alone does not change badge count. Proof should assert **API success + `seen_at` set** separately from badge update on `mark_read`.

### 4.3 Selective CI invocation

Root `mix.exs` journey/mailglass/accrue pattern:

```102:104:mix.exs
      "verify.journeys": [
        "cmd --shell cd examples/chimeway_demo_host && mix deps.get && mix test --only journey"
      ],
```

Phase 62 adds:

```elixir
"verify.inbox": [
  "cmd --shell cd chimeway_inbox && mix deps.get && mix test --warnings-as-errors",
  "cmd --shell cd examples/chimeway_demo_host && mix deps.get && mix test --only inbox --warnings-as-errors"
]
```

No root `mix test --only inbox` unless new root tests tagged — core inbox API stays in default `mix ci` (`test/chimeway/inbox_*_test.exs`).

---

## 5. Guide Structure (DOCS-08)

### 5.1 Artifact location

**Canonical path:** `guides/introduction/inbox-integration.md` — parallel to:

- `guides/introduction/mailglass-integration.md`
- `guides/introduction/accrue-dunning-integration.md`

No inbox blueprint recipe in v1.9 — guide owns end-to-end path (62-CONTEXT D-10).

### 5.2 Section skeleton (mirror Mailglass/Accrue introduction)

Accrue guide golden-path headings (doc-contract enforced):

```507:517:test/chimeway/doc_contract_test.exs
      headings = [
        "## 1. Dependencies",
        "## 2. Database / migrations",
        "## 3. Runtime config",
        "## 4. DunningNotifier reference",
        "## 5. Billing-event triggers",
        "## 6. Verification"
      ]
```

**Inbox guide proposed sections** (62-CONTEXT D-09):

| # | Heading | Content |
|---|---------|---------|
| Intro | Responsibility / JTBD | End-user bell UI vs operator admin (`chimeway_admin`); Chimeway owns lifecycle spine; host owns auth + styling |
| 1 | Dependencies | `{:chimeway, "~> 1.x"}`, `{:chimeway_inbox, path: ...}` or hex when published |
| 2 | Database / migrations | Chimeway spine only — `mix chimeway.gen.migrations`; **no** Accrue sibling |
| 3 | Runtime config | `config :chimeway_inbox, auth_module: MyApp.InboxAuth` |
| 4 | Auth behaviour | `ChimewayInbox.Auth` `@callback current_recipient/2` + host example (mirror `DemoHost.InboxAuth`) |
| 5 | Router mount | `import ChimewayInbox.Router` / `chimeway_inbox_routes/0` at `/inbox` |
| 6 | Bell UI surface | `BellDropdownLive`, `data-cw-inbox-*` hooks per `61-UI-SPEC.md`, events (`toggle_panel`, `mark_read`, `mark_all_read`, `load_more`) |
| 7 | Headless API cross-reference | `Chimeway.unread_count/1`, paginated `list_for_recipient/2`, `mark_read/3`, `mark_seen/3` — host/API path when UI does not wire seen |
| 8 | Verification | `mix verify.inbox`, demo route `/inbox`, `DemoHost.Seeds.seed_inbox/0`, `:inbox` proof test pointer |
| 9 | Related guides | golden-path, getting-started inbox section, mention-escalation (mark_read cancel_signals), mailglass/accrue optional |

Accrue verification section template:

```124:140:guides/introduction/accrue-dunning-integration.md
## 6. Verification

After wiring dependencies and config, run the named proof command:

```bash
ACCRUE_PATH=../accrue/accrue mix verify.accrue --warnings-as-errors
```

...
Seed the demo host dunning scenario:

```elixir
DemoHost.Seeds.seed_accrue_dunning/0
```
```

Inbox verification section should cite **`mix verify.inbox`** (no `ACCRUE_PATH`) and **`DemoHost.Seeds.seed_inbox/0`**.

### 5.3 README + HexDocs registration

Current README adoption links:

```42:43:README.md
- [Mailglass Integration Guide](guides/introduction/mailglass-integration.md)
- [Accrue Dunning Integration Guide](guides/introduction/accrue-dunning-integration.md)
```

Add inbox guide link (62-CONTEXT D-11). README doc-contract currently requires mailglass + accrue paths — extend in 62-02:

```696:704:test/chimeway/doc_contract_test.exs
    @required ~w(
      ...
      guides/introduction/mailglass-integration.md
      guides/introduction/accrue-dunning-integration.md
    )
```

HexDocs extras (add after accrue entry):

```142:147:mix.exs
      extras: [
        ...
        "guides/introduction/mailglass-integration.md",
        "guides/introduction/accrue-dunning-integration.md",
```

---

## 6. Doc-Contract Pattern (DOCS-09)

### 6.1 Template location

Insert **after** Accrue guide describe (~line 536):

```439:441:test/chimeway/doc_contract_test.exs
  @accrue_integration_guide Path.expand("../../guides/introduction/accrue-dunning-integration.md", __DIR__)

  describe "accrue dunning integration guide doc contract (DOCS-08 / DOCS-09)" do
```

New block:

```elixir
@inbox_integration_guide Path.expand("../../guides/introduction/inbox-integration.md", __DIR__)

describe "inbox integration guide doc contract (DOCS-08 / DOCS-09)" do
```

### 6.2 Shared guards (reuse verbatim)

```104:108:test/chimeway/doc_contract_test.exs
  @recipe_forbidden_strings ~w(
    stop_conditions
    Workflows.Workers
    Chimeway.Trigger.trigger
  )
```

Plus fictional-module regex (Accrue pattern):

```454:457:test/chimeway/doc_contract_test.exs
      refute Regex.match?(~r/Chimeway\.Workflow(?![s])/, content),
             "accrue dunning integration guide must not reference fictional Chimeway.Workflow"
```

### 6.3 Required strings (minimum — 62-CONTEXT D-14)

```elixir
@required ~w(
  ChimewayInbox.Auth
  chimeway_inbox_routes
  config :chimeway_inbox
  auth_module
  Chimeway.unread_count
  Chimeway.list_for_recipient
  Chimeway.mark_read
  Chimeway.mark_seen
  BellDropdownLive
  mix verify.inbox
  DemoHost.Seeds
  /inbox
)
```

Planner discretion: include `seed_inbox` as explicit substring vs `DemoHost.Seeds` only; include `data-cw-inbox-bell` as required vs recommended in prose.

### 6.4 Section-order test

Mirror Accrue golden-path order test — inbox-specific headings, e.g.:

```elixir
headings = [
  "## 1. Dependencies",
  "## 2. Database / migrations",
  "## 3. Runtime config",
  "## 4. Auth behaviour",
  "## 5. Router mount",
  "## 6. Bell UI surface",
  "## 7. Headless API",
  "## 8. Verification"
]
```

Verify section must contain `mix verify.inbox` and `DemoHost.Seeds.seed_inbox` (or equivalent seed pointer).

### 6.5 HexDocs extras describe extension

```757:792:test/chimeway/doc_contract_test.exs
  describe "hexdocs extras doc contract" do
    ...
    @integration_guides ~w(
      guides/introduction/mailglass-integration.md
      guides/introduction/accrue-dunning-integration.md
    )
    ...
    test "lists accrue integration guide after mailglass integration guide in extras"
```

Extend `@integration_guides` with inbox path; add ordering test: mailglass < accrue < inbox (or accrue < inbox per D-15 discretion).

---

## 7. Release Gate Pattern (GATE-05)

### 7.1 `mix verify.inbox` alias

Existing verify aliases for comparison:

```107:117:mix.exs
      "verify.mailglass": [
        "cmd env MIX_ENV=test mix test --only mailglass --warnings-as-errors",
        "cmd --shell cd examples/chimeway_demo_host && mix deps.get && mix test --only mailglass --warnings-as-errors"
      ],

      "verify.accrue": [
        "deps.compile accrue --force",
        "cmd env MIX_ENV=test mix test --only accrue --warnings-as-errors",
        "cmd --shell cd examples/chimeway_demo_host && env ... mix test --only accrue --warnings-as-errors"
      ]
```

**Inbox alias (62-03)** — simpler than Accrue:

```elixir
"verify.inbox": [
  "cmd --shell cd chimeway_inbox && mix deps.get && mix test --warnings-as-errors",
  "cmd --shell cd examples/chimeway_demo_host && mix deps.get && mix test --only inbox --warnings-as-errors"
]
```

Note: `verify.example` already runs full `chimeway_inbox` test suite (line 88) — `verify.inbox` is the **selective named gate** for GATE-05, not a duplicate of verify.example's demo-host lane.

### 7.2 CI job `verify_inbox`

Mirror `verify_mailglass` structure (Postgres service, deps.get, ecto create/migrate, `mix verify.inbox`):

```211:249:.github/workflows/ci.yml
  verify_mailglass:
    name: Mailglass integration gate
    runs-on: ubuntu-latest
    services:
      postgres:
        ...
    env:
      MIX_ENV: test
      DATABASE_URL: postgres://postgres:postgres@localhost/chimeway_test
    steps:
      ...
      - run: mix ecto.create --quiet
      - run: mix ecto.migrate --quiet
      - run: mix verify.mailglass
```

**No** Accrue-style sibling checkout. **No** extra env vars beyond standard Postgres.

### 7.3 `release_gate_contract_test.exs` updates

Current pre-ship verify commands (4 named gates):

```14:19:test/chimeway/release_gate_contract_test.exs
  @pre_ship_verify_commands [
    {"verify.example", "verify_example", "mix verify.example"},
    {"verify.journeys", "verify_journeys", "mix verify.journeys"},
    {"verify.mailglass", "verify_mailglass", "mix verify.mailglass"},
    {"verify.accrue", "verify_accrue", "mix verify.accrue"}
  ]
```

Add: `{"verify.inbox", "verify_inbox", "mix verify.inbox"}`

Current ci-gate lanes (8):

```12:12:test/chimeway/release_gate_contract_test.exs
  @ci_gate_lanes ~w(lint test verify_gates verify_docs verify_example verify_journeys verify_mailglass verify_accrue)
```

Add: `verify_inbox` → **9 lanes**

Current MAINTAINING septet assertion:

```43:46:test/chimeway/release_gate_contract_test.exs
    test "MAINTAINING documents seven-gate pre-ship requirement", %{maintaining: maintaining} do
      assert Regex.match?(~r/All seven must pass/i, maintaining),
```

Update to **eight-gate** pre-ship (62-CONTEXT D-19).

Current ci-gate job needs:

```346:362:.github/workflows/ci.yml
    needs: [lint, test, verify_gates, verify_docs, verify_example, verify_journeys, verify_mailglass, verify_accrue]
    ...
          for lane in LINT TEST VERIFY_GATES VERIFY_DOCS VERIFY_EXAMPLE VERIFY_JOURNEYS VERIFY_MAILGLASS VERIFY_ACCRUE; do
```

Add `verify_inbox` to `needs`, env vars, and loop.

GATE-06 test `"ci-gate aggregates 8 required lanes"` → **9 required lanes**.

### 7.4 MAINTAINING.md pre-ship block

Current seven commands:

```48:68:MAINTAINING.md
Run all seven before opening or merging release-related changes:

```bash
mix ci
mix ci.docs
mix ci.verify_gates
mix verify.example
mix verify.journeys
mix verify.mailglass
mix verify.accrue
```
...
All seven must pass before publishing.
```

Add:

```bash
mix verify.inbox
```

With description: Inbox integration gate (GATE-05 Inbox): `chimeway_inbox` package tests + demo host DEMO-08 `:inbox` proof — no sibling checkout.

Update **"All seven must pass"** → **"All eight must pass"**.

---

## 8. Validation Architecture (Nyquist)

| Property | Value |
|----------|-------|
| Framework | ExUnit |
| Doc-contract quick run | `mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` |
| Full inbox gate | `mix verify.inbox --warnings-as-errors` |
| CI job | `verify_inbox` with Postgres 15 |
| Estimated runtime | ~30–60s doc-contract; ~1–2 min verify.inbox (in-repo path deps only) |

### Per-deliverable verification map

| Deliverable | Plan | Primary command | Requirement |
|-------------|------|-----------------|-------------|
| Demo mount + seeds + proof | 62-01 | `cd examples/chimeway_demo_host && mix test --only inbox --warnings-as-errors` | DEMO-08 |
| Guide file + README + extras | 62-02 (guide half) | Manual grep + `mix ci.docs` | DOCS-08 |
| Doc-contract describe | 62-02 (contract half) | `mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` | DOCS-09 |
| verify.inbox alias | 62-03 | `mix verify.inbox --warnings-as-errors` | GATE-05 |
| CI job + ci-gate | 62-03 | CI workflow / `mix test test/chimeway/release_gate_contract_test.exs` | GATE-05 + GATE-06 |
| MAINTAINING parity | 62-03 | release_gate_contract MAINTAINING tests | GATE-05 |

### ROADMAP success criteria → proof

| # | Success criterion | Automated proof |
|---|-------------------|-----------------|
| 1 | Demo host mounts inbox; journey proves list → mark_read/seen → badge | `mix test --only inbox` in demo host |
| 2 | Golden-path guide covers dep → mount → auth → bell | Doc-contract + manual section review |
| 3 | Doc-contract + verify.inbox + MAINTAINING octet | `mix ci.verify_gates` + `mix verify.inbox` |

**Docs/release-gate phase acceptance** (AGENTS.md): green `mix ci.verify_gates` + ecosystem verify CI jobs — skip conversational UAT; auto-sign from contract test evidence.

---

## 9. Risks & Gotchas

| ID | Risk | Mitigation |
|----|------|------------|
| P-62-01 | `AdminActor` session `"demo:operator"` conflated with inbox recipient | `DemoHost.InboxAuth` uses distinct session key or explicit test session; document in guide §4 |
| P-62-02 | Proof tagged `:journey` pollutes journey CI / adapter config | Dedicated `@moduletag :inbox` module only (D-06) |
| P-62-03 | `mark_seen` expected to change badge | Badge = unread (`read_at` nil); prove mark_seen via API + DB assert, not badge (D-07) |
| P-62-04 | Guide presents `Chimeway.Inbox` direct calls | Doc-contract + guide §7 must cite public `Chimeway.*` delegates only |
| P-62-05 | Breaking existing seven verify jobs / ci-gate | Additive only — new job + alias; do not modify mailglass/accrue/journey lanes |
| P-62-06 | `verify.example` vs `verify.inbox` overlap | verify.inbox is selective gate; verify.example keeps full demo + admin smoke |
| P-62-07 | Guide verification cites demo before 62-01 lands | Block 62-02 on 62-01 (ROADMAP Wave 2) |
| P-62-08 | ci-gate lane count drift | Update `release_gate_contract_test.exs` **and** ci.yml loop in same plan (62-03) |
| P-62-09 | HexDocs extras / README doc-contract lag | Extend both README `@required` and hexdocs describe in 62-02 |
| P-62-10 | Seed uses email-only notifier | Require `in_app` channel in `seed_inbox/0` so bell list is non-empty |

---

## 10. Plan Recommendations

### 62-01 — Demo host inbox mount + DEMO-08 proof (Wave 1)

**Goal:** Runnable `/inbox` bell on demo host with adopter-copyable seeds and selective proof test.

**Tasks:**

1. Add `{:chimeway_inbox, path: "../../chimeway_inbox"}` to `examples/chimeway_demo_host/mix.exs`
2. `config :chimeway_inbox, auth_module: DemoHost.InboxAuth` in demo host config
3. Implement `DemoHost.InboxAuth` — `@behaviour ChimewayInbox.Auth`, `current_recipient/2` resolving `"user:#{email}"` pattern
4. Mount in router:

   ```elixir
   scope "/inbox" do
     pipe_through :browser
     import ChimewayInbox.Router
     chimeway_inbox_routes()
   end
   ```

5. Add `DemoHost.Seeds.seed_inbox/0` — `Chimeway.trigger/3`, in_app channel, alex identity, return notification ids
6. Create `test/demo_host_web/inbox_bell_proof_test.exs`:
   - `@moduletag :inbox`
   - moduledoc explaining journey isolation
   - Test A: seed → live `/inbox` → toggle panel → `mark_read` → badge hidden at 0
   - Test B: seed → `Chimeway.mark_seen/3` → assert `seen_at` on notification
7. Optional: `DemoHost.Seeds.inbox_path/0` helper returning `"/inbox"` for guide cross-reference

**Acceptance:** `cd examples/chimeway_demo_host && mix test --only inbox --warnings-as-errors`

---

### 62-03 — `mix verify.inbox` + CI + MAINTAINING octet (Wave 1, parallel)

**Goal:** Formal GATE-05 inbox half without breaking existing gates.

**Tasks:**

1. Add `verify.inbox` alias to root `mix.exs` (package + demo `--only inbox`)
2. Add `verify_inbox` job to `.github/workflows/ci.yml` (mirror verify_mailglass, no sibling checkout)
3. Update `ci-gate` needs + env loop with `VERIFY_INBOX`
4. Update `test/chimeway/release_gate_contract_test.exs`:
   - `@pre_ship_verify_commands` + verify.inbox tuple
   - `@ci_gate_lanes` + `verify_inbox`
   - MAINTAINING seven → **eight** assertion
   - GATE-06 ci-gate 8 → **9** lanes assertion
5. Update `MAINTAINING.md` pre-ship block + inbox gate description

**Acceptance:** `mix verify.inbox --warnings-as-errors` + `mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors`

**Note:** 62-03 can land before proof test exists but `mix verify.inbox` won't pass until 62-01 completes — acceptable for Wave 1 parallel if 62-03 merges after 62-01 or both land together before phase sign-off.

---

### 62-02 — Inbox integration guide + doc-contract (Wave 2, blocked on 62-01)

**Goal:** DOCS-08 golden path + DOCS-09 truth lock citing demo artifacts from 62-01.

**Tasks:**

1. Create `guides/introduction/inbox-integration.md` (9-section skeleton §5.2)
2. Add README adoption link
3. Add HexDocs extras entry in `mix.exs` (after accrue guide)
4. Add `inbox integration guide doc contract` describe in `doc_contract_test.exs`
5. Extend `hexdocs extras doc contract` + README `@required` with inbox guide path
6. Cross-link getting-started inbox lifecycle section if present

**Acceptance:** `mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` + `mix ci.docs`

---

### File checklist (all plans)

| File | Plan | Action |
|------|------|--------|
| `examples/chimeway_demo_host/mix.exs` | 62-01 | Add chimeway_inbox dep |
| `examples/chimeway_demo_host/config/config.exs` | 62-01 | auth_module config |
| `examples/chimeway_demo_host/lib/demo_host/inbox_auth.ex` | 62-01 | Create |
| `examples/chimeway_demo_host/lib/demo_host_web/router.ex` | 62-01 | `/inbox` scope |
| `examples/chimeway_demo_host/lib/demo_host/seeds.ex` | 62-01 | `seed_inbox/0` |
| `examples/chimeway_demo_host/test/demo_host_web/inbox_bell_proof_test.exs` | 62-01 | Create |
| `mix.exs` | 62-02/03 | `verify.inbox` alias + extras |
| `guides/introduction/inbox-integration.md` | 62-02 | Create |
| `README.md` | 62-02 | Adoption link |
| `test/chimeway/doc_contract_test.exs` | 62-02 | Inbox describe + hexdocs/README |
| `.github/workflows/ci.yml` | 62-03 | verify_inbox job + ci-gate |
| `test/chimeway/release_gate_contract_test.exs` | 62-03 | Eight-gate + nine-lane parity |
| `MAINTAINING.md` | 62-03 | Octet pre-ship block |

---

## RESEARCH COMPLETE
