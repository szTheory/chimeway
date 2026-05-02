---
phase: 33-webhook-ingress-durability
verified: 2026-05-01T03:00:00Z
status: gaps_found
score: 7/8 must-haves verified
overrides_applied: 0
re_verification: null
supersedes: "Plan 33-05 gate-closure artifact (gate-asserted satisfied; verifier-authored re-evaluation finds 1 gap blocking phase goal)"
gaps:
  - truth: "Webhook ingress failures stay safe and explainable on production-shaped traffic (Phase 33 ROADMAP goal half; T-33-RAWBODY threat mitigation)"
    status: failed
    reason: |
      The canonical CacheBodyReader pattern that the phase ships and explicitly tells host
      authors to copy (Plan 04 D-12, demo_host moduledoc lines 14-16) silently drops every
      chunk except the last when Plug.Conn.read_body/2 returns {:more, body, conn}. The with
      clause `with {:ok, body, conn} <- Plug.Conn.read_body(conn, opts)` only matches `:ok`;
      on `:more` it falls through and returns the bare {:more, ...} tuple to Plug.Parsers
      WITHOUT writing the chunk to conn.assigns[:raw_body]. Plug.Parsers calls read_body again
      for the next chunk, but only the FINAL chunk reaches the cache. The controller flattens
      that single-chunk iolist to a binary, hands it to the adapter's verify_webhook/3, and
      the HMAC over the truncated body never matches the signature header — yielding 401
      indistinguishable from a real attacker.
      Cowboy's default :read_length is 1MB, so any webhook body larger than ~1MB will chunk;
      Plug.Parsers' default :length is 8MB. Provider callbacks above 1MB are uncommon but not
      rare (some providers ship large dumps in receipts/bounces). This BL-01 propagates into
      every adopter who follows the docs (D-12 makes this the canonical reference). The test
      suite never exercises the bug because Plug.Test.conn/3 always delivers in a single :ok
      read — verified by reproducing the with-clause behavior in a standalone elixir probe
      (with {:ok, ...} <- {:more, ...} returns the bare tuple).
      The narrow SC-3 (a host-mounted HTTP path proves through to process/4) is met by file
      existence and the 5 small-body Plug.Test cases that pass. But the broader phase goal
      ("ingress failures stay safe and explainable") and the T-33-RAWBODY mitigation claim in
      33-VERIFICATION's threats table are undermined: chunked-body verification fails
      silently, neither safe nor explainable.
    artifacts:
      - path: "examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex"
        issue: "Lines 19-25: with-clause only matches :ok; :more chunks are dropped from the cache. Reference pattern is defective."
    missing:
      - "Rewrite read_body/2 to handle both :ok and :more cases: case Plug.Conn.read_body(conn, opts) do {:ok, body, conn} -> ...; {:more, body, conn} -> ...; {:error, _} = err -> err end. Both ok/more branches must update conn.assigns[:raw_body] with the chunk."
      - "Add a regression test that forces chunked delivery (e.g., set :length and :read_length opts in Plug.Parsers smaller than the body, OR boot a real Cowboy adapter with a body > 1MB) and asserts an HMAC-over-full-body signature still verifies (status 200, ingress row exists)."

deferred: []

human_verification:
  - test: "Verify D-12 reference-doc cross-links once BL-01 is fixed"
    expected: "External documentation pages and any future host-mount guides should reference examples/chimeway_demo_host/ ONLY after CacheBodyReader handles {:more, ...}"
    why_human: "Doc-cross-link verification requires reading external docs and integration channels — not programmable from the codebase alone."
  - test: "Operator A6 backwards-compat shim deploy-runbook review (carried from Plan 33-05's manual verification table)"
    expected: "Operator confirms whether the Oban queue is drained pre-deploy of Phase 33 (in which case the legacy shim in process_feedback_worker.ex perform_legacy_args/1 can be removed in Phase 34) OR explicit decision to keep the shim through one production release cycle"
    why_human: "Deploy-runbook policy decision; not derivable from code."
