# Phase 65: Ecosystem Blueprints & Demo - Research

**Researched:** 2026-05-30
**Domain:** Elixir documentation blueprints, demo host proof tests, doc-contract CI, HexDocs extras wiring
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-01:** `guides/recipes/sigra-auth-blueprint.md` follows the exact structure of `guides/recipes/accrue-dunning-blueprint.md` — sections: "Who this is for," responsibility split, notifier authoring code example for `sigra.auth.magic_link` and `sigra.auth.confirmation_code`, adopter wiring config, `Chimeway.trigger/3` call with `idempotency_key` + `tenant_id`, runnable demo pointer (`DemoHost.Seeds.seed_sigra_*`), and a reciprocal cross-link to the forthcoming Phase 66 `sigra-auth-integration.md` guide.

**D-02:** Responsibility split language mirrors Accrue blueprint: "Chimeway orchestrates the when and why; Sigra owns auth state, token generation, and rate limits." Explicit callout that Phase 65 is NOT a `Chimeway.Adapter` delivery seam — it is a trigger bridge only.

**D-03:** Both demo proofs are separate test files in `examples/chimeway_demo_host/test/demo_host_web/`:
- `threadline_telemetry_proof_test.exs` — `@moduletag :threadline`, proves Chimeway notification lifecycle event → Threadline `audit_actions` row with `correlation_id`, operator trace inspectability at `/admin/chimeway`
- `sigra_auth_proof_test.exs` — `@moduletag :sigra`, proves Sigra auth event → Chimeway trigger → durable delivery attempt, operator trace inspectability

**D-04:** Both proof files are guarded with `Code.ensure_loaded?/1` wrapping the entire module (Accrue proof precedent). Both use `ConnCase, async: false` + `Oban.Testing` + `DemoHost.Seeds.*` as the trigger entry point — mirroring `accrue_dunning_proof_test.exs` exactly.

**D-05:** `DemoHost.Seeds` gets dedicated seed helpers: `seed_threadline_notification/0` (triggers a notification while ThreadlineReporter is attached, proves audit row creation) and `seed_sigra_auth/0` (triggers magic link or confirmation code flow, proves Chimeway delivery attempt). These are the "runnable demo" pointers in both the blueprint doc and the doc-contract required strings.

**D-06:** Demo proofs include a `/admin/chimeway` LiveView search assertion to prove operator trace inspectability (same as DEMO-07 Accrue proof lines 95–124).

**D-07:** ECOS-10 doc-contract is a new `describe "ECOS-10 sigra auth blueprint"` block appended to `test/chimeway/doc_contract_test.exs` (not a separate file) — mirrors ECOS-05 (Mailglass, line ~247) and ECOS-07 (Accrue, line ~297) patterns.

**D-08:** Required strings in ECOS-10 doc-contract: `Sigra.Integrations.Chimeway`, `sigra.auth.magic_link`, `sigra.auth.confirmation_code`, `Chimeway.trigger`, `idempotency_key`, `tenant_id`, `orchestrates`, `DemoHost.Seeds.seed_sigra`, `/admin/chimeway`, `sigra-auth-integration.md` (reciprocal cross-link to Phase 66 guide).

**D-09:** `guides/recipes/sigra-auth-blueprint.md` is added to `mix.exs` HexDocs extras in Phase 65 (alongside the existing blueprint entries) so the existing HexDocs extras contract test (lines ~851–901) catches omissions immediately.

### Claude's Discretion

- Exact seed helper names (`seed_sigra_auth/0` vs `seed_sigra_magic_link/0` etc.) — any stable name that the blueprint and doc-contract can agree on.
- Whether the Threadline demo proof uses an existing notifier (e.g. `teampulse.invite_sent`) or a new minimal notifier — either works as long as a Threadline `audit_actions` row with `correlation_id` is proven.
- Whether `sigra-auth-blueprint.md` is `guides/recipes/sigra-auth-blueprint.md` or uses a slightly different slug.
- Exact forbidden phrases in ECOS-10 doc-contract (Phase 64 D-07 redaction language to forbid: raw token, confirmation code verbatim).

### Deferred Ideas (OUT OF SCOPE)

- **Golden-path Sigra auth integration guide** — Phase 66 DOCS-10.
- **Sigra guide doc-contract tests** — Phase 66 DOCS-11.
- **`mix verify.sigra` + `mix verify.threadline` CI gates** — Phase 66 GATE-07.
- **MAINTAINING.md pre-ship checklist entries for Threadline/Sigra** — Phase 66.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ECOS-10 | Published Sigra auth notification reference blueprint with CI doc-contract coverage (Chimeway orchestrates when/why; Sigra owns auth state) | Blueprint document + `doc_contract_test.exs` ECOS-10 describe block + `mix.exs` HexDocs extras entry |
| DEMO-09 | Demo host proves Threadline audit correlation for at least one notification lifecycle event with operator inspectability at `/admin/chimeway` | `threadline_telemetry_proof_test.exs` + `seed_threadline_notification/0` seed helper |
| DEMO-10 | Demo host proves Sigra auth notification flow end-to-end (magic link or MFA token dispatch) with operator trace inspectability | `sigra_auth_proof_test.exs` + `seed_sigra_auth/0` seed helper |
</phase_requirements>

---

## Summary

Phase 65 is a pure documentation + test layer built on top of the Phase 63 (ThreadlineReporter) and Phase 64 (Sigra.Integrations.Chimeway) core integrations. There is no new library code — the work is: one new Markdown blueprint document, one new doc-contract describe block, two new demo host proof test files, two new `DemoHost.Seeds` helpers, and one `mix.exs` HexDocs extras entry.

