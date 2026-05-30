# Phase 65: Ecosystem Blueprints & Demo - Pattern Map

**Mapped:** 2026-05-30
**Files analyzed:** 6
**Analogs found:** 6 / 6

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `guides/recipes/sigra-auth-blueprint.md` | documentation | transform | `guides/recipes/accrue-dunning-blueprint.md` | exact |
| `test/chimeway/doc_contract_test.exs` (ECOS-10 block) | test | request-response | `test/chimeway/doc_contract_test.exs` lines 297–363 (ECOS-07) | exact |
| `examples/chimeway_demo_host/test/demo_host_web/threadline_telemetry_proof_test.exs` | test | event-driven | `examples/chimeway_demo_host/test/demo_host_web/accrue_dunning_proof_test.exs` | exact |
| `examples/chimeway_demo_host/test/demo_host_web/sigra_auth_proof_test.exs` | test | request-response | `examples/chimeway_demo_host/test/demo_host_web/accrue_dunning_proof_test.exs` | exact |
| `examples/chimeway_demo_host/lib/demo_host/seeds.ex` (two new helpers) | utility | request-response | `examples/chimeway_demo_host/lib/demo_host/seeds.ex` lines 139–146 (`seed_accrue_dunning/0`) | exact |
| `mix.exs` (HexDocs extras entry) | config | — | `mix.exs` lines 192–195 (existing blueprint entries) | exact |

---

## Pattern Assignments

### `guides/recipes/sigra-auth-blueprint.md` (documentation, transform)

**Analog:** `guides/recipes/accrue-dunning-blueprint.md`

**Section order to copy exactly** (from lines 1–134 of analog):
```markdown
## Who this is for
## Prerequisites
## Responsibility split (SEED-003)
## Feature Developer: [Role]Notifier authoring
## Adopter: [integration] registration
## Trigger example (local / test)
## Runnable demo
## Out of scope
## Related guides
```

**Responsibility split pattern** (analog lines 14–20) — adapt with Sigra domain language:
```markdown
## Responsibility split (SEED-003)

**Chimeway orchestrates the when and why:** durable notification lifecycle,
suppression and preference gates, idempotency, and operator traces you can
search at `/admin/chimeway`.

**Accrue owns billing state:** subscriptions, invoices, payment failure and
recovery anchors ...
```
Sigra adaptation: replace "billing state" with "auth state" and replace domain specifics
with: "token generation, hashed persistence, rate limits, and magic link /
confirmation code TTL. Sigra emits auth events; Chimeway does not mutate Sigra records."

**Not-a-Chimeway.Adapter callout** (analog line 20):
```markdown
This integration is **not** a `Chimeway.Adapter` seam — it is a Sigra auth
event → `Chimeway.trigger/3` bridge only.
```

**Required strings (D-08)** — all must appear verbatim in the document:
- `Sigra.Integrations.Chimeway`
- `sigra.auth.magic_link`
- `sigra.auth.confirmation_code`
- `Chimeway.trigger`
- `idempotency_key`
- `tenant_id`
- `orchestrates`
- `DemoHost.Seeds.seed_sigra` (prefix — any `seed_sigra_*` variant satisfies this)
- `/admin/chimeway`
- `sigra-auth-integration.md`

**Security constraint (Phase 64 D-07):** Code examples in the trigger section must
show identifier-only params (`user_id`, `email`, `correlation_id`) — never `raw_token`,
`code` verbatim values, or full magic-link URLs as parameter values.

**Runnable demo section pattern** (analog lines 116–122):
```markdown
## Runnable demo

- **Seeds:** `DemoHost.Seeds.seed_sigra_auth/0` — standalone API ...
- **Verification:** `SIGRA_PATH=../sigra mix verify.sigra --warnings-as-errors`
- **Operator trace:** Search `/admin/chimeway` by user email to inspect ...
```

**Related guides cross-link** (analog lines 128–133) — must include:
```markdown
- [Sigra auth integration](../introduction/sigra-auth-integration.md) — ...
```
This provides the `sigra-auth-integration.md` required string for the doc-contract.

---

