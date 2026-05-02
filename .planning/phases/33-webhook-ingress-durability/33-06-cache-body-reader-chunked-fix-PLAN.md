---
phase: 33-webhook-ingress-durability
plan: 06
type: execute
wave: 1
depends_on: []
files_modified:
  - examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex
  - examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs
autonomous: true
requirements: [FEED-01, FEED-02]
requirements_addressed: [FEED-01, FEED-02]
gap_closure: true
tags: [elixir, plug, webhook, body_reader, chunked, hmac, regression]

must_haves:
  truths:
    - "On chunked-body delivery, the canonical `CacheBodyReader.read_body/2` accumulates ALL chunks into `conn.assigns[:raw_body]` (not just the final chunk). The function handles all three return shapes from `Plug.Conn.read_body/2` — `:ok`, `:more`, and `:error` — and updates `conn.assigns[:raw_body]` on both `:ok` and `:more` branches."
    - "T-33-RAWBODY threat mitigation holds for production-shaped traffic: the test suite no longer leaves the `:more` path unexercised. A regression test constructs a conn whose adapter returns `{:more, chunk1, conn}` then `{:ok, chunk2, conn}`, calls `CacheBodyReader.read_body/2` in the same loop pattern `Plug.Parsers` uses, and asserts `conn.assigns[:raw_body]` contains BOTH chunks (full body). An HMAC-over-full-body signature computed against the concatenated body still verifies — asserting status 200 and ingress row count == 1."
    - "The old `with {:ok, body, conn} <- Plug.Conn.read_body(conn, opts)` single-clause shape is gone from `cache_body_reader.ex`. The file contains a `{:more, body, conn} ->` branch that writes the chunk to `conn.assigns[:raw_body]`. The file contains an `{:error, _} = err -> err` branch. The grep pattern `with {:ok, body, conn} <- Plug.Conn.read_body` returns zero matches."
    - "The existing 5 E2E tests in `webhooks_controller_test.exs` still pass after the rewrite — the fix is additive, not destructive."
  artifacts:
    - path: "examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex"
      provides: "Corrected canonical body-reader plug that accumulates ALL chunks from Plug.Conn.read_body/2"
      contains: "{:more, body, conn} ->"
    - path: "examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs"
      provides: "Regression test that forces the :more path and asserts full-body HMAC verification passes"
      contains: "chunked-body delivery"
  key_links:
    - from: "examples/chimeway_demo_host/lib/demo_host_web/endpoint.ex"
      to: "examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex"
      via: "plug Plug.Parsers with body_reader: {DemoHost.Plugs.CacheBodyReader, :read_body, []}"
      pattern: "body_reader: \\{DemoHost.Plugs.CacheBodyReader"
    - from: "examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs"
      to: "examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex"
      via: "Direct calls to CacheBodyReader.read_body/2 with a custom chunked adapter conn in the unit regression"
      pattern: "CacheBodyReader.read_body"
    - from: "examples/chimeway_demo_host/lib/demo_host_web/controllers/webhooks_controller.ex"
      to: "Chimeway.Webhooks.process/4"
      via: "Chimeway.Webhooks.process(adapter_module, raw_body, headers, config) — raw_body is now correct for chunked delivery after the CacheBodyReader fix"
      pattern: "Chimeway.Webhooks.process"
---

<objective>
Close BL-01: the canonical `DemoHost.Plugs.CacheBodyReader.read_body/2` silently drops every chunk except the last when `Plug.Conn.read_body/2` returns `{:more, body, conn}`. The `with` clause only matches `:ok`; on `:more` it falls through without writing the chunk to `conn.assigns[:raw_body]`. Cowboy's default `:read_length` is 1 MB, so any provider webhook body larger than 1 MB will chunk — HMAC over the truncated (last-chunk-only) body never matches the provider's signature, yielding a silent 401 indistinguishable from a real attacker. The moduledoc tells host authors to "copy that pattern in your own host app" (D-12), propagating the defect to adopters.