---

# Phase 33: Webhook Ingress Durability — Verification Report

**Phase Goal (from ROADMAP):** Provider callbacks acknowledge success only after durable async handoff, and webhook ingress failures stay safe and explainable.
**Verified:** 2026-05-01T03:00:00Z
**Status:** gaps_found
**Re-verification:** No — initial verifier-authored verification (supersedes the Plan 33-05 gate-closure artifact)

## Note on Supersession

The previous `33-VERIFICATION.md` (committed by Plan 33-05 at `50d2ebe`) was authored as a gate-closure artifact by the executor and reported `status: satisfied`. This verifier-authored report supersedes that artifact per the orchestrator instruction. The implementation work that artifact described is largely sound and verified below, but a goal-backward re-evaluation against the codebase — informed by the reviewer's findings in `33-REVIEW.md` — surfaces one BLOCKER (BL-01, chunked-body silent verification failure in the canonical reference pattern) that the gate-closure artifact did not catch because the test suite never exercises chunked delivery.

## Goal Achievement

### Roadmap Success Criteria

| # | Success Criterion | Status | Evidence |
|---|-------------------|--------|----------|
| SC-1 | `Chimeway.Webhooks.process/4` only returns success when async processing is durably queued, and queue insertion failures surface explicitly. | VERIFIED | `lib/chimeway/webhooks.ex:43-56`: `Multi.new() \|> Multi.insert(:ingress, ..., on_conflict: :nothing, conflict_target: ...) \|> Oban.insert(:job, fn %{ingress: ingress} -> ProcessFeedbackWorker.new(...)) \|> Repo.transaction() \|> case do {:ok, %{ingress: ingress}} -> {:ok, ingress}; {:error, _step, reason, _changes} -> {:error, reason} end`. The success path requires both Multi steps to commit. Rollback test in `test/chimeway/webhooks_test.exs:200-237` (`FailingOnInsertAdapter` produces `{:ok, %{status: :unknown_status}}` which fails `validate_inclusion(:normalized_status, ~w(delivered bounced failed))` at the `:ingress` step, yielding `{:error, %Ecto.Changeset{}}` from `process/4` AND `Repo.aggregate(Ingress, :count) == 0` AND `refute_enqueued`) — proves rollback is atomic. Test passes (verified via `mix test`). |
| SC-2 | Unknown or stale `delivery_id` callbacks fail safely without crashing the feedback worker. | VERIFIED | `lib/chimeway/webhooks/process_feedback_worker.ex:81-93`: `apply_feedback/1` uses non-raising `Deliveries.fetch_delivery/1` and on `{:error, :not_found}` calls `mark_ignored(ingress, :delivery_not_found)`. `mark_ignored/2` writes `ingress_state: :ignored, ignored_reason: :delivery_not_found, processed_at: DateTime.utc_now()` and returns `{:ignored, reason}`. `normalize_perform_result/1` (lines 133-136) collapses `{:ignored, _}` to `:ok` at the Oban queue boundary. Branches at lines 45-66 also handle `nil` (hard-delete race), `:ignored` (idempotent), and `:processed` (idempotent) — all return `:ok`. Tests in `test/chimeway/webhooks/process_feedback_worker_test.exs` cover stale delivery_id (with FK trigger disabled to simulate edge case), stale provider_message_id, hard-deleted ingress, already-`:ignored`, already-`:processed`. All 10 tests pass. Negative greps confirm: no `Deliveries.get_delivery!`, no `def enqueue`, no `String.to_atom(`, no `queue: :default`. |
| SC-3 | The repo includes a runtime ingress seam or reference consumer proving a host-mounted HTTP path into `Chimeway.Webhooks.process/4`. | PARTIAL | Sibling Mix project at `examples/chimeway_demo_host/` exists with 19 files, depends on chimeway via `path: "../.."`, declares `phoenix ~> 1.7` + `plug ~> 1.16` + `oban ~> 2.17` (in example app only — root `mix.exs` correctly has neither phoenix nor plug). Endpoint at `lib/demo_host_web/endpoint.ex` wires `Plug.Parsers` with `body_reader: {DemoHost.Plugs.CacheBodyReader, :read_body, []}`. Controller at `lib/demo_host_web/controllers/webhooks_controller.ex` flattens via `Enum.reverse \|> IO.iodata_to_binary`, calls `Chimeway.Webhooks.process/4`, maps to 200/401/500. `mix verify.example` exits 0; 5 E2E tests pass (valid signature, bad signature, unresolvable body, raw body iolist regression, HMAC verify-before-parse). However: see BL-01 below — the CacheBodyReader pattern, declared canonical and tagged "copy that pattern in your own host app" (cache_body_reader.ex moduledoc lines 14-16), silently drops chunks on `{:more, ...}` returns from `Plug.Conn.read_body/2`. The narrow SC-3 ("a host-mounted HTTP path exists and proves through to process/4") is met for non-chunked bodies; the broader Phase 33 goal claim ("ingress failures stay safe and explainable") is undermined for chunked bodies (>1MB or any multi-TCP-read body in production Cowboy). |