### `test/chimeway/doc_contract_test.exs` — ECOS-10 describe block (test, request-response)

**Analog:** Same file, lines 297–363 (ECOS-07 Accrue block)

**Module-level attribute to add** (mirrors line 297):
```elixir
@sigra_blueprint_recipe Path.expand("../../guides/recipes/sigra-auth-blueprint.md", __DIR__)
```

**Full describe block pattern** (copy from lines 299–363, adapt for Sigra):

```elixir
describe "sigra auth blueprint recipe doc contract (ECOS-10)" do
  setup do
    content = File.read!(@sigra_blueprint_recipe)
    %{content: content}
  end

  for forbidden <- @recipe_forbidden_strings do
    test "forbids #{forbidden} in sigra auth blueprint recipe", %{content: content} do
      refute String.contains?(content, unquote(forbidden)),
             "sigra auth blueprint recipe must not reference #{unquote(forbidden)}"
    end
  end

  test "forbids Chimeway.Workflow module (not Workflows) in sigra auth blueprint recipe",
       %{content: content} do
    refute Regex.match?(~r/Chimeway\.Workflow(?![s])/, content),
           "sigra auth blueprint recipe must not reference fictional Chimeway.Workflow"
  end

  @required ~w(
    Sigra.Integrations.Chimeway
    sigra.auth.magic_link
    sigra.auth.confirmation_code
    Chimeway.trigger
    idempotency_key
    tenant_id
    orchestrates
    DemoHost.Seeds.seed_sigra
    /admin/chimeway
    sigra-auth-integration.md
  )

  for required <- @required do
    test "requires #{required} in sigra auth blueprint recipe", %{content: content} do
      assert String.contains?(content, unquote(required)),
             "sigra auth blueprint recipe must reference #{unquote(required)}"
    end
  end

  test "requires auth-state split language in sigra auth blueprint recipe", %{content: content} do
    assert String.contains?(content, "auth state") or String.contains?(content, "auth_state"),
           "sigra auth blueprint recipe must document auth-state responsibility split"
  end

  test "requires reciprocal link to sigra auth integration guide", %{content: content} do
    assert String.contains?(content, "sigra-auth-integration.md"),
           "sigra auth blueprint recipe must link to Phase 66 introduction guide"
  end
end
```

**Key detail:** `@recipe_forbidden_strings` is already defined at module level (line 104):
`~w(stop_conditions Workflows.Workers Chimeway.Trigger.trigger)`. The new block reuses it —
no new module-level forbidden strings attribute needed. Additional security-specific
forbidden phrases (`raw_token`, `raw token`) are defined inline in the describe block if
desired, or accepted as Claude's discretion.

**Append position:** After the ECOS-07 block (line 363), before the mailglass integration
guide block (line 368).

---

### `examples/chimeway_demo_host/test/demo_host_web/threadline_telemetry_proof_test.exs` (test, event-driven)

**Analog:** `examples/chimeway_demo_host/test/demo_host_web/accrue_dunning_proof_test.exs`

**Module guard pattern** (analog line 1):
```elixir
if Code.ensure_loaded?(Threadline) and
     Code.ensure_loaded?(Chimeway.Telemetry.ThreadlineReporter) do
  defmodule DemoHostWeb.ThreadlineTelemetryProofTest do
```

**Module header pattern** (analog lines 9–19):
```elixir
use DemoHostWeb.ConnCase, async: false
use Oban.Testing, repo: Chimeway.Repo

import Phoenix.LiveViewTest
import Ecto.Query

@moduletag :threadline

alias Threadline.Semantics.AuditAction
alias Threadline.Test.Repo, as: ThreadlineRepo
```

**Setup pattern** — Threadline-specific (mirrors `test/chimeway/integrations/threadline_telemetry_lifecycle_test.exs` lines 124–131 for reporter attach, plus Accrue proof sandbox checkout pattern lines 22–47):
```elixir
setup do
  :ok = Ecto.Adapters.SQL.Sandbox.checkout(ThreadlineRepo)
  Ecto.Adapters.SQL.Sandbox.mode(ThreadlineRepo, {:shared, self()})

  ThreadlineRepo.delete_all(AuditAction)

  attach_threadline_reporter!()
  configure_chimeway_logger_adapter!()

  on_exit(fn -> detach_threadline_reporter!() end)

  :ok
end
```

