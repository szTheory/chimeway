---
phase: 33-webhook-ingress-durability
reviewed: 2026-05-02T00:00:00Z
depth: standard
files_reviewed: 25
files_reviewed_list:
  - lib/chimeway/adapter.ex
  - lib/chimeway/deliveries.ex
  - lib/chimeway/webhooks.ex
  - lib/chimeway/webhooks/ingress.ex
  - lib/chimeway/webhooks/process_feedback_worker.ex
  - priv/repo/migrations/20260502120000_create_chimeway_webhook_ingress.exs
  - test/chimeway/deliveries_test.exs
  - test/chimeway/webhooks/ingress_test.exs
  - test/chimeway/webhooks/process_feedback_worker_test.exs
  - test/chimeway/webhooks_test.exs
  - examples/chimeway_demo_host/mix.exs
  - examples/chimeway_demo_host/config/config.exs
  - examples/chimeway_demo_host/config/test.exs
  - examples/chimeway_demo_host/lib/demo_host.ex
  - examples/chimeway_demo_host/lib/demo_host/application.ex
  - examples/chimeway_demo_host/lib/demo_host/adapters/echo_adapter.ex
  - examples/chimeway_demo_host/lib/demo_host/adapters/raw_body_hmac_adapter.ex
  - examples/chimeway_demo_host/lib/demo_host_web.ex
  - examples/chimeway_demo_host/lib/demo_host_web/endpoint.ex
  - examples/chimeway_demo_host/lib/demo_host_web/router.ex
  - examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex
  - examples/chimeway_demo_host/lib/demo_host_web/controllers/webhooks_controller.ex
  - examples/chimeway_demo_host/lib/demo_host_web/controllers/error_json.ex
  - examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs
  - examples/chimeway_demo_host/test/test_helper.exs
findings:
  blocker: 2
  warning: 7
  info: 4
  total: 13
status: issues_found
---

# Phase 33: Code Review Report

**Reviewed:** 2026-05-02T00:00:00Z
**Depth:** standard
**Files Reviewed:** 25
**Status:** issues_found

## Summary

The Phase 33 implementation lands the core durable-spine model cleanly: the partial composite unique index, the `Multi.insert + Oban.insert` atomic handoff in `Chimeway.Webhooks.process/4`, and the safe-noop convergence in `ProcessFeedbackWorker.perform/1` are all coherent and well-tested at the unit level. However the host-mount reference (the entire D-13 / T-33-RAWBODY contract) ships with a real chunked-body bug in `DemoHost.Plugs.CacheBodyReader.read_body/2` that silently breaks signature verification for any request large enough for `Plug.Conn.read_body/2` to return `{:more, ...}`. Because the moduledoc explicitly tells host authors to "copy that pattern in your own host app," that defect propagates into production adopters. A second BLOCKER comes from the `T-33-AUTH-LEAK` test asserting `Repo.aggregate(Ingress, :count) == 0` after sending an unsigned `"any"` body — the body is non-JSON and would never reach the `Multi.insert` regardless of signature, so the test does NOT actually prove that an authorized signature with the same body would behave the same way; the assertion accepts a false-negative success.

Several WARNINGs cluster around the `:body_reader` MFA contract (the canonical pattern is repeated almost verbatim from a Plug docs example that is not webhook-grade), the lack of explicit `:max_body_length` / size-limit configuration on the Plug.Parsers stack (DoS surface), and the `update_in(conn.assigns[:raw_body], ...)` precedence ambiguity that depends on `Map`'s Access protocol returning `nil` rather than raising for missing keys.

The `Chimeway.Webhooks.Ingress` schema and migration are correct: partial unique index syntax is right, the `unique_constraint` on the changeset uses the index name, and the `validate_correlation_present/1` helper covers the `:ignored`-without-correlation-keys case via `get_field/2` (which sees the changes as well as the data). Worker idempotency via the three early `Repo.get` heads (`nil`, `:ignored`, `:processed`) is correct. The Multi+Oban handoff in `Webhooks.process/4` correctly uses `Oban.insert(:job, fn %{ingress: …} → …)` so the job carries the durable ingress id.

## BLOCKER Issues

### BL-01: `CacheBodyReader.read_body/2` drops every chunk except the last when the body chunks (signature verification silently breaks for large webhook bodies)