The project has a mature vertical-slice pattern for exactly this kind of "demo + blueprint" phase (established in Phase 56/57 for Mailglass, Phase 60 for Accrue). Every structural choice — `Code.ensure_loaded?` module guard, `@moduletag :sigra`/`:threadline`, `ConnCase async: false` + `Oban.Testing`, `DemoHost.Seeds.*` trigger entry point, `/admin/chimeway` LiveView search assertion, `describe "ECOS-XX"` doc-contract block — already exists in the codebase and is directly copy-adaptable.

The primary challenge is not architectural discovery but faithful replication of the existing patterns with the correct Sigra and Threadline details, and ensuring the doc-contract required-strings set for ECOS-10 exactly matches what the blueprint document contains.

**Primary recommendation:** Copy `accrue_dunning_proof_test.exs` + `accrue-dunning-blueprint.md` + ECOS-07 describe block as templates; adapt each for Sigra and Threadline specifics with zero structural invention.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Sigra auth blueprint document | Documentation (guides/recipes/) | — | Static Markdown file; no runtime tier |
| ECOS-10 doc-contract CI | Test Layer (doc_contract_test.exs) | — | Pure string-presence assertions on Markdown content |
| HexDocs extras registration | Build config (mix.exs) | — | `docs/extras` list; detected by existing hexdocs extras contract test |
| Threadline demo proof test | Demo Host Test Layer | Chimeway Repo (sandbox) | ConnCase + Oban.Testing; Threadline.Test.Repo sandbox |
| Sigra demo proof test | Demo Host Test Layer | Chimeway Repo (sandbox) | ConnCase + Oban.Testing; Sigra.TestRepo sandbox |
| `seed_threadline_notification/0` | Demo Host Seeds | Chimeway trigger spine | Entry point for proof test; callable standalone |
| `seed_sigra_auth/0` | Demo Host Seeds | Sigra.Integrations.Chimeway | Delegates to Sigra integration; Code.ensure_loaded? guard |
| ThreadlineReporter attach in demo host | Demo Host Application | Chimeway.Telemetry | Needed so seed → trigger → audit row path is live in test |

---

## Standard Stack

No new external packages are introduced in Phase 65. All dependencies were established in Phases 63 and 64.

### No New Dependencies

Phase 65 consumes only already-installed packages:

| Library | Already In | Purpose in Phase 65 |
|---------|-----------|---------------------|
| `Chimeway` core | `lib/` | `Chimeway.trigger/3`, traces, telemetry |
| `Threadline` | `mix.exs` optional dep | `audit_actions` row assertions in demo proof |
| `Sigra` + `Sigra.Integrations.Chimeway` | `mix.exs` optional dep | Sigra auth flow entry point for demo proof |
| `Oban.Testing` | `oban` optional dep | Queue drain in demo proof tests |
| `Phoenix.LiveViewTest` | demo host dep | `/admin/chimeway` LiveView search assertions |

**No `npm install` or `mix deps.get` changes required for Phase 65.**

---

## Package Legitimacy Audit

No new packages are introduced. This section is not applicable.

**Packages removed due to slopcheck verdict:** none
**Packages flagged as suspicious:** none

---

## Architecture Patterns

### System Architecture Diagram

```
[DemoHost.Seeds.seed_threadline_notification/0]
        |
        v (Chimeway.trigger/3 with correlation_id)
[Chimeway trigger spine]
        |
        +--> [Chimeway.Telemetry dispatch stop event]
        |            |
        |            v (ThreadlineReporter handler)
        |    [Threadline.record_action/2]
        |            |
        |            v
        |    [Threadline.Test.Repo audit_actions row]
        |
        +--> [Chimeway.Repo delivery row]
                     |
                     v
           [/admin/chimeway LiveView]
                     |
                     v
           [Demo proof assertion: html =~ delivery_id]


[DemoHost.Seeds.seed_sigra_auth/0]
        |
        v (Sigra.Integrations.Chimeway.dispatch_* call)
[Chimeway.trigger/3 with idempotency_key + tenant_id]
        |
        +--> [Chimeway.Repo: event + notification + delivery rows]
        |
        +--> [/admin/chimeway LiveView search]
                     |
                     v
           [Demo proof assertion: html =~ notification_key]
```

### Recommended Project Structure (Phase 65 additions only)

```
guides/
└── recipes/
    └── sigra-auth-blueprint.md               # NEW (ECOS-10)

test/chimeway/
└── doc_contract_test.exs                      # APPEND ECOS-10 describe block

mix.exs                                        # APPEND sigra-auth-blueprint.md to extras

examples/chimeway_demo_host/
├── lib/demo_host/seeds.ex                     # APPEND seed_threadline_notification/0 + seed_sigra_auth/0
└── test/demo_host_web/
    ├── threadline_telemetry_proof_test.exs    # NEW (DEMO-09)
    └── sigra_auth_proof_test.exs             # NEW (DEMO-10)
```

### Pattern 1: Blueprint Document Structure

**What:** Markdown recipe document covering a specific ecosystem integration, scoped to "notifier authoring + wiring + demo pointer" without duplicating the full golden-path guide.

**When to use:** Every SEED-003 ecosystem integration blueprint (ECOS-05 Mailglass, ECOS-07 Accrue, ECOS-10 Sigra).