**Score:** 2/3 SCs fully verified, 1/3 PARTIAL (SC-3 narrow met, broader phase goal undermined).

### Required Artifacts (level-by-level)

| Artifact | Exists | Substantive | Wired | Data Flows | Status |
|----------|--------|-------------|-------|------------|--------|
| `lib/chimeway/webhooks/ingress.ex` | YES (78 lines) | YES — `defmodule Chimeway.Webhooks.Ingress`, schema with 8 fields, `changeset/2`, `validate_correlation_present/1`, `unique_constraint(...:chimeway_webhook_ingress_adapter_provider_event_uniq)`. No PII fields (`field(:provider_response`, `field(:headers`, `field(:raw_body`, `field(:source_ip` all return zero matches). | YES — aliased and used by `lib/chimeway/webhooks.ex:17`, `lib/chimeway/webhooks/process_feedback_worker.ex:39`, and tests. | YES — schema fields populated from `attrs` map in `Webhooks.process/4` (real adapter callbacks) and from `Repo.get/2` reads in worker. | VERIFIED |
| `priv/repo/migrations/20260502120000_create_chimeway_webhook_ingress.exs` | YES (35 lines) | YES — table DDL with binary_id PK, FK to chimeway_deliveries with `on_delete: :nilify_all`, 3 lookup indexes, partial composite unique index `where: "provider_event_id IS NOT NULL"`. Negative grep clean: no `add :provider_response`, no `add :headers`, no `add :raw_body`, no `add :source_ip`. | YES — `MIX_ENV=test mix ecto.migrate` exits 0; tests in `test/chimeway/webhooks/ingress_test.exs` insert against the migrated table successfully. | N/A (migration). | VERIFIED |
| `lib/chimeway/webhooks.ex` | YES (95 lines) | YES — atomic Multi+Oban handoff, tagged-tuple error union (5 atom variants + changeset + term), `with`-chain short-circuits before `Multi.new()`. No `ProcessFeedbackWorker.enqueue` and no bare `_ -> :error` catch-all (negative greps return zero). | YES — called by example app controller at `examples/chimeway_demo_host/lib/demo_host_web/controllers/webhooks_controller.ex:32` (the runtime seam). | YES — `attrs` map flows into `Ingress.changeset/2`; commit returns the inserted ingress; Oban job carries `ingress.id` to the worker. | VERIFIED |
| `lib/chimeway/webhooks/process_feedback_worker.ex` | YES (220 lines) | YES — `if Code.ensure_loaded?(Oban) do` wrap, `use Oban.Worker, queue: :chimeway_delivery, max_attempts: 5`, primary `perform/1` head reads ingress + branches on 4 states, A6 legacy shim heads, `apply_feedback/1` non-raising lookups, `mark_ignored/2` + `mark_processed/1`, `normalize_perform_result/1` mirrors WorkflowProgressionWorker shape, `canonicalize_status/1` minimal. | YES — wired via `Oban.insert(:job, fn %{ingress: ingress} -> ProcessFeedbackWorker.new(...))` in `webhooks.ex:49-51`. | YES — reads ingress row from durable spine; writes `:ignored`/`:processed` lifecycle back to ingress; emits `Chimeway.Signal.track/4` for downstream workflow progression. | VERIFIED |
| `lib/chimeway/deliveries.ex` (`fetch_delivery/1`) | YES (lines 437-443) | YES — non-raising `{:ok, %Delivery{}} \| {:error, :not_found}`, `is_binary/1` guard. Existing `get_delivery!/1` at line 428 unchanged. | YES — used by worker's `apply_feedback/1` at `process_feedback_worker.ex:82` and legacy shim at line 175. | YES — Repo.get returns real or nil. | VERIFIED |
| `lib/chimeway/adapter.ex` (`resolve_provider_event_id/1`) | YES | YES — `@callback resolve_provider_event_id(parsed :: map()) :: {:ok, binary()} \| :none` declared, `@optional_callbacks` lists it. | YES — used by `Webhooks.extract_provider_event_id/2` via `function_exported?(adapter_module, :resolve_provider_event_id, 1)` at `webhooks.ex:84-94`. | YES — adapters that implement it return event ids; partial unique index dedups. | VERIFIED |
| `examples/chimeway_demo_host/lib/demo_host_web/endpoint.ex` | YES | YES — `Plug.Parsers` wired with `body_reader: {DemoHost.Plugs.CacheBodyReader, :read_body, []}`. | YES — Endpoint plugs Router, controller is wired through pipeline. | YES — request bodies flow through `:body_reader` MFA, then to controller. | VERIFIED |
| `examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex` | YES (25 lines) | PARTIAL — `read_body/2` exists with the canonical `update_in(conn.assigns[:raw_body], &[body \| &1 \|\| []])` accumulator, BUT only handles `:ok` from `Plug.Conn.read_body/2`. Falls through on `:more` without caching the chunk. (BL-01.) | YES — referenced by Endpoint via the MFA. | DISCONNECTED for chunked bodies — chunks 1..N-1 are dropped from cache; only final chunk reaches the controller. Verified by reproducing the with-clause behavior in a standalone elixir probe. | **HOLLOW** (BL-01) |
| `examples/chimeway_demo_host/lib/demo_host_web/controllers/webhooks_controller.ex` | YES | YES — `IO.iodata_to_binary` after `Enum.reverse`, calls `Chimeway.Webhooks.process/4`, maps `{:ok, _} -> 200`, `{:error, :unauthorized} -> 401`, `{:error, _other} -> 500`. Routes `"echo"` to EchoAdapter, `"rawbody"` to RawBodyHmacAdapter. (Note: catch-all in `adapter_for/1` defaults unknown slugs to EchoAdapter — see IN-03 in `33-REVIEW.md`; not a phase blocker.) | YES — used by Router at line 12, called via Endpoint pipeline. | PARTIAL — flattening logic correct for non-chunked bodies; flattening of a single-chunk iolist is what reaches the adapter for chunked bodies (consequence of BL-01 upstream). | VERIFIED for non-chunked path; **inherits HOLLOW from CacheBodyReader for chunked path**. |
| `examples/chimeway_demo_host/lib/demo_host/adapters/echo_adapter.ex` | YES | YES — `@behaviour Chimeway.Adapter`, `verify_webhook/3`, `resolve_delivery/1`, `normalize_feedback/1`, `resolve_provider_event_id/1`. | YES — used by controller for `"echo"` slug. | YES. | VERIFIED |
| `examples/chimeway_demo_host/lib/demo_host/adapters/raw_body_hmac_adapter.ex` | YES | YES — `@behaviour Chimeway.Adapter`, `:crypto.mac(:hmac, :sha256, ..., body)`, `Plug.Crypto.secure_compare/2`. | YES — used by controller for `"rawbody"` slug; exercised by verify-before-parse E2E test. | YES (for non-chunked bodies). | VERIFIED for non-chunked path. |
| `test/chimeway/webhooks/ingress_test.exs` | YES | YES — 10 tests: 7 changeset validation + 3 DB integration (partial unique index dedup, NULL non-collision, cross-adapter). Passes 10/10. | YES. | YES. | VERIFIED |
| `test/chimeway/webhooks_test.exs` | YES | YES — 12 tests across 3 describes (`process/4`, atomic-handoff T-33-ATOMIC, dedup-convergence T-33-DEDUP). Passes 12/12. | YES. | YES (test data flows through real Multi+Oban path with sandbox transaction rollback). | VERIFIED — but see BL-02 WARNING below: the "unauthorized signature creates NO ingress row" test at lines 239-245 sends `"any"` (non-JSON) and would short-circuit at `decode_body` regardless of authorization, so the test does not actually prove auth-leak protection. Code path is structurally sound; test is a non-regression detector. |
| `test/chimeway/webhooks/process_feedback_worker_test.exs` | YES | YES — 10 tests including ingress-driven success paths, stale delivery_id, stale provider_message_id, safe-noop edge cases (Pitfall 2 + idempotency), backwards-compat shim (A6). Passes 10/10. | YES. | YES. | VERIFIED |
| `examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs` | YES | YES — 5 E2E tests. All pass (`cd examples/chimeway_demo_host && mix test` exits 0). | YES — uses real Endpoint + sandbox-shared Chimeway.Repo. | YES — but only on non-chunked Plug.Test bodies (BL-01 root-cause: Plug.Test.conn delivers in single :ok read; chunked path is never exercised). | PARTIAL — tests pass but do not exercise the chunked-body path that BL-01 breaks. |
| `mix.exs` (root, `verify.example` alias) | YES | YES — `"verify.example": ["cmd cd examples/chimeway_demo_host && mix deps.get && mix test"]`. Negative grep: no `{:phoenix` and no `{:plug, ` deps in root. | YES — alias resolves; verified by running `cd examples/chimeway_demo_host && mix deps.get && mix test` which exits 0 with 5 tests passing. | YES. | VERIFIED |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `lib/chimeway/webhooks.ex` | `lib/chimeway/webhooks/ingress.ex` | `alias` + `Multi.insert(:ingress, Ingress.changeset(%Ingress{}, attrs), on_conflict: :nothing, conflict_target: ...)` | WIRED | webhooks.ex:17 alias + 44-48 Multi.insert call |
| `lib/chimeway/webhooks.ex` | `lib/chimeway/webhooks/process_feedback_worker.ex` | `Oban.insert(:job, fn %{ingress: ingress} -> ProcessFeedbackWorker.new(%{"ingress_id" => ingress.id}) end)` | WIRED | webhooks.ex:49-51 |
| `test/chimeway/webhooks_test.exs` | `lib/chimeway/webhooks.ex` | `Webhooks.process(...)` + `assert_enqueued worker: Chimeway.Webhooks.ProcessFeedbackWorker, args: %{"ingress_id" => ingress.id}` | WIRED | Verified by passing 12 tests including atomic-handoff describe |
| `lib/chimeway/webhooks/process_feedback_worker.ex` | `lib/chimeway/webhooks/ingress.ex` | `alias Chimeway.Webhooks.Ingress` + `Repo.get(Ingress, ingress_id)` | WIRED | worker.ex:39 + 45 |
| `lib/chimeway/webhooks/process_feedback_worker.ex` | `lib/chimeway/deliveries.ex` | `Deliveries.fetch_delivery(id)` + `Deliveries.get_delivery_by_provider_message_id(pmid)` | WIRED | worker.ex:82, 89, 175, 185 |
| `examples/chimeway_demo_host/lib/demo_host_web/endpoint.ex` | `examples/.../plugs/cache_body_reader.ex` | `body_reader: {DemoHost.Plugs.CacheBodyReader, :read_body, []}` | WIRED structurally; **disconnected for chunked bodies (BL-01)** | endpoint.ex (Plug.Parsers config). With chunked bodies, CacheBodyReader returns `{:more, ...}` to Plug.Parsers without writing to assigns — chunks 1..N-1 are lost before reaching the controller's `IO.iodata_to_binary`. |
| `examples/chimeway_demo_host/lib/demo_host_web/controllers/webhooks_controller.ex` | `Chimeway.Webhooks.process/4` | `Chimeway.Webhooks.process(adapter_module, raw_body, headers, config)` | WIRED | controller.ex:32 |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `Chimeway.Webhooks.Ingress` rows | `attrs` map | Real adapter callbacks (verify_webhook/resolve_delivery/normalize_feedback/optional resolve_provider_event_id) feed real data through process/4 | YES | FLOWING |
| `ProcessFeedbackWorker.perform/1` | `ingress` from `Repo.get(Ingress, ingress_id)` | Durable DB row written by Multi.insert | YES (live DB read; tests confirm) | FLOWING |
| `webhooks_controller.ex` `raw_body` | `conn.assigns[:raw_body]` flattened iolist | `CacheBodyReader.read_body/2` cache (Plug.Parsers MFA) | PARTIAL — full data for single-chunk delivery; **partial data (last chunk only) for chunked delivery (BL-01)** | STATIC for chunked path |
| `examples/.../webhooks_controller_test.exs` body | Test conn body via `Plug.Test.conn(:post, path, body)` | Hardcoded JSON binaries built in test | YES — but always single-chunk (Plug.Test does not exercise the `:more` path) | FLOWING (for what the tests actually exercise; not a regression detector for chunked path) |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Code compiles clean | `MIX_ENV=test mix compile --warnings-as-errors` | exit 0 | PASS |
| Migration applies | (already applied; test DB is migrated) | DB has `chimeway_webhook_ingress` table per `MIX_ENV=test mix ecto.migrate` | PASS |
| Ingress schema + DB tests pass | `MIX_ENV=test mix test test/chimeway/webhooks/ingress_test.exs` | 10 tests, 0 failures, exit 0 | PASS |
| Webhooks process/4 contract tests | `MIX_ENV=test mix test test/chimeway/webhooks_test.exs` | 12 tests, 0 failures, exit 0 | PASS |
| Worker safe-noop + idempotent + shim | `MIX_ENV=test mix test test/chimeway/webhooks/process_feedback_worker_test.exs` | 10 tests, 0 failures, exit 0 | PASS |
| Full chimeway test suite | `MIX_ENV=test mix test` | 548 tests, 0 failures, exit 0 | PASS |
| Example app E2E suite | `cd examples/chimeway_demo_host && mix deps.get && MIX_ENV=test mix test` | 5 tests, 0 failures, exit 0 (after fetching deps from Hex on first run) | PASS for non-chunked path only — tests do not exercise the `:more`/chunked path that BL-01 breaks |
| BL-01 reproduction probe | `with {:ok, body, conn} <- {:more, "chunk1", :fake_conn} do ... end` returns `{:more, "chunk1", :fake_conn}` (the with-clause does NOT match `:more`, falls through, returns the bare tuple) | confirmed via standalone elixir probe | FAIL — confirms BL-01 is real and chunks 1..N-1 are dropped from the cache |