**File:** `examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex:19-25`
**Issue:** The body reader's `with {:ok, body, conn} <- Plug.Conn.read_body(conn, opts)` clause matches ONLY `:ok`. When `Plug.Conn.read_body/2` returns `{:more, chunk, conn}` (which it does for any request body larger than the default `:length` of 8MB *or* whenever the underlying adapter delivers the body in multiple TCP reads — Cowboy's default `:read_length` is 1MB), the `with` falls through and returns `{:more, chunk, conn}` to `Plug.Parsers` **without prepending `chunk` to `conn.assigns[:raw_body]`**. `Plug.Parsers` then calls `read_body` again for the next chunk. The result is that only the FINAL chunk (the one that returns `:ok`) is cached. The controller flattens that single chunk to a binary, hands it to `verify_webhook/3`, and the HMAC over the truncated body never matches the signature header. The whole `T-33-RAWBODY` / D-13 contract collapses for any chunked request — silently, with a 401 indistinguishable from a real attacker. The test suite does not detect this because `Plug.Test.conn(:post, …, body)` delivers the entire body in a single `:ok` read.

This propagates into adopters because `webhooks_controller.ex:5-8` and `cache_body_reader.ex:13-16` explicitly tell host authors to copy this pattern.

**Fix:**
```elixir
def read_body(conn, opts) do
  case Plug.Conn.read_body(conn, opts) do
    {:ok, body, conn} ->
      {:ok, body, update_in(conn.assigns[:raw_body], &[body | &1 || []])}

    {:more, body, conn} ->
      {:more, body, update_in(conn.assigns[:raw_body], &[body | &1 || []])}

    {:error, _} = err ->
      err
  end
end
```

Add a regression test that forces chunked delivery (e.g., by setting `:length` and `:read_length` opts in `Plug.Parsers` to a value smaller than the body, or by using a real Cowboy adapter with a body > 1 MB) and asserts that an HMAC-over-full-body signature still verifies.

### BL-02: `unauthorized signature creates NO ingress row` test is a false-positive — it never had a chance to commit one regardless of authorization

**File:** `test/chimeway/webhooks_test.exs:239-245`
**Issue:** The assertion claims to prove `D-09 / T-33-AUTH-LEAK` ("unauthorized signatures must NOT durably persist anything"). The test sends `"any"` as `raw_body` with an invalid signature and asserts `Repo.aggregate(Chimeway.Webhooks.Ingress, :count) == 0`. But `"any"` is not valid JSON — even if `verify_webhook/3` had returned `:ok`, the next step in the `with` chain (`decode_body/1`) would have returned `{:error, :unparseable_body}` and short-circuited before the `Multi.insert(:ingress, …)` step. The test therefore proves nothing about the auth gate specifically; it proves the early-fail behavior of `decode_body`, which is already covered by the `unparseable_body` test on line 247-255.

A real `T-33-AUTH-LEAK` test must use a body that WOULD have produced an ingress row had verification passed (e.g., the same JSON body used in the `:ok` test cases) and only flip the signature header. As written, this test cannot detect a regression where verification is skipped — because the body fails parsing anyway.

**Fix:**
```elixir
test "unauthorized signature creates NO ingress row (D-09 / T-33-AUTH-LEAK)" do
  # Use a body that WOULD have produced an ingress row if verification passed —
  # the auth gate is the only difference between this test and the success case.
  body = Jason.encode!(%{"msg_id" => "msg_authleak", "status" => "ok"})

  assert {:error, :unauthorized} =
           Webhooks.process(MockAdapter, body, [{"signature", "invalid"}], [])

  assert Repo.aggregate(Chimeway.Webhooks.Ingress, :count) == 0
  refute_enqueued worker: Chimeway.Webhooks.ProcessFeedbackWorker
end
```

Add a second positive control test that asserts the SAME body with `[{"signature", "valid"}]` produces exactly one ingress row, so the only-difference-is-the-signature contract is verifiable.

## WARNINGs

### WR-01: `Chimeway.Webhooks.process/4` accepts an iolist `raw_body` per spec but offers no enforcement, and the `:body_reader` cache is iolist-shaped