**Canonical section order (from accrue-dunning-blueprint.md):**
1. `## Who this is for` — two JTBDs: Feature Developer (notifier authoring) and Adopter (wiring config)
2. `## Prerequisites` — links to golden-path + sibling checkout env var
3. `## Responsibility split (SEED-003)` — Chimeway orchestrates when/why; ecosystem lib owns domain state; explicit "not a Chimeway.Adapter seam" callout
4. `## Feature Developer: [Role]Notifier authoring` — stable key constants, `workflow/2` or `build/2` code example
5. `## Adopter: [integration] registration` — `config :sigra, chimeway: [...]` wiring
6. `## Trigger example (local / test)` — the `Sigra.Integrations.Chimeway.dispatch_*` entry points
7. `## Runnable demo` — `DemoHost.Seeds.seed_sigra_auth/0` pointer, operator trace search instructions
8. `## Out of scope` — explicit deferral to Phase 66 guide (DOCS-10) with cross-link placeholder
9. `## Related guides` — links to Phase 66 guide, golden path, other blueprints

**Key Sigra blueprint content requirements (ECOS-10 doc-contract required strings from D-08):**
- `Sigra.Integrations.Chimeway` — the integration module name
- `sigra.auth.magic_link` — magic link notifier key
- `sigra.auth.confirmation_code` — confirmation code notifier key
- `Chimeway.trigger` — trigger call example
- `idempotency_key` — required trigger option
- `tenant_id` — required trigger option
- `orchestrates` — responsibility split language
- `DemoHost.Seeds.seed_sigra` — runnable demo pointer (matches prefix of any `seed_sigra_*` function name)
- `/admin/chimeway` — operator trace inspectability path
- `sigra-auth-integration.md` — reciprocal cross-link to Phase 66 guide

**Forbidden phrases (Phase 64 D-07 redaction enforcement — `@forbidden_phrases` in doc-contract):**
- `raw_token` — must never appear in blueprint code examples
- `confirmation_code` as a literal parameter value (the code verbatim) — not as a concept name

**Example — responsibility split section (verified from accrue-dunning-blueprint.md):**
```markdown
## Responsibility split (SEED-003)

**Chimeway orchestrates the when and why:** durable notification lifecycle,
suppression and preference gates, idempotency, and operator traces you can
search at `/admin/chimeway`.

**Sigra owns auth state:** token generation, hashed persistence, rate limits,
and magic link / confirmation code TTL. Sigra emits auth events; Chimeway does
not mutate Sigra records.

This integration is **not** a `Chimeway.Adapter` seam — it is a Sigra auth
event → `Chimeway.trigger/3` bridge only.
```

### Pattern 2: Doc-Contract Describe Block

**What:** An `ExUnit.describe` block in `test/chimeway/doc_contract_test.exs` that reads the blueprint Markdown file and asserts required/forbidden string presence.

**When to use:** Every published blueprint recipe (ECOS-05, ECOS-07, ECOS-10).

**Verified structure (from lines ~297 of doc_contract_test.exs):**

```elixir
# Source: test/chimeway/doc_contract_test.exs lines ~297 (ECOS-07 block as template)
@sigra_blueprint_recipe Path.expand("../../guides/recipes/sigra-auth-blueprint.md", __DIR__)

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

**Key detail:** `@recipe_forbidden_strings` is already defined at the module level (line ~104): `~w(stop_conditions Workflows.Workers Chimeway.Trigger.trigger)`. The new ECOS-10 block reuses this — no new module-level attribute needed.

### Pattern 3: Demo Host Proof Test

**What:** A demo host test file that proves an ecosystem integration end-to-end via `DemoHost.Seeds.*` entry points and asserts operator trace inspectability at `/admin/chimeway`.

**When to use:** Every DEMO-0N proof for an ecosystem integration (DEMO-07 Accrue, DEMO-08 Inbox, DEMO-09 Threadline, DEMO-10 Sigra).

**Verified structure (from accrue_dunning_proof_test.exs):**

```elixir
# Source: examples/chimeway_demo_host/test/demo_host_web/accrue_dunning_proof_test.exs
if Code.ensure_loaded?(MODULE_A) and Code.ensure_loaded?(MODULE_B) do
  defmodule DemoHostWeb.XxxProofTest do
    use DemoHostWeb.ConnCase, async: false
    use Oban.Testing, repo: Chimeway.Repo

    import Phoenix.LiveViewTest

    @moduletag :ecosystem_tag   # :threadline or :sigra

    setup do
      # repo sandbox checkout for the ecosystem's TestRepo
      # attach reporter or configure integration
      # adapter config
      # on_exit cleanup
      :ok
    end

    test "DEMO-0N primary proof" do
      assert {:ok, result} = DemoHost.Seeds.seed_xxx()
      # assert delivery/audit_action row
    end

    test "DEMO-0N admin trace shows workflow", %{conn: conn} do
      assert {:ok, result} = DemoHost.Seeds.seed_xxx()

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
  end