Purpose: Restore the broader Phase 33 goal half — "ingress failures stay safe and explainable" — for production-shaped traffic (chunked bodies), not just for the non-chunked Plug.Test bodies the existing suite exercises. Fix the reference pattern so it is safe to copy. Add a regression test that exercises the `:more` code path so this can never silently regress again.

Output: Corrected `cache_body_reader.ex` + one new regression test describe block in `webhooks_controller_test.exs`. No chimeway core files are touched (D-10 boundary). `mix verify.example` exits 0 with all 6 tests passing.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/33-webhook-ingress-durability/33-CONTEXT.md
@.planning/phases/33-webhook-ingress-durability/33-VERIFICATION.md
@.planning/phases/33-webhook-ingress-durability/33-REVIEW.md
@.planning/phases/33-webhook-ingress-durability/33-04-SUMMARY.md

<interfaces>
<!-- Current defective implementation (read before touching): -->
<!-- examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex -->

From `examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex` (CURRENT — defective):
```elixir
def read_body(conn, opts) do
  with {:ok, body, conn} <- Plug.Conn.read_body(conn, opts) do
    conn = update_in(conn.assigns[:raw_body], &[body | &1 || []])
    {:ok, body, conn}
  end
end
```

The `with` clause only matches `:ok`. On `{:more, body, conn}`, the `with` falls through and returns
the bare `{:more, body, conn}` tuple to `Plug.Parsers` WITHOUT writing `body` to `conn.assigns[:raw_body]`.
Plug.Parsers then calls `read_body` again for the next chunk, but only the FINAL chunk (the `:ok`
return) is ever written to the cache. Chunks 1..N-1 are silently discarded.

From `33-REVIEW.md` BL-01 (the reference fix):
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

From `examples/chimeway_demo_host/lib/demo_host/adapters/raw_body_hmac_adapter.ex` (the HMAC adapter
already in place — use it as the E2E verifier in the regression test):
```elixir
@secret "test-secret-rawbody"

def verify_webhook(body, headers, _config) when is_binary(body) do
  expected = :crypto.mac(:hmac, :sha256, @secret, body) |> Base.encode16(case: :lower)
  case Enum.find(headers, fn {k, _} -> String.downcase(k) == "x-signature" end) do
    {_, provided} when is_binary(provided) ->
      if Plug.Crypto.secure_compare(provided, expected), do: :ok, else: {:error, :unauthorized}
    _ -> {:error, :unauthorized}
  end
end
```