### Requirements Coverage

| Requirement | Source Plan(s) | Description | Status | Evidence |
|-------------|---------------|-------------|--------|----------|
| FEED-01 | 33-01, 33-02, 33-03, 33-04, 33-05 | System provides a webhook ingestion layer to receive asynchronous provider callbacks (receipts, bounces). | SATISFIED with WARNING | Atomic Multi+Oban handoff in `Chimeway.Webhooks.process/4` (Plan 02) + safe-noop worker (Plan 03) + runtime host-mount example (Plan 04). All 32 phase-33 unit/integration tests pass. **Caveat:** the canonical reference adopters are told to copy (`CacheBodyReader`) silently fails on chunked bodies (BL-01). FEED-01's existence as an ingestion layer is met; FEED-01's reliability for production-shaped traffic depends on adopters not copying the reference verbatim. |
| FEED-02 | 33-01, 33-03 | Provider-specific callback payloads are normalized into canonical Chimeway delivery outcomes (delivered, bounced, failed). | SATISFIED | Schema field `:normalized_status` constrained by `validate_inclusion(:normalized_status, ~w(delivered bounced failed))` (`lib/chimeway/webhooks/ingress.ex:56`). Adapter callback `normalize_feedback/1` returns `{:ok, %{status: :delivered \| :bounced \| :failed}}`. Worker reads `ingress.normalized_status` and routes via `canonicalize_status/1` (`delivered -> succeeded`, others passthrough). Tests cover all three outcomes round-tripping through the schema. |