end
```

**Threadline-specific proof considerations (DEMO-09):**
- Guard: `Code.ensure_loaded?(Threadline) and Code.ensure_loaded?(Chimeway.Telemetry.ThreadlineReporter)`
- `@moduletag :threadline`
- Setup must: checkout `Threadline.Test.Repo` sandbox, `attach_threadline_reporter!()`, configure Logger adapter, `on_exit` detach
- Primary assertion: Threadline `audit_actions` row exists with matching `correlation_id` — this goes beyond the Accrue proof which only asserts delivery rows
- The `seed_threadline_notification/0` helper returns a result map including `correlation_id` and `delivery_ids`
- The demo host `test_helper.exs` already handles `Threadline.Test.Repo` bootstrap (Phase 63 shipped this) — verify before assuming

**Sigra-specific proof considerations (DEMO-10):**
- Guard: `Code.ensure_loaded?(Sigra) and Code.ensure_loaded?(Sigra.Integrations.Chimeway)`
- `@moduletag :sigra`
- Setup must: checkout `Sigra.TestRepo` sandbox, configure Sigra Chimeway integration, configure Logger adapter, `on_exit` cleanup
- The `seed_sigra_auth/0` helper calls `Sigra.Integrations.Chimeway.dispatch_magic_link_after_request` or `dispatch_confirmation_after_generate` internally via the existing Sigra integration (Phase 64)
- The demo proof mirrors the lifecycle test structure but adds the `/admin/chimeway` LiveView assertion layer

### Pattern 4: DemoHost.Seeds Ecosystem Helper

**What:** A `@spec seed_xxx() :: {:ok, map()} | {:error, term()}` function in `DemoHost.Seeds` that calls the ecosystem integration's trigger entry point and returns a normalized result map with `recipient_identity`, `trace.delivery_ids`, and any ecosystem-specific fields.

**Verified pattern (from seeds.ex `seed_accrue_dunning/0`):**

```elixir
# Source: examples/chimeway_demo_host/lib/demo_host/seeds.ex lines ~139
@doc """
DEMO-07: Accrue billing-event dunning through Chimeway with Logger email delivery.
Standalone API; not invoked from `run/0`.
"""
@spec seed_accrue_dunning() :: {:ok, map()} | {:error, term()}
def seed_accrue_dunning do
  if Code.ensure_loaded?(DemoHost.AccrueSeeds) do
    DemoHost.AccrueSeeds.seed_accrue_dunning()
  else
    {:error, :accrue_not_available}
  end