**`attach_threadline_reporter!` source:** `test/support/threadline/fixtures.ex` lines 22–26.
Note: this fixture is in root test support. Verify demo host can import it or inline
the three-line body directly.

**Primary proof test** (DEMO-09 audit row assertion — derived from lifecycle test lines 192–208):
```elixir
test "DEMO-09 threadline audit row created for notification lifecycle event" do
  assert {:ok, result} = DemoHost.Seeds.seed_threadline_notification()

  rows = ThreadlineRepo.all(
    from(a in AuditAction,
      where: a.correlation_id == ^result.trace.correlation_id
    )
  )
  assert length(rows) >= 1
end
```

**Admin trace proof test** (DEMO-09 `/admin/chimeway` assertion — copy from analog lines 95–124):
```elixir
test "DEMO-09 admin trace shows threadline notification", %{conn: conn} do
  assert {:ok, result} = DemoHost.Seeds.seed_threadline_notification()

  conn = get(conn, "/admin/chimeway")
  assert html_response(conn, 200) =~ "Trace search"

  {:ok, view, _html} = live(conn)

  html =
    view
    |> form("#trace-search-form", %{
      "mode" => "recipient",
      "query" => result.recipient_identity,
      "notification_key" => ""
    })
    |> render_submit()

  assert html =~ result.recipient_identity

  delivery_id = hd(result.trace.delivery_ids)
  assert String.contains?(html, delivery_id)

  {:ok, _detail_view, detail_html} =
    live(conn, "/admin/chimeway/deliveries/#{delivery_id}")
  assert detail_html =~ "Trace detail"
end
```

**Prerequisite check:** Before writing this file, verify
`examples/chimeway_demo_host/test/test_helper.exs` contains a
`if Code.ensure_loaded?(Threadline)` bootstrap block. The current file (read in full)
contains ONLY Mailglass and Accrue blocks (lines 13–107) — Threadline bootstrap is absent.
This must be added as a Wave 0 task (see Shared Patterns section).

---

### `examples/chimeway_demo_host/test/demo_host_web/sigra_auth_proof_test.exs` (test, request-response)

**Analog:** `examples/chimeway_demo_host/test/demo_host_web/accrue_dunning_proof_test.exs`

**Module guard pattern** (analog line 1, adapted):
```elixir
if Code.ensure_loaded?(Sigra) and Code.ensure_loaded?(Sigra.Integrations.Chimeway) do
  defmodule DemoHostWeb.SigraAuthProofTest do
```

**Module header pattern** (analog lines 9–19):
```elixir
use DemoHostWeb.ConnCase, async: false
use Oban.Testing, repo: Chimeway.Repo

import Phoenix.LiveViewTest

@moduletag :sigra
```

**Setup pattern** — Sigra-specific (mirrors `configure_sigra_chimeway_integration!` from
`test/support/sigra/fixtures.ex` lines 27–41, inlined because root test support may not
be available in demo host — see Pitfall 6 in RESEARCH.md):
```elixir
setup do
  :ok = Ecto.Adapters.SQL.Sandbox.checkout(Sigra.TestRepo)
  Ecto.Adapters.SQL.Sandbox.mode(Sigra.TestRepo, {:shared, self()})

  previous_dispatcher = Application.get_env(:chimeway, :dispatcher)
  Application.put_env(:sigra, :chimeway, enabled: true)
  Application.put_env(:sigra, :repo, Sigra.TestRepo)
  Application.put_env(:chimeway, :dispatcher, Chimeway.Dispatch.Sync)
  configure_chimeway_logger_adapter!()

  on_exit(fn ->
    Application.put_env(:chimeway, :dispatcher, previous_dispatcher)
    Application.delete_env(:sigra, :chimeway)
    Application.delete_env(:sigra, :repo)
  end)

  :ok
end
```

