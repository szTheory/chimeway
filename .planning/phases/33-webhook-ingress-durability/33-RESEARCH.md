# Phase 33: Webhook Ingress Durability - Research

**Researched:** 2026-05-01
**Domain:** Webhook ingress durability, atomic Multi+Oban handoff, host-mounted Phoenix proof
**Confidence:** HIGH

## Summary

Phase 33 closes three concrete v1.4 audit gaps in the existing webhook pipeline without
broadening scope: (1) `Chimeway.Webhooks.process/4` currently acknowledges success even
when the Oban enqueue is silently dropped, (2) `ProcessFeedbackWorker.perform/1` raises
on unknown `delivery_id` via `Deliveries.get_delivery!/1`, and (3) the repo has no
runtime proof that the pure-function seam can actually be mounted as host HTTP.

The shape of the fix is fully constrained by CONTEXT.md: introduce a durable
`chimeway_webhook_ingress` row, atomically commit it together with the
`ProcessFeedbackWorker` Oban job inside one `Ecto.Multi` (mirroring `Chimeway.Signal.track/4`
verbatim), pivot the worker from raising lookups to noop-on-missing-row + ignored-reason
write (mirroring `Chimeway.Dispatch.WorkflowProgressionWorker.normalize_progress_result/1`),
and ship a fixture Phoenix host app under `examples/` that proves the mount pattern using
`Plug.Parsers` `:body_reader` for raw-body preservation.

Two precedents in the codebase already encode the locked patterns. **Replicate, do not
reinvent.** `lib/chimeway/signal.ex:30-40` is the literal template for D-02's atomic
handoff. `lib/chimeway/dispatch/workflow_progression_worker.ex:67-74` is the literal
template for D-06/D-07's safe-noop pivot. The example app pattern is constrained by Plug's
official `:body_reader` MFA contract — there is exactly one canonical shape, documented at
hexdocs.pm/plug/Plug.Parsers.html.

**Primary recommendation:** Ship Phase 33 as five sequential plans — (1) ingress schema +
migration, (2) `Webhooks.process/4` atomic handoff rewrite, (3) `ProcessFeedbackWorker`
ingress-driven pivot with safe-noop, (4) `examples/chimeway_demo_host` fixture Phoenix app
under a sibling Mix project, (5) test extensions wiring the new contract. No new public
behaviour callbacks; the existing `Chimeway.Adapter` callbacks (`verify_webhook/3`,
`resolve_delivery/1`, `normalize_feedback/1`) are unchanged.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Provider HTTP receipt + raw body preservation | Frontend Server (host Phoenix) | — | Per D-10/D-11, this lives in the host app, not Chimeway core. Raw bytes must be cached before any parser consumes them. |
| HMAC signature verification (per-adapter) | API / Backend (`Chimeway.Webhooks` -> Adapter) | — | `verify_webhook/3` runs on raw bytes synchronously inside `process/4` per D-13. |
| Durable ingress row insert | Database | API / Backend | Inside the `Ecto.Multi` transaction; the row is the explainability anchor (D-04, D-05). |
| Async work handoff | API / Backend (`Oban.insert` in same Multi) | Database | Atomic with the ingress row insert per D-02. |
| Stale/unknown correlation handling | API / Backend (`ProcessFeedbackWorker`) | Database | Worker reads ingress row, writes ignored reason, returns `:ok` per D-06/D-07. |
| Host HTTP error mapping | Frontend Server (host controller) | — | Translates `process/4` returns to status codes per D-03 — strictly host concern. |

## User Constraints (from CONTEXT.md)

### Locked Decisions

**Durable ingress handoff:**
- **D-01:** Phase 33 extends Chimeway's durable lifecycle spine with a dedicated inbound webhook ingress record for trusted callbacks. The durable path becomes: `provider callback -> verified ingress row -> queued feedback worker -> delivery attempt -> signal/workflow/traces`.
- **D-02:** `Chimeway.Webhooks.process/4` is the acknowledgment boundary. It MUST return success only after one `Ecto.Multi` transaction commits both: (1) insertion of the ingress row, and (2) insertion of the `ProcessFeedbackWorker` Oban job. Any queue insertion or validation failure returns an explicit error tuple.
- **D-03:** The host HTTP layer owns HTTP mapping, but the canonical contract is: `{:ok, ingress}` or `{:ok, job}` -> host may return `2xx`; `{:error, :unauthorized}` -> host returns `401`; all other library-level failures -> host returns a non-`2xx` status so the provider can retry.
- **D-04:** The ingress row stores only provider-safe, payload-safe, explainability-first fields needed for audit and replay. Do NOT persist arbitrary full raw payloads or secret headers by default. Persist normalized status, adapter identity, correlation keys, provider event/message ids when available, durable ingress outcome, and timestamps.
- **D-05:** If the adapter exposes a stable provider event identifier, the ingress row should persist it and use it as the primary duplicate-collapse seam together with adapter identity. Duplicate provider retries should converge on the same ingress fact rather than creating unbounded inbound noise.

**Safe stale / unknown callback handling:**
- **D-06:** Unknown or stale `delivery_id` and `provider_message_id` callbacks are treated as understood-but-ignored async events, not worker failures. `ProcessFeedbackWorker` must stop using raising lookup paths like `get_delivery!/1` for this boundary.
- **D-07:** Missing delivery correlation returns `:ok` from the worker to avoid Oban retry storms, but MUST update the ingress row with an explicit ignored reason such as `delivery_not_found`, `provider_message_id_not_found`, or equivalent durable status.
- **D-08:** The ignored/stale audit lives on the new ingress surface, not on `DeliveryAttempt`. A delivery attempt means Chimeway resolved a canonical delivery row and recorded an actual delivery lifecycle fact; unresolved inbound callbacks are a different durable concept and should not overload attempt semantics.
- **D-09:** Unauthorized signature failures and malformed/unparseable requests do NOT get a durable ingress row in core. They remain host-edge concerns surfaced through safe error tuples and optional telemetry/logging. Only requests that pass adapter verification and basic parsing enter Chimeway's durable inbound lifecycle.

**Host ingress proof and developer ergonomics:**
- **D-10:** Chimeway core stays framework-agnostic. Do NOT add a Chimeway-owned Plug, Phoenix controller helper, or pseudo-request-map adapter in core for Phase 33.
- **D-11:** The runtime proof requirement is satisfied with an executable example or fixture Phoenix host app that mounts a real route, preserves the raw request body via `Plug.Parsers` `:body_reader`, calls `Chimeway.Webhooks.process/4`, and proves the success/error mapping end to end.
- **D-12:** The example app becomes the canonical reference for docs. Guides should point to that fixture instead of repeating large copy-paste controller snippets in multiple places, to reduce drift and keep one blessed mount pattern.
- **D-13:** The example ingress path should emphasize the ecosystem footgun explicitly: signature verification must operate on the exact raw request body bytes before JSON parsing or body mutation. This is a first-class DX concern, not incidental setup.

**Scope and sequencing:**
- **D-14:** Phase 33 is deliberately narrow: ingress durability, safe stale handling, and host-mounted proof only. Outcome vocabulary unification and the real webhook → workflow → trace end-to-end contract stay reserved for Phase 34.

### Claude's Discretion (per CONTEXT.md)

- Exact ingress schema naming (`webhook_ingress`, `feedback_ingress`, etc.) so long as it clearly represents trusted inbound provider callback facts rather than generic host HTTP traffic.
- Exact enum/string vocabulary for ingress processing states (`queued`, `processed`, `ignored`, `failed`) so long as the write/read path stays explicit and queryable.
- Whether `process/4` returns the ingress row, the Oban job, or a compact result struct, so long as success only means the transaction committed and the host can map it cleanly to `2xx`.

### Deferred Ideas (OUT OF SCOPE)