end
```

**For `seed_threadline_notification/0`:** Uses `Chimeway.trigger/3` directly (like `seed_invite/0`) but also attaches the ThreadlineReporter — or more precisely, the *proof test's setup* attaches the reporter, and the seed helper is a pure `Chimeway.trigger/3` call. The seed helper returns `{:ok, %{recipient_identity:, trace: %{delivery_ids:, correlation_id:}}}`.

**For `seed_sigra_auth/0`:** Delegates to `Sigra.Integrations.Chimeway` (via `Code.ensure_loaded?` guard), analogous to `seed_accrue_dunning/0` delegating to `DemoHost.AccrueSeeds`. Returns `{:ok, map()}` with `recipient_identity` and `trace.delivery_ids` that the admin LiveView assertion can use.

**Key insight about `seed_threadline_notification/0`:** The ThreadlineReporter must be attached *before* the trigger fires for audit rows to appear. In the lifecycle test, this is handled in `setup`. In the demo host proof, the same pattern applies — `setup` attaches reporter, then the test calls `DemoHost.Seeds.seed_threadline_notification/0`. The seed helper itself does NOT attach the reporter; attachment belongs in test setup.

**Return map shape consistency:** The `/admin/chimeway` assertion pattern (Accrue proof lines 95–124) requires `result.recipient_identity` and `hd(result.trace.delivery_ids)`. Both new seed helpers must return a map with exactly these keys.

### Pattern 5: HexDocs Extras Registration

**What:** Adding the new blueprint file path to the `extras` list in `mix.exs` `docs/0`.

**Current extras list ending (verified from mix.exs lines ~193):**
```elixir
"guides/recipes/accrue-dunning-blueprint.md",
"guides/recipes/mailglass-integration-blueprint.md",
# ... other recipes
```

**Required addition:**
```elixir
"guides/recipes/sigra-auth-blueprint.md",
```

**Positioning:** The existing HexDocs extras contract test (lines ~851–901) only tests the three integration *guide* files (`mailglass-integration.md`, `accrue-dunning-integration.md`, `inbox-integration.md`) and their relative ordering. It does NOT assert relative ordering of blueprint *recipes*. The sigra blueprint can be inserted after the accrue blueprint in the recipes section — no ordering constraint to satisfy for the existing tests.

**Note:** The Phase 65 doc-contract does NOT add a new test asserting `guides/recipes/sigra-auth-blueprint.md` appears in HexDocs extras. D-09 states the addition ensures the *existing* contract test catches omissions — but the existing hexdocs extras test only checks integration guides, not recipe blueprints. The ECOS-10 doc-contract describe block covers the blueprint content; HexDocs extras registration ensures publishability. The planner should note this: adding `sigra-auth-blueprint.md` to `mix.exs` extras is needed for correct publishing but is NOT gated by an existing extras contract test assertion. Phase 65 may want to add a simple extras assertion for the blueprint file path (analogous to ECOS-07 enforcement) — this is Claude's discretion territory.

### Anti-Patterns to Avoid

- **Forgetting the `Code.ensure_loaded?` module guard in demo proof test files:** Without the guard the test module fails to compile when Sigra/Threadline are not available. Every ecosystem proof file must be wrapped.
- **Attaching ThreadlineReporter inside the seed helper:** Reporter attach belongs in `setup`, not in the seed. Seeds are adopter-copyable public API and should not embed test infrastructure concerns.
- **Using `Chimeway.Dispatch.Oban` in Sigra demo proof without queue drain:** The Sigra lifecycle tests (Phase 64) configure `Chimeway.Dispatch.Sync`. If the demo proof uses Sync dispatcher the `Oban.Testing` import is still present (for consistency) but queue drain is not strictly needed. If Oban dispatcher is used, `Oban.drain_queue(queue: :chimeway_delivery)` is needed before asserting delivery status.
- **Hardcoding the delivery_id vs using `hd(result.trace.delivery_ids)`:** The Accrue proof demonstrates the correct pattern — get delivery IDs from the seed result, not from a Repo query in the test body.
- **Required strings in ECOS-10 doc-contract that do not appear in the blueprint:** The required string list must be drafted *alongside* the blueprint content, not independently, to avoid false contract failures.
- **`mix.exs` HexDocs extras adding the introduction guide (Phase 66) prematurely:** Phase 65 adds only the blueprint recipe (`guides/recipes/sigra-auth-blueprint.md`). The integration guide (`guides/introduction/sigra-auth-integration.md`) is Phase 66 DOCS-10.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Demo host repo sandbox setup for Threadline TestRepo | Custom sandbox boilerplate | Existing `Threadline.DataCase` pattern from `test/support/threadline/data_case.ex` | Already handles dual-repo (Threadline.Test.Repo + Chimeway.Repo) checkout/cleanup |
| Threadline reporter config/attach/detach | Custom handler management | `attach_threadline_reporter!()` / `detach_threadline_reporter!()` from `Chimeway.TestSupport.ThreadlineFixtures` | Already imported by any test using `Threadline.DataCase` |
| Sigra repo sandbox for demo host | Custom setup | Mirror `accrue_dunning_proof_test.exs` + Sigra DataCase pattern from `test/support/sigra/data_case.ex` | Pattern already exists in root Chimeway tests |
| `/admin/chimeway` LiveView trace search | New admin surface | Existing `ChimewayAdmin` mounted at `/admin/chimeway` in demo host router | Already proven in DEMO-07 (accrue proof lines 95–124) and JOUR-04/07/08 |
| `@recipe_forbidden_strings` in ECOS-10 block | New module-level attribute | Reuse the existing `@recipe_forbidden_strings ~w(stop_conditions Workflows.Workers Chimeway.Trigger.trigger)` already defined in `doc_contract_test.exs` | Module attribute already in scope |

**Key insight:** Phase 65 is explicitly a copy-and-adapt phase. Every structure needed already exists in the codebase. The risk is not "build vs buy" but "copy wrongly" — the planner must reference the exact file paths and line ranges for templates.

---

## Common Pitfalls

### Pitfall 1: Demo Host test_helper.exs Missing Threadline/Sigra Bootstrap

**What goes wrong:** The demo host `test_helper.exs` already bootstraps Mailglass and Accrue TestRepos. If Threadline and Sigra TestRepo bootstraps are not present (or were not added in Phase 63/64), the demo proof tests will fail at test startup with database connection errors.

**Why it happens:** Phase 63 and Phase 64 added bootstrap code to the *root* `test/test_helper.exs` (for root Chimeway integration tests), but the demo host has its own `examples/chimeway_demo_host/test/test_helper.exs`. This file handles Mailglass and Accrue separately; Threadline and Sigra bootstrap may or may not have been added.

**How to avoid:** Before writing the demo proof tests, verify `examples/chimeway_demo_host/test/test_helper.exs` contains `if Code.ensure_loaded?(Threadline)` and `if Code.ensure_loaded?(Sigra)` blocks analogous to the Accrue block (lines ~44–107 of the current file). If missing, add them as Wave 0 tasks in the plan.

**Warning signs:** `(DBConnection.OwnershipError)` or `(UndefinedFunctionError) Threadline.Test.Repo.start_link/0 is undefined` at test startup.

### Pitfall 2: `@compile {:no_warn_undefined, [...]}` Missing in Seeds Module

**What goes wrong:** When `Sigra.Integrations.Chimeway` is not loaded (Sigra not in deps), the compiler warns about undefined module calls in `DemoHost.Seeds`.

**Why it happens:** Elixir emits undefined module warnings even when the call is guarded by `Code.ensure_loaded?` at runtime. The Accrue precedent uses `@compile {:no_warn_undefined, [DemoHost.AccrueSeeds]}` to suppress this.

**How to avoid:** Add `@compile {:no_warn_undefined, [Sigra.Integrations.Chimeway]}` (or equivalent) at the top of the `DemoHost.Seeds` additions, as the module already does for `DemoHost.AccrueSeeds`.

**Warning signs:** `warning: Sigra.Integrations.Chimeway is undefined` during `mix compile` even when Sigra is not available.

### Pitfall 3: Demo Proof Tests Not Excluded from Default demo host `mix test`

**What goes wrong:** `mix verify.example` runs `cd examples/chimeway_demo_host && mix test` without any `--exclude` flags. If Threadline/Sigra are not available (no `THREADLINE_PATH`/`SIGRA_PATH`), the `Code.ensure_loaded?` module guard prevents the test module from being defined, so the tests simply don't exist. This is correct behavior — the guard pattern itself handles exclusion. No additional `--exclude` wiring is needed in the demo host.

**Why it is NOT a pitfall:** This is the established pattern. The `Code.ensure_loaded?` wrapper means the test module only exists when the dep is loaded. When the dep is unavailable, the file compiles to nothing and ExUnit sees no tests from that file.

**Remaining concern:** Verify that `mix verify.accrue` (which runs the demo host with `--only accrue`) is the model for how Threadline/Sigra demo proofs would eventually be run in `mix verify.threadline`/`mix verify.sigra` (Phase 66 GATE-07). Phase 65 does NOT add these aliases — just confirm the proof tests are tagged correctly so Phase 66 can wire them trivially.

### Pitfall 4: doc-contract `@required` Strings Not Present in Blueprint

**What goes wrong:** The ECOS-10 doc-contract `@required` string list is written before the blueprint is finalized, resulting in strings that the blueprint author forgot to include — or vice versa, the blueprint contains different phrasing than the doc-contract checks.

**Why it happens:** The doc-contract and blueprint must be co-authored. The required strings are substring matches — `"DemoHost.Seeds.seed_sigra"` will match `seed_sigra_auth/0`, `seed_sigra_magic_link/0`, etc. Use prefix-matching strings for flexibility where the exact function name is Claude's discretion.

**How to avoid:** Write the doc-contract required strings as prefixes/substrings that will survive any of the allowed seed helper name variants. Draft the blueprint first, then derive the required strings from its actual content.

**Warning signs:** New doc-contract describe block causes immediate test failures after writing the blueprint — indicates a mismatch between `@required` list and actual blueprint content.

### Pitfall 5: ThreadlineReporter Not Attached in Demo Host for Proof Test

**What goes wrong:** `seed_threadline_notification/0` triggers a Chimeway notification, but no Threadline `audit_actions` row is created because `Chimeway.Telemetry.ThreadlineReporter` is not attached in the demo host's test process.

**Why it happens:** The ThreadlineReporter is an optional telemetry handler. In production it would be attached in `Application.start/2`. In tests, it must be attached in `setup`. The Accrue demo proof does not need this pattern (Accrue's engine is configured via `Application.put_env`), but the Threadline proof specifically requires the reporter to be running.

**How to avoid:** Demo host proof `setup` must call `attach_threadline_reporter!()` (from `Chimeway.TestSupport.ThreadlineFixtures`) and configure the threadline reporter with the test repo/actor. The `on_exit` must call `detach_threadline_reporter!()`. The seed helper itself does nothing with the reporter.

**Warning signs:** `seed_threadline_notification/0` returns `{:ok, result}` but the subsequent `audit_actions` row assertion fails with "expected exactly one :notification_dispatched audit row... got 0."

### Pitfall 6: Sigra `dispatch_*` Functions Require Correct Config in Demo Host Test

**What goes wrong:** The Sigra demo proof calls `DemoHost.Seeds.seed_sigra_auth/0` which internally calls Sigra dispatch functions. These require Sigra to be configured with a `:repo` pointing to the test process's sandbox-checked-out `Sigra.TestRepo`.

**Why it happens:** `configure_sigra_chimeway_integration!()` (from `Chimeway.TestSupport.SigraFixtures`) sets `Application.put_env(:sigra, :repo, Sigra.TestRepo)` and `Application.put_env(:sigra, :chimeway, enabled: true)`. If these calls are not in the demo host proof's `setup`, the dispatch will fail with repo ownership errors or disabled integration errors.

**How to avoid:** The demo host proof `setup` must mirror `configure_sigra_chimeway_integration!()`. Since `Chimeway.TestSupport.SigraFixtures` is a root test support module (not available to the demo host), the demo host must inline equivalent setup or import from a support file. The cleanest solution is to replicate the needed setup directly in the test's `setup` block (as `accrue_dunning_proof_test.exs` inlines `configure_chimeway_dunning_engine!()` via `DemoHost.AccrueFixtures`).

---

## Code Examples

Verified patterns from the existing codebase.

### Demo Proof Module Structure (verified from accrue_dunning_proof_test.exs)

```elixir
# Source: examples/chimeway_demo_host/test/demo_host_web/accrue_dunning_proof_test.exs
if Code.ensure_loaded?(Threadline) and
     Code.ensure_loaded?(Chimeway.Telemetry.ThreadlineReporter) do
  defmodule DemoHostWeb.ThreadlineTelemetryProofTest do
    use DemoHostWeb.ConnCase, async: false
    use Oban.Testing, repo: Chimeway.Repo

    import Phoenix.LiveViewTest
    import Ecto.Query

    @moduletag :threadline

    alias Threadline.Semantics.AuditAction
    alias Threadline.Test.Repo, as: ThreadlineRepo

    setup do
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(ThreadlineRepo)
      Ecto.Adapters.SQL.Sandbox.mode(ThreadlineRepo, {:shared, self()})

      # ThreadlineRepo must be clean for audit row assertion
      ThreadlineRepo.delete_all(AuditAction)

      attach_threadline_reporter!()   # from Chimeway.TestSupport.ThreadlineFixtures
      configure_chimeway_logger_adapter!()

      on_exit(fn -> detach_threadline_reporter!() end)

      :ok
    end

    test "DEMO-09 threadline audit row created for notification lifecycle event" do
      assert {:ok, result} = DemoHost.Seeds.seed_threadline_notification()

      rows = ThreadlineRepo.all(
        from(a in AuditAction,
          where: a.correlation_id == ^result.trace.correlation_id
        )
      )
      assert length(rows) >= 1
    end

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
  end
