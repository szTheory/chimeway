---
phase: 33-webhook-ingress-durability
reviewed: 2026-05-02T15:30:00Z
depth: standard
files_reviewed: 12
files_reviewed_list:
  - examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex
  - examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs
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
findings:
  blocker: 0
  warning: 8
  info: 4
  total: 12
status: issues_found
---

# Phase 33: Code Review Report (re-review post 33-06)

**Reviewed:** 2026-05-02T15:30:00Z
**Depth:** standard
**Files Reviewed:** 12 (re-scoped to the 12 files in this re-review pass; the prior pass scoped 25 because it included unmodified-since-33-04 host-app files)
**Status:** issues_found (no BLOCKERs; warnings + info remain)

## Summary

Plan 33-06 lands the BL-01 fix cleanly. `DemoHost.Plugs.CacheBodyReader.read_body/2` now uses an exhaustive `case` over the three `Plug.Conn.read_body/2` return shapes (`:ok`, `:more`, `:error`); both `:ok` and `:more` branches write the chunk into `conn.assigns[:raw_body]`, and the moduledoc documents chunked-delivery behavior so adopters who follow D-12 ("copy that pattern in your own host app") get correct behavior on bodies > Cowboy's 1 MB `:read_length`. The accompanying regression suite is well-shaped: a unit test forces `{:more, ...}` via a custom `ChunkedTestAdapter` (`@behaviour Plug.Conn.Adapter`) and asserts the accumulator contains both chunks in reverse arrival order, and an HMAC E2E test proves the full body still verifies after the fix. **BL-01 is closed.**

The other items from the prior pass remain. The `T-33-AUTH-LEAK` test (`test/chimeway/webhooks_test.exs:239-245`) still uses the body `"any"` — an unparseable body that would fail the pipeline at `decode_body/1` regardless of signature verification. The first assertion (`{:error, :unauthorized}`) does provide some protection against a regression that skips `verify_webhook` (the result tag would change), but the test still cannot distinguish between "auth gate works" and "parse gate happened to also reject" for the no-ingress-row claim — so I am downgrading what was BL-02 to a WARNING with the same fix recipe (the demo-host test at `examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs:41-52` already uses a valid JSON body with an invalid signature, which proves the contract at the host-mount layer; the library-layer test should be tightened to match).

The remaining warnings cluster around the library boundary (`Chimeway.Webhooks.process/4` accepts but does not enforce `is_binary(raw_body)`; adapter-callback exceptions propagate as 500s), the legacy worker shim (`String.to_existing_atom/1` on attacker-influenced legacy `status` strings still raises and triggers the T-33-RETRY storm the new path defends against), and the host-mount reference (no `:length` cap on `Plug.Parsers`, the demo controller collapses every non-`:unauthorized` error to 500, the demo `mix.exs` does not list `:chimeway` in `extra_applications`). Info items cover schema-level convention drift (`:binary_id` vs `:uuid` with `gen_random_uuid()` default) and a fail-open default in `adapter_for/1`.

The `Chimeway.Webhooks.Ingress` schema, migration, partial unique index, and worker idempotency convergence (`nil` / `:ignored` / `:processed` early returns) are correct. The `Multi.insert + Oban.insert` atomic handoff in `Webhooks.process/4` is sound (the inner `Oban.insert(:job, fn %{ingress: …} → …)` correctly threads the durable ingress id into the job args).

## BLOCKER Issues

None. BL-01 from the prior pass is closed by Plan 33-06.

## WARNINGs

### WR-01: `unauthorized signature creates NO ingress row` test uses an unparseable body — partially false-confident assertion

**File:** `test/chimeway/webhooks_test.exs:239-245`
**Issue:** The assertion claims to prove `D-09 / T-33-AUTH-LEAK` ("unauthorized signatures must NOT durably persist anything"). The test sends `"any"` as `raw_body` with an invalid signature. Because `"any"` is not valid JSON, even if `verify_webhook/3` returned `:ok` the next step (`decode_body/1`) would short-circuit with `{:error, :unparseable_body}` before the `Multi.insert(:ingress, …)` step. The first assertion (`{:error, :unauthorized}`) does provide *some* regression protection — if a refactor skipped `verify_webhook`, the result would be `:unparseable_body` and the assertion would fail — but the body still cannot prove the auth gate is the only thing preventing the ingress row when the rest of the pipeline would succeed. The companion test at `examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs:41-52` already uses a valid JSON body with an invalid signature; the library-layer test should mirror that shape so a regression like "verify_webhook accidentally returns `:ok`" is caught at the library boundary too.

This was reported as BL-02 in the prior pass; downgrading because the result-tag assertion does provide partial protection and because the host-layer test already covers the strict contract. Still worth fixing.

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