**File:** `lib/chimeway/webhooks.ex:20`, `examples/chimeway_demo_host/lib/demo_host_web/controllers/webhooks_controller.ex:26-30`
**Issue:** The spec says `process(module(), binary(), list(), keyword())`. The example controller flattens the iolist before calling `process/4`. But there is no compile-time or runtime guard that the binary is actually a binary — if a host author forgets to flatten and passes the iolist directly, `RawBodyHmacAdapter.verify_webhook/3` (line 25, `when is_binary(body)`) raises `FunctionClauseError`, which inside `Webhooks.process/4`'s `with` chain bubbles up as an unhandled exception rather than `{:error, :unauthorized}`. That converts a benign mistake into a 500 (controller's `case` doesn't match any tuple) or worse, a leak-prone error response. Add an explicit `is_binary(raw_body)` guard at the `process/4` entry — fail closed with a clear error tuple that the controller can map to `400 Bad Request`.
**Fix:** Add `def process(adapter_module, raw_body, headers, config) when is_atom(adapter_module) and is_binary(raw_body) and is_list(headers) and is_list(config) do …` so the iolist mistake is caught at the library boundary, not deep in the adapter.

### WR-02: No `:length` cap on `Plug.Parsers` in the demo endpoint — DoS surface in the reference host-mount

**File:** `examples/chimeway_demo_host/lib/demo_host_web/endpoint.ex:12-16`
**Issue:** The endpoint's `plug Plug.Parsers, …` does not pass `:length`, leaving the default 8 MB cap. For a webhook ingress endpoint, hosts almost always want a tighter cap (most providers ship < 64 KB callbacks). Worse, because the body is cached in `conn.assigns[:raw_body]` as an iolist, an attacker can submit an 8 MB POST and force the BEAM to allocate 8 MB of binary storage per request before any auth check runs. Document `:length: 65_536` (or similar) as part of the canonical example, and call out that the cache amplifies the cost of an oversize POST.
**Fix:**
```elixir
plug Plug.Parsers,
  parsers: [:urlencoded, :json],
  pass: ["text/*"],
  length: 1_048_576,  # 1 MB cap for webhook ingress; tune per provider.
  body_reader: {DemoHost.Plugs.CacheBodyReader, :read_body, []},
  json_decoder: Jason
```

### WR-03: `update_in(conn.assigns[:raw_body], &[body | &1 || []])` operator-precedence ambiguity is fragile and hard to reason about

**File:** `examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex:21`
**Issue:** The expression `&[body | &1 || []]` parses as `&[body | (&1 || [])]` because `||` binds tighter than `|`. This works, but the moduledoc and surrounding comments do not document this precedence, and a maintainer who tweaks this line is likely to introduce a parse-shape bug (e.g., changing it to `&[body, &1 || []]` or `&[body | &1] || []`). Pair that with BL-01 and the body reader becomes a fragile teaching example. Spell out the alternative `&1 = &1 || []; [body | &1]` form in the function body to remove the precedence trap.
**Fix:**
```elixir
def read_body(conn, opts) do
  case Plug.Conn.read_body(conn, opts) do
    {:ok, body, conn} -> {:ok, body, prepend_chunk(conn, body)}
    {:more, body, conn} -> {:more, body, prepend_chunk(conn, body)}
    {:error, _} = err -> err
  end
end

defp prepend_chunk(conn, chunk) do
  update_in(conn.assigns[:raw_body], fn
    nil -> [chunk]
    list -> [chunk | list]
  end)
end
```

### WR-04: `webhooks_controller.ex` collapses every non-`:unauthorized` library error to a single 500, suppressing operator visibility