end
```

### `seed_threadline_notification/0` Shape (verified pattern from seeds.ex)

```elixir
# Source: examples/chimeway_demo_host/lib/demo_host/seeds.ex (pattern from seed_invite/0)
@doc """
DEMO-09: Threadline audit correlation for notification lifecycle with reporter attached.
Standalone API; not invoked from `run/0`.
"""
@spec seed_threadline_notification() :: {:ok, map()} | {:error, term()}
def seed_threadline_notification do
  if Code.ensure_loaded?(Chimeway.Telemetry.ThreadlineReporter) do
    trigger(
      DemoHost.Notifiers.InviteSent,         # or a minimal inline notifier
      %{email: @alex_email, team_name: "Threadline Demo"},
      idempotency_key: "teampulse-seed-threadline-v1-#{System.unique_integer([:positive])}",
      correlation_id: "teampulse-seed-threadline-corr",
      tenant_id: @tenant_id
    )
  else
    {:error, :threadline_not_available}
  end
end
```

**Note on idempotency key uniqueness:** Unlike other seeds, `seed_threadline_notification/0` may need a unique suffix per call so repeated invocations each create a fresh audit row for assertion. The `System.unique_integer` pattern is used in lifecycle tests for this purpose.

### ECOS-10 Doc-Contract `@required` List (verified against D-08)

```elixir
# These strings MUST appear verbatim in guides/recipes/sigra-auth-blueprint.md
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
```

### mix.exs HexDocs Extras Addition

```elixir
# Source: mix.exs docs/0 extras list — add after existing blueprint entries
"guides/recipes/accrue-dunning-blueprint.md",
"guides/recipes/mailglass-integration-blueprint.md",
"guides/recipes/sigra-auth-blueprint.md",    # ADD THIS
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Demo proofs as journey tests | Demo proofs as isolated `@moduletag :ecosystem_tag` files | Phase 56 (DEMO-07) | Ecosystem proofs excluded from default `mix test`, run only with `mix verify.*` |
| Blueprint + guide in one document | Blueprint recipe (focused) + separate integration guide (golden path) | Phase 57 D-02 | Blueprint is standalone recipe; guide owns end-to-end; cross-links tie them together |
| Manual doc verification | Doc-contract `describe` blocks in CI | Phase 57 (GATE-02/03) | Required string failures catch doc drift immediately |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The demo host `test_helper.exs` has Threadline and Sigra TestRepo bootstrap blocks (added in Phases 63/64) | Common Pitfalls — Pitfall 1 | Demo proof tests fail at startup; Wave 0 task needed to add bootstrap |
| A2 | `Chimeway.TestSupport.ThreadlineFixtures` helpers (`attach_threadline_reporter!`, etc.) are importable from the demo host proof test via `import` or equivalent | Architecture Patterns — Pattern 3 | May need to replicate fixture helpers directly in the demo host test support |
| A3 | `seed_sigra_auth/0` will use `dispatch_magic_link_after_request` as the primary flow (magic link is the more important ECOS-09 flow per D-04/D-05) | Code Examples | Confirmation code path equally valid per Phase 64 D-05; either works |
| A4 | The existing `@recipe_forbidden_strings` in `doc_contract_test.exs` is sufficient for ECOS-10 and no new forbidden strings need to be defined at module level | Architecture Patterns — Pattern 2 | May need inline forbidden phrases for raw token / confirmation code verbatim |
| A5 | `Chimeway.TestSupport.SigraFixtures` helpers are NOT directly importable from demo host tests (root test support is not in demo host elixirc_paths) | Common Pitfalls — Pitfall 6 | If they ARE importable, the setup becomes simpler; if not, setup must be inlined |