### WR-02: `Chimeway.Webhooks.process/4` accepts an iolist `raw_body` per spec but offers no enforcement

**File:** `lib/chimeway/webhooks.ex:28`
**Issue:** The `@spec` declares `process(module(), binary(), list(), keyword())`. The example controller flattens its iolist before calling `process/4`. There is no compile-time or runtime guard that the binary is actually a binary — if a host author forgets to flatten and passes the iolist directly, `RawBodyHmacAdapter.verify_webhook/3` (line 25, `when is_binary(body)`) raises `FunctionClauseError`, which inside `Webhooks.process/4`'s `with` chain bubbles up as an unhandled exception rather than `{:error, :unauthorized}`. That converts a benign mistake into a 500 (controller's `case` doesn't match any tuple) or worse, a leak-prone error response. Add an explicit `is_binary(raw_body)` guard at the `process/4` entry — fail closed with a clear error tuple that the controller can map to `400 Bad Request`.

**Fix:**
```elixir
def process(adapter_module, raw_body, headers, config)
    when is_atom(adapter_module) and is_binary(raw_body) and
         is_list(headers) and is_list(config) do
  # … existing body …
end

def process(_adapter_module, raw_body, _headers, _config) when not is_binary(raw_body) do
  {:error, :raw_body_must_be_binary}
end
```

### WR-03: No `:length` cap on `Plug.Parsers` in the demo endpoint — DoS surface in the reference host-mount

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

### WR-04: `webhooks_controller.ex` collapses every non-`:unauthorized` library error to a single 500, suppressing operator visibility

**File:** `examples/chimeway_demo_host/lib/demo_host_web/controllers/webhooks_controller.ex:43-47`
**Issue:** `{:error, :unparseable_body}`, `{:error, :unresolvable_delivery}`, `{:error, :unnormalizable_feedback}`, and `{:error, %Ecto.Changeset{}}` all map to `send_resp(conn, 500, "Internal Server Error")`. That hides the distinction between "client sent malformed JSON" (400) and "library/database failure" (500), violating the guidance the moduledoc itself acknowledges ("hosts may pick 400 / 422 based on their own observability conventions"). The same response makes it impossible to tell from the provider's retry logs whether the host or the provider needs to fix the issue. Either map the named error atoms to specific 4xx codes in the example, or add a TODO that points adopters at the right mapping table.

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

The same fragility applies to `run_feedback_pipeline/2` (line 96): `String.to_existing_atom(canonicalize_status(ingress.normalized_status))` raises if the ingress row was hand-crafted with an off-vocabulary status. The schema's `validate_inclusion(:normalized_status, ~w(delivered bounced failed))` defends the happy path, but database-level corruption or a future schema migration could surface a bad value here.

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

### WR-06: Demo host `mix.exs` does not list `:chimeway` in `extra_applications`, but the test suite assumes the Chimeway Repo + Oban supervisor are started

**File:** `examples/chimeway_demo_host/mix.exs:18`, `examples/chimeway_demo_host/test/test_helper.exs:8`
**Issue:** The test_helper relies on `Application.ensure_all_started(:demo_host)` to bring up `:chimeway` (and therefore the Repo + Oban). Currently `:demo_host`'s `application/0` returns `[mod: {DemoHost.Application, []}, extra_applications: [:logger]]` — `:chimeway` is not listed. This works today because Mix's dep-resolution pulls `:chimeway` into the app tree as a transitive dep, but the boot order becomes implementation-dependent on Mix's resolution algorithm. Add `:chimeway` to `extra_applications` to make the dependency explicit and survive Mix changes.

**Fix:**
```elixir
def application do
  [mod: {DemoHost.Application, []}, extra_applications: [:logger, :chimeway]]
end
```

### WR-07: `Chimeway.Webhooks.process/4` re-raises adapter-callback exceptions instead of converting to a structured error

**File:** `lib/chimeway/webhooks.ex:29-33`
**Issue:** `adapter_module.verify_webhook(raw_body, headers, config)`, `adapter_module.resolve_delivery(parsed)`, `adapter_module.normalize_feedback(parsed)`, and `adapter_module.resolve_provider_event_id(parsed)` are called directly inside the `with` chain. If the adapter raises (e.g., a buggy adapter calls `String.to_existing_atom` on untrusted input, or a third-party adapter raises on a malformed signature header), the exception propagates out of `Webhooks.process/4` and out of the host controller — typically as a 500 with the exception message, which can leak internals, and as an unrecoverable crash from the provider's perspective. `process/4` is documented as a "pure function boundary" but is not enforced as such. Either decide adapter exceptions are programmer errors (let them crash, surface in logs and document this) or wrap each adapter call in `try`/`rescue` and convert to a structured `{:error, :adapter_callback_raised}`. Whichever choice, document the contract in the moduledoc and add a test that pins the chosen behavior.