**Primary proof test** (DEMO-10):
```elixir
test "DEMO-10 sigra auth creates durable delivery" do
  assert {:ok, result} = DemoHost.Seeds.seed_sigra_auth()

  delivery_id = hd(result.trace.delivery_ids)
  delivery = Chimeway.Repo.get!(Chimeway.Delivery, delivery_id)
  assert delivery.status in [:succeeded, :dispatched]
end
```

**Admin trace proof test** (DEMO-10 `/admin/chimeway` — copy from analog lines 95–124,
same structure as Threadline proof above):
```elixir
test "DEMO-10 admin trace shows sigra auth notification", %{conn: conn} do
  assert {:ok, result} = DemoHost.Seeds.seed_sigra_auth()

  conn = get(conn, "/admin/chimeway")
  assert html_response(conn, 200) =~ "Trace search"

  {:ok, view, _html} = live(conn)

  html =
    view
    |> form("#trace-search-form", %{
      "mode" => "recipient",
      "query" => result.recipient_identity,
      "notification_key" => ""
    })
    |> render_submit()

  assert html =~ result.recipient_identity

  delivery_id = hd(result.trace.delivery_ids)
  assert String.contains?(html, delivery_id)

  {:ok, _detail_view, detail_html} =
    live(conn, "/admin/chimeway/deliveries/#{delivery_id}")
  assert detail_html =~ "Trace detail"
end
```

**Prerequisite check:** Same as Threadline — verify demo host `test_helper.exs` has Sigra
bootstrap block. Currently absent. Must be added in Wave 0.

---

### `examples/chimeway_demo_host/lib/demo_host/seeds.ex` — two new helpers (utility, request-response)

**Analog:** Same file, lines 139–146 (`seed_accrue_dunning/0`)

**`@compile` guard to add at module top** (analog line 2 pattern — already present for
`DemoHost.AccrueSeeds`; extend for new modules):
```elixir
@compile {:no_warn_undefined, [DemoHost.AccrueSeeds, Sigra.Integrations.Chimeway]}
```

**`seed_threadline_notification/0` pattern** (derived from `seed_invite/0` lines 79–88 +
lifecycle test unique_integer pattern):
```elixir
@doc """
DEMO-09: Threadline audit correlation for notification lifecycle with reporter attached.
Standalone API; not invoked from `run/0`.
"""
@spec seed_threadline_notification() :: {:ok, map()} | {:error, term()}
def seed_threadline_notification do
  if Code.ensure_loaded?(Chimeway.Telemetry.ThreadlineReporter) do
    trigger(
      DemoHost.Notifiers.InviteSent,
      %{email: @alex_email, team_name: "Threadline Demo"},
      idempotency_key: "teampulse-seed-threadline-v1-#{System.unique_integer([:positive])}",
      correlation_id: "teampulse-seed-threadline-corr-#{System.unique_integer([:positive])}",
      tenant_id: @tenant_id
    )
  else
    {:error, :threadline_not_available}
  end
end
```

Note: The `trigger/3` private helper (lines 216–227) normalizes the result to
`%{trace: %{delivery_ids:, correlation_id:, event_id:}, recipient_identity:, ...}`.
This shape satisfies `hd(result.trace.delivery_ids)` and `result.recipient_identity` used
in proof tests. The `correlation_id` key in the result comes from `normalize_duplicate/1`
(lines 235–253) — verify `normalize_trigger_result/1` (line 229) also propagates it
from the Chimeway trigger result for the non-duplicate path.

**`seed_sigra_auth/0` pattern** (delegate pattern from `seed_accrue_dunning/0` lines 139–146):
```elixir
@doc """
DEMO-10: Sigra auth → Chimeway durable delivery with operator trace inspectability.
Standalone API; not invoked from `run/0`.
"""
@spec seed_sigra_auth() :: {:ok, map()} | {:error, term()}
def seed_sigra_auth do
  if Code.ensure_loaded?(Sigra.Integrations.Chimeway) do
    DemoHost.SigraSeeds.seed_sigra_auth()
  else
    {:error, :sigra_not_available}
  end
end
```