- Cross-phase outcome vocabulary unification (`delivered` vs `succeeded`) — Phase 34.
- Real webhook → workflow progression → trace E2E proof on the production path — Phase 34.
- Broader framework helper surfaces (dedicated Plug, Phoenix package split, etc.) unless future adoption evidence shows the pure-function + fixture-app seam is insufficient.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| FEED-01 | System provides a webhook ingestion layer to receive asynchronous provider callbacks (receipts, bounces). | The pure function `Chimeway.Webhooks.process/4` already exists; Phase 33 adds the durable ingress row, atomic Oban handoff, and host-mounted proof. The fixture Phoenix app under `examples/` satisfies the "runtime ingress seam or reference consumer" success criterion (#3). |
| FEED-02 | Provider-specific callback payloads are normalized into canonical Chimeway delivery outcomes (delivered, bounced, failed). | `Chimeway.Adapter.normalize_feedback/1` already returns `%{status: :delivered \| :bounced \| :failed}`. The ingress row persists this normalized status verbatim per D-04, satisfying FEED-02 by giving normalized outcomes a durable resting place independent of the worker's perform attempt. |

## Phase Constraints (from CLAUDE.md / AGENTS.md)

- Elixir 1.17+ / OTP 26+
- Ecto 3.x + PostgreSQL 15+ (verified: `ecto 3.13.5`, `postgrex 0.22.0`)
- Phoenix is **NOT** a core dep (verified: not in `mix.exs`); the example app must be a sibling Mix project, not added to `chimeway`'s deps.
- Oban is **optional** — `optional: true` in `mix.exs`. New worker code paths must continue to be guarded by `if Code.ensure_loaded?(Oban) do … end` (precedent: `lib/chimeway/dispatch/workflow_progression_worker.ex:1`, `lib/chimeway/dispatch/deferred_resume_worker.ex:1`).
- Persist stable identity, never module names as durable identity. (Adapter module is persisted as a string per Phase 29 D-20 — apply the same discipline to the new ingress row.)
- Telemetry must not leak sensitive payload fields. (Direct constraint on D-04: `provider_response` and headers MUST NOT default to persistence.)
- `mix verify.*` and `mix ci.*` entrypoints must remain green after the phase.

## Standard Stack

### Core (already in `mix.exs` — no new deps)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| ecto_sql | 3.13.5 | Migration + `Ecto.Multi` transaction | Already the project's persistence seam; `Multi.insert/3` is the codebase's atomic-write idiom. |
| postgrex | 0.22.0 | PG driver | Phase 33's partial unique index needs PG-specific syntax (`WHERE provider_event_id IS NOT NULL`). |
| jason | 1.4.4 | JSON parsing in `Webhooks.process/4` | Already used at `lib/chimeway/webhooks.ex:9`. |
| oban | 2.21.1 (optional) | Atomic job insert via `Oban.insert(:job, fn changes -> … end)` | Already the project's `Multi`+job pattern (Signal.track/4). |

### Example app (sibling Mix project under `examples/chimeway_demo_host/`)

| Library | Version | Purpose |
|---------|---------|---------|
| phoenix | ~> 1.7 (suggest 1.7.x — same range project supports per AGENTS.md) | Endpoint + controller mount |
| plug | ~> 1.16 | `Plug.Parsers` with `:body_reader` MFA |
| jason | ~> 1.4 | JSON decoder for `Plug.Parsers` |
| chimeway | `path: "../.."` | Local path dep so the example always tests against current code |

**Verified versions** [VERIFIED: mix.lock 2026-05-01]: `ecto 3.13.5`, `postgrex 0.22.0`, `jason 1.4.4`, `oban 2.21.1`, no `phoenix` / `plug` present.

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Sibling `examples/chimeway_demo_host` Mix project | `test/support` Phoenix app | A `test/support` app couples Chimeway core to Phoenix as a test dep, which would push it onto downstream consumers via `mix.lock` and break the "Phoenix optional" posture. **Rejected** — D-10 forbids coupling. |
| Fixture app | Live integration tests against a running Phoenix endpoint via `Plug.Test` only | A `Plug.Test`-only test exercises the body reader and controller mapping but cannot prove the full mount-time wiring (`Plug.Parsers` ordering, Endpoint plug pipeline, `:body_reader` MFA registration). The fixture app is the only setup that proves wiring AND can be exercised by a `Phoenix.ConnTest`-style E2E test. |
| Dedicated `chimeway_phoenix` package | Single `examples/` fixture app | Splitting into a package is the deferred path (CONTEXT.md Deferred Ideas). The fixture app is the lower-cost first proof; the package can be extracted later if real adopters need it. |

## Architecture Patterns

### System Architecture Diagram

```text
[Provider]
   │  HTTPS POST /webhooks/chimeway/<adapter> (raw body bytes)
   ▼
[Host Phoenix Endpoint]
   │  Plug.Parsers w/ :body_reader -> {CacheBodyReader, :read_body, []}
   │  caches raw bytes into conn.assigns[:raw_body] BEFORE JSON decode
   ▼
[Host Controller (examples/chimeway_demo_host/.../webhook_controller.ex)]
   │  raw_body = conn.assigns[:raw_body] |> IO.iodata_to_binary()
   │  Chimeway.Webhooks.process(adapter_module, raw_body, headers, config)
   ▼
[Chimeway.Webhooks.process/4]   <-- LIBRARY BOUNDARY (D-10)
   │
   ├── adapter.verify_webhook(raw_body, headers, config)  (D-13: raw bytes BEFORE Jason.decode)
   │      └── :ok                                       └── {:error, :unauthorized}  (D-09: NO ingress row)
   ├── Jason.decode(raw_body)
   │      └── {:ok, parsed}                              └── {:error, _}             (D-09: NO ingress row)
   ├── adapter.resolve_delivery(parsed)
   ├── adapter.normalize_feedback(parsed)
   │
   ▼   ╔════════════════════════════════════════════════════════════════════╗
       ║ Ecto.Multi (single transaction, mirroring Signal.track/4)          ║
       ║   :ingress  -> Multi.insert(WebhookIngress.changeset(%{           ║
       ║                  adapter_module, status, delivery_id |             ║
       ║                  provider_message_id, provider_event_id?,         ║
       ║                  ingress_state: :queued                            ║
       ║                }))                                                 ║
       ║   :job      -> Oban.insert(:job, fn %{ingress: ingress} ->        ║
       ║                  ProcessFeedbackWorker.new(%{                      ║
       ║                    "ingress_id" => ingress.id                      ║
       ║                  })                                                ║
       ║                end)                                                ║
       ║ |> Repo.transaction()                                              ║
       ╚════════════════════════════════════════════════════════════════════╝
       │
       ├── {:ok, %{ingress: ingress, job: job}} -> {:ok, ingress}         (D-03: 2xx)
       └── {:error, _step, reason, _changes}    -> {:error, reason}        (D-03: non-2xx, host retry)

  ── async ─────────────────────────────────────────────────────────────────────

[Oban] picks up the persisted job
   ▼
[ProcessFeedbackWorker.perform(%{"ingress_id" => id})]
   │
   ├── Repo.get(WebhookIngress, id)  -- never get!/1 at queue boundary
   │      └── nil  -> :ok (job racy with hard delete; nothing to retry)
   │
   ├── lookup delivery via ingress.delivery_id || ingress.provider_message_id
   │      ├── {:ok, delivery}                  -> normal record_attempt + Signal.track flow
   │      └── nil / {:error, :not_found}       -> update ingress(state: :ignored,
   │                                              ignored_reason: :delivery_not_found |
   │                                              :provider_message_id_not_found)
   │                                              -> :ok (D-07, no Oban retry)
   │
   └── Deliveries.record_attempt -> Signal.track -> :ok | {:error, reason}
```

### Recommended Project Structure

```
chimeway/
├── lib/chimeway/
│   ├── webhooks.ex                              (* rewrite — atomic Multi handoff)
│   ├── webhooks/
│   │   ├── ingress.ex                           (+ NEW — Ecto schema)
│   │   └── process_feedback_worker.ex           (* rewrite — ingress-driven, safe-noop)
│   └── …
├── priv/repo/migrations/
│   └── 20260502xxxxxx_create_chimeway_webhook_ingress.exs   (+ NEW)
├── test/chimeway/webhooks/
│   ├── ingress_test.exs                         (+ NEW — schema validations + dedup constraint)
│   └── process_feedback_worker_test.exs         (* extended — replaces "raises Ecto.NoResultsError" with safe-noop assertions)
├── test/chimeway/webhooks_test.exs              (* extended — atomic-handoff + Oban-failure rollback assertions)
└── examples/                                    (+ NEW directory)
    └── chimeway_demo_host/                      (+ NEW sibling Mix project)
        ├── mix.exs                              (deps: phoenix, plug, jason, {chimeway, path: "../.."})
        ├── lib/
        │   ├── demo_host/
        │   │   ├── application.ex
        │   │   ├── endpoint.ex
        │   │   ├── router.ex
        │   │   ├── plugs/cache_body_reader.ex   (the canonical raw-body reader, per Plug docs)
        │   │   ├── chimeway_webhook_controller.ex
        │   │   └── adapters/echo_adapter.ex     (test-only adapter implementing the Chimeway.Adapter behaviour)
        │   └── demo_host.ex
        └── test/
            └── demo_host/chimeway_webhook_controller_test.exs   (Phoenix.ConnTest E2E proof)
```

### Pattern 1: Atomic Multi+Oban Handoff (Signal.track/4 verbatim)

**What:** Insert a domain-fact row and atomically enqueue an Oban job in one transaction.
**When to use:** Any host-facing API surface that records a durable fact and wants to offload async processing of that fact.
**Source:** `lib/chimeway/signal.ex:30-40` — Phase 33 mirrors this exactly.

```elixir
# CANONICAL TEMPLATE — copy this shape into Chimeway.Webhooks.process/4
# Source: lib/chimeway/signal.ex:30-40 [VERIFIED: read 2026-05-01]
def track(tenant_id, actor_id, event_name, payload \\ %{}) do
  attrs = %{
    tenant_id: tenant_id,
    actor_id: actor_id,
    event_name: event_name,
    payload: payload
  }

  Multi.new()
  |> Multi.insert(:signal, Signal.changeset(%Signal{}, attrs))
  |> Oban.insert(:job, fn %{signal: signal} ->
    SignalRouterWorker.new(%{"signal_id" => signal.id})
  end)
  |> Repo.transaction()
  |> case do
    {:ok, %{signal: signal}} -> {:ok, signal}
    {:error, _step, reason, _changes} -> {:error, reason}
  end
end
```

**Phase 33 application:** swap `Multi.insert(:signal, ...)` for `Multi.insert(:ingress, ...)` and the Oban job builder for `ProcessFeedbackWorker.new(%{"ingress_id" => ingress.id})`. The case-clause shapes return `{:ok, ingress}` per D-03/discretion-#3.

**Failure modes covered by this shape (and the contract callers can rely on):**

1. Ingress row changeset invalid → `{:error, %Ecto.Changeset{}}` (Multi short-circuits at the `:ingress` step before Oban runs).
2. `Oban.insert/3` returns `{:error, %Ecto.Changeset{}}` (e.g., the `oban_jobs` table is missing or unique_constraint conflict) → `{:error, changeset}`. The `:ingress` insert is rolled back atomically because Multi runs both steps inside `Repo.transaction/1`.
3. Oban not started or queue config missing → raises before `Multi` commits; transaction rolls back. Document this as an environment-config error to be surfaced via boot validation, not a runtime ingress concern.
4. Database connection drop mid-commit → `{:error, %DBConnection.Error{}}` from `Repo.transaction/1`.

[CITED: hexdocs.pm/oban/Oban.html — `Oban.insert/3` returns `{:ok, Oban.Job.t()} | {:error, changeset | term()}`; inside Multi the error surfaces when `Repo.transaction` runs.]

### Pattern 2: Safe-Noop on Missing Row (WorkflowProgressionWorker verbatim)

**What:** Queue worker that converts "row not found" into `:ok` to avoid retry storms, while still updating durable state to record the ignored reason.
**When to use:** Async workers that key on a durable row that may be deleted, expired, or never resolvable.
**Source:** `lib/chimeway/dispatch/workflow_progression_worker.ex:67-74` — Phase 33 mirrors the same `:ok` return convention.

```elixir
# CANONICAL TEMPLATE — copy the result-normalization shape
# Source: lib/chimeway/dispatch/workflow_progression_worker.ex:67-74 [VERIFIED: read 2026-05-01]
@doc false
def normalize_progress_result({:ok, {:advanced, _run, _deliveries}}), do: :ok
def normalize_progress_result({:ok, {:waiting, _run}}), do: :ok
def normalize_progress_result({:ok, {:noop, _run, _reason}}), do: :ok
def normalize_progress_result({:ok, {:completed, _run}}), do: :ok
def normalize_progress_result({:ok, {:stopped, _run}}), do: :ok
def normalize_progress_result({:error, :workflow_run_not_found}), do: :ok
def normalize_progress_result({:error, reason}), do: {:error, reason}
```

**Phase 33 application:** in `ProcessFeedbackWorker.perform/1`:

```elixir
@impl Oban.Worker
def perform(%Oban.Job{args: %{"ingress_id" => ingress_id}}) do
  case Repo.get(WebhookIngress, ingress_id) do
    nil ->
      # Hard-deleted between commit and perform; nothing to retry, nothing to write.
      :ok

    %WebhookIngress{ingress_state: :ignored} = ingress ->
      # Already ignored by a prior duplicate retry that converged on dedup.
      :ok

    %WebhookIngress{} = ingress ->
      ingress
      |> resolve_delivery_for_ingress()
      |> apply_feedback_or_mark_ignored(ingress)
      |> normalize_perform_result()
  end
end

defp resolve_delivery_for_ingress(%{delivery_id: id}) when is_binary(id),
  do: {:lookup_by_delivery_id, Deliveries.fetch_delivery(id)}

defp resolve_delivery_for_ingress(%{provider_message_id: pmid}) when is_binary(pmid),
  do: {:lookup_by_provider_message_id, Deliveries.get_delivery_by_provider_message_id(pmid)}

defp apply_feedback_or_mark_ignored({:lookup_by_delivery_id, {:ok, delivery}}, ingress),
  do: {:ok, run_feedback_pipeline(delivery, ingress)}

defp apply_feedback_or_mark_ignored({:lookup_by_delivery_id, {:error, :not_found}}, ingress),
  do: mark_ingress_ignored(ingress, :delivery_not_found)

defp apply_feedback_or_mark_ignored({:lookup_by_provider_message_id, {:ok, delivery}}, ingress),
  do: {:ok, run_feedback_pipeline(delivery, ingress)}

defp apply_feedback_or_mark_ignored({:lookup_by_provider_message_id, {:error, :not_found}}, ingress),
  do: mark_ingress_ignored(ingress, :provider_message_id_not_found)

# All :ok-shaped outcomes signal queue success — no Oban retry on ignored.
defp normalize_perform_result({:ok, _}), do: :ok
defp normalize_perform_result({:error, reason}), do: {:error, reason}
```

**Critical:** `Deliveries.fetch_delivery/1` does not exist today (only `get_delivery!/1` and `get_delivery_by_provider_message_id/1`). Phase 33 must add a non-raising sibling — `Deliveries.fetch_delivery/1 :: {:ok, Delivery.t()} | {:error, :not_found}` — to satisfy D-06's "stop using raising lookup paths" mandate. See `lib/chimeway/deliveries.ex:427-445` [VERIFIED] for the existing surface that needs the new sibling.

### Pattern 3: Plug.Parsers `:body_reader` for raw HMAC bytes

**What:** Cache the raw request body in `conn.assigns[:raw_body]` BEFORE `Plug.Parsers` consumes it for JSON decoding, so signature verification can run on the exact bytes the provider signed.
**When to use:** Any time HMAC/JWS/asymmetric-signature verification is required and the request body is JSON. (D-13 — first-class DX concern.)
**Source:** [CITED: hexdocs.pm/plug/Plug.Parsers.html] — official `:body_reader` MFA pattern; the same shape used by Stripe Elixir libraries (e.g., `lattice_stripe`).

```elixir
# examples/chimeway_demo_host/lib/demo_host/plugs/cache_body_reader.ex
defmodule DemoHost.Plugs.CacheBodyReader do
  @moduledoc """
  Reads the request body and caches it into `conn.assigns[:raw_body]` so
  webhook signature verification can run on the exact bytes the provider
  signed. Plug.Parsers consumes the body during JSON parsing; without a
  body_reader the raw bytes are unrecoverable.

  This is the canonical pattern from hexdocs.pm/plug/Plug.Parsers.html.
  """

  def read_body(conn, opts) do
    with {:ok, body, conn} <- Plug.Conn.read_body(conn, opts) do
      conn = update_in(conn.assigns[:raw_body], &[body | &1 || []])
      {:ok, body, conn}
    end
  end
end
```

```elixir
# examples/chimeway_demo_host/lib/demo_host/endpoint.ex (excerpt)
plug Plug.Parsers,
  parsers: [:urlencoded, :json],
  pass: ["text/*"],
  body_reader: {DemoHost.Plugs.CacheBodyReader, :read_body, []},
  json_decoder: Jason
```

```elixir
# examples/chimeway_demo_host/lib/demo_host/chimeway_webhook_controller.ex
defmodule DemoHost.ChimewayWebhookController do
  use DemoHostWeb, :controller

  def create(conn, _params) do
    raw_body = conn.assigns |> Map.get(:raw_body, []) |> IO.iodata_to_binary()
    headers = conn.req_headers
    adapter_module = adapter_for(conn.path_params["adapter"])
    config = Application.get_env(:demo_host, :chimeway_adapter_config, [])

    case Chimeway.Webhooks.process(adapter_module, raw_body, headers, config) do
      {:ok, _ingress}            -> send_resp(conn, 200, "OK")
      {:error, :unauthorized}    -> send_resp(conn, 401, "Unauthorized")
      {:error, _other}           -> send_resp(conn, 500, "Internal Server Error")
    end
  end

  # Adapter selection is host-app territory; the example wires one fixture adapter.
  defp adapter_for("echo"), do: DemoHost.Adapters.EchoAdapter
end
```

**The `:raw_body` chunk-list footgun:** `update_in(conn.assigns[:raw_body], &[body | &1 || []])` accumulates body chunks as an iolist. Controllers MUST do `IO.iodata_to_binary(raw_body)` before passing to `verify_webhook/3` — passing an iolist would break HMAC computation on adapters that assume a binary input. This is the exact ecosystem footgun called out by D-13 and must appear in the example controller.

### Anti-Patterns to Avoid

- **Optimistic enqueue helper.** `lib/chimeway/webhooks/process_feedback_worker.ex:64-70` currently does `args |> new() |> Oban.insert(); {:ok, :enqueued}` which **discards the `Oban.insert/1` return** and always reports success. This is the literal bug that triggered the audit gap; the rewrite must propagate the `Oban.insert/1` failure tuple through the Multi.
- **Persisting raw `provider_response` and headers on the ingress row.** D-04 forbids it. The ingress row is for explainability metadata, not blob storage. Adapters already write `provider_response` to `chimeway_delivery_attempts` (D-22 from Phase 29); that surface keeps its responsibility. The ingress row stores only normalized facts.
- **`String.to_atom/1` on `provider_event_id` or any ingress-derived string.** Atom-table exhaustion footgun (Phase 11 discipline). All ingress fields stay as strings.
- **Adding a Chimeway-owned Plug.** D-10 forbids it. The pure function `Chimeway.Webhooks.process/4` is the boundary; the controller is host territory.
- **Raising in the worker on missing rows.** `Deliveries.get_delivery!/1` is the source of the audit gap. Worker code MUST use non-raising lookups (`Repo.get/2`, `fetch_delivery/1`) for the ingress and delivery boundary.
- **Adding `phoenix` or `plug` to `chimeway`'s `mix.exs`.** AGENTS.md and CONTEXT.md D-10 both forbid this. The example app is a sibling Mix project with its own `mix.exs`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Atomic durable-fact + async-job handoff | Custom `try/rescue` around two separate `Repo.insert` + `Oban.insert` calls | `Ecto.Multi` + `Oban.insert/3` (Multi-aware form) | Two-step rollback is impossible without `Multi`; `Oban.insert/3` is documented to participate in Multi via the function-arity-2 form `Oban.insert(multi, name, fun)`. The Multi runs inside `Repo.transaction/1` so the job and the row commit atomically. |
| Raw HTTP body preservation | Custom plug that snapshots `Plug.Conn.read_body/1` before `Plug.Parsers` | `Plug.Parsers`'s built-in `:body_reader` MFA | Plug already has the seam. Re-implementing risks ordering bugs (parser running first, body already consumed). The MFA-form `body_reader` is the documented canonical pattern. |
| HMAC signature verification | Hand-rolled `:crypto.hmac/3` + `==` comparison | Adapter's `verify_webhook/3` callback (already exists) + `Plug.Crypto.secure_compare/2` for timing safety inside the adapter implementation | `==` on HMAC digests is a timing-attack footgun; `Plug.Crypto.secure_compare/2` is the canonical timing-safe primitive on the BEAM. Note: not used in core today; document the requirement on the adapter side. |
| Deduplication of provider retries | Application-level uniqueness check with `Repo.exists?` | PG partial unique index: `unique_index(:chimeway_webhook_ingress, [:adapter_module, :provider_event_id], where: "provider_event_id IS NOT NULL")` | Race-free dedup via DB constraint; matches the D-05 "duplicate-collapse seam" without an `exists?`-then-insert race. `:provider_event_id` is nullable (not all adapters expose it), so the index must be partial. |
| Worker-level "row not found" handling | `Repo.get!`/`get_by!` and rely on Oban max_attempts to give up | Non-raising `Repo.get/2` + explicit `:ok`/`{:error, …}` return | Oban retries on raised exceptions; `:ok` returns are the queue-success signal. The `WorkflowProgressionWorker` precedent already encodes this. |

**Key insight:** All four problems above already have one canonical answer in this codebase or the ecosystem. The Phase 33 work is mostly **mirroring existing patterns** verbatim; there is essentially no novel infrastructure design to do.

## Runtime State Inventory

> Phase 33 is primarily an additive code+schema change but **does** rewrite two queue-boundary call sites (`ProcessFeedbackWorker.perform/1` and `Webhooks.process/4`). Existing Oban jobs queued with the **old args shape** (`%{"delivery_id" => …}` or `%{"provider_message_id" => …}`) may still be in the `oban_jobs` table when Phase 33 deploys.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — the new ingress table is a greenfield additive migration. No renames of existing rows. | None. |
| Live service config | None — Phase 33 does not change `config :chimeway, …` keys or the Oban queue config (already `chimeway_delivery: 10, chimeway_signals: 5` per `config/test.exs:21`). | None. |
| OS-registered state | None. | None. |
| Secrets/env vars | None changed. Adapter config (`config :chimeway, :channel_adapter_configs`) keeps its existing shape. | None. |
| Build artifacts | None — `examples/chimeway_demo_host/` is a separate Mix project; it gets its own `_build/` and `mix.lock`. The root `mix.exs` is unchanged. | None for chimeway; the example app gets a fresh `mix deps.get` once. |
| **In-flight Oban jobs (queue migration)** | The pre-Phase-33 `ProcessFeedbackWorker` job args were `%{"delivery_id" \| "provider_message_id" => id, "status" => …, "provider_response" => …, "adapter_module" => …}`. Post-Phase-33 args become `%{"ingress_id" => id}`. **Mid-deploy jobs with the old shape will fail** if `perform/1` only matches the new shape. | The new `perform/1` MUST keep a backwards-compat clause for the old args shape for at least one release (or document a queue-drain step in the deploy runbook). The compat clause should call into the same shared pipeline as the new path; only the entry-point pattern differs. **This is a release-engineering hazard that the planner MUST surface as a dedicated task.** |

**The canonical question** — *After every file in the repo is updated, what runtime systems still have the old string cached, stored, or registered?* — answers as: **the live `oban_jobs` table** and only that. There is no other runtime-cached old state.

## Common Pitfalls

### Pitfall 1: `process/4` returning `:error` instead of `{:error, reason}` for non-unauthorized failures

**What goes wrong:** Today, `lib/chimeway/webhooks.ex:25` returns the bare atom `:error` for any non-unauthorized failure (delivery cannot be resolved, feedback cannot be normalized). The host controller can't distinguish parse failure from queue failure.

**Why it happens:** The `else` clause in the original `with` collapses everything except `{:error, :unauthorized}` to `_ -> :error`.

**How to avoid:** Phase 33's rewrite must return tagged tuples for every failure mode: `{:error, :unauthorized}`, `{:error, :unparseable_body}` (Jason failure), `{:error, :unresolvable_delivery}` (adapter `resolve_delivery/1` returns `:error`), `{:error, :unnormalizable_feedback}` (adapter `normalize_feedback/1` returns `:error`), `{:error, %Ecto.Changeset{}}` (ingress invalid), `{:error, term()}` (Oban failure). The host can map all `{:error, _}` to non-2xx for retry; this preserves the existing host-mapping contract while making the test assertions and the operator trace far cleaner.

**Warning signs:** Existing `test/chimeway/webhooks_test.exs:32, 37` asserts `assert :error = …`. Updating these to tagged tuples is the canary that the contract was tightened correctly.

### Pitfall 2: Worker `perform/1` racing with hard ingress-row deletion

**What goes wrong:** The transaction commits the ingress row + Oban job, the job is picked up, but the ingress row was deleted (test-suite cleanup, operator action, etc.) before `perform/1` runs.

**Why it happens:** The Oban job and the ingress row commit atomically, but POST-commit the row can be deleted independently. Using `Repo.get!(WebhookIngress, id)` would raise → Oban retries → eventually exhausts.

**How to avoid:** Use `Repo.get/2` (non-raising) in `perform/1`. `nil` → return `:ok` immediately. The `WorkflowProgressionWorker` precedent (`{:error, :workflow_run_not_found}` → `:ok`) is the model. This is independent of D-06/D-07's stale-delivery handling — the ingress-row miss is a different layer.

**Warning signs:** Test that hard-deletes the ingress row between Multi commit and `perform/1` invocation must return `:ok`, not raise.

### Pitfall 3: Persisting raw `parsed` JSON or full headers on the ingress row

**What goes wrong:** D-04 explicitly forbids it. Persisting full bodies leaks PII (recipient emails, phone numbers, billing details) into a low-privilege durable row. Persisting headers leaks signature secrets, bearer tokens, and source IPs into operator-visible state.

**Why it happens:** Defaults toward "save everything" out of audit-completeness anxiety. The audit completeness anxiety is misplaced — `chimeway_delivery_attempts.provider_response` already persists the redacted provider response on attempts (Phase 29 D-22), where it belongs.

**How to avoid:** The ingress changeset's `@allowed_fields` enumerates ONLY the fields D-04 names: `adapter_module`, `delivery_id`, `provider_message_id`, `provider_event_id`, `normalized_status`, `ingress_state`, `ignored_reason`, plus auto timestamps. NEVER add a `provider_response :map` or `headers :map` field. If a future phase needs the raw body for a specific compliance use case, add it deliberately with a feature flag.

**Warning signs:** Schema diff in code review showing `field(:provider_response, :map)` or `field(:headers, :map)` on the ingress schema.

### Pitfall 4: `:body_reader` returns iolist; controller forgets to flatten

**What goes wrong:** `update_in(conn.assigns[:raw_body], &[body | &1 || []])` accumulates body chunks into an iolist. Adapters that compute HMAC over the body via `:crypto.mac(:hmac, :sha256, secret, body)` will reject the iolist unless you binary-coerce first. The signature mismatch is silent — it just always returns `{:error, :unauthorized}` for valid requests.

**Why it happens:** Plug's `:body_reader` is chunked because HTTP bodies arrive in chunks; the documented pattern is intentionally an iolist for memory efficiency.

**How to avoid:** The host controller MUST do `raw_body = conn.assigns[:raw_body] |> IO.iodata_to_binary()` before passing to `Chimeway.Webhooks.process/4`. The example app's controller does this (see Pattern 3 above) and the example app's docstring calls this out explicitly. **The fixture app's E2E test must include a "valid signature with chunked body" assertion** to catch any regression in the docstring guidance.

**Warning signs:** Adapter `verify_webhook/3` returns `{:error, :unauthorized}` in production for known-good signatures; works fine in tests where bodies arrive in single chunks.

### Pitfall 5: Provider event id collisions across adapters

**What goes wrong:** Two adapters might independently emit a provider event id like `"evt_001"`. A naive `unique_index(:chimeway_webhook_ingress, :provider_event_id)` treats them as duplicates.

**Why it happens:** Each provider has its own ID space; collisions across providers are common with short opaque tokens.

**How to avoid:** The dedup index MUST be composite on `(adapter_module, provider_event_id)` and partial (`WHERE provider_event_id IS NOT NULL`). Per D-05: "provider event id (when stable) **+ adapter identity** is the duplicate-collapse seam." The composite is non-negotiable.

**Warning signs:** Migration shows `unique_index(:chimeway_webhook_ingress, [:provider_event_id])` instead of `unique_index(..., [:adapter_module, :provider_event_id], where: "provider_event_id IS NOT NULL")`.

## Code Examples

### Ingress schema (concrete recommendation per D-04, D-05, D-07)

```elixir
# lib/chimeway/webhooks/ingress.ex
defmodule Chimeway.Webhooks.Ingress do
  @moduledoc """
  Durable inbound webhook fact: a verified provider callback has been received,
  normalized, and queued for async processing. One ingress row per accepted
  callback; duplicate provider retries with the same `(adapter_module,
  provider_event_id)` collapse to the existing row via the partial unique index.

  Ingress rows are NOT a payload archive. They store explainability-first
  fields only — adapter identity, correlation keys, normalized status,
  processing state, and (when applicable) an ignored reason. Raw provider
  bodies and headers stay out of this surface by design (Phase 33 D-04).
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  # Normalized outcome from adapter.normalize_feedback/1.
  @normalized_statuses ~w(delivered bounced failed)
  # Lifecycle of the ingress row itself.
  @ingress_states ~w(queued processed ignored failed)a
  # Reason vocabulary for ingress_state == :ignored. Strict enum; never derived
  # from untrusted input. Mirrors Phase 32 D-16 atom-safety discipline.
  @ignored_reasons ~w(delivery_not_found provider_message_id_not_found)a

  schema "chimeway_webhook_ingress" do
    field(:adapter_module, :string)            # "MyApp.TwilioChimewayAdapter" — string, never atom on wire
    field(:delivery_id, :binary_id)            # FK target, BUT not declared as belongs_to to avoid cascade weirdness
    field(:provider_message_id, :string)
    field(:provider_event_id, :string)         # nullable; partial unique index when present
    field(:normalized_status, :string)         # one of @normalized_statuses
    field(:ingress_state, Ecto.Enum, values: @ingress_states, default: :queued)
    field(:ignored_reason, Ecto.Enum, values: @ignored_reasons)
    field(:processed_at, :utc_datetime_usec)   # set when ingress_state transitions out of :queued

    timestamps(type: :utc_datetime_usec)
  end

  @required_fields ~w(adapter_module normalized_status ingress_state)a
  @optional_fields ~w(delivery_id provider_message_id provider_event_id ignored_reason processed_at)a

  def changeset(ingress, attrs) do
    ingress
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:adapter_module, min: 1)
    |> validate_inclusion(:normalized_status, @normalized_statuses)
    |> validate_correlation_present()
    |> unique_constraint(
      [:adapter_module, :provider_event_id],
      name: :chimeway_webhook_ingress_adapter_provider_event_uniq
    )
  end

  # At least one correlation key must be present, OR the row is :ignored with
  # an explicit reason. Prevents orphaned ingress rows that can never be acted on.
  defp validate_correlation_present(changeset) do
    delivery_id = get_field(changeset, :delivery_id)
    pmid = get_field(changeset, :provider_message_id)
    state = get_field(changeset, :ingress_state)
    reason = get_field(changeset, :ignored_reason)

    cond do
      delivery_id || pmid -> changeset
      state == :ignored and reason -> changeset
      true ->
        add_error(changeset, :delivery_id,
          "must be present, or provider_message_id must be present, or ingress must be :ignored with a reason")
    end
  end
end
```

### Migration

```elixir
# priv/repo/migrations/20260502120000_create_chimeway_webhook_ingress.exs
defmodule Chimeway.Repo.Migrations.CreateChimewayWebhookIngress do
  use Ecto.Migration

  def change do
    create table(:chimeway_webhook_ingress, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :adapter_module, :string, null: false
      add :delivery_id, references(:chimeway_deliveries, type: :binary_id, on_delete: :nilify_all)
      add :provider_message_id, :string
      add :provider_event_id, :string
      add :normalized_status, :string, null: false
      add :ingress_state, :string, null: false, default: "queued"
      add :ignored_reason, :string
      add :processed_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    # Operator query: "what's stuck in :queued?"
    create index(:chimeway_webhook_ingress, [:ingress_state])

    # Correlation lookup paths from worker.
    create index(:chimeway_webhook_ingress, [:delivery_id])
    create index(:chimeway_webhook_ingress, [:provider_message_id])

    # Dedup seam (D-05): provider_event_id is nullable, so the index is partial.
    # Composite on adapter_module to prevent cross-provider id collisions.
    create unique_index(
      :chimeway_webhook_ingress,
      [:adapter_module, :provider_event_id],
      name: :chimeway_webhook_ingress_adapter_provider_event_uniq,
      where: "provider_event_id IS NOT NULL"
    )
  end
end
```

### `Chimeway.Webhooks.process/4` rewrite (atomic Multi handoff)

```elixir
defmodule Chimeway.Webhooks do
  @moduledoc """
  Pure function boundary for synchronously ingesting and verifying inbound webhooks.

  Success returns ONLY when the ingress row and the ProcessFeedbackWorker job
  have both committed in a single transaction. Returning `{:ok, ingress}` is
  the host's acknowledgment cue — the host MAY return 2xx to the provider
  (Phase 33 D-03). Any error tuple means the host MUST return non-2xx so the
  provider retries.

  Unauthorized signature failures and unparseable bodies do NOT create a
  durable ingress row (Phase 33 D-09). Only verified, parsed, normalized
  callbacks enter the durable inbound lifecycle.
  """

  alias Chimeway.Repo
  alias Chimeway.Webhooks.{Ingress, ProcessFeedbackWorker}
  alias Ecto.Multi

  @spec process(module(), binary(), list(), keyword()) ::
          {:ok, Ingress.t()}
          | {:error, :unauthorized}
          | {:error, :unparseable_body}
          | {:error, :unresolvable_delivery}
          | {:error, :unnormalizable_feedback}
          | {:error, Ecto.Changeset.t()}
          | {:error, term()}
  def process(adapter_module, raw_body, headers, config) do
    with :ok <- adapter_module.verify_webhook(raw_body, headers, config),
         {:ok, parsed} <- decode_body(raw_body),
         {:ok, delivery_info} <- resolve_delivery(adapter_module, parsed),
         {:ok, feedback_info} <- normalize_feedback(adapter_module, parsed),
         {:ok, provider_event_id} <- extract_provider_event_id(adapter_module, parsed) do

      attrs = %{
        adapter_module: to_string(adapter_module),
        delivery_id: delivery_info[:delivery_id],
        provider_message_id: delivery_info[:provider_message_id],
        provider_event_id: provider_event_id,
        normalized_status: to_string(feedback_info.status),
        ingress_state: :queued
      }

      Multi.new()
      |> Multi.insert(:ingress, Ingress.changeset(%Ingress{}, attrs),
           on_conflict: :nothing,
           conflict_target: {:unsafe_fragment, ~s|("adapter_module", "provider_event_id") WHERE "provider_event_id" IS NOT NULL|},
           returning: true
         )
      |> Oban.insert(:job, fn %{ingress: ingress} ->
        ProcessFeedbackWorker.new(%{"ingress_id" => ingress.id})
      end)
      |> Repo.transaction()
      |> case do
        {:ok, %{ingress: ingress}} -> {:ok, ingress}
        {:error, _step, reason, _changes} -> {:error, reason}
      end
    end
  end

  defp decode_body(raw_body) do
    case Jason.decode(raw_body) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, _} -> {:error, :unparseable_body}
    end
  end

  defp resolve_delivery(adapter_module, parsed) do
    case adapter_module.resolve_delivery(parsed) do
      {:ok, info} -> {:ok, info}
      _ -> {:error, :unresolvable_delivery}
    end
  end

  defp normalize_feedback(adapter_module, parsed) do
    case adapter_module.normalize_feedback(parsed) do
      {:ok, info} -> {:ok, info}
      _ -> {:error, :unnormalizable_feedback}
    end
  end

  # Optional adapter callback — adapters that don't expose stable provider
  # event ids return :none and the row stores nil (no dedup for that adapter).
  defp extract_provider_event_id(adapter_module, parsed) do
    if function_exported?(adapter_module, :resolve_provider_event_id, 1) do
      case adapter_module.resolve_provider_event_id(parsed) do
        {:ok, id} when is_binary(id) -> {:ok, id}
        :none -> {:ok, nil}
        _ -> {:ok, nil}
      end
    else
      {:ok, nil}
    end
  end
end
```

**Key design choices in this rewrite:**

1. **Add ONE optional `Chimeway.Adapter` callback: `resolve_provider_event_id/1`.** Provider event id is the dedup seam (D-05) but not all providers expose one. Adding the optional callback keeps the existing 3-callback contract intact for adapters that don't need dedup. Wrap with `function_exported?/3` so existing adapters compile without changes.

2. **`on_conflict: :nothing` with the partial unique target.** When a duplicate provider retry hits the same `(adapter_module, provider_event_id)`, the insert is silently skipped at the DB level. The Multi continues, the Oban job is enqueued, and the existing ingress is returned. The worker's `:ingress_state == :ignored` early-return covers the rare case where a duplicate retry races a successful first-pass perform.

3. **Removed `provider_response` and `adapter_module` from the Oban job args.** Today's worker carries the parsed payload through Oban; the rewrite carries only `ingress_id`. The worker re-reads the ingress row to get adapter identity and correlation keys, and re-fetches the delivery row for status updates. This is the durable-spine-over-queue-archaeology principle (CONTEXT.md `<specifics>`).

4. **`raw_body`-based dedup is NOT used.** D-05 is explicit: provider event id + adapter identity is the dedup seam. Body-hashing would catch re-deliveries with mutated transit metadata (e.g., reformatted JSON) but is more expensive and less semantically meaningful. The provider event id (when stable) is the right answer.

### `ProcessFeedbackWorker.perform/1` rewrite (ingress-driven, safe-noop)

```elixir
defmodule Chimeway.Webhooks.ProcessFeedbackWorker do
  use Oban.Worker, queue: :chimeway_delivery

  alias Chimeway.{Deliveries, Repo}
  alias Chimeway.Webhooks.Ingress

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"ingress_id" => ingress_id}}) do
    case Repo.get(Ingress, ingress_id) do
      nil ->
        # Ingress row hard-deleted between Multi commit and perform; nothing to retry.
        :ok

      %Ingress{ingress_state: :ignored} ->
        # Already handled by a prior duplicate that converged through the partial unique index.
        :ok

      %Ingress{ingress_state: :processed} ->
        # Already handled by a prior successful run. Idempotent re-run on retries.
        :ok

      %Ingress{} = ingress ->
        ingress
        |> apply_feedback()
        |> normalize_perform_result()
    end
  end

  # === Backwards-compat clause for in-flight pre-Phase-33 jobs ===
  # Drain runbook: keep for one release cycle, then remove.
  def perform(%Oban.Job{args: %{"delivery_id" => _} = legacy_args}),
    do: perform_legacy_args(legacy_args)

  def perform(%Oban.Job{args: %{"provider_message_id" => _} = legacy_args}),
    do: perform_legacy_args(legacy_args)

  # … legacy path delegates to a private function that runs the same feedback
  # pipeline used by the new path, but does NOT create an ingress row.

  # === Main pipeline ===
  defp apply_feedback(%Ingress{delivery_id: id} = ingress) when is_binary(id) do
    case Deliveries.fetch_delivery(id) do
      {:ok, delivery} -> run_feedback_pipeline(delivery, ingress)
      {:error, :not_found} -> mark_ignored(ingress, :delivery_not_found)
    end
  end

  defp apply_feedback(%Ingress{provider_message_id: pmid} = ingress) when is_binary(pmid) do
    case Deliveries.get_delivery_by_provider_message_id(pmid) do
      {:ok, delivery} -> run_feedback_pipeline(delivery, ingress)
      {:error, :not_found} -> mark_ignored(ingress, :provider_message_id_not_found)
    end
  end

  defp run_feedback_pipeline(delivery, %Ingress{} = ingress) do
    outcome = String.to_existing_atom(canonicalize_status(ingress.normalized_status))

    attempt_params = build_attempt_params(outcome, ingress)

    with {:ok, _attempt} <- Deliveries.record_attempt(delivery, attempt_params),
         {:ok, _signal} <- emit_signal(delivery, outcome),
         {:ok, _ingress} <- mark_processed(ingress) do
      :ok
    end
  end

  defp mark_ignored(%Ingress{} = ingress, reason) when reason in [:delivery_not_found, :provider_message_id_not_found] do
    ingress
    |> Ingress.changeset(%{
      ingress_state: :ignored,
      ignored_reason: reason,
      processed_at: DateTime.utc_now()
    })
    |> Repo.update()
    |> case do
      {:ok, _} -> {:ignored, reason}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp mark_processed(%Ingress{} = ingress) do
    ingress
    |> Ingress.changeset(%{
      ingress_state: :processed,
      processed_at: DateTime.utc_now()
    })
    |> Repo.update()
  end

  # Mirror WorkflowProgressionWorker.normalize_progress_result/1: every
  # understood-but-ignored outcome is :ok at the queue boundary; only
  # genuine "should retry" failures return {:error, _}.
  defp normalize_perform_result(:ok), do: :ok
  defp normalize_perform_result({:ignored, _reason}), do: :ok
  defp normalize_perform_result({:error, %Ecto.Changeset{} = cs}), do: {:error, cs}
  defp normalize_perform_result({:error, reason}), do: {:error, reason}

  # Status canonicalization stays minimal — Phase 34 owns vocabulary unification.
  defp canonicalize_status("delivered"), do: "succeeded"
  defp canonicalize_status(other), do: other

  defp build_attempt_params(outcome, %Ingress{} = ingress) do
    base = %{
      outcome: outcome,
      adapter_module: ingress.adapter_module
    }

    base = if outcome in [:bounced, :failed], do: Map.put(base, :error_class, to_string(outcome)), else: base
    if ingress.provider_message_id, do: Map.put(base, :provider_message_id, ingress.provider_message_id), else: base
  end

  defp emit_signal(delivery, outcome) do
    event_name = "chimeway.delivery.#{outcome}"
    payload = %{"delivery_id" => delivery.id, "status" => to_string(outcome)}
    payload = if outcome in [:bounced, :failed], do: Map.put(payload, "error", to_string(outcome)), else: payload

    Chimeway.Signal.track(delivery.tenant_id, delivery.actor_id, event_name, payload)
  end
end
```

**Required new function in `Chimeway.Deliveries`:**

```elixir
@doc """
Fetches a delivery by ID without raising. Pairs with `get_delivery!/1` for
queue-boundary callers that prefer explicit `{:error, :not_found}`.
"""
@spec fetch_delivery(binary()) :: {:ok, Delivery.t()} | {:error, :not_found}
def fetch_delivery(id) when is_binary(id) do
  case Repo.get(Delivery, id) do
    %Delivery{} = delivery -> {:ok, delivery}
    nil -> {:error, :not_found}
  end
end
```

### Fixture host app (sketch — full plan owned by the planner)

```elixir
# examples/chimeway_demo_host/mix.exs
defmodule DemoHost.MixProject do
  use Mix.Project

  def project do
    [
      app: :demo_host,
      version: "0.0.0",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers(),
      start_permanent: false,
      deps: deps()
    ]
  end

  def application do
    [mod: {DemoHost.Application, []}, extra_applications: [:logger]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix, "~> 1.7"},
      {:plug, "~> 1.16"},
      {:jason, "~> 1.4"},
      {:chimeway, path: "../.."}
    ]
  end
end
```

The example app's `test/demo_host/chimeway_webhook_controller_test.exs` exercises the full ingress path with a fixture echo adapter, asserts `200 OK` on success, `401 Unauthorized` on bad signature, and asserts the durable ingress row was committed by querying `Chimeway.Repo`. **Test the chunked-body case explicitly** to catch the iolist-flattening regression.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `Webhooks.process/4` returns `{:ok, :enqueued}` from `ProcessFeedbackWorker.enqueue/1` which discards `Oban.insert/1` result | `Webhooks.process/4` returns `{:ok, ingress}` only after Multi commits both ingress row + Oban job | Phase 33 (this phase) | Closes audit-gap #1 (queue durability). Host can finally trust 2xx as "durably handed off." |
| `ProcessFeedbackWorker` uses `Deliveries.get_delivery!/1` (raises) | Worker uses `Repo.get(Ingress, ...)` and `Deliveries.fetch_delivery/1` (non-raising); marks ingress `:ignored` with explicit reason | Phase 33 | Closes audit-gap #4. No more `Ecto.NoResultsError` retry storms. |
| No durable inbound-callback fact; only `DeliveryAttempt` rows after correlation succeeds | New `chimeway_webhook_ingress` table owns the inbound-callback fact independent of correlation success | Phase 33 D-01, D-08 | Operators can answer "which webhooks did we receive but couldn't correlate?" — previously invisible. |
| No runtime ingress consumer in the repo | `examples/chimeway_demo_host/` Phoenix fixture app proves the mount | Phase 33 D-11 | Closes audit-gap #2 (host ingress proof). Becomes canonical doc reference per D-12. |

**Deprecated/outdated:**
- `Chimeway.Webhooks.ProcessFeedbackWorker.enqueue/1` (the optimistic helper at `webhooks/process_feedback_worker.ex:64-70`) — removed; callers go through `Chimeway.Webhooks.process/4` exclusively.
- `Chimeway.Webhooks.ProcessFeedbackWorker` jobs with `%{"delivery_id" \| "provider_message_id"}` args — backwards-compat shim retained for one release; planner adds removal task to Phase 34 or a v1.5 cleanup phase.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The recommended ingress table name `chimeway_webhook_ingress` is acceptable. CONTEXT.md leaves naming as Claude's discretion. | Code Examples / Migration | Low — pure naming. Planner can substitute `chimeway_feedback_ingress` etc. without changing any other decision. |
| A2 | The recommended ingress state vocabulary (`:queued / :processed / :ignored / :failed`) is acceptable per discretion. | Code Examples / Schema | Low — pure naming. The semantics are what matter, and they map 1:1 to D-06/D-07/D-08. |
| A3 | The recommended `process/4` success return shape `{:ok, %Ingress{}}` (vs `{:ok, %Job{}}` or a struct) is acceptable per discretion item #3. | `Webhooks.process/4` rewrite | Low — pure return-shape choice. The ingress row is the more durable explainability anchor than the job; recommended for trace/audit consumers. |
| A4 | The recommended optional adapter callback `resolve_provider_event_id/1` is the right way to satisfy D-05 without breaking existing adapters. | `Webhooks.process/4` rewrite | Medium — adds a new (optional) callback to `Chimeway.Adapter`. Alternative: derive a stable id from `parsed` payload via a host-configured key path. The optional callback is more explicit and avoids config sprawl, but if planner prefers config-driven extraction, that's a viable substitute. |
| A5 | Phoenix 1.7+ and Plug 1.16+ are appropriate version pins for the example app. | Standard Stack | Low — example app is local-path; pinning is not a publishing concern. Planner may use looser pins. |
| A6 | The backwards-compat shim for in-flight pre-Phase-33 Oban jobs is required and not optional. | Runtime State Inventory | **High if wrong**. If the shim is dropped and pre-Phase-33 jobs are still in `oban_jobs` at deploy time, those jobs will fail-loudly and exhaust max_attempts. The planner SHOULD confirm with the user whether (a) the deploy runbook will drain the queue first (skip the shim), or (b) the shim is required (current recommendation). Default recommendation: include the shim — fail-safe over fail-loud for a production library. |
| A7 | `Repo.get(Ingress, id)` returning `nil` is acceptable as a true `:ok` (not `{:error, :ingress_not_found}`) at the queue boundary. | `ProcessFeedbackWorker.perform/1` rewrite | Low — matches the `WorkflowProgressionWorker` precedent verbatim and CONTEXT.md `<code_context>` calls out that precedent as the established pattern. |

**If this table is empty:** All claims in this research were verified or cited — no user confirmation needed.

(Table not empty — A4 and A6 are the items the planner SHOULD surface to the user during plan-checking.)

## Open Questions

1. **Should the `chimeway_webhook_ingress` table backfill anything from existing `DeliveryAttempt` rows that resulted from prior webhooks?**
   - What we know: D-08 says ignored/stale audit is the new ingress surface, but pre-Phase-33 attempts already encode resolved webhook outcomes. There is no audit-gap claim against historical attempts.
   - What's unclear: Whether operators expect to see pre-Phase-33 webhooks reflected in the ingress table for uniformity.
   - Recommendation: **Do not backfill.** The ingress table is the new fact surface from Phase 33 forward; backfilling synthetic ingress rows from `DeliveryAttempt` would muddy the dedup contract (no real `provider_event_id` to populate). Document this in the migration's `@moduledoc`. If a future operator-UI phase needs uniform history, that phase can synthesize the projection at read time without polluting the durable surface.

2. **Where does the example app's CI run live?**
   - What we know: AGENTS.md and `chimeway-host-app-integration-seam.md:34` call out `mix verify.example` (or equivalent) as a documented hook.
   - What's unclear: Whether the existing `mix ci.test` should chain to the example app's tests, or whether a separate `mix verify.example` is needed.
   - Recommendation: Add a top-level `mix verify.example` alias that runs `cd examples/chimeway_demo_host && mix deps.get && mix test`. Keep it OUT of the default `mix ci.test` (which is fast and runs against the core lib). The planner should make this an explicit task in the example-app plan with a CI-config note.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | core + example app | ✓ | 1.17+ | — |
| PostgreSQL | core (migration + Ecto.Multi tests) | assumed ✓ | 15+ | — |
| Oban | core (Multi+job test) | ✓ | 2.21.1 | gated by `Code.ensure_loaded?(Oban)`; tests already use `use Oban.Testing` |
| Phoenix | example app only | ✗ at root | — | example app installs locally; no impact on chimeway core |
| Plug | example app only | ✗ at root | — | same as Phoenix |

**Missing dependencies with no fallback:** None — all example-app deps are local to the sibling Mix project.

**Missing dependencies with fallback:** Phoenix and Plug are intentionally excluded from `chimeway`'s core deps per D-10. The example app declares them locally.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit |
| Config file | `mix.exs` (`elixirc_paths: ["lib", "test/support"]` for `:test`) |
| Quick run command | `mix test test/chimeway/webhooks/ test/chimeway/webhooks_test.exs` |
| Full suite command | `mix ci` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| FEED-01 | `Webhooks.process/4` returns `{:ok, ingress}` only after BOTH ingress row AND Oban job commit | unit / integration | `mix test test/chimeway/webhooks_test.exs` | ✅ extend |
| FEED-01 | `Webhooks.process/4` returns `{:error, _}` and writes NO ingress row when `Oban.insert` fails (mocked failure) | integration | `mix test test/chimeway/webhooks_test.exs` | ✅ extend |
| FEED-01 | `Webhooks.process/4` returns `{:error, :unauthorized}` and writes NO ingress row | unit | `mix test test/chimeway/webhooks_test.exs` | ✅ extend (rewrite expectation) |
| FEED-01 | Duplicate provider retries with same `(adapter_module, provider_event_id)` collapse to one ingress row | integration | `mix test test/chimeway/webhooks_test.exs` | ❌ Wave 0 |
| FEED-01 | Worker writes `ingress_state=:ignored, ignored_reason=:delivery_not_found` on stale `delivery_id` and returns `:ok` (no retry) | integration | `mix test test/chimeway/webhooks/process_feedback_worker_test.exs` | ✅ extend (replace `assert_raise Ecto.NoResultsError`) |
| FEED-01 | Worker writes `ingress_state=:ignored, ignored_reason=:provider_message_id_not_found` on stale `provider_message_id` and returns `:ok` | integration | `mix test test/chimeway/webhooks/process_feedback_worker_test.exs` | ✅ extend |
| FEED-01 | Worker returns `:ok` when the ingress row was hard-deleted between commit and perform | integration | `mix test test/chimeway/webhooks/process_feedback_worker_test.exs` | ❌ Wave 0 |
| FEED-01 | Host-mounted Phoenix endpoint exercises the full ingress path with a real `Plug.Parsers` body_reader | E2E | `mix test --working-dir examples/chimeway_demo_host` (or `mix verify.example`) | ❌ Wave 0 |
| FEED-01 | Host controller correctly maps `{:ok, _}` → 200, `{:error, :unauthorized}` → 401, other errors → non-2xx | E2E | same as above | ❌ Wave 0 |
| FEED-02 | Adapter `normalize_feedback/1` outputs (`:delivered \| :bounced \| :failed`) round-trip into `ingress.normalized_status` and into `delivery_attempt.outcome` | integration | `mix test test/chimeway/webhooks/process_feedback_worker_test.exs` | ✅ extend |
| FEED-02 | Ingress `normalized_status` is queryable independent of delivery resolution success (proves FEED-02 satisfied even when correlation is stale) | integration | `mix test test/chimeway/webhooks/ingress_test.exs` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `mix test test/chimeway/webhooks/ test/chimeway/webhooks_test.exs` (subsecond on the laptop)
- **Per wave merge:** `mix ci` (full suite green)
- **Phase gate:** `mix ci` AND `mix verify.example` (example app E2E) green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/chimeway/webhooks/ingress_test.exs` — schema validations (required fields, enum constraints, partial unique constraint via `Repo.insert/2` collision)
- [ ] `examples/chimeway_demo_host/test/demo_host/chimeway_webhook_controller_test.exs` — E2E with real `Plug.Parsers` body_reader, fixture adapter, and assertions against `Chimeway.Repo`
- [ ] `examples/chimeway_demo_host/test/test_helper.exs` — Phoenix.ConnTest setup, Ecto sandbox if applicable
- [ ] No new framework install — ExUnit is already in place
- [ ] Existing `test/chimeway/webhooks_test.exs` describe block needs a new "atomic handoff" describe to assert Multi rollback on Oban failure (mock `Oban.insert/1`)
- [ ] Existing `test/chimeway/webhooks/process_feedback_worker_test.exs` describe block needs a NEW "ingress-driven perform" describe and the existing "returns error if delivery cannot be found by delivery_id" test (line 135-145) MUST be rewritten — `assert_raise Ecto.NoResultsError` becomes `assert :ok = …` plus an assertion on the updated ingress row's `ignored_reason`

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Per-adapter HMAC verification via `c:verify_webhook/3`; runs on raw bytes BEFORE JSON decode (D-13). Adapters must use `Plug.Crypto.secure_compare/2` for digest comparison. |
| V3 Session Management | no | Webhooks are stateless provider-to-host calls; no session is established. |
| V4 Access Control | yes (limited) | Trust boundary: only requests that pass `verify_webhook/3` enter the durable ingress lifecycle (D-09). Adapter identity is part of the trust binding (D-05 dedup composite). |
| V5 Input Validation | yes | All JSON parsing isolated to `Jason.decode/1`. Ingress changeset validates required fields, enums, and adapter_module string presence. `String.to_existing_atom/1` only on bounded canonical-status values from the adapter (Phase 32 D-16 discipline). |
| V6 Cryptography | yes | NEVER hand-roll HMAC; use `Plug.Crypto.secure_compare/2` for timing-safe comparison. Document in adapter author guide. |

### Known Threat Patterns for Elixir + Phoenix Webhook Ingress

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Replay attack: provider re-sends old signed callback | Spoofing | Composite partial unique index `(adapter_module, provider_event_id) WHERE provider_event_id IS NOT NULL` collapses replays to existing row (D-05). For adapters without `provider_event_id`, replay protection is best-effort — document this gap in the adapter author guide. |
| Signature bypass via parser-mutated body | Tampering | `Plug.Parsers` `:body_reader` with MFA `{CacheBodyReader, :read_body, []}` stores raw bytes BEFORE parser consumes them (D-13). Controller flattens iolist via `IO.iodata_to_binary/1` before passing to `verify_webhook/3`. |
| Timing attack on HMAC compare | Information Disclosure | `Plug.Crypto.secure_compare/2` (constant-time). Adapter author guide makes this a stated requirement. |
| PII leak via ingress row | Information Disclosure | D-04: do NOT persist raw payload, headers, source IP. Ingress schema's `@allowed_fields` enumerates ONLY safe fields; `provider_response`/`headers` columns do not exist. Atom-safety: `ignored_reason` is `Ecto.Enum`, never `String.to_atom/1`. |
| Atom-table exhaustion via untrusted strings | DoS | All adapter-module strings persisted as `:string` (Phase 11 discipline, Phase 29 D-20). `String.to_existing_atom/1` only on bounded vocabularies. New ingress `ingress_state` and `ignored_reason` are `Ecto.Enum` with compile-time atom lists. |
| Oban retry storm on bad data | DoS | Worker returns `:ok` for unknown/stale rows (D-07). Only genuine transient failures (`{:error, _}`) trigger retries. Mirror `WorkflowProgressionWorker.normalize_progress_result/1`. |
| Log injection via `ignored_reason` | Tampering | `ignored_reason` is `Ecto.Enum` (compile-time atom set). NEVER constructed from untrusted input. |
| Denial via giant body | DoS | Plug enforces `:length` (default 8MB) on `read_body/1`. Document the recommended cap in the example app's endpoint config; default Plug limits are sufficient for typical webhook payloads. |

## Sources

### Primary (HIGH confidence)

- `lib/chimeway/signal.ex:1-41` [VERIFIED: read 2026-05-01] — canonical Multi+Oban handoff template
- `lib/chimeway/dispatch/workflow_progression_worker.ex:1-76` [VERIFIED: read 2026-05-01] — canonical safe-noop normalizer template
- `lib/chimeway/dispatch/deferred_resume_worker.ex:1-55` [VERIFIED: read 2026-05-01] — second example of Multi+`Repo.transaction`+`Oban.insert` pattern
- `lib/chimeway/webhooks.ex:1-31` [VERIFIED: read 2026-05-01] — current implementation; identifies the `enqueue` bug
- `lib/chimeway/webhooks/process_feedback_worker.ex:1-71` [VERIFIED: read 2026-05-01] — current worker; identifies the `get_delivery!/1` raise
- `lib/chimeway/adapter.ex:1-75` [VERIFIED: read 2026-05-01] — confirms existing 3-callback contract; `@optional_callbacks`
- `lib/chimeway/deliveries.ex:425-445` [VERIFIED: read 2026-05-01] — `get_delivery!/1` and `get_delivery_by_provider_message_id/1` surfaces; `fetch_delivery/1` is a NEW addition
- `test/chimeway/webhooks_test.exs:1-67` [VERIFIED: read 2026-05-01] — existing test posture
- `test/chimeway/webhooks/process_feedback_worker_test.exs:1-157` [VERIFIED: read 2026-05-01] — existing worker test posture; line 142-144 is the `assert_raise Ecto.NoResultsError` that must be rewritten
- `mix.exs:33-44` [VERIFIED: read 2026-05-01] — confirms Oban is `optional: true` and Phoenix/Plug are NOT deps
- `mix.lock` [VERIFIED: read 2026-05-01] — confirms `oban 2.21.1`, `ecto 3.13.5`, `postgrex 0.22.0`
- [CITED: hexdocs.pm/plug/Plug.Parsers.html] — official `:body_reader` MFA pattern; canonical `CacheBodyReader.read_body/2` shape
- [CITED: hexdocs.pm/oban/Oban.html] — `Oban.insert/3` Multi-aware form; `{:ok, Oban.Job.t()} | {:error, changeset | term()}` return contract

### Secondary (MEDIUM confidence)

- `.planning/phases/30-inbound-feedback-normalization/30-RESEARCH.md` [VERIFIED: read] — original webhook boundary recommendation; informs the "pure function + body_reader" architecture
- `.planning/phases/31-feedback-driven-progression/31-RESEARCH.md` [VERIFIED: read] — confirms the Signal.track integration that the new worker preserves
- `.planning/phases/32-operator-traces-audit/32-CONTEXT.md` [VERIFIED: read] — atom-safety discipline (D-16) carried forward into Phase 33's enum design
- `.planning/v1.4-MILESTONE-AUDIT.md` [VERIFIED: read] — concrete audit gaps that drive the success criteria

### Tertiary (LOW confidence — flagged for validation)

- LatticeStripe `CacheBodyReader` reference URL in CONTEXT.md DISCUSSION-LOG.md returns 404 (verified via WebFetch). The Plug docs canonical pattern is the authoritative reference; the LatticeStripe reference can be dropped from final documentation.

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — all versions verified against `mix.lock`; no new deps
- Architecture (atomic Multi handoff, safe-noop worker, host fixture app): HIGH — two of three patterns are literal in-repo precedents; the third is the canonical Plug doc pattern
- Pitfalls: HIGH — pitfalls 1, 2, 4, 5 are concretely tied to existing code or canonical docs; pitfall 3 (PII) is directly mandated by D-04
- Security domain: HIGH — leverages established codebase disciplines (Phase 11 atom-safety, Phase 29 D-20 string-typed adapter modules) and well-documented Elixir/Plug primitives

**Research date:** 2026-05-01
**Valid until:** 2026-06-01 (stable surface; Plug `:body_reader` API is years-stable; codebase precedents are months-stable)

---

*Phase: 33-webhook-ingress-durability*
*Research generated: 2026-05-01*