**If this table is empty:** All claims were verified — not applicable here; five assumptions recorded.

---

## Open Questions

1. **Is the demo host `test_helper.exs` already updated with Threadline/Sigra bootstrap?**
   - What we know: Root `test/test_helper.exs` has Mailglass/Accrue bootstrap; Phase 63/64 added root-level integration tests. Demo host `test_helper.exs` currently has Mailglass + Accrue blocks.
   - What's unclear: Whether Phases 63/64 also updated the demo host `test_helper.exs` with Threadline/Sigra bootstrap.
   - Recommendation: Read `examples/chimeway_demo_host/test/test_helper.exs` first in Wave 0. If Threadline/Sigra blocks are absent, add them as the first Wave 0 task before writing proof tests.

2. **Can demo host proof tests import `Chimeway.TestSupport.ThreadlineFixtures` and `Chimeway.TestSupport.SigraFixtures`?**
   - What we know: The root `test/support/` is in `elixirc_paths(:test)` for the root app. The demo host is a separate Mix project with its own `elixirc_paths`.
   - What's unclear: Whether the demo host's test setup can resolve root Chimeway test support modules (they would be available if the Chimeway dep is loaded in :test scope).
   - Recommendation: Check demo host `mix.exs` `elixirc_paths`. If root test support is NOT accessible, the demo host needs its own equivalent fixture helpers (or inline setup as `accrue_dunning_proof_test.exs` does via `DemoHost.AccrueFixtures`).

3. **Should the ECOS-10 doc-contract add an explicit HexDocs extras assertion for `sigra-auth-blueprint.md`?**
   - What we know: The existing hexdocs extras test (lines ~851–901) checks only integration guides, not recipe blueprints. D-09 says adding the file "so the existing contract catches omissions" — but the existing test does not check for blueprint recipes.
   - What's unclear: Whether Phase 65 should add a new assertion for the blueprint in the hexdocs contract block, or leave that for Phase 66.
   - Recommendation: Add a simple assertion in the hexdocs extras describe block for `guides/recipes/sigra-auth-blueprint.md` — one-line addition, prevents silent omission.

---

## Environment Availability

This phase is purely documentation + test additions with no new external tools.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir / Mix | All tasks | Verified in project | ~> 1.17 | — |
| Threadline dep | DEMO-09 proof test + seed | Phase 63 shipped (optional dep in mix.exs) | ~> 0.7 | Test excluded by `Code.ensure_loaded?` guard |
| Sigra + Sigra.Integrations.Chimeway | DEMO-10 proof test + seed | Phase 64 shipped (optional dep in mix.exs) | ~> 0.3 | Test excluded by `Code.ensure_loaded?` guard |
| Chimeway.Telemetry.ThreadlineReporter | DEMO-09 proof | Phase 63 shipped | — | — |
| `/admin/chimeway` route | DEMO-09 + DEMO-10 trace inspectability | Existing demo host router | — | — |