Alternative: inline the dispatch call directly rather than delegating to a `DemoHost.SigraSeeds`
module — depends on whether the Sigra dispatch call requires user fixture insertion that
benefits from module isolation. The Accrue precedent delegates; the inline approach is also
valid if Sigra dispatch is simple.

**Return map shape requirement** (enforced by proof test assertions):
Both helpers must return `{:ok, map()}` where the map contains:
- `result.recipient_identity` — string used in LiveView search form
- `result.trace.delivery_ids` — list; `hd(...)` used to get detail view link
- `result.trace.correlation_id` — used in Threadline audit row assertion

The existing `trigger/3` private helper + `normalize_trigger_result/1` already handles
this shape for Chimeway-triggered seeds. Sigra dispatch returns `{:ok, {raw_token, url, result}}`
(from lifecycle test line 41) — the seed wrapper must extract `result.event.id`, look up
delivery IDs via Repo query (or use `result.trace` if present), and return normalized map.

---

### `mix.exs` — HexDocs extras entry (config)

**Analog:** `mix.exs` lines 194–195

**Current state** (lines 192–199):
```elixir
"guides/recipes/oban-integration.md",
"guides/recipes/custom-adapter.md",
"guides/recipes/accrue-dunning-blueprint.md",
"guides/recipes/mailglass-integration-blueprint.md",
"guides/recipes/tracing-a-notification.md",
"guides/recipes/password-reset-support-trace.md",
"guides/recipes/feedback-escalation-workflow.md",
"guides/recipes/mention-escalation.md",
```

**Addition** — insert after line 195 (after `mailglass-integration-blueprint.md`):
```elixir
"guides/recipes/sigra-auth-blueprint.md",
```

**No ordering constraint:** The existing hexdocs extras contract test (lines 846–901) only
asserts ordering for integration guides (`guides/introduction/`), not blueprint recipes.
Inserting after `mailglass-integration-blueprint.md` is clean but not enforced by tests.

---

## Shared Patterns

### Wave 0 Prerequisite: Demo Host `test_helper.exs` Bootstrap

**Source:** `examples/chimeway_demo_host/test/test_helper.exs` — Accrue block (lines 44–107)
**Apply to:** Must be done BEFORE writing either demo proof test
**Status:** Threadline and Sigra bootstrap blocks are ABSENT from current file. Only Mailglass
(lines 13–42) and Accrue (lines 44–107) are present.

**Pattern to replicate** (Accrue block, condensed):
```elixir
if Code.ensure_loaded?(Accrue) do
  # 1. compile integration module if not yet compiled
  # 2. storage_up for TestRepo
  # 3. switch to ConnectionPool for migration run
  # 4. run migrations
  # 5. restore test pool config
  # 6. TestRepo.start_link()
  # 7. Sandbox.mode(:manual)
  # 8. configure integration (e.g. Application.put_env)
end
```

For Threadline: adapt using `Threadline.Test.Repo` and Threadline migration path (from
`test/chimeway/integrations/threadline_telemetry_lifecycle_test.exs` — uses
`Threadline.DataCase` which handles this at root level; demo host needs equivalent).

For Sigra: adapt using `Sigra.TestRepo` and Sigra migration path (mirrors
`test/chimeway/integrations/sigra_auth_lifecycle_test.exs` which uses `Sigra.DataCase`).

### `Code.ensure_loaded?` Module Guard

**Source:** `examples/chimeway_demo_host/test/demo_host_web/accrue_dunning_proof_test.exs` line 1
**Apply to:** Both new demo proof test files (entire module wrapped)

```elixir
if Code.ensure_loaded?(MODULE_A) and Code.ensure_loaded?(MODULE_B) do
  defmodule DemoHostWeb.XxxProofTest do
    ...
  end
end
```

When the guard condition is false, the file compiles to nothing and ExUnit sees no tests —
this is the correct exclusion mechanism; no `--exclude` wiring needed.

### `ConnCase async: false` + `Oban.Testing`

**Source:** `examples/chimeway_demo_host/test/demo_host_web/accrue_dunning_proof_test.exs` lines 9–10
**Apply to:** Both new demo proof test files

```elixir
use DemoHostWeb.ConnCase, async: false
use Oban.Testing, repo: Chimeway.Repo
```