**File:** `examples/chimeway_demo_host/lib/demo_host_web/controllers/webhooks_controller.ex:43-47`
**Issue:** `{:error, :unparseable_body}`, `{:error, :unresolvable_delivery}`, `{:error, :unnormalizable_feedback}`, and `{:error, %Ecto.Changeset{}}` all map to `send_resp(conn, 500, "Internal Server Error")`. That hides the distinction between "client sent malformed JSON" (400) and "library/database failure" (500), violating the guidance the moduledoc itself acknowledges ("hosts may pick 400 / 422 based on their own observability conventions"). Worse, the same response makes it impossible to tell from the provider's retry logs whether the host or the provider needs to fix the issue. Either map the named error atoms to specific 4xx codes in the example, or add a TODO that points adopters at the right mapping table.
**Fix:**
```elixir
case Chimeway.Webhooks.process(adapter_module, raw_body, headers, config) do
  {:ok, _ingress} -> send_resp(conn, 200, "OK")
  {:error, :unauthorized} -> send_resp(conn, 401, "Unauthorized")
  {:error, :unparseable_body} -> send_resp(conn, 400, "Bad Request")
  {:error, :unresolvable_delivery} -> send_resp(conn, 422, "Unprocessable")
  {:error, :unnormalizable_feedback} -> send_resp(conn, 422, "Unprocessable")
  {:error, _other} -> send_resp(conn, 500, "Internal Server Error")
end
```

### WR-05: Backwards-compat shim swallows `String.to_existing_atom` failure on legacy `status` and crashes the worker (Pitfall 2 escape)

**File:** `lib/chimeway/webhooks/process_feedback_worker.ex:194-218`
**Issue:** `run_legacy_pipeline/2` reads `Map.get(args, "status", "")` then calls `String.to_existing_atom(canonicalize_status(status))`. If a legacy job has `"status" => "queued"` or any other value not pre-existing as an atom in the BEAM, `String.to_existing_atom/1` raises `ArgumentError`. The error escapes `run_legacy_pipeline/2`, escapes `perform_legacy_args/1`, and is NOT caught by the new `normalize_perform_result/1` because legacy heads bypass that path entirely. The result is a job-crash → Oban retry storm, exactly the T-33-RETRY threat that the new path defends against. The legacy shim was added "for one release cycle" (deploy-safety A6), so this regression specifically defeats the safety it was meant to provide.
**Fix:** Wrap the legacy `String.to_existing_atom` in a `try`/`rescue` and route the failure through the same noop convergence as the new path:
```elixir
defp safe_outcome(status) do
  try do
    {:ok, String.to_existing_atom(canonicalize_status(status))}
  rescue
    ArgumentError -> :error
  end
end

defp run_legacy_pipeline(delivery, args) do
  case safe_outcome(Map.get(args, "status", "")) do
    {:ok, outcome} -> # … existing code with outcome …
    :error -> :ok  # legacy unknown status — drain safely, do NOT retry
  end
end
```

The same fix applies to `run_feedback_pipeline/2` (line 95-104) — `String.to_existing_atom(canonicalize_status(ingress.normalized_status))` raises if the ingress row was hand-crafted with an off-vocabulary status. The schema's `validate_inclusion(:normalized_status, ~w(delivered bounced failed))` defends the happy path, but database-level corruption or a future schema migration could surface a bad value here.

### WR-06: Demo host `mix.exs` declares `start_permanent: false`, but the test suite assumes `:chimeway` (with its Repo + Oban supervisor) is started

**File:** `examples/chimeway_demo_host/mix.exs:11`, `examples/chimeway_demo_host/test/test_helper.exs:8`
**Issue:** `start_permanent: false` only affects whether the BEAM crashes when the application stops abnormally — it does not prevent boot. However, the test_helper relies on `Application.ensure_all_started(:demo_host)` to bring up `:chimeway` (and therefore the Repo + Oban). If a maintainer ever changes `:demo_host`'s `application` callback (currently `mod: {DemoHost.Application, []}`) without explicitly listing `:chimeway` in `extra_applications`, the dep-tree start order becomes implementation-dependent on Mix's version. Add `:chimeway` to `extra_applications` to make the dependency explicit and survive Mix changes.
**Fix:**
```elixir
def application do
  [mod: {DemoHost.Application, []}, extra_applications: [:logger, :chimeway]]
end
```

### WR-07: `Chimeway.Webhooks.process/4` re-raises adapter-callback exceptions instead of converting to a structured error