From `Plug.Conn` (struct fields relevant to chunked unit test):
```elixir
# Plug.Conn.read_body/2 delegates to:
#   adapter_module.read_req_body(adapter_state, opts)
# which returns:
#   {:ok, data, new_state} | {:more, data, new_state} | {:error, reason}
#
# A Plug.Test conn's adapter is {Plug.Adapters.Test.Conn, %{...}}.
# Plug.Adapters.Test.Conn.read_req_body/2 always returns {:ok, full_body, state}
# regardless of read_length — it NEVER returns {:more, ...}.
#
# To force {:more, ...} without booting a real HTTP server, construct a conn
# with a custom adapter module that simulates chunked delivery:
#
#   %Plug.Conn{adapter: {MyChunkedAdapter, {["chunk1", "chunk2"], :pending}}}
#
# and implement read_req_body/2 to pop one chunk at a time.
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Rewrite CacheBodyReader.read_body/2 to handle :ok, :more, and :error</name>
  <files>examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex</files>

  <read_first>
    - examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex (MANDATORY — read the current file before writing; the action contains the FULL replacement)
    - .planning/phases/33-webhook-ingress-durability/33-REVIEW.md (BL-01 fix reference — lines 64-78)
    - .planning/phases/33-webhook-ingress-durability/33-VERIFICATION.md (gaps[0].missing — the two required remediations)
  </read_first>

  <action>
    Replace the entire content of `cache_body_reader.ex` with the following. The only substantive change is the `read_body/2` function: `with` is replaced by `case` and a `:more` branch is added that writes the chunk to `conn.assigns[:raw_body]` before returning `{:more, body, conn}` to `Plug.Parsers`. The `:error` passthrough branch is added. The moduledoc is updated to document the `:more` handling and remove the false implication that only the `:ok` branch writes to the cache.

    ```elixir
    defmodule DemoHost.Plugs.CacheBodyReader do
      @moduledoc """
      Reads the request body and caches it into `conn.assigns[:raw_body]` so
      webhook signature verification can run on the exact bytes the provider
      signed. `Plug.Parsers` consumes the body during JSON parsing; without a
      :body_reader the raw bytes are unrecoverable.

      Canonical pattern from hexdocs.pm/plug/Plug.Parsers.html — mirrored here
      because Chimeway core deliberately does not couple to Plug (Phase 33 D-10).

      ## Chunked delivery (production Cowboy)

      `Plug.Conn.read_body/2` returns `{:more, chunk, conn}` when the provider
      body exceeds Cowboy's `:read_length` (default 1 MB). `Plug.Parsers` calls
      `read_body/2` in a loop until it receives `:ok`. This implementation caches
      EVERY chunk — both `:ok` and `:more` branches prepend to the accumulator —
      so the full body is available in `conn.assigns[:raw_body]` regardless of
      how many TCP reads the provider request required.

      Pitfall (Phase 33 D-13 / T-33-RAWBODY): the cached body is an iolist
      (chunk-list accumulator, reverse arrival order). Controllers MUST flatten via
      `Enum.reverse/1 |> IO.iodata_to_binary/1` before passing to verify_webhook/3
      — adapters compute HMAC over binaries, and an iolist input silently fails
      verification. The reference controller at
      lib/demo_host_web/controllers/webhooks_controller.ex does this; copy that
      pattern in your own host app.
      """

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
    end
    ```

    Key invariants to preserve:
    - The accumulator expression `&[body | &1 || []]` is unchanged from the original (it is correct for the `:ok` branch and equally correct for `:more`). Do not simplify or reorder.
    - The `:ok` branch returns `{:ok, body, conn}` — NOT `{:ok, conn}` — because `Plug.Parsers` expects the full 3-tuple from the `:body_reader` MFA.
    - The `:more` branch returns `{:more, body, conn}` — the updated conn (with the chunk in `assigns[:raw_body]`) is the third element. `Plug.Parsers` passes this updated conn back as the first argument on the next `read_body/2` call, so the accumulator is threaded correctly across all calls.
    - The `:error` branch passes through unchanged — `Plug.Parsers` handles `:error` by stopping the read loop and returning an error.
    - Do NOT modify `examples/chimeway_demo_host/lib/demo_host_web/endpoint.ex` — no `:length` or `:read_length` changes are needed for this fix.
    - Do NOT touch any file under `lib/chimeway/` (D-10 boundary — chimeway core must not couple to Plug).
  </action>

  <verify>
    <automated>
      cd /Users/jon/projects/chimeway &&
      grep -c "with {:ok, body, conn} <- Plug.Conn.read_body" examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex | grep -q "^0$" &&
      grep -q "{:more, body, conn} ->" examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex &&
      grep -q "{:error, _} = err" examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex &&
      grep -q "case Plug.Conn.read_body(conn, opts) do" examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex &&
      grep -q "update_in(conn.assigns\[:raw_body\]" examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex &&
      cd examples/chimeway_demo_host && mix compile --warnings-as-errors 2>&1 | tail -5
    </automated>
  </verify>

  <acceptance_criteria>
    - `grep -c "with {:ok, body, conn} <- Plug.Conn.read_body" examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex` returns `0` — the old single-clause shape is gone.
    - `grep -q "{:more, body, conn} ->" examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex` exits 0 — the `:more` branch exists.
    - `grep -q "{:error, _} = err" examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex` exits 0 — the `:error` passthrough exists.
    - `grep -q "case Plug.Conn.read_body(conn, opts) do" examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex` exits 0 — the `case` replaces `with`.
    - Both `:ok` and `:more` branches contain `update_in(conn.assigns[:raw_body]` — confirmed by `grep -c "update_in(conn.assigns\[:raw_body\]" examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex` returning `2`.
    - `cd examples/chimeway_demo_host && mix compile --warnings-as-errors` exits 0 — no compile errors or new warnings introduced.
    - No files under `lib/chimeway/` were modified — confirmed by `git diff --name-only lib/chimeway/` returning empty.
  </acceptance_criteria>

  <done>The `read_body/2` function handles all three return shapes from `Plug.Conn.read_body/2`. The old `with`-clause shape is gone. The file compiles clean. The reference pattern is now safe to copy (D-12).</done>
</task>

<task type="auto">
  <name>Task 2: Add chunked-body regression test that forces the :more path via a custom adapter conn</name>
  <files>examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs</files>

  <read_first>
    - examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs (MANDATORY — read the entire current file; the new describe block appends AFTER the existing tests)
    - examples/chimeway_demo_host/lib/demo_host/adapters/raw_body_hmac_adapter.ex (the HMAC fixture adapter — note @secret = "test-secret-rawbody")
    - examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex (Task 1 output — the fixed module being tested)
    - .planning/phases/33-webhook-ingress-durability/33-VERIFICATION.md (gaps[0].missing — the required regression test specification)
  </read_first>

  <action>
    Append a second `describe` block to the end of `DemoHostWeb.WebhooksControllerTest` (BEFORE the final `end`). Do NOT modify any of the 5 existing tests.

    The regression test works as follows:

    **Why Plug.Test cannot force {:more, ...}:** `Plug.Test.conn/3` uses `Plug.Adapters.Test.Conn` as its adapter, which always returns `{:ok, full_body, state}` from `read_req_body/2` regardless of `:read_length`. To exercise the `:more` path we need a conn whose adapter returns `{:more, chunk, state}` on the first call. We achieve this by defining a minimal `ChunkedTestAdapter` in the test file that pops chunks from a list, and constructing a bare `%Plug.Conn{}` with that adapter.

    **Test flow:**
    1. Build a `body` string from two equal halves: `chunk1 <> chunk2` where each half is 50 bytes.
    2. Compute HMAC-SHA256 over the FULL concatenated body using the same `@secret` as `RawBodyHmacAdapter`.
    3. Construct a `%Plug.Conn{}` with `adapter: {ChunkedTestAdapter, %{chunks: [chunk1, chunk2]}}`.
    4. Call `CacheBodyReader.read_body(conn, [])` → returns `{:more, chunk1, updated_conn}`.
    5. Call `CacheBodyReader.read_body(updated_conn, [])` → returns `{:ok, chunk2, final_conn}`.
    6. Assert `final_conn.assigns[:raw_body]` equals `[chunk2, chunk1]` (reverse prepend order).
    7. Assert `IO.iodata_to_binary(Enum.reverse(final_conn.assigns[:raw_body]))` equals the original full body.
    8. Run the full E2E through the endpoint: post to `/webhooks/chimeway/rawbody` with the full body and the HMAC signature over the full body. Assert status 200 and ingress row count == 1.

    **Note on step 8**: The E2E test through `DemoHostWeb.Endpoint` still uses `Plug.Test.conn/3` (which delivers in a single `:ok`), but after the Task 1 fix this is safe — the `:ok` branch also writes to the cache. The E2E portion proves the FULL path: body arrives, HMAC verification passes, ingress row is committed. The unit portion (steps 3-7) is the part that specifically exercises the `:more` branch.

    The describe block to append (paste verbatim between the last `end` of the existing describe and the module `end`):

    ```elixir
      describe "BL-01 regression: CacheBodyReader chunked-body accumulation" do
        # ---------------------------------------------------------------------------
        # Why a custom adapter: Plug.Test.conn/3 uses Plug.Adapters.Test.Conn whose
        # read_req_body/2 always returns {:ok, full_body, state} — it NEVER returns
        # {:more, ...} regardless of :read_length opts. To exercise the :more branch
        # we construct a bare %Plug.Conn{} with a custom adapter that pops chunks.
        #
        # ChunkedTestAdapter simulates Cowboy delivering a body in two TCP reads:
        #   first call  → {:more, chunk1, new_state}
        #   second call → {:ok,  chunk2, new_state}
        # ---------------------------------------------------------------------------

        defmodule ChunkedTestAdapter do
          @moduledoc false
          @behaviour Plug.Conn.Adapter

          # Called by Plug.Conn.read_body/2.
          # State is %{chunks: remaining_chunks}.
          @impl true
          def read_req_body(%{chunks: [only]} = state, _opts) do
            {:ok, only, %{state | chunks: []}}
          end

          def read_req_body(%{chunks: [head | tail]} = state, _opts) do
            {:more, head, %{state | chunks: tail}}
          end

          def read_req_body(%{chunks: []}, _opts) do
            {:ok, "", %{chunks: []}}
          end

          # Required Plug.Conn.Adapter callbacks — not used by this test.
          @impl true
          def send_resp(state, _status, _headers, _body), do: {:ok, nil, state}
          @impl true
          def send_file(state, _status, _headers, _path, _offset, _length), do: {:ok, nil, state}
          @impl true
          def send_chunked(state, _status, _headers), do: {:ok, nil, state}
          @impl true
          def chunk(state, _body), do: {:ok, state}
          @impl true
          def inform(state, _status, _headers), do: {:ok, state}
          @impl true
          def upgrade(state, _protocol, _opts), do: {:error, :not_supported}
          @impl true
          def push(state, _path, _headers), do: {:ok, state}
          @impl true
          def get_peer_data(_state), do: %{address: {127, 0, 0, 1}, port: 0, ssl_cert: nil}
          @impl true
          def get_http_protocol(_state), do: :"HTTP/1.1"
        end

        test "CacheBodyReader accumulates ALL chunks — :more path writes to assigns (BL-01 unit)" do
          alias DemoHost.Plugs.CacheBodyReader

          # Two 50-byte chunks — total body is 100 bytes.
          chunk1 = String.duplicate("A", 50)
          chunk2 = String.duplicate("B", 50)
          full_body = chunk1 <> chunk2

          # Construct a bare conn with the chunked adapter.
          # assigns[:raw_body] starts as nil (the accumulator's nil-guard handles this).
          conn = %Plug.Conn{
            adapter: {ChunkedTestAdapter, %{chunks: [chunk1, chunk2]}},
            assigns: %{}
          }

          # First call: adapter returns {:more, chunk1, ...}
          # CacheBodyReader MUST write chunk1 to assigns[:raw_body].
          {:more, ^chunk1, conn_after_first} = CacheBodyReader.read_body(conn, [])
          assert conn_after_first.assigns[:raw_body] == [chunk1],
            "Expected [chunk1] after first read; got #{inspect(conn_after_first.assigns[:raw_body])}"

          # Second call: adapter returns {:ok, chunk2, ...}
          # CacheBodyReader MUST write chunk2 to assigns[:raw_body] (prepended).
          {:ok, ^chunk2, conn_after_second} = CacheBodyReader.read_body(conn_after_first, [])
          assert conn_after_second.assigns[:raw_body] == [chunk2, chunk1],
            "Expected [chunk2, chunk1] after second read; got #{inspect(conn_after_second.assigns[:raw_body])}"

          # Flatten: Enum.reverse |> IO.iodata_to_binary must recover the full body.
          recovered =
            conn_after_second.assigns[:raw_body]
            |> Enum.reverse()
            |> IO.iodata_to_binary()

          assert recovered == full_body,
            "Flattened body #{inspect(recovered)} does not equal original #{inspect(full_body)}"
        end

        test "chunked-body delivery — HMAC over full body still verifies (E2E, status 200, ingress row == 1)" do
          # This test proves that after the BL-01 fix, the full-body HMAC still
          # passes through the endpoint pipeline even for bodies that would chunk
          # in production. Because Plug.Test always delivers in a single :ok read,
          # this E2E proves the :ok-path post-fix; the unit test above proves :more.
          #
          # Together they close the gap: the :more path now writes chunks, and the
          # final :ok path has always written. Signature over the full body verifies.
          provider_msg_id = "msg-chunked-" <> Ecto.UUID.generate()

          # Body with intentional non-canonical whitespace (same strategy as the
          # existing verify-before-parse test) so any parse-then-re-encode would
          # produce different bytes and break the HMAC.
          body =
            ~s|{"id":  "| <> provider_msg_id <> ~s|",  "status": "ok"}|

          secret = "test-secret-rawbody"

          signature =
            :crypto.mac(:hmac, :sha256, secret, body)
            |> Base.encode16(case: :lower)

          conn =
            Plug.Test.conn(:post, "/webhooks/chimeway/rawbody", body)
            |> Plug.Conn.put_req_header("content-type", "application/json")
            |> Plug.Conn.put_req_header("x-signature", signature)
            |> DemoHostWeb.Endpoint.call(DemoHostWeb.Endpoint.init([]))

          # Status 200 proves the HMAC over the full raw bytes matched the
          # signature the adapter computed — i.e., CacheBodyReader preserved
          # the complete body (no truncation).
          assert conn.status == 200,
            "Expected 200 but got #{conn.status}; likely HMAC mismatch from truncated body"

          # Ingress row exists — the full pipeline ran to completion.
          assert [%Chimeway.Webhooks.Ingress{provider_message_id: ^provider_msg_id}] =
                   Chimeway.Repo.all(Chimeway.Webhooks.Ingress),
                 "Expected exactly 1 ingress row with provider_message_id=#{provider_msg_id}"
        end
      end
    ```

    **Exact edit instructions:**
    - Open the file.
    - Find the final `end` that closes the outer `describe "POST /webhooks/chimeway/echo ...` block.
    - Insert the new `describe` block AFTER that `end` and BEFORE the module-level `end`.
    - The file should end with the new describe's `end`, then the module's `end`.
    - Do NOT touch the 5 existing tests.

    **Verification that `ChunkedTestAdapter` compiles:**
    The adapter implements `@behaviour Plug.Conn.Adapter`. In Plug 1.16 the required callbacks are:
    `read_req_body/2`, `send_resp/4`, `send_file/6`, `send_chunked/3`, `chunk/2`, `inform/3`,
    `upgrade/3`, `push/3`, `get_peer_data/1`, `get_http_protocol/1`. All are implemented above.
    If `mix compile` reports a missing callback, add the stub (consult `Plug.Conn.Adapter` behaviour
    module for the exact spec of the missing function).
  </action>

  <verify>
    <automated>
      cd /Users/jon/projects/chimeway &&
      grep -q "BL-01 regression: CacheBodyReader chunked-body accumulation" examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs &&
      grep -q "ChunkedTestAdapter" examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs &&
      grep -q "chunked-body delivery" examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs &&
      grep -q "CacheBodyReader accumulates ALL chunks" examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs &&
      cd examples/chimeway_demo_host && mix compile --warnings-as-errors 2>&1 | tail -5
    </automated>
  </verify>

  <acceptance_criteria>
    - `grep -q "BL-01 regression: CacheBodyReader chunked-body accumulation" examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs` exits 0.
    - `grep -q "ChunkedTestAdapter" examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs` exits 0 — the custom adapter module is defined in the test file.
    - `grep -q "CacheBodyReader.read_body" examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs` exits 0 — the unit test calls the module directly.
    - `grep -q "chunked-body delivery" examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs` exits 0 — the E2E test name is present.
    - The file still contains all 5 original test names: "valid signature", "bad signature", "unresolvable body", "raw body iolist", "verify-before-parse ordering" — confirmed by grep for each.
    - `cd examples/chimeway_demo_host && mix compile --warnings-as-errors` exits 0.
    - The `ChunkedTestAdapter` implements `@behaviour Plug.Conn.Adapter` — confirmed by `grep -q "@behaviour Plug.Conn.Adapter" examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs`.
  </acceptance_criteria>

  <done>Two new tests are appended in a "BL-01 regression" describe block: a unit test that directly exercises the `:more` branch via a custom adapter conn, and an E2E test that sends a full-body HMAC request through the endpoint and asserts status 200 + ingress row. The 5 existing tests are untouched.</done>
</task>

<task type="auto">
  <name>Task 3: Run the full verify chain and confirm all 7 tests pass</name>
  <files></files>

  <read_first>
    - No file reads required — this task runs commands only.
    - If any test fails, read the failure output and the relevant source file before fixing.
  </read_first>

  <action>
    Run the following commands in sequence. Every command must exit 0 before proceeding to the next.

    **Step 1: Confirm the old `with`-clause shape is gone**
    ```bash
    cd /Users/jon/projects/chimeway
    grep -c "with {:ok, body, conn} <- Plug.Conn.read_body" \
      examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex
    # Expected output: 0
    ```

    **Step 2: Confirm the :more branch exists**
    ```bash
    grep -q "{:more, body, conn} ->" \
      examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex && echo "PASS: :more branch found"
    ```

    **Step 3: Run the chimeway core test suite (must not be broken by the fix)**
    ```bash
    MIX_ENV=test mix test
    # Expected: all existing tests pass (no regressions in chimeway core)
    ```

    **Step 4: Run the full example app test suite via the root alias**
    ```bash
    mix verify.example
    # Expected: 7 tests, 0 failures, exit 0
    # (5 original + 2 new BL-01 regression tests)
    ```

    **Step 5: Confirm no chimeway core files were modified**
    ```bash
    git diff --name-only lib/chimeway/
    # Expected: empty output (no core files touched — D-10 boundary preserved)
    ```

    If `mix verify.example` reports fewer than 7 tests, the new describe block was not appended
    correctly — go back to Task 2 and verify the file structure. If it reports a compile error
    from `ChunkedTestAdapter`, check that all `@behaviour Plug.Conn.Adapter` callbacks are
    implemented (add missing stubs).
  </action>

  <verify>
    <automated>
      cd /Users/jon/projects/chimeway &&
      grep -c "with {:ok, body, conn} <- Plug.Conn.read_body" examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex | grep -q "^0$" &&
      grep -q "{:more, body, conn} ->" examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex &&
      MIX_ENV=test mix test 2>&1 | grep -E "^[0-9]+ tests" &&
      mix verify.example 2>&1 | grep -E "7 tests, 0 failures"
    </automated>
  </verify>

  <acceptance_criteria>
    - `grep -c "with {:ok, body, conn} <- Plug.Conn.read_body" examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex` outputs `0`.
    - `grep -q "{:more, body, conn} ->" examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex` exits 0.
    - `MIX_ENV=test mix test` exits 0 with 0 failures (chimeway core suite unaffected).
    - `mix verify.example` exits 0.
    - `mix verify.example` output contains `7 tests, 0 failures` — confirming both new BL-01 regression tests pass alongside the 5 original E2E tests.
    - `git diff --name-only lib/chimeway/` produces no output (D-10: chimeway core is untouched).
  </acceptance_criteria>

  <done>All 7 tests pass. The `:more` path is exercised by the regression test suite. The BL-01 gap is closed. `mix verify.example` exits 0.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Provider HTTP -> CacheBodyReader MFA | Raw bytes from provider cross into the body cache on EVERY `Plug.Conn.read_body/2` call — including chunked calls. Previously only the final `:ok` chunk crossed this boundary into the cache. |
| CacheBodyReader assigns -> Controller | The controller reads `conn.assigns[:raw_body]` and flattens via `Enum.reverse |> IO.iodata_to_binary`. After the fix, this contains ALL chunks. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-33-RAWBODY | Tampering / Spoofing | `CacheBodyReader.read_body/2` | mitigate | Fix: `case` replaces `with`; both `:ok` and `:more` branches call `update_in(conn.assigns[:raw_body], &[body | &1 || []])`. HMAC is now computed over the full body regardless of chunking. Regression test (Task 2 unit test) forces `{:more, ...}` via `ChunkedTestAdapter` and asserts all chunks accumulate before flattening. The existing verify-before-parse E2E test (`RawBodyHmacAdapter` with non-canonical whitespace) continues to pass and detects any future parse-before-verify regression. |
| T-33-CHUNK-DROP | Spoofing / Repudiation | `CacheBodyReader.read_body/2` (previously unmitigated) | mitigate | The `:more` path previously returned `{:more, body, conn}` to `Plug.Parsers` WITHOUT updating `conn.assigns[:raw_body]`. A provider could craft a chunked body where chunk 1 differs from what the final HMAC covers — any chunk 1 content was silently discarded. Now every chunk is written. The unit regression test asserts `conn.assigns[:raw_body] == [chunk1]` after the first (`:more`) read, directly proving no chunk is dropped. |
</threat_model>

<verification>
Overall phase checks after this gap-closure plan completes:

- `grep -c "with {:ok, body, conn} <- Plug.Conn.read_body" examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex` returns `0`.
- `grep -c "{:more, body, conn} ->" examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex` returns `1`.
- `grep -c "{:error, _} = err" examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex` returns `1`.
- `grep -c "update_in(conn.assigns\[:raw_body\]" examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex` returns `2` (one per `:ok` and `:more` branch).
- `mix verify.example` exits 0 with `7 tests, 0 failures`.
- `MIX_ENV=test mix test` exits 0 (chimeway core suite unaffected).
- `git diff --name-only lib/chimeway/` is empty (D-10 preserved).
- `grep -q "BL-01 regression: CacheBodyReader chunked-body accumulation" examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs` exits 0.
- `grep -q "ChunkedTestAdapter" examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs` exits 0.
</verification>

<success_criteria>
- `DemoHost.Plugs.CacheBodyReader.read_body/2` handles `:ok`, `:more`, and `:error` — all three return shapes from `Plug.Conn.read_body/2`. Both `:ok` and `:more` branches write the chunk to `conn.assigns[:raw_body]`.
- The old `with {:ok, body, conn} <- Plug.Conn.read_body(conn, opts)` single-clause shape is gone. Any adopter who copies the reference pattern now gets correct chunked-body behavior.
- A regression test in `webhooks_controller_test.exs` directly exercises the `:more` path via `ChunkedTestAdapter` and asserts that `conn.assigns[:raw_body]` contains ALL chunks after the read loop.
- An E2E regression test asserts that a full-body HMAC signature over a body delivered through the endpoint returns status 200 and produces an ingress row.
- `mix verify.example` exits 0 with all 7 tests passing.
- No chimeway core files (`lib/chimeway/...`) are modified (D-10 boundary).
- BL-01 is closed. The broader Phase 33 goal ("ingress failures stay safe and explainable") now holds for production-shaped traffic.
</success_criteria>

<output>
After completion, create `.planning/phases/33-webhook-ingress-durability/33-06-SUMMARY.md` per `$HOME/.claude/get-shit-done/templates/summary.md`. Include:
- `gap_closed: BL-01`
- `requirements_completed: [FEED-01, FEED-02]`
- `threats_mitigated: [T-33-RAWBODY, T-33-CHUNK-DROP]`
- Note: the moduledoc on `CacheBodyReader` now correctly documents chunked delivery behavior and is safe for adopters to copy (D-12 fulfilled).
</output>