No requirement IDs declared in plan frontmatter are missing. Cross-reference with `.planning/REQUIREMENTS.md` `Phase 33` row (`FEED-01`, `FEED-02`) confirms both are claimed by Phase 33 plans and addressed.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex` | 19-25 | `with {:ok, body, conn} <- Plug.Conn.read_body(conn, opts)` only matches `:ok`; `:more` falls through and chunks 1..N-1 are dropped from cache | BLOCKER | Silent HMAC verification failure on any production body that triggers `{:more, ...}` (>1MB by default Cowboy `:read_length`, or any multi-TCP-read delivery). Provider sees 401 indistinguishable from a real attack and retries indefinitely; operator sees a "burst of unauthorized callbacks" with no actionable signal. Pattern is documented as canonical (D-12) and adopters are told to copy it. (`33-REVIEW.md` BL-01.) |
| `test/chimeway/webhooks_test.exs` | 239-245 | "unauthorized signature creates NO ingress row" test sends `"any"` (non-JSON); short-circuits at `decode_body` regardless of authorization, so the test does not detect a regression where auth verification is skipped | WARNING | Code path is structurally sound (the `with`-chain ordering puts `verify_webhook` before `Jason.decode`), so the actual T-33-AUTH-LEAK property holds. But the test is a non-regression detector for D-09: a future refactor that swapped the order (parse-then-verify) would still pass this test, because `"any"` fails parsing first. Recommend rewriting the test with valid JSON + invalid signature, plus a positive control test asserting the same body with a valid signature creates exactly one ingress row. (`33-REVIEW.md` BL-02.) |
| `lib/chimeway/webhooks/process_feedback_worker.ex` | 194-218 | `run_legacy_pipeline/2` calls `String.to_existing_atom(canonicalize_status(status))` on legacy job args without rescue. A legacy job with `"status" => "queued"` (or any value canonicalize_status passes through unchanged that isn't pre-existing as an atom) raises `ArgumentError`, which escapes the legacy heads (`normalize_perform_result/1` is not on the legacy path). | INFO/WARNING (out of phase scope strictly: A6 shim safety) | The A6 backwards-compat shim is meant to provide deploy safety for one release cycle; this regression specifically defeats its purpose. Worker would crash → Oban retry storm — exactly T-33-RETRY's threat. (`33-REVIEW.md` WR-05.) |
| `lib/chimeway/webhooks.ex` | 28 | `process/4` accepts `binary()` per @spec but has no `is_binary(raw_body)` runtime guard | INFO | If a host author forgets to flatten the iolist before calling `process/4`, `RawBodyHmacAdapter.verify_webhook/3` (`when is_binary(body)`) raises FunctionClauseError, which propagates as 500. Fail-closed guard would be cleaner. (`33-REVIEW.md` WR-01.) |

### Human Verification Required

1. **Verify D-12 reference-doc cross-links once BL-01 is fixed.** Once the BL-01 fix lands, audit any external docs / future host-mount guides that point at `examples/chimeway_demo_host/` to confirm they describe the corrected pattern. Why human: doc-cross-link verification spans systems outside the codebase.

2. **A6 backwards-compat shim deploy-runbook review** (carried from Plan 33-05 `33-VALIDATION.md` Manual-Only Verifications). Operator decides: drain Oban queue pre-deploy and remove `perform_legacy_args/1` in Phase 34, OR keep the shim through one production release cycle and address WR-05 (legacy `String.to_existing_atom` rescue). Why human: deploy-policy decision.

### Gaps Summary

**One BLOCKER and one structural WARNING.**

The phase implementation lands the core durable handoff cleanly (Plans 01-03 + 05). `Chimeway.Webhooks.process/4` is structurally atomic via `Ecto.Multi` + `Oban.insert/3`; the `enqueue/1` antipattern is removed; failure modes return tagged tuples; the worker is ingress-driven and safe-noop with explicit `ignored_reason` writes; the partial composite unique index gives race-free dedup; 548 chimeway tests pass; the example app's 5 tests pass. SC-1 and SC-2 are verified end-to-end.

The single gap is the canonical reference pattern Plan 04 ships. `DemoHost.Plugs.CacheBodyReader.read_body/2` only handles the `:ok` return from `Plug.Conn.read_body/2`. When the body chunks (`{:more, body, conn}`), the `with` clause falls through and returns the bare tuple to `Plug.Parsers` without caching the chunk. Plug.Parsers then calls `read_body` again for the next chunk, eventually getting `:ok` for the LAST chunk only — the prior N-1 chunks are silently lost from `conn.assigns[:raw_body]`. The controller flattens that single-chunk iolist to a binary, hands it to the adapter's `verify_webhook/3`, and the HMAC over the truncated body never matches the signature header. Result: 401 indistinguishable from a real attacker on every chunked webhook.

This matters because (a) the moduledoc on `CacheBodyReader` explicitly tells host authors to "copy that pattern in your own host app" (Plan 04 D-12 makes this the canonical reference); (b) Cowboy's default `:read_length` is 1MB, so any provider whose webhook body exceeds 1MB will chunk; (c) the test suite never exercises the `:more` path because `Plug.Test.conn/3` always delivers in a single `:ok` read — verified by reproducing the with-clause behavior in a standalone elixir probe. The phase ships passing tests and a documented threat-mitigation claim (T-33-RAWBODY) that does not survive contact with production-shaped traffic.

The fix is small: replace the `with` clause with a `case` that handles both `:ok` and `:more` and writes the chunk to `conn.assigns[:raw_body]` in both branches. A regression test that forces chunked delivery (e.g., set `:length` and `:read_length` opts in Plug.Parsers smaller than the body, or boot a real Cowboy adapter with a body > 1MB) and asserts an HMAC-over-full-body signature still verifies (status 200, ingress row exists) closes the gap.

The auth-leak test (BL-02) is a separate WARNING: the underlying code path is structurally sound (ordering in the `with`-chain enforces the property), but the regression test does not exercise what it claims to exercise. Recommend tightening the test as a non-blocking follow-up.

---

_Verified: 2026-05-01T03:00:00Z_
_Verifier: Claude (gsd-verifier)_
_Phase 33-VERIFICATION.md authored by Plan 33-05 (`50d2ebe`) is superseded by this report._