### Admin LiveView Trace Search Assertion

**Source:** `examples/chimeway_demo_host/test/demo_host_web/accrue_dunning_proof_test.exs` lines 95–124
**Apply to:** Both new demo proof test files (one test each)

```elixir
conn = get(conn, "/admin/chimeway")
assert html_response(conn, 200) =~ "Trace search"

{:ok, view, _html} = live(conn)

html =
  view
  |> form("#trace-search-form", %{
    "mode" => "recipient",
    "query" => result.recipient_identity,
    "notification_key" => ""
  })
  |> render_submit()

assert html =~ result.recipient_identity

delivery_id = hd(result.trace.delivery_ids)
assert String.contains?(html, delivery_id)

{:ok, _detail_view, detail_html} =
  live(conn, "/admin/chimeway/deliveries/#{delivery_id}")
assert detail_html =~ "Trace detail"
```

### `@recipe_forbidden_strings` Reuse

**Source:** `test/chimeway/doc_contract_test.exs` lines 104–108
**Apply to:** ECOS-10 describe block — no new module attribute needed

```elixir
@recipe_forbidden_strings ~w(
  stop_conditions
  Workflows.Workers
  Chimeway.Trigger.trigger
)
```

The ECOS-10 block uses `for forbidden <- @recipe_forbidden_strings do` exactly as ECOS-05
(line 253) and ECOS-07 (line 305) do.

### Seeds Private `trigger/3` Helper

**Source:** `examples/chimeway_demo_host/lib/demo_host/seeds.ex` lines 216–227
**Apply to:** `seed_threadline_notification/0` (uses this helper directly)

```elixir
defp trigger(notifier, params, opts) do
  case Chimeway.trigger(notifier, params, opts) do
    {:ok, result} ->
      {:ok, normalize_trigger_result(result)}

    {:duplicate, event} ->
      {:ok, normalize_duplicate(event)}

    {:error, _} = error ->
      error
  end
end
```

---

## No Analog Found

All files have direct analogs in the codebase. No entries.

---

## Critical Implementation Notes

1. **`test_helper.exs` bootstrap gap is a blocker.** Both demo proof tests depend on
   Threadline and Sigra TestRepo being available. The current demo host `test_helper.exs`
   has neither block. This is Wave 0 task #1.

2. **Root test support accessibility.** `Chimeway.TestSupport.ThreadlineFixtures` and
   `Chimeway.TestSupport.SigraFixtures` live in `test/support/` of the root app. Their
   availability in demo host tests is unverified. The safest approach is to inline the
   needed setup (3–5 lines each) directly in the proof test `setup` blocks, as
   `accrue_dunning_proof_test.exs` does via `import DemoHost.AccrueFixtures` (line 14)
   from its own fixtures module.

3. **`seed_sigra_auth/0` return shape.** `Sigra.Integrations.Chimeway.dispatch_magic_link_after_request`
   returns `{:ok, {raw_token, url, result}}` (lifecycle test line 41). The seed helper must
   unwrap this and build the normalized `%{recipient_identity:, trace: %{delivery_ids:, ...}}`
   map. It must NOT expose `raw_token` or `url` in the returned map.

4. **`@compile {:no_warn_undefined, [...]}` in seeds.** Extend the existing directive on
   line 2 of `seeds.ex` to include `Sigra.Integrations.Chimeway` (or any module referenced
   inside a `Code.ensure_loaded?` guard).

5. **Blueprint doc-contract co-authoring.** Write the blueprint first, then derive required
   strings from its actual content. The `@required` list in the doc-contract must match
   what the blueprint literally contains. Use substring prefixes where seed function name
   is discretionary (e.g., `DemoHost.Seeds.seed_sigra` matches any `seed_sigra_*` variant).

## Metadata

**Analog search scope:** `guides/recipes/`, `test/chimeway/`, `examples/chimeway_demo_host/test/`, `examples/chimeway_demo_host/lib/`, `mix.exs`, `test/support/threadline/`, `test/support/sigra/`
**Files scanned:** 12
**Pattern extraction date:** 2026-05-30