**Missing dependencies with no fallback:** None.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir built-in) |
| Config file | `test/test_helper.exs`, demo host: `examples/chimeway_demo_host/test/test_helper.exs` |
| Quick run command | `mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` |
| Full suite command | `mix ci.test` (core) + `cd examples/chimeway_demo_host && mix test` (demo host) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ECOS-10 | Blueprint contains all required strings | doc-contract | `mix test test/chimeway/doc_contract_test.exs -k "ECOS-10"` | ❌ Wave 0 (new describe block) |
| ECOS-10 | Blueprint file in HexDocs extras | doc-contract | `mix test test/chimeway/doc_contract_test.exs -k "hexdocs"` | ❌ Wave 0 (new assertion) |
| DEMO-09 | Threadline audit row from notification lifecycle | integration | `cd examples/chimeway_demo_host && mix test --only threadline` | ❌ Wave 0 |
| DEMO-10 | Sigra auth delivery created + traced | integration | `cd examples/chimeway_demo_host && mix test --only sigra` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `mix test test/chimeway/doc_contract_test.exs --warnings-as-errors`
- **Per wave merge:** `mix ci.verify_gates` + `cd examples/chimeway_demo_host && mix test --only threadline --only sigra`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `guides/recipes/sigra-auth-blueprint.md` — covers ECOS-10
- [ ] `test/chimeway/doc_contract_test.exs` ECOS-10 describe block — covers ECOS-10 CI doc-contract
- [ ] `examples/chimeway_demo_host/test/demo_host_web/threadline_telemetry_proof_test.exs` — covers DEMO-09
- [ ] `examples/chimeway_demo_host/test/demo_host_web/sigra_auth_proof_test.exs` — covers DEMO-10
- [ ] `examples/chimeway_demo_host/lib/demo_host/seeds.ex` additions (`seed_threadline_notification/0`, `seed_sigra_auth/0`) — covers both DEMO-09 and DEMO-10
- [ ] `mix.exs` HexDocs extras addition — covers ECOS-10 publishability

---

## Security Domain

The blueprint document is documentation only. The demo proof tests exercise already-implemented security properties from Phase 64.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | Phase 65 is docs + test only |
| V5 Input Validation | Inherited | `sanitize_payload/1` + `@sensitive_keys` already enforced in Phase 64 |
| Sensitive data in docs | Yes | Blueprint must NOT include example code that passes `raw_token`, `code`, or full magic-link URLs into `Chimeway.trigger/3` params |

**Specific doc-security requirement:** The Sigra auth blueprint code examples must show identifier-only params (e.g., `user_id`, `email`, `correlation_id`) in the `Chimeway.trigger/3` call — never raw tokens or confirmation codes. This is both a correctness requirement (Phase 64 D-07) and a doc-security requirement. The ECOS-10 doc-contract `@forbidden_phrases` list should enforce this.

**Forbidden phrases for ECOS-10 doc-contract (Phase 64 D-07 redaction enforcement):**
```elixir
@sigra_blueprint_forbidden_phrases [
  "raw_token",              # must never appear in trigger params example
  "raw token",             # prose form
  "confirmation_code verbatim"  # placeholder — exact phrase TBD based on blueprint authoring
]
```

---

## Sources

### Primary (HIGH confidence)

- `guides/recipes/accrue-dunning-blueprint.md` — verified blueprint section structure and content (direct codebase read)
- `test/chimeway/doc_contract_test.exs` — verified ECOS-05/07 describe block patterns, `@recipe_forbidden_strings`, hexdocs extras test (direct codebase read, full file)
- `examples/chimeway_demo_host/test/demo_host_web/accrue_dunning_proof_test.exs` — verified demo proof module structure, setup pattern, LiveView search assertion (direct codebase read)
- `examples/chimeway_demo_host/lib/demo_host/seeds.ex` — verified seed helper patterns, `Code.ensure_loaded?` delegate, result map shape (direct codebase read)
- `mix.exs` — verified HexDocs extras list, alias definitions, optional dep patterns (direct codebase read)
- `test/support/threadline/fixtures.ex` — verified `attach_threadline_reporter!`, `configure_threadline_reporter!`, `detach_threadline_reporter!` helpers (direct codebase read)
- `test/support/sigra/fixtures.ex` — verified `configure_sigra_chimeway_integration!`, `refute_sensitive_in_trace!`, telemetry handler helpers (direct codebase read)
- `test/chimeway/integrations/threadline_telemetry_lifecycle_test.exs` — verified audit row assertion pattern, `correlation_id` chain (direct codebase read)
- `test/chimeway/integrations/sigra_auth_lifecycle_test.exs` — verified Sigra dispatch function names, trace assertion pattern (direct codebase read)
- `.planning/phases/65-ecosystem-blueprints-demo/65-CONTEXT.md` — locked decisions D-01 through D-09 (direct read)
- `.planning/phases/63-threadline-telemetry-bridge/63-CONTEXT.md` — ThreadlineReporter attach pattern, Phase 63 scope (direct read)
- `.planning/phases/64-sigra-auth-flows-core/64-CONTEXT.md` — Sigra integration seam, dispatch function names, redaction requirements (direct read)

### Secondary (MEDIUM confidence)

- `examples/chimeway_demo_host/test/test_helper.exs` — verified current Accrue/Mailglass bootstrap patterns; Threadline/Sigra bootstrap presence assumed from Phase 63/64 delivery (direct codebase read — but current file content was fully read and does NOT contain Threadline/Sigra blocks — this is Assumption A1)
- `examples/chimeway_demo_host/test/support/conn_case.ex` — verified ConnCase setup pattern (direct codebase read)

---

## Metadata

**Confidence breakdown:**
- Blueprint document structure: HIGH — direct template exists in codebase (accrue-dunning-blueprint.md)
- Doc-contract describe block structure: HIGH — direct template exists in codebase (ECOS-07 block)
- Demo proof test structure: HIGH — direct template exists (accrue_dunning_proof_test.exs)
- Seed helper shape: HIGH — direct pattern exists (seed_accrue_dunning/0)
- mix.exs extras: HIGH — current list verified
- Assumption A1 (demo host test_helper has Threadline/Sigra): LOW — file read and bootstrap blocks are NOT present in current content (only Mailglass + Accrue); this is a Wave 0 gap

**Research date:** 2026-05-30
**Valid until:** 2026-06-30 (stable — all sources are local codebase, not external APIs)