**Fix:** Document and pin the chosen behavior. If wrapping is the chosen direction:
```elixir
defp safe_call(fun, on_raise) do
  try do
    fun.()
  rescue
    e -> {:error, {on_raise, Exception.message(e)}}
  end
end
```

### WR-08: `update_in(conn.assigns[:raw_body], &[body | &1 || []])` operator-precedence ambiguity remains a fragile teaching boundary

**File:** `examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex:32,35`
**Issue:** The expression `&[body | &1 || []]` parses as `&[body | (&1 || [])]` because `||` binds tighter than `|`. This works (the moduledoc and BL-01 fix tests prove the runtime semantics), but the surrounding comments do not document this precedence and a maintainer who tweaks this line is likely to introduce a parse-shape bug (e.g., changing it to `&[body, &1 || []]` or `&[body | &1] || []`). At a teaching-example boundary that adopters are explicitly told to copy (D-12), exhaustiveness-over-brevity is the correct default — same principle that motivated 33-06's `case`-over-`with` rewrite. Either spell out the alternative form in the function body to remove the precedence trap, or add an inline comment that the reader does not need to know `||` precedence to understand the line.

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

## INFO

### IN-01: `chimeway_webhook_ingress.id` uses `:binary_id` without a `default: fragment("gen_random_uuid()")`, while peer migrations use `:uuid` with the DB-side default

**File:** `priv/repo/migrations/20260502120000_create_chimeway_webhook_ingress.exs:6`
**Issue:** Several existing migrations (e.g., `20260424082833_create_chimeway_deliveries.exs`, `20260424082834_create_chimeway_delivery_attempts.exs`) use `add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")`. The new ingress migration uses `add :id, :binary_id, primary_key: true` with no DB-side default, relying on Ecto's `autogenerate: true` in the schema. (Note: the codebase has mixed conventions — some migrations declare `:uuid` without the fragment default — so this is convention-drift, not a hard violation.) Both work, but the inconsistency complicates raw-SQL inserts (e.g., the test suite's `Ecto.Adapters.SQL.query!` calls in `process_feedback_worker_test.exs:155-159`, which already disable triggers and bind UUID binary literals) and operator-side data-fix scripts. Align with the dominant convention.

**Fix:**
```elixir
add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
```

### IN-02: `validate_correlation_present/1` attaches the error to `:delivery_id` even when the issue is a missing `provider_message_id` or missing `:ignored` reason

**File:** `lib/chimeway/webhooks/ingress.ex:64-77`
**Issue:** When validation fails, the error is added to the `:delivery_id` field with a message that mentions all three valid shapes. This makes the changeset error report harder to parse for callers that route on `changeset.errors[:provider_message_id]` or `changeset.errors[:ingress_state]`. Consider attaching the error to `:base` (Ecto supports `:base` as a conventional non-field error key), or replicate the same message onto every relevant field key so callers can match on any of them.

**Fix:** `add_error(changeset, :base, "…")` or replicate onto all three field keys.

### IN-03: `webhooks_controller.ex` defaults unknown adapter slugs to `EchoAdapter` instead of returning 404

**File:** `examples/chimeway_demo_host/lib/demo_host_web/controllers/webhooks_controller.ex:54`
**Issue:** `defp adapter_for(_unknown), do: DemoHost.Adapters.EchoAdapter` silently routes any unknown `/webhooks/chimeway/<slug>` to the `EchoAdapter`, which has the deliberately-weak `[{"signature", "valid"}]` literal-match check. An adopter who copies this controller and forgets to handle unknown slugs will accept arbitrary signed payloads under any URL. Fail closed with a 404 instead.

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

### IN-04: Hardcoded HMAC `@secret` in `RawBodyHmacAdapter` and hardcoded `secret_key_base` in `config.exs`

**File:** `examples/chimeway_demo_host/lib/demo_host/adapters/raw_body_hmac_adapter.ex:21`, `examples/chimeway_demo_host/config/config.exs:6`
**Issue:** Both values are intentional (the moduledoc and inline comments explicitly call them out as test/fixture-only). However, secret-scanning tools (truffleHog, gitleaks) will flag both, which adds noise for adopters who blindly copy the example into their own repo. Prefix with `# trufflehog:ignore` or move to `Application.compile_env/3` reads from an env var so the value is sourced from the environment by default, with the literal as a fallback only when `MIX_ENV == :test`.

---

_Reviewed: 2026-05-02T15:30:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