**File:** `lib/chimeway/webhooks.ex:28-58`
**Issue:** `adapter_module.verify_webhook(raw_body, headers, config)`, `adapter_module.resolve_delivery(parsed)`, and `adapter_module.normalize_feedback(parsed)` are called directly inside the `with` chain. If the adapter raises (e.g., a buggy adapter calls `String.to_existing_atom` on untrusted input, or a third-party adapter raises on a malformed signature header), the exception propagates out of `Webhooks.process/4` and out of the host controller — typically as a 500 with the exception message, which can leak internals, and as an unrecoverable crash from the provider's perspective. `process/4` is documented as a "pure function boundary" but is not enforced as such. Wrap the adapter calls in `try`/`rescue` and convert to `{:error, :adapter_callback_raised}` (or similar) so the host can return a stable status code.
**Fix:** Decide whether adapter exceptions should be programmer errors (let them crash, surface in logs) or runtime errors (catch + wrap). Either way, document the contract in the moduledoc and add a test that asserts the chosen behavior.

## INFO

### IN-01: `chimeway_webhook_ingress.id` uses `:binary_id` without a `default: fragment("gen_random_uuid()")`, while every other Chimeway table uses `:uuid` with the DB-side default

**File:** `priv/repo/migrations/20260502120000_create_chimeway_webhook_ingress.exs:6`
**Issue:** Every other migration in the repo (e.g., `20260424082833_create_chimeway_deliveries.exs`, `20260424082834_create_chimeway_delivery_attempts.exs`, `20260429170100_create_chimeway_workflow_runs.exs`) uses `add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")`. The new ingress migration uses `add :id, :binary_id, primary_key: true` with no DB-side default, relying on Ecto's `autogenerate: true` in the schema. Both work, but the inconsistency complicates raw-SQL inserts (e.g., the test suite's `Ecto.Adapters.SQL.query!` calls in `process_feedback_worker_test.exs:155-159`) and operator-side data-fix scripts. Align with the existing convention.
**Fix:**
```elixir
add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
```

### IN-02: The `validate_correlation_present/1` error attaches the message to `:delivery_id` even when the issue is a missing `provider_message_id` or missing `:ignored` reason

**File:** `lib/chimeway/webhooks/ingress.ex:64-77`
**Issue:** When validation fails, the error is added to the `:delivery_id` field with a message that mentions all three valid shapes. This makes the changeset error report harder to parse for callers that route on `changeset.errors[:provider_message_id]` or `changeset.errors[:ingress_state]`. Consider a `:base` error, or attach the same message to all three field keys so callers can match on any of them.
**Fix:** Use `add_error(changeset, :base, "…")` (Ecto supports `:base` as a conventional non-field error key), or replicate the error onto each missing-field key.

### IN-03: `webhooks_controller.ex` defaults unknown adapter slugs to `EchoAdapter` instead of returning 404

**File:** `examples/chimeway_demo_host/lib/demo_host_web/controllers/webhooks_controller.ex:54`
**Issue:** `defp adapter_for(_unknown), do: DemoHost.Adapters.EchoAdapter` silently routes any unknown `/webhooks/chimeway/<slug>` to the EchoAdapter, which has the deliberately-weak `[{"signature", "valid"}]` literal-match check. An adopter who copies this controller and forgets to handle unknown slugs will accept arbitrary signed payloads under any URL. Fail closed with a 404 instead.
**Fix:**
```elixir
defp adapter_for("echo"), do: {:ok, DemoHost.Adapters.EchoAdapter}
defp adapter_for("rawbody"), do: {:ok, DemoHost.Adapters.RawBodyHmacAdapter}
defp adapter_for(_), do: :error

# In create/2:
case adapter_for(conn.path_params["adapter"]) do
  {:ok, adapter_module} -> # … existing flow …
  :error -> send_resp(conn, 404, "Not Found")
end
```

### IN-04: Hardcoded HMAC `@secret` in `RawBodyHmacAdapter` and hardcoded `secret_key_base` in `config.exs` — both are clearly labeled as fixtures, but both are flagged by static-analysis tools

**File:** `examples/chimeway_demo_host/lib/demo_host/adapters/raw_body_hmac_adapter.ex:21`, `examples/chimeway_demo_host/config/config.exs:6`
**Issue:** Both values are intentional (the moduledoc and inline comments explicitly call them out as test/fixture-only). However, secret-scanning tools (truffleHog, gitleaks) will flag both, which adds noise for adopters who blindly copy the example into their own repo. Prefix with `# trufflehog:ignore` or move to `Application.compile_env/3` reads from an env var so the value is sourced from the environment by default, with the literal as a fallback only when `MIX_ENV == :test`.

---

_Reviewed: 2026-05-02T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
